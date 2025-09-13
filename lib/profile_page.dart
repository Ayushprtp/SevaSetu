import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jansahayak/main.dart'; // Import main.dart to access themeNotifier
import 'package:go_router/go_router.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _getUserFullName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Extract name from email if no user data is available
      final email = user.email ?? '';
      final name = email.split('@').first;
      return name.isNotEmpty ? name : 'User';
    }
    return 'User';
  }

  String _getUserEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email ?? 'user@example.com';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Text(
                'Profile Information',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    _getUserFullName(),
                    style: TextStyle(fontFamily: 'SFProRounded Medium'),
                  ),
                  subtitle: Text(
                    _getUserEmail(),
                    style: TextStyle(fontFamily: 'SFProRounded Regular'),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement profile editing
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Profile editing not implemented')),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),

              // My Reports Section
              Text(
                'My Activity',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text(
                    'My Reports',
                    style: TextStyle(fontFamily: 'SFProRounded Regular'),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to My Reports page
                    context.push('/my-reports');
                  },
                ),
              ),
              SizedBox(height: 24),
              
              // Preferences Section (from old SettingsPage)
              Text(
                'Preferences',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Language',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      subtitle: Text(
                        'English',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement language selection
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Language selection not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
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
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Notifications',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Switch(
                        value: true, // TODO: Implement actual notification setting
                        onChanged: (value) {
                          // TODO: Implement notification setting
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notification settings not implemented')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Account Section (from old SettingsPage)
              Text(
                'Account',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Privacy Policy',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement privacy policy
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Privacy policy not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Terms of Service',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement terms of service
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Terms of service not implemented')),
                        );
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Help & Support',
                        style: TextStyle(fontFamily: 'SFProRounded Regular'),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: Implement help & support
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Help & support not implemented')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Danger Zone (from old SettingsPage)
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      color: Colors.red,
                    ),
                  ),
                  trailing: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onTap: () {
                    // TODO: Implement account deletion
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Account deletion not implemented')),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              
              // App Version (from old SettingsPage)
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}