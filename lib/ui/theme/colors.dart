import 'package:flutter/painting.dart';

/// Bảng màu theo design system đợt 1 (Claude Design).
/// Không dùng đỏ và đen tuyền. Màu đáp án luôn đi kèm một hình cố định.
abstract class TvdColors {
  // Nền và chữ
  static const ink = Color(0xFF1F2A44); // chữ chính, viền nút phụ
  static const inkSoft = Color(0xFF5B6782); // chữ phụ (>= 16px)
  static const line = Color(0xFFE4E7EE); // đường kẻ, rãnh thanh tiến trình
  static const cream = Color(0xFFFFF8EC); // nền điện thoại
  static const sky = Color(0xFFDDF0FF); // nền TV
  static const white = Color(0xFFFFFFFF); // thẻ, ô đáp án
  static const floor = Color(0xFFF6E7CF); // sàn trong cảnh TV
  static const cardShadow = Color(0xFFC6D6EA); // bóng phẳng của thẻ trắng trên nền trời

  // Phản hồi
  static const correct = Color(0xFF22B26B);
  static const correctDark = Color(0xFF0F6B3E);
  static const correctSoft = Color(0xFFDDF6E8);
  static const encourage = Color(0xFFFF9A3D);
  static const encourageDark = Color(0xFFA85A12);
  static const encourageSoft = Color(0xFFFFEEDD);
  static const encourageShadow = Color(0xFFC46F1E);

  // 4 vị trí đáp án (màu + bóng đổ đậm hơn một bậc)
  static const answerA = Color(0xFF2F80ED); // tròn; cũng là màu nút chính, nhãn PHẢI
  static const answerADark = Color(0xFF1C5FBF);
  static const answerB = Color(0xFFFFC53D); // vuông; nhãn TRÁI
  static const answerBDark = Color(0xFFE0A21A);
  static const answerC = Color(0xFF8E6CEF); // tam giác
  static const answerCDark = Color(0xFF6646C9);
  static const answerD = Color(0xFFF2609E); // ngôi sao
  static const answerDDark = Color(0xFFC93C78);

  // Linh vật và phần thưởng
  static const star = Color(0xFFFFB800);
  static const mascotFur = Color(0xFFC8572E);
  static const mascotStripe = Color(0xFF9E3F1E);
  static const mascotDark = Color(0xFF4A2A20);
  static const mascotCream = Color(0xFFFFF1DC);

  // Quy ước trái/phải (G7): vàng = TRÁI, xanh dương = PHẢI, luôn kèm chữ và biểu tượng.
  static const left = answerB;
  static const right = answerA;
}

/// Hình đi kèm mỗi vị trí đáp án (cho trẻ mù màu).
enum AnswerShape { circle, square, triangle, star }

class AnswerSlotStyle {
  const AnswerSlotStyle(this.color, this.shadow, this.shape, this.onColor);

  final Color color;
  final Color shadow;
  final AnswerShape shape;

  /// Màu chữ/biểu tượng khi đặt trên nền [color].
  final Color onColor;

  static const slots = <AnswerSlotStyle>[
    AnswerSlotStyle(TvdColors.answerA, TvdColors.answerADark, AnswerShape.circle, TvdColors.white),
    AnswerSlotStyle(TvdColors.answerB, TvdColors.answerBDark, AnswerShape.square, TvdColors.ink),
    AnswerSlotStyle(TvdColors.answerC, TvdColors.answerCDark, AnswerShape.triangle, TvdColors.white),
    AnswerSlotStyle(TvdColors.answerD, TvdColors.answerDDark, AnswerShape.star, TvdColors.white),
  ];
}
