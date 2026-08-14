import 'package:camera/camera.dart';
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

  CameraController? _cameraController;

  bool _isCameraReady = false;
  bool _isBusy = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera found on this device.';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isCameraReady = true;
        _cameraError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _cameraError = 'Failed to open camera: $error';
      });
    }
  }

  Future<void> _takePhoto() async {
    final controller = _cameraController;

    if (_isBusy) return;

    if (controller == null ||
        !_isCameraReady ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      _showMessage('Camera is not ready.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final XFile image = await controller.takePicture();

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodScanResultScreen(imageFile: image),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to take photo: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (image == null) return;

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodScanResultScreen(imageFile: image),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to pick image: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: _cameraPreviewArea(),
              ),
            ),
            _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _isBusy
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _cameraPreviewArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF1A1A1A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraError != null)
              _cameraErrorView()
            else if (!_isCameraReady || _cameraController == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              _cameraPreviewCover(),
            if (_isBusy)
              Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cameraPreviewCover() {
    final controller = _cameraController!;

    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: 400,
            height: 700,
            child: CameraPreview(controller),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final orientation = MediaQuery.of(context).orientation;

        final previewWidth = orientation == Orientation.portrait
            ? previewSize.height
            : previewSize.width;
        final previewHeight = orientation == Orientation.portrait
            ? previewSize.width
            : previewSize.height;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cameraErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Colors.white30,
            ),
            const SizedBox(height: 14),
            Text(
              _cameraError ?? 'Camera unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: _initializeCamera,
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          const SizedBox(width: 32),
          IconButton(
            onPressed: _isBusy ? null : _pickFromGallery,
            icon: Icon(
              Icons.photo_library_outlined,
              color: _isBusy ? Colors.white24 : AppColors.textMuted,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isBusy ? null : _takePhoto,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
              ),
              child: Container(
                margin: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isBusy ? Colors.white30 : Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}
