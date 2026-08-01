import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _logs = [];
  Map<String, int> _setCounts = {};
  Map<String, int> _exerciseCounts = {};
  Map<String, List<String>> _exerciseNames = {};

  @override
  void initState() {
    super.initState();
    _loadWorkoutHistory();
  }

  Future<void> _loadWorkoutHistory() async {
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
          .select(
            '''
            workout_log_id,
            profile_id,
            free_plan_id,
            personalized_plan_id,
            performed_at,
            duration_min,
            source,
            free_plans(
              plan_name
            )
            ''',
          )
          .eq('profile_id', userId)
          .order('performed_at', ascending: false);

      final logs = List<Map<String, dynamic>>.from(logsResponse as List);

      final workoutLogIds = logs
          .map((log) => log['workout_log_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      final setCounts = <String, int>{};
      final exerciseIdGroups = <String, Set<String>>{};
      final exerciseNames = <String, List<String>>{};

      if (workoutLogIds.isNotEmpty) {
        final exercisesResponse = await client
            .from('workout_exercises')
            .select(
              '''
              workout_log_id,
              exercise_id,
              sets,
              reps,
              weight_kg,
              exercise_library(
                name
              )
              ''',
            )
            .inFilter('workout_log_id', workoutLogIds);

        final rows = List<Map<String, dynamic>>.from(exercisesResponse as List);

        for (final row in rows) {
          final workoutLogId = row['workout_log_id']?.toString();
          final exerciseId = row['exercise_id']?.toString();

          if (workoutLogId == null || workoutLogId.isEmpty) {
            continue;
          }

          setCounts[workoutLogId] = (setCounts[workoutLogId] ?? 0) + 1;

          if (exerciseId != null && exerciseId.isNotEmpty) {
            exerciseIdGroups.putIfAbsent(workoutLogId, () => <String>{});
            exerciseIdGroups[workoutLogId]!.add(exerciseId);
          }

          final library = row['exercise_library'] as Map<String, dynamic>?;
          final exerciseName = library?['name']?.toString().trim();

          if (exerciseName != null && exerciseName.isNotEmpty) {
            exerciseNames.putIfAbsent(workoutLogId, () => <String>[]);

            final alreadyExists = exerciseNames[workoutLogId]!.any(
              (name) => name.toLowerCase() == exerciseName.toLowerCase(),
            );

            if (!alreadyExists) {
              exerciseNames[workoutLogId]!.add(exerciseName);
            }
          }
        }
      }

      final exerciseCounts = <String, int>{};

      for (final entry in exerciseIdGroups.entries) {
        exerciseCounts[entry.key] = entry.value.length;
      }

      if (!mounted) return;

      setState(() {
        _logs = logs;
        _setCounts = setCounts;
        _exerciseCounts = exerciseCounts;
        _exerciseNames = exerciseNames;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workout history: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _titleForLog(Map<String, dynamic> log) {
    final freePlan = log['free_plans'] as Map<String, dynamic>?;

    final planName = freePlan?['plan_name']?.toString().trim();

    if (planName != null && planName.isNotEmpty) {
      return planName;
    }

    final personalizedPlanId = log['personalized_plan_id']?.toString();

    if (personalizedPlanId != null && personalizedPlanId.isNotEmpty) {
      return 'Personalized Plan';
    }

    return 'Workout Plan';
  }

  String _metaForLog(Map<String, dynamic> log) {
    final workoutLogId = log['workout_log_id']?.toString();

    final durationMin = _parseInt(log['duration_min']) ?? 0;
    final setCount =
        workoutLogId == null ? 0 : (_setCounts[workoutLogId] ?? 0);
    final exerciseCount =
        workoutLogId == null ? 0 : (_exerciseCounts[workoutLogId] ?? 0);

    final parts = <String>[];

    if (durationMin > 0) {
      parts.add('$durationMin min');
    }

    if (exerciseCount > 0) {
      parts.add('$exerciseCount exercises');
    }

    if (setCount > 0) {
      parts.add('$setCount sets');
    }

    if (parts.isEmpty) {
      return 'Workout completed';
    }

    return parts.join(' • ');
  }

  String _exerciseSummary(Map<String, dynamic> log) {
    final workoutLogId = log['workout_log_id']?.toString();

    if (workoutLogId == null || workoutLogId.isEmpty) {
      return '';
    }

    final names = _exerciseNames[workoutLogId] ?? [];

    if (names.isEmpty) {
      return '';
    }

    if (names.length <= 2) {
      return names.join(', ');
    }

    return '${names.take(2).join(', ')} +${names.length - 2} more';
  }

  String _whenForLog(Map<String, dynamic> log) {
    final raw = log['performed_at']?.toString();

    if (raw == null || raw.isEmpty) {
      return 'Unknown time';
    }

    final performedAt = DateTime.tryParse(raw);

    if (performedAt == null) {
      return 'Unknown time';
    }

    final localTime = performedAt.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final performedDate = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
    );

    final diffDays = today.difference(performedDate).inDays;

    if (diffDays <= 0) {
      return 'Today';
    }

    if (diffDays == 1) {
      return 'Yesterday';
    }

    if (diffDays < 7) {
      return '$diffDays days ago';
    }

    if (diffDays < 14) {
      return '1 week ago';
    }

    if (diffDays < 30) {
      return '${diffDays ~/ 7} weeks ago';
    }

    return '${localTime.day}/${localTime.month}/${localTime.year}';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Workout History',
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_logs.isEmpty)
          _emptyState()
        else
          for (final log in _logs) ...[
            _historyRow(log),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No workout history yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Finish a workout to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> log) {
    final title = _titleForLog(log);
    final when = _whenForLog(log);
    final meta = _metaForLog(log);
    final exerciseSummary = _exerciseSummary(log);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$when, $meta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (exerciseSummary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    exerciseSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}