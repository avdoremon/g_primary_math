import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../content/curriculum.dart';
import '../../../game/feedback.dart';
import '../../../game/mechanics.dart';
import '../../../game/session.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/widgets/tin_tin.dart';
import '../hud.dart';
import '../kid_figure.dart';
import '../mini_game_view.dart';
import '../scene_art.dart';

/// G7 "Con nói, con làm" (lớp 1 – vị trí, định hướng) theo 10 màn trong artifact design G7.
///
/// Loại lệnh lấy từ `question.data['type']` của dạng bài `position`:
/// - pose: giơ tay trái / tay phải / hai tay (G7-2a, 2b)
/// - touch: chạm đồ vật theo vị trí trong tranh – kệ, cây, bàn, hộp (G7-3a, 3b, 5)
/// - step: bước sang trái / phải (G7-4a)
/// - compound: giơ tay và bước (G7-4b)
/// Phản hồi theo G7-6a / 6b. Theo luật đã chốt, sai thì giải thích rồi sang câu sau, không thử lại.
class SimonSaysView extends MiniGameView {
  const SimonSaysView();

  static const _floor = Color(0xFFF6E7CF);
  static const _grass = Color(0xFFCDEBC3);
  static const _wrongArm = Color(0xFFFFC48F);

  String _type(PlayFrame f) => f.question.data['type'] as String? ?? 'touch';

  // ------------------------------------------------------------------ từ khoá và vùng chạm

  @override
  HudKeyword? keyword(PlayFrame f) {
    if (!f.easy) return null;
    final kw = f.question.data['keyword'] as String?;
    if (kw == null) return null;
    final text = f.question.prompt.contains('tầng $kw') ? 'tầng $kw' : kw;
    return HudKeyword(text, side: kw == 'trái' ? 'l' : (kw == 'phải' ? 'r' : null));
  }

  @override
  List<Rect> targets(PlayFrame f) => _type(f) == 'touch' ? _touch(f).hits : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => switch (_type(f)) {
        'touch' => _touch(f).hits,
        'step' => const [_zoneL, _zoneR],
        'pose' => const [Rect.fromLTWH(96, 340, 560, 540), Rect.fromLTWH(1264, 340, 560, 540), Rect.fromLTWH(730, 340, 460, 690)],
        _ => const [],
      };

  @override
  Widget? camTile(PlayFrame f) => _type(f) == 'touch'
      ? Positioned(
          right: TvLayout.safeX,
          bottom: TvLayout.safeY,
          child: CamTile(frame: f.pose, seen: f.body != null),
        )
      : null;

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) => switch (_type(f)) {
        'pose' => _poseScene(f),
        'step' => _stepScene(f),
        'compound' => _compoundScene(f),
        _ => _touchScene(f),
      };

  // ------------------------------------------------------------------ G7-1 giới thiệu

  @override
  List<Widget>? intro(BuildContext context, Level level, double time) {
    final active = (time / 2.5).floor() % 3;
    TinTinState demo(int i) => switch (i) {
          0 => TinTinState.raiseRight,
          1 => TinTinState.raiseRight,
          _ => TinTinState.stepLeft,
        };
    Widget card(int i, Color bg, String title, String sub, List<Widget> art) {
      final on = i == active;
      return AnimatedScale(
        scale: on ? 1.05 : 1,
        duration: const Duration(milliseconds: 250),
        child: AnimatedOpacity(
          opacity: on ? 1 : .6,
          duration: const Duration(milliseconds: 250),
          child: Container(
            width: 520,
            height: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TvdColors.white,
              borderRadius: BorderRadius.circular(TvdRadius.tv),
              boxShadow: [const BoxShadow(color: TvdColors.cardShadow, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
                  child: Stack(
                    children: [
                      ...art,
                      Positioned(
                        left: 20,
                        top: 20,
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: TvdColors.ink, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: TvText.button.copyWith(fontSize: 48, color: TvdColors.white, height: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TvText.button.copyWith(fontSize: 64, height: 1.05)),
                      Text(sub, style: TvText.label.copyWith(fontSize: 40, color: TvdColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      Positioned(left: 0, right: 0, top: 780, bottom: 0, child: Container(color: _floor)),
      Positioned(
        left: 120,
        top: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Con nói, con làm', style: TvText.button.copyWith(fontSize: 128, height: 1)),
            const SizedBox(height: 12),
            Text('Nghe lệnh, rồi làm theo Tin Tin nhé!', style: TvText.prompt.copyWith(fontSize: 56, color: TvdColors.inkSoft)),
          ],
        ),
      ),
      const Positioned(left: 1500, top: 60, child: TinTin(state: TinTinState.hello, size: 290)),
      Positioned(
        left: 120,
        top: 400,
        child: Row(
          children: [
            card(0, TvdColors.sky, 'Giơ tay', 'Tay trái, tay phải', [
              Align(alignment: Alignment.bottomCenter, child: TinTin(state: demo(0), size: 230)),
            ]),
            const SizedBox(width: 60),
            card(1, const Color(0xFFFFF4D6), 'Chạm đồ vật', 'Trên, dưới, ở giữa', [
              const Positioned(left: 236, top: 168, width: 220, height: 120, child: CustomPaint(painter: TablePainter())),
              placeArt('apple', 296, 96, 100),
              Positioned(left: 40, top: 72, child: TinTin(state: demo(1), size: 200)),
            ]),
            const SizedBox(width: 60),
            card(2, const Color(0xFFEFEAFE), 'Bước chân', 'Sang trái, sang phải', [
              Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 26), child: Art('footL', width: 56)),
                    const Padding(padding: EdgeInsets.only(bottom: 56, left: 6), child: Art('footR', width: 56)),
                    const SizedBox(width: 16),
                    TinTin(state: demo(2), size: 220),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------------ phản hồi chung

  /// Tin Tin ở góc trái với bong bóng lời (G7-6a/6b).
  Widget _mascot(AnswerRecord r, {String? correctText, double top = 690}) {
    final ok = r.correct;
    final msg = SessionFeedback.forRecord(r);
    final text = ok
        ? (correctText ?? msg.title)
        : (r.outcome == AnswerOutcome.timeUp ? 'Hết giờ rồi!' : 'Gần đúng rồi!');
    return Positioned(
      left: 120,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TvdColors.white,
              borderRadius: BorderRadius.circular(TvdRadius.pill),
              border: Border.all(color: ok ? TvdColors.correct : TvdColors.encourage, width: 4),
            ),
            child: Text(
              text,
              style: TvText.button.copyWith(fontSize: 44, height: 1, color: ok ? TvdColors.correctDark : TvdColors.encourageDark),
            ),
          ),
          const SizedBox(height: 8),
          TinTin(state: ok ? TinTinState.praise : TinTinState.encourage, size: 230),
        ],
      ),
    );
  }

  Widget _points(AnswerRecord r, double left, double top) => Positioned(
        left: left,
        top: top,
        child: TalkPill(text: '+${r.points}', fontSize: 64),
      );

  /// Lời giải thích ngắn khi chưa đúng, đặt cạnh đồ vật đúng.
  Widget _explain(AnswerRecord r, Rect near) {
    final rightSide = near.right + 40 + 640 < TvLayout.width - TvLayout.safeX;
    return Positioned(
      left: rightSide ? near.right + 40 : null,
      right: rightSide ? null : TvLayout.width - near.left + 40,
      top: near.center.dy - 55,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: TalkPill(
          text: r.question.explanation,
          fontSize: 48,
          icon: rightSide ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ G7-2 tạo dáng tay

  List<Widget> _poseScene(PlayFrame f) {
    final q = f.question;
    final fb = f.feedback;
    final mech = f.mechanic is ArmChoiceMechanic ? f.mechanic! as ArmChoiceMechanic : null;
    final wantL = q.answer == 0 || q.answer == 2;
    final wantR = q.answer == 1 || q.answer == 2;
    final leftUp = mech?.leftUp ?? false, rightUp = mech?.rightUp ?? false;

    ArmGlow? glow(bool right) {
      final want = right ? wantR : wantL;
      final up = right ? rightUp : leftUp;
      if (fb != null) {
        if (want) return ArmGlow(TvdColors.correct, check: fb.correct);
        final chosen = fb.chosen;
        final pickedThis = chosen != null && (chosen == 2 || chosen == (right ? 1 : 0));
        return pickedThis ? const ArmGlow(_wrongArm) : null;
      }
      return up && want ? ArmGlow(right ? TvdColors.right : TvdColors.left) : null;
    }

    SideLabelState labelState(bool right) {
      if (fb == null) return SideLabelState.normal;
      final want = right ? wantR : wantL;
      return want ? SideLabelState.correct : SideLabelState.dimmed;
    }

    final out = <Widget>[
      Positioned(left: 0, right: 0, top: 880, bottom: 0, child: Container(color: _floor)),
      if (f.easy) ...[
        Positioned(
          left: 140,
          top: 440,
          child: SideLabel(right: false, glow: fb == null && leftUp && wantL, state: labelState(false)),
        ),
        Positioned(
          right: 140,
          top: 440,
          child: SideLabel(right: true, glow: fb == null && rightUp && wantR, state: labelState(true)),
        ),
      ],
      Positioned(
        left: 730,
        top: 340,
        width: 460,
        height: 690,
        child: KidFigure(body: f.body, left: glow(false), right: glow(true), dim: f.body == null && fb == null),
      ),
    ];

    if (fb == null) {
      if (f.easy) {
        out.add(Positioned(
          left: 120,
          top: 690,
          child: Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: TvdColors.white, borderRadius: BorderRadius.circular(TvdRadius.pill)),
                child: Text('Làm như Tin Tin', style: TvText.label.copyWith(fontSize: 36)),
              ),
              const SizedBox(height: 8),
              TinTin(
                state: q.answer == 0 ? TinTinState.raiseLeft : (q.answer == 1 ? TinTinState.raiseRight : TinTinState.raiseBoth),
                size: 240,
              ),
            ],
          ),
        ));
      }
      final fix = mech?.fixArm;
      if (fix != null) {
        final pill = TalkPill(
          text: mech!.hint!,
          color: TvdColors.white,
          shadow: TvdColors.cardShadow,
          textColor: TvdColors.inkSoft,
          fontSize: 48,
          icon: mech.fixLower ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        );
        out.add(fix
            ? Positioned(left: 1260, top: 440, child: pill)
            : Positioned(right: TvLayout.width - 660, top: 440, child: pill));
      }
    } else {
      final side = q.answer == 2 ? 'Hai tay!' : (q.answer == 1 ? 'Tay phải!' : 'Tay trái!');
      out.add(_mascot(fb, correctText: '${SessionFeedback.forRecord(fb).title} $side'));
      if (fb.correct) {
        out.add(_points(fb, 1440, 640));
      } else {
        out.add(Positioned(
          right: TvLayout.safeX,
          top: 660,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TalkPill(text: q.explanation, fontSize: 44),
          ),
        ));
      }
    }
    return out;
  }

  // ------------------------------------------------------------------ G7-3, G7-5 chạm đồ vật

  /// Bố cục cảnh chạm: đồ vật vẽ (theo thứ tự lớp) và vùng chạm theo thứ tự đáp án.
  _TouchLayout _touch(PlayFrame f) {
    final scene = f.question.data['scene'] as String? ?? 'shelf';
    switch (scene) {
      case 'tree':
        return _TouchLayout(
          ground: _grass,
          groundTop: 900,
          items: const [
            ('tree', Offset(740, 420), 440.0),
            ('apple', Offset(1010, 520), 110.0),
            ('cat', Offset(1470, 540), 190.0),
            ('rabbit', Offset(470, 738), 170.0),
            ('rabbit', Offset(1260, 738), 170.0),
          ],
          objects: [artRect('rabbit', 470, 738, 170), artRect('rabbit', 1260, 738, 170)],
        );
      case 'table':
        return _TouchLayout(
          ground: _floor,
          groundTop: 820,
          painted: const [(TablePainter(), Rect.fromLTWH(560, 560, 800, 400))],
          items: const [
            ('ball', Offset(900, 490), 150.0),
            ('ball', Offset(885, 793), 150.0),
            ('cat', Offset(1340, 760), 200.0),
          ],
          objects: [artRect('ball', 900, 490, 150), artRect('ball', 885, 793, 150)],
        );
      case 'box':
        return _TouchLayout(
          ground: _floor,
          groundTop: 800,
          items: const [
            ('cat', Offset(880, 450), 200.0), // mèo sau: nhỏ, bị hộp che thân
            ('box', Offset(740, 590), 440.0),
            ('cat', Offset(620, 760), 240.0), // mèo trước: to, thấp, đè lên mép hộp
            ('ball', Offset(1250, 850), 150.0),
          ],
          // Thứ tự đáp án theo dạng bài: trước, sau.
          objects: [artRect('cat', 620, 760, 240), const Rect.fromLTWH(880, 450, 200, 150)],
        );
      default: // shelf: trên, giữa, dưới
        const shelf = Rect.fromLTWH(600, 370, 720, 640);
        return _TouchLayout(
          ground: _floor,
          groundTop: 880,
          painted: const [(ShelfPainter(), shelf)],
          items: const [
            ('rabbit', Offset(740, 406), 118.0),
            ('ball', Offset(1080, 428), 140.0),
            ('rabbit', Offset(900, 611), 118.0),
            ('apple', Offset(700, 836), 140.0),
            ('rabbit', Offset(1060, 816), 118.0),
          ],
          objects: [artRect('rabbit', 740, 406, 118), artRect('rabbit', 900, 611, 118), artRect('rabbit', 1060, 816, 118)],
          hits: [
            for (var i = 0; i < 3; i++)
              () {
                final t = ShelfPainter.tier(shelf.size, i).shift(shelf.topLeft);
                // Cả ô tầng, nới thêm nửa tấm ván để vùng chạm cao ≥ 200px.
                return Rect.fromLTRB(t.left, t.top - ShelfPainter.board / 2, t.right, t.bottom + ShelfPainter.board / 2);
              }(),
          ],
        );
    }
  }

  List<Widget> _touchScene(PlayFrame f) {
    final layout = _touch(f);
    final fb = f.feedback;
    final q = f.question;
    final scene = q.data['scene'] as String? ?? 'shelf';
    final out = <Widget>[
      Positioned(left: 0, right: 0, top: layout.groundTop, bottom: 0, child: Container(color: layout.ground)),
      for (final (painter, rect) in layout.painted) Positioned.fromRect(rect: rect, child: CustomPaint(painter: painter)),
      for (final (name, at, w) in layout.items) placeArt(name, at.dx, at.dy, w),
    ];
    if (scene == 'tree' && f.easy) {
      out.add(const Positioned(left: 140, top: 400, child: SideLabel(right: false, height: 110, fontSize: 60)));
      out.add(const Positioned(right: 140, top: 400, child: SideLabel(right: true, height: 110, fontSize: 60)));
    }
    final aimed = f.mechanic?.aimed;
    if (fb == null && aimed != null && aimed < layout.objects.length) {
      // Đồ vật đang được nhắm: viền trắng nhẹ.
      out.add(ringAround(layout.objects[aimed], correct: true, pad: 24));
    }
    if (fb != null) {
      final right = layout.objects[q.answer];
      final chosen = fb.chosen;
      if (!fb.correct && chosen != null && chosen != q.answer && chosen < layout.objects.length) {
        out.add(ringAround(layout.objects[chosen], correct: false));
      }
      out.add(ringAround(right, correct: true));
      out.add(_mascot(fb, top: 640));
      out.add(fb.correct ? _points(fb, right.right + 40, right.top) : _explain(fb, right));
    }
    return out;
  }

  // ------------------------------------------------------------------ G7-4 bước chân

  static const _zoneL = Rect.fromLTWH(96, 620, 828, 406);
  static const _zoneR = Rect.fromLTWH(996, 620, 828, 406);

  Widget _zone(Rect r, {required Color bg, required Color border}) => Positioned.fromRect(
        rect: r,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: border, width: 8),
          ),
        ),
      );

  List<Widget> _feet({required bool grey}) => [
        for (final (name, x, y) in const [
          ('footL', 470.0, 810.0),
          ('footR', 600.0, 780.0),
          ('footL', 1300.0, 780.0),
          ('footR', 1430.0, 810.0),
        ])
          grey
              ? Positioned(
                  left: x,
                  top: y,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 0, //
                      0.33, 0.33, 0.33, 0, 0, //
                      0.33, 0.33, 0.33, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: Art(name, width: 110, opacity: .35),
                  ),
                )
              : placeArt(name, x, y, 110),
      ];

  double _shift(AnswerMechanic? m) {
    final offset = switch (m) {
      StepMechanic(:final detector) => detector.offset,
      CompoundMechanic(:final step) => step.offset,
      _ => 0.0,
    };
    return (offset * 108).clamp(-300.0, 300.0).toDouble();
  }

  List<Widget> _stepScene(PlayFrame f) {
    final q = f.question;
    final fb = f.feedback;
    final targetRight = q.answer == 1;
    final easy = f.easy;

    (Color, Color) zoneColors(bool right) {
      if (fb != null) {
        final isAnswer = (q.answer == 1) == right;
        final chosen = fb.chosen;
        final isChosen = chosen != null && (chosen == 1) == right;
        if (isAnswer) return (TvdColors.correctSoft, TvdColors.correct);
        if (isChosen) return (TvdColors.encourageSoft, TvdColors.encourage);
      }
      if (!easy) return (const Color(0xFFEEF1F6), const Color(0xFFC5CBD8));
      return right ? (const Color(0xFFDDEBFF), TvdColors.right) : (const Color(0xFFFFF1CC), TvdColors.left);
    }

    final (lBg, lBorder) = zoneColors(false);
    final (rBg, rBorder) = zoneColors(true);
    final out = <Widget>[
      _zone(_zoneL, bg: lBg, border: lBorder),
      _zone(_zoneR, bg: rBg, border: rBorder),
      ..._feet(grey: !easy),
    ];
    if (easy && fb == null) {
      out.addAll([
        Positioned(left: 300, top: 380, child: SideLabel(right: false, icon: 'foot', glow: !targetRight)),
        Positioned(right: 300, top: 380, child: SideLabel(right: true, icon: 'foot', glow: targetRight)),
        Positioned(left: targetRight ? 1210 : 470, top: 660, child: StepArrow(right: targetRight)),
        Positioned(
          left: targetRight ? 1580 : 150,
          top: 790,
          child: TinTin(state: targetRight ? TinTinState.stepRight : TinTinState.stepLeft, size: 190),
        ),
      ]);
    }
    out.add(Positioned(
      left: 770,
      top: 450,
      width: 380,
      height: 570,
      child: KidFigure(body: f.body, shift: _shift(f.mechanic), dim: f.body == null),
    ));
    if (fb == null) {
      final hint = f.mechanic?.hint;
      if (hint != null) out.add(_centerPill(hint, top: 500));
    } else {
      final msg = SessionFeedback.forRecord(fb);
      out.add(_centerPill(
        fb.correct ? '${msg.title}  +${fb.points}' : '${msg.title}. ${q.explanation}',
        top: 420,
        ok: fb.correct,
      ));
    }
    return out;
  }

  Widget _centerPill(String text, {required double top, bool? ok}) => Positioned(
        left: 200,
        right: 200,
        top: top,
        child: Center(
          child: TalkPill(
            text: text,
            fontSize: 52,
            color: ok == null ? TvdColors.white : (ok ? TvdColors.correct : TvdColors.encourageSoft),
            shadow: ok == null ? TvdColors.cardShadow : (ok ? TvdColors.correctDark : TvdColors.encourage),
            textColor: ok == null ? TvdColors.inkSoft : (ok ? TvdColors.white : TvdColors.encourageDark),
          ),
        ),
      );

  // ------------------------------------------------------------------ G7-4b lệnh ghép

  List<Widget> _compoundScene(PlayFrame f) {
    final q = f.question;
    final fb = f.feedback;
    final mech = f.mechanic is CompoundMechanic ? f.mechanic! as CompoundMechanic : null;
    final armsDone = fb?.correct ?? (mech?.armsOk ?? false);
    final stepDone = fb?.correct ?? (armsDone && (mech?.sideOk ?? false));
    final wantLeft = q.data['left'] == 'up';
    final wantRight = q.data['right'] == 'up';
    final goRight = q.data['side'] == 'right';

    Widget chip(int n, String text, bool done) => Container(
          height: 88,
          padding: const EdgeInsets.only(left: 16, right: 32),
          decoration: BoxDecoration(
            color: done ? TvdColors.correctSoft : TvdColors.white,
            borderRadius: BorderRadius.circular(TvdRadius.pill),
            border: Border.all(color: done ? TvdColors.correct : TvdColors.answerC, width: 5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: done ? TvdColors.correct : TvdColors.answerC, shape: BoxShape.circle),
                child: done
                    ? const Icon(Icons.check_rounded, color: TvdColors.white, size: 44)
                    : Text('$n', style: TvText.button.copyWith(fontSize: 40, color: TvdColors.white, height: 1)),
              ),
              const SizedBox(width: 16),
              Text(text, style: TvText.button.copyWith(fontSize: 48, height: 1, color: done ? TvdColors.correctDark : TvdColors.ink)),
            ],
          ),
        );

    final grey = (const Color(0xFFEEF1F6), const Color(0xFFC5CBD8));
    (Color, Color) zone(bool right) {
      if (stepDone && right == goRight) return (TvdColors.correctSoft, TvdColors.correct);
      return grey;
    }

    final (lBg, lBorder) = zone(false);
    final (rBg, rBorder) = zone(true);
    final armColor = armsDone ? TvdColors.correct : null;
    final out = <Widget>[
      _zone(_zoneL, bg: lBg, border: lBorder),
      _zone(_zoneR, bg: rBg, border: rBorder),
      ..._feet(grey: true),
      Positioned(
        left: 0,
        right: 0,
        top: 370,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [chip(1, 'Giơ tay', armsDone), const SizedBox(width: 24), chip(2, 'Bước chân', stepDone)],
        ),
      ),
      Positioned(
        left: 770,
        top: 450,
        width: 380,
        height: 570,
        child: KidFigure(
          body: f.body,
          shift: _shift(mech),
          left: wantLeft && armColor != null ? ArmGlow(armColor) : null,
          right: wantRight && armColor != null ? ArmGlow(armColor) : null,
          dim: f.body == null,
        ),
      ),
    ];
    if (fb == null) {
      final hint = mech?.hint;
      if (hint != null) out.add(_centerPill(hint, top: 500));
    } else {
      final msg = SessionFeedback.forRecord(fb);
      out.add(_centerPill(
        fb.correct ? '${msg.title}  +${fb.points}' : '${msg.title}. ${q.explanation}',
        top: 500,
        ok: fb.correct,
      ));
    }
    return out;
  }
}

class _TouchLayout {
  _TouchLayout({
    required this.ground,
    required this.groundTop,
    required this.items,
    required this.objects,
    this.painted = const [],
    List<Rect>? hits,
  }) : hits = hits ?? [for (final o in objects) _hitFor(o)];

  final Color ground;
  final double groundTop;

  /// (tên asset, góc trên trái, chiều rộng), vẽ theo thứ tự.
  final List<(String, Offset, double)> items;
  final List<(CustomPainter, Rect)> painted;

  /// Đồ vật ứng với từng đáp án (để vẽ vòng đánh dấu).
  final List<Rect> objects;

  /// Vùng chạm vô hình theo từng đáp án, tối thiểu 220×200 (design G7-3a).
  final List<Rect> hits;

  static Rect _hitFor(Rect o) {
    final w = math.max(220.0, o.width + 60), h = math.max(200.0, o.height + 60);
    return Rect.fromCenter(center: o.center, width: w, height: h);
  }
}
