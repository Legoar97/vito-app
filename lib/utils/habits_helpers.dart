// lib/utils/habits_helpers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'date_helpers.dart';

class HabitsHelpers {
  /// Calcula la racha actual de hábitos completados
  static int calculateStreak(List<QueryDocumentSnapshot> habits) {
    if (habits.isEmpty) return 0;

    final Set<DateTime> allCompletionDates = {};
    final Set<int> allScheduledWeekdays = {};

    // Recolectar todas las fechas de completado y días programados
    for (var habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};

      // Procesar completions
      for (var entry in completionsMap.entries) {
        final completionData = entry.value as Map<String, dynamic>;
        if (completionData['completed'] == true) {
          try {
            final date = DateFormat('yyyy-MM-dd').parse(entry.key);
            allCompletionDates.add(date);
          } catch (e) {
            // Ignorar fechas con formato incorrecto
          }
        }
      }

      // Recolectar días programados
      final days = List<int>.from(data['days'] ?? []);
      allScheduledWeekdays.addAll(days);
    }

    if (allCompletionDates.isEmpty || allScheduledWeekdays.isEmpty) return 0;

    // Calcular racha
    int streak = 0;
    var now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    // Si hoy es un día programado pero no está completado, empezar desde ayer
    if (allScheduledWeekdays.contains(checkDate.weekday) &&
        !allCompletionDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Contar días consecutivos hacia atrás
    for (int i = 0; i < 366; i++) {
      if (allScheduledWeekdays.contains(checkDate.weekday)) {
        if (allCompletionDates.contains(checkDate)) {
          streak++;
        } else {
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calcula el progreso del día seleccionado
  static Map<String, dynamic> calculateDayProgress(
    List<QueryDocumentSnapshot> allHabits,
    DateTime selectedDate,
  ) {
    int totalHabitsForDay = 0;
    int completedHabits = 0;

    for (var habit in allHabits) {
      final data = habit.data() as Map<String, dynamic>;
      final days = List<int>.from(data['days'] ?? []);

      if (days.contains(selectedDate.weekday)) {
        totalHabitsForDay++;

        final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
        final dateKey = DateHelpers.getCompletionKey(selectedDate);

        if (completionsMap[dateKey]?['completed'] == true) {
          completedHabits++;
        }
      }
    }

    return {
      'total': totalHabitsForDay,
      'completed': completedHabits,
      'progress': totalHabitsForDay > 0
          ? completedHabits / totalHabitsForDay
          : 0.0,
      'percentage': totalHabitsForDay > 0
          ? ((completedHabits / totalHabitsForDay) * 100).toInt()
          : 0,
    };
  }

  /// Filtra hábitos por día de la semana
  static List<QueryDocumentSnapshot> filterHabitsByDay(
    List<QueryDocumentSnapshot> allHabits,
    DateTime date,
  ) {
    return allHabits.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final days = List<int>.from(data?['days'] ?? []);
      return days.contains(date.weekday);
    }).toList();
  }

  /// Verifica si un hábito está completado en una fecha específica
  static bool isHabitCompletedOnDate(
    Map<String, dynamic> habitData,
    DateTime date,
  ) {
    final completionsMap = habitData['completions'] as Map<String, dynamic>? ?? {};
    final dateKey = DateHelpers.getCompletionKey(date);
    return completionsMap[dateKey]?['completed'] as bool? ?? false;
  }

  /// Obtiene el progreso de un hábito cuantificable en una fecha
  static int getQuantifiableProgress(
    Map<String, dynamic> habitData,
    DateTime date,
  ) {
    final completionsMap = habitData['completions'] as Map<String, dynamic>? ?? {};
    final dateKey = DateHelpers.getCompletionKey(date);
    return completionsMap[dateKey]?['progress'] as int? ?? 0;
  }

  /// Calcula estadísticas generales de hábitos
  static Map<String, dynamic> calculateHabitStats(
    List<QueryDocumentSnapshot> habits,
    {int daysToAnalyze = 30}
  ) {
    int totalCompletions = 0;
    int totalPossible = 0;
    final Map<String, int> categoryCompletions = {};
    final Map<String, int> categoryTotals = {};

    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: daysToAnalyze));

    for (var habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      final category = data['category'] as String? ?? 'other';
      final days = List<int>.from(data['days'] ?? []);
      final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};

      categoryCompletions[category] ??= 0;
      categoryTotals[category] ??= 0;

      // Analizar cada día en el rango
      for (int i = 0; i < daysToAnalyze; i++) {
        final checkDate = startDate.add(Duration(days: i));
        
        if (days.contains(checkDate.weekday)) {
          totalPossible++;
          categoryTotals[category] = categoryTotals[category]! + 1;

          final dateKey = DateHelpers.getCompletionKey(checkDate);
          if (completionsMap[dateKey]?['completed'] == true) {
            totalCompletions++;
            categoryCompletions[category] = categoryCompletions[category]! + 1;
          }
        }
      }
    }

    // Calcular porcentajes por categoría
    final Map<String, double> categoryPercentages = {};
    categoryTotals.forEach((category, total) {
      if (total > 0) {
        final completions = categoryCompletions[category] ?? 0;
        categoryPercentages[category] = (completions / total) * 100;
      }
    });

    return {
      'totalCompletions': totalCompletions,
      'totalPossible': totalPossible,
      'overallPercentage': totalPossible > 0
          ? ((totalCompletions / totalPossible) * 100).toInt()
          : 0,
      'categoryStats': categoryPercentages,
      'streak': calculateStreak(habits),
    };
  }

  /// Obtiene el mensaje motivacional basado en el progreso
  static String getMotivationalMessage(double progress) {
    if (progress == 0) {
      return '¡Empecemos el día con energía! 💪';
    } else if (progress < 0.25) {
      return '¡Buen comienzo! Sigue así 🌱';
    } else if (progress < 0.5) {
      return '¡Vas por buen camino! 🚀';
    } else if (progress < 0.75) {
      return '¡Excelente progreso! 🌟';
    } else if (progress < 1.0) {
      return '¡Casi lo logras! Un último esfuerzo 🎯';
    } else {
      return '¡Increíble! Has completado todos tus hábitos 🎉';
    }
  }

  /// Genera sugerencias de hábitos basadas en la categoría
  static List<String> getSuggestionsForCategory(String category) {
    final suggestions = {
      'Salud': [
        'Beber 8 vasos de agua',
        'Caminar 10,000 pasos',
        'Dormir 8 horas',
        'Estirar por 10 minutos',
        'Comer 5 porciones de frutas y verduras',
      ],
      'Mente': [
        'Meditar 10 minutos',
        'Escribir 3 cosas por las que estás agradecido',
        'Leer 20 páginas',
        'Practicar respiración profunda',
        'Desconectar de dispositivos 1 hora antes de dormir',
      ],
      'Trabajo': [
        'Revisar tareas del día',
        'Tomar descansos cada hora',
        'Organizar el escritorio',
        'Planificar el día siguiente',
        'Responder emails pendientes',
      ],
      'Creativo': [
        'Dibujar o garabatear 15 minutos',
        'Escribir 500 palabras',
        'Tomar una foto artística',
        'Aprender algo nuevo',
        'Practicar un instrumento',
      ],
      'Finanzas': [
        'Registrar gastos del día',
        'Revisar presupuesto semanal',
        'Ahorrar cantidad específica',
        'Leer noticias financieras',
        'Planificar compras del mes',
      ],
    };

    return suggestions[category] ?? [];
  }
}