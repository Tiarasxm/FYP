import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/professional/mock_exercises.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';

class CreateExercise extends StatefulWidget {
  const CreateExercise({super.key});

  @override
  State<CreateExercise> createState() => _CreateExerciseState();
}

class _CreateExerciseState extends State<CreateExercise> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController repMinController = TextEditingController();
  final TextEditingController repMaxController = TextEditingController();
  final TextEditingController restController = TextEditingController();
  final TextEditingController instructionController = TextEditingController();

  String? muscleGroup;
  String? equipment;

  bool isSaving = false;

  List<String> get muscleGroupOptions {
    return muscleGroups.where((item) => item != 'All').toList();
  }

  List<String> get equipmentOptions {
    return equipmentTypes.where((item) => item != 'All').toList();
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

  Future<void> saveExercise() async {
    final name = nameController.text.trim();
    final repMin = int.tryParse(repMinController.text.trim());
    final repMax = int.tryParse(repMaxController.text.trim());
    final restSec = int.tryParse(restController.text.trim());
    final instructions = instructionController.text.trim();

    if (name.isEmpty) {
      showMessage('Please enter exercise name.');
      return;
    }

    if (muscleGroup == null) {
      showMessage('Please select muscle group.');
      return;
    }

    if (equipment == null) {
      showMessage('Please select equipment.');
      return;
    }

    if (repMin == null) {
      showMessage('Please enter minimum reps.');
      return;
    }

    if (repMax == null) {
      showMessage('Please enter maximum reps.');
      return;
    }

    if (repMax < repMin) {
      showMessage('Maximum reps cannot be smaller than minimum reps.');
      return;
    }

    if (restSec == null) {
      showMessage('Please enter rest seconds.');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      showMessage('You must be signed in.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await Supabase.instance.client.from('exercise_library').insert({
        'professional_id': userId,
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'category': muscleGroup,
        'default_rep_min': repMin,
        'default_rep_max': repMax,
        'default_rest_sec': restSec,
        'instructions': instructions.isEmpty ? null : instructions,
        'status': 'active',
      });

      if (!mounted) return;

      showMessage('Exercise created successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to create exercise: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                    'New Exercise',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _InputField(
                        label: 'Name',
                        controller: nameController,
                        hintText: 'Enter exercise name',
                      ),

                      const SizedBox(height: 20),

                      _DropdownField(
                        label: 'Muscle Group',
                        value: muscleGroup,
                        hintText: 'Select muscle group',
                        items: muscleGroupOptions,
                        onChanged: (value) {
                          setState(() {
                            muscleGroup = value;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      _DropdownField(
                        label: 'Equipment',
                        value: equipment,
                        hintText: 'Select equipment',
                        items: equipmentOptions,
                        onChanged: (value) {
                          setState(() {
                            equipment = value;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Rep Min',
                              controller: repMinController,
                              hintText: 'Min',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _InputField(
                              label: 'Rep Max',
                              controller: repMaxController,
                              hintText: 'Max',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _InputField(
                        label: 'Rest (sec)',
                        controller: restController,
                        hintText: 'Enter rest seconds',
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 20),

                      _InputField(
                        label: 'Instructions',
                        controller: instructionController,
                        hintText: 'Enter instructions',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Colors.grey.shade600,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add demo image / video',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Exercise',
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

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType keyboardType;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldWrapper(
      label: label,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _inputDecoration().copyWith(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final String hintText;
  final List<String> items;
  final void Function(String value) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldWrapper(
      label: label,
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(
          hintText,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(Icons.keyboard_arrow_down),
        decoration: _inputDecoration(),
        menuMaxHeight: MediaQuery.of(context).size.height * 0.45,
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

class _FieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldWrapper({
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration() {
  return InputDecoration(
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
  );
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