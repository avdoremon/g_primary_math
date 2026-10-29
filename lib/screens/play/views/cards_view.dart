import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/mechanics.dart';
import '../../../ui/theme/theme.dart';
import '../../../ui/widgets/tin_tin.dart';
import '../mini_game_view.dart';
import '../play_widgets.dart';

/// Mini game mặc định: ô đáp án lớn hàng ngang (2–4 ô), dùng cho mọi dạng trắc nghiệm
/// tới khi mini game có cảnh riêng. Câu không có ô đáp án (Nhảy đếm, Đồng hồ người, lệnh ghép)
/// hiện bảng tiến độ động tác.
class CardsView extends MiniGameView {
  const CardsView();

  static const _bottom = 820.0;

  static bool hasCards(PlayFrame f) {
    final k = f.mechanic?.kind;
    return f.question.options.length > 1 &&
        k != MechanicKind.count &&
        k != MechanicKind.clock &&
        k != MechanicKind.compound;
  }

  static List<Rect> cardRects(PlayFrame f) {
    final n = f.question.options.length;
    const zone = 1600.0;
    const gap = 64.0;
    final top = QuestionVisual.hasVisual(f.question) ? 500.0 : 420.0;
    final w = math.min(520.0, (zone - gap * (n - 1)) / n);
    final total = w * n + gap * (n - 1);
    final left = (TvLayout.width - total) / 2;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(left + i * (w + gap), top, w, _bottom - top)];
  }

  @override
  List<Rect> targets(PlayFrame f) => hasCards(f) && (f.mechanic?.usesTouch ?? false) ? cardRects(f) : const [];

  @override
  List<Rect> tapTargets(PlayFrame f) => hasCards(f) ? cardRects(f) : const [];

  @override
  List<Widget> scene(BuildContext context, PlayFrame f) {
    final q = f.question;
    final mech = f.mechanic;
    final fb = f.feedback;
    final out = <Widget>[];

    if (QuestionVisual.hasVisual(q)) {
      out.add(Positioned(
        left: 200,
        right: 200,
        top: 340,
        height: 150,
        child: Center(child: QuestionVisual(question: q)),
      ));
    }

    if (hasCards(f)) {
      final rects = cardRects(f);
      final stepHints = mech?.kind == MechanicKind.step && f.easy && q.options.length == 2;
      for (var i = 0; i < q.options.length; i++) {
        var mark = CardMark.none;
        if (fb != null) {
          mark = i == q.answer ? CardMark.correct : (i == fb.chosen ? CardMark.wrongPick : CardMark.dimmed);
        } else if (mech?.aimed == i) {
          mark = CardMark.aimed;
        }
        out.add(Positioned.fromRect(
          rect: rects[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: mark,
            progress: fb == null && mech?.aimed == i ? mech!.progress : 0,
            caption: stepHints ? (i == 0 ? '◀ TRÁI' : 'PHẢI ▶') : null,
          ),
        ));
      }
    } else if (fb == null && mech != null) {
      out.add(_motionPanel(f, mech));
    }

    if (fb != null) {
      out.add(bottomFeedback(fb));
    } else {
      final hint = mech?.hint;
      if (hint != null) {
        out.add(Positioned(
          left: 0,
          right: 0,
          bottom: 90,
          child: Text(hint, textAlign: TextAlign.center, style: TvText.prompt.copyWith(color: TvdColors.encourageDark)),
        ));
      }
    }
    return out;
  }

  /// Mini game không có ô đáp án: hiện tiến độ động tác.
  Widget _motionPanel(PlayFrame f, AnswerMechanic mech) {
    final Widget body = switch (mech) {
      CountMechanic(:final count, :final target) => Text('$count / $target', style: TvText.bigCounter),
      ClockMechanic(:final reading) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TinTin(state: TinTinState.raiseBoth, size: 200),
            Text(
              reading == null
                  ? 'Tay trái là kim giờ, tay phải là kim phút'
                  : 'Con đang chỉ ${reading.minute == 0 ? '${reading.hour} giờ' : '${reading.hour} giờ ${reading.minute} phút'}',
              style: TvText.prompt,
            ),
          ],
        ),
      _ => const TinTin(state: TinTinState.hello, size: 260),
    };
    return Positioned(
      left: 0,
      right: 0,
      top: 380,
      height: 440,
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
