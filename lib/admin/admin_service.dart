import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin roles in the hierarchy
enum AdminRole {
  systemAdmin,
  stateAdmin,
  departmentAdmin,
  officeAdmin,
  worker,
  citizen, // Regular user with no admin role
}

extension AdminRoleExtension on AdminRole {
  String get dbValue {
    switch (this) {
      case AdminRole.systemAdmin:
        return 'system_admin';
      case AdminRole.stateAdmin:
        return 'state_admin';
      case AdminRole.departmentAdmin:
        return 'department_admin';
      case AdminRole.officeAdmin:
        return 'office_admin';
      case AdminRole.worker:
        return 'worker';
      case AdminRole.citizen:
        return 'citizen';
    }
  }

  String get displayName {
    switch (this) {
      case AdminRole.systemAdmin:
        return 'System Admin';
      case AdminRole.stateAdmin:
        return 'State Admin';
      case AdminRole.departmentAdmin:
        return 'Department Admin';
      case AdminRole.officeAdmin:
        return 'Office Admin';
      case AdminRole.worker:
        return 'Field Worker';
      case AdminRole.citizen:
        return 'Citizen';
    }
  }

  static AdminRole fromString(String value) {
    switch (value) {
      case 'system_admin':
        return AdminRole.systemAdmin;
      case 'state_admin':
        return AdminRole.stateAdmin;
      case 'department_admin':
        return AdminRole.departmentAdmin;
      case 'office_admin':
        return AdminRole.officeAdmin;
      case 'worker':
        return AdminRole.worker;
      default:
        return AdminRole.citizen;
    }
  }
}

/// User role information
class UserRoleInfo {
  final AdminRole role;
  final String? state;
  final String? department;
  final String? officeId;
  final String? officeName;
  final bool isActive;

  UserRoleInfo({
    required this.role,
    this.state,
    this.department,
    this.officeId,
    this.officeName,
    this.isActive = true,
  });

  factory UserRoleInfo.citizen() => UserRoleInfo(role: AdminRole.citizen);

  bool get isAdmin => role != AdminRole.citizen;
  bool get canManageUsers => role.index < AdminRole.worker.index;
}

/// Manageable user info
class ManageableUser {
  final String oderId;
  final String email;
  final AdminRole role;
  final String? state;
  final String? department;
  final String? officeName;
  final DateTime createdAt;

  ManageableUser({
    required this.oderId,
    required this.email,
    required this.role,
    this.state,
    this.department,
    this.officeName,
    required this.createdAt,
  });
}

/// Service for admin role management
class AdminService {
  final SupabaseClient _supabase;

  AdminService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user's role
  Future<UserRoleInfo> getCurrentUserRole() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return UserRoleInfo.citizen();

      final response = await _supabase.rpc(
        'get_user_role',
        params: {'p_user_id': userId},
      );

      if (response == null || (response as List).isEmpty) {
        return UserRoleInfo.citizen();
      }

      final data = response[0] as Map<String, dynamic>;
      return UserRoleInfo(
        role: AdminRoleExtension.fromString(data['role'] as String? ?? ''),
        state: data['state'] as String?,
        department: data['department'] as String?,
        officeId: data['office_id'] as String?,
        officeName: data['office_name'] as String?,
        isActive: data['is_active'] as bool? ?? false,
      );
    } catch (e) {
      print('Error getting user role: $e');
      return UserRoleInfo.citizen();
    }
  }

  /// Check if current user has a specific role
  Future<bool> hasRole(AdminRole role) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase.rpc(
        'has_role',
        params: {'p_user_id': userId, 'p_role': role.dbValue},
      );

      return response as bool? ?? false;
    } catch (e) {
      print('Error checking role: $e');
      return false;
    }
  }

  /// Get list of users that current user can manage
  Future<List<ManageableUser>> getManageableUsers() async {
    try {
      final response = await _supabase.rpc('get_manageable_users');

      if (response == null) return [];

      return (response as List).map((data) {
        final map = data as Map<String, dynamic>;
        return ManageableUser(
          oderId: map['user_id'] as String,
          email: map['email'] as String,
          role: AdminRoleExtension.fromString(map['role'] as String? ?? ''),
          state: map['state'] as String?,
          department: map['department'] as String?,
          officeName: map['office_name'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      print('Error getting manageable users: $e');
      return [];
    }
  }

  /// Add a new admin role
  Future<String?> addAdminRole({
    required String targetUserId,
    required AdminRole role,
    String? state,
    String? department,
    String? officeId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'add_admin_role',
        params: {
          'p_target_user_id': targetUserId,
          'p_role': role.dbValue,
          'p_state': state,
          'p_department': department,
          'p_office_id': officeId,
        },
      );

      return response as String?;
    } catch (e) {
      print('Error adding admin role: $e');
      rethrow;
    }
  }

  /// Remove an admin role
  Future<bool> removeAdminRole(String roleId) async {
    try {
      final response = await _supabase.rpc(
        'remove_admin_role',
        params: {'p_role_id': roleId},
      );

      return response as bool? ?? false;
    } catch (e) {
      print('Error removing admin role: $e');
      rethrow;
    }
  }

  /// Get issues visible to current admin
  Future<List<Map<String, dynamic>>> getAdminIssues({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_admin_issues',
        params: {'p_status': status, 'p_limit': limit, 'p_offset': offset},
      );

      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting admin issues: $e');
      return [];
    }
  }

  /// Get all states (for system admin)
  Future<List<String>> getStates() async {
    try {
      final response = await _supabase
          .from('offices')
          .select('state')
          .order('state');

      final states = <String>{};
      for (final row in response as List) {
        final state = row['state'] as String?;
        if (state != null) states.add(state);
      }
      return states.toList();
    } catch (e) {
      print('Error getting states: $e');
      return [];
    }
  }

  /// Get departments
  List<String> getDepartments() {
    return ['pwd', 'sanitation', 'electricity', 'water', 'general'];
  }

  /// Get offices by state and department
  Future<List<Map<String, dynamic>>> getOffices({
    String? state,
    String? department,
  }) async {
    try {
      var query = _supabase
          .from('offices')
          .select('id, name, department, district, state');

      if (state != null) {
        query = query.eq('state', state);
      }
      if (department != null) {
        query = query.eq('department', department);
      }

      final response = await query.order('name');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting offices: $e');
      return [];
    }
  }

  /// Search users by email
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, email, first_name, last_name')
          .ilike('email', '%$email%')
          .limit(10);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get roles that current user can assign
  List<AdminRole> getAssignableRoles(UserRoleInfo currentRole) {
    switch (currentRole.role) {
      case AdminRole.systemAdmin:
        return [AdminRole.stateAdmin];
      case AdminRole.stateAdmin:
        return [AdminRole.departmentAdmin];
      case AdminRole.departmentAdmin:
        return [AdminRole.officeAdmin];
      case AdminRole.officeAdmin:
        return [AdminRole.worker];
      default:
        return [];
    }
  }

  // ============ ANALYTICS METHODS ============

  /// Get system-wide analytics (for system admin)
  Future<Map<String, dynamic>?> getSystemAnalytics() async {
    try {
      final response = await _supabase.rpc('get_system_analytics');
      if (response == null || (response as List).isEmpty) return null;
      return response[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting system analytics: $e');
      return null;
    }
  }

  /// Get state breakdown (for system admin)
  Future<List<Map<String, dynamic>>> getStateBreakdown() async {
    try {
      final response = await _supabase.rpc('get_state_breakdown');
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting state breakdown: $e');
      return [];
    }
  }

  /// Get state analytics (for state admin)
  Future<Map<String, dynamic>?> getStateAnalytics(String state) async {
    try {
      final response = await _supabase.rpc(
        'get_state_analytics',
        params: {'p_state': state},
      );
      if (response == null || (response as List).isEmpty) return null;
      return response[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting state analytics: $e');
      return null;
    }
  }

  /// Get department breakdown (for state admin)
  Future<List<Map<String, dynamic>>> getDepartmentBreakdown(
    String state,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_department_breakdown',
        params: {'p_state': state},
      );
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting department breakdown: $e');
      return [];
    }
  }

  /// Get department analytics (for department admin)
  Future<Map<String, dynamic>?> getDepartmentAnalytics(
    String state,
    String department,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_department_analytics',
        params: {'p_state': state, 'p_department': department},
      );
      if (response == null || (response as List).isEmpty) return null;
      return response[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting department analytics: $e');
      return null;
    }
  }

  /// Get office breakdown (for department admin)
  Future<List<Map<String, dynamic>>> getOfficeBreakdown(
    String state,
    String department,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_office_breakdown',
        params: {'p_state': state, 'p_department': department},
      );
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting office breakdown: $e');
      return [];
    }
  }

  /// Get office analytics (for office admin)
  Future<Map<String, dynamic>?> getOfficeAnalytics(String officeId) async {
    try {
      final response = await _supabase.rpc(
        'get_office_analytics',
        params: {'p_office_id': officeId},
      );
      if (response == null || (response as List).isEmpty) return null;
      return response[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting office analytics: $e');
      return null;
    }
  }

  /// Get worker stats (for office admin)
  Future<List<Map<String, dynamic>>> getWorkerStats(String officeId) async {
    try {
      final response = await _supabase.rpc(
        'get_worker_stats',
        params: {'p_office_id': officeId},
      );
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting worker stats: $e');
      return [];
    }
  }

  /// Get worker's own analytics
  Future<Map<String, dynamic>?> getWorkerAnalytics(String workerId) async {
    try {
      final response = await _supabase.rpc(
        'get_worker_analytics',
        params: {'p_worker_id': workerId},
      );
      if (response == null || (response as List).isEmpty) return null;
      return response[0] as Map<String, dynamic>;
    } catch (e) {
      print('Error getting worker analytics: $e');
      return null;
    }
  }

  /// Get worker's issues
  Future<List<Map<String, dynamic>>> getWorkerIssues(
    String workerId, {
    String? status,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_worker_issues',
        params: {'p_worker_id': workerId, 'p_status': status},
      );
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting worker issues: $e');
      return [];
    }
  }

  /// Get category breakdown
  Future<List<Map<String, dynamic>>> getCategoryBreakdown({
    String? state,
    String? department,
    String? officeId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_category_breakdown',
        params: {
          'p_state': state,
          'p_department': department,
          'p_office_id': officeId,
        },
      );
      if (response == null) return [];
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting category breakdown: $e');
      return [];
    }
  }

  /// Assign issue to worker
  Future<bool> assignIssueToWorker(String issueId, String workerId) async {
    try {
      final response = await _supabase.rpc(
        'assign_issue_to_worker',
        params: {'p_issue_id': issueId, 'p_worker_id': workerId},
      );
      return response as bool? ?? false;
    } catch (e) {
      print('Error assigning issue to worker: $e');
      rethrow;
    }
  }

  /// Update issue status (for workers)
  Future<bool> updateIssueStatus(
    String issueId,
    String status, {
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_issue_status',
        params: {'p_issue_id': issueId, 'p_status': status, 'p_notes': notes},
      );
      return response as bool? ?? false;
    } catch (e) {
      print('Error updating issue status: $e');
      rethrow;
    }
  }

  /// Get office workers (for assignment dropdown)
  Future<List<Map<String, dynamic>>> getOfficeWorkers(String officeId) async {
    try {
      final response = await _supabase
          .from('admin_roles')
          .select('user_id, users:user_id(email, first_name, last_name)')
          .eq('office_id', officeId)
          .eq('role', 'worker')
          .eq('is_active', true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting office workers: $e');
      return [];
    }
  }
}
