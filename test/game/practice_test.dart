import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/content/generators/generator.dart';
import 'package:g_primary_math/content/generators/registry.dart';
import 'package:g_primary_math/game/feedback.dart';
import 'package:g_primary_math/game/practice.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/progress/models.dart';
import 'package:g_primary_math/progress/progress_rules.dart';
import 'package:g_primary_math/progress/progress_store.dart';
import 'package:g_primary_math/progress/weak_skills.dart';

Grade loadGrade(int n) => Grade.parse(File('assets/content/grade$n.json').readAsStringSync());

Map<LevelKey, LevelRecord> starsMap(Map<(String, int), int> stars) => {
      for (final e in stars.entries)
        (topic: e.key.$1, level: e.key.$2): LevelRecord(topicId: e.key.$1, level: e.key.$2, bestStars: e.value),
    };

AnswerLogEntry entry(String topic, String gen, bool ok, {int grade = 1, int level = 1}) => AnswerLogEntry(
      startedAt: DateTime(2026, 10, 29),
      grade: grade,
      topicId: topic,
      level: level,
      generator: gen,
      prompt: '?',
      chosen: ok ? '1' : '2',
      correctOption: '1',
      outcome: ok ? AnswerOutcome.correct : AnswerOutcome.wrong,
      elapsed: const Duration(seconds: 2),
    );

void main() {
  final g1 = loadGrade(1);
  final t0 = g1.topics[0], t1 = g1.topics[1], t2 = g1.topics[2];

  group('Mở chủ đề trên Đường phiêu lưu', () {
    test('chủ đề đầu luôn mở, chủ đề sau khoá khi chủ đề trước chưa đủ 3 sao', () {
      final r = starsMap({(t0.id, 1): 2});
      expect(ProgressRules.isTopicUnlocked(r, g1, 0), isTrue);
      expect(ProgressRules.isTopicUnlocked(r, g1, 1), isFalse);
      expect(ProgressRules.currentTopicIndex(r, g1), 0);
    });

    test('chủ đề trước đủ 3 sao thì chủ đề sau mở, Tin Tin chuyển sang chủ đề sau', () {
      final r = starsMap({(t0.id, 1): 2, (t0.id, 2): 1});
      expect(ProgressRules.isTopicUnlocked(r, g1, 1), isTrue);
      expect(ProgressRules.isTopicUnlocked(r, g1, 2), isFalse);
      expect(ProgressRules.currentTopicIndex(r, g1), 1);
    });

    test('chủ đề đã từng có sao vẫn mở (giữ tiến độ cũ)', () {
      final r = starsMap({(t2.id, 1): 1});
      expect(ProgressRules.isTopicUnlocked(r, g1, 2), isTrue);
      expect(ProgressRules.isTopicUnlocked(r, g1, 1), isFalse);
    });

    test('phụ huynh mở tất cả chủ đề', () {
      final r = starsMap({});
      for (var i = 0; i < g1.topics.length; i++) {
        expect(ProgressRules.isTopicUnlocked(r, g1, i, unlockAll: true), isTrue);
      }
      expect(ProgressRules.currentTopicIndex(r, g1, unlockAll: true), 0);
    });
  });

  group('Dạng bài cần luyện thêm', () {
    test('xếp tỉ lệ đúng thấp trước, bỏ nhóm ít câu và nhóm đúng nhiều', () {
      final log = [
        for (var i = 0; i < 10; i++) entry(t0.id, 'count_objects', i < 5), // 5/10
        for (var i = 0; i < 10; i++) entry(t1.id, 'shape_identify', i < 3), // 3/10
        for (var i = 0; i < 10; i++) entry(t2.id, 'add_sub', i < 9), // 9/10
        entry(t2.id, 'word_problem', false), // chỉ 1 câu
      ];
      final weak = WeakSkills.analyze(log);
      expect(weak.map((w) => w.generator), ['shape_identify', 'count_objects']);
      expect(weak.first.correct, 3);
      expect(weak.first.total, 10);
      expect(weak.first.name, 'Nhận biết hình');
    });

    test('lọc theo lớp', () {
      final log = [for (var i = 0; i < 6; i++) entry('g2-x', 'add_sub', false, grade: 2)];
      expect(WeakSkills.analyze(log, grade: 1), isEmpty);
      expect(WeakSkills.analyze(log, grade: 2), hasLength(1));
    });

    test('mọi dạng bài đều có tên tiếng Việt', () {
      for (final g in Generators.all) {
        expect(SkillNames.of(g.id), isNot(g.id), reason: 'thiếu tên cho ${g.id}');
      }
    });
  });

  group('Luyện tập', () {
    test('Luyện tập thêm: chỉ lấy level đã mở, cùng một mini game', () {
      final r = starsMap({(t0.id, 1): 1, (t0.id, 2): 1});
      for (var seed = 0; seed < 20; seed++) {
        final plan = PracticePlan.forTopic(t0, r, math.Random(seed));
        expect(plan.kind, PracticeKind.topic);
        expect(plan.pool, isNotEmpty);
        for (final l in plan.pool) {
          expect(ProgressRules.isUnlocked(r, t0.id, l.level), isTrue);
          expect(l.miniGame, plan.miniGame);
        }
      }
    });

    test('Luyện chỗ còn sai: lấy đúng dạng bài bé vừa sai; không sai câu nào thì không có', () {
      expect(PracticePlan.forMistakes(g1, [entry(t0.id, 'count_objects', true)], math.Random(1)), isNull);
      final log = [entry(t2.id, 'word_problem', false), entry(t2.id, 'add_sub', true)];
      final plan = PracticePlan.forMistakes(g1, log, math.Random(1))!;
      expect(plan.kind, PracticeKind.mistakes);
      expect(plan.topic.id, t2.id);
      expect(plan.pool.map((l) => l.generator).toSet(), {'word_problem'});
    });

    test('lượt luyện tập trộn câu từ nhóm level, lưu level 0 và không đổi sao level thật', () async {
      final plan = PracticePlan(kind: PracticeKind.topic, topic: t2, pool: [t2.levels[0], t2.levels[1]]);
      final s = GameSession(
        grade: 1,
        topicId: t2.id,
        level: plan.base,
        pool: plan.pool,
        random: math.Random(4),
      )..start();
      final seenLevels = <int>{};
      while (s.phase != SessionPhase.finished) {
        seenLevels.add(s.currentLevel.level);
        expect(plan.pool, contains(s.currentLevel));
        s.answer(s.question!.answer);
        for (var i = 0; i < 50 && s.phase == SessionPhase.feedback; i++) {
          s.tick(const Duration(milliseconds: 100));
        }
      }
      expect(seenLevels, {1, 2}, reason: 'câu lấy từ cả hai level');
      final result = s.result;
      expect(result.level, GameSession.practiceLevel);
      expect(result.extraPractice, isTrue);
      expect(result.stars, 3);
      expect(SessionFeedback.forResult(result).body, isNot(contains('level')));

      final store = MemoryProgressStore();
      final p = await store.createProfile(name: 'An', grade: 1);
      await store.saveSession(p.id, result);
      final records = await store.levelRecords(p.id, 1);
      expect(ProgressRules.topicStars(records, t2), 0, reason: 'luyện tập không cộng sao');
      expect(await store.totalScore(p.id), result.score, reason: 'luyện tập vẫn có điểm');
    });
  });

  group('Mấy và mấy', () {
    final gen = Generators.find('split_number')!;
    test('tách và gộp đúng phép tính, đáp án trong phạm vi', () {
      final r = math.Random(7);
      final kinds = <String>{};
      for (var i = 0; i < 300; i++) {
        final q = gen.generate(GenParams(const {'max': 10}, answers: 3), r);
        final a = q.data['a']! as int, b = q.data['b']! as int;
        expect(a, greaterThanOrEqualTo(1));
        expect(b, greaterThanOrEqualTo(1));
        expect(a + b, lessThanOrEqualTo(10));
        expect(q.options.toSet(), hasLength(3), reason: q.prompt);
        if (q.data['hide'] == 'b') {
          kinds.add('split');
          expect(q.correctOption, '$b');
          expect(q.prompt, '${a + b} gồm $a và mấy?');
        } else {
          kinds.add('join');
          expect(q.correctOption, '${a + b}');
        }
      }
      expect(kinds, {'split', 'join'});
    });

    test('lớp 1, chủ đề Các số từ 0 đến 10 có bài Mấy và mấy', () {
      expect(t0.levels.any((l) => l.generator == 'split_number'), isTrue);
    });
  });
}
