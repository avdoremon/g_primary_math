import 'dart:math' as math;

/// Luật tính điểm đã chốt (28/10/2026):
/// - Mỗi câu đúng: 100 điểm cơ bản + thưởng tốc độ + thưởng chuỗi đúng liên tiếp.
/// - Câu sai: không trừ điểm; báo "Chưa đúng", giải thích đáp án đúng rồi sang câu sau (không thử lại).
/// - Sao mỗi level: 1 sao khi đúng ≥ 6/10 (mở khoá level sau), 2 sao ≥ 8/10, 3 sao 10/10.
abstract class Scoring {
  static const base = 100;

  /// Tối đa 50 điểm khi trả lời ngay, giảm dần theo thời gian còn lại.
  static const maxSpeedBonus = 50;

  /// 20 điểm cho mỗi câu đúng liên tiếp từ câu thứ hai, tối đa 100.
  static const streakStep = 20;
  static const maxStreakBonus = 100;

  /// Điểm cho một câu đúng.
  /// [remainingFraction]: phần thời gian còn lại (0..1); null khi không đếm giờ (chế độ luyện tập).
  /// [streak]: số câu đúng liên tiếp tính cả câu này (≥ 1).
  static int forCorrect({double? remainingFraction, required int streak}) {
    final int speed =
        remainingFraction == null ? 0 : (maxSpeedBonus * remainingFraction.clamp(0.0, 1.0).toDouble()).round();
    final int chain = math.min<int>(maxStreakBonus, streakStep * math.max<int>(0, streak - 1));
    return base + speed + chain;
  }

  static int starsFor(int correct, int total) {
    if (total <= 0) return 0;
    final ratio = correct / total;
    if (ratio >= 1) return 3;
    if (ratio >= 0.8) return 2;
    if (ratio >= 0.6) return 1;
    return 0;
  }

  /// Level sau được mở khi đạt ít nhất 1 sao.
  static bool unlocksNext(int stars) => stars >= 1;
}
