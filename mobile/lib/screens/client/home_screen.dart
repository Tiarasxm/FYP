import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/menu_item.dart';
import '../../services/health_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/calorie_ring.dart';
import '../../widgets/client/section_card.dart';

import 'achievements_screen.dart';
import 'fitness_plan_screen.dart';
import 'leaderboard_screen.dart';
import 'log_meal_screen.dart';
import 'progress_screen.dart';
import 'saved_plans_screen.dart';
import 'workout_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  String _userName = 'User';
  String _avatarLetter = 'U';
  String? _avatarUrl;

  RealtimeChannel? _profileChannel;

  String? _activePlanId;
  String? _activePlanDayId;

  String _todayPlanTitle = 'No active plan';
  String _todayPlanMeta = 'Choose a plan from Workout tab';
  String? _upNextPlanTitle;
  String? _upNextPlanMeta;
  bool _hasActiveWorkoutDay = false;
  bool _completedToday = false;
  bool _isRestDayPending = false;

  int _steps = 0;
  int _heartRate = 0;
  DateTime? _heartRateMeasuredAt;
  int _kcalBurned = 0;
  double _todayVolumeKg = 0;

  final List<MenuItem> _homeMenu = const [
    MenuItem(label: 'Progress', icon: Icons.track_changes),
    MenuItem(label: 'Leaderboard', icon: Icons.groups),
    MenuItem(label: 'My Achievements', icon: Icons.emoji_events),
    MenuItem(label: 'Saved Workout Plans', icon: Icons.bookmark),
    MenuItem(label: 'Workout History', icon: Icons.history),
  ];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      await _loadProfile(client, userId);
      await _loadActivePlan(client, userId);
      await _loadTodayVolume(client, userId);
      await HealthSyncService.syncTodayAndRecentDays(userId);
      await _loadTodayHealthMetrics(userId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load home data: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProfile(SupabaseClient client, String userId) async {
    final profile = await client
        .from('profiles')
        .select('full_name, email, avatar_url')
        .eq('id', userId)
        .maybeSingle();

    final fullName = profile?['full_name']?.toString().trim();
    final email = profile?['email']?.toString().trim();
    final avatarUrl = profile?['avatar_url']?.toString().trim();

    String name = 'User';

    if (fullName != null && fullName.isNotEmpty) {
      name = fullName;
    } else if (email != null && email.isNotEmpty) {
      name = email.split('@').first;
    }

    if (!mounted) return;

    setState(() {
      _userName = name;
      _avatarLetter = name.isEmpty ? 'U' : name[0].toUpperCase();
      _avatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null;
    });

    _subscribeToProfile(client, userId);
  }

  void _subscribeToProfile(SupabaseClient client, String userId) {
    if (_profileChannel != null) return;

    _profileChannel = client
        .channel('public:profiles:home:$userId')
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
            final email = record['email']?.toString().trim();
            final avatarUrl = record['avatar_url']?.toString().trim();

            String name = _userName;

            if (fullName != null && fullName.isNotEmpty) {
              name = fullName;
            } else if (email != null && email.isNotEmpty) {
              name = email.split('@').first;
            }

            if (!mounted) return;

            setState(() {
              _userName = name;
              _avatarLetter = name.isEmpty ? 'U' : name[0].toUpperCase();
              _avatarUrl =
                  (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null;
            });
          },
        )
        .subscribe();
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Map<String, dynamic> _selectCalendarDay({
    required List<Map<String, dynamic>> dayRows,
    required DateTime? activeStartedAt,
  }) {
    final today = _dateOnly(DateTime.now());
    final startDate = activeStartedAt == null ? today : _dateOnly(activeStartedAt);
    final elapsedDays = today.difference(startDate).inDays;
    final index = elapsedDays < 0 ? 0 : elapsedDays;

    if (index < dayRows.length) {
      return dayRows[index];
    }

    return dayRows.last;
  }

  Future<void> _loadActivePlan(SupabaseClient client, String userId) async {
    final savedResponse = await client
        .from('saved_plans')
        .select(
          'saved_plan_id, free_plan_id, personalized_plan_id, saved_at, is_active',
        )
        .eq('profile_id', userId)
        .eq('is_active', true)
        .order('saved_at', ascending: false)
        .limit(1);

    final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

    if (savedRows.isEmpty) {
      _clearActivePlan();
      return;
    }

    final activeSavedRow = savedRows.first;
    final freePlanId = activeSavedRow['free_plan_id']?.toString();
    final personalizedPlanId = activeSavedRow['personalized_plan_id']?.toString();
    final activeStartedAt =
        DateTime.tryParse(activeSavedRow['saved_at']?.toString() ?? '');

    final isPersonalized = personalizedPlanId != null && personalizedPlanId.isNotEmpty;
    final planId = isPersonalized ? personalizedPlanId : freePlanId;

    if (planId == null || planId.isEmpty) {
      _clearActivePlan();
      return;
    }

    String? planName;
    if (isPersonalized) {
      final plan = await client
          .from('personalized_plans')
          .select('personalized_plan_id, plan_name, duration_weeks, status')
          .eq('personalized_plan_id', planId)
          .maybeSingle();

      if (plan == null) {
        _clearActivePlan();
        return;
      }

      planName = plan['plan_name']?.toString();
    } else {
      final plan = await client
          .from('free_plans')
          .select('free_plan_id, plan_name, duration_weeks, visibility, status')
          .eq('free_plan_id', planId)
          .maybeSingle();

      if (plan == null) {
        _clearActivePlan();
        return;
      }

      final visibility =
          plan['visibility']?.toString().trim().toLowerCase() ?? 'public';
      final userType = await client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle()
          .then((p) => p?['user_type']?.toString().trim().toLowerCase() ?? 'free');
      final isPriority = userType == 'priority';

      if (!isPriority && visibility != 'public') {
        _clearActivePlan();
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
            .select('plan_day_id, week_number, day_number, day_name, is_rest_day')
            .eq('free_plan_id', planId)
            .order('week_number', ascending: true)
            .order('day_number', ascending: true);

    final dayRows = List<Map<String, dynamic>>.from(daysResponse as List).map((day) {
      return isPersonalized
          ? {
              ...day,
              'plan_day_id': day['personalized_plan_day_id'],
            }
          : day;
    }).toList();

    dayRows.sort((a, b) {
      final aWeek = _parseInt(a['week_number']) ?? 0;
      final bWeek = _parseInt(b['week_number']) ?? 0;

      if (aWeek != bWeek) {
        return aWeek.compareTo(bWeek);
      }

      final aDay = _parseInt(a['day_number']) ?? 0;
      final bDay = _parseInt(b['day_number']) ?? 0;

      return aDay.compareTo(bDay);
    });

    final activePlanTitle = planName ?? 'Active Plan';

    if (dayRows.isEmpty) {
      if (!mounted) return;

      setState(() {
        _activePlanId = planId;
        _activePlanDayId = null;
        _todayPlanTitle = activePlanTitle;
        _todayPlanMeta = 'No days in this plan yet';
        _upNextPlanTitle = null;
        _upNextPlanMeta = null;
        _hasActiveWorkoutDay = false;
        _completedToday = false;
        _isRestDayPending = false;
      });

      return;
    }

    final selectedDay = _selectCalendarDay(
      dayRows: dayRows,
      activeStartedAt: activeStartedAt,
    );

    final planDayId = selectedDay['plan_day_id']?.toString();
    final dayNumber = selectedDay['day_number']?.toString() ?? '1';
    final dayName = selectedDay['day_name']?.toString().trim();
    final isRestDay = selectedDay['is_rest_day'] == true;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    bool completedToday = false;
    if (planDayId != null && planDayId.isNotEmpty) {
      final todayLogsResponse = await client
          .from('workout_logs')
          .select('workout_log_id')
          .eq('profile_id', userId)
          .eq(isPersonalized ? 'personalized_plan_id' : 'free_plan_id', planId)
          .eq('plan_day_id', planDayId)
          .gte('performed_at', startOfDay.toUtc().toIso8601String())
          .lt('performed_at', endOfDay.toUtc().toIso8601String());

      completedToday = (todayLogsResponse as List).isNotEmpty;
    }

    int exerciseCount = 0;

    if (planDayId != null && planDayId.isNotEmpty && !isRestDay) {
      final exercisesResponse = isPersonalized
          ? await client
              .from('personalized_plan_exercises')
              .select('personalized_plan_exercise_id')
              .eq('personalized_plan_day_id', planDayId)
          : await client
              .from('plan_exercises')
              .select('plan_exercise_id')
              .eq('plan_day_id', planDayId);

      exerciseCount = (exercisesResponse as List).length;
    }

    final dayTitle = dayName == null || dayName.isEmpty
        ? 'Day $dayNumber'
        : 'Day $dayNumber: $dayName';
    final title = '$activePlanTitle - $dayTitle';

    final meta = isRestDay ? 'Rest Day' : '$exerciseCount exercises';

    String? upNextTitle;
    String? upNextMeta;

    if (completedToday) {
      final currentIndex = dayRows.indexOf(selectedDay);
      final nextIndex = currentIndex < 0 ? -1 : currentIndex + 1;

      if (nextIndex >= 0 && nextIndex < dayRows.length) {
        final nextDay = dayRows[nextIndex];
        final nextDayId = nextDay['plan_day_id']?.toString();
        final nextDayNumber = nextDay['day_number']?.toString() ?? '${nextIndex + 1}';
        final nextDayName = nextDay['day_name']?.toString().trim();
        final nextIsRestDay = nextDay['is_rest_day'] == true;

        final nextDayTitle = nextDayName == null || nextDayName.isEmpty
            ? 'Day $nextDayNumber'
            : 'Day $nextDayNumber: $nextDayName';

        upNextTitle = '$activePlanTitle - $nextDayTitle';

        if (nextIsRestDay || nextDayId == null || nextDayId.isEmpty) {
          upNextMeta = 'Rest Day';
        } else {
          final nextExercisesResponse = isPersonalized
              ? await client
                  .from('personalized_plan_exercises')
                  .select('personalized_plan_exercise_id')
                  .eq('personalized_plan_day_id', nextDayId)
              : await client
                  .from('plan_exercises')
                  .select('plan_exercise_id')
                  .eq('plan_day_id', nextDayId);

          upNextMeta = '${(nextExercisesResponse as List).length} exercises';
        }
      } else {
        upNextTitle = 'All plan days completed';
        upNextMeta = 'Great job! You finished this plan.';
      }
    }

    if (!mounted) return;

    setState(() {
      _activePlanId = planId;
      _activePlanDayId = planDayId;
      _todayPlanTitle = title;
      _todayPlanMeta = meta;
      _upNextPlanTitle = upNextTitle;
      _upNextPlanMeta = upNextMeta;
      _hasActiveWorkoutDay =
          planDayId != null && planDayId.isNotEmpty && !isRestDay;
      _completedToday = completedToday;
      _isRestDayPending = isRestDay;
    });
  }

  Future<void> _loadTodayVolume(SupabaseClient client, String userId) async {
    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logsResponse = await client
        .from('workout_logs')
        .select('workout_log_id')
        .eq('profile_id', userId)
        .gte('performed_at', startOfDay.toUtc().toIso8601String())
        .lt('performed_at', endOfDay.toUtc().toIso8601String());

    final logs = List<Map<String, dynamic>>.from(logsResponse as List);

    final workoutLogIds = logs
        .map((log) => log['workout_log_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (workoutLogIds.isEmpty) {
      if (!mounted) return;

      setState(() {
        _todayVolumeKg = 0;
      });

      return;
    }

    final exercisesResponse = await client
        .from('workout_exercises')
        .select('workout_log_id, reps, weight_kg')
        .inFilter('workout_log_id', workoutLogIds);

    final rows = List<Map<String, dynamic>>.from(exercisesResponse as List);

    double total = 0;

    for (final row in rows) {
      final reps = _parseInt(row['reps']) ?? 0;
      final weight = _parseDouble(row['weight_kg']) ?? 0;

      total += reps * weight;
    }

    if (!mounted) return;

    setState(() {
      _todayVolumeKg = total;
    });
  }

  Future<void> _loadTodayHealthMetrics(String userId) async {
    final row = await HealthSyncService.fetchTodayMetrics(userId);

    if (!mounted) return;

    setState(() {
      _steps = _parseInt(row?['steps']) ?? 0;
      _heartRate = _parseInt(row?['heart_rate']) ?? 0;
      _heartRateMeasuredAt =
          DateTime.tryParse(row?['heart_rate_measured_at']?.toString() ?? '');
      _kcalBurned = _parseInt(row?['calories_burned']) ?? 0;
    });
  }

  String? _relativeTimeText(DateTime? time) {
    if (time == null) return null;

    final localTime = time.toLocal();
    final diff = DateTime.now().difference(localTime);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${localTime.day.toString().padLeft(2, '0')}/'
        '${localTime.month.toString().padLeft(2, '0')}';
  }

  void _clearActivePlan() {
    if (!mounted) return;

    setState(() {
      _activePlanId = null;
      _activePlanDayId = null;
      _todayPlanTitle = 'No active plan';
      _todayPlanMeta = 'Choose a plan from Workout tab';
      _upNextPlanTitle = null;
      _upNextPlanMeta = null;
      _hasActiveWorkoutDay = false;
      _completedToday = false;
      _isRestDayPending = false;
    });
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _todayVolumeText() {
    if (_todayVolumeKg % 1 == 0) {
      return _todayVolumeKg.toInt().toString();
    }

    return _todayVolumeKg.toStringAsFixed(1);
  }

  String _todayDateText() {
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

  void _openFitnessPlan() {
    if (_activePlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an active plan from Workout tab first.'),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const FitnessPlanScreen(),
          ),
        )
        .then((_) => _loadHomeData());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            16,
            AppSpacing.screenPadding,
            24,
          ),
          children: [
            _header(),
            const SizedBox(height: 20),
            _dailyProgress(),
            const SizedBox(height: 16),
            _todaysPlan(context),
            const SizedBox(height: 16),
            _quickActions(context),
            const SizedBox(height: 16),
            _menuList(context),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _todayDateText(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hello, $_userName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _avatarUrl == null
              ? Text(
                  _avatarLetter,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _dailyProgress() {
    return SectionCard(
      color: AppColors.cardMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your daily progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _statTile(
                      icon: Icons.directions_walk,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primarySoft,
                      label: 'Steps',
                      value: '$_steps',
                    ),
                    const SizedBox(height: 10),
                    _statTile(
                      icon: Icons.favorite,
                      iconColor: AppColors.red,
                      iconBg: const Color(0xFFFDE8E8),
                      label: 'Heart Rate',
                      value: '$_heartRate',
                      unit: 'bpm',
                      subtitle: () {
                        final relative = _relativeTimeText(_heartRateMeasuredAt);
                        return relative == null ? null : '($relative)';
                      }(),
                    ),
                    const SizedBox(height: 10),
                    _statTile(
                      icon: Icons.fitness_center,
                      iconColor: Colors.white,
                      iconBg: AppColors.dark,
                      label: "Today's Volume",
                      value: _todayVolumeText(),
                      unit: 'kg',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              CalorieRing(
                value: _kcalBurned,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    String? unit,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textPrimary),
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todaysPlan(BuildContext context) {
    final hasPlan = _activePlanId != null;
    final showCompleted = hasPlan && _completedToday;
    final showRestDay = hasPlan && !_completedToday && _isRestDayPending;

    final String headline = showCompleted
        ? 'Completed'
        : showRestDay
            ? 'Rest Day'
            : "Today's Workout";

    final String buttonLabel = showCompleted
        ? 'View Plan'
        : showRestDay
            ? 'View Plan'
            : 'Start';

    return SectionCard(
      color: AppColors.primarySoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!showCompleted) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                showRestDay ? Icons.self_improvement : Icons.calendar_month,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: _isLoading
                ? const Text(
                    'Loading plan...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showCompleted
                            ? (_upNextPlanTitle == null
                                ? 'Up next: No scheduled workout'
                                : 'Up next: $_upNextPlanTitle')
                            : _todayPlanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _hasActiveWorkoutDay || showCompleted
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        showRestDay
                            ? 'Recovery day • no workout scheduled'
                            : showCompleted
                                ? (_upNextPlanMeta ?? 'Workout finished for today')
                                : _todayPlanMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _openFitnessPlan,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(buttonLabel),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.fitness_center,
            iconBg: AppColors.primarySoft,
            iconColor: AppColors.primary,
            label: 'Log Workout',
            onTap: _openFitnessPlan,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _actionCard(
            icon: Icons.restaurant,
            iconBg: const Color(0xFFEFF7DC),
            iconColor: AppColors.green,
            label: 'Log Meal',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogMealScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuList(BuildContext context) {
    return SectionCard(
      color: AppColors.cardMuted,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < _homeMenu.length; i++) ...[
              _menuRow(context, _homeMenu[i]),
              if (i != _homeMenu.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }

  void _openMenuItem(BuildContext context, String label) {
    final screens = <String, Widget Function()>{
      'Progress': () => const ProgressScreen(),
      'Leaderboard': () => const LeaderboardScreen(),
      'My Achievements': () => const AchievementsScreen(),
      'Saved Workout Plans': () => const SavedPlansScreen(),
      'Workout History': () => const WorkoutHistoryScreen(),
    };

    final builder = screens[label];

    if (builder != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder()));
    }
  }

  Widget _menuRow(BuildContext context, MenuItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.icon, size: 20, color: AppColors.primary),
      ),
      title: Text(
        item.label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () => _openMenuItem(context, item.label),
    );
  }
}
