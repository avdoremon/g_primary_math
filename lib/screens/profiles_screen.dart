import 'package:flutter/material.dart';

import '../app/services.dart';
import '../progress/models.dart';
import '../progress/progress_rules.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/app_logo.dart';
import '../ui/widgets/tin_tin.dart';
import '../ui/widgets/tvd_button.dart';
import 'common.dart';
import 'connect_tv_screen.dart';
import 'parent_screen.dart';
import 'profile_edit_screen.dart';
import 'topics_screen.dart';

/// Màn đầu: chọn bé đang chơi. Không đăng nhập, hồ sơ chỉ nằm trên máy.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfileSummary {
  _ProfileSummary(this.profile, this.stars, this.maxStars);

  final Profile profile;
  final int stars;
  final int maxStars;
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late final AppServices _app = AppScope.of(context);
  List<_ProfileSummary>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final out = <_ProfileSummary>[];
    for (final p in await _app.store.profiles()) {
      final grade = _app.curriculum.grade(p.grade);
      if (grade == null) {
        out.add(_ProfileSummary(p, 0, 0));
        continue;
      }
      final records = await _app.store.levelRecords(p.id, p.grade);
      final max = grade.topics.fold<int>(0, (s, t) => s + ProgressRules.maxTopicStars(t));
      out.add(_ProfileSummary(p, ProgressRules.gradeStars(records, grade), max));
    }
    if (mounted) setState(() => _items = out);
  }

  Future<void> _edit([Profile? p]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileEditScreen(profile: p)));
    await _load();
  }

  Future<void> _open(Profile p) async {
    final grade = _app.curriculum.grade(p.grade) ?? _app.curriculum.grade(CurriculumLibrary.availableGrades.first)!;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TopicsScreen(profile: p, grade: grade)));
    await _load();
  }

  Future<void> _connectTv() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectTvScreen()));

  Future<void> _parent() async {
    if (!await showParentGate(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(TvdSpace.s5),
                children: [
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: TvdSpace.s2,
                    runSpacing: TvdSpace.s2,
                    children: [
                      _TopButton(
                        key: const ValueKey('open-connect-tv'),
                        icon: Icons.cast_rounded,
                        label: 'Kết nối TV',
                        onTap: _connectTv,
                      ),
                      _TopButton(
                        key: const ValueKey('open-parent'),
                        icon: Icons.lock_person_rounded,
                        label: 'Phụ huynh',
                        onTap: _parent,
                      ),
                    ],
                  ),
                  const Center(child: TinTin(state: TinTinState.hello, size: 150)),
                  const SizedBox(height: TvdSpace.s3),
                  const Center(child: AppLogo(height: 72)),
                  Text(
                    items.isEmpty ? 'Tạo hồ sơ cho bé để bắt đầu' : 'Ai đang chơi nào?',
                    style: PhoneText.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: TvdSpace.s5),
                  for (final it in items)
                    TvdCard(
                      onTap: () => _open(it.profile),
                      onLongPress: () => _edit(it.profile),
                      child: Row(
                        children: [
                          ProfileAvatar(name: it.profile.name, avatar: it.profile.avatar),
                          const SizedBox(width: TvdSpace.s4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.profile.name, style: PhoneText.item),
                                Text('Lớp ${it.profile.grade}', style: PhoneText.caption),
                              ],
                            ),
                          ),
                          StarCount(stars: it.stars, max: it.maxStars),
                          IconButton(
                            tooltip: 'Sửa hồ sơ',
                            onPressed: () => _edit(it.profile),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: TvdSpace.s3),
                  TvdButton(
                    label: 'Thêm bé',
                    icon: Icons.add,
                    kind: items.isEmpty ? TvdButtonKind.primary : TvdButtonKind.secondary,
                    onPressed: () => _edit(),
                  ),
                  const SizedBox(height: TvdSpace.s6),
                  InkWell(
                    onTap: _connectTv,
                    borderRadius: BorderRadius.circular(TvdRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(TvdSpace.s2),
                      child: Text(
                        'Đặt điện thoại cạnh TV, camera hướng về phía bé (cách 2–3 m), '
                        'rồi phản chiếu màn hình lên TV. Xem hướng dẫn kết nối TV ›',
                        style: PhoneText.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Nút viên thuốc nhỏ ở đầu màn chọn hồ sơ (Kết nối TV, Phụ huynh).
class _TopButton extends StatelessWidget {
  const _TopButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TvdColors.white,
      borderRadius: BorderRadius.circular(TvdRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(TvdRadius.pill),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: TvdSpace.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TvdRadius.pill),
            border: Border.all(color: TvdColors.line, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: TvdColors.ink),
              const SizedBox(width: 6),
              Text(label, style: PhoneText.button.copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
