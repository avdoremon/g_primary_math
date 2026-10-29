import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/services.dart';
import '../content/curriculum.dart';
import '../game/practice.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import 'common.dart';
import 'levels_screen.dart';
import 'play_launcher.dart';

/// Đường phiêu lưu (design Đợt 2 · Bản đồ chủ đề): các chủ đề của một lớp xếp trên con đường
/// uốn lượn từ dưới lên theo thứ tự SGK. Chủ đề đã mở có màu, chủ đề khoá xám. Tin Tin đứng ở
/// chủ đề đang học. Mỗi chủ đề hiện số sao/15. Bấm chủ đề đã mở để xem level.
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key, required this.profile, required this.grade});

  final Profile profile;
  final Grade grade;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  late final AppServices _app = AppScope.of(context);
  late Grade _grade = widget.grade;
  Map<LevelKey, LevelRecord>? _records;
  PracticePlan? _mistakes;
  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await _app.store.levelRecords(widget.profile.id, _grade.grade);
    PracticePlan? mistakes;
    try {
      final log = await _app.store.recentAnswers(widget.profile.id, limit: 100);
      mistakes = PracticePlan.forMistakes(_grade, log, math.Random());
    } on Object catch (e) {
      debugPrint('Không đọc được lịch sử trả lời: $e');
    }
    if (mounted) {
      setState(() {
        _records = records;
        _mistakes = mistakes;
      });
    }
  }

  void _switchGrade(int g) {
    final grade = _app.curriculum.grade(g);
    if (grade == null || grade.grade == _grade.grade) return;
    setState(() {
      _grade = grade;
      _records = null;
      _mistakes = null;
      _scrolled = false;
    });
    _load();
  }

  Future<void> _open(Topic t) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LevelsScreen(profile: widget.profile, grade: _grade, topic: t)),
    );
    await _load();
  }

  void _locked(int index) {
    final prev = _grade.topics[index - 1];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Đạt ${ProgressRules.topicUnlockStars} sao ở chủ đề "${prev.title}" để mở chủ đề này.'),
      ));
  }

  Future<void> _practiceMistakes() async {
    final plan = _mistakes;
    if (plan == null) return;
    await launchPlay(context, profile: widget.profile, grade: _grade, topic: plan.topic, practice: plan);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final unlockAll = _app.settings.unlockAllTopics;
    return Scaffold(
      backgroundColor: TvdColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(records),
            _gradeChips(),
            if (_mistakes != null) _mistakesButton(),
            Expanded(
              child: records == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(builder: (context, c) => _map(c, records, unlockAll)),
            ),
            if (kDebugMode) const _AdSlot(),
          ],
        ),
      ),
    );
  }

  Widget _header(Map<LevelKey, LevelRecord>? records) => Padding(
        padding: const EdgeInsets.fromLTRB(TvdSpace.s4, TvdSpace.s3, TvdSpace.s4, TvdSpace.s2),
        child: Row(
          children: [
            _RoundButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: TvdSpace.s3),
            ProfileAvatar(name: widget.profile.name, avatar: widget.profile.avatar, size: 40),
            const SizedBox(width: TvdSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.profile.name, style: PhoneText.title, overflow: TextOverflow.ellipsis),
                  Text('Đường phiêu lưu · ${_grade.title}', style: PhoneText.caption),
                ],
              ),
            ),
            if (records != null) StarCount(stars: ProgressRules.gradeStars(records, _grade)),
          ],
        ),
      );

  Widget _gradeChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: TvdSpace.s4),
          children: [
            for (final g in CurriculumLibrary.availableGrades)
              Padding(
                padding: const EdgeInsets.only(right: TvdSpace.s2),
                child: ChoiceChip(
                  label: Text('Lớp $g'),
                  selected: _grade.grade == g,
                  onSelected: (_) => _switchGrade(g),
                ),
              ),
          ],
        ),
      );

  Widget _mistakesButton() {
    final plan = _mistakes!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TvdSpace.s4, TvdSpace.s2, TvdSpace.s4, 0),
      child: Material(
        color: TvdColors.encourageSoft,
        borderRadius: BorderRadius.circular(TvdRadius.md),
        child: InkWell(
          key: const ValueKey('practice-mistakes'),
          borderRadius: BorderRadius.circular(TvdRadius.md),
          onTap: _practiceMistakes,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TvdSpace.s4, vertical: TvdSpace.s3),
            child: Row(
              children: [
                const Icon(Icons.replay_rounded, color: TvdColors.encourageDark),
                const SizedBox(width: TvdSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Luyện chỗ còn sai', style: PhoneText.item.copyWith(fontSize: 17)),
                      Text(
                        '10 câu từ những dạng bài con vừa làm chưa đúng · ${plan.topic.title}',
                        style: PhoneText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: TvdColors.encourageDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ bản đồ

  static const _rowHeight = 132.0;
  static const _node = 72.0;
  static const _topPad = 40.0;
  static const _bottomPad = 72.0;

  /// Vị trí ngang (0..1) của các chủ đề, lặp lại để con đường uốn lượn.
  static const _lanes = [0.5, 0.78, 0.5, 0.22];

  Widget _map(BoxConstraints c, Map<LevelKey, LevelRecord> records, bool unlockAll) {
    final topics = _grade.topics;
    final width = c.maxWidth;
    final height = math.max(c.maxHeight, _topPad + _bottomPad + _node + (topics.length - 1) * _rowHeight);
    final current = ProgressRules.currentTopicIndex(records, _grade, unlockAll: unlockAll);

    // Tâm ô chủ đề thứ i (chủ đề 1 ở dưới cùng).
    Offset center(int i) => Offset(width * _lanes[i % _lanes.length], height - _bottomPad - _node / 2 - i * _rowHeight);
    final centers = [for (var i = 0; i < topics.length; i++) center(i)];
    final open = [
      for (var i = 0; i < topics.length; i++) ProgressRules.isTopicUnlocked(records, _grade, i, unlockAll: unlockAll),
    ];

    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        // Cuộn ngược (reverse): 0 = đáy. Đưa chủ đề đang học vào giữa màn.
        final fromBottom = height - centers[current].dy;
        final target = (fromBottom - c.maxHeight / 2).clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.jumpTo(target);
      });
    }

    final tinOnLeft = centers[current].dx > width / 2;
    return SingleChildScrollView(
      controller: _scroll,
      reverse: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _RoadPainter(centers: centers, open: open))),
            for (var i = 0; i < topics.length; i++)
              Positioned(
                left: (centers[i].dx - 80).clamp(0.0, width - 160),
                top: centers[i].dy - _node / 2,
                width: 160,
                child: _TopicNode(
                  key: ValueKey('topic-${topics[i].id}'),
                  index: i,
                  topic: topics[i],
                  open: open[i],
                  current: i == current,
                  stars: ProgressRules.topicStars(records, topics[i]),
                  maxStars: ProgressRules.maxTopicStars(topics[i]),
                  onTap: () => open[i] ? _open(topics[i]) : _locked(i),
                ),
              ),
            Positioned(
              left: tinOnLeft ? centers[current].dx - _node / 2 - 76 : centers[current].dx + _node / 2 + 8,
              top: centers[current].dy - 52,
              child: const IgnorePointer(child: TinTin(state: TinTinState.hello, size: 68)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một chủ đề trên đường: ô màu có biểu tượng, tên chủ đề, số sao hoặc "Khoá".
class _TopicNode extends StatelessWidget {
  const _TopicNode({
    super.key,
    required this.index,
    required this.topic,
    required this.open,
    required this.current,
    required this.stars,
    required this.maxStars,
    required this.onTap,
  });

  final int index;
  final Topic topic;
  final bool open;
  final bool current;
  final int stars;
  final int maxStars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slot = AnswerSlotStyle.slots[index % AnswerSlotStyle.slots.length];
    final bg = open ? slot.color : TvdColors.line;
    final fg = open ? slot.onColor : TvdColors.inkSoft;
    final shadow = open ? slot.shadow : TvdColors.cardShadow;
    return Semantics(
      button: true,
      label: '${topic.title}, ${open ? '$stars trên $maxStars sao' : 'đang khoá'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _TopicsScreenState._node,
              height: _TopicsScreenState._node,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                border: current ? Border.all(color: TvdColors.ink, width: 4) : null,
                boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 5))],
              ),
              child: open ? _TopicGlyph(icon: topic.icon, color: fg) : Icon(Icons.lock_rounded, color: fg, size: 30),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: TvdColors.white.withAlpha(open ? 230 : 160),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    topic.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: PhoneText.caption.copyWith(
                      color: open ? TvdColors.ink : TvdColors.inkSoft,
                      fontSize: 13,
                      height: 17 / 13,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: open ? TvdColors.star : TvdColors.inkSoft),
                      const SizedBox(width: 2),
                      Text(
                        open ? '$stars/$maxStars' : 'Khoá',
                        style: PhoneText.caption.copyWith(color: open ? TvdColors.ink : TvdColors.inkSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu tượng chủ đề theo mã icon trong chương trình (vd. "cm", đồng hồ, "+−").
class _TopicGlyph extends StatelessWidget {
  const _TopicGlyph({required this.icon, required this.color});

  final String? icon;
  final Color color;

  static const _text = {
    'numbers': '123',
    'add_sub': '+−',
    'mul_div': '×÷',
    'position': '⇄',
    'measure': 'cm',
    'money': 'đ',
    'fraction': '½',
    'decimal': '0,5',
    'percent': '%',
    'angle': '∠',
  };

  static const _icons = {
    'shapes': Icons.change_history_rounded,
    'review': Icons.replay_rounded,
    'time': Icons.schedule_rounded,
    'stats': Icons.bar_chart_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = _text[icon];
    if (t != null) {
      return FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(t, style: PhoneText.titleLarge.copyWith(color: color, height: 1)),
        ),
      );
    }
    return Icon(_icons[icon] ?? Icons.auto_awesome_rounded, color: color, size: 36);
  }
}

/// Con đường nối các chủ đề: viền trắng, lòng đường màu kem đậm; đoạn tới chủ đề khoá nhạt và nét đứt.
class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.centers, required this.open});

  final List<Offset> centers;
  final List<bool> open;

  Path _segment(Offset a, Offset b) {
    final mid = (a.dy + b.dy) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..color = TvdColors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 34;
    final road = Paint()
      ..color = TvdColors.floor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 22;
    final dash = Paint()
      ..color = TvdColors.cardShadow
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    for (var i = 0; i + 1 < centers.length; i++) {
      final seg = _segment(centers[i], centers[i + 1]);
      canvas.drawPath(seg, edge);
      if (open[i + 1]) {
        canvas.drawPath(seg, road);
      } else {
        for (final m in seg.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 20) {
            canvas.drawPath(m.extractPath(d, d + 8), dash);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      !listEquals(old.centers, centers) || !listEquals(old.open, open);
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: TvdColors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: TvdColors.cardShadow, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: TvdColors.ink, size: 30),
          ),
        ),
      ),
    );
  }
}

/// Chỗ dành cho quảng cáo 320×50 ở cuối màn (theo design). Chưa gắn mạng quảng cáo nên chỉ hiện
/// khung giữ chỗ trong bản debug; bản phát hành không chiếm chỗ.
class _AdSlot extends StatelessWidget {
  const _AdSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 50,
      margin: const EdgeInsets.only(bottom: TvdSpace.s2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: TvdColors.cardShadow, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('QUẢNG CÁO · 320 × 50', style: PhoneText.caption),
    );
  }
}
