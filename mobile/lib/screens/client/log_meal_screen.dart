import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class LogMealScreen extends StatefulWidget {
  final String initialMealType;

  const LogMealScreen({
    super.key,
    this.initialMealType = 'Breakfast',
  });

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  late String _mealType;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();

  static const _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  @override
  void initState() {
    super.initState();

    if (_mealTypes.contains(widget.initialMealType)) {
      _mealType = widget.initialMealType;
    } else {
      _mealType = 'Breakfast';
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _ingredientsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  int _parseNumber(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (error) {
      _showMessage('Failed to pick image: $error');
    }
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

  Future<String?> _uploadMealImage(String userId) async {
    final image = _selectedImage;
    final bytes = _selectedImageBytes;

    if (image == null || bytes == null) return null;

    final extension = _safeImageExtension(image);
    final contentType = _contentTypeForExtension(extension);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$userId/meal_$timestamp.$extension';

    await Supabase.instance.client.storage.from('meal-images').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    final imageUrl = Supabase.instance.client.storage
        .from('meal-images')
        .getPublicUrl(filePath);

    return imageUrl;
  }

  Future<void> _logMeal() async {
    final foodName = _foodNameController.text.trim();
    final ingredients = _ingredientsController.text.trim();

    final calories = _parseNumber(_caloriesController.text);
    final protein = _parseNumber(_proteinController.text);
    final carbs = _parseNumber(_carbsController.text);
    final fat = _parseNumber(_fatController.text);

    if (foodName.isEmpty) {
      _showMessage('Please enter food name.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final imageUrl = await _uploadMealImage(userId);

      await client.from('meal_logs').insert({
        'profile_id': userId,
        'meal_type': _mealType,
        'food_name': foodName,
        'ingredients': ingredients.isEmpty ? null : ingredients,
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
        'image_url': imageUrl,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal logged successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage('Failed to log meal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Log Meal',
      bottomButton: PrimaryButton(
        label: _isSaving ? 'Saving...' : 'Log Meal',
        onPressed: _isSaving ? null : _logMeal,
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _mealTypeDropdown(),
        ),
        const SizedBox(height: 8),
        _label('Food Name'),
        const SizedBox(height: 8),
        _textField(
          controller: _foodNameController,
          hint: 'eg. Tuna Poke Bowl',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        _label('Ingredients'),
        const SizedBox(height: 8),
        _textField(
          controller: _ingredientsController,
          hint: 'eg. rice, tuna, green beans',
          maxLines: 3,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 18),
        _label('Nutrition Facts'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _factField(
                label: 'Calories',
                controller: _caloriesController,
                suffix: 'kcal',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _factField(
                label: 'Protein',
                controller: _proteinController,
                suffix: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _factField(
                label: 'Carbs',
                controller: _carbsController,
                suffix: 'g',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _factField(
                label: 'Fat',
                controller: _fatController,
                suffix: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Image'),
        const SizedBox(height: 8),
        _imagePicker(),
      ],
    );
  }

  Widget _mealTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mealType,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            for (final type in _mealTypes)
              DropdownMenuItem(
                value: type,
                child: Text(type),
              ),
          ],
          onChanged: _isSaving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _mealType = value;
                    });
                  }
                },
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isSaving,
      style: const TextStyle(fontSize: 14),
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.cardMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _factField({
    required String label,
    required TextEditingController controller,
    required String suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: suffix,
              suffixStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePicker() {
    final imageBytes = _selectedImageBytes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: imageBytes == null
          ? Column(
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 32,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose an image to upload (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving ? null : _pickImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Add image',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _pickImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Change image',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _selectedImage = null;
                                  _selectedImageBytes = null;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}