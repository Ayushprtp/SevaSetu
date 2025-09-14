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
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

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
          .select('first_name, last_name, username, mobile_number, email')
          .eq('id', user.id)
          .single();
      
      setState(() {
        _userData = response as Map<String, dynamic>?;
        _firstNameController.text = _userData?['first_name'] ?? '';
        _lastNameController.text = _userData?['last_name'] ?? '';
        _usernameController.text = _userData?['username'] ?? '';
        _mobileNumberController.text = _userData?['mobile_number'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return;
      
      await supabase
          .from('users')
          .update({
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'username': _usernameController.text.trim(),
            'mobile_number': _mobileNumberController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
      
      // Reload user data
      await _loadUserProfile();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileNumberController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isEditing = false;
                            });
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
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
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _updateProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Medium',
                      fontSize: 20,
                    ),
                  ),
                  if (!_isEditing)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      child: const Text('Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditing)
                _buildEditForm()
              else
                _buildProfileView(),
              const SizedBox(height: 24),
              // My Reports Section
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
              
              // Preferences Section (from old SettingsPage)
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
              
              // Account Section (from old SettingsPage)
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
              
              // Danger Zone (from old SettingsPage)
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontFamily: 'SFProRounded Medium',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      color: Colors.red,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onTap: () {
                    // TODO: Implement account deletion
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account deletion not implemented')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // App Version (from old SettingsPage)
              const Center(
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