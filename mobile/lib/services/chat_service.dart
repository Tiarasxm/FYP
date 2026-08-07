import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomModel {
  final String id;
  final String clientId;
  final String professionalId;
  final String status;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String otherUserName;
  final String otherUserType;
  final String? otherUserAvatarUrl;

  ChatRoomModel({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.status,
    this.lastMessageContent,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUserName = 'Unknown',
    this.otherUserType = 'Free',
    this.otherUserAvatarUrl,
  });
}

class ChatMessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String? content;
  final String messageType;
  final String? planId;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.messageType = 'text',
    this.planId,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'],
      roomId: map['room_id'],
      senderId: map['sender_id'],
      content: map['content'],
      messageType: map['message_type'] ?? 'text',
      planId: map['plan_id'],
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ChatService {
  final SupabaseClient _client;

  ChatService() : _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Create or get existing chat room between client and professional
  Future<String> getOrCreateRoom(String professionalId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');

    // Use the create_chat_room RPC function (handles RLS + checks)
    final roomId = await _client.rpc('create_chat_room', params: {
      'p_client_id': userId,
      'p_professional_id': professionalId,
    });

    return roomId as String;
  }

  /// Get all chat rooms for the current user
  Future<List<ChatRoomModel>> getChatRooms() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final data = await _client
        .from('chat_rooms')
        .select('id, client_id, professional_id, status, last_message_at')
        .or('client_id.eq.$userId,professional_id.eq.$userId')
        .order('last_message_at', ascending: false, nullsFirst: false);

    final rooms = <ChatRoomModel>[];

    for (final row in (data as List)) {
      final roomId = row['id'];
      final clientId = row['client_id'];
      final professionalId = row['professional_id'];
      final isClient = clientId == userId;
      final otherUserId = isClient ? professionalId : clientId;

      // Get the other user's name
      String otherName = 'Unknown';
      String otherType = 'Free';
      String? otherAvatarUrl;

      final profile = await _client
          .from('profiles')
          .select('full_name, user_type, avatar_url')
          .eq('id', otherUserId)
          .maybeSingle();

      if (profile != null) {
        otherName = profile['full_name']?.toString() ?? 'Unknown';
        otherType = profile['user_type']?.toString() ?? 'Free';
        final url = profile['avatar_url']?.toString().trim();
        otherAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
      }

      // If the other user is a professional, try display_name
      if (!isClient) {
        final fp = await _client
            .from('fitness_professional')
            .select('display_name')
            .eq('profile_id', otherUserId)
            .maybeSingle();
        if (fp != null && fp['display_name'] != null) {
          otherName = fp['display_name'];
        }
      }

      // Get last message content
      String? lastContent;
      final lastMsg = await _client
          .from('chat_messages')
          .select('content, message_type')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMsg != null) {
        lastContent = lastMsg['message_type'] == 'plan'
            ? '📋 Sent a plan'
            : lastMsg['content'];
      }

      // Get unread count
      final unreadData = await _client
          .from('chat_messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      rooms.add(ChatRoomModel(
        id: roomId,
        clientId: clientId,
        professionalId: professionalId,
        status: row['status'] ?? 'active',
        lastMessageContent: lastContent,
        lastMessageAt: row['last_message_at'] != null
            ? DateTime.tryParse(row['last_message_at'])
            : null,
        unreadCount: (unreadData as List).length,
        otherUserName: otherName,
        otherUserType: otherType,
        otherUserAvatarUrl: otherAvatarUrl,
      ));
    }

    return rooms;
  }

  /// Get messages for a room
  Future<List<ChatMessageModel>> getMessages(String roomId) async {
    final data = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((m) => ChatMessageModel.fromMap(m))
        .toList();
  }

  /// Send a text message
  Future<void> sendMessage(String roomId, String content) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');

    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'content': content,
      'message_type': 'text',
    });
  }

  /// Send a plan message (stores plan details in content as JSON)
  Future<void> sendPlanMessage(String roomId, {
    required String planId,
    required String title,
    required int days,
    required String duration,
    required List<String> tags,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');

    // Store plan info as JSON in content to avoid FK constraint issues
    final planJson = '{"plan_id":"$planId","title":"$title","days":$days,"duration":"$duration","tags":${tags.map((t) => '"$t"').toList()}}';

    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'content': planJson,
      'message_type': 'plan',
    });
  }

  /// Mark messages as read
  Future<void> markAsRead(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client
        .from('chat_messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  /// Subscribe to new messages in a room (real-time)
  RealtimeChannel subscribeToRoom(
    String roomId,
    void Function(ChatMessageModel message) onMessage,
  ) {
    return _client
        .channel('chat_room_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            try {
              final msg = ChatMessageModel.fromMap(payload.newRecord);
              onMessage(msg);
            } catch (e) {
              debugPrint('Error parsing realtime message: $e');
            }
          },
        )
        .subscribe();
  }

  /// Subscribe to chat room changes (for chat list updates)
  RealtimeChannel subscribeToChatRooms(
    void Function() onUpdate,
  ) {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not signed in');

    return _client
        .channel('chat_rooms_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_rooms',
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  /// Unsubscribe from a channel
  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
