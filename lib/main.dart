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


// --- SECCIÓN DEL SERVICIO EN SEGUNDO PLANO ---
// Esta parte se mantiene sin cambios, ya que maneja las notificaciones
// específicas del temporizador y funciona de manera independiente.
final FlutterLocalNotificationsPlugin serviceNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vito_foreground_service',
    'Vito Tareas en Segundo Plano',
    description: 'Canal para mantener los temporizadores de Vito activos.',
    importance: Importance.low,
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
      initialNotificationTitle: 'Vito está trabajando',
      initialNotificationContent: 'Manteniendo tus temporizadores activos',
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
  // La lógica interna de onStart para el temporizador no necesita cambios.
  final player = AudioPlayer();
  Timer? activeTimer;
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        service.setForegroundNotificationInfo(
          title: "Vito está activo",
          content: "Última actualización: ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
        );
      }
    });
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
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Vito está activo",
            content: "Esperando siguiente temporizador",
          );
        }
      }
    });
  });
  service.on('stopTimer').listen((event) {
    activeTimer?.cancel();
    activeTimer = null;
    service.invoke('timerStopped');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Vito está activo",
        content: "Temporizador detenido",
      );
    }
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

  // 1. Inicializar Firebase (Correcto, sin cambios)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Inicializar NotificationService (Centralizado)
  // Esta única llamada configura notificaciones locales y el manejador de background de Firebase.
  await NotificationService.initialize();

  // 3. CAMBIO: Escuchar notificaciones push en primer plano.
  // Es necesario para que las notificaciones de FCM se muestren si la app está abierta.
  NotificationService.handleForegroundMessages();

  // 4. CAMBIO: Manejar el token de FCM al cambiar el estado de autenticación.
  // Escuchamos los cambios en la autenticación. Si un usuario inicia sesión (o ya estaba logueado
  // al abrir la app), obtenemos y guardamos su token de FCM.
  // Esto es más robusto que llamarlo manualmente desde las pantallas de login/signup.
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null && user.emailVerified) { // Nos aseguramos que el email esté verificado
      print("Usuario verificado (${user.uid}), inicializando token para notificaciones push.");
      NotificationService.initializeAndSaveToken(user.uid);
    }
  });
  
  // 5. Inicializar otros servicios (Correcto, sin cambios)
  await VertexAIService.initialize();

  // 6. CAMBIO: Simplificación de la inicialización de notificaciones.
  // Se elimina la solicitud de permisos explícita (`requestNotificationsPermission`)
  // porque el nuevo `NotificationService` la gestiona internamente cuando es necesario.
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification_icon');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: DarwinInitializationSettings(),
  );
  await serviceNotificationsPlugin.initialize(initializationSettings);
  
  // 7. Inicializar servicio en segundo plano (Correcto, sin cambios)
  await initializeBackgroundService();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const VitoApp(),
    ),
  );
}

// --- LÓGICA DE NAVEGACIÓN Y APP (Sin cambios) ---
// El resto del archivo (GoRouter, VitoApp, etc.) no requiere modificaciones,
// ya que la lógica de enrutamiento y la app en sí no se ven afectadas
// por la nueva implementación del servicio de notificaciones.

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp.router(
      title: 'Vito',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => MainNavigationScreen(
        initialIndex: state.extra as int? ?? 0,
      ),
      routes: [
        GoRoute(
          path: 'achievements',
          builder: (context, state) => const AchievementsScreen(),
        ),
        GoRoute(
          path: 'mood-tracker',
          builder: (context, state) => const MoodTrackerScreen(),
        ),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    final bool isLoggedIn = user != null;
    final bool isEmailVerified = user?.emailVerified ?? false;
    
    final bool isGoingToAuth = state.matchedLocation == '/login' ||
                               state.matchedLocation == '/signup';
    final bool isGoingToVerifyEmail = state.matchedLocation == '/verify-email';

    if (!isLoggedIn) {
      return isGoingToAuth ? null : '/login';
    }

    if (!isEmailVerified) {
      return isGoingToVerifyEmail ? null : '/verify-email';
    }
    
    if (isEmailVerified) {
      if (isGoingToAuth || isGoingToVerifyEmail) {
        return '/home';
      }
    }

    return null;
  },
);