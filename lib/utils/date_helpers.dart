// lib/utils/date_helpers.dart

import 'package:intl/intl.dart';

class DateHelpers {
  /// Compara si dos fechas son el mismo día
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Obtiene el nombre del día de la semana en español
  static String getDayName(DateTime date) {
    return DateFormat.EEEE('es_ES').format(date);
  }

  /// Obtiene el nombre corto del día (2 letras)
  static String getShortDayName(DateTime date) {
    return DateFormat.E('es_ES').format(date).substring(0, 2).toUpperCase();
  }

  /// Formatea una fecha en formato "d MMM"
  static String formatDayMonth(DateTime date) {
    return DateFormat('d MMM', 'es_ES').format(date);
  }

  /// Formatea una fecha en formato "d 'de' MMMM"
  static String formatDayOfMonth(DateTime date) {
    return DateFormat("d 'de' MMMM", 'es_ES').format(date);
  }

  /// Obtiene el formato de clave para completions (yyyy-MM-dd)
  static String getCompletionKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Formatea la hora en formato local
  static String formatTime(int hour, int minute) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat.jm('es_ES').format(dateTime);
  }

  /// Obtiene el inicio de la semana (lunes)
  static DateTime getWeekStart(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  /// Obtiene el fin de la semana (domingo)
  static DateTime getWeekEnd(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.add(Duration(days: 7 - dayOfWeek));
  }

  /// Calcula la diferencia en días entre dos fechas
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  /// Obtiene las fechas de la semana para el selector
  static List<DateTime> getWeekDates(DateTime selectedDate) {
    final startDay = selectedDate.subtract(const Duration(days: 2));
    return List.generate(5, (index) => startDay.add(Duration(days: index)));
  }

  /// Obtiene el día del año (1-366)
  static int getDayOfYear(DateTime date) {
    return int.parse(DateFormat("D").format(date));
  }

  /// Verifica si una fecha está en el pasado
  static bool isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    return compareDate.isBefore(today);
  }

  /// Verifica si una fecha es hoy
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Verifica si una fecha es mañana
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  /// Verifica si una fecha es ayer
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  /// Obtiene una descripción relativa de la fecha
  static String getRelativeDateDescription(DateTime date) {
    if (isToday(date)) return 'Hoy';
    if (isTomorrow(date)) return 'Mañana';
    if (isYesterday(date)) return 'Ayer';
    return formatDayMonth(date);
  }

  /// Formatea duración en minutos a texto legible
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutos';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours ${hours == 1 ? 'hora' : 'horas'}';
      } else {
        return '$hours ${hours == 1 ? 'hora' : 'horas'} y $mins minutos';
      }
    }
  }

  /// Formatea segundos en formato MM:SS
  static String formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}