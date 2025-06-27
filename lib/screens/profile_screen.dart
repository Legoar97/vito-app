import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

// --- Modelo para los Logros ---
// Para una mejor organización, esta clase podría vivir en su propio archivo
// en una carpeta 'models', por ejemplo: 'lib/models/achievement.dart'
class Achievement {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int unlockGoal;
  final String category;
  bool isUnlocked;

  Achievement({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unlockGoal,
    required this.category,
    this.isUnlocked = false,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  int _unlockedAchievementsCount = 0;
  int _totalAchievementsCount = 0;
  
  // La lista maestra vive aquí para calcular el resumen.
  // Es importante que sea idéntica a la de la pantalla de logros.
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
    _loadUserData();
    FirebaseAuth.instance.userChanges().listen((newUser) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _loadAchievementsSummary();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAchievementsSummary() async {
    if (user == null) {
      if(mounted) setState(() => _totalAchievementsCount = _masterAchievements.length);
      return;
    }
    try {
      final habitsSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').get();
      final habitsData = habitsSnapshot.docs.map((doc) => doc.data()).toList();
      
      int totalCompletions = habitsData.fold(0, (sum, habit) => sum + (habit['completions'] as List? ?? []).length);
      int morningCompletions = _countCompletionsBefore(habitsData, 8);
      int healthCompletions = _countCompletionsByCategory(habitsData, 'Salud');
      int mindCompletions = _countCompletionsByCategory(habitsData, 'Mente');

      int unlockedCount = 0;
      for (var achievement in _masterAchievements) {
        bool unlocked = false;
        switch (achievement.category) {
          case 'Progreso General': unlocked = totalCompletions >= achievement.unlockGoal; break;
          case 'Maestría Matutina': unlocked = morningCompletions >= achievement.unlockGoal; break;
          case 'Dominio de Salud': unlocked = healthCompletions >= achievement.unlockGoal; break;
          case 'Dominio de Mente': unlocked = mindCompletions >= achievement.unlockGoal; break;
        }
        if(unlocked) unlockedCount++;
      }
      
      if (mounted) {
        setState(() {
          _unlockedAchievementsCount = unlockedCount;
          _totalAchievementsCount = _masterAchievements.length;
        });
      }

    } catch (e) {
      print("Error al cargar resumen de logros: $e");
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
      // Asume que tus hábitos tienen un campo 'category'
      if (habit['category'] == category) {
        count += (habit['completions'] as List? ?? []).length;
      }
    }
    return count;
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300, pinned: true,
              backgroundColor: Colors.transparent, elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white,
                            image: currentUser?.photoURL != null ? DecorationImage(image: NetworkImage(currentUser!.photoURL!), fit: BoxFit.cover) : null,
                          ),
                          child: currentUser?.photoURL == null ? Icon(Icons.person, size: 50, color: Colors.grey[400]) : null,
                        ),
                        const SizedBox(height: 16),
                        Text(currentUser?.displayName ?? 'Usuario Vito', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (currentUser?.email != null) Text(currentUser!.email!, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: _buildAchievementsSummary(),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: _buildSettings(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Logros", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Asume que la ruta es /home/achievements como se configuró antes
                context.go('/home/achievements'); 
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.primary, size: 40),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Mi Progreso", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text("$_unlockedAchievementsCount de $_totalAchievementsCount logros", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
      ],
    );
  }
  
  Widget _buildSettings(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildSettingTile(icon: Icons.edit, title: 'Editar Perfil', subtitle: 'Cambia tu nombre', onTap: () => _showEditProfileSheet(context)),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingTile(icon: Icons.notifications, title: 'Notificaciones', subtitle: 'Gestiona tus recordatorios', onTap: () => _showNotificationsSettings(context)),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingTile(icon: Icons.palette, title: 'Apariencia', subtitle: 'Cambia el tema de la app', onTap: () => _showAppearanceSettings(context)),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingTile(icon: Icons.logout, title: 'Cerrar Sesión', subtitle: '¡Hasta pronto!', onTap: () => _signOut(context)),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingTile(icon: Icons.delete_forever, title: 'Eliminar Cuenta', subtitle: 'Esta acción es permanente', onTap: () => _confirmDeleteAccount(context), isDestructive: true),
        ],
      ),
    );
   }

  Widget _buildSettingTile({ required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false }) {
    final color = isDestructive ? AppColors.error : AppColors.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDestructive ? color : Theme.of(context).textTheme.bodyLarge?.color)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
   }

  void _showEditProfileSheet(BuildContext context) {
    final nameController = TextEditingController(text: user?.displayName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Editar Perfil", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'El nombre no puede estar vacío.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  if (formKey.currentState!.validate() && user != null) {
                    await user!.updateDisplayName(nameController.text.trim());
                    if(mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Guardar Cambios"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notificaciones", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recordatorios de hábitos'),
              value: true, 
              onChanged: (val) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Funcionalidad en desarrollo."))),
            ),
            SwitchListTile(
              title: const Text('Notificaciones de logros'),
              value: true, 
              onChanged: (val) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Funcionalidad en desarrollo."))),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAppearanceSettings(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Apariencia", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeOption>(
              title: const Text("Tema Claro"),
              value: ThemeOption.light,
              groupValue: themeProvider.currentThemeOption,
              onChanged: (v) {
                if(v != null) themeProvider.setTheme(v);
                Navigator.pop(dialogContext);
              },
            ),
            RadioListTile<ThemeOption>(
              title: const Text("Tema Oscuro"),
              value: ThemeOption.dark,
              groupValue: themeProvider.currentThemeOption,
              onChanged: (v) {
                if(v != null) themeProvider.setTheme(v);
                Navigator.pop(dialogContext);
              },
            ),
            RadioListTile<ThemeOption>(
              title: const Text("Usar tema del sistema"),
              value: ThemeOption.system,
              groupValue: themeProvider.currentThemeOption,
              onChanged: (v) {
                if(v != null) themeProvider.setTheme(v);
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _signOut(BuildContext context) async {
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Cerrar Sesión?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              router.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteAccount(BuildContext context) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar tu cuenta?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text('Esta acción es irreversible. Se borrarán todos tus hábitos y progreso para siempre. ¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      
      final habitsSnapshot = await userRef.collection('habits').get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in habitsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      await userRef.delete();
      await user!.delete();

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Tu cuenta ha sido eliminada.")));
      router.go('/login');

    } on FirebaseAuthException catch (e) {
      String message = "Ocurrió un error al eliminar tu cuenta.";
      if (e.code == 'requires-recent-login') {
        message = "Esta operación requiere que inicies sesión de nuevo por seguridad.";
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Un error inesperado ocurrió: $e")));
    }
  }
}
