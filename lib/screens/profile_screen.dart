import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

// Importa los providers y colores de tu proyecto real
import '../providers/theme_provider.dart'; // Asegúrate de tener este archivo
import '../providers/user_profile_provider.dart'; // Asegúrate de tener este archivo
import '../theme/app_colors.dart'; // Asegúrate de tener este archivo

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;

  final TextEditingController _deletePasswordController = TextEditingController();
  bool _isDeleting = false;


  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Carga los datos iniciales si no se han cargado ya
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    // Solo carga si no hay datos y hay un usuario logueado
    if (userProfileProvider.isLoading && currentUser != null) {
      userProfileProvider.loadData(currentUser);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  void _showEditNameDialog() {
    final userProfile = context.read<UserProfileProvider>();
    final controller = TextEditingController(text: userProfile.displayName);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cambiar Nombre', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Tu nombre',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                userProfile.updateDisplayName(controller.text); // Llama al Provider
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cerrar Sesión', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('¿Estás seguro de que quieres cerrar tu sesión?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if(mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Cerrar Sesión', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Método para mostrar diálogo de eliminación con re-autenticación
  Future<void> _showDeleteAccountDialog() async {
    // Limpiar controlador de contraseña
    _deletePasswordController.clear();

    // Mostrar diálogo para ingresar contraseña
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar Cuenta',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para eliminar tu cuenta, ingresa tu contraseña:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deletePasswordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Eliminar Cuenta', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    // Si el usuario cancela, no hacer nada
    if (shouldDelete != true) return;

    setState(() => _isDeleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-autenticar con email y contraseña
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _deletePasswordController.text.trim(),
        );
        await user.reauthenticateWithCredential(cred);

        // Eliminar usuario de Firebase Auth
        await user.delete();

        // Redirigir al login
        if (mounted) context.go('/login');
      }
    } on FirebaseAuthException catch (e) {
      // Manejo de errores (ej. contraseña incorrecta)
      final message = e.code == 'wrong-password'
          ? 'Contraseña incorrecta.'
          : 'Error al eliminar la cuenta.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final profileProvider = context.watch<UserProfileProvider>();

    if (profileProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => profileProvider.loadData(FirebaseAuth.instance.currentUser),
        child: CustomScrollView(
          slivers: [
            // Nuevo SliverAppBar con el mismo estilo que stats_screen
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FadeTransition(
                            opacity: _fadeController,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Mi Perfil', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('Gestiona tu cuenta', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildUserCard(context, profileProvider),
                  _buildAccountSection(context, profileProvider),
                  // Ya no mostramos _buildPreferencesSection
                  _buildSupportSection(context),
                  _buildLegalSection(),
                  _buildLogoutButton(),
                  _buildDeleteAccountButton(),
                  _buildAppVersion(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserProfileProvider provider) {
    final daysUsing = provider.createdAt != null ? DateTime.now().difference(provider.createdAt!).inDays + 1 : 1;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Center(
              child: Text(
                provider.displayName.isNotEmpty ? provider.displayName.substring(0, 1).toUpperCase() : 'U',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(provider.displayName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
          Text(provider.email, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUserStat('$daysUsing', 'Días activo'),
              Container(height: 30, width: 1, color: Colors.white30),
              _buildUserStat(provider.totalHabits.toString(), 'Hábitos'),
              Container(height: 30, width: 1, color: Colors.white30),
              _buildUserStat(provider.isPremium ? 'Pro' : 'Free', 'Plan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, UserProfileProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_circle_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Mi Cuenta', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ]),
          const SizedBox(height: 20),
          _buildAccountItem('Cambiar nombre', provider.displayName, Icons.person_outline_rounded, () => _showEditNameDialog(), context),
          const SizedBox(height: 16),
          _buildAccountItem('Email', provider.email, Icons.email_outlined, null, context),
        ],
      ),
    );
  }

  Widget _buildAccountItem(String label, String value, IconData icon, VoidCallback? onTap, BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                  Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.edit_outlined, color: Theme.of(context).iconTheme.color?.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Ayuda y Soporte', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ]),
          const SizedBox(height: 20),
          _buildSupportItem('Centro de ayuda', 'Preguntas frecuentes', Icons.quiz_outlined, () {}, context),
          const SizedBox(height: 16),
          _buildSupportItem('Contactar soporte', 'Te respondemos en 24h', Icons.mail_outline_rounded, () {}, context),
        ],
      ),
    );
  }

  Widget _buildSupportItem(String title, String subtitle, IconData icon, VoidCallback onTap, BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: Theme.of(context).iconTheme.color?.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(onPressed: () {}, child: Text('Términos', style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color))),
          Container(height: 20, width: 1, color: Theme.of(context).dividerColor),
          TextButton(onPressed: () {}, child: Text('Privacidad', style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color))),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: OutlinedButton(
        onPressed: _showLogoutDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded),
            const SizedBox(width: 8),
            Text('Cerrar Sesión', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextButton(
        onPressed: _showDeleteAccountDialog,
        style: TextButton.styleFrom(
          foregroundColor: Colors.red.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever_rounded, size: 20),
            const SizedBox(width: 8),
            Text('Eliminar mi cuenta', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.spa_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text('Vito', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Versión 1.2.0', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 4),
          Text('Hecho con 💜 para tu bienestar', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}