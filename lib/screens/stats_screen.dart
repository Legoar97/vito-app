import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedPeriod = 'week';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.streamHabits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              _buildSliverAppBar(),
              _buildPeriodSelector(),
              // <<< NUEVO >>> Widget para el análisis semanal de la IA
              _buildWeeklyAnalysisSection(),
              _buildOverviewSection(processedStats),
              _buildCompletionChartSection(processedStats),
              _buildCategoryBreakdownSection(processedStats),
              _buildHabitsPerformanceSection(processedStats),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // --- Lógica de Procesamiento de Datos ---

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
  
  // --- Widgets de la UI ---

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
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
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Tu Progreso', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Rastrea tus hábitos y observa tu crecimiento', style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.9))),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.show_chart_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text('Aún no hay estadísticas', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('¡Empieza a registrar tus hábitos para ver tu progreso aquí!', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPeriodButton('Semana', 'week'),
            const SizedBox(width: 12),
            _buildPeriodButton('Mes', 'month'),
            const SizedBox(width: 12),
            _buildPeriodButton('Año', 'year'),
          ],
        ),
      ),
    );
  }
  
  // <<< NUEVO >>> Widget para mostrar el análisis semanal de la IA
  Widget _buildWeeklyAnalysisSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weekly_analysis') // La colección donde se guardará el análisis
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No muestra nada si no hay análisis disponible
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        
        final analysisData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        
        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.2))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text('Tu Resumen Semanal por Vito', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                // Se usa Markdown para dar formato al texto de la IA (negritas, listas, etc.)
                MarkdownBody(
                  data: analysisData['summary'] ?? 'No hay resumen disponible.',
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.5)
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard('Total Hábitos', stats['totalHabits'].toString(), Icons.track_changes, AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard('Completado General', '${stats['overallCompletionRate'].toStringAsFixed(0)}%', Icons.trending_up, AppColors.success),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionChartSection(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildCompletionChart(stats['weeklySpots']),
      ),
    );
  }

  Widget _buildCategoryBreakdownSection(Map<String, dynamic> stats) {
     return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: _buildCategoryBreakdown(stats['categoryPerformance']),
      ),
    );
  }
  
  Widget _buildHabitsPerformanceSection(Map<String, dynamic> stats) {
     return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildHabitsPerformance(stats['habitPerformance']),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCompletionChart(List<FlSpot> spots) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progreso Semanal', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
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
                        return SideTitleWidget(axisSide: meta.axisSide, child: Text(days[dayIndex], style: TextStyle(color: Colors.grey[600], fontSize: 12)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text('${value.toInt()}%', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(colors: [AppColors.gradientStart.withOpacity(0.2), AppColors.gradientEnd.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, List<int>> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Rendimiento por Categoría', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ...categories.entries.map((entry) {
            final double progress = entry.value[1] > 0 ? (entry.value[0] / entry.value[1]) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildCategoryBar(entry.key, progress, _getColorForCategory(entry.key)),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getColorForCategory(String category) {
      switch (category.toLowerCase()) {
        case 'salud': return AppColors.categoryHealth;
        case 'mente': return AppColors.categoryMind;
        case 'trabajo': return AppColors.categoryProductivity;
        case 'social': return AppColors.categoryRelationships;
        case 'creativo': return AppColors.categoryCreativity;
        case 'finanzas': return AppColors.categoryFinance;
        default: return Colors.grey;
      }
  }

  Widget _buildCategoryBar(String category, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitsPerformance(List<Map<String, dynamic>> habits) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mejores Hábitos', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const Icon(Icons.emoji_events, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(habits.length, (index) {
              final habit = habits[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildHabitRanking(habit['name'], habit['rate'], index + 1),
              );
          }),
        ],
      ),
    );
  }

  Widget _buildHabitRanking(String habit, int percentage, int rank) {
    Color rankColor;
    switch (rank) {
      case 1: rankColor = const Color(0xFFFFD700); break;
      case 2: rankColor = const Color(0xFFC0C0C0); break;
      case 3: rankColor = const Color(0xFFCD7F32); break;
      default: rankColor = Colors.grey;
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: rankColor,
          child: Text(rank.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(habit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        Text('$percentage%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
