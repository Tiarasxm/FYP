import 'package:flutter/material.dart';
import '../../models/professional/workout_plan.dart';
import '../../theme/app_theme.dart';

class PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback onView;
  final VoidCallback? onEdit;

  const PlanCard({
    super.key,
    required this.plan,
    required this.onView,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final displayChips = [
      ...plan.tags,
      plan.visibility,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${plan.days} Days',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: displayChips.map((chip) {
                    final isVisibility =
                        chip.toLowerCase() == 'public' ||
                        chip.toLowerCase() == 'private';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isVisibility
                            ? AppColors.primarySoft
                            : AppColors.card,
                        border: Border.all(
                          color: isVisibility
                              ? AppColors.primarySoft
                              : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 11,
                          color: isVisibility
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            children: [
              SizedBox(
                width: 68,
                height: 30,
                child: OutlinedButton(
                  onPressed: onEdit ?? () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: 68,
                height: 30,
                child: ElevatedButton(
                  onPressed: onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}