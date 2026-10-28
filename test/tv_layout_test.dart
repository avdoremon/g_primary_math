import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/ui/theme/theme.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

void main() {
  test('vùng đáp án nằm trong 38–88% chiều cao và tránh 8% hai bên', () {
    expect(TvLayout.answerZone.top, closeTo(410.4, 0.01));
    expect(TvLayout.answerZone.bottom, closeTo(950.4, 0.01));
    expect(TvLayout.answerZone.left, closeTo(153.6, 0.01));
    expect(TvLayout.answerZone.right, closeTo(1766.4, 0.01));
  });

  test('vùng chạm tối thiểu >= 15% chiều rộng', () {
    expect(TvLayout.minTouch / TvLayout.width, greaterThanOrEqualTo(0.15));
  });

  test('cỡ chữ TV đạt yêu cầu đọc từ xa', () {
    expect(TvText.answerNumber.fontSize! / TvLayout.height, greaterThanOrEqualTo(0.12));
    expect(TvText.question.fontSize! / TvLayout.height, greaterThanOrEqualTo(0.07));
  });

  test('đổi toạ độ màn hình thật sang khung 1920×1080', () {
    // Màn 2400×1080 (rộng hơn 16:9): khung co theo chiều cao, thừa hai bên 240px.
    const viewport = Size(2400, 1080);
    expect(TvStage.toStage(const Offset(240, 0), viewport), const Offset(0, 0));
    expect(TvStage.toStage(const Offset(1200, 540), viewport), const Offset(960, 540));
  });

  test('mỗi vị trí đáp án có màu và hình riêng', () {
    final shapes = AnswerSlotStyle.slots.map((s) => s.shape).toSet();
    final colors = AnswerSlotStyle.slots.map((s) => s.color).toSet();
    expect(shapes.length, 4);
    expect(colors.length, 4);
    expect(colors.contains(TvdColors.correct), isFalse);
    expect(colors.contains(TvdColors.encourage), isFalse);
  });
}
