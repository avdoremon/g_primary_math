import 'dart:ui';

import '../content/curriculum.dart';
import '../content/question.dart';
import '../motion/body_metrics.dart';
import '../motion/calibration.dart';
import '../motion/detectors/arm_pose.dart';
import '../motion/detectors/knee_lift.dart';
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

  /// T – hai tay tạo thành góc (Góc tay).
  armAngle,

  /// B – đứng vào ô trên tia số rồi giơ tay (Tia số), nhảy (Nhảy ô) hoặc chờ sao rơi (Hứng sao).
  zone,

  /// C – chạm lần lượt nhiều ô theo thứ tự (Chạm theo thứ tự).
  orderTouch,

  /// Đ + B – chạy tại chỗ tới ngã ba rồi nghiêng người chọn đường (Chạy đua).
  run,

  /// Đ – ngồi xuống hoặc nhảy lên để chọn cổng thấp / cao (Cổng nhảy ngồi).
  gate,
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
    if (type == 'pose' && q.options.length == 3) return ArmChoiceMechanic(expected: q.answer);
    const viaOwnMechanic = {MiniGames.balance, MiniGames.runRace, MiniGames.squatGate};
    if (type == 'step' && q.options.length == 2 && !viaOwnMechanic.contains(level.miniGame)) return StepMechanic();
    if (level.miniGame == MiniGames.jumpCount && jumps is int) return CountMechanic(target: jumps);
    if (level.miniGame == MiniGames.humanClock && hour is int && minute is int) {
      return ClockMechanic(hour: hour, minute: minute);
    }
    if (level.miniGame == MiniGames.sides && q.options.length == 2) return StepMechanic(alsoTouch: true);
    final angle = q.data['angle'];
    if (level.miniGame == MiniGames.armAngle && angle is String) return ArmAngleMechanic(target: angle);
    if (level.miniGame == MiniGames.numberLine && q.options.length >= 2) return ZoneMechanic(zones: q.options.length);
    final n = q.options.length;
    switch (level.miniGame) {
      case MiniGames.hopTiles when n >= 2:
        return ZoneMechanic(zones: n, confirm: ZoneConfirm.jump);
      case MiniGames.starCatch when n >= 2:
        return ZoneMechanic(zones: n, confirm: ZoneConfirm.landing, fallSeconds: starFallSeconds(level));
      case MiniGames.touchOrder when q.data['sequence'] is List:
        return OrderTouchMechanic(sequence: (q.data['sequence']! as List).cast<int>());
      case MiniGames.tintinSays when n == 3:
        return ArmChoiceMechanic(expected: q.answer);
      case MiniGames.balance when n == 2:
        return StepMechanic(alsoTouch: true, detector: StepDetector(allowLean: true, holdSeconds: 0.4));
      case MiniGames.runRace when n == 2:
        return RunChooseMechanic();
      case MiniGames.clapCount when jumps is int:
        return CountMechanic(target: jumps as int, kind: RepKind.clap);
      case MiniGames.squatGate when n == 2:
        return GateMechanic();
    }
    return TouchMechanic();
  }

  /// Sao rơi hết trong bao lâu: 60% thời gian của câu, từ 3,5 đến 9 giây (không giới hạn giờ: 7 giây).
  static double starFallSeconds(Level level) =>
      level.secondsPerQuestion <= 0 ? 7 : (level.secondsPerQuestion * 0.6).clamp(3.5, 9.0).toDouble();

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

  /// Giây kể từ lần nhảy gần nhất (để linh vật nhảy theo).
  double sinceRep = 99;

  @override
  MechanicKind get kind => MechanicKind.count;

  @override
  bool get needsCalibration => true;

  @override
  double get progress => target <= 0 ? 1 : (count / target).clamp(0.0, 1.0).toDouble();

  @override
  MechanicSignal? update(MechanicInput input) {
    final cal = input.calibration;
    sinceRep += input.dt;
    if (cal == null || _done) return null;
    if (counter.update(input.body, cal)) {
      _settled = 0;
      sinceRep = 0;
    }
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

/// Lệnh tạo dáng của "Con nói, con làm": giơ tay trái → đáp án 0, tay phải → 1, hai tay → 2.
///
/// Theo design G7-2b: làm đúng tư thế và giữ [holdSeconds] giây thì tính đúng. Làm sai thì KHÔNG tính sai ngay:
/// tay thừa/thiếu được nhắc ("Hạ tay này xuống" / "Giơ tay này lên"), cho [graceSeconds] giây để sửa;
/// hết thời gian sửa mà vẫn sai mới tính là chọn tư thế đó.
class ArmChoiceMechanic extends AnswerMechanic {
  ArmChoiceMechanic({required this.expected, this.holdSeconds = 0.6, this.graceSeconds = 3});

  final int expected;
  final double holdSeconds;
  final double graceSeconds;

  int? _pose;
  double _held = 0;
  double _wrongHeld = 0;
  bool _done = false;

  /// Tay bé đang giơ (theo tay thật, đã lật gương nên trái = bên trái màn hình).
  bool leftUp = false;
  bool rightUp = false;

  /// Tay cần sửa: true = tay phải, false = tay trái, null = không có.
  bool? fixArm;

  /// Tay cần sửa đang giơ thừa (phải hạ xuống) hay đang thiếu (phải giơ lên).
  bool fixLower = true;

  bool get wantLeft => expected == 0 || expected == 2;
  bool get wantRight => expected == 1 || expected == 2;

  @override
  MechanicKind get kind => MechanicKind.armChoice;

  @override
  double get progress => _pose == expected ? (_held / holdSeconds).clamp(0.0, 1.0).toDouble() : 0;

  @override
  String? get hint => fixArm == null ? null : (fixLower ? 'Hạ tay này xuống' : 'Giơ tay này lên');

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
    if (_done) return null;
    final body = input.body;
    leftUp = body?.armRaised(right: false) ?? false;
    rightUp = body?.armRaised(right: true) ?? false;
    final pose = body == null ? null : poseOf(body);

    // Nhắc tay cần sửa khi bé đã giơ ít nhất một tay.
    fixArm = null;
    if (leftUp || rightUp) {
      if (leftUp && !wantLeft) {
        fixArm = false;
        fixLower = true;
      } else if (rightUp && !wantRight) {
        fixArm = true;
        fixLower = true;
      } else if (!leftUp && wantLeft) {
        fixArm = false;
        fixLower = false;
      } else if (!rightUp && wantRight) {
        fixArm = true;
        fixLower = false;
      }
    }

    if (pose != _pose) {
      _pose = pose;
      _held = 0;
    }
    if (pose == null) {
      _wrongHeld = 0;
      return null;
    }
    if (pose == expected) {
      _wrongHeld = 0;
      _held += input.dt;
      if (_held >= holdSeconds) return _finish(pose);
      return null;
    }
    _wrongHeld += input.dt;
    if (_wrongHeld >= graceSeconds) return _finish(pose);
    return null;
  }

  MechanicSignal _finish(int pose) {
    _done = true;
    fixArm = null;
    return ChooseOption(pose);
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

// ------------------------------------------------------------------ Góc tay

/// Góc tay (lớp 4): bé dang hai tay (vai → cổ tay) tạo thành góc nhọn / vuông / tù / bẹt và giữ [holdSeconds] giây.
/// Ngưỡng có biên rộng vì trẻ không giữ tay thẳng tuyệt đối: nhọn < 75°, vuông 75–105°, tù 105–165°, bẹt > 165°.
class ArmAngleMechanic extends AnswerMechanic {
  ArmAngleMechanic({required this.target, this.holdSeconds = 0.8});

  /// acute | right | obtuse | straight
  final String target;
  final double holdSeconds;

  /// Góc giữa hai tay đang thấy (độ), null khi chưa thấy đủ hai tay hoặc bé đang buông thõng cả hai tay.
  double? angle;
  String? current;
  double _held = 0;
  bool _done = false;

  static const order = ['acute', 'right', 'obtuse', 'straight'];

  static String classify(double deg) => deg < 75 ? 'acute' : (deg <= 105 ? 'right' : (deg <= 165 ? 'obtuse' : 'straight'));

  /// Góc giữa hai cánh tay; null nếu không thấy cổ tay hoặc cả hai tay đều buông xuống.
  static double? between(BodySnapshot body) {
    final l = body.armAngle(right: false), r = body.armAngle(right: true);
    if (l == null || r == null) return null;
    if (body.armDown(right: false) && body.armDown(right: true)) return null;
    return BodySnapshot.angleDiff(l, r);
  }

  @override
  MechanicKind get kind => MechanicKind.armAngle;

  @override
  double get progress => current == target ? (_held / holdSeconds).clamp(0.0, 1.0).toDouble() : 0;

  @override
  String? get hint {
    if (current == null || current == target) return null;
    return order.indexOf(current!) < order.indexOf(target) ? 'Mở rộng hai tay ra thêm' : 'Khép hai tay lại một chút';
  }

  @override
  MechanicSignal? update(MechanicInput input) {
    if (_done) return null;
    final body = input.body;
    angle = body == null ? null : between(body);
    final now = angle == null ? null : classify(angle!);
    if (now != current) _held = 0;
    current = now;
    if (now == target) {
      _held += input.dt;
      if (_held >= holdSeconds) {
        _done = true;
        return const ReportResult(true);
      }
    }
    return null;
  }
}

// ------------------------------------------------------------------ Tia số

/// Tia số (lớp 3–5): các đáp án xếp từ trái sang phải; bé đi ngang tới ô có đáp án đúng rồi giơ một tay lên,
/// giữ [holdSeconds] giây để chọn. Phải giơ tay mới chọn nên bé đi qua các ô khác không bị tính.
/// Cách chốt đáp án khi bé đã đứng đúng ô.
enum ZoneConfirm {
  /// Giơ tay giữ [ZoneMechanic.holdSeconds] giây (Tia số).
  handUp,

  /// Nhảy lên một cái (Nhảy ô).
  jump,

  /// Chờ sao rơi xuống đất: bé đang đứng ở ô nào thì chọn ô đó (Hứng sao).
  landing,
}

class ZoneMechanic extends AnswerMechanic {
  ZoneMechanic({
    required this.zones,
    this.holdSeconds = 0.8,
    this.span = 1.6,
    this.confirm = ZoneConfirm.handUp,
    this.fallSeconds = 6,
  });

  final int zones;
  final double holdSeconds;
  final ZoneConfirm confirm;

  /// Hứng sao: số giây sao rơi từ trên xuống đất.
  final double fallSeconds;

  /// Bé bước sang mỗi bên tối đa [span] lần bề rộng vai là tới ô ngoài cùng.
  final double span;

  /// Vị trí bé trên tia số, −1 (trái màn hình) … 1 (phải).
  double position = 0;
  int? zone;
  bool handUp = false;

  /// Độ nhảy hiện tại theo chiều dài thân (để vẽ bé nhảy lên).
  double rise = 0;

  /// Giây đã trôi (hứng sao).
  double elapsed = 0;
  double _held = 0;
  double _stable = 0;
  bool _done = false;

  @override
  MechanicKind get kind => MechanicKind.zone;

  @override
  bool get needsCalibration => true;

  @override
  int? get aimed => zone;

  /// Hứng sao: 0 = sao vừa xuất hiện, 1 = sao chạm đất.
  double get fall => (elapsed / fallSeconds).clamp(0.0, 1.0).toDouble();

  @override
  double get progress => switch (confirm) {
        ZoneConfirm.handUp => handUp ? (_held / holdSeconds).clamp(0.0, 1.0).toDouble() : 0,
        ZoneConfirm.jump => 0,
        ZoneConfirm.landing => fall,
      };

  @override
  String? get hint {
    if (_done) return null;
    return switch (confirm) {
      ZoneConfirm.handUp => zone != null && !handUp ? 'Đứng đúng ô rồi giơ tay lên!' : null,
      ZoneConfirm.jump => zone != null ? 'Đứng vào ô đúng rồi nhảy lên!' : null,
      ZoneConfirm.landing => zone != null && fall < 0.85 ? 'Bước sang dưới ngôi sao đúng nhé!' : null,
    };
  }

  static int zoneOf(double position, int zones) => (((position + 1) / 2) * zones).floor().clamp(0, zones - 1);

  @override
  MechanicSignal? update(MechanicInput input) {
    final cal = input.calibration;
    final body = input.body;
    if (confirm == ZoneConfirm.landing) elapsed += input.dt;
    if (_done || cal == null) return null;
    if (body == null) {
      zone = null;
      handUp = false;
      _held = 0;
      _stable = 0;
      return null;
    }
    position = ((body.hipCenter.dx - cal.hipCenter.dx) / cal.shoulderWidth / span).clamp(-1.0, 1.0).toDouble();
    final z = zoneOf(position, zones);
    rise = cal.torsoLength <= 0 ? 0 : (cal.hipCenter.dy - body.hipCenter.dy) / cal.torsoLength;
    switch (confirm) {
      case ZoneConfirm.handUp:
        final up = body.armRaised(right: false) || body.armRaised(right: true);
        if (z != zone || !up) _held = 0;
        zone = z;
        handUp = up;
        if (up) {
          _held += input.dt;
          if (_held >= holdSeconds) {
            _done = true;
            return ChooseOption(z);
          }
        }
      case ZoneConfirm.jump:
        zone = z;
        // Phải đứng yên trên sàn một lúc trước khi nhảy được tính (tránh chọn khi bé vừa nhảy từ câu trước).
        if (rise < 0.08) {
          _stable += input.dt;
        } else if (rise < 0.15) {
          // vùng trễ: giữ nguyên
        } else if (_stable >= 0.3) {
          _done = true;
          return ChooseOption(z);
        }
        if (rise >= 0.15) _stable = 0;
      case ZoneConfirm.landing:
        zone = z;
        if (elapsed >= fallSeconds) {
          _done = true;
          return ChooseOption(z);
        }
    }
    return null;
  }
}

// ------------------------------------------------------------------ C (nhiều ô, theo thứ tự)

/// Chạm lần lượt các ô theo thứ tự [sequence] (chỉ số ô, vd. từ bé đến lớn).
///
/// Chạm đúng ô kế tiếp thì ô đó được đánh dấu; chạm nhầm ô chưa tới lượt thì tính chưa đúng;
/// chạm đủ cả dãy thì đúng. Ô đã chạm rồi bị bỏ qua.
class OrderTouchMechanic extends AnswerMechanic {
  OrderTouchMechanic({required this.sequence, double dwellSeconds = 0.4}) : dwell = DwellSelector(dwellSeconds: dwellSeconds);

  final List<int> sequence;
  final DwellSelector dwell;

  /// Số ô đã chạm đúng.
  int step = 0;
  bool _done = false;

  /// Ô đã chạm đúng.
  Set<int> get touched => {...sequence.take(step)};

  /// Ô cần chạm tiếp theo (null khi đã xong).
  int? get next => step < sequence.length ? sequence[step] : null;

  @override
  MechanicKind get kind => MechanicKind.orderTouch;

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
    if (_done || input.targets.isEmpty) return null;
    final hit = dwell.update(input.hands, input.targets, input.dt);
    if (hit == null) return null;
    return pick(hit);
  }

  /// Bé chọn ô [i] (chạm tay hoặc chạm màn hình). null: ô đã chạm rồi, bỏ qua.
  MechanicSignal? pick(int i) {
    if (_done || touched.contains(i)) return null;
    if (i != next) {
      _done = true;
      return const ReportResult(false);
    }
    step++;
    if (step >= sequence.length) {
      _done = true;
      return const ReportResult(true);
    }
    return null;
  }
}

// ------------------------------------------------------------------ Đ + B (chạy rồi chọn đường)

/// Chạy tại chỗ đủ [lifts] bước thì tới ngã ba, rồi nghiêng người (hoặc bước) sang trái/phải chọn đường.
class RunChooseMechanic extends AnswerMechanic {
  RunChooseMechanic({this.lifts = 5, StepDetector? detector})
      : detector = detector ?? StepDetector(allowLean: true, holdSeconds: 0.4);

  /// Số bước chạy cần để tới ngã ba.
  final int lifts;
  final StepDetector detector;
  final KneeLiftCounter counter = KneeLiftCounter();

  /// Bé đã đứng giữa ở ngã ba (tránh chọn ngay khi vừa dừng chạy mà người còn lắc).
  bool armed = false;
  bool _done = false;

  int get steps => counter.count.clamp(0, lifts);
  bool get arrived => counter.count >= lifts;

  /// 0..1 quãng đường tới ngã ba.
  double get route => steps / lifts;

  @override
  MechanicKind get kind => MechanicKind.run;

  @override
  bool get needsCalibration => true;

  @override
  double get progress => route;

  @override
  String? get hint {
    if (_done) return null;
    if (!arrived) return counter.seesKnees || counter.count > 0 ? 'Chạy tại chỗ nào!' : 'Lùi ra để camera thấy tới đầu gối nhé';
    return armed ? 'Nghiêng người sang đường đúng!' : 'Dừng lại, đứng thẳng nhé!';
  }

  @override
  MechanicSignal? update(MechanicInput input) {
    if (_done) return null;
    final body = input.body;
    if (!arrived) {
      counter.update(body);
      return null;
    }
    final cal = input.calibration;
    if (cal == null || body == null) return null;
    final event = detector.update(body, cal);
    if (!armed) {
      if (detector.offset.abs() < detector.centerThreshold && body.leanOffset.abs() < detector.leanThreshold / 2) {
        armed = true;
      }
      return null;
    }
    if (event == StepSide.left) return _finish(0);
    if (event == StepSide.right) return _finish(1);
    return null;
  }

  MechanicSignal _finish(int option) {
    _done = true;
    return ChooseOption(option);
  }
}

// ------------------------------------------------------------------ Đ (cổng thấp / cao)

/// Hai cổng: ngồi xuống để chui cổng thấp (đáp án 0), nhảy lên để vượt cổng cao (đáp án 1).
class GateMechanic extends AnswerMechanic {
  GateMechanic({this.squatSeconds = 0.3});

  final double squatSeconds;

  /// Độ cao hông so với lúc đứng, theo chiều dài thân (dương = nhảy, âm = ngồi).
  double rise = 0;
  double _stable = 0;
  double _low = 0;
  bool _done = false;

  @override
  MechanicKind get kind => MechanicKind.gate;

  @override
  bool get needsCalibration => true;

  @override
  double get progress => (_low / squatSeconds).clamp(0.0, 1.0).toDouble();

  @override
  String? get hint => _done ? null : 'Ngồi xuống chui cổng thấp, nhảy lên vượt cổng cao!';

  @override
  MechanicSignal? update(MechanicInput input) {
    final cal = input.calibration;
    final body = input.body;
    if (_done || cal == null || body == null || cal.torsoLength <= 0) return null;
    rise = (cal.hipCenter.dy - body.hipCenter.dy) / cal.torsoLength;
    if (rise.abs() < 0.08) _stable += input.dt;
    // Chỉ tính khi bé đã đứng thẳng một lúc, để không chọn nhầm lúc vừa đổi câu.
    if (_stable < 0.3) return null;
    if (rise <= -0.35) {
      _low += input.dt;
      if (_low >= squatSeconds) return _finish(0);
    } else {
      _low = 0;
    }
    if (rise >= 0.18) return _finish(1);
    return null;
  }

  MechanicSignal _finish(int option) {
    _done = true;
    return ChooseOption(option);
  }
}
