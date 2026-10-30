import '../pose/pose_frame.dart';
import 'one_euro.dart';

/// Làm mượt toàn bộ khung xương bằng One Euro filter (mỗi toạ độ một bộ lọc):
/// mượt khi đứng yên, vẫn bám kịp khi chuyển động nhanh.
class LandmarkSmoother {
  LandmarkSmoother({this.minCutoff = 1.8, this.beta = 3.0, this.holdFor = const Duration(milliseconds: 150)});

  final double minCutoff;
  final double beta;

  /// Khớp chợt bị mất 1–2 khung (che tay, nhiễu) thì giữ vị trí cũ chừng này thời gian thay vì giật về 0.
  final Duration holdFor;

  final List<OneEuroFilter> _fx = [];
  final List<OneEuroFilter> _fy = [];
  final List<PoseLandmark?> _last = [];
  final List<Duration> _lastAt = [];

  void reset() {
    _last.clear();
    _lastAt.clear();
    for (final f in _fx) {
      f.reset();
    }
    for (final f in _fy) {
      f.reset();
    }
  }

  PoseFrame smooth(PoseFrame frame) {
    final lm = frame.landmarks;
    if (lm == null) {
      reset();
      return frame;
    }
    while (_fx.length < lm.length) {
      _fx.add(OneEuroFilter(minCutoff: minCutoff, beta: beta));
      _fy.add(OneEuroFilter(minCutoff: minCutoff, beta: beta));
      _last.add(null);
      _lastAt.add(Duration.zero);
    }
    final out = <PoseLandmark>[];
    for (var i = 0; i < lm.length; i++) {
      final l = lm[i];
      if (!l.visible) {
        final held = _last[i];
        if (held != null && frame.arrival - _lastAt[i] <= holdFor) {
          out.add(held);
          continue;
        }
        _fx[i].reset();
        _fy[i].reset();
        _last[i] = null;
        out.add(l);
        continue;
      }
      final smoothed = PoseLandmark(
        _fx[i].filter(l.x, frame.arrival),
        _fy[i].filter(l.y, frame.arrival),
        l.z,
        l.visibility,
      );
      _last[i] = smoothed;
      _lastAt[i] = frame.arrival;
      out.add(smoothed);
    }
    return frame.withLandmarks(List.unmodifiable(out));
  }
}
