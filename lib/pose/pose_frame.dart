import 'dart:typed_data';

import 'landmarks.dart';

class PoseLandmark {
  const PoseLandmark(this.x, this.y, this.z, this.visibility);

  /// Toạ độ chuẩn hoá 0..1 trong ảnh đã xoay thẳng và ĐÃ LẬT GƯƠNG
  /// (trẻ giơ tay phải thì điểm nằm bên phải màn hình, như soi gương).
  final double x;
  final double y;
  final double z;
  final double visibility;

  bool get visible => visibility >= 0.5;
}

/// Một khung kết quả nhận diện gửi từ lớp native.
class PoseFrame {
  const PoseFrame({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
    required this.processingMs,
    required this.luma,
    required this.gpu,
    required this.arrival,
  });

  /// null khi không thấy người.
  final List<PoseLandmark>? landmarks;
  final int imageWidth;
  final int imageHeight;

  /// Thời gian từ lúc nhận khung hình đến lúc có kết quả (ms).
  final int processingMs;

  /// Độ sáng vùng giữa khung hình, 0..255.
  final double luma;
  final bool gpu;

  /// Thời điểm khung hình đến phía Dart (đồng hồ của PoseService).
  final Duration arrival;

  bool get hasPerson => landmarks != null;

  double get aspect => imageHeight == 0 ? 4 / 3 : imageWidth / imageHeight;

  bool sees(int index) {
    final lm = landmarks;
    return lm != null && index < lm.length && lm[index].visible;
  }

  bool get seesHead => sees(PoseIdx.nose);
  bool get seesBothHands => sees(PoseIdx.leftWrist) && sees(PoseIdx.rightWrist);
  bool get seesBothFeet => sees(PoseIdx.leftAnkle) && sees(PoseIdx.rightAnkle);
  bool get seesWholeBody => seesHead && seesBothHands && seesBothFeet;

  factory PoseFrame.fromMap(Map<dynamic, dynamic> m, Duration arrival) {
    final raw = m['lm'];
    List<double>? values;
    if (raw is Float64List) {
      values = raw;
    } else if (raw is List) {
      values = raw.map((e) => (e as num).toDouble()).toList();
    }

    List<PoseLandmark>? points;
    if (values != null && values.length >= 33 * 4) {
      final v = values;
      points = List<PoseLandmark>.generate(
        v.length ~/ 4,
        (i) => PoseLandmark(1.0 - v[i * 4], v[i * 4 + 1], v[i * 4 + 2], v[i * 4 + 3]),
        growable: false,
      );
    }

    return PoseFrame(
      landmarks: points,
      imageWidth: (m['w'] as num?)?.toInt() ?? 0,
      imageHeight: (m['h'] as num?)?.toInt() ?? 0,
      processingMs: (m['inf'] as num?)?.toInt() ?? 0,
      luma: (m['luma'] as num?)?.toDouble() ?? 0,
      gpu: m['gpu'] == true,
      arrival: arrival,
    );
  }

  /// Bản sao với danh sách điểm khớp khác (dùng cho bộ làm mượt).
  PoseFrame withLandmarks(List<PoseLandmark>? points) => PoseFrame(
        landmarks: points,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        processingMs: processingMs,
        luma: luma,
        gpu: gpu,
        arrival: arrival,
      );

  /// Ghi ra JSON để lưu chuỗi khung xương (toạ độ đã lật gương, làm tròn 4 chữ số).
  Map<String, Object?> toJson() {
    double r(double v) => (v * 10000).roundToDouble() / 10000;
    return {
      't': arrival.inMilliseconds,
      'w': imageWidth,
      'h': imageHeight,
      'inf': processingMs,
      'luma': r(luma),
      'lm': landmarks == null
          ? null
          : [
              for (final l in landmarks!) ...[r(l.x), r(l.y), r(l.z), r(l.visibility)],
            ],
    };
  }

  /// Đọc lại từ [toJson]. Toạ độ trong JSON đã lật gương nên không lật lần nữa.
  factory PoseFrame.fromJson(Map<String, dynamic> j) {
    final raw = j['lm'] as List<dynamic>?;
    List<PoseLandmark>? points;
    if (raw != null) {
      final v = raw.map((e) => (e as num).toDouble()).toList(growable: false);
      points = List<PoseLandmark>.generate(
        v.length ~/ 4,
        (i) => PoseLandmark(v[i * 4], v[i * 4 + 1], v[i * 4 + 2], v[i * 4 + 3]),
        growable: false,
      );
    }
    return PoseFrame(
      landmarks: points,
      imageWidth: (j['w'] as num?)?.toInt() ?? 0,
      imageHeight: (j['h'] as num?)?.toInt() ?? 0,
      processingMs: (j['inf'] as num?)?.toInt() ?? 0,
      luma: (j['luma'] as num?)?.toDouble() ?? 0,
      gpu: false,
      arrival: Duration(milliseconds: (j['t'] as num?)?.toInt() ?? 0),
    );
  }
}
