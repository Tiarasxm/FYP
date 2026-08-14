import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/welcome_screen.dart';
import '../../theme/app_theme.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool isDeleting = false;

  Future<void> _deleteAccount() async {
    if (isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
            "This will deactivate your account. You will not be able to use this account again.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isDeleting = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception("You must be signed in.");
      }

      // ── Clean up all user data ──
      // Social
      await _safeDelete(client, 'post_likes', 'user_id', userId);
      await _safeDelete(client, 'post_comments', 'user_id', userId);
      await _safeDelete(client, 'posts', 'user_id', userId);
      await _safeDelete(client, 'follows', 'follower_id', userId);
      await _safeDelete(client, 'follows', 'following_id', userId);

      // Chat: delete all messages in rooms where user is a participant, then rooms
      await _deleteChatMessagesForRooms(client, userId, 'client_id');
      await _safeDelete(client, 'chat_messages', 'sender_id', userId);
      await _safeDelete(client, 'chat_rooms', 'client_id', userId);

      // Plans & logs
      await _safeDelete(client, 'saved_plans', 'profile_id', userId);
      await _safeDelete(client, 'workout_logs', 'profile_id', userId);
      await _safeDelete(client, 'meal_logs', 'profile_id', userId);
      await _safeDelete(client, 'water_logs', 'profile_id', userId);
      await _safeDelete(client, 'water_settings', 'profile_id', userId);

      // Reviews & reports
      await _safeDelete(client, 'reviews', 'reviewer_id', userId);
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

      // Storage: delete avatar
      await _safeDeleteStorage(client, 'profile-avatars', userId);

      // Soft-delete the profile
      await client.from('profiles').update({
        'status': 'deleted',
      }).eq('id', userId);

      await client.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete account: $error"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
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
      // Continue even if one table fails (e.g. RLS blocks or table missing)
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
                        "Delete Account",
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

              const Spacer(),

              const Icon(
                Icons.warning_amber_rounded,
                size: 76,
                color: Color(0xFFE8C632),
              ),

              const SizedBox(height: 16),

              const Text(
                "Delete Account?",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "This will deactivate your account. It will be marked as deleted and you will be logged out.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isDeleting ? null : _deleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Delete Account",
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