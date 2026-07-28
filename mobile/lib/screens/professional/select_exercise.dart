import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/professional/mock_exercises.dart';
import '../../models/professional/library_exercise.dart';
import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'create_exercise.dart';

class SelectExercise extends StatefulWidget {
  const SelectExercise({super.key});

  @override
  State<SelectExercise> createState() => _SelectExerciseState();
}

class _SelectExerciseState extends State<SelectExercise> {
  String searchText = '';
  String selectedMuscleGroup = 'All';
  String selectedEquipment = 'All';
  bool showMineOnly = true;
  LibraryExercise? selectedExercise;

  List<LibraryExercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final response = await Supabase.instance.client
          .from('exercise_library')
          .select(
              'exercise_id, professional_id, name, muscle_group, equipment, default_rep_min, default_rep_max, default_rest_sec')
          .order('name');

      setState(() {
        _exercises = (response as List<dynamic>)
            .map((row) => LibraryExercise(
                  id: row['exercise_id'] as String,
                  name: row['name'] as String,
                  muscleGroup: row['muscle_group'] as String,
                  equipment: row['equipment'] as String,
                  repMin: row['default_rep_min'] as int?,
                  repMax: row['default_rep_max'] as int?,
                  restSec: row['default_rest_sec'] as int?,
                  byMe: row['professional_id'] == userId,
                ))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateExercise() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateExercise(),
      ),
    );

    if (created == true) {
      _loadExercises();
    }
  }

  List<LibraryExercise> get filteredExercises {
    return _exercises.where((exercise) {
      final matchesSearch = exercise.name.toLowerCase().contains(
            searchText.toLowerCase(),
          );

      final matchesMuscle = selectedMuscleGroup == 'All' ||
          exercise.muscleGroup == selectedMuscleGroup;

      final matchesEquipment =
          selectedEquipment == 'All' || exercise.equipment == selectedEquipment;

      final matchesOwner = !showMineOnly || exercise.byMe;

      return matchesSearch && matchesMuscle && matchesEquipment && matchesOwner;
    }).toList();
  }

  void showFilterPopup({
    required String title,
    required List<String> options,
    required String currentValue,
    required void Function(String value) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Center(
          child: Container(
            width: 430,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
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
                  const SizedBox(height: 10),
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
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option == currentValue;

                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF6C63FF),
                                  size: 18,
                                )
                              : null,
                          onTap: () {
                            onSelected(option);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void confirmSelection() {
    if (selectedExercise == null) {
      return;
    }

    final picked = selectedExercise!;
    final reps = picked.repsLabel.isEmpty ? '10-12 reps' : picked.repsLabel;
    final rest = picked.restSec != null ? '${picked.restSec}s rest' : '60s rest';

    final exercise = Exercise(
      name: picked.name,
      detail: '3 × $reps • $rest',
      exerciseId: picked.id,
      repMin: picked.repMin,
      repMax: picked.repMax,
      restSec: picked.restSec,
    );

    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F2FA),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Select Exercise',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),

              const SizedBox(height: 28),

              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search exercise',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F2FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _FilterButton(
                      text: selectedMuscleGroup == 'All'
                          ? 'All Muscle Group'
                          : selectedMuscleGroup,
                      onTap: () {
                        showFilterPopup(
                          title: 'Select Muscle Group',
                          options: muscleGroups,
                          currentValue: selectedMuscleGroup,
                          onSelected: (value) {
                            setState(() {
                              selectedMuscleGroup = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterButton(
                      text: selectedEquipment == 'All'
                          ? 'All Equipment'
                          : selectedEquipment,
                      onTap: () {
                        showFilterPopup(
                          title: 'Select Equipment',
                          options: equipmentTypes,
                          currentValue: selectedEquipment,
                          onSelected: (value) {
                            setState(() {
                              selectedEquipment = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _OwnerChip(
                    label: 'My exercises',
                    selected: showMineOnly,
                    onTap: () {
                      setState(() {
                        showMineOnly = true;
                        selectedExercise = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _OwnerChip(
                    label: 'All',
                    selected: !showMineOnly,
                    onTap: () {
                      setState(() {
                        showMineOnly = false;
                        selectedExercise = null;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          if (filteredExercises.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  showMineOnly
                                      ? 'You have no exercises yet. Create one below.'
                                      : 'No exercises found.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          for (final exercise in filteredExercises)
                            _SelectableExerciseCard(
                              exercise: exercise,
                              selected: selectedExercise == exercise,
                              onTap: () {
                                setState(() {
                                  selectedExercise = exercise;
                                });
                              },
                            ),
                          _CreateExerciseButton(
                            onTap: _openCreateExercise,
                          ),
                        ],
                      ),
              ),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedExercise == null ? null : confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Select',
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
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FilterButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F2FA),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OwnerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE4E1FF) : const Color(0xFFF3F2FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF6C63FF) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateExerciseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateExerciseButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 18,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Create new exercise',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableExerciseCard extends StatelessWidget {
  final LibraryExercise exercise;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableExerciseCard({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
          width: 1.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          exercise.muscleGroup,
                          if (exercise.repsLabel.isNotEmpty)
                            exercise.repsLabel,
                          if (exercise.restSec != null)
                            '${exercise.restSec}s rest',
                          if (exercise.byMe) 'by you',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}