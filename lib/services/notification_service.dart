// lib/services/notification_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Zonas horarias
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Permisos
import 'package:permission_handler/permission_handler.dart';

// Tu servicio de Firestore
import 'firestore_service.dart';

/// Handler para mensajes push en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 BG Message: ${message.messageId}");
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _firebaseMessaging = FirebaseMessaging.instance;

  static const _habitChannelId     = 'habit_reminders';
  static const _moodChannelId      = 'mood_reminders';
  static const _generalChannelId   = 'general_notifications';
  static const int _moodReminderId = 99;

  /// ——————————————————————
  /// 1) Inicialización general
  /// ——————————————————————
  /// Llama esto UNA VEZ desde main() antes de usar cualquier otra cosa.
  static Future<void> initialize() async {
    // 1. Zonas horarias
    tz.initializeTimeZones();
    final String locName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(locName));

    // 2. Crear canales (Android 8+)
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _habitChannelId,
          'Recordatorios de Hábitos',
          description: 'Notificaciones para tus hábitos diarios',
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _moodChannelId,
          'Recordatorios de Ánimo',
          description: 'Notificaciones para registrar tu estado de ánimo.',
          importance: Importance.defaultImportance,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          'Notificaciones Generales',
          description: 'Alertas y mensajes generales de la app.',
          importance: Importance.max,
        ),
      );
    }

    // 3. Inicializar plugin local notifications
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 4. Configurar FirebaseMessaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// ——————————————————————
  /// 2) Permisos en Android 13+ 
  /// ——————————————————————
  /// Pide POST_NOTIFICATIONS y SCHEDULE_EXACT_ALARM antes de programar.
  static Future<bool> requestNotificationPermissions() async {
    final notifStatus  = await Permission.notification.request();
    final alarmStatus  = await Permission.scheduleExactAlarm.request();

    if (notifStatus.isGranted && alarmStatus.isGranted) {
      return true;
    }
    if (notifStatus.isPermanentlyDenied || alarmStatus.isPermanentlyDenied) {
      openAppSettings();
    }
    return false;
  }

  /// ——————————————————————
  /// 3) Token FCM y Firestore
  /// ——————————————————————
  /// Llama después del login/signup, pasándole el userId.
  static Future<void> initializeAndSaveToken(String userId) async {
    // Pide permiso de push (iOS / Android)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({'fcmToken': fcmToken}, SetOptions(merge: true));
          debugPrint('✅ FCM token saved for $userId');
        } catch (e) {
          debugPrint('❌ Error saving FCM token: $e');
        }
      }
    }
  }

  /// ——————————————————————
  /// 4) Mensajes en foreground
  /// ——————————————————————
  static void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (msg.notification != null) {
        showInstantNotification(
          title: msg.notification!.title  ?? 'Notificación',
          body:  msg.notification!.body   ?? '',
          payload: jsonEncode(msg.data),
        );
      }
    });
  }

  /// ——————————————————————
  /// 5) Notificaciones locales
  /// ——————————————————————

  /// a) Agendar recordatorio de hábito
  static Future<void> scheduleHabitNotification({
    required String habitId,
    required String habitName,
    required TimeOfDay time,
    required List<int> days,
  }) async {
    final String payload = jsonEncode({'habitId': habitId});

    for (final day in days) {
      final tz.TZDateTime scheduled = _nextWeekday(day, time)
          .subtract(const Duration(minutes: 5));
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) continue;

      await _notifications.zonedSchedule(
        habitId.hashCode + day,
        'En 5 minutos: $habitName',
        '¡Prepárate! Tu hábito está por comenzar.',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _habitChannelId,
            'Recordatorios de Hábitos',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('COMPLETE_ACTION', 'Marcar como completado'),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// b) Agendar recordatorio diario de ánimo (8 PM)
  static Future<void> scheduleDailyMoodReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mood_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    if (prefs.getBool(key) ?? false) return;

    await _notifications.zonedSchedule(
      _moodReminderId,
      '¿Cómo te fue hoy? 💭',
      'Tómate un momento para registrar tu estado de ánimo.',
      _nextTime(20, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(_moodChannelId, 'Recordatorios de Ánimo'),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await prefs.setBool(key, true);
  }

  /// c) Cancelar notificaciones de hábito
  static Future<void> cancelHabitNotifications(String habitId, List<int> days) =>
      Future.wait(days.map((d) => _notifications.cancel(habitId.hashCode + d)));

  /// d) Notificación instantánea (test o push)
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().microsecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId,
          'Notificaciones Generales',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// ——————————————————————
  /// 6) Tap en notificación
  /// ——————————————————————
  static void _onNotificationTap(NotificationResponse response) async {
    if (response.payload?.isEmpty ?? true) return;
    final data = jsonDecode(response.payload!);
    final String? habitId = data['habitId'];
    if (response.actionId == 'COMPLETE_ACTION' && habitId != null) {
      try {
        await FirestoreService.toggleHabitCompletion(habitId, DateTime.now());
      } catch (e) {
        debugPrint('Error completando hábito: $e');
      }
    }
  }

  /// ——————————————————————
  /// 7) Helpers de tiempo
  /// ——————————————————————
  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var sched = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (sched.isBefore(now)) sched = sched.add(const Duration(days: 1));
    return sched;
  }

  static tz.TZDateTime _nextWeekday(int weekday, TimeOfDay t) {
    var now = tz.TZDateTime.now(tz.local);
    var sched = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    while (sched.weekday != weekday || sched.isBefore(now)) {
      sched = sched.add(const Duration(days: 1));
    }
    return sched;
  }
}
