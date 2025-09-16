import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier
import 'package:sevasetu/utils/app_styles.dart';
import 'package:flutter/cupertino.dart'; // Added for CupertinoSlidingSegmentedControl
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart'; // Added for awesome_snackbar_content

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _isLoading = true;
  List<dynamic> _issues = [];
  Position? _currentPosition;
  String? _currentUserId; // To store the current user's ID
  Set<String> _upvotedIssueIds = {}; // To store IDs of issues upvoted by the current user

  // Filter and Sort state variables
  List<String> _selectedCategories = ['All']; // List of selected categories
  bool _sortNewestFirst = true; // true for newest first, false for oldest first
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilterType = 'All Time'; // 'All Time', 'Last Week', 'Last Month', 'Custom Range'
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'Potholes',
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
    _currentUserId = Supabase.instance.client.auth.currentUser?.id; // Get current user ID
    _fetchUserIssues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        desiredAccuracy: LocationAccuracy.medium,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              content: AwesomeSnackbarContent(
                title: 'Error',
                message: 'User not authenticated. Please log in.',
                contentType: ContentType.failure,
              ),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch upvoted issues for the current user
      final upvotesResponse = await supabase
          .from('issue_upvotes')
          .select('issue_id')
          .eq('user_id', user.id);

      _upvotedIssueIds = (upvotesResponse as List<dynamic>)
          .map((e) => e['issue_id'] as String)
          .toSet();

      // Fetch user's issues
      var queryBuilder = supabase
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
            upvotes,
            media_files
          ''')
          .eq('user_id', user.id);

      // Apply category filter
      if (!_selectedCategories.contains('All') && _selectedCategories.isNotEmpty) {
        queryBuilder = queryBuilder.filter('category', 'in', _selectedCategories);
      }

      // Apply date filter
      if (_startDate != null && _endDate != null) {
        queryBuilder = queryBuilder.gte('created_at', _startDate!.toIso8601String());
        queryBuilder = queryBuilder.lte('created_at', _endDate!.toIso8601String());
      }

      // Apply search filter by issue ID (first 8 digits of UUID)
      if (_searchController.text.isNotEmpty) {
        final searchQuery = _searchController.text.toLowerCase();
        queryBuilder = queryBuilder.ilike('id', '$searchQuery%'); // Search by partial UUID
      }

      // Apply sorting
      final response = await queryBuilder.order('created_at', ascending: !_sortNewestFirst);

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
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Error fetching your reports: $e',
              contentType: ContentType.failure,
            ),
          ),
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
    final mediaFiles = issue['media_files'] as List<dynamic>?;
    final mediaCount = mediaFiles?.length ?? 0;

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
                          style: AppTextStyles.bodyLarge,
                        ),
                        SizedBox(height: 4),
                        Text(
                          address,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Priority: $priorityLabel • $formattedDistance away',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
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
                    style: AppTextStyles.bodySmall,
                  ),
                  Row(
                    children: [
                      Icon(Icons.image, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$mediaCount media',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Status: ${issue['status'] ?? 'Reported'}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      if (_currentUserId != null && issue['user_id'] != _currentUserId)
                        ElevatedButton(
                          onPressed: _upvotedIssueIds.contains(issueId) ? null : () => _upvoteIssue(issueId),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            backgroundColor: _upvotedIssueIds.contains(issueId) ? Colors.grey : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _upvotedIssueIds.contains(issueId) ? 'Upvoted' : 'Upvote',
                            style: AppTextStyles.bodySmall,
                          ),
                        )
                      else if (_currentUserId != null && issue['user_id'] == _currentUserId)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Your Issue',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.blueGrey[700]),
                          ),
                        ),
                    ],
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
        title: const Text(
          'My Reports',
          style: AppTextStyles.titleMedium,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showFilterOptions(context),
            child: const Icon(CupertinoIcons.line_horizontal_3_decrease),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showSortOptions(context),
            child: const Icon(CupertinoIcons.sort_down),
          ),
        ],
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
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Here are all the issues you\'ve reported',
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Issue ID',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor,
                ),
                onChanged: (value) {
                  _fetchUserIssues();
                },
              ),
              const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      const Text(
                        'No reports found',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to report an issue!',
                        style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Reports (${_issues.length})',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 16),
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

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Issues',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text('Filter by Category:'),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategories.contains('All'),
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedCategories = ['All'];
                            } else {
                              _selectedCategories.remove('All');
                            }
                          });
                        },
                      ),
                      ..._categories.map((category) => FilterChip(
                        label: Text(category),
                        selected: _selectedCategories.contains(category),
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedCategories.remove('All');
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        },
                      )).toList(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Filter by Date:'),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: const Text('All Time'),
                        selected: _dateFilterType == 'All Time',
                        onSelected: (bool selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'All Time' : '';
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Last Week'),
                        selected: _dateFilterType == 'Last Week',
                        onSelected: (bool selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Week' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(const Duration(days: 7));
                            } else {
                              _startDate = null;
                              _endDate = null;
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Last Month'),
                        selected: _dateFilterType == 'Last Month',
                        onSelected: (bool selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Month' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(const Duration(days: 30));
                            } else {
                              _startDate = null;
                              _endDate = null;
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Custom Range'),
                        selected: _dateFilterType == 'Custom Range',
                        onSelected: (bool selected) async {
                          if (selected) {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: DateTimeRange(
                                start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
                                end: _endDate ?? DateTime.now(),
                              ),
                            );
                            if (picked != null) {
                              setModalState(() {
                                _dateFilterType = 'Custom Range';
                                _startDate = picked.start;
                                _endDate = picked.end;
                              });
                            }
                          } else {
                            setModalState(() {
                              _dateFilterType = '';
                              _startDate = null;
                              _endDate = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        _fetchUserIssues();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort Issues',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<bool>(
                    title: const Text('Newest First'),
                    value: true,
                    groupValue: _sortNewestFirst,
                    onChanged: (bool? value) {
                      setModalState(() {
                        _sortNewestFirst = value!;
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('Oldest First'),
                    value: false,
                    groupValue: _sortNewestFirst,
                    onChanged: (bool? value) {
                      setModalState(() {
                        _sortNewestFirst = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        _fetchUserIssues();
                      },
                      child: const Text('Apply Sort'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _upvoteIssue(String issueId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              content: AwesomeSnackbarContent(
                title: 'Error',
                message: 'You need to be logged in to upvote an issue.',
                contentType: ContentType.failure,
              ),
            ),
          );
        }
        return;
      }

      await supabase.rpc('upvote_issue', params: {
        'p_user_id': user.id,
        'p_issue_id': issueId,
      });

      // Refresh the issues list to reflect the new upvote count and status
      await _fetchUserIssues();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Success',
              message: 'Issue upvoted successfully!',
              contentType: ContentType.success,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Error upvoting issue: $e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }
}