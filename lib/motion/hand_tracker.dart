import 'dart:math' as math;
import 'dart:ui';

import '../pose/landmarks.dart';
import '../pose/pose_frame.dart';
import 'one_euro.dart';

/// Vị trí hai bàn tay trên màn hình, toạ độ chuẩn hoá 0..1.
/// [left]/[right] = bàn tay nằm bên trái/phải MÀN HÌNH.
class HandState {
  const HandState(this.left, this.right);

  static const none = HandState(null, null);

  final Offset? left;
  final Offset? right;

  List<Offset?> get both => [left, right];
}

/// Chuyển vị trí bàn tay trong ảnh camera thành vị trí trên màn hình game.
///
/// Dùng một "hộp tầm với" bám theo vai của trẻ: chiều rộng = 3.4 lần bề rộng vai.
/// Nhờ vậy trẻ đứng xa hay gần, cao hay thấp thì dang tay vẫn chạm tới mép màn hình.
class HandTracker {
  HandTracker({this.screenAspect = 16 / 9});

  double screenAspect;

  static const reachFactor = 3.4;
  static const boxSmoothing = 0.08;

  double? _cx;
  double? _cy;
  double? _boxW;
  final List<OneEuroFilter> _filters =
      List.generate(4, (_) => OneEuroFilter(minCutoff: 1.5, beta: 3.0));
  final List<Offset?> _lastHand = [null, null];
  final List<Duration> _lastHandAt = [Duration.zero, Duration.zero];

  /// Bàn tay chợt mất vài khung thì giữ vị trí cũ chừng này thời gian (giữ tay 3 giây không bị đứt).
  static const handHold = Duration(milliseconds: 250);

  /// Cả khung không thấy người thì giữ tay cũ chừng này.
  static const frameHold = Duration(milliseconds: 350);
  Duration _lastFrameAt = Duration.zero;

  HandState state = HandState.none;

  void reset() {
    _cx = null;
    _cy = null;
    _boxW = null;
    for (final f in _filters) {
      f.reset();
    }
    _lastHand[0] = _lastHand[1] = null;
    state = HandState.none;
  }

  HandState update(PoseFrame frame) {
    final lm = frame.landmarks;
    if (lm == null) {
      // Mô hình chợt bỏ sót cả người: giữ vị trí tay cũ một lúc để bé đang giữ tay trên đáp án không bị đứt.
      if (state != HandState.none && frame.arrival - _lastFrameAt <= frameHold) return state;
      for (final f in _filters) {
        f.reset();
      }
      _lastHand[0] = _lastHand[1] = null;
      return state = HandState.none;
    }
    _lastFrameAt = frame.arrival;

    final w = frame.imageWidth.toDouble();
    final h = frame.imageHeight.toDouble();
    final ls = lm[PoseIdx.leftShoulder];
    final rs = lm[PoseIdx.rightShoulder];
    if (!ls.visible || !rs.visible || w <= 0 || h <= 0) {
      return state = HandState.none;
    }

    // Tâm vai và bề rộng vai tính theo pixel ảnh.
    final sx = (ls.x + rs.x) / 2 * w;
    final sy = (ls.y + rs.y) / 2 * h;
    final dx = (ls.x - rs.x) * w;
    final dy = (ls.y - rs.y) * h;
    final shoulderWidth = math.sqrt(dx * dx + dy * dy);
    final targetBoxW = math.max(shoulderWidth * reachFactor, 40.0);

    _cx = _cx == null ? sx : _cx! + (sx - _cx!) * boxSmoothing;
    _cy = _cy == null ? sy : _cy! + (sy - _cy!) * boxSmoothing;
    _boxW = _boxW == null ? targetBoxW : _boxW! + (targetBoxW - _boxW!) * boxSmoothing;

    final boxW = _boxW!;
    final boxH = boxW / screenAspect;
    final cx = _cx!;
    final cy = _cy! - boxH * 0.12; // hơi cao hơn vai: giơ tay lên là tự nhiên

    Offset? mapHand(int wrist, int index, int fx, int fy) {
      final a = lm[wrist];
      final b = lm[index];
      final slot = fx ~/ 2;
      if (!a.visible) {
        final held = _lastHand[slot];
        if (held != null && frame.arrival - _lastHandAt[slot] <= handHold) return held;
        _filters[fx].reset();
        _filters[fy].reset();
        _lastHand[slot] = null;
        return null;
      }
      final hx = (b.visible ? (a.x + b.x) / 2 : a.x) * w;
      final hy = (b.visible ? (a.y + b.y) / 2 : a.y) * h;
      final u = ((hx - cx) / boxW + 0.5).clamp(-0.1, 1.1).toDouble();
      final v = ((hy - cy) / boxH + 0.5).clamp(-0.1, 1.1).toDouble();
      final out = Offset(
        _filters[fx].filter(u, frame.arrival),
        _filters[fy].filter(v, frame.arrival),
      );
      _lastHand[slot] = out;
      _lastHandAt[slot] = frame.arrival;
      return out;
    }

    final a = mapHand(PoseIdx.leftWrist, PoseIdx.leftIndex, 0, 1);
    final b = mapHand(PoseIdx.rightWrist, PoseIdx.rightIndex, 2, 3);

    // Sắp theo vị trí trên màn hình để "left" luôn là tay bên trái màn hình.
    if (a != null && b != null && a.dx > b.dx) {
      return state = HandState(b, a);
    }
    if (a == null && b != null) {
      return state = b.dx < 0.5 ? HandState(b, null) : HandState(null, b);
    }
    if (b == null && a != null) {
      return state = a.dx < 0.5 ? HandState(a, null) : HandState(null, a);
    }
    return state = HandState(a, b);
  }
}
