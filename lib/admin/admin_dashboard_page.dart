import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminService _adminService = AdminService();
  UserRoleInfo? _currentRole;
  List<ManageableUser> _manageableUsers = [];
  List<Map<String, dynamic>> _issues = [];
  bool _isLoading = true;
  String? _error;

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

      final users = await _adminService.getManageableUsers();
      final issues = await _adminService.getAdminIssues(limit: 20);

      setState(() {
        _currentRole = role;
        _manageableUsers = users;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
      floatingActionButton: _currentRole?.canManageUsers == true
          ? FloatingActionButton.extended(
              onPressed: () => _showAddUserDialog(),
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
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoleCard(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            if (_currentRole?.canManageUsers == true) ...[
              _buildManagedUsersSection(),
              const SizedBox(height: 24),
            ],
            _buildRecentIssuesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getRoleIcon(_currentRole!.role),
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentRole!.role.displayName,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (_currentRole!.state != null)
                  Text(
                    '${_currentRole!.state}${_currentRole!.department != null ? ' • ${_currentRole!.department}' : ''}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                if (_currentRole!.officeName != null)
                  Text(
                    _currentRole!.officeName!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Issues',
            _issues.length.toString(),
            Icons.report_problem_rounded,
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'High Priority',
            _issues
                .where((i) => i['is_high_priority'] == true)
                .length
                .toString(),
            Icons.priority_high_rounded,
            AppColors.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Team Members',
            _manageableUsers.length.toString(),
            Icons.people_rounded,
            AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildManagedUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Team Members', style: AppTextStyles.titleLarge),
            TextButton(
              onPressed: () => _showAddUserDialog(),
              child: const Text('Add New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_manageableUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AppColors.neutral400,
                  ),
                  const SizedBox(height: 8),
                  Text('No team members yet', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _manageableUsers.length,
            itemBuilder: (context, index) {
              final user = _manageableUsers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    child: Icon(
                      _getRoleIcon(user.role),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(user.email),
                  subtitle: Text(
                    '${user.role.displayName}${user.officeName != null ? ' • ${user.officeName}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showUserOptions(user),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentIssuesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Issues', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        if (_issues.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: AppColors.neutral400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No issues in your scope',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _issues.length > 10 ? 10 : _issues.length,
            itemBuilder: (context, index) {
              final issue = _issues[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: issue['is_high_priority'] == true
                          ? AppColors.error
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(
                    issue['category'] as String? ?? 'Unknown',
                    style: AppTextStyles.titleSmall,
                  ),
                  subtitle: Text(
                    issue['address'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Score: ${issue['priority_score'] ?? 0}',
                        style: AppTextStyles.labelSmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(issue['status'] as String?),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (issue['status'] as String? ?? 'pending')
                              .toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/issue/${issue['id']}'),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddUserDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddUserBottomSheet(
        currentRole: _currentRole!,
        adminService: _adminService,
        onUserAdded: _loadData,
      ),
    );
  }

  void _showUserOptions(ManageableUser user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show user details
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Remove Role',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                // TODO: Implement remove role
              },
            ),
          ],
        ),
      ),
    );
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

/// Bottom sheet for adding new users
class AddUserBottomSheet extends StatefulWidget {
  final UserRoleInfo currentRole;
  final AdminService adminService;
  final VoidCallback onUserAdded;

  const AddUserBottomSheet({
    super.key,
    required this.currentRole,
    required this.adminService,
    required this.onUserAdded,
  });

  @override
  State<AddUserBottomSheet> createState() => _AddUserBottomSheetState();
}

class _AddUserBottomSheetState extends State<AddUserBottomSheet> {
  final _emailController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  AdminRole? _selectedRole;
  String? _selectedState;
  String? _selectedDepartment;
  String? _selectedOfficeId;
  List<String> _states = [];
  List<Map<String, dynamic>> _offices = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  Future<void> _loadStates() async {
    final states = await widget.adminService.getStates();
    setState(() => _states = states);
  }

  Future<void> _searchUsers(String email) async {
    if (email.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    final results = await widget.adminService.searchUsersByEmail(email);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _loadOffices() async {
    if (_selectedState == null || _selectedDepartment == null) return;

    final offices = await widget.adminService.getOffices(
      state: _selectedState,
      department: _selectedDepartment,
    );
    setState(() => _offices = offices);
  }

  Future<void> _addUser() async {
    if (_selectedUser == null || _selectedRole == null) return;

    setState(() => _isLoading = true);

    try {
      await widget.adminService.addAdminRole(
        targetUserId: _selectedUser!['id'] as String,
        role: _selectedRole!,
        state: _selectedState,
        department: _selectedDepartment,
        officeId: _selectedOfficeId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully')),
        );
        widget.onUserAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignableRoles = widget.adminService.getAssignableRoles(
      widget.currentRole,
    );
    final departments = widget.adminService.getDepartments();

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Team Member', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 24),

            // Email search
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Search by Email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              onChanged: _searchUsers,
            ),

            // Search results
            if (_searchResults.isNotEmpty && _selectedUser == null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      title: Text(user['email'] as String),
                      subtitle: Text(
                        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                            .trim(),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedUser = user;
                          _emailController.text = user['email'] as String;
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),

            // Selected user chip
            if (_selectedUser != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text(_selectedUser!['email'] as String),
                  onDeleted: () => setState(() {
                    _selectedUser = null;
                    _emailController.clear();
                  }),
                ),
              ),

            const SizedBox(height: 16),

            // Role selection
            DropdownButtonFormField<AdminRole>(
              value: _selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: assignableRoles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.displayName),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedRole = value),
            ),

            const SizedBox(height: 16),

            // State selection (for state_admin and below)
            if (_selectedRole != null && _selectedRole != AdminRole.systemAdmin)
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(labelText: 'State'),
                items: _states.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                    _selectedDepartment = null;
                    _selectedOfficeId = null;
                  });
                },
              ),

            // Department selection (for department_admin and below)
            if (_selectedRole != null &&
                _selectedRole!.index >= AdminRole.departmentAdmin.index &&
                _selectedState != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Department'),
                items: departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Text(dept.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                    _selectedOfficeId = null;
                  });
                  _loadOffices();
                },
              ),
            ],

            // Office selection (for office_admin and worker)
            if (_selectedRole != null &&
                _selectedRole!.index >= AdminRole.officeAdmin.index &&
                _selectedDepartment != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOfficeId,
                decoration: const InputDecoration(labelText: 'Office'),
                items: _offices.map((office) {
                  return DropdownMenuItem(
                    value: office['id'] as String,
                    child: Text(office['name'] as String),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedOfficeId = value),
              ),
            ],

            const SizedBox(height: 24),

            // Add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedUser != null &&
                        _selectedRole != null &&
                        !_isLoading
                    ? _addUser
                    : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
