import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingAvatar = false;

  String avatarUrl = '';
  Uint8List? selectedAvatarBytes;

  final ImagePicker picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController specializationOneController =
      TextEditingController();
  final TextEditingController specializationTwoController =
      TextEditingController();
  final TextEditingController specializationThreeController =
      TextEditingController();

  String avatarLetter = 'P';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    bioController.dispose();
    experienceController.dispose();
    specializationOneController.dispose();
    specializationTwoController.dispose();
    specializationThreeController.dispose();
    super.dispose();
  }

  String getFirstLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

  List<String> splitSpecializations(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String joinSpecializations() {
    final values = [
      specializationOneController.text.trim(),
      specializationTwoController.text.trim(),
      specializationThreeController.text.trim(),
    ].where((item) => item.isNotEmpty).toList();

    return values.join(', ');
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        showMessage('You must be signed in.');
        return;
      }

      final profileRow = await client
          .from('profiles')
          .select('full_name, email, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final professionalRow = await client
          .from('fitness_professional')
          .select('display_name, bio, experience, specializations')
          .eq('profile_id', userId)
          .maybeSingle();

      final displayName =
          professionalRow?['display_name']?.toString().trim() ?? '';

      final fullName = profileRow?['full_name']?.toString().trim() ?? '';

      final name = displayName.isNotEmpty
          ? displayName
          : fullName.isNotEmpty
              ? fullName
              : '';

      final email = profileRow?['email']?.toString() ??
          client.auth.currentUser?.email ??
          '';

      final bio = professionalRow?['bio']?.toString() ?? '';
      final experience = professionalRow?['experience']?.toString() ?? '';

      final specializationsText =
          professionalRow?['specializations']?.toString() ?? '';

      final specializations = splitSpecializations(specializationsText);

      nameController.text = name;
      emailController.text = email;
      bioController.text = bio;
      experienceController.text = experience;

      specializationOneController.text =
          specializations.isNotEmpty ? specializations[0] : '';
      specializationTwoController.text =
          specializations.length > 1 ? specializations[1] : '';
      specializationThreeController.text =
          specializations.length > 2 ? specializations[2] : '';

      setState(() {
        avatarLetter = getFirstLetter(name);
        avatarUrl = profileRow?['avatar_url']?.toString() ?? '';
      });
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to load profile: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  Future<String> _uploadAvatar({
    required String userId,
    required XFile image,
    required Uint8List bytes,
  }) async {
    final extension = _safeImageExtension(image);
    final contentType = _contentTypeForExtension(extension);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$userId/avatar_$timestamp.$extension';

    await Supabase.instance.client.storage.from('profile-avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return Supabase.instance.client.storage
        .from('profile-avatars')
        .getPublicUrl(filePath);
  }

  Future<void> _pickAndUploadAvatar() async {
    if (isUploadingAvatar) return;

    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedAvatarBytes = bytes;
        isUploadingAvatar = true;
      });

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final uploadedUrl = await _uploadAvatar(
        userId: userId,
        image: image,
        bytes: bytes,
      );

      await client.from('profiles').update({
        'avatar_url': uploadedUrl,
      }).eq('id', userId);

      if (!mounted) return;

      setState(() {
        avatarUrl = uploadedUrl;
        selectedAvatarBytes = null;
      });

      showMessage('Avatar updated successfully.');
    } catch (e) {
      showMessage('Failed to upload avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          isUploadingAvatar = false;
        });
      }
    }
  }

  ImageProvider? get _avatarImageProvider {
    if (selectedAvatarBytes != null) {
      return MemoryImage(selectedAvatarBytes!);
    }

    if (avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }

    return null;
  }

  Future<void> updateProfile() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      showMessage('You must be signed in.');
      return;
    }

    final name = nameController.text.trim();

    if (name.isEmpty) {
      showMessage('Please enter your name.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await client.from('profiles').update({
        'full_name': name,
      }).eq('id', userId);

      await client.from('fitness_professional').upsert({
        'profile_id': userId,
        'display_name': name,
        'bio': bioController.text.trim(),
        'experience': experienceController.text.trim(),
        'specializations': joinSpecializations(),
      });

      if (!mounted) return;

      setState(() {
        avatarLetter = getFirstLetter(name);
      });

      showMessage('Profile updated successfully.');
    } catch (error) {
      if (!mounted) return;
      showMessage('Failed to update profile: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BackButton(
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'My Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),

                    const SizedBox(height: 36),

                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.black,
                          backgroundImage: _avatarImageProvider,
                          child: _avatarImageProvider == null
                              ? Text(
                                  avatarLetter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                        GestureDetector(
                          onTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                            child: isUploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _InputField(
                              label: 'Name',
                              controller: nameController,
                            ),

                            const SizedBox(height: 22),

                            _InputField(
                              label: 'Email',
                              controller: emailController,
                              enabled: false,
                            ),

                            const SizedBox(height: 22),

                            _InputField(
                              label: 'Professional Bio',
                              controller: bioController,
                              maxLines: 4,
                            ),

                            const SizedBox(height: 22),

                            _InputField(
                              label: 'Years Experience',
                              controller: experienceController,
                            ),

                            const SizedBox(height: 22),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: RichText(
                                text: TextSpan(
                                  text: 'Specializations ',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '(max 3)',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            _NumberedInputField(
                              number: '1',
                              controller: specializationOneController,
                            ),

                            const SizedBox(height: 10),

                            _NumberedInputField(
                              number: '2',
                              controller: specializationTwoController,
                            ),

                            const SizedBox(height: 10),

                            _NumberedInputField(
                              number: '3',
                              controller: specializationThreeController,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Update Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
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

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? const Color(0xFFF3F2FA)
                : const Color(0xFFEDEDED),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _NumberedInputField extends StatelessWidget {
  final String number;
  final TextEditingController controller;

  const _NumberedInputField({
    required this.number,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            number,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F2FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F2FA),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.black54,
        ),
      ),
    );
  }
}