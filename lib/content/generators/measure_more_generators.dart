import 'dart:math' as math;

import '../question.dart';
import 'big_number_generators.dart';
import 'generator.dart';

/// Đổi đơn vị đo. quantities: length | mass | capacity | area | volume | time | years.
/// units: chỉ dùng các đơn vị này (mặc định: tất cả của đại lượng); compound: "3 m 5 cm = ? cm";
/// maxRatio: tỉ số lớn nhất giữa hai đơn vị (mặc định 1000).
class UnitConvertGenerator extends QuestionGenerator {
  const UnitConvertGenerator();

  @override
  String get id => 'unit_convert';

  static const scales = <String, List<(String, int)>>{
    'length': [('mm', 1), ('cm', 10), ('dm', 100), ('m', 1000), ('km', 1000000)],
    'mass': [('g', 1), ('kg', 1000), ('yến', 10000), ('tạ', 100000), ('tấn', 1000000)],
    'capacity': [('ml', 1), ('l', 1000)],
    'area': [('mm²', 1), ('cm²', 100), ('dm²', 10000), ('m²', 1000000), ('ha', 10000000000), ('km²', 1000000000000)],
    'volume': [('cm³', 1), ('dm³', 1000), ('m³', 1000000)],
    'time': [('giây', 1), ('phút', 60), ('giờ', 3600), ('ngày', 86400)],
    'years': [('năm', 1), ('thế kỉ', 100)],
  };

  @override
  List<String> validate(GenParams p) => p
      .strList('quantities', const ['length'])
      .where((q) => !scales.containsKey(q))
      .map((q) => 'quantities không có "$q"')
      .toList();

  @override
  Question generate(GenParams p, math.Random r) {
    final quantity = pick(p.strList('quantities', const ['length']), r);
    final allowed = p.strList('units', const []);
    final maxRatio = p.intOf('maxRatio', 1000);
    final list = [for (final u in scales[quantity]!) if (allowed.isEmpty || allowed.contains(u.$1)) u];
    final pairs = [
      for (var i = 0; i < list.length; i++)
        for (var j = i + 1; j < list.length; j++)
          if (list[j].$2 ~/ list[i].$2 <= maxRatio) (list[i], list[j]),
    ];
    if (pairs.isEmpty) throw StateError('unit_convert: không có cặp đơn vị cho $quantity');
    final ((small, s), (big, b)) = pick(pairs, r);
    final ratio = b ~/ s;
    final v = between(r, 2, ratio >= 1000 ? 9 : 12);
    final compound = p.boolOf('compound', false) && r.nextBool();
    final mode = compound ? 'compound' : (r.nextBool() ? 'down' : 'up');
    late int answer;
    late String prompt;
    var wrong = <int>[];
    switch (mode) {
      case 'compound':
        final w = between(r, 1, math.min(ratio - 1, ratio >= 100 ? ratio ~/ 2 : ratio - 1));
        answer = v * ratio + w;
        prompt = '$v $big ${fmt(w)} $small = ? $small';
        wrong = [int.parse('$v$w'), v * ratio * 10 + w, if (ratio >= 10) v * ratio ~/ 10 + w, v + w];
      case 'down':
        answer = v * ratio;
        prompt = '$v $big = ? $small';
        wrong = [answer * 10, if (ratio >= 10) answer ~/ 10, v * 100, v * 10, v + ratio];
      default:
        answer = v;
        prompt = '${fmt(v * ratio)} $small = ? $big';
        wrong = [v * 10, v * ratio * 10, if (v * ratio % 100 == 0) v * ratio ~/ 100, v + 1];
    }
    final o = numericOptions(r, answer, p.answers, min: 1, max: answer * 100 + 100,
        preferred: wrong.where((x) => x != answer && x > 0));
    return simpleQuestion(
      id,
      prompt: prompt,
      o: o,
      explanation: '1 $big = ${fmt(ratio)} $small. Vậy ${prompt.replaceFirst('?', fmt(answer))}.',
      data: {'result': answer},
    );
  }
}

/// Lớp 3: nhiệt độ. kinds: read (đọc nhiệt kế – data.kind = "thermo") | fact (nhiệt độ quen thuộc).
class TemperatureGenerator extends QuestionGenerator {
  const TemperatureGenerator();

  @override
  String get id => 'temperature';

  static const _facts = [
    ('Nhiệt độ cơ thể người khỏe mạnh khoảng', 37),
    ('Nước đá đang tan có nhiệt độ', 0),
    ('Nước đang sôi có nhiệt độ', 100),
  ];

  @override
  Question generate(GenParams p, math.Random r) {
    String deg(int v) => '$v °C';
    if (pick(p.strList('kinds', const ['read', 'fact']), r) == 'fact') {
      final (text, v) = pick(_facts, r);
      final o = textOptions(r, deg(v), [for (final x in const [0, 37, 100, 73, 10, 50]) deg(x)], p.answers);
      return simpleQuestion(id, prompt: '$text:', o: o, explanation: '$text ${deg(v)}.');
    }
    final v = between(r, 0, 22) * 2;
    final o = numericOptions(r, v, p.answers, min: 0, max: 50, preferred: [v + 2, v - 2, v + 10, v - 10, v + 1], label: deg);
    return simpleQuestion(
      id,
      prompt: 'Nhiệt kế chỉ bao nhiêu độ C?',
      o: o,
      explanation: 'Đầu cột đỏ chỉ vạch $v: ${deg(v)}.',
      data: {'kind': 'thermo', 'value': v},
    );
  }
}

String durationText(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m phút';
  if (m == 0) return '$h giờ';
  return '$h giờ $m phút';
}

/// Thời gian. kinds:
/// - century (lớp 4): năm thuộc thế kỉ nào
/// - elapsed (lớp 3–4): thời gian từ lúc bắt đầu đến lúc kết thúc
/// - add, sub, mul (lớp 5): cộng, trừ, nhân số đo thời gian
/// - hours_decimal (lớp 5): 1,5 giờ = ? phút
class TimeCalcGenerator extends QuestionGenerator {
  const TimeCalcGenerator();

  @override
  String get id => 'time_calc';

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['elapsed']), r);
    switch (kind) {
      case 'century':
        final year = between(r, 1001, 2100);
        final c = (year - 1) ~/ 100 + 1;
        final o = textOptions(r, RomanGenerator.roman(c), [for (final x in [c - 1, c + 1, c + 2, c - 2]) RomanGenerator.roman(x)], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Năm $year thuộc thế kỉ nào?',
          o: o,
          explanation: 'Thế kỉ ${RomanGenerator.roman(c)} gồm các năm từ ${(c - 1) * 100 + 1} đến ${c * 100}.',
          explanationSpeech: 'Năm ${say(year)} thuộc thế kỉ ${say(c)}.',
        );
      case 'add':
      case 'sub':
      case 'mul':
        late int a, b, res;
        late String expr;
        var wrong = <String>[];
        if (kind == 'mul') {
          a = between(r, 1, 3) * 60 + between(r, 1, 11) * 5;
          final k = between(r, 2, 4);
          res = a * k;
          expr = '${durationText(a)} × $k';
          wrong = ['${a ~/ 60 * k} giờ ${a % 60 * k} phút', durationText(res + 60), durationText(res - 30)];
        } else {
          a = between(r, 1, 4) * 60 + between(r, 1, 11) * 5;
          b = between(r, 0, 2) * 60 + between(r, 1, 11) * 5;
          if (kind == 'sub' && a <= b) (a, b) = (b + 60, a);
          res = kind == 'add' ? a + b : a - b;
          expr = '${durationText(a)} ${kind == 'add' ? '+' : '−'} ${durationText(b)}';
          final rawH = kind == 'add' ? a ~/ 60 + b ~/ 60 : a ~/ 60 - b ~/ 60;
          final rawM = kind == 'add' ? a % 60 + b % 60 : a % 60 - b % 60;
          wrong = [
            if (rawM >= 60 || rawM < 0) '$rawH giờ ${rawM.abs()} phút',
            durationText(res + 60),
            if (res > 60) durationText(res - 60),
            durationText(res + 10),
            if (res > 10) durationText(res - 10),
          ];
        }
        final o = textOptions(r, durationText(res), wrong, p.answers);
        return simpleQuestion(
          id,
          prompt: '$expr = ?',
          o: o,
          explanation: kind == 'mul'
              ? '$expr = ${durationText(res)} (60 phút = 1 giờ)'
              : '$expr = ${durationText(res)} (đổi 60 phút = 1 giờ khi cần)',
        );
      case 'hours_decimal':
        final (h, label) = pick(const [(30, '0,5'), (90, '1,5'), (150, '2,5'), (15, '0,25'), (45, '0,75'), (72, '1,2'), (24, '0,4')], r);
        final o = numericOptions(r, h, p.answers, min: 1, max: 300, preferred: [h + 30, h - 30, int.parse(label.replaceAll(',', '')), h * 2]);
        return simpleQuestion(
          id,
          prompt: '$label giờ = ? phút',
          o: o,
          explanation: '$label × 60 = $h (phút)',
        );
      default: // elapsed
        final sh = between(r, 6, 16), sm = between(r, 0, 11) * 5;
        final dur = between(r, 2, 18) * 5;
        final end = sh * 60 + sm + dur;
        final eh = end ~/ 60, em = end % 60;
        String clock(int h, int m) => m == 0 ? '$h giờ' : '$h giờ $m phút';
        final o = numericOptions(r, dur, p.answers, min: 5, max: 180,
            preferred: [dur + 60, (dur - 60).abs(), dur + 10, dur - 5, (em - sm).abs()], label: (v) => '$v phút');
        return simpleQuestion(
          id,
          prompt: 'Bắt đầu lúc ${clock(sh, sm)}, kết thúc lúc ${clock(eh, em)}. Hết bao nhiêu phút?',
          o: o,
          explanation: 'Từ ${clock(sh, sm)} đến ${clock(eh, em)} là $dur phút.',
        );
    }
  }
}

/// Lớp 5: chuyển động đều. kinds: speed | distance | time.
class MotionGenerator extends QuestionGenerator {
  const MotionGenerator();

  @override
  String get id => 'motion';

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['speed', 'distance', 'time']), r);
    final fast = r.nextInt(3) != 0;
    final (who, v, t, dUnit, vUnit, tUnit) = fast
        ? (pick(const ['Một ô tô', 'Một xe máy', 'Một tàu hỏa'], r), between(r, 3, 12) * 5, between(r, 2, 5), 'km', 'km/giờ', 'giờ')
        : (pick(const ['Một bạn chạy', 'Một con ngựa'], r), between(r, 3, 9), between(r, 2, 12) * 5, 'm', 'm/giây', 'giây');
    final s = v * t;
    late String prompt, explanation;
    late int answer;
    late String unit;
    var wrong = <int>[];
    switch (kind) {
      case 'speed':
        prompt = '$who đi được $s $dUnit trong $t $tUnit. Vận tốc là:';
        answer = v;
        unit = vUnit;
        wrong = [s * t, s - t, v + t];
        explanation = 'v = s : t = $s : $t = $v ($vUnit)';
      case 'distance':
        prompt = '$who đi với vận tốc $v $vUnit trong $t $tUnit. Quãng đường đi được là:';
        answer = s;
        unit = dUnit;
        wrong = [v + t, s + v, s - v];
        explanation = 's = v × t = $v × $t = $s ($dUnit)';
      default:
        prompt = '$who đi quãng đường $s $dUnit với vận tốc $v $vUnit. Thời gian đi là:';
        answer = t;
        unit = tUnit;
        wrong = [t + 1, if (t > 2) t - 1, s - v, t * 2];
        explanation = 't = s : v = $s : $v = $t ($tUnit)';
    }
    final o = numericOptions(r, answer, p.answers, min: 1, max: answer * 20 + 50,
        preferred: wrong.where((w) => w > 0 && w != answer), label: (x) => '${fmt(x)} $unit');
    return simpleQuestion(id, prompt: prompt, o: o, explanation: explanation);
  }
}

/// Lớp 3: tiền Việt Nam. kinds: sum (tổng các tờ tiền – data.kind = "notes") | change (tiền trả lại).
class MoneySumGenerator extends QuestionGenerator {
  const MoneySumGenerator();

  @override
  String get id => 'money_sum';

  @override
  Question generate(GenParams p, math.Random r) {
    final notesAllowed = p.intList('notes', const [1000, 2000, 5000, 10000, 20000, 50000]);
    String money(int v) => '${fmt(v)} đồng';
    if (pick(p.strList('kinds', const ['sum', 'change']), r) == 'change') {
      final paid = pick(notesAllowed.where((n) => n >= 5000).toList(), r);
      final price = between(r, 1, paid ~/ 500 - 1) * 500;
      final change = paid - price;
      final item = pick(const ['một quyển vở', 'một cái bút', 'một gói bánh', 'một hộp sữa'], r);
      final o = numericOptions(r, change, p.answers, min: 500, max: paid * 2,
          preferred: [price + paid, change + 1000, change - 1000, change + 500], label: money);
      return simpleQuestion(
        id,
        prompt: 'Mua $item giá ${money(price)}, đưa tờ ${money(paid)}. Được trả lại bao nhiêu tiền?',
        o: o,
        explanation: '${fmt(paid)} − ${fmt(price)} = ${fmt(change)} (đồng)',
      );
    }
    final count = between(r, 2, math.min(4, p.intOf('maxNotes', 4)));
    final notes = [for (var i = 0; i < count; i++) pick(notesAllowed, r)]..sort((a, b) => b.compareTo(a));
    final total = notes.fold(0, (s, v) => s + v);
    final o = numericOptions(r, total, p.answers, min: 1000, max: total * 3,
        preferred: [total + notes.last, total - notes.last, total + 1000, total - 1000, total * 2], label: money);
    return simpleQuestion(
      id,
      prompt: 'Có các tờ tiền như hình. Tất cả bao nhiêu tiền?',
      o: o,
      explanation: '${notes.map(fmt).join(' + ')} = ${fmt(total)} (đồng)',
      data: {'kind': 'notes', 'notes': notes},
    );
  }
}

/// Thống kê, xác suất lớp 3–5. kinds:
/// - table (lớp 3): bảng số liệu – data.kind = "table"
/// - bar (lớp 4): biểu đồ cột – data.kind = "bar"
/// - series (lớp 4): dãy số liệu
/// - coin (lớp 4): số lần xuất hiện; coin_ratio (lớp 5): tỉ số số lần xuất hiện
/// - pie (lớp 5): biểu đồ hình quạt tròn – data.kind = "pie"
class DataGenerator extends QuestionGenerator {
  const DataGenerator();

  @override
  String get id => 'data';

  static const _sets = [
    ('Số cây các lớp trồng được', ['3A', '3B', '3C', '3D'], 'cây'),
    ('Số quyển sách các bạn đã đọc', ['An', 'Bình', 'Chi', 'Dũng'], 'quyển'),
    ('Số con vật ở trang trại', ['Gà', 'Vịt', 'Ngan', 'Ngỗng'], 'con'),
    ('Số bông hoa các tổ làm được', ['Tổ 1', 'Tổ 2', 'Tổ 3', 'Tổ 4'], 'bông'),
  ];

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['table']), r);
    switch (kind) {
      case 'series':
        final heights = r.nextBool();
        final values = [for (var i = 0; i < between(r, 5, 6); i++) heights ? between(r, 125, 140) : between(r, 5, 10)];
        final what = heights ? 'Chiều cao (cm) của ${values.length} bạn' : 'Điểm kiểm tra của ${values.length} bạn';
        final ask = between(r, 0, 2);
        final maxV = values.reduce(math.max), minV = values.reduce(math.min);
        late String q, ex;
        late int answer;
        var wrong = <int>[];
        switch (ask) {
          case 0:
            q = 'Số lớn nhất trong dãy là:';
            answer = maxV;
            wrong = [minV, values.first, maxV - 1];
            ex = 'Số lớn nhất là $maxV.';
          case 1:
            final pickV = pick(values, r);
            final c = values.where((v) => v == pickV).length;
            q = 'Có mấy bạn được $pickV${heights ? ' cm' : ' điểm'}?';
            answer = c;
            wrong = [c + 1, if (c > 1) c - 1, c + 2];
            ex = 'Số $pickV xuất hiện $c lần trong dãy.';
          default:
            q = 'Số lớn nhất hơn số bé nhất bao nhiêu?';
            answer = maxV - minV;
            if (answer == 0) return generate(p, r);
            wrong = [maxV, minV, answer + 1, answer + 2];
            ex = '$maxV − $minV = $answer';
        }
        final o = numericOptions(r, answer, p.answers, min: 0, max: 200, preferred: wrong);
        return simpleQuestion(id, prompt: '$what: ${values.join(', ')}. $q', o: o, explanation: ex);
      case 'coin':
      case 'coin_ratio':
        final total = pick(const [10, 20, 30, 40, 50], r);
        final heads = between(r, 2, total - 2);
        final tails = total - heads;
        final lead = 'Tung đồng xu $total lần, có $heads lần mặt sấp.';
        if (kind == 'coin') {
          final o = numericOptions(r, tails, p.answers, min: 0, max: 100, preferred: [heads, total + heads, tails + 1, tails - 1]);
          return simpleQuestion(id, prompt: '$lead Số lần mặt ngửa là:', o: o, explanation: '$total − $heads = $tails (lần)');
        }
        final correct = '$heads/$total';
        final o = textOptions(r, correct, ['$tails/$total', '$heads/$tails', '$total/$heads'], p.answers);
        return simpleQuestion(
          id,
          prompt: '$lead Tỉ số của số lần mặt sấp và tổng số lần tung là:',
          o: o,
          explanation: 'Số lần mặt sấp : tổng số lần tung = $heads : $total, hay $correct.',
          explanationSpeech: 'Tỉ số là ${say(heads)} phần ${say(total)}.',
        );
      case 'pie':
        final labels = pick(const [
          ['Bóng đá', 'Bơi', 'Cầu lông', 'Cờ vua'],
          ['Đỏ', 'Xanh', 'Vàng', 'Tím'],
          ['Táo', 'Cam', 'Chuối', 'Xoài'],
        ], r).take(between(r, 3, 4)).toList();
        final parts = <int>[];
        var left = 100;
        for (var i = 0; i < labels.length - 1; i++) {
          final v = between(r, 2, math.max(2, left ~/ 5 - 2 * (labels.length - 1 - i))) * 5;
          parts.add(v);
          left -= v;
        }
        parts.add(left);
        if (parts.any((v) => v <= 0) || parts.toSet().length != parts.length) return generate(p, r);
        final students = between(r, 2, 10) * 20;
        final i = between(r, 0, labels.length - 1);
        final topic = labels.first == 'Bóng đá' ? 'môn thể thao yêu thích' : (labels.first == 'Đỏ' ? 'màu yêu thích' : 'loại quả yêu thích');
        final data = {'kind': 'pie', 'labels': labels, 'values': parts};
        if (r.nextBool()) {
          final o = numericOptions(r, parts[i], p.answers, min: 5, max: 100,
              preferred: [for (final v in parts) v, 100 - parts[i]], label: (v) => '$v%');
          return simpleQuestion(id,
              prompt: 'Biểu đồ cho biết $topic của các bạn. Bao nhiêu phần trăm chọn ${labels[i]}?',
              o: o,
              explanation: 'Phần ${labels[i]} ghi ${parts[i]}%.',
              data: data);
        }
        final answer = students * parts[i] ~/ 100;
        final o = numericOptions(r, answer, p.answers, min: 1, max: students,
            preferred: [parts[i], students - answer, answer + 5, answer - 5], label: (v) => '$v bạn');
        return simpleQuestion(id,
            prompt: 'Lớp có $students bạn. Biểu đồ cho biết $topic. Số bạn chọn ${labels[i]} là:',
            o: o,
            explanation: '$students × ${parts[i]} : 100 = $answer (bạn)',
            data: data);
      default: // table, bar
        final (title, allLabels, unit) = pick(_sets, r);
        final n = between(r, 3, 4);
        final labels = allLabels.take(n).toList();
        final step = kind == 'bar' ? 5 : 1;
        final values = <int>[];
        while (values.length < n) {
          final v = between(r, 2, 12) * step * (kind == 'bar' ? 1 : between(r, 1, 4));
          if (!values.contains(v)) values.add(v);
        }
        final data = {'kind': kind, 'title': title, 'labels': labels, 'values': values, 'unit': unit};
        final ask = between(r, 0, 3);
        final maxI = values.indexOf(values.reduce(math.max)), minI = values.indexOf(values.reduce(math.min));
        switch (ask) {
          case 0:
            final i = between(r, 0, n - 1);
            final o = numericOptions(r, values[i], p.answers, min: 0, max: 200,
                preferred: [for (final v in values) v], label: (v) => '$v $unit');
            return simpleQuestion(id,
                prompt: '${labels[i]}: bao nhiêu $unit?', o: o, explanation: '${labels[i]}: ${values[i]} $unit.', data: data);
          case 1:
          case 2:
            final most = ask == 1;
            final target = most ? maxI : minI;
            final o = textOptions(r, labels[target], labels, p.answers);
            return simpleQuestion(id,
                prompt: '${most ? 'Nhiều' : 'Ít'} $unit nhất là:',
                o: o,
                explanation: '${labels[target]}: ${values[target]} $unit, ${most ? 'nhiều' : 'ít'} nhất.',
                data: data);
          default:
            final a = between(r, 0, n - 1);
            var b = between(r, 0, n - 1);
            if (a == b) b = (a + 1) % n;
            final hi = values[a] > values[b] ? a : b, lo = hi == a ? b : a;
            final diff = values[hi] - values[lo];
            final o = numericOptions(r, diff, p.answers, min: 1, max: 200,
                preferred: [values[hi] + values[lo], values[hi], diff + step, diff - step], label: (v) => '$v $unit');
            return simpleQuestion(id,
                prompt: '${labels[hi]} nhiều hơn ${labels[lo]} bao nhiêu $unit?',
                o: o,
                explanation: '${values[hi]} − ${values[lo]} = $diff ($unit)',
                data: data);
        }
    }
  }
}
