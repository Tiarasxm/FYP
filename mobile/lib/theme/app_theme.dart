import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6658FF);
  static const Color primarySoft = Color(0xFFEDEBFF);
  static const Color accent = Color(0xFF6C5CFF);

  static const Color pageBg = Color(0xFFF7F7FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardMuted = Color(0xFFEBEAF2);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color navBar = Color(0xFF111318);

  static const Color blue = Color(0xFF5B8DEF);
  static const Color red = Color(0xFFEF6461);
  static const Color green = Color(0xFF9BD24A);
  static const Color cyan = Color(0xFF3EC6E0);
  static const Color amber = Color(0xFFF4C15A);
  static const Color dark = Color(0xFF1F2430);
}

class AppSpacing {
  static const double screenPadding = 20;
  static const double cardRadius = 20;
  static const double pillRadius = 999;
  static const double gap = 16;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.pageBg,
      ),
      scaffoldBackgroundColor: AppColors.pageBg,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }

  static BoxDecoration cardDecoration({Color? color, double? radius}) {
    return BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius ?? AppSpacing.cardRadius),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}
