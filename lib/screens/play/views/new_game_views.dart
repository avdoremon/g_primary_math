import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/mechanics.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/widgets/tin_tin.dart';
import '../kid_figure.dart';
import '../mini_game_view.dart';
import '../play_widgets.dart';
import 'cards_view.dart';

Widget _hintText(String hint) => Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: Text(hint, textAlign: TextAlign.center, style: TvText.prompt.copyWith(color: TvdColors.encourageDark)),
    );

// ====================================================================== Chạm theo thứ tự (C)

/// Các ô số xếp lưới; bé chạm lần lượt theo thứ tự đề bài. Ô đã chạm đúng chuyển xanh.
class OrderTouchView extends MiniGameView {
  const OrderTouchView();

  static List<Rect> rects(int n) {
    final perRow = n <= 4 ? n : (n / 2).ceil();
    final rows = n <= 4 ? 1 : 2;
    const gap = 40.0;
    final w = math.min(360.0, (1600 - gap * (perRow - 1)) / perRow);
    final h = rows == 1 ? 420.0 : 260.0;
    final top = rows == 1 ? 480.0 : 400.0;
    final out = <Rect>[];
    for (var i = 0; i < n; i++) {
      final row = i ~/ perRow;
      final inRow = row == rows - 1 ? n - perRow * (rows - 1) : perRow;
      final total = w * inRow + gap * (inRow - 1);
      final left = (TvLayout.width - total) / 2 + (i - row * perRow) * (w + gap);
      out.add(Rect.fromLTWH(left, top + row * (h + gap), w, h));
    }
    return out;
  }

  @override
  List<Rect> targets(PlayFrame f) => f.mechanic is OrderTouchMechanic ? rects(f.question.options.length) : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => targets(f);

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! OrderTouchMechanic) return const CardsView().scene(context, f);
    final q = f.question;
    final rs = rects(q.options.length);
    final touched = f.feedback != null && f.feedback!.correct ? {...mech.sequence} : mech.touched;
    return [
      for (var i = 0; i < rs.length; i++)
        Positioned.fromRect(
          key: ValueKey('answer-$i'),
          rect: rs[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: touched.contains(i)
                ? CardMark.correct
                : (f.feedback != null ? CardMark.dimmed : (mech.aimed == i ? CardMark.aimed : CardMark.none)),
            progress: f.answering && mech.aimed == i ? mech.progress : 0,
          ),
        ),
      if (f.answering) _hintText(mech.step == 0 ? 'Chạm lần lượt từng ô theo thứ tự nhé!' : 'Giỏi quá! Chạm ô tiếp theo!'),
    ];
  }
}

// ====================================================================== Cân thăng bằng (B)

/// Cái cân hai đĩa: bé nghiêng người sang bên nào thì đĩa bên đó hạ xuống.
class BalanceView extends MiniGameView {
  const BalanceView();

  @override
  List<Rect> tapTargets(PlayFrame f) => CardsView.hasCards(f) ? CardsView.cardRects(f, top: 520) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! StepMechanic || f.question.options.length != 2) return const CardsView().scene(context, f);
    final q = f.question;
    final rs = CardsView.cardRects(f, top: 520);
    final lean = f.answering ? ((f.body?.leanOffset ?? 0) / 0.5).clamp(-1.0, 1.0).toDouble() : 0.0;
    final dy = 90 * lean; // nghiêng phải (lean>0) → đĩa phải hạ
    return [
      Positioned(
        left: 0,
        right: 0,
        top: 400,
        height: 560,
        child: CustomPaint(painter: _ScalePainter(tilt: lean)),
      ),
      for (var i = 0; i < 2; i++)
        Positioned.fromRect(
          key: ValueKey('answer-$i'),
          rect: rs[i].shift(Offset(0, i == 0 ? -dy : dy)).deflate(70).shift(const Offset(0, 40)),
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: CardsView.markFor(f, i),
            progress: f.answering && mech.aimed == i ? mech.progress : 0,
            caption: f.easy ? (i == 0 ? '◀ NGHIÊNG TRÁI' : 'NGHIÊNG PHẢI ▶') : null,
          ),
        ),
      if (f.answering) _hintText(mech.hint ?? 'Nghiêng người về bên nặng hơn!'),
    ];
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.tilt});

  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final p = Paint()
      ..color = TvdColors.ink
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final y = 150.0;
    final dx = 640.0;
    final dy = 90 * tilt;
    canvas.drawLine(Offset(cx - dx, y - dy), Offset(cx + dx, y + dy), p);
    canvas.drawLine(Offset(cx, y), Offset(cx, size.height - 20), p);
    canvas.drawCircle(Offset(cx, y), 24, Paint()..color = TvdColors.answerA);
  }

  @override
  bool shouldRepaint(_ScalePainter old) => old.tilt != tilt;
}

// ====================================================================== Chạy đua tại chỗ (Đ + B)

/// Bé chạy tại chỗ để Tin Tin chạy tới ngã ba, rồi nghiêng người chọn đường có đáp án đúng.
class RunRaceView extends MiniGameView {
  const RunRaceView();

  @override
  List<Rect> tapTargets(PlayFrame f) => CardsView.hasCards(f) ? CardsView.cardRects(f, top: 560) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! RunChooseMechanic || f.question.options.length != 2) return const CardsView().scene(context, f);
    final q = f.question;
    final rs = CardsView.cardRects(f, top: 560);
    final ready = mech.arrived || f.feedback != null;
    final runnerX = 160 + 520 * (f.feedback != null ? 1.0 : mech.route);
    return [
      // Đường chạy
      Positioned(
        left: 120,
        top: 420,
        width: 720,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(color: TvdColors.line, borderRadius: BorderRadius.circular(20)),
        ),
      ),
      Positioned(
        left: runnerX,
        top: 300 + 6 * math.sin(f.time * 14 * (mech.arrived ? 0 : 1)),
        child: const TinTin(state: TinTinState.hello, size: 200),
      ),
      for (var i = 0; i < 2; i++)
        Positioned.fromRect(
          key: ValueKey('answer-$i'),
          rect: rs[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: !ready ? CardMark.dimmed : CardsView.markFor(f, i),
            progress: f.answering && mech.aimed == i ? mech.progress : 0,
            caption: i == 0 ? '◀ TRÁI' : 'PHẢI ▶',
          ),
        ),
      Positioned(
        right: 160,
        top: 360,
        width: 360,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: mech.route,
            color: TvdColors.correct,
            backgroundColor: TvdColors.white,
          ),
        ),
      ),
      if (f.answering) _hintText(mech.hint ?? ''),
    ];
  }
}

// ====================================================================== Cổng nhảy ngồi (Đ)

/// Cổng thấp: ngồi xuống để chui (đáp án 0). Cổng cao: nhảy lên để vượt (đáp án 1).
class GateView extends MiniGameView {
  const GateView();

  static List<Rect> rects(PlayFrame f) {
    final base = CardsView.cardRects(f, top: 560);
    return [
      Rect.fromLTWH(base[0].left, 720, base[0].width, 220), // thấp
      Rect.fromLTWH(base[1].left, 420, base[1].width, 220), // cao
    ];
  }

  @override
  List<Rect> tapTargets(PlayFrame f) => CardsView.hasCards(f) ? rects(f) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! GateMechanic || f.question.options.length != 2) return const CardsView().scene(context, f);
    final q = f.question;
    final rs = rects(f);
    return [
      Positioned(
        left: 740,
        top: 400,
        width: 440,
        height: 540,
        child: KidFigure(
          body: f.body,
          lift: mech.rise.clamp(0.0, 1.0).toDouble() * 252,
          dim: f.body == null,
        ),
      ),
      for (var i = 0; i < 2; i++)
        Positioned.fromRect(
          key: ValueKey('answer-$i'),
          rect: rs[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: CardsView.markFor(f, i),
            progress: f.answering && i == 0 ? mech.progress : 0,
            caption: i == 0 ? '⬇ NGỒI XUỐNG' : '⬆ NHẢY LÊN',
          ),
        ),
      if (f.answering) _hintText(mech.hint ?? ''),
    ];
  }
}
