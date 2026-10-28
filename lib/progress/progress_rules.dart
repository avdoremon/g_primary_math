import '../content/curriculum.dart';
import 'models.dart';

/// Luật mở khoá và tổng hợp sao.
///
/// - Mọi chủ đề đều mở (phụ huynh/bé chọn theo bài đang học trên lớp).
/// - Trong một chủ đề, level 1 luôn mở; level sau mở khi level trước đạt ít nhất 1 sao.
abstract class ProgressRules {
  static int starsOf(Map<LevelKey, LevelRecord> records, String topicId, int level) =>
      records[(topic: topicId, level: level)]?.bestStars ?? 0;

  static bool isUnlocked(Map<LevelKey, LevelRecord> records, String topicId, int level) =>
      level <= 1 || starsOf(records, topicId, level - 1) >= 1;

  /// Tổng sao của một chủ đề (tối đa 3 × số level).
  static int topicStars(Map<LevelKey, LevelRecord> records, Topic topic) =>
      topic.levels.fold(0, (sum, l) => sum + starsOf(records, topic.id, l.level));

  static int maxTopicStars(Topic topic) => topic.levels.length * 3;

  static int gradeStars(Map<LevelKey, LevelRecord> records, Grade grade) =>
      grade.topics.fold(0, (sum, t) => sum + topicStars(records, t));

  /// Level nên chơi tiếp trong chủ đề: level mở cao nhất chưa có sao,
  /// nếu mọi level đã có sao thì level thấp nhất chưa đủ 3 sao, nếu đã đủ hết thì null.
  static Level? suggestedLevel(Map<LevelKey, LevelRecord> records, Topic topic) {
    for (final l in topic.levels) {
      if (isUnlocked(records, topic.id, l.level) && starsOf(records, topic.id, l.level) == 0) return l;
    }
    for (final l in topic.levels) {
      if (starsOf(records, topic.id, l.level) < 3) return l;
    }
    return null;
  }
}
