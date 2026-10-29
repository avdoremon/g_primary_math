import '../game/session.dart';
import 'models.dart';

/// Nơi lưu tiến độ trên máy: hồ sơ bé, thành tích từng level, lịch sử trả lời, cài đặt.
///
/// Bản chạy thật là [SqliteProgressStore]; [MemoryProgressStore] dùng cho test và màn phát triển.
abstract class ProgressStore {
  Future<List<Profile>> profiles();
  Future<Profile> createProfile({required String name, required int grade, int avatar = 0});
  Future<void> updateProfile(Profile profile);

  /// Xoá hồ sơ cùng toàn bộ tiến độ của hồ sơ đó.
  Future<void> deleteProfile(int profileId);

  /// Thành tích các level của một lớp.
  Future<Map<LevelKey, LevelRecord>> levelRecords(int profileId, int grade);

  /// Lưu một lượt chơi (kể cả lượt bỏ dở, để tính thời gian chơi). Trả về thành tích mới của level.
  Future<LevelRecord> saveSession(int profileId, SessionResult result);

  /// Tổng điểm tích luỹ (mọi lượt chơi), có thể lọc theo lớp.
  Future<int> totalScore(int profileId, {int? grade});

  /// Thời gian chơi trong ngày (theo giờ máy) của [day].
  Future<Duration> playTimeOn(int profileId, DateTime day);

  /// Các câu trả lời gần nhất, mới nhất trước.
  Future<List<AnswerLogEntry>> recentAnswers(int profileId, {int limit = 50});

  /// Cài đặt chung dạng khoá–giá trị. [value] null = xoá.
  Future<String?> setting(String key);
  Future<void> setSetting(String key, String? value);

  Future<void> close();
}

/// Đầu và cuối ngày theo giờ máy, dạng mili giây.
(int, int) dayRangeMs(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
}

class _SessionRow {
  _SessionRow(this.profileId, this.result);

  final int profileId;
  final SessionResult result;
}

/// Lưu trong bộ nhớ, mất khi tắt app.
class MemoryProgressStore implements ProgressStore {
  final List<Profile> _profiles = [];
  final Map<(int, int), Map<LevelKey, LevelRecord>> _records = {};
  final List<_SessionRow> _sessions = [];
  final Map<String, String> _settings = {};
  int _nextId = 1;

  @override
  Future<List<Profile>> profiles() async => List.unmodifiable(_profiles);

  @override
  Future<Profile> createProfile({required String name, required int grade, int avatar = 0}) async {
    final p = Profile(id: _nextId++, name: name, grade: grade, avatar: avatar, createdAt: DateTime.now());
    _profiles.add(p);
    return p;
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    final i = _profiles.indexWhere((p) => p.id == profile.id);
    if (i >= 0) _profiles[i] = profile;
  }

  @override
  Future<void> deleteProfile(int profileId) async {
    _profiles.removeWhere((p) => p.id == profileId);
    _records.removeWhere((k, _) => k.$1 == profileId);
    _sessions.removeWhere((s) => s.profileId == profileId);
  }

  @override
  Future<Map<LevelKey, LevelRecord>> levelRecords(int profileId, int grade) async =>
      Map.unmodifiable(_records[(profileId, grade)] ?? const {});

  @override
  Future<LevelRecord> saveSession(int profileId, SessionResult result) async {
    _sessions.add(_SessionRow(profileId, result));
    final map = _records.putIfAbsent((profileId, result.grade), () => {});
    final key = (topic: result.topicId, level: result.level);
    final updated = (map[key] ?? LevelRecord(topicId: result.topicId, level: result.level)).merge(result);
    map[key] = updated;
    return updated;
  }

  @override
  Future<int> totalScore(int profileId, {int? grade}) async => _sessions
      .where((s) => s.profileId == profileId && (grade == null || s.result.grade == grade))
      .fold<int>(0, (sum, s) => sum + s.result.score);

  @override
  Future<Duration> playTimeOn(int profileId, DateTime day) async {
    final (start, end) = dayRangeMs(day);
    return _sessions
        .where((s) =>
            s.profileId == profileId &&
            s.result.startedAt.millisecondsSinceEpoch >= start &&
            s.result.startedAt.millisecondsSinceEpoch < end)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.result.playTime);
  }

  @override
  Future<List<AnswerLogEntry>> recentAnswers(int profileId, {int limit = 50}) async {
    final out = <AnswerLogEntry>[];
    for (final s in _sessions.reversed) {
      if (s.profileId != profileId) continue;
      for (final a in s.result.answers.reversed) {
        out.add(AnswerLogEntry.of(s.result, a));
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  @override
  Future<String?> setting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
  }

  @override
  Future<void> close() async {}
}
