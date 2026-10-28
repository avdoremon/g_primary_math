import 'dart:ui';

import 'body_metrics.dart';

/// Số đo chuẩn của từng bé, ghi lúc bé đứng thẳng giơ hai tay ở đầu lượt chơi.
/// Mọi ngưỡng của các cơ chế đều tính theo các số đo này, nên bé cao hay thấp,
/// đứng gần hay xa đều dùng chung một bộ ngưỡng.
class Calibration {
  const Calibration({
    required this.hipCenter,
    required this.shoulderWidth,
    required this.torsoLength,
  });

  /// Vị trí tâm hông khi đứng giữa (pixel ảnh).
  final Offset hipCenter;
  final double shoulderWidth;
  final double torsoLength;

  Map<String, Object> toJson() => {
        'hx': hipCenter.dx,
        'hy': hipCenter.dy,
        'sw': shoulderWidth,
        'tl': torsoLength,
      };
}

/// Bước hiệu chỉnh: bé giơ hai tay lên đầu và giữ [holdSeconds] giây.
/// Số đo lấy trung bình trong lúc giữ để bớt nhiễu.
class Calibrator {
  Calibrator({this.holdSeconds = 1.0});

  final double holdSeconds;

  Duration? _since;
  int _n = 0;
  double _hx = 0.0, _hy = 0.0, _sw = 0.0, _tl = 0.0;

  /// 0..1: tiến độ giữ tư thế, dùng để vẽ đếm ngược.
  double progress = 0;

  void reset() {
    _since = null;
    _n = 0;
    _hx = _hy = _sw = _tl = 0.0;
    progress = 0;
  }

  /// Trả về [Calibration] khi giữ đủ lâu, ngược lại null.
  Calibration? update(BodySnapshot? body) {
    if (body == null || !body.bothHandsAboveHead) {
      reset();
      return null;
    }
    _since ??= body.time;
    _n++;
    _hx += body.hipCenter.dx;
    _hy += body.hipCenter.dy;
    _sw += body.shoulderWidth;
    _tl += body.torsoLength;

    final held = (body.time - _since!).inMicroseconds / 1e6;
    progress = (held / holdSeconds).clamp(0.0, 1.0).toDouble();
    if (held < holdSeconds) return null;

    final c = Calibration(
      hipCenter: Offset(_hx / _n, _hy / _n),
      shoulderWidth: _sw / _n,
      torsoLength: _tl / _n,
    );
    reset();
    return c;
  }
}
