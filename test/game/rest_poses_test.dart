import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/game/rest_poses.dart';
import 'package:g_primary_math/motion/body_metrics.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';

import 'mechanics_test.dart' show Rig;

final _sim = PoseSimulator();

BodySnapshot bodyOf(Rig rig, SimPose p) {
  rig.clock += const Duration(milliseconds: 40);
  final b = BodySnapshot.of(_sim.frame(p, rig.clock));
  expect(b, isNotNull);
  return b!;
}

void main() {
  test('mỗi tư thế nhận ra chính tư thế mẫu của nó và không nhận nhầm tư thế khác', () {
    final rig = Rig();
    final cal = rig.engine.calibration;
    for (final a in RestPose.all) {
      final b = bodyOf(rig, a.sample);
      for (final other in RestPose.all) {
        expect(other.matches(b, cal), other.id == a.id, reason: 'mẫu ${a.id} so với ${other.id}');
      }
    }
  });

  test('đứng thẳng buông tay thì không tư thế nào khớp', () {
    final rig = Rig();
    final b = bodyOf(rig, SimPose());
    for (final p in RestPose.all) {
      expect(p.matches(b, rig.engine.calibration), isFalse, reason: p.id);
    }
  });

  test('chọn các tư thế khác nhau', () {
    final picked = RestPose.pick(math.Random(3), count: 4);
    expect(picked.map((p) => p.id).toSet().length, 4);
  });

  group('Lượt tập', () {
    RestPoseSession newSession() => RestPoseSession([RestPose.all[0], RestPose.all[1]], holdSeconds: 1, timeoutSeconds: 5, pauseSeconds: 1);

    test('giữ đúng đủ lâu thì được sao rồi sang tư thế kế', () {
      final rig = Rig();
      final s = newSession();
      final b = bodyOf(rig, s.current!.sample);
      var changed = false;
      for (var i = 0; i < 80; i++) {
        changed |= s.update(1 / 30, b, rig.engine.calibration);
      }
      expect(s.stars, 1);
      expect(changed, isTrue);
      expect(s.index, 1);
    });

    test('đúng chưa đủ lâu rồi sai thì phải giữ lại từ đầu', () {
      final rig = Rig();
      final s = newSession();
      final good = bodyOf(rig, s.current!.sample);
      final bad = bodyOf(rig, SimPose());
      for (var i = 0; i < 20; i++) {
        s.update(1 / 30, good, rig.engine.calibration);
      }
      expect(s.holdProgress, greaterThan(0));
      s.update(1 / 30, bad, rig.engine.calibration);
      expect(s.holdProgress, 0);
      expect(s.stars, 0);
    });

    test('không làm được thì hết giờ sang tư thế kế, không có sao và không phạt', () {
      final rig = Rig();
      final s = newSession();
      final bad = bodyOf(rig, SimPose());
      for (var i = 0; i < 30 * 8; i++) {
        s.update(1 / 30, bad, rig.engine.calibration);
      }
      expect(s.index, 1);
      expect(s.stars, 0);
    });

    test('xong hết các tư thế thì kết thúc', () {
      final rig = Rig();
      final s = newSession();
      for (var i = 0; i < 30 * 20; i++) {
        final cur = s.current;
        s.update(1 / 30, cur == null ? null : bodyOf(rig, cur.sample), rig.engine.calibration);
      }
      expect(s.finished, isTrue);
      expect(s.stars, 2);
      expect(s.current, isNull);
    });

    test('không thấy bé thì không tính', () {
      final s = newSession();
      for (var i = 0; i < 60; i++) {
        s.update(1 / 30, null, null);
      }
      expect(s.stars, 0);
    });
  });
}
