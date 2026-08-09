import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../widgets/professional/plan_card.dart';

import 'edit_plan.dart';
import 'plan_detail.dart';

class AllPlansScreen extends StatefulWidget {
  const AllPlansScreen({super.key});

  @override
  State<AllPlansScreen> createState() => _AllPlansScreenState();
}

class _AllPlansScreenState extends State<AllPlansScreen> {
  bool isLoading = true;

  List<WorkoutPlan> publicPlans = [];
  List<WorkoutPlan> privatePlans = [];

  String selectedTag = 'All';

  @override
  void initState() {
    super.initState();
    loadPlans();
  }

  List<String> get availableTags {
    final tagSet = <String>{};

    for (final plan in [...publicPlans, ...privatePlans]) {
      for (final tag in plan.tags) {
        final cleanTag = tag.trim();

        if (cleanTag.isEmpty) continue;
        if (cleanTag.toLowerCase() == 'public') continue;
        if (cleanTag.toLowerCase() == 'private') continue;

        tagSet.add(cleanTag);
      }
    }

    final tags = tagSet.toList();
    tags.sort();

    return ['All', ...tags];
  }

  List<WorkoutPlan> get filteredPublicPlans {
    if (selectedTag == 'All') {
      return publicPlans;
    }

    return publicPlans.where((plan) {
      return plan.tags.any(
        (tag) => tag.toLowerCase() == selectedTag.toLowerCase(),
      );
    }).toList();
  }

  List<WorkoutPlan> get filteredPrivatePlans {
    if (selectedTag == 'All') {
      return privatePlans;
    }

    return privatePlans.where((plan) {
      return plan.tags.any(
        (tag) => tag.toLowerCase() == selectedTag.toLowerCase(),
      );
    }).toList();
  }

  Future<void> loadPlans() async {
    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          publicPlans = [];
          privatePlans = [];
        });
        return;
      }

      final response = await client
          .from('free_plans')
          .select(
            'free_plan_id, plan_name, tag1, tag2, tag3, visibility, duration_weeks, status, created_at',
          )
          .eq('professional_id', userId)
          .or('status.is.null,status.neq.archived')
          .order('created_at', ascending: false);

      final allPlans = (response as List<dynamic>).map((row) {
        return buildWorkoutPlanFromRow(row as Map<String, dynamic>);
      }).toList();

      final publicList = <WorkoutPlan>[];
      final privateList = <WorkoutPlan>[];

      for (final plan in allPlans) {
        if (plan.visibility.toLowerCase() == 'private') {
          privateList.add(plan);
        } else {
          publicList.add(plan);
        }
      }

      setState(() {
        publicPlans = publicList;
        privatePlans = privateList;

        final tags = availableTags;
        if (!tags.contains(selectedTag)) {
          selectedTag = 'All';
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plans: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  WorkoutPlan buildWorkoutPlanFromRow(Map<String, dynamic> row) {
    final durationWeeks = parseInt(row['duration_weeks']);
    final days = durationWeeks == null ? 30 : durationWeeks * 7;

    final visibilityValue = row['visibility']?.toString().trim();
    final visibility = visibilityValue == null || visibilityValue.isEmpty
        ? 'Public'
        : visibilityValue;

    final tags = [
      row['tag1'],
      row['tag2'],
      row['tag3'],
    ]
        .where((tag) => tag != null && tag.toString().trim().isNotEmpty)
        .map((tag) => tag.toString())
        .toList();

    if (tags.isEmpty) {
      tags.add('General');
    }

    return WorkoutPlan(
      freePlanId: row['free_plan_id']?.toString(),
      title: row['plan_name']?.toString() ?? 'Untitled Plan',
      days: days,
      duration: '~45 min',
      durationWeeks: durationWeeks,
      visibility: visibility,
      tags: tags,
      workoutDays: const [],
    );
  }

  int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<void> openPlanDetail(BuildContext context, WorkoutPlan plan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlanDetailScreen(plan: plan),
      ),
    );

    if (result == true && mounted) {
      loadPlans();
    }
  }

  Future<void> openEditPlan(BuildContext context, WorkoutPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlan(plan: plan),
      ),
    );

    if (mounted) {
      loadPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
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

                  const Expanded(
                    child: Center(
                      child: Text(
                        'Plans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 44),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: _TagFilterBar(
                tags: availableTags,
                selectedTag: selectedTag,
                onSelected: (tag) {
                  setState(() {
                    selectedTag = tag;
                  });
                },
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      onRefresh: loadPlans,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        child: Column(
                          children: [
                            _PlanSection(
                              title: 'My Available Plans',
                              plans: filteredPublicPlans,
                              onView: (plan) {
                                openPlanDetail(context, plan);
                              },
                              onEdit: (plan) {
                                openEditPlan(context, plan);
                              },
                            ),

                            const SizedBox(height: 18),

                            _PlanSection(
                              title: 'Private Plans',
                              plans: filteredPrivatePlans,
                              onView: (plan) {
                                openPlanDetail(context, plan);
                              },
                              onEdit: (plan) {
                                openEditPlan(context, plan);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagFilterBar extends StatelessWidget {
  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onSelected;

  const _TagFilterBar({
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final tag = tags[index];
          final selected = tag == selectedTag;

          return ChoiceChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) {
              onSelected(tag);
            },
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.card,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
          );
        },
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  final String title;
  final List<WorkoutPlan> plans;
  final void Function(WorkoutPlan plan) onView;
  final void Function(WorkoutPlan plan) onEdit;

  const _PlanSection({
    required this.title,
    required this.plans,
    required this.onView,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: '$title ',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: '(${plans.length})',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No plans found.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...plans.map((plan) {
              return PlanCard(
                plan: plan,
                onView: () {
                  onView(plan);
                },
                onEdit: () {
                  onEdit(plan);
                },
              );
            }),
        ],
      ),
    );
  }
}