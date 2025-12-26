import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sevasetu/admin/admin_service.dart';
import 'package:sevasetu/admin/widgets/issue_assignment_sheet.dart';

class IssueDetailPage extends StatefulWidget {
  final String issueId;

  const IssueDetailPage({super.key, required this.issueId});

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  Map<String, dynamic>? _issueDetails;
  Map<String, dynamic>? _reporterDetails;
  bool _isLoading = true;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentUserId;
  bool _hasUpvoted = false;
  String? _issueReporterId;
  UserRoleInfo? _userRole;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchIssueDetails();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _adminService.getCurrentUserRole();
    if (mounted) {
      setState(() => _userRole = role);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchIssueDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _reporterDetails = null;
      });

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('civic_issues')
          .select('''
        *, user_id, users:user_id(username, first_name, last_name)
      ''')
          .eq('id', widget.issueId)
          .single();

      final usersData = response['users'];
      Map<String, dynamic>? reporterData = usersData is Map<String, dynamic>
          ? usersData
          : null;

      bool hasValidJoinedUserData =
          reporterData != null &&
          (reporterData['username'] != null ||
              reporterData['first_name'] != null ||
              reporterData['last_name'] != null);

      if (!hasValidJoinedUserData) {
        final userId = response['user_id'] as String?;
        if (userId != null) {
          try {
            final userResponse = await supabase
                .from('users')
                .select('username, first_name, last_name')
                .eq('id', userId)
                .maybeSingle();
            if (userResponse != null) {
              reporterData = userResponse;
            }
          } catch (_) {}
        }
      }

      bool hasUpvoted = false;
      if (_currentUserId != null) {
        final upvoteResponse = await supabase
            .from('issue_upvotes')
            .select('issue_id')
            .eq('user_id', _currentUserId!)
            .eq('issue_id', widget.issueId)
            .limit(1);
        hasUpvoted = upvoteResponse.isNotEmpty;
      }

      final String? reporterId = response['user_id'] as String?;

      setState(() {
        _issueDetails = response;
        _reporterDetails = reporterData;
        _hasUpvoted = hasUpvoted;
        _issueReporterId = reporterId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching issue details: $e';
        _isLoading = false;
      });
    }
  }

  String _getReporterName() {
    String _buildDisplayName(Map<String, dynamic> userData) {
      final firstName = userData['first_name'] as String?;
      final lastName = userData['last_name'] as String?;
      final username = userData['username'] as String?;

      if (firstName != null && lastName != null) return '$firstName $lastName';
      if (firstName != null) return firstName;
      if (lastName != null) return lastName;
      if (username != null) return username;
      return '';
    }

    if (_reporterDetails != null) return _buildDisplayName(_reporterDetails!);
    if (_issueDetails!['users'] != null) {
      final usersData = _issueDetails!['users'] as Map<String, dynamic>?;
      if (usersData != null) return _buildDisplayName(usersData);
    }
    return 'Anonymous';
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

  double _getStatusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'reported':
        return 0.2;
      case 'in_progress':
        return 0.6;
      case 'completed':
        return 1.0;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _issueDetails == null
          ? _buildNotFoundState()
          : _buildContent(isDark),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Something went wrong', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _fetchIssueDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.neutral400,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Issue not found', style: AppTextStyles.titleLarge),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final category = _issueDetails!['category'] as String? ?? 'Unknown';
    final address = _issueDetails!['address'] as String? ?? 'Unknown location';
    final createdAt = DateTime.parse(_issueDetails!['created_at'] as String);
    final status = _issueDetails!['status'] as String? ?? 'reported';
    final upvotes = _issueDetails!['upvotes'] as int? ?? 0;
    final mediaFiles = _issueDetails!['media_files'] as List<dynamic>?;

    return CustomScrollView(
      slivers: [
        // Hero image app bar
        SliverAppBar(
          expandedHeight: mediaFiles != null && mediaFiles.isNotEmpty
              ? 300
              : 120,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: mediaFiles != null && mediaFiles.isNotEmpty
                ? GestureDetector(
                    onTap: () => _openFullScreenImage(context, mediaFiles, 0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          mediaFiles[0] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primary,
                            child: const Icon(
                              Icons.image_not_supported_rounded,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        if (mediaFiles.length > 1)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${mediaFiles.length - 1}',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                    ),
                  ),
          ),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Category and status header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      category,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
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

              const SizedBox(height: AppSpacing.md),

              // Issue ID
              Text(
                'Issue #${widget.issueId.substring(0, 8)}',
                style: AppTextStyles.headlineSmall,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Location and reporter info
              _buildInfoRow(Icons.location_on_rounded, address),
              const SizedBox(height: AppSpacing.xs),
              _buildInfoRow(
                Icons.person_rounded,
                'Reported by ${_getReporterName()}',
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildInfoRow(
                Icons.access_time_rounded,
                DateFormat('MMM dd, yyyy • HH:mm').format(createdAt),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Description section
              _buildSectionCard(
                'Description',
                Icons.description_rounded,
                child: Text(
                  _issueDetails!['description'] as String? ??
                      'No description provided',
                  style: AppTextStyles.bodyLarge,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // AI Analysis section
              _buildAIAnalysisSection(),

              const SizedBox(height: AppSpacing.md),

              // Media gallery
              if (mediaFiles != null && mediaFiles.length > 1) ...[
                _buildSectionCard(
                  'Evidence (${mediaFiles.length} photos)',
                  Icons.photo_library_rounded,
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: mediaFiles.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () =>
                              _openFullScreenImage(context, mediaFiles, index),
                          child: Container(
                            width: 100,
                            margin: EdgeInsets.only(
                              right: index < mediaFiles.length - 1 ? 8 : 0,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              image: DecorationImage(
                                image: NetworkImage(
                                  mediaFiles[index] as String,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Status progress
              _buildSectionCard(
                'Status Progress',
                Icons.timeline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current: ${status.replaceAll('_', ' ')}',
                          style: AppTextStyles.bodyMedium,
                        ),
                        Text(
                          '${(_getStatusProgress(status) * 100).toInt()}%',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: _getStatusProgress(status),
                        backgroundColor: AppColors.neutral200,
                        color: _getStatusColor(status),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusStep(
                          'Reported',
                          _getStatusProgress(status) >= 0.2,
                        ),
                        _buildStatusStep(
                          'In Progress',
                          _getStatusProgress(status) >= 0.6,
                        ),
                        _buildStatusStep(
                          'Completed',
                          _getStatusProgress(status) >= 1.0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Location details
              _buildLocationSection(),

              const SizedBox(height: AppSpacing.md),

              // Upvote section
              _buildUpvoteSection(upvotes),

              // Assignment section (for office admins)
              if (_userRole != null && _userRole!.role == AdminRole.officeAdmin)
                _buildAssignmentSection(),

              const SizedBox(height: AppSpacing.xl),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.neutral500),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon, {
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusStep(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.success : AppColors.neutral200,
          ),
          child: isActive
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.success : AppColors.neutral400,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final location = _issueDetails!['location'] as String?;
    final address = _issueDetails!['address'] as String? ?? 'N/A';

    if (location == null) return const SizedBox.shrink();

    final RegExp pointRegExp = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
    final Match? match = pointRegExp.firstMatch(location);

    if (match == null) return const SizedBox.shrink();

    final double longitude = double.parse(match.group(1)!);
    final double latitude = double.parse(match.group(2)!);

    return _buildSectionCard(
      'Location',
      Icons.map_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address, style: AppTextStyles.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lat: ${latitude.toStringAsFixed(6)}\nLng: ${longitude.toStringAsFixed(6)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final mapUrl = Uri.parse(
                    'geo:$latitude,$longitude?q=$latitude,$longitude',
                  );
                  if (await canLaunchUrl(mapUrl)) {
                    await launchUrl(mapUrl);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open map')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpvoteSection(int upvotes) {
    final isReporter = _currentUserId == _issueReporterId;
    final canUpvote = _currentUserId != null && !isReporter && !_hasUpvoted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.thumb_up_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community Support', style: AppTextStyles.titleSmall),
                Text(
                  '$upvotes people upvoted this issue',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canUpvote ? () => _upvoteIssue(widget.issueId) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasUpvoted
                  ? AppColors.success
                  : AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.neutral200,
              disabledForegroundColor: AppColors.neutral500,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasUpvoted
                      ? Icons.check_rounded
                      : (isReporter
                            ? Icons.person_rounded
                            : Icons.arrow_upward_rounded),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _hasUpvoted
                      ? 'Upvoted'
                      : (isReporter ? 'Your Issue' : 'Upvote'),
                  style: AppTextStyles.button,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection() {
    final assignedWorkerId = _issueDetails!['assigned_worker_id'] as String?;
    final officeId = _userRole?.officeId;
    final category = _issueDetails!['category'] as String? ?? 'Unknown';
    final address = _issueDetails!['address'] as String? ?? 'Unknown location';

    // Only show for unassigned issues
    if (assignedWorkerId != null || officeId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withValues(alpha: 0.1),
            Colors.teal.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_ind_rounded, color: Colors.teal),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign to Worker', style: AppTextStyles.titleSmall),
                Text(
                  'This issue is not yet assigned',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => showIssueAssignmentSheet(
              context: context,
              issueId: widget.issueId,
              officeId: officeId,
              issueCategory: category,
              issueAddress: address,
              onAssigned: _fetchIssueDetails,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisSection() {
    final aiAnalysis = _issueDetails!['ai_analysis'] as Map<String, dynamic>?;
    final priorityScore = _issueDetails!['priority_score'] as int? ?? 0;
    final isHighPriority = _issueDetails!['is_high_priority'] as bool? ?? false;
    final escalationLevel =
        _issueDetails!['escalation_level'] as String? ?? 'none';
    final severityLevel =
        _issueDetails!['severity_level'] as String? ?? 'MEDIUM';
    final assignedDepartment = _issueDetails!['assigned_department'] as String?;

    if (aiAnalysis == null && priorityScore == 0) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      'AI Analysis & Priority',
      Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority Score Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Priority Score', style: AppTextStyles.bodyMedium),
                        Row(
                          children: [
                            if (isHighPriority)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  'HIGH PRIORITY',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Text(
                              '$priorityScore/100',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: _getPriorityColor(priorityScore),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: priorityScore / 100,
                        backgroundColor: AppColors.neutral200,
                        color: _getPriorityColor(priorityScore),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          // AI Analysis Details
          if (aiAnalysis != null) ...[
            _buildAnalysisRow(
              'Detected Category',
              aiAnalysis['detected_category'] as String? ?? 'Unknown',
              Icons.category_rounded,
            ),
            _buildAnalysisRow(
              'Severity Level',
              severityLevel,
              Icons.warning_rounded,
              color: _getSeverityColor(severityLevel),
            ),
            if (aiAnalysis['confidence_score'] != null)
              _buildAnalysisRow(
                'AI Confidence',
                '${((aiAnalysis['confidence_score'] as num) * 100).toInt()}%',
                Icons.psychology_rounded,
              ),
            if (aiAnalysis['population_impact'] != null)
              _buildAnalysisRow(
                'Population Impact',
                aiAnalysis['population_impact'] as String,
                Icons.people_rounded,
              ),
            if (aiAnalysis['affected_area_sqm'] != null &&
                (aiAnalysis['affected_area_sqm'] as num) > 0)
              _buildAnalysisRow(
                'Affected Area',
                '${(aiAnalysis['affected_area_sqm'] as num).toStringAsFixed(1)} sq.m',
                Icons.square_foot_rounded,
              ),
          ],

          // Routing Info
          if (assignedDepartment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _buildAnalysisRow(
              'Assigned Department',
              assignedDepartment.toUpperCase(),
              Icons.business_rounded,
              color: AppColors.primary,
            ),
          ],

          // Escalation Level
          if (escalationLevel != 'none') ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _getEscalationColor(
                  escalationLevel,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _getEscalationColor(
                    escalationLevel,
                  ).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    color: _getEscalationColor(escalationLevel),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Escalation: ${escalationLevel.toUpperCase()}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: _getEscalationColor(escalationLevel),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hazard Indicators
          if (aiAnalysis != null && aiAnalysis['hazard_indicators'] != null)
            _buildHazardIndicators(
              aiAnalysis['hazard_indicators'] as List<dynamic>,
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.neutral500),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int score) {
    if (score >= 80) return AppColors.error;
    if (score >= 60) return AppColors.warning;
    if (score >= 40) return AppColors.info;
    return AppColors.success;
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return AppColors.warning;
      case 'LOW':
        return AppColors.success;
      default:
        return AppColors.neutral500;
    }
  }

  Color _getEscalationColor(String level) {
    switch (level.toLowerCase()) {
      case 'emergency':
        return AppColors.error;
      case 'highpriority':
        return Colors.orange;
      case 'elevated':
        return AppColors.warning;
      default:
        return AppColors.neutral500;
    }
  }

  Widget _buildHazardIndicators(List<dynamic> hazardIndicators) {
    final hazards = hazardIndicators.cast<String>();
    if (hazards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('Hazard Indicators', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hazards
              .map(
                (hazard) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    hazard.replaceAll('_', ' '),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _upvoteIssue(String issueId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await supabase.rpc(
        'upvote_issue',
        params: {'p_user_id': user.id, 'p_issue_id': issueId},
      );

      await _fetchIssueDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue upvoted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error upvoting issue: $e')));
      }
    }
  }

  void _openFullScreenImage(
    BuildContext context,
    List<dynamic> mediaFiles,
    int initialIndex,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => FullScreenImageViewer(
        mediaFiles: mediaFiles,
        initialIndex: initialIndex,
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> mediaFiles;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.mediaFiles.length}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // Image viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaFiles.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.mediaFiles[index] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Thumbnail strip
          if (widget.mediaFiles.length > 1)
            Container(
              height: 80,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.mediaFiles.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(
                            widget.mediaFiles[index] as String,
                          ),
                          fit: BoxFit.cover,
                          opacity: isSelected ? 1.0 : 0.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
