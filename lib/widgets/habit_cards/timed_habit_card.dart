// lib/widgets/habit_cards/timed_habit_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class TimedHabitCard extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> data; // Estandarizado a 'data'
  final DateTime selectedDate;
  final Function(String, int) onStartTimer;
  final Function() onStopTimer;
  final Function(String, Map<String, dynamic>) onLongPress;
  final bool isTimerActive;
  final int timerSecondsRemaining;

  const TimedHabitCard({
    super.key,
    required this.habitId,
    required this.data, // Estandarizado a 'data'
    required this.selectedDate,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onLongPress,
    required this.isTimerActive,
    required this.timerSecondsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Sin nombre';
    final durationMinutes = data['targetValue'] as int? ?? 1;
    final category = data['category'] ?? 'health';
    final color = AppColors.getCategoryColor(category);
    
    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isCompleted = completionsMap[todayKey]?['completed'] as bool? ?? false;
    
    final minutesStr = (timerSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secondsStr = (timerSecondsRemaining % 60).toString().padLeft(2, '0');
    final timerText = '$minutesStr:$secondsStr';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () => onLongPress(habitId, data),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isTimerActive ? color.withOpacity(0.1) : (isCompleted ? color.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isTimerActive ? color.withOpacity(0.5) : (isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!), width: 1.5),
               boxShadow: [
                 BoxShadow(
                  color: (isTimerActive || isCompleted) ? color.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(isCompleted ? Icons.check_circle_rounded : Icons.timer_outlined, color: color, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (isTimerActive)
                        Text(timerText, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 18))
                      else
                        Text('$durationMinutes minutos', style: GoogleFonts.poppins(color: Colors.grey[600])),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                    elevation: 4,
                  ),
                  onPressed: isCompleted ? null : () {
                    if (isTimerActive) {
                      onStopTimer();
                    } else {
                      onStartTimer(habitId, durationMinutes);
                    }
                  },
                  child: Icon(
                    isCompleted ? Icons.celebration_rounded : (isTimerActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: 24,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}