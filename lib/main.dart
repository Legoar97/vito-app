import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
// import 'screens/onboarding_screen.dart'; // <--- YA NO SE USA, PUEDES BORRARLO
import 'screens/main_navigation_screen.dart';
import 'screens/achievements_screen.dart'; 

// Theme y Provider
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

// Services
import 'services/notification_service.dart';

// Localizations
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

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

// --- ROUTER ACTUALIZADO ---
final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  // La ruta inicial ahora es más simple, el redirect se encarga de todo.
  initialLocation: '/login', 
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    // ELIMINADA: La ruta '/onboarding' ya no es necesaria.
    // GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()), 
    GoRoute(
      path: '/home',
      // MainNavigationScreen ahora es el destino principal después del login/signup.
      // Su pantalla de hábitos se encargará de mostrar el tutorial si es necesario.
      builder: (context, state) => const MainNavigationScreen(),
      routes: [
        GoRoute(
          path: 'achievements', 
          builder: (context, state) => const AchievementsScreen(),
        ),
      ],
    ),
  ],
  // Lógica de redirección simplificada y adaptada al nuevo flujo.
  redirect: (BuildContext context, GoRouterState state) async {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    final bool isGoingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    // CASO 1: El usuario NO está logueado.
    if (!isLoggedIn) {
      // Si no está logueado, solo puede ir a las rutas de autenticación.
      // Si intenta ir a otro lado, se le redirige a /login.
      return isGoingToAuth ? null : '/login';
    }

    // CASO 2: El usuario SÍ está logueado.
    if (isLoggedIn) {
      // Si el usuario ya está logueado e intenta ir a /login o /signup,
      // lo redirigimos a /home, que es su lugar correcto.
      if (isGoingToAuth) {
        return '/home';
      }
    }

    // En cualquier otro caso (usuario logueado yendo a /home, /home/achievements, etc.),
    // no hacemos nada y permitimos la navegación.
    return null;
  },
);