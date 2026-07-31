import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class PlanDetailScreen extends StatefulWidget {
  final String planId;
  final String title;

  const PlanDetailScreen({
    super.key,
    required this.planId,
    required this.title,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _isLoadingDays = true;
  bool _isLoadingExercises = false;

  List<Map<String, dynamic>> _days = [];
  List<Map<String, dynamic>> _exercises = [];

  int _selectedWeekIndex = 0;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDays();
  }

  List<int> get _weekNumbers {
    final weeks = <int>{};
    for (final day in _days) {
      weeks.add(day['week_number'] as int);
    }
    return weeks.toList()..sort();
  }

  List<Map<String, dynamic>> get _daysInSelectedWeek {
    final weeks = _weekNumbers;
    if (weeks.isEmpty) return [];

    final week = weeks[_selectedWeekIndex];
    final days = _days.where((d) => d['week_number'] == week).toList();
    days.sort(
      (a, b) => (a['day_number'] as int).compareTo(b['day_number'] as int),
    );
    return days;
  }

  Map<String, dynamic>? get _selectedDay {
    final days = _daysInSelectedWeek;
    if (_selectedDayIndex >= days.length) return null;
    return days[_selectedDayIndex];
  }

  bool get _isRestDay => _selectedDay?['is_rest_day'] == true;

  Future<void> _loadDays() async {
    setState(() {
      _isLoadingDays = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('plan_days')
          .select('plan_day_id, week_number, day_number, day_name, is_rest_day')
          .eq('free_plan_id', widget.planId)
          .order('week_number')
          .order('day_number');

      if (!mounted) return;
      setState(() {
        _days = List<Map<String, dynamic>>.from(response as List);
        _selectedWeekIndex = 0;
        _selectedDayIndex = 0;
      });

      await _loadExercisesForSelectedDay();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan days: $e')),
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
      final response = await Supabase.instance.client
          .from('plan_exercises')
          .select(
              'sets, rep_min, rep_max, rest_sec, order_index, exercise_library(name, muscle_group)')
          .eq('plan_day_id', day['plan_day_id'] as String)
          .order('order_index');

      if (!mounted) return;
      setState(() {
        _exercises = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $e')),
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

  @override
  Widget build(BuildContext context) {
    final weeks = _weekNumbers;
    final days = _daysInSelectedWeek;

    return SubScreenScaffold(
      title: widget.title,
      bottomButton: PrimaryButton(
        label: 'Switch to this plan',
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        if (_isLoadingDays)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No days in this plan yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          const Text(
            'Week',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _selectorRow(
            count: weeks.length,
            selected: _selectedWeekIndex,
            labelBuilder: (i) => ('W', '${weeks[i]}'),
            onTap: _selectWeek,
          ),
          const SizedBox(height: 18),
          const Text(
            'Day',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _selectorRow(
            count: days.length,
            selected: _selectedDayIndex,
            labelBuilder: (i) => ('DAY', '${days[i]['day_number']}'),
            onTap: _selectDay,
          ),
          const SizedBox(height: 20),
          _dayBanner(),
          const SizedBox(height: 16),
          if (_isLoadingExercises)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_isRestDay)
            const SizedBox.shrink()
          else
            for (var i = 0; i < _exercises.length; i++) ...[
              _exerciseRow(_exercises[i], i),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }

  Widget _selectorRow({
    required int count,
    required int selected,
    required (String, String) Function(int) labelBuilder,
    required ValueChanged<int> onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == selected;
          final label = labelBuilder(i);
          return GestureDetector(
            onTap: () => onTap(i),
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
                      color: isSelected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : AppColors.textPrimary,
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
    final title = day == null
        ? widget.title
        : 'Day ${day['day_number']}: ${day['day_name']}';
    final meta = _isRestDay ? 'Rest Day' : '${_exercises.length} exercises';

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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.calendar_month, color: Colors.white, size: 20),
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
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
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
    final name = library?['name'] as String? ?? 'Exercise';
    final setCount = exercise['sets'] as int?;
    final repMin = exercise['rep_min'] as int?;
    final repMax = exercise['rep_max'] as int?;
    final restSec = exercise['rest_sec'] as int?;
    final meta =
        '${setCount ?? '-'} sets • ${repMin ?? '-'}–${repMax ?? '-'} reps • ${restSec ?? '-'}s rest';

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
}
