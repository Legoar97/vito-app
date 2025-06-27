import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class HabitCard extends StatelessWidget {
  final String habitId;
  final String name;
  final String category;
  final bool isCompleted;
  final TimeOfDay? scheduledTime;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final IconData? icon;

  const HabitCard({
    super.key,
    required this.habitId,
    required this.name,
    required this.category,
    required this.isCompleted,
    this.scheduledTime,
    required this.onTap,
    required this.onLongPress,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(category);
    final categoryIcon = icon ?? AppColors.getCategoryIcon(category);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted ? color : Colors.grey[200]!,
                width: 2,
              ),
              boxShadow: [
                if (!isCompleted)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Checkbox with animation
                _buildCheckbox(color),
                const SizedBox(width: 16),
                
                // Habit details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? color : Colors.black87,
                          decoration: isCompleted 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                      if (scheduledTime != null)
                        Text(
                          _formatTime(scheduledTime!),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Category indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted ? color : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isCompleted
            ? const Icon(
                Icons.check,
                key: ValueKey('check'),
                color: Colors.white,
                size: 20,
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

// Mini version for lists or summaries
class MiniHabitCard extends StatelessWidget {
  final String name;
  final String category;
  final bool isCompleted;
  final VoidCallback? onTap;

  const MiniHabitCard({
    super.key,
    required this.name,
    required this.category,
    required this.isCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(category);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCompleted ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? color : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: isCompleted ? color : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? color : Colors.black87,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}