import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/motion/dwell_selector.dart';
import 'package:g_primary_math/motion/one_euro.dart';

void main() {
  group('DwellSelector', () {
    final targets = [
      const Rect.fromLTWH(0.1, 0.4, 0.2, 0.3),
      const Rect.fromLTWH(0.6, 0.4, 0.2, 0.3),
    ];

    test('chọn khi giữ tay đủ lâu', () {
      final s = DwellSelector(dwellSeconds: 0.4);
      int? picked;
      for (var i = 0; i < 30 && picked == null; i++) {
        picked = s.update([const Offset(0.2, 0.5), null], targets, 1 / 30);
      }
      expect(picked, 0);
    });

    test('không chọn khi tay chỉ lướt qua', () {
      final s = DwellSelector(dwellSeconds: 0.4);
      int? picked;
      for (var i = 0; i < 5; i++) {
        picked ??= s.update([const Offset(0.7, 0.5)], targets, 1 / 30);
      }
      for (var i = 0; i < 20; i++) {
        picked ??= s.update([const Offset(0.45, 0.1)], targets, 1 / 30);
      }
      expect(picked, isNull);
    });

    test('không chọn đúp khi tay vẫn để yên trên đáp án', () {
      final s = DwellSelector(dwellSeconds: 0.4);
      var count = 0;
      for (var i = 0; i < 90; i++) {
        if (s.update([const Offset(0.2, 0.5)], targets, 1 / 30) != null) count++;
      }
      expect(count, 1);
    });
  });

  group('OneEuroFilter', () {
    test('làm mượt nhiễu khi đứng yên', () {
      final f = OneEuroFilter(minCutoff: 1.2, beta: 0.8);
      var t = Duration.zero;
      double out = 0;
      for (var i = 0; i < 60; i++) {
        t += const Duration(milliseconds: 33);
        out = f.filter(i.isEven ? 0.52 : 0.48, t);
      }
      expect((out - 0.5).abs(), lessThan(0.02));
    });
  });
}
