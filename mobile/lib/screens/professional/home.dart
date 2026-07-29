import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../widgets/professional/plan_card.dart';

import 'all_plans.dart';
import 'plan_detail.dart';
import 'exercise_library.dart';
import 'create_plan.dart';
import 'edit_plan.dart';

class ProfessionalHome extends StatefulWidget {
  const ProfessionalHome({super.key});

  @override
  State<ProfessionalHome> createState() => _ProfessionalHomeState();
}

class _ProfessionalHomeState extends State<ProfessionalHome> {
  bool isLoading = true;
  List<WorkoutPlan> publicPlans = [];

  String displayName = 'Professional';
  String avatarLetter = 'P';

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    await Future.wait([
      loadProfessionalProfile(),
      loadPublicPlans(),
    ]);
  }

  String getTodayText() {
    final now = DateTime.now();

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  String getFirstLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

  Future<void> loadProfessionalProfile() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      final profileRow = await client
          .from('profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();

      final professionalRow = await client
          .from('fitness_professional')
          .select('display_name')
          .eq('profile_id', userId)
          .maybeSingle();

      final professionalName =
          professionalRow?['display_name']?.toString().trim() ?? '';

      final profileName = profileRow?['full_name']?.toString().trim() ?? '';

      final name = professionalName.isNotEmpty
          ? professionalName
          : profileName.isNotEmpty
              ? profileName
              : 'Professional';

      if (!mounted) return;

      setState(() {
        displayName = name;
        avatarLetter = getFirstLetter(name);
      });
    } catch (_) {
      // Profile loading failure should not stop the home page.
    }
  }

  Future<void> loadPublicPlans() async {
    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          publicPlans = [];
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

      final rows = response as List<dynamic>;

      final plans = rows
          .map((row) => buildWorkoutPlanFromRow(row as Map<String, dynamic>))
          .where((plan) {
        final lowerTags = plan.tags.map((tag) => tag.toLowerCase()).toList();
        return !lowerTags.contains('private');
      }).toList();

      setState(() {
        publicPlans = plans;
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

    final visibility = row['visibility']?.toString() ?? 'Public';

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
      loadPublicPlans();
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

  Future<void> openCreatePlan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePlan(),
      ),
    );

    if (mounted) {
      loadPublicPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: loadHomeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getTodayText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hello, $displayName',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.black,
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Plans',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanMenuCard(
                          icon: Icons.calendar_month,
                          iconColor: const Color(0xFFDFFF5F),
                          title: 'All Plans',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllPlansScreen(),
                              ),
                            );

                            if (mounted) {
                              loadPublicPlans();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _PlanMenuCard(
                          icon: Icons.fitness_center,
                          iconColor: const Color(0xFFE1D9FF),
                          title: 'Exercise Library',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ExerciseLibrary(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      openCreatePlan(context);
                    },
                    icon: const Icon(
                      Icons.add,
                      size: 20,
                    ),
                    label: const Text(
                      'Create New Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Container(
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
                          text: 'My Public Plans ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(
                              text: '(${publicPlans.length})',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (publicPlans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'No public plans yet.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ...publicPlans.take(3).map((plan) {
                          return PlanCard(
                            plan: plan,
                            onView: () {
                              openPlanDetail(context, plan);
                            },
                            onEdit: () {
                              openEditPlan(context, plan);
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _PlanMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: iconColor,
                  child: Icon(
                    icon,
                    color: const Color(0xFF6C63FF),
                    size: 21,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}