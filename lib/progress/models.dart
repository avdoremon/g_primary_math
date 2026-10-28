import 'dart:math' as math;

import '../game/session.dart';

/// Hồ sơ một bé. Không đăng nhập: hồ sơ chỉ nằm trên máy.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.grade,
    this.avatar = 0,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// Lớp đang học (1–5), quyết định chương trình mở ra trước.
  final int grade;

  /// Chỉ số hình đại diện (màu/biểu tượng), do màn hồ sơ quy định.
  final int avatar;
  final DateTime createdAt;

  Profile copyWith({String? name, int? grade, int? avatar}) =>
      Profile(id: id, name: name ?? this.name, grade: grade ?? this.grade, avatar: avatar ?? this.avatar, createdAt: createdAt);

  @override
  bool operator ==(Object other) =>
      other is Profile && other.id == id && other.name == name && other.grade == grade && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, name, grade, avatar);

  @override
  String toString() => 'Profile($id, $name, lớp $grade)';
}

/// Khoá một level trong một lớp.
typedef LevelKey = ({String topic, int level});

/// Thành tích tốt nhất của một level.
class LevelRecord {
  const LevelRecord({
    required this.topicId,
    required this.level,
    this.bestStars = 0,
    this.bestScore = 0,
    this.bestCorrect = 0,
    this.plays = 0,
    this.lastPlayedAt,
  });

  final String topicId;
  final int level;
  final int bestStars;
  final int bestScore;
  final int bestCorrect;

  /// Số lượt chơi trọn vẹn.
  final int plays;
  final DateTime? lastPlayedAt;

  LevelKey get key => (topic: topicId, level: level);

  /// Gộp một lượt chơi mới vào thành tích. Lượt bỏ dở không thay đổi thành tích.
  LevelRecord merge(SessionResult r) {
    if (r.incomplete) return this;
    return LevelRecord(
      topicId: topicId,
      level: level,
      bestStars: math.max(bestStars, r.stars),
      bestScore: math.max(bestScore, r.score),
      bestCorrect: math.max(bestCorrect, r.correct),
      plays: plays + 1,
      lastPlayedAt: r.startedAt,
    );
  }
}

/// Một dòng lịch sử trả lời (cho màn phụ huynh: con hay sai dạng nào).
class AnswerLogEntry {
  const AnswerLogEntry({
    required this.startedAt,
    required this.grade,
    required this.topicId,
    required this.level,
    required this.generator,
    required this.prompt,
    required this.chosen,
    required this.correctOption,
    required this.outcome,
    required this.elapsed,
  });

  factory AnswerLogEntry.of(SessionResult s, AnswerRecord a) => AnswerLogEntry(
        startedAt: s.startedAt,
        grade: s.grade,
        topicId: s.topicId,
        level: s.level,
        generator: a.question.generator,
        prompt: a.question.prompt,
        chosen: a.chosen == null ? null : a.question.options[a.chosen!],
        correctOption: a.question.correctOption,
        outcome: a.outcome,
        elapsed: a.elapsed,
      );

  /// Thời điểm bắt đầu lượt chơi chứa câu này.
  final DateTime startedAt;
  final int grade;
  final String topicId;
  final int level;
  final String generator;
  final String prompt;

  /// Đáp án bé chọn (chữ hiển thị); null khi hết giờ / mini game không có ô đáp án.
  final String? chosen;
  final String correctOption;
  final AnswerOutcome outcome;
  final Duration elapsed;

  bool get correct => outcome == AnswerOutcome.correct;
}
