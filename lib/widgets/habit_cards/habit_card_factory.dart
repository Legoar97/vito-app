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
    
    // Los callbacks siguen siendo opcionales (nulables)
    Function(String, bool)? onToggleSimple,
    Function(String, int)? onUpdateQuantifiable,
    Function(String, int)? onStartTimer,
    Function()? onStopTimer,
    
    required Function(String, Map<String, dynamic>) onLongPress,
    
    // State
    required String? activeTimerHabitId,
    required int timerSecondsRemaining,
  }) {
    final habitType = data['type'] as String? ?? 'simple';
    
    switch (habitType) {
      case 'quantifiable':
        return QuantifiableHabitCard(
          key: ValueKey('quant-$habitId'),
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          // --- CORRECCIÓN ---
          // Si onUpdateQuantifiable es nulo, le pasamos una función vacía que no hace nada.
          // Esto satisface el requisito de que el parámetro no sea nulo.
          onUpdateProgress: onUpdateQuantifiable ?? (id, value) {},
          onLongPress: onLongPress,
        );
        
      case 'timed':
        return TimedHabitCard(
          key: ValueKey('timed-$habitId'),
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          // --- CORRECCIÓN ---
          // Hacemos lo mismo para los callbacks del temporizador.
          onStartTimer: onStartTimer ?? (id, value) {},
          onStopTimer: onStopTimer ?? () {},
          onLongPress: onLongPress,
          isTimerActive: activeTimerHabitId == habitId,
          timerSecondsRemaining: timerSecondsRemaining,
        );
        
      case 'simple':
      default:
        return SimpleHabitCard(
          key: ValueKey('simple-$habitId'),
          habitId: habitId,
          data: data,
          selectedDate: selectedDate,
          // --- CORRECCIÓN ---
          // Y finalmente para el hábito simple.
          onToggle: onToggleSimple ?? (id, value) {},
          onLongPress: onLongPress,
        );
    }
  }
}