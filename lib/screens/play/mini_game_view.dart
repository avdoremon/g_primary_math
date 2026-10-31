import 'package:flutter/material.dart';

import '../../content/curriculum.dart';
import '../../content/question.dart';
import '../../game/mechanics.dart';
import '../../game/session.dart';
import '../../motion/body_metrics.dart';
import '../../pose/pose_frame.dart';
import '../../ui/theme/theme.dart';
import 'hud.dart';
import 'views/cards_view.dart';
import 'views/line_angle_views.dart';
import 'views/motion_views.dart';
import 'views/new_game_views.dart';
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
        MiniGames.balloon => const BalloonView(),
        MiniGames.sides => const SidesView(),
        MiniGames.jumpCount => const JumpCountView(),
        MiniGames.humanClock => const HumanClockView(),
        MiniGames.shapeHunt => const CardsView(bob: true),
        MiniGames.simonSays => const SimonSaysView(),
        MiniGames.armAngle => const ArmAngleView(),
        MiniGames.numberLine => const NumberLineView(),
        MiniGames.hopTiles => const NumberLineView(variant: LaneVariant.hop),
        MiniGames.starCatch => const NumberLineView(variant: LaneVariant.star),
        MiniGames.touchOrder => const OrderTouchView(),
        MiniGames.tintinSays => const CardsView(captions: ['TAY TRÁI', 'TAY PHẢI', 'HAI TAY']),
        MiniGames.balance => const BalanceView(),
        MiniGames.runRace => const RunRaceView(),
        MiniGames.clapCount => const JumpCountView(clap: true),
        MiniGames.squatGate => const GateView(),
        MiniGames.poseAnswer => const PoseAnswerView(),
        MiniGames.squatCount => const JumpCountView(squat: true),
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

  /// Ô camera góc phải dưới (null = không hiện). Chỉ hiện khi camera đang chạy (chơi bằng chạm thì ẩn).
  Widget? camTile(PlayFrame f) => !f.camera ? null : Positioned(
        right: TvLayout.safeX,
        bottom: 24,
        child: CamTile(frame: f.pose, seen: f.body != null, width: 150),
      );

  /// Thẻ đề ở HUD hiện lời phản hồi sau mỗi câu (false: mini game tự vẽ phản hồi trong cảnh).
  bool get hudFeedback => true;

  /// Màn giới thiệu riêng (null = dùng màn giới thiệu chung). [time] tính bằng giây, để diễn lần lượt.
  /// Màn chơi tự thêm dòng "Giơ hai tay lên để bắt đầu" và thanh hiệu chỉnh ở đáy.
  List<Widget>? intro(BuildContext context, Level level, double time) => null;
}
