import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:jansahayak/main.dart'; // Import main.dart to access themeNotifier
import 'package:flutter/cupertino.dart'; // Import for CupertinoSlidingSegmentedControl
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart'; // Import for awesome_snackbar_content

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Updated to use a Set for segmented control
  Set<AuthMode> _selectedAuthMode = {AuthMode.login};
  bool get _isLogin => _selectedAuthMode.first == AuthMode.login;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _idValueController = TextEditingController();

  String? _selectedIdType;
  final List<String> _idTypeOptions = [
    'Passport',
    'Aadhar Card',
    'Driving License',
    'Voter ID',
    'Pan Card',
    'Ration Card',
    'Marksheet'
  ];

  final SupabaseClient supabase = Supabase.instance.client;
  bool _obscureText = true; // State variable for password visibility

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _mobileNumberController.dispose();
    _idValueController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        _getRoleAndNavigate();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: e.message,
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'An unexpected error occurred: $e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  Future<void> _signUp() async {
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Insert additional profile data
        await supabase.from('profiles').update({
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'mobile_number': _mobileNumberController.text.trim(),
          'id_type': _selectedIdType,
          'id_value': _idValueController.text.trim(),
        }).eq('id', response.user!.id);
      }

      if (mounted) {
        _getRoleAndNavigate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Success',
              message: 'Sign up successful! Please check your email for confirmation.',
              contentType: ContentType.success,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: e.message,
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'An unexpected error occurred: $e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  Future<void> _getRoleAndNavigate() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'User is not logged in.',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final role = response['role'] as String?;

      if (!mounted) return;

      if (role == 'admin') {
        context.go('/admin');
      } else if (role == 'user') {
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Unknown role: $role',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'Error fetching role: $e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    try {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              content: AwesomeSnackbarContent(
                title: 'Info',
                message: 'Please enter your email to reset password.',
                contentType: ContentType.help,
              ),
            ),
          );
        }
        return;
      }
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Success',
              message: 'Password reset email sent. Please check your inbox.',
              contentType: ContentType.success,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: e.message,
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Error',
              message: 'An unexpected error occurred: $e',
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Center the content
                children: <Widget>[
                  const SizedBox(height: 40.0), // Space from top
                  const Text(
                    'JanSahayak',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple, // A prominent color
                      fontFamily: 'SFProRounded Bold',
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  CupertinoSlidingSegmentedControl<AuthMode>(
                    groupValue: _selectedAuthMode.first,
                    backgroundColor: Theme.of(context).cardColor.withAlpha(5),
                    thumbColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.all(8),
                    children: <AuthMode, Widget>{
                      AuthMode.login: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: _isLogin ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontFamily: 'SFProRounded Medium',
                          ),
                        ),
                      ),
                      AuthMode.signup: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: !_isLogin ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontFamily: 'SFProRounded Medium',
                          ),
                        ),
                      ),
                    },
                    onValueChanged: (AuthMode? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedAuthMode = {newValue};
                          _emailController.clear();
                          _passwordController.clear();
                          _firstNameController.clear();
                          _lastNameController.clear();
                          _usernameController.clear();
                          _mobileNumberController.clear();
                          _idValueController.clear();
                          _selectedIdType = null;
                          _obscureText = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 30.0),
                  if (!_isLogin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              hintText: 'Enter your first name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Enter your last name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Choose a username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    TextField(
                      controller: _mobileNumberController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter your mobile number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20.0),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedIdType,
                            hint: const Text('Select ID Type'),
                            isExpanded: true, // Make dropdown take full width
                            dropdownColor: Theme.of(context).cardColor.withOpacity(0.9), // Different shade
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.assignment_ind),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12), // Consistent padding
                            ),
                            items: _idTypeOptions
                                .map((String idType) => DropdownMenuItem<String>(
                                      value: idType,
                                      child: Text(idType),
                                    ))
                                .toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedIdType = newValue;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _idValueController,
                            decoration: InputDecoration(
                              labelText: 'ID Value',
                              hintText: 'Enter ID value',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.format_list_numbered),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureText, // Use the state variable here
                  ),
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(fontFamily: 'SFProRounded Regular'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30.0),
                  ElevatedButton(
                    onPressed: _isLogin ? _signIn : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isLogin ? 'Login' : 'Sign Up',
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'SFProRounded Regular',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  if (_isLogin) ...[ // Only show "OR LOGIN WITH" and Google button if on login page
                    Row(
                      children: <Widget>[
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            'OR LOGIN WITH',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'SFProRounded Regular',
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement Google Sign-In
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            elevation: 0,
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.transparent,
                            content: AwesomeSnackbarContent(
                              title: 'Info',
                              message: 'Google Sign-In not implemented yet.',
                              contentType: ContentType.help,
                            ),
                          ),
                        );
                      },
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                        height: 24.0,
                      ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'SFProRounded Regular',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: IconButton(
              icon: Icon(Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode),
              onPressed: () {
                themeNotifier.value =
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
              tooltip: 'Toggle Theme',
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthMode { login, signup }