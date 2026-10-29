import 'package:flutter/material.dart';

import '../../../content/generators/geometry_generators.dart';
import '../../../game/mechanics.dart';
import '../../../ui/theme/theme.dart';
import '../kid_figure.dart';
import '../math_art.dart';
import '../mini_game_view.dart';
import '../play_widgets.dart';
import '../scene_art.dart';
import '../visuals.dart';
import 'cards_view.dart';

// ====================================================================== Tia số (B)

/// Tia số nằm ngang dưới đề; các đáp án (đã xếp tăng dần) đứng thành ô trên tia số.
/// Bóng bé đi theo vị trí thật của bé; bé đứng vào ô đúng rồi giơ tay để chọn.
/// Biến thể của cảnh các ô đứng ngang: tia số (giơ tay), nhảy ô (nhảy), hứng sao (chờ sao rơi).
enum LaneVariant { line, hop, star }

class NumberLineView extends MiniGameView {
  const NumberLineView({this.variant = LaneVariant.line});

  final LaneVariant variant;

  static const _lineY = 880.0;
  static const _x0 = 180.0, _x1 = 1740.0;

  static List<Rect> zoneRects(int n) {
    final w = (_x1 - _x0) / n;
    final card = (w - 40).clamp(200.0, 380.0).toDouble();
    final top = 560.0;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(_x0 + w * i + (w - card) / 2, top, card, 220)];
  }

  bool _active(PlayFrame f) => f.mechanic is ZoneMechanic;

  @override
  List<Rect> tapTargets(PlayFrame f) => _active(f) ? zoneRects(f.question.options.length) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! ZoneMechanic) return const CardsView().scene(context, f);
    final q = f.question;
    final n = q.options.length;
    final rects = zoneRects(n);
    final zoneW = (_x1 - _x0) / n;
    final out = <Widget>[];
    final art = QuestionArt.of(q);
    // Hình minh hoạ (nếu có) thu nhỏ ở góc trái để tia số còn chỗ.
    if (art != null) out.add(Positioned(left: 120, top: 360, width: 420, height: 180, child: FittedBox(child: art)));

    // Vùng sàn của từng ô.
    for (var i = 0; i < n; i++) {
      final here = f.answering && mech.zone == i;
      out.add(Positioned(
        left: _x0 + zoneW * i + 8,
        top: _lineY - 70,
        width: zoneW - 16,
        height: 150,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: here ? const Color(0xFFDDEBFF) : TvdColors.white.withAlpha(120),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: here ? TvdColors.answerA : TvdColors.line, width: here ? 8 : 4),
          ),
        ),
      ));
    }
    // Tia số: vạch chính và mũi tên.
    out.add(Positioned(
      left: _x0 - 60,
      top: _lineY - 30,
      width: _x1 - _x0 + 140,
      height: 60,
      child: CustomPaint(painter: _RayPainter(ticks: [for (var i = 0; i < n; i++) 60 + zoneW * (i + .5)])),
    ));
    // Hứng sao: các ô rơi dần từ trên xuống sàn.
    final drop = variant == LaneVariant.star && f.answering ? (1 - mech.fall) * 230 : 0.0;
    for (var i = 0; i < n; i++) {
      final aimed = f.answering && mech.zone == i;
      out.add(Positioned.fromRect(
        key: ValueKey('answer-$i'),
        rect: rects[i].shift(Offset(0, -drop)),
        child: AnswerCard(
          slot: i,
          label: q.options[i],
          mark: f.feedback != null ? CardsView.markFor(f, i) : (aimed ? CardMark.aimed : CardMark.none),
          progress: aimed ? mech.progress : 0,
        ),
      ));
    }
    // Bóng bé trên tia số.
    final kidX = _x0 + (_x1 - _x0) * (mech.position + 1) / 2;
    out.add(Positioned(
      left: kidX - 90,
      top: 770,
      width: 180,
      height: 270,
      child: KidFigure(
        body: f.body,
        lift: variant == LaneVariant.hop ? mech.rise.clamp(0.0, 1.2).toDouble() * 252 : 0,
        left: mech.handUp ? const ArmGlow(TvdColors.correct) : null,
        right: mech.handUp ? const ArmGlow(TvdColors.correct) : null,
        dim: f.body == null,
      ),
    ));
    final hint = f.answering ? mech.hint : null;
    if (hint != null) {
      out.add(Positioned(
        left: 0,
        right: 0,
        top: 470,
        child: Center(
          child: TalkPill(text: hint, fontSize: 40, color: TvdColors.white, shadow: TvdColors.cardShadow, textColor: TvdColors.inkSoft),
        ),
      ));
    }
    return out;
  }
}

class _RayPainter extends CustomPainter {
  _RayPainter({required this.ticks});

  final List<double> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = TvdColors.ink;
    canvas.drawLine(Offset(10, y), Offset(size.width - 20, y), p);
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 4, y)
        ..lineTo(size.width - 34, y - 18)
        ..lineTo(size.width - 34, y + 18)
        ..close(),
      Paint()..color = TvdColors.ink,
    );
    for (final x in ticks) {
      canvas.drawLine(Offset(x, y - 22), Offset(x, y + 22), p);
    }
  }

  @override
  bool shouldRepaint(_RayPainter old) => old.ticks.join() != ticks.join();
}

// ====================================================================== Góc tay (T)

/// Bên trái: góc mẫu cần làm. Giữa: góc hai tay bé đang tạo, vẽ theo thời gian thực kèm số đo.
/// Bên phải: bóng bé, hai tay sáng xanh khi đúng loại góc.
class ArmAngleView extends MiniGameView {
  const ArmAngleView();

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! ArmAngleMechanic) return const CardsView().scene(context, f);
    final target = mech.target;
    final targetDeg = const {'acute': 50.0, 'right': 90.0, 'obtuse': 135.0, 'straight': 180.0}[target]!;
    final ok = mech.current == target || (f.feedback?.correct ?? false);
    final live = mech.angle;
    final glow = ArmGlow(ok ? TvdColors.correct : TvdColors.answerA);

    Widget card({required String title, required Widget child, required Color border}) => Container(
          padding: const EdgeInsets.all(TvdSpace.s5),
          decoration: BoxDecoration(
            color: TvdColors.white,
            borderRadius: BorderRadius.circular(TvdRadius.tv),
            border: Border.all(color: border, width: 8),
            boxShadow: TvdShadow.tv(TvdColors.cardShadow),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TvText.prompt.copyWith(fontSize: 44, color: TvdColors.inkSoft)),
                const SizedBox(height: TvdSpace.s3),
                child,
              ],
            ),
          ),
        );

    return [
      Positioned(
        left: 140,
        top: 380,
        width: 520,
        height: 520,
        child: card(
          title: 'Góc cần làm',
          border: TvdColors.answerB,
          child: Column(
            children: [
              AngleArt(deg: targetDeg, size: 230, color: TvdColors.answerBDark),
              const SizedBox(height: TvdSpace.s3),
              Text(GeoGenerator.angleNames[target]!.toUpperCase(), style: TvText.question.copyWith(fontSize: 64)),
            ],
          ),
        ),
      ),
      Positioned(
        left: 720,
        top: 380,
        width: 560,
        height: 520,
        child: card(
          title: 'Tay con đang làm',
          border: ok ? TvdColors.correct : TvdColors.line,
          child: Column(
            children: [
              SizedBox(
                height: 250,
                child: live == null
                    ? Center(child: Text('Dang hai tay ra nào!', style: TvText.prompt.copyWith(fontSize: 46)))
                    : AngleArt(deg: live.roundToDouble(), size: 230, color: ok ? TvdColors.correct : TvdColors.answerA),
              ),
              Text(
                live == null ? '' : '${live.round()}° · ${GeoGenerator.angleNames[mech.current]}',
                style: TvText.question.copyWith(fontSize: 56, color: ok ? TvdColors.correctDark : TvdColors.ink),
              ),
              const SizedBox(height: TvdSpace.s3),
              SizedBox(
                width: 420,
                child: LinearProgressIndicator(
                  value: ok && f.feedback != null ? 1 : mech.progress,
                  minHeight: 20,
                  color: TvdColors.correct,
                  backgroundColor: TvdColors.line,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 1380,
        top: 470,
        width: 380,
        height: 570,
        child: KidFigure(body: f.body, left: glow, right: glow, dim: f.body == null),
      ),
      if (f.answering && mech.hint != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: TalkPill(text: mech.hint!, fontSize: 44, color: TvdColors.white, shadow: TvdColors.cardShadow, textColor: TvdColors.inkSoft),
          ),
        ),
    ];
  }
}
