import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../models/mood.dart';
import '../../models/mood_entry.dart';
import 'cute_mood_icon.dart';

class MoodCalendarWidget extends StatefulWidget {
  final List<MoodEntry> moodHistory;

  const MoodCalendarWidget({
    Key? key,
    required this.moodHistory,
  }) : super(key: key);

  @override
  State<MoodCalendarWidget> createState() => _MoodCalendarWidgetState();
}

class _MoodCalendarWidgetState extends State<MoodCalendarWidget> {
  DateTime _selectedMonth = DateTime.now();

  Map<String, List<MoodEntry>> _groupMoodsByDay() {
    Map<String, List<MoodEntry>> grouped = {};
    
    for (var entry in widget.moodHistory) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      grouped[dayKey]!.add(entry);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 20),
          _buildLegend(),
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
    Map<String, List<MoodEntry>> groupedMoods,
  ) {
    List<Widget> dayWidgets = [];
    
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }
    
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
    List<MoodEntry> moods,
    DateTime date,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final hasMoods = moods.isNotEmpty;
    
    String? dominantMood;
    if (hasMoods) {
      dominantMood = moods.first.mood;
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
            if (moods.length > 1)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${moods.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayMoods(DateTime date, List<MoodEntry> moods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('d MMMM yyyy', 'es_ES').format(date),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: moods.length,
                itemBuilder: (context, index) {
                  final entry = moods[index];
                  final mood = MoodData.moods.firstWhere(
                    (m) => m.name == entry.mood,
                    orElse: () => MoodData.moods.first,
                  );
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: mood.baseColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: mood.baseColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CuteMoodIcon(
                              color: mood.baseColor,
                              expression: mood.expression,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
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
                                    DateFormat('HH:mm').format(entry.timestamp),
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
                        if (entry.aiResponse != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: mood.baseColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.aiResponse!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (entry.journalEntry != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Mi diario:',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.journalEntry!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Leyenda de estados',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: MoodData.moods.take(4).map((mood) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CuteMoodIcon(
                    color: mood.baseColor,
                    expression: mood.expression,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mood.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: mood.baseColor,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}