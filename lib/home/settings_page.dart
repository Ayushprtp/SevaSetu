import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier
import 'package:sevasetu/utils/app_styles.dart'; // Added import
import 'package:flutter/cupertino.dart'; // Added for CupertinoSliverNavigationBar

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
Map<String, dynamic>? _userData;
bool _isLoadingProfile = true; // New state variable for loading
final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final response = await supabase
          .from('users')
          .select('first_name, last_name, username')
          .eq('id', user.id)
          .single();

      setState(() {
        _userData = response as Map<String, dynamic>?;
        _isLoadingProfile = false; // Set loading to false after data is fetched
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data: $e')),
        );
      }
      setState(() {
        _isLoadingProfile = false; // Set loading to false even on error
      });
    }
  }

  String _getUserFullName() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] as String?;
      final lastName = _userData!['last_name'] as String?;
      final username = _userData!['username'] as String?;

      if (firstName != null && firstName.isNotEmpty) {
        return '$firstName ${lastName ?? ''}'.trim();
      } else if (username != null && username.isNotEmpty) {
        return username;
      }
    }
    return 'User';
  }

  String _getUserEmail() {
    return supabase.auth.currentUser?.email ?? 'user@example.com';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(
            'Settings',
            style: AppTextStyles.headlineMedium,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _isLoadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : _userData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 64,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Could not load profile data.',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please ensure you are logged in and try again.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _loadUserData,
                                  child: const Text('Retry Loading Profile'),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Section
                              Text(
                                'Profile',
                                style: AppTextStyles.titleLarge,
                              ),
                              SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(
                                    _getUserFullName(),
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  subtitle: Text(
                                    _getUserEmail(),
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    final result = await context.push('/edit-profile', extra: _userData);
                                    if (result == true) {
                                      await _loadUserData(); // Reload data if profile was updated
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Profile updated successfully!')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              SizedBox(height: 24),

                              // My Reports Section
                              Text(
                                'My Activity',
                                style: AppTextStyles.titleLarge,
                              ),
                              SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.assignment),
                                  title: const Text(
                                    'My Reports',
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    // Navigate to My Reports page
                                    context.push('/my-reports');
                                  },
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // Preferences Section
                              Text(
                                'Preferences',
                                style: AppTextStyles.titleLarge,
                              ),
                              SizedBox(height: 16),
                              Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: const Text(
                                        'Language',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      subtitle: const Text(
                                        'English',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        _showLanguageSelectionSheet(context);
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      title: const Text(
                                        'Dark Mode',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      trailing: Switch(
                                        value: Theme.of(context).brightness == Brightness.dark,
                                        onChanged: (value) {
                                          themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                                        },
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      title: const Text(
                                        'Notifications',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      trailing: Switch(
                                        value: true, // Placeholder for actual notification setting
                                        onChanged: (value) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Notifications ${value ? "enabled" : "disabled"} (placeholder)')),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // Account Section
                              Text(
                                'Account',
                                style: AppTextStyles.titleLarge,
                              ),
                              SizedBox(height: 16),
                              Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: const Text(
                                        'Privacy Policy',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Privacy Policy (placeholder)')),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      title: const Text(
                                        'Terms of Service',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Terms of Service (placeholder)')),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      title: const Text(
                                        'Help & Support',
                                        style: AppTextStyles.bodyLarge,
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Help & Support (placeholder)')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // Danger Zone
                              Text(
                                'Danger Zone',
                                style: AppTextStyles.titleLarge,
                              ),
                              SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  title: Text(
                                    'Delete Account',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: Colors.red,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Account deletion (placeholder)')),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // App Version
                              Center(
                                child: Text(
                                  'Version 1.0.0',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguageSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Language',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('English', style: AppTextStyles.bodyLarge),
                onTap: () {
                  // TODO: Implement actual language change logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language set to English')),
                  );
                },
              ),
              ListTile(
                title: const Text('Hindi', style: AppTextStyles.bodyLarge),
                onTap: () {
                  // TODO: Implement actual language change logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language set to Hindi')),
                  );
                },
              ),
              ListTile(
                title: const Text('Marathi', style: AppTextStyles.bodyLarge),
                onTap: () {
                  // TODO: Implement actual language change logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language set to Marathi')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}