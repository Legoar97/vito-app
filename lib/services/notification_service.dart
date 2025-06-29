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
    
    // ================== ¡CORRECCIÓN CLAVE #1! ==================
    // Aquí establecemos el ícono por defecto para TODAS las notificaciones de Android.
    // Debe apuntar al ícono blanco y transparente que creamos en la carpeta 'drawable'.
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification_icon');
    // ==========================================================

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
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static void _onNotificationTap(NotificationResponse response) async {
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
            // ================== ¡CORRECCIÓN CLAVE #2! ==================
            // Se elimina la línea 'icon: ...' de aquí.
            // ¿Por qué? Para que la notificación use automáticamente el ícono por defecto
            // que definimos arriba en 'initialize()'. Esto hace el código más limpio,
            // seguro y consistente.
            // ==========================================================
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

  // --- El resto de tu código está perfecto y no necesita cambios ---

  static Future<void> scheduleDailyMoodReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'mood_reminder_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

    if (prefs.getBool(todayKey) ?? false) {
      print('El recordatorio de ánimo para hoy ya fue programado.');
      return;
    }

    await _notifications.zonedSchedule(
      _moodReminderId,
      '¿Cómo te fue hoy? 💭',
      'Tómate un momento para registrar tu estado de ánimo en Vito.',
      _nextInstanceOfTime(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_reminders',
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

    await prefs.setBool(todayKey, true);
    print('Recordatorio de ánimo programado para las 8 PM de hoy.');
  }

  static Future<void> cancelDailyMoodReminder() async {
     await _notifications.cancel(_moodReminderId);
     print('Recordatorio de ánimo para hoy (si existía) ha sido cancelado.');
  }

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
      DateTime.now().millisecond,
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
}