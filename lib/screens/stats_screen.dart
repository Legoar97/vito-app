import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  String _selectedPeriod = 'week';
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  
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
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.streamHabits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final habitsDocs = snapshot.data!.docs;
          final processedStats = _processStats(habitsDocs);

          return CustomScrollView(
            slivers: [
              _buildModernSliverAppBar(),
              _buildAnimatedPeriodSelector(),
              _buildWeeklyAnalysisSection(),
              _buildModernOverviewSection(processedStats),
              _buildBeautifulChartSection(processedStats),
              _buildStylishCategorySection(processedStats),
              _buildElegantPerformanceSection(processedStats),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // --- Lógica de Procesamiento (sin cambios) ---
  Map<String, dynamic> _processStats(List<QueryDocumentSnapshot> docs) {
    final totalHabits = docs.length;
    int totalCompletions = 0;
    int possibleCompletions = 0;
    Map<String, List<int>> categoryCompletions = {};
    Map<String, int> habitCompletions = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final completions = List<Timestamp>.from(data['completions'] ?? []);
      final days = List<int>.from(data['days'] ?? []);
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final category = data['category'] as String? ?? 'Otros';
      
      habitCompletions[doc.id] = completions.length;
      totalCompletions += completions.length;

      int daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      for (int i = 0; i <= daysSinceCreation; i++) {
        final date = createdAt.add(Duration(days: i));
        if (days.contains(date.weekday)) {
          possibleCompletions++;
          categoryCompletions.putIfAbsent(category, () => [0, 0]);
          categoryCompletions[category]![1]++;
          if(completions.any((c) => _isSameDay(c.toDate(), date))) {
             categoryCompletions[category]![0]++;
          }
        }
      }
    }

    final double overallCompletionRate = possibleCompletions > 0 ? (totalCompletions / possibleCompletions) * 100 : 0.0;

    final weeklySpots = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      int completionsOnDay = 0;
      int activeHabitsOnDay = 0;

      for(var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final days = List<int>.from(data['days'] ?? []);
        final completions = List<Timestamp>.from(data['completions'] ?? []);
        
        if (days.contains(day.weekday)) {
          activeHabitsOnDay++;
          if(completions.any((c) => _isSameDay(c.toDate(), day))) {
            completionsOnDay++;
          }
        }
      }
      final rate = activeHabitsOnDay > 0 ? (completionsOnDay / activeHabitsOnDay) * 100 : 0.0;
      return FlSpot(index.toDouble(), rate);
    });

    final habitPerformance = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final completions = List<Timestamp>.from(data['completions'] ?? []);
      final days = List<int>.from(data['days'] ?? []);
      final createdAt = (data['createdAt'] as Timestamp).toDate();

      int possible = 0;
      int daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      for (int i = 0; i <= daysSinceCreation; i++) {
        if(days.contains(createdAt.add(Duration(days: i)).weekday)) {
          possible++;
        }
      }
      final rate = possible > 0 ? (completions.length / possible) * 100 : 0.0;
      return {'name': data['name'], 'rate': rate.toInt()};
    }).toList();
    habitPerformance.sort((a, b) => b['rate']!.compareTo(a['rate']!));

    return {
      'totalHabits': totalHabits,
      'overallCompletionRate': overallCompletionRate,
      'weeklySpots': weeklySpots,
      'categoryPerformance': categoryCompletions,
      'habitPerformance': habitPerformance.take(3).toList(),
    };
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
  
  // --- Nuevos Widgets Modernos ---

  SliverAppBar _buildModernSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
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
              // Patrón de fondo decorativo
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
              // Contenido
              SafeArea(
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
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
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
                                    'Tu Progreso',
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Descubre cómo vas con tus hábitos',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w400,
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
            ],
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

  Widget _buildAnimatedPeriodSelector() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: _fadeController,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildModernPeriodButton('Semana', 'week', Icons.calendar_view_week),
                _buildModernPeriodButton('Mes', 'month', Icons.calendar_view_month),
                _buildModernPeriodButton('Año', 'year', Icons.calendar_today),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildWeeklyAnalysisSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weekly_analysis')
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        
        final analysisData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        
        return SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeController,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primary.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.primary],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Resumen Semanal por Vito',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        MarkdownBody(
                          data: analysisData['summary'] ?? 'No hay resumen disponible.',
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: GoogleFonts.poppins(
                              fontSize: 15,
                              height: 1.6,
                              color: const Color(0xFF475569),
                            ),
                            strong: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernOverviewSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Expanded(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _scaleController,
                  curve: Curves.easeOutBack,
                ),
                child: _buildGlassStatCard(
                  'Total Hábitos',
                  stats['totalHabits'].toString(),
                  Icons.spa_rounded,
                  [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                  0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _scaleController,
                  curve: Curves.easeOutBack,
                ),
                child: _buildGlassStatCard(
                  'Completado',
                  '${stats['overallCompletionRate'].toStringAsFixed(0)}%',
                  Icons.trending_up_rounded,
                  [AppColors.success, AppColors.success.withOpacity(0.7)],
                  0.1,
                ),
              ),
            ),
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
    if (stats['categoryPerformance'].isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
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
                Text(
                  'Por Categoría',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.1),
                        Colors.blue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ...stats['categoryPerformance'].entries.map((entry) {
              final double progress = entry.value[1] > 0 
                  ? (entry.value[0] / entry.value[1]) 
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildModernCategoryBar(
                  entry.key,
                  progress,
                  _getGradientForCategory(entry.key),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantPerformanceSection(Map<String, dynamic> stats) {
    if (stats['habitPerformance'].isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFEAA7).withOpacity(0.3),
              const Color(0xFFDFE4EA).withOpacity(0.3),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Hábitos',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Tus mejores desempeños',
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD93D), Color(0xFFF6B93B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD93D).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ...List.generate(stats['habitPerformance'].length, (index) {
              final habit = stats['habitPerformance'][index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 800 + (index * 200)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildBeautifulHabitRanking(
                        habit['name'],
                        habit['rate'],
                        index + 1,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Widgets de soporte modernos ---

  Widget _buildModernPeriodButton(String label, String period, IconData icon) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedPeriod = period);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? const LinearGradient(
              colors: [AppColors.primary, AppColors.primary],
            ) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, List<Color> gradientColors, double delay) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 20),
                TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 1000),
                  tween: IntTween(begin: 0, end: int.tryParse(value.replaceAll('%', '')) ?? 0),
                  builder: (context, val, child) {
                    return Text(
                      value.contains('%') ? '$val%' : val.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
}