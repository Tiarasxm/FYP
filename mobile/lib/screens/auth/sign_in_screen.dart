import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../widgets/professional/required_label.dart';

import '../client/client_shell.dart';
import '../client/onboarding_screen.dart';
import '../professional/professional_shell.dart';
import '../../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const String _googleLoginRedirectUrl =
      'io.supabase.flutter://login-callback/';
  static const String _passwordResetRedirectUrl =
      'io.supabase.flutter://reset-callback/';

  bool hidePassword = true;
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;

  bool isLoading = false;
  bool _isRouting = false;
  bool _isPasswordRecoveryMode = false;
  bool _resetEmailSent = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (!mounted) return;

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          isLoading = false;
          _isPasswordRecoveryMode = true;
          _resetEmailSent = false;
          hideNewPassword = true;
          hideConfirmPassword = true;
          newPasswordController.clear();
          confirmPasswordController.clear();
        });

        showSuccess('Please create a new password.');
        return;
      }

      if (event == AuthChangeEvent.signedIn) {
        if (_isPasswordRecoveryMode) return;

        final User? user = session?.user;
        if (user != null) {
          await _handleSignedInUser(user);
        }
      }
    });
  }

  Future<void> signIn() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showError('Please enter email and password.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final AuthResponse authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final User? user = authResponse.user;

      if (user == null) {
        await supabase.auth.signOut();
        showError('Login failed. Please try again.');
        return;
      }

      await _handleSignedInUser(user);
    } on AuthException catch (error) {
      showError(error.message);
    } catch (error) {
      showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> signInWithGoogle() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _googleLoginRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      showError(error.message);
    } catch (error) {
      showError('Google login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignedInUser(User user) async {
    if (_isRouting) return;
    _isRouting = true;

    try {
      Map<String, dynamic>? profile = await supabase
          .from('profiles')
          .select('user_type, status, has_completed_onboarding')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await _createDefaultClientProfile(user);

        profile = await supabase
            .from('profiles')
            .select('user_type, status, has_completed_onboarding')
            .eq('id', user.id)
            .maybeSingle();
      }

      if (profile == null) {
        await supabase.auth.signOut();
        showError('No profile found for this account.');
        return;
      }

      final String status =
          profile['status']?.toString().trim().toLowerCase() ?? 'active';

      if (status == 'deleted') {
        await supabase.auth.signOut();
        showError('This account has been deleted.');
        return;
      }

      final String userType =
          profile['user_type']?.toString().trim().toLowerCase() ?? '';

      if (!mounted) return;

      if (userType == 'fitness professional') {
        final Map<String, dynamic>? proData = await supabase
            .from('fitness_professional')
            .select('approved')
            .eq('profile_id', user.id)
            .maybeSingle();

        final bool approved = proData?['approved'] == true;

        if (!approved) {
          await supabase.auth.signOut();
          showError('Your application is pending admin approval.');
          return;
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfessionalShell(),
          ),
          (route) => false,
        );
      } else if (userType == 'free' || userType == 'priority') {
        final bool hasCompletedOnboarding =
            profile['has_completed_onboarding'] == true;

        if (!mounted) return;

        if (hasCompletedOnboarding) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const ClientShell(),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        await supabase.auth.signOut();
        showError('This account type cannot log in to the mobile app.');
      }
    } catch (error) {
      if (!mounted) return;
      showError('Failed to load account profile. Please try again.');
    } finally {
      _isRouting = false;
    }
  }

  Future<void> _createDefaultClientProfile(User user) async {
    final String email = user.email?.trim() ?? '';
    final Map<String, dynamic> metadata = user.userMetadata ?? {};

    final String? fullName = _metadataValue(metadata, ['full_name', 'name']);
    final String? avatarUrl = _metadataValue(metadata, ['avatar_url', 'picture']);

    await supabase.from('profiles').upsert({
      'id': user.id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'user_type': 'free',
      'status': 'active',
      'has_completed_onboarding': false,
    });
  }

  String? _metadataValue(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Future<void> forgotPassword() async {
    if (isLoading) return;

    final String email = emailController.text.trim();

    if (email.isEmpty) {
      showError('Please enter your email first.');
      return;
    }

    setState(() {
      isLoading = true;
      _resetEmailSent = false;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _passwordResetRedirectUrl,
      );

      if (!mounted) return;

      setState(() {
        _resetEmailSent = true;
      });

      showSuccess('Password reset email sent. Please check your inbox.');
    } on AuthException catch (error) {
      showError(error.message);
    } catch (error) {
      showError('Failed to send reset email. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> updatePassword() async {
    if (isLoading) return;

    final String newPassword = newPasswordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      showError('Please enter your new password.');
      return;
    }

    if (newPassword.length < 6) {
      showError('Password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      showError('Passwords do not match.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      await supabase.auth.signOut();

      if (!mounted) return;

      setState(() {
        _isPasswordRecoveryMode = false;
        _resetEmailSent = false;
        newPasswordController.clear();
        confirmPasswordController.clear();
        passwordController.clear();
      });

      showSuccess('Password updated. Please sign in again.');
    } on AuthException catch (error) {
      showError(error.message);
    } catch (error) {
      showError('Failed to update password. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelPasswordRecovery() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    setState(() {
      _isPasswordRecoveryMode = false;
      _resetEmailSent = false;
      newPasswordController.clear();
      confirmPasswordController.clear();
    });
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecoveryMode) {
      return _buildPasswordRecoveryPage(context);
    }

    return _buildSignInPage(context);
  }

  Widget _buildSignInPage(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            34,
            0,
            34,
            MediaQuery.of(context).viewInsets.bottom + 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.cardMuted,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Let’s sign in to your ShapeRush account.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 34),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isLoading ? null : signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.border,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/google_logo.png'),
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3C4043),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 34),

              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.border,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.border,
                      thickness: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const RequiredLabel(text: 'Email'),

              const SizedBox(height: 10),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const RequiredLabel(text: 'Password'),

              const SizedBox(height: 10),

              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              if (_resetEmailSent) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Password reset email sent. Please check your inbox.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 22),

              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : forgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRecoveryPage(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            34,
            0,
            34,
            MediaQuery.of(context).viewInsets.bottom + 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.cardMuted,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isLoading ? null : _cancelPasswordRecovery,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Create New Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter a new password for your ShapeRush account.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 34),

              const RequiredLabel(text: 'New Password'),

              const SizedBox(height: 10),

              TextField(
                controller: newPasswordController,
                obscureText: hideNewPassword,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              hideNewPassword = !hideNewPassword;
                            });
                          },
                    icon: Icon(
                      hideNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const RequiredLabel(text: 'Confirm Password'),

              const SizedBox(height: 10),

              TextField(
                controller: confirmPasswordController,
                obscureText: hideConfirmPassword,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Confirm new password',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              hideConfirmPassword = !hideConfirmPassword;
                            });
                          },
                    icon: Icon(
                      hideConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 22),

              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : _cancelPasswordRecovery,
                  child: const Text(
                    'Back to Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
