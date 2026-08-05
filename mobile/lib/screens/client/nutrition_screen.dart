import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/nutrition.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/progress_bar.dart';
import '../../widgets/client/section_card.dart';
import '../../widgets/client/section_header.dart';
import 'food_scan_screen.dart';
import 'log_meal_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  static const int _caloriesGoal = 1600;
  static const int _proteinGoal = 108;
  static const int _carbsGoal = 180;
  static const int _fatGoal = 60;

  int _water = 0;
  int _waterGoal = 2000;
  bool _scanUnlocked = false;
  bool _isLoadingMeals = true;

  List<Map<String, dynamic>> _mealLogs = [];

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  int get _caloriesConsumed {
    return _mealLogs.fold<int>(0, (sum, meal) {
      return sum + (_parseInt(meal['calories']) ?? 0);
    });
  }

  double get _proteinConsumed {
    return _mealLogs.fold<double>(0, (sum, meal) {
      return sum + (_parseDouble(meal['protein_g']) ?? 0);
    });
  }

  double get _carbsConsumed {
    return _mealLogs.fold<double>(0, (sum, meal) {
      return sum + (_parseDouble(meal['carbs_g']) ?? 0);
    });
  }

  double get _fatConsumed {
    return _mealLogs.fold<double>(0, (sum, meal) {
      return sum + (_parseDouble(meal['fat_g']) ?? 0);
    });
  }

  List<Macro> get _macros {
    return [
      Macro(
        name: 'Protein',
        current: _proteinConsumed.round(),
        target: _proteinGoal,
        color: AppColors.red,
      ),
      Macro(
        name: 'Carbs',
        current: _carbsConsumed.round(),
        target: _carbsGoal,
        color: AppColors.cyan,
      ),
      Macro(
        name: 'Fat',
        current: _fatConsumed.round(),
        target: _fatGoal,
        color: AppColors.green,
      ),
    ];
  }

  List<Meal> get _mealSummaries {
    const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final type in mealOrder) {
      grouped[type] = [];
    }

    for (final meal in _mealLogs) {
      final type = meal['meal_type']?.toString() ?? 'Snack';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(meal);
    }

    final result = <Meal>[];

    for (final type in mealOrder) {
      final meals = grouped[type] ?? [];
      if (meals.isEmpty) continue;

      int calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;

      for (final meal in meals) {
        calories += _parseInt(meal['calories']) ?? 0;
        protein += _parseDouble(meal['protein_g']) ?? 0;
        carbs += _parseDouble(meal['carbs_g']) ?? 0;
        fat += _parseDouble(meal['fat_g']) ?? 0;
      }

      result.add(
        Meal(
          name: type,
          calories: calories,
          protein: protein.round(),
          carbs: carbs.round(),
          fat: fat.round(),
          icon: _mealIcon(type),
        ),
      );
    }

    return result;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.free_breakfast;
      case 'Lunch':
        return Icons.lunch_dining;
      case 'Dinner':
        return Icons.dinner_dining;
      case 'Snack':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }

  List<Map<String, dynamic>> _logsForMealType(String mealType) {
    return _mealLogs.where((meal) {
      return meal['meal_type']?.toString() == mealType;
    }).toList();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _isLoadingMeals = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await client
          .from('meal_logs')
          .select(
            'meal_log_id, meal_type, food_name, ingredients, calories, protein_g, carbs_g, fat_g, image_url, logged_at',
          )
          .eq('profile_id', userId)
          .gte('logged_at', startOfDay.toUtc().toIso8601String())
          .lt('logged_at', endOfDay.toUtc().toIso8601String())
          .order('logged_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _mealLogs = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load meals: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMeals = false;
        });
      }
    }
  }

  Future<void> _openLogMeal({String initialMealType = 'Breakfast'}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LogMealScreen(initialMealType: initialMealType),
      ),
    );

    if (created == true && mounted) {
      await _loadMeals();
    }
  }

  Future<void> _openMealDetail(String mealType) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealDetailScreen(
          mealType: mealType,
          meals: _logsForMealType(mealType),
          icon: _mealIcon(mealType),
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadMeals();
    }
  }

  void _addWater() {
    setState(() {
      _water = (_water + 250).clamp(0, _waterGoal);
    });
  }

  void _showWaterSettings() {
    final controller = TextEditingController(text: '$_waterGoal');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Water Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Daily water goal (ml)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'ml',
                    filled: true,
                    fillColor: AppColors.cardMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final goal = int.tryParse(controller.text.trim());
                      if (goal != null && goal > 0) {
                        setState(() {
                          _waterGoal = goal;
                          _water = _water.clamp(0, _waterGoal);
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadMeals,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            16,
            AppSpacing.screenPadding,
            24,
          ),
          children: [
            const Text(
              'Nutrition',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _calorieCard(),
            const SizedBox(height: 14),
            _macrosRow(),
            const SizedBox(height: 16),
            _aiFoodScanCard(),
            const SizedBox(height: 16),
            _waterCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: SectionHeader('Meals')),
                TextButton.icon(
                  onPressed: () {
                    _openLogMeal();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log Meal'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingMeals)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_mealSummaries.isEmpty)
              _emptyMealsCard()
            else
              for (final meal in _mealSummaries) ...[
                _mealRow(meal),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _calorieCard() {
    final consumed = _caloriesConsumed;
    const goal = _caloriesGoal;

    final proteinFraction = (_proteinConsumed * 4 / goal).clamp(0, 1).toDouble();
    final carbsFraction = (_carbsConsumed * 4 / goal).clamp(0, 1).toDouble();
    final fatFraction = (_fatConsumed * 9 / goal).clamp(0, 1).toDouble();

    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.textPrimary),
                    children: [
                      TextSpan(
                        text: '$consumed',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' /$goal kcal',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedBar(
                  fractions: [proteinFraction, carbsFraction, fatFraction],
                  colors: const [
                    AppColors.red,
                    AppColors.cyan,
                    AppColors.green,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macrosRow() {
    final macros = _macros;

    return Row(
      children: [
        for (var i = 0; i < macros.length; i++) ...[
          Expanded(child: _macroTile(macros[i])),
          if (i != macros.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _macroTile(Macro macro) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            macro.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: '${macro.current}g',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' /${macro.target}g',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ProgressBar(progress: macro.progress, color: macro.color),
        ],
      ),
    );
  }

  Widget _aiFoodScanCard() {
    if (_scanUnlocked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FoodScanScreen()),
            );
          },
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('AI Food Scan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SectionCard(
      color: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Food Scan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan food instantly and track nutrition in seconds.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _scanUnlocked = true),
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: const Text('Unlock Priority'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterCard() {
    final progress = _waterGoal == 0 ? 0.0 : _water / _waterGoal;

    return SectionCard(
      color: AppColors.cardMuted,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Text(
                'Water',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$_water ml / $_waterGoal ml',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(progress: progress, color: AppColors.cyan, height: 8),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addWater,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Water',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _showWaterSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Water Settings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  Widget _emptyMealsCard() {
    return SectionCard(
      color: AppColors.cardMuted,
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu,
            color: AppColors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 10),
          const Text(
            'No meals logged today.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Log Meal to add breakfast, lunch, dinner, or snack.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _openLogMeal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log Meal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealRow(Meal meal) {
    return GestureDetector(
      onTap: () {
        _openMealDetail(meal.name);
      },
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                meal.icon,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _macroChip('P ${meal.protein}g', AppColors.red),
                      const SizedBox(width: 8),
                      _macroChip('C ${meal.carbs}g', AppColors.cyan),
                      const SizedBox(width: 8),
                      _macroChip('F ${meal.fat}g', AppColors.green),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.textPrimary),
                    children: [
                      TextSpan(
                        text: '${meal.calories}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' kcal',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class MealDetailScreen extends StatelessWidget {
  final String mealType;
  final List<Map<String, dynamic>> meals;
  final IconData icon;

  const MealDetailScreen({
    super.key,
    required this.mealType,
    required this.meals,
    required this.icon,
  });

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _timeText(dynamic value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '';

    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  int get _totalCalories {
    return meals.fold<int>(0, (sum, meal) {
      return sum + _parseInt(meal['calories']);
    });
  }

  int get _totalProtein {
    return meals.fold<int>(0, (sum, meal) {
      return sum + _parseInt(meal['protein_g']);
    });
  }

  int get _totalCarbs {
    return meals.fold<int>(0, (sum, meal) {
      return sum + _parseInt(meal['carbs_g']);
    });
  }

  int get _totalFat {
    return meals.fold<int>(0, (sum, meal) {
      return sum + _parseInt(meal['fat_g']);
    });
  }

  Future<void> _openLogMeal(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LogMealScreen(initialMealType: mealType),
      ),
    );

    if (created == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardMuted,
                      shape: const CircleBorder(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      mealType,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _openLogMeal(context);
                    },
                    icon: const Icon(Icons.add, size: 22),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  24,
                ),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Foods',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (meals.isEmpty)
                    _emptyDetailCard(context)
                  else
                    for (final meal in meals) ...[
                      _foodCard(meal),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$mealType Summary',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meals.length} item${meals.length == 1 ? '' : 's'} logged today',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _summaryChip('$_totalCalories kcal', AppColors.textPrimary),
                    _summaryChip('P ${_totalProtein}g', AppColors.red),
                    _summaryChip('C ${_totalCarbs}g', AppColors.cyan),
                    _summaryChip('F ${_totalFat}g', AppColors.green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  Widget _emptyDetailCard(BuildContext context) {
    return SectionCard(
      color: AppColors.cardMuted,
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu,
            color: AppColors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            'No $mealType logged today.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _openLogMeal(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Log $mealType',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodCard(Map<String, dynamic> meal) {
    final foodName = meal['food_name']?.toString().trim() ?? 'Food';
    final ingredients = meal['ingredients']?.toString().trim() ?? '';
    final imageUrl = meal['image_url']?.toString().trim() ?? '';
    final calories = _parseInt(meal['calories']);
    final protein = _parseInt(meal['protein_g']);
    final carbs = _parseInt(meal['carbs_g']);
    final fat = _parseInt(meal['fat_g']);
    final time = _timeText(meal['logged_at']);

    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textMuted,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$calories kcal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ingredients,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryChip('P ${protein}g', AppColors.red),
              const SizedBox(width: 10),
              _summaryChip('C ${carbs}g', AppColors.cyan),
              const SizedBox(width: 10),
              _summaryChip('F ${fat}g', AppColors.green),
              const Spacer(),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}