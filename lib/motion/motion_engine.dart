import '../pose/pose_frame.dart';
import 'body_metrics.dart';
import 'calibration.dart';
import 'landmark_smoother.dart';

/// Trạng thái theo dõi bé.
enum TrackingState {
  /// Chưa thấy người lần nào kể từ khi bắt đầu.
  searching,

  /// Đang thấy người.
  tracking,

  /// Mất hình quá [MotionEngine.lostAfter]: game phải tạm dừng.
  lost,
}

/// Kết quả xử lý một khung hình.
class MotionFrame {
  const MotionFrame({
    required this.raw,
    required this.smoothed,
    required this.body,
    required this.tracking,
    required this.coverage,
    required this.calibrationProgress,
    this.justCalibrated,
  });

  final PoseFrame raw;
  final PoseFrame smoothed;

  /// null khi không thấy đủ vai và hông.
  final BodySnapshot? body;
  final TrackingState tracking;
  final BodyCoverage coverage;

  /// 0..1 khi đang giữ tư thế hiệu chỉnh (giơ hai tay).
  final double calibrationProgress;

  /// Có giá trị đúng ở khung vừa hiệu chỉnh xong.
  final Calibration? justCalibrated;
}

/// Lõi xử lý chuyển động, dùng chung cho mọi mini game:
/// làm mượt khung xương → tính số đo cơ thể → hiệu chỉnh → theo dõi mất hình.
/// Các cơ chế (StepDetector, RepCounter, ArmPoseMatcher, DwellSelector) nhận
/// [MotionFrame.body] và [calibration] từ đây.
class MotionEngine {
  MotionEngine({
    LandmarkSmoother? smoother,
    Calibrator? calibrator,
    this.lostAfter = const Duration(seconds: 2),
  })  : smoother = smoother ?? LandmarkSmoother(),
        calibrator = calibrator ?? Calibrator();

  final LandmarkSmoother smoother;
  final Calibrator calibrator;

  /// Mất hình lâu hơn mức này thì tạm dừng (design system: hơn 2 giây).
  final Duration lostAfter;

  Calibration? calibration;
  TrackingState tracking = TrackingState.searching;
  Duration? _lastSeen;

  /// Khi true, bước hiệu chỉnh chạy lại ở khung tiếp theo bé giơ hai tay.
  bool wantsCalibration = true;

  void reset() {
    smoother.reset();
    calibrator.reset();
    calibration = null;
    tracking = TrackingState.searching;
    _lastSeen = null;
    wantsCalibration = true;
  }

  void requestCalibration() {
    calibrator.reset();
    wantsCalibration = true;
  }

  MotionFrame process(PoseFrame frame) {
    final smoothed = smoother.smooth(frame);
    final body = BodySnapshot.of(smoothed);

    if (body != null) {
      _lastSeen = frame.arrival;
      tracking = TrackingState.tracking;
    } else if (_lastSeen != null && frame.arrival - _lastSeen! > lostAfter) {
      tracking = TrackingState.lost;
    }

    Calibration? fresh;
    if (wantsCalibration) {
      fresh = calibrator.update(body);
      if (fresh != null) {
        calibration = fresh;
        wantsCalibration = false;
      }
    }

    return MotionFrame(
      raw: frame,
      smoothed: smoothed,
      body: body,
      tracking: tracking,
      coverage: body?.coverage ?? BodyCoverage.none,
      calibrationProgress: wantsCalibration ? calibrator.progress : 1,
      justCalibrated: fresh,
    );
  }
}
