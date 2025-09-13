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
    
    return GestureDetector(
      onTap: () {
        context.go('/issue/$issueId');
      },
      child: Card(
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
  // Form data
  List<String> _capturedMedia = [];
  String _selectedCategory = '';
  String _description = '';
  String _location = ''; // This will be updated with the actual address
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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Automatically capture location on page load
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
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
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _location = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}'; // Update location string
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
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to capture images')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
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
            SnackBar(content: Text('${images.length} images selected from gallery')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting images: $e')),
        );
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
      
      final fileName = 'issues/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await supabase.storage
          .from('media')
          .upload(fileName, File(compressedImage.path));
      
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
  
  Future<void> _submitReport() async {
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
      
      await supabase.rpc('create_civic_issue', params: {
        'user_id': user.id,
        'category': _selectedCategory,
        'description': _description,
        'lat': _currentPosition!.latitude,
        'lng': _currentPosition!.longitude,
        'address': _location, // Use the updated location string
        'media_urls': uploadedMediaUrls,
        'voice_note_url': null, // Not implemented yet
      });
      
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
        _showSubmissionSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    if (!_isVerifiedUser) {
      return _buildVerificationRequiredScreen();
    }

    return SingleChildScrollView(
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
                              child: Icon(Icons.close, color: Colors.white, size: 16),
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
                  child: Text('📷 Camera'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickImagesFromGallery,
                  child: Text('📁 Gallery'),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            '📍 Issue Location',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLocation)
                    Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (_currentPosition != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Location:',
                          style: TextStyle(
                            fontFamily: 'SFProRounded Medium',
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                          style: TextStyle(fontFamily: 'SFProRounded Regular'),
                        ),
                        Text(
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(fontFamily: 'SFProRounded Regular'),
                        ),
                        Text(
                          'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                          style: TextStyle(fontFamily: 'SFProRounded Regular'),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Location not available. Please enable GPS.',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      child: Text('Refresh Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Category',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
            decoration: InputDecoration(
              labelText: 'Select Category',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue ?? '';
              });
            },
          ),
          SizedBox(height: 24),
          Text(
            '📝 Description',
            style: TextStyle(
              fontFamily: 'SFProRounded Medium',
              fontSize: 20,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe the problem in detail...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _description = value;
              });
            },
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
              '🎤 Add Voice Note (Optional)',
              style: TextStyle(
                fontFamily: 'SFProRounded Regular',
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '📤 Submit Report',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
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