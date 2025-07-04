// main.dart

import 'dart:async';
import 'dart:ui';
import 'dart:io';
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
import 'screens/verify_email_screen.dart'; // <-- CAMBIO: Importamos la nueva pantalla
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/vertex_ai_service.dart';
import 'l10n/app_localizations.dart';

// Instancia global para notificaciones del servicio en segundo plano
final FlutterLocalNotificationsPlugin serviceNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Crear el canal de notificación ANTES de configurar el servicio
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vito_foreground_service',
    'Vito Tareas en Segundo Plano',
    description: 'Canal para mantener los temporizadores de Vito activos.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  await serviceNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Crear canal adicional para notificaciones de finalización
  const AndroidNotificationChannel completionChannel = AndroidNotificationChannel(
    'vito_timer_complete',
    'Temporizador Completado',
    description: 'Notificaciones cuando se completa un temporizador',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await serviceNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(completionChannel);

  // Configurar el servicio
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
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final player = AudioPlayer();
  Timer? activeTimer;

  // Configurar como servicio en primer plano para Android
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    // Actualizar notificación cada minuto
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        service.setForegroundNotificationInfo(
          title: "Vito está activo",
          content:
              "Última actualización: ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
        );
      }
    });
  }

  // Manejar inicio de temporizador
  service.on('startTimer').listen((event) {
    activeTimer?.cancel();
    if (event == null) return;

    final duration = event['duration'] as int? ?? 0;
    final taskName = event['taskName'] as String? ?? 'Tarea';
    var remaining = duration;

    activeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;

      // Actualizar tiempo restante
      service.invoke('timerUpdate', {
        'remaining': remaining,
        'taskName': taskName,
      });

      // Actualizar notificación cada 10 segundos
      if (remaining % 10 == 0 && service is AndroidServiceInstance) {
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        service.setForegroundNotificationInfo(
          title: "Timer activo: $taskName",
          content:
              "Tiempo restante: $minutes:${seconds.toString().padLeft(2, '0')}",
        );
      }

      // Temporizador completado
      if (remaining <= 0) {
        timer.cancel();
        activeTimer = null;

        // Notificar que terminó
        service.invoke('timerComplete', {'taskName': taskName});

        // Reproducir sonido
        try {
          player.play(AssetSource('sounds/completion_sound.mp3'));
        } catch (e) {
          print('Error al reproducir sonido: $e');
        }

        // Mostrar notificación de finalización
        _showCompletionNotification(taskName);

        // Restaurar notificación del servicio
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Vito está activo",
            content: "Esperando siguiente temporizador",
          );
        }
      }
    });
  });

  // Manejar parada de temporizador
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

  // Manejar parada del servicio
  service.on('stopService').listen((event) {
    activeTimer?.cancel();
    player.dispose();
    service.stopSelf();
  });
}

// Función para mostrar notificación de completado
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
    color: Color(0xFF6B5B95),
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  await serviceNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    '¡Temporizador completado!',
    '$taskName ha terminado',
    notificationDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar NotificationService
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  // Inicializar VertexAI
  await VertexAIService.initialize();

  // Inicializar plugin de notificaciones para el servicio en segundo plano
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: DarwinInitializationSettings(),
  );

  await serviceNotificationsPlugin.initialize(initializationSettings);

  // Solicitar permisos de notificación para Android 13+
  if (Platform.isAndroid) {
    final androidPlugin = serviceNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // Inicializar servicio en segundo plano
  await initializeBackgroundService();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const VitoApp(),
    ),
  );
}

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

// <-- CAMBIO: Toda la configuración del router ha sido actualizada.
final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/login', // El redirect se encargará de llevar al usuario al lugar correcto.
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    // <-- CAMBIO: Añadimos la ruta para la pantalla de verificación.
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
  // <-- CAMBIO: La lógica de redirección ahora maneja la verificación de email.
  redirect: (BuildContext context, GoRouterState state) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    final bool isLoggedIn = user != null;
    final bool isEmailVerified = user?.emailVerified ?? false;
    
    final bool isGoingToAuth = state.matchedLocation == '/login' ||
                               state.matchedLocation == '/signup';
    final bool isGoingToVerifyEmail = state.matchedLocation == '/verify-email';

    // CASO 1: Usuario NO está logueado.
    // Si intenta ir a cualquier ruta que no sea de autenticación, lo mandamos a /login.
    if (!isLoggedIn) {
      return isGoingToAuth ? null : '/login';
    }

    // CASO 2: Usuario está logueado, PERO su email NO está verificado.
    // Lo forzamos a ir a la pantalla de verificación, a menos que ya esté yendo allí.
    if (!isEmailVerified) {
      return isGoingToVerifyEmail ? null : '/verify-email';
    }

    // CASO 3: Usuario está logueado Y su email SÍ está verificado.
    // Si intenta acceder a las páginas de login, registro o verificación, lo mandamos a home.
    if (isEmailVerified) {
      if (isGoingToAuth || isGoingToVerifyEmail) {
        return '/home';
      }
    }

    // Si ninguna regla aplica, no se redirige a ningún lado.
    return null;
  },
);