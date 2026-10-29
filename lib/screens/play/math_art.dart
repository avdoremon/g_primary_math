import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/question.dart';
import '../../ui/theme/theme.dart';
import 'visuals.dart';

/// Hình minh hoạ lớp 3–5, chọn theo `data.kind` của câu hỏi.
/// Mọi kích thước theo pixel khung 1920×1080; vùng hình cao tối đa 220.
abstract class MathArt {
  static double heightFor(Question q) => switch (q.data['kind']) {
        'fraction_pic' || 'figure' || 'angle' || 'circle_parts' || 'thermo' || 'pie' || 'bar' || 'table' => 220,
        'segment_mid' => 160,
        'notes' => 200,
        _ => 0,
      };

  static Widget? of(Question q) {
    final d = q.data;
    switch (d['kind']) {
      case 'fraction_pic':
        return FractionPicture(n: d['n']! as int, d: d['d']! as int, shape: d['shape'] as String? ?? 'circle');
      case 'figure':
        return FigureArt(figure: d['figure']! as String, dims: (d['dims']! as List).cast<int>(), unit: d['unit'] as String? ?? 'cm');
      case 'angle':
        return AngleArt(deg: (d['deg']! as num).toDouble(), rotation: (d['rot'] as num? ?? 0).toDouble(), protractor: d['protractor'] == true);
      case 'circle_parts':
        return const CirclePartsArt();
      case 'segment_mid':
        return const SegmentMidArt();
      case 'thermo':
        return Thermometer(value: d['value']! as int);
      case 'notes':
        return Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [for (final v in (d['notes']! as List).cast<int>()) Banknote(value: v, width: 300)],
        );
      case 'table':
        return DataTableArt(
          title: d['title'] as String? ?? '',
          labels: (d['labels']! as List).cast<String>(),
          values: (d['values']! as List).cast<int>(),
          unit: d['unit'] as String? ?? '',
        );
      case 'bar':
        return BarChartArt(labels: (d['labels']! as List).cast<String>(), values: (d['values']! as List).cast<int>());
      case 'pie':
        return PieChartArt(labels: (d['labels']! as List).cast<String>(), percents: (d['values']! as List).cast<int>());
      default:
        return null;
    }
  }
}

// ------------------------------------------------------------------ chữ có phân số

final _fraction = RegExp(r'(\d+)/(\d+)');

/// Chữ có phân số viết chồng (tử trên, vạch ngang, mẫu dưới), như trong sách.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, required this.style, this.textAlign = TextAlign.center});

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  static bool hasFraction(String s) => _fraction.hasMatch(s);

  /// Các đoạn chữ, phân số thay bằng [WidgetSpan] (dùng chung cho đề bài nhiều dòng).
  static List<InlineSpan> spans(String text, TextStyle style) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _fraction.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
      out.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: StackedFraction(numerator: m.group(1)!, denominator: m.group(2)!, style: style),
      ));
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasFraction(text)) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(TextSpan(style: style, children: spans(text, style)), textAlign: textAlign);
  }
}

class StackedFraction extends StatelessWidget {
  const StackedFraction({super.key, required this.numerator, required this.denominator, required this.style});

  final String numerator;
  final String denominator;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 60) * .62;
    final s = style.copyWith(fontSize: size, height: 1.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * .12),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(numerator, style: s, textAlign: TextAlign.center),
            Container(height: math.max(3, size * .08), color: style.color ?? TvdColors.ink, margin: EdgeInsets.symmetric(vertical: size * .06)),
            Text(denominator, style: s, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hình vẽ

Paint _stroke([double w = 6, Color c = TvdColors.ink]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = c;

void _label(Canvas canvas, String text, Offset center, {double size = 40, Color color = TvdColors.ink, Color? bg}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TvText.button.copyWith(fontSize: size, height: 1, color: color)),
    textDirection: TextDirection.ltr,
  )..layout();
  final topLeft = center - Offset(tp.width / 2, tp.height / 2);
  if (bg != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(topLeft.dx - 10, topLeft.dy - 6, tp.width + 20, tp.height + 12), const Radius.circular(12)),
      Paint()..color = bg,
    );
  }
  tp.paint(canvas, topLeft);
  tp.dispose();
}

/// Hình chia phần bằng nhau, tô màu [n] phần trên [d] phần.
class FractionPicture extends StatelessWidget {
  const FractionPicture({super.key, required this.n, required this.d, this.shape = 'circle'});

  final int n;
  final int d;
  final String shape;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: shape == 'bar' ? 640 : 220,
        height: shape == 'bar' ? 140 : 220,
        child: CustomPaint(painter: _FractionPainter(n, d, shape)),
      );
}

class _FractionPainter extends CustomPainter {
  _FractionPainter(this.n, this.d, this.shape);

  final int n, d;
  final String shape;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = TvdColors.answerA;
    final empty = Paint()..color = TvdColors.white;
    final line = _stroke(5);
    if (shape == 'circle') {
      final c = size.center(Offset.zero);
      final r = size.shortestSide / 2 - 6;
      final rect = Rect.fromCircle(center: c, radius: r);
      for (var i = 0; i < d; i++) {
        final start = -math.pi / 2 + 2 * math.pi * i / d;
        canvas.drawArc(rect, start, 2 * math.pi / d, true, i < n ? fill : empty);
        canvas.drawArc(rect, start, 2 * math.pi / d, true, line);
      }
      return;
    }
    // Hình chữ nhật (lưới) hoặc thanh dài.
    final rows = shape == 'rect' && d % 2 == 0 && d > 3 ? 2 : 1;
    final cols = d ~/ rows;
    final w = (size.width - 12) / cols, h = (size.height - 12) / rows;
    for (var i = 0; i < d; i++) {
      final rr = Rect.fromLTWH(6 + (i % cols) * w, 6 + (i ~/ cols) * h, w, h);
      canvas.drawRect(rr, i < n ? fill : empty);
      canvas.drawRect(rr, line);
    }
  }

  @override
  bool shouldRepaint(_FractionPainter old) => old.n != n || old.d != d || old.shape != shape;
}

/// Hình phẳng / hình khối có ghi số đo (chu vi, diện tích, thể tích).
class FigureArt extends StatelessWidget {
  const FigureArt({super.key, required this.figure, required this.dims, this.unit = 'cm'});

  final String figure;
  final List<int> dims;
  final String unit;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 560, height: 230, child: CustomPaint(painter: _FigurePainter(figure, dims, unit)));
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.figure, this.dims, this.unit);

  final String figure;
  final List<int> dims;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFDDEBFF);
    final line = _stroke(6);
    String t(int i) => '${dims[i]} $unit';
    switch (figure) {
      case 'rect':
      case 'square':
        final ratio = figure == 'square' ? 1.0 : (dims[1] / dims[0]).clamp(.35, .8);
        final w = figure == 'square' ? 160.0 : 340.0;
        final h = figure == 'square' ? 160.0 : w * ratio;
        final r = Rect.fromCenter(center: Offset(size.width / 2, 108), width: w, height: h);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, line);
        _label(canvas, t(0), Offset(r.center.dx, r.bottom + 24), size: 34);
        if (figure == 'rect') _label(canvas, t(1), Offset(r.right + 60, r.center.dy), size: 34);
      case 'triangle':
      case 'triangle_h':
        const ta = Offset(110, 196), tb = Offset(450, 196), tc = Offset(220, 30);
        final tri = Path()..addPolygon(const [ta, tb, tc], true);
        canvas.drawPath(tri, fill);
        canvas.drawPath(tri, line);
        if (figure == 'triangle') {
          _label(canvas, t(0), const Offset(280, 222), size: 32);
          _label(canvas, t(1), const Offset(370, 100), size: 32);
          _label(canvas, t(2), const Offset(118, 100), size: 32);
        } else {
          canvas.drawLine(tc, const Offset(220, 196), _stroke(4, TvdColors.answerC));
          canvas.drawRect(const Rect.fromLTWH(220, 180, 16, 16), _stroke(3, TvdColors.answerC));
          _label(canvas, 'đáy ${t(0)}', const Offset(280, 222), size: 30);
          _label(canvas, 'cao ${t(1)}', const Offset(310, 110), size: 30, color: TvdColors.answerCDark);
        }
      case 'quad':
        const qpts = [Offset(120, 40), Offset(400, 28), Offset(460, 190), Offset(90, 196)];
        final quad = Path()..addPolygon(qpts, true);
        canvas.drawPath(quad, fill);
        canvas.drawPath(quad, line);
        _label(canvas, t(0), const Offset(260, 14), size: 30);
        _label(canvas, t(1), const Offset(500, 104), size: 30);
        _label(canvas, t(2), const Offset(275, 222), size: 30);
        _label(canvas, t(3), const Offset(56, 116), size: 30);
      case 'trapezoid':
        const zpts = [Offset(190, 40), Offset(370, 40), Offset(470, 190), Offset(90, 190)];
        final trap = Path()..addPolygon(zpts, true);
        canvas.drawPath(trap, fill);
        canvas.drawPath(trap, line);
        canvas.drawLine(const Offset(190, 40), const Offset(190, 190), _stroke(4, TvdColors.answerC));
        _label(canvas, 'đáy lớn ${t(0)}', const Offset(280, 216), size: 28);
        _label(canvas, 'đáy bé ${t(1)}', const Offset(280, 16), size: 28);
        _label(canvas, 'cao ${t(2)}', const Offset(118, 116), size: 28, color: TvdColors.answerCDark);
      case 'circle_r':
      case 'circle_d':
        const cc = Offset(280, 112);
        canvas.drawCircle(cc, 96, fill);
        canvas.drawCircle(cc, 96, line);
        canvas.drawCircle(cc, 6, Paint()..color = TvdColors.ink);
        if (figure == 'circle_r') {
          canvas.drawLine(cc, const Offset(376, 112), _stroke(5, TvdColors.answerC));
          _label(canvas, 'r = ${t(0)}', const Offset(330, 88), size: 28, color: TvdColors.answerCDark);
        } else {
          canvas.drawLine(const Offset(184, 112), const Offset(376, 112), _stroke(5, TvdColors.answerC));
          _label(canvas, 'd = ${t(0)}', const Offset(280, 88), size: 28, color: TvdColors.answerCDark);
        }
      case 'box':
      case 'cube':
        final bw = figure == 'cube' ? 140.0 : 230.0, bd = figure == 'cube' ? 70.0 : 80.0, bh = figure == 'cube' ? 140.0 : 110.0;
        final x0 = size.width / 2 - (bw + bd * .7) / 2;
        final front = Rect.fromLTWH(x0, 200 - bh, bw, bh);
        final dx = bd * .7, dy = bd * .5;
        final top = Path()
          ..moveTo(front.left, front.top)
          ..lineTo(front.left + dx, front.top - dy)
          ..lineTo(front.right + dx, front.top - dy)
          ..lineTo(front.right, front.top)
          ..close();
        final side = Path()
          ..moveTo(front.right, front.top)
          ..lineTo(front.right + dx, front.top - dy)
          ..lineTo(front.right + dx, front.bottom - dy)
          ..lineTo(front.right, front.bottom)
          ..close();
        canvas.drawPath(top, Paint()..color = const Color(0xFFEEF5FF));
        canvas.drawPath(side, Paint()..color = const Color(0xFFC3DAFA));
        canvas.drawRect(front, fill);
        canvas.drawPath(top, line);
        canvas.drawPath(side, line);
        canvas.drawRect(front, line);
        if (figure == 'cube') {
          _label(canvas, t(0), Offset(front.center.dx, front.bottom + 22), size: 30);
        } else {
          _label(canvas, t(0), Offset(front.center.dx, front.bottom + 22), size: 30);
          _label(canvas, t(1), Offset(front.right + dx / 2 + 50, front.bottom - dy / 2), size: 30);
          _label(canvas, t(2), Offset(front.left - 52, front.center.dy), size: 30);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.figure != figure || old.dims.join() != dims.join();
}

/// Một góc (có thể kèm thước đo góc).
class AngleArt extends StatelessWidget {
  const AngleArt({super.key, required this.deg, this.rotation = 0, this.protractor = false, this.size = 220, this.color});

  final double deg;
  final double rotation;
  final bool protractor;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * (protractor ? 2.1 : 1.6),
        height: size,
        child: CustomPaint(painter: _AnglePainter(deg, rotation, protractor, color ?? TvdColors.answerA)),
      );
}

class _AnglePainter extends CustomPainter {
  _AnglePainter(this.deg, this.rotation, this.protractor, this.color);

  final double deg, rotation;
  final bool protractor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (protractor) {
      final c = Offset(size.width / 2, size.height - 16);
      final r = size.height - 30;
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = const Color(0xFFFFF6D6));
      canvas.drawArc(rect, math.pi, math.pi, true, _stroke(3, TvdColors.inkSoft));
      for (var a = 0; a <= 180; a += 10) {
        final rad = math.pi + a * math.pi / 180;
        final dir = Offset(math.cos(rad), math.sin(rad));
        final major = a % 30 == 0;
        canvas.drawLine(c + dir * (r - (major ? 22 : 12)), c + dir * r, _stroke(major ? 3 : 2, TvdColors.inkSoft));
        if (major) _label(canvas, '$a', c + dir * (r - 42), size: 20, color: TvdColors.inkSoft);
      }
      // Một cạnh trùng vạch 0 (bên phải), cạnh kia mở [deg] độ.
      drawAngle(canvas, c, deg, length: r * .92, color: color, stroke: 6);
      return;
    }
    final vertex = Offset(size.width / 2 - (deg > 120 ? 0 : size.width * .22), size.height * .55);
    canvas.save();
    // Xoay quanh tâm khung để góc không luôn cùng một hướng.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    drawAngle(canvas, vertex + (deg >= 180 ? Offset(0, size.height * .15) : Offset.zero), deg,
        length: deg >= 180 ? size.width * .42 : size.height * .5, color: color, stroke: 8);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnglePainter old) => old.deg != deg || old.rotation != rotation || old.protractor != protractor || old.color != color;
}

/// Hình tròn tâm O, bán kính OA, đường kính MN.
class CirclePartsArt extends StatelessWidget {
  const CirclePartsArt({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: 300, height: 220, child: CustomPaint(painter: _CirclePartsPainter()));
}

class _CirclePartsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 96.0;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFDDEBFF));
    canvas.drawCircle(c, r, _stroke(5));
    final m = c + const Offset(-r, 0), n = c + const Offset(r, 0);
    final a = c + Offset(math.cos(-1.1) * r, math.sin(-1.1) * r);
    canvas.drawLine(m, n, _stroke(5, TvdColors.answerC));
    canvas.drawLine(c, a, _stroke(5, TvdColors.encourageDark));
    for (final p in [c, m, n, a]) {
      canvas.drawCircle(p, 7, Paint()..color = TvdColors.ink);
    }
    _label(canvas, 'O', c + const Offset(0, 26), size: 30);
    _label(canvas, 'M', m + const Offset(-24, 0), size: 30);
    _label(canvas, 'N', n + const Offset(24, 0), size: 30);
    _label(canvas, 'A', a + const Offset(16, -18), size: 30);
  }

  @override
  bool shouldRepaint(_CirclePartsPainter old) => false;
}

/// Đoạn thẳng AB có trung điểm M.
class SegmentMidArt extends StatelessWidget {
  const SegmentMidArt({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: 640, height: 140, child: CustomPaint(painter: _SegmentPainter()));
}

class _SegmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const y = 60.0;
    const a = Offset(40, y), b = Offset(600, y), m = Offset(320, y);
    canvas.drawLine(a, b, _stroke(7));
    for (final p in [a, m, b]) {
      canvas.drawCircle(p, 10, Paint()..color = p == m ? TvdColors.answerA : TvdColors.ink);
    }
    for (final x in [180.0, 460.0]) {
      canvas.drawLine(Offset(x - 6, y - 16), Offset(x + 6, y + 16), _stroke(4, TvdColors.answerA));
    }
    _label(canvas, 'A', const Offset(40, y + 44), size: 34);
    _label(canvas, 'M', const Offset(320, y + 44), size: 34, color: TvdColors.answerADark);
    _label(canvas, 'B', const Offset(600, y + 44), size: 34);
  }

  @override
  bool shouldRepaint(_SegmentPainter old) => false;
}

/// Nhiệt kế 0–50 °C, vạch chia 2 độ, số mỗi 10 độ.
class Thermometer extends StatelessWidget {
  const Thermometer({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => SizedBox(width: 200, height: 220, child: CustomPaint(painter: _ThermoPainter(value)));
}

class _ThermoPainter extends CustomPainter {
  _ThermoPainter(this.value);

  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 70.0, top = 10.0, bottom = 176.0;
    double yOf(num v) => bottom - (bottom - top) * v / 50;
    canvas.drawRRect(RRect.fromLTRBR(x - 14, top - 6, x + 14, bottom + 6, const Radius.circular(14)), Paint()..color = TvdColors.white);
    canvas.drawRRect(RRect.fromLTRBR(x - 14, top - 6, x + 14, bottom + 6, const Radius.circular(14)), _stroke(4));
    final red = Paint()..color = const Color(0xFFE5484D);
    canvas.drawRect(Rect.fromLTRB(x - 7, yOf(value), x + 7, bottom + 8), red);
    canvas.drawCircle(const Offset(x, bottom + 20), 22, red);
    canvas.drawCircle(const Offset(x, bottom + 20), 22, _stroke(4));
    for (var v = 0; v <= 50; v += 2) {
      final major = v % 10 == 0;
      canvas.drawLine(Offset(x + 16, yOf(v)), Offset(x + (major ? 40 : 28), yOf(v)), _stroke(major ? 3 : 2));
      if (major) _label(canvas, '$v', Offset(x + 66, yOf(v)), size: 24);
    }
    _label(canvas, '°C', const Offset(x + 66, top - 2), size: 22, color: TvdColors.inkSoft);
  }

  @override
  bool shouldRepaint(_ThermoPainter old) => old.value != value;
}

/// Bảng số liệu hai cột.
class DataTableArt extends StatelessWidget {
  const DataTableArt({super.key, required this.title, required this.labels, required this.values, required this.unit});

  final String title;
  final List<String> labels;
  final List<int> values;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final head = TvText.button.copyWith(fontSize: 34, height: 1.1, color: TvdColors.white);
    final cell = TvText.button.copyWith(fontSize: 38, height: 1.1);
    Widget box(String s, TextStyle st, Color bg) => Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: bg, border: Border.all(color: TvdColors.ink, width: 2)),
          alignment: Alignment.center,
          child: Text(s, style: st, textAlign: TextAlign.center, maxLines: 1),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TvText.button.copyWith(fontSize: 34, color: TvdColors.inkSoft)),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [for (final l in labels) box(l, head, TvdColors.answerA)]),
        Row(mainAxisSize: MainAxisSize.min, children: [for (final v in values) box('$v', cell, TvdColors.white)]),
      ],
    );
  }
}

/// Biểu đồ cột có ghi số trên mỗi cột.
class BarChartArt extends StatelessWidget {
  const BarChartArt({super.key, required this.labels, required this.values});

  final List<String> labels;
  final List<int> values;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 160.0 * labels.length + 120, height: 220, child: CustomPaint(painter: _BarPainter(labels, values)));
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.labels, this.values);

  final List<String> labels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 80.0, bottom = 180.0, top = 20.0;
    final maxV = values.reduce(math.max);
    final scaleTop = ((maxV + 9) ~/ 10) * 10;
    double yOf(num v) => bottom - (bottom - top) * v / scaleTop;
    for (var v = 0; v <= scaleTop; v += scaleTop ~/ 4 == 0 ? 1 : scaleTop ~/ 4) {
      canvas.drawLine(Offset(left, yOf(v)), Offset(size.width - 10, yOf(v)), _stroke(1.5, TvdColors.line));
      _label(canvas, '$v', Offset(left - 34, yOf(v)), size: 20, color: TvdColors.inkSoft);
    }
    canvas.drawLine(const Offset(left, top - 6), const Offset(left, bottom), _stroke(3));
    canvas.drawLine(Offset(left, bottom), Offset(size.width - 10, bottom), _stroke(3));
    final colors = [TvdColors.answerA, TvdColors.answerB, TvdColors.answerC, TvdColors.answerD];
    for (var i = 0; i < values.length; i++) {
      final x = left + 40 + i * 160.0;
      final r = Rect.fromLTRB(x, yOf(values[i]), x + 90, bottom);
      canvas.drawRect(r, Paint()..color = colors[i % colors.length]);
      canvas.drawRect(r, _stroke(2.5));
      _label(canvas, '${values[i]}', Offset(r.center.dx, r.top - 16), size: 24);
      _label(canvas, labels[i], Offset(r.center.dx, bottom + 22), size: 24);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.values.join() != values.join() || old.labels.join() != labels.join();
}

/// Biểu đồ hình quạt tròn có ghi phần trăm.
class PieChartArt extends StatelessWidget {
  const PieChartArt({super.key, required this.labels, required this.percents});

  final List<String> labels;
  final List<int> percents;

  static const colors = [TvdColors.answerA, TvdColors.answerB, TvdColors.answerC, TvdColors.answerD];

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 220, height: 220, child: CustomPaint(painter: _PiePainter(percents))),
          const SizedBox(width: 32),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: colors[i % 4], border: Border.all(color: TvdColors.ink, width: 2))),
                    const SizedBox(width: 12),
                    Text('${labels[i]}: ${percents[i]}%', style: TvText.button.copyWith(fontSize: 34, height: 1.1)),
                  ]),
                ),
            ],
          ),
        ],
      );
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.percents);

  final List<int> percents;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 4);
    var start = -math.pi / 2;
    for (var i = 0; i < percents.length; i++) {
      final sweep = 2 * math.pi * percents[i] / 100;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = PieChartArt.colors[i % 4]);
      canvas.drawArc(rect, start, sweep, true, _stroke(3));
      final mid = start + sweep / 2;
      _label(canvas, '${percents[i]}%', rect.center + Offset(math.cos(mid), math.sin(mid)) * rect.width * .3, size: 24,
          bg: TvdColors.white.withAlpha(220));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.percents.join() != percents.join();
}
