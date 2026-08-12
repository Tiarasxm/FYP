import 'package:flutter/material.dart';

import '../../models/client/workout_plan.dart';
import '../../theme/app_theme.dart';
import 'pill_tag.dart';
import 'section_card.dart';

class PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onTap;

  const PlanCard({
    super.key,
    required this.plan,
    required this.onBookmarkTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
      color: plan.active ? AppColors.primarySoft : AppColors.cardMuted,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (plan.active)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${plan.duration}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final t in plan.tags) PillTag(t)],
                ),
              ),
              GestureDetector(
                onTap: onBookmarkTap,
                child: Icon(
                  plan.bookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: plan.bookmarked
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
