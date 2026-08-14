import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
          "Privacy Policy",
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
            PolicySection(
              title: "A Legal Disclaimer",
              content:
                  "This Privacy Policy describes how ShapeRush collects, uses, stores and protects information when users access the application. By using the application, users agree to the practices described in this policy.",
            ),
            PolicySection(
              title: "Interpretation and Definition",
              content:
                  "The words used in this Privacy Policy have meanings defined under this section. Account refers to a unique account created for a user. Personal Data refers to information that identifies or may identify an individual.",
            ),
            PolicySection(
              title: "Information We Collect",
              content:
                  "ShapeRush may collect account information, profile details, workout records, nutrition logs, wearable device data, comments, posts, uploaded images and application usage information.",
            ),
            PolicySection(
              title: "How We Use Information",
              content:
                  "The information collected may be used to provide fitness services, generate progress insights, improve recommendations, support account management, maintain security and improve the application experience.",
            ),
            PolicySection(
              title: "Data Storage and Security",
              content:
                  "Reasonable technical and organisational safeguards are used to protect user information. However, no internet transmission or electronic storage system can guarantee complete security.",
            ),
            PolicySection(
              title: "Third-Party Services",
              content:
                  "ShapeRush may use third-party services for authentication, cloud storage, analytics, wearable device integration and payment processing. These providers may process information under their own privacy policies.",
            ),
            PolicySection(
              title: "User Rights",
              content:
                  "Users may request access to, correction of or deletion of their personal information, subject to applicable legal and operational requirements.",
            ),
            PolicySection(
              title: "Changes to This Privacy Policy",
              content:
                  "This Privacy Policy may be updated from time to time. Users are encouraged to review the latest version available in the application.",
            ),
            PolicySection(
              title: "Contact Us",
              content:
                  "Questions about this Privacy Policy may be submitted through the feedback or support function in ShapeRush.",
            ),
          ],
        ),
      ),
    );
  }
}

class PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const PolicySection({
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
