import 'dart:math' as math;

import '../numbers.dart';
import '../question.dart';
import 'big_number_generators.dart';
import 'generator.dart';

const _minus = '−';

/// Đáp án phân số: bỏ đáp án sai trùng giá trị với đáp án đúng (vd. 2/4 khi đáp án là 1/2) và phân số ≤ 0.
({List<String> options, int answer}) fracOptions(math.Random r, Frac correct, Iterable<Frac> wrong, int count) {
  final seen = <String>{};
  final pool = <String>[];
  for (final w in wrong) {
    if (w.d <= 0 || w.n <= 0 || w == correct) continue;
    final t = w.text(compact: true);
    if (seen.add(t)) pool.add(t);
  }
  return textOptions(r, correct.text(compact: true), pool, count);
}

/// Đáp án số thập phân, bỏ giá trị trùng và giá trị âm.
({List<String> options, int answer}) decOptions(math.Random r, Dec correct, Iterable<Dec> wrong, int count,
    {String unit = ''}) {
  final suffix = unit.isEmpty ? '' : ' $unit';
  final pool = <String>{
    for (final w in wrong)
      if (w.units >= 0 && w != correct) '${w.text}$suffix',
  }.toList();
  return textOptions(r, '${correct.text}$suffix', pool, count);
}

Frac _randFrac(math.Random r, {int maxDen = 9, bool proper = true, bool reduced = true}) {
  for (;;) {
    final d = between(r, 2, maxDen);
    final n = between(r, 1, proper ? d - 1 : d * 2);
    final f = Frac(n, d);
    if (!reduced || f.isReduced) return f;
  }
}

/// Phân số (lớp 3: một phần mấy; lớp 4: phân số; lớp 5: hỗn số, phân số thập phân). kinds:
/// picture | of_number | compare | reduce | equivalent | common_den | add | sub | mul | div | mixed | decimal_fraction
/// - unitOnly: chỉ dùng phân số có tử số 1 (lớp 3)
/// - sameDen: cộng, trừ cùng mẫu số
/// - maxDen: mẫu số lớn nhất (mặc định 9)
class FractionGenerator extends QuestionGenerator {
  const FractionGenerator();

  @override
  String get id => 'fraction';

  static const kinds = [
    'picture', 'of_number', 'compare', 'reduce', 'equivalent', 'common_den', //
    'add', 'sub', 'mul', 'div', 'mixed', 'decimal_fraction',
  ];

  @override
  List<String> validate(GenParams p) =>
      p.strList('kinds', const ['picture']).where((k) => !kinds.contains(k)).map((k) => 'kinds không có "$k"').toList();

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['picture']), r);
    final unitOnly = p.boolOf('unitOnly', false);
    final maxDen = p.intOf('maxDen', 9);
    switch (kind) {
      case 'picture':
        final d = between(r, 2, math.min(maxDen, 8));
        final n = unitOnly ? 1 : between(r, 1, d - 1);
        final f = Frac(n, d);
        final o = unitOnly
            ? fracOptions(r, f, [for (var k = 2; k <= 9; k++) Frac(1, k)]..shuffle(r), p.answers)
            : fracOptions(r, f, [Frac(d - n, d), Frac(d, n), Frac(n, d + 1), Frac(n + 1, d), if (n > 1) Frac(n - 1, d)], p.answers);
        final shape = pick(const ['circle', 'rect', 'bar'], r);
        return simpleQuestion(
          id,
          prompt: unitOnly ? 'Đã tô màu một phần mấy hình?' : 'Phân số chỉ phần đã tô màu của hình là:',
          o: o,
          explanation: 'Hình chia thành $d phần bằng nhau, đã tô màu $n phần: ${f.text()}.',
          explanationSpeech: 'Hình chia thành ${say(d)} phần bằng nhau, đã tô màu ${say(n)} phần. Đó là ${f.speech}.',
          data: {'kind': 'fraction_pic', 'n': n, 'd': d, 'shape': shape},
        );
      case 'of_number':
        final d = between(r, 2, math.min(maxDen, 9));
        final n = unitOnly ? 1 : between(r, 1, d - 1);
        final k = between(r, 2, 10);
        final whole = d * k;
        final unit = pick(const ['kg', 'm', 'l', 'quả cam', 'học sinh', 'cái kẹo'], r);
        final answer = n * k;
        final o = numericOptions(r, answer, p.answers, min: 1, max: whole * 2,
            preferred: [k, whole - answer, whole ~/ n + 1, answer + k, answer + 1, answer - 1], label: (v) => '$v $unit');
        final f = Frac(n, d);
        return simpleQuestion(
          id,
          prompt: '${f.text()} của $whole $unit là:',
          o: o,
          explanation: n == 1 ? '$whole : $d = $answer ($unit)' : '$whole : $d × $n = $answer ($unit)',
          explanationSpeech: n == 1
              ? 'Lấy ${say(whole)} chia ${say(d)} được ${say(answer)}.'
              : 'Lấy ${say(whole)} chia ${say(d)} rồi nhân ${say(n)}, được ${say(answer)}.',
        );
      case 'compare':
        late Frac a, b;
        late String rule;
        switch (r.nextInt(3)) {
          case 0:
            final d = between(r, 3, maxDen);
            a = Frac(between(r, 1, d * 2), d);
            b = Frac(between(r, 1, d * 2), d);
            rule = 'Hai phân số cùng mẫu số: phân số nào có tử số lớn hơn thì lớn hơn.';
          case 1:
            final n = between(r, 1, 6);
            a = Frac(n, between(r, 2, maxDen));
            b = Frac(n, between(r, 2, maxDen));
            rule = 'Hai phân số cùng tử số: phân số nào có mẫu số bé hơn thì lớn hơn.';
          default:
            a = _randFrac(r, maxDen: maxDen);
            b = _randFrac(r, maxDen: maxDen);
            rule = 'Quy đồng: ${a.n * b.d}/${a.d * b.d} và ${b.n * a.d}/${a.d * b.d}.';
        }
        final sign = a > b ? '>' : (a < b ? '<' : '=');
        const signs = ['>', '<', '='];
        return simpleQuestion(
          id,
          prompt: '${a.text()} … ${b.text()}',
          speech: 'Chọn dấu thích hợp: ${a.speech} và ${b.speech}.',
          o: (options: signs, answer: signs.indexOf(sign)),
          explanation: '$rule ${a.text()} $sign ${b.text()}',
          data: {'a': a.text(), 'b': b.text()},
        );
      case 'reduce':
        final base = _randFrac(r, maxDen: 9);
        final k = between(r, 2, 6);
        final shown = Frac(base.n * k, base.d * k);
        final wrong = <Frac>[
          for (final g in [2, 3, 5])
            if (k % g == 0 && k != g) Frac(shown.n ~/ g, shown.d ~/ g), // rút gọn chưa hết – bằng nhau nên bị lọc
          Frac(base.d, base.n),
          Frac(base.n + 1, base.d),
          Frac(base.n, base.d + 1),
          Frac(shown.n - base.n, shown.d),
        ];
        final o = fracOptions(r, base, wrong, p.answers);
        return simpleQuestion(
          id,
          prompt: 'Rút gọn phân số ${shown.text()} được phân số tối giản:',
          o: o,
          explanation: '${shown.text()} = (${shown.n} : $k)/(${shown.d} : $k) = ${base.text()}',
          explanationSpeech: 'Chia cả tử số và mẫu số cho ${say(k)}, được ${base.speech}.',
        );
      case 'equivalent':
        final base = _randFrac(r, maxDen: 6);
        final k = between(r, 2, 5);
        final correct = Frac(base.n * k, base.d * k);
        final wrong = [
          Frac(base.n * k, base.d * (k + 1)),
          Frac(base.n + k, base.d + k),
          Frac(base.d, base.n),
          Frac(base.n * k, base.d),
          Frac(base.n, base.d * k),
        ];
        final o = textOptions(
          r,
          correct.text(),
          [for (final w in wrong) if (w != base && w.n > 0) w.text()],
          p.answers,
        );
        return simpleQuestion(
          id,
          prompt: 'Phân số nào bằng ${base.text()}?',
          o: o,
          explanation: 'Nhân cả tử số và mẫu số của ${base.text()} với $k: ${correct.text()}.',
          explanationSpeech: 'Nhân cả tử số và mẫu số với ${say(k)}, được ${correct.speech}.',
        );
      case 'common_den':
        final d1 = between(r, 2, 8);
        final d2 = r.nextBool() ? d1 * between(r, 2, 3) : between(r, 2, 9);
        if (d1 == d2) return generate(p, r);
        final l = Frac.lcm(d1, d2);
        final a = Frac(between(r, 1, d1 - 1), d1), b = Frac(between(r, 1, d2 - 1), d2);
        final o = numericOptions(r, l, p.answers, min: 2, max: d1 * d2 * 2, preferred: [d1 * d2, d1 + d2, math.max(d1, d2), l * 2]);
        return simpleQuestion(
          id,
          prompt: 'Quy đồng mẫu số ${a.text()} và ${b.text()}. Mẫu số chung bé nhất là:',
          o: o,
          explanation: '$l là số bé nhất chia hết cho cả $d1 và $d2.',
        );
      case 'add':
      case 'sub':
        final sameDen = p.boolOf('sameDen', false);
        late Frac a, b;
        for (;;) {
          if (sameDen) {
            final d = between(r, 3, maxDen);
            a = Frac(between(r, 1, d), d);
            b = Frac(between(r, 1, d), d);
          } else {
            a = _randFrac(r, maxDen: maxDen);
            final d2 = r.nextBool() ? a.d * between(r, 2, 3) : between(r, 2, maxDen);
            b = Frac(between(r, 1, d2 - 1), d2);
            if (b.d == a.d) continue;
          }
          if (kind == 'sub' && !(a > b)) continue;
          break;
        }
        final res = kind == 'add' ? a + b : a - b;
        final op = kind == 'add' ? '+' : _minus;
        final naive = kind == 'add' ? Frac(a.n + b.n, a.d + b.d) : Frac((a.n - b.n).abs(), (a.d - b.d).abs());
        final l = Frac.lcm(a.d, b.d);
        final o = fracOptions(r, res, [
          naive,
          Frac(kind == 'add' ? a.n + b.n : a.n - b.n, l),
          res + Frac(1, l),
          if (res > Frac(1, l)) res - Frac(1, l),
          Frac(res.d, res.n),
        ], p.answers);
        final prompt = '${a.text()} $op ${b.text()} = ?';
        final steps = a.d == b.d
            ? '${a.n} $op ${b.n} trên ${a.d}'
            : 'quy đồng: ${a.n * (l ~/ a.d)}/$l $op ${b.n * (l ~/ b.d)}/$l';
        return simpleQuestion(
          id,
          prompt: prompt,
          o: o,
          explanation: '${a.text()} $op ${b.text()}: $steps = ${res.text(compact: true)}',
          explanationSpeech: '${speakMath('${a.text()} $op ${b.text()}')} bằng ${res.d == 1 ? say(res.n) : res.speech}.',
        );
      case 'mul':
      case 'div':
        final a = _randFrac(r, maxDen: maxDen);
        final withInt = r.nextInt(3) == 0;
        final b = withInt ? Frac(between(r, 2, 5), 1) : _randFrac(r, maxDen: maxDen);
        final res = kind == 'mul' ? a * b : a / b;
        final op = kind == 'mul' ? '×' : ':';
        final o = fracOptions(r, res, [
          kind == 'mul' ? a / b : a * b,
          if (withInt) Frac(a.n, a.d * b.n),
          if (!withInt) Frac(a.n * b.n, a.d + b.d),
          Frac(res.d, res.n),
          res + Frac(1, res.d),
        ], p.answers);
        final bt = b.text(compact: true);
        final how = kind == 'mul'
            ? (withInt ? '${a.n} × ${b.n} trên ${a.d}' : 'tử nhân tử, mẫu nhân mẫu: ${a.n * b.n}/${a.d * b.d}')
            : 'nhân với phân số đảo ngược: ${a.text()} × ${b.d}/${b.n}';
        return simpleQuestion(
          id,
          prompt: '${a.text()} $op $bt = ?',
          o: o,
          explanation: '${a.text()} $op $bt: $how = ${res.text(compact: true)}',
          explanationSpeech: '${speakMath('${a.text()} $op $bt')} bằng ${res.d == 1 ? say(res.n) : res.speech}.',
        );
      case 'mixed':
        final w = between(r, 1, 5);
        final f = _randFrac(r, maxDen: 9);
        final improper = Frac(w * f.d + f.n, f.d);
        final o = fracOptions(r, improper, [
          Frac(w + f.n, f.d),
          Frac(w * f.n + f.d, f.d),
          Frac(w * f.d, f.n),
          Frac(improper.n + 1, f.d),
          Frac(improper.n, f.d + 1),
        ], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Hỗn số $w ${f.text()} viết thành phân số là:',
          speech: 'Hỗn số ${say(w)} và ${f.speech} viết thành phân số là bao nhiêu?',
          o: o,
          explanation: '$w ${f.text()} = ($w × ${f.d} + ${f.n})/${f.d} = ${improper.text()}',
          explanationSpeech: 'Lấy ${say(w)} nhân ${say(f.d)} cộng ${say(f.n)} làm tử số, giữ mẫu số ${say(f.d)}: ${improper.speech}.',
        );
      default: // decimal_fraction
        final k = between(r, 1, 3);
        final den = pow10(k);
        final correct = Frac(between(r, 1, den - 1), den);
        final wrongDens = [3, 6, 7, 8, 9, 11, 12, 15, 25, 30]..shuffle(r);
        final o = textOptions(r, correct.text(), [for (final d in wrongDens.take(5)) '${between(r, 1, d - 1)}/$d'], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Phân số nào là phân số thập phân?',
          o: o,
          explanation: 'Phân số thập phân có mẫu số là 10, 100, 1 000…: ${correct.text()}.',
          explanationSpeech: 'Phân số thập phân có mẫu số là mười, một trăm, một nghìn. Đáp án là ${correct.speech}.',
        );
    }
  }
}

/// Lớp 5: số thập phân. kinds:
/// structure | from_fraction | place | compare | max | round | add | sub | mul | div | shift | unit
class DecimalGenerator extends QuestionGenerator {
  const DecimalGenerator();

  @override
  String get id => 'decimal';

  static const kinds = ['structure', 'from_fraction', 'place', 'compare', 'max', 'round', 'add', 'sub', 'mul', 'div', 'shift', 'unit'];

  @override
  List<String> validate(GenParams p) =>
      p.strList('kinds', const ['structure']).where((k) => !kinds.contains(k)).map((k) => 'kinds không có "$k"').toList();

  static Dec _rand(math.Random r, {int maxInt = 99, int scale = 2}) {
    for (;;) {
      final d = Dec(between(r, 1, (maxInt + 1) * pow10(scale) - 1), scale);
      if (d.normalized().scale == scale) return d;
    }
  }

  static const _decPlaces = ['hàng phần mười', 'hàng phần trăm', 'hàng phần nghìn'];

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['structure']), r);
    switch (kind) {
      case 'structure':
        final i = between(r, 1, 99), t = between(r, 1, 9), h = between(r, 0, 9);
        final x = Dec(i * 100 + t * 10 + h, 2);
        final parts = ['$i đơn vị', '$t phần mười', if (h > 0) '$h phần trăm'];
        final o = decOptions(r, x, [
          if (h > 0) Dec(i * 1000 + t * 100 + h, 3),
          Dec(i * 100 + t * 10 + h, 1),
          if (h > 0) Dec(i * 100 + h * 10 + t, 2),
          Dec(i * 100 + t * 10 + h, 3),
          Dec(i * 100 + t, 2),
        ], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Số gồm ${parts.join(', ')} viết là:',
          o: o,
          explanation: '${cap(parts.join(', '))} viết là ${x.text}.',
          explanationSpeech: '${cap(parts.join(', '))} viết là ${x.speech}.',
        );
      case 'from_fraction':
        final k = between(r, 1, 3);
        final n = between(r, 1, pow10(k) * 3);
        final x = Dec(n, k);
        if (x.normalized().scale != k) return generate(p, r);
        final o = decOptions(r, x, [Dec(n, k + 1), Dec(n, k - 1), Dec(n, k + 2), if (k >= 2) Dec(n, k - 2)], p.answers);
        return simpleQuestion(
          id,
          prompt: '$n/${pow10(k)} viết dưới dạng số thập phân là:',
          o: o,
          explanation: '$n/${fmt(pow10(k))} = ${x.text} (mẫu số có $k chữ số 0 thì phần thập phân có $k chữ số).',
          explanationSpeech: '${Frac(n, pow10(k)).speech} bằng ${x.speech}.',
        );
      case 'place':
        final x = _rand(r, maxInt: 99, scale: 3);
        final digits = x.text.split(',').last;
        final pos = [for (var j = 0; j < 3; j++) if (digits[j] != '0' && digits.split('').where((c) => c == digits[j]).length == 1) j];
        if (pos.isEmpty) return generate(p, r);
        final j = pick(pos, r);
        final o = textOptions(r, cap(_decPlaces[j]), [..._decPlaces.map(cap), 'Hàng đơn vị', 'Hàng chục'], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Chữ số ${digits[j]} trong số ${x.text} thuộc hàng nào?',
          o: o,
          explanation: 'Chữ số ${digits[j]} đứng thứ ${j + 1} sau dấu phẩy: ${_decPlaces[j]}.',
          explanationSpeech: 'Chữ số ${say(int.parse(digits[j]))} đứng thứ ${say(j + 1)} sau dấu phẩy, thuộc ${_decPlaces[j]}.',
        );
      case 'compare':
        final i = between(r, 0, 20);
        final a = Dec(i * 100 + between(r, 1, 99), 2).normalized();
        final b = r.nextInt(5) == 0
            ? Dec(a.units * 10, a.scale + 1) // 3,5 và 3,50
            : Dec(i * 10 + between(r, 0, 9), 1);
        final sign = a > b ? '>' : (a < b ? '<' : '=');
        const signs = ['>', '<', '='];
        return simpleQuestion(
          id,
          prompt: '${a.text} … ${b.fixedText}',
          speech: 'Chọn dấu thích hợp: ${a.speech} và ${b.speech}.',
          o: (options: signs, answer: signs.indexOf(sign)),
          explanation: 'Phần nguyên bằng nhau thì so sánh từng hàng của phần thập phân: ${a.text} $sign ${b.text}.',
          explanationSpeech: '${cap(a.speech)} ${{'>': 'lớn hơn', '<': 'bé hơn', '=': 'bằng'}[sign]} ${b.speech}.',
        );
      case 'max':
        final i = between(r, 1, 30), a = between(r, 1, 9), b = between(r, 1, 9);
        if (a == b) return generate(p, r);
        final pool = <Dec>{
          Dec(i * 100 + a * 10 + b, 2),
          Dec(i * 100 + b * 10 + a, 2),
          Dec(i * 10 + a, 1),
          Dec(i * 1000 + a * 10 + b, 3),
          Dec(i * 10 + b, 1),
          Dec(i * 1000 + b * 100 + a, 3),
        }.toList()
          ..shuffle(r);
        final shown = pool.take(math.max(2, p.answers)).toList();
        final wantMax = r.nextBool();
        final target = shown.reduce((x, y) => wantMax ? (x > y ? x : y) : (x < y ? x : y));
        final o = textOptions(r, target.text, [for (final s in shown) s.text], shown.length);
        return simpleQuestion(
          id,
          prompt: 'Số ${wantMax ? 'lớn' : 'bé'} nhất là:',
          o: o,
          explanation: 'So sánh hàng phần mười, rồi hàng phần trăm…: số ${wantMax ? 'lớn' : 'bé'} nhất là ${target.text}.',
          explanationSpeech: 'Số ${wantMax ? 'lớn' : 'bé'} nhất là ${target.speech}.',
        );
      case 'round':
        final to = between(r, 0, 2); // 0: số tự nhiên, 1: phần mười, 2: phần trăm
        final x = _rand(r, maxInt: 50, scale: to + 1 + between(r, 0, 1));
        final step = pow10(x.scale - to);
        final rounded = Dec((x.units + step ~/ 2) ~/ step, to).normalized();
        final down = Dec(x.units ~/ step, to), up = Dec(x.units ~/ step + 1, to);
        final cut = Dec(x.units ~/ (step ~/ 10), to + 1);
        final o = decOptions(r, rounded, [down, up, cut, Dec(rounded.unitsAt(to) + 1, to)], p.answers);
        final where = to == 0 ? 'số tự nhiên gần nhất' : 'hàng ${to == 1 ? 'phần mười' : 'phần trăm'}';
        return simpleQuestion(
          id,
          prompt: 'Làm tròn ${x.text} đến $where:',
          o: o,
          explanation: 'Xét chữ số ngay sau hàng cần làm tròn: từ 5 trở lên thì làm tròn lên. ${x.text} ≈ ${rounded.text}',
          explanationSpeech: '${cap(x.speech)} làm tròn được ${rounded.speech}.',
        );
      case 'add':
      case 'sub':
        var a = _rand(r, maxInt: 40, scale: between(r, 1, 2));
        var b = _rand(r, maxInt: 40, scale: between(r, 1, 2));
        if (kind == 'sub' && a < b) (a, b) = (b, a);
        if (a == b) return generate(p, r);
        final res = kind == 'add' ? a + b : a - b;
        // Lỗi đặt tính thẳng hàng sai: cộng như số tự nhiên rồi đặt dấu phẩy theo số có nhiều chữ số thập phân hơn.
        final s = math.max(a.scale, b.scale);
        final mis = kind == 'add' ? Dec(a.units + b.units, s) : Dec((a.units - b.units).abs(), s);
        final op = kind == 'add' ? '+' : _minus;
        final o = decOptions(r, res, [mis, res + const Dec(1, 1), res - const Dec(1, 1), res + const Dec(1, 0)], p.answers);
        final prompt = '${a.text} $op ${b.text} = ?';
        return simpleQuestion(id,
            prompt: prompt, o: o, explanation: 'Đặt các dấu phẩy thẳng cột: ${a.text} $op ${b.text} = ${res.text}');
      case 'mul':
        final a = _rand(r, maxInt: 20, scale: between(r, 1, 2));
        final b = r.nextBool() ? Dec(between(r, 2, 9), 0) : _rand(r, maxInt: 5, scale: 1);
        final res = a * b;
        final o = decOptions(r, res, [res.shift(1), res.shift(-1), res + Dec(1, res.scale)], p.answers);
        return simpleQuestion(
          id,
          prompt: '${a.text} × ${b.text} = ?',
          o: o,
          explanation: 'Nhân như số tự nhiên, rồi đếm ${a.scale + b.scale} chữ số ở phần thập phân: ${a.text} × ${b.text} = ${res.text}',
          explanationSpeech: '${speakMath('${a.text} × ${b.text}')} bằng ${res.speech}.',
        );
      case 'div':
        final k = between(r, 2, 9);
        final Dec q;
        final Dec a;
        if (r.nextBool()) {
          q = _rand(r, maxInt: 12, scale: 1);
          a = q * Dec(k, 0);
        } else {
          // Số tự nhiên chia số tự nhiên, thương là số thập phân: 7 : 2 = 3,5
          final k2 = pick(const [2, 4, 5], r);
          final whole = between(r, 1, 20) * k2 + between(r, 1, k2 - 1);
          a = Dec(whole, 0);
          q = Dec(whole * (100 ~/ k2), 2).normalized();
          return _divResult(p, r, a, Dec(k2, 0), q);
        }
        return _divResult(p, r, a, Dec(k, 0), q);
      case 'shift':
        final x = _rand(r, maxInt: 99, scale: between(r, 1, 3));
        final (label, k) = pick(const [('× 10', 1), ('× 100', 2), ('× 1 000', 3), (': 10', -1), (': 100', -2), ('× 0,1', -1), ('× 0,01', -2)], r);
        final res = x.shift(k);
        final o = decOptions(r, res, [x.shift(-k), x.shift(k + 1), x.shift(k - 1)], p.answers);
        final prompt = '${x.text} $label = ?';
        final move = k > 0 ? 'sang phải ${k.abs()}' : 'sang trái ${k.abs()}';
        return simpleQuestion(id,
            prompt: prompt,
            o: o,
            explanation: 'Chuyển dấu phẩy $move chữ số: ${x.text} $label = ${res.text}',
            explanationSpeech: 'Chuyển dấu phẩy $move chữ số, được ${res.speech}.');
      default: // unit
        final (big, small, k) = pick(const [
          ('m', 'cm', 2), ('m', 'dm', 1), ('km', 'm', 3), ('kg', 'g', 3), ('tấn', 'kg', 3), ('l', 'ml', 3), ('m', 'mm', 3),
        ], r);
        final f = pow10(k);
        final w = between(r, 0, 9);
        final part = between(r, 1, f - 1);
        final x = Dec(w * f + part, k);
        final digits = '$part'.length;
        final o = decOptions(r, x, [
          Dec(w * f + part, k + 1),
          Dec(w * f + part, k - 1),
          if (digits < k) Dec(w * pow10(digits) + part, digits),
          Dec(w * f + part, k + 2),
        ], p.answers, unit: big);
        final shown = w > 0 ? '$w $big $part $small' : '$part $small';
        return simpleQuestion(
          id,
          prompt: '$shown = ? $big',
          o: o,
          explanation: '$part $small = $part/${fmt(f)} $big. Vậy $shown = ${x.text} $big.',
          explanationSpeech: '${speakMath(shown)} bằng ${x.speech} ${unitWords[big] ?? big}.',
        );
    }
  }

  Question _divResult(GenParams p, math.Random r, Dec a, Dec b, Dec q) {
    final o = decOptions(r, q, [q.shift(1), q.shift(-1), q + const Dec(1, 1), if (q > const Dec(1, 1)) q - const Dec(1, 1)], p.answers);
    return simpleQuestion(
      id,
      prompt: '${a.text} : ${b.text} = ?',
      o: o,
      explanation: '${a.text} : ${b.text} = ${q.text} (vì ${q.text} × ${b.text} = ${a.text})',
      explanationSpeech: '${speakMath('${a.text} : ${b.text}')} bằng ${q.speech}.',
    );
  }
}

/// Lớp 5: tỉ số, tỉ số phần trăm, tỉ lệ bản đồ. kinds: ratio | ratio_percent | of | whole | map_scale
class PercentGenerator extends QuestionGenerator {
  const PercentGenerator();

  @override
  String get id => 'percent';

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['ratio_percent', 'of']), r);
    switch (kind) {
      case 'ratio':
        final a = between(r, 1, 9), b = between(r, 2, 9);
        if (a == b || Frac.gcd(a, b) != 1) return generate(p, r);
        final o = fracOptions(r, Frac(a, b), [Frac(b, a), Frac(a, a + b), Frac(a + 1, b), Frac(b, a + b)], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Tỉ số của $a và $b là:',
          o: o,
          explanation: 'Tỉ số của $a và $b là $a : $b hay $a/$b.',
          explanationSpeech: 'Tỉ số của ${say(a)} và ${say(b)} là ${say(a)} chia ${say(b)}, hay ${Frac(a, b).speech}.',
        );
      case 'ratio_percent':
        final b = pick(const [20, 25, 40, 50, 80, 200, 400, 500], r);
        final pcs = [for (var v = 5; v < 100; v += 5) if (b * v % 100 == 0) v];
        final pc = pick(pcs, r);
        final a = b * pc ~/ 100;
        final o = numericOptions(r, pc, p.answers, min: 1, max: 1000,
            preferred: [100 - pc, a, pc ~/ 10, pc + 10, pc - 10], label: (v) => '$v%');
        return simpleQuestion(
          id,
          prompt: 'Tỉ số phần trăm của $a và $b là:',
          o: o,
          explanation: '$a : $b = ${Dec(a * 100 ~/ b, 2).text} = $pc%',
          explanationSpeech: '${cap(say(a))} chia ${say(b)}, nhân một trăm, được ${say(pc)} phần trăm.',
        );
      case 'whole':
        final pc = pick(const [10, 20, 25, 50, 75], r);
        final whole = between(r, 1, 20) * (100 ~/ Frac.gcd(pc, 100));
        final part = whole * pc ~/ 100;
        final o = numericOptions(r, whole, p.answers, min: 1, max: whole * 4 + 100,
            preferred: [part * pc ~/ 100, part * pc, whole ~/ 2, whole + part]);
        return simpleQuestion(
          id,
          prompt: '$pc% của một số là $part. Số đó là:',
          o: o,
          explanation: '$part : $pc × 100 = $whole',
        );
      case 'map_scale':
        final (scale, unit, factor) = pick(const [(1000, 'm', 10), (10000, 'm', 100), (100000, 'km', 1), (500000, 'km', 5)], r);
        final l = between(r, 2, 9);
        final real = l * factor;
        final o = numericOptions(r, real, p.answers, min: 1, max: real * 1000,
            preferred: [real * 10, if (real % 10 == 0) real ~/ 10, l * scale, real * 100], label: (v) => '${fmt(v)} $unit');
        return simpleQuestion(
          id,
          prompt: 'Bản đồ tỉ lệ 1 : ${fmt(scale)}. Đoạn $l cm trên bản đồ dài bao nhiêu trên thực tế?',
          speech: 'Bản đồ tỉ lệ một trên ${say(scale)}. Đoạn ${say(l)} xăng-ti-mét trên bản đồ dài bao nhiêu trên thực tế?',
          o: o,
          explanation: '$l × ${fmt(scale)} = ${fmt(l * scale)} (cm) = ${fmt(real)} $unit',
          explanationSpeech: '${cap(say(l))} nhân ${say(scale)} bằng ${say(l * scale)} xăng-ti-mét, tức là ${say(real)} ${unitWords[unit]}.',
        );
      default: // of
        final pc = pick(const [10, 20, 25, 30, 40, 50, 60, 75], r);
        final whole = between(r, 1, 12) * (100 ~/ Frac.gcd(pc, 100));
        final part = whole * pc ~/ 100;
        final o = numericOptions(r, part, p.answers, min: 1, max: whole * pc + 100,
            preferred: [whole - part, part * 10, whole * 100 ~/ pc, part + 5]);
        return simpleQuestion(
          id,
          prompt: '$pc% của $whole là:',
          o: o,
          explanation: '$whole × $pc : 100 = $part',
        );
    }
  }
}
