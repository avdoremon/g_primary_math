import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dev/skeleton_painter.dart';
import '../../pose/pose_frame.dart';
import '../../ui/theme/theme.dart';

/// Từ khoá tô màu trong đề (mức gợi ý dễ): "trái" vàng, "phải" xanh dương, còn lại tím nhạt.
class HudKeyword {
  const HudKeyword(this.text, {this.side});

  final String text;

  /// 'l', 'r' hoặc null.
  final String? side;

  Color get background => switch (side) {
        'l' => TvdColors.left,
        'r' => TvdColors.right,
        _ => const Color(0xFFEFEAFE),
      };

  Color get foreground => side == 'r' ? TvdColors.white : TvdColors.ink;
}

/// HUD chung của mọi mini game (design ConNoiConLamHud): câu số mấy và mức gợi ý bên trái,
/// điểm và chuỗi bên phải, thẻ đề ở giữa có nút loa, từ khoá tô màu và thanh thời gian.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.index,
    required this.total,
    required this.score,
    required this.streak,
    required this.prompt,
    this.keyword,
    this.remaining,
    this.easy,
  });

  final int index;
  final int total;
  final int score;
  final int streak;
  final String prompt;
  final HudKeyword? keyword;

  /// 0..1; null = không đếm giờ.
  final double? remaining;

  /// null = không hiện nhãn mức.
  final bool? easy;

  /// Vùng thẻ đề (để chạm nút loa đọc lại đề).
  static const cardRect = Rect.fromLTRB(400, 54, 1520, 330);

  static final _pill = BoxDecoration(
    color: TvdColors.white,
    borderRadius: BorderRadius.circular(TvdRadius.pill),
    boxShadow: TvdShadow.tv(TvdColors.cardShadow),
  );

  static TextStyle get _pillText => TvText.button.copyWith(fontSize: 48, height: 1);

  @override
  Widget build(BuildContext context) {
    final r = remaining;
    return Stack(
      children: [
        Positioned(
          left: TvLayout.safeX,
          top: TvLayout.safeY,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 96,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                alignment: Alignment.center,
                decoration: _pill,
                child: Text('Câu ${math.min(index + 1, total)}/$total', style: _pillText),
              ),
              if (easy != null) ...[
                const SizedBox(height: TvdSpace.s4),
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: easy! ? TvdColors.sky : TvdColors.answerC,
                    borderRadius: BorderRadius.circular(TvdRadius.pill),
                  ),
                  child: Text(
                    easy! ? 'Mức dễ' : 'Mức khó',
                    style: TvText.button.copyWith(
                      fontSize: 38,
                      height: 1,
                      color: easy! ? TvdColors.answerADark : TvdColors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: TvLayout.safeX,
          top: TvLayout.safeY,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 96,
                padding: const EdgeInsets.only(left: 24, right: 36),
                decoration: _pill,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: TvdColors.star, size: 60),
                    const SizedBox(width: TvdSpace.s3),
                    Text('$score', style: _pillText),
                  ],
                ),
              ),
              const SizedBox(height: TvdSpace.s4),
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TvdColors.correctSoft,
                  borderRadius: BorderRadius.circular(TvdRadius.pill),
                ),
                child: Text(
                  'Chuỗi ×$streak',
                  style: TvText.button.copyWith(fontSize: 38, height: 1, color: TvdColors.correctDark),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: cardRect.left,
          right: TvLayout.width - cardRect.right,
          top: cardRect.top,
          child: Container(
            padding: const EdgeInsets.fromLTRB(40, 24, 40, 28),
            decoration: BoxDecoration(
              color: TvdColors.white,
              borderRadius: BorderRadius.circular(TvdRadius.tv),
              boxShadow: TvdShadow.tv(TvdColors.cardShadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: TvdColors.answerA, shape: BoxShape.circle),
                      child: const Icon(Icons.volume_up_rounded, color: TvdColors.white, size: 52),
                    ),
                    const SizedBox(width: 28),
                    Expanded(child: PromptText(prompt: prompt, keyword: keyword)),
                  ],
                ),
                if (r != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TvdRadius.pill),
                    child: LinearProgressIndicator(
                      value: r,
                      minHeight: 22,
                      backgroundColor: TvdColors.line,
                      color: r <= 0.25 ? TvdColors.answerB : TvdColors.answerA,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Đề bài cỡ 80px, tự thu nhỏ (tối thiểu 48px) để vừa tối đa 3 dòng; tô từ khoá nếu có.
class PromptText extends StatelessWidget {
  const PromptText({super.key, required this.prompt, this.keyword, this.maxHeight = 240});

  final String prompt;
  final HudKeyword? keyword;
  final double maxHeight;

  TextSpan _span(double size) {
    final base = TvText.question.copyWith(fontSize: size, height: 1.12);
    final k = keyword;
    final i = k == null || k.text.isEmpty ? -1 : prompt.lastIndexOf(k.text);
    if (i < 0) return TextSpan(text: prompt, style: base);
    return TextSpan(
      style: base,
      children: [
        TextSpan(text: prompt.substring(0, i)),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: k!.background, borderRadius: BorderRadius.circular(20)),
            child: Text(k.text, style: base.copyWith(color: k.foreground)),
          ),
        ),
        TextSpan(text: prompt.substring(i + k.text.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var size = 80.0;
      while (size > 48) {
        final tp = TextPainter(
          text: TextSpan(text: prompt, style: TvText.question.copyWith(fontSize: size, height: 1.12)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: c.maxWidth - (keyword == null ? 0 : 28));
        final fits = tp.height <= maxHeight;
        tp.dispose();
        if (fits) break;
        size -= 4;
      }
      return Text.rich(_span(size), maxLines: 3, overflow: TextOverflow.ellipsis);
    });
  }
}

/// Ô camera góc phải dưới: khung xương thu nhỏ và trạng thái "Thấy con rồi".
class CamTile extends StatelessWidget {
  const CamTile({super.key, required this.frame, required this.seen, this.width = 240});

  final PoseFrame? frame;
  final bool seen;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = seen ? TvdColors.correct : TvdColors.encourage;
    return Container(
      width: width,
      height: width * 272 / 240,
      decoration: BoxDecoration(
        color: TvdColors.ink,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 6),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(child: CustomPaint(size: Size.infinite, painter: SkeletonPainter(frame, color: const Color(0xFF7FE0AE)))),
          Text(
            seen ? 'Thấy con rồi' : 'Chưa thấy con',
            style: TvText.label.copyWith(fontSize: width / 8, color: TvdColors.white),
          ),
        ],
      ),
    );
  }
}

/// Con trỏ bàn tay theo design (vòng trắng mờ, vòng nạp xanh lá, bàn tay ở giữa).
class HandCursors extends CustomPainter {
  HandCursors({required this.hands, this.active, this.progress = 0});

  /// Vị trí tay, chuẩn hoá 0..1 theo khung.
  final List<Offset?> hands;
  final Offset? active;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 52.0 * 1.25;
    for (final h in hands) {
      if (h == null) continue;
      final c = Offset(h.dx * size.width, h.dy * size.height);
      canvas.drawCircle(c, r, Paint()..color = TvdColors.white.withAlpha(140));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = TvdColors.white,
      );
      final isActive = active != null && (active! - h).distance < 0.001;
      if (isActive && progress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round
            ..color = TvdColors.correct,
        );
      }
      // Bàn tay nhỏ ở giữa.
      final hand = Paint()..color = TvdColors.white;
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = TvdColors.ink;
      final palm = RRect.fromRectAndRadius(Rect.fromCenter(center: c + const Offset(0, 10), width: 34, height: 30), const Radius.circular(12));
      for (var i = 0; i < 4; i++) {
        final f = RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 17 + i * 9, c.dy - 20 + (i == 0 || i == 3 ? 6 : 0), 8, 26),
          const Radius.circular(4),
        );
        canvas.drawRRect(f, hand);
        canvas.drawRRect(f, outline);
      }
      canvas.drawRRect(palm, hand);
      canvas.drawRRect(palm, outline);
    }
  }

  @override
  bool shouldRepaint(HandCursors oldDelegate) => true;
}
