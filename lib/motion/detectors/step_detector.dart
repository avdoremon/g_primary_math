import '../body_metrics.dart';
import '../calibration.dart';

/// Vùng đứng theo chiều ngang màn hình (đã lật gương: trái màn hình = bên trái bé).
enum StepSide { left, center, right }

/// Cơ chế B – bước (hoặc nghiêng người) sang trái/phải.
///
/// - Bước: tâm hông lệch khỏi vị trí giữa đã hiệu chỉnh ≥ [stepThreshold] bề rộng vai.
/// - Nghiêng: tâm vai lệch so với tâm hông ≥ [leanThreshold] bề rộng vai (khi bật [allowLean]).
/// - Phải ở nguyên một phía [holdSeconds] giây mới tính (chống rung).
/// - Trễ biên: về giữa khi độ lệch < [centerThreshold], tránh nhảy qua lại sát ngưỡng.
class StepDetector {
  StepDetector({
    this.stepThreshold = 1.0,
    this.centerThreshold = 0.5,
    this.leanThreshold = 0.35,
    this.holdSeconds = 0.3,
    this.allowLean = false,
  });

  final double stepThreshold;
  final double centerThreshold;
  final double leanThreshold;
  final double holdSeconds;
  final bool allowLean;

  StepSide _raw = StepSide.center;
  Duration? _rawSince;

  /// Phía đã xác nhận (sau thời gian giữ).
  StepSide side = StepSide.center;

  /// Độ lệch hiện tại của tâm hông, theo bề rộng vai (âm = trái, dương = phải).
  double offset = 0;

  void reset() {
    _raw = StepSide.center;
    _rawSince = null;
    side = StepSide.center;
    offset = 0;
  }

  /// Trả về phía mới khi vừa đổi phía (đã giữ đủ lâu), ngược lại null.
  StepSide? update(BodySnapshot? body, Calibration cal) {
    if (body == null || cal.shoulderWidth <= 0) return null;
    offset = (body.hipCenter.dx - cal.hipCenter.dx) / cal.shoulderWidth;
    final lean = (body.shoulderCenter.dx - body.hipCenter.dx) / cal.shoulderWidth;

    StepSide raw;
    if (offset <= -stepThreshold || (allowLean && lean <= -leanThreshold)) {
      raw = StepSide.left;
    } else if (offset >= stepThreshold || (allowLean && lean >= leanThreshold)) {
      raw = StepSide.right;
    } else if (offset.abs() < centerThreshold && (!allowLean || lean.abs() < leanThreshold / 2)) {
      raw = StepSide.center;
    } else {
      raw = _raw; // vùng trễ biên: giữ nguyên
    }

    if (raw != _raw) {
      _raw = raw;
      _rawSince = body.time;
    }
    _rawSince ??= body.time;
    final held = (body.time - _rawSince!).inMicroseconds / 1e6;
    if (_raw != side && held >= holdSeconds) {
      side = _raw;
      return side;
    }
    return null;
  }
}
