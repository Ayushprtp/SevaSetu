import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart'; // Assuming this is used for snackbars
import 'package:flutter/cupertino.dart'; // Import for CupertinoSliverNavigationBar
import 'package:sevasetu/utils/app_styles.dart'; // Added import
import 'package:sevasetu/hierarchical_system/issue_processing_service.dart';

class ReportProblemPage extends StatefulWidget {
  final VoidCallback? onReportSubmitted;
  const ReportProblemPage({super.key, this.onReportSubmitted});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  // Form data
  List<String> _capturedMedia = [];
  String _selectedCategory = '';
  String _description = '';
  String _location = ''; // This will be updated with the actual address
  bool _isVerifiedUser = false; // This will be determined by user's id_value
  bool _isSubmitting = false; // New state variable for submission
  bool _isLoadingUserData = true; // New state variable for loading user data
  Map<String, dynamic>? _userData; // New state variable to hold user data

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // Location data
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Categories for issues
  final List<String> _categories = [
    'POTHOLE',
    'Power Cut',
    'Water Leak',
    'Sewage Overflow',
    'Garbage Issue',
    'Street Light',
    'Drainage Problem',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data to check verification status
    _getCurrentLocation(); // Automatically capture location on page load
    _initSpeech();
  }

  /// Fetch user data to determine verification status
  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoadingUserData = false;
        });
        return;
      }

      final response = await supabase
          .from('users')
          .select('id_value')
          .eq('id', user.id)
          .single();

      setState(() {
        _userData = response as Map<String, dynamic>?;
        // User is verified if id_value is not null and not empty
        _isVerifiedUser =
            (response['id_value'] as String?)?.isNotEmpty ?? false;
        _isLoadingUserData = false;
      });
    } catch (e) {
      // If we can't fetch user data, assume not verified
      setState(() {
        _isLoadingUserData = false;
        _isVerifiedUser = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking verification status: $e')),
        );
      }
    }
  }

  /// This initializes the speech to text plugin.
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    if (_speechEnabled) {
      setState(() {
        _isListening = true;
      });
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30), // Listen for up to 30 seconds
        localeId: 'en_IN', // Specify Indian English locale
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  /// Manually stop the active speech recognition session
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns a new result.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _description =
          _description + (_description.isEmpty ? '' : ' ') + _lastWords;
    });
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to get your current location',
            ),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in your device settings.',
              ),
            ),
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await _checkLocationPermission();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied. Please enable them in your device settings.',
              ),
            ),
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _location =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}'; // Update location string
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location retrieved successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<void> _captureImage() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to capture images'),
            ),
          );
        }
        return;
      }

      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _capturedMedia.add(photo.path);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo captured successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _capturedMedia.addAll(images.map((e) => e.path));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} images selected from gallery'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting images: $e')));
      }
    }
  }

  Future<String?> _compressAndUploadImage(String imagePath) async {
    try {
      final compressedFile = File('${imagePath}_compressed.jpg');

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        compressedFile.path,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedImage == null) {
        throw Exception('Failed to compress image');
      }

      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName =
          'issues/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('media')
          .upload(fileName, File(compressedImage.path));

      final publicUrl = supabase.storage.from('media').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
      return null;
    }
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_selectedCategory.isEmpty) {
        throw Exception('Please select a category');
      }

      if (_description.isEmpty) {
        throw Exception('Please provide a description');
      }

      if (_currentPosition == null) {
        throw Exception('Please provide a location');
      }

      // Upload all media files
      final uploadedMediaUrls = await _uploadAllMedia();

      // Use the new IssueProcessingService for AI analysis and routing
      final processingService = IssueProcessingService();
      final result = await processingService.createIssueWithAnalysis(
        userId: user.id,
        category: _selectedCategory,
        description: _description,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _location,
        district: 'Bhopal', // TODO: Extract from reverse geocoding
        state: 'Madhya Pradesh', // TODO: Extract from reverse geocoding
        mediaUrls: uploadedMediaUrls,
        voiceNoteUrl: null,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Failed to create issue');
      }

      // Store current state before clearing for the dialog
      final bool locationCaptured = _currentPosition != null;
      final int mediaCount = _capturedMedia.length;

      setState(() {
        _capturedMedia.clear();
        _selectedCategory = '';
        _description = '';
        _currentPosition = null;
        _location = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
        _showSubmissionSuccessWithAI(
          result.issueId,
          locationCaptured,
          mediaCount,
          result,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<List<String>> _uploadAllMedia() async {
    final List<String> uploadedUrls = [];

    for (final mediaPath in _capturedMedia) {
      final url = await _compressAndUploadImage(mediaPath);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  void _showSubmissionSuccess(
    String? issueId,
    bool locationCaptured,
    int mediaCount,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to close
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                SizedBox(height: 24),
                Text(
                  'Report Submitted!',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Your report has been received and is being processed.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: 24),
                _buildStatusRow(
                  context,
                  Icons.location_on,
                  locationCaptured
                      ? 'Location Captured'
                      : 'Location Not Captured',
                  locationCaptured ? Colors.green : Colors.red,
                ),
                SizedBox(height: 12),
                _buildStatusRow(
                  context,
                  Icons.image,
                  'Media: $mediaCount item(s)',
                  mediaCount > 0 ? Colors.green : Colors.orange,
                ),
                SizedBox(height: 12),
                _buildStatusRow(
                  context,
                  Icons.search,
                  'Checking for similar issues...',
                  Colors.blue,
                  showProgress: true,
                ),
                SizedBox(height: 24),
                Text(
                  'You\'ll receive updates via push notifications.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    if (issueId != null && context.mounted) {
                      context.push('/issue/$issueId');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'View Report Status',
                    style: AppTextStyles.titleSmall,
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    widget.onReportSubmitted
                        ?.call(); // Call the callback to navigate to Feed page
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    'Return to Home',
                    style: AppTextStyles.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSubmissionSuccessWithAI(
    String? issueId,
    bool locationCaptured,
    int mediaCount,
    IssueCreationResult result,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.isHighPriority == true
                        ? Icons.priority_high
                        : Icons.check_circle_outline,
                    size: 80,
                    color: result.isHighPriority == true
                        ? Colors.orange
                        : Colors.green,
                  ),
                  SizedBox(height: 24),
                  Text(
                    result.isHighPriority == true
                        ? 'High Priority Issue!'
                        : 'Report Submitted!',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your report has been analyzed and routed automatically.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  SizedBox(height: 24),

                  // AI Analysis Results
                  if (result.aiAnalysis != null) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI Analysis',
                                style: AppTextStyles.titleSmall,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildAIResultRow(
                            'Category',
                            result.aiAnalysis!.detectedCategory,
                          ),
                          _buildAIResultRow(
                            'Severity',
                            result.aiAnalysis!.severityLevel,
                          ),
                          _buildAIResultRow(
                            'Confidence',
                            '${(result.aiAnalysis!.confidenceScore * 100).toInt()}%',
                          ),
                          _buildAIResultRow(
                            'Priority Score',
                            '${result.priorityScore}/100',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Routing Info
                  if (result.assignedDepartment != null) ...[
                    _buildStatusRow(
                      context,
                      Icons.business,
                      'Dept: ${result.assignedDepartment}',
                      Colors.blue,
                    ),
                    SizedBox(height: 8),
                  ],
                  if (result.assignedOfficeName != null) ...[
                    _buildStatusRow(
                      context,
                      Icons.location_city,
                      result.assignedOfficeName!,
                      Colors.green,
                    ),
                    SizedBox(height: 8),
                  ],

                  _buildStatusRow(
                    context,
                    Icons.location_on,
                    locationCaptured
                        ? 'Location Captured'
                        : 'Location Not Captured',
                    locationCaptured ? Colors.green : Colors.red,
                  ),
                  SizedBox(height: 8),
                  _buildStatusRow(
                    context,
                    Icons.image,
                    'Media: $mediaCount item(s)',
                    mediaCount > 0 ? Colors.green : Colors.orange,
                  ),

                  if (result.warning != null) ...[
                    SizedBox(height: 12),
                    Text(
                      result.warning!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ],

                  SizedBox(height: 24),
                  Text(
                    'You\'ll receive updates via push notifications.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (issueId != null && context.mounted) {
                        context.push('/issue/$issueId');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'View Report Status',
                      style: AppTextStyles.titleSmall,
                    ),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReportSubmitted?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                    child: Text(
                      'Return to Home',
                      style: AppTextStyles.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    IconData icon,
    String text,
    Color color, {
    bool showProgress = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        if (showProgress) ...[
          SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVerifiedUser) {
      return _buildVerificationRequiredScreen();
    }

    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          heroTag:
              'report_problem_nav_bar', // Unique hero tag to avoid conflicts
          largeTitle: const Text(
            'Report Problem',
            style: AppTextStyles.headlineMedium,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('📸 Capture Evidence', style: AppTextStyles.titleLarge),
              SizedBox(height: 24),
              // Display captured media
              if (_capturedMedia.isNotEmpty)
                Container(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedMedia.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_capturedMedia[index]),
                                fit: BoxFit.cover,
                                width: 100,
                                height: 150,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _capturedMedia.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _captureImage,
                      child: const Text(
                        '📷 Camera',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickImagesFromGallery,
                      child: const Text(
                        '📁 Gallery',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text('📍 Issue Location', style: AppTextStyles.titleLarge),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingLocation)
                        Center(child: CircularProgressIndicator())
                      else if (_currentPosition != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Location:',
                              style: AppTextStyles.titleSmall,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            Text(
                              'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            Text(
                              'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        )
                      else
                        Text(
                          'Location not available. Please enable GPS.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoadingLocation
                              ? null
                              : _getCurrentLocation,
                          child: Text(
                            'Refresh Location',
                            style: AppTextStyles.button,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text('Category', style: AppTextStyles.titleLarge),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  labelStyle: AppTextStyles.bodyMedium, // Added style
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue ?? '';
                  });
                },
              ),
              SizedBox(height: 24),
              Text('📝 Description', style: AppTextStyles.titleLarge),
              SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _description),
                onChanged: (value) {
                  _description = value;
                },
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail...',
                  hintStyle: AppTextStyles.bodyMedium, // Added style
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: _isListening
                          ? Colors.red
                          : Theme.of(context).iconTheme.color,
                    ),
                    onPressed: _speechEnabled
                        ? () {
                            _isListening ? _stopListening() : _startListening();
                          }
                        : null,
                  ),
                ),
                style: AppTextStyles.bodyMedium, // Added style
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : _submitReport, // Disable button when submitting
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          // Added const
                          '📤 Submit Report',
                          style: AppTextStyles.button, // Changed style
                        ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationRequiredScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Theme.of(context).primaryColor),
            SizedBox(height: 24),
            Text(
              'You Can\'t Raise New Issue You Are Not Verified',
              style: AppTextStyles.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'You Can\'t Raise New Issue , First Gets Verified',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
            SizedBox(height: 24),
            Text(
              'Why verify?\n'
              '✅ Prevent fake reports\n'
              '✅ Build trusted community\n'
              '✅ Unlock full features\n'
              '✅ Earn recognition badges',
              textAlign: TextAlign.left,
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: const Text(
                // Added const
                'Verify with Aadhaar',
                style: AppTextStyles.button, // Changed style
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: const Text(
                // Added const
                'Verify with Voter ID',
                style: AppTextStyles.button, // Changed style
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: const Text(
                // Added const
                'Verify with Driving License',
                style: AppTextStyles.button, // Changed style
              ),
            ),
          ],
        ),
      ),
    );
  }
}
