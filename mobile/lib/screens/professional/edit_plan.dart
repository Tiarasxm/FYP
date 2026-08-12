import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'edit_plan_schedule.dart';

class EditPlan extends StatefulWidget {
  final WorkoutPlan plan;

  const EditPlan({
    super.key,
    required this.plan,
  });

  @override
  State<EditPlan> createState() => _EditPlanState();
}

class _EditPlanState extends State<EditPlan> {
  late TextEditingController planNameController;

  late String tagOne;
  late String tagTwo;
  late String tagThree;
  String visibility = 'Public';
  String targetActivityLevel = 'Lightly Active';
  String targetFitnessGoal = 'Get Fitter';
  bool isLoadingMetadata = true;

  final List<String> tagOptions = [
    'Full Body',
    'Fat Loss',
    'Strength',
    'Upper Body',
    'Lower Body',
    'Core',
    'Cardio',
    'Beginner',
  ];

  final List<String> visibilityOptions = [
    'Public',
    'Private',
  ];

  final List<String> activityLevelOptions = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];

  final List<String> fitnessGoalOptions = [
    'Get Fitter',
    'Gain Weight',
    'Lose Weight',
    'Improve Endurance',
    'Build Muscles',
  ];

  @override
  void initState() {
    super.initState();

    planNameController = TextEditingController(
      text: widget.plan.title,
    );

    tagOne = widget.plan.tags.isNotEmpty ? widget.plan.tags[0] : 'Full Body';
    tagTwo = widget.plan.tags.length > 1 ? widget.plan.tags[1] : 'Fat Loss';
    tagThree = widget.plan.tags.length > 2 ? widget.plan.tags[2] : 'Strength';
    visibility = widget.plan.visibility.isEmpty ? 'Public' : widget.plan.visibility;

    _loadPlanRecommendationFields();
  }

  @override
  void dispose() {
    planNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanRecommendationFields() async {
    final freePlanId = widget.plan.freePlanId;

    if (freePlanId == null || freePlanId.isEmpty) {
      setState(() {
        isLoadingMetadata = false;
      });
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('free_plans')
          .select('visibility, target_activity_level, target_fitness_goal')
          .eq('free_plan_id', freePlanId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        final loadedVisibility = data?['visibility']?.toString().trim();
        if (loadedVisibility != null && visibilityOptions.contains(loadedVisibility)) {
          visibility = loadedVisibility;
        }

        final loadedActivity = data?['target_activity_level']?.toString().trim();
        if (loadedActivity != null && activityLevelOptions.contains(loadedActivity)) {
          targetActivityLevel = loadedActivity;
        }

        final loadedGoal = data?['target_fitness_goal']?.toString().trim();
        if (loadedGoal != null && fitnessGoalOptions.contains(loadedGoal)) {
          targetFitnessGoal = loadedGoal;
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan settings: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMetadata = false;
        });
      }
    }
  }


  String _durationTextForSchedule() {
    final weeks = widget.plan.durationWeeks;

    if (weeks != null && weeks > 0) {
      return weeks == 1 ? '1 week' : '$weeks weeks';
    }

    return '4 weeks';
  }

  void _goToSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlanSchedule(
          plan: widget.plan,
          planName: planNameController.text.trim().isEmpty
              ? 'Untitled Plan'
              : planNameController.text.trim(),
          tags: [tagOne, tagTwo, tagThree],
          duration: _durationTextForSchedule(),
          visibility: visibility,
          targetActivityLevel: targetActivityLevel,
          targetFitnessGoal: targetFitnessGoal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.cardMuted,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: Text(
                      'Edit: ${widget.plan.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              if (isLoadingMetadata)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: planNameController,
                          decoration: _editInputDecoration(),
                        ),

                        const SizedBox(height: 30),

                        RichText(
                          text: TextSpan(
                            text: 'Tags ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: '(max 3)',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        _EditDropdown(
                          value: tagOne,
                          items: tagOptions,
                          onChanged: (value) {
                            setState(() {
                              tagOne = value;
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        _EditDropdown(
                          value: tagTwo,
                          items: tagOptions,
                          onChanged: (value) {
                            setState(() {
                              tagTwo = value;
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        _EditDropdown(
                          value: tagThree,
                          items: tagOptions,
                          onChanged: (value) {
                            setState(() {
                              tagThree = value;
                            });
                          },
                        ),

                        const SizedBox(height: 30),

                        const _FieldLabel('Visibility'),
                        const SizedBox(height: 10),
                        _EditDropdown(
                          value: visibility,
                          items: visibilityOptions,
                          onChanged: (value) {
                            setState(() {
                              visibility = value;
                            });
                          },
                        ),

                        const SizedBox(height: 30),

                        const _FieldLabel('Target Activity Level'),
                        const SizedBox(height: 10),
                        _EditDropdown(
                          value: targetActivityLevel,
                          items: activityLevelOptions,
                          onChanged: (value) {
                            setState(() {
                              targetActivityLevel = value;
                            });
                          },
                        ),

                        const SizedBox(height: 30),

                        const _FieldLabel('Target Fitness Goal'),
                        const SizedBox(height: 10),
                        _EditDropdown(
                          value: targetFitnessGoal,
                          items: fitnessGoalOptions,
                          onChanged: (value) {
                            setState(() {
                              targetFitnessGoal = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoadingMetadata ? null : _goToSchedule,
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 15,
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

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _EditDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String value) onChanged;

  const _EditDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;

    return DropdownButtonFormField<String>(
      value: safeValue,
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: AppColors.textMuted,
      ),
      decoration: _editInputDecoration(),
      dropdownColor: Colors.white,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

InputDecoration _editInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.cardMuted,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide.none,
    ),
  );
}
