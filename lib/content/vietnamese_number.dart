/// Đọc số bằng tiếng Việt (0 – 999 999), dùng cho giọng đọc đề bài và lời giải thích.
///
/// Theo cách đọc trong sách giáo khoa tiểu học:
/// 15 → "mười lăm", 21 → "hai mươi mốt", 24 → "hai mươi tư", 25 → "hai mươi lăm",
/// 105 → "một trăm linh năm", 1005 → "một nghìn không trăm linh năm".
abstract class VietnameseNumber {
  static const _digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

  static String read(int n) {
    if (n < 0) return 'âm ${read(-n)}';
    if (n < 1000) return _hundreds(n, full: false);
    if (n < 1000000) {
      final thousands = n ~/ 1000;
      final rest = n % 1000;
      final head = '${_hundreds(thousands, full: false)} nghìn';
      if (rest == 0) return head;
      return '$head ${_hundreds(rest, full: true)}';
    }
    throw ArgumentError.value(n, 'n', 'chỉ hỗ trợ số nhỏ hơn 1 000 000');
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
