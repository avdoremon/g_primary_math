/// Một câu hỏi đã sinh, đủ thông tin cho mini game, giọng đọc và lời giải thích khi sai.
class Question {
  const Question({
    required this.generator,
    required this.prompt,
    required this.speech,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.explanationSpeech,
    this.data = const {},
  });

  /// Mã dạng bài sinh ra câu này (vd. "add_sub").
  final String generator;

  /// Đề hiển thị trên TV, vd. "7 + 5 = ?".
  final String prompt;

  /// Đề đọc thành tiếng, vd. "Bảy cộng năm bằng mấy?".
  final String speech;

  /// Các đáp án hiển thị (2–4). Với mini game không cần đáp án (Nhảy đếm, Đồng hồ người)
  /// danh sách có thể chỉ có một phần tử là đáp án đúng.
  final List<String> options;

  /// Vị trí đáp án đúng trong [options].
  final int answer;

  /// Giải thích đáp án đúng, hiện khi bé chọn chưa đúng, vd. "7 + 5 = 12".
  final String explanation;
  final String explanationSpeech;

  /// Dữ liệu riêng cho mini game (đồ vật để đếm, giờ cần chỉ, số lần cần nhảy…).
  final Map<String, Object?> data;

  String get correctOption => options[answer];

  /// Tên đọc được của đáp án [i]: dạng bài dùng mã hình / mã tờ tiền thì đổi ra tên ("hình vuông", "2 000 đồng").
  String label(int i) {
    final o = options[i];
    final names = data['names'];
    if (names is Map && names[o] is String) return names[o] as String;
    if (data['kind'] == 'banknote' && o.startsWith('vnd_')) {
      final v = int.tryParse(o.substring(4)) ?? 0;
      final s = '$v';
      final b = StringBuffer();
      for (var k = 0; k < s.length; k++) {
        if (k > 0 && (s.length - k) % 3 == 0) b.write(' ');
        b.write(s[k]);
      }
      return '$b đồng';
    }
    return o;
  }

  String get correctLabel => label(answer);

  /// Giá trị số của một đáp án ("1 250", "2,5", "3/4", "25%", "12 cm"); null nếu không phải số.
  static double? valueOf(String option) {
    final m = RegExp('^(\\d+(?:[ \u00a0]\\d{3})*)(?:,(\\d+))?(?:/(\\d+))?').firstMatch(option.trim());
    if (m == null) return null;
    final digits = m.group(1)!.replaceAll(RegExp('[ \u00a0]'), '');
    final whole = double.parse(digits);
    if (m.group(3) != null) return m.group(2) == null ? whole / double.parse(m.group(3)!) : null;
    return m.group(2) == null ? whole : double.parse('$digits.${m.group(2)}');
  }

  /// Bản sao với các đáp án xếp tăng dần theo giá trị (giữ nguyên nếu có đáp án không phải số).
  Question sortedByValue() {
    final values = [for (final o in options) valueOf(o)];
    if (values.any((v) => v == null)) return this;
    final order = List.generate(options.length, (i) => i)..sort((a, b) => values[a]!.compareTo(values[b]!));
    return Question(
      generator: generator,
      prompt: prompt,
      speech: speech,
      options: [for (final i in order) options[i]],
      answer: order.indexOf(answer),
      explanation: explanation,
      explanationSpeech: explanationSpeech,
      data: data,
    );
  }

  @override
  String toString() => '$prompt  [${options.join(' | ')}]  → ${options[answer]}';
}
