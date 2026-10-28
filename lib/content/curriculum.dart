import 'dart:convert';
import 'dart:math' as math;

import 'generators/generator.dart';
import 'generators/registry.dart';
import 'question.dart';

/// Mini game hiện có (khớp mục "Mini game" trong kế hoạch).
abstract class MiniGames {
  static const balloon = 'balloon'; // Bóng bay phép tính (C)
  static const sides = 'sides'; // Bên nào lớn hơn / Đúng hay sai (B)
  static const jumpCount = 'jump_count'; // Nhảy đếm (Đ)
  static const humanClock = 'human_clock'; // Đồng hồ người (T)
  static const shapeHunt = 'shape_hunt'; // Săn hình (C)
  static const simonSays = 'simon_says'; // Con nói, con làm (T, C, B)

  static const all = {balloon, sides, jumpCount, humanClock, shapeHunt, simonSays};

  static const titles = {
    balloon: 'Bóng bay phép tính',
    sides: 'Bên nào lớn hơn',
    jumpCount: 'Nhảy đếm',
    humanClock: 'Đồng hồ người',
    shapeHunt: 'Săn hình',
    simonSays: 'Con nói, con làm',
  };

  static String title(String id) => titles[id] ?? id;
}

/// Mức gợi ý (design G7): level 1–3 dùng mức dễ (nhãn TRÁI/PHẢI, linh vật làm mẫu, tô từ khóa),
/// level 4–5 dùng mức khó (ẩn gợi ý, có thể có lệnh ghép).
enum HintLevel { easy, hard }

class Level {
  Level({
    required this.level,
    required this.questions,
    required this.secondsPerQuestion,
    required this.generator,
    required this.params,
    required this.answers,
    required this.miniGame,
    HintLevel? hints,
  }) : hints = hints ?? (level <= 3 ? HintLevel.easy : HintLevel.hard);

  final int level;
  final int questions;

  /// 0 = không giới hạn (chế độ luyện tập vẫn bỏ giới hạn ở mọi level).
  final int secondsPerQuestion;
  final String generator;
  final Map<String, Object?> params;
  final int answers;
  final String miniGame;
  final HintLevel hints;

  GenParams get genParams => GenParams(params, answers: answers);

  Question generate(math.Random r) => Generators.byId[generator]!.generate(genParams, r);

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        level: (j['level'] as num).toInt(),
        questions: (j['questions'] as num?)?.toInt() ?? 10,
        secondsPerQuestion: (j['secondsPerQuestion'] as num?)?.toInt() ?? 12,
        generator: j['generator'] as String,
        params: Map<String, Object?>.from(j['params'] as Map? ?? const {}),
        answers: (j['answers'] as num?)?.toInt() ?? 3,
        miniGame: j['miniGame'] as String? ?? MiniGames.balloon,
        hints: switch (j['hints']) {
          'easy' => HintLevel.easy,
          'hard' => HintLevel.hard,
          _ => null,
        },
      );
}

class Topic {
  Topic({required this.id, required this.title, required this.sgkOrder, required this.levels, this.icon});

  final String id;
  final String title;

  /// Thứ tự chủ đề theo SGK Toán (Kết nối tri thức với cuộc sống).
  final int sgkOrder;
  final String? icon;
  final List<Level> levels;

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'] as String,
        title: j['title'] as String,
        sgkOrder: (j['sgkOrder'] as num?)?.toInt() ?? 0,
        icon: j['icon'] as String?,
        levels: [for (final l in j['levels'] as List<dynamic>) Level.fromJson(l as Map<String, dynamic>)],
      );
}

class Grade {
  Grade({required this.grade, required this.title, required this.topics});

  final int grade;
  final String title;
  final List<Topic> topics;

  factory Grade.fromJson(Map<String, dynamic> j) {
    final topics = [for (final t in j['topics'] as List<dynamic>) Topic.fromJson(t as Map<String, dynamic>)]
      ..sort((a, b) => a.sgkOrder.compareTo(b.sgkOrder));
    return Grade(grade: (j['grade'] as num).toInt(), title: j['title'] as String? ?? 'Lớp ${j['grade']}', topics: topics);
  }

  static Grade parse(String json) => Grade.fromJson(jsonDecode(json) as Map<String, dynamic>);

  /// Kiểm tra toàn bộ chương trình; trả về danh sách lỗi (rỗng = hợp lệ).
  List<String> validate() {
    final errors = <String>[];
    final ids = <String>{};
    for (final t in topics) {
      if (!ids.add(t.id)) errors.add('Trùng mã chủ đề "${t.id}"');
      if (t.levels.length != 5) errors.add('${t.id}: cần đúng 5 level, đang có ${t.levels.length}');
      for (final l in t.levels) {
        final where = '${t.id} level ${l.level}';
        final g = Generators.byId[l.generator];
        if (g == null) {
          errors.add('$where: không có dạng bài "${l.generator}"');
          continue;
        }
        if (!MiniGames.all.contains(l.miniGame)) errors.add('$where: không có mini game "${l.miniGame}"');
        if (l.answers < 1 || l.answers > 4) errors.add('$where: answers phải từ 1 đến 4');
        if (l.questions < 1) errors.add('$where: questions phải ≥ 1');
        if (l.secondsPerQuestion < 0) errors.add('$where: secondsPerQuestion không được âm');
        errors.addAll(g.validate(l.genParams).map((e) => '$where: $e'));
      }
    }
    return errors;
  }
}
