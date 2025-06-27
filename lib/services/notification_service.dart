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
      // <<< MEJORA >>> Manejador para cuando se toca la notificación
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // <<< NUEVO >>> Solicita permisos explícitamente
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

  // <<< MEJORA >>> El payload ahora contiene información para la acción
  static void _onNotificationTap(NotificationResponse response) async {
    debugPrint('Notification tapped with payload: ${response.payload}');
    if (response.payload == null || response.payload!.isEmpty) return;

    final payloadData = jsonDecode(response.payload!);
    final String? habitId = payloadData['habitId'];
    
    // Si la acción es completar, se llama a FirestoreService
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
    // <<< NUEVO >>> Payload con el ID del hábito para la interactividad
    final payload = jsonEncode({'habitId': habitId});

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
            icon: '@drawable/ic_notification', // Asegúrate que este ícono exista
            color: const Color(0xFF6B5B95),
            sound: const RawResourceAndroidNotificationSound('notification_sound'), // <<< NUEVO >>> Sonido personalizado
            // <<< MEJORA >>> Acciones interactivas
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'COMPLETE_ACTION',
                'Marcar como completado',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'HABIT_REMINDER_CATEGORY',
          ),
        ),
        payload: payload, // <<< MEJORA >>> Se añade el payload
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
    // ... (sin cambios)
  }
}
