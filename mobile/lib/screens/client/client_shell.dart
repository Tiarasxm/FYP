import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/chat_service.dart';
import '../../services/membership_service.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';
import 'workout_screen.dart';
import 'nutrition_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  late final List<Widget> _screens;

  int _totalUnread = 0;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const WorkoutScreen(),
      const NutritionScreen(),
      const SocialScreen(),
      const ProfileScreen(),
    ];
    MembershipService.ensureCurrentPriorityStatus();
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
        .channel('chat_messages_client_nav_badge')
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

  void _selectTab(int index) {
    if (index == _index) return;

    setState(() {
      _index = index;
    });
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
          onTap: _selectTab,
          backgroundColor: AppColors.navBar,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF8A8F98),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          showUnselectedLabels: true,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Workout',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: 'Nutrition',
            ),
            BottomNavigationBarItem(
              icon: _chatNavIcon(),
              activeIcon: _chatNavIcon(active: true),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatNavIcon({bool active = false}) {
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
