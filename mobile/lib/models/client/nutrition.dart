import 'package:flutter/material.dart';

class Macro {
  final String name;
  final int current;
  final int target;
  final Color color;

  const Macro({
    required this.name,
    required this.current,
    required this.target,
    required this.color,
  });

  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
}

class Meal {
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final IconData icon;
  final String? imageUrl;

  const Meal({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.icon = Icons.restaurant,
    this.imageUrl,
  });
}
