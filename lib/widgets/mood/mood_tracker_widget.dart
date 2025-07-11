import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../models/mood.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import 'mood_item.dart';
import 'cute_mood_icon.dart';

class MoodTrackerWidget extends StatefulWidget {
  final AnimationController? animationController;
  final bool showFullCard;
  final Function(String)? onMoodSaved;

  const MoodTrackerWidget({
    Key? key,
    this.animationController,
    this.showFullCard = true,
    this.onMoodSaved,
  }) : super(key: key);

  @override
  State<MoodTrackerWidget> createState() => _MoodTrackerWidgetState();
}

class _MoodTrackerWidgetState extends State<MoodTrackerWidget> {
  List<Map<String, dynamic>> _todaysMoods = [];
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadTodaysMood();
  }

  Future<void> _loadTodaysMood() async {
    if (user == null) return;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user!.uid)
      .collection('moods')
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
        _showMessage('Puedes registrar tu ánimo de nuevo en un rato.');
        return;
      }
    }

    HapticFeedback.lightImpact();
    await FirebaseFirestore.instance
      .collection('users')
      .doc(user!.uid)
      .collection('moods')
      .add({'mood': mood, 'timestamp': Timestamp.now()});

    // await NotificationService.cancelDailyMoodReminder();

    _loadTodaysMood();
    _showMessage('¡Ánimo registrado!');
    
    // Callback opcional
    widget.onMoodSaved?.call(mood);
  }

  void _showMessage(String message) {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastMoodName = _todaysMoods.isEmpty ? null : _todaysMoods.first['mood'];

    if (!widget.showFullCard) {
      // Versión compacta para mostrar en otras pantallas
      return _buildCompactVersion(lastMoodName);
    }

    // Versión completa con animaciones
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Cómo te sientes?',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Registra tu estado de ánimo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: MoodData.moods.map((mood) {
                    return MoodItem(
                      mood: mood,
                      isSelected: lastMoodName == mood.name,
                      onTap: () => _saveMood(mood.name),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Si hay animationController, aplicar animaciones
    if (widget.animationController != null) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: widget.animationController!,
          curve: const Interval(0.2, 1.0),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: widget.animationController!,
              curve: const Interval(0.2, 1.0),
            ),
          ),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildCompactVersion(String? lastMoodName) {
    final selectedMood = lastMoodName != null
        ? MoodData.moods.firstWhere(
            (mood) => mood.name == lastMoodName,
            orElse: () => MoodData.moods.first,
          )
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tu ánimo de hoy',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
          if (selectedMood != null)
            Row(
              children: [
                CuteMoodIcon(
                  color: selectedMood.baseColor,
                  expression: selectedMood.expression,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedMood.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selectedMood.gradient.last,
                  ),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/mood-tracker');
              },
              child: Text(
                'Registrar',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}