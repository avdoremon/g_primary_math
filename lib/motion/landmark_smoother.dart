import '../pose/pose_frame.dart';
import 'one_euro.dart';

/// Làm mượt toàn bộ khung xương bằng One Euro filter (mỗi toạ độ một bộ lọc):
/// mượt khi đứng yên, vẫn bám kịp khi chuyển động nhanh.
class LandmarkSmoother {
  LandmarkSmoother({this.minCutoff = 1.5, this.beta = 0.6});

  final double minCutoff;
  final double beta;

  final List<OneEuroFilter> _fx = [];
  final List<OneEuroFilter> _fy = [];

  void reset() {
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
    }
    final out = <PoseLandmark>[];
    for (var i = 0; i < lm.length; i++) {
      final l = lm[i];
      if (!l.visible) {
        _fx[i].reset();
        _fy[i].reset();
        out.add(l);
        continue;
      }
      out.add(PoseLandmark(
        _fx[i].filter(l.x, frame.arrival),
        _fy[i].filter(l.y, frame.arrival),
        l.z,
        l.visibility,
      ));
    }
    return frame.withLandmarks(List.unmodifiable(out));
  }
}
