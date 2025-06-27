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
import 'screens/onboarding_screen.dart';
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

final GoRouter _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return '/login';
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final onboardingCompleted = userDoc.data()?['onboardingCompleted'] ?? false;

        return onboardingCompleted ? '/home' : '/onboarding';
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationScreen(),
      routes: [
        GoRoute(
          path: 'achievements', 
          builder: (context, state) => const AchievementsScreen(),
        ),
      ],
    ),
  ],
  // <<< MEJORA >>> Lógica de redirección inteligente
  redirect: (BuildContext context, GoRouterState state) async {
    final user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = user != null;
    final bool isOnAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
    final bool isOnOnboarding = state.matchedLocation == '/onboarding';

    if (!loggedIn) {
      // Si no está logueado, solo puede estar en login o signup
      return isOnAuthRoute ? null : '/login';
    }

    // Si está logueado, verificamos el estado del onboarding
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final bool onboardingCompleted = userDoc.data()?['onboardingCompleted'] ?? false;

    if (!onboardingCompleted) {
      // Si no ha completado el onboarding, DEBE ir a /onboarding
      return isOnOnboarding ? null : '/onboarding';
    }
    
    // Si ya completó el onboarding, no puede volver a las rutas de auth/onboarding
    if (isOnAuthRoute || isOnOnboarding) {
      return '/home';
    }

    // En cualquier otro caso, permite la navegación.
    return null;
  },
);
