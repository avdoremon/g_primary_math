import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/content/generators/generator.dart';
import 'package:g_primary_math/content/generators/registry.dart';
import 'package:g_primary_math/content/question.dart';
import 'package:g_primary_math/content/scoring.dart';
import 'package:g_primary_math/game/mechanics.dart';

Grade loadGrade(int n) => Grade.parse(File('assets/content/grade$n.json').readAsStringSync());

final _numeric = RegExp(r'^\d[\d ]*$');
int? asInt(String s) => _numeric.hasMatch(s) ? int.parse(s.replaceAll(' ', '')) : null;

/// Mini game không cần chọn đáp án (bé làm động tác), chỉ có một "đáp án".
const _singleAnswerGames = {MiniGames.jumpCount, MiniGames.humanClock, MiniGames.armAngle, MiniGames.clapCount};

void checkQuestion(Question q, Level level, String where) {
  expect(q.prompt.trim(), isNotEmpty, reason: '$where: đề trống');
  expect(q.speech.trim(), isNotEmpty, reason: '$where: giọng đọc trống');
  expect(q.explanation.trim(), isNotEmpty, reason: '$where: thiếu giải thích');
  expect(q.explanationSpeech.trim(), isNotEmpty, reason: '$where: thiếu giải thích bằng giọng đọc');
  expect(q.options, isNotEmpty, reason: '$where: không có đáp án');
  expect(q.options.toSet().length, q.options.length, reason: '$where: đáp án trùng nhau ${q.options}');
  expect(q.answer, inInclusiveRange(0, q.options.length - 1), reason: '$where: vị trí đáp án sai');
  expect(q.options.length, lessThanOrEqualTo(4), reason: '$where: quá 4 đáp án');
  final isCompound = q.data['type'] == 'compound';
  if (!_singleAnswerGames.contains(level.miniGame) && !isCompound) {
    expect(q.options.length, greaterThanOrEqualTo(2), reason: '$where: cần ít nhất 2 đáp án ($q)');
  }
  for (final o in q.options) {
    final v = asInt(o);
    if (v != null) expect(v, greaterThanOrEqualTo(0), reason: '$where: đáp án âm');
  }
}

void main() {
  for (final n in [1, 2, 3, 4, 5]) {
    group('Chương trình lớp $n', () {
      final grade = loadGrade(n);

      test('hợp lệ: đủ 5 level mỗi chủ đề, dạng bài và mini game có thật', () {
        expect(grade.validate(), isEmpty);
        expect(grade.topics, isNotEmpty);
      });

      test('mức gợi ý: level 1–3 dễ, level 4–5 khó', () {
        for (final t in grade.topics) {
          for (final l in t.levels) {
            expect(l.hints, l.level <= 3 ? HintLevel.easy : HintLevel.hard);
          }
        }
      });

      test('mỗi level có đủ biến thể để 10 câu không lặp liên tục', () {
        final r = math.Random(99);
        final few = <String>[];
        for (final t in grade.topics) {
          for (final l in t.levels) {
            final keys = <String>{};
            for (var i = 0; i < 400; i++) {
              final q = l.generate(r);
              final o = [...q.options]..sort();
              keys.add('${q.prompt}|${o.join('|')}|${q.options[q.answer]}|${q.data}');
            }
            if (keys.length < 12) few.add('${t.id} L${l.level} (${l.generator}/${l.miniGame}) chỉ có ${keys.length}');
          }
        }
        expect(few, isEmpty, reason: few.join('\n'));
      });

      test('mọi level sinh được 300 câu hỏi hợp lệ', () {
        final r = math.Random(2026);
        for (final t in grade.topics) {
          for (final l in t.levels) {
            for (var i = 0; i < 300; i++) {
              checkQuestion(l.generate(r), l, '${t.id} level ${l.level}');
            }
          }
        }
      });
    });
  }

  group('Game vận động mới', () {
    const expected = {
      MiniGames.starCatch: MechanicKind.zone,
      MiniGames.hopTiles: MechanicKind.zone,
      MiniGames.touchOrder: MechanicKind.orderTouch,
      MiniGames.tintinSays: MechanicKind.armChoice,
      MiniGames.balance: MechanicKind.step,
      MiniGames.runRace: MechanicKind.run,
      MiniGames.squatGate: MechanicKind.gate,
      MiniGames.clapCount: MechanicKind.count,
    };

    test('mọi level dùng game mới đều sinh câu hỏi khớp cơ chế của game', () {
      final r = math.Random(11);
      final used = <String>{};
      for (final n in [1, 2, 3, 4, 5]) {
        for (final t in loadGrade(n).topics) {
          for (final l in t.levels) {
            final kind = expected[l.miniGame];
            if (kind == null) continue;
            used.add(l.miniGame);
            for (var i = 0; i < 100; i++) {
              final q = l.generate(r);
              expect(AnswerMechanic.forQuestion(l, q).kind, kind, reason: '${t.id} level ${l.level}: ${q.prompt}');
            }
          }
        }
      }
      expect(used, expected.keys.toSet(), reason: 'mỗi game mới phải có ít nhất một level');
    });
  });

  group('Dạng bài cộng trừ', () {
    final g = Generators.find('add_sub')!;
    final r = math.Random(7);

    int value(Question q) => q.data['result']! as int;

    test('không nhớ: không có lượt nhớ nào, kết quả trong phạm vi', () {
      for (var i = 0; i < 500; i++) {
        final q = g.generate(GenParams({'max': 100, 'ops': ['+'], 'carry': 'none'}, answers: 3), r);
        final parts = (q.data['expression']! as String).split(' + ').map((s) => int.parse(s)).toList();
        expect(carriesInAdd(parts[0], parts[1]), 0, reason: '$q');
        expect(value(q), lessThanOrEqualTo(100));
        expect(q.correctOption, '${value(q)}');
      }
    });

    test('có nhớ: đúng một lượt nhớ', () {
      for (var i = 0; i < 500; i++) {
        final q = g.generate(GenParams({'max': 100, 'ops': ['+'], 'carry': 'required'}, answers: 3), r);
        final parts = (q.data['expression']! as String).split(' + ').map((s) => int.parse(s)).toList();
        expect(carriesInAdd(parts[0], parts[1]), 1, reason: '$q');
      }
    });

    test('Đúng hay sai: đáp án khớp với kết quả hiển thị', () {
      for (var i = 0; i < 300; i++) {
        final q = g.generate(GenParams({'max': 10, 'format': 'true_false'}, answers: 2), r);
        expect(q.options, ['Sai', 'Đúng']);
        expect(q.answer == 1, q.data['shown'] == q.data['result'], reason: '$q');
      }
    });

    test('ba số hạng tính từ trái sang phải trong phạm vi 10', () {
      for (var i = 0; i < 300; i++) {
        final q = g.generate(GenParams({'max': 10, 'terms': 3}, answers: 4), r);
        expect(value(q), inInclusiveRange(0, 10));
        expect((q.data['expression']! as String).split(' ').length, 5);
      }
    });

    test('lời giải thích nêu đúng phép tính và kết quả', () {
      final q = g.generate(GenParams({'max': 10, 'ops': ['+']}, answers: 3), r);
      expect(q.explanation, '${q.data['expression']} = ${q.data['result']}');
      expect(q.explanationSpeech, contains('bằng'));
    });
  });

  group('Các dạng bài khác', () {
    final r = math.Random(11);

    test('bảng nhân 2 và 5', () {
      final g = Generators.find('mul_div')!;
      for (var i = 0; i < 200; i++) {
        final q = g.generate(GenParams({'tables': [2, 5], 'ops': ['×']}, answers: 4), r);
        final m = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(q.prompt)!;
        expect(int.parse(q.correctOption), int.parse(m[1]!) * int.parse(m[2]!));
        expect([2, 5], contains(int.parse(m[1]!)));
      }
    });

    test('nhảy đếm: dãy số tăng đều theo bước', () {
      final g = Generators.find('skip_count')!;
      final q = g.generate(GenParams({'steps': [5], 'format': 'jump', 'minJumps': 4, 'maxJumps': 4}), r);
      expect(q.data['sequence'], [5, 10, 15, 20]);
      expect(q.data['jumps'], 4);
    });

    test('đồng hồ: đáp án đúng khớp giờ trong data', () {
      final g = Generators.find('time')!;
      for (var i = 0; i < 200; i++) {
        final q = g.generate(
          GenParams({'ask': ['read'], 'minutes': [0, 15, 30]}, answers: 4),
          r,
        );
        final h = q.data['hour']! as int;
        final m = q.data['minute']! as int;
        expect(q.correctOption, m == 0 ? '$h giờ' : '$h giờ $m phút');
      }
    });

    test('so sánh hai số: đáp án là số lớn hơn hoặc bé hơn theo đề', () {
      final g = Generators.find('compare')!;
      for (var i = 0; i < 200; i++) {
        final q = g.generate(GenParams({'max': 100, 'format': 'side'}, answers: 2), r);
        final a = int.parse(q.options[0]), b = int.parse(q.options[1]);
        final larger = q.prompt.contains('lớn hơn');
        final expected = larger ? (a > b ? 0 : 1) : (a < b ? 0 : 1);
        expect(q.answer, expected, reason: '$q');
      }
    });

    test('khả năng xảy ra', () {
      final g = Generators.find('likelihood')!;
      for (var i = 0; i < 200; i++) {
        final q = g.generate(GenParams({}), r);
        final box = (q.data['box']! as List).cast<String>();
        final asked = q.data['asked']! as String;
        final expected = !box.contains(asked) ? 'Không thể' : (box.length == 1 ? 'Chắc chắn' : 'Có thể');
        expect(q.correctOption, expected, reason: '$q');
      }
    });

    test('đọc số có dấu cách nhóm nghìn', () {
      expect(fmt(999), '999');
      expect(fmt(1000), '1 000');
      expect(fmt(50000), '50 000');
    });
  });

  group('Tính điểm', () {
    test('100 điểm cơ bản + thưởng tốc độ + thưởng chuỗi', () {
      expect(Scoring.forCorrect(remainingFraction: 0, streak: 1), 100);
      expect(Scoring.forCorrect(remainingFraction: 1, streak: 1), 150);
      expect(Scoring.forCorrect(remainingFraction: 0.5, streak: 3), 100 + 25 + 40);
      expect(Scoring.forCorrect(remainingFraction: null, streak: 1), 100);
      expect(Scoring.forCorrect(remainingFraction: 0, streak: 50), 200);
    });

    test('sao theo số câu đúng', () {
      expect(Scoring.starsFor(5, 10), 0);
      expect(Scoring.starsFor(6, 10), 1);
      expect(Scoring.starsFor(8, 10), 2);
      expect(Scoring.starsFor(10, 10), 3);
      expect(Scoring.unlocksNext(1), isTrue);
      expect(Scoring.unlocksNext(0), isFalse);
    });
  });
}
