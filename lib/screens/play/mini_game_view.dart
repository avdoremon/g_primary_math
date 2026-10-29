import 'package:flutter/material.dart';

import '../../content/curriculum.dart';
import '../../content/question.dart';
import '../../game/feedback.dart';
import '../../game/mechanics.dart';
import '../../game/session.dart';
import '../../motion/body_metrics.dart';
import '../../pose/pose_frame.dart';
import '../../ui/theme/theme.dart';
import '../../ui/widgets/tin_tin.dart';
import 'hud.dart';
import 'views/cards_view.dart';
import 'views/simon_says_view.dart';

/// Trạng thái màn chơi ở một khung hình, đưa cho mini game vẽ cảnh.
class PlayFrame {
  const PlayFrame({
    required this.level,
    required this.question,
    this.mechanic,
    this.feedback,
    this.body,
    this.pose,
    this.camera = false,
    this.time = 0,
  });

  final Level level;
  final Question question;
  final AnswerMechanic? mechanic;

  /// Câu vừa trả lời (đang hiện phản hồi); null khi đang hỏi.
  final AnswerRecord? feedback;

  /// Số đo cơ thể đã làm mượt (null khi không thấy bé).
  final BodySnapshot? body;
  final PoseFrame? pose;

  /// Camera đang chạy.
  final bool camera;

  /// Giây kể từ khi vào màn chơi (cho chuyển động nhẹ).
  final double time;

  bool get easy => level.hints == HintLevel.easy;
  bool get answering => feedback == null;
}

/// Khung mini game (G1): mỗi mini game chỉ khai báo bố cục cảnh, vùng chạm và từ khoá;
/// vòng đời câu hỏi, đồng hồ, điểm, chuỗi, phản hồi, tạm dừng do [GameSession] và màn chơi lo.
/// Mọi toạ độ tính theo khung 1920×1080.
abstract class MiniGameView {
  const MiniGameView();

  static MiniGameView of(Level level) => switch (level.miniGame) {
        MiniGames.simonSays => const SimonSaysView(),
        _ => const CardsView(),
      };

  /// Vùng chạm bằng tay (cơ chế C) theo thứ tự đáp án; rỗng nếu câu này không chạm.
  List<Rect> targets(PlayFrame f) => const [];

  /// Vùng chạm màn hình thay cho động tác (máy không có camera, phụ huynh thử).
  List<Rect> tapTargets(PlayFrame f) => targets(f);

  /// Các lớp cảnh, vẽ dưới HUD.
  List<Widget> scene(BuildContext context, PlayFrame f);

  /// Từ khoá tô màu trong đề (chỉ ở mức gợi ý dễ).
  HudKeyword? keyword(PlayFrame f) => null;

  /// Ô camera góc phải dưới (null = không hiện).
  Widget? camTile(PlayFrame f) => Positioned(
        right: TvLayout.safeX,
        bottom: 24,
        child: CamTile(frame: f.pose, seen: f.body != null, width: 150),
      );

  /// Màn giới thiệu riêng (null = dùng màn giới thiệu chung). [time] tính bằng giây, để diễn lần lượt.
  /// Màn chơi tự thêm dòng "Giơ hai tay lên để bắt đầu" và thanh hiệu chỉnh ở đáy.
  List<Widget>? intro(BuildContext context, Level level, double time) => null;
}

/// Băng phản hồi chung: Tin Tin khen/động viên và lời giải thích.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.record});

  final AnswerRecord record;

  @override
  Widget build(BuildContext context) {
    final msg = SessionFeedback.forRecord(record);
    final ok = record.correct;
    final accent = ok ? TvdColors.correct : TvdColors.encourage;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TinTin(state: ok ? TinTinState.praise : TinTinState.encourage, size: 130),
        const SizedBox(width: TvdSpace.s4),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              color: TvdColors.white,
              borderRadius: BorderRadius.circular(TvdRadius.tv),
              border: Border.all(color: accent, width: 5),
              boxShadow: TvdShadow.tv(ok ? TvdColors.correctDark : TvdColors.encourageShadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok && record.points > 0 ? '${msg.title}  +${record.points}' : msg.title,
                  style: TvText.button.copyWith(fontSize: 52, color: ok ? TvdColors.correctDark : TvdColors.encourageDark),
                ),
                if (msg.body.isNotEmpty)
                  Text(
                    msg.body,
                    style: TvText.label.copyWith(fontSize: 40, height: 1.15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Đặt [FeedbackBanner] giữa đáy màn hình.
Widget bottomFeedback(AnswerRecord r) => Positioned(
      left: 260,
      right: 260,
      bottom: 24,
      child: Center(child: FeedbackBanner(record: r)),
    );
