import 'package:flutter/material.dart';

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
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Social',
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
}
