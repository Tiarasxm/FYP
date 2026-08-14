class NutritionGoals {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const NutritionGoals defaults = NutritionGoals(
    calories: 1600,
    protein: 108,
    carbs: 180,
    fat: 60,
  );

  double get proteinFraction => calories > 0 ? (protein * 4) / calories : 0;
  double get carbsFraction => calories > 0 ? (carbs * 4) / calories : 0;
  double get fatFraction => calories > 0 ? (fat * 9) / calories : 0;
}
