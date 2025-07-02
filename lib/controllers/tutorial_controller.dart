// lib/screens/habits/controllers/tutorial_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TutorialController extends ChangeNotifier {
  bool _showTutorial = false;
  int _tutorialStep = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Keys para los elementos del tutorial
  final GlobalKey moodTrackerKey = GlobalKey();
  final GlobalKey progressCardKey = GlobalKey();
  final GlobalKey fabKey = GlobalKey();
  
  // Getters
  bool get showTutorial => _showTutorial;
  int get tutorialStep => _tutorialStep;
  bool get isInWelcomeStep => _tutorialStep == -1;
  
  Future<void> checkOnboardingStatus() async {
    if (user == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
          
      final onboardingCompleted = userDoc.data()?['onboardingCompleted'] ?? false;
      
      if (!onboardingCompleted) {
        _showTutorial = true;
        _tutorialStep = -1; // Empieza con la bienvenida
        notifyListeners();
      }
    } catch (e) {
      print("Error al verificar estado de onboarding: $e");
    }
  }
  
  void nextStep() {
    _tutorialStep++;
    notifyListeners();
  }
  
  void skipTutorial() {
    _completeTutorial();
  }
  
  Future<void> _completeTutorial() async {
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));
      
      _showTutorial = false;
      _tutorialStep = 0;
      notifyListeners();
    } catch (e) {
      print("Error al completar el tutorial: $e");
    }
  }
  
  Future<void> completeAndStartCreatingHabit() async {
    await _completeTutorial();
    // El callback para abrir el sheet de creación se maneja en la UI
  }
  
  Rect? getWidgetRect(GlobalKey key) {
    final RenderBox? renderBox = 
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    }
    return null;
  }
  
  TutorialStepInfo getCurrentStepInfo() {
    switch (_tutorialStep) {
      case -1:
        return TutorialStepInfo(
          title: '',
          description: '',
          isWelcome: true,
        );
      case 0:
        return TutorialStepInfo(
          title: 'Registra tu Ánimo',
          description: 'Empecemos por aquí. Toca un emoji para registrar cómo te sientes. '
              'Esto te ayudará a ver la conexión entre tu ánimo y tus hábitos. '
              'Puedes registrar tu ánimo cada 3 horas.',
          widgetKey: moodTrackerKey,
          showStaticWidget: true,
        );
      case 1:
        return TutorialStepInfo(
          title: 'Tu Centro de Mando',
          description: 'Esta tarjeta te mostrará tu progreso diario y tu racha de constancia. '
              '¡Vamos a llenarla!',
          widgetKey: progressCardKey,
          showStaticWidget: true,
        );
      case 2:
        return TutorialStepInfo(
          title: 'Crea tu Primer Hábito',
          description: 'Toca este botón para añadir un nuevo hábito. '
              'Te ayudaré a configurarlo paso a paso.',
          widgetKey: fabKey,
          isLastStep: true,
        );
      default:
        return TutorialStepInfo(
          title: '',
          description: '',
        );
    }
  }
}

class TutorialStepInfo {
  final String title;
  final String description;
  final GlobalKey? widgetKey;
  final bool isWelcome;
  final bool isLastStep;
  final bool showStaticWidget;
  
  TutorialStepInfo({
    required this.title,
    required this.description,
    this.widgetKey,
    this.isWelcome = false,
    this.isLastStep = false,
    this.showStaticWidget = false,
  });
}