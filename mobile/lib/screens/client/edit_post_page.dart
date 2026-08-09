import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/social_post.dart';
import '../../theme/app_theme.dart';

class EditPostPage extends StatefulWidget {
  final SocialPost post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late final TextEditingController _contentController;
  final _picker = ImagePicker();
  XFile? _newImage;
  late String? _imageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _imageUrl = widget.post.imageUrl;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image != null && mounted) setState(() => _newImage = image);
  }

  Future<String?> _uploadNewImage(String userId) async {
    if (_newImage == null) return _imageUrl;
    final extension = _newImage!.path.split('.').last.toLowerCase();
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage.from('post-images');
    await storage.upload(path, File(_newImage!.path));
    return storage.getPublicUrl(path);
  }

  Future<void> _saveChanges() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageUrl == null && _newImage == null) {
      _showMessage('A post must contain text or a photo.');
      return;
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId != widget.post.userId) {
      _showMessage('You can only edit your own post.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newImageUrl = await _uploadNewImage(userId);
      await client.from('posts').update({
        'content': content,
        'image_url': newImageUrl,
        'visibility': 'public',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.post.id);

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage('Failed to update post: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('posts')
          .delete()
          .eq('id', widget.post.id)
          .eq('user_id', widget.post.userId);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (error) {
      if (mounted) _showMessage('Failed to delete post: $error');
    }
  }

  Widget _photoPreview() {
    final image = _newImage != null
        ? Image.file(File(_newImage!.path), fit: BoxFit.cover)
        : _imageUrl != null
            ? Image.network(_imageUrl!, fit: BoxFit.cover)
            : null;

    if (image == null) {
      return OutlinedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add Photo'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.43,
            width: double.infinity,
            child: image,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _pickImage, child: const Text('Replace')),
            TextButton(
              onPressed: () => setState(() {
                _newImage = null;
                _imageUrl = null;
              }),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Edit Post',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _deletePost,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
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
                    _photoPreview(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 1000,
                      scrollPadding: const EdgeInsets.only(bottom: 100),
                      decoration: const InputDecoration(
                        hintText: 'Write caption with details',
                        hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
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
