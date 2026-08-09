import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  final String dayLabel;
  final int durationSeconds;
  final double totalVolumeKg;
  final int totalSets;

  const WorkoutCompleteScreen({
    super.key,
    required this.dayLabel,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.totalSets,
  });

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String get _durationText {
    final minutes = widget.durationSeconds ~/ 60;
    final seconds = widget.durationSeconds % 60;

    if (minutes <= 0) {
      return '${seconds}s';
    }

    return '${minutes}m ${seconds}s';
  }

  String get _volumeText {
    if (widget.totalVolumeKg % 1 == 0) {
      return '${widget.totalVolumeKg.toInt()} KG';
    }

    return '${widget.totalVolumeKg.toStringAsFixed(1)} KG';
  }

  String get _shareCaption {
    return 'Just finished "${widget.dayLabel}" on ShapeRush \u2014 '
        '$_durationText, $_volumeText volume, ${widget.totalSets} sets completed! \ud83d\udcaa';
  }

  Future<Uint8List?> _captureCard() {
    return _screenshotController.capture(pixelRatio: 2.5);
  }

  Future<void> _handleShare(String label) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final bytes = await _captureCard();

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare the image to share.')),
        );
        return;
      }

      final file = XFile.fromData(
        bytes,
        name: 'shaperush_workout.png',
        mimeType: 'image/png',
      );

      if (label == 'Download') {
        await Share.shareXFiles(
          [file],
          fileNameOverrides: const ['shaperush_workout.png'],
        );
      } else {
        await Share.shareXFiles(
          [file],
          text: _shareCaption,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Great workout!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                widget.dayLabel,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _summaryCard()),
              const SizedBox(height: 20),
              const Text(
                'Share workout',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _shareRow(),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Screenshot(
      controller: _screenshotController,
      child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Spacer(),
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'WORKOUT COMPLETED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.dayLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat(_durationText, 'DURATION'),
              _divider(),
              _stat(_volumeText, 'VOLUME'),
              _divider(),
              _stat('${widget.totalSets}', 'SETS'),
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.navBar,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'ShapeRush',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                Text(
                  'Workout Completed',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 28, color: AppColors.border);
  }

  Widget _shareRow() {
    const items = [
      (Icons.alternate_email, 'Twitter / X'),
      (Icons.camera_alt_outlined, 'Instagram'),
      (Icons.facebook, 'Facebook'),
      (Icons.download_outlined, 'Download'),
    ];

    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () => _handleShare(item.$2),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _isSharing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(item.$1, size: 20, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}