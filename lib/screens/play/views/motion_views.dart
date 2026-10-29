import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/mechanics.dart';
import '../../../motion/detectors/arm_pose.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/widgets/tin_tin.dart';
import '../kid_figure.dart';
import '../math_art.dart';
import '../mini_game_view.dart';
import '../play_widgets.dart';
import '../scene_art.dart';
import '../visuals.dart';
import 'cards_view.dart';

// ====================================================================== G2 Bóng bay phép tính (C)

/// Bóng bay mang đáp án bay lơ lửng; bé giơ tay giữ lên quả bóng để chọn.
class BalloonView extends MiniGameView {
  const BalloonView();

  static const _bodyRatio = 172 / 160; // phần thân bóng (không tính dây) theo design

  double _width(int n) => math.min(320.0, (1600 - 80.0 * (n - 1)) / n);

  /// Thân bóng thứ [i] (pixel khung), có bồng bềnh theo thời gian.
  List<Rect> _bodies(PlayFrame f) {
    final n = f.question.options.length;
    final w = _width(n);
    final h = w * _bodyRatio;
    final top = CardsView.cardsTop(f).clamp(420.0, 940.0 - h - 30).toDouble();
    final total = w * n + 80.0 * (n - 1);
    final left = (TvLayout.width - total) / 2;
    return [
      for (var i = 0; i < n; i++)
        Rect.fromLTWH(left + i * (w + 80), top + 16 * math.sin(f.time * 1.6 + i * 1.3), w, h),
    ];
  }

  @override
  List<Rect> targets(PlayFrame f) => (f.mechanic?.usesTouch ?? false) && f.question.options.length > 1 ? _bodies(f) : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => f.question.options.length > 1 ? _bodies(f) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final q = f.question;
    final out = <Widget>[
      // Mây trang trí.
      for (final (x, y, w) in const [(140.0, 420.0, 260.0), (1560.0, 470.0, 220.0), (820.0, 990.0, 300.0)])
        Positioned(
          left: x,
          top: y,
          width: w,
          height: w * .38,
          child: DecoratedBox(
            decoration: BoxDecoration(color: TvdColors.white.withAlpha(150), borderRadius: BorderRadius.circular(w)),
          ),
        ),
    ];
    final a = CardsView.art(f);
    if (a != null) out.add(a);
    if (q.options.length < 2) return out..addAll(const CardsView().scene(context, f));

    final bodies = _bodies(f);
    for (var i = 0; i < q.options.length; i++) {
      final b = bodies[i];
      final mark = CardsView.markFor(f, i);
      final slot = AnswerSlotStyle.slots[i % AnswerSlotStyle.slots.length];
      final color = switch (mark) {
        CardMark.correct => TvdColors.correct,
        CardMark.wrongPick => TvdColors.encourage,
        CardMark.dimmed => TvdColors.line,
        _ => slot.color,
      };
      final fg = mark == CardMark.dimmed ? TvdColors.inkSoft : (color == TvdColors.answerB ? TvdColors.ink : TvdColors.white);
      final aimed = f.answering && f.mechanic?.aimed == i;
      out.add(Positioned(
        key: ValueKey('answer-$i'),
        left: b.left,
        top: b.top,
        width: b.width,
        height: b.width * 1.5,
        child: AnimatedScale(
          scale: mark == CardMark.correct ? 1.1 : (aimed ? 1.06 : 1),
          duration: const Duration(milliseconds: 150),
          child: CustomPaint(
            painter: _BalloonPainter(color: color, ring: aimed ? f.mechanic!.progress : 0, dashed: mark == CardMark.wrongPick),
            child: Align(
              alignment: const Alignment(0, -.42),
              child: SizedBox(
                width: b.width * .78,
                height: b.height * .62,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MathText(
                    q.options[i],
                    style: (q.options[i].length <= 4 ? TvText.answerNumber : TvText.prompt).copyWith(color: fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return out;
  }
}

class _BalloonPainter extends CustomPainter {
  _BalloonPainter({required this.color, this.ring = 0, this.dashed = false});

  final Color color;
  final double ring;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 240);
    canvas.drawPath(
      Path()
        ..moveTo(80, 176)
        ..quadraticBezierTo(74, 200, 86, 214)
        ..quadraticBezierTo(96, 226, 84, 240),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = TvdColors.ink,
    );
    final body = Path()
      ..moveTo(80, 6)
      ..cubicTo(36, 6, 10, 40, 10, 80)
      ..cubicTo(10, 124, 46, 160, 80, 172)
      ..cubicTo(114, 160, 150, 124, 150, 80)
      ..cubicTo(150, 40, 124, 6, 80, 6)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(72, 170)
        ..lineTo(88, 170)
        ..lineTo(94, 184)
        ..lineTo(66, 184)
        ..close(),
      Paint()..color = color,
    );
    canvas.save();
    canvas.translate(48, 58);
    canvas.rotate(25 * math.pi / 180);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 44), Paint()..color = TvdColors.white.withAlpha(90));
    canvas.restore();
    if (dashed) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = TvdColors.encourageDark;
      for (final m in body.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 18) {
          canvas.drawPath(m.extractPath(d, d + 10), p);
        }
      }
    }
    if (ring > 0) {
      canvas.drawArc(
        const Rect.fromLTWH(18, 14, 124, 148),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = TvdColors.white,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BalloonPainter old) => old.color != color || old.ring != ring || old.dashed != dashed;
}

// ====================================================================== G3 Bên nào lớn hơn / Đúng hay sai (B)

/// Hai nửa màn hình theo chiều gương (trái màn hình = bên trái bé). Bé bước sang nửa có đáp án đúng;
/// cũng có thể giơ tay giữ lên thẻ đáp án.
class SidesView extends MiniGameView {
  const SidesView();

  static const _zoneL = Rect.fromLTWH(96, 700, 828, 326);
  static const _zoneR = Rect.fromLTWH(996, 700, 828, 326);

  /// Thẻ đáp án ở phần trên mỗi nửa (cao, phải chủ động giơ tay mới chạm tới).
  static const _cardL = Rect.fromLTWH(200, 380, 620, 270);
  static const _cardR = Rect.fromLTWH(1100, 380, 620, 270);

  @override
  List<Rect> targets(PlayFrame f) =>
      f.question.options.length == 2 && (f.mechanic?.usesTouch ?? false) ? const [_cardL, _cardR] : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => f.question.options.length == 2 ? const [_cardL, _cardR] : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final q = f.question;
    if (q.options.length != 2) return const CardsView().scene(context, f);
    final fb = f.feedback;
    final easy = f.easy;

    (Color, Color) zone(int i) {
      if (fb != null) {
        if (i == q.answer) return (TvdColors.correctSoft, TvdColors.correct);
        if (i == fb.chosen) return (TvdColors.encourageSoft, TvdColors.encourage);
      }
      if (!easy) return (const Color(0xFFEEF1F6), const Color(0xFFC5CBD8));
      return i == 1 ? (const Color(0xFFDDEBFF), TvdColors.right) : (const Color(0xFFFFF1CC), TvdColors.left);
    }

    final offset = switch (f.mechanic) {
      StepMechanic(:final detector) => detector.offset,
      _ => 0.0,
    };
    final out = <Widget>[];
    for (var i = 0; i < 2; i++) {
      final (bg, border) = zone(i);
      out.add(Positioned.fromRect(
        rect: i == 0 ? _zoneL : _zoneR,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: border, width: 8),
          ),
        ),
      ));
    }
    out.addAll([
      placeArt('footL', 380, 820, 100, opacity: easy ? 1 : .35),
      placeArt('footR', 500, 790, 100, opacity: easy ? 1 : .35),
      placeArt('footL', 1320, 790, 100, opacity: easy ? 1 : .35),
      placeArt('footR', 1440, 820, 100, opacity: easy ? 1 : .35),
    ]);
    if (easy && fb == null) {
      out.addAll(const [
        Positioned(left: 130, top: 730, child: SideLabel(right: false, icon: 'foot', height: 110, fontSize: 60)),
        Positioned(right: 130, top: 730, child: SideLabel(right: true, icon: 'foot', height: 110, fontSize: 60)),
      ]);
    }
    for (var i = 0; i < 2; i++) {
      final aimed = f.answering && f.mechanic?.aimed == i;
      out.add(Positioned.fromRect(
        key: ValueKey('answer-$i'),
        rect: i == 0 ? _cardL : _cardR,
        child: AnswerCard(
          slot: i == 0 ? 1 : 0, // trái vàng, phải xanh dương như nhãn TRÁI/PHẢI
          label: q.options[i],
          mark: CardsView.markFor(f, i),
          progress: aimed ? f.mechanic!.progress : 0,
        ),
      ));
    }
    out.add(Positioned(
      left: 810,
      top: 560,
      width: 300,
      height: 450,
      child: KidFigure(body: f.body, shift: (offset * 108).clamp(-300.0, 300.0).toDouble(), dim: f.body == null),
    ));
    final hint = f.answering ? f.mechanic?.hint : null;
    if (hint != null) {
      out.add(Positioned(
        left: 0,
        right: 0,
        top: 660,
        child: Center(
          child: TalkPill(
            text: hint,
            fontSize: 44,
            color: TvdColors.white,
            shadow: TvdColors.cardShadow,
            textColor: TvdColors.inkSoft,
          ),
        ),
      ));
    }
    return out;
  }
}

// ====================================================================== G4 Nhảy đếm (Đ)

/// Bộ đếm lớn, dãy số đếm thêm (2, 4, 6… hoặc 5, 10, 15…) sáng dần theo mỗi lần nhảy, Tin Tin nhảy cùng.
class JumpCountView extends MiniGameView {
  const JumpCountView();

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final q = f.question;
    final mech = f.mechanic;
    if (mech is! CountMechanic) return const CardsView().scene(context, f);
    final seq = (q.data['sequence'] as List?)?.cast<int>() ?? [for (var i = 1; i <= mech.target; i++) i];
    final done = f.feedback != null ? (f.feedback!.correct ? seq.length : mech.count) : mech.count;
    final current = done == 0 ? 0 : seq[math.min(done, seq.length) - 1];
    final bounce = math.max(0.0, 1 - mech.sinceRep / .45);
    final tinTinUp = 70 * math.sin(bounce * math.pi);
    final rise = mech.counter.value.clamp(0.0, 1.0).toDouble();

    return [
      Positioned(left: 0, right: 0, top: 900, bottom: 0, child: Container(color: const Color(0xFFF6E7CF))),
      Positioned(
        left: 150,
        top: 380,
        width: 360,
        height: 540,
        child: KidFigure(body: f.body, lift: rise * 252, dim: f.body == null),
      ),
      Positioned(
        left: 560,
        right: 560,
        top: 360,
        height: 330,
        child: Center(
          child: FittedBox(
            child: Text('$current', style: TvText.bigCounter.copyWith(fontSize: 300, color: TvdColors.answerA)),
          ),
        ),
      ),
      Positioned(
        left: 300,
        right: 300,
        top: 720,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            for (var i = 0; i < seq.length; i++)
              Container(
                width: 130,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < done ? TvdColors.correct : TvdColors.white,
                  borderRadius: BorderRadius.circular(TvdRadius.md),
                  boxShadow: TvdShadow.tv(i < done ? TvdColors.correctDark : TvdColors.cardShadow),
                ),
                child: Text(
                  '${seq[i]}',
                  style: TvText.button.copyWith(fontSize: 60, height: 1, color: i < done ? TvdColors.white : TvdColors.inkSoft),
                ),
              ),
          ],
        ),
      ),
      Positioned(
        right: 160,
        top: 520 - tinTinUp,
        child: TinTin(state: f.feedback?.correct ?? false ? TinTinState.happy : TinTinState.raiseBoth, size: 280),
      ),
      if (f.answering && f.body != null && mech.count == 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Text('Nhảy lên nào!', textAlign: TextAlign.center, style: TvText.prompt.copyWith(color: TvdColors.answerADark)),
        ),
    ];
  }
}

// ====================================================================== G5 Đồng hồ người (T)

/// Đồng hồ lớn có kim bám theo tay bé: tay trái là kim ngắn (giờ), tay phải là kim dài (phút).
/// Mức dễ hiện kim mục tiêu mờ nét đứt.
class HumanClockView extends MiniGameView {
  const HumanClockView();

  @override
  Widget? camTile(PlayFrame f) => null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final mech = f.mechanic;
    if (mech is! ClockMechanic) return const CardsView().scene(context, f);
    final body = f.body;
    final hourA = body?.armAngle(right: false);
    final minA = body?.armAngle(right: true);
    final matching = mech.progress > 0;
    final done = f.feedback?.correct ?? false;
    final reading = mech.reading;
    final handColor = done || matching ? TvdColors.correct : TvdColors.ink;

    Widget legend(bool right) => Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: right ? TvdColors.right : TvdColors.left,
            borderRadius: BorderRadius.circular(TvdRadius.pill),
            border: Border.all(color: TvdColors.ink, width: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Art(right ? 'handR' : 'handL', width: 52),
              const SizedBox(width: 14),
              Text(
                right ? 'Tay phải: kim dài (phút)' : 'Tay trái: kim ngắn (giờ)',
                style: TvText.button.copyWith(fontSize: 40, height: 1, color: right ? TvdColors.white : TvdColors.ink),
              ),
            ],
          ),
        );

    return [
      Positioned(
        left: 220,
        top: 360,
        width: 580,
        height: 580,
        child: Stack(
          children: [
            Positioned.fill(
              child: CircularProgressIndicator(
                value: done ? 1 : mech.progress,
                strokeWidth: 18,
                color: TvdColors.correct,
                backgroundColor: Colors.transparent,
              ),
            ),
            Center(
              child: ClockFace(
                size: 540,
                hourAngle: hourA,
                minuteAngle: minA,
                ghostHour: f.easy ? HumanClock.hourAngle(mech.hour, mech.minute) : null,
                ghostMinute: f.easy ? HumanClock.minuteAngle(mech.minute) : null,
                handColor: handColor,
              ),
            ),
          ],
        ),
      ),
      Positioned(right: 140, top: 380, child: legend(false)),
      Positioned(right: 140, top: 486, child: legend(true)),
      Positioned(
        left: 1080,
        top: 590,
        width: 300,
        height: 450,
        child: KidFigure(
          body: body,
          left: ArmGlow(done || matching ? TvdColors.correct : TvdColors.left),
          right: ArmGlow(done || matching ? TvdColors.correct : TvdColors.right),
          dim: body == null,
        ),
      ),
      if (f.answering)
        Positioned(
          left: 1400,
          top: 640,
          width: 420,
          child: Text(
            reading == null
                ? 'Con dang hai tay ra làm kim nhé!'
                : 'Con đang chỉ\n${reading.minute == 0 ? '${reading.hour} giờ' : '${reading.hour} giờ ${reading.minute} phút'}',
            style: TvText.prompt.copyWith(fontSize: 52),
          ),
        ),
    ];
  }
}
