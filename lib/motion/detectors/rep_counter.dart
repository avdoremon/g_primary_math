import '../body_metrics.dart';
import '../calibration.dart';

enum RepKind { jump, squat, clap }

/// Cơ chế Đ – đếm động tác bằng máy trạng thái hai pha ("lên" ↔ "về"),
/// có ngưỡng trễ và khoảng cách tối thiểu giữa hai lần đếm để không đếm đúp.
///
/// - Nhảy: tâm hông cao hơn mức đứng ≥ 15% chiều dài thân, rồi về ≤ 5%.
/// - Ngồi xổm: tâm hông thấp hơn mức đứng ≥ 35% chiều dài thân, rồi đứng lên ≤ 10%.
///   (Nhìn từ phía trước, góc gối trên ảnh 2D không đáng tin, nên dùng độ hạ hông.)
/// - Vỗ tay: hai cổ tay gần nhau < 0,6 bề rộng vai, rồi tách ra > 1,2.
class RepCounter {
  RepCounter(this.kind, {this.minIntervalSeconds = 0.25});

  final RepKind kind;
  final double minIntervalSeconds;

  int count = 0;
  bool _active = false;
  Duration? _lastRep;

  /// Giá trị đo hiện tại (để vẽ thanh gợi ý), theo đơn vị của từng kiểu.
  double value = 0;

  void reset() {
    count = 0;
    _active = false;
    _lastRep = null;
    value = 0;
  }

  /// Trả về true đúng một lần cho mỗi động tác hoàn chỉnh.
  bool update(BodySnapshot? body, Calibration cal) {
    if (body == null || cal.torsoLength <= 0) return false;
    final rise = (cal.hipCenter.dy - body.hipCenter.dy) / cal.torsoLength;

    late bool enter; // vào pha "động tác"
    late bool exit; // về pha nghỉ
    switch (kind) {
      case RepKind.jump:
        value = rise;
        enter = rise >= 0.15;
        exit = rise <= 0.05;
      case RepKind.squat:
        value = -rise;
        enter = -rise >= 0.35;
        exit = -rise <= 0.10;
      case RepKind.clap:
        final gap = body.wristGap;
        if (gap == null) return false;
        value = gap;
        enter = gap < 0.6;
        exit = gap > 1.2;
    }

    if (!_active && enter) {
      _active = true;
      return false;
    }
    if (_active && exit) {
      _active = false;
      final last = _lastRep;
      if (last != null && (body.time - last).inMicroseconds / 1e6 < minIntervalSeconds) return false;
      _lastRep = body.time;
      count++;
      return true;
    }
    return false;
  }
}
