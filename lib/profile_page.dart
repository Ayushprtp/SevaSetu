import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  int _userReportCount = 0;

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
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
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
                        style: const TextStyle(
                          fontFamily: 'SFProRounded Medium',
                          fontSize: 20,
                        ),
                      ),
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          style: const TextStyle(
                            fontFamily: 'SFProRounded Regular',
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'SFProRounded Regular',
                          color: Colors.grey,
                        ),
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
                    style: const TextStyle(
                      fontFamily: 'SFProRounded Regular',
                    ),
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
                      style: TextStyle(
                        fontFamily: 'SFProRounded Medium',
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$_userReportCount',
                          style: const TextStyle(
                            fontFamily: 'SFProRounded Medium',
                            fontSize: 16,
                          ),
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
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
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
            child: const Text('Edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            const Text(
              'Profile Information',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileView(),
            const SizedBox(height: 24),
            
            // My Activity Section
            const Text(
              'My Activity',
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text(
                  'My Reports',
                  style: TextStyle(fontFamily: 'SFProRounded Regular'),
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
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Language',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    subtitle: const Text(
                      'English',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implement language selection
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Language selection not implemented')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
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
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    trailing: Switch(
                      value: true, // TODO: Implement actual notification setting
                      onChanged: (value) {
                        // TODO: Implement notification setting
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification settings not implemented')),
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
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implement privacy policy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Privacy policy not implemented')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      'Terms of Service',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implement terms of service
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Terms of service not implemented')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      'Help & Support',
                      style: TextStyle(fontFamily: 'SFProRounded Regular'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // TODO: Implement help & support
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Help & support not implemented')),
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
}