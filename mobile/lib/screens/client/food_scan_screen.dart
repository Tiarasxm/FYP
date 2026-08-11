import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'food_scan_result_screen.dart';
import '../../theme/app_theme.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isPickingImage = false;

  Future<void> _pickFoodImage(ImageSource source) async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (image == null) return;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FoodScanResultScreen(imageFile: image),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isPickingImage
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: const CircleBorder(),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'AI Food Scan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _isPickingImage
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 46,
                              color: Colors.white24,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Take or upload a food photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: _isPickingImage
                        ? null
                        : () => _pickFoodImage(ImageSource.gallery),
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isPickingImage
                        ? null
                        : () => _pickFoodImage(ImageSource.camera),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isPickingImage ? Colors.white30 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
