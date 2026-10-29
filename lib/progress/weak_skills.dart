import 'models.dart';

/// Kết quả gần đây của một dạng bài trong một chủ đề.
class SkillStat {
  SkillStat({required this.grade, required this.topicId, required this.generator});

  final int grade;
  final String topicId;
  final String generator;
  int total = 0;
  int correct = 0;

  int get wrong => total - correct;
  double get accuracy => total == 0 ? 1 : correct / total;

  /// Tên dạng bài cho phụ huynh đọc, vd. "Xem giờ đúng trên đồng hồ".
  String get name => SkillNames.of(generator);
}

/// Tìm các dạng bài bé hay sai từ lịch sử trả lời (mới nhất trước).
abstract class WeakSkills {
  /// Gộp theo (lớp, chủ đề, dạng bài). Chỉ giữ nhóm có ít nhất [minAnswers] câu, có câu sai và
  /// tỉ lệ đúng dưới [below]. Xếp: tỉ lệ đúng thấp trước, rồi nhiều câu sai trước.
  static List<SkillStat> analyze(
    List<AnswerLogEntry> log, {
    int? grade,
    int minAnswers = 4,
    double below = 0.8,
    int limit = 3,
  }) {
    final groups = <String, SkillStat>{};
    for (final e in log) {
      if (grade != null && e.grade != grade) continue;
      final s = groups.putIfAbsent(
        '${e.grade}|${e.topicId}|${e.generator}',
        () => SkillStat(grade: e.grade, topicId: e.topicId, generator: e.generator),
      );
      s.total++;
      if (e.correct) s.correct++;
    }
    final weak = groups.values.where((s) => s.total >= minAnswers && s.wrong > 0 && s.accuracy < below).toList()
      ..sort((a, b) {
        final c = a.accuracy.compareTo(b.accuracy);
        return c != 0 ? c : b.wrong.compareTo(a.wrong);
      });
    return weak.take(limit).toList();
  }
}

/// Tên dạng bài theo cách nói của SGK, dùng ở khu phụ huynh.
abstract class SkillNames {
  static const _names = {
    'count_objects': 'Đếm số đồ vật',
    'split_number': 'Mấy và mấy (tách, gộp số)',
    'place_value': 'Chục và đơn vị',
    'compare': 'So sánh số',
    'order_numbers': 'Sắp xếp số theo thứ tự',
    'neighbors': 'Số liền trước, liền sau',
    'add_sub': 'Cộng, trừ',
    'word_problem': 'Bài toán có lời văn',
    'mul_div': 'Bảng nhân, bảng chia',
    'skip_count': 'Đếm thêm',
    'polyline_length': 'Độ dài đường gấp khúc',
    'position': 'Vị trí: trên dưới, trái phải',
    'shape_identify': 'Nhận biết hình',
    'length_compare': 'So sánh dài, ngắn',
    'unit_choose': 'Chọn đơn vị đo',
    'time': 'Xem giờ đúng trên đồng hồ',
    'money_identify': 'Nhận biết tiền Việt Nam',
    'pictograph': 'Biểu đồ tranh',
    'likelihood': 'Chắc chắn, có thể, không thể',
    'digits': 'Đọc, viết số nhiều chữ số',
    'rounding': 'Làm tròn số',
    'roman': 'Số La Mã',
    'even_odd': 'Số chẵn, số lẻ',
    'find_unknown': 'Tìm thành phần chưa biết',
    'mul_div_big': 'Nhân, chia số lớn',
    'times': 'Gấp lên, giảm đi',
    'expression': 'Tính giá trị biểu thức',
    'story': 'Giải bài toán',
    'fraction': 'Phân số',
    'decimal': 'Số thập phân',
    'percent': 'Tỉ số phần trăm',
    'perimeter_area': 'Chu vi, diện tích',
    'geo': 'Góc, đường thẳng, hình',
    'unit_convert': 'Đổi đơn vị đo',
    'temperature': 'Nhiệt độ',
    'time_calc': 'Tính thời gian',
    'motion': 'Vận tốc, quãng đường',
    'money_sum': 'Tính tiền',
    'data': 'Đọc bảng, biểu đồ',
  };

  static String of(String generator) => _names[generator] ?? generator;
}
