import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.cardDecoration(color: color, radius: radius),
      child: child,
    );
  }
}
