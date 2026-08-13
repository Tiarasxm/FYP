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
  bool _isUpdating = false;

  bool _isPriority = false;
  List<Map<String, dynamic>> _savedPlans = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlans();
  }

  Future<void> _loadSavedPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final profile = await client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType =
          profile?['user_type']?.toString().trim().toLowerCase() ?? 'free';
      final isPriority = userType == 'priority';

      final savedResponse = await client
          .from('saved_plans')
          .select('saved_plan_id, free_plan_id, is_active, saved_at')
          .eq('profile_id', userId)
          .eq('is_saved', true)
          .order('saved_at', ascending: false);

      final savedRows = List<Map<String, dynamic>>.from(savedResponse as List);

      final planIds = savedRows
          .map((row) => row['free_plan_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (planIds.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isPriority = isPriority;
          _savedPlans = [];
        });

        return;
      }

      final plansResponse = await client
          .from('free_plans')
          .select(
            'free_plan_id, professional_id, plan_name, category, tag1, tag2, tag3, visibility, duration_weeks, status, created_at, fitness_professional(display_name, profiles!inner(full_name, avatar_url))',
          )
          .inFilter('free_plan_id', planIds)
          .or('status.is.null,status.neq.archived');

      final planRows = List<Map<String, dynamic>>.from(plansResponse as List);

      final planById = <String, Map<String, dynamic>>{};

      for (final plan in planRows) {
        final id = plan['free_plan_id']?.toString();
        if (id != null && id.isNotEmpty) {
          planById[id] = plan;
        }
      }

      final mergedPlans = <Map<String, dynamic>>[];

      for (final saved in savedRows) {
        final planId = saved['free_plan_id']?.toString();
        if (planId == null || planId.isEmpty) continue;

        final plan = planById[planId];
        if (plan == null) continue;

        final visibility =
            plan['visibility']?.toString().trim().toLowerCase() ?? 'public';

        if (!isPriority && visibility != 'public') {
          continue;
        }

        mergedPlans.add({
          ...plan,
          '_saved_plan_id': saved['saved_plan_id'],
          '_is_active': saved['is_active'] == true,
          '_saved_at': saved['saved_at'],
        });
      }

      if (!mounted) return;

      setState(() {
        _isPriority = isPriority;
        _savedPlans = mergedPlans;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved plans: $error')),
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

  bool _isActivePlan(Map<String, dynamic> plan) {
    return plan['_is_active'] == true;
  }

  Future<void> _setActivePlan(Map<String, dynamic> plan) async {
    if (_isUpdating) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final planId = plan['free_plan_id']?.toString();
    final savedPlanId = plan['_saved_plan_id']?.toString();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan id.')),
      );
      return;
    }

    if (savedPlanId == null || savedPlanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing saved plan id.')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await client
          .from('saved_plans')
          .update({'is_active': false})
          .eq('profile_id', userId)
          .eq('is_active', true);

      await client
          .from('saved_plans')
          .update({
            'is_active': true,
            'saved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('saved_plan_id', savedPlanId)
          .eq('profile_id', userId);

      await _loadSavedPlans();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active plan updated.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set active plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _removeSavedPlan(Map<String, dynamic> plan) async {
    if (_isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove saved plan?'),
          content: Text(
            _isActivePlan(plan)
                ? 'This plan will be removed from saved plans, but it will stay as your active plan.'
                : 'This plan will be removed from your saved plans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final savedPlanId = plan['_saved_plan_id']?.toString();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    if (savedPlanId == null || savedPlanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing saved plan id.')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_isActivePlan(plan)) {
        await client
            .from('saved_plans')
            .update({'is_saved': false})
            .eq('saved_plan_id', savedPlanId)
            .eq('profile_id', userId);
      } else {
        await client
            .from('saved_plans')
            .delete()
            .eq('saved_plan_id', savedPlanId)
            .eq('profile_id', userId);
      }

      await _loadSavedPlans();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved plans.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove saved plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openPlanDetail(Map<String, dynamic> plan) async {
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
      await _loadSavedPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitText = _isPriority
        ? '${_savedPlans.length} saved plans'
        : '${_savedPlans.length}/5 saved plans';

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
        else ...[
          Text(
            limitText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (_savedPlans.isEmpty)
            _emptyState()
          else
            for (final plan in _savedPlans) ...[
              _planCard(plan),
              const SizedBox(height: 14),
            ],
        ],
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
              'No saved plans yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Save plans from the Workout tab.',
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
    final isActive = _isActivePlan(plan);

    return GestureDetector(
      onTap: () => _openPlanDetail(plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySoft : AppColors.cardMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
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
                IconButton(
                  onPressed: _isUpdating ? null : () => _removeSavedPlan(plan),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              duration,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _planCreatorRow(plan),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isActive) const PillTag('Active'),
                for (final tag in tags) PillTag(tag),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isActive || _isUpdating ? null : () => _setActivePlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isActive ? 'Current Active Plan' : 'Set as Active Plan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCreatorRow(Map<String, dynamic> plan) {
    final profData = plan['fitness_professional'];
    String? name;
    String? avatarUrl;

    if (profData is Map) {
      final displayName = profData['display_name']?.toString().trim();
      final profiles = profData['profiles'];
      if (profiles is Map) {
        final fullName = profiles['full_name']?.toString().trim();
        avatarUrl = profiles['avatar_url']?.toString().trim();
        if (displayName != null && displayName.isNotEmpty) {
          name = displayName;
        } else if (fullName != null && fullName.isNotEmpty) {
          name = fullName;
        }
      }
    }

    if (name == null || name.isEmpty) {
      name = 'ShapeRush';
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.cardMuted,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
