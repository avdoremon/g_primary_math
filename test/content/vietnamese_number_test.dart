import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/vietnamese_number.dart';

void main() {
  test('đọc số theo cách đọc của sách giáo khoa', () {
    const cases = {
      0: 'không',
      5: 'năm',
      10: 'mười',
      11: 'mười một',
      14: 'mười bốn',
      15: 'mười lăm',
      20: 'hai mươi',
      21: 'hai mươi mốt',
      24: 'hai mươi tư',
      25: 'hai mươi lăm',
      55: 'năm mươi lăm',
      100: 'một trăm',
      105: 'một trăm linh năm',
      110: 'một trăm mười',
      115: 'một trăm mười lăm',
      999: 'chín trăm chín mươi chín',
      1000: 'một nghìn',
      1005: 'một nghìn không trăm linh năm',
      20000: 'hai mươi nghìn',
      50000: 'năm mươi nghìn',
    };
    cases.forEach((n, text) => expect(VietnameseNumber.read(n), text, reason: '$n'));
  });
}
