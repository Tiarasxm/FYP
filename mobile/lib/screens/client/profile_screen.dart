import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../auth/welcome_screen.dart';
import 'my_profile_page.dart';
import 'manage_account_page.dart';
import 'membership_page.dart';
import 'wearable_devices_page.dart';
import 'notifications_page.dart';
import 'follow_requests_screen.dart';
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
  String avatarUrl = '';

  DateTime? _priorityUntil;
  bool _isCancelling = false;

  int completedExercises = 0;
  int dayStreak = 0;
  int followers = 0;
  int following = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in.');
      }

      final profileResponse = await client
          .from('profiles')
          .select('full_name, email, user_type, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final profile = profileResponse ?? <String, dynamic>{};

      final stats = await _loadProfileStats(user.id);

      final userTypeValue =
          profile['user_type']?.toString().trim().toLowerCase() ?? 'free';

      DateTime? priorityUntil;
      bool isCancelling = false;

      if (userTypeValue == 'priority') {
        final priorityResponse = await client
            .from('priority_user')
            .select('subscribed_at, expires_at')
            .eq('profile_id', user.id)
            .maybeSingle();

        final expiresAt =
            DateTime.tryParse(priorityResponse?['expires_at']?.toString() ?? '');

        if (expiresAt != null) {
          priorityUntil = expiresAt;
          isCancelling = expiresAt.isAfter(DateTime.now());
        } else {
          final subscribedAt =
              DateTime.tryParse(priorityResponse?['subscribed_at']?.toString() ?? '');
          if (subscribedAt != null) {
            priorityUntil = DateTime(
              subscribedAt.year,
              subscribedAt.month + 1,
              subscribedAt.day,
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        fullName = profile['full_name']?.toString().trim() ?? '';
        email = profile['email']?.toString().trim() ?? user.email ?? '';
        userType = profile['user_type']?.toString().trim() ?? 'free';
        avatarUrl = profile['avatar_url']?.toString().trim() ?? '';
        _priorityUntil = priorityUntil;
        _isCancelling = isCancelling;

        if (fullName.isEmpty) {
          fullName = email.isNotEmpty ? email.split('@').first : 'User';
        }

        completedExercises = stats.completedExercises;
        dayStreak = stats.dayStreak;
        followers = stats.followers;
        following = stats.following;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<_ProfileStatsData> _loadProfileStats(String userId) async {
    final client = Supabase.instance.client;

    int completed = 0;
    int streak = 0;
    int followerCount = 0;
    int followingCount = 0;

    try {
      final workoutLogsResponse = await client
          .from('workout_logs')
          .select('workout_log_id, performed_at')
          .eq('profile_id', userId)
          .order('performed_at', ascending: false);

      final workoutLogs =
          List<Map<String, dynamic>>.from(workoutLogsResponse as List);

      final workoutLogIds = workoutLogs
          .map((row) => row['workout_log_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (workoutLogIds.isNotEmpty) {
        final workoutExercisesResponse = await client
            .from('workout_exercises')
            .select('workout_log_id, exercise_id')
            .inFilter('workout_log_id', workoutLogIds);

        final workoutExercises =
            List<Map<String, dynamic>>.from(workoutExercisesResponse as List);

        final completedExerciseKeys = <String>{};
        final validWorkoutLogIds = <String>{};

        for (final row in workoutExercises) {
          final workoutLogId = row['workout_log_id']?.toString();
          final exerciseId = row['exercise_id']?.toString();

          if (workoutLogId == null ||
              workoutLogId.isEmpty ||
              exerciseId == null ||
              exerciseId.isEmpty) {
            continue;
          }

          completedExerciseKeys.add('$workoutLogId-$exerciseId');
          validWorkoutLogIds.add(workoutLogId);
        }

        completed = completedExerciseKeys.length;

        final completedDateKeys = <String>{};

        for (final log in workoutLogs) {
          final workoutLogId = log['workout_log_id']?.toString();

          if (workoutLogId == null || !validWorkoutLogIds.contains(workoutLogId)) {
            continue;
          }

          final performedAt = DateTime.tryParse(
            log['performed_at']?.toString() ?? '',
          );

          if (performedAt == null) continue;

          final local = performedAt.toLocal();
          completedDateKeys.add(_dateKey(local));
        }

        streak = _calculateStreak(completedDateKeys);
      }
    } catch (_) {
      completed = 0;
      streak = 0;
    }

    try {
      final followersResponse = await client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      followerCount = (followersResponse as List).length;
    } catch (_) {
      followerCount = 0;
    }

    try {
      final followingResponse = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      followingCount = (followingResponse as List).length;
    } catch (_) {
      followingCount = 0;
    }

    return _ProfileStatsData(
      completedExercises: completed,
      dayStreak: streak,
      followers: followerCount,
      following: followingCount,
    );
  }

  int _calculateStreak(Set<String> completedDateKeys) {
    if (completedDateKeys.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime? cursor;

    if (completedDateKeys.contains(_dateKey(today))) {
      cursor = today;
    } else if (completedDateKeys.contains(_dateKey(yesterday))) {
      cursor = yesterday;
    } else {
      return 0;
    }

    int count = 0;

    while (completedDateKeys.contains(_dateKey(cursor!))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return count;
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Future<void> _openMyProfilePage() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const MyProfilePage(),
      ),
    );

    if (changed == true && mounted) {
      await _loadProfile();
    }
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

  String get _membershipText {
    return userType.toLowerCase() == 'priority' ? 'PRIORITY' : 'FREE';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.cardMuted,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 32,
                                    color: AppColors.textMuted,
                                  )
                                : null,
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
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _membershipText,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
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
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ProfileStat(
                            number: "$completedExercises",
                            label: "EXERCISES",
                          ),
                          ProfileStat(
                            number: "$dayStreak",
                            label: "DAY STREAK",
                          ),
                          ProfileStat(
                            number: "$followers",
                            label: "FOLLOWERS",
                          ),
                          ProfileStat(
                            number: "$following",
                            label: "FOLLOWING",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (userType.toLowerCase() == 'priority') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_isCancelling)
                                Text(
                                  _priorityUntil != null
                                      ? "Your subscription ends on ${_formatDate(_priorityUntil!)}. Renew to keep your benefits."
                                      : "Your subscription is being cancelled.",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                )
                              else
                                Text(
                                  _priorityUntil != null
                                      ? "Next billing date: ${_formatDate(_priorityUntil!)}"
                                      : "Manage your Priority subscription.",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
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
                          child: Text(_isCancelling ? "Renew" : "Manage"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (userType.toLowerCase() == 'free') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Upgrade to Priority",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Unlock advanced features, additional insights and enhanced membership benefits.",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
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
                          child: const Text("Upgrade"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ProfileMenuSection(
                  title: "GENERAL",
                  items: [
                    ProfileMenuItem(
                      title: "My Profile",
                      onTap: _openMyProfilePage,
                    ),
                    ProfileMenuItem(
                      title: "Follow Requests",
                      onTap: () {
                        _openPage(
                          context,
                          const FollowRequestsScreen(),
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
      ),
    );
  }
}

class _ProfileStatsData {
  final int completedExercises;
  final int dayStreak;
  final int followers;
  final int following;

  const _ProfileStatsData({
    required this.completedExercises,
    required this.dayStreak,
    required this.followers,
    required this.following,
  });
}

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
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

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
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
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