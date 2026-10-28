import 'package:flutter/material.dart';

import '../app/services.dart';
import '../dev/dev_menu_screen.dart';
import '../progress/models.dart';
import '../progress/play_settings.dart';
import '../ui/theme/theme.dart';
import 'common.dart';

/// Khu phụ huynh (qua cổng phép nhân): thời gian chơi, âm thanh, chế độ luyện tập,
/// tiến độ và lịch sử trả lời của từng bé, xoá hồ sơ.
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late final AppServices _app = AppScope.of(context);
  late PlaySettings _s = _app.settings;
  List<Profile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final p = await _app.store.profiles();
    if (mounted) setState(() => _profiles = p);
  }

  Future<void> _update(PlaySettings s) async {
    setState(() => _s = s);
    await _app.updateSettings(s);
  }

  String _limitLabel(int m) => m == 0 ? 'Không giới hạn' : '$m phút';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phụ huynh')),
      body: ListView(
        padding: const EdgeInsets.all(TvdSpace.s4),
        children: [
          Text('Thời gian chơi', style: PhoneText.title),
          const SizedBox(height: TvdSpace.s2),
          Text('Giới hạn mỗi ngày (mỗi bé)', style: PhoneText.item),
          Wrap(
            spacing: TvdSpace.s2,
            children: [
              for (final m in PlaySettings.dailyLimitChoices)
                ChoiceChip(
                  label: Text(_limitLabel(m)),
                  selected: _s.dailyLimitMinutes == m,
                  onSelected: (_) => _update(_s.copyWith(dailyLimitMinutes: m)),
                ),
            ],
          ),
          const SizedBox(height: TvdSpace.s3),
          Text('Nhắc nghỉ sau khi chơi liên tục', style: PhoneText.item),
          Wrap(
            spacing: TvdSpace.s2,
            children: [
              for (final m in PlaySettings.breakChoices)
                ChoiceChip(
                  label: Text(m == 0 ? 'Không nhắc' : '$m phút'),
                  selected: _s.breakEveryMinutes == m,
                  onSelected: (_) => _update(_s.copyWith(breakEveryMinutes: m)),
                ),
            ],
          ),
          Text(
            'Giới hạn và nhắc nghỉ chỉ áp dụng giữa hai level, không cắt ngang khi bé đang chơi.',
            style: PhoneText.caption,
          ),
          const Divider(height: TvdSpace.s7),
          Text('Chơi', style: PhoneText.title),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đọc đề và lời giải thích'),
            value: _s.voice,
            onChanged: (v) => _update(_s.copyWith(voice: v)),
          ),
          if (!_app.audio.ttsAvailable)
            Text(
              'Máy chưa có giọng đọc tiếng Việt: cài "Dịch vụ chuyển văn bản thành giọng nói của Google" '
              'và tải giọng Tiếng Việt trong Cài đặt Android.',
              style: PhoneText.caption.copyWith(color: TvdColors.encourageDark),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hiệu ứng âm thanh'),
            value: _s.soundEffects,
            onChanged: (v) => _update(_s.copyWith(soundEffects: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chế độ luyện tập'),
            subtitle: const Text('Không đếm giờ, không có thưởng tốc độ'),
            value: _s.practiceMode,
            onChanged: (v) => _update(_s.copyWith(practiceMode: v)),
          ),
          const Divider(height: TvdSpace.s7),
          Text('Tiến độ của bé', style: PhoneText.title),
          const SizedBox(height: TvdSpace.s2),
          if (_profiles.isEmpty) Text('Chưa có hồ sơ nào.', style: PhoneText.caption),
          for (final p in _profiles)
            TvdCard(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ProfileReport(profile: p)));
                await _loadProfiles();
              },
              child: Row(
                children: [
                  ProfileAvatar(name: p.name, avatar: p.avatar, size: 40),
                  const SizedBox(width: TvdSpace.s3),
                  Expanded(child: Text(p.name, style: PhoneText.item)),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          const Divider(height: TvdSpace.s7),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.build_outlined),
            title: const Text('Công cụ phát triển'),
            subtitle: const Text('Khung xương, đo độ trễ TV, cài đặt camera'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DevMenuScreen())),
          ),
          const SizedBox(height: TvdSpace.s4),
          Text(
            'Ảnh camera chỉ được xử lý trên máy để nhận diện tư thế: không ghi hình, không gửi đi đâu. '
            'Tiến độ chỉ lưu trên điện thoại này.',
            style: PhoneText.caption,
          ),
        ],
      ),
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
