import 'package:flutter/material.dart';

import '../../motion/body_metrics.dart';
import '../../pose/landmarks.dart';
import '../../ui/theme/theme.dart';

/// Tô sáng một cánh tay của bóng người.
class ArmGlow {
  const ArmGlow(this.color, {this.check = false});

  final Color color;

  /// Vẽ dấu ✓ cạnh bàn tay (phản hồi đúng).
  final bool check;
}

/// "Bóng người cỡ lớn" của design G7: khung xương + bóng, vẽ từ toạ độ khớp thật (không phải ảnh camera).
///
/// Vẽ trong hệ toạ độ 600×900 của design rồi co theo khung. Toạ độ bé được dời sao cho tâm hông
/// nằm ở (300 + [shift], 520) và chiều dài thân bằng 252, nên bé đứng xa hay gần thì bóng vẫn cùng cỡ.
/// Không thấy bé thì vẽ tư thế đứng buông tay.
class KidFigurePainter extends CustomPainter {
  KidFigurePainter({this.body, this.shift = 0, this.left, this.right, this.dim = false});

  final BodySnapshot? body;

  /// Dời ngang (đơn vị design) – dùng khi bé bước sang trái/phải.
  final double shift;

  /// Tô sáng tay trái / tay phải của bé (tay trái nằm bên trái màn hình).
  final ArmGlow? left;
  final ArmGlow? right;
  final bool dim;

  static const _body = Color(0xFF33415F);
  static const _bone = Color(0xFF9FB3D6);
  static const designSize = Size(600, 900);

  /// Tư thế mặc định (design: kid, hai tay buông).
  static final _rest = <int, Offset>{
    PoseIdx.nose: const Offset(300, 140),
    PoseIdx.leftShoulder: const Offset(246, 268),
    PoseIdx.rightShoulder: const Offset(354, 268),
    PoseIdx.leftElbow: const Offset(212, 394),
    PoseIdx.rightElbow: const Offset(388, 394),
    PoseIdx.leftWrist: const Offset(178, 520),
    PoseIdx.rightWrist: const Offset(422, 520),
    PoseIdx.leftHip: const Offset(270, 520),
    PoseIdx.rightHip: const Offset(330, 520),
    PoseIdx.leftKnee: const Offset(263, 690),
    PoseIdx.rightKnee: const Offset(337, 690),
    PoseIdx.leftAnkle: const Offset(256, 860),
    PoseIdx.rightAnkle: const Offset(344, 860),
  };

  Map<int, Offset> _points() {
    final b = body;
    if (b == null || b.torsoLength <= 0) return _rest;
    final s = 252 / b.torsoLength;
    final hip = b.hipCenter;
    final out = <int, Offset>{};
    for (final i in _rest.keys) {
      out[i] = b.sees(i) || i == PoseIdx.leftHip || i == PoseIdx.rightHip || i == PoseIdx.leftShoulder || i == PoseIdx.rightShoulder
          ? (b.point(i) - hip) * s + const Offset(300, 520)
          : _rest[i]!;
    }
    // Đầu: nếu không thấy mũi thì đặt trên vai.
    if (!b.sees(PoseIdx.nose)) {
      final sc = (out[PoseIdx.leftShoulder]! + out[PoseIdx.rightShoulder]!) / 2;
      out[PoseIdx.nose] = sc - const Offset(0, 128);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / designSize.width, size.height / designSize.height);
    canvas.translate(shift, 0);
    final p = _points();
    final alpha = dim ? 110 : 255;
    final bodyColor = _body.withAlpha(alpha);

    // Bóng dưới chân.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(300, 884), width: 300, height: 28),
      Paint()..color = TvdColors.ink.withAlpha(30),
    );

    void limb(List<int> chain, double width, Color color, {Color? glow}) {
      final path = Path()..moveTo(p[chain.first]!.dx, p[chain.first]!.dy);
      for (final i in chain.skip(1)) {
        path.lineTo(p[i]!.dx, p[i]!.dy);
      }
      if (glow != null) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 2.15
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = glow.withAlpha(72),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = (glow != null ? TvdColors.white : _bone).withAlpha((alpha * 0.8).round()),
      );
      for (final i in chain.skip(1)) {
        canvas.drawCircle(p[i]!, 9, Paint()..color = TvdColors.white.withAlpha(alpha));
      }
    }

    // Chân.
    limb([PoseIdx.leftHip, PoseIdx.leftKnee, PoseIdx.leftAnkle], 58, bodyColor);
    limb([PoseIdx.rightHip, PoseIdx.rightKnee, PoseIdx.rightAnkle], 58, bodyColor);

    // Thân: viên thuốc từ tâm vai tới tâm hông.
    final sc = (p[PoseIdx.leftShoulder]! + p[PoseIdx.rightShoulder]!) / 2;
    final hc = (p[PoseIdx.leftHip]! + p[PoseIdx.rightHip]!) / 2;
    canvas.drawLine(
      sc + const Offset(0, 20),
      hc,
      Paint()
        ..strokeWidth = 148
        ..strokeCap = StrokeCap.round
        ..color = bodyColor,
    );
    canvas.drawLine(
      sc,
      hc,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = _bone.withAlpha((alpha * .8).round()),
    );

    // Tay.
    void arm(bool isRight, ArmGlow? g) {
      final chain = isRight
          ? [PoseIdx.rightShoulder, PoseIdx.rightElbow, PoseIdx.rightWrist]
          : [PoseIdx.leftShoulder, PoseIdx.leftElbow, PoseIdx.leftWrist];
      final color = g?.color ?? bodyColor;
      limb(chain, 52, color, glow: g?.color);
      final hand = p[chain.last]!;
      canvas.drawCircle(hand, 36, Paint()..color = color);
      if (g != null) {
        canvas.drawCircle(
          hand,
          36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = TvdColors.white,
        );
      }
      if (g?.check ?? false) {
        final c = hand + Offset(isRight ? 46 : -46, -40);
        canvas.drawCircle(c, 38, Paint()..color = TvdColors.correct);
        canvas.drawCircle(
          c,
          38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = TvdColors.white,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 17, c.dy)
            ..relativeLineTo(11, 12)
            ..relativeLineTo(22, -24),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = TvdColors.white,
        );
      }
    }

    arm(false, left);
    arm(true, right);

    // Đầu và khớp vai, hông.
    canvas.drawCircle(p[PoseIdx.nose]!, 76, Paint()..color = bodyColor);
    for (final i in [PoseIdx.leftShoulder, PoseIdx.rightShoulder, PoseIdx.leftHip, PoseIdx.rightHip]) {
      canvas.drawCircle(p[i]!, 10, Paint()..color = TvdColors.white.withAlpha(alpha));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KidFigurePainter oldDelegate) => true;
}

/// Bóng người trong một khung có tỉ lệ 600×900 (2:3).
class KidFigure extends StatelessWidget {
  const KidFigure({super.key, this.body, this.shift = 0, this.left, this.right, this.dim = false});

  final BodySnapshot? body;
  final double shift;
  final ArmGlow? left;
  final ArmGlow? right;
  final bool dim;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: KidFigurePainter(body: body, shift: shift, left: left, right: right, dim: dim),
      );
}
