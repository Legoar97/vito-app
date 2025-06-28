// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'firestore_service.dart'; 

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  static Future<void> requestPermissions() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
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
            showWhen: true,
            icon: '@drawable/ic_notification',
            color: Color(0xFF6B5B95),
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'COMPLETE_ACTION',
                'Marcar como completado',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'HABIT_REMINDER_CATEGORY',
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // CORRECCIÓN: Se añade el método que faltaba
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Recordatorios Diarios',
          channelDescription: 'Recordatorios diarios generales',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

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
      0,
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