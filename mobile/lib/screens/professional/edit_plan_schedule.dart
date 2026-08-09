import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'create_exercise.dart';
import 'review_plan.dart';
import 'select_exercise.dart';

class EditPlanSchedule extends StatefulWidget {
  final WorkoutPlan plan;
  final String planName;
  final List<String> tags;
  final String duration;
  final String visibility;
  final String targetActivityLevel;
  final String targetFitnessGoal;

  const EditPlanSchedule({
    super.key,
    required this.plan,
    required this.planName,
    required this.tags,
    required this.duration,
    required this.visibility,
    required this.targetActivityLevel,
    required this.targetFitnessGoal,
  });

  @override
  State<EditPlanSchedule> createState() => _EditPlanScheduleState();
}

class _EditPlanScheduleState extends State<EditPlanSchedule> {
  bool isLoading = true;

  int selectedWeek = 1;
  int selectedDay = 1;

  final List<int> weeks = [];
  final Map<int, List<int>> daysByWeek = {};
  final Map<String, PlanDayDraft> dayDrafts = {};

  final TextEditingController dayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadExistingPlan();
  }

  @override
  void dispose() {
    dayNameController.dispose();
    super.dispose();
  }

  String dayKey(int week, int day) {
    return '$week-$day';
  }

  PlanDayDraft ensureDayExists(int week, int day) {
    final key = dayKey(week, day);

    if (!dayDrafts.containsKey(key)) {
      dayDrafts[key] = PlanDayDraft(
        weekNumber: week,
        dayNumber: day,
      );
    }

    return dayDrafts[key]!;
  }

  PlanDayDraft get currentDay {
    return ensureDayExists(selectedWeek, selectedDay);
  }

  Future<void> loadExistingPlan() async {
    setState(() {
      isLoading = true;
    });

    try {
      final planId = widget.plan.freePlanId;

      if (planId == null || planId.isEmpty) {
        setupDefaultDay();
        return;
      }

      final client = Supabase.instance.client;

      final dayResponse = await client
          .from('plan_days')
          .select(
            'plan_day_id, week_number, day_number, day_name, is_rest_day',
          )
          .eq('free_plan_id', planId)
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      final dayRows = dayResponse as List<dynamic>;

      if (dayRows.isEmpty) {
        setupDefaultDay();
        return;
      }

      weeks.clear();
      daysByWeek.clear();
      dayDrafts.clear();

      for (final item in dayRows) {
        final row = item as Map<String, dynamic>;

        final planDayId = row['plan_day_id']?.toString();
        final weekNumber = parseInt(row['week_number']) ?? 1;
        final dayNumber = parseInt(row['day_number']) ?? 1;
        final dayName = row['day_name']?.toString() ?? '';
        final isRestDay = row['is_rest_day'] == true;

        if (!weeks.contains(weekNumber)) {
          weeks.add(weekNumber);
        }

        daysByWeek.putIfAbsent(weekNumber, () => []);

        if (!daysByWeek[weekNumber]!.contains(dayNumber)) {
          daysByWeek[weekNumber]!.add(dayNumber);
        }

        final exercises = planDayId == null
            ? <Exercise>[]
            : await loadExercisesForDay(planDayId);

        dayDrafts[dayKey(weekNumber, dayNumber)] = PlanDayDraft(
          weekNumber: weekNumber,
          dayNumber: dayNumber,
          dayName: dayName,
          isRestDay: isRestDay,
          exercises: exercises,
        );
      }

      weeks.sort();

      for (final week in daysByWeek.keys) {
        daysByWeek[week]!.sort();
      }

      selectedWeek = weeks.first;
      selectedDay = daysByWeek[selectedWeek]!.first;
      dayNameController.text = currentDay.dayName;
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan schedule: $error')),
      );

      setupDefaultDay();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void setupDefaultDay() {
    weeks.clear();
    daysByWeek.clear();
    dayDrafts.clear();

    weeks.add(1);
    daysByWeek[1] = [1];
    selectedWeek = 1;
    selectedDay = 1;
    ensureDayExists(1, 1);
    dayNameController.text = currentDay.dayName;
  }

  Future<List<Exercise>> loadExercisesForDay(String planDayId) async {
    final client = Supabase.instance.client;

    final exerciseRowsResponse = await client
        .from('plan_exercises')
        .select(
          'exercise_id, order_index, sets, rep_min, rep_max, rest_sec',
        )
        .eq('plan_day_id', planDayId)
        .order('order_index', ascending: true);

    final exerciseRows = exerciseRowsResponse as List<dynamic>;

    if (exerciseRows.isEmpty) {
      return [];
    }

    final exerciseIds = exerciseRows
        .map((row) => (row as Map<String, dynamic>)['exercise_id']?.toString())
        .whereType<String>()
        .toList();

    final Map<String, String> exerciseNames = {};

    if (exerciseIds.isNotEmpty) {
      final libraryResponse = await client
          .from('exercise_library')
          .select('exercise_id, name')
          .inFilter('exercise_id', exerciseIds);

      final libraryRows = libraryResponse as List<dynamic>;

      for (final item in libraryRows) {
        final row = item as Map<String, dynamic>;
        final id = row['exercise_id']?.toString();
        final name = row['name']?.toString();

        if (id != null && name != null) {
          exerciseNames[id] = name;
        }
      }
    }

    return exerciseRows.map((item) {
      final row = item as Map<String, dynamic>;

      final exerciseId = row['exercise_id']?.toString();
      final sets = parseInt(row['sets']) ?? 3;
      final repMin = parseInt(row['rep_min']);
      final repMax = parseInt(row['rep_max']);
      final restSec = parseInt(row['rest_sec']);

      final repsText = buildRepsText(repMin, repMax);
      final restText = restSec == null ? '60s rest' : '${restSec}s rest';

      return Exercise(
        exerciseId: exerciseId,
        name: exerciseNames[exerciseId] ?? 'Unknown Exercise',
        sets: sets,
        repMin: repMin,
        repMax: repMax,
        restSec: restSec,
        detail: '$sets × $repsText • $restText',
      );
    }).toList();
  }

  String buildRepsText(int? repMin, int? repMax) {
    if (repMin == null && repMax == null) {
      return '10-12 reps';
    }

    if (repMin != null && (repMax == null || repMax == repMin)) {
      return '$repMin reps';
    }

    return '${repMin ?? ''}-${repMax ?? ''} reps';
  }

  int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void selectWeek(int week) {
    final availableDays = daysByWeek[week] ?? [1];

    setState(() {
      selectedWeek = week;
      selectedDay = availableDays.first;
      dayNameController.text = currentDay.dayName;
    });
  }

  void selectDay(int day) {
    setState(() {
      selectedDay = day;
      dayNameController.text = currentDay.dayName;
    });
  }

  void addWeek() {
    final nextWeek = weeks.isEmpty ? 1 : weeks.last + 1;

    setState(() {
      weeks.add(nextWeek);
      daysByWeek[nextWeek] = [1];
      selectedWeek = nextWeek;
      selectedDay = 1;
      ensureDayExists(nextWeek, 1);
      dayNameController.text = currentDay.dayName;
    });
  }

  void addDay() {
    final currentDays = daysByWeek[selectedWeek] ?? [1];
    final nextDay = currentDays.isEmpty ? 1 : currentDays.last + 1;

    setState(() {
      currentDays.add(nextDay);
      daysByWeek[selectedWeek] = currentDays;
      selectedDay = nextDay;
      ensureDayExists(selectedWeek, nextDay);
      dayNameController.text = currentDay.dayName;
    });
  }

  Future<void> addExistingExercise() async {
    if (currentDay.isRestDay) {
      showMessage('This day is marked as rest day.');
      return;
    }

    final result = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectExercise(),
      ),
    );

    if (result != null) {
      setState(() {
        currentDay.exercises.add(result);
        currentDay.isRestDay = false;
      });
    }
  }

  Future<void> createNewExercise() async {
    if (currentDay.isRestDay) {
      showMessage('This day is marked as rest day.');
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateExercise(),
      ),
    );

    if (created == true && mounted) {
      await addExistingExercise();
    }
  }

  void showAddExerciseOptions() {
    if (currentDay.isRestDay) {
      showMessage('This day is marked as rest day.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: Container(
            width: 430,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
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
                  const SizedBox(height: 18),
                  const Text(
                    'Add Exercise',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SheetOption(
                    icon: Icons.list_alt,
                    title: 'Select from Exercise Library',
                    onTap: () {
                      Navigator.pop(context);
                      addExistingExercise();
                    },
                  ),
                  const SizedBox(height: 10),
                  _SheetOption(
                    icon: Icons.add_circle_outline,
                    title: 'Create New Exercise',
                    onTap: () {
                      Navigator.pop(context);
                      createNewExercise();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void editExercise(int index) {
    final exercise = currentDay.exercises[index];

    final setController = TextEditingController(
      text: exercise.sets?.toString() ?? '3',
    );
    final minRepController = TextEditingController(
      text: exercise.repMin?.toString() ?? '10',
    );
    final maxRepController = TextEditingController(
      text: exercise.repMax?.toString() ?? '12',
    );
    final restController = TextEditingController(
      text: exercise.restSec?.toString() ?? '60',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Center(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              width: 430,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
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
                    const SizedBox(height: 14),
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SheetLabel('Set'),
                    const SizedBox(height: 8),
                    _SheetInput(controller: setController),
                    const SizedBox(height: 16),
                    const _SheetLabel('Reps'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetInput(
                            controller: minRepController,
                            hint: 'Min',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetInput(
                            controller: maxRepController,
                            hint: 'Max',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SheetLabel('Rest'),
                    const SizedBox(height: 8),
                    _SheetInput(
                      controller: restController,
                      suffixText: 'seconds',
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  currentDay.exercises.removeAt(index);
                                });

                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(
                                  color: Colors.red,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                final sets =
                                    int.tryParse(setController.text) ?? 3;
                                final repMin =
                                    int.tryParse(minRepController.text);
                                final repMax =
                                    int.tryParse(maxRepController.text);
                                final restSec =
                                    int.tryParse(restController.text);

                                final newDetail =
                                    '$sets × ${minRepController.text}-${maxRepController.text} • ${restController.text}s rest';

                                setState(() {
                                  currentDay.exercises[index] = Exercise(
                                    name: exercise.name,
                                    detail: newDetail,
                                    exerciseId: exercise.exerciseId,
                                    sets: sets,
                                    repMin: repMin,
                                    repMax: repMax,
                                    restSec: restSec,
                                  );
                                });

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
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
            ),
          ),
        );
      },
    );
  }

  List<PlanDayDraft> get allPlanDays {
    final allDays = dayDrafts.values.toList();

    allDays.sort((a, b) {
      final weekCompare = a.weekNumber.compareTo(b.weekNumber);
      if (weekCompare != 0) return weekCompare;
      return a.dayNumber.compareTo(b.dayNumber);
    });

    return allDays;
  }

  void goToReview() {
    for (final day in allPlanDays) {
      final hasExercises = day.exercises.isNotEmpty;

      if (!day.isRestDay && !hasExercises) {
        showMessage(
          'Week ${day.weekNumber} Day ${day.dayNumber} needs exercise or rest day.',
        );
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPlan(
          freePlanId: widget.plan.freePlanId,
          planName: widget.planName,
          tags: widget.tags,
          visibility: widget.visibility,
          duration: widget.duration,
          targetActivityLevel: widget.targetActivityLevel,
          targetFitnessGoal: widget.targetFitnessGoal,
          planDays: allPlanDays,
          buttonText: 'Update Changes',
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = currentDay;
    final currentDays = daysByWeek[selectedWeek] ?? [1];
    final hasExercises = day.exercises.isNotEmpty;

    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BackButton(
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Edit: ${widget.planName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Week',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final week in weeks) ...[
                            _SmallBox(
                              number: '$week',
                              selected: selectedWeek == week,
                              onTap: () {
                                selectWeek(week);
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                          _AddSmallBox(
                            onTap: addWeek,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final dayNumber in currentDays) ...[
                            _SmallBox(
                              number: '$dayNumber',
                              selected: selectedDay == dayNumber,
                              onTap: () {
                                selectDay(dayNumber);
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                          _AddSmallBox(
                            onTap: addDay,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Day Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dayNameController,
                      onChanged: (value) {
                        currentDay.dayName = value;
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter day name',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F2FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: day.exercises.isEmpty
                          ? Center(
                              child: Text(
                                day.isRestDay
                                    ? 'This day is marked as rest day.'
                                    : 'No exercises added yet.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: day.exercises.length,
                              itemBuilder: (context, index) {
                                return _ExerciseEditCard(
                                  number: index + 1,
                                  exercise: day.exercises[index],
                                  onEdit: () {
                                    editExercise(index);
                                  },
                                );
                              },
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: day.isRestDay ? null : showAddExerciseOptions,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Add Exercise to This Day',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          disabledForegroundColor: Colors.grey,
                          side: BorderSide(
                            color: day.isRestDay
                                ? Colors.grey
                                : const Color(0xFF6C63FF),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: day.isRestDay,
                          activeColor: const Color(0xFF6C63FF),
                          onChanged: hasExercises
                              ? null
                              : (value) {
                                  setState(() {
                                    day.isRestDay = value ?? false;
                                  });
                                },
                        ),
                        Text(
                          hasExercises
                              ? 'Rest Day unavailable after adding exercises'
                              : 'Mark as Rest Day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasExercises ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: goToReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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

class _ExerciseEditCard extends StatelessWidget {
  final int number;
  final Exercise exercise;
  final VoidCallback onEdit;

  const _ExerciseEditCard({
    required this.number,
    required this.exercise,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            '$number :',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: exercise.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: ' ${exercise.detail}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBox extends StatelessWidget {
  final String number;
  final bool selected;
  final VoidCallback onTap;

  const _SmallBox({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF333333) : const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 17,
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSmallBox extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSmallBox({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? suffixText;

  const _SheetInput({
    required this.controller,
    this.hint,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffixText,
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F2FA),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.black54,
        ),
      ),
    );
  }
}