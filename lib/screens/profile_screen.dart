import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  bool _isLoading = false;
  
  // Estadísticas básicas del usuario
  int _totalHabits = 0;
  int _currentStreak = 0;
  DateTime? _memberSince;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _loadUserStats();
    
    FirebaseAuth.instance.userChanges().listen((newUser) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Cargar estadísticas básicas
      final habitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('habits')
          .get();
      
      _totalHabits = habitsSnapshot.docs.length;
      
      // Calcular racha actual (simplificado)
      int maxStreak = 0;
      for (var doc in habitsSnapshot.docs) {
        final habit = doc.data();
        final streak = habit['streak'] ?? 0;
        if (streak > maxStreak) maxStreak = streak;
      }
      _currentStreak = maxStreak;
      
      // Obtener fecha de registro
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (userDoc.exists && userDoc.data()?['createdAt'] != null) {
        _memberSince = (userDoc.data()!['createdAt'] as Timestamp).toDate();
      } else {
        _memberSince = user!.metadata.creationTime ?? DateTime.now();
      }
      
    } catch (e) {
      print("Error loading user stats: $e");
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadUserStats,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            _buildProfileInfo(),
            _buildQuickStats(),
            _buildSettingsSection(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decoración de fondo
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              // Título
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FadeTransition(
                        opacity: _fadeController,
                        child: Text(
                          'Mi Perfil',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'Gestiona tu cuenta',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileInfo() {
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -40),
        child: FadeTransition(
          opacity: _fadeController,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _scaleController,
              curve: Curves.easeOutBack,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar con animación
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.8),
                                AppColors.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                image: user?.photoURL != null
                                    ? DecorationImage(
                                        image: NetworkImage(user!.photoURL!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: user?.photoURL == null
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: AppColors.primary.withOpacity(0.7),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Nombre
                  Text(
                    user?.displayName ?? 'Usuario Vito',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  
                  // Email
                  if (user?.email != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user!.email!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                  
                  // Miembro desde
                  if (_memberSince != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Miembro desde ${_formatDate(_memberSince!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickStats() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.track_changes,
                value: _totalHabits.toString(),
                label: 'Hábitos',
                color: AppColors.primary,
                delay: 0.1,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department,
                value: _currentStreak.toString(),
                label: 'Racha máxima',
                color: const Color(0xFFF97316),
                delay: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required double delay,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (delay * 1000).toInt()),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 1000),
                  tween: IntTween(begin: 0, end: int.parse(value)),
                  builder: (context, val, child) {
                    return Text(
                      val.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSettingsSection() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildModernSettingTile(
                icon: Icons.edit_rounded,
                title: 'Editar Perfil',
                subtitle: 'Cambia tu información',
                color: AppColors.primary,
                onTap: () => _showEditProfileSheet(context),
              ),
              _buildDivider(),
              _buildModernSettingTile(
                icon: Icons.palette_rounded,
                title: 'Apariencia',
                subtitle: 'Tema de la aplicación',
                color: const Color(0xFF8B5CF6),
                onTap: () => _showAppearanceSettings(context),
              ),
              _buildDivider(),
              _buildModernSettingTile(
                icon: Icons.notifications_rounded,
                title: 'Notificaciones',
                subtitle: 'Gestiona tus alertas',
                color: const Color(0xFF3B82F6),
                onTap: () => _showNotificationsSettings(context),
              ),
              _buildDivider(),
              _buildModernSettingTile(
                icon: Icons.help_rounded,
                title: 'Ayuda y Soporte',
                subtitle: 'Centro de ayuda',
                color: const Color(0xFF10B981),
                onTap: () => _showHelpCenter(context),
              ),
              _buildDivider(),
              _buildModernSettingTile(
                icon: Icons.logout_rounded,
                title: 'Cerrar Sesión',
                subtitle: 'Hasta pronto',
                color: const Color(0xFF6B7280),
                onTap: () => _signOut(context),
              ),
              _buildDivider(),
              _buildModernSettingTile(
                icon: Icons.delete_forever_rounded,
                title: 'Eliminar Cuenta',
                subtitle: 'Acción permanente',
                color: AppColors.error,
                onTap: () => _confirmDeleteAccount(context),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildModernSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDestructive 
                            ? color 
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: const Color(0xFFE2E8F0),
      ),
    );
  }
  
  void _showEditProfileSheet(BuildContext context) {
    final nameController = TextEditingController(text: user?.displayName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Editar Perfil',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    labelStyle: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre no puede estar vacío';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate() && user != null) {
                        HapticFeedback.mediumImpact();
                        await user!.updateDisplayName(
                          nameController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Guardar Cambios',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showAppearanceSettings(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Apariencia',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              _buildThemeOption(
                context: modalContext,
                title: 'Tema Claro',
                icon: Icons.light_mode,
                option: ThemeOption.light,
                currentOption: themeProvider.currentThemeOption,
                onTap: () {
                  themeProvider.setTheme(ThemeOption.light);
                  Navigator.pop(modalContext);
                },
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                context: modalContext,
                title: 'Tema Oscuro',
                icon: Icons.dark_mode,
                option: ThemeOption.dark,
                currentOption: themeProvider.currentThemeOption,
                onTap: () {
                  themeProvider.setTheme(ThemeOption.dark);
                  Navigator.pop(modalContext);
                },
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                context: modalContext,
                title: 'Tema del Sistema',
                icon: Icons.settings_brightness,
                option: ThemeOption.system,
                currentOption: themeProvider.currentThemeOption,
                onTap: () {
                  themeProvider.setTheme(ThemeOption.system);
                  Navigator.pop(modalContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required ThemeOption option,
    required ThemeOption currentOption,
    required VoidCallback onTap,
  }) {
    final isSelected = option == currentOption;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(0.1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected 
                      ? AppColors.primary
                      : const Color(0xFF64748B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? AppColors.primary
                      : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showNotificationsSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Notificaciones',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las notificaciones se configuran individualmente para cada hábito',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ve a la pantalla de hábitos para configurar recordatorios específicos',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showHelpCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.support_agent_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '¿Necesitas ayuda?',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estamos aquí para apoyarte',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.email_rounded, color: AppColors.primary),
              title: Text(
                'soporte@vitoapp.com',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              subtitle: Text(
                'Envíanos un email',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                // Abrir cliente de email
              },
            ),
            ListTile(
              leading: Icon(Icons.article_rounded, color: AppColors.primary),
              title: Text(
                'Centro de ayuda',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              subtitle: Text(
                'Preguntas frecuentes',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                // Abrir FAQ
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _signOut(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF64748B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Cerrar Sesión?',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Estás seguro de que deseas salir?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            GoRouter.of(context).go('/login');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Cerrar Sesión',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _confirmDeleteAccount(BuildContext context) {
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Eliminar cuenta?',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Esta acción es permanente. Se eliminarán todos tus hábitos y progreso.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _deleteAccount(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Eliminar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (user == null) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      
      // Eliminar hábitos
      final habitsSnapshot = await userRef.collection('habits').get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in habitsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Eliminar documento del usuario
      await userRef.delete();
      
      // Eliminar cuenta de autenticación
      await user!.delete();

      // Cerrar loading
      if (context.mounted) Navigator.pop(context);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Tu cuenta ha sido eliminada',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      
      router.go('/login');

    } on FirebaseAuthException catch (e) {
      // Cerrar loading si está abierto
      if (context.mounted) Navigator.pop(context);
      
      String message = 'Ocurrió un error al eliminar tu cuenta';
      if (e.code == 'requires-recent-login') {
        message = 'Por seguridad, debes iniciar sesión de nuevo';
      }
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      // Cerrar loading si está abierto
      if (context.mounted) Navigator.pop(context);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error inesperado: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}