import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SubScreenScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? header;
  final Widget? bottomButton;
  final Widget? trailing;

  const SubScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.header,
    this.bottomButton,
    this.trailing,
  });

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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardMuted,
                      shape: const CircleBorder(),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  if (trailing != null)
                    trailing!
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: header,
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  24,
                ),
                children: children,
              ),
            ),

            if (bottomButton != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  16,
                ),
                child: bottomButton!,
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;

  // 这里改成 VoidCallback?
  // 这样 onPressed 可以传 null
  final VoidCallback? onPressed;

  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              disabled ? AppColors.textMuted : AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textMuted,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}