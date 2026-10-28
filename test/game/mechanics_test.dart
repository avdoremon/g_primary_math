import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/content/question.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/motion/motion_engine.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';

final sim = PoseSimulator();

/// Motion Engine đã hiệu chỉnh cùng đồng hồ giả chạy tiếp qua các lần [drive].
class Rig {
  Rig() {
    for (final f in sim.sequence(seconds: 1.5, pose: (_) => SimPose(leftArm: 0, rightArm: 0))) {
      engine.process(f);
    }
    expect(engine.calibration, isNotNull);
  }

  final engine = MotionEngine();
  Duration clock = const Duration(seconds: 2);
}

Rig calibrated() => Rig();

/// Cho cơ chế chạy theo một chuỗi tư thế, trả về các tín hiệu nhận được.
List<MechanicSignal> drive(AnswerMechanic m, Rig rig, SimPose Function(double t) pose, double seconds) {
  final out = <MechanicSignal>[];
  for (final f in sim.sequence(seconds: seconds, start: rig.clock, pose: pose)) {
    final mf = rig.engine.process(f);
    final s = m.update(MechanicInput(dt: 1 / 30, body: mf.body, calibration: rig.engine.calibration));
    if (s != null) out.add(s);
  }
  rig.clock += Duration(milliseconds: (seconds * 1000).round() + 100);
  return out;
}

Level level(String miniGame) => Level(
      level: 1,
      questions: 10,
      secondsPerQuestion: 12,
      generator: 'add_sub',
      params: const {},
      answers: 2,
      miniGame: miniGame,
    );

Question question({List<String> options = const ['1', '2'], Map<String, Object?> data = const {}}) => Question(
      generator: 'test',
      prompt: '?',
      speech: '?',
      options: options,
      answer: 0,
      explanation: '.',
      explanationSpeech: '.',
      data: data,
    );

void main() {
  group('Chọn cơ chế theo mini game', () {
    test('mặc định là chạm tay', () {
      expect(AnswerMechanic.forQuestion(level(MiniGames.balloon), question()).kind, MechanicKind.touch);
    });
    test('Bên nào lớn hơn: bước (vẫn cho chạm)', () {
      final m = AnswerMechanic.forQuestion(level(MiniGames.sides), question());
      expect(m.kind, MechanicKind.step);
      expect(m.usesTouch, isTrue);
    });
    test('Nhảy đếm, Đồng hồ người, Con nói con làm', () {
      expect(
        AnswerMechanic.forQuestion(level(MiniGames.jumpCount), question(options: ['3 lần'], data: {'jumps': 3})).kind,
        MechanicKind.count,
      );
      expect(
        AnswerMechanic.forQuestion(
          level(MiniGames.humanClock),
          question(options: ['3 giờ'], data: {'hour': 3, 'minute': 0}),
        ).kind,
        MechanicKind.clock,
      );
      expect(
        AnswerMechanic.forQuestion(
          level(MiniGames.simonSays),
          question(options: ['Tay trái', 'Tay phải', 'Hai tay'], data: {'type': 'pose'}),
        ).kind,
        MechanicKind.armChoice,
      );
      expect(
        AnswerMechanic.forQuestion(level(MiniGames.simonSays), question(data: {'type': 'step'})).kind,
        MechanicKind.step,
      );
      expect(
        AnswerMechanic.forQuestion(
          level(MiniGames.simonSays),
          question(options: ['x'], data: {'type': 'compound', 'left': 'up', 'right': 'down', 'side': 'right'}),
        ).kind,
        MechanicKind.compound,
      );
    });
  });

  test('C – giữ tay 0,4 giây trên ô thứ hai thì chọn ô đó', () {
    final m = TouchMechanic();
    final targets = [const Rect.fromLTWH(0, 0.4, 0.3, 0.4), const Rect.fromLTWH(0.6, 0.4, 0.3, 0.4)];
    MechanicSignal? got;
    for (var i = 0; i < 20 && got == null; i++) {
      got = m.update(MechanicInput(dt: 1 / 30, hands: const [null, Offset(0.7, 0.6)], targets: targets));
    }
    expect(got, const ChooseOption(1));
  });

  test('B – bước sang trái chọn đáp án 0, sang phải chọn đáp án 1', () {
    final e = calibrated();
    expect(drive(StepMechanic(), e, (t) => SimPose(centerX: t < 0.5 ? 0.5 : 0.3), 1.5), [const ChooseOption(0)]);
    expect(drive(StepMechanic(), e, (t) => SimPose(centerX: t < 0.5 ? 0.5 : 0.7), 1.5), [const ChooseOption(1)]);
  });

  test('B – đang đứng lệch từ câu trước thì phải về giữa rồi mới chọn được', () {
    final e = calibrated();
    drive(TouchMechanic(), e, (_) => SimPose(centerX: 0.3), 1); // câu trước: bé đã đứng sang trái
    final m = StepMechanic();
    // Vẫn đứng bên trái 1 giây: chưa tính.
    expect(drive(m, e, (_) => SimPose(centerX: 0.3), 1), isEmpty);
    expect(m.hint, isNotNull);
    // Về giữa rồi bước trái: tính.
    expect(drive(m, e, (t) => SimPose(centerX: t < 0.8 ? 0.5 : 0.3), 1.8), [const ChooseOption(0)]);
  });

  test('Đ – nhảy đúng 3 lần thì đúng, nhảy 4 lần khi đề là 3 thì sai', () {
    final e = calibrated();
    SimPose Function(double) jumping(int n) => (t) => SimPose(jump: (t % 0.6) < 0.3 && t < 0.6 * n ? 0.35 : 0);

    final ok = CountMechanic(target: 3);
    expect(drive(ok, e, jumping(3), 3.5), [const ReportResult(true)]);

    final over = CountMechanic(target: 3);
    final s = drive(over, e, jumping(4), 3.5);
    expect(s.first, const ReportResult(false));
  });

  test('T – giơ tay phải giữ 0,6 giây chọn "Tay phải", hai tay chọn "Hai tay"', () {
    final e = calibrated();
    expect(drive(ArmChoiceMechanic(), e, (_) => SimPose(rightArm: 10), 1).first, const ChooseOption(1));
    expect(drive(ArmChoiceMechanic(), e, (_) => SimPose(leftArm: 350), 1).first, const ChooseOption(0));
    expect(drive(ArmChoiceMechanic(), e, (_) => SimPose(leftArm: 0, rightArm: 0), 1).first, const ChooseOption(2));
    expect(drive(ArmChoiceMechanic(), e, (_) => SimPose(), 1), isEmpty, reason: 'buông tay thì không chọn');
  });

  test('T – Đồng hồ người: chỉ đúng 3 giờ thì đúng, chỉ 6 giờ thì chưa', () {
    final e = calibrated();
    expect(drive(ClockMechanic(hour: 3, minute: 0), e, (_) => SimPose(leftArm: 90, rightArm: 0), 1.5),
        [const ReportResult(true)]);
    final wrong = ClockMechanic(hour: 3, minute: 0);
    expect(drive(wrong, e, (_) => SimPose(leftArm: 180, rightArm: 0), 1.5), isEmpty);
    expect(wrong.reading, (hour: 6, minute: 0));
  });

  test('T + B – lệnh ghép: giơ tay trái và bước sang phải', () {
    final e = calibrated();
    final m = AnswerMechanic.forQuestion(
      level(MiniGames.simonSays),
      question(options: ['x'], data: {'type': 'compound', 'left': 'up', 'right': 'down', 'side': 'right'}),
    );
    // Chỉ giơ tay, chưa bước: chưa đúng, có lời nhắc bước.
    expect(drive(m, e, (_) => SimPose(leftArm: 0), 1), isEmpty);
    expect(m.hint, contains('bước sang bên phải'));
    // Giữ tay và bước sang phải.
    expect(drive(m, e, (_) => SimPose(leftArm: 0, centerX: 0.7), 1.5), [const ReportResult(true)]);
  });
}
