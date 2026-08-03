import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'plan_detail_screen.dart';

class SavedPlansScreen extends StatefulWidget {
  const SavedPlansScreen({super.key});

  @override
  State<SavedPlansScreen> createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  bool _isLoading = true;

  Map<String, dynamic>? _activePlan;
  String _createdBy = 'ShapeRush';

  @override
  void initState() {
    super.initState();
    _loadActivePlan();
  }

  Future<void> _loadActivePlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final savedResponse = await client
          .from('saved_plans')
          .select('saved_plan_id, free_plan_id, saved_at')
          .eq('profile_id', userId)
          .order('saved_at', ascending: false)
          .limit(1);

      final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

      if (savedRows.isEmpty) {
        if (!mounted) return;

        setState(() {
          _activePlan = null;
          _createdBy = 'ShapeRush';
        });

        return;
      }

      final freePlanId = savedRows.first['free_plan_id']?.toString();

      if (freePlanId == null || freePlanId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _activePlan = null;
          _createdBy = 'ShapeRush';
        });

        return;
      }

      final plan = await client
          .from('free_plans')
          .select(
            'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at',
          )
          .eq('free_plan_id', freePlanId)
          .or('status.is.null,status.neq.archived')
          .maybeSingle();

      if (plan == null) {
        if (!mounted) return;

        setState(() {
          _activePlan = null;
          _createdBy = 'ShapeRush';
        });

        return;
      }

      String createdBy = 'ShapeRush';

      final professionalId = plan['professional_id']?.toString();

      if (professionalId != null && professionalId.isNotEmpty) {
        final profile = await client
            .from('profiles')
            .select('full_name, email')
            .eq('id', professionalId)
            .maybeSingle();

        final fullName = profile?['full_name']?.toString().trim();
        final email = profile?['email']?.toString().trim();

        if (fullName != null && fullName.isNotEmpty) {
          createdBy = fullName;
        } else if (email != null && email.isNotEmpty) {
          createdBy = email.split('@').first;
        }
      }

      if (!mounted) return;

      setState(() {
        _activePlan = plan;
        _createdBy = createdBy;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load active plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _planTitle(Map<String, dynamic> plan) {
    final title = plan['plan_name']?.toString().trim();

    if (title == null || title.isEmpty) {
      return 'Untitled Plan';
    }

    return title;
  }

  String _durationText(Map<String, dynamic> plan) {
    final durationWeeks = _parseInt(plan['duration_weeks']);

    if (durationWeeks == null || durationWeeks <= 0) {
      return '30 Days';
    }

    return '${durationWeeks * 7} Days';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<String> _planTags(Map<String, dynamic> plan) {
    final tags = [
      plan['tag1'],
      plan['tag2'],
      plan['tag3'],
    ]
        .where((tag) => tag != null && tag.toString().trim().isNotEmpty)
        .map((tag) => tag.toString().trim())
        .toList();

    final category = plan['category']?.toString().trim();

    if (category != null && category.isNotEmpty) {
      final exists = tags.any(
        (tag) => tag.toLowerCase() == category.toLowerCase(),
      );

      if (!exists) {
        tags.add(category);
      }
    }

    if (tags.isEmpty) {
      tags.add('General');
    }

    return tags;
  }

  Future<void> _openPlanDetail() async {
    final plan = _activePlan;

    if (plan == null) return;

    final planId = plan['free_plan_id']?.toString();

    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan id.')),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(
          planId: planId,
          title: _planTitle(plan),
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadActivePlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Saved Workout Plans',
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_activePlan == null)
          _emptyState()
        else
          _planCard(_activePlan!),
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border,
                color: AppColors.primary,
                size: 30,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No active plan yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Choose a public plan from the Workout tab.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final title = _planTitle(plan);
    final duration = _durationText(plan);
    final tags = _planTags(plan);

    return GestureDetector(
      onTap: _openPlanDetail,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.pillRadius,
                    ),
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
              '$duration • ~45 min',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags) PillTag(tag),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Created By $_createdBy',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

                const Icon(
                  Icons.bookmark,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}