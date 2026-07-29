import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
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

  @override
  void initState() {
    super.initState();
    loadPlans();
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

    final visibility = row['visibility']?.toString().trim().isEmpty == true
      ? 'Public'
      : row['visibility']?.toString() ?? 'Public';

    final tags = [
      row['tag1'],
      row['tag2'],
      row['tag3'],
    ]
        .where((tag) => tag != null && tag.toString().trim().isNotEmpty)
        .map((tag) => tag.toString())
        .toList();

    if (tags.isEmpty) {
      tags.add('Full Body');
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
    final deletedOrChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlanDetailScreen(plan: plan),
      ),
    );

    if (deletedOrChanged == true && mounted) {
      loadPlans();
    }
  }

  void openEditPlan(BuildContext context, WorkoutPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlan(plan: plan),
      ),
    );
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
                      color: Color(0xFFF3F2FA),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        'All Plans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: loadPlans,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.black54,
                    ),
                  ),
                ],
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
                              title: 'My Public Plans',
                              plans: publicPlans,
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
                              plans: privatePlans,
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
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(18),
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
                color: Colors.black,
              ),
              children: [
                TextSpan(
                  text: '(${plans.length})',
                  style: TextStyle(
                    color: Colors.grey.shade500,
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
                  'No plans yet.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
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