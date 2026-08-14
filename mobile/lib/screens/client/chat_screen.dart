import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/professional.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'plan_detail_screen.dart';
import 'report_professional_dialog.dart';
import 'review_dialog.dart';

class ChatScreen extends StatefulWidget {
  final Professional professional;

  const ChatScreen({super.key, required this.professional});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _roomId;
  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  RealtimeChannel? _profileChannel;

  String? _professionalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _professionalAvatarUrl = widget.professional.avatarUrl;
    _initChat();
    _loadProfessionalAvatar();
  }

  Future<void> _loadProfessionalAvatar() async {
    final profId = widget.professional.profileId;

    if (profId == null || profId.isEmpty) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', profId)
          .maybeSingle();

      final avatarUrl = profile?['avatar_url']?.toString().trim();

      if (!mounted) return;

      setState(() {
        _professionalAvatarUrl =
            avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null;
      });

      _subscribeToProfessionalProfile(profId);
    } catch (e) {
      debugPrint('Error loading professional avatar: $e');
    }
  }

  void _subscribeToProfessionalProfile(String profId) {
    if (_profileChannel != null) return;

    _profileChannel = Supabase.instance.client
        .channel('public:profiles:client_chat:$profId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: profId,
          ),
          callback: (payload) {
            final avatarUrl = payload.newRecord['avatar_url']?.toString().trim();

            if (!mounted) return;

            setState(() {
              _professionalAvatarUrl =
                  avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null;
            });
          },
        )
        .subscribe();
  }

  Widget _avatar(String? avatarUrl, {double radius = 14}) {
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : const Icon(
              Icons.person,
              size: 14,
              color: AppColors.primary,
            ),
    );
  }

  Future<void> _initChat() async {
    try {
      final profId = widget.professional.profileId;
      if (profId == null) {
        setState(() => _loading = false);
        return;
      }

      final roomId = await _chatService.getOrCreateRoom(profId);
      final messages = await _chatService.getMessages(roomId);
      await _chatService.markAsRead(roomId);

      if (!mounted) return;

      setState(() {
        _roomId = roomId;
        _messages = messages;
        _loading = false;
      });

      _scrollToBottom();

      // Subscribe to real-time messages
      _channel = _chatService.subscribeToRoom(roomId, (msg) {
        if (!mounted) return;
        setState(() {
          // Avoid duplicates
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        });
        _scrollToBottom();

        // Mark as read if message is from the other person
        if (msg.senderId != _chatService.currentUserId) {
          _chatService.markAsRead(roomId);
        }
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _roomId == null) return;

    _controller.clear();
    try {
      await _chatService.sendMessage(_roomId!, text);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  void dispose() {
    if (_channel != null) _chatService.unsubscribe(_channel!);
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _chatService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderId == myId;

                        if (msg.messageType == 'plan') {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _planBubble(
                              isMe,
                              msg.content,
                              avatarUrl: _professionalAvatarUrl,
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _messageBubble(
                            msg.content ?? '',
                            isMe,
                            avatarUrl: _professionalAvatarUrl,
                          ),
                        );
                      },
                    ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardMuted,
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
          _avatar(_professionalAvatarUrl, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.professional.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              final profId = widget.professional.profileId;
              if (profId == null) return;

              if (value == 'review') {
                final submitted = await showReviewDialog(
                  context: context,
                  professionalId: profId,
                );
                if (submitted && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review submitted. Thank you!')),
                  );
                }
              } else if (value == 'report') {
                final submitted = await showReportProfessionalDialog(
                  context: context,
                  professionalId: profId,
                );
                if (submitted && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. Our team will review it.')),
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'review',
                child: Text('Give a Review', style: TextStyle(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text(
                  'Report Fitness Professional',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String text, bool isMe, {String? avatarUrl}) {
    return Row(
      mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          _avatar(avatarUrl, radius: 14),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : AppColors.cardMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _planBubble(bool isMe, String? content, {String? avatarUrl}) {
    String title = 'Workout Plan';
    String? planId;
    int days = 0;
    
    List<String> tags = [];
    bool isPersonalized = false;

    if (content != null && content.isNotEmpty) {
      try {
        final data = jsonDecode(content) as Map<String, dynamic>;
        planId = data['plan_id'];
        title = data['title'] ?? 'Workout Plan';
        days = data['days'] ?? 0;
        
        tags = (data['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
        isPersonalized = data['is_personalized'] == true;
      } catch (_) {
        title = content;
      }
    }

    return Row(
      mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          _avatar(avatarUrl, radius: 14),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (days > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$days Days',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (planId != null && planId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanDetailScreen(
                              planId: planId!,
                              title: title,
                              isPersonalized: isPersonalized,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'View Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardMuted,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, size: 20, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
