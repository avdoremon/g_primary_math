import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/mechanics.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/widgets/tin_tin.dart';
import '../mini_game_view.dart';
import '../play_widgets.dart';
import '../visuals.dart';

/// Mini game mặc định: hình minh hoạ (nếu có) và ô đáp án lớn hàng ngang (2–4 ô).
/// Phản hồi hiện ở thẻ đề của HUD.
class CardsView extends MiniGameView {
  const CardsView({this.bob = false});

  /// Hình trong ô trôi lên xuống nhẹ (Săn hình).
  final bool bob;

  static const bottom = 940.0;

  static bool hasCards(PlayFrame f) {
    final k = f.mechanic?.kind;
    return f.question.options.length > 1 &&
        k != MechanicKind.count &&
        k != MechanicKind.clock &&
        k != MechanicKind.compound;
  }

  /// Đỉnh vùng ô đáp án, chừa chỗ cho hình minh hoạ.
  static double cardsTop(PlayFrame f) {
    final h = QuestionArt.heightFor(f.question);
    return h == 0 ? 420.0 : math.min(600.0, 360 + h + 20);
  }

  static List<Rect> cardRects(PlayFrame f, {double? top}) {
    final n = f.question.options.length;
    const zone = 1600.0;
    const gap = 64.0;
    final t = top ?? cardsTop(f);
    final w = math.min(520.0, (zone - gap * (n - 1)) / n);
    final total = w * n + gap * (n - 1);
    final left = (TvLayout.width - total) / 2;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(left + i * (w + gap), t, w, bottom - t)];
  }

  @override
  List<Rect> targets(PlayFrame f) => hasCards(f) && (f.mechanic?.usesTouch ?? false) ? cardRects(f) : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => hasCards(f) ? cardRects(f) : const [];

  @override
  Widget? camTile(PlayFrame f) => null;

  /// Hình minh hoạ đặt giữa, ngay dưới thẻ đề.
  static Widget? art(PlayFrame f) {
    final a = QuestionArt.of(f.question);
    if (a == null) return null;
    return Positioned(
      left: 160,
      right: 160,
      top: 360,
      height: math.min(QuestionArt.heightFor(f.question), cardsTop(f) - 380),
      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: a)),
    );
  }

  static CardMark markFor(PlayFrame f, int i) {
    final fb = f.feedback;
    if (fb != null) {
      return i == f.question.answer ? CardMark.correct : (i == fb.chosen ? CardMark.wrongPick : CardMark.dimmed);
    }
    return f.mechanic?.aimed == i ? CardMark.aimed : CardMark.none;
  }

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final q = f.question;
    final mech = f.mechanic;
    final out = <Widget>[];
    final a = art(f);
    if (a != null) out.add(a);

    if (hasCards(f)) {
      final rects = cardRects(f);
      final stepHints = mech?.kind == MechanicKind.step && f.easy && q.options.length == 2;
      final drawn = q.data['kind'] == 'shape' || q.data['kind'] == 'banknote';
      for (var i = 0; i < q.options.length; i++) {
        out.add(Positioned.fromRect(
          key: ValueKey('answer-$i'),
          rect: rects[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            content: drawn
                ? Transform.translate(
                    offset: Offset(0, bob ? 14 * math.sin(f.time * 1.3 + i * 1.7) : 0),
                    child: optionArt(q, i),
                  )
                : null,
            mark: markFor(f, i),
            progress: f.answering && mech?.aimed == i ? mech!.progress : 0,
            caption: stepHints ? (i == 0 ? '◀ TRÁI' : 'PHẢI ▶') : null,
          ),
        ));
      }
    } else if (f.answering && mech != null) {
      out.add(_motionPanel(mech));
    }

    final hint = f.answering ? mech?.hint : null;
    if (hint != null) {
      out.add(Positioned(
        left: 0,
        right: 0,
        bottom: 20,
        child: Text(hint, textAlign: TextAlign.center, style: TvText.prompt.copyWith(color: TvdColors.encourageDark)),
      ));
    }
    return out;
  }

  /// Câu không có ô đáp án: hiện tiến độ động tác.
  Widget _motionPanel(AnswerMechanic mech) {
    final Widget body = switch (mech) {
      CountMechanic(:final count, :final target) => Text('$count / $target', style: TvText.bigCounter),
      _ => const TinTin(state: TinTinState.hello, size: 260),
    };
    return Positioned(
      left: 0,
      right: 0,
      top: 380,
      height: 500,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            body,
            const SizedBox(height: TvdSpace.s5),
            SizedBox(
              width: 700,
              child: LinearProgressIndicator(
                value: mech.progress,
                minHeight: 24,
                color: TvdColors.correct,
                backgroundColor: TvdColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
