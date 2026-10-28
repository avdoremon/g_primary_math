import '../body_metrics.dart';

/// Yêu cầu cho một cánh tay.
class ArmTarget {
  const ArmTarget._(this._kind, [this.angle = 0]);

  /// Không quan tâm tay này.
  static const any = ArmTarget._(_ArmKind.any);

  /// Giơ lên (cổ tay cao hơn vai).
  static const up = ArmTarget._(_ArmKind.up);

  /// Hạ xuống (cổ tay thấp hơn vai).
  static const down = ArmTarget._(_ArmKind.down);

  /// Chỉ theo một hướng: [degrees] theo chiều kim đồng hồ, 0° = thẳng lên, 90° = sang phải màn hình.
  const ArmTarget.direction(double degrees) : this._(_ArmKind.direction, degrees);

  final _ArmKind _kind;
  final double angle;
}

enum _ArmKind { any, up, down, direction }

/// Trạng thái từng tay so với yêu cầu, để giao diện tô sáng tay đúng và nhắc tay sai
/// (ví dụ "Hạ tay này xuống").
enum ArmStatus { ok, wrong, unseen, ignored }

class ArmPoseResult {
  const ArmPoseResult(this.left, this.right, this.progress, this.matched);

  final ArmStatus left;
  final ArmStatus right;

  /// 0..1: tiến độ giữ tư thế đúng.
  final double progress;

  /// true đúng một lần khi giữ tư thế đủ lâu.
  final bool matched;
}

/// Cơ chế T – tạo dáng tay. Tư thế đúng phải giữ [holdSeconds] giây (design: 0,6 giây).
/// Tay trái/phải là tay thật của bé; vì đã lật gương nên tay phải nằm bên phải màn hình.
class ArmPoseMatcher {
  ArmPoseMatcher({
    required this.left,
    required this.right,
    this.holdSeconds = 0.6,
    this.toleranceDegrees = 15,
  });

  ArmTarget left;
  ArmTarget right;
  final double holdSeconds;
  final double toleranceDegrees;

  Duration? _since;
  bool _fired = false;

  void reset() {
    _since = null;
    _fired = false;
  }

  ArmPoseResult update(BodySnapshot? body) {
    if (body == null) {
      reset();
      return const ArmPoseResult(ArmStatus.unseen, ArmStatus.unseen, 0, false);
    }
    final l = _check(body, left, right: false);
    final r = _check(body, right, right: true);
    final allOk = (l == ArmStatus.ok || l == ArmStatus.ignored) && (r == ArmStatus.ok || r == ArmStatus.ignored);

    if (!allOk) {
      _since = null;
      _fired = false;
      return ArmPoseResult(l, r, 0, false);
    }
    _since ??= body.time;
    final held = (body.time - _since!).inMicroseconds / 1e6;
    final progress = (held / holdSeconds).clamp(0.0, 1.0).toDouble();
    final fire = !_fired && held >= holdSeconds;
    if (fire) _fired = true;
    return ArmPoseResult(l, r, progress, fire);
  }

  ArmStatus _check(BodySnapshot body, ArmTarget t, {required bool right}) {
    if (t._kind == _ArmKind.any) return ArmStatus.ignored;
    final angle = body.armAngle(right: right);
    if (angle == null) return ArmStatus.unseen;
    final ok = switch (t._kind) {
      _ArmKind.up => body.armRaised(right: right),
      _ArmKind.down => body.armDown(right: right),
      _ArmKind.direction => BodySnapshot.angleDiff(angle, t.angle) <= toleranceDegrees,
      _ArmKind.any => true,
    };
    return ok ? ArmStatus.ok : ArmStatus.wrong;
  }
}

/// "Đồng hồ người": tay trái là kim giờ (ngắn), tay phải là kim phút (dài).
abstract class HumanClock {
  /// Góc kim giờ cho [hour]:[minute] (lớp 1: giờ đúng; lớp 2: kim phút chỉ số 3, số 6).
  static double hourAngle(int hour, int minute) => ((hour % 12) * 30 + minute * 0.5) % 360;
  static double minuteAngle(int minute) => (minute % 60) * 6.0;

  /// Bộ so khớp cho giờ cần chỉ. Sai lệch cho phép mặc định ±15°, đủ phân biệt từng số trên mặt đồng hồ.
  static ArmPoseMatcher matcherFor(int hour, int minute, {double tolerance = 15, double holdSeconds = 1.0}) =>
      ArmPoseMatcher(
        left: ArmTarget.direction(hourAngle(hour, minute)),
        right: ArmTarget.direction(minuteAngle(minute)),
        toleranceDegrees: tolerance,
        holdSeconds: holdSeconds,
      );

  /// Đọc giờ đang chỉ (để vẽ kim ảo bám theo tay). null nếu không thấy đủ hai tay.
  static ({int hour, int minute})? read(BodySnapshot body) {
    final h = body.armAngle(right: false);
    final m = body.armAngle(right: true);
    if (h == null || m == null) return null;
    var hour = (h / 30).round() % 12;
    if (hour == 0) hour = 12;
    final minute = ((m / 6).round() % 60);
    return (hour: hour, minute: minute);
  }
}
