import 'dart:math' as math;

import '../question.dart';
import '../vietnamese_number.dart';

/// Tham số của một level, đọc từ JSON chương trình.
class GenParams {
  GenParams(this.raw, {this.answers = 3});

  final Map<String, Object?> raw;

  /// Số đáp án cần hiển thị (2–4), lấy từ level.
  final int answers;

  int intOf(String key, int fallback) => (raw[key] as num?)?.toInt() ?? fallback;
  bool boolOf(String key, bool fallback) => raw[key] as bool? ?? fallback;
  String strOf(String key, String fallback) => raw[key] as String? ?? fallback;

  List<String> strList(String key, List<String> fallback) =>
      (raw[key] as List<dynamic>?)?.map((e) => e.toString()).toList(growable: false) ?? fallback;

  List<int> intList(String key, List<int> fallback) =>
      (raw[key] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(growable: false) ?? fallback;
}

/// Một dạng bài. Mỗi lần [generate] cho ra một câu hỏi mới theo tham số,
/// nên số câu hỏi gần như vô hạn và trẻ không học thuộc được đáp án.
abstract class QuestionGenerator {
  const QuestionGenerator();

  String get id;

  /// Kiểm tra tham số khi nạp chương trình; trả về danh sách lỗi (rỗng = hợp lệ).
  List<String> validate(GenParams p) => const [];

  Question generate(GenParams p, math.Random r);
}

// ----------------------------------------------------------------- tiện ích dùng chung

T pick<T>(List<T> items, math.Random r) => items[r.nextInt(items.length)];

/// Số ngẫu nhiên trong [lo, hi] (gồm cả hai đầu).
int between(math.Random r, int lo, int hi) => hi <= lo ? lo : lo + r.nextInt(hi - lo + 1);

/// Viết số như sách giáo khoa: từ 1 000 trở lên tách nhóm ba chữ số bằng dấu cách.
String fmt(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return n < 0 ? '-$s' : s;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Đọc số thành chữ.
String say(int n) => VietnameseNumber.read(n);

/// Viết hoa chữ cái đầu câu.
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Danh sách đáp án số gồm [answer] và các đáp án gây nhiễu hợp lý.
/// [preferred]: các lỗi trẻ hay mắc (lệch 1, lệch 10, nhầm phép tính) được ưu tiên.
({List<String> options, int answer}) numericOptions(
  math.Random r,
  int answer,
  int count, {
  int min = 0,
  required int max,
  Iterable<int> preferred = const [],
  String Function(int)? label,
}) {
  final values = <int>{answer};
  final pref = preferred.where((v) => v >= min && v <= max && v != answer).toList()..shuffle(r);
  for (final v in pref) {
    if (values.length >= count) break;
    values.add(v);
  }
  var spread = 1;
  var guard = 0;
  while (values.length < count && guard++ < 200) {
    final v = answer + (r.nextBool() ? spread : -spread);
    if (v >= min && v <= max) values.add(v);
    if (guard % 2 == 0) spread++;
  }
  final list = values.toList()..shuffle(r);
  final f = label ?? fmt;
  return (options: [for (final v in list) f(v)], answer: list.indexOf(answer));
}

/// Danh sách đáp án chữ gồm [correct] và [count] − 1 đáp án lấy từ [distractors].
({List<String> options, int answer}) textOptions(
  math.Random r,
  String correct,
  List<String> distractors,
  int count,
) {
  final pool = distractors.where((d) => d != correct).toSet().toList()..shuffle(r);
  final list = [correct, ...pool.take(math.max(0, count - 1))]..shuffle(r);
  return (options: list, answer: list.indexOf(correct));
}

/// Số lần nhớ khi cộng [a] + [b] (theo từng hàng).
int carriesInAdd(int a, int b) {
  var carries = 0;
  var c = 0;
  while (a > 0 || b > 0) {
    final s = a % 10 + b % 10 + c;
    c = s >= 10 ? 1 : 0;
    carries += c;
    a ~/= 10;
    b ~/= 10;
  }
  return carries;
}

/// Số lần mượn khi trừ [a] − [b] (a ≥ b).
int borrowsInSub(int a, int b) {
  var borrows = 0;
  var c = 0;
  while (a > 0 || b > 0) {
    final d = a % 10 - c - b % 10;
    c = d < 0 ? 1 : 0;
    borrows += c;
    a ~/= 10;
    b ~/= 10;
  }
  return borrows;
}
