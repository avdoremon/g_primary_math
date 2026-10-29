import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/services.dart';
import '../dev/dev_menu_screen.dart';
import '../pose/pose_service.dart';
import '../progress/models.dart';
import '../progress/play_settings.dart';
import '../progress/progress_rules.dart';
import '../progress/weak_skills.dart';
import '../ui/theme/theme.dart';
import 'common.dart';
import 'connect_tv_screen.dart';

/// Khu phụ huynh (qua cổng phép nhân, design Phone-Parent): thẻ từng bé (thời gian chơi,
/// dạng bài cần luyện thêm, lịch sử trả lời), thời gian chơi, cài đặt chơi, camera và TV.
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late final AppServices _app = AppScope.of(context);
  late PlaySettings _s = _app.settings;
  List<Profile> _profiles = const [];
  Map<int, _ChildSummary> _summaries = const {};
  String? _lastCrash;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    PoseService.instance.status().then((st) {
      if (mounted) setState(() => _lastCrash = st.lastCrash);
    });
  }

  /// Báo lỗi lần trước: xem, sao chép gửi đội phát triển, hoặc xoá.
  Future<void> _showCrash() async {
    final text = _lastCrash ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo lỗi lần trước'),
        content: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 13))),
        actions: [
          TextButton(
            onPressed: () async {
              await PoseService.instance.clearCrash();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) setState(() => _lastCrash = null);
            },
            child: const Text('Xoá'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Đã sao chép. Dán vào tin nhắn gửi đội phát triển.')));
              }
            },
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfiles() async {
    final profiles = await _app.store.profiles();
    final summaries = <int, _ChildSummary>{};
    final now = DateTime.now();
    for (final p in profiles) {
      try {
        final today = await _app.store.playTimeOn(p.id, now);
        var week = Duration.zero;
        for (var d = 0; d < 7; d++) {
          week += await _app.store.playTimeOn(p.id, now.subtract(Duration(days: d)));
        }
        final log = await _app.store.recentAnswers(p.id, limit: 100);
        summaries[p.id] = _ChildSummary(today: today, week: week, played: log.isNotEmpty, weak: WeakSkills.analyze(log));
      } on Object catch (e) {
        debugPrint('Không đọc được tiến độ của ${p.name}: $e');
      }
    }
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _summaries = summaries;
      });
    }
  }

  Future<void> _update(PlaySettings s) async {
    setState(() => _s = s);
    await _app.updateSettings(s);
  }

  String _limitLabel(int m) => m == 0 ? 'Không giới hạn' : '$m phút';

  Future<void> _openReport(Profile p) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ProfileReport(profile: p)));
    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvdColors.cream,
      appBar: AppBar(title: const Text('Phụ huynh'), backgroundColor: TvdColors.cream),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TvdSpace.s4, 0, TvdSpace.s4, TvdSpace.s6),
        children: [
          if (_profiles.isEmpty)
            _Section(child: Text('Chưa có hồ sơ nào. Tạo hồ sơ cho bé ở màn đầu.', style: PhoneText.body)),
          for (final p in _profiles) _childCard(p),
          _Section(
            title: 'Thời gian chơi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mỗi ngày tối đa (mỗi bé)', style: PhoneText.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: TvdSpace.s2),
                Wrap(
                  spacing: TvdSpace.s2,
                  runSpacing: TvdSpace.s2,
                  children: [
                    for (final m in PlaySettings.dailyLimitChoices)
                      _Pill(
                        label: _limitLabel(m),
                        selected: _s.dailyLimitMinutes == m,
                        onTap: () => _update(_s.copyWith(dailyLimitMinutes: m)),
                      ),
                  ],
                ),
                const SizedBox(height: TvdSpace.s4),
                Text('Nhắc nghỉ sau', style: PhoneText.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: TvdSpace.s2),
                Wrap(
                  spacing: TvdSpace.s2,
                  runSpacing: TvdSpace.s2,
                  children: [
                    for (final m in PlaySettings.breakChoices)
                      _Pill(
                        label: m == 0 ? 'Không nhắc' : '$m phút',
                        selected: _s.breakEveryMinutes == m,
                        onTap: () => _update(_s.copyWith(breakEveryMinutes: m)),
                      ),
                  ],
                ),
                const SizedBox(height: TvdSpace.s3),
                Text(
                  'Giới hạn và nhắc nghỉ chỉ áp dụng giữa hai lượt chơi, không cắt ngang khi bé đang chơi.',
                  style: PhoneText.caption,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Chơi',
            child: Column(
              children: [
                _Toggle(
                  label: 'Đọc đề và lời giải thích',
                  value: _s.voice,
                  onChanged: (v) => _update(_s.copyWith(voice: v)),
                ),
                if (!_app.audio.ttsAvailable)
                  Text(
                    'Máy chưa có giọng đọc tiếng Việt: cài "Dịch vụ chuyển văn bản thành giọng nói của Google" '
                    'và tải giọng Tiếng Việt trong Cài đặt Android.',
                    style: PhoneText.caption.copyWith(color: TvdColors.encourageDark),
                  ),
                _Toggle(
                  label: 'Hiệu ứng âm thanh',
                  value: _s.soundEffects,
                  onChanged: (v) => _update(_s.copyWith(soundEffects: v)),
                ),
                _Toggle(
                  label: 'Chế độ luyện tập (không đếm giờ)',
                  value: _s.practiceMode,
                  onChanged: (v) => _update(_s.copyWith(practiceMode: v)),
                ),
                _Toggle(
                  key: const ValueKey('unlock-all-topics'),
                  label: 'Mở tất cả chủ đề',
                  subtitle: 'Bình thường chủ đề sau mở khi chủ đề trước đạt ${ProgressRules.topicUnlockStars} sao. '
                      'Bật khi trên lớp học khác thứ tự.',
                  value: _s.unlockAllTopics,
                  onChanged: (v) => _update(_s.copyWith(unlockAllTopics: v)),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Camera và TV',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Camera mặc định khi vào chơi', style: PhoneText.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: TvdSpace.s2),
                SegmentedButton<bool>(
                  key: const ValueKey('default-camera'),
                  segments: const [
                    ButtonSegment(value: true, label: Text('Camera trước'), icon: Icon(Icons.camera_front_outlined)),
                    ButtonSegment(value: false, label: Text('Camera sau'), icon: Icon(Icons.camera_rear_outlined)),
                  ],
                  selected: {_s.frontCamera},
                  onSelectionChanged: (v) => _update(_s.copyWith(frontCamera: v.first)),
                ),
                const SizedBox(height: TvdSpace.s2),
                Text(
                  _s.frontCamera
                      ? 'Màn hình điện thoại quay về phía bé. Hợp khi dựng máy trước mặt bé.'
                      : 'Mặt lưng điện thoại quay về phía bé, máy đặt cạnh TV. Góc rộng và nét hơn.',
                  style: PhoneText.caption,
                ),
                Text('Khi đang chơi vẫn đổi được camera bằng nút ở góc dưới màn hình.', style: PhoneText.caption),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cast_rounded, color: TvdColors.answerADark),
                  title: const Text('Hướng dẫn kết nối TV'),
                  subtitle: const Text('Phản chiếu màn hình, đặt điện thoại, thử camera'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ConnectTvScreen()),
                  ),
                ),
                if (_lastCrash != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report_outlined, color: TvdColors.encourageDark),
                    title: const Text('Báo lỗi lần trước'),
                    subtitle: const Text('App đã bị dừng bất thường. Bấm để xem và sao chép gửi đội phát triển.'),
                    onTap: _showCrash,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_outlined),
                  title: const Text('Công cụ phát triển'),
                  subtitle: const Text('Khung xương, đo độ trễ TV, cài đặt camera'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DevMenuScreen())),
                ),
              ],
            ),
          ),
          Text(
            'Ảnh camera chỉ được xử lý trên máy để nhận diện tư thế: không ghi hình, không gửi đi đâu. '
            'Tiến độ chỉ lưu trên điện thoại này.',
            style: PhoneText.caption,
          ),
        ],
      ),
    );
  }

  /// Thẻ một bé: thời gian chơi hôm nay / tuần này, các dạng bài cần luyện thêm, lịch sử trả lời.
  Widget _childCard(Profile p) {
    final sum = _summaries[p.id];
    final limit = _s.dailyLimitMinutes;
    final todayMin = sum?.today.inMinutes ?? 0;
    return _Section(
      key: ValueKey('child-${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: p.name, avatar: p.avatar, size: 40),
              const SizedBox(width: TvdSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} · Lớp ${p.grade}', style: PhoneText.item.copyWith(fontSize: 17)),
                    Text(
                      sum == null
                          ? 'Đang tải…'
                          : 'Hôm nay ${limit == 0 ? '$todayMin phút' : '$todayMin/$limit phút'} · '
                              'tuần này ${sum.week.inMinutes} phút',
                      style: PhoneText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (limit > 0) ...[
            const SizedBox(height: TvdSpace.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(TvdRadius.pill),
              child: LinearProgressIndicator(
                value: (todayMin / limit).clamp(0.0, 1.0),
                minHeight: 10,
                color: todayMin >= limit ? TvdColors.encourage : TvdColors.correct,
                backgroundColor: TvdColors.line,
              ),
            ),
          ],
          const SizedBox(height: TvdSpace.s3),
          Text('Cần luyện thêm', style: PhoneText.body.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: TvdSpace.s1),
          if (sum != null && !sum.played)
            Text('Bé chưa chơi lần nào.', style: PhoneText.caption)
          else if (sum != null && sum.weak.isEmpty)
            Text('Chưa thấy dạng bài nào bé hay sai. Giỏi lắm!', style: PhoneText.caption)
          else if (sum != null)
            for (final w in sum.weak)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(w.name, style: PhoneText.body.copyWith(fontWeight: FontWeight.w700))),
                    Text(
                      '${w.correct}/${w.total} đúng',
                      style: PhoneText.caption.copyWith(color: TvdColors.encourageDark, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          if (sum != null && sum.weak.isNotEmpty)
            Text('Bé bấm "Luyện chỗ còn sai" trên Đường phiêu lưu để luyện đúng các dạng này.', style: PhoneText.caption),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => _openReport(p),
            child: const Text('Xem lịch sử trả lời'),
          ),
        ],
      ),
    );
  }
}

class _ChildSummary {
  const _ChildSummary({required this.today, required this.week, required this.played, required this.weak});

  final Duration today;
  final Duration week;
  final bool played;
  final List<SkillStat> weak;
}

/// Thẻ trắng có tiêu đề, theo design Phone-Parent.
class _Section extends StatelessWidget {
  const _Section({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Nền trắng vẽ bằng Material (không phải DecoratedBox) để ListTile/công tắc bên trong
    // hiện được hiệu ứng chạm; DecoratedBox ngoài chỉ vẽ bóng.
    return Container(
      margin: const EdgeInsets.only(bottom: TvdSpace.s3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TvdRadius.md),
        boxShadow: TvdShadow.phone(TvdColors.cardShadow),
      ),
      child: Material(
        color: TvdColors.white,
        borderRadius: BorderRadius.circular(TvdRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: PhoneText.title.copyWith(fontSize: 20, height: 26 / 20)),
                const SizedBox(height: TvdSpace.s2),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút chọn dạng viên thuốc: đang chọn thì nền mực, chữ trắng.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? TvdColors.ink : TvdColors.white,
        borderRadius: BorderRadius.circular(TvdRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(TvdRadius.pill),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TvdRadius.pill),
              border: selected ? null : Border.all(color: TvdColors.line, width: 2),
            ),
            child: Text(
              label,
              style: PhoneText.button.copyWith(fontSize: 15, color: selected ? TvdColors.white : TvdColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.label, required this.value, required this.onChanged, this.subtitle});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: PhoneText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: PhoneText.caption),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Tiến độ một bé: thời gian chơi hôm nay, điểm, các câu trả lời gần đây.
class _ProfileReport extends StatefulWidget {
  const _ProfileReport({required this.profile});

  final Profile profile;

  @override
  State<_ProfileReport> createState() => _ProfileReportState();
}

class _ProfileReportState extends State<_ProfileReport> {
  late final AppServices _app = AppScope.of(context);
  List<AnswerLogEntry>? _log;
  Duration _today = Duration.zero;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await _app.store.recentAnswers(widget.profile.id, limit: 40);
    final today = await _app.store.playTimeOn(widget.profile.id, DateTime.now());
    final score = await _app.store.totalScore(widget.profile.id);
    if (mounted) {
      setState(() {
        _log = log;
        _today = today;
        _score = score;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xoá hồ sơ ${widget.profile.name}?'),
        content: const Text('Toàn bộ sao, điểm và lịch sử của bé sẽ bị xoá, không khôi phục được.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    await _app.store.deleteProfile(widget.profile.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final wrong = log?.where((e) => !e.correct).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.name),
        actions: [IconButton(tooltip: 'Xoá hồ sơ', onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: log == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(TvdSpace.s4),
              children: [
                Text('Hôm nay đã chơi ${formatMinutes(_today)} · tổng $_score điểm', style: PhoneText.item),
                if (log.isNotEmpty)
                  Text('${log.length} câu gần nhất: sai $wrong câu', style: PhoneText.caption),
                const SizedBox(height: TvdSpace.s3),
                if (log.isEmpty) Text('Bé chưa chơi lần nào.', style: PhoneText.body),
                for (final e in log)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      e.correct ? Icons.check_circle : Icons.cancel,
                      color: e.correct ? TvdColors.correct : TvdColors.encourage,
                    ),
                    title: Text(e.prompt),
                    subtitle: Text(
                      e.correct
                          ? 'Đúng: ${e.correctOption}'
                          : '${e.chosen == null ? 'Hết giờ / chưa làm được' : 'Chọn ${e.chosen}'} · đáp án ${e.correctOption}',
                    ),
                    trailing: Text('${(e.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s', style: PhoneText.caption),
                  ),
              ],
            ),
    );
  }
}
