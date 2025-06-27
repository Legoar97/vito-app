import 'package:flutter/material.dart';
import 'modern_habits_screen.dart';
import 'stats_screen.dart';
import 'ai_coach_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const ModernHabitsScreen(),
    const StatsScreen(),
    const AICoachScreen(),
    const ProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).cardColor,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey[400],
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.spa_outlined), // Ícono más zen (hoja/spa)
                activeIcon: Icon(Icons.spa_rounded, size: 30),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_rounded),
                activeIcon: Icon(Icons.insights_rounded, size: 30),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_rounded),
                activeIcon: Icon(Icons.auto_awesome_rounded, size: 30),
                label: 'AI Coach',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded, size: 30),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}