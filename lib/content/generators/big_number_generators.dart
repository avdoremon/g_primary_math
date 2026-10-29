import 'dart:math' as math;

import '../numbers.dart';
import '../question.dart';
import 'generator.dart';

/// Tên các hàng, từ hàng đơn vị (chỉ số 0) trở lên.
const placeNames = [
  'hàng đơn vị',
  'hàng chục',
  'hàng trăm',
  'hàng nghìn',
  'hàng chục nghìn',
  'hàng trăm nghìn',
  'hàng triệu',
  'hàng chục triệu',
  'hàng trăm triệu',
];

int pow10(int k) {
  var p = 1;
  for (var i = 0; i < k; i++) {
    p *= 10;
  }
  return p;
}

/// Số có đúng [digits] chữ số; [zeroChance] (0..1) để thỉnh thoảng có chữ số 0 ở giữa (đọc "linh", "không trăm").
int numberWithDigits(math.Random r, int digits, {double zeroChance = .35}) {
  final ds = [between(r, 1, 9), for (var i = 1; i < digits; i++) between(r, 0, 9)];
  if (digits >= 3 && r.nextDouble() < zeroChance) ds[between(r, 1, digits - 2)] = 0;
  return int.parse(ds.join());
}

/// Đề + giọng đọc dùng chung cho câu hỏi có đáp án số / chữ.
Question simpleQuestion(
  String generator, {
  required String prompt,
  String? speech,
  required ({List<String> options, int answer}) o,
  required String explanation,
  String? explanationSpeech,
  Map<String, Object?> data = const {},
}) =>
    Question(
      generator: generator,
      prompt: prompt,
      speech: speech ?? cap(speakMath(prompt)),
      options: o.options,
      answer: o.answer,
      explanation: explanation,
      explanationSpeech: explanationSpeech ?? cap(speakMath(explanation)),
      data: data,
    );

/// Lớp 3–4: đọc, viết, cấu tạo số có nhiều chữ số.
/// - digits: [4, 5] số chữ số
/// - kinds: write (đọc → viết số) | value (giá trị chữ số) | place (chữ số thuộc hàng nào) | expand (tổng các hàng → số)
class DigitsGenerator extends QuestionGenerator {
  const DigitsGenerator();

  @override
  String get id => 'digits';

  @override
  List<String> validate(GenParams p) =>
      p.intList('digits', const [4]).any((d) => d < 2 || d > 9) ? const ['digits trong khoảng 2–9'] : const [];

  @override
  Question generate(GenParams p, math.Random r) {
    final d = pick(p.intList('digits', const [4]), r);
    final kind = pick(p.strList('kinds', const ['write', 'value', 'place', 'expand']), r);
    final n = numberWithDigits(r, d);
    final s = '$n';
    final maxN = pow10(d + 1);

    switch (kind) {
      case 'value':
      case 'place':
        // Chọn chữ số khác 0, chỉ xuất hiện một lần, không ở hàng đơn vị (cho câu hỏi có ý nghĩa).
        final positions = [
          for (var k = 1; k < d; k++)
            if (s[d - 1 - k] != '0' && s.split('').where((c) => c == s[d - 1 - k]).length == 1) k,
        ];
        if (positions.isEmpty) return generate(p, r);
        final k = pick(positions, r);
        final digit = int.parse(s[d - 1 - k]);
        if (kind == 'value') {
          final value = digit * pow10(k);
          final wrong = [for (var j = 0; j < d; j++) if (j != k) fmt(digit * pow10(j))];
          final o = textOptions(r, fmt(value), wrong, p.answers);
          return simpleQuestion(
            id,
            prompt: 'Giá trị của chữ số $digit trong số ${fmt(n)} là:',
            o: o,
            explanation: 'Chữ số $digit ở ${placeNames[k]} nên có giá trị ${fmt(value)}.',
          );
        }
        final o = textOptions(r, cap(placeNames[k]), [for (var j = 0; j < d; j++) cap(placeNames[j])], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Chữ số $digit trong số ${fmt(n)} thuộc hàng nào?',
          o: o,
          explanation: 'Số ${fmt(n)}: chữ số $digit ở ${placeNames[k]}.',
        );
      case 'expand':
        final parts = [
          for (var k = d - 1; k >= 0; k--)
            if (s[d - 1 - k] != '0') int.parse(s[d - 1 - k]) * pow10(k),
        ];
        if (parts.length < 2) return generate(p, r);
        final squeezed = int.parse(parts.map((v) => '$v'.replaceAll('0', '')).join());
        final o = numericOptions(r, n, p.answers, min: 1, max: maxN, preferred: [
          squeezed,
          n * 10,
          if (n % 10 == 0) n ~/ 10,
          n + pow10(d - 2),
          n - pow10(d - 2),
        ]);
        final expr = parts.map(fmt).join(' + ');
        return simpleQuestion(
          id,
          prompt: '$expr = ?',
          o: o,
          explanation: '$expr = ${fmt(n)}',
        );
      default: // write
        final swapped = <int>{
          for (var k = 0; k + 1 < d; k++)
            int.parse(s.substring(0, k) + s[k + 1] + s[k] + s.substring(k + 2)),
        }.where((v) => v != n && '$v'.length == d);
        final noZero = s.contains('0') ? int.tryParse(s.replaceFirst('0', '')) : null;
        final o = numericOptions(r, n, p.answers, min: 1, max: maxN, preferred: [
          ...swapped,
          if (noZero != null && noZero > 0) noZero,
          int.parse('${s[0]}0${s.substring(1)}'),
        ]);
        final words = cap(say(n));
        return simpleQuestion(
          id,
          prompt: '$words. Số này viết là:',
          speech: '$words. Số này viết là số nào?',
          o: o,
          explanation: '$words viết là ${fmt(n)}.',
          explanationSpeech: '$words viết là: ${s.split('').map((c) => say(int.parse(c))).join(', ')}.',
        );
    }
  }
}

/// Làm tròn số. to: ["tens", "hundreds", "thousands", "ten_thousands", "hundred_thousands"]; digits: [4, 5, 6].
class RoundingGenerator extends QuestionGenerator {
  const RoundingGenerator();

  @override
  String get id => 'rounding';

  static const _units = {'tens': 1, 'hundreds': 2, 'thousands': 3, 'ten_thousands': 4, 'hundred_thousands': 5};

  @override
  List<String> validate(GenParams p) =>
      p.strList('to', const ['hundreds']).any((t) => !_units.containsKey(t)) ? ['to chỉ gồm ${_units.keys.join(', ')}'] : const [];

  @override
  Question generate(GenParams p, math.Random r) {
    final k = _units[pick(p.strList('to', const ['hundreds']), r)]!;
    final d = math.max(k + 1, pick(p.intList('digits', const [4]), r));
    final u = pow10(k);
    var n = numberWithDigits(r, d, zeroChance: .15);
    if (n % u == 0) n += between(r, 1, u - 1);
    final rounded = (n + u ~/ 2) ~/ u * u;
    final digit = n ~/ (u ~/ 10) % 10;
    final down = n ~/ u * u;
    final up = down + u;
    final o = textOptions(
      r,
      fmt(rounded),
      [fmt(rounded == up ? down : up), fmt(rounded + (rounded == up ? u : -u)), fmt((n + u ~/ 20) ~/ (u ~/ 10) * (u ~/ 10)), fmt(up + u), if (down >= u) fmt(down - u)],
      p.answers,
    );
    final place = placeNames[k];
    final lower = placeNames[k - 1];
    final rule = digit >= 5 ? '$digit ≥ 5 nên làm tròn lên' : '$digit < 5 nên làm tròn xuống';
    return simpleQuestion(
      id,
      prompt: 'Làm tròn số ${fmt(n)} đến $place:',
      o: o,
      explanation: 'Chữ số ở $lower là $rule: ${fmt(rounded)}.',
      explanationSpeech: 'Chữ số ở $lower là ${say(digit)}, ${digit >= 5 ? 'lớn hơn hoặc bằng năm nên làm tròn lên' : 'bé hơn năm nên làm tròn xuống'}. '
          'Được ${say(rounded)}.',
      data: {'n': n, 'rounded': rounded},
    );
  }
}

/// Lớp 3: chữ số La Mã (I đến XX). kinds: to_number | to_roman.
class RomanGenerator extends QuestionGenerator {
  const RomanGenerator();

  @override
  String get id => 'roman';

  static const _values = [10, 9, 5, 4, 1];
  static const _symbols = ['X', 'IX', 'V', 'IV', 'I'];

  static List<(String, int)> parts(int n) {
    final out = <(String, int)>[];
    for (var i = 0; i < _values.length; i++) {
      while (n >= _values[i]) {
        out.add((_symbols[i], _values[i]));
        n -= _values[i];
      }
    }
    return out;
  }

  static String roman(int n) => parts(n).map((e) => e.$1).join();

  @override
  Question generate(GenParams p, math.Random r) {
    final max = math.min(p.intOf('max', 20), 39);
    final n = between(r, 1, max);
    final rm = roman(n);
    // Nhầm thường gặp: IV ↔ VI, IX ↔ XI, XIV ↔ XVI.
    int flip(int v) => switch (v % 10) { 4 => v + 2, 6 => v - 2, 9 => v + 2, _ => v };
    final near = <int>{flip(n), n + 1, n - 1, n + 5, n - 5, n + 10, n - 10}.where((v) => v >= 1 && v <= 39 && v != n).toList();
    final ps = parts(n);
    final explanation = ps.length == 1
        ? '$rm = $n'
        : '$rm = ${ps.map((e) => e.$1).join(' + ')} = ${ps.map((e) => e.$2).join(' + ')} = $n';
    final explanationSpeech = 'Số La Mã này là số ${say(n)}.';
    if (pick(p.strList('kinds', const ['to_number', 'to_roman']), r) == 'to_roman') {
      final o = textOptions(r, rm, [for (final v in near) roman(v)], p.answers);
      return simpleQuestion(
        id,
        prompt: 'Số $n viết bằng chữ số La Mã là:',
        o: o,
        explanation: explanation,
        explanationSpeech: explanationSpeech,
      );
    }
    final o = textOptions(r, '$n', [for (final v in near) '$v'], p.answers);
    return simpleQuestion(
      id,
      prompt: 'Số La Mã $rm là số nào?',
      speech: 'Số La Mã trên màn hình là số nào?',
      o: o,
      explanation: explanation,
      explanationSpeech: explanationSpeech,
    );
  }
}

/// Lớp 4: số chẵn, số lẻ. format "side": hai đáp án Số chẵn / Số lẻ (bước sang bên); "pick": chọn số chẵn / lẻ.
class EvenOddGenerator extends QuestionGenerator {
  const EvenOddGenerator();

  @override
  String get id => 'even_odd';

  @override
  Question generate(GenParams p, math.Random r) {
    final max = p.intOf('max', 1000);
    if (p.strOf('format', 'side') == 'side') {
      final n = between(r, 10, max);
      final even = n.isEven;
      return Question(
        generator: id,
        prompt: 'Số ${fmt(n)} là số chẵn hay số lẻ?',
        speech: 'Số ${say(n)} là số chẵn hay số lẻ?',
        options: const ['Số chẵn', 'Số lẻ'],
        answer: even ? 0 : 1,
        explanation: 'Chữ số hàng đơn vị là ${n % 10} nên ${fmt(n)} là số ${even ? 'chẵn' : 'lẻ'}.',
        explanationSpeech: 'Chữ số hàng đơn vị là ${say(n % 10)} nên đây là số ${even ? 'chẵn' : 'lẻ'}.',
      );
    }
    final wantEven = r.nextBool();
    final count = p.answers;
    int make(bool even) {
      final v = between(r, 10, max);
      return v.isEven == even ? v : (v + 1 <= max ? v + 1 : v - 1);
    }
    final correct = make(wantEven);
    final others = <int>{};
    while (others.length < count - 1) {
      final v = make(!wantEven);
      if (v != correct) others.add(v);
    }
    final o = textOptions(r, fmt(correct), [for (final v in others) fmt(v)], count);
    final word = wantEven ? 'chẵn' : 'lẻ';
    return simpleQuestion(
      id,
      prompt: 'Số nào là số $word?',
      o: o,
      explanation: '${fmt(correct)} có chữ số hàng đơn vị là ${correct % 10} nên là số $word.',
    );
  }
}
