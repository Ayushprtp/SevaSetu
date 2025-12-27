import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sevasetu/utils/app_styles.dart';

class UpvotedIssuesPage extends StatefulWidget {
  const UpvotedIssuesPage({super.key});

  @override
  State<UpvotedIssuesPage> createState() => _UpvotedIssuesPageState();
}

class _UpvotedIssuesPageState extends State<UpvotedIssuesPage> {
  bool _isLoading = true;
  List<dynamic> _issues = [];
  Position? _currentPosition;
  bool _sortNewestFirst = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUpvotedIssues();
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

  Future<void> _fetchUpvotedIssues() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view upvoted issues'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Get all issue IDs that the user has upvoted
      final upvotesResponse = await supabase
          .from('issue_upvotes')
          .select('issue_id, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: !_sortNewestFirst);

      final upvotedIssueIds = (upvotesResponse as List<dynamic>)
          .map((e) => e['issue_id'] as String)
          .toList();

      if (upvotedIssueIds.isEmpty) {
        setState(() {
          _issues = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch the actual issues
      var query = supabase
          .from('civic_issues')
          .select('''
            id, category, description, location, address, status,
            priority_score, created_at, upvotes, media_files, user_id
          ''')
          .inFilter('id', upvotedIssueIds);

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        query = query.ilike('id', '${_searchController.text.toLowerCase()}%');
      }

      final issuesResponse = await query;

      // Fetch reporter info for each issue
      List<dynamic> issuesWithReporter = [];
      for (var issue in issuesResponse) {
        final userId = issue['user_id'] as String?;
        String reporterName = 'Anonymous';

        if (userId != null) {
          try {
            final userResponse = await supabase
                .from('users')
                .select('first_name, last_name')
                .eq('id', userId)
                .single();

            final firstName = userResponse['first_name'] as String? ?? '';
            final lastName = userResponse['last_name'] as String? ?? '';
            reporterName = '$firstName $lastName'.trim();
            if (reporterName.isEmpty) reporterName = 'Anonymous';
          } catch (_) {
            // Keep default 'Anonymous'
          }
        }

        issuesWithReporter.add({...issue, 'reporter_name': reporterName});
      }

      // Sort by upvote time (maintain order from upvotes query)
      final orderedIssues = <dynamic>[];
      for (var id in upvotedIssueIds) {
        final issue = issuesWithReporter.firstWhere(
          (i) => i['id'] == id,
          orElse: () => null,
        );
        if (issue != null) orderedIssues.add(issue);
      }

      setState(() {
        _issues = orderedIssues;
        _isLoading = false;
      });

      await _getCurrentLocation();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching upvoted issues: $e')),
        );
      }
    }
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
      case 'resolved':
        return AppColors.success;
      case 'in_progress':
      case 'assigned':
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
                          'Upvoted Issues',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_issues.length} issues supported',
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
                  onChanged: (_) => _fetchUpvotedIssues(),
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
              Icons.thumb_up_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Upvoted Issues', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Support issues in your community by upvoting them',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(dynamic issue) {
    final issueId = issue['id'] as String? ?? '';
    final issueNumber = issueId.length >= 8 ? issueId.substring(0, 8) : issueId;
    final category = issue['category'] as String? ?? 'Unknown';
    final address = issue['address'] as String? ?? 'Unknown location';
    final upvotes = issue['upvotes'] as int? ?? 0;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final status = issue['status'] as String? ?? 'reported';
    final reporterName = issue['reporter_name'] as String? ?? 'Anonymous';
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

                  // Reporter info
                  Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: AppColors.neutral400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reported by $reporterName',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

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
                        Icons.thumb_up_rounded,
                        '$upvotes',
                        AppColors.success,
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

                  _buildSortOption('Recently Upvoted', _sortNewestFirst, () {
                    setModalState(() => _sortNewestFirst = true);
                  }),
                  _buildSortOption('Oldest Upvoted', !_sortNewestFirst, () {
                    setModalState(() => _sortNewestFirst = false);
                  }),

                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchUpvotedIssues();
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
