import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier
import 'package:sevasetu/utils/app_styles.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  int _userReportCount = 0;
  bool _isLoadingProfile = true; // New state variable for loading

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
      
      // Fetch user data
      final response = await supabase
          .from('users')
          .select('first_name, last_name, username, mobile_number, email')
          .eq('id', user.id)
          .single();
      
      // Fetch user report count
      final reportCountResponse = await supabase
          .from('civic_issues')
          .select('id')
          .eq('user_id', user.id);
      
      final count = reportCountResponse.length;
      
      setState(() {
        _userData = response as Map<String, dynamic>?;
        _userReportCount = count;
        _isLoadingProfile = false; // Set loading to false after data is fetched
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
      setState(() {
        _isLoadingProfile = false; // Set loading to false even on error
      });
    }
  }

  Widget _buildProfileView() {
    final firstName = _userData?['first_name'] ?? '';
    final lastName = _userData?['last_name'] ?? '';
    final username = _userData?['username'] ?? '';
    final email = _userData?['email'] ?? '';
    final mobileNumber = _userData?['mobile_number'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : username,
                        style: AppTextStyles.titleMedium,
                      ),
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                        ),
                      Text(
                        email,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (mobileNumber.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    mobileNumber,
                    style: AppTextStyles.bodyLarge,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Display report count and make it tappable
            GestureDetector(
              onTap: () {
                // Navigate to My Reports page
                context.push('/my-reports');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Reports',
                      style: AppTextStyles.titleSmall,
                    ),
                    Row(
                      children: [
                        Text(
                          '$_userReportCount',
                          style: AppTextStyles.titleSmall,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: AppTextStyles.titleMedium,
        ),
        actions: [
          TextButton(
            onPressed: _isLoadingProfile
                ? null
                : () async {
                    // Navigate to edit profile page and wait for result
                    final result = await context.push('/edit-profile', extra: _userData);
                    // If result is true, it means profile was updated successfully
                    if (result == true) {
                      // Reload user data to reflect changes
                      await _loadUserProfile();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!')),
                        );
                      }
                    }
                  },
            child: _isLoadingProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Edit', style: AppTextStyles.button),
          ),
        ],
      ),
      body: _isLoadingProfile
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
                        onPressed: _loadUserProfile,
                        child: const Text('Retry Loading Profile'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      const Text(
                        'Profile Information',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileView(),
                      const SizedBox(height: 24),
                      
                      // My Activity Section
                      const Text(
                        'My Activity',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      
                      // Preferences Section
                      const Text(
                        'Preferences',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 16),
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
                                style: AppTextStyles.bodyLarge,
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
                      const SizedBox(height: 24),
                      
                      // Account Section
                      const Text(
                        'Account',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
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