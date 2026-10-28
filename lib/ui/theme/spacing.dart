import 'package:flutter/painting.dart';

/// Khoảng cách theo bước 4 (space-1 … space-8). Màn TV dùng ×2.
abstract class TvdSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 64.0;

  static double tv(double phoneSpace) => phoneSpace * 2;
}

abstract class TvdRadius {
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const tv = 40.0;
  static const pill = 999.0;
}

/// Bóng đổ phẳng: lệch xuống, cùng màu đậm hơn một bậc, không làm mờ.
abstract class TvdShadow {
  static List<BoxShadow> phone(Color darker) => [BoxShadow(color: darker, offset: const Offset(0, 4))];
  static List<BoxShadow> tv(Color darker) => [BoxShadow(color: darker, offset: const Offset(0, 8))];
}

/// Quy tắc bố cục màn TV, tính theo khung 1920×1080.
abstract class TvLayout {
  static const width = 1920.0;
  static const height = 1080.0;
  static const size = Size(width, height);

  /// Vùng an toàn 5%: 96px hai bên, 54px trên dưới (một số TV cắt viền).
  static const safeX = 96.0;
  static const safeY = 54.0;
  static const safeArea = Rect.fromLTRB(safeX, safeY, width - safeX, height - safeY);

  /// Đáp án chỉ nằm trong 38–88% chiều cao, tránh dải 8% sát hai bên (tầm với của bé).
  static const answerZone = Rect.fromLTRB(width * 0.08, height * 0.38, width * 0.92, height * 0.88);

  /// Vùng chạm tối thiểu.
  static const minTouch = 320.0;

  /// Ô bóng người ở góc dưới phải. Không đặt đáp án đè lên vùng này.
  static const bodyTile = Rect.fromLTWH(width - safeX - 300, height - safeY - 340, 300, 340);

  /// Nút chọn bằng tay trên TV.
  static const handButtonHeight = 160.0;
  static const handButtonMinWidth = 420.0;
}
