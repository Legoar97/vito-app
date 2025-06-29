import 'dart:async';
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
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/vertex_ai_service.dart';
import 'l10n/app_localizations.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const String notificationChannelId = 'vito_foreground_service';
  const String notificationChannelName = 'Vito Tareas en Segundo Plano';
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    notificationChannelName,
    description: 'Canal para mantener los temporizadores de Vito activos.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Vito está trabajando',
      initialNotificationContent: 'Manteniendo tus temporizadores activos.',
      foregroundServiceNotificationId: 888,
      // El parámetro 'notificationIcon' se ha eliminado para que coincida
      // con tu versión del paquete y evitar el error de compilación.
      // Ahora es OBLIGATORIO crear el archivo 'ic_bg_service_small.xml'
      // en las carpetas 'res/drawable'.
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  final player = AudioPlayer();
  Timer? activeTimer;
  service.on('startTimer').listen((event) {
    activeTimer?.cancel();
    if (event == null) return;
    final durationInSeconds = event['duration'] as int;
    activeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = durationInSeconds - timer.tick;
      if (remaining >= 0) {
        service.invoke('update', {'remaining': remaining});
      }
      if (remaining <= 0) {
        timer.cancel();
        activeTimer = null;
        service.invoke('timerFinished');
        try {
          player.play(AssetSource('sounds/completion_sound.mp3'));
        } catch (e) {
          print("Error al reproducir sonido: $e");
        }
      }
    });
  });
  service.on('stopTimer').listen((event) {
    activeTimer?.cancel();
    activeTimer = null;
    service.invoke('update', {'remaining': 0});
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  await VertexAIService.initialize();
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

final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationScreen(),
      routes: [
        GoRoute(path: 'achievements', builder: (context, state) => const AchievementsScreen()),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) async {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;
    final bool isGoingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
    if (!isLoggedIn) {
      return isGoingToAuth ? null : '/login';
    }
    if (isLoggedIn && isGoingToAuth) {
      return '/home';
    }
    return null;
  },
);