import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/exercise.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'workout_complete_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String planId;
  final String planTitle;
  final String planDayId;
  final String dayLabel;

  const ActiveWorkoutScreen({
    super.key,
    required this.planId,
    required this.planTitle,
    required this.planDayId,
    required this.dayLabel,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  bool _isLoading = true;
  bool _isFinishing = false;

  final DateTime _startedAt = DateTime.now();

  List<Map<String, dynamic>> _exercises = [];
  late Map<int, List<ExerciseSet>> _sets;

  @override
  void initState() {
    super.initState();
    _sets = {};
    _loadExercises();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('plan_exercises')
          .select(
            'plan_exercise_id, exercise_id, sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)',
          )
          .eq('plan_day_id', widget.planDayId)
          .order('order_index');

      final rows = List<Map<String, dynamic>>.from(response as List);

      final newSets = <int, List<ExerciseSet>>{};

      for (var i = 0; i < rows.length; i++) {
        final setCount = _parseInt(rows[i]['sets']) ?? 3;
        final defaultReps = _defaultReps(rows[i]);

        newSets[i] = List.generate(
          setCount,
          (_) => ExerciseSet(reps: defaultReps),
        );
      }

      if (!mounted) return;

      setState(() {
        _exercises = rows;
        _sets = newSets;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workout: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _defaultReps(Map<String, dynamic> exercise) {
    final repMin = _parseInt(exercise['rep_min']);
    final repMax = _parseInt(exercise['rep_max']);

    if (repMax != null) return '$repMax';
    if (repMin != null) return '$repMin';

    return '12';
  }

  String _exerciseName(Map<String, dynamic> exercise) {
    final library = exercise['exercise_library'] as Map<String, dynamic>?;
    return library?['name']?.toString() ?? 'Exercise';
  }

  String _exerciseMeta(Map<String, dynamic> exercise) {
    final sets = _parseInt(exercise['sets']) ?? 0;
    final repMin = _parseInt(exercise['rep_min']);
    final repMax = _parseInt(exercise['rep_max']);
    final restSec = _parseInt(exercise['rest_sec']) ?? 60;

    String repsText;

    if (repMin == null && repMax == null) {
      repsText = '- reps';
    } else if (repMin != null && (repMax == null || repMin == repMax)) {
      repsText = '$repMin reps';
    } else {
      repsText = '${repMin ?? '-'}-${repMax ?? '-'} reps';
    }

    return '$sets × $repsText • ${restSec}s rest';
  }

  String _elapsedText() {
    final elapsed = DateTime.now().difference(_startedAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get _completedSetCount {
    int count = 0;

    for (final sets in _sets.values) {
      count += sets.where((set) => set.done).length;
    }

    return count;
  }

  double get _totalVolume {
    double total = 0;

    for (final sets in _sets.values) {
      for (final set in sets) {
        if (!set.done) continue;

        final kg = double.tryParse(set.kg.trim()) ?? 0;
        final reps = int.tryParse(set.reps.trim()) ?? 0;

        total += kg * reps;
      }
    }

    return total;
  }

  Future<void> _finishWorkout() async {
    if (_isFinishing) return;

    if (_completedSetCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete at least one set.')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      final durationSeconds = DateTime.now().difference(_startedAt).inSeconds;
      final durationMin = durationSeconds <= 0
          ? 1
          : (durationSeconds / 60).ceil();

      final logRow = await Supabase.instance.client
          .from('workout_logs')
          .insert({
            'profile_id': userId,
            'free_plan_id': widget.planId,
            'personalized_plan_id': null,
            'performed_at': DateTime.now().toIso8601String(),
            'duration_min': durationMin,
            'source': 'active_plan',
          })
          .select('workout_log_id')
          .single();

      final workoutLogId = logRow['workout_log_id']?.toString();

      if (workoutLogId == null || workoutLogId.isEmpty) {
        throw Exception('Missing workout_log_id.');
      }

      final exerciseRows = <Map<String, dynamic>>[];

      for (var exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
        final exercise = _exercises[exerciseIndex];
        final exerciseId = exercise['exercise_id']?.toString();
        final sets = _sets[exerciseIndex] ?? [];

        if (exerciseId == null || exerciseId.isEmpty) continue;

        for (var setIndex = 0; setIndex < sets.length; setIndex++) {
          final set = sets[setIndex];

          if (!set.done) continue;

          final reps = int.tryParse(set.reps.trim());
          final weight = double.tryParse(set.kg.trim());

          exerciseRows.add({
            'workout_log_id': workoutLogId,
            'exercise_id': exerciseId,
            'sets': setIndex + 1,
            'reps': reps ?? 0,
            'weight_kg': weight ?? 0,
          });
        }
      }

      if (exerciseRows.isNotEmpty) {
        await Supabase.instance.client
            .from('workout_exercises')
            .insert(exerciseRows);
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutCompleteScreen(
            dayLabel: widget.dayLabel,
            durationSeconds: durationSeconds,
            totalVolumeKg: _totalVolume,
            totalSets: _completedSetCount,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to finish workout: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: widget.dayLabel,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _elapsedText(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      bottomButton: PrimaryButton(
        label: _isFinishing ? 'Saving...' : 'Finish Workout',
        onPressed: _isFinishing ? null : _finishWorkout,
      ),
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No exercises in this workout.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          for (var i = 0; i < _exercises.length; i++) ...[
            _exerciseCard(i),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  Widget _exerciseCard(int index) {
    final exercise = _exercises[index];
    final sets = _sets[index] ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exerciseName(exercise),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _exerciseMeta(exercise),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.help_outline,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 30,
                child: Text('SET', style: _headerStyle),
              ),
              Expanded(child: Text('KG', style: _headerStyle)),
              SizedBox(width: 10),
              Expanded(child: Text('REPS', style: _headerStyle)),
              SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 6),
          for (var s = 0; s < sets.length; s++) _setRow(sets[s], s),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );

  Widget _setRow(ExerciseSet set, int number) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${number + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: _setField(
              initial: set.kg,
              onChanged: (value) => set.kg = value,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _setField(
              initial: set.reps,
              onChanged: (value) => set.reps = value,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => set.done = !set.done),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: set.done ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: set.done ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: set.done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _setField({
    required String initial,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        initialValue: initial,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}