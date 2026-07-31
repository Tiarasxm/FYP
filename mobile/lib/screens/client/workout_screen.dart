import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock_data.dart';
import '../../models/client/professional.dart';
import '../../models/client/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/filter_chips.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/plan_card.dart';
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
  late final WorkoutPlan _activePlan;

  bool _isLoadingPlans = true;
  List<Map<String, dynamic>> _freePlansData = [];
  String? _userType;

  @override
  void initState() {
    super.initState();
    _activePlan = MockData.activePlan();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final profile = await client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .single();

      final userType = profile['user_type'] as String?;

      final response = await client
          .from('free_plans')
          .select('free_plan_id, plan_name, tag1, tag2, tag3, visibility')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _userType = userType;
        _freePlansData = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plans: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visiblePlans {
    if (_filter == 'All') return _freePlansData;
    return _freePlansData.where((p) {
      final tags = [p['tag1'], p['tag2'], p['tag3']].whereType<String>();
      return tags.contains(_filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final showChatFab = _topTab == 1 && _fpUnlocked;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
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
                _professionalTab(),
            ],
          ),
          if (showChatFab)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ChatListScreen()),
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.chat_bubble_outline,
                    color: Colors.white),
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
        onTap: () => setState(() => _topTab = index),
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
      PlanCard(
        plan: _activePlan,
        onBookmarkTap: () =>
            setState(() => _activePlan.bookmarked = !_activePlan.bookmarked),
        // Active plan assignment isn't wired yet, so there's no real plan id here.
        onTap: () => _openPlan('', _activePlan.title),
      ),
      const SizedBox(height: 24),
      const SectionHeader('Free Plans'),
      const SizedBox(height: 12),
      FilterChips(
        options: MockData.workoutFilters,
        selected: _filter,
        onSelected: (value) => setState(() => _filter = value),
      ),
      const SizedBox(height: 16),
      if (_isLoadingPlans)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        for (final plan in _visiblePlans) ...[
          _freePlanCard(plan),
          const SizedBox(height: 14),
        ],
        if (_visiblePlans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No plans in this category yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    ];
  }

  Widget _freePlanCard(Map<String, dynamic> plan) {
    final tags = [plan['tag1'], plan['tag2'], plan['tag3']]
        .whereType<String>()
        .toList();
    final isPrivate = plan['visibility'] == 'Private';
    final isLocked = isPrivate && _userType != 'priority';
    final title = plan['plan_name'] as String? ?? 'Untitled Plan';

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showUpgradePrompt();
        } else {
          _openPlan(plan['free_plan_id'] as String, title);
        }
      },
      child: SectionCard(
        color: AppColors.cardMuted,
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
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.pillRadius),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'PRIORITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isPrivate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.pillRadius),
                    ),
                    child: const Text(
                      'PRIVATE',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags) PillTag(t),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPlan(String planId, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(planId: planId, title: title),
      ),
    );
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.lock, size: 34, color: AppColors.primary),
                const SizedBox(height: 14),
                const Text(
                  'Priority Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Subscribe to Priority to access this plan and get personalised guidance from fitness professionals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Upgrade to Priority',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Maybe later',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _professionalsTab() {
    return [
      TextField(
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search fitness professionals',
          hintStyle:
              const TextStyle(fontSize: 13, color: AppColors.textMuted),
          suffixIcon: const Icon(Icons.search,
              size: 20, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.cardMuted,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        onSelected: (value) => setState(() => _proFilter = value),
      ),
      const SizedBox(height: 16),
      for (final pro in MockData.professionals) ...[
        _professionalCard(pro),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _professionalCard(Professional pro) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfessionalDetailScreen(professional: pro),
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
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pro.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pro.specialties,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '${pro.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pro.reviewCount} Reviews',
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _professionalTab() {
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
                  onPressed: () => setState(() => _fpUnlocked = true),
                  icon: const Icon(Icons.workspace_premium, size: 18),
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
