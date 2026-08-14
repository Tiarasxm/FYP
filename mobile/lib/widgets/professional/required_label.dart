import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RequiredLabel extends StatelessWidget {
  final String text;

  const RequiredLabel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        children: const [
          TextSpan(
            text: '*',
            style: TextStyle(
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}