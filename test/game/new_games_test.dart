import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/motion/detectors/knee_lift.dart';
import 'package:g_primary_math/motion/detectors/rep_counter.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';

import 'mechanics_test.dart' show Rig, drive, level, question;

void main() {
  group('Chọn cơ chế cho game mới', () {
    test('mỗi mini game chọn đúng cơ chế', () {
      AnswerMechanic of(String g, {List<String>? o, Map<String, Object?> d = const {}}) =>
          AnswerMechanic.forQuestion(level(g), question(options: o ?? ['1', '2', '3'], data: d));
      expect(of(MiniGames.hopTiles), isA<ZoneMechanic>());
      expect((of(MiniGames.hopTiles) as ZoneMechanic).confirm, ZoneConfirm.jump);
      expect((of(MiniGames.starCatch) as ZoneMechanic).confirm, ZoneConfirm.landing);
      expect(of(MiniGames.touchOrder, d: {'sequence': [2, 0, 1]}), isA<OrderTouchMechanic>());
      expect(of(MiniGames.tintinSays), isA<ArmChoiceMechanic>());
      expect(of(MiniGames.balance, o: ['a', 'b']).kind, MechanicKind.step);
      expect(of(MiniGames.runRace, o: ['a', 'b']), isA<RunChooseMechanic>());
      expect(of(MiniGames.squatGate, o: ['a', 'b']), isA<GateMechanic>());
      expect(of(MiniGames.clapCount, o: ['3 lần'], d: {'jumps': 3}).kind, MechanicKind.count);
    });

    test('câu bước trái/phải vẫn dùng cơ chế riêng của Chạy đua và Cổng', () {
      final q = question(options: ['a', 'b'], data: {'type': 'step'});
      expect(AnswerMechanic.forQuestion(level(MiniGames.runRace), q), isA<RunChooseMechanic>());
      expect(AnswerMechanic.forQuestion(level(MiniGames.squatGate), q), isA<GateMechanic>());
    });

    test('thiếu dữ liệu thì rơi về chạm tay', () {
      expect(AnswerMechanic.forQuestion(level(MiniGames.touchOrder), question()).kind, MechanicKind.touch);
    });
  });

  group('Nhảy ô', () {
    test('đứng ô trái rồi nhảy thì chọn ô trái', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3, confirm: ZoneConfirm.jump);
      expect(drive(m, rig, (_) => SimPose(centerX: .15), 1), isEmpty);
      expect(m.zone, 0);
      final out = drive(m, rig, (t) => SimPose(centerX: .15, jump: t < .4 ? .35 : 0), 1.5);
      expect(out, [const ChooseOption(0)]);
    });

    test('đứng yên không nhảy thì không chọn', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3, confirm: ZoneConfirm.jump);
      expect(drive(m, rig, (_) => SimPose(), 3), isEmpty);
    });
  });

  group('Hứng sao', () {
    test('sao rơi xong thì chọn ô bé đang đứng', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3, confirm: ZoneConfirm.landing, fallSeconds: 2);
      final out = drive(m, rig, (_) => SimPose(centerX: .85), 2.5);
      expect(out, [const ChooseOption(2)]);
    });

    test('bé đổi chỗ trong lúc sao rơi: tính theo chỗ đứng cuối', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3, confirm: ZoneConfirm.landing, fallSeconds: 2);
      final out = drive(m, rig, (t) => SimPose(centerX: t < 1 ? .85 : .15), 2.5);
      expect(out, [const ChooseOption(0)]);
    });

    test('không thấy bé thì không chọn bừa', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3, confirm: ZoneConfirm.landing, fallSeconds: 1);
      expect(drive(m, rig, (_) => SimPose(visible: false), 2), isEmpty);
    });

    test('thời gian rơi theo giờ của level', () {
      Level l(int s) => Level(
            level: 1, questions: 10, secondsPerQuestion: s, generator: 'add_sub', params: const {},
            answers: 3, miniGame: MiniGames.starCatch,
          );
      expect(AnswerMechanic.starFallSeconds(l(15)), 9);
      expect(AnswerMechanic.starFallSeconds(l(8)), closeTo(4.8, 1e-9));
      expect(AnswerMechanic.starFallSeconds(l(2)), 3.5);
      expect(AnswerMechanic.starFallSeconds(l(0)), 7);
    });
  });

  group('Chạm theo thứ tự', () {
    test('chạm đủ theo thứ tự thì đúng', () {
      final m = OrderTouchMechanic(sequence: [2, 0, 1]);
      expect(m.next, 2);
      expect(m.pick(2), isNull);
      expect(m.pick(2), isNull); // ô đã chạm: bỏ qua
      expect(m.pick(0), isNull);
      expect(m.touched, {2, 0});
      expect(m.pick(1), const ReportResult(true));
    });

    test('chạm nhầm ô thì chưa đúng', () {
      final m = OrderTouchMechanic(sequence: [2, 0, 1]);
      expect(m.pick(0), const ReportResult(false));
      expect(m.pick(2), isNull); // đã xong
    });
  });

  group('Cổng nhảy ngồi', () {
    test('ngồi xuống chọn cổng thấp', () {
      final rig = Rig();
      final m = GateMechanic();
      final out = drive(m, rig, (t) => SimPose(squat: t < .6 ? 0 : 1), 1.8);
      expect(out, [const ChooseOption(0)]);
    });

    test('nhảy lên chọn cổng cao', () {
      final rig = Rig();
      final m = GateMechanic();
      final out = drive(m, rig, (t) => SimPose(jump: t < .6 ? 0 : (t < 1 ? .35 : 0)), 1.8);
      expect(out, [const ChooseOption(1)]);
    });

    test('đứng yên thì không chọn', () {
      final rig = Rig();
      expect(drive(GateMechanic(), rig, (_) => SimPose(), 3), isEmpty);
    });
  });

  group('Chạy đua tại chỗ', () {
    SimPose run(double t) => SimPose(leftKnee: (t % .5) < .25 ? 1 : 0, rightKnee: (t % .5) >= .25 ? 1 : 0);

    test('đếm bước chạy bằng nhấc đầu gối', () {
      final rig = Rig();
      final c = KneeLiftCounter();
      for (final f in sim4.sequence(seconds: 3.5, start: rig.clock, pose: run)) {
        c.update(rig.engine.process(f).body);
      }
      expect(c.count, inInclusiveRange(5, 7));
    });

    test('chạy đủ rồi đứng thẳng, nghiêng trái thì chọn đường trái', () {
      final rig = Rig();
      final m = RunChooseMechanic();
      expect(drive(m, rig, run, 3.5), isEmpty);
      expect(m.arrived, isTrue);
      expect(drive(m, rig, (_) => SimPose(), 1), isEmpty);
      expect(m.armed, isTrue);
      expect(drive(m, rig, (_) => SimPose(lean: -.7), 1.2), [const ChooseOption(0)]);
    });

    test('nghiêng phải thì chọn đường phải', () {
      final rig = Rig();
      final m = RunChooseMechanic();
      drive(m, rig, run, 3.5);
      drive(m, rig, (_) => SimPose(), 1);
      expect(drive(m, rig, (_) => SimPose(lean: .7), 1.2), [const ChooseOption(1)]);
    });

    test('chưa chạy đủ thì nghiêng không có tác dụng', () {
      final rig = Rig();
      final m = RunChooseMechanic();
      expect(drive(m, rig, (_) => SimPose(lean: .7), 2), isEmpty);
    });
  });

  group('Vỗ tay theo nhịp', () {
    test('vỗ đủ số lần thì đúng', () {
      final rig = Rig();
      final m = CountMechanic(target: 3, kind: RepKind.clap);
      SimPose clap(double t) =>
          (t % .5) < .25 && t < 1.5 ? SimPose(leftArm: 140, rightArm: 220) : SimPose(leftArm: 240, rightArm: 120);

      final out = drive(m, rig, clap, 3.5);
      expect(out, [const ReportResult(true)]);
    });
  });
}

final sim4 = PoseSimulator();
