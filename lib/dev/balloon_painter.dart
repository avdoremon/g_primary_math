import 'package:flutter/material.dart';

enum BalloonMark { none, correct, wrong }

/// Quả bóng bay: thân bầu dục, nút thắt, dây; viền xanh khi đúng, cam khi sai.
class BalloonPainter extends CustomPainter {
  BalloonPainter({
    required this.color,
    this.aim = 0,
    this.mark = BalloonMark.none,
  });

  final Color color;

  /// 0..1: mức đang được nhắm (vẽ quầng sáng).
  final double aim;
  final BalloonMark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(size.width * 0.06, 0, size.width * 0.88, size.height * 0.8);

    if (aim > 0) {
      canvas.drawOval(
        body.inflate(size.width * 0.05 * aim),
        Paint()..color = Colors.white.withAlpha((120 * aim).round()),
      );
    }

    canvas.drawOval(body, Paint()..color = color);

    // Vệt sáng
    canvas.drawOval(
      Rect.fromLTWH(body.left + body.width * 0.2, body.top + body.height * 0.12,
          body.width * 0.22, body.height * 0.18),
      Paint()..color = Colors.white.withAlpha(90),
    );

    // Nút thắt
    final knotTop = body.bottom - 2;
    final knot = Path()
      ..moveTo(size.width / 2, knotTop)
      ..lineTo(size.width / 2 - size.width * 0.05, knotTop + size.height * 0.04)
      ..lineTo(size.width / 2 + size.width * 0.05, knotTop + size.height * 0.04)
      ..close();
    canvas.drawPath(knot, Paint()..color = color);

    // Dây
    final string = Path()
      ..moveTo(size.width / 2, knotTop + size.height * 0.04)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.9, size.width / 2, size.height);
    canvas.drawPath(
      string,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1F3A5F).withAlpha(150),
    );

    if (mark != BalloonMark.none) {
      canvas.drawOval(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.06
          ..color = mark == BalloonMark.correct ? const Color(0xFF1FA35B) : const Color(0xFFF08A24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BalloonPainter old) =>
      old.color != color || old.aim != aim || old.mark != mark;
}
