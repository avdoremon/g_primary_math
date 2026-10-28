import 'package:flutter/material.dart';

import '../app/services.dart';
import '../content/curriculum.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../ui/theme/theme.dart';
import 'common.dart';
import 'levels_screen.dart';

/// Danh sách chủ đề của một lớp theo thứ tự SGK, kèm số sao đã đạt.
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key, required this.profile, required this.grade});

  final Profile profile;
  final Grade grade;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  late final AppServices _app = AppScope.of(context);
  late Grade _grade = widget.grade;
  Map<LevelKey, LevelRecord>? _records;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _app.store.levelRecords(widget.profile.id, _grade.grade);
    final score = await _app.store.totalScore(widget.profile.id, grade: _grade.grade);
    if (mounted) {
      setState(() {
        _records = records;
        _score = score;
      });
    }
  }

  void _switchGrade(int g) {
    final grade = _app.curriculum.grade(g);
    if (grade == null) return;
    setState(() {
      _grade = grade;
      _records = null;
    });
    _load();
  }

  Future<void> _open(Topic t) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LevelsScreen(profile: widget.profile, grade: _grade, topic: t)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ProfileAvatar(name: widget.profile.name, avatar: widget.profile.avatar, size: 36),
            const SizedBox(width: TvdSpace.s3),
            Expanded(child: Text(widget.profile.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(TvdSpace.s4),
              children: [
                Wrap(
                  spacing: TvdSpace.s2,
                  children: [
                    for (final g in CurriculumLibrary.availableGrades)
                      ChoiceChip(
                        label: Text('Lớp $g'),
                        selected: _grade.grade == g,
                        onSelected: (_) => _switchGrade(g),
                      ),
                  ],
                ),
                const SizedBox(height: TvdSpace.s3),
                Row(
                  children: [
                    Expanded(child: Text(_grade.title, style: PhoneText.title)),
                    StarCount(stars: ProgressRules.gradeStars(records, _grade)),
                    const SizedBox(width: TvdSpace.s3),
                    Text('$_score điểm', style: PhoneText.caption),
                  ],
                ),
                const SizedBox(height: TvdSpace.s3),
                for (final (i, t) in _grade.topics.indexed)
                  TvdCard(
                    onTap: () => _open(t),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AnswerSlotStyle.slots[i % 4].color,
                          foregroundColor: AnswerSlotStyle.slots[i % 4].onColor,
                          child: Text('${i + 1}', style: PhoneText.item.copyWith(color: AnswerSlotStyle.slots[i % 4].onColor)),
                        ),
                        const SizedBox(width: TvdSpace.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, style: PhoneText.item),
                              const SizedBox(height: TvdSpace.s2),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(TvdRadius.pill),
                                child: LinearProgressIndicator(
                                  value: ProgressRules.topicStars(records, t) / ProgressRules.maxTopicStars(t),
                                  minHeight: 8,
                                  color: TvdColors.star,
                                  backgroundColor: TvdColors.line,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: TvdSpace.s3),
                        StarCount(stars: ProgressRules.topicStars(records, t), max: ProgressRules.maxTopicStars(t)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
