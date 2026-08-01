import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/professional/mock_exercises.dart';
import '../../models/professional/library_exercise.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';

import 'create_exercise.dart';

class ExerciseLibrary extends StatefulWidget {
  const ExerciseLibrary({super.key});

  @override
  State<ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends State<ExerciseLibrary> {
  String searchText = '';
  String selectedMuscleGroup = 'All';
  String selectedEquipment = 'All';

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

      if (userId == null) {
        setState(() {
          _exercises = [];
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('exercise_library')
          .select('name, muscle_group, equipment')
          .eq('professional_id', userId)
          .order('name');

      setState(() {
        _exercises = (response as List<dynamic>)
            .map(
              (row) => LibraryExercise(
                name: row['name']?.toString() ?? '',
                muscleGroup: row['muscle_group']?.toString() ?? '',
                equipment: row['equipment']?.toString() ?? '',
              ),
            )
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

    if (created == true && mounted) {
      await _loadExercises();
    }
  }

  List<LibraryExercise> get filteredExercises {
    return _exercises.where((exercise) {
      final bool matchesSearch = exercise.name.toLowerCase().contains(
            searchText.toLowerCase(),
          );

      final bool matchesMuscleGroup = selectedMuscleGroup == 'All' ||
          exercise.muscleGroup == selectedMuscleGroup;

      final bool matchesEquipment =
          selectedEquipment == 'All' || exercise.equipment == selectedEquipment;

      return matchesSearch && matchesMuscleGroup && matchesEquipment;
    }).toList();
  }

  void showSelectionPopup({
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
                      color: Colors.black,
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
                        final bool isSelected = option == currentValue;

                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            children: [
              // top bar
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
                        'Exercise Library',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 44),
                ],
              ),

              const SizedBox(height: 28),

              // search box
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
                    fontWeight: FontWeight.w500,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                    size: 22,
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

              // filters
              Row(
                children: [
                  Expanded(
                    child: _FilterButton(
                      text: selectedMuscleGroup == 'All'
                          ? 'All Muscle Group'
                          : selectedMuscleGroup,
                      onTap: () {
                        showSelectionPopup(
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
                        showSelectionPopup(
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

              const SizedBox(height: 24),

              // exercise list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : filteredExercises.isEmpty
                        ? Center(
                            child: Text(
                              'No exercises found',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadExercises,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: filteredExercises.length,
                              itemBuilder: (context, index) {
                                final exercise = filteredExercises[index];

                                return _ExerciseCard(exercise: exercise);
                              },
                            ),
                          ),
              ),

              const SizedBox(height: 12),

              // bottom create exercise button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _openCreateExercise,
                  icon: const Icon(
                    Icons.add,
                    size: 20,
                  ),
                  label: const Text(
                    'Create Exercise',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                    color: Colors.black,
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

class _ExerciseCard extends StatelessWidget {
  final LibraryExercise exercise;

  const _ExerciseCard({
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  exercise.muscleGroup,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
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