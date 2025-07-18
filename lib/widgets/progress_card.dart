// lib/screens/habits/widgets/progress_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';

class ProgressCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> allHabits;
  final int totalHabits;
  final int completedHabits;
  final double progress;
  final int streak;
  final AnimationController animationController;

  const ProgressCard({
    Key? key,
    required this.allHabits,
    required this.totalHabits,
    required this.completedHabits,
    required this.progress,
    required this.streak,
    required this.animationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animationController,
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
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProgressBar(context),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                '$completedHabits de $totalHabits completados',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (streak > 0) _buildStreakBadge(),
      ],
    );
  }

  Widget _buildStreakBadge() {
    return Container(
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
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    // --- INICIO DE LA CORRECCIÓN ---
    // 1. Usamos LayoutBuilder para obtener el ancho real disponible para la barra.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 'constraints.maxWidth' nos da el ancho exacto del contenedor padre.
        final availableWidth = constraints.maxWidth;

        return Stack(
          children: [
            // El fondo de la barra, que ocupa todo el ancho disponible.
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // La barra de progreso animada.
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 12,
              // 2. Calculamos el ancho basándonos en el espacio real, no en la pantalla.
              //    Y eliminamos el número mágico "0.75".
              width: availableWidth * progress,
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
        );
      },
    );
    // --- FIN DE LA CORRECCIÓN ---
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center, // Ayuda a alinear verticalmente
      children: [
        // --- INICIO DE LA CORRECCIÓN ---
        // 1. Envolvemos la Row interna en un Expanded.
        //    Esto le dice que ocupe todo el espacio que pueda,
        //    empujando al otro widget hacia el borde derecho.
        Expanded(
          child: Row(
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
              // 2. Envolvemos el Text en Flexible.
              //    Esto es una buena práctica dentro de un Expanded para
              //    asegurarnos de que el texto se cortará con "..." si
              //    fuera extremadamente largo, en lugar de desbordarse.
              Flexible(
                child: Text(
                  '${(progress * 100).toInt()}% completado',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis, // Evita desbordamientos de texto
                ),
              ),
            ],
          ),
        ),
        // --- FIN DE LA CORRECCIÓN ---

        // Si el progreso es 100%, la insignia ahora tendrá su propio espacio
        // sin causar un desbordamiento.
        if (progress == 1.0) _buildCompletedBadge(),
      ],
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
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
    );
  }
}