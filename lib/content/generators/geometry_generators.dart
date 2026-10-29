import 'dart:math' as math;

import '../numbers.dart';
import '../question.dart';
import 'big_number_generators.dart';
import 'fraction_generators.dart';
import 'generator.dart';

/// Chu vi, diện tích, thể tích. kinds:
/// - lớp 3: rect_perimeter, square_perimeter, triangle_perimeter, quad_perimeter, rect_area, square_area
/// - lớp 5: triangle_area, trapezoid_area, circle_c (chu vi hình tròn), circle_area, box_volume, cube_volume,
///   box_lateral, box_total, cube_lateral, cube_total
/// Hình vẽ kèm số đo: data.kind = "figure".
class PerimeterAreaGenerator extends QuestionGenerator {
  const PerimeterAreaGenerator();

  @override
  String get id => 'perimeter_area';

  static const kinds = [
    'rect_perimeter', 'square_perimeter', 'triangle_perimeter', 'quad_perimeter', 'rect_area', 'square_area', //
    'triangle_area', 'trapezoid_area', 'circle_c', 'circle_area', 'box_volume', 'cube_volume', //
    'box_lateral', 'box_total', 'cube_lateral', 'cube_total',
  ];

  @override
  List<String> validate(GenParams p) => p
      .strList('kinds', const ['rect_perimeter'])
      .where((k) => !kinds.contains(k))
      .map((k) => 'kinds không có "$k"')
      .toList();

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['rect_perimeter']), r);
    final u = pick(p.strList('units', const ['cm']), r);
    final maxSide = p.intOf('maxSide', 12);
    int side([int lo = 2]) => between(r, lo, maxSide);

    late String figure, prompt, explanation;
    late List<int> dims;
    late int value;
    var wrong = <int>[];
    var unit = u;
    switch (kind) {
      case 'rect_perimeter':
      case 'rect_area':
        final a = side(3), b = between(r, 2, a - 1);
        figure = 'rect';
        dims = [a, b];
        if (kind == 'rect_perimeter') {
          value = (a + b) * 2;
          wrong = [a + b, a * b, a * 2 + b];
          prompt = 'Chu vi hình chữ nhật là:';
          explanation = '($a + $b) × 2 = $value ($u)';
        } else {
          value = a * b;
          unit = '$u²';
          wrong = [(a + b) * 2, a + b, a * b + a];
          prompt = 'Diện tích hình chữ nhật là:';
          explanation = '$a × $b = $value ($unit)';
        }
      case 'square_perimeter':
      case 'square_area':
        final a = side();
        figure = 'square';
        dims = [a];
        if (kind == 'square_perimeter') {
          value = a * 4;
          wrong = [a * a, a + 4, a * 2];
          prompt = 'Chu vi hình vuông là:';
          explanation = '$a × 4 = $value ($u)';
        } else {
          value = a * a;
          unit = '$u²';
          wrong = [a * 4, a * 2, a * a + a];
          prompt = 'Diện tích hình vuông là:';
          explanation = '$a × $a = $value ($unit)';
        }
      case 'triangle_perimeter':
        final a = side(3), b = side(3);
        final c = between(r, (a - b).abs() + 1, a + b - 1);
        figure = 'triangle';
        dims = [a, b, c];
        value = a + b + c;
        wrong = [a + b, a * b, value + 1];
        prompt = 'Chu vi hình tam giác là:';
        explanation = '$a + $b + $c = $value ($u)';
      case 'quad_perimeter':
        dims = [side(), side(), side(), side()];
        figure = 'quad';
        value = dims.fold(0, (s, v) => s + v);
        wrong = [value - dims.last, value + 1, value - 1];
        prompt = 'Chu vi hình tứ giác là:';
        explanation = '${dims.join(' + ')} = $value ($u)';
      case 'triangle_area':
        final h = side(2);
        var a = side(3);
        if (a * h % 2 == 1) a++;
        figure = 'triangle_h';
        dims = [a, h];
        value = a * h ~/ 2;
        unit = '$u²';
        wrong = [a * h, a + h, value + a];
        prompt = 'Diện tích hình tam giác là:';
        explanation = '$a × $h : 2 = $value ($unit)';
      case 'trapezoid_area':
        final a = side(4), b = between(r, 2, a - 1);
        var h = side(2);
        if ((a + b) * h % 2 == 1) h++;
        figure = 'trapezoid';
        dims = [a, b, h];
        value = (a + b) * h ~/ 2;
        unit = '$u²';
        wrong = [(a + b) * h, a * b * h ~/ 2, a * h];
        prompt = 'Diện tích hình thang là:';
        explanation = '($a + $b) × $h : 2 = $value ($unit)';
      case 'circle_c':
      case 'circle_area':
        final rad = between(r, 1, 10);
        final useD = kind == 'circle_c' && r.nextBool();
        figure = useD ? 'circle_d' : 'circle_r';
        dims = [useD ? rad * 2 : rad];
        const pi = Dec(314, 2);
        final Dec v;
        final List<Dec> w;
        if (kind == 'circle_c') {
          v = Dec(rad * 2, 0) * pi;
          w = [Dec(rad, 0) * pi, Dec(rad * rad, 0) * pi, Dec(rad * 4, 0) * pi];
          prompt = 'Chu vi hình tròn là:';
          explanation = useD ? '${rad * 2} × 3,14 = ${v.text} ($u)' : '$rad × 2 × 3,14 = ${v.text} ($u)';
        } else {
          v = Dec(rad * rad, 0) * pi;
          unit = '$u²';
          w = [Dec(rad * 2, 0) * pi, Dec(rad, 0) * pi, Dec(rad * rad * 4, 0) * pi];
          prompt = 'Diện tích hình tròn là:';
          explanation = '$rad × $rad × 3,14 = ${v.text} ($unit)';
        }
        final o = decOptions(r, v, w, p.answers, unit: unit);
        return simpleQuestion(id,
            prompt: prompt, o: o, explanation: explanation, data: {'kind': 'figure', 'figure': figure, 'dims': dims, 'unit': u});
      case 'box_volume':
      case 'box_lateral':
      case 'box_total':
        final a = side(3), b = between(r, 2, a), c = side(2);
        figure = 'box';
        dims = [a, b, c];
        final lateral = (a + b) * 2 * c;
        switch (kind) {
          case 'box_volume':
            value = a * b * c;
            unit = '$u³';
            wrong = [a * b + c, lateral, a * b * 2];
            prompt = 'Thể tích hình hộp chữ nhật là:';
            explanation = '$a × $b × $c = $value ($unit)';
          case 'box_lateral':
            value = lateral;
            unit = '$u²';
            wrong = [lateral + 2 * a * b, a * b * c, (a + b) * c];
            prompt = 'Diện tích xung quanh của hình hộp chữ nhật là:';
            explanation = '($a + $b) × 2 × $c = $value ($unit)';
          default:
            value = lateral + 2 * a * b;
            unit = '$u²';
            wrong = [lateral, lateral + a * b, a * b * c];
            prompt = 'Diện tích toàn phần của hình hộp chữ nhật là:';
            explanation = '$lateral + $a × $b × 2 = $value ($unit)';
        }
      default: // cube_*
        final a = side(2);
        figure = 'cube';
        dims = [a];
        switch (kind) {
          case 'cube_volume':
            value = a * a * a;
            unit = '$u³';
            wrong = [a * a * 6, a * 3, a * a];
            prompt = 'Thể tích hình lập phương là:';
            explanation = '$a × $a × $a = $value ($unit)';
          case 'cube_lateral':
            value = a * a * 4;
            unit = '$u²';
            wrong = [a * a * 6, a * 4, a * a * a];
            prompt = 'Diện tích xung quanh của hình lập phương là:';
            explanation = '$a × $a × 4 = $value ($unit)';
          default:
            value = a * a * 6;
            unit = '$u²';
            wrong = [a * a * 4, a * 6, a * a * a];
            prompt = 'Diện tích toàn phần của hình lập phương là:';
            explanation = '$a × $a × 6 = $value ($unit)';
        }
    }
    final o = numericOptions(r, value, p.answers, min: 1, max: value * 4 + 50,
        preferred: [...wrong, value + 2, value - 2], label: (v) => '${fmt(v)} $unit');
    return simpleQuestion(id,
        prompt: prompt, o: o, explanation: explanation, data: {'kind': 'figure', 'figure': figure, 'dims': dims, 'unit': u});
  }
}

/// Hình học không cần tính chu vi, diện tích. kinds:
/// - circle_parts (lớp 3): tâm, bán kính, đường kính – có hình vẽ (data.kind = "circle_parts")
/// - radius_diameter (lớp 3): bán kính ↔ đường kính
/// - midpoint (lớp 3): trung điểm đoạn thẳng
/// - angle_type (lớp 4): góc nhọn, vuông, tù, bẹt – có hình vẽ (data.kind = "angle")
/// - angle_measure (lớp 4): đọc số đo góc trên thước đo góc (data.kind = "angle", protractor)
/// - arm_angle (lớp 4): mini game Góc tay – bé dùng hai tay tạo góc (data.angle = acute|right|obtuse|straight)
class GeoGenerator extends QuestionGenerator {
  const GeoGenerator();

  @override
  String get id => 'geo';

  static const angleNames = {
    'acute': 'góc nhọn',
    'right': 'góc vuông',
    'obtuse': 'góc tù',
    'straight': 'góc bẹt',
  };

  static const angleFacts = {
    'acute': 'Góc nhọn bé hơn góc vuông.',
    'right': 'Góc vuông có số đo 90°.',
    'obtuse': 'Góc tù lớn hơn góc vuông, bé hơn góc bẹt.',
    'straight': 'Góc bẹt có số đo 180°, hai cạnh thẳng hàng.',
  };

  static String angleKind(int deg) => deg < 90 ? 'acute' : (deg == 90 ? 'right' : (deg < 180 ? 'obtuse' : 'straight'));

  @override
  Question generate(GenParams p, math.Random r) {
    final kind = pick(p.strList('kinds', const ['angle_type']), r);
    switch (kind) {
      case 'circle_parts':
        const parts = ['Tâm', 'Bán kính', 'Đường kính'];
        final which = between(r, 0, 2);
        final (asked, label) = switch (which) {
          0 => ('Điểm O', 'điểm O'),
          1 => ('Đoạn thẳng OA', 'đoạn thẳng OA'),
          _ => ('Đoạn thẳng MN', 'đoạn thẳng MN'),
        };
        final facts = [
          'O là tâm của hình tròn.',
          'OA nối tâm O với một điểm trên đường tròn: OA là bán kính.',
          'MN đi qua tâm O, nối hai điểm trên đường tròn: MN là đường kính.',
        ];
        final o = textOptions(r, parts[which], parts, 3);
        return Question(
          generator: id,
          prompt: '$asked là gì của hình tròn?',
          speech: '${cap(label)} là gì của hình tròn?',
          options: o.options,
          answer: o.answer,
          explanation: facts[which],
          explanationSpeech: facts[which].replaceAll('OA', 'ô a').replaceAll('MN', 'em nờ').replaceAll(' O', ' ô'),
          data: const {'kind': 'circle_parts'},
        );
      case 'radius_diameter':
        final rad = between(r, 2, 20);
        final askD = r.nextBool();
        final value = askD ? rad * 2 : rad;
        final o = numericOptions(r, value, p.answers, min: 1, max: 100,
            preferred: [askD ? rad : rad * 2, askD ? rad + 2 : rad * 4, value + 1, value - 1], label: (v) => '$v cm');
        return simpleQuestion(
          id,
          prompt: askD
              ? 'Hình tròn có bán kính $rad cm. Đường kính của hình tròn là:'
              : 'Hình tròn có đường kính ${rad * 2} cm. Bán kính của hình tròn là:',
          o: o,
          explanation: askD ? 'Đường kính gấp 2 lần bán kính: $rad × 2 = $value (cm)' : 'Bán kính bằng một nửa đường kính: ${rad * 2} : 2 = $value (cm)',
        );
      case 'midpoint':
        final half = between(r, 2, 20);
        final askHalf = r.nextBool();
        final value = askHalf ? half : half * 2;
        final o = numericOptions(r, value, p.answers, min: 1, max: 100,
            preferred: [askHalf ? half * 2 : half, value + 1, value - 1, value + 2], label: (v) => '$v cm');
        return simpleQuestion(
          id,
          prompt: askHalf
              ? 'M là trung điểm của đoạn thẳng AB. AB = ${half * 2} cm. Độ dài AM là:'
              : 'M là trung điểm của đoạn thẳng AB. AM = $half cm. Độ dài AB là:',
          speech: askHalf
              ? 'M là trung điểm của đoạn thẳng AB. AB dài ${say(half * 2)} xăng-ti-mét. Độ dài AM là bao nhiêu?'
              : 'M là trung điểm của đoạn thẳng AB. AM dài ${say(half)} xăng-ti-mét. Độ dài AB là bao nhiêu?',
          o: o,
          explanation: askHalf ? 'AM bằng một nửa AB: ${half * 2} : 2 = $half (cm)' : 'AB gấp đôi AM: $half × 2 = ${half * 2} (cm)',
          explanationSpeech: askHalf ? 'AM bằng một nửa AB, là ${say(half)} xăng-ti-mét.' : 'AB gấp đôi AM, là ${say(half * 2)} xăng-ti-mét.',
          data: {'kind': 'segment_mid', 'ab': half * 2},
        );
      case 'angle_measure':
        final deg = pick(const [30, 45, 60, 90, 120, 135, 150, 180], r);
        final o = numericOptions(r, deg, p.answers, min: 10, max: 180,
            preferred: [180 - deg, deg + 30, deg - 30, deg + 15, deg - 15], label: (v) => '$v°');
        return simpleQuestion(
          id,
          prompt: 'Góc trong hình có số đo là:',
          o: o,
          explanation: 'Đặt tâm thước trùng đỉnh góc, một cạnh trùng vạch 0: cạnh kia chỉ $deg°.',
          explanationSpeech: 'Góc này có số đo ${say(deg)} độ.',
          data: {'kind': 'angle', 'deg': deg, 'protractor': true, 'rot': between(r, 0, 1) * 180},
        );
      case 'arm_angle':
        final target = pick(p.strList('angles', const ['acute', 'right', 'obtuse', 'straight']), r);
        final name = angleNames[target]!;
        return Question(
          generator: id,
          prompt: 'Dùng hai tay làm $name!',
          speech: 'Con dang hai tay làm thành $name nhé!',
          options: [cap(name)],
          answer: 0,
          explanation: angleFacts[target]!,
          explanationSpeech: '${angleFacts[target]!.replaceAll('90°', 'chín mươi độ').replaceAll('180°', 'một trăm tám mươi độ')} ',
          data: {'angle': target, 'kind': 'angle', 'deg': const {'acute': 50, 'right': 90, 'obtuse': 135, 'straight': 180}[target]},
        );
      default: // angle_type
        final pool = p.strList('angles', const ['acute', 'right', 'obtuse', 'straight']);
        final target = pick(pool, r);
        final deg = switch (target) {
          'acute' => between(r, 2, 8) * 10,
          'right' => 90,
          'obtuse' => between(r, 10, 17) * 10,
          _ => 180,
        };
        final o = textOptions(r, cap(angleNames[target]!), [for (final a in pool) cap(angleNames[a]!)], p.answers);
        return simpleQuestion(
          id,
          prompt: 'Góc trong hình là góc gì?',
          o: o,
          explanation: angleFacts[target]!,
          explanationSpeech: 'Đây là ${angleNames[target]}. ${angleFacts[target]!.replaceAll('90°', 'chín mươi độ').replaceAll('180°', 'một trăm tám mươi độ')}',
          data: {'kind': 'angle', 'deg': deg, 'rot': between(r, 0, 3) * 90},
        );
    }
  }
}
