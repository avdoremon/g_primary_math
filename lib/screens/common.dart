import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme/theme.dart';

/// Màu hình đại diện của hồ sơ (chỉ số lưu trong Profile.avatar).
const avatarColors = [
  TvdColors.answerA,
  TvdColors.answerB,
  TvdColors.answerC,
  TvdColors.answerD,
  TvdColors.correct,
  TvdColors.encourage,
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, required this.avatar, this.size = 56});

  final String name;
  final int avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = avatarColors[avatar % avatarColors.length];
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: TvdShadow.phone(TvdColors.cardShadow)),
      child: Text(
        initial,
        style: PhoneText.title.copyWith(
          color: color == TvdColors.answerB ? TvdColors.ink : TvdColors.white,
          fontSize: size * 0.45,
          height: 1,
        ),
      ),
    );
  }
}

/// Sao nhỏ trên điện thoại: "★ 7/15".
class StarCount extends StatelessWidget {
  const StarCount({super.key, required this.stars, this.max});

  final int stars;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: TvdColors.star, size: 22),
        const SizedBox(width: 2),
        Text(max == null ? '$stars' : '$stars/$max', style: PhoneText.item),
      ],
    );
  }
}

/// Ba sao của một level.
class LevelStars extends StatelessWidget {
  const LevelStars({super.key, required this.stars, this.size = 24});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < stars ? TvdColors.star : TvdColors.line,
            size: size,
          ),
      ],
    );
  }
}

/// Thẻ trắng bo góc dùng cho danh sách trên điện thoại.
class TvdCard extends StatelessWidget {
  const TvdCard({super.key, required this.child, this.onTap, this.onLongPress, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TvdSpace.s3),
      child: Material(
        color: enabled ? TvdColors.white : TvdColors.line.withAlpha(120),
        borderRadius: BorderRadius.circular(TvdRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(TvdRadius.md),
          onTap: enabled ? onTap : null,
          onLongPress: onLongPress,
          child: Padding(padding: const EdgeInsets.all(TvdSpace.s4), child: child),
        ),
      ),
    );
  }
}

/// Cổng phụ huynh: một phép nhân trẻ lớp 1–2 chưa làm được, để bé không tự đổi cài đặt.
Future<bool> showParentGate(BuildContext context) async {
  final r = math.Random();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _ParentGateDialog(a: 6 + r.nextInt(4), b: 6 + r.nextInt(4)),
  );
  return ok ?? false;
}

/// Hộp thoại giữ ô nhập trong State để ô nhập chỉ bị huỷ khi hộp thoại đã đóng hẳn
/// (huỷ ngay sau showDialog thì hiệu ứng đóng vẫn còn dùng ô nhập).
class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.a, required this.b});

  final int a;
  final int b;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String v) => Navigator.of(context).pop(int.tryParse(v.trim()) == widget.a * widget.b);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dành cho phụ huynh'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.a} × ${widget.b} = ?', style: PhoneText.titleLarge),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Nhập kết quả'),
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
        FilledButton(onPressed: () => _submit(_controller.text), child: const Text('Vào')),
      ],
    );
  }
}

String formatMinutes(Duration d) {
  final m = d.inMinutes;
  return m < 1 ? 'dưới 1 phút' : '$m phút';
}
