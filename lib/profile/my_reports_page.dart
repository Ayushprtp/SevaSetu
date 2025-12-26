import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _isLoading = true;
  List<dynamic> _issues = [];
  Position? _currentPosition;

  List<String> _selectedCategories = ['All'];
  bool _sortNewestFirst = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilterType = 'All Time';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Potholes',
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
    _fetchUserIssues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      // Silently fail for location
    }
  }

  Future<void> _fetchUserIssues() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showSnackBar(
          'Please log in to view your reports',
          ContentType.failure,
        );
        setState(() => _isLoading = false);
        return;
      }

      final upvotesResponse = await supabase
          .from('issue_upvotes')
          .select('issue_id')
          .eq('user_id', user.id);

      // Store upvoted IDs for potential future use
      final _ = (upvotesResponse as List<dynamic>)
          .map((e) => e['issue_id'] as String)
          .toSet();

      var queryBuilder = supabase
          .from('civic_issues')
          .select('''
        id, category, description, location, address, status,
        priority_score, created_at, upvotes, media_files
      ''')
          .eq('user_id', user.id);

      if (!_selectedCategories.contains('All') &&
          _selectedCategories.isNotEmpty) {
        queryBuilder = queryBuilder.filter(
          'category',
          'in',
          _selectedCategories,
        );
      }

      if (_startDate != null && _endDate != null) {
        queryBuilder = queryBuilder.gte(
          'created_at',
          _startDate!.toIso8601String(),
        );
        queryBuilder = queryBuilder.lte(
          'created_at',
          _endDate!.toIso8601String(),
        );
      }

      if (_searchController.text.isNotEmpty) {
        queryBuilder = queryBuilder.ilike(
          'id',
          '${_searchController.text.toLowerCase()}%',
        );
      }

      final response = await queryBuilder.order(
        'created_at',
        ascending: !_sortNewestFirst,
      );

      setState(() {
        _issues = response as List<dynamic>;
        _isLoading = false;
      });

      await _getCurrentLocation();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching reports: $e', ContentType.failure);
    }
  }

  void _showSnackBar(String message, ContentType type) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: type == ContentType.success ? 'Success' : 'Error',
          message: message,
          contentType: type,
        ),
      ),
    );
  }

  String _getPriorityLabel(int score) {
    if (score < 50) return 'Low';
    if (score < 100) return 'Medium';
    if (score < 300) return 'High';
    return 'Very High';
  }

  Color _getPriorityColor(int score) {
    if (score < 50) return AppColors.priorityLow;
    if (score < 100) return AppColors.priorityMedium;
    if (score < 300) return AppColors.priorityHigh;
    return AppColors.priorityVeryHigh;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  IconData _getIssueIcon(String category) {
    switch (category.toLowerCase()) {
      case 'power cut':
        return Icons.flash_on_rounded;
      case 'water leak':
        return Icons.water_drop_rounded;
      case 'pothole':
        return Icons.circle_rounded;
      case 'garbage issue':
        return Icons.delete_rounded;
      case 'street light':
        return Icons.lightbulb_rounded;
      case 'drainage problem':
        return Icons.water_rounded;
      default:
        return Icons.report_rounded;
    }
  }

  double _calculateDistance(dynamic issue) {
    if (_currentPosition == null) return 0.0;
    final locationStr = issue['location'] as String?;
    if (locationStr == null) return 0.0;

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

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  CupertinoIcons.line_horizontal_3_decrease,
                  color: Colors.white,
                ),
                onPressed: () => _showFilterSheet(context),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.sort_down, color: Colors.white),
                onPressed: () => _showSortSheet(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 56,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Reports',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_issues.length} issues reported',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search by Issue ID...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.neutral400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.neutral400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                  onChanged: (_) => _fetchUserIssues(),
                ),
              ),
            ),
          ),

          // Content
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _issues.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildIssueCard(_issues[index]),
                      childCount: _issues.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Reports Yet', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start reporting issues in your area',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(dynamic issue) {
    final issueId = issue['id'] as String? ?? '';
    final issueNumber = issueId.substring(0, 8);
    final category = issue['category'] as String? ?? 'Unknown';
    final address = issue['address'] as String? ?? 'Unknown location';
    final upvotes = issue['upvotes'] as int? ?? 0;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final status = issue['status'] as String? ?? 'reported';
    final distance = _calculateDistance(issue);
    final mediaFiles = issue['media_files'] as List<dynamic>?;

    return GestureDetector(
      onTap: () => context.push('/issue/$issueId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview if available
            if (mediaFiles != null && mediaFiles.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: Image.network(
                  mediaFiles[0] as String,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.neutral100,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppColors.neutral400,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          _getIssueIcon(category),
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$issueNumber',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.neutral500,
                              ),
                            ),
                            Text(category, style: AppTextStyles.titleSmall),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.neutral400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.neutral500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Footer row
                  Row(
                    children: [
                      _buildChip(
                        Icons.arrow_upward_rounded,
                        '$upvotes',
                        AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildChip(
                        Icons.priority_high_rounded,
                        _getPriorityLabel(priorityScore),
                        _getPriorityColor(priorityScore),
                      ),
                      const Spacer(),
                      if (_currentPosition != null)
                        Text(
                          '${_formatDistance(distance)} away',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.neutral400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.neutral300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Filter Issues', style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.lg),

                  Text('Category', style: AppTextStyles.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'All',
                        _selectedCategories.contains('All'),
                        (selected) {
                          setModalState(() {
                            if (selected)
                              _selectedCategories = ['All'];
                            else
                              _selectedCategories.remove('All');
                          });
                        },
                      ),
                      ..._categories.map(
                        (cat) => _buildFilterChip(
                          cat,
                          _selectedCategories.contains(cat),
                          (selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedCategories.remove('All');
                                _selectedCategories.add(cat);
                              } else {
                                _selectedCategories.remove(cat);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text('Date Range', style: AppTextStyles.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'All Time',
                        _dateFilterType == 'All Time',
                        (selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'All Time' : '';
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                      _buildFilterChip(
                        'Last Week',
                        _dateFilterType == 'Last Week',
                        (selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Week' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(
                                const Duration(days: 7),
                              );
                            }
                          });
                        },
                      ),
                      _buildFilterChip(
                        'Last Month',
                        _dateFilterType == 'Last Month',
                        (selected) {
                          setModalState(() {
                            _dateFilterType = selected ? 'Last Month' : '';
                            if (selected) {
                              _endDate = DateTime.now();
                              _startDate = DateTime.now().subtract(
                                const Duration(days: 30),
                              );
                            }
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchUserIssues();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    ValueChanged<bool> onSelected,
  ) {
    return FilterChip(
      label: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: selected ? Colors.white : AppColors.neutral700,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.neutral100,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.neutral300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Sort By', style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.md),

                  _buildSortOption('Newest First', _sortNewestFirst, () {
                    setModalState(() => _sortNewestFirst = true);
                  }),
                  _buildSortOption('Oldest First', !_sortNewestFirst, () {
                    setModalState(() => _sortNewestFirst = false);
                  }),

                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchUserIssues();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String label, bool selected, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.neutral300),
    );
  }
}
