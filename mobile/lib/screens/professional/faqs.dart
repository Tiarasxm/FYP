import 'package:flutter/material.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../theme/app_theme.dart';

class FAQs extends StatelessWidget {
  const FAQs({super.key});

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
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
                        'FAQs',
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

              const SizedBox(height: 42),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    _FAQItem(
                      question: 'Is ShapeRush free to use?',
                      answer:
                          'ShapeRush provides basic features for free. Some advanced plans or professional services may require a paid subscription.',
                    ),
                    _FAQItem(
                      question: 'Can I track weight, workout or intermittent fasting?',
                      answer:
                          'Yes. ShapeRush can help users track fitness progress, workout plans, and health-related goals.',
                    ),
                    _FAQItem(
                      question: 'How do I switch fitness plans?',
                      answer:
                          'You can open your active plan, choose another plan, and update your current fitness plan.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),

        if (expanded)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
              right: 8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
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