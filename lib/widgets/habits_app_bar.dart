// lib/screens/habits/widgets/habits_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../theme/app_colors.dart';
import 'week_selector.dart';

class HabitsAppBar extends StatelessWidget {
  final AnimationController animationController;
  final double scrollOffset;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final String greeting;
  final String quote;

  const HabitsAppBar({
    Key? key,
    required this.animationController,
    required this.scrollOffset,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.greeting,
    required this.quote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              _buildDecorativeCircles(),
              // Contenido principal
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      _buildGreetingSection(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: _buildWeekSelectorSection(),
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

  Widget _buildDecorativeCircles() {
    return Stack(
      children: [
        Positioned(
          top: -50 - (scrollOffset * 0.5),
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
          bottom: -40 - (scrollOffset * 0.3),
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
      ],
    );
  }

  Widget _buildGreetingSection() {
    return FadeTransition(
      opacity: animationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.3, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.easeOut,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quote,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelectorSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onPreviousDay();
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
          child: WeekSelector(
            selectedDate: selectedDate,
            onDateSelected: onDateChanged,
          ),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onNextDay();
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