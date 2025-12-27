import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:sevasetu/admin/admin_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  int _userReportCount = 0;
  bool _isLoadingProfile = true;
  UserRoleInfo? _userRole;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final response = await supabase
          .from('users')
          .select(
            'first_name, last_name, username, mobile_number, email, id_value',
          )
          .eq('id', user.id)
          .single();

      final reportCountResponse = await supabase
          .from('civic_issues')
          .select('id')
          .eq('user_id', user.id);

      final count = reportCountResponse.length;

      // Load user role
      final role = await _adminService.getCurrentUserRole();

      setState(() {
        _userData = response as Map<String, dynamic>?;
        _userReportCount = count;
        _userRole = role;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  bool get _isVerified {
    if (_userData == null) return false;
    final idValue = _userData!['id_value'] as String?;
    return idValue != null && idValue.isNotEmpty;
  }

  String get _fullName {
    if (_userData == null) return '';
    final firstName = _userData!['first_name'] ?? '';
    final lastName = _userData!['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String get _username {
    return _userData?['username'] ?? '';
  }

  String get _email {
    return _userData?['email'] ?? '';
  }

  String get _mobileNumber {
    return _userData?['mobile_number'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Custom App Bar with gradient
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primary,
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // Avatar with verification badge
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Text(
                                      _fullName.isNotEmpty
                                          ? _fullName[0].toUpperCase()
                                          : 'U',
                                      style: AppTextStyles.headlineLarge
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                                if (_isVerified)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _fullName.isNotEmpty ? _fullName : _username,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (_username.isNotEmpty)
                              Text(
                                '@$_username',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            // Role Badge
                            if (_userRole != null && _userRole!.isAdmin)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(_userRole!.role),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getRoleIcon(_userRole!.role),
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _userRole!.role.displayName,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      onPressed: () async {
                        final result = await context.push(
                          '/edit-profile',
                          extra: _userData,
                        );
                        if (result == true) {
                          await _loadUserProfile();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Quick Stats Row
                      Container(
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              'Reports',
                              '$_userReportCount',
                              Icons.assignment_rounded,
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: AppColors.neutral200,
                            ),
                            _buildStatColumn(
                              'Points',
                              '60',
                              Icons.stars_rounded,
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: AppColors.neutral200,
                            ),
                            _buildStatColumn(
                              'Badges',
                              '1',
                              Icons.military_tech_rounded,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Contact Info Section
                      _buildSectionTitle('Contact Information'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildInfoCard([
                        _buildInfoTile(Icons.email_rounded, 'Email', _email),
                        if (_mobileNumber.isNotEmpty)
                          _buildInfoTile(
                            Icons.phone_rounded,
                            'Phone',
                            _mobileNumber,
                          ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),

                      // My Activity Section
                      _buildSectionTitle('My Activity'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildInfoCard([
                        _buildActionTile(
                          Icons.assignment_rounded,
                          'My Reports',
                          '$_userReportCount issues reported',
                          () => context.push('/my-reports'),
                        ),
                        _buildActionTile(
                          Icons.thumb_up_rounded,
                          'Upvoted Issues',
                          'Issues you supported',
                          () => context.push('/upvoted-issues'),
                        ),
                      ]),

                      // Admin Dashboard Section (only for admins)
                      if (_userRole != null && _userRole!.isAdmin) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _buildSectionTitle('Admin Access'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildInfoCard([
                          _buildActionTile(
                            Icons.dashboard_rounded,
                            'Dashboard',
                            'View analytics and manage issues',
                            () => context.push('/dashboard'),
                          ),
                          if (_userRole!.role == AdminRole.worker)
                            _buildActionTile(
                              Icons.assignment_ind_rounded,
                              'My Tasks',
                              'View assigned issues',
                              () => context.push('/worker-dashboard'),
                            ),
                          if (_userRole!.canManageUsers)
                            _buildActionTile(
                              Icons.admin_panel_settings_rounded,
                              'Admin Panel',
                              'Manage users and roles',
                              () => context.push('/admin-dashboard'),
                            ),
                        ]),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // Preferences Section
                      _buildSectionTitle('Preferences'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildInfoCard([
                        _buildSwitchTile(
                          Icons.dark_mode_rounded,
                          'Dark Mode',
                          isDark,
                          (value) {
                            themeNotifier.value = value
                                ? ThemeMode.dark
                                : ThemeMode.light;
                          },
                        ),
                        _buildSwitchTile(
                          Icons.notifications_rounded,
                          'Notifications',
                          true,
                          (value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Notifications ${value ? "enabled" : "disabled"}',
                                ),
                              ),
                            );
                          },
                        ),
                        _buildActionTile(
                          Icons.language_rounded,
                          'Language',
                          'English',
                          () => _showLanguageSheet(context),
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),

                      // Support Section
                      _buildSectionTitle('Support'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildInfoCard([
                        _buildActionTile(
                          Icons.help_outline_rounded,
                          'Help & Support',
                          'Get help with the app',
                          () {},
                        ),
                        _buildActionTile(
                          Icons.privacy_tip_rounded,
                          'Privacy Policy',
                          'Read our privacy policy',
                          () {},
                        ),
                        _buildActionTile(
                          Icons.description_rounded,
                          'Terms of Service',
                          'Read our terms',
                          () {},
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),

                      // Logout Button
                      Container(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (mounted) {
                              context.go('/auth');
                            }
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.error,
                          ),
                          label: Text(
                            'Sign Out',
                            style: AppTextStyles.button.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.titleMedium),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.neutral500),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: AppTextStyles.titleMedium),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
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
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Divider(height: 1, indent: 56, color: AppColors.neutral200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.neutral500),
      ),
      subtitle: Text(value, style: AppTextStyles.bodyLarge),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.neutral500),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.neutral400,
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyLarge),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
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
              Text('Select Language', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _buildLanguageOption('English', true),
              _buildLanguageOption('Hindi', false),
              _buildLanguageOption('Marathi', false),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String language, bool isSelected) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Language set to $language')));
      },
      title: Text(language, style: AppTextStyles.bodyLarge),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
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
}
