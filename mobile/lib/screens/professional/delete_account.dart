import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import '../auth/welcome_screen.dart';

class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  bool isLoading = false;

  Future<void> confirmAndDeleteAccount() async {
    if (isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This will permanently deactivate your account. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('You must be signed in.');
      }

      // ── Clean up all user data ──
      // Social
      await _safeDelete(client, 'post_likes', 'user_id', userId);
      await _safeDelete(client, 'post_comments', 'user_id', userId);
      await _safeDelete(client, 'posts', 'user_id', userId);
      await _safeDelete(client, 'follows', 'follower_id', userId);
      await _safeDelete(client, 'follows', 'following_id', userId);

      // Chat: delete all messages in rooms where user is a participant, then rooms
      await _deleteChatMessagesForRooms(client, userId, 'professional_id');
      await _deleteChatMessagesForRooms(client, userId, 'client_id');
      await _safeDelete(client, 'chat_messages', 'sender_id', userId);
      await _safeDelete(client, 'chat_tags', 'professional_id', userId);
      await _safeDelete(client, 'chat_rooms', 'professional_id', userId);
      await _safeDelete(client, 'chat_rooms', 'client_id', userId);

      // Plans & logs (as client)
      await _safeDelete(client, 'saved_plans', 'profile_id', userId);
      await _safeDelete(client, 'workout_logs', 'profile_id', userId);
      await _safeDelete(client, 'meal_logs', 'profile_id', userId);
      await _safeDelete(client, 'water_logs', 'profile_id', userId);
      await _safeDelete(client, 'water_settings', 'profile_id', userId);

      // Reviews (as reviewer and as professional)
      await _safeDelete(client, 'reviews', 'reviewer_id', userId);
      await _safeDelete(client, 'reviews', 'professional_id', userId);

      // Reports
      await _safeDelete(client, 'reports', 'reporter_id', userId);
      await _safeDelete(client, 'reports', 'reported_user_id', userId);

      // Notifications
      await _safeDelete(client, 'notification_settings', 'profile_id', userId);
      await _safeDelete(client, 'notification_reminders', 'profile_id', userId);

      // Health
      await _safeDelete(client, 'daily_health_metrics', 'profile_id', userId);
      await _safeDelete(client, 'wearable_connections', 'profile_id', userId);

      // Feedback
      await _safeDelete(client, 'app_feedback', 'profile_id', userId);

      // Priority
      await _safeDelete(client, 'priority_user', 'profile_id', userId);

      // ── Professional-specific cleanup ──
      // Exercise library
      await _safeDelete(client, 'exercise_library', 'professional_id', userId);

      // Free plans: delete plan_days first, then free_plans
      await _deletePlanDaysForProfessional(client, userId);
      await _safeDelete(client, 'free_plans', 'professional_id', userId);

      // Personalized plans: delete personalized_plan_days first, then personalized_plans
      await _deletePersonalizedPlanDaysForProfessional(client, userId);
      await _safeDelete(client, 'personalized_plans', 'professional_id', userId);

      // Fitness professional profile
      await _safeDelete(client, 'fitness_professional', 'profile_id', userId);

      // Storage: delete avatar and certifications
      await _safeDeleteStorage(client, 'profile-avatars', userId);
      await _safeDeleteStorage(client, 'certifications', userId);

      // Soft-delete the profile
      await client.from('profiles').update({
        'status': 'deleted',
      }).eq('id', userId);

      await client.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _safeDelete(
    SupabaseClient client,
    String table,
    String column,
    String userId,
  ) async {
    try {
      await client.from(table).delete().eq(column, userId);
    } catch (_) {
      // Continue even if one table fails
    }
  }

  Future<void> _deleteChatMessagesForRooms(
    SupabaseClient client,
    String userId,
    String roomColumn,
  ) async {
    try {
      final rooms = await client
          .from('chat_rooms')
          .select('id')
          .eq(roomColumn, userId);

      for (final room in rooms) {
        final roomId = room['id'];
        await client
            .from('chat_messages')
            .delete()
            .eq('room_id', roomId);
      }
    } catch (_) {}
  }

  Future<void> _safeDeleteStorage(
    SupabaseClient client,
    String bucket,
    String userId,
  ) async {
    try {
      final files = await client.storage.from(bucket).list(path: userId);

      for (final file in files) {
        await client.storage.from(bucket).remove(['$userId/${file.name}']);
      }
    } catch (_) {}
  }

  Future<void> _deletePlanDaysForProfessional(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final plans = await client
          .from('free_plans')
          .select('free_plan_id')
          .eq('professional_id', userId);

      for (final plan in plans) {
        final planId = plan['free_plan_id'];
        await client
            .from('plan_days')
            .delete()
            .eq('free_plan_id', planId);
      }
    } catch (_) {}
  }

  Future<void> _deletePersonalizedPlanDaysForProfessional(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final plans = await client
          .from('personalized_plans')
          .select('personalized_plan_id')
          .eq('professional_id', userId);

      for (final plan in plans) {
        final planId = plan['personalized_plan_id'];
        await client
            .from('personalized_plan_days')
            .delete()
            .eq('personalized_plan_id', planId);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _BackButton(onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),

              const Spacer(),

              const Icon(
                Icons.warning_rounded,
                size: 74,
                color: Color(0xFFEAC63A),
              ),

              const SizedBox(height: 18),

              const Text(
                'Delete Account?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'This will permanently erase your account and all data from our servers. It cannot be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : confirmAndDeleteAccount,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
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

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.cardMuted,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
