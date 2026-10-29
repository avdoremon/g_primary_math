import '../content/curriculum.dart';
import 'models.dart';

/// Luật mở khoá và tổng hợp sao.
///
/// - Chủ đề đầu tiên của lớp luôn mở. Chủ đề sau mở khi chủ đề trước đạt ít nhất [topicUnlockStars] sao,
///   hoặc khi bé đã từng có sao ở chính chủ đề đó (giữ tiến độ cũ). Phụ huynh có thể mở tất cả chủ đề.
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

  /// Số sao ở chủ đề trước cần có để mở chủ đề sau (khoảng ba level đầu, mỗi level một sao).
  static const topicUnlockStars = 3;

  /// Chủ đề thứ [index] (theo thứ tự SGK) của [grade] đã mở chưa.
  static bool isTopicUnlocked(Map<LevelKey, LevelRecord> records, Grade grade, int index, {bool unlockAll = false}) {
    if (unlockAll || index <= 0) return true;
    if (index >= grade.topics.length) return false;
    if (topicStars(records, grade.topics[index]) > 0) return true;
    return topicStars(records, grade.topics[index - 1]) >= topicUnlockStars;
  }

  /// Chủ đề bé đang học (Tin Tin đứng ở đây trên Đường phiêu lưu): chủ đề mở đầu tiên chưa đủ
  /// [topicUnlockStars] sao; nếu mọi chủ đề mở đã qua thì chủ đề mở cuối cùng.
  static int currentTopicIndex(Map<LevelKey, LevelRecord> records, Grade grade, {bool unlockAll = false}) {
    var lastOpen = 0;
    for (var i = 0; i < grade.topics.length; i++) {
      if (!isTopicUnlocked(records, grade, i, unlockAll: unlockAll)) break;
      lastOpen = i;
      if (topicStars(records, grade.topics[i]) < topicUnlockStars) return i;
    }
    return lastOpen;
  }

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
