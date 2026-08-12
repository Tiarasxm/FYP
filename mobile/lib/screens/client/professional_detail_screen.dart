import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/professional.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/pill_tag.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'chat_screen.dart';
import 'plan_detail_screen.dart';
import 'reviews_screen.dart';

class ProfessionalDetailScreen extends StatefulWidget {
  final Professional professional;

  const ProfessionalDetailScreen({super.key, required this.professional});

  @override
  State<ProfessionalDetailScreen> createState() => _ProfessionalDetailScreenState();
}

class _ProfessionalDetailScreenState extends State<ProfessionalDetailScreen> {
  late Professional professional;
  RealtimeChannel? _reviewsChannel;
  RealtimeChannel? _profileChannel;

  List<Map<String, dynamic>> _plans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    professional = widget.professional;
    _loadRating();
    _loadPlans();
    _subscribeToReviews();
    _subscribeToProfileChanges();
  }

  @override
  void dispose() {
    if (_reviewsChannel != null) {
      Supabase.instance.client.removeChannel(_reviewsChannel!);
    }
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  void _subscribeToProfileChanges() {
    final profId = professional.profileId;
    if (profId == null) return;

    _profileChannel = Supabase.instance.client
        .channel('public:profile_detail:$profId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: profId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final name = record['full_name']?.toString().trim();
            final url = record['avatar_url']?.toString().trim();

            if (!mounted) return;
            setState(() {
              professional = Professional(
                profileId: professional.profileId,
                name: (name != null && name.isNotEmpty) ? name : professional.name,
                specialties: professional.specialties,
                rating: professional.rating,
                reviewCount: professional.reviewCount,
                yearsExp: professional.yearsExp,
                bio: professional.bio,
                avatarUrl: (url != null && url.isNotEmpty) ? url : professional.avatarUrl,
              );
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'fitness_professional',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: profId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final displayName = record['display_name']?.toString().trim();
            final bio = record['bio']?.toString();
            final specializations = record['specializations']?.toString();

            if (!mounted) return;
            setState(() {
              professional = Professional(
                profileId: professional.profileId,
                name: (displayName != null && displayName.isNotEmpty) ? displayName : professional.name,
                specialties: specializations ?? professional.specialties,
                rating: professional.rating,
                reviewCount: professional.reviewCount,
                yearsExp: professional.yearsExp,
                bio: bio ?? professional.bio,
                avatarUrl: professional.avatarUrl,
              );
            });
          },
        )
        .subscribe();
  }

  void _subscribeToReviews() {
    final profId = professional.profileId;
    if (profId == null) return;

    _reviewsChannel = Supabase.instance.client
        .channel('public:reviews:detail:$profId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          callback: (payload) {
            final affectedId = (payload.newRecord['professional_id'] ??
                    payload.oldRecord['professional_id'])
                ?.toString();
            if (affectedId == profId) {
              _loadRating();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRating() async {
    final profId = professional.profileId;
    if (profId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('professional_id', profId);

      final rows = List<Map<String, dynamic>>.from(data as List);
      final reviewCount = rows.length;
      double avgRating = 0;
      if (reviewCount > 0) {
        final total = rows.fold<double>(
            0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0));
        avgRating = total / reviewCount;
      }

      if (!mounted) return;
      setState(() {
        professional = Professional(
          profileId: professional.profileId,
          name: professional.name,
          specialties: professional.specialties,
          rating: avgRating,
          reviewCount: reviewCount,
          yearsExp: professional.yearsExp,
          bio: professional.bio,
          avatarUrl: professional.avatarUrl,
        );
      });
    } catch (e) {
      debugPrint('Error loading professional rating: $e');
    }
  }

  Future<void> _loadPlans() async {
    final profId = professional.profileId;

    if (profId == null) {
      setState(() => _isLoadingPlans = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('free_plans')
          .select(
            'free_plan_id, plan_name, duration_weeks, tag1, tag2, tag3, visibility, status',
          )
          .eq('professional_id', profId)
          .ilike('visibility', 'public')
          .not('status', 'in', ['draft', 'archived'])
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _plans = List<Map<String, dynamic>>.from(data as List);
        _isLoadingPlans = false;
      });
    } catch (e) {
      debugPrint('Error loading professional plans: $e');
      if (!mounted) return;
      setState(() => _isLoadingPlans = false);
    }
  }

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
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: professional.avatarUrl != null &&
                        professional.avatarUrl!.trim().isNotEmpty
                    ? NetworkImage(professional.avatarUrl!)
                    : null,
                child: professional.avatarUrl == null ||
                        professional.avatarUrl!.trim().isEmpty
                    ? const Icon(Icons.person, size: 44, color: AppColors.primary)
                    : null,
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
        _plansSection(),
      ],
    );
  }

  Widget _plansSection() {
    if (_isLoadingPlans) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Text(
        'No public plans available.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _plans.map((plan) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _planCard(plan),
        );
      }).toList(),
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
            final profId = professional.profileId;
            if (profId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReviewsScreen(professionalId: profId),
              ),
            );
          },
          child: _stat('${professional.reviewCount}', 'Reviews'),
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

  Widget _planCard(Map<String, dynamic> plan) {
    final title = plan['plan_name']?.toString() ?? 'Untitled Plan';
    final durationWeeks = (plan['duration_weeks'] as num?)?.toInt() ?? 4;
    final days = durationWeeks * 7;
    final tags = [plan['tag1'], plan['tag2'], plan['tag3']]
        .whereType<String>()
        .where((tag) => tag.trim().isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: () {
        final planId = plan['free_plan_id']?.toString();
        if (planId == null || planId.isEmpty) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlanDetailScreen(
              planId: planId,
              title: title,
            ),
          ),
        );
      },
      child: Container(
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
            Text(
              '$days Days',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => PillTag(tag)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
