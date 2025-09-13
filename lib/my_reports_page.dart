import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jansahayak/main.dart'; // Import main.dart to access themeNotifier

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _isLoading = true;
  List<dynamic> _issues = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserIssues();
  }

  String _getUserFirstName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Extract first name from email if no user data is available
      final email = user.email ?? '';
      final name = email.split('@').first;
      return name.isNotEmpty ? name : 'User';
    }
    return 'User';
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them in your device settings.')),
          );
        }
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final status = await Geolocator.requestPermission();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required to calculate distances')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in your device settings.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _fetchUserIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch user's issues
      final response = await supabase
          .from('civic_issues')
          .select('''
            id,
            category,
            description,
            location,
            address,
            status,
            priority_score,
            created_at,
            upvotes
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _issues = response as List<dynamic>;
        _isLoading = false;
      });

      // Get current location for distance calculations
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching your reports: $e')),
        );
      }
    }
  }

  String _getPriorityLabel(int priorityScore) {
    if (priorityScore < 50) {
      return 'Low';
    } else if (priorityScore < 100) {
      return 'Medium';
    } else if (priorityScore < 300) {
      return 'High';
    } else {
      return 'Very High';
    }
  }

  IconData _getIssueIcon(String category) {
    switch (category.toLowerCase()) {
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

  double _calculateDistance(dynamic issue) {
    if (_currentPosition == null) return 0.0;

    // Parse the location string (POINT(lng lat))
    final locationStr = issue['location'] as String?;
    if (locationStr == null) return 0.0;

    // Extract coordinates using regex
    final regExp = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)');
    final match = regExp.firstMatch(locationStr);
    if (match == null) return 0.0;

    final issueLng = double.parse(match.group(1)!);
    final issueLat = double.parse(match.group(2)!);

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      issueLat,
      issueLng,
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  Widget _buildIssueCard(dynamic issue) {
    final issueId = issue['id'] as String? ?? '';
    final issueNumber = issueId.substring(0, 8); // First 8 digits of UUID as issue number
    final category = issue['category'] as String? ?? 'Unknown';
    final address = issue['address'] as String? ?? 'Unknown location';
    final upvotes = issue['upvotes'] as int? ?? 0;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final priorityLabel = _getPriorityLabel(priorityScore);
    final distance = _calculateDistance(issue);
    final formattedDistance = _formatDistance(distance);

    return GestureDetector(
      onTap: () {
        context.push('/issue/$issueId');
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
                          'Issue #$issueNumber - $category',
                          style: TextStyle(
                            fontFamily: 'SFProRounded Medium',
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$address',
                          style: TextStyle(
                            fontFamily: 'SFProRounded Regular',
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Priority: $priorityLabel • $formattedDistance away',
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
                  Text(
                    'Status: ${issue['status'] ?? 'Reported'}',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Reports',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
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
                      Text(
                        'Hello, ${_getUserFirstName()}!',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Medium',
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Here are all the issues you\'ve reported',
                        style: TextStyle(
                          fontFamily: 'SFProRounded Regular',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Issues list
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
                        'No reports found',
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
                  children: [
                    Text(
                      'Your Reports (${_issues.length})',
                      style: TextStyle(
                        fontFamily: 'SFProRounded Medium',
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 16),
                    Column(
                      children: _issues.map((issue) => _buildIssueCard(issue)).toList(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}