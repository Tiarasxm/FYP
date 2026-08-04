import 'package:flutter/material.dart';

import '../../models/client/professional.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'chat_screen.dart';
import 'reviews_screen.dart';

class ProfessionalDetailScreen extends StatelessWidget {
  final Professional professional;

  const ProfessionalDetailScreen({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Fitness Professional Details',
      bottomButton: PrimaryButton(
        label: 'Chat Now',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(professional: professional),
            ),
          );
        },
      ),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.person, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                professional.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                professional.specialties,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _statsRow(context),
        const SizedBox(height: 24),
        const Text(
          'About',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          professional.bio ?? 'No bio available.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "${professional.name.split(' ').first}'s Fitness Plans",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _planCard('30-Day Full Body Fat Burn'),
        const SizedBox(height: 12),
        _planCard('30-Day Upper Body Strength'),
      ],
    );
  }

  Widget _statsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stat('${professional.yearsExp}', 'Years Exp.'),
        _divider(),
        _stat('${professional.rating}', 'Rating'),
        _divider(),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReviewsScreen()),
            );
          },
          child: _stat('${professional.reviewCount + 28}', 'Reviews'),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: AppColors.border);
  }

  Widget _planCard(String title) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.bookmark_border,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '30 Days • ~45 min',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillTag('Full Body'),
              PillTag('Fat Loss'),
              PillTag('Strength'),
            ],
          ),
        ],
      ),
    );
  }
}
