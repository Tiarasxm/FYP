import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'health_service.dart';

/// Syncs Health Connect data (steps, heart rate, calories) into the
/// `daily_health_metrics` Supabase table for the current user.
class HealthSyncService {
  static const String _provider = 'google_fit';

  /// Returns true if the current user has an active Health Connect
  /// connection recorded in `wearable_connections`.
  static Future<bool> isConnected(String userId) async {
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('wearable_connections')
          .select('is_connected')
          .eq('profile_id', userId)
          .eq('provider', _provider)
          .maybeSingle();

      return row?['is_connected'] == true;
    } catch (e) {
      debugPrint('HealthSyncService.isConnected error: $e');
      return false;
    }
  }

  /// Syncs today's + recent days' Health Connect metrics into Supabase.
  /// [daysBack] controls how many days of history to backfill (used to
  /// populate the Progress screen charts). No-op if not connected or
  /// permissions are missing.
  static Future<void> syncTodayAndRecentDays(
    String userId, {
    int daysBack = 35,
  }) async {
    final connected = await isConnected(userId);
    if (!connected) return;

    final hasPermissions = await HealthService.hasPermissions();
    if (!hasPermissions) return;

    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: daysBack - 1));

      final metrics = await HealthService.fetchMetricsForRange(start, now);

      if (metrics.isEmpty) return;

      final client = Supabase.instance.client;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final rows = metrics.map((m) {
        final dateStr =
            '${m.date.year.toString().padLeft(4, '0')}-'
            '${m.date.month.toString().padLeft(2, '0')}-'
            '${m.date.day.toString().padLeft(2, '0')}';

        return {
          'profile_id': userId,
          'metric_date': dateStr,
          'steps': m.steps,
          'heart_rate': m.heartRate,
          'heart_rate_measured_at': m.heartRateMeasuredAt?.toUtc().toIso8601String(),
          'calories_burned': m.caloriesBurned,
          'synced_at': nowIso,
        };
      }).toList();

      await client
          .from('daily_health_metrics')
          .upsert(rows, onConflict: 'profile_id,metric_date');

      await client
          .from('wearable_connections')
          .update({'last_synced_at': nowIso})
          .eq('profile_id', userId)
          .eq('provider', _provider);
    } catch (e) {
      debugPrint('HealthSyncService.syncTodayAndRecentDays error: $e');
    }
  }

  /// Reads today's row from `daily_health_metrics`, if any.
  static Future<Map<String, dynamic>?> fetchTodayMetrics(
    String userId,
  ) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final client = Supabase.instance.client;
      return await client
          .from('daily_health_metrics')
          .select('steps, heart_rate, heart_rate_measured_at, calories_burned')
          .eq('profile_id', userId)
          .eq('metric_date', dateStr)
          .maybeSingle();
    } catch (e) {
      debugPrint('HealthSyncService.fetchTodayMetrics error: $e');
      return null;
    }
  }

  /// Reads `daily_health_metrics` rows between [start] and [end] (inclusive).
  static Future<List<Map<String, dynamic>>> fetchMetricsForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final client = Supabase.instance.client;
      final response = await client
          .from('daily_health_metrics')
          .select('metric_date, steps, heart_rate, calories_burned')
          .eq('profile_id', userId)
          .gte('metric_date', fmt(start))
          .lte('metric_date', fmt(end))
          .order('metric_date', ascending: true);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HealthSyncService.fetchMetricsForRange error: $e');
      return [];
    }
  }
}
