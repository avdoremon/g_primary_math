/// Chỉ số 33 điểm khớp của MediaPipe Pose.
/// "left"/"right" là bên trái/phải thật của cơ thể trẻ (không phải bên màn hình).
abstract class PoseIdx {
  static const nose = 0;
  static const leftEye = 2;
  static const rightEye = 5;
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftPinky = 17;
  static const rightPinky = 18;
  static const leftIndex = 19;
  static const rightIndex = 20;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;

  /// Các đoạn nối để vẽ khung xương (bỏ chi tiết khuôn mặt).
  static const connections = <List<int>>[
    [leftShoulder, rightShoulder],
    [leftShoulder, leftElbow],
    [leftElbow, leftWrist],
    [rightShoulder, rightElbow],
    [rightElbow, rightWrist],
    [leftShoulder, leftHip],
    [rightShoulder, rightHip],
    [leftHip, rightHip],
    [leftHip, leftKnee],
    [leftKnee, leftAnkle],
    [rightHip, rightKnee],
    [rightKnee, rightAnkle],
    [leftWrist, leftIndex],
    [rightWrist, rightIndex],
  ];

  /// Các điểm thân (không tính mặt) dùng để vẽ chấm.
  static const bodyPoints = <int>[
    leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist,
    leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle,
  ];
}
