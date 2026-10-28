import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vẽ hai bàn tay ảo và vòng "đang nạp" quanh bàn tay đang chọn đáp án.
class HandCursorPainter extends CustomPainter {
  HandCursorPainter({
    required this.hands,
    required this.activePoint,
    required this.progress,
  });

  final List<Offset?> hands;
  final Offset? activePoint;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.04;
    final fill = Paint()..color = Colors.white.withAlpha(230);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18
      ..color = const Color(0xFF1F3A5F);

    for (final h in hands) {
      if (h == null) continue;
      final c = Offset(h.dx * size.width, h.dy * size.height);
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, border);
    }

    final a = activePoint;
    if (a != null && progress > 0) {
      final c = Offset(a.dx * size.width, a.dy * size.height);
      final ringR = r * 1.7;
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.35
          ..color = Colors.white.withAlpha(90),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.35
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF2E9E6B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HandCursorPainter old) => true;
}
