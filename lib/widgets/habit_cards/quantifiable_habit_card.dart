// lib/widgets/habit_cards/quantifiable_habit_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class QuantifiableHabitCard extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> data; // Estandarizado a 'data'
  final DateTime selectedDate;
  final Function(String, int) onUpdateProgress;
  final Function(String, Map<String, dynamic>) onLongPress;

  const QuantifiableHabitCard({
    super.key,
    required this.habitId,
    required this.data, // Estandarizado a 'data'
    required this.selectedDate,
    required this.onUpdateProgress,
    required this.onLongPress,
  });

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () => onLongPress(habitId, data),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!, width: 1.5),
              boxShadow: [
                 BoxShadow(
                  color: isCompleted ? color.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      ),
                    ),
                    Text(
                      '$currentProgress / $target ${unit.isNotEmpty ? unit : ''}',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 10,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => onUpdateProgress(habitId, -1),
                      icon: Icon(Icons.remove_circle_outline, color: Colors.grey[400]),
                    ),
                    IconButton(
                      iconSize: 36,
                      onPressed: isCompleted ? null : () => onUpdateProgress(habitId, 1),
                      icon: Icon(Icons.add_circle, color: isCompleted ? Colors.grey[400] : color),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}