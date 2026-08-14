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
      final totalWorkouts = logs.length;

      final completedFirstProgram = await _checkCompletedFirstProgram(
        client: client,
        userId: userId,
        logs: logs,
      );

      final totalVolumeKg = await _calculateLifetimeVolume(
        client: client,
        logs: logs,
      );

      final mealLogDays = await _calculateMealLogDays(
        client: client,
        userId: userId,
      );

      final achievements = [
        _streakAchievement(
          days: 3,
          longestStreak: longestStreak,
          icon: Icons.local_fire_department,
          color: AppColors.amber,
        ),
        _streakAchievement(
          days: 7,
          longestStreak: longestStreak,
          icon: Icons.local_fire_department,
          color: AppColors.amber,
        ),
        _streakAchievement(
          days: 30,
          longestStreak: longestStreak,
          icon: Icons.whatshot,
          color: const Color(0xFFF08A3C),
        ),
        _streakAchievement(
          days: 100,
          longestStreak: longestStreak,
          icon: Icons.whatshot,
          color: const Color(0xFFF08A3C),
        ),
        Achievement(
          label: 'Completed First Program',
          description: 'Finish every training day in an active plan.',
          icon: Icons.event_available,
          color: AppColors.primary,
          achieved: completedFirstProgram,
          progressValue: completedFirstProgram ? 1 : 0,
        ),
        _countAchievement(
          label: 'Getting Started',
          description: 'Log 10 completed workouts.',
          target: 10,
          current: totalWorkouts,
          unit: 'workouts',
          icon: Icons.fitness_center,
          color: AppColors.blue,
        ),
        _countAchievement(
          label: 'Iron Regular',
          description: 'Log 50 completed workouts.',
          target: 50,
          current: totalWorkouts,
          unit: 'workouts',
          icon: Icons.fitness_center,
          color: AppColors.blue,
        ),
        _countAchievement(
          label: 'Volume Titan',
          description: 'Lift a combined 5,000 kg across all workouts.',
          target: 5000,
          current: totalVolumeKg.round(),
          unit: 'kg',
          icon: Icons.bolt,
          color: const Color(0xFF9B6BFF),
        ),
        _countAchievement(
          label: 'Volume Legend',
          description: 'Lift a combined 25,000 kg across all workouts.',
          target: 25000,
          current: totalVolumeKg.round(),
          unit: 'kg',
          icon: Icons.bolt,
          color: const Color(0xFF9B6BFF),
        ),
        _countAchievement(
          label: 'Nutrition Tracker',
          description: 'Log a meal on 7 different days.',
          target: 7,
          current: mealLogDays,
          unit: 'days',
          icon: Icons.restaurant,
          color: AppColors.green,
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

  Achievement _streakAchievement({
    required int days,
    required int longestStreak,
    required IconData icon,
    required Color color,
  }) {
    final achieved = longestStreak >= days;

    return Achievement(
      label: '$days-Day Streak',
      description: 'Complete workouts on $days days in a row.',
      icon: icon,
      color: color,
      achieved: achieved,
      progressLabel: achieved ? null : 'Best streak: $longestStreak/$days days',
      progressValue: (longestStreak / days).clamp(0, 1).toDouble(),
    );
  }

  Achievement _countAchievement({
    required String label,
    required String description,
    required int target,
    required int current,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final achieved = current >= target;

    return Achievement(
      label: label,
      description: description,
      icon: icon,
      color: color,
      achieved: achieved,
      progressLabel: achieved
          ? null
          : '${_formatNumber(current)}/${_formatNumber(target)} $unit',
      progressValue: (current / target).clamp(0, 1).toDouble(),
    );
  }

  String _formatNumber(int value) {
    if (value < 1000) return '$value';

    final thousands = value / 1000;
    final rounded = thousands == thousands.roundToDouble()
        ? thousands.toInt().toString()
        : thousands.toStringAsFixed(1);

    return '${rounded}k';
  }

  Future<double> _calculateLifetimeVolume({
    required SupabaseClient client,
    required List<Map<String, dynamic>> logs,
  }) async {
    final workoutLogIds = logs
        .map((log) => log['workout_log_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (workoutLogIds.isEmpty) return 0;

    final exercisesResponse = await client
        .from('workout_exercises')
        .select('reps, weight_kg')
        .inFilter('workout_log_id', workoutLogIds);

    final rows = List<Map<String, dynamic>>.from(exercisesResponse as List);

    double total = 0;

    for (final row in rows) {
      final reps = _parseInt(row['reps']) ?? 0;
      final weight = _parseDouble(row['weight_kg']) ?? 0;

      total += reps * weight;
    }

    return total;
  }

  Future<int> _calculateMealLogDays({
    required SupabaseClient client,
    required String userId,
  }) async {
    final response = await client
        .from('meal_logs')
        .select('logged_at')
        .eq('profile_id', userId);

    final rows = List<Map<String, dynamic>>.from(response as List);

    final uniqueDays = <String>{};

    for (final row in rows) {
      final raw = row['logged_at']?.toString();

      if (raw == null || raw.isEmpty) continue;

      final parsed = DateTime.tryParse(raw);

      if (parsed == null) continue;

      uniqueDays.add(_dateKey(parsed.toLocal()));
    }

    return uniqueDays.length;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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
          Row(
            children: [
              const Text(
                'Achieved',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${achieved.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (achieved.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Complete a workout to earn your first badge.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final item in achieved) ...[
                  _achievementTile(item),
                  const SizedBox(height: 10),
                ],
              ],
            ),

          const SizedBox(height: 26),

          const Text(
            'Unachieved Challenges',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'Keep going — here\'s what\'s next.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final item in unachieved) ...[
                _achievementTile(item),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _achievementTile(Achievement item) {
    final achieved = item.achieved;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved ? item.color.withOpacity(0.25) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: achieved
                  ? item.color.withOpacity(0.14)
                  : AppColors.cardMuted,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: achieved ? item.color : AppColors.textMuted,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: achieved
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withOpacity(0.85),
                        ),
                      ),
                    ),
                    if (achieved)
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.green,
                      )
                    else
                      const Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!achieved && item.progressValue != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.progressValue,
                      minHeight: 6,
                      backgroundColor: AppColors.cardMuted,
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                  if (item.progressLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.progressLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}