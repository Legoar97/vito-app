// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'firestore_service.dart'; 

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // ID único y fijo para la notificación de recordatorio de ánimo
  static const int _moodReminderId = 99;

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  static Future<void> requestPermissions() async {
    // Tu código para solicitar permisos es perfecto, se mantiene igual.
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static void _onNotificationTap(NotificationResponse response) async {
    // Tu código para manejar el tap es perfecto, se mantiene igual.
    debugPrint('Notification tapped with payload: ${response.payload}');
    if (response.payload == null || response.payload!.isEmpty) return;

    final payloadData = jsonDecode(response.payload!);
    final String? habitId = payloadData['habitId'];
    
    if (habitId != null && response.actionId == 'COMPLETE_ACTION') {
      debugPrint('Completing habit $habitId from notification');
      try {
        await FirestoreService.toggleHabitCompletion(habitId, DateTime.now());
        debugPrint('Habit $habitId completed successfully.');
      } catch (e) {
        debugPrint('Error completing habit from notification: $e');
      }
    }
  }

  static Future<void> scheduleHabitNotification({
    required String habitId,
    required String habitName,
    required TimeOfDay time,
    required List<int> days,
  }) async {
    // Tu código para programar notificaciones de hábitos es excelente, se mantiene igual.
    final payload = jsonEncode({'habitId': habitId});
    for (final day in days) {
      final id = habitId.hashCode + day;
      await _notifications.zonedSchedule(
        id,
        'Hora de: $habitName',
        '¡Mantén tu racha! Es momento de completar tu hábito.',
        _nextInstanceOfWeekdayTime(day, time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habit_reminders',
            'Recordatorios de Hábitos',
            channelDescription: 'Notificaciones para tus hábitos diarios',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: Color(0xFF6B5B95),
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            actions: <AndroidNotificationAction>[AndroidNotificationAction('COMPLETE_ACTION', 'Marcar como completado')],
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true, categoryIdentifier: 'HABIT_REMINDER_CATEGORY'),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // --- NUEVA FUNCIÓN PARA PROGRAMAR EL RECORDATORIO DE ÁNIMO ---
  static Future<void> scheduleDailyMoodReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'mood_reminder_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

    // 1. Verificamos si ya hemos programado el recordatorio para hoy
    if (prefs.getBool(todayKey) ?? false) {
      print('El recordatorio de ánimo para hoy ya fue programado.');
      return;
    }

    // 2. Programamos la notificación para las 8 PM (20:00)
    await _notifications.zonedSchedule(
      _moodReminderId, // Usamos un ID fijo para poder cancelarlo
      '¿Cómo te fue hoy? 💭',
      'Tómate un momento para registrar tu estado de ánimo en Vito.',
      _nextInstanceOfTime(20, 0), // Llama al helper para las 8 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_reminders', // Un canal separado es una buena práctica
          'Recordatorios de Ánimo',
          channelDescription: 'Recordatorios para registrar tu estado de ánimo.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 3. Marcamos que ya se programó para hoy para no volverlo a hacer
    await prefs.setBool(todayKey, true);
    print('Recordatorio de ánimo programado para las 8 PM de hoy.');
  }

  // --- NUEVA FUNCIÓN PARA CANCELAR EL RECORDATORIO DE ÁNIMO ---
  static Future<void> cancelDailyMoodReminder() async {
     await _notifications.cancel(_moodReminderId);
     print('Recordatorio de ánimo para hoy (si existía) ha sido cancelado.');
  }

  // --- HELPERS Y OTRAS FUNCIONES (sin cambios) ---

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> cancelHabitNotifications(String habitId, List<int> days) async {
    for (final day in days) {
      await _notifications.cancel(habitId.hashCode + day);
    }
  }

  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
     await _notifications.show(
      DateTime.now().millisecond, // ID aleatorio para que no se sobreescriban
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_notifications',
          'Notificaciones Generales',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // He eliminado 'scheduleDailyNotification' ya que 'scheduleDailyMoodReminder'
  // es más específica y hace un trabajo similar. Si la usabas para otra cosa,
  // puedes mantenerla, pero esta nueva estructura es más clara.
}