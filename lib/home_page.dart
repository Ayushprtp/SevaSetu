import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jansahayak/main.dart'; // Import main.dart to access themeNotifier
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const FeedPage(),
    const ReportProblemPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JanSahayak',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value =
                  Theme.of(context).brightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.feed, size: 35),
          Icon(Icons.add, size: 35),
          Icon(Icons.settings, size: 35),
        ],
        color: Theme.of(context).colorScheme.primary,
        buttonBackgroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  List<dynamic> _issues = [];
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFetchIssues();
  }
  
  Future<void> _getCurrentLocationAndFetchIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them in your device settings.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final status = await Permission.location.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required to show nearby issues')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in your device settings.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });
      
      // Fetch issues from database
      await _fetchIssues(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }
  
  Future<void> _fetchIssues(double lat, double lng) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Call the database function to get issues within radius
      final response = await supabase.rpc('get_issues_within_radius', params: {
        'user_lat': lat,
        'user_lng': lng,
        'radius_km': 15, // 15 km radius
      });
      
      setState(() {
        _issues = response as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching issues: $e')),
        );
      }
    }
  }
  
  Future<void> _fetchClusteredIssues() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch issue clusters
      final clusterResponse = await supabase
          .from('issue_clusters')
          .select('id, primary_issue_id, cluster_radius');
      
      // Fetch cluster members
      final memberResponse = await supabase
          .from('cluster_members')
          .select('cluster_id, issue_id');
      
      // Process clusters and members to group issues
      // This is a simplified implementation - in a real app, you'd do more complex clustering
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clustered issues fetched')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching clustered issues: $e')),
        );
      }
    }
  }
  
  Future<void> _upvoteIssue(String issueId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Call the database function to upvote the issue
      final response = await supabase.rpc('upvote_issue', params: {
        'user_id': user.id,
        'issue_id': issueId,
      });
      
      // Refresh the issues list
      if (_currentPosition != null) {
        await _fetchIssues(_currentPosition!.latitude, _currentPosition!.longitude);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue upvoted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error upvoting issue: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Good Morning, Ayush!',
                          style: TextStyle(
                            fontFamily: 'SFProRounded Medium',
                            fontSize: 18,
                          ),
                        ),
                        Icon(Icons.verified, color: Colors.green),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✅ Verified',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatItem('Points', '156'),
                        SizedBox(width: 16),
                        _buildStatItem('Badges', '5'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            // Priority issues section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔥 Priority Issues',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Medium',
                    fontSize: 18,
                  ),
                ),
                if (_currentPosition != null)
                  Text(
                    '${_issues.length} issues nearby',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              )
            else if (_issues.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.info,
                      size: 64,
                      color: Theme.of(context).hintColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No issues found in your area',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Be the first to report an issue!',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _issues.map((issue) {
                  return _buildIssueCardFromData(issue);
                }).toList(),
              ),
            SizedBox(height: 24),
            // Report button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to report problem page
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '📸 Report New Issue',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Medium',
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            // Recent activity section
            Text(
              'Recent Activity (2)',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'My Reports',
                            style: TextStyle(
                              fontFamily: 'SFProRounded Medium',
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3',
                            style: TextStyle(
                              fontFamily: 'SFProRounded Regular',
                              fontSize: 24,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Community',
                            style: TextStyle(
                              fontFamily: 'SFProRounded Medium',
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '12',
                            style: TextStyle(
                              fontFamily: 'SFProRounded Regular',
                              fontSize: 24,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIssueCardFromData(dynamic issue) {
    final issueId = issue['id'] as String? ?? '';
    final category = issue['category'] as String? ?? 'Unknown';
    final address = issue['address'] as String? ?? 'Unknown location';
    final upvotes = issue['upvotes'] as int? ?? 0;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final distanceKm = issue['distance_km'] as double? ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIssueIcon(category),
                  size: 24,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$category - $address',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Medium',
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Priority: $priorityScore • ${distanceKm.toStringAsFixed(1)}km away',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Regular',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$upvotes upvotes',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 14,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _upvoteIssue(issueId),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Upvote',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SFProRounded Regular',
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildIssueCard(BuildContext context, String issue, String location, int upvotes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _getIssueIcon(issue),
              size: 24,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$issue - $location',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Medium',
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$upvotes↑',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _getIssueIcon(String issue) {
    switch (issue.toLowerCase()) {
      case 'power cut':
        return Icons.flash_on;
      case 'water leak':
        return Icons.water_drop;
      case 'pothole':
        return Icons.circle;
      default:
        return Icons.report;
    }
  }
}

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Form data
  List<String> _capturedMedia = [];
  String _selectedCategory = '';
  String _description = '';
  String _location = '';
  bool _isVerifiedUser = true; // This should come from user profile in real implementation
  
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
    'Other'
  ];

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }
  
  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denied
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to get your current location')),
        );
      }
    }
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them in your device settings.')),
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
      
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await _checkLocationPermission();
        return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in your device settings.')),
          );
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }
  
  Future<void> _captureImage() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to capture images')),
          );
        }
        return;
      }
      
      // Capture image
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _capturedMedia.add(image.path);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image selected from gallery')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }
  
  Future<String?> _compressAndUploadImage(String imagePath) async {
    try {
      // Create a temporary file for the compressed image
      final compressedFile = File('${imagePath}_compressed.jpg');
      
      // Compress the image
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        compressedFile.path,
        quality: 80, // Adjust quality as needed
        minWidth: 1024, // Adjust dimensions as needed
        minHeight: 1024,
      );
      
      if (compressedImage == null) {
        throw Exception('Failed to compress image');
      }
      
      // Get Supabase client
      final supabase = Supabase.instance.client;
      
      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Generate a unique file name
      final fileName = 'issues/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase storage
      final response = await supabase.storage
          .from('media')
          .upload(fileName, File(compressedImage.path));
      
      // Get the public URL of the uploaded file
      final publicUrl = supabase.storage
          .from('media')
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }
  
  Future<void> _submitReport(List<String> mediaUrls) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Validate required fields
      if (_selectedCategory.isEmpty) {
        throw Exception('Please select a category');
      }
      
      if (_description.isEmpty) {
        throw Exception('Please provide a description');
      }
      
      if (_currentPosition == null) {
        throw Exception('Please provide a location');
      }
      
      // Call the database function to create a new issue
      final response = await supabase.rpc('create_civic_issue', params: {
        'user_id': user.id,
        'category': _selectedCategory,
        'description': _description,
        'lat': _currentPosition!.latitude,
        'lng': _currentPosition!.longitude,
        'address': 'Current Location', // In a real app, you'd get the actual address
        'media_urls': mediaUrls,
        'voice_note_url': null, // Not implemented yet
      });
      
      // Reset form
      setState(() {
        _currentStep = 0;
        _capturedMedia.clear();
        _selectedCategory = '';
        _description = '';
        _currentPosition = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is verified
    if (!_isVerifiedUser) {
      return _buildVerificationRequiredScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report New Issue',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              // Navigate back to home
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1: Media Capture
                _buildMediaCaptureStep(),
                // Step 2: AI Category Detection
                _buildAICategoryDetectionStep(),
                // Step 3: Description Input
                _buildDescriptionStep(),
                // Step 4: Location Confirmation
                _buildLocationStep(),
                // Step 5: Review & Submit
                _buildReviewStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
              decoration: BoxDecoration(
                color: _currentStep >= index
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVerificationRequiredScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              'Verification Required',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 24,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'To report civic issues, please complete identity verification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Why verify?\n'
              '✅ Prevent fake reports\n'
              '✅ Build trusted community\n'
              '✅ Unlock full features\n'
              '✅ Earn recognition badges',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 14,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement verification flow
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Verify with Aadhaar',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // TODO: Implement verification flow
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Verify with Voter ID',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // TODO: Implement verification flow
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification flow not implemented yet'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Verify with Driving License',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCaptureStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📸 Capture Evidence',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'Live Camera Feed',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _captureImage,
                      child: Text('📷 Capture'),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        // TODO: Implement video recording
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Video recording not implemented')),
                        );
                      },
                      child: Text('🎥 Video'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Center(
            child: Text(
              'OR',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 24),
          OutlinedButton(
            onPressed: _pickImageFromGallery,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              '📁 Choose from Gallery',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Implement voice description
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Voice description not implemented')),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              '🎵 Voice Description (Optional)',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '💡 Tip: Include multiple angles for better AI detection',
            style: TextStyle(
              fontFamily: 'SFProRounded Regular',
              fontSize: 14,
              color: Theme.of(context).hintColor,
            ),
          ),
          Spacer(),
          if (_capturedMedia.isNotEmpty)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Next →',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAICategoryDetectionStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCategory.isEmpty) ...[
            Text(
              '🤖 JanSahayak AI Analyzing...',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            SizedBox(height: 24),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '🧠 Processing your image...',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '████████░░ 80%',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            // Simulate AI detection completion
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'POTHOLE';
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Simulate AI Detection Complete',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
            ),
          ] else ...[
            Text(
              '✅ AI Detection Complete',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '🎯 Detected: $_selectedCategory',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '📊 Confidence: 95%',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Select Category:',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return Card(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : Theme.of(context).cardColor,
                    child: ListTile(
                      title: Text(
                        category,
                        style: TextStyle(
                          fontFamily: 'SFProRounded Regular',
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Text(
              '💡 AI got it right? Continue!\n'
              '🔧 Wrong? Tap correct category',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 14,
                color: Theme.of(context).hintColor,
              ),
            ),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    child: Text(
                      '← Back',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    child: Text(
                      'Continue →',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 Describe the problem:',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '$_selectedCategory Issue',
            style: TextStyle(
              fontFamily: 'SFProRounded Regular',
              fontSize: 18,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: TextField(
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Describe the problem in detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              onChanged: (value) {
                setState(() {
                  _description = value;
                });
              },
            ),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_description.length}/300',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'OR',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Implement voice description
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Voice description not implemented')),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              '🎤 Voice Description',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                '🌍 Language:',
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 8),
              DropdownButton<String>(
                value: 'English',
                items: ['English', 'Hindi', 'Bengali', 'Marathi', 'Tamil']
                    .map((String language) => DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  // TODO: Implement language change
                },
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text(
                    '← Back',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextStep,
                  child: Text(
                    'Continue →',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📍 Issue Location',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Interactive Map View',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_currentPosition != null) ...[
                    Text(
                      '📍 You are here',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                      'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '📍 Location not set',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 14,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          // TODO: Implement zoom in
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          // TODO: Implement zoom out
                        },
                      ),
                      SizedBox(width: 16),
                      Text(
                        _currentPosition != null
                          ? '📡 GPS: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m'
                          : '📡 GPS: Not available',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Regular',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            '📮 Address:',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _currentPosition != null
              ? 'Current Location\n'
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
              : 'MG Road, near City Hospital\n'
                'Battigul, Ranchi, Jharkhand',
            style: TextStyle(
              fontFamily: 'SFProRounded Regular',
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
            child: _isLoadingLocation
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Getting Location...',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Regular',
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Text(
                  '🎯 Use Current Location',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 16,
                  ),
                ),
          ),
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Implement location search
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Search location not implemented')),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              '🗺️ Search Different Location',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            _currentPosition != null
              ? '✅ GPS Accuracy: ${_currentPosition!.accuracy < 10 ? "High" : "Medium"} (±${_currentPosition!.accuracy.toStringAsFixed(1)} meters)'
              : '⚠️ GPS Accuracy: Not available',
            style: TextStyle(
              fontFamily: 'SFProRounded Regular',
              fontSize: 14,
              color: _currentPosition != null && _currentPosition!.accuracy < 10
                ? Colors.green
                : _currentPosition != null
                  ? Colors.orange
                  : Colors.red,
            ),
          ),
          Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text(
                    '← Back',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentPosition != null ? _nextStep : null,
                  child: Text(
                    'Continue →',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👀 Please Review Your Report',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 24, color: Theme.of(context).primaryColor),
                      SizedBox(width: 8),
                      Text(
                        '$_selectedCategory ISSUE',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Medium',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: _capturedMedia.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_capturedMedia.first),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Center(
                          child: Text(
                            '📸 No image captured',
                            style: TextStyle(
                              fontFamily: 'SFProRounded Regular',
                            ),
                          ),
                        ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _description.isEmpty ? '"Add a description..."' : '"$_description"',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _currentPosition != null
                      ? '📍 Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                        'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}\n'
                        '   Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m'
                      : '📍 MG Road, near City Hospital\n'
                        '   Ranchi, Jharkhand',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⏰ Reported: Dec 13, 2025 13:45',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '👤 Reporter: Ayush Kumar',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  // TODO: Edit category
                  setState(() {
                    _currentStep = 1;
                  });
                },
                child: Text('✏️ Edit Category'),
              ),
              OutlinedButton(
                onPressed: () {
                  // TODO: Change photo
                  setState(() {
                    _currentStep = 0;
                  });
                },
                child: Text('🖼️ Change Photo'),
              ),
              OutlinedButton(
                onPressed: () {
                  // TODO: Edit description
                  setState(() {
                    _currentStep = 2;
                  });
                },
                child: Text('📝 Edit Description'),
              ),
              OutlinedButton(
                onPressed: () {
                  // TODO: Edit location
                  setState(() {
                    _currentStep = 3;
                  });
                },
                child: Text('📍 Edit Location'),
              ),
            ],
          ),
          Spacer(),
          CheckboxListTile(
            title: Text(
              'I confirm this is accurate',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
              ),
            ),
            value: true, // TODO: Implement actual checkbox state
            onChanged: (bool? value) {},
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            title: Text(
              'I agree to terms of service',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
              ),
            ),
            value: true, // TODO: Implement actual checkbox state
            onChanged: (bool? value) {},
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text(
                    '← Back',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Upload media and submit report
                    final uploadedMediaUrls = await _uploadAllMedia();
                    await _submitReport(uploadedMediaUrls);
                    _showSubmissionSuccess();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    '📤 Submit Report',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
  
  void _showSubmissionSuccess() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              Text(
                '✅ Report Submitted!',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '🎉 Success! 🎉\n\n'
                'Your report has been received\n'
                'and is being processed...\n\n'
                '📍 Location: ${_currentPosition != null ? "Captured" : "Not captured"}\n'
                '📸 Media: ${_capturedMedia.length} item(s)\n'
                '🤖 Checking for similar issues...\n'
                '████████░░ Processing...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),
              Text(
                '📧 You\'ll receive updates via\n'
                '   push notifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate back to home
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  '📊 View Report Status',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate back to home
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  '🏠 Return to Home',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Text(
                'Profile',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    'Ayush Kumar',
                    style: TextStyle(fontFamily: 'SFProRounded Medium'),
                  ),
                  subtitle: Text(
                    'ayush.kumar@example.com',
                    style: TextStyle(fontFamily: 'SFProRounded Regular'),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
              ),
              SizedBox(height: 24),
              
              // Preferences Section
              Text(
                'Preferences',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Language',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      subtitle: Text(
                        'English',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement language selection
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Language selection not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Dark Mode',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Switch(
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (value) {
                          themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Notifications',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Switch(
                        value: true, // TODO: Implement actual notification setting
                        onChanged: (value) {
                          // TODO: Implement notification setting
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notification settings not implemented')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Account Section
              Text(
                'Account',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Privacy Policy',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement privacy policy
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Privacy policy not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Terms of Service',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement terms of service
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Terms of service not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Help & Support',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement help & support
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Help & support not implemented')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Danger Zone
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      color: Colors.red,
                    ),
                  ),
                  trailing: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onTap: () {
                    // TODO: Implement account deletion
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Account deletion not implemented')),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              
              // App Version
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}