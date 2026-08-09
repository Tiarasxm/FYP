import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/chat_service.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import 'chat.dart';
import '../../theme/app_theme.dart';

class ProfessionalMessages extends StatefulWidget {
  const ProfessionalMessages({super.key});

  @override
  State<ProfessionalMessages> createState() => _ProfessionalMessagesState();
}

class _ProfessionalMessagesState extends State<ProfessionalMessages> {
  final ChatService _chatService = ChatService();
  String searchText = '';
  String _selectedFilter = 'All';
  List<ChatRoomModel> _rooms = [];
  Map<String, List<String>> _roomTags = {}; // roomId -> list of tags
  bool _loading = true;

  RealtimeChannel? _profilesChannel;

  final List<String> _filterOptions = ['All', 'New', 'Consult', 'Follow-up', 'Urgent', 'Weight Loss'];

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _subscribeToProfileChanges();
  }

  @override
  void dispose() {
    if (_profilesChannel != null) {
      Supabase.instance.client.removeChannel(_profilesChannel!);
    }
    super.dispose();
  }

  void _subscribeToProfileChanges() {
    _profilesChannel = Supabase.instance.client
        .channel('public:profiles:pro_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final changedId = payload.newRecord['id']?.toString();
            if (changedId == null) return;
            final isRelevant = _rooms.any((room) =>
                room.clientId == changedId || room.professionalId == changedId);
            if (isRelevant) {
              _loadRooms();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _chatService.getChatRooms();
      await _loadTags();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTags() async {
    final myId = _chatService.currentUserId;
    if (myId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('chat_tags')
          .select('room_id, tag')
          .eq('professional_id', myId);

      final map = <String, List<String>>{};
      for (final row in (data as List)) {
        final roomId = row['room_id'] as String;
        final tag = row['tag'] as String;
        map.putIfAbsent(roomId, () => []).add(tag);
      }

      if (mounted) {
        setState(() {
          _roomTags = map;
        });
      }
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  List<ChatRoomModel> get filteredRooms {
    var list = _rooms;

    if (searchText.isNotEmpty) {
      list = list.where((room) {
        return room.otherUserName.toLowerCase().contains(searchText.toLowerCase());
      }).toList();
    }

    if (_selectedFilter != 'All') {
      // Map filter label to tag name stored in DB
      final tagName = _selectedFilter == 'New' ? 'New Client' : _selectedFilter;
      list = list.where((room) {
        final tags = _roomTags[room.id] ?? [];
        return tags.contains(tagName);
      }).toList();
    }

    return list;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt.toLocal());
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 28),

              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search clients',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredRooms.isEmpty
                        ? Center(
                            child: Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRooms.length,
                            itemBuilder: (context, index) {
                              final room = filteredRooms[index];

                              return _ConversationItem(
                                room: room,
                                tags: _roomTags[room.id] ?? [],
                                formattedTime: _formatTime(room.lastMessageAt),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Chat(
                                        roomId: room.id,
                                        otherUserName: room.otherUserName,
                                        otherUserType: room.otherUserType,
                                        clientId: room.clientId,
                                      ),
                                    ),
                                  );
                                  // Reload rooms and tags when returning
                                  _loadRooms();
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final ChatRoomModel room;
  final List<String> tags;
  final String formattedTime;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.room,
    required this.tags,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = room.otherUserName.isNotEmpty
        ? room.otherUserName[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.textPrimary,
                backgroundImage: room.otherUserAvatarUrl != null
                    ? NetworkImage(room.otherUserAvatarUrl!)
                    : null,
                child: room.otherUserAvatarUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            room.otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        for (final tag in tags) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      room.lastMessageContent ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (room.unreadCount > 0)
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '${room.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}