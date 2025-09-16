import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier
import 'package:sevasetu/utils/app_styles.dart'; // Added import

class FeedPage extends StatefulWidget {
  final VoidCallback onReportPressed;
  const FeedPage({super.key, required this.onReportPressed});
  
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  List<dynamic> _issues = [];
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
  Map<String, dynamic>? _userData;
  bool _showPrioritized = false; // false for Recents, true for Prioritized
  String? _currentUserId; // To store the current user's ID
  Set<String> _upvotedIssueIds = {}; // To store IDs of issues upvoted by the current user

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadUserData();
    _getCurrentLocationAndFetchIssues();
  }
  
  Future<void> _loadUserData() async {
    final userData = await _getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
      });
    }
  }
  
  String _getUserFullName() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] as String?;
      final lastName = _userData!['last_name'] as String?;
      if (firstName != null && firstName.isNotEmpty) {
        return '$firstName ${lastName ?? ''}'.trim();
      }
    }
    return 'User';
  }

  String _getUserUsername() {
    if (_userData != null) {
      final username = _userData!['username'] as String?;
      if (username != null && username.isNotEmpty) {
        return '@$username';
      }
    }
    return '';
  }

  String _getGreeting() {
    // Get current time in IST (UTC+5:30)
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night'; // Or 'Good Evening' if preferred for late night
    }
  }
  
  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return null;
      
      final response = await supabase
          .from('users')
          .select('first_name, last_name, username, id_value')
          .eq('id', user.id)
          .single();
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      // If we can't fetch user data, return null
      return null;
    }
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
        desiredAccuracy: LocationAccuracy.medium, // Changed to medium for faster initial load
      );
      
      setState(() {
        _currentPosition = position;
      });
      
      // Fetch issues from database
      await _fetchIssues(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
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
        'radius_km': 10, // 10 km radius
      });
      
      List<dynamic> filteredIssues = response as List<dynamic>;

      // Deduplicate issues based on their 'id'
      final uniqueIssues = <String, dynamic>{};
      for (var issue in filteredIssues) {
        uniqueIssues[issue['id'] as String] = issue;
      }
      filteredIssues = uniqueIssues.values.toList();
      
      // Fetch user information for each issue
      for (int i = 0; i < filteredIssues.length; i++) {
        final issue = filteredIssues[i];
        final userId = issue['user_id'] as String?;
        
        if (userId != null) {
          try {
            // Try to get user data
            final userResponse = await supabase
                .from('users')
                .select('first_name, last_name')
                .eq('id', userId)
                .single();
            
            // Add user data to the issue
            filteredIssues[i] = Map<String, dynamic>.from(issue)
              ..['reporter_first_name'] = userResponse['first_name'] as String? ?? 'Anonymous'
              ..['reporter_last_name'] = userResponse['last_name'] as String? ?? '';
          } catch (userFetchError) {
            // If we can't fetch user data, set default values
            filteredIssues[i] = Map<String, dynamic>.from(issue)
              ..['reporter_first_name'] = 'Anonymous'
              ..['reporter_last_name'] = '';
          }
        } else {
          // If no user_id, set default values
          filteredIssues[i] = Map<String, dynamic>.from(issue)
            ..['reporter_first_name'] = 'Anonymous'
            ..['reporter_last_name'] = '';
        }
      }
      
      // Apply category filter
      if (!_selectedCategories.contains('All') && _selectedCategories.isNotEmpty) {
        filteredIssues = filteredIssues.where((issue) => _selectedCategories.contains(issue['category'])).toList();
      }
      
      // Apply date filter
      if (_startDate != null && _endDate != null) {
        filteredIssues = filteredIssues.where((issue) {
          final issueDate = DateTime.parse(issue['created_at'] ?? '1970-01-01T00:00:00Z');
          return issueDate.isAfter(_startDate!) && issueDate.isBefore(_endDate!);
        }).toList();
      }

      // Apply search filter by issue ID (first 8 digits of UUID)
      if (_searchController.text.isNotEmpty) {
        final searchQuery = _searchController.text.toLowerCase();
        filteredIssues = filteredIssues.where((issue) {
          final issueId = issue['id'] as String? ?? '';
          return issueId.toLowerCase().startsWith(searchQuery);
        }).toList();
      }
      
      // Apply sorting and filtering based on selected view
      if (_showPrioritized) {
        // Filter for issues with more than 1 upvote for "Prioritized" view
        filteredIssues = filteredIssues.where((issue) {
          final upvotes = issue['upvotes'] as int? ?? 0;
          return upvotes > 1;
        }).toList();
        // Sort by upvotes for "Prioritized" view (descending)
        filteredIssues.sort((a, b) {
          final upvotesA = a['upvotes'] as int? ?? 0;
          final upvotesB = b['upvotes'] as int? ?? 0;
          return upvotesB.compareTo(upvotesA);
        });
      } else {
        // Sort by date for "Recents" view (newest first)
        filteredIssues.sort((a, b) {
          final dateA = DateTime.parse(a['created_at'] ?? '1970-01-01T00:00:00Z');
          final dateB = DateTime.parse(b['created_at'] ?? '1970-01-01T00:00:00Z');
          return dateB.compareTo(dateA); // Newest first
        });
      }
      
      // Fetch upvotes for the current user
      _upvotedIssueIds.clear();
      if (_currentUserId != null) {
        final upvotesResponse = await supabase
            .from('issue_upvotes')
            .select('issue_id')
            .eq('user_id', _currentUserId!);

        if (upvotesResponse != null) {
          for (var upvote in upvotesResponse) {
            _upvotedIssueIds.add(upvote['issue_id'] as String);
          }
        }
      }

      setState(() {
        _issues = filteredIssues;
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
        'p_user_id': user.id,
        'p_issue_id': issueId,
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
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          alwaysShowMiddle: true,

          largeTitle: Text(
            'Feed',
            style: AppTextStyles.headlineLarge,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showFilterOptions(context),
                child: Icon(CupertinoIcons.line_horizontal_3_decrease),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showSortOptions(context),
                child: Icon(CupertinoIcons.sort_down),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // User greeting section
                Card(
                  margin: EdgeInsets.zero, // Remove default card margin
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                          _getGreeting(),
                          style: AppTextStyles.titleMedium,
                        ),
                        SizedBox(width: 8,),
                            Text(
                               _getUserFullName(),
                              style: AppTextStyles.titleLarge,
                            ),
                            const SizedBox(width: 8),
                            Spacer(),
                            if (_userData != null && (_userData!['id_value'] as String? ?? '').isNotEmpty)
                              const Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: 20,
                              )
                            else
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 20,
                              ),
                          ],
                        ),
                        if (_getUserUsername().isNotEmpty)
                          Text(
                            _getUserUsername(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatItem('Points', '60'),
                            const SizedBox(width: 16),
                            _buildStatItem('Badges', '1'),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // Segmented control for Recents and Prioritized
                CupertinoSlidingSegmentedControl<bool>(
                  groupValue: _showPrioritized,
                  backgroundColor: CupertinoColors.systemGrey3,
                  thumbColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.all(8),
                  children: <bool, Widget>{
                    false: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Recents',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: !_showPrioritized ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    true: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Prioritized',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _showPrioritized ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (bool? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _showPrioritized = newValue;
                        if (_currentPosition != null) {
                          _fetchIssues(_currentPosition!.latitude, _currentPosition!.longitude);
                        }
                      });
                    }
                  },
                ),
                SizedBox(height: 24),
                // Priority issues section (or Recents)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _showPrioritized ? '🔥 Priority Issues' : '🕒 Recent Issues',
                      style: AppTextStyles.titleMedium,
                    ),
                    if (_currentPosition != null)
                      Text(
                        '${_issues.length} issues nearby',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Issue ID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor,
                  ),
                  onChanged: (value) {
                    if (_currentPosition != null) {
                      _fetchIssues(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  },
                ),
                const SizedBox(height: 16),
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
                  ..._issues.map((issue) {
                    return _buildIssueCardFromData(issue);
                  }).toList(),
                SizedBox(height: 24),
                // Report button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onReportPressed,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '📸 Report New Issue',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                    style: AppTextStyles.titleLarge,
                  ),
                  SizedBox(height: 16),
                  Text('Filter by Category:', style: AppTextStyles.bodyLarge,),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: Text('All', style: AppTextStyles.bodyMedium,),
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
                        label: Text(category, style: AppTextStyles.bodyMedium,),
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
                  SizedBox(height: 16),
                  Text('Filter by Date:', style: AppTextStyles.bodyLarge,),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: Text('All Time', style: AppTextStyles.bodyMedium,),
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
                        label: Text('Last Week', style: AppTextStyles.bodyMedium,),
                        selected: _dateFilterType == 'Last Week',
                        onSelected: (bool selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Week' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(Duration(days: 7));
                            } else {
                              _startDate = null;
                              _endDate = null;
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: Text('Last Month', style: AppTextStyles.bodyMedium,),
                        selected: _dateFilterType == 'Last Month',
                        onSelected: (bool selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Month' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(Duration(days: 30));
                            } else {
                              _startDate = null;
                              _endDate = null;
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: Text('Custom Range', style: AppTextStyles.bodyMedium,),
                        selected: _dateFilterType == 'Custom Range',
                        onSelected: (bool selected) async {
                          if (selected) {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: DateTimeRange(
                                start: _startDate ?? DateTime.now().subtract(Duration(days: 7)),
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
                  if (_dateFilterType == 'Custom Range' && _startDate != null && _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Selected: ${_startDate!.toLocal().toString().split(' ')[0]} to ${_endDate!.toLocal().toString().split(' ')[0]}',
                        style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        if (_currentPosition != null) {
                          _fetchIssues(_currentPosition!.latitude, _currentPosition!.longitude);
                        }
                      },
                      child: Text('Apply Filters', style: AppTextStyles.titleMedium,),
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
                    style: AppTextStyles.titleLarge,
                  ),
                  SizedBox(height: 16),
                  RadioListTile<bool>(
                    title: Text('Newest First', style: AppTextStyles.bodyLarge,),
                    value: true,
                    groupValue: _sortNewestFirst,
                    onChanged: (bool? value) {
                      setModalState(() {
                        _sortNewestFirst = value!;
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    title: Text('Oldest First', style: AppTextStyles.bodyLarge,),
                    value: false,
                    groupValue: _sortNewestFirst,
                    onChanged: (bool? value) {
                      setModalState(() {
                        _sortNewestFirst = value!;
                      });
                    },
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        if (_currentPosition != null) {
                          _fetchIssues(_currentPosition!.latitude, _currentPosition!.longitude);
                        }
                      },
                      child: Text('Apply Sort', style: AppTextStyles.titleMedium,),
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
  
  Widget _buildIssueCardFromData(dynamic issue) {
    final issueId = issue['id'] as String? ?? '';
    final issueNumber = issueId.substring(0, 8); // First 8 digits of UUID as issue number
    final category = issue['category'] as String? ?? 'Unknown';
    final address = issue['address'] as String? ?? 'Unknown location';
    final upvotes = issue['upvotes'] as int? ?? 0;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final priorityLabel = _getPriorityLabel(priorityScore);
    final distanceKm = issue['distance_km'] as double? ?? 0.0;
    final reporterFirstName = issue['reporter_first_name'] as String? ?? 'Anonymous';
    final reporterLastName = issue['reporter_last_name'] as String? ?? '';
    final reporterName = reporterFirstName == 'Anonymous' ? 'Anonymous' : '$reporterFirstName $reporterLastName';
    final reporterId = issue['user_id'] as String?; // Get the reporter's user ID

    final bool hasUpvoted = _upvotedIssueIds.contains(issueId);
    final bool isReporter = _currentUserId != null && _currentUserId == reporterId;

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
                          style: AppTextStyles.titleSmall,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$address',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Priority: $priorityLabel • ${distanceKm.toStringAsFixed(1)}km away',
                          style: AppTextStyles.bodySmall.copyWith(
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
                    style: AppTextStyles.bodySmall,
                  ),
                  ElevatedButton(
                    onPressed: isReporter || hasUpvoted ? null : () => _upvoteIssue(issueId),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      backgroundColor: hasUpvoted ? Colors.green : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isReporter
                          ? 'Your Issue'
                          : hasUpvoted
                              ? 'Upvoted'
                              : 'Upvote',
                      style: AppTextStyles.bodySmall,
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
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.titleMedium,
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
                    style: AppTextStyles.titleSmall,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$upvotes↑',
                    style: AppTextStyles.bodySmall.copyWith(
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