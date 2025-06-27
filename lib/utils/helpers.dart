import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

class Helpers {
  // Date helpers
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static String formatDate(DateTime date, {String? format}) {
    return DateFormat(format ?? AppConstants.dateFormat, 'es_ES').format(date);
  }

  static String formatTime(TimeOfDay time, BuildContext context) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm('es_ES').format(dateTime);
  }

  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? "minuto" : "minutos"}';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? "hora" : "horas"}';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? "día" : "días"}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? "semana" : "semanas"}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? "mes" : "meses"}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace $years ${years == 1 ? "año" : "años"}';
    }
  }

  // String helpers
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - suffix.length)}$suffix';
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Number helpers
  static String formatPercentage(double value, {int decimals = 0}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  static String formatNumber(int number) {
    return NumberFormat.decimalPattern('es_ES').format(number);
  }

  // UI helpers
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration ?? AppConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
      ),
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDestructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : null,
            ),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(message ?? 'Cargando...'),
            ),
          ],
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Habit helpers
  static String getDayName(int weekday, {bool short = false}) {
    if (weekday < 1 || weekday > 7) return '';
    return short 
        ? AppConstants.weekDaysShort[weekday - 1]
        : AppConstants.weekDaysFull[weekday - 1];
  }

  static String getCategoryName(String category) {
    return AppConstants.categoryNames[category] ?? category;
  }

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String getMotivationalQuote() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final index = random % AppConstants.motivationalQuotes.length;
    return AppConstants.motivationalQuotes[index];
  }

  // Validation helpers
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu email';
    }
    if (!isValidEmail(value)) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'La contraseña debe tener al menos ${AppConstants.minPasswordLength} caracteres';
    }
    return null;
  }

  static String? validateHabitName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa un nombre';
    }
    if (value.length > AppConstants.maxHabitNameLength) {
      return 'El nombre es demasiado largo';
    }
    return null;
  }

  // Color helpers
  static Color darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  static Color lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  // Platform helpers
  static bool get isAndroid => Theme.of(NavigatorState().context).platform == TargetPlatform.android;
  static bool get isIOS => Theme.of(NavigatorState().context).platform == TargetPlatform.iOS;

  // Error handling
  static String getErrorMessage(String errorCode) {
    return AppConstants.errorMessages[errorCode] ?? 
           AppConstants.errorMessages['unknown']!;
  }

  static String getSuccessMessage(String successCode) {
    return AppConstants.successMessages[successCode] ?? 
           'Operación completada exitosamente';
  }
}