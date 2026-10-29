import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/generators/generator.dart';
import 'package:g_primary_math/content/generators/registry.dart';
import 'package:g_primary_math/content/numbers.dart';
import 'package:g_primary_math/content/question.dart';

Question gen(String id, Map<String, Object?> params, math.Random r, {int answers = 4}) =>
    Generators.find(id)!.generate(GenParams(params, answers: answers), r);

int n(String s) => int.parse(s.replaceAll(' ', ''));

Dec dec(String s) {
  final t = s.replaceAll(' ', '');
  final i = t.indexOf(',');
  return i < 0 ? Dec(int.parse(t), 0) : Dec(int.parse(t.replaceAll(',', '')), t.length - i - 1);
}

Frac frac(String s) {
  final p = s.split('/');
  return p.length == 1 ? Frac(int.parse(p[0]), 1) : Frac(int.parse(p[0]), int.parse(p[1]));
}

void main() {
  final r = math.Random(345);

  test('tìm thành phần chưa biết: thay đáp án vào thì phép tính đúng', () {
    for (var i = 0; i < 400; i++) {
      final q = gen('find_unknown', {'ops': ['+', '-', '×', ':']}, r);
      final eq = q.prompt.replaceFirst('?', q.correctOption).split(' = ');
      final parts = eq[0].split(' ');
      final a = n(parts[0]), b = n(parts[2]), c = n(eq[1]);
      final v = switch (parts[1]) { '+' => a + b, '−' => a - b, '×' => a * b, _ => a ~/ b };
      expect(v, c, reason: '$q');
      if (parts[1] == ':') expect(a % b, 0, reason: '$q');
    }
  });

  test('làm tròn số đúng quy tắc', () {
    for (var i = 0; i < 300; i++) {
      final q = gen('rounding', {'to': ['tens', 'hundreds', 'thousands'], 'digits': [4, 5]}, r);
      expect(n(q.correctOption), q.data['rounded'], reason: '$q');
    }
  });

  test('nhân chia số nhiều chữ số và phép chia có dư', () {
    for (var i = 0; i < 300; i++) {
      final q = gen('mul_div_big', {'aDigits': 4, 'bDigits': 1, 'ops': [':'], 'remainder': true}, r);
      final p = q.prompt.replaceAll(' = ?', '').split(' : ');
      final a = n(p[0]), b = n(p[1]);
      expect(q.correctOption, '${groupThousands(a ~/ b)} dư ${a % b}', reason: '$q');
      expect(a % b, inInclusiveRange(1, b - 1));
    }
  });

  test('phân số: kết quả cộng, trừ, nhân, chia đúng và tối giản', () {
    for (var i = 0; i < 400; i++) {
      final q = gen('fraction', {'kinds': ['add', 'sub', 'mul', 'div']}, r);
      final m = RegExp(r'^(\d+(?:/\d+)?) (.) (\d+(?:/\d+)?) = \?$').firstMatch(q.prompt)!;
      final a = frac(m.group(1)!), b = frac(m.group(3)!);
      final want = switch (m.group(2)) { '+' => a + b, '−' => a - b, '×' => a * b, _ => a / b };
      final got = frac(q.correctOption);
      expect(got == want, isTrue, reason: '$q');
      expect(got.isReduced, isTrue, reason: '$q');
      // Không đáp án sai nào bằng giá trị đáp án đúng.
      for (var k = 0; k < q.options.length; k++) {
        if (k != q.answer) expect(frac(q.options[k]) == want, isFalse, reason: '$q');
      }
    }
  });

  test('số thập phân: phép tính chính xác', () {
    for (var i = 0; i < 400; i++) {
      final q = gen('decimal', {'kinds': ['add', 'sub', 'mul', 'div']}, r);
      final m = RegExp(r'^([\d ,]+) (.) ([\d ,]+) = \?$').firstMatch(q.prompt)!;
      final a = dec(m.group(1)!), b = dec(m.group(3)!);
      final got = dec(q.correctOption);
      switch (m.group(2)) {
        case '+':
          expect(got, a + b, reason: '$q');
        case '−':
          expect(got, a - b, reason: '$q');
        case '×':
          expect(got, a * b, reason: '$q');
        default:
          expect(got * b, a, reason: '$q');
      }
    }
  });

  test('đổi đơn vị: đáp án khớp tỉ lệ', () {
    for (var i = 0; i < 300; i++) {
      final q = gen('unit_convert', {'quantities': ['length', 'mass', 'area', 'volume', 'time'], 'maxRatio': 10000, 'compound': true}, r);
      expect(q.explanation, contains(q.correctOption), reason: '$q');
    }
  });

  test('chu vi, diện tích: đáp án có đơn vị đúng', () {
    for (var i = 0; i < 200; i++) {
      final q = gen('perimeter_area', {'kinds': ['rect_area', 'square_area', 'triangle_area', 'trapezoid_area']}, r);
      expect(q.correctOption, endsWith('cm²'), reason: '$q');
      final q2 = gen('perimeter_area', {'kinds': ['box_volume', 'cube_volume']}, r);
      expect(q2.correctOption, endsWith('cm³'), reason: '$q2');
    }
  });

  test('Tia số: đáp án được xếp tăng dần, vị trí đáp án đúng theo kịp', () {
    const q = Question(
      generator: 't',
      prompt: '?',
      speech: '?',
      options: ['4 800', '4 700', '5 000', '4 600'],
      answer: 1,
      explanation: '.',
      explanationSpeech: '.',
    );
    final s = q.sortedByValue();
    expect(s.options, ['4 600', '4 700', '4 800', '5 000']);
    expect(s.correctOption, '4 700');
    expect(Question.valueOf('3/4'), .75);
    expect(Question.valueOf('2,5 kg'), 2.5);
    expect(Question.valueOf('1250'), 1250);
    expect(Question.valueOf('Góc tù'), isNull);
  });

  test('đọc đề lớp 3–5 không còn ký hiệu khó đọc', () {
    final ids = ['digits', 'rounding', 'find_unknown', 'mul_div_big', 'times', 'expression', 'fraction', 'decimal', 'percent', 'perimeter_area', 'unit_convert', 'motion'];
    for (final id in ids) {
      for (var i = 0; i < 50; i++) {
        final q = gen(id, const {}, r);
        expect(q.speech, isNot(contains('×')), reason: '$id: ${q.speech}');
        expect(q.speech, isNot(contains('cm²')), reason: '$id: ${q.speech}');
        expect(q.speech, isNot(matches(RegExp(r'\d/\d'))), reason: '$id: ${q.speech}');
      }
    }
  });
}
