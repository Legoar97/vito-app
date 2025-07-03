import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/mood/enhanced_mood_tracker_widget.dart';
import '../widgets/mood/mood_calendar_widget.dart';
import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../widgets/mood/cute_mood_icon.dart';

class MoodTrackerScreen extends StatefulWidget {
  const MoodTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen>
    with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  List<MoodEntry> _moodHistory = [];
  bool _isLoading = true;
  bool _showCalendar = false;

  // <<< 1. AÑADIMOS UNA ANIMACIÓN DE DESLIZAMIENTO
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // <<< 2. INICIALIZAMOS LA ANIMACIÓN
    // Hará que los widgets se deslicen desde abajo hacia arriba.
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _loadMoodHistory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodHistory() async {
    if (user == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      if (mounted) {
        setState(() {
          _moodHistory = snapshot.docs
              .map((doc) => MoodEntry.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading mood history: $e');
    }
  }

  SliverAppBar _buildModernSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.book_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu Estado de Ánimo',
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                'Registra cómo te sientes hoy',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildModernMoodStats() {
    if (_moodHistory.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentMoods = _moodHistory
        .where((entry) => entry.timestamp.isAfter(thirtyDaysAgo))
        .toList();

    if (recentMoods.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    Map<String, int> moodCounts = {};
    for (var entry in recentMoods) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }

    String mostCommonMood = '';
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonMood = mood;
      }
    });

    final mostCommonMoodData = MoodData.moods.firstWhere(
      (m) => m.name == mostCommonMood,
      orElse: () => MoodData.moods.first,
    );

    return SliverToBoxAdapter(
      // <<< 4. AÑADIMOS ANIMACIÓN A LAS ESTADÍSTICAS
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeController,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado Predominante',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Últimos 30 días',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: mostCommonMoodData.gradient,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: CuteMoodIcon(
                          color: Colors.white,
                          expression: mostCommonMoodData.expression,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: mostCommonMoodData.gradient
                            .map((c) => c.withOpacity(0.1))
                            .toList(),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: mostCommonMoodData.gradient),
                            shape: BoxShape.circle,
                          ),
                          child: CuteMoodIcon(
                            color: Colors.white,
                            expression: mostCommonMoodData.expression,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mostCommonMoodData.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '$maxCount veces registrado',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: mostCommonMoodData.gradient),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: mostCommonMoodData.baseColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '${((maxCount / recentMoods.length) * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
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
    );
  }

  Widget _buildModernCalendarToggle() {
    return SliverToBoxAdapter(
      // <<< 5. AÑADIMOS ANIMACIÓN AL BOTÓN DEL CALENDARIO
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeController,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _showCalendar = !_showCalendar);
                  HapticFeedback.lightImpact();
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showCalendar ? Icons.edit_calendar_outlined : Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _showCalendar ? 'Ocultar calendario' : 'Ver calendario',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.book_rounded,
                  size: 60,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aún no hay registros',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '¡Empieza a registrar tu estado de ánimo para ver tu progreso aquí!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // <<< 3. APLICAMOS EL NUEVO FONDO CON GRADIENTE
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.08),
              const Color(0xFFF8FAFC),
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildModernSliverAppBar(),
                  SliverToBoxAdapter(
                    // <<< 6. AÑADIMOS ANIMACIÓN AL WIDGET PRINCIPAL
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeController,
                        child: EnhancedMoodTrackerWidget(
                          animationController: _fadeController,
                          onMoodSaved: (mood) {
                            _loadMoodHistory();
                            _scaleController.forward(from: 0.0);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_moodHistory.isNotEmpty) ...[
                    _buildModernMoodStats(),
                    _buildModernCalendarToggle(),
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: _showCalendar
                            ? SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeController,
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                    padding: const EdgeInsets.all(4),
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
                                    child: MoodCalendarWidget(
                                      moodHistory: _moodHistory,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ] else
                    _buildEmptyState(),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
      ),
    );
  }
}