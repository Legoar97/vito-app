import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Importar Screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/achievements_screen.dart'; // <-- IMPORTANTE: Importar la nueva pantalla

// Importar Theme y Provider
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

// Importar Servicios
import 'services/notification_service.dart';

// Importar Localizations
import 'l10n/app_localizations.dart';

void main() async {
  // Asegura que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa el servicio de notificaciones
  await NotificationService.initialize();

  // Envolver la app con ChangeNotifierProvider para el tema
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const VitoApp(),
    ),
  );
}

/// Una clase auxiliar para que GoRouter pueda escuchar los cambios de autenticación de Firebase.
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
    // Consumir el ThemeProvider para que la app reaccione a los cambios
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Vito',
      debugShowCheckedModeBanner: false,
      
      // Configuración de Localización
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
      // Configuración de Tema ahora es dinámica gracias al provider
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      
      // Configuración del Router
      routerConfig: _router,
    );
  }
}

// --- Configuración del Router con la ruta corregida ---
final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => FirebaseAuth.instance.currentUser != null ? '/home' : '/login',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // --- INICIO DE LA CORRECCIÓN ---
    // Ahora '/home' tiene una ruta anidada para los logros.
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationScreen(),
      routes: [
        GoRoute(
          path: 'achievements', // Esto crea la ruta /home/achievements
          builder: (context, state) => const AchievementsScreen(),
        ),
      ],
    ),
    // --- FIN DE LA CORRECCIÓN ---
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    
    // Rutas que son de autenticación o públicas
    final bool isAuthRoute = state.matchedLocation == '/login' ||
                             state.matchedLocation == '/signup' ||
                             state.matchedLocation == '/onboarding';

    // Si el usuario está logueado pero intenta ir a una ruta de autenticación
    if (loggedIn && isAuthRoute) {
      return '/home';
    }

    // Si el usuario NO está logueado y intenta acceder a cualquier ruta que NO sea pública
    if (!loggedIn && !isAuthRoute) {
      return '/login';
    }
    
    // En cualquier otro caso, permite la navegación.
    return null;
  },
);
