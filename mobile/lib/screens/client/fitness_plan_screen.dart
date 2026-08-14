import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'active_workout_screen.dart';

class FitnessPlanScreen extends StatefulWidget {
  const FitnessPlanScreen({super.key});

  @override
  State<FitnessPlanScreen> createState() => _FitnessPlanScreenState();
}

class _FitnessPlanScreenState extends State<FitnessPlanScreen> {
  bool _isLoading = true;

  String? _planId;
  String? _planTitle;
  bool _isPersonalized = false;

  List<Map<String, dynamic>> _days = [];
  List<Map<String, dynamic>> _exercises = [];

  Set<String> _completedDayIds = {};
  String? _latestCompletedDayId;

  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadActivePlan();
  }

  Map<String, dynamic>? get _selectedDay {
    if (_days.isEmpty) return null;
    if (_selectedDayIndex < 0 || _selectedDayIndex >= _days.length) return null;
    return _days[_selectedDayIndex];
  }

  bool get _isRestDay {
    return _selectedDay?['is_rest_day'] == true;
  }

  bool get _isSelectedDayCompleted {
    final dayId = _selectedDay?['plan_day_id']?.toString();
    if (dayId == null || dayId.isEmpty) return false;
    return _completedDayIds.contains(dayId);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int _initialDayIndex({
    required List<Map<String, dynamic>> days,
    required Set<String> completedDayIds,
    required String? latestCompletedDayId,
  }) {
    if (days.isEmpty) return 0;

    // Main rule:
    // 1. Show the first unfinished workout day.
    // 2. Rest days do not block progress.
    // 3. If all workout days are completed, show the latest completed day.
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final isRestDay = day['is_rest_day'] == true;
      final dayId = day['plan_day_id']?.toString();

      if (isRestDay) continue;

      if (dayId == null || dayId.isEmpty) {
        return i;
      }

      if (!completedDayIds.contains(dayId)) {
        return i;
      }
    }

    if (latestCompletedDayId != null && latestCompletedDayId.isNotEmpty) {
      final latestIndex = days.indexWhere((day) {
        return day['plan_day_id']?.toString() == latestCompletedDayId;
      });

      if (latestIndex != -1) {
        return latestIndex;
      }
    }

    // If the plan has only rest days, just show the first day.
    return 0;
  }

  Future<void> _loadActivePlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final profile = await client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType =
          profile?['user_type']?.toString().trim().toLowerCase() ?? 'free';
      final isPriority = userType == 'priority';

      final savedResponse = await client
          .from('saved_plans')
          .select('free_plan_id, personalized_plan_id, is_active, saved_at')
          .eq('profile_id', userId)
          .eq('is_active', true)
          .order('saved_at', ascending: false)
          .limit(1);

      final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

      if (savedRows.isEmpty) {
        if (!mounted) return;

        setState(() {
          _planId = null;
          _planTitle = null;
          _isPersonalized = false;
          _days = [];
          _exercises = [];
          _completedDayIds = {};
          _latestCompletedDayId = null;
          _selectedDayIndex = 0;
        });

        return;
      }

      final activeSavedRow = savedRows.first;
      final freePlanId = activeSavedRow['free_plan_id']?.toString();
      final personalizedPlanId =
          activeSavedRow['personalized_plan_id']?.toString();
      final isPersonalized =
          personalizedPlanId != null && personalizedPlanId.isNotEmpty;
      final planId = isPersonalized ? personalizedPlanId : freePlanId;

      if (planId == null || planId.isEmpty) {
        throw Exception('Missing active plan id.');
      }

      String? planName;

      if (isPersonalized) {
        final plan = await client
            .from('personalized_plans')
            .select('personalized_plan_id, plan_name, status')
            .eq('personalized_plan_id', planId)
            .or('status.is.null,status.neq.archived')
            .maybeSingle();

        if (plan == null) {
          if (!mounted) return;

          setState(() {
            _planId = null;
            _planTitle = null;
            _isPersonalized = false;
            _days = [];
            _exercises = [];
            _completedDayIds = {};
            _latestCompletedDayId = null;
            _selectedDayIndex = 0;
          });

          return;
        }

        planName = plan['plan_name']?.toString();
      } else {
        final plan = await client
            .from('free_plans')
            .select('free_plan_id, plan_name, visibility, status')
            .eq('free_plan_id', planId)
            .or('status.is.null,status.neq.archived')
            .maybeSingle();

        final visibility =
            plan?['visibility']?.toString().trim().toLowerCase() ?? 'public';

        if (plan == null || (!isPriority && visibility != 'public')) {
          if (!mounted) return;

          setState(() {
            _planId = null;
            _planTitle = null;
            _isPersonalized = false;
            _days = [];
            _exercises = [];
            _completedDayIds = {};
            _latestCompletedDayId = null;
            _selectedDayIndex = 0;
          });

          return;
        }

        planName = plan['plan_name']?.toString();
      }

      final daysResponse = isPersonalized
          ? await client
              .from('personalized_plan_days')
              .select(
                'personalized_plan_day_id, week_number, day_number, day_name, is_rest_day',
              )
              .eq('personalized_plan_id', planId)
              .order('week_number', ascending: true)
              .order('day_number', ascending: true)
          : await client
              .from('plan_days')
              .select(
                'plan_day_id, week_number, day_number, day_name, is_rest_day',
              )
              .eq('free_plan_id', planId)
              .order('week_number', ascending: true)
              .order('day_number', ascending: true);

      final days = List<Map<String, dynamic>>.from(daysResponse as List).map((day) {
        return isPersonalized
            ? {
                ...day,
                'plan_day_id': day['personalized_plan_day_id'],
              }
            : day;
      }).toList();

      days.sort((a, b) {
        final aWeek = _parseInt(a['week_number']) ?? 0;
        final bWeek = _parseInt(b['week_number']) ?? 0;

        if (aWeek != bWeek) {
          return aWeek.compareTo(bWeek);
        }

        final aDay = _parseInt(a['day_number']) ?? 0;
        final bDay = _parseInt(b['day_number']) ?? 0;

        return aDay.compareTo(bDay);
      });

      final completedLogsResponse = await client
          .from('workout_logs')
          .select('plan_day_id, performed_at')
          .eq('profile_id', userId)
          .eq(isPersonalized ? 'personalized_plan_id' : 'free_plan_id', planId)
          .not('plan_day_id', 'is', null)
          .order('performed_at', ascending: false);

      final completedRows = List<Map<String, dynamic>>.from(
        completedLogsResponse as List,
      );

      final completedDayIds = completedRows
          .map((row) => row['plan_day_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final latestCompletedDayId = completedRows.isEmpty
          ? null
          : completedRows.first['plan_day_id']?.toString();

      final initialIndex = _initialDayIndex(
        days: days,
        completedDayIds: completedDayIds,
        latestCompletedDayId: latestCompletedDayId,
      );

      if (!mounted) return;

      setState(() {
        _planId = planId;
        _planTitle = planName ?? 'My Fitness Plan';
        _isPersonalized = isPersonalized;
        _days = days;
        _completedDayIds = completedDayIds;
        _latestCompletedDayId = latestCompletedDayId;
        _selectedDayIndex = initialIndex;
      });

      await _loadExercisesForSelectedDay();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load fitness plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadExercisesForSelectedDay() async {
    final selectedDay = _selectedDay;

    if (selectedDay == null || selectedDay['is_rest_day'] == true) {
      setState(() {
        _exercises = [];
      });
      return;
    }

    final planDayId = selectedDay['plan_day_id']?.toString();

    if (planDayId == null || planDayId.isEmpty) {
      setState(() {
        _exercises = [];
      });
      return;
    }

    final response = _isPersonalized
        ? await Supabase.instance.client
            .from('personalized_plan_exercises')
            .select(
              'personalized_plan_exercise_id, exercise_id, sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)',
            )
            .eq('personalized_plan_day_id', planDayId)
            .order('order_index')
        : await Supabase.instance.client
            .from('plan_exercises')
            .select(
              'plan_exercise_id, exercise_id, sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)',
            )
            .eq('plan_day_id', planDayId)
            .order('order_index');

    if (!mounted) return;

    setState(() {
      _exercises = List<Map<String, dynamic>>.from(response as List);
    });
  }

  void _selectDay(int index) {
    setState(() {
      _selectedDayIndex = index;
    });

    _loadExercisesForSelectedDay();
  }

  void _startWorkout() {
    final planId = _planId;
    final selectedDay = _selectedDay;
    final planDayId = selectedDay?['plan_day_id']?.toString();

    if (planId == null ||
        planId.isEmpty ||
        planDayId == null ||
        planDayId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout day selected.')),
      );
      return;
    }

    if (_isRestDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is a rest day.')),
      );
      return;
    }

    if (_isSelectedDayCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This workout day is already completed.')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercises in this day.')),
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ActiveWorkoutScreen(
              planId: planId,
              planTitle: _planTitle ?? 'My Fitness Plan',
              planDayId: planDayId,
              dayLabel: _dayTitle(),
              isPersonalized: _isPersonalized,
            ),
          ),
        )
        .then((_) => _loadActivePlan());
  }

  String _dayTitle() {
    final day = _selectedDay;

    if (day == null) return 'Workout';

    final dayNumber = day['day_number']?.toString() ?? '1';
    final dayName = day['day_name']?.toString().trim();
    final planName = _planTitle ?? 'My Fitness Plan';

    if (dayName == null || dayName.isEmpty) {
      return '$planName - Day $dayNumber';
    }

    return '$planName - Day $dayNumber: $dayName';
  }

  String _dayMeta() {
    final planName = _planTitle ?? 'My Fitness Plan';

    if (_isRestDay) {
      return '$planName • Rest Day';
    }

    if (_isSelectedDayCompleted) {
      return '$planName • Completed';
    }

    return '$planName • ${_exercises.length} exercises';
  }

  String _exerciseMeta(Map<String, dynamic> exercise) {
    final sets = _parseInt(exercise['sets']) ?? 0;
    final repMin = _parseInt(exercise['rep_min']);
    final repMax = _parseInt(exercise['rep_max']);
    final restSec = _parseInt(exercise['rest_sec']) ?? 60;

    String repsText;

    if (repMin == null && repMax == null) {
      repsText = '- reps';
    } else if (repMin != null && (repMax == null || repMin == repMax)) {
      repsText = '$repMin reps';
    } else {
      repsText = '${repMin ?? '-'}-${repMax ?? '-'} reps';
    }

    return '$sets × $repsText • ${restSec}s rest';
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'My Fitness Plan',
      bottomButton: _bottomButton(),
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_planId == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Set an active plan from the Workout tab or Saved Plans.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No days in this plan yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          _dayStrip(),
          const SizedBox(height: 18),
          _dayBanner(),
          const SizedBox(height: 16),
          if (_isRestDay)
            _restDayView()
          else if (_exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No exercises in this day.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            for (var i = 0; i < _exercises.length; i++) ...[
              _exerciseRow(_exercises[i], i),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }

  Widget? _bottomButton() {
    if (_isLoading || _planId == null || _days.isEmpty) return null;
    if (_isRestDay) return null;

    if (_isSelectedDayCompleted) {
      return const PrimaryButton(
        label: 'Completed',
        icon: Icons.check,
        onPressed: null,
      );
    }

    return PrimaryButton(
      label: 'Start Workout',
      icon: Icons.chevron_right,
      onPressed: _startWorkout,
    );
  }

  Widget _restDayView() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.self_improvement,
              color: AppColors.primary,
              size: 34,
            ),
            SizedBox(height: 10),
            Text(
              'Rest Day',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'No workout scheduled for this day.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayStrip() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = _days[index];
          final selected = index == _selectedDayIndex;
          final dayId = day['plan_day_id']?.toString();
          final completed =
              dayId != null && dayId.isNotEmpty && _completedDayIds.contains(dayId);
          final rest = day['is_rest_day'] == true;

          final dayNumber = day['day_number']?.toString() ?? '${index + 1}';
          final weekNumber = day['week_number']?.toString() ?? '1';

          return GestureDetector(
            onTap: () => _selectDay(index),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.navBar : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.navBar : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'W$weekNumber',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (completed)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: selected ? Colors.white : AppColors.primary,
                    )
                  else if (rest)
                    Icon(
                      Icons.self_improvement,
                      size: 18,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    )
                  else
                    Text(
                      dayNumber,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dayBanner() {
    final completed = _isSelectedDayCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              completed
                  ? Icons.check_circle
                  : _isRestDay
                      ? Icons.self_improvement
                      : Icons.calendar_month,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dayMeta(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseRow(Map<String, dynamic> exercise, int index) {
    final library = exercise['exercise_library'] as Map<String, dynamic>?;

    final name = library?['name']?.toString() ?? 'Exercise';
    final completed = _isSelectedDayCompleted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed ? AppColors.primary : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: completed
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _exerciseMeta(exercise),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Completed',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
