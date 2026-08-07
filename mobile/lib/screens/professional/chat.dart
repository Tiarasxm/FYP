import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../services/chat_service.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'plan_detail.dart';
import 'send_plan.dart';

class Chat extends StatefulWidget {
  final String roomId;
  final String otherUserName;
  final String otherUserType;
  final String? clientId;

  const Chat({
    super.key,
    required this.roomId,
    required this.otherUserName,
    this.otherUserType = 'Free',
    this.clientId,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final ChatService _chatService = ChatService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.roomId);
      await _chatService.markAsRead(widget.roomId);

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });

      _scrollToBottom();

      _channel = _chatService.subscribeToRoom(widget.roomId, (msg) {
        if (!mounted) return;
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
        if (msg.senderId != _chatService.currentUserId) {
          _chatService.markAsRead(widget.roomId);
        }
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
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

  @override
  void dispose() {
    if (_channel != null) _chatService.unsubscribe(_channel!);
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> sendTextMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    messageController.clear();
    try {
      await _chatService.sendMessage(widget.roomId, text);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> openSendPlan() async {
    final selectedPlan = await Navigator.push<WorkoutPlan>(
      context,
      MaterialPageRoute(
        builder: (context) => const SendPlan(),
      ),
    );

    if (selectedPlan != null) {
      try {
        await _chatService.sendPlanMessage(
          widget.roomId,
          planId: selectedPlan.freePlanId ?? '',
          title: selectedPlan.title,
          days: selectedPlan.days,
          duration: selectedPlan.duration,
          tags: selectedPlan.tags,
        );
      } catch (e) {
        debugPrint('Error sending plan: $e');
      }
    }
  }

  void _showCustomerProfile() async {
    if (widget.clientId == null) return;

    final client = Supabase.instance.client;
    try {
      final profile = await client
          .from('profiles')
          .select('full_name, gender, user_type, date_of_birth, weight_kg, height_cm, activity_level, fitness_goal')
          .eq('id', widget.clientId!)
          .maybeSingle();

      if (profile == null || !mounted) return;

      final isPriority = (profile['user_type'] ?? '').toString().toLowerCase() == 'priority';
      final fullName = profile['full_name'] ?? 'Unknown';
      final gender = profile['gender'] ?? 'Not specified';

      final dob = profile['date_of_birth'];
      final age = dob != null
          ? DateTime.now().year - DateTime.parse(dob.toString()).year
          : null;
      final weight = profile['weight_kg']?.toString();
      final height = profile['height_cm']?.toString();
      final activityLevel = profile['activity_level']?.toString();
      final fitnessGoal = profile['fitness_goal']?.toString();

      showDialog(
        context: context,
        builder: (ctx) {
          return Center(
            child: Container(
              width: 300,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black,
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECE9FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'PRIORITY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              Text(
                                fullName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Gender: $gender',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, size: 18, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fitness Information',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (age != null)
                            Text('Age: $age', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                          if (age != null) const SizedBox(height: 6),
                          Text('Gender: $gender', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          if (weight != null)
                            Text('Weight: $weight kg', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                          if (weight != null) const SizedBox(height: 6),
                          if (height != null)
                            Text('Height: $height cm', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                          if (height != null) const SizedBox(height: 6),
                          if (activityLevel != null)
                            Text('Activity Level: $activityLevel', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                          if (activityLevel != null) const SizedBox(height: 6),
                          if (fitnessGoal != null)
                            Text('Fitness Goal: $fitnessGoal', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error loading customer profile: $e');
    }
  }

  void _showAssignTagPopup() async {
    final client = Supabase.instance.client;
    final myId = _chatService.currentUserId;
    if (myId == null) return;

    // Fetch existing tags for this room
    List<String> existingTags = [];
    try {
      final data = await client
          .from('chat_tags')
          .select('tag')
          .eq('room_id', widget.roomId)
          .eq('professional_id', myId);
      existingTags = (data as List).map((r) => r['tag'].toString()).toList();
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }

    final List<String> availableTags = [
      'New Client',
      'Urgent',
      'Weight Loss',
      'Consult',
      'Follow-up',
    ];

    final selectedTags = existingTags.toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Assign Tags',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      ...availableTags.map((tag) {
                        final checked = selectedTags.contains(tag);
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                tag,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Checkbox(
                              value: checked,
                              activeColor: const Color(0xFF6C63FF),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedTags.add(tag);
                                  } else {
                                    selectedTags.remove(tag);
                                  }
                                });
                              },
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _saveTags(selectedTags.toList());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveTags(List<String> newTags) async {
    final client = Supabase.instance.client;
    final myId = _chatService.currentUserId;
    if (myId == null) return;

    try {
      // Delete all existing tags for this room by this professional
      await client
          .from('chat_tags')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('professional_id', myId);

      // Insert new tags
      if (newTags.isNotEmpty) {
        final rows = newTags.map((tag) => {
          'room_id': widget.roomId,
          'professional_id': myId,
          'tag': tag,
        }).toList();
        await client.from('chat_tags').insert(rows);
      }
    } catch (e) {
      debugPrint('Error saving tags: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _chatService.currentUserId;
    final initials = widget.otherUserName.isNotEmpty
        ? widget.otherUserName[0].toUpperCase()
        : '?';

    return MobilePageWrapper(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F2FA),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                  Expanded(
                    child: GestureDetector(
                      onTap: _showCustomerProfile,
                      child: Center(
                        child: Text(
                          widget.otherUserName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                  PopupMenuButton<String>(
                    icon: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F2FA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.black,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    offset: const Offset(0, 44),
                    onSelected: (value) {
                      if (value == 'assign_tag') {
                        _showAssignTagPopup();
                      } else if (value == 'report') {
                        // TODO: implement report
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'assign_tag',
                        child: Text('Assign Tag', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == myId;

                        if (message.messageType == 'plan') {
                          return _PlanMessageBubble(
                            isMe: isMe,
                            content: message.content,
                          );
                        }

                        return _TextMessageBubble(
                          text: message.content ?? '',
                          isMe: isMe,
                          avatarText: initials,
                          onAvatarTap: isMe ? null : _showCustomerProfile,
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      onSubmitted: (_) => sendTextMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F2FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: sendTextMessage,
                    icon: const Icon(Icons.send_outlined),
                  ),

                  IconButton(
                    onPressed: openSendPlan,
                    icon: const Icon(Icons.calendar_month),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String avatarText;
  final VoidCallback? onAvatarTap;

  const _TextMessageBubble({
    required this.text,
    required this.isMe,
    required this.avatarText,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(maxWidth: 250),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.black,
            child: Text(
              avatarText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 245),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanMessageBubble extends StatelessWidget {
  final bool isMe;
  final String? content;

  const _PlanMessageBubble({required this.isMe, this.content});

  void _viewPlan(BuildContext context) {
    // Parse plan details from JSON content
    String? planId;
    String title = 'Workout Plan';
    int days = 0;
    String duration = '~45 min';
    List<String> tags = [];

    if (content != null && content!.isNotEmpty) {
      try {
        final data = jsonDecode(content!) as Map<String, dynamic>;
        planId = data['plan_id'];
        title = data['title'] ?? 'Workout Plan';
        days = data['days'] ?? 0;
        duration = data['duration'] ?? '~45 min';
        tags = (data['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
      } catch (_) {}
    }

    final plan = WorkoutPlan(
      freePlanId: planId,
      title: title,
      days: days,
      duration: duration,
      tags: tags,
      workoutDays: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(plan: plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Parse plan details from JSON content
    String title = 'Workout Plan';
    int days = 0;
    String duration = '~45 min';
    List<String> tags = [];

    if (content != null && content!.isNotEmpty) {
      try {
        final data = jsonDecode(content!) as Map<String, dynamic>;
        title = data['title'] ?? 'Workout Plan';
        days = data['days'] ?? 0;
        duration = data['duration'] ?? '~45 min';
        tags = (data['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
      } catch (_) {
        title = content!;
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
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
                '$days Days • $duration',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: () => _viewPlan(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'View Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}