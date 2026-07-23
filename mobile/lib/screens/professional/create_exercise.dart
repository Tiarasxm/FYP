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
  final TextEditingController repsController = TextEditingController();
  final TextEditingController restController = TextEditingController();
  final TextEditingController instructionController = TextEditingController();

  String muscleGroup = 'Chest';
  String equipment = 'Barbell';
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    repsController.dispose();
    restController.dispose();
    instructionController.dispose();
    super.dispose();
  }

  Future<void> saveExercise() async {
    final name = nameController.text.trim();
    final reps = repsController.text.trim();
    final rest = restController.text.trim();
    final instructions = instructionController.text.trim();

    if (name.isEmpty) {
      showMessage('Please enter exercise name.');
      return;
    }

    final repNumbers = RegExp(r'\d+')
        .allMatches(reps)
        .map((match) => int.parse(match.group(0)!))
        .toList();
    final repMin = repNumbers.isNotEmpty ? repNumbers.first : null;
    final repMax = repNumbers.length > 1 ? repNumbers.last : repMin;
    final restSec = int.tryParse(rest);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      showMessage('You must be signed in to save an exercise.');
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
        'default_rep_min': repMin,
        'default_rep_max': repMax,
        'default_rest_sec': restSec,
        'instructions': instructions,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage('Failed to save exercise: $e');
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
                      fontSize: 22,
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
                        hint: 'Chest Press (Barbell)',
                      ),

                      const SizedBox(height: 18),

                      _DropdownField(
                        label: 'Muscle Group',
                        value: muscleGroup,
                        items: muscleGroups.where((item) => item != 'All').toList(),
                        onChanged: (value) {
                          setState(() {
                            muscleGroup = value;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      _DropdownField(
                        label: 'Equipment',
                        value: equipment,
                        items: equipmentTypes.where((item) => item != 'All').toList(),
                        onChanged: (value) {
                          setState(() {
                            equipment = value;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              label: 'Default reps',
                              controller: repsController,
                              hint: '6 - 8',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _InputField(
                              label: 'Rest (sec)',
                              controller: restController,
                              hint: '120',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _InputField(
                        label: 'Instructions',
                        controller: instructionController,
                        hint: 'Keep back flat, lower bar to mid-chest...',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.3,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Add demo image / video',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _InputField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String value) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F2FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
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
      ],
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