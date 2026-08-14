import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipService {
  static Future<bool> ensureCurrentPriorityStatus() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) return false;

    try {
      final profile = await client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType =
          profile?['user_type']?.toString().trim().toLowerCase() ?? 'free';

      final priority = await client
          .from('priority_user')
          .select('subscribed_at, expires_at')
          .eq('profile_id', userId)
          .maybeSingle();

      final subscribedAt = _parseDateTime(priority?['subscribed_at']);
      final expiresAt = _parseDateTime(priority?['expires_at']);

      if (userType == 'priority') {
        final endsAt = expiresAt ?? _oneMonthAfter(subscribedAt);

        if (endsAt != null && endsAt.isBefore(DateTime.now())) {
          await client
              .from('profiles')
              .update({'user_type': 'Free'})
              .eq('id', userId);

          await client.from('priority_user').delete().eq('profile_id', userId);

          return false;
        }
      }

      return userType == 'priority';
    } catch (error) {
      return false;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static DateTime? _oneMonthAfter(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month + 1, date.day);
  }
}
