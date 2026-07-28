import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'home.dart';
import 'professional_shell.dart';

class ReviewPlan extends StatefulWidget {
  final String planName;
  final List<String> tags;
  final String visibility;
  final String duration;
  final int weekNumber;
  final int dayNumber;
  final String dayName;
  final bool isRestDay;
  final List<Exercise> exercises;
  final String buttonText;

  const ReviewPlan({
    super.key,
    required this.planName,
    required this.tags,
    required this.visibility,
    required this.duration,
    required this.weekNumber,
    required this.dayNumber,
    required this.dayName,
    required this.isRestDay,
    required this.exercises,
    this.buttonText = 'Update Changes',
  });

  @override
  State<ReviewPlan> createState() => _ReviewPlanState();
}

class _ReviewPlanState extends State<ReviewPlan> {
  bool isSaving = false;

  void finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfessionalHome(),
      ),
      (route) => false,
    );
  }

  Future<void> _publishPlan() async {
    setState(() {
      isSaving = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final planRow = await client
          .from('free_plans')
          .insert({
            'professional_id': userId,
            'plan_name': widget.planName,
            'tag1': widget.tags.isNotEmpty ? widget.tags[0] : null,
            'tag2': widget.tags.length > 1 ? widget.tags[1] : null,
            'tag3': widget.tags.length > 2 ? widget.tags[2] : null,
            'visibility': widget.visibility,
            'status': 'published',
          })
          .select('free_plan_id')
          .single();

      final planId = planRow['free_plan_id'] as String;

      final dayRow = await client
          .from('plan_days')
          .insert({
            'free_plan_id': planId,
            'week_number': widget.weekNumber,
            'day_number': widget.dayNumber,
            'day_name': widget.dayName,
            'is_rest_day': widget.isRestDay,
          })
          .select('plan_day_id')
          .single();

      final planDayId = dayRow['plan_day_id'] as String;

      if (!widget.isRestDay) {
        for (var i = 0; i < widget.exercises.length; i++) {
          final exercise = widget.exercises[i];
          if (exercise.exerciseId == null) continue;

          await client.from('plan_exercises').insert({
            'plan_day_id': planDayId,
            'exercise_id': exercise.exerciseId,
            'sets': 3,
            'rep_min': exercise.repMin,
            'rep_max': exercise.repMax,
            'rest_sec': exercise.restSec,
            'order_index': i,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan published successfully!')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfessionalShell(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  ...widget.tags.map((tag) => _InfoChip(text: tag)),
                  _InfoChip(text: widget.visibility),
                  _InfoChip(text: widget.duration),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
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
                        'Week ${widget.weekNumber} · Day ${widget.dayNumber} — ${widget.dayName}',
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
                widget.isRestDay
                    ? 'Rest Day'
                    : '${widget.exercises.length} exercises • ~45 min',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 18),

              Expanded(
                child: widget.isRestDay
                    ? Center(
                        child: Text(
                          'This day is marked as a rest day.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = widget.exercises[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1} :',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: exercise.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: ' ${exercise.detail}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          if (widget.buttonText == 'Publish Plan') {
                            _publishPlan();
                          } else {
                            finish();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
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