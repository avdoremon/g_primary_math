import 'dart:math' as math;

import '../question.dart';
import 'generator.dart';

/// Lớp 1: vị trí, định hướng không gian – dữ liệu cho mini game G7 "Con nói, con làm".
///
/// types:
/// - "pose": giơ tay trái / phải / hai tay (cơ chế T)
/// - "step": bước sang trái / phải (cơ chế B)
/// - "touch": chạm đồ vật theo vị trí trong cảnh (trên–giữa–dưới, trái–phải, trước–sau)
/// - "compound": lệnh ghép hai vế, chỉ dùng ở level khó
class PositionGenerator extends QuestionGenerator {
  const PositionGenerator();

  @override
  String get id => 'position';

  static const _scenes = <String, ({String object, String objectName, List<String> slots, String Function(String) say})>{
    'shelf': (
      object: 'rabbit',
      objectName: 'bạn thỏ',
      slots: ['trên', 'giữa', 'dưới'],
      say: _shelf,
    ),
    'tree': (
      object: 'rabbit',
      objectName: 'bạn thỏ',
      slots: ['trái', 'phải'],
      say: _tree,
    ),
    'table': (
      object: 'ball',
      objectName: 'quả bóng',
      slots: ['trên', 'dưới'],
      say: _table,
    ),
    'box': (
      object: 'cat',
      objectName: 'con mèo',
      slots: ['trước', 'sau'],
      say: _box,
    ),
  };

  static String _shelf(String slot) => 'ở tầng $slot';
  static String _tree(String slot) => 'ở bên $slot cái cây';
  static String _table(String slot) => 'ở $slot cái bàn';
  static String _box(String slot) => 'đứng $slot cái hộp';

  @override
  List<String> validate(GenParams p) {
    const known = ['pose', 'step', 'touch', 'compound'];
    final errors = [
      for (final t in p.strList('types', const ['pose', 'step', 'touch']))
        if (!known.contains(t)) 'types không có "$t"',
      for (final s in p.strList('scenes', _scenes.keys.toList()))
        if (!_scenes.containsKey(s)) 'scenes không có "$s"',
    ];
    return errors;
  }

  @override
  Question generate(GenParams p, math.Random r) {
    final type = pick(p.strList('types', const ['pose', 'step', 'touch']), r);
    switch (type) {
      case 'pose':
        final which = pick(const ['trái', 'phải', 'hai'], r);
        final text = which == 'hai' ? 'Con giơ hai tay lên!' : 'Con giơ tay $which lên!';
        const options = ['Tay trái', 'Tay phải', 'Hai tay'];
        final answer = which == 'trái' ? 0 : (which == 'phải' ? 1 : 2);
        return Question(
          generator: id,
          prompt: text,
          speech: text,
          options: options,
          answer: answer,
          explanation: which == 'hai' ? 'Giơ cả hai tay lên nhé!' : 'Tay $which là tay ở bên $which của con.',
          explanationSpeech: which == 'hai' ? 'Giơ cả hai tay lên nhé!' : 'Tay $which là tay ở bên $which của con.',
          data: {
            'type': 'pose',
            'left': which == 'phải' ? 'down' : 'up',
            'right': which == 'trái' ? 'down' : 'up',
            'keyword': which == 'hai' ? 'hai tay' : which,
          },
        );
      case 'step':
        final side = pick(const ['trái', 'phải'], r);
        return Question(
          generator: id,
          prompt: 'Con bước sang bên $side!',
          speech: 'Con bước sang bên $side!',
          options: const ['Bên trái', 'Bên phải'],
          answer: side == 'trái' ? 0 : 1,
          explanation: 'Bên $side là phía tay $side của con.',
          explanationSpeech: 'Bên $side là phía tay $side của con.',
          data: {'type': 'step', 'side': side == 'trái' ? 'left' : 'right', 'keyword': side},
        );
      case 'compound':
        final hand = pick(const ['trái', 'phải'], r);
        final side = pick(const ['trái', 'phải'], r);
        final text = 'Giơ tay $hand và bước sang $side!';
        return Question(
          generator: id,
          prompt: text,
          speech: text,
          options: const ['Làm đúng cả hai việc'],
          answer: 0,
          explanation: 'Vế 1: giơ tay $hand. Vế 2: bước sang bên $side.',
          explanationSpeech: 'Đầu tiên giơ tay $hand, rồi vẫn giữ tay và bước sang bên $side.',
          data: {
            'type': 'compound',
            'left': hand == 'trái' ? 'up' : 'down',
            'right': hand == 'phải' ? 'up' : 'down',
            'side': side == 'trái' ? 'left' : 'right',
          },
        );
      default:
        final sceneId = pick(p.strList('scenes', _scenes.keys.toList()), r);
        final scene = _scenes[sceneId]!;
        final slot = pick(scene.slots, r);
        final where = scene.say(slot);
        final text = 'Chạm vào ${scene.objectName} $where';
        return Question(
          generator: id,
          prompt: text,
          speech: '$text nhé!',
          options: [for (final s in scene.slots) '${scene.objectName} ${scene.say(s)}'],
          answer: scene.slots.indexOf(slot),
          explanation: '${cap(scene.objectName)} $where ở đây nè!',
          explanationSpeech: '${cap(scene.objectName)} $where.',
          data: {'type': 'touch', 'scene': sceneId, 'object': scene.object, 'slots': scene.slots, 'keyword': slot},
        );
    }
  }
}

/// Hình phẳng, hình khối (lớp 1–2): chạm đúng hình được gọi tên.
class ShapeIdentifyGenerator extends QuestionGenerator {
  const ShapeIdentifyGenerator();

  @override
  String get id => 'shape_identify';

  static const shapes = <String, ({String name, String fact})>{
    'square': (name: 'hình vuông', fact: 'Hình vuông có 4 cạnh dài bằng nhau.'),
    'circle': (name: 'hình tròn', fact: 'Hình tròn không có cạnh, không có góc.'),
    'triangle': (name: 'hình tam giác', fact: 'Hình tam giác có 3 cạnh.'),
    'rectangle': (name: 'hình chữ nhật', fact: 'Hình chữ nhật có 4 cạnh, hai cạnh dài và hai cạnh ngắn.'),
    'quadrilateral': (name: 'hình tứ giác', fact: 'Hình tứ giác có 4 cạnh.'),
    'cube': (name: 'khối lập phương', fact: 'Khối lập phương có các mặt đều là hình vuông.'),
    'cuboid': (name: 'khối hộp chữ nhật', fact: 'Khối hộp chữ nhật giống cái hộp.'),
    'cylinder': (name: 'khối trụ', fact: 'Khối trụ giống cái lon, lăn được.'),
    'sphere': (name: 'khối cầu', fact: 'Khối cầu giống quả bóng, lăn được.'),
    'segment': (name: 'đoạn thẳng', fact: 'Đoạn thẳng nối hai điểm.'),
    'curve': (name: 'đường cong', fact: 'Đường cong không thẳng.'),
    'polyline': (name: 'đường gấp khúc', fact: 'Đường gấp khúc gồm nhiều đoạn thẳng nối nhau.'),
    // Lớp 3–5
    'angle_right': (name: 'góc vuông', fact: 'Góc vuông giống góc của tờ giấy, số đo 90°.'),
    'angle_acute': (name: 'góc nhọn', fact: 'Góc nhọn bé hơn góc vuông.'),
    'angle_obtuse': (name: 'góc tù', fact: 'Góc tù lớn hơn góc vuông nhưng bé hơn góc bẹt.'),
    'angle_straight': (name: 'góc bẹt', fact: 'Góc bẹt có hai cạnh thẳng hàng, số đo 180°.'),
    'lines_perpendicular': (name: 'hai đường thẳng vuông góc', fact: 'Hai đường thẳng vuông góc tạo thành bốn góc vuông.'),
    'lines_parallel': (name: 'hai đường thẳng song song', fact: 'Hai đường thẳng song song không bao giờ cắt nhau.'),
    'lines_intersect': (name: 'hai đường thẳng cắt nhau', fact: 'Hai đường thẳng cắt nhau tại một điểm.'),
    'parallelogram': (name: 'hình bình hành', fact: 'Hình bình hành có hai cặp cạnh đối diện song song và bằng nhau.'),
    'rhombus': (name: 'hình thoi', fact: 'Hình thoi có bốn cạnh bằng nhau và hai cặp cạnh đối diện song song.'),
    'trapezoid': (name: 'hình thang', fact: 'Hình thang có một cặp cạnh đối diện song song.'),
  };

  @override
  List<String> validate(GenParams p) => [
        for (final s in p.strList('shapes', const ['square', 'circle', 'triangle', 'rectangle']))
          if (!shapes.containsKey(s)) 'shapes không có "$s"',
      ];

  @override
  Question generate(GenParams p, math.Random r) {
    final set = p.strList('shapes', const ['square', 'circle', 'triangle', 'rectangle']);
    final target = pick(set, r);
    final info = shapes[target]!;
    final o = textOptions(r, target, set, p.answers);
    return Question(
      generator: id,
      prompt: 'Chạm vào ${info.name}!',
      speech: 'Con chạm vào ${info.name} nhé!',
      options: o.options,
      answer: o.answer,
      explanation: info.fact,
      explanationSpeech: 'Đây là ${info.name}. ${info.fact}',
      data: {'kind': 'shape', 'names': {for (final s in o.options) s: shapes[s]!.name}},
    );
  }
}

/// Dài hơn / ngắn hơn (lớp 1), nặng hơn / nhẹ hơn (lớp 2): hai đồ vật, bước về phía đồ vật đúng.
class LengthCompareGenerator extends QuestionGenerator {
  const LengthCompareGenerator();

  @override
  String get id => 'length_compare';

  static const _length = <String, int>{
    'cái bút chì': 15,
    'cái thước kẻ': 20,
    'cục tẩy': 4,
    'quyển sách': 25,
    'cái kẹp tóc': 6,
    'cái thìa': 12,
  };
  static const _weight = <String, int>{
    'quả dưa hấu': 3000,
    'quả cam': 200,
    'con mèo': 4000,
    'quyển vở': 100,
    'bao gạo': 10000,
    'cái lá': 1,
  };

  @override
  Question generate(GenParams p, math.Random r) {
    final weight = p.strOf('measure', 'length') == 'weight';
    final table = weight ? _weight : _length;
    final names = table.keys.toList()..shuffle(r);
    final a = names[0], b = names[1];
    final askMore = r.nextBool();
    final word = weight ? (askMore ? 'nặng hơn' : 'nhẹ hơn') : (askMore ? 'dài hơn' : 'ngắn hơn');
    final bigger = table[a]! > table[b]! ? a : b;
    final target = askMore ? bigger : (bigger == a ? b : a);
    final other = target == a ? b : a;
    return Question(
      generator: id,
      prompt: 'Cái nào $word?',
      speech: '${cap(a)} và $b, cái nào $word?',
      options: [a, b],
      answer: target == a ? 0 : 1,
      explanation: '${cap(target)} $word $other.',
      explanationSpeech: '${cap(target)} $word $other.',
      data: {'measure': weight ? 'weight' : 'length', 'values': {a: table[a], b: table[b]}},
    );
  }
}

/// Lớp 2: chọn đơn vị đo phù hợp (cm, dm, m, km, kg, l) và đổi đơn vị độ dài.
class UnitChooseGenerator extends QuestionGenerator {
  const UnitChooseGenerator();

  @override
  String get id => 'unit_choose';

  static const _items = <({String text, String speech, String unit})>[
    (text: 'Bàn học cao khoảng 7 …', speech: 'Bàn học cao khoảng bảy mấy?', unit: 'dm'),
    (text: 'Cột cờ trường em cao khoảng 6 …', speech: 'Cột cờ trường em cao khoảng sáu mấy?', unit: 'm'),
    (text: 'Cái bút chì dài khoảng 15 …', speech: 'Cái bút chì dài khoảng mười lăm mấy?', unit: 'cm'),
    (text: 'Từ nhà Lan đến chợ huyện khoảng 5 …', speech: 'Từ nhà Lan đến chợ huyện khoảng năm mấy?', unit: 'km'),
    (text: 'Bao gạo nặng 25 …', speech: 'Bao gạo nặng hai mươi lăm mấy?', unit: 'kg'),
    (text: 'Quả dưa hấu nặng khoảng 3 …', speech: 'Quả dưa hấu nặng khoảng ba mấy?', unit: 'kg'),
    (text: 'Cái xô đựng được 10 … nước', speech: 'Cái xô đựng được mười mấy nước?', unit: 'l'),
    (text: 'Chai nước to đựng 2 … nước', speech: 'Chai nước to đựng hai mấy nước?', unit: 'l'),
    (text: 'Cửa lớp học cao khoảng 2 …', speech: 'Cửa lớp học cao khoảng hai mấy?', unit: 'm'),
    // Lớp 3: mm, g, ml
    (text: 'Con kiến dài khoảng 5 …', speech: 'Con kiến dài khoảng năm mấy?', unit: 'mm'),
    (text: 'Quyển vở dày khoảng 4 …', speech: 'Quyển vở dày khoảng bốn mấy?', unit: 'mm'),
    (text: 'Quả trứng gà nặng khoảng 50 …', speech: 'Quả trứng gà nặng khoảng năm mươi mấy?', unit: 'g'),
    (text: 'Gói kẹo nặng 200 …', speech: 'Gói kẹo nặng hai trăm mấy?', unit: 'g'),
    (text: 'Hộp sữa nhỏ đựng 180 … sữa', speech: 'Hộp sữa nhỏ đựng một trăm tám mươi mấy sữa?', unit: 'ml'),
    (text: 'Cái thìa đựng được 5 … nước', speech: 'Cái thìa đựng được năm mấy nước?', unit: 'ml'),
  ];

  static const _unitWords = {
    'cm': 'xăng-ti-mét',
    'dm': 'đề-xi-mét',
    'm': 'mét',
    'km': 'ki-lô-mét',
    'kg': 'ki-lô-gam',
    'l': 'lít',
    'mm': 'mi-li-mét',
    'g': 'gam',
    'ml': 'mi-li-lít',
  };

  /// Đơn vị lớp 2 (mặc định). Lớp 3 thêm mm, g, ml qua tham số "units".
  static const _grade2Units = ['cm', 'dm', 'm', 'km', 'kg', 'l'];

  static const _conversions = <({String text, String speech, int value, List<int> wrong, String unit})>[
    (text: '1 dm = … cm', speech: 'Một đề-xi-mét bằng bao nhiêu xăng-ti-mét?', value: 10, wrong: [1, 100], unit: 'cm'),
    (text: '1 m = … dm', speech: 'Một mét bằng bao nhiêu đề-xi-mét?', value: 10, wrong: [100, 1], unit: 'dm'),
    (text: '1 m = … cm', speech: 'Một mét bằng bao nhiêu xăng-ti-mét?', value: 100, wrong: [10, 1000], unit: 'cm'),
    (text: '1 km = … m', speech: 'Một ki-lô-mét bằng bao nhiêu mét?', value: 1000, wrong: [100, 10], unit: 'm'),
  ];

  @override
  Question generate(GenParams p, math.Random r) {
    final ask = switch (p.strOf('ask', 'unit')) {
      'mixed' => r.nextBool() ? 'unit' : 'convert',
      final s => s,
    };
    if (ask == 'convert') {
      final c = pick(_conversions, r);
      final o = textOptions(r, fmt(c.value), [for (final w in c.wrong) fmt(w)], p.answers);
      final u = c.text.split(' = ').first;
      return Question(
        generator: id,
        prompt: c.text,
        speech: c.speech,
        options: o.options,
        answer: o.answer,
        explanation: '$u = ${fmt(c.value)} ${c.unit}',
        explanationSpeech: c.speech.replaceAll(' bao nhiêu ', ' ${say(c.value)} ').replaceAll('?', '.'),
      );
    }
    final units = p.strList('units', _grade2Units);
    final item = pick(_items.where((i) => units.contains(i.unit)).toList(), r);
    final o = textOptions(r, item.unit, units, p.answers);
    final answerText = item.text.replaceAll('…', item.unit);
    return Question(
      generator: id,
      prompt: item.text,
      speech: '${item.speech} Con chọn đơn vị phù hợp nhé!',
      options: o.options,
      answer: o.answer,
      explanation: answerText,
      explanationSpeech: item.speech.replaceAll(' mấy', ' ${_unitWords[item.unit]}').replaceAll('?', '.'),
    );
  }
}

/// Xem giờ, xem lịch.
/// ask "read": đọc giờ trên đồng hồ; "pose": mini game Đồng hồ người (data.hour, data.minute);
/// "weekday": thứ trong tuần; "month_days": số ngày trong tháng (lớp 2).
class TimeGenerator extends QuestionGenerator {
  const TimeGenerator();

  @override
  String get id => 'time';

  static const _weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
  static const _monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  static String timeText(int h, int m) => m == 0 ? '$h giờ' : '$h giờ $m phút';
  static String timeSpeech(int h, int m) => m == 0 ? '${say(h)} giờ' : '${say(h)} giờ ${say(m)} phút';

  @override
  Question generate(GenParams p, math.Random r) {
    final ask = pick(p.strList('ask', const ['read']), r);
    final minutes = p.intList('minutes', const [0]);

    switch (ask) {
      case 'weekday':
        final today = between(r, 0, 6);
        final tomorrow = r.nextBool();
        final target = (today + (tomorrow ? 1 : 6)) % 7;
        final word = tomorrow ? 'Ngày mai' : 'Hôm qua';
        final o = textOptions(r, _weekdays[target], _weekdays, p.answers);
        return Question(
          generator: id,
          prompt: 'Hôm nay là ${_weekdays[today]}. $word là thứ mấy?',
          speech: 'Hôm nay là ${_weekdays[today]}. $word là thứ mấy?',
          options: o.options,
          answer: o.answer,
          explanation: '$word là ${_weekdays[target]}.',
          explanationSpeech: 'Một tuần có bảy ngày. $word là ${_weekdays[target]}.',
        );
      case 'month_days':
        final month = between(r, 1, 12);
        final days = _monthDays[month - 1];
        final o = textOptions(r, '$days', const ['28', '30', '31'], math.min(3, p.answers));
        return Question(
          generator: id,
          prompt: 'Tháng $month có bao nhiêu ngày?',
          speech: 'Tháng ${say(month)} có bao nhiêu ngày?',
          options: o.options,
          answer: o.answer,
          explanation: 'Tháng $month có $days ngày${month == 2 ? ' (năm nhuận có 29 ngày)' : ''}.',
          explanationSpeech: 'Tháng ${say(month)} có ${say(days)} ngày.',
        );
      case 'pose':
        final h = between(r, 1, 12);
        final m = pick(minutes, r);
        return Question(
          generator: id,
          prompt: 'Con hãy chỉ ${timeText(h, m)}!',
          speech: 'Con dùng hai tay làm kim đồng hồ, chỉ ${timeSpeech(h, m)} nhé!',
          options: [timeText(h, m)],
          answer: 0,
          explanation: 'Kim ngắn chỉ số $h${m == 0 ? '' : ' (hơi lệch)'}, kim dài chỉ số ${m == 0 ? 12 : m ~/ 5}.',
          explanationSpeech: 'Kim ngắn chỉ số ${say(h)}, kim dài chỉ số ${say(m == 0 ? 12 : m ~/ 5)}.',
          data: {'hour': h, 'minute': m},
        );
      default:
        final h = between(r, 1, 12);
        final m = pick(minutes, r);
        final mirror = 12 - h == 0 ? 12 : 12 - h; // nhầm đọc ngược chiều
        final swapped = m == 0 ? 12 : m ~/ 5; // nhầm kim ngắn với kim dài
        final wrong = <String>{
          timeText(h % 12 + 1, m),
          timeText(h == 1 ? 12 : h - 1, m),
          if (mirror != h) timeText(mirror, m),
          if (m == 0 && swapped != h) timeText(swapped, 0),
          for (final mm in minutes)
            if (mm != m) timeText(h, mm),
        }.toList();
        final o = textOptions(r, timeText(h, m), wrong, p.answers);
        return Question(
          generator: id,
          prompt: 'Đồng hồ chỉ mấy giờ?',
          speech: 'Đồng hồ chỉ mấy giờ?',
          options: o.options,
          answer: o.answer,
          explanation: 'Kim ngắn chỉ số $h, kim dài chỉ số ${m == 0 ? 12 : m ~/ 5}: ${timeText(h, m)}.',
          explanationSpeech: 'Kim ngắn chỉ số ${say(h)}, kim dài chỉ số ${say(m == 0 ? 12 : m ~/ 5)}. '
              'Đồng hồ chỉ ${timeSpeech(h, m)}.',
          data: {'hour': h, 'minute': m},
        );
    }
  }
}

/// Lớp 2: nhận biết tiền Việt Nam qua hình ảnh tờ tiền.
class MoneyIdentifyGenerator extends QuestionGenerator {
  const MoneyIdentifyGenerator();

  @override
  String get id => 'money_identify';

  @override
  Question generate(GenParams p, math.Random r) {
    final notes = p.intList('notes', const [1000, 2000, 5000, 10000]);
    final target = pick(notes, r);
    final o = textOptions(r, 'vnd_$target', [for (final n in notes) 'vnd_$n'], p.answers);
    return Question(
      generator: id,
      prompt: 'Chạm vào tờ ${fmt(target)} đồng!',
      speech: 'Con chạm vào tờ ${say(target)} đồng nhé!',
      options: o.options,
      answer: o.answer,
      explanation: 'Đây là tờ ${fmt(target)} đồng.',
      explanationSpeech: 'Đây là tờ ${say(target)} đồng.',
      data: {'kind': 'banknote', 'values': {for (final s in o.options) s: int.parse(s.substring(4))}},
    );
  }
}
