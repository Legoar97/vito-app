// lib/widgets/coach_welcome_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CoachWelcomeView extends StatelessWidget {
  final AnimationController animationController;
  final Function(String) onCategorySelected;

  const CoachWelcomeView({
    Key? key,
    required this.animationController,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'name': 'Salud',
        'icon': Icons.favorite_rounded,
        'color': AppColors.categoryHealth,
        'gradient': [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
      },
      {
        'name': 'Mente',
        'icon': Icons.self_improvement,
        'color': AppColors.categoryMind,
        'gradient': [const Color(0xFF818CF8), const Color(0xFF6366F1)]
      },
      {
        'name': 'Trabajo',
        'icon': Icons.work_rounded,
        'color': AppColors.categoryProductivity,
        'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]
      },
      {
        'name': 'Creativo',
        'icon': Icons.palette_rounded,
        'color': AppColors.categoryCreativity,
        'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
      },
      {
        'name': 'Finanzas',
        'icon': Icons.attach_money_rounded,
        'color': AppColors.categoryFinance,
        'gradient': [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]
      },
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
                _buildLogo(),
                const SizedBox(height: 32),
                _buildTitle(),
                const SizedBox(height: 12),
                _buildSubtitle(),
                const SizedBox(height: 48),
                _buildCategoryGrid(categories),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          Icons.spa,
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

  Widget _buildSubtitle() {
    return Text(
      "Tu coach personal de bienestar.\n¿En qué área te gustaría enfocarte hoy?",
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: const Color(0xFF64748B),
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCategoryGrid(List<Map<String, dynamic>> categories) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: categories.map((category) {
        final gradientColors = category['gradient'] as List<Color>;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onCategorySelected(category['name'] as String);
          },
          child: _buildCategoryCard(category, gradientColors),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(
    Map<String, dynamic> category,
    List<Color> gradientColors,
  ) {
    return Container(
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
    );
  }
}