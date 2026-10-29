import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/generators/generator.dart' show fmt;
import '../../content/question.dart';
import '../../ui/theme/theme.dart';
import 'scene_art.dart';

/// Hình minh hoạ cho đề bài (đếm đồ vật, đồng hồ, biểu đồ tranh, hộp bóng, đường gấp khúc).
/// Mọi kích thước theo pixel khung 1920×1080.
abstract class QuestionArt {
  /// Chiều cao vùng minh hoạ cần cho câu [q]; 0 = câu không có hình.
  static double heightFor(Question q) {
    switch (q.generator) {
      case 'count_objects':
        return q.data['count'] is int && _countArt.containsKey(q.data['object']) ? 150 : 0;
      case 'time':
        return q.data['hour'] is int && q.data['minute'] is int && q.options.length > 1 ? 250 : 0;
      case 'pictograph':
        return q.data['rows'] is List ? 70.0 * (q.data['rows']! as List).length + 20 : 0;
      case 'likelihood':
        return 230;
      case 'polyline_length':
        return 230;
      default:
        return 0;
    }
  }

  static const _countArt = {'apple': 'apple', 'ball': 'ball', 'fish': 'fish'};

  static Widget? of(Question q) {
    if (heightFor(q) == 0) return null;
    switch (q.generator) {
      case 'count_objects':
        return _CountArt(object: _countArt[q.data['object']]!, count: q.data['count']! as int);
      case 'time':
        return ClockFace(hour: q.data['hour']! as int, minute: q.data['minute']! as int, size: 250);
      case 'pictograph':
        return Pictograph(rows: [
          for (final r in q.data['rows']! as List) ((r as Map)['item'] as String, r['count'] as int),
        ]);
      case 'likelihood':
        return BallBox(colors: (q.data['box']! as List).cast<String>());
      case 'polyline_length':
        return Polyline(
          segments: (q.data['segments']! as List).cast<int>(),
          unit: q.data['unit'] as String? ?? 'cm',
          name: q.data['name'] as String? ?? '',
        );
      default:
        return null;
    }
  }
}

class _CountArt extends StatelessWidget {
  const _CountArt({required this.object, required this.count});

  final String object;
  final int count;

  @override
  Widget build(BuildContext context) {
    final size = count <= 10 ? 96.0 : (count <= 20 ? 60.0 : 30.0);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: count > 20 ? 6 : 16,
      runSpacing: 12,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            // Trên 20 đồ vật: tách nhóm mười cho dễ đếm theo chục.
            padding: EdgeInsets.only(right: count > 20 && i % 10 == 9 ? 28 : 0),
            child: Art(object, width: size),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ đồng hồ

/// Mặt đồng hồ kim. Có thể vẽ thêm kim "ma" (giờ mục tiêu) mờ và kim theo tay bé.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    this.hour,
    this.minute,
    this.size = 300,
    this.hourAngle,
    this.minuteAngle,
    this.ghostHour,
    this.ghostMinute,
    this.handColor = TvdColors.ink,
  });

  /// Giờ hiển thị bằng kim (bỏ qua nếu truyền [hourAngle]/[minuteAngle]).
  final int? hour;
  final int? minute;
  final double size;

  /// Góc kim (độ, 0 = số 12, theo chiều kim đồng hồ) – dùng cho Đồng hồ người.
  final double? hourAngle;
  final double? minuteAngle;

  /// Kim mục tiêu vẽ mờ, nét đứt (mức gợi ý dễ).
  final double? ghostHour;
  final double? ghostMinute;
  final Color handColor;

  static double hourAngleOf(int h, int m) => ((h % 12) * 30 + m * 0.5) % 360;
  static double minuteAngleOf(int m) => (m % 60) * 6.0;

  @override
  Widget build(BuildContext context) {
    final ha = hourAngle ?? (hour == null ? null : hourAngleOf(hour!, minute ?? 0));
    final ma = minuteAngle ?? (minute == null ? null : minuteAngleOf(minute!));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ClockPainter(
          hourAngle: ha,
          minuteAngle: ma,
          ghostHour: ghostHour,
          ghostMinute: ghostMinute,
          handColor: handColor,
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({this.hourAngle, this.minuteAngle, this.ghostHour, this.ghostMinute, required this.handColor});

  final double? hourAngle;
  final double? minuteAngle;
  final double? ghostHour;
  final double? ghostMinute;
  final Color handColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = TvdColors.ink);
    canvas.drawCircle(c, r * .93, Paint()..color = TvdColors.white);
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final long = i % 5 == 0;
      final p1 = c + Offset(math.sin(a), -math.cos(a)) * r * (long ? .80 : .86);
      final p2 = c + Offset(math.sin(a), -math.cos(a)) * r * .90;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = long ? r * .025 : r * .01
          ..color = TvdColors.inkSoft,
      );
    }
    for (var n = 1; n <= 12; n++) {
      final a = n * math.pi / 6;
      final tp = TextPainter(
        text: TextSpan(text: '$n', style: TvText.button.copyWith(fontSize: r * .2, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(math.sin(a), -math.cos(a)) * r * .66 - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, p);
      tp.dispose();
    }

    void hand(double deg, double len, double width, Color color, {bool dashed = false}) {
      final a = deg * math.pi / 180;
      final end = c + Offset(math.sin(a), -math.cos(a)) * r * len;
      final paint = Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color;
      if (!dashed) {
        canvas.drawLine(c, end, paint);
        return;
      }
      const n = 7;
      for (var i = 0; i < n; i += 2) {
        canvas.drawLine(Offset.lerp(c, end, i / n)!, Offset.lerp(c, end, (i + 1) / n)!, paint);
      }
    }

    if (ghostHour != null) hand(ghostHour!, .45, r * .07, TvdColors.correct.withAlpha(120), dashed: true);
    if (ghostMinute != null) hand(ghostMinute!, .72, r * .045, TvdColors.correct.withAlpha(120), dashed: true);
    // Kim ngắn (giờ) màu vàng như tay trái, kim dài (phút) xanh như tay phải.
    if (hourAngle != null) hand(hourAngle!, .45, r * .08, handColor == TvdColors.ink ? TvdColors.left : handColor);
    if (minuteAngle != null) hand(minuteAngle!, .74, r * .05, handColor == TvdColors.ink ? TvdColors.right : handColor);
    canvas.drawCircle(c, r * .06, Paint()..color = TvdColors.ink);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hourAngle != hourAngle ||
      old.minuteAngle != minuteAngle ||
      old.ghostHour != ghostHour ||
      old.ghostMinute != ghostMinute ||
      old.handColor != handColor;
}

// ------------------------------------------------------------------ biểu đồ tranh

/// Đồ vật trong biểu đồ tranh: dùng SVG của bộ asset khi có, còn lại dùng biểu tượng cảm xúc của máy.
Widget itemIcon(String item, double size) {
  const svg = {'apple', 'cat', 'fish', 'rabbit', 'ball'};
  if (svg.contains(item)) return Art(item, width: size);
  const emoji = {'orange': '🍊', 'banana': '🍌', 'mango': '🥭', 'dog': '🐶'};
  return SizedBox(
    width: size,
    height: size,
    child: FittedBox(child: Text(emoji[item] ?? '●', style: const TextStyle(fontSize: 64))),
  );
}

class Pictograph extends StatelessWidget {
  const Pictograph({super.key, required this.rows});

  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(color: TvdColors.white, borderRadius: BorderRadius.circular(TvdRadius.md)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (item, n) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < n; i++) Padding(padding: const EdgeInsets.only(right: 12), child: itemIcon(item, 56)),
                  for (var i = n; i < 8; i++) const SizedBox(width: 68),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ hộp bóng

const ballColors = {'xanh': Color(0xFF22B26B), 'đỏ': Color(0xFFEF5B4F), 'vàng': Color(0xFFFFC53D)};

class BallBox extends StatelessWidget {
  const BallBox({super.key, required this.colors});

  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    final balls = [for (var i = 0; i < 6; i++) colors[i % colors.length]];
    return Container(
      width: 520,
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE2AE6E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC99050), width: 8),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final c in balls)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ballColors[c] ?? TvdColors.inkSoft,
                shape: BoxShape.circle,
                border: Border.all(color: TvdColors.ink, width: 4),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ đường gấp khúc

class Polyline extends StatelessWidget {
  const Polyline({super.key, required this.segments, required this.unit, required this.name});

  final List<int> segments;
  final String unit;
  final String name;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 900, height: 220, child: CustomPaint(painter: _PolylinePainter(segments, unit, name)));
}

class _PolylinePainter extends CustomPainter {
  _PolylinePainter(this.segments, this.unit, this.name);

  final List<int> segments;
  final String unit;
  final String name;

  @override
  void paint(Canvas canvas, Size size) {
    final n = segments.length;
    final step = (size.width - 120) / n;
    final pts = [for (var i = 0; i <= n; i++) Offset(60 + i * step, i.isEven ? size.height - 50 : 60)];
    final line = Paint()
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..color = TvdColors.answerA;
    canvas.drawPath(Path()..addPolygon(pts, false), line);
    for (var i = 0; i <= n; i++) {
      canvas.drawCircle(pts[i], 12, Paint()..color = TvdColors.ink);
      if (i < name.length) _label(canvas, name[i], pts[i] + Offset(0, i.isEven ? 34 : -34), 40, TvdColors.ink);
    }
    for (var i = 0; i < n; i++) {
      final mid = Offset.lerp(pts[i], pts[i + 1], .5)!;
      _label(canvas, '${fmt(segments[i])} $unit', mid + const Offset(-70, 0), 36, TvdColors.answerADark);
    }
  }

  void _label(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TvText.button.copyWith(fontSize: size, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_PolylinePainter old) => false;
}

// ------------------------------------------------------------------ hình phẳng, hình khối

/// Vẽ một hình của dạng bài shape_identify (theo mã hình).
class ShapeIcon extends StatelessWidget {
  const ShapeIcon({super.key, required this.shape, this.size = 200, this.color});

  final String shape;
  final double size;
  final Color? color;

  static const known = {
    'square', 'circle', 'triangle', 'rectangle', 'quadrilateral', 'cube', 'cuboid', 'cylinder', 'sphere',
    'segment', 'curve', 'polyline', //
  };

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _ShapePainter(shape, color)));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);

  final String shape;
  final Color? color;

  static const _defaults = {
    'square': TvdColors.answerB,
    'circle': TvdColors.answerA,
    'triangle': TvdColors.answerC,
    'rectangle': TvdColors.answerD,
    'quadrilateral': Color(0xFF47A267),
    'cube': TvdColors.answerB,
    'cuboid': Color(0xFFE2AE6E),
    'cylinder': TvdColors.answerA,
    'sphere': TvdColors.correct,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.scale(s / 120);
    final fill = Paint()..color = color ?? _defaults[shape] ?? TvdColors.answerA;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = TvdColors.ink;
    void both(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    final light = Paint()..color = TvdColors.white.withAlpha(150);
    switch (shape) {
      case 'square':
        both(Path()..addRRect(RRect.fromLTRBR(10, 10, 110, 110, const Radius.circular(6))));
      case 'circle':
        both(Path()..addOval(const Rect.fromLTWH(8, 8, 104, 104)));
      case 'triangle':
        both(Path()
          ..moveTo(60, 10)
          ..lineTo(112, 106)
          ..lineTo(8, 106)
          ..close());
      case 'rectangle':
        both(Path()..addRRect(RRect.fromLTRBR(4, 28, 116, 92, const Radius.circular(6))));
      case 'quadrilateral':
        both(Path()
          ..moveTo(22, 18)
          ..lineTo(100, 30)
          ..lineTo(112, 100)
          ..lineTo(10, 92)
          ..close());
      case 'cube':
        canvas.drawPath(
          Path()
            ..moveTo(10, 40)
            ..lineTo(40, 10)
            ..lineTo(110, 10)
            ..lineTo(80, 40)
            ..close(),
          light,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, 40)
            ..lineTo(40, 10)
            ..lineTo(110, 10)
            ..lineTo(80, 40)
            ..close(),
          stroke,
        );
        both(Path()
          ..moveTo(80, 40)
          ..lineTo(110, 10)
          ..lineTo(110, 80)
          ..lineTo(80, 110)
          ..close());
        both(Path()..addRect(const Rect.fromLTWH(10, 40, 70, 70)));
      case 'cuboid':
        final top = Path()
          ..moveTo(4, 50)
          ..lineTo(30, 26)
          ..lineTo(116, 26)
          ..lineTo(90, 50)
          ..close();
        canvas.drawPath(top, light);
        canvas.drawPath(top, stroke);
        both(Path()
          ..moveTo(90, 50)
          ..lineTo(116, 26)
          ..lineTo(116, 80)
          ..lineTo(90, 104)
          ..close());
        both(Path()..addRect(const Rect.fromLTWH(4, 50, 86, 54)));
      case 'cylinder':
        both(Path()
          ..moveTo(15, 26)
          ..lineTo(15, 96)
          ..arcToPoint(const Offset(105, 96), radius: const Radius.elliptical(45, 14), clockwise: false)
          ..lineTo(105, 26));
        final topE = Path()..addOval(const Rect.fromLTWH(15, 12, 90, 28));
        canvas.drawPath(topE, light);
        canvas.drawPath(topE, stroke);
      case 'sphere':
        both(Path()..addOval(const Rect.fromLTWH(8, 8, 104, 104)));
        canvas.drawOval(const Rect.fromLTWH(26, 26, 26, 16), light);
        canvas.drawOval(
          const Rect.fromLTWH(8, 46, 104, 28),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = TvdColors.ink.withAlpha(110),
        );
      case 'segment':
        final p = Paint()
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = TvdColors.ink;
        canvas.drawLine(const Offset(14, 90), const Offset(106, 30), p);
        canvas.drawCircle(const Offset(14, 90), 9, Paint()..color = TvdColors.answerA);
        canvas.drawCircle(const Offset(106, 30), 9, Paint()..color = TvdColors.answerA);
      case 'curve':
        canvas.drawPath(
          Path()
            ..moveTo(10, 80)
            ..cubicTo(35, 10, 70, 120, 110, 40),
          stroke..strokeWidth = 8,
        );
      case 'polyline':
        canvas.drawPath(
          Path()..addPolygon(const [Offset(10, 96), Offset(38, 30), Offset(70, 86), Offset(110, 24)], false),
          stroke..strokeWidth = 8,
        );
        for (final o in const [Offset(10, 96), Offset(38, 30), Offset(70, 86), Offset(110, 24)]) {
          canvas.drawCircle(o, 8, Paint()..color = TvdColors.answerA);
        }
      default:
        both(Path()..addOval(const Rect.fromLTWH(30, 30, 60, 60)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.shape != shape || old.color != color;
}

// ------------------------------------------------------------------ tiền Việt Nam

/// Tờ tiền cách điệu (không sao chép mẫu tiền thật): màu gần với tờ thật, mệnh giá in to.
class Banknote extends StatelessWidget {
  const Banknote({super.key, required this.value, this.width = 360});

  final int value;
  final double width;

  static const _colors = {
    1000: Color(0xFFB59A6A),
    2000: Color(0xFF8C8FA8),
    5000: Color(0xFF6C7FB8),
    10000: Color(0xFFC9A44A),
    20000: Color(0xFF5B8DD6),
    50000: Color(0xFFD27BA4),
    100000: Color(0xFF6DAA6A),
    200000: Color(0xFFC0705A),
    500000: Color(0xFF4FA3B8),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[value] ?? TvdColors.answerA;
    return Container(
      width: width,
      height: width * .48,
      padding: EdgeInsets.all(width * .04),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(width * .04),
        border: Border.all(color: TvdColors.ink, width: 4),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: TvdColors.white.withAlpha(170), width: 3),
          borderRadius: BorderRadius.circular(width * .03),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmt(value), style: TvText.button.copyWith(fontSize: 72, color: TvdColors.white, height: 1)),
                Text('ĐỒNG', style: TvText.label.copyWith(fontSize: 28, color: TvdColors.white, letterSpacing: 6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nội dung một ô đáp án: hình (Săn hình, tờ tiền) hoặc chữ.
Widget optionArt(Question q, int i, {double size = 200}) {
  final o = q.options[i];
  if (q.data['kind'] == 'shape' && ShapeIcon.known.contains(o)) return ShapeIcon(shape: o, size: size);
  if (q.data['kind'] == 'banknote' && o.startsWith('vnd_')) {
    return Banknote(value: int.tryParse(o.substring(4)) ?? 0, width: size * 1.6);
  }
  return Text(o);
}
