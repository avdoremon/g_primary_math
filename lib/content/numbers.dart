import 'vietnamese_number.dart';

/// Số thập phân chính xác: [units] / 10^[scale] (vd. 2,05 = Dec(205, 2)). Không dùng double để tránh sai số.
class Dec implements Comparable<Dec> {
  const Dec(this.units, [this.scale = 0]);

  factory Dec.fromInt(int v) => Dec(v, 0);

  final int units;
  final int scale;

  static int _pow10(int k) {
    var p = 1;
    for (var i = 0; i < k; i++) {
      p *= 10;
    }
    return p;
  }

  /// Đổi về cùng số chữ số thập phân [s] (s ≥ scale).
  int unitsAt(int s) => units * _pow10(s - scale);

  /// Bỏ các chữ số 0 thừa ở cuối phần thập phân.
  Dec normalized() {
    var u = units, s = scale;
    while (s > 0 && u % 10 == 0) {
      u ~/= 10;
      s--;
    }
    return Dec(u, s);
  }

  Dec operator +(Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return Dec(unitsAt(s) + o.unitsAt(s), s).normalized();
  }

  Dec operator -(Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return Dec(unitsAt(s) - o.unitsAt(s), s).normalized();
  }

  Dec operator *(Dec o) => Dec(units * o.units, scale + o.scale).normalized();

  /// Nhân / chia cho 10^k (k âm = chia).
  Dec shift(int k) => k >= 0 ? Dec(units * _pow10(k), scale).normalized() : Dec(units, scale - k).normalized();

  bool get isInteger => normalized().scale == 0;

  @override
  int compareTo(Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return unitsAt(s).compareTo(o.unitsAt(s));
  }

  @override
  bool operator ==(Object o) => o is Dec && compareTo(o) == 0;

  @override
  int get hashCode => normalized().units.hashCode ^ normalized().scale;

  bool operator <(Dec o) => compareTo(o) < 0;
  bool operator >(Dec o) => compareTo(o) > 0;

  /// Viết như sách giáo khoa: dấu phẩy thập phân, nhóm nghìn bằng dấu cách. 2,05; 1 250,5.
  String get text => normalized().fixedText;

  /// Viết giữ nguyên số chữ số thập phân (3,50 vẫn là "3,50").
  String get fixedText {
    final n = this;
    final u = n.units.abs();
    final p = _pow10(n.scale);
    final intPart = groupThousands(u ~/ p);
    final sign = n.units < 0 ? '-' : '';
    if (n.scale == 0) return '$sign$intPart';
    return '$sign$intPart,${(u % p).toString().padLeft(n.scale, '0')}';
  }

  /// Đọc: 2,05 → "hai phẩy không năm".
  String get speech {
    final n = normalized();
    final u = n.units.abs();
    final p = _pow10(n.scale);
    final head = VietnameseNumber.read(u ~/ p);
    final sign = n.units < 0 ? 'âm ' : '';
    if (n.scale == 0) return '$sign$head';
    return '$sign$head phẩy ${VietnameseNumber.readDecimalPart((u % p).toString().padLeft(n.scale, '0'))}';
  }

  @override
  String toString() => text;
}

/// Phân số [n]/[d] (d > 0).
class Frac implements Comparable<Frac> {
  const Frac(this.n, this.d);

  final int n;
  final int d;

  static int gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }

  static int lcm(int a, int b) => a ~/ gcd(a, b) * b;

  Frac reduced() {
    final g = gcd(n, d);
    return Frac(n ~/ g, d ~/ g);
  }

  bool get isReduced => gcd(n, d) == 1;

  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d).reduced();
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d).reduced();
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d).reduced();
  Frac operator /(Frac o) => Frac(n * o.d, d * o.n).reduced();

  @override
  int compareTo(Frac o) => (n * o.d).compareTo(o.n * d);

  bool operator <(Frac o) => compareTo(o) < 0;
  bool operator >(Frac o) => compareTo(o) > 0;

  @override
  bool operator ==(Object o) => o is Frac && n * o.d == o.n * d;

  @override
  int get hashCode => reduced().n.hashCode ^ reduced().d.hashCode;

  /// Viết "3/4"; số nguyên viết gọn ("2") khi [compact].
  String text({bool compact = false}) {
    if (compact && d == 1) return '$n';
    return '$n/$d';
  }

  /// Đọc "ba phần tư" (mẫu 4 đọc "tư" như sách: "một phần tư").
  String get speech {
    final den = d == 4 ? 'tư' : VietnameseNumber.read(d);
    return '${VietnameseNumber.read(n)} phần $den';
  }

  @override
  String toString() => text();
}

/// Nhóm ba chữ số bằng dấu cách: 1250000 → "1 250 000".
String groupThousands(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return n < 0 ? '-$s' : s;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Đọc một biểu thức toán viết như trên TV thành lời:
/// "1 250 + 3/4 × 2,5 = ?" → "một nghìn hai trăm năm mươi cộng ba phần tư nhân hai phẩy năm bằng mấy".
String speakMath(String expr) {
  // Ngoặc chứa chữ (đơn vị, lời chú thích) thì bỏ ngoặc; ngoặc của phép tính mới đọc "mở ngoặc".
  expr = expr.replaceAllMapped(RegExp(r'\(([^()]*)\)'), (m) {
    final inner = m.group(1)!;
    return RegExp(r'^[\d\s,+−×:/\-]+$').hasMatch(inner) ? '($inner)' : ', $inner,';
  });
  final number = RegExp(r'\d{1,3}(?: \d{3})+(?:,\d+)?|\d+(?:,\d+)?(?:/\d+)?');
  final out = StringBuffer();
  var last = 0;
  for (final m in number.allMatches(expr)) {
    out.write(_speakSymbols(expr.substring(last, m.start)));
    final t = m.group(0)!;
    if (t.contains('/')) {
      final parts = t.split('/');
      out.write(Frac(int.parse(parts[0]), int.parse(parts[1])).speech);
    } else {
      final clean = t.replaceAll(' ', '');
      final comma = clean.indexOf(',');
      if (comma < 0) {
        out.write(VietnameseNumber.read(int.parse(clean)));
      } else {
        final digits = clean.substring(comma + 1);
        out.write(Dec(int.parse(clean.replaceAll(',', '')), digits.length).speech);
      }
    }
    last = m.end;
  }
  out.write(_speakSymbols(expr.substring(last)));
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Tên đọc của đơn vị đo (dài trước ngắn để "cm²" không bị đọc thành "cm").
const unitWords = <String, String>{
  'km/giờ': 'ki-lô-mét trên giờ',
  'm/giây': 'mét trên giây',
  'm/phút': 'mét trên phút',
  'mm²': 'mi-li-mét vuông',
  'cm²': 'xăng-ti-mét vuông',
  'dm²': 'đề-xi-mét vuông',
  'km²': 'ki-lô-mét vuông',
  'm²': 'mét vuông',
  'cm³': 'xăng-ti-mét khối',
  'dm³': 'đề-xi-mét khối',
  'm³': 'mét khối',
  '°C': 'độ C',
  '°': 'độ',
  'mm': 'mi-li-mét',
  'cm': 'xăng-ti-mét',
  'dm': 'đề-xi-mét',
  'km': 'ki-lô-mét',
  'kg': 'ki-lô-gam',
  'ml': 'mi-li-lít',
  'ha': 'héc-ta',
  'm': 'mét',
  'g': 'gam',
  'l': 'lít',
};

final _unitPattern = RegExp(
  '(?<![\\p{L}])(${unitWords.keys.map(RegExp.escape).join('|')})(?![\\p{L}²³])',
  unicode: true,
);

/// Đổi ký hiệu đơn vị thành lời đọc: "24 cm²" → "24 xăng-ti-mét vuông".
String speakUnits(String s) => s.replaceAllMapped(_unitPattern, (m) => ' ${unitWords[m.group(1)]!} ');

final _placeholder = RegExp(r'(^|[\s(=])[?…](?=$|[\s)=])');

String _speakSymbols(String s) => speakUnits(s)
    .replaceAllMapped(_placeholder, (m) => '${m.group(1)} mấy ')
    .replaceAll('×', ' nhân ')
    .replaceAll(' : ', ' chia ')
    .replaceAll('+', ' cộng ')
    .replaceAll('−', ' trừ ')
    .replaceAll(' - ', ' trừ ')
    .replaceAll('=', ' bằng ')
    .replaceAll('(', ' mở ngoặc ')
    .replaceAll(')', ' đóng ngoặc ')
    .replaceAll('%', ' phần trăm ')
    .replaceAll('>', ' lớn hơn ')
    .replaceAll('<', ' bé hơn ');
