import 'package:flutter/painting.dart';

import 'colors.dart';

abstract class TvdFonts {
  static const display = 'Baloo2'; // tiêu đề, chữ số
  static const body = 'Nunito'; // nội dung, nút, menu
}

TextStyle _style(String family, FontWeight weight, double size, double lineHeight, [Color color = TvdColors.ink]) =>
    TextStyle(
      fontFamily: family,
      fontWeight: weight,
      fontSize: size,
      height: lineHeight / size,
      color: color,
    );

/// Kiểu chữ màn TV. Cỡ tính theo pixel của khung 1920×1080 (xem TvStage),
/// khung được co giãn theo màn hình thật nên tỉ lệ luôn giữ đúng design.
abstract class TvText {
  /// Số đáp án: 160px = 14,8% chiều cao.
  static final answerNumber = _style(TvdFonts.display, FontWeight.w800, 160, 160);
  static final bigCounter = _style(TvdFonts.display, FontWeight.w800, 280, 280);

  /// Đề bài: 88px = 8,1% chiều cao.
  static final question = _style(TvdFonts.display, FontWeight.w800, 88, 96);
  static final prompt = _style(TvdFonts.display, FontWeight.w700, 64, 72);
  static final button = _style(TvdFonts.display, FontWeight.w800, 56, 64);
  static final label = _style(TvdFonts.body, FontWeight.w800, 40, 48);
}

/// Kiểu chữ màn điện thoại (390×844).
abstract class PhoneText {
  static final titleLarge = _style(TvdFonts.display, FontWeight.w800, 34, 40);
  static final title = _style(TvdFonts.display, FontWeight.w700, 26, 32);
  static final item = _style(TvdFonts.body, FontWeight.w800, 20, 26);
  static final body = _style(TvdFonts.body, FontWeight.w600, 17, 24);
  static final button = _style(TvdFonts.body, FontWeight.w800, 18, 24);
  static final caption = _style(TvdFonts.body, FontWeight.w700, 14, 20, TvdColors.inkSoft);
}
