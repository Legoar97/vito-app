import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mood.dart';
import 'cute_mood_icon.dart';

class MoodItem extends StatelessWidget {
  final Mood mood;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodItem({
    Key? key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        // Añadido para centrar el contenido verticalmente, lo cual es bueno
        // cuando se usa Flexible.
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ¡AQUÍ ESTÁ LA SOLUCIÓN!
          // Flexible permite que el ícono se adapte al espacio disponible,
          // evitando que desborde cuando la animación lo hace más grande.
          Flexible(
            child: AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isSelected ? 14 : 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: mood.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: mood.gradient.first.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ]
                      : [],
                ),
                child: CuteMoodIcon(
                  color: isSelected ? Colors.white : mood.baseColor,
                  expression: mood.expression,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mood.name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? mood.gradient.last : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}