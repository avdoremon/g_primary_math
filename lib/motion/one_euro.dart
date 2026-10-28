import 'dart:math' as math;

class _LowPass {
  double? _y;

  double filter(double x, double alpha) {
    final prev = _y;
    final y = prev == null ? x : alpha * x + (1 - alpha) * prev;
    _y = y;
    return y;
  }

  void reset() => _y = null;
}

/// One Euro Filter: mượt khi đứng yên, vẫn bám kịp khi chuyển động nhanh.
/// Tham khảo: Casiez, Roussel, Vogel (CHI 2012).
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.5, this.dCutoff = 1.0});

  double minCutoff;
  double beta;
  double dCutoff;

  final _x = _LowPass();
  final _dx = _LowPass();
  double? _lastRaw;
  Duration? _lastTime;

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double filter(double value, Duration time) {
    final last = _lastTime;
    var dt = last == null ? 1 / 30 : (time - last).inMicroseconds / 1e6;
    if (dt <= 0) dt = 1 / 30;
    _lastTime = time;

    final prev = _lastRaw;
    _lastRaw = value;
    final rawSpeed = prev == null ? 0.0 : (value - prev) / dt;
    final speed = _dx.filter(rawSpeed, _alpha(dCutoff, dt));
    final cutoff = minCutoff + beta * speed.abs();
    return _x.filter(value, _alpha(cutoff, dt));
  }

  void reset() {
    _x.reset();
    _dx.reset();
    _lastRaw = null;
    _lastTime = null;
  }
}
