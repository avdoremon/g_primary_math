import 'dart:math' as math;

import '../question.dart';
import 'generator.dart';

/// Đồ vật dùng để đếm (khớp với asset đợt 3 của design).
const countObjects = <String, String>{
  'apple': 'quả táo',
  'ball': 'quả bóng',
  'star': 'ngôi sao',
  'pencil': 'cái bút chì',
  'fish': 'con cá',
};

/// Lớp 1: đếm, đọc số trong phạm vi 10, 20, 100. Trên 20, đồ vật xếp thành bó chục.
class CountObjectsGenerator extends QuestionGenerator {
  const CountObjectsGenerator();

  @override
  String get id => 'count_objects';

  @override
  List<String> validate(GenParams p) => p.intOf('max', 10) < 1 ? ['max phải ≥ 1'] : const [];

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 10);
    final min = p.intOf('min', 1);
    final obj = pick(p.strList('objects', countObjects.keys.toList()), r);
    final name = countObjects[obj] ?? obj;
    final n = between(r, min, max);
    final o = numericOptions(r, n, p.answers, min: 1, max: max, preferred: [n + 1, n - 1, n + 10, n - 10]);
    return Question(
      generator: id,
      prompt: 'Có bao nhiêu $name?',
      speech: 'Có bao nhiêu $name?',
      options: o.options,
      answer: o.answer,
      explanation: 'Có ${fmt(n)} $name.',
      explanationSpeech: 'Có ${say(n)} $name.',
      data: {'object': obj, 'count': n, 'groupBy': n > 20 ? 10 : 1},
    );
  }
}

/// Lớp 1, bài "Mấy và mấy": tách một số thành hai phần, hoặc gộp hai phần thành một số.
/// Có hình hai nhóm đồ vật để bé đếm; câu tách thì nhóm thứ hai là ô dấu hỏi.
class SplitNumberGenerator extends QuestionGenerator {
  const SplitNumberGenerator();

  @override
  String get id => 'split_number';

  @override
  List<String> validate(GenParams p) => p.intOf('max', 10) < 2 ? ['max phải ≥ 2'] : const [];

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 10);
    final n = between(r, math.max(2, p.intOf('min', 2)), max);
    final a = between(r, 1, n - 1);
    final b = n - a;
    final obj = pick(p.strList('objects', countObjects.keys.toList()), r);
    final ask = p.strOf('ask', 'mixed');
    final split = ask == 'split' || (ask == 'mixed' && r.nextBool());
    if (split) {
      final o = numericOptions(r, b, p.answers, min: 0, max: max, preferred: [n, a, b + 1, b - 1]);
      return Question(
        generator: id,
        prompt: '$n gồm $a và mấy?',
        speech: '${cap(say(n))} gồm ${say(a)} và mấy?',
        options: o.options,
        answer: o.answer,
        explanation: '$n gồm $a và $b.',
        explanationSpeech: '${cap(say(n))} gồm ${say(a)} và ${say(b)}.',
        data: {'object': obj, 'a': a, 'b': b, 'hide': 'b'},
      );
    }
    final o = numericOptions(r, n, p.answers, min: 1, max: max + 1, preferred: [n + 1, n - 1, a, b]);
    return Question(
      generator: id,
      prompt: '$a và $b gộp lại là mấy?',
      speech: '${cap(say(a))} và ${say(b)} gộp lại là mấy?',
      options: o.options,
      answer: o.answer,
      explanation: '$a và $b là $n.',
      explanationSpeech: '${cap(say(a))} và ${say(b)} là ${say(n)}.',
      data: {'object': obj, 'a': a, 'b': b},
    );
  }
}

/// Lớp 1–2: chục và đơn vị (lớp 2 thêm trăm), viết số thành tổng.
class PlaceValueGenerator extends QuestionGenerator {
  const PlaceValueGenerator();

  @override
  String get id => 'place_value';

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 100);
    final n = between(r, max >= 1000 ? 101 : 11, max >= 1000 ? 999 : math.min(max, 99));
    final h = n ~/ 100, t = (n % 100) ~/ 10, u = n % 10;
    final parts = <String>[if (h > 0) '$h trăm', '$t chục', '$u đơn vị'];
    final partsSpeech = <String>[if (h > 0) '${say(h)} trăm', '${say(t)} chục', '${say(u)} đơn vị'];

    if (r.nextBool()) {
      // Từ các hàng → số. Đáp án nhiễu: đảo chữ số.
      final digits = '$n'.split('');
      final swaps = <int>{
        int.parse(digits.reversed.join()),
        if (digits.length == 3) int.parse('${digits[0]}${digits[2]}${digits[1]}'),
        if (digits.length == 3) int.parse('${digits[1]}${digits[0]}${digits[2]}'),
        n + 10,
        n - 10,
      };
      final o = numericOptions(r, n, p.answers, min: 1, max: max, preferred: swaps);
      return Question(
        generator: id,
        prompt: 'Số gồm ${parts.join(', ')} là số nào?',
        speech: 'Số gồm ${partsSpeech.join(', ')} là số nào?',
        options: o.options,
        answer: o.answer,
        explanation: '${parts.join(', ')} là số ${fmt(n)}.',
        explanationSpeech: '${partsSpeech.join(', ')} là số ${say(n)}.',
      );
    }
    // Từ số → các hàng.
    String label(int hh, int tt, int uu) => [if (hh > 0) '$hh trăm', '$tt chục', '$uu đơn vị'].join(' ');
    final correct = label(h, t, u);
    final wrong = <String>[
      label(h, u, t),
      if (h > 0) label(t, h, u),
      label(h, t == 9 ? 8 : t + 1, u),
      label(h, t, u == 0 ? 1 : u - 1),
      label(h, t, u == 9 ? 8 : u + 1),
      if (h > 0) label(h == 9 ? 8 : h + 1, t, u),
    ];
    final o = textOptions(r, correct, wrong, p.answers);
    return Question(
      generator: id,
      prompt: 'Số ${fmt(n)} gồm:',
      speech: 'Số ${say(n)} gồm mấy ${h > 0 ? 'trăm, mấy ' : ''}chục và mấy đơn vị?',
      options: o.options,
      answer: o.answer,
      explanation: 'Số ${fmt(n)} gồm ${parts.join(', ')}.',
      explanationSpeech: 'Số ${say(n)} gồm ${partsSpeech.join(', ')}.',
    );
  }
}

/// So sánh hai số. format "side": hai đáp án trái/phải (Bên nào lớn hơn);
/// format "sign": chọn dấu >, <, =.
class CompareGenerator extends QuestionGenerator {
  const CompareGenerator();

  @override
  String get id => 'compare';

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 10);
    final format = p.strOf('format', 'side');
    final a = between(r, 0, max);
    var b = between(r, 0, max);

    if (format == 'sign') {
      if (r.nextInt(5) == 0) b = a; // thỉnh thoảng hai số bằng nhau
      final sign = a > b ? '>' : (a < b ? '<' : '=');
      const signs = ['>', '<', '='];
      final word = {'>': 'lớn hơn', '<': 'bé hơn', '=': 'bằng'}[sign]!;
      return Question(
        generator: id,
        prompt: '${fmt(a)} … ${fmt(b)}',
        speech: 'Chọn dấu thích hợp: ${say(a)} và ${say(b)}.',
        options: signs,
        answer: signs.indexOf(sign),
        explanation: '${fmt(a)} $sign ${fmt(b)}',
        explanationSpeech: '${cap(say(a))} $word ${say(b)}.',
        data: {'a': a, 'b': b},
      );
    }

    while (a == b) {
      b = between(r, 0, max);
    }
    final askLarger = switch (p.strOf('ask', 'mixed')) {
      'larger' => true,
      'smaller' => false,
      _ => r.nextBool(),
    };
    final target = askLarger ? math.max(a, b) : math.min(a, b);
    final word = askLarger ? 'lớn hơn' : 'bé hơn';
    final other = target == a ? b : a;
    return Question(
      generator: id,
      prompt: 'Số nào $word?',
      speech: 'Số nào $word? Con bước sang bên số đó nhé!',
      options: [fmt(a), fmt(b)],
      answer: target == a ? 0 : 1,
      explanation: askLarger ? '${fmt(target)} > ${fmt(other)}' : '${fmt(target)} < ${fmt(other)}',
      explanationSpeech: '${cap(say(target))} $word ${say(other)}.',
      data: {'a': a, 'b': b},
    );
  }
}

/// Xếp thứ tự (≤ 4 số), tìm số lớn nhất / bé nhất.
/// ask "order": chạm lần lượt theo thứ tự trong data.sequence; [Question.answer] là số phải chạm đầu tiên.
class OrderNumbersGenerator extends QuestionGenerator {
  const OrderNumbersGenerator();

  @override
  String get id => 'order_numbers';

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 100);
    final count = p.intOf('count', math.min(4, math.max(3, p.answers)));
    final ask = switch (p.strOf('ask', 'mixed')) {
      'mixed' => pick(const ['order', 'max', 'min'], r),
      final s => s,
    };
    final nums = <int>{};
    while (nums.length < count) {
      nums.add(between(r, 0, max));
    }
    final list = nums.toList()..shuffle(r);
    final options = [for (final n in list) fmt(n)];
    final asc = [...list]..sort();

    switch (ask) {
      case 'max':
      case 'min':
        final target = ask == 'max' ? asc.last : asc.first;
        final word = ask == 'max' ? 'lớn nhất' : 'bé nhất';
        return Question(
          generator: id,
          prompt: 'Số nào $word?',
          speech: 'Số nào $word?',
          options: options,
          answer: list.indexOf(target),
          explanation: 'Số $word là ${fmt(target)}.',
          explanationSpeech: 'Số $word là ${say(target)}.',
        );
      default:
        final descending = p.strOf('order', 'asc') == 'desc';
        final seq = descending ? asc.reversed.toList() : asc;
        final words = descending ? 'từ lớn đến bé' : 'từ bé đến lớn';
        return Question(
          generator: id,
          prompt: 'Chạm các số theo thứ tự $words',
          speech: 'Con chạm các số theo thứ tự $words nhé!',
          options: options,
          answer: list.indexOf(seq.first),
          explanation: seq.map(fmt).join(descending ? ' > ' : ' < '),
          explanationSpeech: 'Thứ tự $words là ${seq.map(say).join(', ')}.',
          data: {'sequence': [for (final n in seq) list.indexOf(n)]},
        );
    }
  }
}

/// Lớp 2: số liền trước, số liền sau, số trên tia số.
class NeighborsGenerator extends QuestionGenerator {
  const NeighborsGenerator();

  @override
  String get id => 'neighbors';

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 100);
    final ask = switch (p.strOf('ask', 'mixed')) {
      'mixed' => pick(const ['next', 'prev', 'number_line'], r),
      final s => s,
    };

    if (ask == 'number_line') {
      final step = pick(p.intList('steps', const [1, 10]), r);
      final length = 5;
      final start = between(r, 0, math.max(0, max - step * (length - 1)));
      final missing = between(r, 1, length - 1);
      final value = start + step * missing;
      final o = numericOptions(r, value, p.answers,
          max: max, preferred: [value + step, value - step, value + 1, value - 1]);
      final marks = [for (var i = 0; i < length; i++) i == missing ? null : start + step * i];
      return Question(
        generator: id,
        prompt: 'Số nào ở chỗ dấu ? trên tia số?',
        speech: 'Số nào ở chỗ dấu hỏi trên tia số?',
        options: o.options,
        answer: o.answer,
        explanation: marks.map((m) => m == null ? fmt(value) : fmt(m)).join(', '),
        explanationSpeech: 'Số đó là ${say(value)}, vì mỗi vạch cách nhau ${say(step)}.',
        data: {'numberLine': marks, 'step': step},
      );
    }

    final next = ask == 'next';
    final n = next ? between(r, 0, max - 1) : between(r, 1, max);
    final value = next ? n + 1 : n - 1;
    final word = next ? 'liền sau' : 'liền trước';
    final o = numericOptions(r, value, p.answers,
        max: max, preferred: [n, next ? n - 1 : n + 1, value + 10, value - 10, value + 2]);
    return Question(
      generator: id,
      prompt: 'Số $word của ${fmt(n)} là số nào?',
      speech: 'Số $word của ${say(n)} là số nào?',
      options: o.options,
      answer: o.answer,
      explanation: 'Số $word của ${fmt(n)} là ${fmt(value)}.',
      explanationSpeech: 'Số $word của ${say(n)} là ${say(value)}.',
    );
  }
}
