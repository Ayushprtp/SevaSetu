import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:sevasetu/services/photo_verification_service.dart';
import 'package:sevasetu/services/geofencing_service.dart';

/// Dialog for photo verification when resolving issues
class PhotoVerificationDialog extends StatefulWidget {
  final String issueId;
  final VoidCallback? onResolved;

  const PhotoVerificationDialog({
    super.key,
    required this.issueId,
    this.onResolved,
  });

  @override
  State<PhotoVerificationDialog> createState() =>
      _PhotoVerificationDialogState();
}

class _PhotoVerificationDialogState extends State<PhotoVerificationDialog> {
  final PhotoVerificationService _photoService = PhotoVerificationService();
  final GeofencingService _geofencingService = GeofencingService();
  final TextEditingController _notesController = TextEditingController();

  VerificationPhoto? _capturedPhoto;
  GeofenceResult? _geofenceResult;
  bool _isVerifyingLocation = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _verifyLocation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _verifyLocation() async {
    setState(() => _isVerifyingLocation = true);
    final result = await _geofencingService.verifyWorkerAtLocation(
      widget.issueId,
    );
    setState(() {
      _geofenceResult = result;
      _isVerifyingLocation = false;
    });
  }

  Future<void> _capturePhoto() async {
    setState(() => _isCapturing = true);
    final photo = await _photoService.captureVerificationPhoto();
    setState(() {
      _capturedPhoto = photo;
      _isCapturing = false;
    });
  }

  Future<void> _submitResolution() async {
    if (_capturedPhoto == null) return;

    setState(() => _isSubmitting = true);

    final result = await _photoService.submitResolution(
      issueId: widget.issueId,
      photo: _capturedPhoto!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue resolved successfully!')),
        );
        widget.onResolved?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to submit resolution'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Verify Resolution', style: AppTextStyles.titleLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Location verification
              _buildLocationSection(),
              const SizedBox(height: AppSpacing.lg),

              // Photo capture
              _buildPhotoSection(),
              const SizedBox(height: AppSpacing.lg),

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Resolution Notes (optional)',
                  hintText: 'Add any notes about the resolution...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submitResolution : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    return _capturedPhoto != null &&
        (_geofenceResult?.isWithinRange ?? false) &&
        !_isSubmitting;
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _getLocationColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _getLocationColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (_isVerifyingLocation)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              _geofenceResult?.isWithinRange == true
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: _getLocationColor(),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVerifyingLocation
                      ? 'Verifying location...'
                      : _geofenceResult?.isWithinRange == true
                      ? 'Location verified'
                      : 'Not at issue location',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: _getLocationColor(),
                  ),
                ),
                if (_geofenceResult != null && !_isVerifyingLocation)
                  Text(
                    _geofenceResult!.distanceMessage,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isVerifyingLocation)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _verifyLocation,
              tooltip: 'Refresh location',
            ),
        ],
      ),
    );
  }

  Color _getLocationColor() {
    if (_isVerifyingLocation) return AppColors.info;
    if (_geofenceResult?.isWithinRange == true) return AppColors.success;
    return AppColors.error;
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification Photo', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),

        if (_capturedPhoto != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.file(
                  File(_capturedPhoto!.originalPath),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => setState(() => _capturedPhoto = null),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              if (_capturedPhoto!.hasLocation)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GPS tagged',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          InkWell(
            onTap: _isCapturing ? null : _capturePhoto,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.neutral300,
                  style: BorderStyle.solid,
                ),
              ),
              child: _isCapturing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 48,
                          color: AppColors.neutral400,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tap to capture photo',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

/// Show the photo verification dialog
Future<void> showPhotoVerificationDialog({
  required BuildContext context,
  required String issueId,
  VoidCallback? onResolved,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        PhotoVerificationDialog(issueId: issueId, onResolved: onResolved),
  );
}
