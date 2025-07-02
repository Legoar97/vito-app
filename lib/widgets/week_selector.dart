// lib/widgets/week_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class WeekSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WeekSelector({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // El selector muestra 5 días con el día seleccionado en el centro
    final startDay = selectedDate.subtract(const Duration(days: 2));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final date = startDay.add(Duration(days: index));
        final isSelected = _isSameDay(date, selectedDate);
        final isToday = _isSameDay(date, DateTime.now());

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onDateSelected(date);
          },
          child: AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 50,
              height: 75,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isToday && !isSelected
                      ? Colors.white.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E('es_ES')
                        .format(date)
                        .substring(0, 2)
                        .toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d().format(date),
                    style: GoogleFonts.poppins(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}