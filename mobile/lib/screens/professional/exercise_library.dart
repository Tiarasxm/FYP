import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/professional/mock_exercises.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';

import 'create_exercise.dart';
import '../../theme/app_theme.dart';

class ExerciseLibrary extends StatefulWidget {
  const ExerciseLibrary({super.key});

  @override
  State<ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends State<ExerciseLibrary> {
  String searchText = '';
  String selectedMuscleGroup = 'All';
  String selectedEquipment = 'All';

  List<_ExerciseItem> _exercises = [];
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
        if (!mounted) return;

        setState(() {
          _exercises = [];
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('exercise_library')
          .select(
            'exercise_id, name, muscle_group, equipment, category, default_rep_min, default_rep_max, default_rest_sec, instructions, status',
          )
          .eq('professional_id', userId)
          .or('status.is.null,status.eq.active')
          .order('name');

      final exercises = (response as List<dynamic>).map((row) {
        return _ExerciseItem.fromMap(
          Map<String, dynamic>.from(row as Map),
        );
      }).toList();

      final exerciseIds = exercises
          .map((exercise) => exercise.id)
          .where((id) => id.isNotEmpty)
          .toList();

      final usedExerciseIds = <String>{};

      if (exerciseIds.isNotEmpty) {
        final planUsedResponse = await Supabase.instance.client
            .from('plan_exercises')
            .select('exercise_id')
            .inFilter('exercise_id', exerciseIds);

        for (final row in planUsedResponse as List<dynamic>) {
          final id = row['exercise_id']?.toString();

          if (id != null && id.isNotEmpty) {
            usedExerciseIds.add(id);
          }
        }

        final workoutUsedResponse = await Supabase.instance.client
            .from('workout_exercises')
            .select('exercise_id')
            .inFilter('exercise_id', exerciseIds);

        for (final row in workoutUsedResponse as List<dynamic>) {
          final id = row['exercise_id']?.toString();

          if (id != null && id.isNotEmpty) {
            usedExerciseIds.add(id);
          }
        }
      }

      final finalExercises = exercises.map((exercise) {
        return exercise.copyWith(
          isUsed: usedExerciseIds.contains(exercise.id),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _exercises = finalExercises;
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

  List<_ExerciseItem> get filteredExercises {
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

  List<String> get _muscleGroupOptions {
    return muscleGroups.where((item) => item != 'All').toList();
  }

  List<String> get _equipmentOptions {
    return equipmentTypes.where((item) => item != 'All').toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _isUsedInPlan(String exerciseId) async {
    final response = await Supabase.instance.client
        .from('plan_exercises')
        .select('plan_exercise_id')
        .eq('exercise_id', exerciseId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  Future<bool> _hasWorkoutHistory(String exerciseId) async {
    final response = await Supabase.instance.client
        .from('workout_exercises')
        .select('workout_exercise_id')
        .eq('exercise_id', exerciseId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  Future<String> _saveEditedExercise({
    required _ExerciseItem oldExercise,
    required _ExerciseEditResult result,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('You must be signed in.');
    }

    final usedInPlan = await _isUsedInPlan(oldExercise.id);
    final hasHistory = await _hasWorkoutHistory(oldExercise.id);

    if (usedInPlan || hasHistory) {
      throw Exception(
        'This exercise is already used in a plan or workout history. It cannot be edited.',
      );
    }

    final data = {
      'professional_id': userId,
      'name': result.name,
      'muscle_group': result.muscleGroup,
      'equipment': result.equipment,
      'category': result.muscleGroup,
      'default_rep_min': result.repMin,
      'default_rep_max': result.repMax,
      'default_rest_sec': result.restSec,
      'instructions':
          result.instructions.trim().isEmpty ? null : result.instructions.trim(),
      'status': 'active',
    };

    await Supabase.instance.client
        .from('exercise_library')
        .update(data)
        .eq('exercise_id', oldExercise.id)
        .eq('professional_id', userId);

    return 'Exercise updated.';
  }

  Future<void> _deleteExercise(_ExerciseItem exercise) async {
    if (exercise.isUsed) {
      _showMessage(
        'This exercise is already used in a plan or workout history. It cannot be deleted.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Exercise'),
          content: Text(
            'Are you sure you want to delete "${exercise.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        _showMessage('You must be signed in.');
        return;
      }

      final usedInPlan = await _isUsedInPlan(exercise.id);
      final hasHistory = await _hasWorkoutHistory(exercise.id);

      if (usedInPlan || hasHistory) {
        _showMessage(
          'This exercise is already used in a plan or workout history. It cannot be deleted.',
        );
        await _loadExercises();
        return;
      }

      await Supabase.instance.client
          .from('exercise_library')
          .delete()
          .eq('exercise_id', exercise.id)
          .eq('professional_id', userId);

      _showMessage('Exercise deleted.');

      await _loadExercises();
    } catch (e) {
      _showMessage('Failed to delete exercise: $e');
    }
  }

  Future<void> _openExerciseDetail(_ExerciseItem exercise) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ExerciseDetailSheet(exercise: exercise);
      },
    );
  }

  Future<void> _openEditExercise(_ExerciseItem exercise) async {
    if (exercise.isUsed) {
      _showMessage(
        'This exercise is already used in a plan or workout history. It cannot be edited.',
      );
      return;
    }

    final result = await showModalBottomSheet<_ExerciseEditResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) {
        return _EditExerciseSheet(
          exercise: exercise,
          muscleGroupOptions: _muscleGroupOptions,
          equipmentOptions: _equipmentOptions,
        );
      },
    );

    if (result == null) return;

    try {
      final message = await _saveEditedExercise(
        oldExercise: exercise,
        result: result,
      );

      if (!mounted) return;

      await _loadExercises();
      _showMessage(message);
    } catch (e) {
      _showMessage('Failed to update exercise: $e');
    }
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
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: AppColors.border,
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
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.cardMuted,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppColors.textMuted,
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
                          color: AppColors.textPrimary,
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
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
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
                                color: AppColors.textSecondary,
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

                                return _ExerciseCard(
                                  exercise: exercise,
                                  onTap: () {
                                    _openExerciseDetail(exercise);
                                  },
                                  onEdit: () {
                                    _openEditExercise(exercise);
                                  },
                                  onDelete: () {
                                    _deleteExercise(exercise);
                                  },
                                );
                              },
                            ),
                          ),
              ),
              const SizedBox(height: 12),
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
                    backgroundColor: AppColors.primary,
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

class _ExerciseItem {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final int? repMin;
  final int? repMax;
  final int? restSec;
  final String? instructions;
  final String? status;
  final bool isUsed;

  const _ExerciseItem({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.repMin,
    this.repMax,
    this.restSec,
    this.instructions,
    this.status,
    this.isUsed = false,
  });

  factory _ExerciseItem.fromMap(Map<String, dynamic> row) {
    return _ExerciseItem(
      id: row['exercise_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      muscleGroup: row['muscle_group']?.toString() ?? '',
      equipment: row['equipment']?.toString() ?? '',
      repMin: _parseIntValue(row['default_rep_min']),
      repMax: _parseIntValue(row['default_rep_max']),
      restSec: _parseIntValue(row['default_rest_sec']),
      instructions: row['instructions']?.toString(),
      status: row['status']?.toString(),
    );
  }

  _ExerciseItem copyWith({
    bool? isUsed,
  }) {
    return _ExerciseItem(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      repMin: repMin,
      repMax: repMax,
      restSec: restSec,
      instructions: instructions,
      status: status,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  static int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _ExerciseEditResult {
  final String name;
  final String muscleGroup;
  final String equipment;
  final int repMin;
  final int repMax;
  final int restSec;
  final String instructions;

  const _ExerciseEditResult({
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.repMin,
    required this.repMax,
    required this.restSec,
    required this.instructions,
  });
}

class _EditExerciseSheet extends StatefulWidget {
  final _ExerciseItem exercise;
  final List<String> muscleGroupOptions;
  final List<String> equipmentOptions;

  const _EditExerciseSheet({
    required this.exercise,
    required this.muscleGroupOptions,
    required this.equipmentOptions,
  });

  @override
  State<_EditExerciseSheet> createState() => _EditExerciseSheetState();
}

class _EditExerciseSheetState extends State<_EditExerciseSheet> {
  late final TextEditingController nameController;
  late final TextEditingController repMinController;
  late final TextEditingController repMaxController;
  late final TextEditingController restController;
  late final TextEditingController instructionController;

  String? selectedMuscle;
  String? selectedEquipment;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.exercise.name);
    repMinController = TextEditingController(
      text: widget.exercise.repMin?.toString() ?? '',
    );
    repMaxController = TextEditingController(
      text: widget.exercise.repMax?.toString() ?? '',
    );
    restController = TextEditingController(
      text: widget.exercise.restSec?.toString() ?? '',
    );
    instructionController = TextEditingController(
      text: widget.exercise.instructions ?? '',
    );

    selectedMuscle = widget.muscleGroupOptions.contains(
      widget.exercise.muscleGroup,
    )
        ? widget.exercise.muscleGroup
        : null;

    selectedEquipment = widget.equipmentOptions.contains(
      widget.exercise.equipment,
    )
        ? widget.exercise.equipment
        : null;
  }

  @override
  void dispose() {
    nameController.dispose();
    repMinController.dispose();
    repMaxController.dispose();
    restController.dispose();
    instructionController.dispose();
    super.dispose();
  }

  void _showSheetMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  void _submit() {
    final name = nameController.text.trim();
    final repMin = _parseInt(repMinController.text);
    final repMax = _parseInt(repMaxController.text);
    final restSec = _parseInt(restController.text);

    if (name.isEmpty) {
      _showSheetMessage('Please enter exercise name.');
      return;
    }

    if (selectedMuscle == null) {
      _showSheetMessage('Please select muscle group.');
      return;
    }

    if (selectedEquipment == null) {
      _showSheetMessage('Please select equipment.');
      return;
    }

    if (repMin == null) {
      _showSheetMessage('Please enter minimum reps.');
      return;
    }

    if (repMax == null) {
      _showSheetMessage('Please enter maximum reps.');
      return;
    }

    if (repMax < repMin) {
      _showSheetMessage('Maximum reps cannot be smaller than minimum reps.');
      return;
    }

    if (restSec == null) {
      _showSheetMessage('Please enter rest seconds.');
      return;
    }

    Navigator.of(context).pop(
      _ExerciseEditResult(
        name: name,
        muscleGroup: selectedMuscle!,
        equipment: selectedEquipment!,
        repMin: repMin,
        repMax: repMax,
        restSec: restSec,
        instructions: instructionController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Center(
          child: Container(
            width: 430,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Edit Exercise',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 24,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: AppColors.border,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditTextField(
                            label: 'Name',
                            controller: nameController,
                            hintText: 'Enter exercise name',
                          ),
                          const SizedBox(height: 16),
                          _EditDropdownField(
                            label: 'Muscle Group',
                            value: selectedMuscle,
                            hintText: 'Select muscle group',
                            items: widget.muscleGroupOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedMuscle = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _EditDropdownField(
                            label: 'Equipment',
                            value: selectedEquipment,
                            hintText: 'Select equipment',
                            items: widget.equipmentOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedEquipment = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _EditTextField(
                                  label: 'Rep Min',
                                  controller: repMinController,
                                  hintText: 'Min',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _EditTextField(
                                  label: 'Rep Max',
                                  controller: repMaxController,
                                  hintText: 'Max',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _EditTextField(
                            label: 'Rest Seconds',
                            controller: restController,
                            hintText: 'Enter rest seconds',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          _EditTextField(
                            label: 'Instructions',
                            controller: instructionController,
                            hintText: 'Enter instructions',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      color: AppColors.cardMuted,
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseItem exercise;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 64,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
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
                  color: AppColors.textPrimary,
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.isUsed
                          ? '${exercise.muscleGroup} • ${exercise.equipment} • Used'
                          : '${exercise.muscleGroup} • ${exercise.equipment}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: exercise.isUsed
                            ? Colors.orange.shade700
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: exercise.isUsed
                      ? AppColors.border
                      : AppColors.primary,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: exercise.isUsed ? AppColors.border : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final _ExerciseItem exercise;

  const _ExerciseDetailSheet({required this.exercise});

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: Container(
          width: 430,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Exercise Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.close,
                            size: 24,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: AppColors.border,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Name', exercise.name),
                        _detailRow('Muscle Group', exercise.muscleGroup),
                        _detailRow('Equipment', exercise.equipment),
                        _detailRow(
                          'Rep Range',
                          exercise.repMin != null && exercise.repMax != null
                              ? '${exercise.repMin} - ${exercise.repMax}'
                              : (exercise.repMin?.toString() ?? '-'),
                        ),
                        _detailRow(
                          'Rest Seconds',
                          exercise.restSec?.toString() ?? '-',
                        ),
                        _detailRow(
                          'Instructions',
                          exercise.instructions?.isNotEmpty == true
                              ? exercise.instructions!
                              : '-',
                        ),
                        if (exercise.isUsed) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'This exercise is used in a plan or workout history. It cannot be edited or deleted.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _EditTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType keyboardType;

  const _EditTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return _EditFieldWrapper(
      label: label,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _editInputDecoration().copyWith(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EditDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final String hintText;
  final List<String> items;
  final void Function(String value) onChanged;

  const _EditDropdownField({
    required this.label,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _EditFieldWrapper(
      label: label,
      child: DropdownButtonFormField<String>(
        value: value,
        menuMaxHeight: MediaQuery.of(context).size.height * 0.45,
        hint: Text(
          hintText,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(Icons.keyboard_arrow_down),
        decoration: _editInputDecoration(),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _EditFieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;

  const _EditFieldWrapper({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _editInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.cardMuted,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 15,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}