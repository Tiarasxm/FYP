import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController currentPasswordController =
      TextEditingController();

  final TextEditingController newPasswordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool hideCurrentPassword = true;
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;

  bool isSubmitting = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage("Please fill in all password fields.");
      return;
    }

    if (newPassword.length < 8) {
      _showMessage(
        "New password must contain at least 8 characters.",
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage(
        "New password and confirm password do not match.",
      );
      return;
    }

    if (currentPassword == newPassword) {
      _showMessage(
        "New password must be different from the current password.",
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final email = user?.email;

      if (user == null || email == null || email.isEmpty) {
        throw Exception('User email was not found.');
      }

      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      _showMessage("Password changed successfully.");

      Navigator.pop(context);
    } on AuthException catch (error) {
      if (!mounted) return;

      if (error.message.toLowerCase().contains('invalid')) {
        _showMessage('Current password is incorrect.');
      } else {
        _showMessage('Unable to change password: ${error.message}');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        "Unable to change password: $error",
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _CircleBackButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Change Password",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      PasswordInputField(
                        label: "Current Password",
                        hintText: "Enter current password",
                        controller: currentPasswordController,
                        obscureText: hideCurrentPassword,
                        onToggleVisibility: () {
                          setState(() {
                            hideCurrentPassword = !hideCurrentPassword;
                          });
                        },
                      ),
                      PasswordInputField(
                        label: "New Password",
                        hintText: "Enter new password",
                        controller: newPasswordController,
                        obscureText: hideNewPassword,
                        onToggleVisibility: () {
                          setState(() {
                            hideNewPassword = !hideNewPassword;
                          });
                        },
                      ),
                      PasswordInputField(
                        label: "Confirm Password",
                        hintText: "Confirm new password",
                        controller: confirmPasswordController,
                        obscureText: hideConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            hideConfirmPassword = !hideConfirmPassword;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Change Password",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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

class PasswordInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  const PasswordInputField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscureText,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F3FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              suffixIcon: IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CircleBackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FC),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}