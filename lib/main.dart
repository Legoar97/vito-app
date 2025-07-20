// main.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/mood_tracker_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/vertex_ai_service.dart';
import 'l10n/app_localizations.dart';

import 'providers/user_profile_provider.dart';

// --- SECCIÓN DEL SERVICIO EN SEGUNDO PLANO (SIN CAMBIOS) ---
final FlutterLocalNotificationsPlugin serviceNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vito_foreground_service',
    'Vito Tareas en Segundo Plano',
    description: 'Canal para mantener los temporizadores de Vito activos.',
    importance: Importance.min,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  await serviceNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidNotificationChannel completionChannel = AndroidNotificationChannel(
    'vito_timer_complete',
    'Temporizador Completado',
    description: 'Notificaciones cuando se completa un temporizador',
    importance: Importance.high,
  );

  await serviceNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(completionChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'vito_foreground_service',
      initialNotificationTitle: 'Vito',
      initialNotificationContent: 'Iniciando temporizador...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  final player = AudioPlayer();
  Timer? activeTimer;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on('startTimer').listen((event) {
    activeTimer?.cancel();
    if (event == null) return;

    final duration = event['duration'] as int? ?? 0;
    final taskName = event['taskName'] as String? ?? 'Tarea';
    var remaining = duration;

    activeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      service.invoke('timerUpdate', {'remaining': remaining, 'taskName': taskName});
      if (remaining % 10 == 0 && service is AndroidServiceInstance) {
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        service.setForegroundNotificationInfo(
          title: "Timer activo: $taskName",
          content: "Tiempo restante: $minutes:${seconds.toString().padLeft(2, '0')}",
        );
      }
      if (remaining <= 0) {
        timer.cancel();
        activeTimer = null;
        service.invoke('timerComplete', {'taskName': taskName});
        try { player.play(AssetSource('sounds/completion_sound.mp3')); } catch (e) { print('Error al reproducir sonido: $e'); }
        _showCompletionNotification(taskName);
        service.stopSelf();
      }
    });
  });

  service.on('stopTimer').listen((event) {
    activeTimer?.cancel();
    activeTimer = null;
    service.invoke('timerStopped');
    service.stopSelf();
  });

  service.on('stopService').listen((event) {
    activeTimer?.cancel();
    player.dispose();
    service.stopSelf();
  });
}

Future<void> _showCompletionNotification(String taskName) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'vito_timer_complete',
    'Temporizador Completado',
    channelDescription: 'Notificaciones cuando se completa un temporizador',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@drawable/ic_notification_icon',
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );
  await serviceNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    '¡Temporizador completado!',
    '$taskName ha terminado',
    notificationDetails,
  );
}

// --- FIN SECCIÓN DEL SERVICIO EN SEGUNDO PLANO ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  final granted = await NotificationService.requestNotificationPermissions();
  if (!granted) {
    print('⚠️ Permisos de notificación NO concedidos. Las notificaciones no funcionarán.');
  }
  NotificationService.handleForegroundMessages();

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null && user.emailVerified) {
      print("Usuario verificado (${user.uid}), inicializando token para notificaciones push.");
      NotificationService.initializeAndSaveToken(user.uid);
    }
  });
  
  await VertexAIService.initialize();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/ic_notification_icon');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: DarwinInitializationSettings());
  await serviceNotificationsPlugin.initialize(initializationSettings);
  
  await initializeBackgroundService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
      ],
      child: const VitoApp(),
    ),
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class VitoApp extends StatelessWidget {
  const VitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'Vito',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Esta es la línea que se corrigió:
      themeMode: themeProvider.themeMode, 
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
    GoRoute(
      path: '/home',
      builder: (context, state) => MainNavigationScreen(initialIndex: state.extra as int? ?? 0),
      routes: [
        GoRoute(path: 'achievements', builder: (context, state) => const AchievementsScreen()),
        GoRoute(path: 'mood-tracker', builder: (context, state) => const MoodTrackerScreen()),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null &&
                        FirebaseAuth.instance.currentUser!.emailVerified;
    
    final isGoingToAuth = state.matchedLocation == '/login' ||
                           state.matchedLocation == '/signup' ||
                           state.matchedLocation == '/verify-email';

    if (!isLoggedIn && !isGoingToAuth) return '/login';
    if (isLoggedIn && isGoingToAuth) return '/home';

    return null;
  },
);