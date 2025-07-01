import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:ui';
import 'dart:async'; 
import 'dart:math' as math;

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../screens/vito_chat_habit_screen.dart';
import '../services/notification_service.dart';


// --- NUEVO MODELO DE MOOD ---
class Mood {
  final String name;
  final IconData icon;
  final List<Color> gradient;
  Mood({required this.name, required this.icon, required this.gradient});
}

// Modelo para la Sugerencia de la IA
class SuggestedHabit {
  final String name;
  final String category;
  SuggestedHabit({required this.name, required this.category});
}

class ModernHabitsScreen extends StatefulWidget {
  const ModernHabitsScreen({super.key});

  @override
  State<ModernHabitsScreen> createState() => _ModernHabitsScreenState();
}

class _ModernHabitsScreenState extends State<ModernHabitsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _pulseAnimationController;
  DateTime _selectedDate = DateTime.now();
    // --- NUEVAS VARIABLES PARA EL TUTORIAL ---
  bool _showTutorial = false;
  int _tutorialStep = 0;
  final GlobalKey _moodTrackerKey = GlobalKey();
  final GlobalKey _progressCardKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey(); // FAB = Floating Action Button
  String _userName = ''; 
  // --- FIN DE VARIABLES PARA EL TUTORIAL ---

  bool _isLoadingSuggestions = false;
  List<SuggestedHabit> _suggestedHabits = [];
  bool _showCoachWelcome = false;

  Stream<QuerySnapshot>? _allHabitsStream;
  final User? user = FirebaseAuth.instance.currentUser;

  // --- LÓGICA DE MOOD TRACKER ACTUALIZADA ---
  List<Map<String, dynamic>> _todaysMoods = [];
  // Nueva lista de moods con iconos y colores mejorados
// En _ModernHabitsScreenState
  final List<Mood> moods = [
      Mood(name: 'Feliz', icon: Icons.sentiment_very_satisfied_rounded, gradient: [const Color(0xFF4ADE80), const Color(0xFF22C55E)]),
      Mood(name: 'Normal', icon: Icons.sentiment_satisfied_rounded, gradient: [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]),
      Mood(name: 'Triste', icon: Icons.sentiment_very_dissatisfied_rounded, gradient: [const Color(0xFF94A3B8), const Color(0xFF64748B)]),
      Mood(name: 'Enojado', icon: Icons.local_fire_department_rounded, gradient: [const Color(0xFFF87171), const Color(0xFFEF4444)]),
      Mood(name: 'Estresado', icon: Icons.storm_rounded, gradient: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]),
      Mood(name: 'Motivado', icon: Icons.rocket_launch_rounded, gradient: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]),
    ];

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  Timer? _habitTimer;
  String? _activeTimerHabitId;
  int _timerSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    
    // Inicialización de controladores de animación y scroll
    _animationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
    _floatingAnimationController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _pulseAnimationController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    
    _scrollController = ScrollController()..addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });

    // Carga de datos inicial
    if (user != null) {
      _initializeStream();
      _loadUserNameAndOnboarding(); // <--- CAMBIO CLAVE: Nueva función que agrupa la lógica
      _loadTodaysMood();
    }
    
    // Configuración de servicios y notificaciones
    NotificationService.scheduleDailyMoodReminder(); 
    _listenToBackgroundService();
  }

  // --- NUEVO: Método separado para mantener el código limpio ---
  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();

    // Escucha el evento 'update' que el servicio envía cada segundo.
    service.on('update').listen((event) {
      if (mounted && _activeTimerHabitId != null && event != null) {
        // Actualiza el estado de la UI con el tiempo restante.
        setState(() {
          _timerSecondsRemaining = event['remaining'] as int? ?? 0;
        });
      }
    });

    // Escucha el evento 'timerFinished' que el servicio envía una vez al terminar.
    service.on('timerFinished').listen((event) {
      if (mounted && _activeTimerHabitId != null) {
        // Cuando el timer termina, marca el hábito como completado
        _completeTimedHabit(_activeTimerHabitId!);
        // Y resetea el estado del timer en la UI.
        setState(() {
          _activeTimerHabitId = null;
          _timerSecondsRemaining = 0;
        });
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      // Si el onboarding NO está completado, iniciamos el tutorial
      if (mounted && (userDoc.data()?['onboardingCompleted'] == null || userDoc.data()?['onboardingCompleted'] == false)) {
        setState(() {
          _showTutorial = true;
          _tutorialStep = -1; // Empezamos desde el primer paso
        });
      }
    } catch (e) {
      print("Error al verificar estado de onboarding: $e");
    }
  }

  void _initializeStream() {
    setState(() {
      _allHabitsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('habits')
          .snapshots();
    });
  }

  Future<void> _checkIfFirstTime() async {
    if (user == null) return;
    await Future.delayed(const Duration(seconds: 1)); 
    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid).collection('habits').limit(1).get();
    if (snapshot.docs.isEmpty && mounted) {
      setState(() => _showCoachWelcome = true);
    }
  }

  Future<void> _getAiHabitSuggestions(String category) async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestedHabits = [];
    });

    // Simulación de llamada a Vertex AI
    await Future.delayed(const Duration(seconds: 2));
    final Map<String, List<String>> mockSuggestions = {
      'Salud': ['Beber un vaso de agua', 'Estirar por 10 minutos', 'Caminar 15 minutos'],
      'Mente': ['Meditar 5 minutos', 'Escribir un diario', 'Leer 10 minutos'],
      'Trabajo': ['Organizar tu escritorio', 'Planificar tus 3 tareas más importantes', 'Tomar un descanso de 5 min'],
      'Creativo': ['Dibujar algo simple', 'Escuchar música nueva', 'Escribir una idea'],
      'Finanzas': ['Anotar gastos del día', 'Revisar tu presupuesto', 'Aprender un término financiero'],
    };
    final suggestions = mockSuggestions[category] ?? [];

    if (mounted) {
      setState(() {
        _suggestedHabits = suggestions.map((name) => SuggestedHabit(name: name, category: category)).toList();
        _isLoadingSuggestions = false;
        _showCoachWelcome = false;
      });
    }
  }

  void _addSuggestedHabitWithForm(SuggestedHabit habit) {
    final habitToRemove = habit;
    
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => VitoChatHabitSheet(
        initialMessage: habit.name,
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _suggestedHabits.remove(habitToRemove));
      }
    });
  }


  Future<void> _loadUserNameAndOnboarding() async {
    if (user == null) return;
    
    // Primero, obtenemos el nombre de usuario
    final displayName = user!.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      _userName = displayName.split(' ').first;
    } else {
      // Si no está en Auth, lo buscamos en Firestore
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if(mounted && userDoc.exists) {
          _userName = (userDoc.data()?['displayName'] as String?)?.split(' ').first ?? 'amigo';
        }
      } catch (e) {
        _userName = ''; 
      }
    }
    
    // Una vez que tenemos el nombre, actualizamos el estado y LUEGO verificamos el onboarding.
    if (mounted) {
      setState(() {}); // Actualiza la UI para que el nombre esté disponible en el saludo
      _checkOnboardingStatus(); // Ahora sí, verificamos el onboarding con el nombre ya cargado.
    }
  }

  // --- LÓGICA DE MOOD TRACKER ACTUALIZADA ---
  Future<void> _loadTodaysMood() async {
    if (user == null) return;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
      .collection('users').doc(user!.uid).collection('moods')
      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
      .where('timestamp', isLessThan: endOfDay)
      .orderBy('timestamp', descending: true)
      .get();

    if (mounted) {
      setState(() {
        _todaysMoods = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    }
  }

  Future<void> _saveMood(String mood) async {
    if (user == null) return;

    // Lógica para limitar el registro cada 3 horas
    if (_todaysMoods.isNotEmpty) {
      final lastMoodTime = (_todaysMoods.first['timestamp'] as Timestamp).toDate();
      if (DateTime.now().difference(lastMoodTime).inHours < 3) {
        _showSuccessSnackBar('Puedes registrar tu ánimo de nuevo en un rato.');
        return;
      }
    }

    HapticFeedback.lightImpact();
    await FirebaseFirestore.instance
      .collection('users').doc(user!.uid).collection('moods')
      .add({'mood': mood, 'timestamp': Timestamp.now()});

    await NotificationService.cancelDailyMoodReminder();

    _loadTodaysMood(); // Recargar los moods para actualizar la UI
    _showSuccessSnackBar('¡Ánimo registrado!');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ), 
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      )
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _habitTimer?.cancel();
    _floatingAnimationController.dispose();
    _pulseAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
@override
  Widget build(BuildContext context) {
    // Primero, comprobamos si debemos mostrar la vista de bienvenida del coach
    // en lugar de la pantalla principal.
    if (_showCoachWelcome) {
      return _buildCoachWelcomeView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _showTutorial,
            child: CustomScrollView(
              physics: _showTutorial
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              controller: _scrollController,
              slivers: [
                _buildPremiumSliverAppBar(),

                // --- CORRECCIÓN 1 ---
                // La GlobalKey para el Mood Tracker se asigna aquí, fuera del método de construcción.
                // Esto asegura que la llave esté en un lugar estable del árbol de widgets.
                SliverToBoxAdapter(
                  child: Container(
                    key: _moodTrackerKey, // <-- KEY ASIGNADA AQUÍ
                    child: _buildPremiumMoodTracker(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _showTutorial
                        // --- CORRECCIÓN 2 (PARTE A) ---
                        // Lo mismo para la tarjeta de progreso en modo tutorial.
                        ? Container(
                            key: _progressCardKey, // <-- KEY ASIGNADA AQUÍ
                            child: _buildPremiumProgressCard([]),
                          )
                        : StreamBuilder<QuerySnapshot>(
                            stream: _allHabitsStream,
                            builder: (context, snapshot) {
                              final allHabits = snapshot.data?.docs ?? [];
                              // --- CORRECCIÓN 2 (PARTE B) ---
                              // Y también para la tarjeta de progreso en modo normal.
                              // Al estar fuera del StreamBuilder, no se duplica.
                              return Container(
                                key: _progressCardKey, // <-- KEY ASIGNADA AQUÍ
                                child: _buildPremiumProgressCard(allHabits),
                              );
                            },
                          ),
                  ),
                ),
                if (_isLoadingSuggestions) _buildLoadingSuggestionsIndicator(),
                if (_suggestedHabits.isNotEmpty) _buildPremiumSuggestionsSection(),
                _buildPremiumHabitsListHeader(),
                StreamBuilder<QuerySnapshot>(
                  stream: _allHabitsStream,
                  builder: (context, snapshot) {
                    if (_showTutorial) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    final allHabits = snapshot.data?.docs ?? [];
                    return _buildPremiumHabitsList(allHabits);
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          if (!_showTutorial) ...[
            _buildIdeaChip(),
          ],
          // Esta condición ahora llama al overlay corregido
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
      floatingActionButton: Container(
        key: _fabKey,
        child: _buildFloatingActionButton(),
      ),
    );
  }

// Métodos para tutorial
// Obtiene la posición y tamaño de un widget usando su GlobalKey

  Widget _buildStaticMoodTrackerTutorial() {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo oscuro
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _tutorialStep++),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
          // Centramos el Mood Tracker y el diálogo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Usamos el widget original, pero fuera del scroll
                _buildPremiumMoodTracker(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTutorialDialog(
                    title: 'Registra tu Ánimo',
                    text: 'Empecemos por aquí. Toca un emoji para registrar cómo te sientes. Esto te ayudará a ver la conexión entre tu ánimo y tus hábitos. Puedes registrar tu ánimo cada 3 horas.',
                    isLastStep: false,
                    onNext: () => setState(() => _tutorialStep++),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Rect? _getWidgetRect(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    }
    return null;
  }

  Widget _buildStaticCardTutorial() {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo oscuro y difuminado (cubre toda la pantalla)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _tutorialStep++),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
          // Colocamos una copia visual de la tarjeta y el diálogo encima
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostramos una versión vacía de la tarjeta para el tutorial
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildPremiumProgressCard([]), 
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTutorialDialog(
                    title: 'Tu Centro de Mando',
                    text: 'Esta tarjeta te mostrará tu progreso diario y tu racha de constancia. ¡Vamos a llenarla!',
                    isLastStep: false,
                    onNext: () => setState(() => _tutorialStep++),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    // Paso de bienvenida
    if (_tutorialStep == -1) {
      return _buildWelcomeDialog();
    }
    
    // Paso 0 (Mood Tracker) ahora usa su propia vista estática
    if (_tutorialStep == 0) {
      return _buildStaticMoodTrackerTutorial();
    }

    // Paso 1 (Centro de Mando) ya usa su vista estática
    if (_tutorialStep == 1) {
      return _buildStaticCardTutorial();
    }
    
    // Paso 2 (FAB) usa el spotlight porque SÍ es un RenderBox (no está en el scroll)
    if (_tutorialStep == 2) {
      GlobalKey? currentKey = _fabKey;
      String title = 'Crea tu Primer Hábito';
      String text = 'Toca este botón para añadir un nuevo hábito. Te ayudaré a configurarlo paso a paso.';
      
      final highlightRect = currentKey != null ? _getWidgetRect(currentKey) : null;
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // El último paso solo avanza con el botón
                onTap: () {}, 
                child: ClipPath(
                  clipper: InvertedClipper(
                    rect: highlightRect?.inflate(15.0) ?? Rect.zero,
                    shape: BoxShape.circle,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(color: Colors.black.withOpacity(0.6)),
                  ),
                ),
              ),
            ),
            if (highlightRect != null)
              Positioned(
                // Alineación del diálogo sobre el FAB
                bottom: MediaQuery.of(context).size.height - highlightRect.top + 20,
                left: 20,
                right: 20,
                child: _buildTutorialDialog(
                  title: title,
                  text: text,
                  isLastStep: _tutorialStep == 2,
                  onNext: () async {
                    // Acción final
                    await _completeTutorial(); 
                    _showAddHabitBottomSheet();
                  },
                ),
              ),
          ],
        ),
      );
    }

    // Fallback por si hay un estado de tutorial inválido
    return const SizedBox.shrink();
  }

  Widget _buildWelcomeDialog() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.spa_rounded, color: AppColors.primary, size: 60),
                  const SizedBox(height: 24),
                  // --- LÍNEA CORREGIDA ---
                  // Se usa la variable _userName que es parte del estado de la clase.
                  Text(
                    _userName.isNotEmpty ? '¡Hola, $_userName!' : '¡Qué bueno tenerte aquí!',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    // Usamos comillas triples para que el texto multilínea no de problemas
                    '''Vito es tu espacio para construir una vida más saludable y feliz, un pequeño paso a la vez. El verdadero cambio viene de la constancia, y mi trabajo es hacer que ese camino sea fácil y motivador para ti. En este rápido tour, te mostraré las herramientas clave que usaremos juntos. 🌱''',
                    style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF64748B), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => setState(() => _tutorialStep = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('¡Comencemos!', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialDialog({
    required String title,
    required String text,
    required bool isLastStep,
    required VoidCallback onNext,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLastStep ? '¡Entendido!' : 'Siguiente',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  // Marca el tutorial como completado en Firestore
  Future<void> _completeTutorial() async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));
      setState(() => _showTutorial = false);
    } catch (e) {
      print("Error al completar el tutorial: $e");
    }
  }     
  
  // --- NUEVO WIDGET PARA EL CHIP DE IDEAS ---
  Widget _buildIdeaChip() {
    return Positioned(
      bottom: 95, // Justo encima del FAB
      right: 20,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          final categories = ['Salud', 'Mente', 'Trabajo', 'Creativo', 'Finanzas'];
          final randomCategory = categories[math.Random().nextInt(categories.length)];
          _getAiHabitSuggestions(randomCategory);
        },
        child: Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ideas',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  SliverToBoxAdapter _buildLoadingSuggestionsIndicator() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text('Vito está pensando...', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Botón flotante premium
  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + (_pulseAnimationController.value * 0.05),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20 + (_pulseAnimationController.value * 10),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _showAddHabitBottomSheet,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }

  // Formas flotantes decorativas
  List<Widget> _buildFloatingShapes() {
    return [
      AnimatedBuilder(
        animation: _floatingAnimationController,
        builder: (context, child) {
          return Positioned(
            top: 100 + (30 * math.sin(_floatingAnimationController.value * 2 * math.pi)),
            right: -60,
            child: Transform.rotate(
              angle: _floatingAnimationController.value * math.pi,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _floatingAnimationController,
        builder: (context, child) {
          return Positioned(
            bottom: 200 + (20 * math.cos(_floatingAnimationController.value * 2 * math.pi)),
            left: -80,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.08),
                    AppColors.secondary.withOpacity(0.01),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  // Mood Tracker Premium
  Widget _buildPremiumMoodTracker() {
    final lastMoodName = _todaysMoods.isEmpty ? null : _todaysMoods.first['mood'];

    return FadeTransition(
      opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 1.0)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 1.0))),
        child: Container(
          // NOTA: La key ya no se asigna aquí. Se asignará en el 'build'.
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.favorite_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('¿Cómo te sientes?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              Text('Registra tu estado de ánimo', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: moods.map((mood) {
                        final isSelected = lastMoodName == mood.name;
                        return GestureDetector(
                          onTap: () => _saveMood(mood.name), // o onSaveMood(mood.name)
                          child: Column(
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: EdgeInsets.all(isSelected ? 14 : 12),
                                  decoration: BoxDecoration(
                                    gradient: isSelected ? LinearGradient(colors: mood.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                                    color: isSelected ? null : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    boxShadow: isSelected ? [BoxShadow(color: mood.gradient.first.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : [],
                                  ),
                                  child: Icon(mood.icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 26),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // --- CAMBIO CLAVE AQUÍ ---
                              // El texto ahora siempre es visible, pero su estilo cambia.
                              Text(
                                mood.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  // Si está seleccionado, usa el color del gradiente. Si no, un gris sutil.
                                  color: isSelected ? mood.gradient.last : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCoachWelcomeView() {
    final categories = [
      {'name': 'Salud', 'icon': Icons.favorite_rounded, 'color': AppColors.categoryHealth, 'gradient': [const Color(0xFF4ADE80), const Color(0xFF22C55E)]},
      {'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind, 'gradient': [const Color(0xFF818CF8), const Color(0xFF6366F1)]},
      {'name': 'Trabajo', 'icon': Icons.work_rounded, 'color': AppColors.categoryProductivity, 'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]},
      {'name': 'Creativo', 'icon': Icons.palette_rounded, 'color': AppColors.categoryCreativity, 'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]},
      {'name': 'Finanzas', 'icon': Icons.attach_money_rounded, 'color': AppColors.categoryFinance, 'gradient': [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]},
    ];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.spa,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "¡Hola! Soy Vito",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Tu coach personal de bienestar.\n¿En qué área te gustaría enfocarte hoy?",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: categories.map((category) {
                    final gradientColors = category['gradient'] as List<Color>;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _getAiHabitSuggestions(category['name'] as String);
                      },
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: gradientColors.first.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildPremiumSuggestionsSection() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeIn,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.primary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Vito sugiere:",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _suggestedHabits = []);
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._suggestedHabits.asMap().entries.map((entry) {
                final index = entry.key;
                final habit = entry.value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            habit.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _addSuggestedHabitWithForm(habit),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.success, Color(0xFF22C55E)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildPremiumSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.secondary.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Patrón de fondo
              Positioned.fill(
                child: CustomPaint(
                  painter: _PatternPainter(),
                ),
              ),
              // Círculos decorativos con parallax
              Positioned(
                top: -50 - (_scrollOffset * 0.5),
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -40 - (_scrollOffset * 0.3),
                left: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _animationController,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.3, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeOut,
                          )),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getMotivationalQuote(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: _buildPremiumWeekSelector(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = user?.displayName?.split(' ').first ?? '';
    if (hour < 12) return 'Buenos días${name.isNotEmpty ? ", $name" : ""}';
    if (hour < 18) return 'Buenas tardes${name.isNotEmpty ? ", $name" : ""}';
    return 'Buenas noches${name.isNotEmpty ? ", $name" : ""}';
  }

  String _getMotivationalQuote() {
    // Lista de frases nuevas y sin emojis
    final quotes = [
      'Un pequeño paso hoy es un gran salto mañana.',
      'La constancia es la clave del éxito.',
      'Tu mejor versión te está esperando.',
      'Cree en el poder de tus hábitos.',
      'Cada día es una nueva oportunidad para mejorar.',
      'La disciplina es el puente entre metas y logros.',
      'El progreso, no la perfección, es lo que importa.',
      'Eres más fuerte de lo que piensas.',
      'Siembra un hábito, cosecha un futuro.',
      'La acción más pequeña es mejor que la intención más grande.',
      'Enfócate en el progreso, no en los resultados.',
      'Tu futuro se crea por lo que haces hoy.',
      'Confía en el proceso de tu crecimiento.',
      'La paciencia y la perseverancia tienen un efecto mágico.',
      'Transforma tus rutinas para transformar tu vida.'
    ];
    
    // Usamos el "día del año" (un número del 1 al 366) para seleccionar la frase.
    // Esto garantiza que la frase sea la misma durante todo un día, pero cambie al día siguiente.
    final dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));
    
    // El módulo asegura que el índice siempre esté dentro de los límites de la lista.
    final quoteIndex = dayOfYear % quotes.length;
    
    return quotes[quoteIndex];
  }

  Widget _buildPremiumWeekSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            // --- CAMBIO AQUÍ: Retrocede un día ---
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: _buildWeekDays(),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            // --- CAMBIO AQUÍ: Avanza un día ---
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildWeekDays() {
    // --- CAMBIO DE LÓGICA: El inicio es 2 días antes del seleccionado ---
    final startDay = _selectedDate.subtract(const Duration(days: 2));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) { // --- CAMBIO: Generamos solo 5 días ---
        final date = startDay.add(Duration(days: index));
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, DateTime.now());

        // Pequeña animación para resaltar el día seleccionado
        final double scale = isSelected ? 1.1 : 1.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            // Si el usuario toca un día, la vista se centra en él
            setState(() => _selectedDate = date);
          },
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 50,
              height: 75,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isToday && !isSelected
                      ? Colors.white.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E('es_ES').format(date).substring(0, 2).toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d().format(date),
                    style: GoogleFonts.poppins(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // TEMPORIZADOR

// lib/screens/modern_habits_screen.dart

  void _startTimer(String habitId, int durationMinutes) {
    // --- AÑADIMOS ESTA LÍNEA ---
    // Inicia el servicio en segundo plano justo cuando se necesita.
    FlutterBackgroundService().startService(); 
    
    _habitTimer?.cancel();

    setState(() {
      _activeTimerHabitId = habitId;
      _timerSecondsRemaining = durationMinutes * 60;
    });

    _habitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSecondsRemaining > 0) {
        setState(() {
          _timerSecondsRemaining--;
        });
      } else {
        _habitTimer?.cancel();
        _completeTimedHabit(_activeTimerHabitId!);
        setState(() {
          _activeTimerHabitId = null;
        });
      }
    });
  }

// lib/screens/modern_habits_screen.dart

  void _stopTimer() {
    // --- AÑADIMOS ESTA LÍNEA ---
    // Le decimos al servicio que ya no es necesario y puede detenerse.
    FlutterBackgroundService().invoke("stopService");

    _habitTimer?.cancel();
    setState(() {
      _activeTimerHabitId = null;
      _timerSecondsRemaining = 0;
    });
  }

  // Y una función para marcar el hábito como completado
// lib/screens/modern_habits_screen.dart

  Future<void> _completeTimedHabit(String habitId) async {
    // --- AÑADIMOS ESTA LÍNEA ---
    // El temporizador terminó, así que el servicio ya cumplió su función.
    FlutterBackgroundService().invoke("stopService");

    if (user == null) return;
    HapticFeedback.heavyImpact();
    
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final habitRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').doc(habitId);
    
    await habitRef.update({
      'completions.$todayKey': {
        'progress': 1,
        'completed': true,
      }
    });
    _showSuccessSnackBar('¡Hábito completado! 💪');
  }
  int _getStreakFromHabitsData(List<QueryDocumentSnapshot> habits) {
    if (habits.isEmpty) return 0;
    
    final Set<DateTime> allCompletionDates = {};
    final Set<int> allScheduledWeekdays = {};
    
    for (var habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      
      // --- LÓGICA CORREGIDA ---
      // Leemos el mapa de completions
      final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
      // Iteramos sobre las entradas del mapa
      for (var entry in completionsMap.entries) {
        final completionData = entry.value as Map<String, dynamic>;
        // Si el día fue marcado como completo, añadimos la fecha a nuestro set
        if (completionData['completed'] == true) {
          try {
            final date = DateFormat('yyyy-MM-dd').parse(entry.key);
            allCompletionDates.add(date);
          } catch (e) {
            // Ignorar claves de fecha con formato incorrecto
          }
        }
      }
      
      final days = List<int>.from(data['days'] ?? []);
      allScheduledWeekdays.addAll(days);
    }

    if (allCompletionDates.isEmpty || allScheduledWeekdays.isEmpty) return 0;

    // El resto de la lógica de cálculo de racha funciona igual que antes
    int streak = 0;
    var now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    if (allScheduledWeekdays.contains(checkDate.weekday) && !allCompletionDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    for (int i = 0; i < 366; i++) {
      if (allScheduledWeekdays.contains(checkDate.weekday)) {
        if (allCompletionDates.contains(checkDate)) {
          streak++;
        } else {
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Widget _buildPremiumProgressCard(List<QueryDocumentSnapshot> allHabits) {
    int totalHabitsForSelectedDay = 0;
    int completedOnSelectedDay = 0;
    
    for (var habit in allHabits) {
      final data = habit.data() as Map<String, dynamic>;
      final days = List<int>.from(data['days'] ?? []);
      
      if (days.contains(_selectedDate.weekday)) {
        totalHabitsForSelectedDay++;
        
        // --- LÓGICA CORREGIDA ---
        final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
        final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
        
        if (completionsMap[dateKey]?['completed'] == true) {
          completedOnSelectedDay++;
        }
      }
    }

    final progress = totalHabitsForSelectedDay > 0 ? completedOnSelectedDay / totalHabitsForSelectedDay : 0.0;
    final streak = _getStreakFromHabitsData(allHabits);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        )),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progreso de hoy',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '$completedOnSelectedDay de $totalHabitsForSelectedDay completados',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF87171), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$streak días',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Barra de progreso mejorada
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: 12,
                    width: MediaQuery.of(context).size.width * progress * 0.75,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progress * 100).toInt()}% completado',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (progress == 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '¡Día completo!',
                            style: GoogleFonts.poppins(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  SliverToBoxAdapter _buildPremiumHabitsListHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSameDay(_selectedDate, DateTime.now()) 
                      ? "Hábitos de hoy" 
                      : "Hábitos del ${DateFormat('d MMM', 'es_ES').format(_selectedDate)}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Toca para completar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHabitsList(List<QueryDocumentSnapshot> allHabits) {
    final habitsForDay = allHabits.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final days = List<int>.from(data?['days'] ?? []);
      return days.contains(_selectedDate.weekday);
    }).toList();

    if (habitsForDay.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No hay hábitos para este día',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agrega uno nuevo para empezar',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final habit = habitsForDay[index];
          final data = habit.data() as Map<String, dynamic>;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: _buildPremiumHabitCard(habit.id, data),
          );
        },
        childCount: habitsForDay.length,
      ),
    );
  }

  Widget _buildPremiumHabitCard(String habitId, Map<String, dynamic> data) {
    final habitType = data['type'] as String? ?? 'simple';
    
    switch (habitType) {
      case 'quantifiable':
        return _buildQuantifiableHabitCard(habitId, data);
      case 'timed':
        return _buildTimedHabitCard(habitId, data);
      case 'simple':
      default:
        return _buildSimpleHabitCard(habitId, data);
    }
  }

  // 2. AÑADE estas tres nuevas funciones a tu clase.

  // --- TARJETA PARA HÁBITOS SIMPLES (SÍ/NO) ---
  // Esta es básicamente tu tarjeta original, pero adaptada a la nueva estructura de datos.
  Widget _buildSimpleHabitCard(String habitId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Hábito sin nombre';
    final category = data['category'] ?? 'health';
    final timeData = data['specificTime'] as Map<String, dynamic>?;
    final color = AppColors.getCategoryColor(category);

    // Lógica de completado con el nuevo mapa de 'completions'
    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final isCompleted = completionsMap[todayKey]?['completed'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSimpleHabit(habitId, isCompleted), // Llama a la nueva función de toggle
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showEditHabitBottomSheet(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isCompleted ? color.withOpacity(0.15) : Colors.black.withOpacity(0.03),
                  blurRadius: isCompleted ? 20 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Checkbox animado
                GestureDetector(
                  onTap: () => _toggleSimpleHabit(habitId, isCompleted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: isCompleted ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
                      color: isCompleted ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isCompleted ? Colors.transparent : Colors.grey[300]!, width: 2),
                    ),
                    child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Detalles del hábito
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? color : const Color(0xFF1E293B),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: color.withOpacity(0.5),
                          decorationThickness: 2,
                        ),
                      ),
                      if (timeData != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(_formatTime(timeData), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.celebration, color: color, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TARJETA PARA HÁBITOS CUANTIFICABLES (CONTADOR) ---
// En tu clase _ModernHabitsScreenState

  Widget _buildQuantifiableHabitCard(String habitId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Sin nombre';
    final target = data['targetValue'] as int? ?? 1;
    final unit = data['unit'] as String? ?? '';
    final category = data['category'] ?? 'health';
    final color = AppColors.getCategoryColor(category);

    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final currentProgress = completionsMap[todayKey]?['progress'] as int? ?? 0;
    final isCompleted = currentProgress >= target;
    final progressPercent = target > 0 ? (currentProgress / target) : 0.0;

    Future<void> updateProgress(int change) async {
      if (!_isSameDay(_selectedDate, DateTime.now())) {
        // Muestra un mensaje de que solo se puede editar hoy
        return;
      }
      final newProgress = (currentProgress + change).clamp(0, target);
      if (newProgress == currentProgress) return;
      
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').doc(habitId).update({
        'completions.$todayKey': {
          'progress': newProgress,
          'completed': newProgress >= target,
        }
      });
      HapticFeedback.lightImpact();
    }

    // --- ENVOLTORIO PARA onLongPress ---
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showEditHabitBottomSheet(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isCompleted ? color.withOpacity(0.15) : Colors.black.withOpacity(0.03),
                  blurRadius: 15, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      ),
                    ),
                    Text(
                      '$currentProgress / $target ${unit.isNotEmpty ? unit : ''}',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 10,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => updateProgress(-1),
                      icon: Icon(Icons.remove_circle_outline, color: Colors.grey[400]),
                    ),
                    IconButton(
                      iconSize: 36,
                      onPressed: () => updateProgress(1),
                      icon: Icon(Icons.add_circle, color: isCompleted ? Colors.grey[400] : color),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TARJETA PARA HÁBITOS CON TEMPORIZADOR ---
  Widget _buildTimedHabitCard(String habitId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Sin nombre';
    final durationMinutes = data['targetValue'] as int? ?? 1;
    final category = data['category'] ?? 'health';
    final color = AppColors.getCategoryColor(category);
    
    final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final isCompleted = completionsMap[todayKey]?['completed'] as bool? ?? false;
    
    final bool isTimerActive = _activeTimerHabitId == habitId;
    
    final minutesStr = (_timerSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secondsStr = (_timerSecondsRemaining % 60).toString().padLeft(2, '0');
    final timerText = '$minutesStr:$secondsStr';

    // --- ENVOLTORIO PARA onLongPress ---
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showEditHabitBottomSheet(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isTimerActive ? color.withOpacity(0.1) : (isCompleted ? color.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isTimerActive ? color.withOpacity(0.5) : (isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!), width: 1.5),
              boxShadow: [BoxShadow(color: (isTimerActive || isCompleted) ? color.withOpacity(0.15) : Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Icon(isCompleted ? Icons.check_circle_rounded : Icons.timer_outlined, color: color, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (isTimerActive)
                        Text(timerText, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 18))
                      else
                        Text('$durationMinutes minutos', style: GoogleFonts.poppins(color: Colors.grey[600])),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    elevation: 5, shadowColor: color.withOpacity(0.5)
                  ),
                  onPressed: isCompleted ? null : () {
                    if (isTimerActive) {
                      _stopTimer();
                    } else {
                      HapticFeedback.heavyImpact();
                      _startTimer(habitId, durationMinutes);
                    }
                  },
                  child: Icon(
                    isCompleted ? Icons.celebration_rounded : (isTimerActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    color: Colors.white
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. AÑADE esta nueva función de toggle para los hábitos simples.
  // Reemplaza la lógica de tu `_toggleHabit` actual.
  Future<void> _toggleSimpleHabit(String habitId, bool isCurrentlyCompleted) async {
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.info_outline, color: Colors.white), SizedBox(width: 12), Expanded(child: Text('Solo puedes modificar los hábitos de hoy', style: TextStyle(fontWeight: FontWeight.w500)))]),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    
    if (user == null) return;
    HapticFeedback.lightImpact();

    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final habitRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').doc(habitId);
        
    await habitRef.update({
      'completions.$todayKey': {
        'progress': isCurrentlyCompleted ? 0 : 1,
        'completed': !isCurrentlyCompleted,
      }
    });

    if (!isCurrentlyCompleted) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSuccessSnackBar('¡Hábito completado! 🎉');
      }
    }
  }

  void _showAddHabitBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const VitoChatHabitSheet(),
    );
  }

  void _showEditHabitBottomSheet(String habitId, Map<String, dynamic> data) {
    // ADAPTADO A LA NUEVA ESTRUCTURA DE HABIT
    final timeData = data['specificTime'] as Map<String, dynamic>? ?? {'hour': 12, 'minute': 0};
    final time = TimeOfDay(hour: timeData['hour'], minute: timeData['minute']);
    
    // Creamos el objeto Habit completo, ahora incluyendo todos los campos requeridos
    final habit = Habit(
      id: habitId,
      name: data['name'] ?? 'Sin nombre',
      category: data['category'] ?? 'health',
      days: List<int>.from(data['days'] ?? []),
      specificTime: time,
      notifications: data['notifications'] ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      
      // --- LÍNEAS CORREGIDAS Y AÑADIDAS ---
      type: data['type'] as String? ?? 'simple', // Leemos el tipo desde los datos
      completions: Map<String, dynamic>.from(data['completions'] ?? {}), // Leemos el mapa de completions
      targetValue: data['targetValue'] as int?, // Leemos el valor objetivo
      unit: data['unit'] as String?, // Leemos la unidad
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VitoChatHabitSheet(habit: habit),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(Map<String, dynamic> timeData) {
    final hour = timeData['hour'] as int;
    final minute = timeData['minute'] as int;
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat.jm('es_ES').format(dateTime);
  }
}

// Custom painter para el patrón del header
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Dibujar círculos decorativos
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawCircle(
          Offset(i * 80.0 + 40, j * 80.0 + 40),
          20,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- CUSTOM CLIPPER PARA EL EFECTO SPOTLIGHT ---
class InvertedClipper extends CustomClipper<Path> {
  final Rect rect;
  final BoxShape shape;

  InvertedClipper({required this.rect, required this.shape});

  @override
  Path getClip(Size size) {
    // Path del fondo completo
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Path del "agujero"
    Path cutoutPath;
    if (shape == BoxShape.circle) {
      cutoutPath = Path()..addOval(rect);
    } else {
      cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    }

    // Combina los dos paths para crear el recorte
    return Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
  }

  @override
  bool shouldReclip(InvertedClipper oldClipper) {
    return rect != oldClipper.rect || shape != oldClipper.shape;
  }
}