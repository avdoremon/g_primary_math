import 'dart:math' as math;

import '../numbers.dart';
import '../question.dart';
import 'big_number_generators.dart';
import 'generator.dart';

const _minus = '−';

/// Lớp 3: tìm thành phần chưa biết của phép tính ("? + 25 = 60", "56 : ? = 8").
/// ops: ["+", "-", "×", ":"]; max: phạm vi cộng trừ; tables: bảng nhân chia dùng cho × và :.
class FindUnknownGenerator extends QuestionGenerator {
  const FindUnknownGenerator();

  @override
  String get id => 'find_unknown';

  @override
  Question generate(GenParams p, math.Random r) {
    final op = pick(p.strList('ops', const ['+', '-', '×', ':']), r);
    final max = p.intOf('max', 100);
    final tables = p.intList('tables', const [2, 3, 4, 5, 6, 7, 8, 9]);
    final first = r.nextBool(); // ẩn ở vị trí thứ nhất hay thứ hai
    late int a, b, c, answer, wrongInverse;
    late String rule;
    switch (op) {
      case '+':
        a = between(r, 1, max - 1);
        b = between(r, 1, max - a);
        c = a + b;
        answer = first ? a : b;
        wrongInverse = c + (first ? b : a);
        rule = 'Muốn tìm số hạng, lấy tổng trừ đi số hạng kia: ${fmt(c)} $_minus ${fmt(first ? b : a)} = ${fmt(answer)}.';
      case '-':
        a = between(r, 2, max);
        b = between(r, 1, a - 1);
        c = a - b;
        if (first) {
          answer = a;
          wrongInverse = (c - b).abs();
          rule = 'Muốn tìm số bị trừ, lấy hiệu cộng với số trừ: ${fmt(c)} + ${fmt(b)} = ${fmt(a)}.';
        } else {
          answer = b;
          wrongInverse = a + c;
          rule = 'Muốn tìm số trừ, lấy số bị trừ trừ đi hiệu: ${fmt(a)} $_minus ${fmt(c)} = ${fmt(b)}.';
        }
      case '×':
        a = pick(tables, r);
        b = between(r, 2, 10);
        if (r.nextBool()) (a, b) = (b, a);
        c = a * b;
        answer = first ? a : b;
        wrongInverse = c - (first ? b : a);
        rule = 'Muốn tìm thừa số, lấy tích chia cho thừa số kia: ${fmt(c)} : ${fmt(first ? b : a)} = ${fmt(answer)}.';
      default:
        b = pick(tables, r);
        c = between(r, 2, 10);
        a = b * c;
        if (first) {
          answer = a;
          wrongInverse = c + b;
          rule = 'Muốn tìm số bị chia, lấy thương nhân với số chia: ${fmt(c)} × ${fmt(b)} = ${fmt(a)}.';
        } else {
          answer = b;
          wrongInverse = a * c;
          rule = 'Muốn tìm số chia, lấy số bị chia chia cho thương: ${fmt(a)} : ${fmt(c)} = ${fmt(b)}.';
        }
    }
    final opText = op == '-' ? _minus : op;
    final prompt = first ? '? $opText ${fmt(b)} = ${fmt(c)}' : '${fmt(a)} $opText ? = ${fmt(c)}';
    final o = numericOptions(r, answer, p.answers,
        min: 0, max: math.max(answer, wrongInverse) + 20, preferred: [wrongInverse, answer + 1, answer - 1, answer + 10, answer - 10]);
    return simpleQuestion(
      id,
      prompt: prompt,
      speech: 'Tìm số thích hợp: ${speakMath(prompt)}.',
      o: o,
      explanation: rule,
      data: {'result': answer},
    );
  }
}

/// Nhân, chia số có nhiều chữ số.
/// - aDigits: số chữ số của thừa số lớn / số bị chia; bDigits: 1 hoặc 2
/// - ops: ["×", ":"]; remainder: true = chia có dư; bValues: số nhân/chia cố định (vd. [10, 100, 1000])
/// - format: "choice" | "exact_or_not" (Chia hết hay có dư? – hai đáp án)
class MulDivBigGenerator extends QuestionGenerator {
  const MulDivBigGenerator();

  @override
  String get id => 'mul_div_big';

  @override
  Question generate(GenParams p, math.Random r) {
    final aDigits = p.intOf('aDigits', 2);
    final bDigits = p.intOf('bDigits', 1);
    final op = pick(p.strList('ops', const ['×', ':']), r);
    final max = p.intOf('max', 100000);
    final fixed = p.intList('bValues', const []);
    int pickB() => fixed.isNotEmpty ? pick(fixed, r) : (bDigits == 1 ? between(r, 2, 9) : between(r, 11, 99));
    final lo = pow10(aDigits - 1), hi = pow10(aDigits) - 1;

    if (p.strOf('format', 'choice') == 'exact_or_not') {
      final b = between(r, 2, 9);
      final q = between(r, math.max(2, lo ~/ b), math.max(2, hi ~/ b));
      final exact = r.nextBool();
      final a = b * q + (exact ? 0 : between(r, 1, b - 1));
      final rem = a % b;
      return Question(
        generator: id,
        prompt: '${fmt(a)} : $b là phép chia hết hay phép chia có dư?',
        speech: '${cap(say(a))} chia ${say(b)} là phép chia hết hay phép chia có dư?',
        options: const ['Chia hết', 'Có dư'],
        answer: rem == 0 ? 0 : 1,
        explanation: rem == 0 ? '${fmt(a)} : $b = ${fmt(a ~/ b)}' : '${fmt(a)} : $b = ${fmt(a ~/ b)} (dư $rem)',
        explanationSpeech: rem == 0
            ? '${cap(say(a))} chia ${say(b)} được ${say(a ~/ b)}, không dư.'
            : '${cap(say(a))} chia ${say(b)} được ${say(a ~/ b)}, dư ${say(rem)}.',
      );
    }

    if (op == '×') {
      late int a, b;
      for (var t = 0;; t++) {
        a = between(r, lo, hi);
        b = pickB();
        if (a * b <= max || t > 200) break;
      }
      final result = a * b;
      final o = numericOptions(r, result, p.answers, min: 0, max: result * 10 + 100, preferred: [
        result + b,
        result - b,
        result + 10,
        result - 10,
        if (b < 10) a * (b + 1),
        result + pow10(math.max(1, '$result'.length - 2)),
      ]);
      final prompt = '${fmt(a)} × ${fmt(b)} = ?';
      return simpleQuestion(id, prompt: prompt, o: o, explanation: '${fmt(a)} × ${fmt(b)} = ${fmt(result)}', data: {'result': result});
    }

    late int a, b, q;
    for (var t = 0;; t++) {
      b = pickB();
      final qLo = math.max(2, (lo + b - 1) ~/ b), qHi = hi ~/ b;
      if (qHi >= qLo || t > 200) {
        q = between(r, qLo, math.max(qLo, qHi));
        a = b * q;
        break;
      }
    }
    if (p.boolOf('remainder', false)) {
      final rem = between(r, 1, b - 1);
      a += rem;
      String lbl(int qq, int rr) => '${fmt(qq)} dư $rr';
      final wrong = <String>[
        lbl(q + 1, rem),
        if (q > 1) lbl(q - 1, rem),
        if (rem + 1 < b) lbl(q, rem + 1),
        if (rem > 1) lbl(q, rem - 1),
        lbl(q - 1, rem + b),
      ];
      final o = textOptions(r, lbl(q, rem), wrong, p.answers);
      return simpleQuestion(
        id,
        prompt: '${fmt(a)} : ${fmt(b)} = ?',
        speech: '${cap(say(a))} chia ${say(b)} được bao nhiêu, dư bao nhiêu?',
        o: o,
        explanation: '${fmt(a)} : ${fmt(b)} = ${fmt(q)} (dư $rem). Số dư bé hơn số chia.',
        explanationSpeech: '${cap(say(a))} chia ${say(b)} được ${say(q)}, dư ${say(rem)}.',
      );
    }
    final o = numericOptions(r, q, p.answers, min: 1, max: q * 10 + 100, preferred: [
      q + 1,
      q - 1,
      q * 10,
      if (q % 10 == 0) q ~/ 10,
      q + 10,
      q - 10,
    ]);
    return simpleQuestion(
      id,
      prompt: '${fmt(a)} : ${fmt(b)} = ?',
      o: o,
      explanation: '${fmt(a)} : ${fmt(b)} = ${fmt(q)} (vì ${fmt(q)} × ${fmt(b)} = ${fmt(a)})',
      data: {'result': q},
    );
  }
}

/// Lớp 3: gấp lên, giảm đi một số lần; số lớn gấp mấy lần số bé; một phần mấy của một số.
/// kinds: ["up", "down", "how_many", "part"]; tables: [2..9]
class TimesGenerator extends QuestionGenerator {
  const TimesGenerator();

  @override
  String get id => 'times';

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['up', 'down', 'how_many', 'part']), r);
    final t = pick(p.intList('tables', const [2, 3, 4, 5, 6, 7, 8, 9]), r);
    final k = between(r, 2, 9);
    final big = t * k;
    switch (kind) {
      case 'up':
        final o = numericOptions(r, big, p.answers, max: 200, preferred: [k + t, big + k, big - k, big + t]);
        return simpleQuestion(
          id,
          prompt: 'Gấp $k lên $t lần được bao nhiêu?',
          o: o,
          explanation: 'Gấp $k lên $t lần: $k × $t = $big.',
          data: {'result': big},
        );
      case 'down':
        final o = numericOptions(r, k, p.answers, max: 200, preferred: [big - t, k + 1, k - 1, big ~/ 2]);
        return simpleQuestion(
          id,
          prompt: 'Giảm $big đi $t lần được bao nhiêu?',
          o: o,
          explanation: 'Giảm $big đi $t lần: $big : $t = $k.',
          data: {'result': k},
        );
      case 'how_many':
        final o = numericOptions(r, k, p.answers, max: 200, preferred: [big - t, k + 1, k - 1]);
        return simpleQuestion(
          id,
          prompt: 'Số lớn là $big, số bé là $t. Số lớn gấp mấy lần số bé?',
          o: o,
          explanation: '$big : $t = $k. Số lớn gấp $k lần số bé.',
          data: {'result': k},
        );
      default: // part: 1/t của big
        final o = numericOptions(r, k, p.answers, max: 200, preferred: [big - t, big * t, k + 1, k - 1]);
        return simpleQuestion(
          id,
          prompt: '1/$t của $big là bao nhiêu?',
          o: o,
          explanation: 'Lấy $big chia thành $t phần bằng nhau: $big : $t = $k.',
          data: {'result': k},
        );
    }
  }
}

/// Tính giá trị biểu thức. kinds:
/// - mix (lớp 3): nhân chia trước, cộng trừ sau – "24 + 6 × 3"
/// - paren (lớp 3): có dấu ngoặc – "(24 + 6) : 3"
/// - letter (lớp 4): biểu thức chứa chữ – "Nếu a = 5 thì 12 + a × 3 = ?"
/// - quick (lớp 4): tính thuận tiện – "25 × 7 × 4", "47 × 6 + 47 × 4", "36 + 78 + 64"
class ExpressionGenerator extends QuestionGenerator {
  const ExpressionGenerator();

  @override
  String get id => 'expression';

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['mix', 'paren']), r);
    switch (kind) {
      case 'paren':
        return _paren(p, r);
      case 'letter':
        return _letter(p, r);
      case 'quick':
        return _quick(p, r);
      default:
        return _mix(p, r);
    }
  }

  Question _finish(GenParams p, math.Random r, String expr, List<String> steps, int value, List<int> wrong,
      {String? lead}) {
    final o = numericOptions(r, value, p.answers, min: 0, max: math.max(value, wrong.fold<int>(0, (m, w) => math.max(m, w))) + 50,
        preferred: [...wrong.where((w) => w >= 0), value + 1, value - 1, value + 10]);
    final prompt = '${lead ?? ''}$expr = ?';
    return simpleQuestion(
      id,
      prompt: prompt,
      speech: '${lead == null ? 'Tính: ' : ''}${speakMath(prompt)}',
      o: o,
      explanation: [expr, ...steps].join(' = '),
      data: {'result': value},
    );
  }

  Question _mix(GenParams p, math.Random r) {
    final a = between(r, 10, 90);
    final b = between(r, 2, 9);
    final c = between(r, 2, 9);
    switch (r.nextInt(4)) {
      case 0: // a + b × c
        return _finish(p, r, '$a + $b × $c', ['$a + ${b * c}', '${a + b * c}'], a + b * c, [(a + b) * c]);
      case 1: // a − b × c (đảm bảo không âm)
        final aa = b * c + between(r, 1, 60);
        return _finish(p, r, '$aa $_minus $b × $c', ['$aa $_minus ${b * c}', '${aa - b * c}'], aa - b * c,
            [(aa - b) * c]);
      case 2: // b × c + a
        return _finish(p, r, '$b × $c + $a', ['${b * c} + $a', '${b * c + a}'], b * c + a, [b * (c + a)]);
      default: // (b·c) : c + a
        final q = b * c;
        return _finish(p, r, '$a + $q : $c', ['$a + $b', '${a + b}'], a + b, [(a + q) ~/ c]);
    }
  }

  Question _paren(GenParams p, math.Random r) {
    final b = between(r, 2, 9);
    final c = between(r, 2, 9);
    switch (r.nextInt(3)) {
      case 0: // (a + d) × c
        final a = between(r, 2, 30), d = between(r, 2, 20);
        return _finish(p, r, '($a + $d) × $c', ['${a + d} × $c', '${(a + d) * c}'], (a + d) * c, [a + d * c]);
      case 1: // (x − y) : c, chia hết
        final q = between(r, 2, 12);
        final y = between(r, 2, 30);
        final x = q * c + y;
        return _finish(p, r, '($x $_minus $y) : $c', ['${x - y} : $c', '$q'], q,
            [if (y % c == 0) x - y ~/ c, q + 1]);
      default: // a × (b + c)
        final a = between(r, 2, 9);
        return _finish(p, r, '$a × ($b + $c)', ['$a × ${b + c}', '${a * (b + c)}'], a * (b + c), [a * b + c]);
    }
  }

  Question _letter(GenParams p, math.Random r) {
    final letter = pick(const ['a', 'b', 'c', 'n'], r);
    final v = between(r, 2, 9);
    final x = between(r, 10, 60);
    final k = between(r, 2, 9);
    final y = between(r, 1, v * k - 1);
    final (expr, steps, value, wrong) = switch (r.nextInt(3)) {
      0 => ('$x + $letter × $k', ['$x + $v × $k', '$x + ${v * k}', '${x + v * k}'], x + v * k, [(x + v) * k]),
      1 => ('$letter × $k $_minus $y', ['$v × $k $_minus $y', '${v * k} $_minus $y', '${v * k - y}'], v * k - y, [v * (k - y).abs(), v + k]),
      _ => ('($x + $letter) × $k', ['($x + $v) × $k', '${x + v} × $k', '${(x + v) * k}'], (x + v) * k, [x + v * k]),
    };
    final o = numericOptions(r, value, p.answers, min: 0, max: value + 100,
        preferred: [...wrong, value + 1, value - 1, value + k]);
    final prompt = 'Nếu $letter = $v thì $expr = ?';
    return simpleQuestion(
      id,
      prompt: prompt,
      speech: 'Nếu $letter bằng ${say(v)} thì ${speakMath('$expr = ?')}',
      o: o,
      explanation: 'Thay $letter = $v: ${steps.join(' = ')}',
      explanationSpeech: 'Thay $letter bằng ${say(v)}, ta được ${say(value)}.',
      data: {'result': value},
    );
  }

  Question _quick(GenParams p, math.Random r) {
    switch (r.nextInt(3)) {
      case 0: // 25 × k × 4  hoặc 2 × k × 50
        final (x, y) = pick(const [(25, 4), (2, 50), (5, 20), (4, 25)], r);
        final k = between(r, 3, 9);
        final v = x * k * y;
        return _finish(p, r, '$x × $k × $y', ['$k × ${x * y}', fmt(v)], v, [v ~/ 10, v + x * y]);
      case 1: // a × b + a × c = a × (b + c)
        final a = between(r, 12, 99);
        final b = between(r, 2, 8);
        final c = 10 - b;
        final v = a * 10;
        return _finish(p, r, '$a × $b + $a × $c', ['$a × ($b + $c)', '$a × 10', fmt(v)], v, [a * b + c, v + a]);
      default: // a + b + (tròn trăm − a)
        final a = between(r, 11, 89);
        final b = between(r, 11, 89);
        final c = 100 - a;
        final v = 100 + b;
        return _finish(p, r, '$a + $b + $c', ['($a + $c) + $b', '100 + $b', fmt(v)], v, [v + 10, v - 10]);
    }
  }
}

/// Bài toán có lời văn nhiều bước. kinds:
/// - two_step (lớp 3) – bài toán giải bằng hai phép tính
/// - unit_rate (lớp 4) – rút về đơn vị
/// - average (lớp 4) – trung bình cộng
/// - sum_diff (lớp 4) – tìm hai số khi biết tổng và hiệu
/// - sum_ratio, diff_ratio (lớp 5) – tìm hai số khi biết tổng (hiệu) và tỉ số
class StoryGenerator extends QuestionGenerator {
  const StoryGenerator();

  @override
  String get id => 'story';

  static const kinds = ['two_step', 'unit_rate', 'average', 'sum_diff', 'sum_ratio', 'diff_ratio'];

  @override
  List<String> validate(GenParams p) =>
      p.strList('kinds', const ['two_step']).where((k) => !kinds.contains(k)).map((k) => 'kinds không có "$k"').toList();

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['two_step']), r);
    late String text, explanation;
    late int answer;
    var wrong = <int>[];
    switch (kind) {
      case 'two_step':
        switch (r.nextInt(4)) {
          case 0:
            final a = between(r, 12, 60), b = between(r, 5, 30);
            text = 'Thùng thứ nhất có $a l dầu. Thùng thứ hai có nhiều hơn thùng thứ nhất $b l. Cả hai thùng có bao nhiêu lít dầu?';
            answer = a + a + b;
            wrong = [a + b, a + b + b];
            explanation = 'Thùng thứ hai: $a + $b = ${a + b} (l). Cả hai thùng: $a + ${a + b} = $answer (l).';
          case 1:
            final a = between(r, 30, 90), b = between(r, 5, a - 10);
            text = 'Lớp 3A thu được $a kg giấy. Lớp 3B thu được ít hơn lớp 3A $b kg. Cả hai lớp thu được bao nhiêu ki-lô-gam giấy?';
            answer = a + a - b;
            wrong = [a - b, a + b];
            explanation = 'Lớp 3B: $a $_minus $b = ${a - b} (kg). Cả hai lớp: $a + ${a - b} = $answer (kg).';
          case 2:
            final a = between(r, 3, 9), k = between(r, 2, 5);
            text = 'Lan có $a bông hoa. Mai có số hoa gấp $k lần của Lan. Cả hai bạn có bao nhiêu bông hoa?';
            answer = a + a * k;
            wrong = [a * k, a + k];
            explanation = 'Mai có: $a × $k = ${a * k} (bông). Cả hai bạn: $a + ${a * k} = $answer (bông).';
          default:
            final boxes = between(r, 3, 8), each = between(r, 4, 9), give = between(r, 2, boxes * each - 2);
            text = 'Có $boxes hộp bút, mỗi hộp có $each cái. Cô cho các bạn $give cái bút. Còn lại bao nhiêu cái bút?';
            answer = boxes * each - give;
            wrong = [boxes * each, boxes + each - give];
            explanation = 'Có tất cả: $boxes × $each = ${boxes * each} (cái). Còn lại: ${boxes * each} $_minus $give = $answer (cái).';
        }
      case 'unit_rate':
        final n = between(r, 2, 6), each = between(r, 4, 12), m = between(r, 2, 9);
        final total = n * each;
        text = '$n hộp bánh như nhau có $total cái bánh. Hỏi $m hộp như thế có bao nhiêu cái bánh?';
        answer = each * m;
        wrong = [total + m, total * m, each];
        explanation = 'Mỗi hộp: $total : $n = $each (cái). $m hộp: $each × $m = $answer (cái).';
      case 'average':
        final count = between(r, 2, 4);
        final avg = between(r, 20, 60);
        final values = [for (var i = 0; i < count - 1; i++) avg + between(r, -8, 8)];
        values.add(avg * count - values.fold(0, (s, v) => s + v));
        if (values.any((v) => v <= 0)) return generate(p, r);
        final sum = avg * count;
        text = 'Trung bình cộng của các số ${values.join(', ')} là bao nhiêu?';
        answer = avg;
        wrong = [sum, avg + 1, avg - 1, sum ~/ (count + 1)];
        explanation = '(${values.join(' + ')}) : $count = $sum : $count = $avg';
      case 'sum_diff':
        final small = between(r, 10, 60), diff = between(r, 2, 30);
        final big = small + diff, sum = small + big;
        final askBig = r.nextBool();
        text = 'Tổng hai số là $sum, hiệu hai số là $diff. Số ${askBig ? 'lớn' : 'bé'} là bao nhiêu?';
        answer = askBig ? big : small;
        wrong = [askBig ? small : big, sum - diff, sum ~/ 2];
        explanation = askBig
            ? 'Số lớn = (tổng + hiệu) : 2 = ($sum + $diff) : 2 = $big.'
            : 'Số bé = (tổng $_minus hiệu) : 2 = ($sum $_minus $diff) : 2 = $small.';
      case 'sum_ratio':
        final m = between(r, 1, 4), n = between(r, m + 1, 7), part = between(r, 3, 15);
        if (Frac.gcd(m, n) != 1) return generate(p, r);
        final sum = (m + n) * part;
        final askBig = r.nextBool();
        text = 'Tổng hai số là $sum. Số bé bằng $m/$n số lớn. Số ${askBig ? 'lớn' : 'bé'} là bao nhiêu?';
        answer = (askBig ? n : m) * part;
        wrong = [(askBig ? m : n) * part, sum ~/ n * m, part];
        explanation = 'Tổng số phần bằng nhau: $m + $n = ${m + n}. Mỗi phần: $sum : ${m + n} = $part. '
            'Số ${askBig ? 'lớn' : 'bé'}: $part × ${askBig ? n : m} = $answer.';
      default: // diff_ratio
        final m = between(r, 1, 4), n = between(r, m + 1, 8), part = between(r, 3, 15);
        if (Frac.gcd(m, n) != 1) return generate(p, r);
        final diff = (n - m) * part;
        final askBig = r.nextBool();
        text = 'Hiệu hai số là $diff. Số bé bằng $m/$n số lớn. Số ${askBig ? 'lớn' : 'bé'} là bao nhiêu?';
        answer = (askBig ? n : m) * part;
        wrong = [(askBig ? m : n) * part, diff * n, part];
        explanation = 'Hiệu số phần bằng nhau: $n $_minus $m = ${n - m}. Mỗi phần: $diff : ${n - m} = $part. '
            'Số ${askBig ? 'lớn' : 'bé'}: $part × ${askBig ? n : m} = $answer.';
    }
    final o = numericOptions(r, answer, p.answers, min: 1, max: answer * 4 + 50,
        preferred: [...wrong, answer + 1, answer - 1, answer + 10]);
    return simpleQuestion(id, prompt: text, o: o, explanation: explanation, data: {'result': answer});
  }
}
