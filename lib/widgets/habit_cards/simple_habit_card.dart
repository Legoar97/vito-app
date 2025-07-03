// lib/widgets/habit_cards/simple_habit_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class SimpleHabitCard extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> data; // Estandarizado a 'data'
  final DateTime selectedDate;
  final Function(String, bool) onToggle;
  final Function(String, Map<String, dynamic>) onLongPress;

  const SimpleHabitCard({
    super.key,
    required this.habitId,
    required this.data, // Estandarizado a 'data'
    required this.selectedDate,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Hábito sin nombre';
    final category = data['category'] ?? 'health';
    final timeData = data['specificTime'] as Map<String, dynamic>?;
    final color = AppColors.getCategoryColor(category);

    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isCompleted = completionsMap[dateKey]?['completed'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle(habitId, isCompleted),
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
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => onToggle(habitId, isCompleted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isCompleted ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
                      color: isCompleted ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Detalles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: color,
                        ),
                      ),
                      if (timeData != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(timeData),
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(Map<String, dynamic> timeData) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, timeData['hour'], timeData['minute']);
    return DateFormat.jm('es_ES').format(dateTime);
  }
}