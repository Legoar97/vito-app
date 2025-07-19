// lib/widgets/coach_welcome_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CoachWelcomeView extends StatelessWidget {
  final AnimationController animationController;
  // ELIMINAMOS 'onCategorySelected' Y AÑADIMOS 'onOnboardingComplete'
  final VoidCallback onOnboardingComplete;

  const CoachWelcomeView({
    Key? key,
    required this.animationController,
    required this.onOnboardingComplete, // <-- Parámetro nuevo y más claro
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // La estructura principal y el fondo se mantienen, son muy bonitos.
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
              crossAxisAlignment: CrossAxisAlignment.stretch, // Para centrar el botón
              children: [
                _buildLogo(),
                const SizedBox(height: 32),
                _buildTitle(),
                const SizedBox(height: 16),
                // HEMOS CAMBIADO EL SUBTÍTULO POR UN TEXTO INFORMATIVO
                _buildInfoText(),
                const SizedBox(height: 48),
                // HEMOS REEMPLAZADO LA CUADRÍCULA DE CATEGORÍAS POR UN ÚNICO BOTÓN
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // El logo y el título se mantienen igual
  Widget _buildLogo() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animationController,
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
          Icons.spa_rounded, // Un icono ligeramente diferente y más redondeado
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      "¡Hola! Soy Vito",
      style: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E293B),
      ),
      textAlign: TextAlign.center,
    );
  }

  // WIDGET MODIFICADO: Ahora es un texto de bienvenida más general.
  Widget _buildInfoText() {
    return Text(
      "Estoy aquí para ayudarte a construir hábitos positivos y mejorar tu bienestar día a día.\n\n¡Empecemos este viaje juntos!",
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: const Color(0xFF64748B),
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  // WIDGET NUEVO: El botón para continuar.
  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        // Simplemente llamamos a la función que nos pasaron,
        // la lógica estará en el widget padre.
        onOnboardingComplete();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 5,
        shadowColor: AppColors.primary.withOpacity(0.4),
      ),
      child: Text(
        'Entendido',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}