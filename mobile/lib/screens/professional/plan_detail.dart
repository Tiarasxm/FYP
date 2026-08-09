import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'edit_plan.dart';
import '../../theme/app_theme.dart';

class PlanDetailScreen extends StatefulWidget {
  final WorkoutPlan plan;

  const PlanDetailScreen({
    super.key,
    required this.plan,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool isLoading = true;
  bool isDeleting = false;

  List<WorkoutDay> workoutDays = [];

  int selectedWeek = 1;
  int selectedDay = 1;

  @override
  void initState() {
    super.initState();
    loadPlanDetail();
  }

  List<int> get weeks {
    final set = workoutDays.map((day) => day.weekNumber).toSet().toList();
    set.sort();
    return set.isEmpty ? [1] : set;
  }

  List<WorkoutDay> get daysForSelectedWeek {
    final days = workoutDays
        .where((day) => day.weekNumber == selectedWeek)
        .toList();

    days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return days;
  }

  WorkoutDay? get selectedWorkoutDay {
    final days = daysForSelectedWeek;

    for (final day in days) {
      if (day.dayNumber == selectedDay) {
        return day;
      }
    }

    if (days.isNotEmpty) {
      return days.first;
    }

    return null;
  }

  Future<void> loadPlanDetail() async {
    setState(() {
      isLoading = true;
    });

    try {
      final planId = widget.plan.freePlanId;

      if (planId == null || planId.isEmpty) {
        setState(() {
          workoutDays = widget.plan.workoutDays;
          if (workoutDays.isNotEmpty) {
            selectedWeek = workoutDays.first.weekNumber;
            selectedDay = workoutDays.first.dayNumber;
          }
        });
        return;
      }

      final client = Supabase.instance.client;

      final dayResponse = await client
          .from('plan_days')
          .select(
            'plan_day_id, week_number, day_number, day_name, is_rest_day',
          )
          .eq('free_plan_id', planId)
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      final dayRows = dayResponse as List<dynamic>;

      final loadedDays = <WorkoutDay>[];

      for (final dayItem in dayRows) {
        final dayRow = dayItem as Map<String, dynamic>;

        final planDayId = dayRow['plan_day_id']?.toString();
        final weekNumber = parseInt(dayRow['week_number']) ?? 1;
        final dayNumber = parseInt(dayRow['day_number']) ?? 1;
        final dayName = dayRow['day_name']?.toString() ?? 'Day $dayNumber';
        final isRestDay = dayRow['is_rest_day'] == true;

        final exercises = planDayId == null
            ? <Exercise>[]
            : await loadExercisesForDay(planDayId);

        loadedDays.add(
          WorkoutDay(
            planDayId: planDayId,
            weekNumber: weekNumber,
            dayNumber: dayNumber,
            title: dayName,
            duration: '~45 min',
            exerciseCount: exercises.length,
            isRestDay: isRestDay,
            exercises: exercises,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        workoutDays = loadedDays;

        if (workoutDays.isNotEmpty) {
          selectedWeek = workoutDays.first.weekNumber;
          selectedDay = workoutDays.first.dayNumber;
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan detail: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Exercise>> loadExercisesForDay(String planDayId) async {
    final client = Supabase.instance.client;

    final exerciseRowsResponse = await client
        .from('plan_exercises')
        .select(
          'exercise_id, order_index, sets, rep_min, rep_max, rest_sec',
        )
        .eq('plan_day_id', planDayId)
        .order('order_index', ascending: true);

    final exerciseRows = exerciseRowsResponse as List<dynamic>;

    if (exerciseRows.isEmpty) {
      return [];
    }

    final exerciseIds = exerciseRows
        .map((row) => (row as Map<String, dynamic>)['exercise_id']?.toString())
        .whereType<String>()
        .toList();

    final Map<String, String> exerciseNames = {};

    if (exerciseIds.isNotEmpty) {
      final libraryResponse = await client
          .from('exercise_library')
          .select('exercise_id, name')
          .inFilter('exercise_id', exerciseIds);

      final libraryRows = libraryResponse as List<dynamic>;

      for (final item in libraryRows) {
        final row = item as Map<String, dynamic>;
        final id = row['exercise_id']?.toString();
        final name = row['name']?.toString();

        if (id != null && name != null) {
          exerciseNames[id] = name;
        }
      }
    }

    return exerciseRows.map((item) {
      final row = item as Map<String, dynamic>;

      final exerciseId = row['exercise_id']?.toString();
      final sets = parseInt(row['sets']) ?? 3;
      final repMin = parseInt(row['rep_min']);
      final repMax = parseInt(row['rep_max']);
      final restSec = parseInt(row['rest_sec']);

      final repsText = buildRepsText(repMin, repMax);
      final restText = restSec == null ? '60s rest' : '${restSec}s rest';

      return Exercise(
        exerciseId: exerciseId,
        name: exerciseNames[exerciseId] ?? 'Unknown Exercise',
        sets: sets,
        repMin: repMin,
        repMax: repMax,
        restSec: restSec,
        detail: '$sets × $repsText • $restText',
      );
    }).toList();
  }

  String buildRepsText(int? repMin, int? repMax) {
    if (repMin == null && repMax == null) {
      return '10-12 reps';
    }

    if (repMin != null && (repMax == null || repMax == repMin)) {
      return '$repMin reps';
    }

    return '${repMin ?? ''}-${repMax ?? ''} reps';
  }

  int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void selectWeek(int week) {
    final days = workoutDays
        .where((day) => day.weekNumber == week)
        .toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    setState(() {
      selectedWeek = week;
      selectedDay = days.isNotEmpty ? days.first.dayNumber : 1;
    });
  }

  void selectDay(int day) {
    setState(() {
      selectedDay = day;
    });
  }

  Future<void> confirmDeletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Plan?'),
          content: const Text(
            'This plan will be archived and hidden from users. Workout history will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deletePlan();
    }
  }

  Future<void> deletePlan() async {
    final planId = widget.plan.freePlanId;

    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This plan cannot be deleted from Supabase.'),
        ),
      );
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('You must be signed in.');
      }

      await client
          .from('free_plans')
          .update({
            'status': 'archived',
            'visibility': 'Private',
          })
          .eq('free_plan_id', planId)
          .eq('professional_id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan archived successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to archive plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  void openEditPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlan(plan: widget.plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = selectedWorkoutDay;

    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BackButton(
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Week',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final week in weeks) ...[
                            _SmallBox(
                              topText: 'WEEK',
                              number: '$week',
                              selected: selectedWeek == week,
                              onTap: () {
                                selectWeek(week);
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final day in daysForSelectedWeek) ...[
                            _SmallBox(
                              topText: 'DAY',
                              number: '${day.dayNumber}',
                              selected: selectedDay == day.dayNumber,
                              onTap: () {
                                selectDay(day.dayNumber);
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (currentDay == null)
                      Expanded(
                        child: Center(
                          child: Text(
                            'No day data found.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              Color(0xFFA49DED),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.calendar_month,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Week ${currentDay.weekNumber} · Day ${currentDay.dayNumber} — ${currentDay.title}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        currentDay.isRestDay
                            ? 'Rest Day'
                            : '${currentDay.exercises.length} exercises • ${currentDay.duration}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Expanded(
                        child: currentDay.isRestDay
                            ? Center(
                                child: Text(
                                  'This day is marked as rest day.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : currentDay.exercises.isEmpty
                                ? Center(
                                    child: Text(
                                      'No exercises for this day.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: currentDay.exercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise =
                                          currentDay.exercises[index];

                                      return _ExerciseCard(
                                        number: index + 1,
                                        exercise: exercise,
                                      );
                                    },
                                  ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed:
                                  isDeleting ? null : confirmDeletePlan,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isDeleting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Text(
                                      'Delete Plan',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isDeleting ? null : openEditPlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Edit Plan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SmallBox extends StatelessWidget {
  final String topText;
  final String number;
  final bool selected;
  final VoidCallback onTap;

  const _SmallBox({
    required this.topText,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 56,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                topText,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? AppColors.textMuted : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                number,
                style: TextStyle(
                  fontSize: 16,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int number;
  final Exercise exercise;

  const _ExerciseCard({
    required this.number,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  exercise.detail,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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