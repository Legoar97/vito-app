import 'package:flutter/material.dart';
import 'modern_habits_screen.dart';
import 'stats_screen.dart';
import 'mood_tracker_screen.dart'; // Agregar import
import 'ai_coach_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });
  
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }
  
  final List<Widget> _screens = [
    const ModernHabitsScreen(),
    const MoodTrackerScreen(),
    const AICoachScreen(),
    const StatsScreen(),
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
                icon: Icon(Icons.spa_outlined),
                activeIcon: Icon(Icons.spa_rounded, size: 28),
                label: 'Hábitos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book_rounded),
                activeIcon: Icon(Icons.book_rounded, size: 28),
                label: 'Ánimo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome_rounded, size: 28),
                label: 'Coach IA',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights_rounded, size: 28),
                label: 'Estadísticas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded, size: 28),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}