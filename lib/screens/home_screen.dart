import 'package:flutter/material.dart';

import '../app/tv_mode.dart';
import '../dev/balloon_game_screen.dart';
import '../dev/latency_screen.dart';
import '../dev/skeleton_screen.dart';
import '../dev/theme_preview_screen.dart';
import '../pose/pose_service.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import '../ui/widgets/tvd_button.dart';

/// Màn chính tạm thời (giai đoạn Nền tảng): lối vào các công cụ phát triển.
/// Sẽ thay bằng luồng màn hình theo design đợt 2 (hạng mục G8).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PoseSettings get _s => PoseService.instance.settings;

  void _open(Widget screen, {bool tv = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => tv ? TvModeScope(child: screen) : screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TvdSpace.s5),
          children: [
            const Center(child: TinTin(state: TinTinState.hello, size: 140)),
            const SizedBox(height: TvdSpace.s3),
            Text('Toán Vận Động', style: PhoneText.titleLarge, textAlign: TextAlign.center),
            Text('Bản phát triển · giai đoạn Nền tảng', style: PhoneText.caption, textAlign: TextAlign.center),
            const SizedBox(height: TvdSpace.s6),
            TvdButton(
              label: 'Khung xương thời gian thực',
              icon: Icons.accessibility_new,
              onPressed: () => _open(const SkeletonScreen(), tv: true),
            ),
            const SizedBox(height: TvdSpace.s3),
            TvdButton(
              label: 'Bóng bay phép tính (PoC)',
              icon: Icons.bubble_chart,
              onPressed: () => _open(const BalloonGameScreen(), tv: true),
            ),
            const SizedBox(height: TvdSpace.s3),
            TvdButton(
              label: 'Đo độ trễ TV',
              icon: Icons.timer_outlined,
              onPressed: () => _open(const LatencyScreen(), tv: true),
            ),
            const SizedBox(height: TvdSpace.s3),
            TvdButton(
              label: 'Xem design system',
              kind: TvdButtonKind.secondary,
              icon: Icons.palette_outlined,
              onPressed: () => _open(const ThemePreviewScreen()),
            ),
            const SizedBox(height: TvdSpace.s6),
            Text('Cài đặt nhận diện', style: PhoneText.title),
            SwitchListTile(
              title: const Text('Dùng camera trước'),
              subtitle: const Text('Mặc định camera sau (nét hơn, có góc rộng)'),
              value: _s.frontCamera,
              onChanged: (v) => setState(() => _s.frontCamera = v),
            ),
            SwitchListTile(
              title: const Text('Góc rộng (camera sau)'),
              value: _s.wideAngle,
              onChanged: _s.frontCamera ? null : (v) => setState(() => _s.wideAngle = v),
            ),
            SwitchListTile(
              title: const Text('Mô hình "full"'),
              subtitle: const Text('Chính xác hơn nhưng nặng hơn "lite"'),
              value: _s.fullModel,
              onChanged: (v) => setState(() => _s.fullModel = v),
            ),
            SwitchListTile(
              title: const Text('Dùng GPU'),
              subtitle: const Text('Tự lùi về CPU nếu máy không hỗ trợ'),
              value: _s.gpu,
              onChanged: (v) => setState(() => _s.gpu = v),
            ),
          ],
        ),
      ),
    );
  }
}
