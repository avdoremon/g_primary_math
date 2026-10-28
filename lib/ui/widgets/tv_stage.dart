import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Khung vẽ cho mọi màn TV: con của TvStage được bố cục trên canvas 1920×1080
/// (đúng đơn vị pixel trong design), rồi co giãn vừa màn hình thật, giữ tỉ lệ 16:9.
/// Phần thừa (nếu màn hình không đúng 16:9) tô màu [background].
class TvStage extends StatelessWidget {
  const TvStage({super.key, required this.child, this.background = TvdColors.sky});

  final Widget child;
  final Color background;

  /// Đổi một điểm trên màn hình thật (vd. vị trí chạm) sang toạ độ khung 1920×1080.
  static Offset toStage(Offset local, Size viewport) {
    final scale = _scale(viewport);
    final dx = (viewport.width - TvLayout.width * scale) / 2;
    final dy = (viewport.height - TvLayout.height * scale) / 2;
    return Offset((local.dx - dx) / scale, (local.dy - dy) / scale);
  }

  static double _scale(Size viewport) {
    final sx = viewport.width / TvLayout.width;
    final sy = viewport.height / TvLayout.height;
    return sx < sy ? sx : sy;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: TvLayout.width,
            height: TvLayout.height,
            child: ClipRect(
              child: MediaQuery(
                // Trong khung TV không áp cỡ chữ hệ thống: bố cục đã tính sẵn cho màn lớn.
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lớp phủ hiển thị các vùng bố cục (chỉ dùng khi phát triển).
class TvLayoutGuides extends StatelessWidget {
  const TvLayoutGuides({super.key});

  @override
  Widget build(BuildContext context) {
    Widget zone(Rect r, Color c, String label) => Positioned.fromRect(
          rect: r,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              border: Border.all(color: c, width: 4),
              borderRadius: BorderRadius.circular(TvdRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(label, style: TvText.label.copyWith(color: c)),
            ),
          ),
        );
    return IgnorePointer(
      child: Stack(
        children: [
          zone(TvLayout.safeArea, TvdColors.inkSoft, 'Vùng an toàn 5%'),
          zone(TvLayout.answerZone, TvdColors.answerA, 'Vùng đáp án 38–88%'),
          zone(TvLayout.bodyTile, TvdColors.correct, 'Ô bóng người'),
        ],
      ),
    );
  }
}
