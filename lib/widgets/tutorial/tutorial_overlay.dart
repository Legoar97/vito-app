// lib/widgets/tutorial/tutorial_overlay.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/tutorial_controller.dart';
import '../../theme/app_colors.dart';
import '../mood/mood_tracker_widget.dart';
import '../progress_card.dart';
import 'tutorial_dialog.dart';

class TutorialOverlay extends StatelessWidget {
  final TutorialController controller;
  final String userName;
  final VoidCallback onComplete;

  const TutorialOverlay({
    Key? key,
    required this.controller,
    required this.userName,
    required this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stepInfo = controller.getCurrentStepInfo();

    if (stepInfo.isWelcome) {
      return _buildWelcomeDialog(context);
    }

    if (stepInfo.showStaticWidget) {
      return _buildStaticStepOverlay(context, stepInfo);
    }

    return _buildSpotlightOverlay(context, stepInfo);
  }

  Widget _buildWelcomeDialog(BuildContext context) {
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
                  Icon(
                    Icons.spa_rounded,
                    color: AppColors.primary,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    userName.isNotEmpty
                        ? '¡Hola, $userName!'
                        : '¡Qué bueno tenerte aquí!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vito es tu espacio para construir una vida más saludable y feliz, '
                    'un pequeño paso a la vez. El verdadero cambio viene de la constancia, '
                    'y mi trabajo es hacer que ese camino sea fácil y motivador para ti. '
                    'En este rápido tour, te mostraré las herramientas clave que usaremos juntos. 🌱',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF64748B),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: controller.nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '¡Comencemos!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticStepOverlay(BuildContext context, TutorialStepInfo stepInfo) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo oscuro
          Positioned.fill(
            child: GestureDetector(
              onTap: controller.nextStep,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
          // Widget estático y diálogo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.tutorialStep == 0)
                  const MoodTrackerWidget(showFullCard: true),
                if (controller.tutorialStep == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: ProgressCard(
                      allHabits: [],
                      totalHabits: 0,
                      completedHabits: 0,
                      progress: 0.0,
                      streak: 0,
                      animationController: AnimationController(
                        duration: const Duration(milliseconds: 1200),
                        vsync: Navigator.of(context),
                      )..forward(),
                    ),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TutorialDialog(
                    title: stepInfo.title,
                    description: stepInfo.description,
                    isLastStep: stepInfo.isLastStep,
                    onNext: stepInfo.isLastStep
                        ? () async {
                            await controller.completeAndStartCreatingHabit();
                            onComplete();
                          }
                        : controller.nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightOverlay(BuildContext context, TutorialStepInfo stepInfo) {
    final highlightRect = stepInfo.widgetKey != null
        ? controller.getWidgetRect(stepInfo.widgetKey!)
        : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: stepInfo.isLastStep ? null : controller.nextStep,
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
              bottom: MediaQuery.of(context).size.height - highlightRect.top + 20,
              left: 20,
              right: 20,
              child: TutorialDialog(
                title: stepInfo.title,
                description: stepInfo.description,
                isLastStep: stepInfo.isLastStep,
                onNext: stepInfo.isLastStep
                    ? () async {
                        await controller.completeAndStartCreatingHabit();
                        onComplete();
                      }
                    : controller.nextStep,
              ),
            ),
        ],
      ),
    );
  }
}

// Custom clipper para el efecto spotlight
class InvertedClipper extends CustomClipper<Path> {
  final Rect rect;
  final BoxShape shape;

  InvertedClipper({required this.rect, required this.shape});

  @override
  Path getClip(Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    Path cutoutPath;
    if (shape == BoxShape.circle) {
      cutoutPath = Path()..addOval(rect);
    } else {
      cutoutPath = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    }

    return Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
  }

  @override
  bool shouldReclip(InvertedClipper oldClipper) {
    return rect != oldClipper.rect || shape != oldClipper.shape;
  }
}