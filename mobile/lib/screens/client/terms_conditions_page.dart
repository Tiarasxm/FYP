import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
          "Terms and Conditions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TermsSection(
              title: "Acceptance of Terms",
              content:
                  "By downloading, installing or using ShapeRush, users agree to comply with these Terms and Conditions. Users who do not agree should stop using the application.",
            ),
            TermsSection(
              title: "Eligibility",
              content:
                  "Users must provide accurate account information and must be legally permitted to use the service. Users under the required legal age should obtain permission from a parent or guardian.",
            ),
            TermsSection(
              title: "Health and Safety Disclaimer",
              content:
                  "ShapeRush provides general fitness and wellness information. It does not provide medical diagnosis, treatment or professional medical advice.",
            ),
            TermsSection(
              title: "Physical Limitations",
              content:
                  "Users are responsible for considering their health, fitness level and physical limitations before performing any exercise. Users should stop exercising and seek professional advice if pain, dizziness or discomfort occurs.",
            ),
            TermsSection(
              title: "User Accounts",
              content:
                  "Users are responsible for maintaining the confidentiality of their login credentials and for all activities performed through their accounts.",
            ),
            TermsSection(
              title: "User Content",
              content:
                  "Users may upload posts, images, comments and other content. Users must not upload unlawful, harmful, abusive, misleading or copyrighted content without permission.",
            ),
            TermsSection(
              title: "Social Features",
              content:
                  "Users must interact respectfully with other members. Harassment, impersonation, spam and misuse of reporting features are prohibited.",
            ),
            TermsSection(
              title: "Wearable Device Information",
              content:
                  "Data received from wearable devices may be incomplete or inaccurate. ShapeRush does not guarantee the accuracy of third-party device measurements.",
            ),
            TermsSection(
              title: "Membership and Payment",
              content:
                  "Premium features may require payment. Subscription fees, cancellation rules and renewal terms will be shown before the user confirms a purchase.",
            ),
            TermsSection(
              title: "Limitation of Liability",
              content:
                  "To the extent permitted by law, ShapeRush is not liable for injuries, losses, data inaccuracies or damages arising from reliance on application content or third-party services.",
            ),
            TermsSection(
              title: "Changes to the Terms",
              content:
                  "These Terms and Conditions may be updated periodically. Continued use of the application after an update indicates acceptance of the revised terms.",
            ),
          ],
        ),
      ),
    );
  }
}

class TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const TermsSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
