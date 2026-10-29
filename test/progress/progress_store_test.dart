import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/play_guard.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/progress/models.dart';
import 'package:g_primary_math/progress/play_settings.dart';
import 'package:g_primary_math/progress/progress_rules.dart';
import 'package:g_primary_math/progress/progress_store.dart';
import 'package:g_primary_math/progress/sqlite_progress_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Level _level(int n) => Level(
      level: n,
      questions: 10,
      secondsPerQuestion: 10,
      generator: 'add_sub',
      params: const {'max': 10},
      answers: 3,
      miniGame: MiniGames.balloon,
    );

/// Chơi một level với số câu đúng cho trước.
SessionResult play({
  required int correct,
  String topic = 'add_10',
  int level = 1,
  int grade = 1,
  DateTime? at,
  int answered = 10,
}) {
  final s = GameSession(
    grade: grade,
    topicId: topic,
    level: _level(level),
    random: math.Random(level * 31 + correct),
    startedAt: at ?? DateTime(2026, 10, 29, 9),
  )..start();
  for (var i = 0; i < answered; i++) {
    s.tick(const Duration(seconds: 2));
    final q = s.question!;
    s.answer(i < correct ? q.answer : (q.answer + 1) % q.options.length);
    s.tick(const Duration(seconds: 5));
  }
  return s.result;
}

void storeTests(String name, Future<ProgressStore> Function() open) {
  group(name, () {
    late ProgressStore store;
    setUp(() async => store = await open());
    tearDown(() async => store.close());

    test('tạo, sửa, xoá hồ sơ; nhiều hồ sơ trên một máy', () async {
      final an = await store.createProfile(name: 'An', grade: 1);
      final binh = await store.createProfile(name: 'Bình', grade: 2, avatar: 3);
      expect((await store.profiles()).map((p) => p.name), ['An', 'Bình']);

      await store.updateProfile(an.copyWith(name: 'An An', grade: 2));
      final list = await store.profiles();
      expect(list.first.name, 'An An');
      expect(list.first.grade, 2);
      expect(list.last.avatar, 3);

      await store.saveSession(binh.id, play(correct: 7, grade: 2));
      await store.deleteProfile(binh.id);
      expect((await store.profiles()).map((p) => p.id), [an.id]);
      expect(await store.levelRecords(binh.id, 2), isEmpty);
      expect(await store.totalScore(binh.id), 0);
    });

    test('giữ thành tích tốt nhất, đếm lượt chơi, tích điểm mọi lượt', () async {
      final p = await store.createProfile(name: 'An', grade: 1);
      final first = play(correct: 8);
      final second = play(correct: 6);
      await store.saveSession(p.id, first);
      final rec = await store.saveSession(p.id, second);

      expect(rec.bestStars, 2);
      expect(rec.bestCorrect, 8);
      expect(rec.bestScore, first.score);
      expect(rec.plays, 2);

      final records = await store.levelRecords(p.id, 1);
      expect(records[(topic: 'add_10', level: 1)]!.bestStars, 2);
      expect(await store.totalScore(p.id), first.score + second.score);
      expect(await store.totalScore(p.id, grade: 2), 0);
    });

    test('lượt bỏ dở vẫn tính thời gian chơi nhưng không đổi thành tích', () async {
      final p = await store.createProfile(name: 'An', grade: 1);
      final quit = play(correct: 3, answered: 3);
      expect(quit.incomplete, isTrue);
      final rec = await store.saveSession(p.id, quit);
      expect(rec.plays, 0);
      expect(rec.bestStars, 0);
      expect(await store.playTimeOn(p.id, DateTime(2026, 10, 29)), quit.playTime);
    });

    test('thời gian chơi tính theo ngày', () async {
      final p = await store.createProfile(name: 'An', grade: 1);
      final today = play(correct: 6, at: DateTime(2026, 10, 29, 20));
      final yesterday = play(correct: 6, at: DateTime(2026, 10, 28, 20));
      await store.saveSession(p.id, today);
      await store.saveSession(p.id, yesterday);
      expect(await store.playTimeOn(p.id, DateTime(2026, 10, 29, 7)), today.playTime);
      expect(await store.playTimeOn(p.id, DateTime(2026, 10, 27)), Duration.zero);
    });

    test('lịch sử trả lời: mới nhất trước, có đáp án bé chọn và đáp án đúng', () async {
      final p = await store.createProfile(name: 'An', grade: 1);
      final r = play(correct: 9);
      await store.saveSession(p.id, r);
      final log = await store.recentAnswers(p.id, limit: 3);
      expect(log.length, 3);
      expect(log.first.prompt, r.answers.last.question.prompt);
      expect(log.first.correct, isFalse);
      expect(log.first.chosen, isNot(log.first.correctOption));
      expect(log[1].correct, isTrue);
      expect(log[1].chosen, log[1].correctOption);
    });

    test('cài đặt phụ huynh lưu và đọc lại được', () async {
      expect((await PlaySettings.load(store)).dailyLimitMinutes, 30);
      await const PlaySettings(dailyLimitMinutes: 45, breakEveryMinutes: 0, voice: false).save(store);
      final s = await PlaySettings.load(store);
      expect(s.dailyLimitMinutes, 45);
      expect(s.breakEveryMinutes, 0);
      expect(s.voice, isFalse);
      expect(s.soundEffects, isTrue);
      await store.setSetting('play.voice', null);
      expect((await PlaySettings.load(store)).voice, isTrue);
    });
  });
}

void main() {
  sqfliteFfiInit();

  storeTests('Lưu trong bộ nhớ', () async => MemoryProgressStore());
  storeTests(
    'Lưu bằng SQLite',
    () => SqliteProgressStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
  );

  group('Mở khoá level', () {
    final topic = Topic(id: 'add_10', title: 'Cộng trong 10', sgkOrder: 1, levels: [for (var i = 1; i <= 5; i++) _level(i)]);

    test('level 1 luôn mở; level sau mở khi level trước có ít nhất 1 sao', () async {
      final store = MemoryProgressStore();
      final p = await store.createProfile(name: 'An', grade: 1);
      var records = await store.levelRecords(p.id, 1);
      expect(ProgressRules.isUnlocked(records, 'add_10', 1), isTrue);
      expect(ProgressRules.isUnlocked(records, 'add_10', 2), isFalse);
      expect(ProgressRules.suggestedLevel(records, topic)!.level, 1);

      await store.saveSession(p.id, play(correct: 5));
      records = await store.levelRecords(p.id, 1);
      expect(ProgressRules.isUnlocked(records, 'add_10', 2), isFalse, reason: '5/10 chưa đủ 1 sao');

      await store.saveSession(p.id, play(correct: 6));
      records = await store.levelRecords(p.id, 1);
      expect(ProgressRules.isUnlocked(records, 'add_10', 2), isTrue);
      expect(ProgressRules.isUnlocked(records, 'add_10', 3), isFalse);
      expect(ProgressRules.suggestedLevel(records, topic)!.level, 2);
      expect(ProgressRules.topicStars(records, topic), 1);
      expect(ProgressRules.maxTopicStars(topic), 15);
    });
  });

  group('Nhắc nghỉ và giới hạn thời gian', () {
    test('nhắc nghỉ sau 15 phút chơi liên tục, nghỉ xong chơi tiếp', () {
      final g = PlayGuard(settings: const PlaySettings(dailyLimitMinutes: 0, breakEveryMinutes: 15));
      g.addPlay(const Duration(minutes: 10));
      expect(g.check(), GuardVerdict.ok);
      g.addPlay(const Duration(minutes: 6));
      expect(g.check(), GuardVerdict.takeBreak);
      g.breakTaken();
      expect(g.check(), GuardVerdict.ok);
    });

    test('rời app vài phút được tính là đã nghỉ', () {
      final g = PlayGuard(settings: const PlaySettings(breakEveryMinutes: 15));
      g.addPlay(const Duration(minutes: 16));
      g.idle(const Duration(minutes: 1));
      expect(g.check(), GuardVerdict.takeBreak);
      g.idle(const Duration(minutes: 3));
      expect(g.check(), GuardVerdict.ok);
    });

    test('hết giới hạn ngày thì dừng, kể cả khi vừa nghỉ', () {
      final g = PlayGuard(
        settings: const PlaySettings(dailyLimitMinutes: 30, breakEveryMinutes: 15),
        playedToday: const Duration(minutes: 25),
      );
      expect(g.remainingToday, const Duration(minutes: 5));
      g.addPlay(const Duration(minutes: 5));
      g.breakTaken();
      expect(g.check(), GuardVerdict.dailyLimitReached);
      g.newDay();
      expect(g.check(), GuardVerdict.ok);
    });

    test('0 phút = không giới hạn, không nhắc', () {
      final g = PlayGuard(settings: const PlaySettings(dailyLimitMinutes: 0, breakEveryMinutes: 0));
      g.addPlay(const Duration(hours: 3));
      expect(g.check(), GuardVerdict.ok);
      expect(g.remainingToday, isNull);
    });
  });

  test('LevelRecord.merge giữ giá trị lớn nhất', () {
    const old = LevelRecord(topicId: 't', level: 1, bestStars: 3, bestScore: 2000, bestCorrect: 10, plays: 4);
    final m = old.merge(play(correct: 6, topic: 't'));
    expect(m.bestStars, 3);
    expect(m.bestScore, 2000);
    expect(m.plays, 5);
  });
}
