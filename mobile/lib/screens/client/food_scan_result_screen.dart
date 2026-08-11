import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class FoodScanResultScreen extends StatefulWidget {
  final XFile imageFile;

  const FoodScanResultScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<FoodScanResultScreen> createState() => _FoodScanResultScreenState();
}

class _FoodScanResultScreenState extends State<FoodScanResultScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _mealImageBucket = 'meal-images';

  bool _isScanning = true;
  bool _isLogging = false;

  Uint8List? _imageBytes;

  String _mealType = 'Breakfast';
  String _foodName = 'Scanning food...';

  int _calories = 0;
  int _proteinG = 0;
  int _carbsG = 0;
  int _fatG = 0;

  final List<_IngredientDraft> _ingredients = [];

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _loadAndScanImage();
  }

  @override
  void dispose() {
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAndScanImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
      });

      await _scanFood();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to load image: $error');
      setState(() {
        _isScanning = false;
      });
    }
  }

  String get _imageMimeType {
    final path = widget.imageFile.path.toLowerCase();

    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }


  Future<void> _scanFood() async {
    final bytes = _imageBytes;

    if (bytes == null || bytes.isEmpty) {
      _showMessage('Missing food image.');
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final response = await _client.functions.invoke(
        'ai-food-scan',
        body: {
          'imageBase64': base64Encode(bytes),
          'mimeType': _imageMimeType,
        },
      );

      final Map<String, dynamic> data = _parseFunctionResponse(response.data);

      _applyScanResult(data);
    } catch (error) {
      if (!mounted) return;

      _showMessage('AI food scan failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Map<String, dynamic> _parseFunctionResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String) {
      final decoded = jsonDecode(data);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }

    throw Exception('Invalid AI response.');
  }

  void _applyScanResult(Map<String, dynamic> data) {
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }

    final rawIngredients = data['ingredients'];
    final newIngredients = <_IngredientDraft>[];

    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final name = map['name']?.toString().trim();
          final kcal = _parseInt(map['calories_kcal']);

          if (name != null && name.isNotEmpty) {
            newIngredients.add(
              _IngredientDraft(
                name: name,
                caloriesKcal: kcal ?? 0,
              ),
            );
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _foodName = data['food_name']?.toString().trim().isNotEmpty == true
          ? data['food_name'].toString().trim()
          : 'Unknown Food';
      _calories = _parseInt(data['calories_kcal']) ?? 0;
      _proteinG = _parseInt(data['protein_g']) ?? 0;
      _carbsG = _parseInt(data['carbs_g']) ?? 0;
      _fatG = _parseInt(data['fat_g']) ?? 0;
      _ingredients
        ..clear()
        ..addAll(newIngredients);
    });
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    return int.tryParse(value.toString().trim());
  }

  Future<void> _logMeal() async {
    if (_isLogging || _isScanning) return;

    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      _showMessage('You must be signed in.');
      return;
    }

    setState(() {
      _isLogging = true;
    });

    try {
      final ingredientText = _ingredients
          .map((item) {
            final name = item.name.trim();
            final kcal = item.caloriesKcal;

            if (name.isEmpty) return null;
            if (kcal <= 0) return name;

            return '$name (${kcal} kcal)';
          })
          .whereType<String>()
          .join(', ');

      final imageUrl = await _uploadMealImage(userId);

      await _client.from('meal_logs').insert({
        'profile_id': userId,
        'meal_type': _mealType,
        'food_name': _foodName.trim().isEmpty ? 'Unknown Food' : _foodName.trim(),
        'ingredients': ingredientText,
        'calories': _calories,
        'protein_g': _proteinG,
        'carbs_g': _carbsG,
        'fat_g': _fatG,
        'image_url': imageUrl,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      _showMessage('Meal logged successfully.');

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to log meal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  Future<String?> _uploadMealImage(String userId) async {
    final bytes = _imageBytes;

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final fileExtension = _imageFileExtension;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final storagePath = '$userId/$fileName';

    await _client.storage.from(_mealImageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _imageMimeType,
          ),
        );

    return _client.storage.from(_mealImageBucket).getPublicUrl(storagePath);
  }

  String get _imageFileExtension {
    final path = widget.imageFile.path.toLowerCase();

    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';

    return 'jpg';
  }


  Future<void> _editTextValue({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSaved,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Save',
                    onPressed: () {
                      Navigator.of(sheetContext).pop(controller.text.trim());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (value == null || value.isEmpty) return;

    setState(() {
      onSaved(value);
    });
  }

  void _editFoodName() {
    _editTextValue(
      title: 'Edit Food Name',
      initialValue: _foodName,
      onSaved: (value) {
        _foodName = value;
      },
    );
  }

  void _editCalories() {
    _editTextValue(
      title: 'Edit Calories',
      initialValue: '$_calories',
      keyboardType: TextInputType.number,
      onSaved: (value) {
        _calories = int.tryParse(value) ?? _calories;
      },
    );
  }

  void _editMacro(String label) {
    int currentValue;

    switch (label) {
      case 'Protein':
        currentValue = _proteinG;
        break;
      case 'Carbs':
        currentValue = _carbsG;
        break;
      case 'Fat':
        currentValue = _fatG;
        break;
      default:
        currentValue = 0;
    }

    _editTextValue(
      title: 'Edit $label',
      initialValue: '$currentValue',
      keyboardType: TextInputType.number,
      onSaved: (value) {
        final number = int.tryParse(value);

        if (number == null) return;

        if (label == 'Protein') _proteinG = number;
        if (label == 'Carbs') _carbsG = number;
        if (label == 'Fat') _fatG = number;
      },
    );
  }

  Future<void> _editIngredient(int index) async {
    if (index < 0 || index >= _ingredients.length) return;

    final item = _ingredients[index];
    final nameController = TextEditingController(text: item.name);
    final kcalController = TextEditingController(text: '${item.caloriesKcal}');

    final result = await showModalBottomSheet<_IngredientDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Ingredient',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      fillColor: AppColors.cardMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kcalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Calories',
                      filled: true,
                      fillColor: AppColors.cardMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Save',
                    onPressed: () {
                      Navigator.of(sheetContext).pop(
                        _IngredientDraft(
                          name: nameController.text.trim(),
                          caloriesKcal:
                              int.tryParse(kcalController.text.trim()) ?? 0,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    kcalController.dispose();

    if (result == null) return;

    setState(() {
      item.name = result.name;
      item.caloriesKcal = result.caloriesKcal;
      result.dispose();
    });
  }

  void _deleteIngredient(int index) {
    if (index < 0 || index >= _ingredients.length) return;

    setState(() {
      final removed = _ingredients.removeAt(index);
      removed.dispose();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _isScanning;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _imageHeader(context),
          Expanded(
            child: scanning
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _editFoodName,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _foodName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _mealTypeDropdown(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _editCalories,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$_calories',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'kcal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Icon(
                                Icons.edit,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _macroBox(
                              'Protein',
                              '${_proteinG}g',
                              () => _editMacro('Protein'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _macroBox(
                              'Carbs',
                              '${_carbsG}g',
                              () => _editMacro('Carbs'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _macroBox(
                              'Fat',
                              '${_fatG}g',
                              () => _editMacro('Fat'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Identified Ingredients',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_ingredients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No ingredients identified.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < _ingredients.length; i++)
                          _ingredientRow(_ingredients[i], i),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              8,
              AppSpacing.screenPadding,
              16,
            ),
            child: PrimaryButton(
              label: scanning
                  ? 'Scanning...'
                  : _isLogging
                      ? 'Logging...'
                      : 'Log Meal',
              onPressed: scanning || _isLogging ? null : _logMeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageHeader(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      color: const Color(0xFF3D2E28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_imageBytes != null)
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
            )
          else
            const Center(
              child: Icon(
                Icons.restaurant,
                size: 56,
                color: Colors.white24,
              ),
            ),
          Container(color: Colors.black.withOpacity(0.18)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    shape: const CircleBorder(),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'AI Food Scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mealType,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: [
            for (final type in _mealTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) {
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

  Widget _macroBox(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 11, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientRow(_IngredientDraft item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${item.caloriesKcal} kcal',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editIngredient(index),
            child: const Icon(
              Icons.edit,
              size: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteIngredient(index),
            child: const Icon(
              Icons.delete_outline,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientDraft {
  String name;
  int caloriesKcal;

  _IngredientDraft({
    required this.name,
    required this.caloriesKcal,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories_kcal': caloriesKcal,
    };
  }

  void dispose() {}
}
