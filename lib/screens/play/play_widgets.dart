import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../content/question.dart';
import '../../ui/theme/theme.dart';

/// Thành phần màn chơi dùng chung. Mọi kích thước tính theo khung 1920×1080.

enum CardMark { none, aimed, correct, wrongPick, dimmed }

/// Ô đáp án: màu + hình theo vị trí (cho trẻ mù màu), chữ lớn.
class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.slot,
    required this.label,
    this.mark = CardMark.none,
    this.progress = 0,
    this.caption,
  });

  final int slot;
  final String label;
  final CardMark mark;

  /// 0..1 – vòng nạp khi bé giữ tay.
  final double progress;

  /// Nhãn gợi ý dưới ô (vd. "TRÁI").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final style = AnswerSlotStyle.slots[slot % AnswerSlotStyle.slots.length];
    final (bg, shadow, fg) = switch (mark) {
      CardMark.correct => (TvdColors.correct, TvdColors.correctDark, TvdColors.white),
      CardMark.wrongPick => (TvdColors.encourageSoft, TvdColors.encourage, TvdColors.encourageDark),
      CardMark.dimmed => (TvdColors.line, TvdColors.cardShadow, TvdColors.inkSoft),
      _ => (style.color, style.shadow, style.onColor),
    };
    final short = label.length <= 4;
    final scale = mark == CardMark.aimed ? 1.06 : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(TvdRadius.tv),
                boxShadow: TvdShadow.tv(shadow),
                border: mark == CardMark.aimed ? Border.all(color: TvdColors.white, width: 10) : null,
              ),
              padding: const EdgeInsets.all(TvdSpace.s5),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: CustomPaint(size: const Size(56, 56), painter: _ShapePainter(style.shape, fg.withAlpha(150))),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: (short ? TvText.answerNumber : TvText.prompt).copyWith(color: fg),
                      ),
                    ),
                  ),
                  if (progress > 0)
                    Positioned.fill(
                      child: CustomPaint(painter: _RingPainter(progress, fg)),
                    ),
                  if (mark == CardMark.correct)
                    const Positioned(right: 0, top: 0, child: Icon(Icons.check_circle, color: TvdColors.white, size: 72)),
                ],
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: TvdSpace.s4),
            Text(caption!, style: TvText.label.copyWith(color: TvdColors.ink, letterSpacing: 4)),
          ],
        ],
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);

  final AnswerShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    switch (shape) {
      case AnswerShape.circle:
        canvas.drawCircle(c, r, p);
      case AnswerShape.square:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r * 0.9), const Radius.circular(6)), p);
      case AnswerShape.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy + r * 0.8)
            ..lineTo(c.dx - r, c.dy + r * 0.8)
            ..close(),
          p,
        );
      case AnswerShape.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final rr = i.isEven ? r : r * 0.45;
          final a = -math.pi / 2 + i * math.pi / 5;
          final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(path..close(), p);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.shape != shape || old.color != color;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = color.withAlpha(200),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// Hình minh hoạ đơn giản cho đề (hiện chỉ có đếm đồ vật); các dạng khác chờ design G1–G6.
class QuestionVisual extends StatelessWidget {
  const QuestionVisual({super.key, required this.question});

  final Question question;

  static const _objects = {'apple', 'ball', 'fish'};

  static bool hasVisual(Question q) =>
      q.generator == 'count_objects' && _objects.contains(q.data['object']) && q.data['count'] is int;

  @override
  Widget build(BuildContext context) {
    if (!hasVisual(question)) return const SizedBox.shrink();
    final n = question.data['count']! as int;
    final asset = 'assets/svg/g7/${question.data['object']}.svg';
    final size = n <= 10 ? 96.0 : (n <= 20 ? 60.0 : 30.0);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: n > 20 ? 6 : 16,
      runSpacing: 12,
      children: [
        for (var i = 0; i < n; i++)
          Padding(
            // Trên 20 đồ vật: tách nhóm mười cho dễ đếm theo chục.
            padding: EdgeInsets.only(right: n > 20 && i % 10 == 9 ? 28 : 0),
            child: SvgPicture.asset(asset, width: size, height: size),
          ),
      ],
    );
  }
}

/// Hàng sao kết quả.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 140});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: i == 1 ? size * 1.2 : size,
            color: i < stars ? TvdColors.star : TvdColors.cardShadow,
          ),
      ],
    );
  }
}
