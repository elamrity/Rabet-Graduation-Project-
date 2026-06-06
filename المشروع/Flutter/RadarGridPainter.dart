import 'dart:math';
import 'package:flutter/material.dart';

class RadarGridPainter extends CustomPainter {
  final Map<String, Offset> users;
  final double angle;

  RadarGridPainter({
    required this.users,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // =========================
    // 1) Background Glow
    // =========================
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bgPaint);

    // =========================
    // 2) Radar Grid
    // =========================
    final gridPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (radius / 4) * i, gridPaint);
    }

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      gridPaint,
    );

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      gridPaint,
    );

    // خطوط قطرية لزيادة شكل الرادار
    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy - radius * 0.7),
      Offset(center.dx + radius * 0.7, center.dy + radius * 0.7),
      gridPaint,
    );

    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy + radius * 0.7),
      Offset(center.dx + radius * 0.7, center.dy - radius * 0.7),
      gridPaint,
    );

    // =========================
    // 3) Sweep
    // =========================
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi / 3,
        colors: [
          Colors.cyanAccent.withOpacity(0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, radius, sweepPaint);
    canvas.restore();

    // =========================
    // 4) Rotating Line
    // =========================
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.9)
      ..strokeWidth = 2;

    final lineEnd = Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );

    canvas.drawLine(center, lineEnd, linePaint);

    // =========================
    // 5) Center Dot
    // =========================
    canvas.drawCircle(center, 6, Paint()..color = Colors.cyanAccent);

    // =========================
    // 6) Users Points
    // =========================
    for (var entry in users.entries) {
      final x = entry.value.dx;
      final y = entry.value.dy;

      // Scale الإحداثيات
      final scale = 50.0;

      double drawX = center.dx + (x * scale);
      double drawY = center.dy - (y * scale);

      // منع النقطة من الخروج خارج الرادار
      final point = Offset(drawX, drawY);
      final distance = (point - center).distance;

      Offset finalPoint = point;

      if (distance > radius - 15) {
        final dx = point.dx - center.dx;
        final dy = point.dy - center.dy;
        final theta = atan2(dy, dx);

        finalPoint = Offset(
          center.dx + cos(theta) * (radius - 15),
          center.dy + sin(theta) * (radius - 15),
        );
      }

      // Glow
      canvas.drawCircle(
        finalPoint,
        12,
        Paint()..color = Colors.cyanAccent.withOpacity(0.18),
      );

      // Dot
      canvas.drawCircle(
        finalPoint,
        5,
        Paint()..color = Colors.cyanAccent,
      );

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, finalPoint + const Offset(8, -16));
    }
  }

  @override
  bool shouldRepaint(covariant RadarGridPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.users != users;
  }
}