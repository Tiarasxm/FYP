import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/professional.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/filter_chips.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/section_card.dart';
import '../../widgets/client/section_header.dart';

import 'chat_list_screen.dart';
import 'plan_detail_screen.dart';
import 'professional_detail_screen.dart';
import 'membership_page.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _topTab = 0;

  String _filter = 'All';
  String _proFilter = 'All';
  String _durationFilter = 'All';

  final _planSearchController = TextEditingController();
  String _planSearchText = '';

  bool _isPriority = false;
  bool _isLoadingPlans = true;
  bool _isLoadingPros = true;

  String? _userActivityLevel;
  String? _userFitnessGoal;

  List<Map<String, dynamic>> _availablePlans = [];
  Map<String, dynamic>? _activePlan;
  String? _activePlanId;

  Set<String> _savedPlanIds = {};
  int _savedPlanCount = 0;

  List<Professional> _professionals = [];
  String _proSearchText = '';

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _planSearchController.dispose();
    super.dispose();
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

      await _loadUserProfileForRecommendation(client, userId);
      await _loadActivePlan(client, userId);
      await _loadAvailablePlans(client);
      await _loadSavedPlanStatus(client, userId);

      if (_isPriority) {
        await _loadProfessionals(client);
      } else {
        if (!mounted) return;
        setState(() {
          _professionals = [];
          _isLoadingPros = false;
        });
      }

      if (!mounted) return;

      if (_isPriority) {
        setState(() => _isLoadingPros = false);
      }

      final filters = _workoutFilters;
      if (!filters.contains(_filter)) {
        setState(() {
          _filter = 'All';
        });
      }

      if (!_durationFilters.contains(_durationFilter)) {
        setState(() {
          _durationFilter = 'All';
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
          _isLoadingPros = false;
        });
      }
    }
  }

  Future<void> _loadUserProfileForRecommendation(
    SupabaseClient client,
    String userId,
  ) async {
    final profile = await client
        .from('profiles')
        .select('user_type, activity_level, fitness_goal')
        .eq('id', userId)
        .maybeSingle();

    final userType =
        profile?['user_type']?.toString().trim().toLowerCase() ?? 'free';
    final isPriority = userType == 'priority';

    if (!mounted) return;

    setState(() {
      _isPriority = isPriority;
      _isLoadingPros = isPriority;
      _userActivityLevel = profile?['activity_level']?.toString().trim();
      _userFitnessGoal = profile?['fitness_goal']?.toString().trim();
    });
  }

  Future<void> _loadActivePlan(SupabaseClient client, String userId) async {
    final savedRows = await client
        .from('saved_plans')
        .select('saved_plan_id, free_plan_id, personalized_plan_id, is_active, saved_at')
        .eq('profile_id', userId)
        .eq('is_active', true)
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
          'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at, target_activity_level, target_fitness_goal',
        )
        .eq('free_plan_id', activePlanId)
        .or('status.is.null,status.neq.archived')
        .maybeSingle();

    if (!mounted) return;

    final visibility =
        activePlan?['visibility']?.toString().trim().toLowerCase() ?? 'public';

    if (activePlan == null || (!_isPriority && visibility != 'public')) {
      setState(() {
        _activePlanId = null;
        _activePlan = null;
      });
      return;
    }

    setState(() {
      _activePlanId = activePlanId;
      _activePlan = activePlan;
    });
  }

  Future<void> _loadSavedPlanStatus(
    SupabaseClient client,
    String userId,
  ) async {
    final response = await client
        .from('saved_plans')
        .select('free_plan_id, is_saved')
        .eq('profile_id', userId)
        .eq('is_saved', true);

    final rows = List<Map<String, dynamic>>.from(response as List);

    final savedIds = rows
        .map((row) => row['free_plan_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();

    if (!mounted) return;

    setState(() {
      _savedPlanIds = savedIds;
      _savedPlanCount = savedIds.length;
    });
  }

  Future<void> _loadAvailablePlans(SupabaseClient client) async {
    dynamic response;

    const selectFields =
        'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at, target_activity_level, target_fitness_goal';

    if (_isPriority) {
      response = await client
          .from('free_plans')
          .select(selectFields)
          .or('status.is.null,status.neq.archived')
          .order('created_at', ascending: false);
    } else {
      response = await client
          .from('free_plans')
          .select(selectFields)
          .ilike('visibility', 'public')
          .or('status.is.null,status.neq.archived')
          .order('created_at', ascending: false);
    }

    final plans = List<Map<String, dynamic>>.from(response as List);

    if (_isPriority) {
      plans.removeWhere((plan) {
        final visibility =
            plan['visibility']?.toString().trim().toLowerCase() ?? '';
        return visibility != 'public' && visibility != 'private';
      });
    }

    plans.sort((a, b) {
      final scoreA = _recommendationScore(a);
      final scoreB = _recommendationScore(b);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      final createdA = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final createdB = DateTime.tryParse(b['created_at']?.toString() ?? '');

      if (createdA == null || createdB == null) return 0;
      return createdB.compareTo(createdA);
    });

    if (!mounted) return;

    setState(() {
      _availablePlans = plans;
    });
  }

  int _recommendationScore(Map<String, dynamic> plan) {
    int score = 0;

    final userGoal = _normalize(_userFitnessGoal);
    final userActivity = _normalize(_userActivityLevel);

    final planGoal = _normalize(plan['target_fitness_goal']);
    final planActivity = _normalize(plan['target_activity_level']);

    final planName = _normalize(plan['plan_name']);
    final category = _normalize(plan['category']);
    final tag1 = _normalize(plan['tag1']);
    final tag2 = _normalize(plan['tag2']);
    final tag3 = _normalize(plan['tag3']);

    final textPool = '$planName $category $tag1 $tag2 $tag3';

    if (userGoal.isNotEmpty) {
      if (planGoal == userGoal) {
        score += 60;
      } else if (_textContainsGoal(textPool, userGoal)) {
        score += 40;
      }
    }

    if (userActivity.isNotEmpty && planActivity == userActivity) {
      score += 25;
    }

    return score;
  }

  bool _textContainsGoal(String textPool, String userGoal) {
    final keywords = _goalKeywords(userGoal);

    return keywords.any((keyword) {
      return textPool.contains(keyword);
    });
  }

  List<String> _goalKeywords(String goal) {
    switch (goal) {
      case 'lose weight':
        return [
          'lose weight',
          'weight loss',
          'fat loss',
          'fat burn',
          'burn fat',
          'slim',
        ];

      case 'build muscles':
        return [
          'build muscles',
          'build muscle',
          'muscle gain',
          'strength',
          'hypertrophy',
          'bodybuilding',
        ];

      case 'gain weight':
        return [
          'gain weight',
          'weight gain',
          'bulk',
          'bulking',
          'mass gain',
          'muscle gain',
        ];

      case 'improve endurance':
        return [
          'improve endurance',
          'endurance',
          'cardio',
          'stamina',
          'running',
          'conditioning',
        ];

      case 'get fitter':
        return [
          'get fitter',
          'fitness',
          'general',
          'full body',
          'conditioning',
          'active',
        ];

      default:
        return [goal];
    }
  }

  String _normalize(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  List<String> get _workoutFilters {
    final tags = <String>{};

    for (final plan in _availablePlans) {
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

  List<String> get _durationFilters {
    return const ['All', '7 Days', '14 Days', '30 Days'];
  }

  List<Map<String, dynamic>> get _visiblePlans {
    var plans = List<Map<String, dynamic>>.from(_availablePlans);

    if (_planSearchText.trim().isNotEmpty) {
      final query = _planSearchText.trim().toLowerCase();
      plans = plans.where((plan) {
        final name = _planTitle(plan).toLowerCase();
        final tags = _planTags(plan).join(' ').toLowerCase();
        return name.contains(query) || tags.contains(query);
      }).toList();
    }

    if (_filter != 'All') {
      plans = plans.where((plan) {
        final tags = _planTags(plan);
        return tags.any(
          (tag) => tag.toLowerCase() == _filter.toLowerCase(),
        );
      }).toList();
    }

    if (_durationFilter != 'All') {
      plans = plans.where((plan) {
        return _durationText(plan) == _durationFilter;
      }).toList();
    }

    plans.sort((a, b) {
      final scoreA = _recommendationScore(a);
      final scoreB = _recommendationScore(b);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      final createdA = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final createdB = DateTime.tryParse(b['created_at']?.toString() ?? '');

      if (createdA == null || createdB == null) return 0;
      return createdB.compareTo(createdA);
    });

    return plans;
  }

  List<Map<String, dynamic>> get _recommendedPlans {
    return _visiblePlans.where((plan) {
      return _recommendationScore(plan) > 0;
    }).toList();
  }

  List<Map<String, dynamic>> get _otherPlans {
    return _visiblePlans.where((plan) {
      return _recommendationScore(plan) <= 0;
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

  Future<void> _loadProfessionals(SupabaseClient client) async {
    final data = await client
        .from('fitness_professional')
        .select(
          'profile_id, display_name, bio, experience, specializations, approved, profiles!inner(full_name)',
        )
        .eq('approved', true);

    final rows = List<Map<String, dynamic>>.from(data as List);

    final profileIds = rows
        .map((row) => row['profile_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    final ratingTotals = <String, double>{};
    final ratingCounts = <String, int>{};

    if (profileIds.isNotEmpty) {
      final reviewData = await client
          .from('reviews')
          .select('professional_id, rating')
          .inFilter('professional_id', profileIds);

      final reviewRows = List<Map<String, dynamic>>.from(reviewData as List);

      for (final review in reviewRows) {
        final professionalId = review['professional_id']?.toString();

        if (professionalId == null || professionalId.isEmpty) {
          continue;
        }

        final rating = (review['rating'] as num?)?.toDouble() ?? 0;

        ratingTotals[professionalId] =
            (ratingTotals[professionalId] ?? 0) + rating;
        ratingCounts[professionalId] = (ratingCounts[professionalId] ?? 0) + 1;
      }
    }

    final pros = <Professional>[];

    for (final row in rows) {
      final profileId = row['profile_id']?.toString() ?? '';
      final reviewCount = ratingCounts[profileId] ?? 0;
      final avgRating = reviewCount > 0
          ? (ratingTotals[profileId] ?? 0) / reviewCount
          : 0.0;

      row['avg_rating'] = avgRating;
      row['review_count'] = reviewCount;

      pros.add(Professional.fromSupabase(row));
    }

    if (!mounted) return;

    setState(() {
      _professionals = pros;
    });
  }

  List<String> get _professionalFilters {
    final specSet = <String>{};
    for (final pro in _professionals) {
      final specs = pro.specialties.split(RegExp(r'[•,]'));
      for (final s in specs) {
        final clean = s.trim();
        if (clean.isNotEmpty) specSet.add(clean);
      }
    }
    final result = specSet.toList()..sort();
    return ['All', ...result];
  }

  List<Professional> get _filteredProfessionals {
    var list = _professionals;
    if (_proSearchText.isNotEmpty) {
      list = list
          .where(
            (p) => p.name.toLowerCase().contains(_proSearchText.toLowerCase()),
          )
          .toList();
    }
    if (_proFilter != 'All') {
      list = list
          .where(
            (p) => p.specialties.toLowerCase().contains(_proFilter.toLowerCase()),
          )
          .toList();
    }
    return list;
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

  bool _isSavedPlan(Map<String, dynamic> plan) {
    final planId = plan['free_plan_id']?.toString();
    return planId != null && _savedPlanIds.contains(planId);
  }

  Future<void> _toggleSavePlan(Map<String, dynamic> plan) async {
    final planId = plan['free_plan_id']?.toString();

    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan id.')),
      );
      return;
    }

    if (_isSavedPlan(plan)) {
      await _removeSavedPlan(planId);
    } else {
      await _savePlan(planId);
    }
  }

  Future<void> _savePlan(String planId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    try {
      if (!_isPriority && !_savedPlanIds.contains(planId) && _savedPlanCount >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Free users can save up to 5 plans. Remove one saved plan first.',
            ),
          ),
        );
        return;
      }

      final existingResponse = await client
          .from('saved_plans')
          .select('saved_plan_id, is_active')
          .eq('profile_id', userId)
          .eq('free_plan_id', planId)
          .limit(1);

      final existingRows =
          List<Map<String, dynamic>>.from(existingResponse as List);

      final now = DateTime.now().toUtc().toIso8601String();

      if (existingRows.isEmpty) {
        await client.from('saved_plans').insert({
          'profile_id': userId,
          'free_plan_id': planId,
          'personalized_plan_id': null,
          'is_saved': true,
          'is_active': false,
          'saved_at': now,
        });
      } else {
        final savedPlanId = existingRows.first['saved_plan_id']?.toString();

        if (savedPlanId == null || savedPlanId.isEmpty) {
          throw Exception('Missing saved_plan_id.');
        }

        await client
            .from('saved_plans')
            .update({
              'is_saved': true,
              'saved_at': now,
            })
            .eq('saved_plan_id', savedPlanId)
            .eq('profile_id', userId);
      }

      await _loadSavedPlanStatus(client, userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan saved.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plan: $error')),
      );
    }
  }

  Future<void> _removeSavedPlan(String planId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    try {
      final existingResponse = await client
          .from('saved_plans')
          .select('saved_plan_id, is_active')
          .eq('profile_id', userId)
          .eq('free_plan_id', planId)
          .limit(1);

      final existingRows =
          List<Map<String, dynamic>>.from(existingResponse as List);

      if (existingRows.isEmpty) {
        await _loadSavedPlanStatus(client, userId);
        return;
      }

      final row = existingRows.first;
      final savedPlanId = row['saved_plan_id']?.toString();
      final isActive = row['is_active'] == true;

      if (savedPlanId == null || savedPlanId.isEmpty) {
        throw Exception('Missing saved_plan_id.');
      }

      if (isActive) {
        await client
            .from('saved_plans')
            .update({'is_saved': false})
            .eq('saved_plan_id', savedPlanId)
            .eq('profile_id', userId);
      } else {
        await client
            .from('saved_plans')
            .delete()
            .eq('saved_plan_id', savedPlanId)
            .eq('profile_id', userId);
      }

      await _loadSavedPlanStatus(client, userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved plans.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove saved plan: $error')),
      );
    }
  }

  Future<void> _openPlan(Map<String, dynamic> plan) async {
    final planId = plan['free_plan_id']?.toString();
    final visibility =
        plan['visibility']?.toString().trim().toLowerCase() ?? 'public';

    if (!_isPriority && visibility != 'public') {
      await _openMembership();
      return;
    }

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

  Future<void> _openMembership() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MembershipPage()),
    );

    if (mounted) {
      await _loadWorkoutData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChatFab = _topTab == 1 && _isPriority;

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
                else if (_isPriority)
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

  Widget _planSearchField() {
    return TextField(
      controller: _planSearchController,
      decoration: InputDecoration(
        hintText: 'Search by plan name',
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: _planSearchText.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _planSearchController.clear();
                  setState(() {
                    _planSearchText = '';
                  });
                },
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      onChanged: (value) {
        setState(() {
          _planSearchText = value;
        });
      },
    );
  }

  bool get _hasActiveFilters =>
      _filter != 'All' || _durationFilter != 'All';

  int get _activeFilterCount {
    var count = 0;
    if (_filter != 'All') count++;
    if (_durationFilter != 'All') count++;
    return count;
  }

  Widget _filterButton() {
    final active = _hasActiveFilters;

    return GestureDetector(
      onTap: _showFilterPopup,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune,
              size: 20,
              color: active ? Colors.white : AppColors.primary,
            ),
            if (_activeFilterCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterPopup() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _workoutFilters.map((option) {
                        final selected = option == _filter;
                        return _filterChip(
                          label: option,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _filter = option;
                            });
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _durationFilters.map((option) {
                        final selected = option == _durationFilter;
                        return _filterChip(
                          label: option,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _durationFilter = option;
                            });
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _filter = 'All';
                                _durationFilter = 'All';
                              });
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Show ${_visiblePlans.length} results',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
            );
          },
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
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
    final recommendedPlans = _recommendedPlans;
    final otherPlans = _otherPlans;

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
          child: Text(
            'No active plan yet. Choose a plan below.',
            style: const TextStyle(
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
          showRecommendation: _recommendationScore(_activePlan!) > 0,
          onTap: () {
            _openPlan(_activePlan!);
          },
        ),

      const SizedBox(height: 24),

      const SectionHeader('Available Plans'),

      const SizedBox(height: 12),

      Row(
        children: [
          Expanded(child: _planSearchField()),
          const SizedBox(width: 10),
          _filterButton(),
        ],
      ),

      const SizedBox(height: 16),

      if (_isLoadingPlans)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_visiblePlans.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No plans match your search or filters.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
      else ...[
        if (recommendedPlans.isNotEmpty) ...[
          const SectionHeader('Recommended for You'),
          const SizedBox(height: 12),
          for (final plan in recommendedPlans) ...[
            _planCard(
              plan: plan,
              active: _isActivePlan(plan),
              showRecommendation: true,
              onTap: () {
                _openPlan(plan);
              },
            ),
            const SizedBox(height: 14),
          ],
          if (otherPlans.isNotEmpty) const SizedBox(height: 10),
        ],
        if (otherPlans.isNotEmpty) ...[
          if (recommendedPlans.isNotEmpty) ...[
            const SectionHeader('Other Plans'),
            const SizedBox(height: 12),
          ],
          for (final plan in otherPlans) ...[
            _planCard(
              plan: plan,
              active: _isActivePlan(plan),
              showRecommendation: false,
              onTap: () {
                _openPlan(plan);
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    ];
  }

  Widget _planCard({
    required Map<String, dynamic> plan,
    required bool active,
    required VoidCallback onTap,
    bool showRecommendation = false,
  }) {
    final title = _planTitle(plan);
    final duration = _durationText(plan);
    final sessionLength = _sessionLengthText(plan);
    final tags = _planTags(plan);
    final visibility =
        plan['visibility']?.toString().trim().toLowerCase() ?? 'public';
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

                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => _toggleSavePlan(plan),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      _isSavedPlan(plan)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 18,
                      color: _isSavedPlan(plan)
                          ? AppColors.primary
                          : AppColors.textSecondary,
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
                PillTag(visibility == 'private' ? 'Private' : 'Public'),
                if (_isSavedPlan(plan)) const PillTag('Saved'),
                if (showRecommendation) const PillTag('Recommended'),
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
        onChanged: (value) {
          setState(() {
            _proSearchText = value;
          });
        },
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
        options: _professionalFilters,
        selected: _proFilter,
        onSelected: (value) {
          setState(() {
            _proFilter = value;
          });
        },
      ),

      const SizedBox(height: 16),

      if (_isLoadingPros)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_filteredProfessionals.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No professionals found',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        )
      else
        for (final professional in _filteredProfessionals) ...[
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
                  onPressed: _openMembership,
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
