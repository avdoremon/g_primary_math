import 'session.dart';

/// Lời phản hồi sau mỗi câu: tiêu đề hiện trên TV, nội dung, và câu đọc thành tiếng.
class FeedbackMessage {
  const FeedbackMessage({required this.title, required this.body, required this.speech});

  final String title;

  /// Rỗng khi trả lời đúng.
  final String body;
  final String speech;
}

abstract class SessionFeedback {
  /// Lời khen xoay vòng để không lặp một câu suốt lượt chơi.
  static const praises = ['Đúng rồi!', 'Giỏi quá!', 'Tuyệt vời!', 'Chính xác!', 'Hay lắm!'];

  static FeedbackMessage forRecord(AnswerRecord r) {
    final q = r.question;
    switch (r.outcome) {
      case AnswerOutcome.correct:
        final praise = praises[r.index % praises.length];
        return FeedbackMessage(title: praise, body: '', speech: praise);
      case AnswerOutcome.wrong:
        return FeedbackMessage(
          title: 'Chưa đúng',
          body: q.explanation,
          speech: 'Chưa đúng rồi. ${q.explanationSpeech}',
        );
      case AnswerOutcome.timeUp:
        return FeedbackMessage(
          title: 'Hết giờ rồi',
          body: q.explanation,
          speech: 'Hết giờ rồi. ${q.explanationSpeech}',
        );
    }
  }

  /// Lời tổng kết cuối level theo số sao.
  static FeedbackMessage forResult(SessionResult r) {
    final line = 'Con đúng ${r.correct} trên ${r.total} câu, được ${r.score} điểm.';
    return switch (r.stars) {
      3 => FeedbackMessage(title: 'Xuất sắc!', body: line, speech: 'Xuất sắc! $line'),
      2 => FeedbackMessage(title: 'Giỏi lắm!', body: line, speech: 'Giỏi lắm! $line'),
      1 => FeedbackMessage(
          title: 'Làm tốt lắm!',
          body: '$line Đã mở level tiếp theo.',
          speech: 'Làm tốt lắm! $line Con đã mở được level tiếp theo.',
        ),
      _ => FeedbackMessage(
          title: 'Cố lên nào!',
          body: '$line Cần đúng 6 câu để mở level tiếp theo.',
          speech: 'Cố lên nào! $line Con chơi lại để đúng sáu câu nhé.',
        ),
    };
  }
}
