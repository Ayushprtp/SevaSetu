import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sevasetu/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
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
    'Marksheet',
  ];

  final SupabaseClient supabase = Supabase.instance.client;
  bool _obscureText = true;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? 'YOUR_WEB_CLIENT_ID' : null,
  );

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _mobileNumberController.dispose();
    _idValueController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnackBar('Please fill in all fields', ContentType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        _getRoleAndNavigate();
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, ContentType.failure);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', ContentType.failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty) {
      _showSnackBar('Please fill in all required fields', ContentType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        await supabase.from('users').upsert({
          'id': response.user!.id,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'mobile_number': _mobileNumberController.text.trim(),
          'id_type': _selectedIdType,
          'id_value': _idValueController.text.trim(),
        });
      }

      if (mounted) {
        _getRoleAndNavigate();
        _showSnackBar(
          'Sign up successful! Please check your email for confirmation.',
          ContentType.success,
        );
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, ContentType.failure);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', ContentType.failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getRoleAndNavigate() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('User is not logged in.', ContentType.failure);
      return;
    }

    try {
      await supabase.from('users').select('id').eq('id', user.id).single();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      _showSnackBar('Error fetching role: $e', ContentType.failure);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(
        'Please enter your email to reset password.',
        ContentType.help,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.sevasetu://reset-callback/',
      );
      _showSnackBar(
        'Password reset email sent. Please check your inbox.',
        ContentType.success,
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message, ContentType.failure);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', ContentType.failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        _showSnackBar('Google authentication failed.', ContentType.failure);
        return;
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        _getRoleAndNavigate();
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, ContentType.failure);
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred during Google Sign-In: $e',
        ContentType.failure,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, ContentType contentType) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: contentType == ContentType.success
              ? 'Success'
              : contentType == ContentType.failure
              ? 'Error'
              : contentType == ContentType.warning
              ? 'Warning'
              : 'Info',
          message: message,
          contentType: contentType,
        ),
      ),
    );
  }

  void _switchAuthMode(AuthMode? newValue) {
    if (newValue == null) return;
    _animationController.reverse().then((_) {
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
      _animationController.forward();
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.neutral200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.backgroundLight, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: AppSpacing.xl),

                        // Logo and title
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ).createShader(bounds),
                          child: Text(
                            'SevaSetu',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'Connecting Citizens to Solutions',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Auth mode toggle
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoSlidingSegmentedControl<AuthMode>(
                            groupValue: _selectedAuthMode.first,
                            backgroundColor: isDark
                                ? AppColors.neutral800
                                : AppColors.neutral200,
                            thumbColor: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                            padding: const EdgeInsets.all(4),
                            children: <AuthMode, Widget>{
                              AuthMode.login: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Login',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: _isLogin
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.neutral400
                                              : AppColors.neutral600),
                                    fontWeight: _isLogin
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              AuthMode.signup: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Sign Up',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: !_isLogin
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.neutral400
                                              : AppColors.neutral600),
                                    fontWeight: !_isLogin
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            },
                            onValueChanged: _switchAuthMode,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Form fields
                        if (!_isLogin) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'Enter first name',
                                  icon: Icons.person_rounded,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Enter last name',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Choose a username',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildTextField(
                            controller: _mobileNumberController,
                            label: 'Mobile Number',
                            hint: 'Enter mobile number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedIdType,
                                    hint: Text(
                                      'ID Type',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    isExpanded: true,
                                    dropdownColor: Theme.of(context).cardColor,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.neutral200,
                                          width: 1,
                                        ),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.badge_rounded,
                                        color: AppColors.primary,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                    ),
                                    items: _idTypeOptions
                                        .map(
                                          (String idType) =>
                                              DropdownMenuItem<String>(
                                                value: idType,
                                                child: Text(
                                                  idType,
                                                  style:
                                                      AppTextStyles.bodyMedium,
                                                ),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: (String? newValue) {
                                      setState(
                                        () => _selectedIdType = newValue,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  controller: _idValueController,
                                  label: 'ID Number',
                                  hint: 'Enter ID number',
                                  icon: Icons.numbers_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Enter your email',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_rounded,
                          obscureText: _obscureText,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppColors.neutral400,
                            ),
                            onPressed: () =>
                                setState(() => _obscureText = !_obscureText),
                          ),
                        ),

                        if (_isLogin) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              child: Text(
                                'Forgot Password?',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.lg),

                        // Submit button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_isLogin ? _signIn : _signUp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Login' : 'Create Account',
                                    style: AppTextStyles.button.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        if (_isLogin) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: AppColors.neutral300),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  'OR',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.neutral400,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: AppColors.neutral300),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Google sign in button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.neutral200),
                              color: Theme.of(context).cardColor,
                            ),
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              label: Text(
                                'Continue with Google',
                                style: AppTextStyles.button.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.neutral700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),

              // Theme toggle - Bottom Left Corner
              Align(
                alignment: AlignmentGeometry.bottomLeft,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.neutral800 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? AppColors.neutral700
                          : AppColors.neutral200,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark ? AppColors.accent : AppColors.primary,
                    ),
                    onPressed: () {
                      themeNotifier.value = isDark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                    tooltip: isDark
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
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

enum AuthMode { login, signup }
