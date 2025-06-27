import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';

/// Modelo de datos para un Logro.
/// Incluye el tipo de logro para la lógica de desbloqueo y si es secreto.
class Achievement {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int unlockGoal;
  final String category;
  final String type; // e.g., 'total_completions', 'streak', 'category_completions_health'
  bool isUnlocked;
  final bool isSecret;

  Achievement({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unlockGoal,
    required this.category,
    required this.type,
    this.isUnlocked = false,
    this.isSecret = false,
  });
}

/// Pantalla que muestra todos los logros del usuario, agrupados por categoría.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, List<Achievement>> _achievementsByCategory = {};
  bool _isLoading = true;
  int _previousUnlockedCount = 0;
  
  late ConfettiController _confettiController;

  // Lista maestra de todos los logros disponibles en la app.
  final List<Achievement> _masterAchievements = [
    Achievement(type: 'total_completions', category: 'Progreso General', icon: Icons.flag_outlined, title: 'El Comienzo', subtitle: 'Completa 1 hábito', unlockGoal: 1, color: AppColors.primary),
    Achievement(type: 'total_completions', category: 'Progreso General', icon: Icons.whatshot_outlined, title: 'En Fuego', subtitle: 'Completa 10 hábitos', unlockGoal: 10, color: Colors.orange),
    Achievement(type: 'total_completions', category: 'Progreso General', icon: Icons.auto_awesome_outlined, title: 'Estrella Naciente', subtitle: 'Completa 25 hábitos', unlockGoal: 25, color: Colors.amber),
    Achievement(type: 'category_completions_health', category: 'Dominio de Salud', icon: Icons.fitness_center_outlined, title: 'Atleta en Ascenso', subtitle: 'Completa 10 hábitos de salud', unlockGoal: 10, color: Colors.green),
    Achievement(type: 'category_completions_mind', category: 'Dominio de Mente', icon: Icons.psychology_outlined, title: 'Mente Clara', subtitle: 'Completa 10 hábitos mentales', unlockGoal: 10, color: Colors.blue),
    Achievement(type: 'streak', category: 'Consistencia', icon: Icons.calendar_today_outlined, title: 'Amante de la Rutina', subtitle: 'Alcanza una racha de 7 días', unlockGoal: 7, color: AppColors.accent, isSecret: true),
    Achievement(type: 'streak', category: 'Consistencia', icon: Icons.verified_outlined, title: 'Maestro de la Racha', subtitle: 'Alcanza una racha de 30 días', unlockGoal: 30, color: AppColors.success, isSecret: true),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _loadUserAchievements();
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// Carga los datos de los hábitos del usuario y determina qué logros se han desbloqueado.
  Future<void> _loadUserAchievements() async {
    if (user == null) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final habitsSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').get();
      final habitsDocs = habitsSnapshot.docs;

      // Calcular métricas de progreso
      int totalCompletions = 0;
      int healthCompletions = 0;
      int mindCompletions = 0;
      int maxStreak = 0;

      for (var doc in habitsDocs) {
        final data = doc.data();
        totalCompletions += (data['completions'] as List? ?? []).length;
        if(data['category'] == 'health') healthCompletions += (data['completions'] as List? ?? []).length;
        if(data['category'] == 'mind') mindCompletions += (data['completions'] as List? ?? []).length;
        if((data['currentStreak'] as int? ?? 0) > maxStreak) maxStreak = data['currentStreak'];
      }
      
      int unlockedCount = 0;
      Map<String, List<Achievement>> groupedAchievements = {};

      // Comprobar cada logro maestro contra las métricas del usuario
      for (var achievement in _masterAchievements) {
        bool isUnlocked = false;
        switch(achievement.type) {
          case 'total_completions': isUnlocked = totalCompletions >= achievement.unlockGoal; break;
          case 'category_completions_health': isUnlocked = healthCompletions >= achievement.unlockGoal; break;
          case 'category_completions_mind': isUnlocked = mindCompletions >= achievement.unlockGoal; break;
          case 'streak': isUnlocked = maxStreak >= achievement.unlockGoal; break;
        }
        
        if(isUnlocked) unlockedCount++;
        achievement.isUnlocked = isUnlocked;
        (groupedAchievements[achievement.category] ??= []).add(achievement);
      }
      
      if(mounted) {
        // Si el número de logros desbloqueados ha aumentado, ¡fiesta!
        if (_previousUnlockedCount > 0 && unlockedCount > _previousUnlockedCount) {
          _confettiController.play();
        }
        setState(() {
          _achievementsByCategory = groupedAchievements;
          _isLoading = false;
          _previousUnlockedCount = unlockedCount;
        });
      }

    } catch (e) {
      print("Error al cargar logros: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Logros', style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      // El Stack permite superponer el confeti sobre la lista de logros.
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadUserAchievements,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _achievementsByCategory.length,
                    itemBuilder: (context, index) {
                      final category = _achievementsByCategory.keys.elementAt(index);
                      final achievements = _achievementsByCategory[category]!;
                      return _buildAchievementCategory(category, achievements);
                    },
                  ),
                ),
          // Widget que muestra la animación de confeti
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            gravity: 0.1,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
          ),
        ],
      ),
    );
  }

  /// Construye una sección para una categoría de logros.
  Widget _buildAchievementCategory(String title, List<Achievement> achievements) {
    // Los logros secretos solo se muestran si ya están desbloqueados.
    final visibleAchievements = achievements.where((a) => !a.isSecret || a.isUnlocked).toList();
    if(visibleAchievements.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9,
            ),
            itemCount: visibleAchievements.length,
            itemBuilder: (context, index) {
              return _AchievementCard(achievement: visibleAchievements[index]);
            },
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar una tarjeta de logro individual.
class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({required this.achievement});

  void _shareAchievement() {
    Share.share('¡He desbloqueado el logro "${achievement.title}" en Vito App! 🏆 #VitoApp #LogroDesbloqueado');
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final color = isUnlocked ? achievement.color : Colors.grey;

    return GestureDetector(
      onTap: isUnlocked ? _shareAchievement : null,
      child: Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: isUnlocked ? Theme.of(context).cardColor : Theme.of(context).colorScheme.surface.withOpacity(0.5),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: isUnlocked ? color.withOpacity(0.5) : Colors.transparent, width: 2),
           boxShadow: isUnlocked ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))] : [],
         ),
         child: Opacity(
           opacity: isUnlocked ? 1.0 : 0.6,
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(isUnlocked ? achievement.icon : Icons.lock_outline, color: color, size: 40),
               const SizedBox(height: 12),
               Text(achievement.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               const SizedBox(height: 4),
               Text(achievement.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
             ],
           ),
         ),
       ),
    );
  }
}
