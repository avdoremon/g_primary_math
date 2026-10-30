import 'dart:math' as math;

import '../motion/body_metrics.dart';
import '../motion/calibration.dart';
import '../motion/sim/pose_simulator.dart';

/// Một tư thế thể dục nhẹ lúc giải lao. Tay và thân dùng đúng quy ước của game:
/// trái / phải là bên trái / phải MÀN HÌNH (bé nhìn mình như trong gương).
class RestPose {
  const RestPose({
    required this.id,
    required this.name,
    required this.speech,
    required this.sample,
    required this.matches,
  });

  final String id;

  /// Tên ngắn hiện trên TV.
  final String name;

  /// Lời Tin Tin đọc.
  final String speech;

  /// Tư thế mẫu để vẽ bóng người làm mẫu.
  final SimPose sample;

  /// Bé đã tạo dáng giống chưa. [cal] có thể null (chưa hiệu chỉnh) khi tư thế không cần.
  final bool Function(BodySnapshot body, Calibration? cal) matches;

  static bool _arm(BodySnapshot b, {required bool right, required double angle, double tolerance = 40}) {
    final a = b.armAngle(right: right);
    return a != null && BodySnapshot.angleDiff(a, angle) <= tolerance;
  }

  static final all = <RestPose>[
    RestPose(
      id: 'hands_up',
      name: 'Giơ hai tay lên cao',
      speech: 'Con giơ hai tay lên cao nào!',
      sample: SimPose(leftArm: 0, rightArm: 0),
      matches: (b, _) => _arm(b, right: false, angle: 0) && _arm(b, right: true, angle: 0),
    ),
    RestPose(
      id: 'wings',
      name: 'Dang hai tay như cánh chim',
      speech: 'Con dang rộng hai tay như cánh chim nào!',
      sample: SimPose(leftArm: 270, rightArm: 90),
      matches: (b, _) => _arm(b, right: false, angle: 270) && _arm(b, right: true, angle: 90),
    ),
    RestPose(
      id: 'letter_v',
      name: 'Hai tay thành chữ V',
      speech: 'Con giơ hai tay chéo lên thành chữ V nào!',
      sample: SimPose(leftArm: 315, rightArm: 45),
      matches: (b, _) => _arm(b, right: false, angle: 315, tolerance: 30) && _arm(b, right: true, angle: 45, tolerance: 30),
    ),
    RestPose(
      id: 'left_up',
      name: 'Tay trái lên, tay phải xuống',
      speech: 'Con giơ tay trái lên, tay phải thả xuống nhé!',
      sample: SimPose(leftArm: 0, rightArm: 180),
      matches: (b, _) => _arm(b, right: false, angle: 0) && _arm(b, right: true, angle: 180, tolerance: 45),
    ),
    RestPose(
      id: 'right_up',
      name: 'Tay phải lên, tay trái xuống',
      speech: 'Con giơ tay phải lên, tay trái thả xuống nhé!',
      sample: SimPose(leftArm: 180, rightArm: 0),
      matches: (b, _) => _arm(b, right: true, angle: 0) && _arm(b, right: false, angle: 180, tolerance: 45),
    ),
    RestPose(
      id: 'lean_left',
      name: 'Nghiêng người sang trái',
      speech: 'Con nghiêng người sang bên trái nào!',
      sample: SimPose(lean: -0.7),
      matches: (b, _) => b.leanOffset <= -0.35,
    ),
    RestPose(
      id: 'lean_right',
      name: 'Nghiêng người sang phải',
      speech: 'Con nghiêng người sang bên phải nào!',
      sample: SimPose(lean: 0.7),
      matches: (b, _) => b.leanOffset >= 0.35,
    ),
    RestPose(
      id: 'squat',
      name: 'Ngồi xuống nhẹ nhàng',
      speech: 'Con ngồi xuống thật nhẹ nhàng nào!',
      sample: SimPose(squat: 1),
      matches: (b, cal) =>
          cal != null && cal.torsoLength > 0 && (cal.hipCenter.dy - b.hipCenter.dy) / cal.torsoLength <= -0.3,
    ),
  ];

  /// Chọn ngẫu nhiên [count] tư thế khác nhau.
  static List<RestPose> pick(math.Random r, {int count = 4}) {
    final pool = [...all]..shuffle(r);
    final out = <RestPose>[];
    for (final p in pool) {
      if (out.length >= count) break;
      out.add(p);
    }
    return out;
  }
}

/// Chạy bài thể dục giải lao: lần lượt từng tư thế, giữ đúng [holdSeconds] giây thì được sao,
/// quá [timeoutSeconds] giây chưa giống thì sang tư thế kế (không trừ gì cả).
class RestPoseSession {
  RestPoseSession(this.poses, {this.holdSeconds = 1.0, this.timeoutSeconds = 12, this.pauseSeconds = 1.6});

  final List<RestPose> poses;
  final double holdSeconds;
  final double timeoutSeconds;

  /// Dừng ngắn sau mỗi tư thế để khen trước khi sang tư thế mới.
  final double pauseSeconds;

  int index = 0;
  int stars = 0;

  /// Tư thế vừa rồi được sao hay không (để hiện khen), null khi đang chơi tư thế hiện tại.
  bool? lastMatched;

  double _held = 0;
  double _elapsed = 0;
  double _pause = 0;

  bool get finished => index >= poses.length;
  RestPose? get current => finished ? null : poses[index];

  /// Đang giữ đúng tư thế: 0..1.
  double get holdProgress => (_held / holdSeconds).clamp(0.0, 1.0).toDouble();

  /// Đang dừng khen giữa hai tư thế.
  bool get pausing => _pause > 0;

  /// Số giây còn lại cho tư thế hiện tại.
  double get timeLeft => math.max(0.0, timeoutSeconds - _elapsed);

  /// Trả về true ở khung vừa chuyển sang tư thế mới (để đọc lời hướng dẫn).
  bool update(double dt, BodySnapshot? body, Calibration? cal) {
    if (finished) return false;
    if (_pause > 0) {
      _pause -= dt;
      if (_pause <= 0) {
        _pause = 0;
        lastMatched = null;
        index++;
        _held = 0;
        _elapsed = 0;
        return !finished;
      }
      return false;
    }
    _elapsed += dt;
    final ok = body != null && current!.matches(body, cal);
    _held = ok ? _held + dt : 0;
    if (_held >= holdSeconds) {
      stars++;
      lastMatched = true;
      _pause = pauseSeconds;
    } else if (_elapsed >= timeoutSeconds) {
      lastMatched = false;
      _pause = pauseSeconds;
    }
    return false;
  }
}
