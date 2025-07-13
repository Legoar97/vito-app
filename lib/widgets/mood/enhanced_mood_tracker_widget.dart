// lib/widgets/mood/enhanced_mood_tracker_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mood.dart';
import '../../theme/app_colors.dart';
import '../../services/mood_ai_service.dart';
import 'mood_item.dart';
import 'mood_journal_widget.dart';

class EnhancedMoodTrackerWidget extends StatefulWidget {
  final AnimationController animationController;
  final Function(String)? onMoodSaved;

  const EnhancedMoodTrackerWidget({
    Key? key,
    required this.animationController,
    this.onMoodSaved,
  }) : super(key: key);

  @override
  State<EnhancedMoodTrackerWidget> createState() => _EnhancedMoodTrackerWidgetState();
}

class _EnhancedMoodTrackerWidgetState extends State<EnhancedMoodTrackerWidget> {
  final User? user = FirebaseAuth.instance.currentUser;
  Mood? _selectedMood;
  String? _aiResponse;
  bool _isLoading = false;
  bool _showJournal = false;
  DateTime? _nextCheckIn;
  bool _canCheckIn = true;

  Timer? _countdownTimer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    _checkLastMoodEntry();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLastMoodEntry() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastEntry = snapshot.docs.first.data();
        if (lastEntry['nextCheckIn'] != null) {
          final next = (lastEntry['nextCheckIn'] as Timestamp).toDate();
          if (next.isAfter(DateTime.now())) {
            setState(() {
              _nextCheckIn = next;
              _canCheckIn = false;
            });
            _startCountdown();
          }
        }
      }
    } catch (e) {
      print('Error checking last mood: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (_nextCheckIn == null) return;

    final remaining = _nextCheckIn!.difference(DateTime.now());
    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _canCheckIn = true;
          _countdownText = '';
        });
      }
    } else {
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          _countdownText = '$h:$m:$s';
        });
      }
    }
  }

  Future<void> _selectMood(Mood mood) async {
    if (!_canCheckIn) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ya has registrado tu ánimo. ¡Inténtalo más tarde!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _selectedMood = mood;
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final recentMoods = await _getRecentMoods();
      final response = await MoodAiService.generateMoodResponse(
        mood: mood.name,
        userContext: {'recentMoods': recentMoods ?? ''},
      );

      if (mounted) {
        setState(() {
          _aiResponse = response;
          _showJournal = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Me alegra que compartas cómo te sientes.';
          _showJournal = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _getRecentMoods() async {
    if (user == null) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.map((doc) => doc.data()['mood'] as String).join(', ');
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveMood(String journalEntry) async {
    if (user == null || _selectedMood == null) return;
    setState(() => _isLoading = true);
    try {
      final nextCheckIn = DateTime.now().add(const Duration(hours: 4));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .add({
        'mood': _selectedMood!.name,
        'timestamp': FieldValue.serverTimestamp(),
        'journalEntry': journalEntry.isNotEmpty ? journalEntry : null,
        'aiResponse': _aiResponse,
        'nextCheckIn': Timestamp.fromDate(nextCheckIn),
      });

      widget.onMoodSaved?.call(_selectedMood!.name);

      if (mounted) {
        setState(() {
          _showJournal = false;
          _selectedMood = null;
          _aiResponse = null;
          _nextCheckIn = nextCheckIn;
          _canCheckIn = false;
          _isLoading = false;
        });
        _startCountdown();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tu estado de ánimo ha sido registrado',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: _selectedMood!.baseColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error saving mood: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showJournal && _selectedMood != null) {
      return MoodJournalWidget(
        selectedMood: _selectedMood!,
        aiResponse: _aiResponse,
        onJournalSaved: _saveMood,
        onCancel: () {
          if (mounted) {
            setState(() {
              _showJournal = false;
              _selectedMood = null;
              _aiResponse = null;
            });
          }
        },
      );
    }

    return Column(
      children: [
        // Banner de cuenta regresiva
        if (!_canCheckIn && _countdownText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Vuelve en $_countdownText',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        FadeTransition(
          opacity: CurvedAnimation(
            parent: widget.animationController,
            curve: const Interval(0.2, 1.0),
          ),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                Text(
                  '¿Cómo te sientes hoy?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: MoodData.moods.length,
                  itemBuilder: (context, index) {
                    final mood = MoodData.moods[index];
                    return MoodItem(
                      mood: mood,
                      isSelected: _selectedMood == mood,
                      onTap: () => _selectMood(mood),
                    );
                  },
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
