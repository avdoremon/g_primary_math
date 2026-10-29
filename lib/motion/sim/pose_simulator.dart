import 'dart:math' as math;
import 'dart:ui';

import '../../pose/landmarks.dart';
import '../../pose/pose_frame.dart';

/// Thông số một tư thế giả lập (nhìn trên màn hình, đã lật gương).
class SimPose {
  SimPose({
    this.centerX = 0.5,
    this.scale = 1.0,
    this.jump = 0,
    this.squat = 0,
    this.lean = 0,
    this.leftKnee = 0,
    this.rightKnee = 0,
    this.leftArm = 180,
    this.rightArm = 180,
    this.visible = true,
    Set<int>? hidden,
  }) : hidden = hidden ?? <int>{};

  /// Vị trí ngang của tâm hông, 0..1 theo chiều rộng ảnh.
  double centerX;

  /// 1 = cỡ người bình thường khi đứng cách máy khoảng 2 m.
  double scale;

  /// Độ nhảy lên, theo chiều dài thân (0 = đứng trên sàn).
  double jump;

  /// 0 = đứng thẳng, 1 = ngồi xổm hết mức (hông hạ 50% chiều dài thân).
  double squat;

  /// Nghiêng người: tâm vai lệch khỏi tâm hông, tính theo bề rộng vai (âm = sang trái màn hình).
  double lean;

  /// Nhấc đầu gối trái / phải: 0 = đứng, 1 = đùi nằm ngang (chạy tại chỗ).
  double leftKnee;
  double rightKnee;

  /// Góc cánh tay (độ, theo chiều kim đồng hồ, 0 = thẳng lên, 180 = buông xuống).
  double leftArm;
  double rightArm;

  bool visible;

  /// Các điểm khớp bị che (visibility = 0).
  Set<int> hidden;

  SimPose copy() => SimPose(
        centerX: centerX,
        scale: scale,
        jump: jump,
        squat: squat,
        lean: lean,
        leftKnee: leftKnee,
        rightKnee: rightKnee,
        leftArm: leftArm,
        rightArm: rightArm,
        visible: visible,
        hidden: {...hidden},
      );
}

/// Sinh khung xương 33 điểm từ [SimPose] để test các cơ chế mà không cần camera,
/// và để điều khiển game bằng chạm/bàn phím khi phát triển.
class PoseSimulator {
  PoseSimulator({this.imageWidth = 640, this.imageHeight = 480});

  final int imageWidth;
  final int imageHeight;

  PoseFrame frame(SimPose p, Duration t) {
    if (!p.visible) {
      return PoseFrame(
        landmarks: null,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        processingMs: 30,
        luma: 120,
        gpu: false,
        arrival: t,
      );
    }
    final w = imageWidth.toDouble();
    final h = imageHeight.toDouble();
    final torso = 0.22 * h * p.scale; // tâm vai → tâm hông
    final shoulderW = 0.8 * torso;
    final hipW = 0.6 * shoulderW;
    final arm = 0.9 * torso;
    final leg = 0.95 * torso; // mỗi đoạn đùi / cẳng chân

    final ground = 0.95 * h - p.jump * torso;
    final standHipY = ground - 2 * leg;
    final hipY = standHipY + p.squat * 0.5 * torso;
    final hip = Offset(p.centerX * w, hipY);
    final sh = hip + Offset(p.lean * shoulderW, -torso);

    final pts = List<Offset>.filled(33, sh);
    void put(int i, Offset o) => pts[i] = o;

    // Đầu
    final nose = sh - Offset(0, 0.45 * torso);
    put(PoseIdx.nose, nose);
    for (final i in const [1, 2, 3, 7, 9]) {
      put(i, nose + Offset(-0.08 * torso, i == 9 ? 0.12 * torso : -0.05 * torso));
    }
    for (final i in const [4, 5, 6, 8, 10]) {
      put(i, nose + Offset(0.08 * torso, i == 10 ? 0.12 * torso : -0.05 * torso));
    }

    // Vai, hông (tay phải của bé ở bên phải màn hình)
    final ls = sh - Offset(shoulderW / 2, 0);
    final rs = sh + Offset(shoulderW / 2, 0);
    put(PoseIdx.leftShoulder, ls);
    put(PoseIdx.rightShoulder, rs);
    put(PoseIdx.leftHip, hip - Offset(hipW / 2, 0));
    put(PoseIdx.rightHip, hip + Offset(hipW / 2, 0));

    // Tay
    Offset dir(double deg) {
      final r = deg * math.pi / 180;
      return Offset(math.sin(r), -math.cos(r));
    }

    void armAt(Offset s, double deg, int elbow, int wrist, int pinky, int index, int thumb) {
      final d = dir(deg);
      put(elbow, s + d * (arm / 2));
      put(wrist, s + d * arm);
      put(pinky, s + d * (arm * 1.08));
      put(index, s + d * (arm * 1.1));
      put(thumb, s + d * (arm * 1.05));
    }

    armAt(ls, p.leftArm, PoseIdx.leftElbow, PoseIdx.leftWrist, PoseIdx.leftPinky, PoseIdx.leftIndex, 21);
    armAt(rs, p.rightArm, PoseIdx.rightElbow, PoseIdx.rightWrist, PoseIdx.rightPinky, PoseIdx.rightIndex, 22);

    // Chân: bàn chân cố định trên sàn (trừ khi nhảy), đầu gối dạt ra khi ngồi
    for (final right in const [false, true]) {
      final sign = right ? 1.0 : -1.0;
      final hipP = hip + Offset(sign * hipW / 2, 0);
      final ankle = Offset(hipP.dx, ground - 0.05 * torso);
      final lift = right ? p.rightKnee : p.leftKnee;
      final stand = (hipP.dy + ankle.dy) / 2;
      final knee = Offset(
        hipP.dx + sign * p.squat * 0.4 * torso,
        stand + (hipP.dy + 0.05 * torso - stand) * lift,
      );
      put(right ? PoseIdx.rightKnee : PoseIdx.leftKnee, knee);
      put(right ? PoseIdx.rightAnkle : PoseIdx.leftAnkle, ankle);
      put(right ? 30 : 29, ankle + Offset(0, 0.03 * torso)); // gót
      put(right ? 32 : 31, ankle + Offset(sign * 0.1 * torso, 0.05 * torso)); // mũi chân
    }

    final lm = <PoseLandmark>[
      for (var i = 0; i < 33; i++)
        PoseLandmark(
          pts[i].dx / w,
          pts[i].dy / h,
          0,
          p.hidden.contains(i) || !_inside(pts[i], w, h) ? 0.0 : 0.99,
        ),
    ];
    return PoseFrame(
      landmarks: lm,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      processingMs: 30,
      luma: 120,
      gpu: false,
      arrival: t,
    );
  }

  static bool _inside(Offset o, double w, double h) => o.dx >= 0 && o.dx <= w && o.dy >= 0 && o.dy <= h;

  /// Chuỗi khung hình ở [fps] khung/giây trong [seconds] giây, tư thế tính theo thời gian.
  Iterable<PoseFrame> sequence({
    required double seconds,
    required SimPose Function(double t) pose,
    double fps = 30,
    Duration start = Duration.zero,
  }) sync* {
    final n = (seconds * fps).round();
    for (var i = 0; i <= n; i++) {
      final t = i / fps;
      yield frame(pose(t), start + Duration(microseconds: (t * 1e6).round()));
    }
  }
}
