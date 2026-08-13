import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/professional.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  List<ChatRoomModel> _rooms = [];
  bool _loading = true;

  final Map<String, String?> _avatarUrlsByProfileId = {};
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    if (_messagesChannel != null) {
      Supabase.instance.client.removeChannel(_messagesChannel!);
    }
    super.dispose();
  }

  void _subscribeToNewMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('chat_messages_client_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            _loadRooms();
          },
        )
        .subscribe();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _chatService.getChatRooms();
      await _loadAvatarUrlsForRooms(rooms);

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');

      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadAvatarUrlsForRooms(List<ChatRoomModel> rooms) async {
    final ids = rooms
        .map(_avatarProfileIdForRoom)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, avatar_url')
          .inFilter('id', ids);

      final rows = List<Map<String, dynamic>>.from(response as List);

      _avatarUrlsByProfileId.clear();

      for (final row in rows) {
        final id = row['id']?.toString();
        final avatarUrl = row['avatar_url']?.toString().trim();

        if (id == null || id.isEmpty) continue;

        _avatarUrlsByProfileId[id] =
            avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null;
      }
    } catch (e) {
      debugPrint('Error loading chat avatars: $e');
    }
  }

  String? _avatarProfileIdForRoom(ChatRoomModel room) {
    final isClient = room.clientId == _chatService.currentUserId;

    // Client side should show the fitness professional avatar.
    // Professional side will show the client avatar.
    return isClient ? room.professionalId : room.clientId;
  }

  String? _avatarUrlForRoom(ChatRoomModel room) {
    final id = _avatarProfileIdForRoom(room);
    if (id == null || id.isEmpty) return null;

    return _avatarUrlsByProfileId[id];
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) return DateFormat('h:mm a').format(dt.toLocal());
    if (diff.inDays == 1) return 'Yesterday';

    return DateFormat('MMM d').format(dt.toLocal());
  }

  Widget _avatar(String? avatarUrl, {double radius = 22}) {
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : const Icon(
              Icons.person,
              color: AppColors.primary,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'Chat',
      children: [
        TextField(
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search chats',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textMuted),
            suffixIcon:
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.cardMuted,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_rooms.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No chats yet',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (final room in _rooms) ...[
            _chatRow(
              context,
              room: room,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _chatRow(BuildContext context, {required ChatRoomModel room}) {
    final isClient = room.clientId == _chatService.currentUserId;
    final avatarUrl = _avatarUrlForRoom(room);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: _avatar(avatarUrl),
        title: Text(
          room.otherUserName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          room.lastMessageContent ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(room.lastMessageAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            if (room.unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${room.unreadCount}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          final professional = Professional(
            profileId: isClient ? room.professionalId : room.clientId,
            name: room.otherUserName,
            specialties: '',
            rating: 0,
            reviewCount: 0,
            avatarUrl: avatarUrl,
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(professional: professional),
            ),
          );
        },
      ),
    );
  }
}
