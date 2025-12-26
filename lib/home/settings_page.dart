import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:sevasetu/admin/admin_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _userData;
  bool _isLoadingProfile = true;
  bool _notificationsEnabled = true;
  UserRoleInfo? _userRole;
  final SupabaseClient supabase = Supabase.instance.client;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingProfile = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users')
          .select('first_name, last_name, username, id_value')
          .eq('id', user.id)
          .single();

      // Load user role
      final role = await _adminService.getCurrentUserRole();

      setState(() {
        _userData = response as Map<String, dynamic>?;
        _userRole = role;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
      setState(() => _isLoadingProfile = false);
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

  String _getUserEmail() {
    return supabase.auth.currentUser?.email ?? 'user@example.com';
  }

  bool _isVerified() {
    return (_userData?['id_value'] as String?)?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          heroTag: 'settings_nav_bar', // Unique hero tag to avoid conflicts
          largeTitle: Text('Settings', style: AppTextStyles.headlineLarge),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_isLoadingProfile)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Profile Card
                _buildProfileCard(),
                const SizedBox(height: AppSpacing.lg),

                // Quick Stats
                _buildQuickStats(),
                const SizedBox(height: AppSpacing.lg),

                // My Activity Section
                _buildSectionHeader('My Activity'),
                const SizedBox(height: AppSpacing.sm),
                _buildActivityCard(),

                // Admin Dashboard Section (only for admins)
                if (_userRole != null && _userRole!.isAdmin) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildSectionHeader('Admin Access'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildAdminCard(),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Preferences Section
                _buildSectionHeader('Preferences'),
                const SizedBox(height: AppSpacing.sm),
                _buildPreferencesCard(isDark),
                const SizedBox(height: AppSpacing.lg),

                // Support Section
                _buildSectionHeader('Support'),
                const SizedBox(height: AppSpacing.sm),
                _buildSupportCard(),
                const SizedBox(height: AppSpacing.lg),

                // Danger Zone
                _buildSectionHeader('Account'),
                const SizedBox(height: AppSpacing.sm),
                _buildDangerZone(),
                const SizedBox(height: AppSpacing.lg),

                // App Version
                Center(
                  child: Text(
                    'SevaSetu v1.0.0',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        title,
        style: AppTextStyles.titleSmall.copyWith(color: AppColors.neutral500),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getUserFullName().isNotEmpty
                      ? _getUserFullName()[0].toUpperCase()
                      : 'U',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getUserFullName(),
                          style: AppTextStyles.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (_isVerified())
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _getUserEmail(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  // Role Badge
                  if (_userRole != null && _userRole!.isAdmin)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(_userRole!.role),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoleIcon(_userRole!.role),
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userRole!.role.displayName,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Edit Button
            IconButton(
              onPressed: () async {
                final result = await context.push(
                  '/edit-profile',
                  extra: _userData,
                );
                if (result == true) {
                  await _loadUserData();
                }
              },
              icon: Icon(
                CupertinoIcons.pencil,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: CupertinoIcons.star_fill,
            value: '60',
            label: 'Points',
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatItem(
            icon: CupertinoIcons.rosette,
            value: '1',
            label: 'Badges',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatItem(
            icon: CupertinoIcons.doc_text,
            value: '0',
            label: 'Reports',
            color: AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            icon: CupertinoIcons.doc_text,
            title: 'My Reports',
            subtitle: 'View all your submitted reports',
            onTap: () => context.push('/my-reports'),
          ),
          const Divider(height: 1, indent: 56),
          _buildListTile(
            icon: CupertinoIcons.arrow_up_circle,
            title: 'Upvoted Issues',
            subtitle: 'Issues you\'ve supported',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard() {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            icon: CupertinoIcons.chart_bar_square,
            title: 'Dashboard',
            subtitle: 'View analytics and manage issues',
            onTap: () => context.push('/dashboard'),
          ),
          if (_userRole!.role == AdminRole.worker) ...[
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: CupertinoIcons.person_badge_plus,
              title: 'My Tasks',
              subtitle: 'View your assigned issues',
              onTap: () => context.push('/worker-dashboard'),
            ),
          ],
          if (_userRole!.canManageUsers) ...[
            const Divider(height: 1, indent: 56),
            _buildListTile(
              icon: CupertinoIcons.person_3,
              title: 'Admin Panel',
              subtitle: 'Manage users and roles',
              onTap: () => context.push('/admin-dashboard'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(bool isDark) {
    return Card(
      child: Column(
        children: [
          _buildSwitchTile(
            icon: isDark
                ? CupertinoIcons.moon_fill
                : CupertinoIcons.sun_max_fill,
            title: 'Dark Mode',
            subtitle: isDark
                ? 'Currently using dark theme'
                : 'Currently using light theme',
            value: isDark,
            onChanged: (value) {
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: CupertinoIcons.bell_fill,
            title: 'Notifications',
            subtitle: 'Receive updates about your reports',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Notifications ${value ? "enabled" : "disabled"}',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildListTile(
            icon: CupertinoIcons.globe,
            title: 'Language',
            subtitle: 'English',
            trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
            onTap: () => _showLanguageSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            icon: CupertinoIcons.question_circle,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help center coming soon!')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildListTile(
            icon: CupertinoIcons.doc_plaintext,
            title: 'Privacy Policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon!')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildListTile(
            icon: CupertinoIcons.doc_text,
            title: 'Terms of Service',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            icon: CupertinoIcons.square_arrow_right,
            title: 'Sign Out',
            titleColor: AppColors.error,
            onTap: () async {
              await supabase.auth.signOut();
              if (mounted) {
                context.go('/auth');
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildListTile(
            icon: CupertinoIcons.trash,
            title: 'Delete Account',
            titleColor: AppColors.error,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (titleColor ?? Theme.of(context).colorScheme.primary)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          color: titleColor ?? Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral500,
              ),
            )
          : null,
      trailing:
          trailing ??
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.neutral400,
          ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral500),
      ),
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Language', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _buildLanguageOption('English', true),
            _buildLanguageOption('Hindi', false),
            _buildLanguageOption('Marathi', false),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isSelected) {
    return ListTile(
      title: Text(language, style: AppTextStyles.bodyLarge),
      trailing: isSelected
          ? Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success)
          : null,
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Language set to $language')));
      },
    );
  }

  IconData _getRoleIcon(AdminRole role) {
    switch (role) {
      case AdminRole.systemAdmin:
        return CupertinoIcons.shield_lefthalf_fill;
      case AdminRole.stateAdmin:
        return CupertinoIcons.building_2_fill;
      case AdminRole.departmentAdmin:
        return CupertinoIcons.briefcase_fill;
      case AdminRole.officeAdmin:
        return CupertinoIcons.location_solid;
      case AdminRole.worker:
        return CupertinoIcons.hammer_fill;
      case AdminRole.citizen:
        return CupertinoIcons.person_fill;
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
