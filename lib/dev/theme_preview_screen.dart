import 'package:flutter/material.dart';

import '../app/tv_mode.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import '../ui/widgets/tv_stage.dart';
import '../ui/widgets/tvd_button.dart';

/// Màn xem thử design system trên điện thoại, để so với artifact Claude Design.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  static const _swatches = <MapEntry<String, Color>>[
    MapEntry('Mực', TvdColors.ink),
    MapEntry('Mực nhạt', TvdColors.inkSoft),
    MapEntry('Viền', TvdColors.line),
    MapEntry('Kem', TvdColors.cream),
    MapEntry('Trời', TvdColors.sky),
    MapEntry('Đúng', TvdColors.correct),
    MapEntry('Động viên', TvdColors.encourage),
    MapEntry('A · Xanh dương', TvdColors.answerA),
    MapEntry('B · Vàng', TvdColors.answerB),
    MapEntry('C · Tím', TvdColors.answerC),
    MapEntry('D · Hồng', TvdColors.answerD),
    MapEntry('Sao vàng', TvdColors.star),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system'), backgroundColor: TvdColors.cream),
      body: ListView(
        padding: const EdgeInsets.all(TvdSpace.s5),
        children: [
          Text('Chào bé Na!', style: PhoneText.titleLarge),
          Text('Chọn lớp', style: PhoneText.title),
          Text('Phép cộng trong 10', style: PhoneText.item),
          Text('Đặt điện thoại cao ngang hông bé.', style: PhoneText.body),
          Text('Cập nhật hôm nay · Ằ Ẫ Ợ Ữ Ỹ', style: PhoneText.caption),
          const SizedBox(height: TvdSpace.s5),
          Wrap(
            spacing: TvdSpace.s3,
            runSpacing: TvdSpace.s3,
            children: [
              for (final sw in _swatches)
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: sw.value,
                          borderRadius: BorderRadius.circular(TvdRadius.sm),
                          border: Border.all(color: TvdColors.line),
                        ),
                      ),
                      const SizedBox(height: TvdSpace.s1),
                      Text(sw.key, style: PhoneText.caption),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: TvdSpace.s6),
          TvdButton(label: 'Bắt đầu chơi', onPressed: () {}),
          const SizedBox(height: TvdSpace.s3),
          TvdButton(label: 'Kết nối TV', kind: TvdButtonKind.secondary, icon: Icons.tv, onPressed: () {}),
          const SizedBox(height: TvdSpace.s3),
          TvdButton(label: 'Để sau', kind: TvdButtonKind.text, onPressed: () {}),
          const SizedBox(height: TvdSpace.s3),
          const TvdButton(label: 'Sắp ra mắt', icon: Icons.lock, onPressed: null),
          const SizedBox(height: TvdSpace.s6),
          Text('Linh vật Tin Tin', style: PhoneText.title),
          const SizedBox(height: TvdSpace.s3),
          Wrap(
            spacing: TvdSpace.s4,
            runSpacing: TvdSpace.s4,
            children: [
              for (final s in TinTinState.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [TinTin(state: s, size: 96), Text(s.label, style: PhoneText.caption)],
                ),
            ],
          ),
          const SizedBox(height: TvdSpace.s6),
          TvdButton(
            label: 'Xem khung TV 1920×1080',
            kind: TvdButtonKind.secondary,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TvModeScope(child: _TvPreview())),
            ),
          ),
          const SizedBox(height: TvdSpace.s7),
        ],
      ),
    );
  }
}

class _TvPreview extends StatelessWidget {
  const _TvPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: TvStage(
          child: Stack(
            children: [
              Positioned(
                left: TvLayout.safeX,
                right: TvLayout.safeX,
                top: TvLayout.safeY,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  decoration: BoxDecoration(
                    color: TvdColors.white,
                    borderRadius: BorderRadius.circular(TvdRadius.tv),
                    boxShadow: TvdShadow.tv(TvdColors.cardShadow),
                  ),
                  child: Text('7 + 5 = ?', style: TvText.question, textAlign: TextAlign.center),
                ),
              ),
              Positioned(
                left: TvLayout.answerZone.left,
                top: TvLayout.answerZone.top + 40,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: TvLayout.minTouch,
                        height: TvLayout.minTouch,
                        margin: const EdgeInsets.only(right: 48),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TvdColors.white,
                          border: Border.all(color: AnswerSlotStyle.slots[i].color, width: 10),
                          borderRadius: BorderRadius.circular(TvdRadius.tv),
                          boxShadow: TvdShadow.tv(AnswerSlotStyle.slots[i].shadow),
                        ),
                        child: Text('${const [10, 12, 11, 13][i]}', style: TvText.answerNumber),
                      ),
                  ],
                ),
              ),
              const Positioned(left: 120, bottom: 60, child: TinTin(state: TinTinState.hello, size: 240)),
              const TvLayoutGuides(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 70,
                child: Text('Chạm để quay lại', textAlign: TextAlign.center, style: TvText.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
