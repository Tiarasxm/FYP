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
  static const List<String> _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  bool _isScanning = true;
  bool _isLogging = false;
  bool _isFixing = false;

  Uint8List? _imageBytes;

  String _mealType = 'Breakfast';
  String _foodName = 'Scanning food...';

  int _calories = 0;
  int _proteinG = 0;
  int _carbsG = 0;
  int _fatG = 0;

  final List<_IngredientDraft> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _loadAndScanImage();
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

  Future<void> _scanFood({String? fixDescription}) async {
    final bytes = _imageBytes;

    if (bytes == null || bytes.isEmpty) {
      _showMessage('Missing food image.');
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final body = <String, dynamic>{
        'imageBase64': base64Encode(bytes),
        'mimeType': _imageMimeType,
      };

      if (fixDescription != null && fixDescription.isNotEmpty) {
        body['correction'] = fixDescription;
        body['previousResult'] = {
          'food_name': _foodName,
          'calories_kcal': _calories,
          'protein_g': _proteinG,
          'carbs_g': _carbsG,
          'fat_g': _fatG,
          'ingredients': _ingredients
              .map((e) => {
                    'name': e.name,
                    'calories_kcal': e.caloriesKcal,
                  })
              .toList(),
        };
      }

      final response = await _client.functions.invoke(
        'ai-food-scan',
        body: body,
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
        'logged_at': DateTime.now().toUtc().toIso8601String(),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _foodName,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _mealTypeDropdown(),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_calories',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 7),
                            child: Text(
                              'kcal',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(child: _macroBox('Protein', '${_proteinG}g')),
                          const SizedBox(width: 10),
                          Expanded(child: _macroBox('Carbs', '${_carbsG}g')),
                          const SizedBox(width: 10),
                          Expanded(child: _macroBox('Fat', '${_fatG}g')),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Identified Ingredients',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),

                      const SizedBox(height: 12),

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
                        for (final ingredient in _ingredients)
                          _ingredientRow(ingredient),
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
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: scanning
                        ? 'Scanning...'
                        : _isLogging
                            ? 'Logging...'
                            : 'Log Meal',
                    onPressed: scanning || _isLogging ? null : _logMeal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: scanning || _isFixing
                        ? null
                        : _showFixDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isFixing ? 'Fixing...' : 'Fix',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFixDialog() async {
    final description = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FixResultsSheet(),
    );

    if (description == null || description.isEmpty) return;
    if (!mounted) return;

    await _rescanWithFix(description);
  }

  Future<void> _rescanWithFix(String description) async {
    setState(() {
      _isFixing = true;
    });

    await _scanFood(fixDescription: description);

    if (mounted) {
      setState(() {
        _isFixing = false;
      });
      _showMessage('Results updated with your fix.');
    }
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mealType,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.card,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          items: [
            for (final type in _mealTypes)
              DropdownMenuItem(
                value: type,
                child: Text(type),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _mealType = value;
            });
          },
        ),
      ),
    );
  }

  Widget _macroBox(String label, String value) {
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
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientRow(_IngredientDraft item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${item.caloriesKcal} kcal',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
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
}

class _FixResultsSheet extends StatefulWidget {
  const _FixResultsSheet();

  @override
  State<_FixResultsSheet> createState() => _FixResultsSheetState();
}

class _FixResultsSheetState extends State<_FixResultsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _controller.text.trim();

    if (description.isEmpty) return;

    Navigator.of(context).pop(description);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fix Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe what\'s wrong with the analysis so the AI can re-scan '
            'with your corrections.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'e.g. This is a chicken salad, not a burger. '
                  'The portion is smaller.',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.cardMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Re-scan with Fix',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
