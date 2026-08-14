import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class ReviewsScreen extends StatefulWidget {
  final String professionalId;

  const ReviewsScreen({super.key, required this.professionalId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _isLoading = true;
  double _avgRating = 0;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await Supabase.instance.client
          .from('reviews')
          .select('rating, feedback, submitted_at, profiles!reviews_reviewer_id_fkey(full_name)')
          .eq('professional_id', widget.professionalId)
          .order('submitted_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(data as List);

      double avg = 0;
      if (rows.isNotEmpty) {
        final total = rows.fold<double>(
          0,
          (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0),
        );
        avg = total / rows.length;
      }

      if (!mounted) return;
      setState(() {
        _reviews = rows;
        _avgRating = avg;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Reviews',
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Center(
            child: Column(
              children: [
                Text(
                  _avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                _stars(_avgRating.round()),
                const SizedBox(height: 4),
                Text(
                  'based on ${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            for (final review in _reviews) ...[
              _reviewCard(review),
              const SizedBox(height: 12),
            ],
        ],
      ],
    );
  }

  Widget _stars(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < count ? Icons.star : Icons.star_border,
            size: 20,
            color: AppColors.amber,
          ),
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final profile = review['profiles'] as Map<String, dynamic>?;
    final reviewer = profile?['full_name']?.toString() ?? 'ShapeRush User';
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final feedback = review['feedback']?.toString() ?? '';

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
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.person, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reviewer,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.star, size: 14, color: AppColors.amber),
              const SizedBox(width: 2),
              Text(
                '$rating',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
