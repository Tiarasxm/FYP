import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'home.dart' as professional_home;
import 'messages.dart' as professional_messages;
import 'profile.dart' as professional_profile;

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({super.key});

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  int _index = 0;
  int _totalUnread = 0;
  RealtimeChannel? _messagesChannel;

  static const List<Widget> _screens = [
    professional_home.ProfessionalHome(),
    professional_messages.ProfessionalMessages(),
    professional_profile.ProfessionalProfile(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final chatService = ChatService();
      final rooms = await chatService.getChatRooms();

      if (!mounted) return;

      final total = rooms.fold<int>(0, (sum, room) => sum + room.unreadCount);

      setState(() {
        _totalUnread = total;
      });
    } catch (_) {}
  }

  void _subscribeToNewMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('chat_messages_pro_nav_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) {
            _loadUnreadCount();
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBar,
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) {
            setState(() {
              _index = index;
            });
          },
          backgroundColor: AppColors.navBar,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF8A8F98),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          showUnselectedLabels: true,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Plans',
            ),
            BottomNavigationBarItem(
              icon: _messagesNavIcon(),
              activeIcon: _messagesNavIcon(active: true),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesNavIcon({bool active = false}) {
    if (_totalUnread <= 0) {
      return Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}