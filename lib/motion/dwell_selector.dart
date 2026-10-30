import 'dart:math' as math;
import 'dart:ui';

/// Cơ chế C – "Chạm đáp án": tay nằm trong vùng đáp án đủ lâu thì chọn.
///
/// - Toạ độ tay và vùng đáp án đều chuẩn hoá 0..1 theo màn hình.
/// - Vùng đang được nhắm phóng to thêm một chút (trễ biên) để tay hơi rung không bị mất.
/// - Sau khi chọn, phải đưa tay ra khỏi vùng đó mới chọn lại được (tránh chọn đúp).
class DwellSelector {
  DwellSelector({this.dwellSeconds = 0.4, this.hysteresis = 0.025});

  double dwellSeconds;
  double hysteresis;

  int? candidate;

  /// 0..1, tiến độ nạp của vùng đang nhắm.
  double progress = 0;

  /// Bàn tay đang nạp (để vẽ vòng tiến trình).
  Offset? activePoint;

  int? _lockedOn;

  /// Tay rời ô chừng ngắn hơn mức này (nhiễu nhận diện) thì tiến độ giữ nguyên, không tụt.
  double grace = 0.25;
  double _away = 0;

  void reset() {
    candidate = null;
    progress = 0;
    activePoint = null;
    _lockedOn = null;
    _away = 0;
  }

  /// Trả về chỉ số vùng vừa được chọn, hoặc null.
  int? update(List<Offset?> points, List<Rect> targets, double dt) {
    int? hit;
    Offset? hitPoint;
    for (final p in points) {
      if (p == null) continue;
      for (var i = 0; i < targets.length; i++) {
        final r = i == candidate ? targets[i].inflate(hysteresis) : targets[i];
        if (r.contains(p)) {
          hit = i;
          hitPoint = p;
          break;
        }
      }
      if (hit != null) break;
    }

    if (_lockedOn != null) {
      if (hit == _lockedOn) {
        progress = 0;
        activePoint = null;
        return null;
      }
      _lockedOn = null;
    }

    if (hit != null) _away = 0;
    if (hit == null && progress > 0 && (_away += dt) <= grace) return null;
    if (hit == null) {
      progress = math.max(0.0, progress - dt / dwellSeconds * 2);
      if (progress == 0) {
        candidate = null;
        activePoint = null;
      }
      return null;
    }

    if (hit != candidate) {
      candidate = hit;
      progress = 0;
    }
    activePoint = hitPoint;
    progress += dt / dwellSeconds;
    if (progress >= 1) {
      progress = 0;
      _lockedOn = hit;
      candidate = null;
      activePoint = null;
      return hit;
    }
    return null;
  }
}
