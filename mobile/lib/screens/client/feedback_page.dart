import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int selectedRating = 0;
  bool permissionToPublish = false;
  bool isSubmitting = false;

  final TextEditingController feedbackController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> submitFeedback() async {
    final feedbackText = feedbackController.text.trim();

    if (selectedRating == 0) {
      _showMessage("Please select a rating.", isError: true);
      return;
    }

    if (feedbackText.isEmpty) {
      _showMessage("Please enter your feedback.", isError: true);
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      await supabase.from('app_feedback').insert({
        'profile_id': userId,
        'rating': selectedRating,
        'feedback_text': feedbackText,
        'permission_to_publish': permissionToPublish,
        'media_url': null,
        'status': 'submitted',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        selectedRating = 0;
        permissionToPublish = false;
        feedbackController.clear();
      });

      _showMessage("Feedback submitted successfully.");

      Navigator.pop(context);
    } catch (error) {
      _showMessage("Failed to submit feedback: $error", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleBackButton(
                    onPressed: isSubmitting
                        ? () {}
                        : () {
                            Navigator.pop(context);
                          },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Feedback",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),

              const SizedBox(height: 24),

              _FeedbackSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "1. Overall Rating *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "How would you rate ShapeRush?",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) {
                          final rating = index + 1;

                          return IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      selectedRating = rating;
                                    });
                                  },
                            icon: Icon(
                              rating <= selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 30,
                              color: rating <= selectedRating
                                  ? Colors.amber
                                  : AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Poor",
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          "Excellent",
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _FeedbackSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "2. Tell us about your experience *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "What changed after using ShapeRush?",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      enabled: !isSubmitting,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            "Share your experience, results, and what you like about ShapeRush...",
                        hintStyle: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _FeedbackSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "3. Permission to publish",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Help and inspire others by allowing us to share your review.",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: permissionToPublish,
                      activeColor: AppColors.primary,
                      title: const Text(
                        "I agree to publish my feedback as a public testimonial.",
                        style: TextStyle(fontSize: 10),
                      ),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                permissionToPublish = value ?? false;
                              });
                            },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Submit Form",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final Widget child;

  const _FeedbackSection({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CircleBackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FC),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}