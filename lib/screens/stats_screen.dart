import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../services/stats_processing_service.dart';
import '../theme/app_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _scaleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<QuerySnapshot>>(
        stream: StatsProcessingService.getHabitsAndMoodsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data![0].docs.isEmpty) {
            return _buildEmptyState();
          }

          final habitsDocs = snapshot.data![0].docs;
          // Los moodDocs ya no se usan en esta pantalla
          // final moodDocs = snapshot.data![1].docs;
          
          final processedStats = StatsProcessingService.processStats(habitsDocs);
          
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernSliverAppBar(),
              // <<< NUEVA ESTRUCTURA DE LA PANTALLA >>>
              _buildCurrentStreakCard(processedStats['currentStreak'] ?? 0),
              _buildAchievementsSection(processedStats),
              _buildBeautifulChartSection(processedStats),
              _buildStylishCategorySection(processedStats),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildModernSliverAppBar() {
    return SliverAppBar(
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
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tus Logros', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Celebra tu consistencia', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9))),
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
    );
  }

  // <<< NUEVO WIDGET: TARJETA DE RACHA ACTUAL >>>
  Widget _buildCurrentStreakCard(int streak) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeController,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Racha Actual', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9))),
                      Text('$streak Días', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Text('¡Sigue así!', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // <<< NUEVO WIDGET: SECCIÓN DE LOGROS Y MEDALLAS >>>
  Widget _buildAchievementsSection(Map<String, dynamic> stats) {
    // Simulación de datos de logros. Esto debería venir de tu StatsProcessingService.
    final achievements = [
      {'title': 'Pionero', 'icon': Icons.flag_rounded, 'isUnlocked': true},
      {'title': 'Consistente', 'icon': Icons.star_rounded, 'isUnlocked': (stats['currentStreak'] ?? 0) >= 7},
      {'title': 'Madrugador', 'icon': Icons.light_mode_rounded, 'isUnlocked': false},
      {'title': 'Maestro Zen', 'icon': Icons.spa_rounded, 'isUnlocked': (stats['totalMeditate'] ?? 0) >= 10},
      {'title': 'Invencible', 'icon': Icons.shield_rounded, 'isUnlocked': (stats['longestStreak'] ?? 0) >= 30},
    ];

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 15))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logros y Medallas', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: achievements.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  return _buildAchievementBadge(achievement['title'] as String, achievement['icon'] as IconData, achievement['isUnlocked'] as bool);
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // <<< WIDGET AUXILIAR PARA CADA MEDALLA >>>
  Widget _buildAchievementBadge(String title, IconData icon, bool isUnlocked) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isUnlocked
                  ? [AppColors.primary, AppColors.secondary]
                  : [Colors.grey.shade200, Colors.grey.shade300],
            ),
            boxShadow: isUnlocked
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                : [],
          ),
          child: Icon(icon, color: isUnlocked ? Colors.white : Colors.grey.shade500, size: 36),
        ),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: isUnlocked ? const Color(0xFF1E293B) : Colors.grey.shade600)),
      ],
    );
  }

  // (El resto de los widgets como el gráfico y las categorías se mantienen, ya que aportan gran valor visual)
  
  Widget _buildBeautifulChartSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 15))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rendimiento Semanal', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              const SizedBox(height: 32),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 30, interval: 1,
                          getTitlesWidget: (value, meta) {
                            const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                            final dayIndex = DateTime.now().subtract(Duration(days: 6 - value.toInt())).weekday - 1;
                            return SideTitleWidget(axisSide: meta.axisSide, child: Text(days[dayIndex], style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, interval: 25, reservedSize: 45,
                          getTitlesWidget: (value, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text('${value.toInt()}%', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12))),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0, maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: stats['weeklySpots'],
                        isCurved: true, curveSmoothness: 0.4,
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                        barWidth: 5, isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.0)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          ),
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

  Widget _buildStylishCategorySection(Map<String, dynamic> stats) {
    if ((stats['categoryPerformance'] as Map).isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 15))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progreso por Categoría', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 28),
            ...(stats['categoryPerformance'] as Map<String, List<int>>).entries.map((entry) {
              final double progress = entry.value[1] > 0 ? (entry.value[0] / entry.value[1]) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildModernCategoryBar(entry.key, progress, _getGradientForCategory(entry.key)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModernCategoryBar(String category, double progress, List<Color> gradientColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B))),
            Text('${(progress * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: gradientColors[0])),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(height: 10, decoration: BoxDecoration(color: gradientColors[0].withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
            LayoutBuilder(
              builder: (context, constraints) => TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: progress),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Container(
                    height: 10,
                    width: constraints.maxWidth * value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Color> _getGradientForCategory(String category) {
    // (Este método se mantiene igual)
    switch (category.toLowerCase()) {
      case 'salud': return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
      case 'mente': return [const Color(0xFF9C27B0), const Color(0xFFBA68C8)];
      case 'trabajo': return [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
      case 'social': return [const Color(0xFFE91E63), const Color(0xFFF06292)];
      case 'creativo': return [const Color(0xFFFF9800), const Color(0xFFFFB74D)];
      case 'finanzas': return [const Color(0xFF795548), const Color(0xFFA1887F)];
      default: return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
    }
  }

  Widget _buildEmptyState() {
    // (Este método se mantiene igual)
    return Center(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.show_chart_rounded, size: 60, color: AppColors.primary.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            Text('Aún no hay estadísticas', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '¡Empieza a registrar tus hábitos para ver tu progreso aquí!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}