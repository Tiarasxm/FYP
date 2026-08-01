import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/achievement.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _isLoading = true;

  List<Achievement> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final logsResponse = await client
          .from('workout_logs')
          .select('workout_log_id, free_plan_id, performed_at')
          .eq('profile_id', userId)
          .order('performed_at', ascending: true);

      final logs = List<Map<String, dynamic>>.from(logsResponse as List);

      final workoutDates = _extractUniqueWorkoutDates(logs);
      final longestStreak = _calculateLongestStreak(workoutDates);

      final completedFirstProgram = await _checkCompletedFirstProgram(
        client: client,
        userId: userId,
        logs: logs,
      );

      final achievements = [
        Achievement(
          label: '3-Day Streak',
          icon: Icons.local_fire_department,
          achieved: longestStreak >= 3,
        ),
        Achievement(
          label: '7-Day Streak',
          icon: Icons.local_fire_department,
          achieved: longestStreak >= 7,
        ),
        Achievement(
          label: '30-Day Streak',
          icon: Icons.local_fire_department,
          achieved: longestStreak >= 30,
        ),
        Achievement(
          label: '100-Day Streak',
          icon: Icons.local_fire_department,
          achieved: longestStreak >= 100,
        ),
        Achievement(
          label: 'Completed First Program',
          icon: Icons.event_available,
          achieved: completedFirstProgram,
        ),
      ];

      if (!mounted) return;

      setState(() {
        _achievements = achievements;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load achievements: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DateTime> _extractUniqueWorkoutDates(List<Map<String, dynamic>> logs) {
    final dateSet = <String>{};

    for (final log in logs) {
      final raw = log['performed_at']?.toString();

      if (raw == null || raw.isEmpty) continue;

      final parsed = DateTime.tryParse(raw);

      if (parsed == null) continue;

      final local = parsed.toLocal();
      final dateKey = _dateKey(local);

      dateSet.add(dateKey);
    }

    final dates = dateSet.map((key) {
      final parts = key.split('-');

      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList();

    dates.sort();

    return dates;
  }

  int _calculateLongestStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (var i = 1; i < dates.length; i++) {
      final previous = dates[i - 1];
      final currentDate = dates[i];

      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current += 1;
      } else if (difference > 1) {
        current = 1;
      }

      if (current > longest) {
        longest = current;
      }
    }

    return longest;
  }

  Future<bool> _checkCompletedFirstProgram({
    required SupabaseClient client,
    required String userId,
    required List<Map<String, dynamic>> logs,
  }) async {
    final savedResponse = await client
        .from('saved_plans')
        .select('free_plan_id, saved_at')
        .eq('profile_id', userId)
        .order('saved_at', ascending: false)
        .limit(1);

    final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

    if (savedRows.isEmpty) {
      return false;
    }

    final activePlanId = savedRows.first['free_plan_id']?.toString();

    if (activePlanId == null || activePlanId.isEmpty) {
      return false;
    }

    final daysResponse = await client
        .from('plan_days')
        .select('plan_day_id, is_rest_day')
        .eq('free_plan_id', activePlanId);

    final days = List<Map<String, dynamic>>.from(daysResponse as List);

    final trainingDayCount =
        days.where((day) => day['is_rest_day'] != true).length;

    if (trainingDayCount <= 0) {
      return false;
    }

    final completedWorkoutCount = logs.where((log) {
      final freePlanId = log['free_plan_id']?.toString();
      return freePlanId == activePlanId;
    }).length;

    return completedWorkoutCount >= trainingDayCount;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final achieved = _achievements.where((item) => item.achieved).toList();
    final unachieved = _achievements.where((item) => !item.achieved).toList();

    return SubScreenScaffold(
      title: 'My Achievements',
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          const Text(
            'Achieved',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (achieved.isEmpty)
            const Text(
              'No achievements yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            _badgeGrid(achieved, achieved: true),

          const SizedBox(height: 24),

          const Text(
            'Unachieved',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _badgeGrid(unachieved, achieved: false),
        ],
      ],
    );
  }

  Widget _badgeGrid(List<Achievement> items, {required bool achieved}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items) _badge(item, achieved),
      ],
    );
  }

  Widget _badge(Achievement item, bool achieved) {
    final isStreak = item.label.contains('Streak');

    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 30,
            color: achieved
                ? AppColors.amber
                : AppColors.textMuted.withOpacity(0.55),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: isStreak ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: achieved ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}