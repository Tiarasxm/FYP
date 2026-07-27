import 'package:flutter/material.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'create_exercise.dart';
import 'review_plan.dart';
import 'select_exercise.dart';

class CreatePlanSchedule extends StatefulWidget {
  final String planName;
  final List<String> tags;
  final String duration;
  final String visibility;

  const CreatePlanSchedule({
    super.key,
    required this.planName,
    required this.tags,
    required this.duration,
    required this.visibility,
  });

  @override
  State<CreatePlanSchedule> createState() => _CreatePlanScheduleState();
}

class _CreatePlanScheduleState extends State<CreatePlanSchedule> {
  int selectedWeek = 1;
  int selectedDay = 1;
  bool markAsRestDay = false;

  final TextEditingController dayNameController = TextEditingController(
    text: 'Full Body Strength',
  );

  final List<Exercise> exercises = [
    const Exercise(
      name: 'Barbell Squats',
      detail: '3 × 10-12 • 60s rest',
    ),
    const Exercise(
      name: 'Barbell Bench Press',
      detail: '3 × 6-8 • 120s rest',
    ),
  ];

  @override
  void dispose() {
    dayNameController.dispose();
    super.dispose();
  }

  Future<void> addExistingExercise() async {
    final result = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectExercise(),
      ),
    );

    if (result != null) {
      setState(() {
        exercises.add(result);
      });
    }
  }

  Future<void> createNewExercise() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateExercise(),
      ),
    );
  }

  void showAddExerciseOptions() {
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
    final exercise = exercises[index];

    final setController = TextEditingController(text: '3');
    final minRepController = TextEditingController(text: '10');
    final maxRepController = TextEditingController(text: '12');
    final restController = TextEditingController(text: '60');

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

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final newDetail =
                              '${setController.text} × ${minRepController.text}-${maxRepController.text} • ${restController.text}s rest';

                          setState(() {
                            exercises[index] = Exercise(
                              name: exercise.name,
                              detail: newDetail,
                              exerciseId: exercise.exerciseId,
                              repMin: int.tryParse(minRepController.text),
                              repMax: int.tryParse(maxRepController.text),
                              restSec: int.tryParse(restController.text),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void goToReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPlan(
          planName: widget.planName,
          tags: widget.tags,
          visibility: widget.visibility,
          duration: widget.duration,
          weekNumber: selectedWeek,
          dayNumber: selectedDay,
          dayName: dayNameController.text.trim().isEmpty
              ? 'Day $selectedDay'
              : dayNameController.text.trim(),
          isRestDay: markAsRestDay,
          exercises: exercises,
          buttonText: 'Publish Plan',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
          child: Column(
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
                  const Text(
                    'Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
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

              Row(
                children: [
                  for (int i = 1; i <= 3; i++) ...[
                    _SmallBox(
                      topText: '',
                      number: '$i',
                      selected: selectedWeek == i,
                      onTap: () {
                        setState(() {
                          selectedWeek = i;
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  const _AddSmallBox(),
                ],
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

              Row(
                children: [
                  for (int i = 1; i <= 3; i++) ...[
                    _SmallBox(
                      topText: '',
                      number: '$i',
                      selected: selectedDay == i,
                      onTap: () {
                        setState(() {
                          selectedDay = i;
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  const _AddSmallBox(),
                ],
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
                decoration: InputDecoration(
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
                child: ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    return _ExerciseEditCard(
                      number: index + 1,
                      exercise: exercises[index],
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
                  onPressed: showAddExerciseOptions,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add Exercise to This Day',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(
                      color: Color(0xFF6C63FF),
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
                    value: markAsRestDay,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (value) {
                      setState(() {
                        markAsRestDay = value ?? false;
                      });
                    },
                  ),
                  const Text(
                    'Mark as Rest Day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
  final String topText;
  final String number;
  final bool selected;
  final VoidCallback onTap;

  const _SmallBox({
    required this.topText,
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
          width: 48,
          height: 44,
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 16,
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
  const _AddSmallBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 44,
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