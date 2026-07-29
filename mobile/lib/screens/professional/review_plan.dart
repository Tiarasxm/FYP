import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'professional_shell.dart';

class ReviewPlan extends StatefulWidget {
  final String? freePlanId;

  final String planName;
  final List<String> tags;
  final String visibility;
  final String duration;
  final List<PlanDayDraft>? planDays;

  final int? weekNumber;
  final int? dayNumber;
  final String? dayName;
  final bool isRestDay;
  final List<Exercise> exercises;

  final String buttonText;

  const ReviewPlan({
    super.key,
    this.freePlanId,
    required this.planName,
    required this.tags,
    required this.visibility,
    required this.duration,
    this.planDays,
    this.weekNumber,
    this.dayNumber,
    this.dayName,
    this.isRestDay = false,
    this.exercises = const [],
    this.buttonText = 'Update Changes',
  });

  @override
  State<ReviewPlan> createState() => _ReviewPlanState();
}

class _ReviewPlanState extends State<ReviewPlan> {
  bool isSaving = false;

  List<PlanDayDraft> get reviewDays {
    if (widget.planDays != null && widget.planDays!.isNotEmpty) {
      final days = widget.planDays!.toList();

      days.sort((a, b) {
        final weekCompare = a.weekNumber.compareTo(b.weekNumber);
        if (weekCompare != 0) return weekCompare;
        return a.dayNumber.compareTo(b.dayNumber);
      });

      return days;
    }

    return [
      PlanDayDraft(
        weekNumber: widget.weekNumber ?? 1,
        dayNumber: widget.dayNumber ?? 1,
        dayName: widget.dayName ?? '',
        isRestDay: widget.isRestDay,
        exercises: widget.exercises,
      ),
    ];
  }

  int? get durationWeeks {
    final match = RegExp(r'\d+').firstMatch(widget.duration);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  int get totalExerciseCount {
    return reviewDays.fold<int>(
      0,
      (sum, day) => sum + day.exercises.length,
    );
  }

  void finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfessionalShell(),
      ),
      (route) => false,
    );
  }

  bool validatePlan() {
    for (final day in reviewDays) {
      final validExercises = day.exercises
          .where((exercise) => exercise.exerciseId != null)
          .toList();

      if (!day.isRestDay && validExercises.isEmpty) {
        showMessage(
          'Week ${day.weekNumber} Day ${day.dayNumber} needs exercise or rest day.',
        );
        return false;
      }
    }

    return true;
  }

  Future<void> publishPlan() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      showMessage('You must be signed in to publish a plan.');
      return;
    }

    if (!validatePlan()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final planRow = await client
          .from('free_plans')
          .insert({
            'professional_id': userId,
            'plan_name': widget.planName,
            'category': widget.tags.isNotEmpty ? widget.tags.first : null,
            'status': 'published',
            'tag1': widget.tags.isNotEmpty ? widget.tags[0] : null,
            'tag2': widget.tags.length > 1 ? widget.tags[1] : null,
            'tag3': widget.tags.length > 2 ? widget.tags[2] : null,
            'visibility': widget.visibility,
            'duration_weeks': durationWeeks,
          })
          .select('free_plan_id')
          .single();

      final planId = planRow['free_plan_id'] as String;

      await insertPlanDaysAndExercises(planId);

      if (!mounted) return;

      showMessage('Plan published successfully.');
      finish();
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to publish plan: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> updatePlan() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final planId = widget.freePlanId;

    if (userId == null) {
      showMessage('You must be signed in to update a plan.');
      return;
    }

    if (planId == null || planId.isEmpty) {
      showMessage('Missing plan id. Cannot update this plan.');
      return;
    }

    if (!validatePlan()) return;

    setState(() {
      isSaving = true;
    });

    try {
      await client
          .from('free_plans')
          .update({
            'plan_name': widget.planName,
            'category': widget.tags.isNotEmpty ? widget.tags.first : null,
            'status': 'published',
            'tag1': widget.tags.isNotEmpty ? widget.tags[0] : null,
            'tag2': widget.tags.length > 1 ? widget.tags[1] : null,
            'tag3': widget.tags.length > 2 ? widget.tags[2] : null,
            'visibility': widget.visibility,
            'duration_weeks': durationWeeks,
          })
          .eq('free_plan_id', planId)
          .eq('professional_id', userId);

      await deleteExistingPlanChildren(planId);
      await insertPlanDaysAndExercises(planId);

      if (!mounted) return;

      showMessage('Plan updated successfully.');
      finish();
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to update plan: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> deleteExistingPlanChildren(String planId) async {
    final client = Supabase.instance.client;

    final dayRowsResponse = await client
        .from('plan_days')
        .select('plan_day_id')
        .eq('free_plan_id', planId);

    final dayRows = dayRowsResponse as List<dynamic>;

    final planDayIds = dayRows
        .map((row) => (row as Map<String, dynamic>)['plan_day_id']?.toString())
        .whereType<String>()
        .toList();

    for (final dayId in planDayIds) {
      await client.from('plan_exercises').delete().eq('plan_day_id', dayId);
    }

    await client.from('plan_days').delete().eq('free_plan_id', planId);
  }

  Future<void> insertPlanDaysAndExercises(String planId) async {
    final client = Supabase.instance.client;

    for (final day in reviewDays) {
      final dayRow = await client
          .from('plan_days')
          .insert({
            'free_plan_id': planId,
            'week_number': day.weekNumber,
            'day_number': day.dayNumber,
            'day_name': day.displayName,
            'is_rest_day': day.isRestDay,
          })
          .select('plan_day_id')
          .single();

      final planDayId = dayRow['plan_day_id'] as String;

      if (!day.isRestDay) {
        final validExercises = day.exercises
            .where((exercise) => exercise.exerciseId != null)
            .toList();

        final exerciseRows = <Map<String, dynamic>>[];

        for (int i = 0; i < validExercises.length; i++) {
          final exercise = validExercises[i];

          exerciseRows.add({
            'plan_day_id': planDayId,
            'exercise_id': exercise.exerciseId,
            'order_index': i + 1,
            'sets': exercise.sets ?? 3,
            'rep_min': exercise.repMin,
            'rep_max': exercise.repMax,
            'rest_sec': exercise.restSec,
          });
        }

        if (exerciseRows.isNotEmpty) {
          await client.from('plan_exercises').insert(exerciseRows);
        }
      }
    }
  }

  void handleMainButton() {
    if (widget.buttonText == 'Publish Plan') {
      publishPlan();
    } else {
      updatePlan();
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = reviewDays;

    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
          child: Column(
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
                      widget.planName,
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

              const SizedBox(height: 18),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.tags.map((tag) {
                    return _InfoChip(text: tag);
                  }),
                  _InfoChip(text: widget.visibility),
                  _InfoChip(text: widget.duration),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                '${days.length} days • $totalExerciseCount exercises',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView.builder(
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];

                    return _ReviewDayCard(day: day);
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : handleMainButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.buttonText,
                          style: const TextStyle(
                            fontSize: 16,
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

class _ReviewDayCard extends StatelessWidget {
  final PlanDayDraft day;

  const _ReviewDayCard({
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFFA49DED),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Week ${day.weekNumber} · Day ${day.dayNumber} — ${day.displayName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          if (day.isRestDay)
            Text(
              'Rest Day',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < day.exercises.length; i++)
                  _ExerciseRow(
                    number: i + 1,
                    exercise: day.exercises[i],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int number;
  final Exercise exercise;

  const _ExerciseRow({
    required this.number,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFECE9FF),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: exercise.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: ' ${exercise.detail}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;

  const _InfoChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFECE9FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6C63FF),
          fontWeight: FontWeight.w800,
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
        color: Color(0xFFF3F2FA),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.black54,
        ),
      ),
    );
  }
}