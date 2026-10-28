import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/services.dart';
import '../../audio/audio_service.dart';
import '../../content/curriculum.dart';
import '../../dev/hand_cursor_painter.dart';
import '../../dev/pose_screen_mixin.dart';
import '../../dev/skeleton_painter.dart';
import '../../game/feedback.dart';
import '../../game/mechanics.dart';
import '../../game/play_guard.dart';
import '../../game/session.dart';
import '../../motion/hand_tracker.dart';
import '../../motion/motion_engine.dart';
import '../../pose/pose_frame.dart';
import '../../progress/models.dart';
import '../../progress/progress_rules.dart';
import '../../ui/theme/theme.dart';
import '../../ui/widgets/tin_tin.dart';
import '../../ui/widgets/tv_stage.dart';
import 'play_widgets.dart';

enum _Stage { intro, playing, result, rest, limit }

/// Màn chơi TẠM trên TV (F11), dùng chung cho mọi mini game cho tới khi có màn riêng theo design.
///
/// Luồng: giới thiệu (giơ hai tay 1 giây để hiệu chỉnh và bắt đầu) → 10 câu → tổng kết
/// (chơi lại / level sau / về menu, chọn bằng tay hoặc chạm màn hình) → nhắc nghỉ hoặc hết giờ chơi nếu cần.
/// Không có camera (máy dev) thì chạm màn hình để chọn.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.profile, required this.grade, required this.topic, required this.levelIndex});

  final Profile profile;
  final Grade grade;
  final Topic topic;

  /// Vị trí level trong [Topic.levels].
  final int levelIndex;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin, PoseScreenMixin {
  static const _stage = Size(TvLayout.width, TvLayout.height);

  late final AppServices _app;
  late final Ticker _ticker;
  final MotionEngine _engine = MotionEngine();
  final HandTracker _tracker = HandTracker();
  HandState _hands = HandState.none;
  MotionFrame? _motion;

  late int _levelIndex;
  Level get _level => widget.topic.levels[_levelIndex];

  _Stage _phase = _Stage.intro;
  GameSession? _session;
  StreamSubscription<SessionEvent>? _events;
  AnswerMechanic? _mech;
  SessionResult? _result;
  bool _saved = false;
  bool _nextUnlocked = false;
  TouchMechanic _menuTouch = TouchMechanic();
  VoidCallback? _afterRest;
  double _restLeft = 0;
  Duration _lastTick = Duration.zero;

  bool get _camera => startInfo != null && poseError == null;

  @override
  void initState() {
    super.initState();
    _app = AppScope.of(context);
    _levelIndex = widget.levelIndex;
    _ticker = createTicker(_tick)..start();
    startPose();
    unawaited(_app.audio.say('Con đứng vào giữa khung hình, giơ hai tay lên để bắt đầu nhé!'));
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopPose();
    final s = _session;
    if (s != null && !_saved && s.answers.isNotEmpty) unawaited(_save(s.result));
    _events?.cancel();
    s?.dispose();
    unawaited(_app.audio.stop());
    super.dispose();
  }

  // ------------------------------------------------------------------ nhận diện

  @override
  void onPoseFrame(PoseFrame frame) {
    _tracker.screenAspect = TvLayout.width / TvLayout.height;
    _hands = _tracker.update(frame);
    final m = _engine.process(frame);
    _motion = m;
    if (_phase == _Stage.intro && m.justCalibrated != null) _startSession();
  }

  // ------------------------------------------------------------------ vòng lặp

  void _tick(Duration elapsed) {
    final dtSec = math.min(0.1, math.max(0.0, (elapsed - _lastTick).inMicroseconds / 1e6));
    _lastTick = elapsed;
    final dt = Duration(microseconds: (dtSec * 1e6).round());

    switch (_phase) {
      case _Stage.intro:
        break;
      case _Stage.playing:
        final s = _session!;
        final lost = _camera && _engine.tracking == TrackingState.lost;
        if (lost && !s.paused) s.pause();
        if (!lost && s.paused) s.resume();
        s.tick(dt);
        final mech = _mech;
        if (s.phase == SessionPhase.asking && !s.paused && mech != null) {
          final signal = mech.update(MechanicInput(
            dt: dtSec,
            body: _motion?.body,
            calibration: _engine.calibration,
            hands: _hands.both,
            targets: _normalized(_answerRects()),
          ));
          switch (signal) {
            case ChooseOption(:final option):
              s.answer(option);
            case ReportResult(:final correct):
              s.answerResult(correct);
            case null:
              break;
          }
        }
      case _Stage.result:
      case _Stage.limit:
        final hit = _menuTouch.update(MechanicInput(dt: dtSec, hands: _hands.both, targets: _normalized(_menuRects())));
        if (hit is ChooseOption) _menuAction(hit.option);
      case _Stage.rest:
        _restLeft -= dtSec;
        if (_restLeft <= 0) _endRest();
    }
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------ lượt chơi

  void _startSession() {
    _events?.cancel();
    _session?.dispose();
    final s = GameSession(
      grade: widget.grade.grade,
      topicId: widget.topic.id,
      level: _level,
      practice: _app.settings.practiceMode,
    );
    _events = s.events.listen(_onEvent);
    _session = s;
    _result = null;
    _saved = false;
    _phase = _Stage.playing;
    s.start();
  }

  void _onEvent(SessionEvent e) {
    final s = _session!;
    switch (e) {
      case QuestionShown(:final question):
        _mech = AnswerMechanic.forQuestion(_level, question);
        unawaited(_app.audio.say(question.speech));
      case Answered(:final record):
        _app.audio.play(switch (record.outcome) {
          AnswerOutcome.correct => Sfx.correct,
          AnswerOutcome.wrong => Sfx.wrong,
          AnswerOutcome.timeUp => Sfx.timeUp,
        });
        // Giữ màn phản hồi cho tới khi đọc xong lời giải thích.
        s.holdFeedback();
        unawaited(_app.audio.say(SessionFeedback.forRecord(record).speech).whenComplete(s.releaseFeedback));
      case SessionFinished(:final result):
        unawaited(_onFinished(result));
    }
  }

  Future<void> _onFinished(SessionResult r) async {
    _result = r;
    _phase = _Stage.result;
    _menuTouch = TouchMechanic();
    _app.audio.play(r.stars > 0 ? Sfx.star : Sfx.levelDone);
    await _save(r);
    final records = await _app.store.levelRecords(widget.profile.id, widget.grade.grade);
    final next = _levelIndex + 1;
    _nextUnlocked = next < widget.topic.levels.length &&
        ProgressRules.isUnlocked(records, widget.topic.id, widget.topic.levels[next].level);
    if (mounted) setState(() {});
    unawaited(_app.audio.say(SessionFeedback.forResult(r).speech));
  }

  Future<void> _save(SessionResult r) async {
    if (_saved) return;
    _saved = true;
    try {
      await _app.store.saveSession(widget.profile.id, r);
    } on Object catch (e) {
      debugPrint('Lưu tiến độ lỗi: $e');
    }
    _app.playedFor(widget.profile.id, r.playTime);
  }

  // ------------------------------------------------------------------ menu cuối level

  List<(String, VoidCallback)> _menuItems() {
    if (_phase == _Stage.limit) return [('Về menu', _exit)];
    return [
      ('Chơi lại', () => _continueWith(_levelIndex)),
      if (_nextUnlocked) ('Level sau', () => _continueWith(_levelIndex + 1)),
      ('Về menu', _exit),
    ];
  }

  void _menuAction(int i) {
    final items = _menuItems();
    if (i < 0 || i >= items.length) return;
    _app.audio.play(Sfx.tap);
    items[i].$2();
  }

  Future<void> _continueWith(int levelIndex) async {
    final guard = await _app.guardFor(widget.profile.id);
    if (!mounted) return;
    void go() {
      _levelIndex = levelIndex;
      _startSession();
    }

    switch (guard.check()) {
      case GuardVerdict.ok:
        setState(go);
      case GuardVerdict.takeBreak:
        setState(() {
          _phase = _Stage.rest;
          _restLeft = PlayGuard.breakLength.inSeconds.toDouble();
          _afterRest = () {
            guard.breakTaken();
            go();
          };
        });
        unawaited(_app.audio.say('Nghỉ một chút nhé! Con uống nước, nhìn ra xa cho mắt nghỉ ngơi.'));
      case GuardVerdict.dailyLimitReached:
        setState(() {
          _phase = _Stage.limit;
          _menuTouch = TouchMechanic();
        });
        unawaited(_app.audio.say('Hôm nay con chơi đủ rồi. Mai mình chơi tiếp nhé!'));
    }
  }

  void _endRest() {
    final f = _afterRest;
    _afterRest = null;
    if (f != null) f();
  }

  void _exit() => Navigator.of(context).maybePop();

  // ------------------------------------------------------------------ bố cục (pixel khung 1920×1080)

  bool get _withVisual {
    final q = _session?.question;
    return q != null && QuestionVisual.hasVisual(q);
  }

  /// Mini game có ô đáp án để hiển thị.
  bool get _showsCards {
    final q = _session?.question ?? _session?.last?.question;
    if (q == null) return false;
    final k = _mech?.kind;
    return q.options.length > 1 && k != MechanicKind.count && k != MechanicKind.clock && k != MechanicKind.compound;
  }

  List<Rect> _cardRects(int n, {required bool withVisual}) {
    const zone = 1600.0;
    const gap = 64.0;
    final top = withVisual ? 560.0 : 440.0;
    const bottom = 900.0;
    final w = math.min(520.0, (zone - gap * (n - 1)) / n);
    final total = w * n + gap * (n - 1);
    final left = (TvLayout.width - total) / 2;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(left + i * (w + gap), top, w, bottom - top)];
  }

  List<Rect> _answerRects() {
    final q = _session?.question;
    if (q == null || !_showsCards || !(_mech?.usesTouch ?? false)) return const [];
    return _cardRects(q.options.length, withVisual: _withVisual);
  }

  List<Rect> _menuRects() {
    final n = _menuItems().length;
    const w = 440.0, h = 240.0, gap = 64.0;
    final left = (TvLayout.width - (w * n + gap * (n - 1))) / 2;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(left + i * (w + gap), 760, w, h)];
  }

  static List<Rect> _normalized(List<Rect> rects) => [
        for (final r in rects)
          Rect.fromLTRB(r.left / _stage.width, r.top / _stage.height, r.right / _stage.width, r.bottom / _stage.height),
      ];

  // ------------------------------------------------------------------ chạm màn hình

  void _onTap(Offset stagePoint) {
    switch (_phase) {
      case _Stage.intro:
        _startSession();
      case _Stage.playing:
        final s = _session!;
        if (s.phase == SessionPhase.feedback) {
          s.skipFeedback();
          return;
        }
        final q = s.question;
        if (q == null || !_showsCards) return;
        final rects = _cardRects(q.options.length, withVisual: _withVisual);
        for (var i = 0; i < rects.length; i++) {
          if (rects[i].contains(stagePoint)) s.answer(i);
        }
      case _Stage.result:
      case _Stage.limit:
        final rects = _menuRects();
        for (var i = 0; i < rects.length; i++) {
          if (rects[i].contains(stagePoint)) _menuAction(i);
        }
      case _Stage.rest:
        break;
    }
  }

  // ------------------------------------------------------------------ giao diện

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvdColors.sky,
      body: LayoutBuilder(
        builder: (context, c) {
          final viewport = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(TvStage.toStage(d.localPosition, viewport)),
            child: TvStage(
              child: Stack(
                children: [
                  ..._content(),
                  Positioned(
                    right: TvLayout.safeX,
                    bottom: 20,
                    width: 150,
                    height: 150,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: TvdColors.ink.withAlpha(140),
                        borderRadius: BorderRadius.circular(TvdRadius.md),
                      ),
                      child: CustomPaint(painter: SkeletonPainter(lastFrame)),
                    ),
                  ),
                  if (_handsVisible)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: HandCursorPainter(
                            hands: _hands.both,
                            activePoint: _activePoint,
                            progress: _activeProgress,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 24,
                    top: 24,
                    child: IconButton.filledTonal(
                      iconSize: 40,
                      onPressed: _exit,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  if (_session?.paused ?? false) _pauseOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _handsVisible => switch (_phase) {
        _Stage.result || _Stage.limit => true,
        _Stage.playing => (_mech?.usesTouch ?? false) && _session?.phase == SessionPhase.asking,
        _ => false,
      };

  Offset? get _activePoint => _phase == _Stage.playing ? _mech?.activePoint : _menuTouch.activePoint;
  double get _activeProgress => _phase == _Stage.playing ? (_mech?.progress ?? 0) : _menuTouch.progress;

  List<Widget> _content() => switch (_phase) {
        _Stage.intro => [_intro()],
        _Stage.playing => _playing(),
        _Stage.result || _Stage.limit => _resultView(),
        _Stage.rest => [_rest()],
      };

  Widget _centered(Widget child) => Positioned.fill(child: Center(child: child));

  Widget _intro() {
    final progress = _motion?.calibrationProgress ?? 0;
    final seen = _motion?.body != null;
    return _centered(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${widget.topic.title} · Level ${_level.level}', style: TvText.prompt, textAlign: TextAlign.center),
        const SizedBox(height: TvdSpace.s6),
        const TinTin(state: TinTinState.raiseBoth, size: 320),
        const SizedBox(height: TvdSpace.s6),
        Text(
          !_camera
              ? (poseError != null ? 'Chạm màn hình để bắt đầu' : 'Đang mở camera…')
              : (seen ? 'Giơ hai tay lên để bắt đầu!' : 'Con đứng vào giữa khung hình nhé!'),
          style: TvText.question,
        ),
        if (_camera && progress > 0) ...[
          const SizedBox(height: TvdSpace.s5),
          SizedBox(
            width: 600,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 24,
              color: TvdColors.correct,
              backgroundColor: TvdColors.white,
            ),
          ),
        ],
      ],
    ));
  }

  List<Widget> _playing() {
    final s = _session!;
    final q = s.question ?? s.last?.question;
    if (q == null) return const [];
    final feedback = s.phase == SessionPhase.feedback ? s.last : null;
    final mech = _mech;
    final widgets = <Widget>[
      Positioned(
        left: 140,
        right: TvLayout.safeX,
        top: 40,
        child: PlayTopBar(
          index: s.index,
          total: s.total,
          score: s.score,
          streak: s.streak,
          remaining: s.remainingFraction,
        ),
      ),
    ];

    // Đề bài, hoặc bảng phản hồi khi vừa trả lời.
    if (feedback != null) {
      final msg = SessionFeedback.forRecord(feedback);
      widgets.add(Positioned(
        left: TvLayout.safeX,
        right: TvLayout.safeX,
        top: 130,
        height: 300,
        child: Center(
          child: FeedbackPanel(
            correct: feedback.correct,
            title: msg.title,
            body: msg.body,
            points: feedback.points,
          ),
        ),
      ));
    } else {
      widgets.add(Positioned(
        left: TvLayout.safeX,
        right: TvLayout.safeX,
        top: 150,
        child: Text(
          q.prompt,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TvText.question,
        ),
      ));
      if (_withVisual) {
        widgets.add(Positioned(
          left: 200,
          right: 200,
          top: 300,
          height: 240,
          child: Center(child: QuestionVisual(question: q)),
        ));
      }
    }

    if (_showsCards) {
      final rects = _cardRects(q.options.length, withVisual: _withVisual && feedback == null);
      final stepHints = mech?.kind == MechanicKind.step && _level.hints == HintLevel.easy && q.options.length == 2;
      for (var i = 0; i < q.options.length; i++) {
        var mark = CardMark.none;
        if (feedback != null) {
          mark = i == q.answer ? CardMark.correct : (i == feedback.chosen ? CardMark.wrongPick : CardMark.dimmed);
        } else if (mech?.aimed == i) {
          mark = CardMark.aimed;
        }
        widgets.add(Positioned.fromRect(
          rect: rects[i],
          child: AnswerCard(
            slot: i,
            label: q.options[i],
            mark: mark,
            progress: feedback == null && mech?.aimed == i ? mech!.progress : 0,
            caption: stepHints ? (i == 0 ? '◀ TRÁI' : 'PHẢI ▶') : null,
          ),
        ));
      }
    } else if (feedback == null && mech != null) {
      widgets.add(_motionPanel(mech));
    }

    final hint = feedback == null ? mech?.hint ?? _coverageHint(mech) : null;
    if (hint != null) {
      widgets.add(Positioned(
        left: 0,
        right: 0,
        bottom: 190,
        child: Text(hint, textAlign: TextAlign.center, style: TvText.prompt.copyWith(color: TvdColors.encourageDark)),
      ));
    }
    if (!_camera && feedback == null && !_showsCards) widgets.add(_devButtons());
    return widgets;
  }

  String? _coverageHint(AnswerMechanic? mech) {
    final m = _motion;
    if (!_camera || m == null || m.body == null || mech == null || !mech.needsCalibration) return null;
    return m.coverage.feet ? null : 'Con lùi lại một chút để thấy cả chân nhé!';
  }

  /// Mini game không có ô đáp án: hiện tiến độ động tác.
  Widget _motionPanel(AnswerMechanic mech) {
    final Widget body = switch (mech) {
      CountMechanic(:final count, :final target) => Text('$count / $target', style: TvText.bigCounter),
      ClockMechanic(:final reading) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TinTin(state: TinTinState.raiseBoth, size: 220),
            Text(
              reading == null
                  ? 'Tay trái là kim giờ, tay phải là kim phút'
                  : 'Con đang chỉ ${reading.minute == 0 ? '${reading.hour} giờ' : '${reading.hour} giờ ${reading.minute} phút'}',
              style: TvText.prompt,
            ),
          ],
        ),
      _ => TinTin(state: _demoPose(), size: 280),
    };
    return Positioned(
      left: 0,
      right: 0,
      top: 380,
      height: 480,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            body,
            const SizedBox(height: TvdSpace.s5),
            SizedBox(
              width: 700,
              child: LinearProgressIndicator(
                value: mech.progress,
                minHeight: 24,
                color: TvdColors.correct,
                backgroundColor: TvdColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tin Tin làm mẫu (chỉ ở mức gợi ý dễ).
  TinTinState _demoPose() {
    final q = _session?.question;
    if (q == null || _level.hints == HintLevel.hard) return TinTinState.hello;
    final left = q.data['left'] == 'up', right = q.data['right'] == 'up';
    if (left && right) return TinTinState.raiseBoth;
    if (left) return TinTinState.raiseLeft;
    if (right) return TinTinState.raiseRight;
    return TinTinState.hello;
  }

  /// Máy không có camera: nút thay động tác để thử luồng.
  Widget _devButtons() {
    final s = _session!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(onPressed: () => s.answerResult(true), child: const Text('Làm đúng (thử)')),
          const SizedBox(width: 24),
          OutlinedButton(onPressed: () => s.answerResult(false), child: const Text('Chưa đúng (thử)')),
        ],
      ),
    );
  }

  List<Widget> _resultView() {
    final items = _menuItems();
    final rects = _menuRects();
    final r = _result;
    final widgets = <Widget>[];
    if (_phase == _Stage.limit) {
      widgets.add(_centeredTop(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TinTin(state: TinTinState.wait, size: 260),
          Text('Hôm nay con chơi đủ rồi!', style: TvText.question),
          Text('Mai mình chơi tiếp nhé.', style: TvText.prompt),
        ],
      )));
    } else if (r != null) {
      final msg = SessionFeedback.forResult(r);
      final mood = r.stars >= 3 ? TinTinState.happy : (r.stars > 0 ? TinTinState.praise : TinTinState.encourage);
      widgets.add(_centeredTop(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TinTin(state: mood, size: 280),
          const SizedBox(width: TvdSpace.s7),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRow(stars: r.stars, size: 120),
                Text(msg.title, style: TvText.question),
                Text(msg.body, style: TvText.prompt, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      )));
    }
    for (var i = 0; i < items.length; i++) {
      final aimed = _menuTouch.aimed == i;
      widgets.add(Positioned.fromRect(
        rect: rects[i],
        child: AnswerCard(
          slot: i,
          label: items[i].$1,
          mark: aimed ? CardMark.aimed : CardMark.none,
          progress: aimed ? _menuTouch.progress : 0,
        ),
      ));
    }
    return widgets;
  }

  Widget _centeredTop(Widget child) =>
      Positioned(left: TvLayout.safeX, right: TvLayout.safeX, top: 60, height: 680, child: Center(child: child));

  Widget _rest() {
    final left = _restLeft.ceil();
    return _centered(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TinTin(state: TinTinState.wait, size: 320),
        const SizedBox(height: TvdSpace.s5),
        Text('Nghỉ một chút nhé!', style: TvText.question),
        Text('Uống nước, nhìn ra xa cho mắt nghỉ ngơi.', style: TvText.prompt),
        const SizedBox(height: TvdSpace.s5),
        Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: TvText.bigCounter),
      ],
    ));
  }

  Widget _pauseOverlay() => Positioned.fill(
        child: ColoredBox(
          color: TvdColors.ink.withAlpha(215),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TinTin(state: TinTinState.wait, size: 260),
                const SizedBox(height: TvdSpace.s5),
                Text('Con đứng vào khung hình nhé!', style: TvText.question.copyWith(color: TvdColors.white)),
                const SizedBox(height: TvdSpace.s5),
                SizedBox(
                  width: 360,
                  height: 400,
                  child: CustomPaint(painter: SkeletonPainter(lastFrame, showFrame: true)),
                ),
              ],
            ),
          ),
        ),
      );
}
