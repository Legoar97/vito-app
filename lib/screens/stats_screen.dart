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
  late AnimationController _scaleController; // Restaurado

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    // Restaurado
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose(); // Restaurado
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
          final moodDocs = snapshot.data![1].docs;
          
          final processedStats = StatsProcessingService.processStats(habitsDocs);
          final moodStats = StatsProcessingService.processMoodStats(moodDocs);

          // La llamada a _buildMoodStatsSection ahora es correcta
          return CustomScrollView(
            slivers: [
              _buildModernSliverAppBar(),
              _buildModernOverviewSection(processedStats),
              _buildMoodStatsSection(moodStats), // Esta llamada es correcta
              _buildBeautifulChartSection(processedStats),
              _buildStylishCategorySection(processedStats),
              _buildElegantPerformanceSection(processedStats),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS DE UI RESTAURADOS Y COMPLETOS ---

  SliverAppBar _buildModernSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200, // Ajustado para un look más limpio
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
                          child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tu Progreso', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Un vistazo a tus logros', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9))),
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

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                Icons.show_chart_rounded,
                size: 60,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aún no hay estadísticas',
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
                '¡Empieza a registrar tus hábitos para ver tu progreso aquí!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildModernOverviewSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _buildGlassStatCard(
                'Total Hábitos',
                stats['totalHabits'].toString(),
                Icons.spa_rounded,
                [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGlassStatCard(
                'Completado',
                '${stats['overallCompletionRate'].toStringAsFixed(0)}%',
                Icons.trending_up_rounded,
                [AppColors.success, AppColors.success.withOpacity(0.7)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, List<Color> gradientColors) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 20),
            Text(value, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBeautifulChartSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          margin: const EdgeInsets.all(20),
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
                        'Progreso Semanal',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Últimos 7 días',
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                            final dayIndex = DateTime.now().subtract(Duration(days: 6 - value.toInt())).weekday - 1;
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                days[dayIndex],
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 25,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${value.toInt()}%',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: stats['weeklySpots'],
                        isCurved: true,
                        curveSmoothness: 0.3,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary,
                          ],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: AppColors.primary,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
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
            Text('Por Categoría', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
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
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gradientColors[0],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: gradientColors[0].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: progress),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Container(
                  height: 10,
                  width: MediaQuery.of(context).size.width * value * 0.7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  
  List<Color> _getGradientForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'salud': 
        return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
      case 'mente': 
        return [const Color(0xFF9C27B0), const Color(0xFFBA68C8)];
      case 'trabajo': 
        return [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
      case 'social': 
        return [const Color(0xFFE91E63), const Color(0xFFF06292)];
      case 'creativo': 
        return [const Color(0xFFFF9800), const Color(0xFFFFB74D)];
      case 'finanzas': 
        return [const Color(0xFF795548), const Color(0xFFA1887F)];
      default: 
        return [const Color(0xFF607D8B), const Color(0xFF90A4AE)];
    }
  }

  Widget _buildElegantPerformanceSection(Map<String, dynamic> stats) {
    if ((stats['habitPerformance'] as List).isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Hábitos', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 28),
            ...List.generate((stats['habitPerformance'] as List).length, (index) {
              final habit = stats['habitPerformance'][index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildBeautifulHabitRanking(habit['name'], habit['rate'], index + 1),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBeautifulHabitRanking(String habit, int percentage, int rank) {
    final medals = ['🥇', '🥈', '🥉'];
    final colors = [
      [const Color(0xFFFFD700), const Color(0xFFFFA000)],
      [const Color(0xFFC0C0C0), const Color(0xFF9E9E9E)],
      [const Color(0xFFCD7F32), const Color(0xFF8D6E63)],
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[rank - 1][0].withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors[rank - 1]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors[rank - 1][0].withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                medals[rank - 1],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Completado consistentemente',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.1),
                  AppColors.success.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$percentage%',
              style: GoogleFonts.poppins(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMoodStatsSection(Map<String, dynamic> moodStats) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(30) // Últimos 30 días
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // 1) Contar ocurrencias de cada estado
        final moodCounts = <String, int>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final moodValue = data['mood'] as String;
          moodCounts[moodValue] = (moodCounts[moodValue] ?? 0) + 1;
        }

        // 2) Determinar estado más frecuente
        String? mostFrequentMood;
        int maxCount = 0;
        moodCounts.forEach((m, count) {
          if (count > maxCount) {
            maxCount = count;
            mostFrequentMood = m;
          }
        });

        // 3) Si no hay mood, salimos
        if (mostFrequentMood == null) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // 4) Asignar a variable no-nullable
        final String mood = mostFrequentMood!;  
        final int totalDays = snapshot.data!.docs.length;

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE0E7FF).withOpacity(0.5),
                  const Color(0xFFC7D2FE).withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu Estado de Ánimo',
                          style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Últimos 30 días',
                          style: GoogleFonts.poppins(
                            fontSize: 14, color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mood_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Estado más frecuente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _getMoodGradient(mood)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getMoodIcon(mood), color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estado más frecuente', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B))),
                            Text(mood, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getMoodGradient(mood)[0].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${((maxCount / totalDays) * 100).toInt()}%',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _getMoodGradient(mood)[0]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Distribución de todos los estados
                Text('Distribución', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                const SizedBox(height: 12),
                ...moodCounts.entries.map((entry) {
                  final percent = entry.value / totalDays;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: _getMoodGradient(entry.key)), shape: BoxShape.circle),
                          child: Icon(_getMoodIcon(entry.key), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(entry.key, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B))),
                                Text('${entry.value} días', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 1000),
                                  tween: Tween(begin: 0.0, end: percent),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) => LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    backgroundColor: _getMoodGradient(entry.key)[0].withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(_getMoodGradient(entry.key)[0]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Feliz': return Icons.sentiment_very_satisfied;
      case 'Normal': return Icons.sentiment_satisfied;
      case 'Triste': return Icons.sentiment_dissatisfied;
      case 'Estresado': return Icons.bolt;
      case 'Motivado': return Icons.local_fire_department;
      default: return Icons.sentiment_neutral;
    }
  }
  
  List<Color> _getMoodGradient(String mood) {
    switch (mood) {
      case 'Feliz': return [const Color(0xFF4ADE80), const Color(0xFF22C55E)];
      case 'Normal': return [const Color(0xFF60A5FA), const Color(0xFF3B82F6)];
      case 'Triste': return [const Color(0xFF94A3B8), const Color(0xFF64748B)];
      case 'Estresado': return [const Color(0xFFFBBF24), const Color(0xFFF59E0B)];
      case 'Motivado': return [const Color(0xFFF87171), const Color(0xFFEF4444)];
      default: return [const Color(0xFF9CA3AF), const Color(0xFF6B7280)];
    }
  }
}