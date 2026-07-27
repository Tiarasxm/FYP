import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/welcome_screen.dart';
import 'my_profile_page.dart';
import 'manage_account_page.dart';
import 'membership_page.dart';
import 'wearable_devices_page.dart';
import 'notifications_page.dart';
import 'feedback_page.dart';
import 'faq_page.dart';
import 'privacy_policy_page.dart';
import 'terms_conditions_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  String fullName = '';
  String email = '';
  String userType = 'free';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email, user_type')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();

      if (!mounted) return;
      setState(() {
        fullName = data['full_name'] as String? ?? '';
        email = data['email'] as String? ?? '';
        userType = data['user_type'] as String? ?? 'free';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              // ====================================
              // User information
              // ====================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey,

                          // 以后连接数据库图片：
                          // backgroundImage:
                          //     NetworkImage(user.profileImageUrl),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurpleAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  userType == 'priority' ? "PRIORITY" : "FREE",
                                  style: const TextStyle(
                                    color: Colors.deepPurpleAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ProfileStat(
                          number: "120",
                          label: "WORKOUTS",
                        ),
                        ProfileStat(
                          number: "30",
                          label: "DAY STREAK",
                        ),
                        ProfileStat(
                          number: "528",
                          label: "FOLLOWERS",
                        ),
                        ProfileStat(
                          number: "31",
                          label: "FOLLOWING",
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ====================================
              // Priority plan
              // ====================================
              if (userType == 'priority') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E5FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Priority Plan",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Cancel Priority and return\nto the free plan.",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _openPage(
                            context,
                            const MembershipPage(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],

              // ====================================
              // General
              // ====================================
              ProfileMenuSection(
                title: "GENERAL",
                items: [
                  ProfileMenuItem(
                    title: "My Profile",
                    onTap: () {
                      _openPage(
                        context,
                        const MyProfilePage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Manage Account",
                    onTap: () {
                      _openPage(
                        context,
                        const ManageAccountPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Membership",
                    onTap: () {
                      _openPage(
                        context,
                        const MembershipPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Wearable Devices",
                    onTap: () {
                      _openPage(
                        context,
                        const WearableDevicesPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Notifications",
                    onTap: () {
                      _openPage(
                        context,
                        const NotificationsPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Feedback",
                    onTap: () {
                      _openPage(
                        context,
                        const FeedbackPage(),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ====================================
              // Others
              // ====================================
              ProfileMenuSection(
                title: "OTHERS",
                items: [
                  ProfileMenuItem(
                    title: "FAQs",
                    onTap: () {
                      _openPage(
                        context,
                        const FaqPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Privacy Policy",
                    onTap: () {
                      _openPage(
                        context,
                        const PrivacyPolicyPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Terms & Conditions",
                    onTap: () {
                      _openPage(
                        context,
                        const TermsConditionsPage(),
                      );
                    },
                  ),
                  ProfileMenuItem(
                    title: "Logout",
                    showArrow: false,
                    titleColor: Colors.red,
                    trailing: const Icon(
                      Icons.logout,
                      size: 18,
                      color: Colors.red,
                    ),
                    onTap: () {
                      _showLogoutDialog(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// Profile statistics
// ==================================================
class ProfileStat extends StatelessWidget {
  final String number;
  final String label;

  const ProfileStat({
    super.key,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ==================================================
// Menu section
// ==================================================
class ProfileMenuSection extends StatelessWidget {
  final String title;
  final List<ProfileMenuItem> items;

  const ProfileMenuSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }
}

// ==================================================
// Menu item
// ==================================================
class ProfileMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool showArrow;
  final Color? titleColor;
  final Widget? trailing;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.showArrow = true,
    this.titleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(
          vertical: -2,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: titleColor,
          ),
        ),
        trailing: trailing ??
            (showArrow
                ? const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}
