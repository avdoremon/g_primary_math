import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/motion/body_metrics.dart';
import 'package:g_primary_math/motion/calibration.dart';
import 'package:g_primary_math/motion/detectors/arm_pose.dart';
import 'package:g_primary_math/motion/detectors/rep_counter.dart';
import 'package:g_primary_math/motion/detectors/step_detector.dart';
import 'package:g_primary_math/motion/motion_engine.dart';
import 'package:g_primary_math/motion/sim/pose_recording.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';
import 'package:g_primary_math/pose/landmarks.dart';

final sim = PoseSimulator();

/// Hiệu chỉnh: giơ hai tay 1,5 giây ở giữa khung.
MotionEngine calibratedEngine() {
  final engine = MotionEngine();
  for (final f in sim.sequence(seconds: 1.5, pose: (_) => SimPose(leftArm: 0, rightArm: 0))) {
    engine.process(f);
  }
  expect(engine.calibration, isNotNull, reason: 'phải hiệu chỉnh xong sau 1,5 giây giơ hai tay');
  return engine;
}

void main() {
  group('Hiệu chỉnh', () {
    test('giơ hai tay đủ 1 giây thì có số đo chuẩn', () {
      final engine = MotionEngine();
      Calibration? got;
      var lastProgress = 0.0;
      for (final f in sim.sequence(seconds: 1.5, pose: (_) => SimPose(leftArm: 0, rightArm: 0))) {
        final m = engine.process(f);
        got ??= m.justCalibrated;
        if (got == null) lastProgress = m.calibrationProgress;
      }
      expect(got, isNotNull);
      expect(lastProgress, greaterThan(0.8));
      expect(got!.shoulderWidth, greaterThan(0));
      expect(got.hipCenter.dx, closeTo(320, 5));
    });

    test('hạ tay giữa chừng thì tính lại từ đầu', () {
      final engine = MotionEngine();
      for (final f in sim.sequence(
        seconds: 1.5,
        pose: (t) => t < 0.7 ? SimPose(leftArm: 0, rightArm: 0) : SimPose(),
      )) {
        engine.process(f);
      }
      expect(engine.calibration, isNull);
    });
  });

  group('Cơ chế B – bước trái/phải', () {
    test('bước sang trái rồi sang phải', () {
      final engine = calibratedEngine();
      final step = StepDetector();
      final events = <StepSide>[];
      for (final f in sim.sequence(
        seconds: 3,
        start: const Duration(seconds: 2),
        pose: (t) => SimPose(centerX: t < 1 ? 0.30 : (t < 2 ? 0.5 : 0.70)),
      )) {
        final m = engine.process(f);
        final e = step.update(m.body, engine.calibration!);
        if (e != null) events.add(e);
      }
      expect(events, [StepSide.left, StepSide.center, StepSide.right]);
    });

    test('lắc nhẹ tại chỗ không tính là bước', () {
      final engine = calibratedEngine();
      final step = StepDetector();
      final events = <StepSide>[];
      for (final f in sim.sequence(
        seconds: 2,
        start: const Duration(seconds: 2),
        pose: (t) => SimPose(centerX: 0.5 + 0.04 * (t * 10 % 2 < 1 ? 1 : -1)),
      )) {
        final e = step.update(engine.process(f).body, engine.calibration!);
        if (e != null) events.add(e);
      }
      expect(events, isEmpty);
    });
  });

  group('Cơ chế Đ – đếm động tác', () {
    int countReps(RepKind kind, SimPose Function(double t) pose, double seconds) {
      final engine = calibratedEngine();
      final counter = RepCounter(kind);
      for (final f in sim.sequence(seconds: seconds, start: const Duration(seconds: 2), pose: pose)) {
        counter.update(engine.process(f).body, engine.calibration!);
      }
      return counter.count;
    }

    test('nhảy 3 lần đếm đúng 3', () {
      // Mỗi lần nhảy 0,6 giây: 0,3 giây trên không, 0,3 giây chạm đất.
      final n = countReps(RepKind.jump, (t) => SimPose(jump: (t % 0.6) < 0.3 && t < 1.8 ? 0.35 : 0), 2.4);
      expect(n, 3);
    });

    test('ngồi xổm 2 lần đếm đúng 2', () {
      final n = countReps(RepKind.squat, (t) => SimPose(squat: (t % 1.2) < 0.6 && t < 2.4 ? 1.0 : 0), 3.0);
      expect(n, 2);
    });

    test('vỗ tay 4 lần đếm đúng 4', () {
      final n = countReps(
        RepKind.clap,
        (t) => (t % 0.5) < 0.25 && t < 2.0 ? SimPose(leftArm: 140, rightArm: 220) : SimPose(leftArm: 240, rightArm: 120),
        2.5,
      );
      expect(n, 4);
    });

    test('đứng yên không đếm', () {
      expect(countReps(RepKind.jump, (_) => SimPose(), 2), 0);
      expect(countReps(RepKind.squat, (_) => SimPose(), 2), 0);
    });
  });

  group('Cơ chế T – tạo dáng tay', () {
    test('giơ tay phải giữ 0,6 giây thì khớp đúng một lần', () {
      final engine = calibratedEngine();
      final m = ArmPoseMatcher(left: ArmTarget.down, right: ArmTarget.up);
      var fired = 0;
      for (final f in sim.sequence(
        seconds: 2,
        start: const Duration(seconds: 2),
        pose: (_) => SimPose(rightArm: 10),
      )) {
        if (m.update(engine.process(f).body).matched) fired++;
      }
      expect(fired, 1);
    });

    test('giơ cả hai tay khi đề chỉ yêu cầu tay trái: tay phải bị nhắc', () {
      final engine = calibratedEngine();
      final m = ArmPoseMatcher(left: ArmTarget.up, right: ArmTarget.down);
      ArmPoseResult? last;
      for (final f in sim.sequence(
        seconds: 1,
        start: const Duration(seconds: 2),
        pose: (_) => SimPose(leftArm: 0, rightArm: 0),
      )) {
        last = m.update(engine.process(f).body);
      }
      expect(last!.left, ArmStatus.ok);
      expect(last.right, ArmStatus.wrong);
      expect(last.matched, isFalse);
    });

    test('đồng hồ người đọc đúng 3 giờ', () {
      final engine = calibratedEngine();
      // 3:00 → kim giờ (tay trái) chỉ 90°, kim phút (tay phải) chỉ 0°.
      final matcher = HumanClock.matcherFor(3, 0);
      var matched = false;
      ({int hour, int minute})? reading;
      for (final f in sim.sequence(
        seconds: 1.5,
        start: const Duration(seconds: 2),
        pose: (_) => SimPose(leftArm: 90, rightArm: 0),
      )) {
        final body = engine.process(f).body;
        if (matcher.update(body).matched) matched = true;
        if (body != null) reading = HumanClock.read(body);
      }
      expect(matched, isTrue);
      expect(reading, (hour: 3, minute: 0));
    });

    test('góc kim theo giờ', () {
      expect(HumanClock.hourAngle(12, 0), 0);
      expect(HumanClock.hourAngle(6, 0), 180);
      expect(HumanClock.hourAngle(3, 30), 105);
      expect(HumanClock.minuteAngle(15), 90);
      expect(HumanClock.minuteAngle(30), 180);
    });
  });

  group('Theo dõi và ghi hình', () {
    test('mất hình hơn 2 giây thì chuyển sang tạm dừng', () {
      final engine = calibratedEngine();
      final states = <TrackingState>[];
      for (final f in sim.sequence(
        seconds: 3,
        start: const Duration(seconds: 2),
        pose: (_) => SimPose(visible: false),
      )) {
        states.add(engine.process(f).tracking);
      }
      expect(states.first, TrackingState.tracking);
      expect(states.last, TrackingState.lost);
    });

    test('thiếu chân thì báo thiếu chân', () {
      final engine = MotionEngine();
      final m = engine.process(
        sim.frame(SimPose(hidden: {PoseIdx.leftAnkle, PoseIdx.rightAnkle}), Duration.zero),
      );
      expect(m.coverage.head, isTrue);
      expect(m.coverage.hands, isTrue);
      expect(m.coverage.feet, isFalse);
      expect(m.coverage.whole, isFalse);
    });

    test('ghi rồi phát lại cho cùng kết quả đếm', () {
      final rec = PoseRecording();
      for (final f in sim.sequence(seconds: 1.5, pose: (_) => SimPose(leftArm: 0, rightArm: 0))) {
        rec.add(f);
      }
      for (final f in sim.sequence(
        seconds: 2.4,
        start: const Duration(seconds: 2),
        pose: (t) => SimPose(jump: (t % 0.6) < 0.3 && t < 1.8 ? 0.35 : 0),
      )) {
        rec.add(f);
      }
      final replay = PoseRecording.fromJsonLines(rec.toJsonLines());
      expect(replay.frames.length, rec.frames.length);

      final engine = MotionEngine();
      final counter = RepCounter(RepKind.jump);
      for (final f in replay.frames) {
        final m = engine.process(f);
        if (engine.calibration != null && m.justCalibrated == null) counter.update(m.body, engine.calibration!);
      }
      expect(counter.count, 3);
    });

    test('góc cánh tay: 0 lên, 90 phải, 180 xuống, 270 trái', () {
      final body = BodySnapshot.of(sim.frame(SimPose(leftArm: 270, rightArm: 90), Duration.zero))!;
      expect(body.armAngle(right: true), closeTo(90, 1));
      expect(body.armAngle(right: false), closeTo(270, 1));
      expect(BodySnapshot.angleDiff(350, 10), closeTo(20, 0.001));
    });
  });
}
