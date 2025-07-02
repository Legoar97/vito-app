// lib/screens/habits/widgets/habit_cards/quantifiable_habit_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_colors.dart';

class QuantifiableHabitCard extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> data;
  final DateTime selectedDate;
  final Function(String, int, int, int) onUpdateProgress;
  final Function(String, Map<String, dynamic>) onEdit;

  const QuantifiableHabitCard({
    Key? key,
    required this.habitId,
    required this.data,
    required this.selectedDate,
    required this.onUpdateProgress,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Sin nombre';
    final target = data['targetValue'] as int? ?? 1;
    final unit = data['unit'] as String? ?? '';
    final category = data['category'] ?? 'health';
    final color = AppColors.getCategoryColor(category);

    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final currentProgress = completionsMap[todayKey]?['progress'] as int? ?? 0;
    final isCompleted = currentProgress >= target;
    final progressPercent = target > 0 ? (currentProgress / target) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onEdit(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCompleted
                      ? color.withOpacity(0.15)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(name, currentProgress, target, unit, color),
                const SizedBox(height: 16),
                _buildProgressBar(progressPercent, color),
                const SizedBox(height: 8),
                _buildControls(currentProgress, target, color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, int current, int target, String unit, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        Text(
          '$current / $target ${unit.isNotEmpty ? unit : ''}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: color.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildControls(int current, int target, Color color) {
    final canEdit = _isSameDay(selectedDate, DateTime.now());
    final isCompleted = current >= target;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: canEdit && current > 0
              ? () => onUpdateProgress(habitId, current, target, -1)
              : null,
          icon: Icon(
            Icons.remove_circle_outline,
            color: canEdit && current > 0 ? Colors.grey[400] : Colors.grey[300],
          ),
        ),
        IconButton(
          iconSize: 36,
          onPressed: canEdit && !isCompleted
              ? () => onUpdateProgress(habitId, current, target, 1)
              : null,
          icon: Icon(
            Icons.add_circle,
            color: canEdit && !isCompleted ? color : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// lib/screens/habits/widgets/habit_cards/timed_habit_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_colors.dart';

class TimedHabitCard extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> data;
  final DateTime selectedDate;
  final Function(String, int) onStartTimer;
  final Function() onStopTimer;
  final Function(String, Map<String, dynamic>) onEdit;
  final bool isTimerActive;
  final int timerSecondsRemaining;

  const TimedHabitCard({
    Key? key,
    required this.habitId,
    required this.data,
    required this.selectedDate,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onEdit,
    required this.isTimerActive,
    required this.timerSecondsRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Sin nombre';
    final durationMinutes = data['targetValue'] as int? ?? 1;
    final category = data['category'] ?? 'health';
    final color = AppColors.getCategoryColor(category);

    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isCompleted = completionsMap[todayKey]?['completed'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onEdit(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isTimerActive
                  ? color.withOpacity(0.1)
                  : (isCompleted ? color.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isTimerActive
                    ? color.withOpacity(0.5)
                    : (isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isTimerActive || isCompleted)
                      ? color.withOpacity(0.15)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildIcon(isCompleted, color),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildContent(
                    name,
                    durationMinutes,
                    isTimerActive,
                    color,
                  ),
                ),
                _buildTimerButton(
                  isCompleted,
                  isTimerActive,
                  durationMinutes,
                  color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isCompleted, Color color) {
    return Icon(
      isCompleted ? Icons.check_circle_rounded : Icons.timer_outlined,
      color: color,
      size: 28,
    );
  }

  Widget _buildContent(
    String name,
    int durationMinutes,
    bool isActive,
    Color color,
  ) {
    final minutesStr = (timerSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secondsStr = (timerSecondsRemaining % 60).toString().padLeft(2, '0');
    final timerText = '$minutesStr:$secondsStr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isActive)
          Text(
            timerText,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          )
        else
          Text(
            '$durationMinutes minutos',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildTimerButton(
    bool isCompleted,
    bool isActive,
    int durationMinutes,
    Color color,
  ) {
    final canEdit = _isSameDay(selectedDate, DateTime.now());

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        elevation: 5,
        shadowColor: color.withOpacity(0.5),
      ),
      onPressed: !canEdit || isCompleted
          ? null
          : () {
              if (isActive) {
                onStopTimer();
              } else {
                HapticFeedback.heavyImpact();
                onStartTimer(habitId, durationMinutes);
              }
            },
      child: Icon(
        isCompleted
            ? Icons.celebration_rounded
            : (isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
        color: Colors.white,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}