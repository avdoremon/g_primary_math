import '../../pose/landmarks.dart';
import '../body_metrics.dart';

/// Nhận ra động tác vẫy tay: một tay giơ cao hơn vai và đưa qua đưa lại.
///
/// Đổi chiều ít nhất [reversals] lần, mỗi lần đi được ít nhất [swing] bề rộng vai,
/// trong vòng [windowSeconds] giây thì tính là một lần vẫy.
class WaveDetector {
  WaveDetector({this.swing = 0.25, this.reversals = 2, this.windowSeconds = 1.6});

  final double swing;
  final int reversals;
  final double windowSeconds;

  final List<_HandTrack> _hands = [_HandTrack(), _HandTrack()];

  /// Tay đang giơ lên để vẫy (để vẽ gợi ý).
  bool get raised => _hands.any((h) => h.extreme != null);

  void reset() {
    for (final h in _hands) {
      h.clear();
    }
  }

  /// true ở khung vừa nhận ra một lần vẫy.
  bool update(BodySnapshot? body) {
    if (body == null || body.shoulderWidth <= 0) {
      reset();
      return false;
    }
    final t = body.time.inMicroseconds / 1e6;
    for (final right in const [false, true]) {
      final h = _hands[right ? 1 : 0];
      final wi = right ? PoseIdx.rightWrist : PoseIdx.leftWrist;
      final si = right ? PoseIdx.rightShoulder : PoseIdx.leftShoulder;
      final otherRaised = body.armRaised(right: !right);
      if (!body.sees(wi) || body.point(wi).dy > body.point(si).dy || otherRaised) {
        h.clear();
        continue;
      }
      final x = body.point(wi).dx / body.shoulderWidth;
      if (h.update(x, t, swing)) {
        h.times.removeWhere((s) => t - s > windowSeconds);
        if (h.times.length >= reversals) {
          reset();
          return true;
        }
      }
    }
    return false;
  }
}

class _HandTrack {
  double? extreme;
  int dir = 0;
  final List<double> times = [];

  void clear() {
    extreme = null;
    dir = 0;
    times.clear();
  }

  /// true khi vừa đổi chiều.
  bool update(double x, double t, double swing) {
    final e = extreme;
    if (e == null) {
      extreme = x;
      return false;
    }
    if (dir == 0) {
      if ((x - e).abs() >= swing) {
        dir = x > e ? 1 : -1;
        extreme = x;
      }
      return false;
    }
    if ((dir > 0 && x > e) || (dir < 0 && x < e)) {
      extreme = x;
      return false;
    }
    if ((x - e).abs() >= swing) {
      dir = -dir;
      extreme = x;
      times.add(t);
      return true;
    }
    return false;
  }
}
