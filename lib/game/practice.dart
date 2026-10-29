import 'dart:math' as math;

import '../content/curriculum.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../progress/weak_skills.dart';

enum PracticeKind {
  /// Luyện tập thêm một chủ đề: trộn câu từ các level đã mở.
  topic,

  /// Luyện chỗ còn sai: câu từ những dạng bài bé vừa sai gần đây.
  mistakes,
}

/// Một lượt luyện tập: 10 câu, mỗi câu lấy từ một level trong [pool].
///
/// Mọi level trong [pool] dùng chung một mini game để bé không phải đổi cách chơi giữa lượt.
/// Lượt luyện tập có điểm nhưng lưu với level 0 nên không đổi sao của level nào.
class PracticePlan {
  PracticePlan({required this.kind, required this.topic, required this.pool}) : assert(pool.isNotEmpty);

  final PracticeKind kind;
  final Topic topic;
  final List<Level> pool;

  Level get base => pool.first;
  String get miniGame => base.miniGame;

  String get title => switch (kind) {
        PracticeKind.topic => 'Luyện tập thêm',
        PracticeKind.mistakes => 'Luyện chỗ còn sai',
      };

  /// Luyện tập thêm [topic]: chọn ngẫu nhiên một mini game trong các level đã mở,
  /// rồi lấy mọi level đã mở có mini game đó. Mỗi lượt sau có thể ra mini game khác.
  static PracticePlan forTopic(Topic topic, Map<LevelKey, LevelRecord> records, math.Random r) {
    final open = [for (final l in topic.levels) if (ProgressRules.isUnlocked(records, topic.id, l.level)) l];
    final levels = open.isEmpty ? [topic.levels.first] : open;
    final games = {for (final l in levels) l.miniGame}.toList();
    final game = games[r.nextInt(games.length)];
    return PracticePlan(
      kind: PracticeKind.topic,
      topic: topic,
      pool: [for (final l in levels) if (l.miniGame == game) l],
    );
  }

  /// Luyện chỗ còn sai trong [grade]: lấy dạng bài sai nhiều nhất gần đây, cùng các dạng bài
  /// khác bé cũng sai trong cùng chủ đề và cùng mini game. null khi gần đây bé không sai câu nào.
  static PracticePlan? forMistakes(Grade grade, List<AnswerLogEntry> log, math.Random r) {
    final weak = WeakSkills.analyze(log, grade: grade.grade, minAnswers: 1, below: 1, limit: 20);
    for (final top in weak) {
      final topic = grade.topics.where((t) => t.id == top.topicId).firstOrNull;
      if (topic == null) continue;
      final gens = {for (final s in weak) if (s.topicId == topic.id) s.generator};
      final first = topic.levels.where((l) => l.generator == top.generator).toList();
      if (first.isEmpty) continue;
      final game = first[r.nextInt(first.length)].miniGame;
      return PracticePlan(
        kind: PracticeKind.mistakes,
        topic: topic,
        pool: [for (final l in topic.levels) if (gens.contains(l.generator) && l.miniGame == game) l],
      );
    }
    return null;
  }

  /// Lượt kế tiếp cùng loại (nút "Luyện tiếp" trên TV).
  PracticePlan next(Grade grade, Map<LevelKey, LevelRecord> records, List<AnswerLogEntry> log, math.Random r) =>
      switch (kind) {
        PracticeKind.topic => forTopic(topic, records, r),
        PracticeKind.mistakes => forMistakes(grade, log, r) ?? forTopic(topic, records, r),
      };
}
