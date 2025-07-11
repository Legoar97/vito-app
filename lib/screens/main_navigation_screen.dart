import 'package:flutter/material.dart';
import 'modern_habits_screen.dart';
import 'stats_screen.dart';
import 'mood_tracker_screen.dart';
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
  
  // --- CAMBIO CLAVE 1: Se elimina la lista de pantallas de aquí ---
  // final List<Widget> _screens = [ ... ];
  
  @override
  Widget build(BuildContext context) {

    // --- CAMBIO CLAVE 2: La lista de pantallas ahora se define DENTRO del build ---
    // Esto asegura que cada vez que el widget se reconstruye (por ejemplo, al cambiar de tema),
    // la pantalla activa se vuelve a crear con el contexto y tema actualizados.
    final List<Widget> screens = [
      const ModernHabitsScreen(),
      const MoodTrackerScreen(),
      const AICoachScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
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

            // --- CAMBIO CLAVE 3: Color que se adapta al tema ---
            // En lugar de un color fijo, usamos uno del tema actual.
            unselectedItemColor: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
            
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