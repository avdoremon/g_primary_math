import '../progress/play_settings.dart';

enum GuardVerdict {
  /// Chơi tiếp được.
  ok,

  /// Đã chơi liên tục đủ lâu: hiện màn nghỉ (vận động mắt, uống nước) trước level sau.
  takeBreak,

  /// Đã hết thời gian chơi trong ngày.
  dailyLimitReached,
}

/// Quy tắc thời gian chơi. Chỉ kiểm tra GIỮA hai level, không bao giờ cắt ngang một level.
///
/// - Nhắc nghỉ sau [PlaySettings.breakEveryMinutes] phút chơi liên tục.
/// - Rời app hoặc nghỉ ít nhất [restCounts] thì coi như đã nghỉ.
/// - Hết [PlaySettings.dailyLimitMinutes] phút trong ngày thì không cho bắt đầu level mới.
class PlayGuard {
  PlayGuard({required this.settings, Duration playedToday = Duration.zero}) : _today = playedToday;

  PlaySettings settings;

  /// Nghỉ (không chơi) ít nhất ngần này thì tính lại từ đầu thời gian chơi liên tục.
  static const restCounts = Duration(minutes: 3);

  /// Màn nghỉ kéo dài ít nhất ngần này.
  static const breakLength = Duration(minutes: 2);

  Duration _today;
  Duration _sinceBreak = Duration.zero;

  Duration get playedToday => _today;
  Duration get sinceBreak => _sinceBreak;

  Duration? get dailyLimit =>
      settings.dailyLimitMinutes <= 0 ? null : Duration(minutes: settings.dailyLimitMinutes);

  Duration? get breakEvery =>
      settings.breakEveryMinutes <= 0 ? null : Duration(minutes: settings.breakEveryMinutes);

  /// Thời gian còn lại trong ngày; null = không giới hạn.
  Duration? get remainingToday {
    final limit = dailyLimit;
    if (limit == null) return null;
    final left = limit - _today;
    return left.isNegative ? Duration.zero : left;
  }

  GuardVerdict check() {
    final limit = dailyLimit;
    if (limit != null && _today >= limit) return GuardVerdict.dailyLimitReached;
    final every = breakEvery;
    if (every != null && _sinceBreak >= every) return GuardVerdict.takeBreak;
    return GuardVerdict.ok;
  }

  /// Cộng thời gian của một lượt chơi vừa xong.
  void addPlay(Duration d) {
    _today += d;
    _sinceBreak += d;
  }

  /// Bé không chơi trong [d] (ở menu, rời app...).
  void idle(Duration d) {
    if (d >= restCounts) _sinceBreak = Duration.zero;
  }

  /// Đã xong màn nghỉ.
  void breakTaken() => _sinceBreak = Duration.zero;

  /// Sang ngày mới.
  void newDay() {
    _today = Duration.zero;
    _sinceBreak = Duration.zero;
  }
}
