import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/game/pose_answer.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';

import 'mechanics_test.dart' show Rig, drive, level, question;

/// Đứng thẳng 0,6 giây (để cơ chế sẵn sàng) rồi làm [act].
SimPose Function(double) after(SimPose Function(double t) act) => (t) => t < 0.6 ? SimPose() : act(t - 0.6);

void main() {
  const all = [AnswerAction.jump, AnswerAction.squat, AnswerAction.clap, AnswerAction.wings];

  test('chọn cơ chế Tạo dáng trả lời và động tác khớp số đáp án, không trùng, không cặp dễ nhầm', () {
    for (var n = 2; n <= 4; n++) {
      for (var k = 0; k < 50; k++) {
        final q = question(options: [for (var i = 0; i < n; i++) '${k * 10 + i}']);
        final m = AnswerMechanic.forQuestion(level(MiniGames.poseAnswer), q);
        expect(m, isA<PoseAnswerMechanic>());
        final acts = (m as PoseAnswerMechanic).actions;
        expect(acts.length, n);
        expect(acts.toSet().length, n);
        for (final a in acts) {
          for (final b in acts) {
            if (a != b) expect(AnswerAction.clash(a, b), isFalse);
          }
        }
        expect(AnswerAction.forQuestion(q), acts, reason: 'màn hình và cơ chế phải ra cùng động tác');
      }
    }
  });

  test('nhảy lên chọn ô có động tác nhảy', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: all);
    final out = drive(m, rig, after((t) => SimPose(jump: t < 0.4 ? 0.35 : 0)), 1.6);
    expect(out, [const ChooseOption(0)]);
  });

  test('ngồi xuống chọn ô ngồi', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: all);
    expect(drive(m, rig, after((_) => SimPose(squat: 1)), 1.8), [const ChooseOption(1)]);
  });

  test('vỗ tay chọn ô vỗ tay', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: all);
    final out = drive(m, rig, after((t) => t < 0.3 ? SimPose(leftArm: 240, rightArm: 120) : SimPose(leftArm: 140, rightArm: 220)), 1.6);
    expect(out, [const ChooseOption(2)]);
  });

  test('dang tay giữ đủ lâu chọn ô dang tay', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: all);
    expect(drive(m, rig, after((_) => SimPose(leftArm: 270, rightArm: 90)), 1.8), [const ChooseOption(3)]);
  });

  test('vẫy tay chọn ô vẫy tay', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: const [AnswerAction.jump, AnswerAction.wave]);
    final out = drive(m, rig, after((t) => SimPose(rightArm: (t * 3).floor().isEven ? 10 : 60)), 2.5);
    expect(out, [const ChooseOption(1)]);
  });

  test('vào câu mà vẫn đang dang tay từ câu trước thì chưa chọn, phải buông tay trước', () {
    final rig = Rig();
    final m = PoseAnswerMechanic(actions: all);
    expect(drive(m, rig, (_) => SimPose(leftArm: 270, rightArm: 90), 2), isEmpty);
    expect(m.armed, isFalse);
  });

  test('đứng yên thì không chọn gì', () {
    final rig = Rig();
    expect(drive(PoseAnswerMechanic(actions: all), rig, (_) => SimPose(), 3), isEmpty);
  });

  test('Đứng lên ngồi xuống: đếm số lần ngồi', () {
    final m = AnswerMechanic.forQuestion(level(MiniGames.squatCount), question(options: ['3 lần'], data: {'jumps': 3}));
    expect(m.kind, MechanicKind.count);
    final rig = Rig();
    final out = drive(m, rig, (t) => SimPose(squat: (t % 1.2) < 0.6 && t < 3.6 ? 1.0 : 0), 5.5);
    expect(out, [const ReportResult(true)]);
  });
}
