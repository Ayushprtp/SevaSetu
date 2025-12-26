import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for geofencing and location verification
class GeofencingService {
  final SupabaseClient _supabase;

  /// Maximum allowed distance (in meters) from issue location for status updates
  static const double maxDistanceMeters = 100.0;

  GeofencingService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Check if user is within allowed distance of issue location
  Future<GeofenceResult> verifyWorkerAtLocation(String issueId) async {
    try {
      // Get current position
      final position = await _getCurrentPosition();
      if (position == null) {
        return GeofenceResult(
          isWithinRange: false,
          error: 'Unable to get current location',
        );
      }

      // Get issue location
      final issueLocation = await _getIssueLocation(issueId);
      if (issueLocation == null) {
        return GeofenceResult(
          isWithinRange: false,
          error: 'Issue location not found',
        );
      }

      // Calculate distance
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        issueLocation['latitude'] as double,
        issueLocation['longitude'] as double,
      );

      final isWithinRange = distance <= maxDistanceMeters;

      return GeofenceResult(
        isWithinRange: isWithinRange,
        currentDistance: distance,
        maxAllowedDistance: maxDistanceMeters,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
        issueLatitude: issueLocation['latitude'] as double,
        issueLongitude: issueLocation['longitude'] as double,
      );
    } catch (e) {
      return GeofenceResult(
        isWithinRange: false,
        error: 'Error verifying location: $e',
      );
    }
  }

  /// Get current position with permission handling
  Future<Position?> _getCurrentPosition() async {
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
  }

  /// Get issue location from database
  Future<Map<String, double>?> _getIssueLocation(String issueId) async {
    try {
      final response = await _supabase
          .from('civic_issues')
          .select('location')
          .eq('id', issueId)
          .single();

      final location = response['location'] as String?;
      if (location == null) return null;

      // Parse POINT(lng lat) format
      final regex = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
      final match = regex.firstMatch(location);
      if (match == null) return null;

      return {
        'longitude': double.parse(match.group(1)!),
        'latitude': double.parse(match.group(2)!),
      };
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Log location verification attempt
  Future<void> logVerificationAttempt({
    required String issueId,
    required String workerId,
    required bool success,
    double? distance,
    String? error,
  }) async {
    await _supabase.from('location_verifications').insert({
      'issue_id': issueId,
      'worker_id': workerId,
      'success': success,
      'distance_meters': distance,
      'error_message': error,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

/// Result of geofence verification
class GeofenceResult {
  final bool isWithinRange;
  final double? currentDistance;
  final double? maxAllowedDistance;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? issueLatitude;
  final double? issueLongitude;
  final String? error;

  GeofenceResult({
    required this.isWithinRange,
    this.currentDistance,
    this.maxAllowedDistance,
    this.currentLatitude,
    this.currentLongitude,
    this.issueLatitude,
    this.issueLongitude,
    this.error,
  });

  String get distanceMessage {
    if (currentDistance == null) return 'Unknown distance';
    if (currentDistance! < 1000) {
      return '${currentDistance!.toStringAsFixed(0)}m away';
    }
    return '${(currentDistance! / 1000).toStringAsFixed(1)}km away';
  }
}
