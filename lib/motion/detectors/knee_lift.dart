import '../../pose/landmarks.dart';
import '../body_metrics.dart';

/// Đếm bước chạy tại chỗ: mỗi lần một đầu gối nhấc lên (đùi gần nằm ngang) rồi hạ xuống.
///
/// Đo bằng khoảng cách dọc từ hông đến đầu gối chia cho chiều dài thân, nên không cần hiệu chỉnh
/// và bé đứng gần hay xa đều như nhau. Đứng thẳng khoảng 0,95; nhấc gối còn dưới [liftBelow].
/// Cần thấy cả hông và đầu gối (bé đứng đủ xa cho camera thấy tới đầu gối).
class KneeLiftCounter {
  KneeLiftCounter({this.liftBelow = 0.6, this.downAbove = 0.8, this.minIntervalSeconds = 0.15});

  final double liftBelow;
  final double downAbove;
  final double minIntervalSeconds;

  int count = 0;

  /// Chân đang nhấc (để vẽ), theo chân thật của bé.
  bool leftUp = false;
  bool rightUp = false;

  /// Thấy được đầu gối ở khung gần nhất.
  bool seesKnees = false;

  Duration? _last;

  void reset() {
    count = 0;
    leftUp = rightUp = false;
    seesKnees = false;
    _last = null;
  }

  /// Trả về true mỗi lần có thêm một bước.
  bool update(BodySnapshot? body) {
    if (body == null || body.torsoLength <= 0) {
      seesKnees = false;
      return false;
    }
    var stepped = false;
    var seen = false;
    for (final right in const [false, true]) {
      final ki = right ? PoseIdx.rightKnee : PoseIdx.leftKnee;
      final hi = right ? PoseIdx.rightHip : PoseIdx.leftHip;
      if (!body.sees(ki)) continue;
      seen = true;
      final drop = (body.point(ki).dy - body.point(hi).dy) / body.torsoLength;
      final up = right ? rightUp : leftUp;
      if (!up && drop < liftBelow) {
        if (right) {
          rightUp = true;
        } else {
          leftUp = true;
        }
        final last = _last;
        if (last == null || (body.time - last).inMicroseconds / 1e6 >= minIntervalSeconds) {
          _last = body.time;
          count++;
          stepped = true;
        }
      } else if (up && drop > downAbove) {
        if (right) {
          rightUp = false;
        } else {
          leftUp = false;
        }
      }
    }
    seesKnees = seen;
    return stepped;
  }
}
