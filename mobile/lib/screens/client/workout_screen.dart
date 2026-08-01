import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock_data.dart';
import '../../models/client/professional.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/filter_chips.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/section_card.dart';
import '../../widgets/client/section_header.dart';

import 'chat_list_screen.dart';
import 'plan_detail_screen.dart';
import 'professional_detail_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _topTab = 0;

  String _filter = 'All';
  String _proFilter = 'All';

  bool _fpUnlocked = false;
  bool _isLoadingPlans = true;

  List<Map<String, dynamic>> _publicPlans = [];
  Map<String, dynamic>? _activePlan;
  String? _activePlanId;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  Future<void> _loadWorkoutData() async {
    setState(() {
      _isLoadingPlans = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      await _loadActivePlan(client, userId);
      await _loadPublicPlans(client);

      if (!mounted) return;

      final filters = _workoutFilters;
      if (!filters.contains(_filter)) {
        setState(() {
          _filter = 'All';
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workout data: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
        });
      }
    }
  }

  Future<void> _loadActivePlan(SupabaseClient client, String userId) async {
    final savedRows = await client
        .from('saved_plans')
        .select('saved_plan_id, free_plan_id, saved_at')
        .eq('profile_id', userId)
        .order('saved_at', ascending: false)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(savedRows as List);

    if (rows.isEmpty) {
      if (!mounted) return;

      setState(() {
        _activePlanId = null;
        _activePlan = null;
      });

      return;
    }

    final activePlanId = rows.first['free_plan_id']?.toString();

    if (activePlanId == null || activePlanId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _activePlanId = null;
        _activePlan = null;
      });

      return;
    }

    final activePlan = await client
        .from('free_plans')
        .select(
          'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at',
        )
        .eq('free_plan_id', activePlanId)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      _activePlanId = activePlanId;
      _activePlan = activePlan;
    });
  }

  Future<void> _loadPublicPlans(SupabaseClient client) async {
    final response = await client
        .from('free_plans')
        .select(
          'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at',
        )
        .ilike('visibility', 'public')
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      _publicPlans = List<Map<String, dynamic>>.from(response as List);
    });
  }

  List<String> get _workoutFilters {
    final tags = <String>{};

    for (final plan in _publicPlans) {
      for (final tag in _planTags(plan)) {
        final cleanTag = tag.trim();

        if (cleanTag.isEmpty) continue;
        if (cleanTag.toLowerCase() == 'public') continue;
        if (cleanTag.toLowerCase() == 'private') continue;

        tags.add(cleanTag);
      }
    }

    final result = tags.toList();
    result.sort();

    return ['All', ...result];
  }

  List<Map<String, dynamic>> get _visiblePlans {
    if (_filter == 'All') {
      return _publicPlans;
    }

    return _publicPlans.where((plan) {
      final tags = _planTags(plan);

      return tags.any(
        (tag) => tag.toLowerCase() == _filter.toLowerCase(),
      );
    }).toList();
  }

  List<String> _planTags(Map<String, dynamic> plan) {
    final tags = [
      plan['tag1'],
      plan['tag2'],
      plan['tag3'],
    ]
        .where((tag) => tag != null && tag.toString().trim().isNotEmpty)
        .map((tag) => tag.toString().trim())
        .toList();

    final category = plan['category']?.toString().trim();

    if (category != null && category.isNotEmpty) {
      final alreadyExists = tags.any(
        (tag) => tag.toLowerCase() == category.toLowerCase(),
      );

      if (!alreadyExists) {
        tags.add(category);
      }
    }

    if (tags.isEmpty) {
      tags.add('General');
    }

    return tags;
  }

  String _planTitle(Map<String, dynamic> plan) {
    final title = plan['plan_name']?.toString().trim();

    if (title == null || title.isEmpty) {
      return 'Untitled Plan';
    }

    return title;
  }

  String _durationText(Map<String, dynamic> plan) {
    final durationWeeks = _parseInt(plan['duration_weeks']);

    if (durationWeeks == null || durationWeeks <= 0) {
      return '30 Days';
    }

    return '${durationWeeks * 7} Days';
  }

  String _sessionLengthText(Map<String, dynamic> plan) {
    return '~45 min';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool _isActivePlan(Map<String, dynamic> plan) {
    final planId = plan['free_plan_id']?.toString();
    return planId != null && planId == _activePlanId;
  }

  Future<void> _openPlan(Map<String, dynamic> plan) async {
    final planId = plan['free_plan_id']?.toString();

    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan id.')),
      );
      return;
    }

    final switched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(
          planId: planId,
          title: _planTitle(plan),
        ),
      ),
    );

    if (switched == true && mounted) {
      await _loadWorkoutData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChatFab = _topTab == 1 && _fpUnlocked;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadWorkoutData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                16,
                AppSpacing.screenPadding,
                24,
              ),
              children: [
                _topToggle(),
                const SizedBox(height: 22),
                if (_topTab == 0)
                  ..._workoutTab()
                else if (_fpUnlocked)
                  ..._professionalsTab()
                else
                  _professionalLockedTab(),
              ],
            ),
          ),

          if (showChatFab)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatListScreen(),
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        children: [
          _toggleButton('Workout', 0),
          _toggleButton('Fitness Professional', 1),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, int index) {
    final selected = _topTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _topTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _workoutTab() {
    return [
      const SectionHeader('Active Plan'),

      const SizedBox(height: 12),

      if (_isLoadingPlans)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_activePlan == null)
        SectionCard(
          color: AppColors.cardMuted,
          radius: 16,
          child: const Text(
            'No active plan yet. Choose a public plan below.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
      else
        _planCard(
          plan: _activePlan!,
          active: true,
          onTap: () {
            _openPlan(_activePlan!);
          },
        ),

      const SizedBox(height: 24),

      const SectionHeader('Free Plans'),

      const SizedBox(height: 12),

      FilterChips(
        options: _workoutFilters,
        selected: _filter,
        onSelected: (value) {
          setState(() {
            _filter = value;
          });
        },
      ),

      const SizedBox(height: 16),

      if (_isLoadingPlans)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_visiblePlans.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No public plans in this category yet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
      else
        for (final plan in _visiblePlans) ...[
          _planCard(
            plan: plan,
            active: _isActivePlan(plan),
            onTap: () {
              _openPlan(plan);
            },
          ),
          const SizedBox(height: 14),
        ],
    ];
  }

  Widget _planCard({
    required Map<String, dynamic> plan,
    required bool active,
    required VoidCallback onTap,
  }) {
    final title = _planTitle(plan);
    final duration = _durationText(plan);
    final sessionLength = _sessionLengthText(plan);
    final tags = _planTags(plan);

    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        color: active ? AppColors.primarySoft : AppColors.cardMuted,
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              '$duration • $sessionLength',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags) PillTag(tag),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _professionalsTab() {
    return [
      TextField(
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search fitness professionals',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          suffixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.cardMuted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      const SizedBox(height: 20),

      const SectionHeader('More Fitness Professionals'),

      const SizedBox(height: 12),

      FilterChips(
        options: MockData.professionalFilters,
        selected: _proFilter,
        onSelected: (value) {
          setState(() {
            _proFilter = value;
          });
        },
      ),

      const SizedBox(height: 16),

      for (final professional in MockData.professionals) ...[
        _professionalCard(professional),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _professionalCard(Professional professional) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfessionalDetailScreen(
              professional: professional,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primarySoft,
              child: Icon(
                Icons.person,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    professional.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    professional.specialties,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${professional.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${professional.reviewCount} Reviews',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _professionalLockedTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        60,
        AppSpacing.screenPadding,
        24,
      ),
      child: Center(
        child: SectionCard(
          color: AppColors.primarySoft,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fitness Professional',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Get personalised workout plans, professional guidance, and direct messaging with fitness experts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _fpUnlocked = true;
                    });
                  },
                  icon: const Icon(
                    Icons.workspace_premium,
                    size: 18,
                  ),
                  label: const Text(
                    'Unlock Priority',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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