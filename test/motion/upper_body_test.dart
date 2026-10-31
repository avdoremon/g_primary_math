import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/motion/body_metrics.dart';
import 'package:g_primary_math/motion/motion_engine.dart';
import 'package:g_primary_math/motion/sim/pose_simulator.dart';
import 'package:g_primary_math/pose/landmarks.dart';
import 'package:g_primary_math/pose/pose_frame.dart';

const _lowerBody = {
  PoseIdx.leftHip,
  PoseIdx.rightHip,
  PoseIdx.leftKnee,
  PoseIdx.rightKnee,
  PoseIdx.leftAnkle,
  PoseIdx.rightAnkle,
};

void main() {
  final sim = PoseSimulator();

  test('thấy đủ hông thì dùng hông thật', () {
    final b = BodySnapshot.of(sim.frame(SimPose(), Duration.zero))!;
    expect(b.hipsEstimated, isFalse);
  });

  test('chỉ thấy nửa người trên: vẫn có số đo, hông ước lượng ngay dưới vai', () {
    final real = BodySnapshot.of(sim.frame(SimPose(), Duration.zero))!;
    final b = BodySnapshot.of(sim.frame(SimPose(hidden: _lowerBody), Duration.zero))!;
    expect(b.hipsEstimated, isTrue);
    expect(b.hipCenter.dx, closeTo(real.hipCenter.dx, 1));
    expect(b.hipCenter.dy, closeTo(real.hipCenter.dy, real.torsoLength * 0.1));
    expect(b.torsoLength, closeTo(real.torsoLength, real.torsoLength * 0.1));
  });

  test('hông nằm ngang vai (điểm đoán ngoài khung) cũng coi là không thấy hông', () {
    final f = sim.frame(SimPose(), Duration.zero);
    final lm = [...f.landmarks!];
    for (final i in [PoseIdx.leftHip, PoseIdx.rightHip]) {
      lm[i] = PoseLandmark(lm[i].x, lm[PoseIdx.leftShoulder].y, 0, 0.9);
    }
    final b = BodySnapshot.of(f.withLandmarks(lm))!;
    expect(b.hipsEstimated, isTrue);
  });

  test('không thấy vai thì không có số đo', () {
    final f = sim.frame(SimPose(hidden: {PoseIdx.leftShoulder}), Duration.zero);
    expect(BodySnapshot.of(f), isNull);
  });

  test('camera chỉ thấy nửa người trên: vẫn hiệu chỉnh được và không bị coi là mất hình', () {
    final engine = MotionEngine();
    for (final f in sim.sequence(seconds: 1.6, pose: (_) => SimPose(leftArm: 0, rightArm: 0, hidden: _lowerBody))) {
      engine.process(f);
    }
    expect(engine.calibration, isNotNull);
    expect(engine.tracking, TrackingState.tracking);
  });

  test('bé ra khỏi khung hình rồi quay lại: game thấy lại ngay và hết báo mất hình', () {
    final engine = MotionEngine();
    var t = Duration.zero;
    MotionFrame step(SimPose p) {
      t += const Duration(milliseconds: 33);
      return engine.process(sim.frame(p, t));
    }

    for (var i = 0; i < 50; i++) {
      step(SimPose(leftArm: 0, rightArm: 0));
    }
    expect(engine.calibration, isNotNull);
    for (var i = 0; i < 100; i++) {
      step(SimPose(visible: false));
    }
    expect(engine.tracking, TrackingState.lost);
    late MotionFrame back;
    for (var i = 0; i < 3; i++) {
      back = step(SimPose());
    }
    expect(back.body, isNotNull);
    expect(engine.tracking, TrackingState.tracking);
  });

  test('vài khớp mất lâu rồi thấy lại cũng không lỗi', () {
    final engine = MotionEngine();
    var t = Duration.zero;
    for (var i = 0; i < 60; i++) {
      t += const Duration(milliseconds: 33);
      final hidden = i >= 10 && i < 40 ? {PoseIdx.leftWrist, PoseIdx.rightWrist} : <int>{};
      expect(() => engine.process(sim.frame(SimPose(hidden: hidden), t)), returnsNormally);
    }
  });
}
