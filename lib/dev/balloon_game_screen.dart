import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../motion/dwell_selector.dart';
import '../motion/hand_tracker.dart';
import '../pose/pose_frame.dart';
import '../pose/pose_service.dart';
import 'balloon_painter.dart';
import 'hand_cursor_painter.dart';
import 'pose_screen_mixin.dart';
import 'skeleton_painter.dart';

/// Màn 2: mini game "Bóng bay phép tính" – thử cơ chế C (chạm đáp án bằng cách giữ tay).
/// Chạm màn hình cũng chọn được, để thử khi chưa đứng trước camera.
class BalloonGameScreen extends StatefulWidget {
  const BalloonGameScreen({super.key});

  @override
  State<BalloonGameScreen> createState() => _BalloonGameScreenState();
}

enum _Phase { pickLevel, playing, feedback, finished }

class _Question {
  _Question(this.text, this.answer, this.options);

  final String text;
  final int answer;
  final List<int> options;
}

/// Sinh câu hỏi cộng/trừ theo mức:
/// 1 = trong phạm vi 10, 2 = trong phạm vi 20, 3 = số tròn chục trong phạm vi 100.
class _QuestionGenerator {
  final _r = math.Random();

  _Question next(int level) {
    final max = level == 1 ? 10 : (level == 2 ? 20 : 100);
    final step = level == 3 ? 10 : 1;
    final units = max ~/ step;

    late int a, b, answer;
    late String op;
    if (_r.nextBool()) {
      answer = (_r.nextInt(units) + 1) * step;
      a = _r.nextInt(answer ~/ step + 1) * step;
      b = answer - a;
      op = '+';
    } else {
      a = (_r.nextInt(units) + 1) * step;
      b = _r.nextInt(a ~/ step + 1) * step;
      answer = a - b;
      op = '−';
    }

    // Đáp án nhiễu theo lỗi trẻ hay mắc: lệch 1–3 (hoặc lệch 1–3 chục ở mức 3).
    final deltas = [1, -1, 2, -2, 3, -3].map((d) => d * step).toList()..shuffle(_r);
    final options = <int>{answer};
    for (final d in deltas) {
      final v = answer + d;
      if (v >= 0 && v <= max) options.add(v);
      if (options.length == 3) break;
    }
    var extra = 4;
    while (options.length < 3) {
      options.add(answer + step * extra++);
    }
    final list = options.toList()..shuffle(_r);
    return _Question('$a $op $b = ?', answer, list);
  }
}

class _BalloonGameScreenState extends State<BalloonGameScreen>
    with SingleTickerProviderStateMixin, PoseScreenMixin {
  static const _totalQuestions = 10;
  static const _questionSeconds = 12.0;
  static const _feedbackSeconds = 1.6;
  static const _colors = [Color(0xFFFF7A59), Color(0xFFFFC233), Color(0xFF4CC38A), Color(0xFF5B8DEF)];

  final _tracker = HandTracker();
  final _dwell = DwellSelector(dwellSeconds: 0.4);
  final _generator = _QuestionGenerator();
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  double _time = 0;
  double _screenAspect = 16 / 9;
  HandState _hands = HandState.none;
  Duration _lastPersonAt = Duration.zero;
  bool _paused = false;

  _Phase _phase = _Phase.pickLevel;
  int _level = 1;
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _correct = 0;
  int _lastGain = 0;
  bool _lastWasCorrect = false;
  _Question? _q;
  double _remaining = _questionSeconds;
  double _feedbackLeft = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    startPose();
  }

  @override
  void dispose() {
    _ticker.dispose();
    stopPose();
    super.dispose();
  }

  @override
  void onPoseFrame(PoseFrame frame) {
    _tracker.screenAspect = _screenAspect;
    _hands = _tracker.update(frame);
    if (frame.hasPerson) _lastPersonAt = frame.arrival;
  }

  // ------------------------------------------------------------ vòng lặp game

  void _tick(Duration elapsed) {
    final dt = math.min(0.1, math.max(0.0, (elapsed - _lastTick).inMicroseconds / 1e6));
    _lastTick = elapsed;
    _time += dt;

    // Chỉ tạm dừng khi camera đang chạy mà không thấy người quá 2 giây (design system).
    final now = PoseService.instance.clock.elapsed;
    _paused = startInfo != null && now - _lastPersonAt > const Duration(seconds: 2);

    if (!_paused) {
      switch (_phase) {
        case _Phase.playing:
          _remaining -= dt;
          if (_remaining <= 0) _answer(null);
        case _Phase.feedback:
          _feedbackLeft -= dt;
          if (_feedbackLeft <= 0) _nextQuestion();
        case _Phase.pickLevel:
        case _Phase.finished:
          break;
      }

      final targets = _targets();
      if (targets.isEmpty) {
        _dwell.reset();
      } else {
        final hit = _dwell.update(_hands.both, targets, dt);
        if (hit != null) _select(hit);
      }
    }
    setState(() {});
  }

  // ------------------------------------------------------------ luật chơi

  List<String> _labels() {
    switch (_phase) {
      case _Phase.pickLevel:
        return const ['Mức 1\ntrong 10', 'Mức 2\ntrong 20', 'Mức 3\nsố chục'];
      case _Phase.playing:
      case _Phase.feedback:
        return _q!.options.map((e) => '$e').toList();
      case _Phase.finished:
        return const ['Chơi\nlại', 'Về\nmenu'];
    }
  }

  List<Offset> _centers(int n) {
    final xs = n == 2 ? const [0.33, 0.67] : const [0.2, 0.5, 0.8];
    return [
      for (var i = 0; i < n; i++) Offset(xs[i], 0.56 + 0.025 * math.sin(_time * 1.8 + i * 1.3)),
    ];
  }

  static const _balloonW = 0.17;
  static const _balloonH = 0.36;

  List<Rect> _targets() {
    if (_phase == _Phase.feedback) return const [];
    return _centers(_labels().length)
        .map((c) => Rect.fromCenter(center: c, width: _balloonW, height: _balloonH))
        .toList();
  }

  void _select(int i) {
    switch (_phase) {
      case _Phase.pickLevel:
        _level = i + 1;
        _startGame();
      case _Phase.playing:
        _answer(_q!.options[i]);
      case _Phase.finished:
        if (i == 0) {
          setState(() => _phase = _Phase.pickLevel);
        } else {
          Navigator.of(context).pop();
        }
      case _Phase.feedback:
        break;
    }
  }

  void _startGame() {
    _index = 0;
    _score = 0;
    _streak = 0;
    _correct = 0;
    _q = _generator.next(_level);
    _remaining = _questionSeconds;
    _phase = _Phase.playing;
    _dwell.reset();
  }

  void _answer(int? value) {
    final q = _q!;
    _lastWasCorrect = value == q.answer;
    if (_lastWasCorrect) {
      _streak++;
      _correct++;
      _lastGain = 100 + (_remaining * 10).round() + (_streak - 1) * 20;
      _score += _lastGain;
    } else {
      _streak = 0;
      _lastGain = 0;
    }
    _phase = _Phase.feedback;
    _feedbackLeft = _feedbackSeconds;
    _dwell.reset();
  }

  void _nextQuestion() {
    _index++;
    if (_index >= _totalQuestions) {
      _phase = _Phase.finished;
    } else {
      _q = _generator.next(_level);
      _remaining = _questionSeconds;
      _phase = _Phase.playing;
    }
    _dwell.reset();
  }

  int get _stars => _correct >= 10 ? 3 : (_correct >= 8 ? 2 : (_correct >= 6 ? 1 : 0));

  void _onTap(Offset normalized) {
    if (_phase == _Phase.feedback) return;
    final targets = _targets();
    for (var i = 0; i < targets.length; i++) {
      if (targets[i].contains(normalized)) {
        _select(i);
        return;
      }
    }
  }

  // ------------------------------------------------------------ giao diện

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _screenAspect = size.width / size.height;
        final labels = _labels();
        final centers = _centers(labels.length);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onTap(Offset(d.localPosition.dx / size.width, d.localPosition.dy / size.height)),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF79C6F2), Color(0xFFCDEBFA)],
                    ),
                  ),
                ),
              ),
              _header(size),
              for (var i = 0; i < labels.length; i++) _balloon(size, centers[i], labels[i], i),
              Positioned(
                left: size.width * 0.02,
                bottom: size.height * 0.03,
                width: size.width * 0.13,
                height: size.width * 0.1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3A5F).withAlpha(170),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(painter: SkeletonPainter(lastFrame)),
                ),
              ),
              Positioned(
                right: size.width * 0.02,
                bottom: size.height * 0.03,
                child: Text(
                  poseError != null
                      ? 'Chế độ chạm màn hình'
                      : '${PoseService.instance.fps.toStringAsFixed(0)} khung/giây',
                  style: const TextStyle(color: Color(0xFF1F3A5F), fontSize: 14),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: HandCursorPainter(
                      hands: _hands.both,
                      activePoint: _dwell.activePoint,
                      progress: _dwell.progress,
                    ),
                  ),
                ),
              ),
              if (_phase == _Phase.feedback) _feedbackBanner(size),
              if (_paused) _pauseOverlay(size),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(Size size) {
    const ink = Color(0xFF1F3A5F);
    final big = size.height * 0.11;
    switch (_phase) {
      case _Phase.pickLevel:
        return Positioned(
          top: size.height * 0.08,
          left: 0,
          right: 0,
          child: Text('Chọn mức chơi: đưa tay chạm vào bóng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size.height * 0.07, fontWeight: FontWeight.w800, color: ink)),
        );
      case _Phase.finished:
        final stars = List.generate(3, (i) => i < _stars ? '★' : '☆').join();
        return Positioned(
          top: size.height * 0.06,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(stars, style: TextStyle(fontSize: big, color: const Color(0xFFFFB400))),
              Text('Đúng $_correct/$_totalQuestions câu · $_score điểm',
                  style: TextStyle(fontSize: size.height * 0.06, fontWeight: FontWeight.w800, color: ink)),
            ],
          ),
        );
      case _Phase.playing:
      case _Phase.feedback:
        return Positioned(
          top: size.height * 0.05,
          left: size.width * 0.08,
          right: size.width * 0.05,
          child: Column(
            children: [
              Row(
                children: [
                  Text('Câu ${_index + 1}/$_totalQuestions',
                      style: TextStyle(fontSize: size.height * 0.045, color: ink, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_streak >= 2)
                    Text('Chuỗi $_streak  ',
                        style: TextStyle(fontSize: size.height * 0.045, color: const Color(0xFFE8590C))),
                  Text('$_score điểm',
                      style: TextStyle(fontSize: size.height * 0.045, color: ink, fontWeight: FontWeight.w700)),
                ],
              ),
              Text(_q!.text, style: TextStyle(fontSize: big, fontWeight: FontWeight.w900, color: ink)),
              SizedBox(
                width: size.width * 0.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_remaining / _questionSeconds).clamp(0.0, 1.0).toDouble(),
                    minHeight: size.height * 0.018,
                    backgroundColor: Colors.white.withAlpha(150),
                    color: _remaining < 4 ? const Color(0xFFF08A24) : const Color(0xFF2E9E6B),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _balloon(Size size, Offset center, String label, int i) {
    final w = _balloonW * size.width;
    final h = _balloonH * size.height;
    var mark = BalloonMark.none;
    if (_phase == _Phase.feedback && _q != null) {
      final value = _q!.options[i];
      if (value == _q!.answer) mark = BalloonMark.correct;
    }
    final aim = _dwell.candidate == i ? _dwell.progress : 0.0;
    final isNumber = !label.contains('\n');

    return Positioned(
      left: center.dx * size.width - w / 2,
      top: center.dy * size.height - h / 2,
      width: w,
      height: h,
      child: CustomPaint(
        painter: BalloonPainter(color: _colors[i % _colors.length], aim: aim, mark: mark),
        child: Align(
          alignment: const Alignment(0, -0.2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isNumber ? size.height * 0.11 : size.height * 0.05,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 4, color: Color(0x66000000))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedbackBanner(Size size) {
    final ok = _lastWasCorrect;
    return Positioned(
      bottom: size.height * 0.04,
      left: size.width * 0.25,
      right: size.width * 0.25,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFF1FA35B) : const Color(0xFFF08A24),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          ok ? 'Đúng rồi! +$_lastGain' : 'Chưa đúng — đáp án là ${_q!.answer}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size.height * 0.06, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }

  Widget _pauseOverlay(Size size) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC101820),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Con đứng vào khung hình nhé!',
                  style: TextStyle(fontSize: size.height * 0.08, fontWeight: FontWeight.w800, color: Colors.white)),
              SizedBox(height: size.height * 0.03),
              SizedBox(
                width: size.width * 0.25,
                height: size.height * 0.4,
                child: CustomPaint(painter: SkeletonPainter(lastFrame, showFrame: true)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
