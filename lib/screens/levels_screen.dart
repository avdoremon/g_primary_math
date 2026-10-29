import 'dart:async';

import 'package:flutter/material.dart';

import '../app/services.dart';
import '../app/tv_mode.dart';
import '../content/curriculum.dart';
import '../game/play_guard.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import 'common.dart';
import 'play/play_screen.dart';

/// 5 level của một chủ đề. Level 1 luôn mở; level sau mở khi level trước được ít nhất 1 sao.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.profile, required this.grade, required this.topic});

  final Profile profile;
  final Grade grade;
  final Topic topic;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late final AppServices _app = AppScope.of(context);
  Map<LevelKey, LevelRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _app.store.levelRecords(widget.profile.id, widget.grade.grade);
    if (mounted) setState(() => _records = r);
  }

  Future<void> _play(int index) async {
    final guard = await _app.guardFor(widget.profile.id);
    if (!mounted) return;
    switch (guard.check()) {
      case GuardVerdict.dailyLimitReached:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const TinTin(state: TinTinState.wait, size: 96),
            title: const Text('Hôm nay con chơi đủ rồi!'),
            content: Text(
              'Đã chơi ${formatMinutes(guard.playedToday)} hôm nay. '
              'Phụ huynh có thể đổi giới hạn trong phần cài đặt.',
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
        if (rested != true || !mounted) return;
        guard.breakTaken();
      case GuardVerdict.ok:
        break;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TvModeScope(
          child: PlayScreen(profile: widget.profile, grade: widget.grade, topic: widget.topic, levelIndex: index),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title, maxLines: 2)),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(TvdSpace.s4),
              children: [
                for (final (i, l) in widget.topic.levels.indexed) _tile(i, l, records),
                const SizedBox(height: TvdSpace.s4),
                Text(
                  'Khi bắt đầu, màn hình tự xoay ngang. Bé đứng cách TV 2–3 m, giơ hai tay lên để bắt đầu.',
                  style: PhoneText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _tile(int index, Level l, Map<LevelKey, LevelRecord> records) {
    final open = ProgressRules.isUnlocked(records, widget.topic.id, l.level);
    final rec = records[(topic: widget.topic.id, level: l.level)];
    final seconds = _app.settings.practiceMode || l.secondsPerQuestion == 0 ? 'không đếm giờ' : '${l.secondsPerQuestion} giây/câu';
    return TvdCard(
      enabled: open,
      onTap: () => _play(index),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: open ? TvdColors.answerA : TvdColors.line,
            child: open
                ? Text('${l.level}', style: PhoneText.title.copyWith(color: TvdColors.white))
                : const Icon(Icons.lock_outline, color: TvdColors.inkSoft),
          ),
          const SizedBox(width: TvdSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${l.level} · ${MiniGames.title(l.miniGame)}', style: PhoneText.item),
                Text(
                  open
                      ? '${l.questions} câu · $seconds${rec != null && rec.plays > 0 ? ' · cao nhất ${rec.bestScore} điểm' : ''}'
                      : 'Đạt 1 sao ở level ${l.level - 1} để mở',
                  style: PhoneText.caption,
                ),
              ],
            ),
          ),
          LevelStars(stars: rec?.bestStars ?? 0),
        ],
      ),
    );
  }
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
