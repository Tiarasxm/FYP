import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/section_card.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _stepsRange = 0;
  int _caloriesRange = 0;

  late DateTime _selectedVolumeMonth;

  bool _isLoadingVolume = true;
  List<double> _weeklyVolumeValues = [0, 0, 0, 0];
  double _averageWeeklyVolume = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedVolumeMonth = DateTime(now.year, now.month, 1);

    _loadWeeklyVolume();
  }

  Future<void> _loadWeeklyVolume() async {
    setState(() {
      _isLoadingVolume = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final monthStart = DateTime(
        _selectedVolumeMonth.year,
        _selectedVolumeMonth.month,
        1,
      );

      final monthEnd = DateTime(
        _selectedVolumeMonth.year,
        _selectedVolumeMonth.month + 1,
        1,
      );

      final logsResponse = await client
          .from('workout_logs')
          .select('workout_log_id, performed_at')
          .eq('profile_id', userId)
          .gte('performed_at', monthStart.toUtc().toIso8601String())
          .lt('performed_at', monthEnd.toUtc().toIso8601String());

      final logs = List<Map<String, dynamic>>.from(logsResponse as List);

      final logWeekMap = <String, int>{};

      for (final log in logs) {
        final logId = log['workout_log_id']?.toString();
        final performedRaw = log['performed_at']?.toString();

        if (logId == null || logId.isEmpty) continue;
        if (performedRaw == null || performedRaw.isEmpty) continue;

        final performedAt = DateTime.tryParse(performedRaw);
        if (performedAt == null) continue;

        final localDate = performedAt.toLocal();

        int weekIndex = ((localDate.day - 1) ~/ 7);

        if (weekIndex < 0) weekIndex = 0;
        if (weekIndex > 3) weekIndex = 3;

        logWeekMap[logId] = weekIndex;
      }

      if (logWeekMap.isEmpty) {
        if (!mounted) return;

        setState(() {
          _weeklyVolumeValues = [0, 0, 0, 0];
          _averageWeeklyVolume = 0;
        });

        return;
      }

      final workoutLogIds = logWeekMap.keys.toList();

      final exercisesResponse = await client
          .from('workout_exercises')
          .select('workout_log_id, reps, weight_kg')
          .inFilter('workout_log_id', workoutLogIds);

      final exerciseRows =
          List<Map<String, dynamic>>.from(exercisesResponse as List);

      final weeklyVolumes = [0.0, 0.0, 0.0, 0.0];

      for (final row in exerciseRows) {
        final logId = row['workout_log_id']?.toString();

        if (logId == null || logId.isEmpty) continue;

        final weekIndex = logWeekMap[logId];
        if (weekIndex == null) continue;

        final reps = _parseInt(row['reps']) ?? 0;
        final weightKg = _parseDouble(row['weight_kg']) ?? 0;

        weeklyVolumes[weekIndex] += reps * weightKg;
      }

      final nonZeroWeeks = weeklyVolumes.where((value) => value > 0).toList();

      final average = nonZeroWeeks.isEmpty
          ? 0.0
          : nonZeroWeeks.reduce((a, b) => a + b) / nonZeroWeeks.length;

      if (!mounted) return;

      setState(() {
        _weeklyVolumeValues = weeklyVolumes;
        _averageWeeklyVolume = average;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load weekly volume: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVolume = false;
        });
      }
    }
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

  String _numberText(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  List<String> _labelsForRange(int range) {
    if (range == 0) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }

    if (range == 1) {
      return ['W1', 'W2', 'W3', 'W4'];
    }

    if (range == 2) {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    }

    return [
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
  }

  List<double> _emptyValuesForRange(int range) {
    final count = _labelsForRange(range).length;
    return List.generate(count, (_) => 0.0);
  }

  List<DateTime> _monthOptions() {
    final now = DateTime.now();
    final months = <DateTime>[];

    for (var month = now.month; month >= 1; month--) {
      months.add(DateTime(now.year, month, 1));
    }

    return months;
  }

  String _monthLabel(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Progress',
      children: [
        _chartCard(
          title: 'Step Count',
          average: '0',
          unit: 'steps',
          values: _emptyValuesForRange(_stepsRange),
          labels: _labelsForRange(_stepsRange),
          barColor: AppColors.primarySoft,
          highlightColor: AppColors.primary,
          selectedRange: _stepsRange,
          onRangeChanged: (i) {
            setState(() {
              _stepsRange = i;
            });
          },
          emptyMessage: 'No step API data yet',
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: 'Calories Burned',
          average: '0',
          unit: 'kcal',
          values: _emptyValuesForRange(_caloriesRange),
          labels: _labelsForRange(_caloriesRange),
          barColor: const Color(0xFFEFF7DC),
          highlightColor: AppColors.green,
          selectedRange: _caloriesRange,
          onRangeChanged: (i) {
            setState(() {
              _caloriesRange = i;
            });
          },
          emptyMessage: 'No calories API data yet',
        ),
        const SizedBox(height: 16),
        _weeklyVolumeCard(),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String average,
    required String unit,
    required List<double> values,
    required List<String> labels,
    required Color barColor,
    required Color highlightColor,
    required int selectedRange,
    required ValueChanged<int> onRangeChanged,
    required String emptyMessage,
  }) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _rangeToggle(selectedRange, highlightColor, onRangeChanged),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'AVERAGE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: average,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            emptyMessage,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i < labels.length ? labels[i] : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != values.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyVolumeCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weekly Volume',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime>(
                    value: _selectedVolumeMonth,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _monthOptions().map((month) {
                      return DropdownMenuItem<DateTime>(
                        value: month,
                        child: Text(_monthLabel(month)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedVolumeMonth = value;
                      });

                      _loadWeeklyVolume();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'AVERAGE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: _numberText(_averageWeeklyVolume),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: ' kg',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingVolume)
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            _volumeBars(),
        ],
      ),
    );
  }

  Widget _volumeBars() {
    final maxValue = _weeklyVolumeValues.isEmpty
        ? 1.0
        : _weeklyVolumeValues.reduce((a, b) => a > b ? a : b);

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    const labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _weeklyVolumeValues.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: _weeklyVolumeValues[i] <= 0
                        ? 6
                        : 100 * _weeklyVolumeValues[i] / safeMax,
                    decoration: BoxDecoration(
                      color: _weeklyVolumeValues[i] <= 0
                          ? AppColors.border
                          : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != _weeklyVolumeValues.length - 1)
              const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _rangeToggle(
    int selected,
    Color highlightColor,
    ValueChanged<int> onChanged,
  ) {
    const labels = ['W', 'M', '6M', 'Y'];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: selected == i ? highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected == i ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}