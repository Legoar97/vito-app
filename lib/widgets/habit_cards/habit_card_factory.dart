// lib/widgets/habit_cards/habit_card_factory.dart

import 'package:flutter/material.dart';
import 'simple_habit_card.dart';
import 'quantifiable_habit_card.dart';
import 'timed_habit_card.dart';

class HabitCardFactory {
  static Widget buildHabitCard({
    required String habitId,
    required Map<String, dynamic> data,
    required DateTime selectedDate,
    required Function(String, bool) onToggleSimple,
    required Function(String, int, int, int) onUpdateQuantifiable,
    required Function(String, int) onStartTimer,
    required Function() onStopTimer,
    required Function(String, Map<String, dynamic>) onEdit,
    required String? activeTimerHabitId,
    required int timerSecondsRemaining,
  }) {
    final habitType = data['type'] as String? ?? 'simple';
    
    switch (habitType) {
      case 'quantifiable':
        return QuantifiableHabitCard(
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          onUpdateProgress: onUpdateQuantifiable,
          onEdit: onEdit,
        );
        
      case 'timed':
        return TimedHabitCard(
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          onStartTimer: onStartTimer,
          onStopTimer: onStopTimer,
          onEdit: onEdit,
          isTimerActive: activeTimerHabitId == habitId,
          timerSecondsRemaining: timerSecondsRemaining,
        );
        
      case 'simple':
      default:
        return SimpleHabitCard(
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          onToggle: onToggleSimple,
          onEdit: onEdit,
        );
    }
  }
}