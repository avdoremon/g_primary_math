import 'package:sqflite/sqflite.dart';

import '../game/session.dart';
import 'models.dart';
import 'progress_store.dart';

/// Lưu tiến độ bằng SQLite (file `toan_van_dong.db` trong thư mục dữ liệu của app).
///
/// Bảng:
/// - `profiles`: hồ sơ bé
/// - `level_records`: thành tích tốt nhất mỗi level (khoá: hồ sơ, lớp, chủ đề, level)
/// - `sessions`: từng lượt chơi (để tính tổng điểm, thời gian chơi trong ngày)
/// - `answers`: từng câu trả lời (màn phụ huynh), giữ tối đa [maxAnswersPerProfile] dòng mỗi hồ sơ
/// - `settings`: cài đặt khoá–giá trị
class SqliteProgressStore implements ProgressStore {
  SqliteProgressStore._(this._db);

  static const fileName = 'toan_van_dong.db';
  static const schemaVersion = 1;
  static const maxAnswersPerProfile = 5000;

  final Database _db;

  /// Mở (hoặc tạo) cơ sở dữ liệu. Test truyền [factory] (sqflite ffi) và [path] trong bộ nhớ.
  static Future<SqliteProgressStore> open({DatabaseFactory? factory, String? path}) async {
    final options = OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: path != inMemoryDatabasePath,
    );
    final Database db;
    if (factory != null) {
      db = await factory.openDatabase(path ?? fileName, options: options);
    } else {
      final dir = await getDatabasesPath();
      db = await openDatabase(
        path ?? '$dir/$fileName',
        version: options.version,
        onConfigure: options.onConfigure,
        onCreate: options.onCreate,
        onUpgrade: options.onUpgrade,
      );
    }
    return SqliteProgressStore._(db);
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          grade INTEGER NOT NULL,
          avatar INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE level_records (
          profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
          grade INTEGER NOT NULL,
          topic_id TEXT NOT NULL,
          level INTEGER NOT NULL,
          best_stars INTEGER NOT NULL DEFAULT 0,
          best_score INTEGER NOT NULL DEFAULT 0,
          best_correct INTEGER NOT NULL DEFAULT 0,
          plays INTEGER NOT NULL DEFAULT 0,
          last_played_at INTEGER,
          PRIMARY KEY (profile_id, grade, topic_id, level)
        )''')
      ..execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
          grade INTEGER NOT NULL,
          topic_id TEXT NOT NULL,
          level INTEGER NOT NULL,
          started_at INTEGER NOT NULL,
          play_ms INTEGER NOT NULL,
          total INTEGER NOT NULL,
          correct INTEGER NOT NULL,
          score INTEGER NOT NULL,
          stars INTEGER NOT NULL,
          practice INTEGER NOT NULL,
          complete INTEGER NOT NULL
        )''')
      ..execute('CREATE INDEX sessions_profile_time ON sessions(profile_id, started_at)')
      ..execute('''
        CREATE TABLE answers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
          profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
          idx INTEGER NOT NULL,
          generator TEXT NOT NULL,
          prompt TEXT NOT NULL,
          chosen TEXT,
          correct_option TEXT NOT NULL,
          outcome TEXT NOT NULL,
          elapsed_ms INTEGER NOT NULL
        )''')
      ..execute('CREATE INDEX answers_profile ON answers(profile_id, id)')
      ..execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await batch.commit(noResult: true);
  }

  /// Nâng cấp lược đồ khi tăng [schemaVersion]: thêm nhánh `if (from < N)` cho mỗi phiên bản mới.
  static Future<void> _onUpgrade(Database db, int from, int to) async {}

  // ------------------------------------------------------------------ hồ sơ

  static Profile _profile(Map<String, Object?> r) => Profile(
        id: r['id']! as int,
        name: r['name']! as String,
        grade: r['grade']! as int,
        avatar: r['avatar']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
      );

  @override
  Future<List<Profile>> profiles() async {
    final rows = await _db.query('profiles', orderBy: 'id');
    return [for (final r in rows) _profile(r)];
  }

  @override
  Future<Profile> createProfile({required String name, required int grade, int avatar = 0}) async {
    final now = DateTime.now();
    final id = await _db.insert('profiles', {
      'name': name,
      'grade': grade,
      'avatar': avatar,
      'created_at': now.millisecondsSinceEpoch,
    });
    return Profile(id: id, name: name, grade: grade, avatar: avatar, createdAt: now);
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    await _db.update(
      'profiles',
      {'name': profile.name, 'grade': profile.grade, 'avatar': profile.avatar},
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  @override
  Future<void> deleteProfile(int profileId) async {
    // Xoá rõ ràng từng bảng (không chỉ dựa vào ON DELETE CASCADE).
    await _db.transaction((txn) async {
      for (final table in const ['answers', 'sessions', 'level_records']) {
        await txn.delete(table, where: 'profile_id = ?', whereArgs: [profileId]);
      }
      await txn.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
    });
  }

  // ------------------------------------------------------------------ tiến độ

  static LevelRecord _record(Map<String, Object?> r) => LevelRecord(
        topicId: r['topic_id']! as String,
        level: r['level']! as int,
        bestStars: r['best_stars']! as int,
        bestScore: r['best_score']! as int,
        bestCorrect: r['best_correct']! as int,
        plays: r['plays']! as int,
        lastPlayedAt: r['last_played_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_played_at']! as int),
      );

  @override
  Future<Map<LevelKey, LevelRecord>> levelRecords(int profileId, int grade) async {
    final rows = await _db.query(
      'level_records',
      where: 'profile_id = ? AND grade = ?',
      whereArgs: [profileId, grade],
    );
    return {for (final r in rows) _record(r).key: _record(r)};
  }

  @override
  Future<LevelRecord> saveSession(int profileId, SessionResult result) {
    return _db.transaction((txn) async {
      final sessionId = await txn.insert('sessions', {
        'profile_id': profileId,
        'grade': result.grade,
        'topic_id': result.topicId,
        'level': result.level,
        'started_at': result.startedAt.millisecondsSinceEpoch,
        'play_ms': result.playTime.inMilliseconds,
        'total': result.total,
        'correct': result.correct,
        'score': result.score,
        'stars': result.stars,
        'practice': result.practice ? 1 : 0,
        'complete': result.incomplete ? 0 : 1,
      });

      final batch = txn.batch();
      for (final a in result.answers) {
        batch.insert('answers', {
          'session_id': sessionId,
          'profile_id': profileId,
          'idx': a.index,
          'generator': a.question.generator,
          'prompt': a.question.prompt,
          'chosen': a.chosen == null ? null : a.question.label(a.chosen!),
          'correct_option': a.question.correctLabel,
          'outcome': a.outcome.name,
          'elapsed_ms': a.elapsed.inMilliseconds,
        });
      }
      await batch.commit(noResult: true);

      // Chỉ giữ các câu trả lời gần nhất.
      await txn.rawDelete(
        'DELETE FROM answers WHERE profile_id = ? AND id NOT IN '
        '(SELECT id FROM answers WHERE profile_id = ? ORDER BY id DESC LIMIT ?)',
        [profileId, profileId, maxAnswersPerProfile],
      );

      final existing = await txn.query(
        'level_records',
        where: 'profile_id = ? AND grade = ? AND topic_id = ? AND level = ?',
        whereArgs: [profileId, result.grade, result.topicId, result.level],
      );
      final old = existing.isEmpty
          ? LevelRecord(topicId: result.topicId, level: result.level)
          : _record(existing.first);
      final updated = old.merge(result);
      await txn.insert(
        'level_records',
        {
          'profile_id': profileId,
          'grade': result.grade,
          'topic_id': updated.topicId,
          'level': updated.level,
          'best_stars': updated.bestStars,
          'best_score': updated.bestScore,
          'best_correct': updated.bestCorrect,
          'plays': updated.plays,
          'last_played_at': updated.lastPlayedAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return updated;
    });
  }

  @override
  Future<int> totalScore(int profileId, {int? grade}) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(score), 0) AS s FROM sessions WHERE profile_id = ?${grade == null ? '' : ' AND grade = ?'}',
      [profileId, if (grade != null) grade],
    );
    return (rows.first['s'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Duration> playTimeOn(int profileId, DateTime day) async {
    final (start, end) = dayRangeMs(day);
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(play_ms), 0) AS ms FROM sessions WHERE profile_id = ? AND started_at >= ? AND started_at < ?',
      [profileId, start, end],
    );
    return Duration(milliseconds: (rows.first['ms'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<List<AnswerLogEntry>> recentAnswers(int profileId, {int limit = 50}) async {
    final rows = await _db.rawQuery(
      'SELECT a.*, s.started_at, s.grade, s.topic_id, s.level FROM answers a '
      'JOIN sessions s ON s.id = a.session_id WHERE a.profile_id = ? ORDER BY a.id DESC LIMIT ?',
      [profileId, limit],
    );
    return [
      for (final r in rows)
        AnswerLogEntry(
          startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at']! as int),
          grade: r['grade']! as int,
          topicId: r['topic_id']! as String,
          level: r['level']! as int,
          generator: r['generator']! as String,
          prompt: r['prompt']! as String,
          chosen: r['chosen'] as String?,
          correctOption: r['correct_option']! as String,
          outcome: AnswerOutcome.values.byName(r['outcome']! as String),
          elapsed: Duration(milliseconds: r['elapsed_ms']! as int),
        ),
    ];
  }

  // ------------------------------------------------------------------ cài đặt

  @override
  Future<String?> setting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> close() => _db.close();
}
