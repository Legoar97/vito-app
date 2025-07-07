// lib/services/notification_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_service.dart';

// Esta función debe estar FUERA de la clase para que Firebase la pueda llamar en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Notificación recibida en segundo plano: ${message.messageId}");
}

class NotificationService {
  // Instancia para notificaciones locales
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Instancia para notificaciones de Firebase (push)
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // ID fijo para el recordatorio de ánimo
  static const int _moodReminderId = 99;

  // Se llama una vez desde main.dart
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification_icon');
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
    
    // Configura el manejador para cuando la app está cerrada o en segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // --- SECCIÓN DE FIREBASE CLOUD MESSAGING (Notificaciones Push) ---

  // Llama a esta función después de un login/signup exitoso
  static Future<void> initializeAndSaveToken(String userId) async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        print('Token de Firebase Messaging: $fcmToken');
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {'fcmToken': fcmToken}, 
            SetOptions(merge: true)
          );
        } catch (e) {
          print('Error al guardar token FCM: $e');
        }
      }
    }
  }

  // Se llama una vez desde main.dart para escuchar notificaciones con la app abierta
  static void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificación Push recibida en primer plano!');
      if (message.notification != null) {
        showInstantNotification(
          title: message.notification!.title ?? 'Nueva Notificación',
          body: message.notification!.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  // --- SECCIÓN DE NOTIFICACIONES LOCALES (Recordatorios) ---

  static void _onNotificationTap(NotificationResponse response) async {
    debugPrint('Notification tapped with payload: ${response.payload}');
    if (response.payload == null || response.payload!.isEmpty) return;

    final payloadData = jsonDecode(response.payload!);
    final String? habitId = payloadData['habitId'];
    
    if (habitId != null && response.actionId == 'COMPLETE_ACTION') {
      debugPrint('Completando hábito $habitId desde la notificación');
      try {
        await FirestoreService.toggleHabitCompletion(habitId, DateTime.now());
      } catch (e) {
        debugPrint('Error al completar hábito desde la notificación: $e');
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
      final scheduledTime = _nextInstanceOfWeekdayTime(day, time);
      final reminderTime = scheduledTime.subtract(const Duration(minutes: 5));

      if (reminderTime.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }
      
      await _notifications.zonedSchedule(
        habitId.hashCode + day,
        'En 5 minutos: $habitName',
        '¡Prepárate! Tu hábito está por comenzar.',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habit_reminders',
            'Recordatorios de Hábitos',
            channelDescription: 'Notificaciones para tus hábitos diarios',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[AndroidNotificationAction('COMPLETE_ACTION', 'Marcar como completado')],
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> scheduleDailyMoodReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'mood_reminder_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    if (prefs.getBool(todayKey) ?? false) return;
    
    await _notifications.zonedSchedule(
      _moodReminderId,
      '¿Cómo te fue hoy? 💭',
      'Tómate un momento para registrar tu estado de ánimo en Vito.',
      _nextInstanceOfTime(20, 0), // 8 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_reminders',
          'Recordatorios de Ánimo',
          channelDescription: 'Recordatorios para registrar tu estado de ánimo.',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    await prefs.setBool(todayKey, true);
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

  // --- FUNCIONES AUXILIARES DE TIEMPO (Ahora más confiables) ---

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}