import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/services.dart';
import '../../audio/audio_service.dart';
import '../../content/curriculum.dart';
import '../../content/vietnamese_number.dart';
import '../../dev/pose_screen_mixin.dart';
import '../../dev/skeleton_painter.dart';
import '../../game/feedback.dart';
import '../../game/mechanics.dart';
import '../../game/play_guard.dart';
import '../../game/session.dart';
import '../../motion/hand_tracker.dart';
import '../../motion/motion_engine.dart';
import '../../pose/pose_frame.dart';
import '../../pose/pose_service.dart';
import '../../progress/models.dart';
import '../../progress/progress_rules.dart';
import '../../ui/theme/theme.dart';
import '../../ui/widgets/tin_tin.dart';
import '../../ui/widgets/tv_stage.dart';
import 'hud.dart';
import 'mini_game_view.dart';
import 'play_widgets.dart';

enum _Stage { intro, playing, result, rest, limit }

/// Màn chơi trên TV, dùng chung cho mọi mini game (G1): HUD, vòng câu hỏi, cơ chế trả lời, tạm dừng,
/// tổng kết. Cảnh và vùng chạm của từng mini game do [MiniGameView] khai báo.
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
  MiniGameView get _view => MiniGameView.of(_level);
  double _time = 0;
  int _spokenCount = 0;

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

  /// Giây camera đã chạy / giây liên tục chưa thấy bé (màn bắt đầu).
  double _cameraOn = 0;
  double _unseen = 0;
  bool _switching = false;

  /// Đổi camera trước ↔ sau ngay ở màn bắt đầu, lưu lại cho lần sau.
  Future<void> _switchCamera() async {
    if (_switching) return;
    _switching = true;
    final front = !_app.settings.frontCamera;
    stopPose();
    setState(() {
      startInfo = null;
      poseError = null;
      _motion = null;
      _cameraOn = 0;
      _unseen = 0;
    });
    await _app.updateSettings(_app.settings.copyWith(frontCamera: front));
    PoseService.instance.settings.frontCamera = front;
    await startPose();
    _switching = false;
  }

  bool get _camera => startInfo != null && poseError == null;

  @override
  void initState() {
    super.initState();
    _app = AppScope.of(context);
    _levelIndex = widget.levelIndex;
    _ticker = createTicker(_tick)..start();
    PoseService.instance.settings.frontCamera = _app.settings.frontCamera;
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
    _time += dtSec;
    final dt = Duration(microseconds: (dtSec * 1e6).round());

    switch (_phase) {
      case _Stage.intro:
        // Đếm thời gian camera chạy mà chưa thấy bé, để hiện hướng dẫn đặt máy / đổi camera.
        _unseen = _camera && _motion?.body == null ? _unseen + dtSec : 0;
        if (_camera) _cameraOn += dtSec;
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
            targets: _normalized(_view.targets(_frame()!)),
          ));
          // Nhảy đếm: đọc to số vừa đếm được.
          if (mech is CountMechanic && mech.count != _spokenCount) {
            _spokenCount = mech.count;
            final seq = (s.question?.data['sequence'] as List?)?.cast<int>();
            if (_spokenCount > 0) {
              final n = seq != null && _spokenCount <= seq.length ? seq[_spokenCount - 1] : _spokenCount;
              unawaited(_app.audio.say(VietnameseNumber.read(n)));
            }
          }
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
        _spokenCount = 0;
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

  /// Trạng thái hiện tại cho mini game vẽ; null khi không có câu hỏi.
  PlayFrame? _frame() {
    final s = _session;
    final q = s?.question ?? s?.last?.question;
    if (s == null || q == null) return null;
    return PlayFrame(
      level: _level,
      question: q,
      mechanic: _mech,
      feedback: s.phase == SessionPhase.feedback ? s.last : null,
      body: _motion?.body,
      pose: _motion?.smoothed ?? lastFrame,
      camera: _camera,
      time: _time,
    );
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
        if (GameHud.cardRect.contains(stagePoint) && s.question != null) {
          // Chạm thẻ đề: đọc lại đề.
          unawaited(_app.audio.say(s.question!.speech));
          return;
        }
        if (s.phase == SessionPhase.feedback) {
          s.skipFeedback();
          return;
        }
        final f = _frame();
        if (f == null || s.phase != SessionPhase.asking) return;
        final rects = _view.tapTargets(f);
        for (var i = 0; i < rects.length; i++) {
          if (rects[i].contains(stagePoint)) {
            s.answer(i);
            return;
          }
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
                  ..._content(context),
                  if (_handsVisible)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: HandCursors(hands: _hands.both, active: _activePoint, progress: _activeProgress),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: IconButton.filledTonal(
                      iconSize: 36,
                      tooltip: 'Thoát',
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

  List<Widget> _content(BuildContext context) => switch (_phase) {
        _Stage.intro => _intro(context),
        _Stage.playing => _playing(context),
        _Stage.result || _Stage.limit => _resultView(),
        _Stage.rest => [_rest()],
      };

  Widget _centered(Widget child) => Positioned.fill(child: Center(child: child));

  /// Trạng thái camera ở màn bắt đầu: bé và phụ huynh biết camera có chạy và đang nhìn thấy gì.
  Widget _cameraPanel() {
    final front = _app.settings.frontCamera;
    final fps = PoseService.instance.fps;
    final String status;
    final Color color;
    if (poseError != null) {
      status = 'Không mở được camera: $poseError\nVẫn chơi được bằng cách chạm màn hình.';
      color = TvdColors.encourageDark;
    } else if (!_camera) {
      status = 'Đang mở camera ${front ? 'trước' : 'sau'}…';
      color = TvdColors.inkSoft;
    } else if (_cameraOn > 3 && fps < 1) {
      status = 'Camera ${front ? 'trước' : 'sau'} đã mở nhưng chưa có hình. Thử đổi camera.';
      color = TvdColors.encourageDark;
    } else if (_motion?.body != null) {
      status = 'Camera ${front ? 'trước' : 'sau'} · thấy con rồi';
      color = TvdColors.correctDark;
    } else if (_unseen > 3) {
      status = 'Camera ${front ? 'trước' : 'sau'} chưa thấy con.\n'
          '${front ? 'Màn hình điện thoại' : 'Mặt lưng điện thoại'} phải quay về phía con, đặt máy cách 2–3 m, thấy cả người.';
      color = TvdColors.encourageDark;
    } else {
      status = 'Camera ${front ? 'trước' : 'sau'} đang tìm con…';
      color = TvdColors.inkSoft;
    }
    return Positioned(
      right: TvLayout.safeX,
      top: 40,
      width: 640,
      child: Container(
        padding: const EdgeInsets.all(TvdSpace.s5),
        decoration: BoxDecoration(
          color: TvdColors.white,
          borderRadius: BorderRadius.circular(TvdRadius.lg),
          boxShadow: TvdShadow.tv(TvdColors.cardShadow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CamTile(frame: lastFrame, seen: _motion?.body != null, width: 180),
            const SizedBox(width: TvdSpace.s5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: TvText.label.copyWith(fontSize: 30, height: 1.25, color: color)),
                  if (_camera) Text('${fps.round()} khung hình/giây', style: TvText.label.copyWith(fontSize: 24, color: TvdColors.inkSoft)),
                  const SizedBox(height: TvdSpace.s4),
                  FilledButton.icon(
                    key: const ValueKey('switch-camera'),
                    onPressed: _switching ? null : _switchCamera,
                    icon: const Icon(Icons.cameraswitch, size: 40),
                    label: Text('Đổi sang camera ${front ? 'sau' : 'trước'}', style: const TextStyle(fontSize: 28)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _startText {
    if (!_camera) return poseError != null ? 'Chạm màn hình để bắt đầu' : 'Đang mở camera…';
    return _motion?.body != null ? 'Giơ hai tay lên để bắt đầu' : 'Con đứng vào giữa khung hình nhé!';
  }

  List<Widget> _intro(BuildContext context) {
    final progress = _motion?.calibrationProgress ?? 0;
    final custom = _view.intro(context, _level, _time);
    if (custom != null) {
      return [
        ...custom,
        _cameraPanel(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Center(
            child: Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              decoration: BoxDecoration(
                color: TvdColors.answerA,
                borderRadius: BorderRadius.circular(TvdRadius.pill),
                boxShadow: TvdShadow.tv(TvdColors.answerADark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_startText, style: TvText.button.copyWith(color: TvdColors.white, fontSize: 60, height: 1)),
                  if (_camera && progress > 0) ...[
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(value: progress, strokeWidth: 12, color: TvdColors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      _centered(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.topic.title} · Level ${_level.level}', style: TvText.prompt, textAlign: TextAlign.center),
          Text(MiniGames.title(_level.miniGame), style: TvText.label.copyWith(color: TvdColors.inkSoft)),
          const SizedBox(height: TvdSpace.s5),
          const TinTin(state: TinTinState.raiseBoth, size: 300),
          const SizedBox(height: TvdSpace.s5),
          Text(_startText, style: TvText.question),
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
      )),
      _cameraPanel(),
    ];
  }

  List<Widget> _playing(BuildContext context) {
    final s = _session!;
    final f = _frame();
    if (f == null) return const [];
    final cam = _view.camTile(f);
    return [
      ..._view.scene(context, f),
      if (cam != null) cam,
      Positioned.fill(
        child: IgnorePointer(
          child: GameHud(
            index: s.index,
            total: s.total,
            score: s.score,
            streak: s.streak,
            prompt: f.question.prompt,
            keyword: _view.keyword(f),
            remaining: s.remainingFraction,
            easy: _level.miniGame == MiniGames.simonSays ? f.easy : null,
            feedback: _view.hudFeedback ? f.feedback : null,
          ),
        ),
      ),
      if (!_camera && f.answering && _view.tapTargets(f).isEmpty) _devButtons(),
    ];
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
