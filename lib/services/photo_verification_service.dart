import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Service for photo verification when resolving issues
class PhotoVerificationService {
  final SupabaseClient _supabase;
  final ImagePicker _imagePicker = ImagePicker();

  PhotoVerificationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Capture verification photo with metadata
  Future<VerificationPhoto?> captureVerificationPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Get current location
      final position = await _getCurrentPosition();

      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        image.path,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedBytes == null) return null;

      return VerificationPhoto(
        bytes: compressedBytes,
        originalPath: image.path,
        capturedAt: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
    } catch (e) {
      print('Error capturing verification photo: $e');
      return null;
    }
  }

  /// Upload verification photo to storage
  Future<String?> uploadVerificationPhoto({
    required String issueId,
    required VerificationPhoto photo,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final fileName =
          'verification_${issueId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'verifications/$issueId/$fileName';

      await _supabase.storage
          .from('issue-media')
          .uploadBinary(
            path,
            Uint8List.fromList(photo.bytes),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _supabase.storage
          .from('issue-media')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print('Error uploading verification photo: $e');
      return null;
    }
  }

  /// Submit resolution with photo verification
  Future<ResolutionResult> submitResolution({
    required String issueId,
    required VerificationPhoto photo,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return ResolutionResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Upload photo
      final photoUrl = await uploadVerificationPhoto(
        issueId: issueId,
        photo: photo,
      );

      if (photoUrl == null) {
        return ResolutionResult(
          success: false,
          error: 'Failed to upload verification photo',
        );
      }

      // Create resolution record
      await _supabase.from('issue_resolutions').insert({
        'issue_id': issueId,
        'worker_id': userId,
        'verification_photo_url': photoUrl,
        'notes': notes,
        'photo_latitude': photo.latitude,
        'photo_longitude': photo.longitude,
        'resolved_at': DateTime.now().toIso8601String(),
      });

      // Update issue status
      await _supabase
          .from('civic_issues')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': userId,
            'resolution_photo_url': photoUrl,
          })
          .eq('id', issueId);

      return ResolutionResult(success: true, photoUrl: photoUrl);
    } catch (e) {
      return ResolutionResult(
        success: false,
        error: 'Error submitting resolution: $e',
      );
    }
  }

  /// Get resolution details for an issue
  Future<Map<String, dynamic>?> getResolutionDetails(String issueId) async {
    try {
      final response = await _supabase
          .from('issue_resolutions')
          .select('*, worker:worker_id(email, first_name, last_name)')
          .eq('issue_id', issueId)
          .order('resolved_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting resolution details: $e');
      return null;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Captured verification photo with metadata
class VerificationPhoto {
  final List<int> bytes;
  final String originalPath;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;

  VerificationPhoto({
    required this.bytes,
    required this.originalPath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;
}

/// Result of resolution submission
class ResolutionResult {
  final bool success;
  final String? photoUrl;
  final String? error;

  ResolutionResult({required this.success, this.photoUrl, this.error});
}
