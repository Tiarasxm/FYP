import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker picker = ImagePicker();

  XFile? selectedImage;
  Uint8List? selectedImageBytes;

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

  String _safeImageExtension(XFile image) {
    final name = image.name.toLowerCase();
    final path = image.path.toLowerCase();

    String extension = 'jpg';

    if (name.contains('.')) {
      extension = name.split('.').last;
    } else if (path.contains('.')) {
      extension = path.split('.').last;
    }

    if (extension == 'jpeg') return 'jpg';
    if (extension == 'jpg') return 'jpg';
    if (extension == 'png') return 'png';
    if (extension == 'webp') return 'webp';
    if (extension == 'gif') return 'gif';

    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'gif') return 'image/gif';

    return 'image/jpeg';
  }

  Future<void> _pickImage() async {
    if (isSubmitting) return;

    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        selectedImageBytes = bytes;
      });
    } catch (error) {
      _showMessage('Failed to select image: $error', isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
    });
  }

  Future<String?> _uploadFeedbackImage({
    required String userId,
    required XFile image,
    required Uint8List bytes,
  }) async {
    final extension = _safeImageExtension(image);
    final contentType = _contentTypeForExtension(extension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$userId/feedback_$timestamp.$extension';

    await supabase.storage.from('feedback-media').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return supabase.storage.from('feedback-media').getPublicUrl(filePath);
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

      String? mediaUrl;

      if (selectedImage != null && selectedImageBytes != null) {
        mediaUrl = await _uploadFeedbackImage(
          userId: userId,
          image: selectedImage!,
          bytes: selectedImageBytes!,
        );
      }

      await supabase.from('app_feedback').insert({
        'profile_id': userId,
        'rating': selectedRating,
        'feedback_text': feedbackText,
        'permission_to_publish': permissionToPublish,
        'media_url': mediaUrl,
        'status': 'submitted',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        selectedRating = 0;
        permissionToPublish = false;
        selectedImage = null;
        selectedImageBytes = null;
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
                      "3. Add Media",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "(optional)",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _mediaPicker(),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _FeedbackSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "4. Permission to publish",
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

  Widget _mediaPicker() {
    if (selectedImageBytes != null) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              selectedImageBytes!,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: InkWell(
              onTap: isSubmitting ? null : _removeImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isSubmitting ? null : _pickImage,
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 8),
            Text(
              "Choose an image to upload",
              style: TextStyle(fontSize: 10),
            ),
          ],
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