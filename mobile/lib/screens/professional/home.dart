import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../theme/app_theme.dart';
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
  List<WorkoutPlan> privatePlans = [];

  String selectedTag = 'All';

  String displayName = 'Professional';
  String avatarLetter = 'P';
  String? avatarUrl;

  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  Future<void> loadHomeData() async {
    await Future.wait([
      loadProfessionalProfile(),
      loadPlans(),
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

  Future<void> loadProfessionalProfile() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      final profileRow = await client
          .from('profiles')
          .select('full_name, email, avatar_url')
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

      final url = profileRow?['avatar_url']?.toString().trim();

      if (!mounted) return;

      setState(() {
        displayName = name;
        avatarLetter = getFirstLetter(name);
        avatarUrl = (url != null && url.isNotEmpty) ? url : null;
      });

      _subscribeToProfile(client, userId);
    } catch (_) {
    }
  }

  void _subscribeToProfile(SupabaseClient client, String userId) {
    if (_profileChannel != null) return;

    _profileChannel = client
        .channel('public:profiles:pro_home:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final fullName = record['full_name']?.toString().trim();
            final url = record['avatar_url']?.toString().trim();

            if (!mounted) return;
            setState(() {
              if (fullName != null && fullName.isNotEmpty) {
                displayName = fullName;
                avatarLetter = getFirstLetter(fullName);
              }
              avatarUrl = (url != null && url.isNotEmpty) ? url : null;
            });
          },
        )
        .subscribe();
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

      final rows = response as List<dynamic>;

      final allPlans = rows.map((row) {
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
    final visibility =
        visibilityValue == null || visibilityValue.isEmpty ? 'Public' : visibilityValue;

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

  Future<void> openCreatePlan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePlan(),
      ),
    );

    if (mounted) {
      loadPlans();
    }
  }

  Future<void> openAllPlans(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllPlansScreen(),
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
        bottom: false,
        child: RefreshIndicator(
          onRefresh: loadHomeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getTodayText(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hello, $displayName',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                      child: avatarUrl == null
                          ? Text(
                              avatarLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Plans',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanMenuCard(
                          icon: Icons.calendar_month,
                          iconColor: const Color(0xFFDFFF5F),
                          title: 'Plans',
                          onTap: () {
                            openAllPlans(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _PlanMenuCard(
                          icon: Icons.fitness_center,
                          iconColor: AppColors.primarySoft,
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
                  ),
                ),

                const SizedBox(height: 14),

                _TagFilterBar(
                  tags: availableTags,
                  selectedTag: selectedTag,
                  onSelected: (tag) {
                    setState(() {
                      selectedTag = tag;
                    });
                  },
                ),

                const SizedBox(height: 18),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
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
              ],
            ),
          ),
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
                    color: AppColors.primary,
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
                    color: AppColors.textPrimary,
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
              padding: const EdgeInsets.symmetric(vertical: 22),
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