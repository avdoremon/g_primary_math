import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/services.dart';
import '../content/curriculum.dart';
import '../game/practice.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../ui/theme/theme.dart';
import 'common.dart';
import 'play_launcher.dart';

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
    await launchPlay(context, profile: widget.profile, grade: widget.grade, topic: widget.topic, levelIndex: index);
    await _load();
  }

  /// Luyện tập thêm: câu mới mỗi lượt, trộn từ các level đã mở, không đổi sao.
  Future<void> _practice() async {
    final records = _records ?? await _app.store.levelRecords(widget.profile.id, widget.grade.grade);
    if (!mounted) return;
    final plan = PracticePlan.forTopic(widget.topic, records, math.Random());
    await launchPlay(context, profile: widget.profile, grade: widget.grade, topic: widget.topic, practice: plan);
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
                _practiceTile(),
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

  Widget _practiceTile() => TvdCard(
        key: const ValueKey('practice-more'),
        onTap: _practice,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: TvdColors.correct,
              child: Icon(Icons.all_inclusive_rounded, color: TvdColors.white),
            ),
            const SizedBox(width: TvdSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Luyện tập thêm', style: PhoneText.item),
                  Text('Câu mới mỗi lượt, trộn các level đã mở. Có điểm, không đổi sao.', style: PhoneText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: TvdColors.inkSoft),
          ],
        ),
      );

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
