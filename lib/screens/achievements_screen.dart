import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import 'profile_screen.dart'; // Importamos el modelo Achievement

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, List<Achievement>> _achievementsByCategory = {};
  bool _isLoading = true;

  // La lista maestra de logros ahora vive aquí o en un archivo compartido.
  final List<Achievement> _masterAchievements = [
    Achievement(category: 'Progreso General', icon: Icons.flag, title: 'El Comienzo', subtitle: 'Completa 1 hábito', unlockGoal: 1, color: AppColors.primary),
    Achievement(category: 'Progreso General', icon: Icons.whatshot, title: 'En Fuego', subtitle: 'Completa 10 hábitos', unlockGoal: 10, color: Colors.orange),
    Achievement(category: 'Progreso General', icon: Icons.auto_awesome, title: 'Estrella Naciente', subtitle: 'Completa 25 hábitos', unlockGoal: 25, color: Colors.amber),
    Achievement(category: 'Progreso General', icon: Icons.shield, title: 'Persistente', subtitle: 'Completa 50 hábitos', unlockGoal: 50, color: AppColors.success),
    Achievement(category: 'Progreso General', icon: Icons.military_tech, title: 'Veterano', subtitle: 'Completa 100 hábitos', unlockGoal: 100, color: Colors.blueGrey),
    Achievement(category: 'Maestría Matutina', icon: Icons.wb_sunny, title: 'Madrugador', subtitle: 'Completa 5 hábitos matutinos', unlockGoal: 5, color: Colors.yellow.shade700),
    Achievement(category: 'Maestría Matutina', icon: Icons.light_mode, title: 'Amo del Amanecer', subtitle: 'Completa 20 hábitos matutinos', unlockGoal: 20, color: Colors.orangeAccent),
    Achievement(category: 'Dominio de Salud', icon: Icons.fitness_center, title: 'Atleta en Ascenso', subtitle: 'Completa 10 hábitos de salud', unlockGoal: 10, color: Colors.green),
    Achievement(category: 'Dominio de Mente', icon: Icons.psychology, title: 'Mente Clara', subtitle: 'Completa 10 hábitos mentales', unlockGoal: 10, color: Colors.blue),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAchievements();
  }

  Future<void> _loadUserAchievements() async {
    if (user == null) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final habitsSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').get();
      final habitsData = habitsSnapshot.docs.map((doc) => doc.data()).toList();
      
      int totalCompletions = habitsData.fold(0, (sum, habit) => sum + (habit['completions'] as List? ?? []).length);
      int morningCompletions = _countCompletionsBefore(habitsData, 8);
      int healthCompletions = _countCompletionsByCategory(habitsData, 'Salud');
      int mindCompletions = _countCompletionsByCategory(habitsData, 'Mente');

      Map<String, List<Achievement>> groupedAchievements = {};
      for (var achievement in _masterAchievements) {
        bool unlocked = false;
        switch (achievement.category) {
          case 'Progreso General': unlocked = totalCompletions >= achievement.unlockGoal; break;
          case 'Maestría Matutina': unlocked = morningCompletions >= achievement.unlockGoal; break;
          case 'Dominio de Salud': unlocked = healthCompletions >= achievement.unlockGoal; break;
          case 'Dominio de Mente': unlocked = mindCompletions >= achievement.unlockGoal; break;
        }
        achievement.isUnlocked = unlocked;
        (groupedAchievements[achievement.category] ??= []).add(achievement);
      }
      
      if (mounted) setState(() {
        _achievementsByCategory = groupedAchievements;
        _isLoading = false;
      });

    } catch (e) {
      print("Error al cargar logros: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  int _countCompletionsBefore(List<Map<String, dynamic>> habits, int hour) {
    int count = 0;
    for (var habit in habits) {
      final completions = habit['completions'] as List? ?? [];
      for (var timestamp in completions) {
        if ((timestamp as Timestamp).toDate().hour < hour) count++;
      }
    }
    return count;
  }

  int _countCompletionsByCategory(List<Map<String, dynamic>> habits, String category) {
    int count = 0;
    for (var habit in habits) {
      if (habit['category'] == category) {
        count += (habit['completions'] as List? ?? []).length;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todos los Logros', style: GoogleFonts.poppins()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserAchievements,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _achievementsByCategory.length,
                itemBuilder: (context, index) {
                  final category = _achievementsByCategory.keys.elementAt(index);
                  final achievements = _achievementsByCategory[category]!;
                  return _buildAchievementCategory(category, achievements);
                },
              ),
            ),
    );
  }

  Widget _buildAchievementCategory(String title, List<Achievement> achievements) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return GestureDetector(
                onTap: achievement.isUnlocked ? () => _shareAchievement(achievement) : null,
                child: Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: achievement.isUnlocked ? Theme.of(context).cardColor : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                     borderRadius: BorderRadius.circular(20),
                     boxShadow: achievement.isUnlocked ? [BoxShadow(color: achievement.color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))] : [],
                   ),
                   child: Opacity(
                     opacity: achievement.isUnlocked ? 1.0 : 0.5,
                     child: Stack(
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Icon(achievement.icon, color: achievement.color, size: 32),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(achievement.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                 Text(achievement.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                               ],
                             ),
                           ],
                         ),
                         if(achievement.isUnlocked)
                           const Positioned(top: 0, right: 0, child: Icon(Icons.share, size: 18, color: Colors.grey)),
                       ],
                     ),
                   ),
                 ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _shareAchievement(Achievement achievement) {
    Share.share('¡He desbloqueado el logro "${achievement.title}" en Vito App! 🏆 #VitoApp #LogroDesbloqueado');
  }
}
