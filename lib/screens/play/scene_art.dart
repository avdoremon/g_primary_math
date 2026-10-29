import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/theme/theme.dart';

/// Hình vẽ dùng chung cho các cảnh mini game (theo bộ asset G7, đơn vị pixel khung 1920×1080).

/// Đồ vật SVG trong `assets/svg/g7/`, giữ tỉ lệ gốc theo chiều rộng [width].
class Art extends StatelessWidget {
  const Art(this.name, {super.key, required this.width, this.opacity = 1});

  final String name;
  final double width;
  final double opacity;

  static const sizes = <String, Size>{
    'apple': Size(120, 120),
    'ball': Size(120, 120),
    'box': Size(340, 260),
    'cat': Size(160, 170),
    'fish': Size(170, 110),
    'footL': Size(100, 150),
    'footR': Size(100, 150),
    'handL': Size(110, 120),
    'handR': Size(110, 120),
    'rabbit': Size(150, 210),
    'tree': Size(360, 460),
  };

  static double heightFor(String name, double width) {
    final s = sizes[name] ?? const Size(1, 1);
    return width * s.height / s.width;
  }

  @override
  Widget build(BuildContext context) {
    final pic = SvgPicture.asset('assets/svg/g7/$name.svg', width: width, height: heightFor(name, width));
    return opacity >= 1 ? pic : Opacity(opacity: opacity, child: pic);
  }
}

/// Đặt [Art] tại toạ độ góc trên trái (như design).
Widget placeArt(String name, double left, double top, double width, {double opacity = 1}) => Positioned(
      left: left,
      top: top,
      width: width,
      height: Art.heightFor(name, width),
      child: Art(name, width: width, opacity: opacity),
    );

Rect artRect(String name, double left, double top, double width) =>
    Rect.fromLTWH(left, top, width, Art.heightFor(name, width));

const _wood = Color(0xFFC98A4B);
const _woodDark = Color(0xFFA86E36);
const _woodLight = Color(0xFFF3D9B5);

/// Kệ 3 tầng (design: shelf). Kích thước tự do.
class ShelfPainter extends CustomPainter {
  const ShelfPainter();

  static const board = 26.0;

  /// Vùng trong của tầng [i] (0 = trên cùng), theo toạ độ của kệ.
  static Rect tier(Size size, int i) {
    final inner = (size.height - board * 4) / 3;
    final top = board + i * (inner + board);
    return Rect.fromLTWH(board, top, size.width - 2 * board, inner);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)), Paint()..color = _wood);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(board, board, size.width - 2 * board, size.height - 2 * board),
          const Radius.circular(12)),
      Paint()..color = _woodLight,
    );
    final inner = (size.height - board * 4) / 3;
    for (var i = 1; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(board / 2, board + i * inner + (i - 1) * board, size.width - board, board),
          const Radius.circular(8),
        ),
        Paint()..color = _woodDark,
      );
    }
  }

  @override
  bool shouldRepaint(ShelfPainter oldDelegate) => false;
}

/// Cái bàn (design: table). Mặt bàn ở 20% chiều cao.
class TablePainter extends CustomPainter {
  const TablePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h * .2, w, h * .14), Radius.circular(h * .05)),
      Paint()..color = _wood,
    );
    canvas.drawRect(Rect.fromLTWH(w * .05, h * .33, w * .9, h * .08), Paint()..color = _woodDark);
    for (final x in [w * .07, w * .86]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * .36, w * .07, h * .64), Radius.circular(w * .025)),
        Paint()..color = _woodDark,
      );
    }
  }

  @override
  bool shouldRepaint(TablePainter oldDelegate) => false;
}

/// Nhãn TRÁI (vàng, bàn tay/bàn chân trái) hoặc PHẢI (xanh dương) – quy ước chiều gương của design.
class SideLabel extends StatelessWidget {
  const SideLabel({
    super.key,
    required this.right,
    this.height = 150,
    this.fontSize = 84,
    this.icon = 'hand',
    this.glow = false,
    this.state = SideLabelState.normal,
  });

  final bool right;
  final double height;
  final double fontSize;

  /// "hand" hoặc "foot".
  final String icon;
  final bool glow;
  final SideLabelState state;

  @override
  Widget build(BuildContext context) {
    final correct = state == SideLabelState.correct;
    final bg = correct ? TvdColors.correct : (right ? TvdColors.right : TvdColors.left);
    final border = correct ? TvdColors.correctDark : TvdColors.ink;
    final fg = correct || right ? TvdColors.white : TvdColors.ink;
    final text = Text(right ? 'PHẢI' : 'TRÁI', style: TvText.button.copyWith(fontSize: fontSize, color: fg, height: 1));
    final iconSize = height * (icon == 'hand' ? 0.61 : 0.44);
    final Widget glyph = correct
        ? Container(
            width: height * .56,
            height: height * .56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: TvdColors.white, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: TvdColors.correct, size: height * .44),
          )
        : Art('$icon${right ? 'R' : 'L'}', width: iconSize);
    final label = Container(
      height: height,
      padding: EdgeInsets.only(left: right ? height * .29 : height * .19, right: right ? height * .19 : height * .29),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TvdRadius.pill),
        border: Border.all(color: border, width: height / 25),
        boxShadow: [
          BoxShadow(color: border, offset: const Offset(0, 10)),
          if (glow) BoxShadow(color: bg.withAlpha(90), spreadRadius: 18),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: right
            ? [text, SizedBox(width: height * .13), glyph]
            : [glyph, SizedBox(width: height * .13), text],
      ),
    );
    return state == SideLabelState.dimmed ? Opacity(opacity: .5, child: label) : label;
  }
}

enum SideLabelState { normal, correct, dimmed }

/// Vòng đánh dấu đồ vật: xanh liền (đúng) hoặc cam nét đứt (bé chọn chưa đúng).
class MarkRing extends StatelessWidget {
  const MarkRing({super.key, required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RingPainter(correct));
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.correct);

  final bool correct;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 5;
    final color = correct ? TvdColors.correct : TvdColors.encourage;
    canvas.drawCircle(c, r, Paint()..color = color.withAlpha(correct ? 46 : 41));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = color;
    if (correct) {
      canvas.drawCircle(c, r, stroke);
      return;
    }
    // Nét đứt.
    const dash = 0.22, gap = 0.14;
    for (var a = 0.0; a < 2 * math.pi; a += dash + gap) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, dash, false, stroke);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.correct != correct;
}

/// Vòng tròn quanh một vùng (đặt theo tâm vùng đó).
Widget ringAround(Rect r, {required bool correct, double pad = 30}) {
  final d = math.max(r.width, r.height) + pad * 2;
  return Positioned(
    left: r.center.dx - d / 2,
    top: r.center.dy - d / 2,
    width: d,
    height: d,
    child: MarkRing(correct: correct),
  );
}

/// Viên thuốc chữ (giải thích ngắn, điểm cộng…).
class TalkPill extends StatelessWidget {
  const TalkPill({
    super.key,
    required this.text,
    this.color = TvdColors.correct,
    this.shadow = TvdColors.correctDark,
    this.textColor = TvdColors.white,
    this.fontSize = 56,
    this.icon,
    this.border,
    this.maxWidth = 1400,
  });

  final double maxWidth;
  final String text;
  final Color color;
  final Color shadow;
  final Color textColor;
  final double fontSize;
  final IconData? icon;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * .6, vertical: fontSize * .3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TvdRadius.pill),
        border: border == null ? null : Border.all(color: border!, width: 4),
        boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: fontSize),
            SizedBox(width: fontSize * .25),
          ],
          Flexible(
            child: Text(
              text,
              style: TvText.button.copyWith(fontSize: fontSize, color: textColor, height: 1.15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Mũi tên chỉ hướng bước (design G7-4a).
class StepArrow extends StatelessWidget {
  const StepArrow({super.key, required this.right});

  final bool right;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        height: 100,
        child: CustomPaint(painter: _ArrowPainter(right)),
      );
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.right);

  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TvdColors.ink;
    final path = Path()
      ..moveTo(230, 50)
      ..lineTo(40, 50)
      ..moveTo(80, 10)
      ..lineTo(30, 50)
      ..lineTo(80, 90);
    if (right) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(path, p);
      canvas.restore();
    } else {
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.right != right;
}
