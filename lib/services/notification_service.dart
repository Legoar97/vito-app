import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize timezone
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

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    debugPrint('Notification tapped: ${response.payload}');
  }

  static Future<void> scheduleHabitNotification({
    required String habitId,
    required String habitName,
    required TimeOfDay time,
    required List<int> days,
  }) async {
    for (final day in days) {
      final id = habitId.hashCode + day;
      
      await _notifications.zonedSchedule(
        id,
        'Hora de: $habitName',
        '¡Mantén tu racha! Es momento de completar tu hábito.',
        _nextInstanceOfWeekdayTime(day, time),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'habit_reminders',
            'Recordatorios de Hábitos',
            channelDescription: 'Notificaciones para tus hábitos diarios',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF6B5B95),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
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

    // Find next instance of the weekday
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
    const androidDetails = AndroidNotificationDetails(
      'instant_notifications',
      'Notificaciones Instantáneas',
      channelDescription: 'Notificaciones importantes de la app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: Color(0xFF6B5B95),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}