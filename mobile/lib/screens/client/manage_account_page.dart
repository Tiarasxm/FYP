import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/welcome_screen.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';
import '../../theme/app_theme.dart';

class ManageAccountPage extends StatelessWidget {
  const ManageAccountPage({super.key});

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text(
            "Are you sure you want to log out?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _logout(context);
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        "Manage Account",
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
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Security",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    _AccountMenuItem(
                      title: "Change Password",
                      onTap: () {
                        _openPage(
                          context,
                          const ChangePasswordPage(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Account",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    _AccountMenuItem(
                      title: "Delete Account",
                      titleColor: Colors.red,
                      onTap: () {
                        _openPage(
                          context,
                          const DeleteAccountPage(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                      fontSize: 12,
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

class _AccountMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;

  const _AccountMenuItem({
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(
        vertical: -2,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: titleColor,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 13,
      ),
      onTap: onTap,
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