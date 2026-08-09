import 'package:flutter/material.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../theme/app_theme.dart';

class TermsConditions extends StatelessWidget {
  const TermsConditions({super.key});

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _BackButton(
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Terms and Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),

              const SizedBox(height: 36),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TermsTitle('Acceptance of Terms'),
                      _TermsText(
                        'By downloading, installing, or using ShapeRush, you agree to follow these Terms and Conditions. If you do not agree with these terms, you should not use the App.',
                      ),

                      SizedBox(height: 28),

                      _TermsTitle('Eligibility'),
                      _TermsText(
                        'To use ShapeRush, you must be old enough to create an account and capable of entering into a binding agreement. You are responsible for providing accurate account information.',
                      ),

                      SizedBox(height: 28),

                      _TermsTitle('Health and Safety Disclaimer'),
                      SizedBox(height: 14),

                      _TermsSubtitle('General Health'),
                      _TermsText(
                        'Users should consult a healthcare professional before starting any exercise program, especially if they have medical conditions, are pregnant, or have not exercised in a long time. ShapeRush is not a medical service.',
                      ),

                      SizedBox(height: 18),

                      _TermsSubtitle('Physical Limitations'),
                      _TermsText(
                        'Workout plans may not be suitable for every individual. Users should understand their own physical limits and stop exercising if they feel pain, discomfort, dizziness, or other unusual symptoms.',
                      ),

                      SizedBox(height: 28),

                      _TermsTitle('User Responsibilities'),
                      _TermsText(
                        'You are responsible for using the App safely, keeping your account secure, and ensuring the information you provide is accurate. You must not misuse the App or attempt to harm other users.',
                      ),

                      SizedBox(height: 28),

                      _TermsTitle('Fitness Professional Services'),
                      _TermsText(
                        'Fitness professionals may provide plans, advice, or communication through ShapeRush. Users should understand that results may vary and depend on personal effort, health condition, and consistency.',
                      ),

                      SizedBox(height: 28),

                      _TermsTitle('Changes to Terms'),
                      _TermsText(
                        'ShapeRush may update these Terms and Conditions from time to time. Continued use of the App after changes means you accept the updated terms.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsTitle extends StatelessWidget {
  final String text;

  const _TermsTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TermsSubtitle extends StatelessWidget {
  final String text;

  const _TermsSubtitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  final String text;

  const _TermsText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.3,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.cardMuted,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}