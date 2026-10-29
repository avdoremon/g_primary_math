import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';

import 'mechanics_test.dart' show Rig, drive, level, question;

void main() {
  group('Góc tay', () {
    test('phân loại góc giữa hai tay', () {
      expect(ArmAngleMechanic.classify(40), 'acute');
      expect(ArmAngleMechanic.classify(95), 'right');
      expect(ArmAngleMechanic.classify(140), 'obtuse');
      expect(ArmAngleMechanic.classify(175), 'straight');
    });

    test('chọn cơ chế Góc tay khi level là arm_angle', () {
      final m = AnswerMechanic.forQuestion(level(MiniGames.armAngle), question(options: ['Góc vuông'], data: {'angle': 'right'}));
      expect(m, isA<ArmAngleMechanic>());
    });

    test('một tay lên, một tay ngang = góc vuông; giữ đủ lâu thì đúng', () {
      final rig = Rig();
      final m = ArmAngleMechanic(target: 'right');
      final out = drive(m, rig, (_) => SimPose(leftArm: 270, rightArm: 0), 1.5);
      expect(out, [const ReportResult(true)]);
    });

    test('dang ngang hai tay là góc bẹt, chưa phải góc vuông: nhắc khép tay', () {
      final rig = Rig();
      final m = ArmAngleMechanic(target: 'right');
      final out = drive(m, rig, (_) => SimPose(leftArm: 270, rightArm: 90), 1.5);
      expect(out, isEmpty);
      expect(m.current, 'straight');
      expect(m.hint, 'Khép hai tay lại một chút');
    });

    test('buông thõng hai tay không tính là góc nhọn', () {
      final rig = Rig();
      final m = ArmAngleMechanic(target: 'acute');
      final out = drive(m, rig, (_) => SimPose(leftArm: 190, rightArm: 170), 1.5);
      expect(out, isEmpty);
      expect(m.angle, isNull);
    });
  });

  group('Tia số', () {
    test('chia vị trí thành các ô', () {
      expect(ZoneMechanic.zoneOf(-1, 3), 0);
      expect(ZoneMechanic.zoneOf(0, 3), 1);
      expect(ZoneMechanic.zoneOf(.99, 3), 2);
      expect(ZoneMechanic.zoneOf(1, 4), 3);
    });

    test('đứng giữa không giơ tay thì không chọn; sang trái giơ tay thì chọn ô đầu', () {
      final rig = Rig();
      final m = ZoneMechanic(zones: 3);
      expect(drive(m, rig, (_) => SimPose(), 2), isEmpty);
      expect(m.zone, 1);
      final out = drive(m, rig, (_) => SimPose(centerX: .15, rightArm: 0), 2);
      expect(out, [const ChooseOption(0)]);
    });

    test('chọn cơ chế Tia số khi level là number_line', () {
      final m = AnswerMechanic.forQuestion(level(MiniGames.numberLine), question(options: ['1', '2', '3']));
      expect(m, isA<ZoneMechanic>());
    });
  });
}
