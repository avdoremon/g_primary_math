import 'dart:ui';

import '../content/curriculum.dart';
import '../content/question.dart';
import '../motion/body_metrics.dart';
import '../motion/calibration.dart';
import '../motion/detectors/arm_pose.dart';
import '../motion/detectors/rep_counter.dart';
import '../motion/detectors/step_detector.dart';
import '../motion/dwell_selector.dart';

/// Cách bé trả lời một câu hỏi (khớp các cơ chế trong design system).
enum MechanicKind {
  /// C – giữ tay lên ô đáp án.
  touch,

  /// B – bước sang trái/phải (2 đáp án). Mini game "Bên nào lớn hơn" vẫn cho chạm tay.
  step,

  /// Đ – nhảy đủ số lần.
  count,

  /// T – giơ tay trái / tay phải / hai tay (Con nói, con làm).
  armChoice,

  /// T – hai tay làm kim đồng hồ.
  clock,

  /// T + B – lệnh ghép: giơ tay và bước sang một bên.
  compound,
}

/// Dữ liệu đầu vào mỗi khung hình.
class MechanicInput {
  const MechanicInput({
    required this.dt,
    this.body,
    this.calibration,
    this.hands = const [],
    this.targets = const [],
  });

  /// Giây đã trôi từ khung trước.
  final double dt;
  final BodySnapshot? body;
  final Calibration? calibration;

  /// Vị trí hai bàn tay trên màn hình, chuẩn hoá 0..1.
  final List<Offset?> hands;

  /// Vùng các ô đáp án trên màn hình, chuẩn hoá 0..1, theo thứ tự đáp án.
  final List<Rect> targets;
}

/// Kết quả cơ chế báo cho phiên chơi.
sealed class MechanicSignal {
  const MechanicSignal();
}

/// Bé chọn ô đáp án [option].
class ChooseOption extends MechanicSignal {
  const ChooseOption(this.option);

  final int option;

  @override
  bool operator ==(Object other) => other is ChooseOption && other.option == option;

  @override
  int get hashCode => option.hashCode;

  @override
  String toString() => 'ChooseOption($option)';
}

/// Mini game không có ô đáp án: bé làm đúng hay sai.
class ReportResult extends MechanicSignal {
  const ReportResult(this.correct);

  final bool correct;

  @override
  bool operator ==(Object other) => other is ReportResult && other.correct == correct;

  @override
  int get hashCode => correct.hashCode;

  @override
  String toString() => 'ReportResult($correct)';
}

abstract class AnswerMechanic {
  MechanicKind get kind;

  /// Cần số đo chuẩn (bước chân, nhảy).
  bool get needsCalibration => false;

  /// Màn chơi vẽ con trỏ bàn tay và ô đáp án chạm được.
  bool get usesTouch => false;

  /// 0..1 – tiến độ (vòng nạp khi giữ tay / giữ tư thế).
  double get progress => 0;

  /// Lời nhắc ngắn cho bé (vd. "Về giữa trước nhé!"), null nếu không cần.
  String? get hint => null;

  /// Ô đáp án đang được nhắm (để phóng to / vẽ vòng nạp) và bàn tay đang nạp.
  int? get aimed => null;
  Offset? get activePoint => null;

  MechanicSignal? update(MechanicInput input);

  /// Chọn cơ chế theo mini game của level và dữ liệu câu hỏi.
  static AnswerMechanic forQuestion(Level level, Question q) {
    final type = q.data['type'];
    final jumps = q.data['jumps'];
    final hour = q.data['hour'];
    final minute = q.data['minute'];
    if (type == 'compound') {
      return CompoundMechanic(
        left: _armTarget(q.data['left']),
        right: _armTarget(q.data['right']),
        side: q.data['side'] == 'left' ? StepSide.left : StepSide.right,
      );
    }
    if (type == 'pose' && q.options.length == 3) return ArmChoiceMechanic();
    if (type == 'step' && q.options.length == 2) return StepMechanic();
    if (level.miniGame == MiniGames.jumpCount && jumps is int) return CountMechanic(target: jumps);
    if (level.miniGame == MiniGames.humanClock && hour is int && minute is int) {
      return ClockMechanic(hour: hour, minute: minute);
    }
    if (level.miniGame == MiniGames.sides && q.options.length == 2) return StepMechanic(alsoTouch: true);
    return TouchMechanic();
  }

  static ArmTarget _armTarget(Object? v) => switch (v) {
        'up' => ArmTarget.up,
        'down' => ArmTarget.down,
        _ => ArmTarget.any,
      };
}

// ------------------------------------------------------------------ C

class TouchMechanic extends AnswerMechanic {
  TouchMechanic({double dwellSeconds = 0.4}) : dwell = DwellSelector(dwellSeconds: dwellSeconds);

  final DwellSelector dwell;

  @override
  MechanicKind get kind => MechanicKind.touch;

  @override
  bool get usesTouch => true;

  @override
  double get progress => dwell.progress;

  @override
  int? get aimed => dwell.candidate;

  @override
  Offset? get activePoint => dwell.activePoint;

  @override
  MechanicSignal? update(MechanicInput input) {
    if (input.targets.isEmpty) return null;
    final hit = dwell.update(input.hands, input.targets, input.dt);
    return hit == null ? null : ChooseOption(hit);
  }
}

// ------------------------------------------------------------------ B

class StepMechanic extends AnswerMechanic {
  StepMechanic({this.alsoTouch = false, StepDetector? detector}) : detector = detector ?? StepDetector();

  final bool alsoTouch;
  final StepDetector detector;
  final DwellSelector _dwell = DwellSelector();

  /// Bé phải đứng giữa trước khi chọn (tránh tự chọn khi câu trước bé còn đứng lệch một bên).
  bool armed = false;
  bool _seen = false;

  @override
  MechanicKind get kind => MechanicKind.step;

  @override
  bool get needsCalibration => true;

  @override
  bool get usesTouch => alsoTouch;

  @override
  double get progress => _dwell.progress;

  @override
  int? get aimed => _dwell.candidate;

  @override
  Offset? get activePoint => _dwell.activePoint;

  @override
  String? get hint => armed || !_seen ? null : 'Con về giữa trước nhé!';

  @override
  MechanicSignal? update(MechanicInput input) {
    if (alsoTouch && input.targets.isNotEmpty) {
      final hit = _dwell.update(input.hands, input.targets, input.dt);
      if (hit != null) return ChooseOption(hit);
    }
    final cal = input.calibration;
    if (cal == null || input.body == null) return null;
    _seen = true;
    final event = detector.update(input.body, cal);
    if (!armed) {
      if (detector.offset.abs() < detector.centerThreshold) armed = true;
      return null;
    }
    if (event == StepSide.left) return const ChooseOption(0);
    if (event == StepSide.right) return const ChooseOption(1);
    return null;
  }
}

// ------------------------------------------------------------------ Đ

class CountMechanic extends AnswerMechanic {
  CountMechanic({required this.target, this.settleSeconds = 0.8, RepKind kind = RepKind.jump})
      : counter = RepCounter(kind);

  final int target;

  /// Đủ số lần rồi mà ngần này giây không nhảy thêm thì tính là đúng.
  final double settleSeconds;
  final RepCounter counter;
  double _settled = 0;

  int get count => counter.count;

  @override
  MechanicKind get kind => MechanicKind.count;

  @override
  bool get needsCalibration => true;

  @override
  double get progress => target <= 0 ? 1 : (count / target).clamp(0.0, 1.0).toDouble();

  @override
  MechanicSignal? update(MechanicInput input) {
    final cal = input.calibration;
    if (cal == null || _done) return null;
    if (counter.update(input.body, cal)) _settled = 0;
    if (count > target) return _finish(false);
    if (count == target) {
      _settled += input.dt;
      if (_settled >= settleSeconds) return _finish(true);
    }
    return null;
  }

  bool _done = false;

  MechanicSignal _finish(bool correct) {
    _done = true;
    return ReportResult(correct);
  }
}

// ------------------------------------------------------------------ T

/// Giơ tay trái → đáp án 0, tay phải → 1, hai tay → 2 (thứ tự ô của dạng bài "position/pose").
class ArmChoiceMechanic extends AnswerMechanic {
  ArmChoiceMechanic({this.holdSeconds = 0.6});

  final double holdSeconds;
  int? _pose;
  double _held = 0;

  @override
  MechanicKind get kind => MechanicKind.armChoice;

  @override
  double get progress => _pose == null ? 0 : (_held / holdSeconds).clamp(0.0, 1.0).toDouble();

  /// Tư thế đang thấy: 0 tay trái, 1 tay phải, 2 hai tay, null không rõ / chưa giơ.
  static int? poseOf(BodySnapshot body) {
    final lUp = body.armRaised(right: false), rUp = body.armRaised(right: true);
    final lDown = body.armDown(right: false), rDown = body.armDown(right: true);
    if (lUp && rUp) return 2;
    if (lUp && rDown) return 0;
    if (rUp && lDown) return 1;
    return null;
  }

  @override
  MechanicSignal? update(MechanicInput input) {
    final body = input.body;
    final pose = body == null ? null : poseOf(body);
    if (pose != _pose) {
      _pose = pose;
      _held = 0;
      return null;
    }
    if (pose == null) return null;
    _held += input.dt;
    if (_held >= holdSeconds) {
      _held = 0;
      _pose = null;
      return ChooseOption(pose);
    }
    return null;
  }
}

class ClockMechanic extends AnswerMechanic {
  ClockMechanic({required this.hour, required this.minute, double holdSeconds = 0.6})
      : matcher = HumanClock.matcherFor(hour, minute, holdSeconds: holdSeconds);

  final int hour;
  final int minute;
  final ArmPoseMatcher matcher;
  double _progress = 0;

  /// Giờ bé đang chỉ (để hiện "Con đang chỉ 4 giờ").
  ({int hour, int minute})? reading;

  @override
  MechanicKind get kind => MechanicKind.clock;

  @override
  double get progress => _progress;

  @override
  MechanicSignal? update(MechanicInput input) {
    final body = input.body;
    reading = body == null ? null : HumanClock.read(body);
    final r = matcher.update(body);
    _progress = r.progress;
    return r.matched ? const ReportResult(true) : null;
  }
}

class CompoundMechanic extends AnswerMechanic {
  CompoundMechanic({required ArmTarget left, required ArmTarget right, required this.side, this.holdSeconds = 0.6})
      : arms = ArmPoseMatcher(left: left, right: right, holdSeconds: 0.01),
        step = StepDetector();

  final StepSide side;
  final double holdSeconds;
  final ArmPoseMatcher arms;
  final StepDetector step;
  double _held = 0;
  bool _done = false;
  ArmPoseResult? lastArms;

  @override
  MechanicKind get kind => MechanicKind.compound;

  @override
  bool get needsCalibration => true;

  @override
  double get progress => (_held / holdSeconds).clamp(0.0, 1.0).toDouble();

  bool get armsOk =>
      lastArms != null &&
      (lastArms!.left == ArmStatus.ok || lastArms!.left == ArmStatus.ignored) &&
      (lastArms!.right == ArmStatus.ok || lastArms!.right == ArmStatus.ignored);

  bool get sideOk => step.side == side;

  @override
  String? get hint {
    if (lastArms == null) return null;
    if (!armsOk) return 'Giơ đúng tay trước nhé!';
    if (!sideOk) return 'Giữ tay và bước sang bên ${side == StepSide.left ? 'trái' : 'phải'}!';
    return null;
  }

  @override
  MechanicSignal? update(MechanicInput input) {
    final cal = input.calibration;
    if (cal == null || _done) return null;
    step.update(input.body, cal);
    lastArms = arms.update(input.body);
    if (armsOk && sideOk) {
      _held += input.dt;
      if (_held >= holdSeconds) {
        _done = true;
        return const ReportResult(true);
      }
    } else {
      _held = 0;
    }
    return null;
  }
}
