import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class PlanDetailScreen extends StatefulWidget {
  final String planId;
  final String title;
  final bool isPersonalized;

  const PlanDetailScreen({
    super.key,
    required this.planId,
    required this.title,
    this.isPersonalized = false,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _isLoadingDays = true;
  bool _isLoadingExercises = false;
  bool _isSwitching = false;
  bool _isSavingPlan = false;
  bool _isLoadingPlanState = true;

  bool _isPriority = false;
  bool _isSaved = false;
  bool _isActive = false;
  int _savedPlanCount = 0;

  List<Map<String, dynamic>> _days = [];
  List<Map<String, dynamic>> _exercises = [];

  int _selectedWeekIndex = 0;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDays();
    _loadPlanState();
  }

  List<int> get _weekNumbers {
    final weeks = <int>{};

    for (final day in _days) {
      final weekNumber = _parseInt(day['week_number']);
      if (weekNumber != null) {
        weeks.add(weekNumber);
      }
    }

    return weeks.toList()..sort();
  }

  List<Map<String, dynamic>> get _daysInSelectedWeek {
    final weeks = _weekNumbers;

    if (weeks.isEmpty) {
      return [];
    }

    if (_selectedWeekIndex >= weeks.length) {
      return [];
    }

    final week = weeks[_selectedWeekIndex];

    final days = _days.where((day) {
      return _parseInt(day['week_number']) == week;
    }).toList();

    days.sort((a, b) {
      final aDay = _parseInt(a['day_number']) ?? 0;
      final bDay = _parseInt(b['day_number']) ?? 0;
      return aDay.compareTo(bDay);
    });

    return days;
  }

  Map<String, dynamic>? get _selectedDay {
    final days = _daysInSelectedWeek;

    if (_selectedDayIndex < 0 || _selectedDayIndex >= days.length) {
      return null;
    }

    return days[_selectedDayIndex];
  }

  bool get _isRestDay {
    return _selectedDay?['is_rest_day'] == true;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String get _planIdColumn {
    return widget.isPersonalized ? 'personalized_plan_id' : 'free_plan_id';
  }

  Map<String, dynamic> _planPayload({
    required String userId,
    required bool isSaved,
    required bool isActive,
  }) {
    final now = DateTime.now().toIso8601String();

    return {
      'profile_id': userId,
      'free_plan_id': widget.isPersonalized ? null : widget.planId,
      'personalized_plan_id': widget.isPersonalized ? widget.planId : null,
      'is_saved': isSaved,
      'is_active': isActive,
      'saved_at': now,
    };
  }

  Future<Map<String, dynamic>?> _findSavedPlanRow(
    SupabaseClient client,
    String userId,
  ) async {
    final response = await client
        .from('saved_plans')
        .select('saved_plan_id, is_saved, is_active')
        .eq('profile_id', userId)
        .eq(_planIdColumn, widget.planId)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(response as List);

    if (rows.isEmpty) return null;

    return rows.first;
  }

  Future<String> _ensureSavedPlanRow({
    required SupabaseClient client,
    required String userId,
    required bool isSavedWhenCreating,
  }) async {
    final existing = await _findSavedPlanRow(client, userId);

    if (existing != null) {
      final savedPlanId = existing['saved_plan_id']?.toString();

      if (savedPlanId == null || savedPlanId.isEmpty) {
        throw Exception('Missing saved_plan_id.');
      }

      return savedPlanId;
    }

    final row = await client
        .from('saved_plans')
        .insert(
          _planPayload(
            userId: userId,
            isSaved: isSavedWhenCreating,
            isActive: false,
          ),
        )
        .select('saved_plan_id')
        .single();

    final savedPlanId = row['saved_plan_id']?.toString();

    if (savedPlanId == null || savedPlanId.isEmpty) {
      throw Exception('Missing saved_plan_id.');
    }

    return savedPlanId;
  }

  Future<void> _loadPlanState() async {
    setState(() {
      _isLoadingPlanState = true;
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

      final savedResponse = await client
          .from('saved_plans')
          .select('saved_plan_id')
          .eq('profile_id', userId)
          .eq('is_saved', true);

      final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);
      final currentRow = await _findSavedPlanRow(client, userId);

      if (!mounted) return;

      setState(() {
        _isPriority = userType == 'priority';
        _savedPlanCount = savedRows.length;
        _isSaved = currentRow?['is_saved'] == true;
        _isActive = currentRow?['is_active'] == true;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlanState = false;
        });
      }
    }
  }

  Future<void> _savePlan() async {
    if (_isSavingPlan || _isSaved) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    if (!_isPriority && _savedPlanCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Free users can save up to 5 plans. Delete a saved plan first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSavingPlan = true;
    });

    try {
      final savedPlanId = await _ensureSavedPlanRow(
        client: client,
        userId: userId,
        isSavedWhenCreating: true,
      );

      await client
          .from('saved_plans')
          .update({
            'is_saved': true,
            'saved_at': DateTime.now().toIso8601String(),
          })
          .eq('saved_plan_id', savedPlanId)
          .eq('profile_id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan saved.')),
      );

      await _loadPlanState();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPlan = false;
        });
      }
    }
  }

  Future<void> _deleteSavedPlan() async {
    if (_isSavingPlan || !_isSaved) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete saved plan?'),
          content: Text(
            _isActive
                ? 'This plan will be removed from Saved Plans, but it will stay as your active plan.'
                : 'This plan will be removed from your Saved Plans.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSavingPlan = true;
    });

    try {
      final currentRow = await _findSavedPlanRow(client, userId);
      final savedPlanId = currentRow?['saved_plan_id']?.toString();

      if (savedPlanId == null || savedPlanId.isEmpty) {
        await _loadPlanState();
        return;
      }

      final isActive = currentRow?['is_active'] == true;

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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Removed from Saved Plans. It is still your active plan.'
                : 'Saved plan deleted.',
          ),
        ),
      );

      await _loadPlanState();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete saved plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPlan = false;
        });
      }
    }
  }

  Future<void> _toggleSavedPlan() async {
    if (_isSaved) {
      await _deleteSavedPlan();
    } else {
      await _savePlan();
    }
  }


  Future<void> _loadDays() async {
    setState(() {
      _isLoadingDays = true;
    });

    try {
      final response = widget.isPersonalized
          ? await Supabase.instance.client
              .from('personalized_plan_days')
              .select(
                'personalized_plan_day_id, week_number, day_number, day_name, is_rest_day',
              )
              .eq('personalized_plan_id', widget.planId)
              .order('week_number')
              .order('day_number')
          : await Supabase.instance.client
              .from('plan_days')
              .select(
                'plan_day_id, week_number, day_number, day_name, is_rest_day',
              )
              .eq('free_plan_id', widget.planId)
              .order('week_number')
              .order('day_number');

      if (!mounted) return;

      setState(() {
        _days = List<Map<String, dynamic>>.from(response as List).map((day) {
          return widget.isPersonalized
              ? {
                  ...day,
                  'plan_day_id': day['personalized_plan_day_id'],
                }
              : day;
        }).toList();
        _selectedWeekIndex = 0;
        _selectedDayIndex = 0;
      });

      await _loadExercisesForSelectedDay();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan days: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDays = false;
        });
      }
    }
  }

  Future<void> _loadExercisesForSelectedDay() async {
    final day = _selectedDay;

    if (day == null || day['is_rest_day'] == true) {
      setState(() {
        _exercises = [];
      });
      return;
    }

    setState(() {
      _isLoadingExercises = true;
    });

    try {
      final response = widget.isPersonalized
          ? await Supabase.instance.client
              .from('personalized_plan_exercises')
              .select(
                'sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)',
              )
              .eq('personalized_plan_day_id', day['plan_day_id'] as String)
              .order('order_index')
          : await Supabase.instance.client
              .from('plan_exercises')
              .select(
                'sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)',
              )
              .eq('plan_day_id', day['plan_day_id'] as String)
              .order('order_index');

      if (!mounted) return;

      setState(() {
        _exercises = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExercises = false;
        });
      }
    }
  }

  void _selectWeek(int index) {
    setState(() {
      _selectedWeekIndex = index;
      _selectedDayIndex = 0;
    });

    _loadExercisesForSelectedDay();
  }

  void _selectDay(int index) {
    setState(() {
      _selectedDayIndex = index;
    });

    _loadExercisesForSelectedDay();
  }

  Future<void> _switchToPlan() async {
    if (_isSwitching || _isActive) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    if (widget.planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan id.')),
      );
      return;
    }

    setState(() {
      _isSwitching = true;
    });

    try {
      await client
          .from('saved_plans')
          .update({'is_active': false})
          .eq('profile_id', userId)
          .eq('is_active', true);

      final savedPlanId = await _ensureSavedPlanRow(
        client: client,
        userId: userId,
        isSavedWhenCreating: false,
      );

      await client
          .from('saved_plans')
          .update({
            'is_active': true,
            'saved_at': DateTime.now().toIso8601String(),
          })
          .eq('saved_plan_id', savedPlanId)
          .eq('profile_id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active plan updated.')),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  String get _activeButtonLabel {
    if (_isLoadingPlanState) return 'Loading...';
    if (_isActive) return 'Current Active Plan';
    return _isSwitching ? 'Switching...' : 'Set as Active Plan';
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weekNumbers;
    final days = _daysInSelectedWeek;

    return SubScreenScaffold(
      title: widget.title,
      bottomButton: PrimaryButton(
        label: _activeButtonLabel,
        onPressed: (_isSwitching || _isLoadingPlanState || _isActive)
            ? null
            : _switchToPlan,
      ),
      children: [
        if (_isLoadingDays)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No days in this plan yet.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else ...[
          _savedPlanActionCard(),

          const SizedBox(height: 18),

          const Text(
            'Week',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          _selectorRow(
            count: weeks.length,
            selected: _selectedWeekIndex,
            labelBuilder: (index) {
              return ('W', '${weeks[index]}');
            },
            onTap: _selectWeek,
          ),

          const SizedBox(height: 18),

          const Text(
            'Day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          _selectorRow(
            count: days.length,
            selected: _selectedDayIndex,
            labelBuilder: (index) {
              final dayNumber = days[index]['day_number'];
              return ('DAY', '$dayNumber');
            },
            onTap: _selectDay,
          ),

          const SizedBox(height: 20),

          _dayBanner(),

          const SizedBox(height: 16),

          if (_isLoadingExercises)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_isRestDay)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Rest day',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else if (_exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No exercises in this day.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (int i = 0; i < _exercises.length; i++) ...[
              _exerciseRow(_exercises[i], i),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }

  Widget _savedPlanActionCard() {
    final limitText = _isPriority ? 'No save limit' : '$_savedPlanCount/5 saved';

    String statusText;

    if (_isLoadingPlanState) {
      statusText = 'Loading saved status...';
    } else if (_isSaved && _isActive) {
      statusText = 'Saved • Current active plan';
    } else if (_isSaved) {
      statusText = 'Saved to your saved plans';
    } else if (_isActive) {
      statusText = 'Active plan • not saved';
    } else {
      statusText = 'Not saved yet';
    }

    final buttonText = _isSaved ? 'Delete Saved' : 'Save Plan';
    final buttonIcon = _isSaved ? Icons.bookmark_remove : Icons.bookmark_add_outlined;
    final buttonColor = _isSaved ? Colors.red : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                limitText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: (_isSavingPlan || _isLoadingPlanState)
                  ? null
                  : _toggleSavedPlan,
              icon: Icon(buttonIcon, size: 18),
              label: Text(
                _isSavingPlan ? 'Updating...' : buttonText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: buttonColor,
                side: BorderSide(color: buttonColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorRow({
    required int count,
    required int selected,
    required (String, String) Function(int index) labelBuilder,
    required ValueChanged<int> onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          final label = labelBuilder(index);

          return GestureDetector(
            onTap: () {
              onTap(index);
            },
            child: Container(
              width: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navBar : AppColors.cardMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.$1,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.textMuted : AppColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    label.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
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
    final day = _selectedDay;

    final dayNumber = day?['day_number']?.toString() ?? '-';
    final dayName = day?['day_name']?.toString().trim();

    final title = dayName == null || dayName.isEmpty
        ? 'Day $dayNumber'
        : 'Day $dayNumber: $dayName';

    final meta = _isRestDay ? 'Rest Day' : '${_exercises.length} exercises';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.accent,
          ],
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
            child: const Icon(
              Icons.calendar_month,
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
                  title,
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
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _exerciseRow(Map<String, dynamic> exercise, int index) {
    final library = exercise['exercise_library'] as Map<String, dynamic>?;

    final name = library?['name']?.toString() ?? 'Exercise';
    final setCount = _parseInt(exercise['sets']);
    final repMin = _parseInt(exercise['rep_min']);
    final repMax = _parseInt(exercise['rep_max']);
    final restSec = _parseInt(exercise['rest_sec']);

    final repsText = _buildRepsText(repMin, repMax);

    final meta =
        '${setCount ?? '-'} sets • $repsText • ${restSec ?? '-'}s rest';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildRepsText(int? repMin, int? repMax) {
    if (repMin == null && repMax == null) {
      return '- reps';
    }

    if (repMin != null && (repMax == null || repMax == repMin)) {
      return '$repMin reps';
    }

    return '${repMin ?? '-'}-${repMax ?? '-'} reps';
  }
}