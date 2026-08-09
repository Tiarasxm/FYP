import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingAvatar = false;
  bool hasSavedChanges = false;

  String avatarUrl = '';

  String? selectedActivityLevel;
  String? selectedFitnessGoal;

  Uint8List? selectedAvatarBytes;
  XFile? selectedAvatarFile;

  final ImagePicker picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController bmiController = TextEditingController();

  static const List<String> activityOptions = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];

  static const List<String> fitnessGoalOptions = [
    'Get Fitter',
    'Gain Weight',
    'Lose Weight',
    'Improve Endurance',
    'Build Muscles',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    genderController.dispose();
    dateOfBirthController.dispose();
    weightController.dispose();
    heightController.dispose();
    bmiController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _validOption(dynamic value, List<String> options) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) return null;

    return options.contains(text) ? text : null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in.');
      }

      final response = await client
          .from('profiles')
          .select(
            'full_name, email, gender, date_of_birth, weight_kg, height_cm, activity_level, fitness_goal, avatar_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      final data = response ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        nameController.text = data['full_name']?.toString() ?? '';
        emailController.text = data['email']?.toString() ?? user.email ?? '';
        genderController.text = data['gender']?.toString() ?? '';
        dateOfBirthController.text = _formatDateForDisplay(
          data['date_of_birth'],
        );
        weightController.text = _formatNumber(data['weight_kg']);
        heightController.text = _formatNumber(data['height_cm']);
        selectedActivityLevel = _validOption(
          data['activity_level'],
          activityOptions,
        );
        selectedFitnessGoal = _validOption(
          data['fitness_goal'],
          fitnessGoalOptions,
        );
        avatarUrl = data['avatar_url']?.toString() ?? '';

        _updateBmiText();
      });
    } catch (e) {
      _showMessage('Failed to load profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatDateForDisplay(dynamic value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return value.toString();

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString().padLeft(4, '0');

    return '$day/$month/$year';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '';

    final number = double.tryParse(value.toString());

    if (number == null) return value.toString();

    if (number == number.roundToDouble()) {
      return number.round().toString();
    }

    return number.toString();
  }

  DateTime? _parseDateInput(String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    if (text.contains('/')) {
      final parts = text.split('/');

      if (parts.length != 3) return null;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) return null;

      final date = DateTime(year, month, day);

      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }

      return date;
    }

    final parsed = DateTime.tryParse(text);

    if (parsed == null) return null;

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String? _dateToDatabase(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  double? _parseNumberInput(String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  void _updateBmiText() {
    final weight = _parseNumberInput(weightController.text);
    final heightCm = _parseNumberInput(heightController.text);

    if (weight == null || heightCm == null || heightCm <= 0) {
      bmiController.text = '';
      return;
    }

    final heightM = heightCm / 100;
    final bmi = weight / (heightM * heightM);

    bmiController.text = bmi.toStringAsFixed(1);
  }

  String _safeImageExtension(XFile image) {
    final name = image.name.toLowerCase();
    final path = image.path.toLowerCase();

    String extension = 'jpg';

    if (name.contains('.')) {
      extension = name.split('.').last;
    } else if (path.contains('.')) {
      extension = path.split('.').last;
    }

    if (extension == 'jpeg') return 'jpg';
    if (extension == 'jpg') return 'jpg';
    if (extension == 'png') return 'png';
    if (extension == 'webp') return 'webp';
    if (extension == 'gif') return 'gif';

    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'gif') return 'image/gif';

    return 'image/jpeg';
  }

  Future<String> _uploadAvatar({
    required String userId,
    required XFile image,
    required Uint8List bytes,
  }) async {
    final extension = _safeImageExtension(image);
    final contentType = _contentTypeForExtension(extension);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$userId/avatar_$timestamp.$extension';

    await Supabase.instance.client.storage.from('profile-avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    final imageUrl = Supabase.instance.client.storage
        .from('profile-avatars')
        .getPublicUrl(filePath);

    return imageUrl;
  }

  Future<void> _pickAndUploadAvatar() async {
    if (isUploadingAvatar) return;

    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedAvatarFile = image;
        selectedAvatarBytes = bytes;
        isUploadingAvatar = true;
      });

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in.');
      }

      final uploadedUrl = await _uploadAvatar(
        userId: user.id,
        image: image,
        bytes: bytes,
      );

      await client.from('profiles').update({
        'avatar_url': uploadedUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        avatarUrl = uploadedUrl;
        hasSavedChanges = true;
        selectedAvatarFile = null;
        selectedAvatarBytes = null;
      });

      _showMessage('Avatar updated successfully.');
    } catch (e) {
      _showMessage('Failed to upload avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          isUploadingAvatar = false;
        });
      }
    }
  }

  void _goBack() {
    Navigator.pop(context, hasSavedChanges);
  }

  Future<void> updateProfile() async {
    final name = nameController.text.trim();
    final gender = genderController.text.trim();
    final dateText = dateOfBirthController.text.trim();
    final weightText = weightController.text.trim();
    final heightText = heightController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your name.');
      return;
    }

    final dateOfBirth = _parseDateInput(dateText);

    if (dateText.isNotEmpty && dateOfBirth == null) {
      _showMessage('Please enter date of birth as DD/MM/YYYY.');
      return;
    }

    final weight = _parseNumberInput(weightText);
    final height = _parseNumberInput(heightText);

    if (weightText.isNotEmpty && weight == null) {
      _showMessage('Please enter a valid weight.');
      return;
    }

    if (heightText.isNotEmpty && height == null) {
      _showMessage('Please enter a valid height.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in.');
      }

      await client.from('profiles').update({
        'full_name': name,
        'gender': gender.isEmpty ? null : gender,
        'date_of_birth': _dateToDatabase(dateOfBirth),
        'weight_kg': weight,
        'height_cm': height,
        'activity_level': selectedActivityLevel,
        'fitness_goal': selectedFitnessGoal,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        hasSavedChanges = true;
        _updateBmiText();
      });

      _showMessage('Profile updated successfully.');
    } catch (e) {
      _showMessage('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  ImageProvider? get _avatarImageProvider {
    if (selectedAvatarBytes != null) {
      return MemoryImage(selectedAvatarBytes!);
    }

    if (avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.card,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BackButton(
                    onPressed: _goBack,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "My Profile",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),

              const SizedBox(height: 28),

              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: _avatarImageProvider,
                      child: _avatarImageProvider == null
                          ? const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 34,
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ProfileInputField(
                label: "Name",
                controller: nameController,
              ),
              ProfileInputField(
                label: "Email",
                controller: emailController,
                enabled: false,
                keyboardType: TextInputType.emailAddress,
              ),
              ProfileInputField(
                label: "Gender",
                controller: genderController,
              ),
              ProfileInputField(
                label: "Date of Birth",
                controller: dateOfBirthController,
                keyboardType: TextInputType.datetime,
                hintText: 'DD/MM/YYYY',
              ),
              ProfileInputField(
                label: "Weight (kg)",
                controller: weightController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setState(() {
                    _updateBmiText();
                  });
                },
              ),
              ProfileInputField(
                label: "Height (cm)",
                controller: heightController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setState(() {
                    _updateBmiText();
                  });
                },
              ),
              ProfileInputField(
                label: "BMI",
                controller: bmiController,
                enabled: false,
                hintText: 'Calculated from weight and height',
              ),
              ProfileDropdownField(
                label: "Activity Level",
                value: selectedActivityLevel,
                items: activityOptions,
                hintText: "Select activity level",
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() {
                          selectedActivityLevel = value;
                        });
                      },
              ),
              ProfileDropdownField(
                label: "Fitness Goal",
                value: selectedFitnessGoal,
                items: fitnessGoalOptions,
                hintText: "Select fitness goal",
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() {
                          selectedFitnessGoal = value;
                        });
                      },
              ),

              const SizedBox(height: 4),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving ? null : updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isSaving ? "Updating..." : "Update Changes",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

class ProfileInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const ProfileInputField({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.keyboardType,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: enabled ? AppColors.cardMuted : AppColors.border,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String hintText;
  final ValueChanged<String?>? onChanged;

  const ProfileDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final String? safeValue = items.contains(value) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.cardMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                hint: Text(
                  hintText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.cardMuted,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}