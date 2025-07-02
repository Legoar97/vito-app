import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/mood/mood_tracker_widget.dart';
import '../models/mood.dart';
import '../widgets/mood/cute_mood_icon.dart';

class MoodTrackerScreen extends StatefulWidget {
  const MoodTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  List<Map<String, dynamic>> _moodHistory = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    _loadMoodHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodHistory() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    // Cargar los últimos 30 días
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .where('timestamp', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _moodHistory = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupMoodsByDay() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var mood in _moodHistory) {
      final timestamp = (mood['timestamp'] as Timestamp).toDate();
      final dayKey = DateFormat('yyyy-MM-dd').format(timestamp);
      
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      grouped[dayKey]!.add(mood);
    }
    
    return grouped;
  }

  Widget _buildMoodCalendar() {
    final groupedMoods = _groupMoodsByDay();
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 20),
          _buildWeekDayLabels(),
          const SizedBox(height: 10),
          _buildCalendarGrid(firstWeekday, daysInMonth, groupedMoods),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            });
          },
          icon: Icon(Icons.chevron_left, color: AppColors.primary),
        ),
        Text(
          DateFormat('MMMM yyyy', 'es_ES').format(_selectedMonth),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
              );
            });
          },
          icon: Icon(Icons.chevron_right, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildWeekDayLabels() {
    final weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((day) {
        return Text(
          day,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(
    int firstWeekday,
    int daysInMonth,
    Map<String, List<Map<String, dynamic>>> groupedMoods,
  ) {
    List<Widget> dayWidgets = [];
    
    // Espacios vacíos antes del primer día
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }
    
    // Días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final dayMoods = groupedMoods[dayKey] ?? [];
      
      dayWidgets.add(_buildCalendarDay(day, dayMoods, date));
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarDay(
    int day,
    List<Map<String, dynamic>> moods,
    DateTime date,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final hasMoods = moods.isNotEmpty;
    
    // Obtener el mood predominante del día
    String? dominantMood;
    if (hasMoods) {
      // Usar el último mood registrado del día
      dominantMood = moods.first['mood'];
    }
    
    final mood = dominantMood != null
        ? MoodData.moods.firstWhere(
            (m) => m.name == dominantMood,
            orElse: () => MoodData.moods.first,
          )
        : null;
    
    return GestureDetector(
      onTap: hasMoods ? () => _showDayMoods(date, moods) : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.primary.withOpacity(0.1)
              : (hasMoods ? mood!.baseColor.withOpacity(0.1) : null),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? AppColors.primary
                : (hasMoods ? mood!.baseColor.withOpacity(0.3) : Colors.transparent),
            width: isToday ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              day.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                color: isToday
                    ? AppColors.primary
                    : (hasMoods ? mood!.baseColor : Colors.grey[600]),
              ),
            ),
            if (hasMoods && mood != null)
              Positioned(
                bottom: 4,
                child: CuteMoodIcon(
                  color: mood.baseColor,
                  expression: mood.expression,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayMoods(DateTime date, List<Map<String, dynamic>> moods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('d MMMM yyyy', 'es_ES').format(date),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            ...moods.map((moodData) {
              final timestamp = (moodData['timestamp'] as Timestamp).toDate();
              final moodName = moodData['mood'];
              final mood = MoodData.moods.firstWhere(
                (m) => m.name == moodName,
                orElse: () => MoodData.moods.first,
              );
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CuteMoodIcon(
                      color: mood.baseColor,
                      expression: mood.expression,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mood.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: mood.baseColor,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
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
  }

  Widget _buildMoodStats() {
    if (_moodHistory.isEmpty) {
      return Container();
    }

    // Calcular estadísticas
    Map<String, int> moodCounts = {};
    for (var moodData in _moodHistory) {
      final mood = moodData['mood'] as String;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    // Encontrar el mood más común
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: mostCommonMoodData.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mostCommonMoodData.baseColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CuteMoodIcon(
            color: Colors.white,
            expression: mostCommonMoodData.expression,
            size: 48,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu ánimo predominante',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  mostCommonMoodData.name,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$maxCount veces en los últimos 30 días',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Registro de Ánimo',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Widget del mood tracker
                  MoodTrackerWidget(
                    animationController: _animationController,
                    onMoodSaved: (mood) {
                      // Recargar el historial cuando se guarda un nuevo mood
                      _loadMoodHistory();
                    },
                  ),
                  
                  // Estadísticas
                  if (_moodHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 1.0),
                      ),
                      child: _buildMoodStats(),
                    ),
                  ],
                  
                  // Calendario
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.6, 1.0),
                    ),
                    child: _buildMoodCalendar(),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}