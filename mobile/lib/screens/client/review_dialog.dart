import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

Future<bool> showReviewDialog({
  required BuildContext context,
  required String professionalId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ReviewDialog(professionalId: professionalId),
  );
  return result == true;
}

class _ReviewDialog extends StatefulWidget {
  final String professionalId;

  const _ReviewDialog({required this.professionalId});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  Future<void> _loadExistingReview() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('reviews')
          .select('rating, feedback')
          .eq('reviewer_id', myId)
          .eq('professional_id', widget.professionalId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _rating = (data['rating'] as num?)?.toInt() ?? 0;
          _feedbackController.text = data['feedback']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading existing review: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null || _rating == 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('reviews').upsert(
        {
          'reviewer_id': myId,
          'professional_id': widget.professionalId,
          'rating': _rating,
          'feedback': _feedbackController.text.trim(),
        },
        onConflict: 'reviewer_id,professional_id',
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Give a Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Overall Rating',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How would you rate this fitness professional?',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            return GestureDetector(
                              onTap: () => setState(() => _rating = star),
                              child: Icon(
                                star <= _rating ? Icons.star : Icons.star_border,
                                size: 32,
                                color: star <= _rating
                                    ? AppColors.amber
                                    : AppColors.textMuted,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Poor',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                            if (_rating > 0)
                              Text(
                                _ratingLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            Text(
                              'Excellent',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Tell us about your experience',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What changed after using ShapeRush?',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _feedbackController,
                          enabled: !_isSubmitting,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Share your experience, results, and what you love about ShapeRush...',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.card,
                            counterText: '',
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _rating == 0 || _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Review',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
