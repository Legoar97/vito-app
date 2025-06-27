import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // User data to collect
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedGoals = {};
  final Set<String> _selectedAreas = {};
  String _experienceLevel = '';
  String _preferredTime = '';
  final List<Map<String, dynamic>> _suggestedHabits = [];
  final Set<int> _selectedHabitIndices = {};

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage == 5) {
        // Generate suggestions before showing them
        _generateHabitSuggestions();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 1: // Name page
        if (_nameController.text.trim().isEmpty) {
          _showError('Por favor ingresa tu nombre');
          return false;
        }
        return true;
      case 2: // Goals page
        if (_selectedGoals.isEmpty) {
          _showError('Por favor selecciona al menos un objetivo');
          return false;
        }
        return true;
      case 3: // Areas page
        if (_selectedAreas.isEmpty) {
          _showError('Por favor selecciona al menos un área de interés');
          return false;
        }
        return true;
      case 4: // Experience page
        if (_experienceLevel.isEmpty) {
          _showError('Por favor selecciona tu nivel de experiencia');
          return false;
        }
        return true;
      case 5: // Time preference page
        if (_preferredTime.isEmpty) {
          _showError('Por favor selecciona tu horario preferido');
          return false;
        }
        return true;
      case 6: // Habit selection page
        if (_selectedHabitIndices.isEmpty) {
          _showError('Por favor selecciona al menos un hábito para comenzar');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _generateHabitSuggestions() {
    _suggestedHabits.clear();
    
    // Generate personalized suggestions based on user selections
    if (_selectedAreas.contains('health')) {
      _suggestedHabits.addAll([
        {'name': 'Beber 8 vasos de agua al día', 'category': 'health', 'icon': Icons.water_drop},
        {'name': 'Caminar 10,000 pasos', 'category': 'health', 'icon': Icons.directions_walk},
      ]);
    }
    
    if (_selectedAreas.contains('mindfulness')) {
      _suggestedHabits.addAll([
        {'name': 'Meditar 10 minutos', 'category': 'mind', 'icon': Icons.self_improvement},
        {'name': 'Escribir 3 cosas por las que agradecer', 'category': 'mind', 'icon': Icons.edit_note},
      ]);
    }
    
    if (_selectedAreas.contains('productivity')) {
      _suggestedHabits.addAll([
        {'name': 'Planificar el día siguiente', 'category': 'productivity', 'icon': Icons.calendar_today},
        {'name': 'Leer 20 páginas de un libro', 'category': 'productivity', 'icon': Icons.menu_book},
      ]);
    }
    
    if (_selectedAreas.contains('fitness')) {
      _suggestedHabits.addAll([
        {'name': 'Hacer 20 flexiones', 'category': 'health', 'icon': Icons.fitness_center},
        {'name': 'Estirar por 15 minutos', 'category': 'health', 'icon': Icons.accessibility_new},
      ]);
    }
    
    if (_selectedAreas.contains('creativity')) {
      _suggestedHabits.addAll([
        {'name': 'Dibujar o escribir algo creativo', 'category': 'creativity', 'icon': Icons.palette},
        {'name': 'Aprender algo nuevo', 'category': 'creativity', 'icon': Icons.lightbulb},
      ]);
    }
    
    if (_selectedAreas.contains('social')) {
      _suggestedHabits.addAll([
        {'name': 'Conectar con un amigo o familiar', 'category': 'relationships', 'icon': Icons.people},
        {'name': 'Hacer un acto de bondad', 'category': 'relationships', 'icon': Icons.favorite},
      ]);
    }
    
    // Add beginner-friendly habits if new to habit building
    if (_experienceLevel == 'beginner') {
      _suggestedHabits.insert(0, {
        'name': 'Hacer la cama cada mañana',
        'category': 'productivity',
        'icon': Icons.bed,
      });
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save user profile data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'displayName': _nameController.text.trim(),
        'onboardingCompleted': true,
        'profile': {
          'goals': _selectedGoals.toList(),
          'interests': _selectedAreas.toList(),
          'experienceLevel': _experienceLevel,
          'preferredTime': _preferredTime,
          'createdAt': Timestamp.now(),
        },
        'aiContext': {
          'personalInfo': {
            'name': _nameController.text.trim(),
            'goals': _selectedGoals.toList(),
            'focusAreas': _selectedAreas.toList(),
            'habitExperience': _experienceLevel,
            'dailySchedulePreference': _preferredTime,
          },
        },
      }, SetOptions(merge: true));

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Add selected habits
      for (int index in _selectedHabitIndices) {
        final habit = _suggestedHabits[index];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('habits')
            .add({
          'name': habit['name'],
          'category': habit['category'],
          'days': [1, 2, 3, 4, 5, 6, 7], // All days by default
          'specificTime': _getTimeFromPreference(),
          'notifications': true,
          'completions': [],
          'createdAt': Timestamp.now(),
          'source': 'onboarding',
        });
      }

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      _showError('Error al guardar tus preferencias: $e');
    }
  }

  Map<String, int> _getTimeFromPreference() {
    switch (_preferredTime) {
      case 'morning':
        return {'hour': 7, 'minute': 0};
      case 'afternoon':
        return {'hour': 14, 'minute': 0};
      case 'evening':
        return {'hour': 19, 'minute': 0};
      case 'night':
        return {'hour': 21, 'minute': 0};
      default:
        return {'hour': 9, 'minute': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9FE), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              if (_currentPage > 0)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: LinearProgressIndicator(
                    value: _currentPage / 7,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              
              // Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildWelcomePage(),
                    _buildNamePage(),
                    _buildGoalsPage(),
                    _buildAreasPage(),
                    _buildExperiencePage(),
                    _buildTimePage(),
                    _buildHabitSuggestionsPage(),
                    _buildCompletionPage(),
                  ],
                ),
              ),
              
              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spa, size: 80, color: AppColors.primary),
          const SizedBox(height: 32),
          Text(
            'Bienvenido a Vito',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vamos a personalizar tu experiencia para ayudarte a construir hábitos que realmente se mantengan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Cómo te llamas?',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Me encantaría conocerte mejor',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24),
            decoration: InputDecoration(
              hintText: 'Tu nombre',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    final goals = [
      {'id': 'health', 'title': 'Mejorar mi salud', 'icon': Icons.favorite},
      {'id': 'productivity', 'title': 'Ser más productivo', 'icon': Icons.trending_up},
      {'id': 'stress', 'title': 'Reducir el estrés', 'icon': Icons.spa},
      {'id': 'happiness', 'title': 'Ser más feliz', 'icon': Icons.mood},
      {'id': 'growth', 'title': 'Crecimiento personal', 'icon': Icons.psychology},
      {'id': 'balance', 'title': 'Encontrar balance', 'icon': Icons.balance},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            '¿Cuáles son tus objetivos?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona todos los que apliquen',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final isSelected = _selectedGoals.contains(goal['id']);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedGoals.remove(goal['id']);
                      } else {
                        _selectedGoals.add(goal['id'] as String);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          goal['icon'] as IconData,
                          size: 32,
                          color: isSelected ? AppColors.primary : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          goal['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreasPage() {
    final areas = [
      {'id': 'health', 'title': 'Salud física', 'icon': Icons.favorite},
      {'id': 'mindfulness', 'title': 'Mindfulness', 'icon': Icons.self_improvement},
      {'id': 'productivity', 'title': 'Productividad', 'icon': Icons.work},
      {'id': 'fitness', 'title': 'Ejercicio', 'icon': Icons.fitness_center},
      {'id': 'creativity', 'title': 'Creatividad', 'icon': Icons.palette},
      {'id': 'social', 'title': 'Relaciones', 'icon': Icons.people},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            '¿En qué áreas quieres enfocarte?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Esto me ayudará a sugerirte los mejores hábitos',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final area = areas[index];
                final isSelected = _selectedAreas.contains(area['id']);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAreas.remove(area['id']);
                      } else {
                        _selectedAreas.add(area['id'] as String);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          area['icon'] as IconData,
                          size: 32,
                          color: isSelected ? AppColors.primary : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          area['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencePage() {
    final levels = [
      {
        'id': 'beginner',
        'title': 'Soy nuevo en esto',
        'subtitle': 'Quiero empezar con calma',
        'icon': Icons.egg,
      },
      {
        'id': 'intermediate',
        'title': 'Tengo algo de experiencia',
        'subtitle': 'He intentado formar hábitos antes',
        'icon': Icons.trending_up,
      },
      {
        'id': 'advanced',
        'title': 'Soy experimentado',
        'subtitle': 'Busco optimizar mi rutina',
        'icon': Icons.rocket_launch,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            '¿Cuál es tu experiencia con hábitos?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                final isSelected = _experienceLevel == level['id'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _experienceLevel = level['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              level['icon'] as IconData,
                              color: isSelected ? AppColors.primary : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level['title'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primary : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  level['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePage() {
    final times = [
      {'id': 'morning', 'title': 'Por la mañana', 'subtitle': '6:00 - 12:00', 'icon': Icons.wb_sunny},
      {'id': 'afternoon', 'title': 'Por la tarde', 'subtitle': '12:00 - 18:00', 'icon': Icons.wb_twilight},
      {'id': 'evening', 'title': 'Por la noche', 'subtitle': '18:00 - 22:00', 'icon': Icons.nightlight_round},
      {'id': 'flexible', 'title': 'Variable', 'subtitle': 'Diferentes momentos', 'icon': Icons.schedule},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            '¿Cuándo prefieres hacer tus hábitos?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes cambiar esto después',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: times.length,
              itemBuilder: (context, index) {
                final time = times[index];
                final isSelected = _preferredTime == time['id'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _preferredTime = time['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            time['icon'] as IconData,
                            size: 32,
                            color: isSelected ? AppColors.primary : Colors.grey[600],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  time['title'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primary : Colors.black87,
                                  ),
                                ),
                                Text(
                                  time['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitSuggestionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Hábitos sugeridos para ti',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona algunos para empezar',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestedHabits.length,
              itemBuilder: (context, index) {
                final habit = _suggestedHabits[index];
                final isSelected = _selectedHabitIndices.contains(index);
                final categoryColor = AppColors.getCategoryColor(habit['category']);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedHabitIndices.remove(index);
                        } else {
                          _selectedHabitIndices.add(index);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? categoryColor.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? categoryColor : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              habit['icon'] as IconData,
                              color: categoryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              habit['name'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? categoryColor : Colors.black87,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? categoryColor : Colors.grey[400]!,
                                width: 2,
                              ),
                              color: isSelected ? categoryColor : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionPage() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration,
              size: 50,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '¡Todo listo, ${_nameController.text}!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'He personalizado Vito especialmente para ti. Comencemos este viaje juntos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.tips_and_updates, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  'Tip: Empieza pequeño',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los mejores hábitos son los que puedes mantener',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          if (_currentPage > 0)
            TextButton(
              onPressed: _previousPage,
              child: const Text('Atrás'),
            )
          else
            const SizedBox(width: 80),
          
          // Next/Complete button
          ElevatedButton(
            onPressed: _currentPage == 7 ? _completeOnboarding : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              _currentPage == 7 ? 'Comenzar' : 'Siguiente',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}