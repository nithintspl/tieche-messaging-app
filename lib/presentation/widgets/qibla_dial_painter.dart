import 'dart:math' as math;

import 'package:flutter/material.dart';

class QiblaDialPainter extends CustomPainter {
  QiblaDialPainter({
    required this.heading,
    required this.qiblaAngle,
    required this.isAligned,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  final double heading;
  final double qiblaAngle;
  final bool isAligned;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    _drawDialFace(canvas, radius);
    _drawQiblaPointer(canvas, radius);
    canvas.restore();

    _drawTopMarker(canvas, center, radius);
  }

  void _drawDialFace(Canvas canvas, double radius) {
    final fillPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, fillPaint);

    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    const cardinals = ['N', 'E', 'S', 'W'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var degree = 0; degree < 360; degree += 5) {
      final isMajor = degree % 30 == 0;
      final isCardinal = degree % 90 == 0;
      final tickLength = isCardinal ? 14.0 : (isMajor ? 10.0 : 5.0);
      final tickWidth = isCardinal ? 2.5 : 1.0;

      final paint = Paint()
        ..color = isCardinal ? primaryColor : onSurfaceColor.withValues(alpha: 0.45)
        ..strokeWidth = tickWidth;

      final outer = radius - 4;
      final inner = outer - tickLength;
      // 0° = North at top of screen (y-up in canvas-local space after center translate).
      final angle = (degree - 90) * math.pi / 180;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      canvas.drawLine(
        Offset(cosA * inner, sinA * inner),
        Offset(cosA * outer, sinA * outer),
        paint,
      );

      if (isCardinal) {
        final label = cardinals[degree ~/ 90];
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        final labelRadius = radius - 36;
        textPainter.paint(
          canvas,
          Offset(
            cosA * labelRadius - textPainter.width / 2,
            sinA * labelRadius - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawQiblaPointer(Canvas canvas, double radius) {
    final angle = (qiblaAngle - 90) * math.pi / 180;
    final tip = Offset(math.cos(angle) * (radius - 28), math.sin(angle) * (radius - 28));

    final pointerPaint = Paint()
      ..color = isAligned ? const Color(0xFF1B5E20) : const Color(0xFFC9A227)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 10, tip.dy + 22)
      ..lineTo(tip.dx, tip.dy + 14)
      ..lineTo(tip.dx + 10, tip.dy + 22)
      ..close();

    canvas.drawPath(path, pointerPaint);

    final kaabaPaint = Paint()
      ..color = pointerPaint.color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            math.cos(angle) * (radius - 48),
            math.sin(angle) * (radius - 48),
          ),
          width: 14,
          height: 14,
        ),
        const Radius.circular(3),
      ),
      kaabaPaint,
    );
  }

  void _drawTopMarker(Canvas canvas, Offset center, double radius) {
    final aligned = isAligned;
    final paint = Paint()
      ..color = aligned ? const Color(0xFF2E7D32) : primaryColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 8, center.dy - radius - 14)
      ..lineTo(center.dx + 8, center.dy - radius - 14)
      ..close();
    canvas.drawPath(path, paint);

    if (aligned) {
      final glow = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(center, radius, glow);
    }
  }

  @override
  bool shouldRepaint(covariant QiblaDialPainter oldDelegate) {
    return (oldDelegate.heading - heading).abs() > 0.05 ||
        (oldDelegate.qiblaAngle - qiblaAngle).abs() > 0.05 ||
        oldDelegate.isAligned != isAligned ||
        oldDelegate.primaryColor != primaryColor;
  }
}