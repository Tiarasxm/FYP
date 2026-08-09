import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "FAQs",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FaqItem(
            question: "Is WiseWorkout free to use?",
            answer:
                "Yes. WiseWorkout offers a free plan with basic workout, nutrition, progress tracking and social features. Some advanced features may require a premium membership.",
          ),
          SizedBox(height: 10),
          FaqItem(
            question: "Can I track weight, workout or nutrition?",
            answer:
                "Yes. You can record your weight, workout activities, meals, water intake and other fitness data through the application.",
          ),
          SizedBox(height: 10),
          FaqItem(
            question: "How do I switch fitness plans?",
            answer:
                "Go to the fitness plan section, select a new plan and confirm the change. Your previous workout records will remain available.",
          ),
          SizedBox(height: 10),
          FaqItem(
            question: "Can I connect a wearable device?",
            answer:
                "Yes. Supported wearable devices can be connected from Profile, followed by Wearable Devices.",
          ),
          SizedBox(height: 10),
          FaqItem(
            question: "How do I reset my password?",
            answer:
                "Open the login page and select Forgot Password. A password reset link will be sent to your registered email address.",
          ),
        ],
      ),
    );
  }
}

class FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const FaqItem({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        childrenPadding: const EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: 14,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
