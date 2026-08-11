import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client/nutrition_goals.dart';

class NutritionGoalsService {
  static const _defaultGoals = NutritionGoals.defaults;

  static Future<NutritionGoals> calculateForCurrentUser() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      return _defaultGoals;
    }

    try {
      final profile = await client
          .from('profiles')
          .select(
            'weight_kg, height_cm, date_of_birth, gender, activity_level, fitness_goal',
          )
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        return _defaultGoals;
      }

      return _calculateFromProfile(profile);
    } catch (error) {
      return _defaultGoals;
    }
  }

  static NutritionGoals _calculateFromProfile(Map<String, dynamic> profile) {
    final weight = _parseDouble(profile['weight_kg']);
    final height = _parseDouble(profile['height_cm']);
    final gender = _normalize(profile['gender']);
    final activityLevel = _normalize(profile['activity_level']);
    final fitnessGoal = _normalize(profile['fitness_goal']);
    final age = _ageFromDob(profile['date_of_birth']);

    if (weight == null || height == null || age == null) {
      return _defaultGoals;
    }

    // Mifflin-St Jeor BMR
    double bmr = (10 * weight) + (6.25 * height) - (5 * age);

    if (gender == 'female') {
      bmr -= 161;
    } else {
      // male or unknown default
      bmr += 5;
    }

    // Activity multiplier
    final activityMultiplier = _activityMultiplier(activityLevel);
    final tdee = bmr * activityMultiplier;

    // Goal adjustment
    final goalAdjustment = _goalAdjustment(fitnessGoal);
    final calories = (tdee + goalAdjustment).round();

    if (calories <= 0) {
      return _defaultGoals;
    }

    // Macro split by goal
    final split = _macroSplit(fitnessGoal);
    final protein = ((calories * split.protein) / 4).round();
    final carbs = ((calories * split.carbs) / 4).round();
    final fat = ((calories * split.fat) / 9).round();

    return NutritionGoals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _normalize(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  static int? _ageFromDob(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;

    final now = DateTime.now();
    var age = now.year - parsed.year;

    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }

    return age;
  }

  static double _activityMultiplier(String activityLevel) {
    switch (activityLevel) {
      case 'sedentary':
        return 1.2;
      case 'lightly active':
        return 1.375;
      case 'moderately active':
        return 1.55;
      case 'very active':
        return 1.725;
      default:
        return 1.2;
    }
  }

  static double _goalAdjustment(String fitnessGoal) {
    switch (fitnessGoal) {
      case 'lose weight':
        return -500;
      case 'gain weight':
        return 300;
      case 'build muscles':
        return 250;
      case 'improve endurance':
        return 100;
      case 'get fitter':
      case 'maintain':
      default:
        return 0;
    }
  }

  static _MacroSplit _macroSplit(String fitnessGoal) {
    switch (fitnessGoal) {
      case 'lose weight':
        return const _MacroSplit(protein: 0.35, carbs: 0.30, fat: 0.35);
      case 'gain weight':
        return const _MacroSplit(protein: 0.25, carbs: 0.50, fat: 0.25);
      case 'build muscles':
        return const _MacroSplit(protein: 0.30, carbs: 0.45, fat: 0.25);
      case 'improve endurance':
        return const _MacroSplit(protein: 0.25, carbs: 0.55, fat: 0.20);
      case 'get fitter':
      case 'maintain':
      default:
        return const _MacroSplit(protein: 0.30, carbs: 0.40, fat: 0.30);
    }
  }
}

class _MacroSplit {
  final double protein;
  final double carbs;
  final double fat;

  const _MacroSplit({
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}
