import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'admin_service.dart';
import 'widgets/photo_verification_dialog.dart';

class WorkerDashboardPage extends StatefulWidget {
  const WorkerDashboardPage({super.key});

  @override
  State<WorkerDashboardPage> createState() => _WorkerDashboardPageState();
}

class _WorkerDashboardPageState extends State<WorkerDashboardPage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _pendingIssues = [];
  List<Map<String, dynamic>> _inProgressIssues = [];
  List<Map<String, dynamic>> _resolvedIssues = [];
  bool _isLoading = true;
  String? _workerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _workerId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_workerId == null) return;

    setState(() => _isLoading = true);

    try {
      final analytics = await _adminService.getWorkerAnalytics(_workerId!);
      final pending = await _adminService.getWorkerIssues(
        _workerId!,
        status: 'assigned',
      );
      final inProgress = await _adminService.getWorkerIssues(
        _workerId!,
        status: 'in_progress',
      );
      final resolved = await _adminService.getWorkerIssues(
        _workerId!,
        status: 'resolved',
      );

      setState(() {
        _analytics = analytics;
        _pendingIssues = pending;
        _inProgressIssues = inProgress;
        _resolvedIssues = resolved;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${_pendingIssues.length}'),
                isLabelVisible: _pendingIssues.isNotEmpty,
                child: const Icon(Icons.pending_actions),
              ),
              text: 'Pending',
            ),
            Tab(
              icon: Badge(
                label: Text('${_inProgressIssues.length}'),
                isLabelVisible: _inProgressIssues.isNotEmpty,
                child: const Icon(Icons.engineering),
              ),
              text: 'In Progress',
            ),
            Tab(icon: const Icon(Icons.check_circle), text: 'Resolved'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIssueList(_pendingIssues, 'assigned'),
                      _buildIssueList(_inProgressIssues, 'in_progress'),
                      _buildIssueList(_resolvedIssues, 'resolved'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    if (_analytics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'Today',
              '${_analytics!['resolved_today'] ?? 0}',
              Icons.today,
              AppColors.success,
            ),
          ),
          Expanded(
            child: _buildMiniStat(
              'This Week',
              '${_analytics!['resolved_this_week'] ?? 0}',
              Icons.date_range,
              AppColors.info,
            ),
          ),
          Expanded(
            child: _buildMiniStat(
              'Avg Time',
              '${((_analytics!['avg_resolution_hours'] as num?)?.toStringAsFixed(1) ?? '0')}h',
              Icons.timer,
              AppColors.warning,
            ),
          ),
          Expanded(
            child: _buildMiniStat(
              'High Priority',
              '${_analytics!['high_priority_pending'] ?? 0}',
              Icons.priority_high,
              AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.neutral500),
        ),
      ],
    );
  }

  Widget _buildIssueList(
    List<Map<String, dynamic>> issues,
    String currentStatus,
  ) {
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              currentStatus == 'resolved' ? Icons.celebration : Icons.inbox,
              size: 64,
              color: AppColors.neutral300,
            ),
            const SizedBox(height: 16),
            Text(
              currentStatus == 'resolved'
                  ? 'No resolved issues yet'
                  : 'No pending tasks!',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: issues.length,
        itemBuilder: (context, index) {
          final issue = issues[index];
          return _buildIssueCard(issue, currentStatus);
        },
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue, String currentStatus) {
    final isHighPriority = issue['is_high_priority'] as bool? ?? false;
    final priorityScore = issue['priority_score'] as int? ?? 0;
    final mediaFiles = issue['media_files'] as List<dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHighPriority
            ? const BorderSide(color: AppColors.error, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => context.push('/issue/${issue['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (mediaFiles != null && mediaFiles.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  mediaFiles[0] as String,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.neutral200,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          issue['category'] as String? ?? 'Unknown',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isHighPriority)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.priority_high,
                                size: 12,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'HIGH',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Text(
                        'Score: $priorityScore',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issue['address'] as String? ?? 'Unknown location',
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  if (currentStatus != 'resolved')
                    Row(
                      children: [
                        if (currentStatus == 'assigned')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateStatus(
                                issue['id'] as String,
                                'in_progress',
                              ),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Start Work'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.info,
                              ),
                            ),
                          ),
                        if (currentStatus == 'in_progress') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => showPhotoVerificationDialog(
                                context: context,
                                issueId: issue['id'] as String,
                                onResolved: _loadData,
                              ),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Resolve with Photo'),
                            ),
                          ),
                        ],
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

  Future<void> _updateStatus(String issueId, String status) async {
    try {
      await _adminService.updateIssueStatus(issueId, status);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status updated to $status')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
