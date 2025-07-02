// lib/screens/habits/controllers/timer_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TimerController extends ChangeNotifier {
  Timer? _habitTimer;
  String? _activeTimerHabitId;
  int _timerSecondsRemaining = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Getters
  String? get activeTimerHabitId => _activeTimerHabitId;
  int get timerSecondsRemaining => _timerSecondsRemaining;
  bool get isTimerActive => _activeTimerHabitId != null;
  
  TimerController() {
    _initializeBackgroundService();
  }
  
  void _initializeBackgroundService() {
    final service = FlutterBackgroundService();
    
    // Escucha actualizaciones del temporizador
    service.on('update').listen((event) {
      if (_activeTimerHabitId != null && event != null) {
        _timerSecondsRemaining = event['remaining'] as int? ?? 0;
        notifyListeners();
      }
    });
    
    // Escucha cuando el temporizador termina
    service.on('timerFinished').listen((event) {
      if (_activeTimerHabitId != null) {
        completeTimedHabit(_activeTimerHabitId!);
        stopTimer();
      }
    });
  }
  
  void startTimer(String habitId, int durationMinutes) {
    // Inicia el servicio en segundo plano
    FlutterBackgroundService().startService();
    
    _habitTimer?.cancel();
    
    _activeTimerHabitId = habitId;
    _timerSecondsRemaining = durationMinutes * 60;
    notifyListeners();
    
    _habitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSecondsRemaining > 0) {
        _timerSecondsRemaining--;
        notifyListeners();
      } else {
        _habitTimer?.cancel();
        completeTimedHabit(_activeTimerHabitId!);
        stopTimer();
      }
    });
  }
  
  void stopTimer() {
    // Detiene el servicio en segundo plano
    FlutterBackgroundService().invoke("stopService");
    
    _habitTimer?.cancel();
    _activeTimerHabitId = null;
    _timerSecondsRemaining = 0;
    notifyListeners();
  }
  
  Future<void> completeTimedHabit(String habitId) async {
    if (user == null) return;
    
    // Detiene el servicio ya que el timer terminó
    FlutterBackgroundService().invoke("stopService");
    
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .doc(habitId);
    
    await habitRef.update({
      'completions.$todayKey': {
        'progress': 1,
        'completed': true,
      }
    });
  }
  
  String getFormattedTime() {
    final minutes = (_timerSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_timerSecondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  @override
  void dispose() {
    _habitTimer?.cancel();
    if (_activeTimerHabitId != null) {
      FlutterBackgroundService().invoke("stopService");
    }
    super.dispose();
  }
}