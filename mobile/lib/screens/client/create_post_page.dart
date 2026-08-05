import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with WidgetsBindingObserver {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  CameraController? _cameraController;
  XFile? _selectedImage;
  bool _isCameraLoading = true;
  bool _isTakingPhoto = false;
  bool _isPublishing = false;
  String? _cameraError;

  bool get _isComposeStep => _selectedImage != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed && !_isComposeStep) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isCameraLoading = true;
        _cameraError = null;
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', 'No camera found.');

      final backCamera = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final controller = CameraController(
        backCamera.isNotEmpty ? backCamera.first : cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _isCameraLoading = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _cameraError = error.code == 'CameraAccessDenied'
            ? 'Camera permission is required.'
            : 'Camera is unavailable.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _cameraError = 'Camera is unavailable.';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isTakingPhoto) {
      return;
    }

    setState(() => _isTakingPhoto = true);
    try {
      final image = await controller.takePicture();
      if (mounted) setState(() => _selectedImage = image);
    } on CameraException {
      if (mounted) _showMessage('Failed to take photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() => _selectedImage = image);
  }

  Future<void> _returnToCamera() async {
    setState(() {
      _selectedImage = null;
      _contentController.clear();
    });
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initializeCamera();
    }
  }

  Future<String> _uploadImage(String userId) async {
    final image = _selectedImage!;
    final extension = image.path.split('.').last.toLowerCase();
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage.from('post-images');
    await storage.upload(
      path,
      File(image.path),
      fileOptions: const FileOptions(upsert: false),
    );
    return storage.getPublicUrl(path);
  }

  Future<void> _publishPost() async {
    if (_selectedImage == null) {
      _showMessage('Please take or select a photo.');
      return;
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      _showMessage('You must be signed in to create a post.');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final imageUrl = await _uploadImage(userId);
      await client.from('posts').insert({
        'user_id': userId,
        'content': _contentController.text.trim(),
        'image_url': imageUrl,
        'visibility': 'public',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage('Failed to publish post: $error');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isComposeStep ? _buildComposePage() : _buildCameraPage();
  }

  Widget _buildCameraPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Create Post',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCameraPreview()),
            SizedBox(
              width: double.infinity,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 24,
                    child: IconButton.filled(
                      onPressed: _pickFromGallery,
                      style: IconButton.styleFrom(backgroundColor: Colors.white24),
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 70,
                      height: 70,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8E8E8),
                          shape: BoxShape.circle,
                        ),
                        child: _isTakingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isCameraLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 42),
              const SizedBox(height: 12),
              Text(_cameraError!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _initializeCamera, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFF303030),
      child: Center(child: CameraPreview(_cameraController!)),
    );
  }

  Widget _buildComposePage() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: _isPublishing ? null : _returnToCamera,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 30),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_selectedImage!.path),
                        width: double.infinity,
                        height: MediaQuery.sizeOf(context).height * 0.43,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 1000,
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      decoration: const InputDecoration(
                        hintText: 'Write caption with details',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isPublishing ? null : _publishPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPublishing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Post',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
