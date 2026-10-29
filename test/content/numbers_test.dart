import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/numbers.dart';

void main() {
  test('số thập phân: viết, đọc, tính chính xác', () {
    expect(const Dec(205, 2).text, '2,05');
    expect(const Dec(205, 2).speech, 'hai phẩy không năm');
    expect(const Dec(12505, 1).text, '1\u00a0250,5');
    expect((const Dec(1, 1) + const Dec(2, 1)).text, '0,3');
    expect((const Dec(25, 1) * const Dec(4, 0)).text, '10');
    expect(const Dec(345, 2).shift(1).text, '34,5');
    expect(const Dec(345, 2).shift(-2).text, '0,0345');
    expect(const Dec(50, 2) == const Dec(5, 1), isTrue);
    expect(const Dec(19, 1) < const Dec(2, 0), isTrue);
  });

  test('phân số: rút gọn, so sánh, phép tính, đọc', () {
    expect(const Frac(6, 8).reduced().text(), '3/4');
    expect((const Frac(1, 2) + const Frac(1, 3)).text(), '5/6');
    expect((const Frac(3, 4) - const Frac(1, 4)).text(), '1/2');
    expect((const Frac(2, 3) * const Frac(3, 5)).text(), '2/5');
    expect((const Frac(1, 2) / const Frac(1, 4)).text(compact: true), '2');
    expect(const Frac(2, 3) > const Frac(3, 5), isTrue);
    expect(const Frac(3, 4).speech, 'ba phần tư');
    expect(const Frac(2, 5).speech, 'hai phần năm');
  });

  test('đọc biểu thức', () {
    expect(speakMath('7 + 5 = ?'), 'bảy cộng năm bằng mấy');
    expect(speakMath('1 250 × 3 = ?'), 'một nghìn hai trăm năm mươi nhân ba bằng mấy');
    expect(speakMath('3/4 + 1/4'), 'ba phần tư cộng một phần tư');
    expect(speakMath('2,5 − 0,75'), 'hai phẩy năm trừ không phẩy bảy mươi lăm');
    expect(speakMath('(12 + 8) : 4'), 'mở ngoặc mười hai cộng tám đóng ngoặc chia bốn');
    expect(speakMath('3 m = ? cm'), 'ba mét bằng mấy xăng-ti-mét');
    expect(speakMath('Diện tích là bao nhiêu?'), 'Diện tích là bao nhiêu?');
    expect(speakMath('24 cm²'), 'hai mươi tư xăng-ti-mét vuông');
    expect(speakMath('Số 3 405 gồm:'), 'Số ba nghìn bốn trăm linh năm gồm:');
    expect(speakMath('25% của 80 kg'), 'hai mươi lăm phần trăm của tám mươi ki-lô-gam');
  });
}
