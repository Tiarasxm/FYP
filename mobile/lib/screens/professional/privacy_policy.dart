import 'package:flutter/material.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

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
                        'Privacy Policy',
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
                      _PolicyTitle('A legal disclaimer'),
                      _PolicyText(
                        'This Privacy Policy explains how ShapeRush collects, uses, stores, and protects your personal information when you use our application and services. By using ShapeRush, you agree to the practices described in this policy.',
                      ),

                      SizedBox(height: 28),

                      _PolicyTitle('Interpretation and Definition'),
                      SizedBox(height: 14),

                      _PolicySubtitle('Interpretation'),
                      _PolicyText(
                        'Words with capitalized first letters have meanings defined under the following conditions. These definitions apply whether they appear in singular or plural form.',
                      ),

                      SizedBox(height: 18),

                      _PolicySubtitle('Definition'),
                      _PolicyText(
                        'For this Privacy Policy, “App” refers to ShapeRush. “User” refers to the person using the App. “Personal Data” means information that can identify a user, such as name, email address, profile details, and fitness-related data.',
                      ),

                      SizedBox(height: 28),

                      _PolicyTitle('Information We Collect'),
                      _PolicyText(
                        'We may collect account details, profile information, fitness goals, workout plans, messages, progress data, and technical information such as device type and app usage. This information helps us provide and improve our services.',
                      ),

                      SizedBox(height: 28),

                      _PolicyTitle('How We Use Information'),
                      _PolicyText(
                        'We use your information to create and manage your account, provide workout plans, connect users with fitness professionals, improve app performance, and support user safety and service quality.',
                      ),

                      SizedBox(height: 28),

                      _PolicyTitle('Data Security'),
                      _PolicyText(
                        'We aim to protect your information using reasonable technical and organizational measures. However, no online service can guarantee complete security.',
                      ),

                      SizedBox(height: 28),

                      _PolicyTitle('Contact Us'),
                      _PolicyText(
                        'If you have questions about this Privacy Policy, you may contact the ShapeRush support team through the app or official website.',
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

class _PolicyTitle extends StatelessWidget {
  final String text;

  const _PolicyTitle(this.text);

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

class _PolicySubtitle extends StatelessWidget {
  final String text;

  const _PolicySubtitle(this.text);

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

class _PolicyText extends StatelessWidget {
  final String text;

  const _PolicyText(this.text);

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