/// Đọc số bằng tiếng Việt (0 – 999 tỉ), dùng cho giọng đọc đề bài và lời giải thích.
///
/// Theo cách đọc trong sách giáo khoa tiểu học:
/// 15 → "mười lăm", 21 → "hai mươi mốt", 24 → "hai mươi tư", 25 → "hai mươi lăm",
/// 105 → "một trăm linh năm", 1005 → "một nghìn không trăm linh năm",
/// 2 005 000 → "hai triệu không trăm linh năm nghìn" (lớp bằng 0 thì bỏ qua).
abstract class VietnameseNumber {
  static const _digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
  static const _groups = ['', ' nghìn', ' triệu', ' tỉ'];

  static String read(int n) {
    if (n < 0) return 'âm ${read(-n)}';
    if (n < 1000) return _hundreds(n, full: false);
    if (n >= 1000000000000) throw ArgumentError.value(n, 'n', 'chỉ hỗ trợ số nhỏ hơn 1 000 tỉ');
    final parts = <String>[];
    final groups = <int>[];
    var x = n;
    while (x > 0) {
      groups.add(x % 1000);
      x ~/= 1000;
    }
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g == 0) continue;
      parts.add('${_hundreds(g, full: parts.isNotEmpty)}${_groups[i]}');
    }
    return parts.join(' ');
  }

  /// Đọc chữ số thập phân sau dấu phẩy: các chữ số 0 đứng đầu đọc là "không", phần còn lại đọc như số.
  /// "05" → "không năm", "45" → "bốn mươi lăm", "5" → "năm".
  static String readDecimalPart(String digits) {
    final words = <String>[];
    var i = 0;
    while (i < digits.length - 1 && digits[i] == '0') {
      words.add('không');
      i++;
    }
    words.add(read(int.parse(digits.substring(i))));
    return words.join(' ');
  }

  /// Đọc 0..999. [full] = true khi đứng sau hàng nghìn (đọc cả "không trăm").
  static String _hundreds(int n, {required bool full}) {
    final h = n ~/ 100;
    final t = (n % 100) ~/ 10;
    final u = n % 10;
    final parts = <String>[];
    if (h > 0 || full) {
      parts.add('${_digits[h]} trăm');
      if (t == 0 && u > 0) parts.add('linh');
    }
    if (t == 0) {
      if (u > 0 || parts.isEmpty) parts.add(_digits[u]);
      return parts.join(' ');
    }
    if (t == 1) {
      parts.add('mười');
    } else {
      parts.add('${_digits[t]} mươi');
    }
    if (u == 0) return parts.join(' ');
    if (u == 1) {
      parts.add(t == 1 ? 'một' : 'mốt');
    } else if (u == 4) {
      parts.add(t == 1 ? 'bốn' : 'tư');
    } else if (u == 5) {
      parts.add('lăm');
    } else {
      parts.add(_digits[u]);
    }
    return parts.join(' ');
  }
}
