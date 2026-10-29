import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/feedback.dart';
import 'package:g_primary_math/game/session.dart';

Level testLevel({int seconds = 10, int questions = 10, String miniGame = MiniGames.balloon}) => Level(
      level: 2,
      questions: questions,
      secondsPerQuestion: seconds,
      generator: 'add_sub',
      params: const {'max': 10, 'ops': ['+']},
      answers: 3,
      miniGame: miniGame,
    );

GameSession newSession({int seconds = 10, bool practice = false, int questions = 10}) => GameSession(
      grade: 1,
      topicId: 'add_sub_10',
      level: testLevel(seconds: seconds, questions: questions),
      practice: practice,
      random: math.Random(1),
      startedAt: DateTime(2026, 10, 29, 8),
    );

const frame = Duration(milliseconds: 100);

/// Chạy đồng hồ giả [d] theo từng khung 100 ms.
void run(GameSession s, Duration d) {
  for (var t = Duration.zero; t < d; t += frame) {
    s.tick(frame);
  }
}

int wrongOption(GameSession s) => (s.question!.answer + 1) % s.question!.options.length;

void main() {
  test('trả lời đúng ngay: 100 + thưởng tốc độ gần tối đa, chuỗi tăng dần', () {
    final s = newSession()..start();
    expect(s.phase, SessionPhase.asking);

    run(s, const Duration(seconds: 1)); // còn 9/10 thời gian
    final r1 = s.answer(s.question!.answer)!;
    expect(r1.correct, isTrue);
    expect(r1.points, 100 + 45);
    expect(s.phase, SessionPhase.feedback);

    run(s, const Duration(milliseconds: 1500));
    expect(s.phase, SessionPhase.asking);
    expect(s.index, 1);
    expect(s.elapsed, Duration.zero);

    run(s, const Duration(seconds: 5)); // còn 5/10
    final r2 = s.answer(s.question!.answer)!;
    expect(r2.points, 100 + 25 + 20);
    expect(s.score, r1.points + r2.points);
    expect(s.streak, 2);
  });

  test('sai: không trừ điểm, chuỗi về 0, không cho chọn lại, hiện giải thích', () {
    final s = newSession()..start();
    s.answer(s.question!.answer);
    run(s, const Duration(seconds: 2));
    final before = s.score;

    final r = s.answer(wrongOption(s))!;
    expect(r.outcome, AnswerOutcome.wrong);
    expect(r.points, 0);
    expect(s.score, before);
    expect(s.streak, 0);
    expect(s.answer(s.question!.answer), isNull, reason: 'không cho thử lại câu đã sai');

    final msg = SessionFeedback.forRecord(r);
    expect(msg.title, 'Chưa đúng');
    expect(msg.body, r.question.explanation);
    expect(msg.speech, contains(r.question.explanationSpeech));

    // Phản hồi sai hiện lâu hơn phản hồi đúng.
    run(s, const Duration(seconds: 2));
    expect(s.phase, SessionPhase.feedback);
    run(s, const Duration(seconds: 3));
    expect(s.phase, SessionPhase.asking);
  });

  test('hết giờ tính là chưa đúng', () {
    final s = newSession(seconds: 6)..start();
    run(s, const Duration(milliseconds: 6100));
    expect(s.last!.outcome, AnswerOutcome.timeUp);
    expect(s.last!.chosen, isNull);
    expect(SessionFeedback.forRecord(s.last!).title, 'Hết giờ rồi');
  });

  test('tạm dừng khi mất hình: đồng hồ đứng yên, không nhận đáp án', () {
    final s = newSession(seconds: 6)..start();
    run(s, const Duration(seconds: 2));
    s.pause();
    run(s, const Duration(seconds: 30));
    expect(s.phase, SessionPhase.asking);
    expect(s.elapsed, const Duration(seconds: 2));
    expect(s.answer(s.question!.answer), isNull);
    s.resume();
    expect(s.answer(s.question!.answer)!.points, 100 + 33 /* round(50 × 4/6) */);
    expect(s.playTime, const Duration(seconds: 2));
  });

  test('luyện tập: không đếm giờ, không có thưởng tốc độ', () {
    final s = newSession(practice: true)..start();
    run(s, const Duration(minutes: 2));
    expect(s.phase, SessionPhase.asking);
    expect(s.remainingFraction, isNull);
    expect(s.answer(s.question!.answer)!.points, 100);
  });

  test('giữ phản hồi khi giọng đọc chưa xong', () {
    final s = newSession()..start();
    s.answer(wrongOption(s));
    s.holdFeedback();
    run(s, const Duration(seconds: 10));
    expect(s.phase, SessionPhase.feedback);
    s.releaseFeedback();
    run(s, frame);
    expect(s.phase, SessionPhase.asking);
  });

  test('chơi hết 10 câu: đúng 8 được 2 sao và mở level sau; sự kiện đủ', () {
    final s = newSession();
    final events = <SessionEvent>[];
    s.events.listen(events.add);
    s.start();
    for (var i = 0; i < 10; i++) {
      s.answer(i < 8 ? s.question!.answer : wrongOption(s));
      run(s, const Duration(seconds: 5));
    }
    expect(s.phase, SessionPhase.finished);
    final r = s.result;
    expect(r.correct, 8);
    expect(r.stars, 2);
    expect(r.unlocksNext, isTrue);
    expect(r.incomplete, isFalse);
    expect(r.maxStreak, 8);
    expect(r.answers.length, 10);
    expect(events.whereType<QuestionShown>().length, 10);
    expect(events.whereType<Answered>().length, 10);
    expect(events.last, isA<SessionFinished>());
    expect(SessionFeedback.forResult(r).title, 'Giỏi lắm!');
  });

  test('đúng 5/10 thì 0 sao, chưa mở level sau', () {
    final s = newSession()..start();
    for (var i = 0; i < 10; i++) {
      s.answer(i.isEven ? s.question!.answer : wrongOption(s));
      run(s, const Duration(seconds: 5));
    }
    expect(s.result.stars, 0);
    expect(s.result.unlocksNext, isFalse);
    expect(SessionFeedback.forResult(s.result).body, contains('6 câu'));
  });

  test('bỏ dở giữa chừng: 0 sao', () {
    final s = newSession()..start();
    s.answer(s.question!.answer);
    expect(s.result.incomplete, isTrue);
    expect(s.result.stars, 0);
  });

  test('không lặp câu hỏi trong một lượt khi còn câu khác', () {
    final s = newSession(questions: 10)..start();
    final prompts = <String>{};
    for (var i = 0; i < 10; i++) {
      prompts.add('${s.question!.prompt}|${s.question!.options}');
      s.answer(s.question!.answer);
      run(s, const Duration(seconds: 2));
    }
    expect(prompts.length, 10);
  });

  test('mini game không có ô đáp án báo kết quả trực tiếp', () {
    final s = newSession()..start();
    expect(s.answerResult(true)!.correct, isTrue);
    run(s, const Duration(seconds: 2));
    expect(s.answerResult(false)!.outcome, AnswerOutcome.wrong);
  });
}
