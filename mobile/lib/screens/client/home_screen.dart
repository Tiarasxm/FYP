import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/menu_item.dart';
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
  String? _activePlanTitle;
  String? _activePlanDayId;

  String _todayPlanTitle = 'No active plan';
  String _todayPlanMeta = 'Choose a plan from Workout tab';
  bool _hasActiveWorkoutDay = false;

  int _steps = 0;
  int _heartRate = 0;
  int _kcalBurned = 0;
  int _kcalGoal = 500;
  double _weeklyVolumeKg = 0;

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
      await _loadWeeklyVolume(client, userId);
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

  Future<void> _loadActivePlan(SupabaseClient client, String userId) async {
    final savedResponse = await client
        .from('saved_plans')
        .select('saved_plan_id, free_plan_id, saved_at')
        .eq('profile_id', userId)
        .order('saved_at', ascending: false)
        .limit(1);

    final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

    if (savedRows.isEmpty) {
      _clearActivePlan();
      return;
    }

    final freePlanId = savedRows.first['free_plan_id']?.toString();

    if (freePlanId == null || freePlanId.isEmpty) {
      _clearActivePlan();
      return;
    }

    final plan = await client
        .from('free_plans')
        .select('free_plan_id, plan_name, duration_weeks')
        .eq('free_plan_id', freePlanId)
        .maybeSingle();

    if (plan == null) {
      _clearActivePlan();
      return;
    }

    final daysResponse = await client
        .from('plan_days')
        .select('plan_day_id, week_number, day_number, day_name, is_rest_day')
        .eq('free_plan_id', freePlanId)
        .order('week_number', ascending: true)
        .order('day_number', ascending: true);

    final dayRows = List<Map<String, dynamic>>.from(daysResponse as List);

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

    if (dayRows.isEmpty) {
      if (!mounted) return;

      setState(() {
        _activePlanId = freePlanId;
        _activePlanTitle = plan['plan_name']?.toString() ?? 'Active Plan';
        _activePlanDayId = null;
        _todayPlanTitle = _activePlanTitle!;
        _todayPlanMeta = 'No days in this plan yet';
        _hasActiveWorkoutDay = false;
      });

      return;
    }

    final selectedDay = dayRows.firstWhere(
      (day) => day['is_rest_day'] != true,
      orElse: () => dayRows.first,
    );

    final planDayId = selectedDay['plan_day_id']?.toString();
    final dayNumber = selectedDay['day_number']?.toString() ?? '1';
    final dayName = selectedDay['day_name']?.toString().trim();
    final isRestDay = selectedDay['is_rest_day'] == true;

    int exerciseCount = 0;

    if (planDayId != null && planDayId.isNotEmpty && !isRestDay) {
      final exercisesResponse = await client
          .from('plan_exercises')
          .select('plan_exercise_id')
          .eq('plan_day_id', planDayId);

      exerciseCount = (exercisesResponse as List).length;
    }

    final title = dayName == null || dayName.isEmpty
        ? 'Day $dayNumber'
        : 'Day $dayNumber: $dayName';

    final meta = isRestDay ? 'Rest Day' : '~45 min • $exerciseCount exercises';

    if (!mounted) return;

    setState(() {
      _activePlanId = freePlanId;
      _activePlanTitle = plan['plan_name']?.toString() ?? 'Active Plan';
      _activePlanDayId = planDayId;
      _todayPlanTitle = title;
      _todayPlanMeta = meta;
      _hasActiveWorkoutDay =
          planDayId != null && planDayId.isNotEmpty && !isRestDay;
    });
  }

  Future<void> _loadWeeklyVolume(SupabaseClient client, String userId) async {
    final now = DateTime.now();

    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );

    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final logsResponse = await client
        .from('workout_logs')
        .select('workout_log_id')
        .eq('profile_id', userId)
        .gte('performed_at', startOfWeek.toUtc().toIso8601String())
        .lt('performed_at', endOfWeek.toUtc().toIso8601String());

    final logs = List<Map<String, dynamic>>.from(logsResponse as List);

    final workoutLogIds = logs
        .map((log) => log['workout_log_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (workoutLogIds.isEmpty) {
      if (!mounted) return;

      setState(() {
        _weeklyVolumeKg = 0;
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
      _weeklyVolumeKg = total;
    });
  }

  void _clearActivePlan() {
    if (!mounted) return;

    setState(() {
      _activePlanId = null;
      _activePlanTitle = null;
      _activePlanDayId = null;
      _todayPlanTitle = 'No active plan';
      _todayPlanMeta = 'Choose a plan from Workout tab';
      _hasActiveWorkoutDay = false;
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

  String _weeklyVolumeText() {
    if (_weeklyVolumeKg % 1 == 0) {
      return _weeklyVolumeKg.toInt().toString();
    }

    return _weeklyVolumeKg.toStringAsFixed(1);
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
    if (_activePlanId == null || _activePlanDayId == null) {
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
                    ),
                    const SizedBox(height: 10),
                    _statTile(
                      icon: Icons.fitness_center,
                      iconColor: Colors.white,
                      iconBg: AppColors.dark,
                      label: 'Weekly Volume',
                      value: _weeklyVolumeText(),
                      unit: 'kg',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              CalorieRing(
                value: _kcalBurned,
                goal: _kcalGoal,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todaysPlan(BuildContext context) {
    final String planName =
        _activePlanTitle == null || _activePlanTitle!.trim().isEmpty
            ? 'No active plan'
            : _activePlanTitle!;

    return SectionCard(
      color: AppColors.primarySoft,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month, color: AppColors.primary),
          ),

          const SizedBox(width: 14),

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
                      const Text(
                        "Current Plan",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        planName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _activePlanTitle == null
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Today's Workout",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _todayPlanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _hasActiveWorkoutDay
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),

                      Text(
                        _todayPlanMeta,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.textMuted,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Icon(Icons.chevron_right, size: 18),
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