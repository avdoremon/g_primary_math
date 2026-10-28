import 'dart:math' as math;

import '../question.dart';
import 'generator.dart';

const _minus = '−'; // dấu trừ chuẩn, rõ hơn gạch nối khi nhìn từ xa

String _opText(String op) => op == '+' ? '+' : _minus;
String _opWord(String op) => op == '+' ? 'cộng' : 'trừ';

/// Cộng, trừ. Tham số:
/// - max: phạm vi (10, 20, 100, 1000)
/// - carry: "none" (không nhớ) | "allowed" (nhớ không quá một lượt) | "required" (đúng một lượt nhớ)
/// - ops: ["+", "-"]; terms: 2 hoặc 3 (lớp 1: hai dấu phép tính, tính từ trái sang phải)
/// - round: "none" | "tens" (số tròn chục) | "hundreds" (số tròn trăm)
/// - format: "choice" (chọn đáp án) | "true_false" (Đúng hay sai: bước trái = Sai, bước phải = Đúng)
class AddSubGenerator extends QuestionGenerator {
  const AddSubGenerator();

  @override
  String get id => 'add_sub';

  @override
  List<String> validate(GenParams p) {
    final errors = <String>[];
    final ops = p.strList('ops', const ['+', '-']);
    if (ops.isEmpty || ops.any((o) => o != '+' && o != '-')) errors.add('ops chỉ gồm "+" và "-"');
    if (!const ['none', 'allowed', 'required'].contains(p.strOf('carry', 'none'))) {
      errors.add('carry phải là none, allowed hoặc required');
    }
    if (!const [2, 3].contains(p.intOf('terms', 2))) errors.add('terms phải là 2 hoặc 3');
    return errors;
  }

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 10);
    final carry = p.strOf('carry', 'none');
    final ops = p.strList('ops', const ['+', '-']);
    final terms = p.intOf('terms', 2);
    final unit = switch (p.strOf('round', 'none')) {
      'tens' => 10,
      'hundreds' => 100,
      _ => 1,
    };

    late List<int> nums;
    late List<String> opsUsed;
    late int result;
    for (var attempt = 0;; attempt++) {
      nums = [between(r, 0, max ~/ unit) * unit];
      opsUsed = [];
      var acc = nums.first;
      var carries = 0;
      var ok = true;
      for (var i = 1; i < terms; i++) {
        final op = pick(ops, r);
        final int n;
        if (op == '+') {
          n = between(r, 0, (max - acc) ~/ unit) * unit;
          carries += carriesInAdd(acc, n);
          acc += n;
        } else {
          n = between(r, 0, acc ~/ unit) * unit;
          carries += borrowsInSub(acc, n);
          acc -= n;
        }
        nums.add(n);
        opsUsed.add(op);
        if (acc < 0 || acc > max) ok = false;
      }
      if (carries > 1) ok = false;
      if (carry == 'none' && carries > 0) ok = false;
      if (carry == 'required' && carries != 1) ok = false;
      // Hạn chế phép tính với số 0 cho đỡ nhàm (vẫn giữ một ít vì sách có dạng này).
      if (nums.any((n) => n == 0) && r.nextInt(5) != 0) ok = false;
      if (ok || attempt > 2000) {
        result = acc;
        break;
      }
    }

    final exprParts = <String>[];
    final speechParts = <String>[];
    for (var i = 0; i < nums.length; i++) {
      if (i > 0) {
        exprParts.add(_opText(opsUsed[i - 1]));
        speechParts.add(_opWord(opsUsed[i - 1]));
      }
      exprParts.add(fmt(nums[i]));
      speechParts.add(say(nums[i]));
    }
    final expr = exprParts.join(' ');
    final exprSpeech = speechParts.join(' ');

    final preferred = <int>[
      result + unit,
      result - unit,
      result + 2 * unit,
      result - 2 * unit,
      if (max > 20) result + 10,
      if (max > 20) result - 10,
      if (terms == 2) opsUsed.first == '+' ? nums[0] - nums[1] : nums[0] + nums[1],
    ];

    if (p.strOf('format', 'choice') == 'true_false') {
      final showWrong = r.nextBool();
      final candidates = preferred.where((v) => v >= 0 && v != result).toList();
      final shown = showWrong && candidates.isNotEmpty ? pick(candidates, r) : result;
      final isTrue = shown == result;
      return Question(
        generator: id,
        prompt: '$expr = ${fmt(shown)}',
        speech: '${cap(exprSpeech)} bằng ${say(shown)}. Đúng hay sai?',
        options: const ['Sai', 'Đúng'],
        answer: isTrue ? 1 : 0,
        explanation: '$expr = ${fmt(result)}',
        explanationSpeech: '${cap(exprSpeech)} bằng ${say(result)}.',
        data: {'expression': expr, 'shown': shown, 'result': result},
      );
    }

    final o = numericOptions(r, result, p.answers, max: math.max(max, result), preferred: preferred);
    return Question(
      generator: id,
      prompt: '$expr = ?',
      speech: '${cap(exprSpeech)} bằng mấy?',
      options: o.options,
      answer: o.answer,
      explanation: '$expr = ${fmt(result)}',
      explanationSpeech: '${cap(exprSpeech)} bằng ${say(result)}.',
      data: {'expression': expr, 'result': result},
    );
  }
}

class _Story {
  const _Story(this.text, this.question, this.unit, this.op);

  final String text; // có {a} và {b}
  final String question;
  final String unit;
  final String op; // '+' hoặc '-'
}

/// Bài toán có lời văn một bước: thêm, bớt (lớp 1); nhiều hơn, ít hơn (lớp 2).
/// ask "result": chọn kết quả; "expression": chọn phép tính đúng.
class WordProblemGenerator extends QuestionGenerator {
  const WordProblemGenerator();

  @override
  String get id => 'word_problem';

  static const _stories = <String, List<_Story>>{
    'add': [
      _Story('Lan có {a} quả táo. Mẹ cho Lan thêm {b} quả táo.', 'Lan có tất cả bao nhiêu quả táo?', 'quả táo', '+'),
      _Story('Trong chuồng có {a} con gà. Có thêm {b} con gà chạy vào.', 'Trong chuồng có tất cả bao nhiêu con gà?',
          'con gà', '+'),
      _Story('Tổ Một trồng được {a} cây. Tổ Hai trồng được {b} cây.', 'Cả hai tổ trồng được bao nhiêu cây?', 'cây', '+'),
    ],
    'sub': [
      _Story('Trên cành có {a} con chim. Có {b} con chim bay đi.', 'Trên cành còn lại bao nhiêu con chim?', 'con chim',
          '-'),
      _Story('Bình có {a} viên bi. Bình cho bạn {b} viên bi.', 'Bình còn lại bao nhiêu viên bi?', 'viên bi', '-'),
      _Story('Lớp em có {a} quả bóng bay. Có {b} quả bị vỡ.', 'Lớp em còn lại bao nhiêu quả bóng bay?', 'quả bóng bay',
          '-'),
    ],
    'more': [
      _Story('Hoa có {a} bông hoa. Mai có nhiều hơn Hoa {b} bông hoa.', 'Mai có bao nhiêu bông hoa?', 'bông hoa', '+'),
      _Story('Thùng thứ nhất có {a} quả cam. Thùng thứ hai có nhiều hơn thùng thứ nhất {b} quả cam.',
          'Thùng thứ hai có bao nhiêu quả cam?', 'quả cam', '+'),
    ],
    'less': [
      _Story('Đội Xanh có {a} bạn. Đội Đỏ có ít hơn đội Xanh {b} bạn.', 'Đội Đỏ có bao nhiêu bạn?', 'bạn', '-'),
      _Story('Nhà An nuôi {a} con vịt. Nhà Bình nuôi ít hơn nhà An {b} con vịt.', 'Nhà Bình nuôi bao nhiêu con vịt?',
          'con vịt', '-'),
    ],
  };

  @override
  List<String> validate(GenParams p) {
    final kinds = p.strList('kinds', const ['add', 'sub']);
    return kinds.where((k) => !_stories.containsKey(k)).map((k) => 'kinds không có "$k"').toList();
  }

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 10);
    final story = pick(_stories[pick(p.strList('kinds', const ['add', 'sub']), r)]!, r);
    late int a, b, result;
    if (story.op == '+') {
      a = between(r, 1, max - 1);
      b = between(r, 1, max - a);
      result = a + b;
    } else {
      a = between(r, 2, max);
      b = between(r, 1, a - 1);
      result = a - b;
    }
    final text = story.text.replaceAll('{a}', fmt(a)).replaceAll('{b}', fmt(b));
    final textSpeech = story.text.replaceAll('{a}', say(a)).replaceAll('{b}', say(b));
    final expr = '${fmt(a)} ${_opText(story.op)} ${fmt(b)}';
    final explanation = '$expr = ${fmt(result)} (${story.unit})';
    final explanationSpeech = 'Ta làm phép tính ${say(a)} ${_opWord(story.op)} ${say(b)} bằng ${say(result)}.';

    final ask = switch (p.strOf('ask', 'result')) {
      'mixed' => r.nextBool() ? 'result' : 'expression',
      final s => s,
    };
    if (ask == 'expression') {
      final other = story.op == '+' ? '-' : '+';
      final wrong = <String>[
        if (a >= b || other == '+') '${fmt(a)} ${_opText(other)} ${fmt(b)}',
        '${fmt(b)} ${_opText(story.op)} ${fmt(a)}',
        '${fmt(a)} ${_opText(story.op)} ${fmt(b + 1)}',
        if (b > 1) '${fmt(a)} ${_opText(story.op)} ${fmt(b - 1)}',
      ];
      // Phép cộng có tính giao hoán: "b + a" cũng đúng nên không dùng làm đáp án sai.
      if (story.op == '+') wrong.remove('${fmt(b)} ${_opText(story.op)} ${fmt(a)}');
      final o = textOptions(r, expr, wrong, p.answers);
      return Question(
        generator: id,
        prompt: '$text ${story.question} Chọn phép tính đúng.',
        speech: '$textSpeech ${story.question} Con chọn phép tính đúng nhé!',
        options: o.options,
        answer: o.answer,
        explanation: explanation,
        explanationSpeech: explanationSpeech,
        data: {'expression': expr, 'result': result},
      );
    }
    final o = numericOptions(r, result, p.answers,
        max: max, preferred: [story.op == '+' ? (a - b).abs() : a + b, result + 1, result - 1]);
    return Question(
      generator: id,
      prompt: '$text ${story.question}',
      speech: '$textSpeech ${story.question}',
      options: o.options,
      answer: o.answer,
      explanation: explanation,
      explanationSpeech: explanationSpeech,
      data: {'expression': expr, 'result': result},
    );
  }
}

/// Lớp 2: bảng nhân 2, 5 và bảng chia 2, 5.
class MulDivGenerator extends QuestionGenerator {
  const MulDivGenerator();

  @override
  String get id => 'mul_div';

  @override
  Question generate(GenParams p, math.Random r) {
    final table = pick(p.intList('tables', const [2, 5]), r);
    final op = pick(p.strList('ops', const ['×', ':']), r);
    final k = between(r, 1, 10);
    final product = table * k;
    final isMul = op == '×' || op == 'x' || op == '*';
    final a = isMul ? table : product;
    final b = isMul ? k : table;
    final result = isMul ? product : k;
    final sign = isMul ? '×' : ':';
    final word = isMul ? 'nhân' : 'chia';
    final o = numericOptions(r, result, p.answers,
        max: table * 10,
        preferred: isMul ? [result + table, result - table, a + b] : [result + 1, result - 1, product - table]);
    return Question(
      generator: id,
      prompt: '${fmt(a)} $sign ${fmt(b)} = ?',
      speech: '${cap(say(a))} $word ${say(b)} bằng mấy?',
      options: o.options,
      answer: o.answer,
      explanation: '${fmt(a)} $sign ${fmt(b)} = ${fmt(result)}',
      explanationSpeech: '${cap(say(a))} $word ${say(b)} bằng ${say(result)}.',
      data: {'table': table, 'op': sign},
    );
  }
}

/// Đếm thêm theo bước (1, 2, 5, 10).
/// format "jump": mini game Nhảy đếm – bé nhảy đủ số lần trong data.jumps, mỗi lần đếm một số;
/// format "choice": tìm số tiếp theo của dãy.
class SkipCountGenerator extends QuestionGenerator {
  const SkipCountGenerator();

  @override
  String get id => 'skip_count';

  @override
  Question generate(GenParams p, math.Random r) {
    final step = pick(p.intList('steps', const [2, 5]), r);
    final start = step;
    if (p.strOf('format', 'jump') == 'jump') {
      final jumps = between(r, p.intOf('minJumps', 3), p.intOf('maxJumps', 6));
      final seq = [for (var i = 0; i < jumps; i++) start + step * i];
      final last = seq.last;
      final title = step == 1 ? 'Con nhảy ${fmt(jumps)} cái nhé!' : 'Đếm thêm ${fmt(step)}: nhảy và đếm đến ${fmt(last)}!';
      final titleSpeech =
          step == 1 ? 'Con nhảy ${say(jumps)} cái nhé!' : 'Đếm thêm ${say(step)}. Con nhảy và đếm đến ${say(last)} nhé!';
      return Question(
        generator: id,
        prompt: title,
        speech: titleSpeech,
        options: ['${fmt(jumps)} lần'],
        answer: 0,
        explanation: seq.map(fmt).join(', '),
        explanationSpeech: seq.map(say).join(', '),
        data: {'step': step, 'start': start, 'jumps': jumps, 'sequence': seq},
      );
    }
    final shownCount = 4;
    final first = start + step * between(r, 0, 3);
    final shown = [for (var i = 0; i < shownCount; i++) first + step * i];
    final next = shown.last + step;
    final o = numericOptions(r, next, p.answers,
        max: next + step * 2, preferred: [shown.last + 1, next + step, next + 1, next - 1]);
    return Question(
      generator: id,
      prompt: '${shown.map(fmt).join(', ')}, ?',
      speech: 'Đếm thêm ${say(step)}: ${shown.map(say).join(', ')}. Số tiếp theo là số nào?',
      options: o.options,
      answer: o.answer,
      explanation: '${shown.map(fmt).join(', ')}, ${fmt(next)}',
      explanationSpeech: 'Đếm thêm ${say(step)}, sau ${say(shown.last)} là ${say(next)}.',
      data: {'step': step, 'sequence': [...shown, next]},
    );
  }
}

/// Lớp 2: độ dài đường gấp khúc khi biết độ dài các đoạn.
class PolylineLengthGenerator extends QuestionGenerator {
  const PolylineLengthGenerator();

  @override
  String get id => 'polyline_length';

  @override
  Question generate(GenParams p, math.Random r) {
    final segments = between(r, p.intOf('minSegments', 2), p.intOf('maxSegments', 3));
    final unit = p.strOf('unit', 'cm');
    final unitWord = unit == 'dm' ? 'đề-xi-mét' : 'xăng-ti-mét';
    final lengths = [for (var i = 0; i < segments; i++) between(r, p.intOf('minLength', 2), p.intOf('maxLength', 9))];
    final total = lengths.fold<int>(0, (s, v) => s + v);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final name = letters.take(segments + 1).join();
    final o = numericOptions(r, total, p.answers,
        min: 1,
        max: total + 20,
        preferred: [total - lengths.last, total + 1, total - 1, total + lengths.first],
        label: (v) => '${fmt(v)} $unit');
    return Question(
      generator: id,
      prompt: 'Đường gấp khúc $name dài bao nhiêu $unit?',
      speech: 'Đường gấp khúc $name dài bao nhiêu $unitWord?',
      options: o.options,
      answer: o.answer,
      explanation: '${lengths.map(fmt).join(' + ')} = ${fmt(total)} ($unit)',
      explanationSpeech: 'Cộng độ dài các đoạn: ${lengths.map(say).join(' cộng ')} bằng ${say(total)} $unitWord.',
      data: {'segments': lengths, 'unit': unit, 'name': name},
    );
  }
}
