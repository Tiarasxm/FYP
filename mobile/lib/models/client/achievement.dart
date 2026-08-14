import 'package:flutter/material.dart';

class Achievement {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool achieved;
  final String? progressLabel;
  final double? progressValue;

  const Achievement({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    this.achieved = false,
    this.progressLabel,
    this.progressValue,
  });
}
