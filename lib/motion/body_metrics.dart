import 'dart:math' as math;
import 'dart:ui';

import '../pose/landmarks.dart';
import '../pose/pose_frame.dart';

/// Các số đo cơ thể tính từ một khung xương, theo pixel ảnh camera
/// (đã lật gương: bên phải màn hình = tay phải của bé).
///
/// "Trái/phải" trong các tên dưới đây là trái/phải THẬT của cơ thể bé;
/// vì đã lật gương nên tay phải của bé luôn nằm bên phải màn hình.
class BodySnapshot {
  BodySnapshot._(this.frame, this._px);

  final PoseFrame frame;
  final List<Offset> _px;

  static const _minVisibility = 0.5;

  /// null nếu không thấy người hoặc không thấy đủ hai vai và hai hông.
  static BodySnapshot? of(PoseFrame frame) {
    final lm = frame.landmarks;
    if (lm == null || frame.imageWidth <= 0 || frame.imageHeight <= 0) return null;
    for (final i in const [PoseIdx.leftShoulder, PoseIdx.rightShoulder, PoseIdx.leftHip, PoseIdx.rightHip]) {
      if (lm[i].visibility < _minVisibility) return null;
    }
    final w = frame.imageWidth.toDouble();
    final h = frame.imageHeight.toDouble();
    return BodySnapshot._(frame, [for (final l in lm) Offset(l.x * w, l.y * h)]);
  }

  Duration get time => frame.arrival;

  Offset point(int index) => _px[index];
  bool sees(int index) => frame.sees(index);

  Offset get shoulderCenter => (point(PoseIdx.leftShoulder) + point(PoseIdx.rightShoulder)) / 2;
  Offset get hipCenter => (point(PoseIdx.leftHip) + point(PoseIdx.rightHip)) / 2;

  /// Bề rộng vai (pixel). Đơn vị chuẩn để so khoảng cách ngang.
  double get shoulderWidth => (point(PoseIdx.leftShoulder) - point(PoseIdx.rightShoulder)).distance;

  /// Chiều dài thân: tâm vai → tâm hông (pixel). Đơn vị chuẩn để so khoảng cách dọc.
  double get torsoLength => (shoulderCenter - hipCenter).distance;

  Offset get leftWrist => point(PoseIdx.leftWrist);
  Offset get rightWrist => point(PoseIdx.rightWrist);

  /// Góc cánh tay (vai → cổ tay) trên màn hình, tính bằng độ theo chiều kim đồng hồ:
  /// 0° = chỉ thẳng lên, 90° = sang phải màn hình, 180° = xuống, 270° = sang trái.
  /// null nếu không thấy cổ tay.
  double? armAngle({required bool right}) {
    final s = point(right ? PoseIdx.rightShoulder : PoseIdx.leftShoulder);
    final wi = right ? PoseIdx.rightWrist : PoseIdx.leftWrist;
    if (!sees(wi)) return null;
    final v = point(wi) - s;
    return angleFromUp(v);
  }

  /// Tay giơ lên: cổ tay cao hơn vai ít nhất 20% chiều dài thân.
  bool armRaised({required bool right}) {
    final wi = right ? PoseIdx.rightWrist : PoseIdx.leftWrist;
    final si = right ? PoseIdx.rightShoulder : PoseIdx.leftShoulder;
    return sees(wi) && point(wi).dy < point(si).dy - 0.2 * torsoLength;
  }

  /// Tay hạ xuống: cổ tay thấp hơn vai ít nhất 50% chiều dài thân.
  bool armDown({required bool right}) {
    final wi = right ? PoseIdx.rightWrist : PoseIdx.leftWrist;
    final si = right ? PoseIdx.rightShoulder : PoseIdx.leftShoulder;
    return sees(wi) && point(wi).dy > point(si).dy + 0.5 * torsoLength;
  }

  /// Cả hai cổ tay cao hơn mũi (tư thế hiệu chỉnh / bắt đầu chơi).
  bool get bothHandsAboveHead {
    if (!sees(PoseIdx.nose) || !sees(PoseIdx.leftWrist) || !sees(PoseIdx.rightWrist)) return false;
    final noseY = point(PoseIdx.nose).dy;
    return leftWrist.dy < noseY && rightWrist.dy < noseY;
  }

  /// Khoảng cách hai cổ tay, theo đơn vị bề rộng vai.
  double? get wristGap {
    if (!sees(PoseIdx.leftWrist) || !sees(PoseIdx.rightWrist) || shoulderWidth == 0) return null;
    return (leftWrist - rightWrist).distance / shoulderWidth;
  }

  /// Mức thấy được cơ thể, dùng cho ô bóng người và màn "đứng vào khung".
  BodyCoverage get coverage => BodyCoverage(
        head: sees(PoseIdx.nose),
        leftHand: sees(PoseIdx.leftWrist),
        rightHand: sees(PoseIdx.rightWrist),
        leftFoot: sees(PoseIdx.leftAnkle),
        rightFoot: sees(PoseIdx.rightAnkle),
      );

  static double angleFromUp(Offset v) {
    final deg = math.atan2(v.dx, -v.dy) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  /// Hiệu hai góc (độ), luôn trong 0..180.
  static double angleDiff(double a, double b) {
    final d = ((a - b) % 360 + 360) % 360;
    return d > 180 ? 360 - d : d;
  }
}

class BodyCoverage {
  const BodyCoverage({
    required this.head,
    required this.leftHand,
    required this.rightHand,
    required this.leftFoot,
    required this.rightFoot,
  });

  static const none = BodyCoverage(head: false, leftHand: false, rightHand: false, leftFoot: false, rightFoot: false);

  final bool head;
  final bool leftHand;
  final bool rightHand;
  final bool leftFoot;
  final bool rightFoot;

  bool get hands => leftHand && rightHand;
  bool get feet => leftFoot && rightFoot;
  bool get whole => head && hands && feet;

  /// Thấy nửa người trên (đủ cho cơ chế chạm và tạo dáng tay).
  bool get upperBody => head && hands;
}
