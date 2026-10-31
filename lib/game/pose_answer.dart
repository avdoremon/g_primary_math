import 'dart:math' as math;

import '../content/question.dart';
import '../motion/sim/pose_simulator.dart';

/// Động tác dùng để chọn đáp án trong game "Tạo dáng trả lời": mỗi ô đáp án một động tác.
enum AnswerAction {
  jump('NHẢY LÊN', 'nhảy lên'),
  squat('NGỒI XUỐNG', 'ngồi xuống'),
  clap('VỖ TAY', 'vỗ tay'),
  wave('VẪY TAY', 'vẫy tay'),
  handsUp('GIƠ 2 TAY', 'giơ hai tay lên cao'),
  wings('DANG TAY', 'dang hai tay');

  const AnswerAction(this.caption, this.spoken);

  /// Nhãn dưới hình trên TV.
  final String caption;

  /// Dùng trong lời đọc.
  final String spoken;

  /// Tư thế mẫu để vẽ hình (dùng bộ giả lập khung xương).
  SimPose get sample => switch (this) {
        AnswerAction.jump => SimPose(jump: 0.3, leftArm: 330, rightArm: 30),
        AnswerAction.squat => SimPose(squat: 1, leftArm: 250, rightArm: 110),
        AnswerAction.clap => SimPose(leftArm: 140, rightArm: 220),
        AnswerAction.wave => SimPose(rightArm: 25),
        AnswerAction.handsUp => SimPose(leftArm: 0, rightArm: 0),
        AnswerAction.wings => SimPose(leftArm: 270, rightArm: 90),
      };

  /// Hai động tác dễ nhận nhầm nhau thì không cho cùng một câu.
  static bool clash(AnswerAction a, AnswerAction b) {
    bool pair(AnswerAction x, AnswerAction y) => (a == x && b == y) || (a == y && b == x);
    return pair(AnswerAction.clap, AnswerAction.handsUp) || pair(AnswerAction.wave, AnswerAction.handsUp);
  }

  /// Động tác cho từng đáp án của câu [q]. Cố định theo câu (màn hình và cơ chế nhận cùng một kết quả).
  static List<AnswerAction> forQuestion(Question q) {
    var seed = 17;
    for (final c in '${q.prompt}|${q.options.join('|')}'.codeUnits) {
      seed = (seed * 31 + c) & 0x3fffffff;
    }
    final pool = [...values]..shuffle(math.Random(seed));
    final out = <AnswerAction>[];
    for (final a in pool) {
      if (out.length >= q.options.length) break;
      if (out.any((b) => clash(a, b))) continue;
      out.add(a);
    }
    return out;
  }
}
