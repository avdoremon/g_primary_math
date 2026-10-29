import 'dart:async';

import 'package:flutter/material.dart';

import '../app/services.dart';
import '../app/tv_mode.dart';
import '../content/curriculum.dart';
import '../game/play_guard.dart';
import '../game/practice.dart';
import '../progress/models.dart';
import '../ui/widgets/tin_tin.dart';
import 'common.dart';
import 'connect_tv_screen.dart';
import 'play/play_screen.dart';

/// Vào màn chơi từ menu điện thoại (chọn level, luyện tập thêm, luyện chỗ còn sai).
///
/// Kiểm tra giới hạn giờ chơi và nhắc nghỉ, lần đầu chơi thì hiện hướng dẫn kết nối TV,
/// rồi mở màn chơi ngang.
Future<void> launchPlay(
  BuildContext context, {
  required Profile profile,
  required Grade grade,
  required Topic topic,
  int levelIndex = 0,
  PracticePlan? practice,
}) async {
  final app = AppScope.of(context);
  final guard = await app.guardFor(profile.id);
  if (!context.mounted) return;
  switch (guard.check()) {
    case GuardVerdict.dailyLimitReached:
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const TinTin(state: TinTinState.wait, size: 96),
          title: const Text('Hôm nay con chơi đủ rồi!'),
          content: Text(
            'Đã chơi ${formatMinutes(guard.playedToday)} hôm nay. '
            'Phụ huynh có thể đổi giới hạn trong khu phụ huynh.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đồng ý'))],
        ),
      );
      return;
    case GuardVerdict.takeBreak:
      final rested = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _BreakDialog(),
      );
      if (rested != true || !context.mounted) return;
      guard.breakTaken();
    case GuardVerdict.ok:
      break;
  }
  if (!context.mounted) return;
  await ConnectTvScreen.showOnce(context, app);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TvModeScope(
        child: PlayScreen(profile: profile, grade: grade, topic: topic, levelIndex: levelIndex, practice: practice),
      ),
    ),
  );
}

/// Màn nghỉ trên điện thoại khi bé chơi liên tục quá lâu (bắt đầu level từ menu).
class _BreakDialog extends StatefulWidget {
  const _BreakDialog();

  @override
  State<_BreakDialog> createState() => _BreakDialogState();
}

class _BreakDialogState extends State<_BreakDialog> {
  late int _left = PlayGuard.breakLength.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 0) return;
      setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const TinTin(state: TinTinState.wait, size: 96),
      title: const Text('Nghỉ một chút nhé!'),
      content: Text(
        'Con uống nước, nhìn ra xa cho mắt nghỉ ngơi.\n'
        '${_left > 0 ? 'Còn ${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}' : 'Chơi tiếp được rồi!'}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Để sau')),
        FilledButton(
          onPressed: _left > 0 ? null : () => Navigator.of(context).pop(true),
          child: const Text('Chơi tiếp'),
        ),
      ],
    );
  }
}
