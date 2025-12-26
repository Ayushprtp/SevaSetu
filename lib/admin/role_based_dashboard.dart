import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'admin_service.dart';
import 'widgets/analytics_cards.dart';

/// Main dashboard that adapts based on user role
class RoleBasedDashboard extends StatefulWidget {
  const RoleBasedDashboard({super.key});

  @override
  State<RoleBasedDashboard> createState() => _RoleBasedDashboardState();
}

class _RoleBasedDashboardState extends State<RoleBasedDashboard> {
  final AdminService _adminService = AdminService();
  UserRoleInfo? _currentRole;
  bool _isLoading = true;
  String? _error;

  // Analytics data
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _breakdown = [];
  List<Map<String, dynamic>> _categoryBreakdown = [];
  List<Map<String, dynamic>> _issues = [];
  List<ManageableUser> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final role = await _adminService.getCurrentUserRole();

      if (!role.isAdmin) {
        setState(() {
          _error = 'You do not have admin access';
          _isLoading = false;
        });
        return;
      }

      // Load role-specific data
      await _loadRoleSpecificData(role);

      // Load common data
      final teamMembers = await _adminService.getManageableUsers();
      final issues = await _adminService.getAdminIssues(limit: 10);

      setState(() {
        _currentRole = role;
        _teamMembers = teamMembers;
        _issues = issues;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoleSpecificData(UserRoleInfo role) async {
    switch (role.role) {
      case AdminRole.systemAdmin:
        _analytics = await _adminService.getSystemAnalytics();
        _breakdown = await _adminService.getStateBreakdown();
        _categoryBreakdown = await _adminService.getCategoryBreakdown();
        break;
      case AdminRole.stateAdmin:
        if (role.state != null) {
          _analytics = await _adminService.getStateAnalytics(role.state!);
          _breakdown = await _adminService.getDepartmentBreakdown(role.state!);
          _categoryBreakdown = await _adminService.getCategoryBreakdown(
            state: role.state,
          );
        }
        break;
      case AdminRole.departmentAdmin:
        if (role.state != null && role.department != null) {
          _analytics = await _adminService.getDepartmentAnalytics(
            role.state!,
            role.department!,
          );
          _breakdown = await _adminService.getOfficeBreakdown(
            role.state!,
            role.department!,
          );
          _categoryBreakdown = await _adminService.getCategoryBreakdown(
            state: role.state,
            department: role.department,
          );
        }
        break;
      case AdminRole.officeAdmin:
        if (role.officeId != null) {
          _analytics = await _adminService.getOfficeAnalytics(role.officeId!);
          _breakdown = await _adminService.getWorkerStats(role.officeId!);
          _categoryBreakdown = await _adminService.getCategoryBreakdown(
            officeId: role.officeId,
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
      floatingActionButton: _currentRole?.canManageUsers == true
          ? FloatingActionButton.extended(
              onPressed: () => _showAddUserSheet(),
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error!, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // App Bar with role info
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(background: _buildRoleHeader()),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            ],
          ),

          // Stats Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: _buildStatsGrid()),
          ),

          // Status Distribution
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildStatusSection()),
          ),

          // Breakdown Section
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: _buildBreakdownSection()),
          ),

          // Category Breakdown
          if (_categoryBreakdown.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildCategorySection()),
            ),

          // Team Members (if can manage)
          if (_currentRole?.canManageUsers == true && _teamMembers.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: _buildTeamSection()),
            ),

          // Recent Issues
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: _buildRecentIssuesSection()),
          ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildRoleHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getRoleColor(_currentRole!.role),
            _getRoleColor(_currentRole!.role).withValues(alpha: 0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getRoleIcon(_currentRole!.role),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentRole!.role.displayName,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentRole!.state != null)
                          Text(
                            _getScopeText(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
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

  String _getScopeText() {
    final parts = <String>[];
    if (_currentRole!.state != null) parts.add(_currentRole!.state!);
    if (_currentRole!.department != null)
      parts.add(_currentRole!.department!.toUpperCase());
    if (_currentRole!.officeName != null) parts.add(_currentRole!.officeName!);
    return parts.join(' • ');
  }

  Widget _buildStatsGrid() {
    if (_analytics == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          title: 'Total Issues',
          value: '${_analytics!['total_issues'] ?? 0}',
          icon: Icons.report_problem_rounded,
          color: AppColors.primary,
          subtitle: 'Today: ${_analytics!['issues_today'] ?? 0}',
        ),
        StatCard(
          title: 'High Priority',
          value: '${_analytics!['high_priority_issues'] ?? 0}',
          icon: Icons.priority_high_rounded,
          color: AppColors.error,
        ),
        StatCard(
          title: 'Pending',
          value: '${_analytics!['pending_issues'] ?? 0}',
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
        ),
        StatCard(
          title: 'Resolved',
          value: '${_analytics!['resolved_issues'] ?? 0}',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue Status Distribution', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            StatusDistribution(
              pending: (_analytics!['pending_issues'] as num?)?.toInt() ?? 0,
              inProgress:
                  (_analytics!['in_progress_issues'] as num?)?.toInt() ?? 0,
              resolved: (_analytics!['resolved_issues'] as num?)?.toInt() ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownSection() {
    if (_breakdown.isEmpty) return const SizedBox.shrink();

    final title = switch (_currentRole!.role) {
      AdminRole.systemAdmin => 'State-wise Breakdown',
      AdminRole.stateAdmin => 'Department Performance',
      AdminRole.departmentAdmin => 'Office Performance',
      AdminRole.officeAdmin => 'Worker Performance',
      _ => 'Breakdown',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _breakdown.length > 5 ? 5 : _breakdown.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = _breakdown[index];
                return _buildBreakdownItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(Map<String, dynamic> item) {
    final name =
        item['state'] ??
        item['department'] ??
        item['office_name'] ??
        item['worker_email'] ??
        'Unknown';
    final total =
        (item['total_issues'] as num?)?.toInt() ??
        (item['assigned_issues'] as num?)?.toInt() ??
        0;
    final resolved = (item['resolved_issues'] as num?)?.toInt() ?? 0;
    final pending = (item['pending_issues'] as num?)?.toInt() ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name.toString(), style: AppTextStyles.bodyMedium),
      subtitle: Text(
        'Total: $total • Resolved: $resolved • Pending: $pending',
        style: AppTextStyles.caption,
      ),
      trailing: CircularProgressIndicator(
        value: total > 0 ? resolved / total : 0,
        backgroundColor: AppColors.neutral200,
        color: AppColors.success,
        strokeWidth: 4,
      ),
    );
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issues by Category', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            CategoryBreakdownChart(data: _categoryBreakdown),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team Members (${_teamMembers.length})',
                  style: AppTextStyles.titleMedium,
                ),
                TextButton(
                  onPressed: () => _showAddUserSheet(),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _teamMembers.length,
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  return Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getRoleColor(member.role),
                          child: Icon(
                            _getRoleIcon(member.role),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member.email.split('@')[0],
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentIssuesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Issues', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            if (_issues.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No issues in your scope'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _issues.length > 5 ? 5 : _issues.length,
                itemBuilder: (context, index) {
                  final issue = _issues[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: issue['is_high_priority'] == true
                            ? AppColors.error
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(
                      issue['category'] as String? ?? 'Unknown',
                      style: AppTextStyles.bodyMedium,
                    ),
                    subtitle: Text(
                      issue['address'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(issue['status'] as String?),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (issue['status'] as String? ?? 'pending').toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    onTap: () => context.push('/issue/${issue['id']}'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddUserSheet() {
    // Import and show the AddUserBottomSheet from admin_dashboard_page.dart
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Admin Dashboard to add users')),
    );
    context.push('/admin-dashboard');
  }

  IconData _getRoleIcon(AdminRole role) {
    switch (role) {
      case AdminRole.systemAdmin:
        return Icons.admin_panel_settings;
      case AdminRole.stateAdmin:
        return Icons.account_balance;
      case AdminRole.departmentAdmin:
        return Icons.business;
      case AdminRole.officeAdmin:
        return Icons.location_city;
      case AdminRole.worker:
        return Icons.engineering;
      case AdminRole.citizen:
        return Icons.person;
    }
  }

  Color _getRoleColor(AdminRole role) {
    switch (role) {
      case AdminRole.systemAdmin:
        return Colors.purple;
      case AdminRole.stateAdmin:
        return Colors.indigo;
      case AdminRole.departmentAdmin:
        return Colors.blue;
      case AdminRole.officeAdmin:
        return Colors.teal;
      case AdminRole.worker:
        return Colors.green;
      case AdminRole.citizen:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'resolved':
        return AppColors.success;
      case 'in_progress':
      case 'assigned':
        return AppColors.warning;
      case 'escalated':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }
}
