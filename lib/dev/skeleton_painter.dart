import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pose/landmarks.dart';
import '../pose/pose_frame.dart';

/// Vẽ khung xương (đã lật gương) vừa khít trong khung, giữ đúng tỉ lệ ảnh camera.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter(
    this.frame, {
    this.color = Colors.white,
    this.showFrame = false,
  });

  final PoseFrame? frame;
  final Color color;
  final bool showFrame;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final aspect = f?.aspect ?? 4 / 3;
    var w = size.width;
    var h = w / aspect;
    if (h > size.height) {
      h = size.height;
      w = h * aspect;
    }
    final ox = (size.width - w) / 2;
    final oy = (size.height - h) / 2;

    if (showFrame) {
      canvas.drawRect(
        Rect.fromLTWH(ox, oy, w, h),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withAlpha(70),
      );
    }

    final lm = f?.landmarks;
    if (lm == null) return;

    Offset p(int i) => Offset(ox + lm[i].x * w, oy + lm[i].y * h);
    final stroke = math.max(2.0, size.shortestSide * 0.012);

    final line = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (final c in PoseIdx.connections) {
      final a = c[0];
      final b = c[1];
      if (lm[a].visible && lm[b].visible) canvas.drawLine(p(a), p(b), line);
    }

    final dot = Paint()..color = color;
    for (final i in PoseIdx.bodyPoints) {
      if (lm[i].visible) canvas.drawCircle(p(i), stroke * 1.2, dot);
    }

    final ls = lm[PoseIdx.leftShoulder];
    final rs = lm[PoseIdx.rightShoulder];
    if (lm[PoseIdx.nose].visible && ls.visible && rs.visible) {
      final shoulderPx = (p(PoseIdx.leftShoulder) - p(PoseIdx.rightShoulder)).distance;
      canvas.drawCircle(
        p(PoseIdx.nose),
        math.max(stroke * 3, shoulderPx * 0.32),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter old) => true;
}
