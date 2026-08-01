import 'package:flutter/material.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'edit_plan_schedule.dart';

class EditPlan extends StatefulWidget {
  final WorkoutPlan plan;

  const EditPlan({
    super.key,
    required this.plan,
  });

  @override
  State<EditPlan> createState() => _EditPlanState();
}

class _EditPlanState extends State<EditPlan> {
  late final TextEditingController planNameController;

  late List<String> selectedTags;
  late String duration;
  late String visibility;

  final List<String> tagOptions = [
    'Fat Loss',
    'Full Body',
    'Strength',
    'Upper Body',
    'Lower Body',
    'Core',
    'Cardio',
    'Beginner',
  ];

  final List<String> durationOptions = [
    '1 week',
    '2 weeks',
    '4 weeks',
    '8 weeks',
    '12 weeks',
  ];

  final List<String> visibilityOptions = [
    'Public',
    'Private',
  ];

  @override
  void initState() {
    super.initState();

    planNameController = TextEditingController(text: widget.plan.title);

    selectedTags = widget.plan.tags
        .where((tag) =>
            tag.toLowerCase() != 'public' && tag.toLowerCase() != 'private')
        .take(3)
        .toList();

    visibility = normalizeVisibility(widget.plan.visibility);
    duration = getDurationText();
  }

  @override
  void dispose() {
    planNameController.dispose();
    super.dispose();
  }

  String normalizeVisibility(String value) {
    final lower = value.trim().toLowerCase();

    if (lower == 'private') {
      return 'Private';
    }

    return 'Public';
  }

  String getDurationText() {
    if (widget.plan.durationWeeks != null) {
      return '${widget.plan.durationWeeks} weeks';
    }

    if (widget.plan.days > 0 && widget.plan.days % 7 == 0) {
      return '${widget.plan.days ~/ 7} weeks';
    }

    return '4 weeks';
  }

  List<String> get allDurationOptions {
    final options = [...durationOptions];

    if (!options.contains(duration)) {
      options.insert(0, duration);
    }

    return options;
  }

  void addTag() {
    if (selectedTags.length >= 3) {
      return;
    }

    final availableTags =
        tagOptions.where((tag) => !selectedTags.contains(tag)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
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

                const SizedBox(height: 16),

                const Text(
                  'Select Tag',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: availableTags.isEmpty
                      ? Center(
                          child: Text(
                            'No more tags available.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                          itemCount: availableTags.length,
                          itemBuilder: (context, index) {
                            final tag = availableTags[index];

                            return ListTile(
                              title: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedTags.add(tag);
                                });

                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void goToSchedule() {
    final planName = planNameController.text.trim();

    if (planName.isEmpty) {
      showMessage('Please enter a plan name.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlanSchedule(
          plan: widget.plan,
          planName: planName,
          tags: selectedTags,
          duration: duration,
          visibility: visibility,
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
                  Expanded(
                    child: Text(
                      'Edit: ${widget.plan.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 34),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InputField(
                        label: 'Plan Name',
                        controller: planNameController,
                        hintText: 'Enter plan name',
                      ),

                      const SizedBox(height: 26),

                      RichText(
                        text: TextSpan(
                          text: 'Tags ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(
                              text: '(max 3)',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...selectedTags.map((tag) {
                            return _TagChip(
                              text: tag,
                              onDeleted: () {
                                setState(() {
                                  selectedTags.remove(tag);
                                });
                              },
                            );
                          }),
                          if (selectedTags.length < 3)
                            GestureDetector(
                              onTap: addTag,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Text(
                                  '+ Add Tag',
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      _DropdownField(
                        label: 'Duration',
                        value: duration,
                        items: allDurationOptions,
                        onChanged: (value) {
                          setState(() {
                            duration = value;
                          });
                        },
                      ),

                      const SizedBox(height: 26),

                      _DropdownField(
                        label: 'Visibility',
                        value: visibility,
                        items: visibilityOptions,
                        onChanged: (value) {
                          setState(() {
                            visibility = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: goToSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Next',
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

class _TagChip extends StatelessWidget {
  final String text;
  final VoidCallback onDeleted;

  const _TagChip({
    required this.text,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: const Color(0xFFECE9FF),
      deleteIcon: const Icon(
        Icons.close,
        size: 16,
        color: Color(0xFF6C63FF),
      ),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldWrapper(
      label: label,
      child: TextField(
        controller: controller,
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
    return _FieldWrapper(
      label: label,
      child: DropdownButtonFormField<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down),
        decoration: _inputDecoration(),
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