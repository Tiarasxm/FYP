import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const ProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        backgroundColor: AppColors.cardMuted,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class SegmentedBar extends StatelessWidget {
  final List<double> fractions;
  final List<Color> colors;
  final double height;

  const SegmentedBar({
    super.key,
    required this.fractions,
    required this.colors,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[];
    for (var i = 0; i < fractions.length; i++) {
      final f = fractions[i];
      if (f <= 0) continue;
      segments.add(
        Expanded(
          flex: (f * 1000).round(),
          child: Container(color: colors[i % colors.length]),
        ),
      );
    }
    final used = fractions.fold<double>(0, (a, b) => a + b).clamp(0, 1);
    final remaining = (1 - used);
    if (remaining > 0) {
      segments.add(
        Expanded(
          flex: (remaining * 1000).round(),
          child: Container(color: AppColors.cardMuted),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(children: segments),
      ),
    );
  }
}
