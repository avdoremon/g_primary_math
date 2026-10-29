import 'package:flutter/material.dart';

import '../app/services.dart';
import '../progress/models.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tvd_button.dart';
import 'common.dart';

/// Tạo hoặc sửa hồ sơ bé: tên, lớp, màu hình đại diện.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.profile});

  final Profile? profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final AppServices _app = AppScope.of(context);
  late final TextEditingController _name = TextEditingController(text: widget.profile?.name ?? '');
  late int _grade = widget.profile?.grade ?? 1;
  late int _avatar = widget.profile?.avatar ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final p = widget.profile;
    if (p == null) {
      await _app.store.createProfile(name: name, grade: _grade, avatar: _avatar);
    } else {
      await _app.store.updateProfile(p.copyWith(name: name, grade: _grade, avatar: _avatar));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.profile == null ? 'Thêm bé' : 'Sửa hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(TvdSpace.s5),
        children: [
          Center(child: ProfileAvatar(name: _name.text, avatar: _avatar, size: 96)),
          const SizedBox(height: TvdSpace.s5),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Tên của bé', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TvdSpace.s4),
          Text('Bé đang học lớp', style: PhoneText.item),
          const SizedBox(height: TvdSpace.s2),
          Wrap(
            spacing: TvdSpace.s2,
            children: [
              for (var g = 1; g <= 5; g++)
                ChoiceChip(
                  label: Text(CurriculumLibrary.availableGrades.contains(g) ? 'Lớp $g' : 'Lớp $g (sắp có)'),
                  selected: _grade == g,
                  onSelected: CurriculumLibrary.availableGrades.contains(g) ? (_) => setState(() => _grade = g) : null,
                ),
            ],
          ),
          const SizedBox(height: TvdSpace.s5),
          Text('Màu của bé', style: PhoneText.item),
          const SizedBox(height: TvdSpace.s2),
          Wrap(
            spacing: TvdSpace.s3,
            children: [
              for (var i = 0; i < avatarColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _avatar = i),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: avatarColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: _avatar == i ? TvdColors.ink : Colors.transparent, width: 4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TvdSpace.s7),
          TvdButton(label: 'Lưu', icon: Icons.check, onPressed: _saving || _name.text.trim().isEmpty ? null : _save),
        ],
      ),
    );
  }
}
