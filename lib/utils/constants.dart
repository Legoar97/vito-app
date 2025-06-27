// App constants
class AppConstants {
  // App info
  static const String appName = 'Vito';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Pequeños pasos, gran compañía';
  
  // Firebase collections
  static const String usersCollection = 'users';
  static const String habitsCollection = 'habits';
  
  // Storage keys
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themePreferenceKey = 'theme_preference';
  static const String languagePreferenceKey = 'language_preference';
  static const String notificationsEnabledKey = 'notifications_enabled';
  
  // Habit categories
  static const List<String> habitCategories = [
    'health',
    'mind',
    'productivity',
    'relationships',
    'creativity',
    'finance',
  ];
  
  // Category names (Spanish)
  static const Map<String, String> categoryNames = {
    'health': 'Salud',
    'mind': 'Mente',
    'productivity': 'Productividad',
    'relationships': 'Relaciones',
    'creativity': 'Creatividad',
    'finance': 'Finanzas',
  };
  
  // Days of week
  static const List<String> weekDaysShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const List<String> weekDaysFull = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  
  // Time formats
  static const String timeFormat12h = 'h:mm a';
  static const String timeFormat24h = 'HH:mm';
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  
  // Limits
  static const int maxHabitsPerUser = 50;
  static const int maxHabitNameLength = 50;
  static const int minPasswordLength = 6;
  static const int maxStreakDays = 9999;
  
  // Durations
  static const Duration habitCompletionWindow = Duration(hours: 24);
  static const Duration notificationAdvanceTime = Duration(minutes: 0);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 3);
  
  // AI Coach
  static const int maxChatMessages = 100;
  static const int maxPromptLength = 500;
  static const Duration aiResponseTimeout = Duration(seconds: 30);
  
  // Statistics
  static const List<String> statisticPeriods = ['week', 'month', 'year'];
  static const int defaultChartDataPoints = 7;
  
  // Motivational quotes
  static const List<String> motivationalQuotes = [
    'Pequeños pasos llevan a grandes cambios',
    'Progreso, no perfección',
    'Lo estás haciendo increíble',
    'Sigue adelante, ¡puedes lograrlo!',
    'Cada día es un nuevo comienzo',
    'La constancia es la clave del éxito',
    'Un hábito a la vez',
    'Tu futuro yo te lo agradecerá',
    'Hoy es el mejor día para empezar',
    'Los grandes logros requieren tiempo',
  ];
  
  // Achievement thresholds
  static const Map<String, int> achievementThresholds = {
    'first_habit': 1,
    'habit_beginner': 5,
    'habit_intermediate': 10,
    'habit_expert': 25,
    'habit_master': 50,
    'week_streak': 7,
    'month_streak': 30,
    'quarter_streak': 90,
    'year_streak': 365,
    'perfect_week': 7,
    'perfect_month': 30,
  };
  
  // Error messages
  static const Map<String, String> errorMessages = {
    'auth/user-not-found': 'No existe una cuenta con este email',
    'auth/wrong-password': 'Contraseña incorrecta',
    'auth/email-already-in-use': 'Ya existe una cuenta con este email',
    'auth/weak-password': 'La contraseña es muy débil',
    'auth/invalid-email': 'Email inválido',
    'auth/network-request-failed': 'Error de conexión',
    'permission-denied': 'No tienes permisos para realizar esta acción',
    'not-found': 'No se encontró el recurso solicitado',
    'unknown': 'Ha ocurrido un error inesperado',
  };
  
  // Success messages
  static const Map<String, String> successMessages = {
    'habit_created': '¡Hábito creado exitosamente!',
    'habit_updated': 'Hábito actualizado',
    'habit_deleted': 'Hábito eliminado',
    'habit_completed': '¡Bien hecho! Hábito completado',
    'profile_updated': 'Perfil actualizado',
    'password_changed': 'Contraseña cambiada exitosamente',
    'data_exported': 'Datos exportados exitosamente',
  };
  
  // Notification channels
  static const String habitRemindersChannel = 'habit_reminders';
  static const String achievementsChannel = 'achievements';
  static const String generalChannel = 'general';
  
  // URLs
  static const String privacyPolicyUrl = 'https://vito-app.com/privacy';
  static const String termsOfServiceUrl = 'https://vito-app.com/terms';
  static const String supportEmail = 'support@vito-app.com';
  
  // Cache durations
  static const Duration cacheValidDuration = Duration(hours: 24);
  static const Duration temporaryCacheDuration = Duration(minutes: 5);
}