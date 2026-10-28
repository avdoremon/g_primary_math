import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../content/curriculum.dart';
import '../content/question.dart';
import '../content/scoring.dart';

/// Các pha của một lượt chơi (một level, mặc định 10 câu).
enum SessionPhase {
  /// Chưa bắt đầu (màn giới thiệu / hiệu chỉnh).
  ready,

  /// Đang hiện câu hỏi, đồng hồ đang chạy.
  asking,

  /// Đang báo đúng/sai và giải thích đáp án.
  feedback,

  /// Hết câu hỏi.
  finished,
}

enum AnswerOutcome { correct, wrong, timeUp }

/// Một câu đã trả lời.
class AnswerRecord {
  const AnswerRecord({
    required this.index,
    required this.question,
    required this.chosen,
    required this.outcome,
    required this.elapsed,
    required this.points,
    required this.streak,
  });

  /// Thứ tự câu trong lượt chơi (từ 0).
  final int index;
  final Question question;

  /// Vị trí đáp án bé chọn; null khi hết giờ hoặc mini game không có ô đáp án.
  final int? chosen;
  final AnswerOutcome outcome;

  /// Thời gian từ lúc hiện câu hỏi đến lúc trả lời (không tính lúc tạm dừng).
  final Duration elapsed;

  /// Điểm nhận được (0 khi sai).
  final int points;

  /// Chuỗi đúng liên tiếp sau câu này.
  final int streak;

  bool get correct => outcome == AnswerOutcome.correct;
}

/// Kết quả một lượt chơi, dùng để lưu tiến độ và hiện màn tổng kết.
class SessionResult {
  const SessionResult({
    required this.grade,
    required this.topicId,
    required this.level,
    required this.total,
    required this.correct,
    required this.score,
    required this.maxStreak,
    required this.answers,
    required this.startedAt,
    required this.playTime,
    required this.practice,
  });

  final int grade;
  final String topicId;
  final int level;
  final int total;
  final int correct;
  final int score;
  final int maxStreak;
  final List<AnswerRecord> answers;
  final DateTime startedAt;

  /// Thời gian chơi thực (không tính lúc tạm dừng).
  final Duration playTime;

  /// Chế độ luyện tập: không đếm giờ.
  final bool practice;

  /// Lượt chơi bỏ dở giữa chừng (thoát trước khi hết câu).
  bool get incomplete => answers.length < total;

  int get stars => incomplete ? 0 : Scoring.starsFor(correct, total);
  bool get unlocksNext => Scoring.unlocksNext(stars);
}

/// Sự kiện để phát âm thanh / giọng đọc, không cần dò thay đổi trạng thái.
sealed class SessionEvent {
  const SessionEvent();
}

class QuestionShown extends SessionEvent {
  const QuestionShown(this.index, this.question);

  final int index;
  final Question question;
}

class Answered extends SessionEvent {
  const Answered(this.record);

  final AnswerRecord record;
}

class SessionFinished extends SessionEvent {
  const SessionFinished(this.result);

  final SessionResult result;
}

/// Lõi một lượt chơi, dùng chung cho mọi mini game.
///
/// Không phụ thuộc giao diện hay đồng hồ thật: màn chơi gọi [tick] mỗi khung hình với
/// khoảng thời gian đã trôi, gọi [answer] / [answerResult] khi bé chọn. Nhờ vậy test được
/// bằng đồng hồ giả.
///
/// Luật đã chốt:
/// - Câu đúng: điểm theo [Scoring.forCorrect] (100 + tốc độ + chuỗi).
/// - Câu sai hoặc hết giờ: không trừ điểm, chuỗi về 0, hiện "Chưa đúng" và giải thích đáp án đúng,
///   không cho thử lại, sau đó sang câu tiếp.
/// - Mất hình (bé ra khỏi khung) → [pause]; đồng hồ đứng yên cho tới khi [resume].
class GameSession extends ChangeNotifier {
  GameSession({
    required this.grade,
    required this.topicId,
    required this.level,
    this.practice = false,
    math.Random? random,
    DateTime? startedAt,
    this.correctFeedback = const Duration(milliseconds: 1500),
    this.wrongFeedback = const Duration(milliseconds: 4500),
  })  : _random = random ?? math.Random(),
        startedAt = startedAt ?? DateTime.now();

  final int grade;
  final String topicId;
  final Level level;
  final bool practice;
  final DateTime startedAt;

  /// Thời gian tối thiểu hiện phản hồi khi đúng / khi sai (sai lâu hơn để kịp đọc giải thích).
  final Duration correctFeedback;
  final Duration wrongFeedback;

  final math.Random _random;
  final _events = StreamController<SessionEvent>.broadcast(sync: true);

  SessionPhase phase = SessionPhase.ready;

  /// Câu đang hỏi (từ 0).
  int index = 0;
  Question? question;
  int score = 0;
  int streak = 0;
  int maxStreak = 0;
  int correctCount = 0;
  bool paused = false;

  /// Câu vừa trả lời (để hiện phản hồi).
  AnswerRecord? last;
  final List<AnswerRecord> answers = [];

  Duration _elapsed = Duration.zero;
  Duration _playTime = Duration.zero;
  Duration _feedbackLeft = Duration.zero;
  int _holds = 0;
  final Set<String> _seen = {};

  Stream<SessionEvent> get events => _events.stream;

  int get total => level.questions;

  /// null = không giới hạn thời gian (luyện tập hoặc level đặt 0).
  Duration? get timeLimit =>
      practice || level.secondsPerQuestion <= 0 ? null : Duration(seconds: level.secondsPerQuestion);

  Duration get elapsed => _elapsed;
  Duration get playTime => _playTime;

  Duration? get remaining {
    final limit = timeLimit;
    if (limit == null) return null;
    final left = limit - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Phần thời gian còn lại 0..1 (thanh thời gian); null khi không giới hạn.
  double? get remainingFraction {
    final limit = timeLimit;
    if (limit == null) return null;
    return (1 - _elapsed.inMicroseconds / limit.inMicroseconds).clamp(0.0, 1.0).toDouble();
  }

  /// Tiến độ lượt chơi 0..1.
  double get progress => total == 0 ? 1 : answers.length / total;

  void start() {
    if (phase != SessionPhase.ready) return;
    _ask();
    notifyListeners();
  }

  /// Gọi mỗi khung hình. [dt] là thời gian thật đã trôi kể từ lần gọi trước.
  void tick(Duration dt) {
    if (paused || dt <= Duration.zero) return;
    switch (phase) {
      case SessionPhase.asking:
        _playTime += dt;
        _elapsed += dt;
        final limit = timeLimit;
        if (limit != null && _elapsed >= limit) {
          _resolve(null, AnswerOutcome.timeUp);
        }
        notifyListeners();
      case SessionPhase.feedback:
        _playTime += dt;
        _feedbackLeft -= dt;
        if (_feedbackLeft <= Duration.zero && _holds == 0) _next();
        notifyListeners();
      case SessionPhase.ready:
      case SessionPhase.finished:
        break;
    }
  }

  /// Bé chọn ô đáp án [option]. Trả về bản ghi câu trả lời, hoặc null nếu lúc này không nhận đáp án.
  AnswerRecord? answer(int option) {
    final q = question;
    if (phase != SessionPhase.asking || paused || q == null) return null;
    if (option < 0 || option >= q.options.length) return null;
    final r = _resolve(option, option == q.answer ? AnswerOutcome.correct : AnswerOutcome.wrong);
    notifyListeners();
    return r;
  }

  /// Cho mini game không có ô đáp án (Nhảy đếm, Đồng hồ người): báo bé làm đúng hay chưa.
  AnswerRecord? answerResult(bool correct) {
    final q = question;
    if (phase != SessionPhase.asking || paused || q == null) return null;
    final r = _resolve(correct ? q.answer : null, correct ? AnswerOutcome.correct : AnswerOutcome.wrong);
    notifyListeners();
    return r;
  }

  void pause() {
    if (paused) return;
    paused = true;
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    notifyListeners();
  }

  /// Giữ màn phản hồi (vd. khi giọng đọc giải thích chưa xong). Mỗi lần giữ phải [releaseFeedback].
  void holdFeedback() => _holds++;

  void releaseFeedback() {
    if (_holds > 0) _holds--;
  }

  /// Bỏ qua phần phản hồi còn lại (vd. phụ huynh chạm màn hình), chỉ khi không ai đang giữ.
  void skipFeedback() {
    if (phase == SessionPhase.feedback && _holds == 0) {
      _next();
      notifyListeners();
    }
  }

  SessionResult get result => SessionResult(
        grade: grade,
        topicId: topicId,
        level: level.level,
        total: total,
        correct: correctCount,
        score: score,
        maxStreak: maxStreak,
        answers: List.unmodifiable(answers),
        startedAt: startedAt,
        playTime: _playTime,
        practice: practice,
      );

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }

  // ------------------------------------------------------------------ nội bộ

  void _ask() {
    question = _freshQuestion();
    _elapsed = Duration.zero;
    phase = SessionPhase.asking;
    _events.add(QuestionShown(index, question!));
  }

  /// Sinh câu mới, tránh lặp lại câu đã hỏi trong lượt (thử tối đa 8 lần).
  Question _freshQuestion() {
    var q = level.generate(_random);
    for (var i = 0; i < 8 && _seen.contains(_key(q)); i++) {
      q = level.generate(_random);
    }
    _seen.add(_key(q));
    return q;
  }

  static String _key(Question q) => '${q.prompt}|${q.options.join('|')}|${q.data}';

  AnswerRecord _resolve(int? chosen, AnswerOutcome outcome) {
    final ok = outcome == AnswerOutcome.correct;
    var points = 0;
    if (ok) {
      streak++;
      correctCount++;
      if (streak > maxStreak) maxStreak = streak;
      points = Scoring.forCorrect(remainingFraction: remainingFraction, streak: streak);
      score += points;
    } else {
      streak = 0;
    }
    final record = AnswerRecord(
      index: index,
      question: question!,
      chosen: chosen,
      outcome: outcome,
      elapsed: _elapsed,
      points: points,
      streak: streak,
    );
    answers.add(record);
    last = record;
    phase = SessionPhase.feedback;
    _feedbackLeft = ok ? correctFeedback : wrongFeedback;
    _events.add(Answered(record));
    return record;
  }

  void _next() {
    index++;
    if (index >= total) {
      phase = SessionPhase.finished;
      question = null;
      _events.add(SessionFinished(result));
    } else {
      _ask();
    }
  }
}
