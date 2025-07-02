import 'package:flutter/material.dart';
import '../../models/mood.dart';

class CuteMoodIcon extends StatelessWidget {
  final Color color;
  final MoodExpression expression;
  final double size;

  const CuteMoodIcon({
    Key? key,
    required this.color,
    required this.expression,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: CuteMoodPainter(color: color, expression: expression),
    );
  }
}

class CuteMoodPainter extends CustomPainter {
  final Color color;
  final MoodExpression expression;

  CuteMoodPainter({required this.color, required this.expression});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cara base
    final facePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, facePaint);

    // Variables para ojos
    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final eyeRadius = radius * 0.1;
    final eyeY = center.dy - radius * 0.2;
    final eyeSpacing = radius * 0.3;

    // Boca según la expresión
    final mouthPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case MoodExpression.excellent:
        _drawExcellentFace(canvas, center, radius, eyeY, eyeSpacing);
        break;
      case MoodExpression.good:
        _drawGoodFace(canvas, center, radius, eyePaint, eyeRadius, eyeY, eyeSpacing, mouthPaint);
        break;
      case MoodExpression.okay:
        _drawOkayFace(canvas, center, radius, eyePaint, eyeRadius, eyeY, eyeSpacing, mouthPaint);
        break;
      case MoodExpression.bad:
        _drawBadFace(canvas, center, radius, eyeY, eyeSpacing, mouthPaint);
        break;
      case MoodExpression.terrible:
        _drawTerribleFace(canvas, center, radius, eyePaint, eyeRadius, eyeY, eyeSpacing);
        break;
    }
  }

  void _drawExcellentFace(Canvas canvas, Offset center, double radius, double eyeY, double eyeSpacing) {
    // Ojos felices (cerrados en forma de arco)
    final happyEyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round;
    
    final eyePath1 = Path();
    eyePath1.addArc(
      Rect.fromCenter(
        center: Offset(center.dx - eyeSpacing, eyeY),
        width: radius * 0.3,
        height: radius * 0.3,
      ),
      0,
      3.14,
    );
    canvas.drawPath(eyePath1, happyEyePaint);
    
    final eyePath2 = Path();
    eyePath2.addArc(
      Rect.fromCenter(
        center: Offset(center.dx + eyeSpacing, eyeY),
        width: radius * 0.3,
        height: radius * 0.3,
      ),
      0,
      3.14,
    );
    canvas.drawPath(eyePath2, happyEyePaint);

    // Sonrisa muy grande
    final mouthPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final startX = center.dx - radius * 0.4;
    final endX = center.dx + radius * 0.4;
    final mouthY = center.dy + radius * 0.05;

    path.moveTo(startX, mouthY);
    path.quadraticBezierTo(
      center.dx,
      mouthY + radius * 0.45,
      endX,
      mouthY,
    );
    canvas.drawPath(path, mouthPaint);

    // Mejillas rosadas
    final blushPaint = Paint()
      ..color = Colors.pink.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - radius * 0.55, center.dy + radius * 0.05),
      radius * 0.2,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.55, center.dy + radius * 0.05),
      radius * 0.2,
      blushPaint,
    );
  }

  void _drawGoodFace(Canvas canvas, Offset center, double radius, Paint eyePaint, 
      double eyeRadius, double eyeY, double eyeSpacing, Paint mouthPaint) {
    // Ojos normales
    canvas.drawCircle(
        Offset(center.dx - eyeSpacing, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + eyeSpacing, eyeY), eyeRadius, eyePaint);

    // Sonrisa normal
    final path = Path();
    final startX = center.dx - radius * 0.3;
    final endX = center.dx + radius * 0.3;
    final mouthY = center.dy + radius * 0.15;

    path.moveTo(startX, mouthY);
    path.quadraticBezierTo(
      center.dx,
      mouthY + radius * 0.25,
      endX,
      mouthY,
    );
    canvas.drawPath(path, mouthPaint);
  }

  void _drawOkayFace(Canvas canvas, Offset center, double radius, Paint eyePaint,
      double eyeRadius, double eyeY, double eyeSpacing, Paint mouthPaint) {
    // Ojos normales
    canvas.drawCircle(
        Offset(center.dx - eyeSpacing, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + eyeSpacing, eyeY), eyeRadius, eyePaint);

    // Línea recta
    canvas.drawLine(
      Offset(center.dx - radius * 0.25, center.dy + radius * 0.25),
      Offset(center.dx + radius * 0.25, center.dy + radius * 0.25),
      mouthPaint,
    );
  }

  void _drawBadFace(Canvas canvas, Offset center, double radius, double eyeY, 
      double eyeSpacing, Paint mouthPaint) {
    // Ojos tristes
    final sadEyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    final eyeRadius = radius * 0.1;
    
    canvas.save();
    canvas.translate(center.dx - eyeSpacing, eyeY);
    canvas.rotate(-0.2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: eyeRadius * 2, height: eyeRadius * 1.5),
      sadEyePaint,
    );
    canvas.restore();
    
    canvas.save();
    canvas.translate(center.dx + eyeSpacing, eyeY);
    canvas.rotate(0.2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: eyeRadius * 2, height: eyeRadius * 1.5),
      sadEyePaint,
    );
    canvas.restore();

    // Boca triste
    final path = Path();
    final startX = center.dx - radius * 0.25;
    final endX = center.dx + radius * 0.25;
    final mouthY = center.dy + radius * 0.35;

    path.moveTo(startX, mouthY);
    path.quadraticBezierTo(
      center.dx,
      mouthY - radius * 0.2,
      endX,
      mouthY,
    );
    canvas.drawPath(path, mouthPaint);
  }

  void _drawTerribleFace(Canvas canvas, Offset center, double radius, Paint eyePaint,
      double eyeRadius, double eyeY, double eyeSpacing) {
    // Ojos normales pero con mirada triste
    canvas.drawCircle(
        Offset(center.dx - eyeSpacing, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + eyeSpacing, eyeY), eyeRadius, eyePaint);

    // Boca tipo D: (shock/horror)
    final mouthRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.3),
      width: radius * 0.5,
      height: radius * 0.4,
    );
    
    // Dibuja la boca abierta hacia arriba (invertida)
    final mouthPath = Path();
    mouthPath.addArc(mouthRect, 3.14, 3.14); // Arco invertido
    
    // Relleno de la boca
    final mouthFillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(mouthPath, mouthFillPaint);
    
    // Línea inferior de la boca (para dar profundidad)
    final mouthLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02;
    
    canvas.drawLine(
      Offset(mouthRect.left + radius * 0.05, mouthRect.bottom - radius * 0.05),
      Offset(mouthRect.right - radius * 0.05, mouthRect.bottom - radius * 0.05),
      mouthLinePaint,
    );

    // MÚLTIPLES LÁGRIMAS
    final tearPaint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Función para dibujar una lágrima
    void drawTear(double x, double y, double size) {
      final tearPath = Path();
      tearPath.moveTo(x, y);
      tearPath.quadraticBezierTo(
        x - radius * size * 0.08,
        y + radius * size * 0.2,
        x,
        y + radius * size * 0.25,
      );
      tearPath.quadraticBezierTo(
        x + radius * size * 0.08,
        y + radius * size * 0.2,
        x,
        y,
      );
      canvas.drawPath(tearPath, tearPaint);
    }

    // Lágrimas del ojo izquierdo
    drawTear(center.dx - eyeSpacing, eyeY + radius * 0.15, 1.2);
    drawTear(center.dx - eyeSpacing - radius * 0.12, eyeY + radius * 0.25, 0.8);
    drawTear(center.dx - eyeSpacing + radius * 0.08, eyeY + radius * 0.35, 0.6);
    
    // Lágrimas del ojo derecho
    drawTear(center.dx + eyeSpacing, eyeY + radius * 0.15, 1.2);
    drawTear(center.dx + eyeSpacing + radius * 0.12, eyeY + radius * 0.25, 0.8);
    drawTear(center.dx + eyeSpacing - radius * 0.08, eyeY + radius * 0.35, 0.6);
    
    // Lágrima adicional en el centro
    drawTear(center.dx, eyeY + radius * 0.45, 0.7);
    
    // Pequeñas gotas adicionales para más dramatismo
    final dropPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    // Gotitas pequeñas
    canvas.drawCircle(
      Offset(center.dx - eyeSpacing - radius * 0.2, eyeY + radius * 0.4),
      radius * 0.03,
      dropPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + eyeSpacing + radius * 0.2, eyeY + radius * 0.4),
      radius * 0.03,
      dropPaint,
    );
    canvas.drawCircle(
      Offset(center.dx, eyeY + radius * 0.6),
      radius * 0.025,
      dropPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}