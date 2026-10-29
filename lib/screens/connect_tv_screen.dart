import 'dart:async';

import 'package:flutter/material.dart';

import '../app/services.dart';
import '../dev/pose_screen_mixin.dart';
import '../pose/pose_frame.dart';
import '../pose/pose_service.dart';
import '../ui/theme/theme.dart';
import '../ui/widgets/tin_tin.dart';
import '../ui/widgets/tvd_button.dart';
import 'play/hud.dart';

/// Hướng dẫn kết nối TV (design Phone-ConnectTV): phản chiếu màn hình, đặt điện thoại, bé đứng cách 2–3 m.
///
/// Tự hiện một lần trước lượt chơi đầu tiên ([showOnce]); sau đó mở lại từ nút "Kết nối TV".
class ConnectTvScreen extends StatelessWidget {
  const ConnectTvScreen({super.key, this.beforePlay = false});

  /// Đang hiện trước lượt chơi đầu tiên: nút cuối là "Để sau" (đi tiếp vào chơi).
  final bool beforePlay;

  static const seenKey = 'onboarding.tvGuideSeen';

  /// Hiện hướng dẫn nếu máy này chưa xem lần nào.
  static Future<void> showOnce(BuildContext context, AppServices app) async {
    try {
      if (await app.store.setting(seenKey) == '1') return;
      await app.store.setSetting(seenKey, '1');
    } on Object catch (e) {
      debugPrint('Không đọc được cài đặt hướng dẫn TV: $e');
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConnectTvScreen(beforePlay: true)),
    );
  }

  Future<void> _openCast(BuildContext context) async {
    final ok = await PoseService.instance.openCastSettings();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Máy này chưa mở thẳng được. Kéo thanh thông báo xuống, chọn "Smart View" hoặc "Phản chiếu màn hình".'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvdColors.cream,
      appBar: AppBar(
        title: const Text('Kết nối TV'),
        backgroundColor: TvdColors.cream,
        scrolledUnderElevation: 0,
        notificationPredicate: (_) => false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(TvdSpace.s4, 0, TvdSpace.s4, TvdSpace.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TvIllustration(),
                    SizedBox(height: TvdSpace.s3),
                    _Step(
                      n: 1,
                      title: 'Phản chiếu màn hình lên TV',
                      body: 'Wifi: kéo thanh thông báo, chọn "Smart View" / "Phản chiếu màn hình" rồi chọn TV. '
                          'Hoặc cắm cáp HDMI.',
                    ),
                    _Step(
                      n: 2,
                      title: 'Đặt điện thoại cạnh TV',
                      body: 'Dựng máy cao ngang bụng bé, camera hướng về phía bé. '
                          'Dùng camera trước hay sau thì chọn ở khu phụ huynh.',
                    ),
                    _Step(
                      n: 3,
                      title: 'Bé đứng cách 2–3 m',
                      body: 'Phòng đủ sáng, dọn đồ quanh bé. Màn TV hiện "Thấy con rồi" là sẵn sàng.',
                    ),
                  ],
                ),
              ),
            ),
            // Nút luôn nằm cuối màn như thiết kế, không phải cuộn mới thấy.
            Padding(
              padding: const EdgeInsets.fromLTRB(TvdSpace.s4, TvdSpace.s2, TvdSpace.s4, TvdSpace.s2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvdButton(
                    key: const ValueKey('open-cast'),
                    label: 'Mở Smart View',
                    icon: Icons.cast_rounded,
                    onPressed: () => _openCast(context),
                  ),
                  const SizedBox(height: TvdSpace.s2),
                  TvdButton(
                    key: const ValueKey('camera-check'),
                    label: 'Thử camera',
                    icon: Icons.videocam_rounded,
                    kind: TvdButtonKind.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const CameraCheckScreen()),
                    ),
                  ),
                  TvdButton(
                    label: beforePlay ? 'Để sau' : 'Xong',
                    kind: TvdButtonKind.text,
                    onPressed: () => Navigator.of(context).maybePop(),
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

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.body});

  final int n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: TvdSpace.s3 - 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TvdColors.white,
        borderRadius: BorderRadius.circular(TvdRadius.md),
        boxShadow: TvdShadow.phone(TvdColors.cardShadow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: TvdColors.ink, shape: BoxShape.circle),
            child: Text('$n', style: PhoneText.item.copyWith(color: TvdColors.white, fontSize: 18)),
          ),
          const SizedBox(width: TvdSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PhoneText.item.copyWith(fontSize: 17, height: 22 / 17)),
                const SizedBox(height: 2),
                Text(body, style: PhoneText.body.copyWith(fontSize: 15, color: TvdColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TV có Tin Tin, điện thoại đặt cạnh, đường sóng nét đứt, bé đứng phía trước.
class _TvIllustration extends StatelessWidget {
  const _TvIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 358 / 190,
      child: LayoutBuilder(
        builder: (context, c) {
          final k = c.maxWidth / 358;
          return ClipRRect(
            borderRadius: BorderRadius.circular(TvdRadius.md),
            child: ColoredBox(
              color: TvdColors.sky,
              child: Stack(
                children: [
                  Positioned(
                    left: 24 * k,
                    top: 26 * k,
                    width: 220 * k,
                    height: 126 * k,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TvdColors.ink,
                        borderRadius: BorderRadius.circular(12 * k),
                        border: Border.all(color: const Color(0xFF33415F), width: 6 * k),
                      ),
                      alignment: Alignment.center,
                      child: TinTin(state: TinTinState.hello, size: 70 * k),
                    ),
                  ),
                  Positioned(
                    left: 112 * k,
                    top: 158 * k,
                    width: 44 * k,
                    height: 8 * k,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF33415F),
                        borderRadius: BorderRadius.circular(4 * k),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 268 * k,
                    top: 92 * k,
                    width: 30 * k,
                    height: 56 * k,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TvdColors.ink,
                        borderRadius: BorderRadius.circular(8 * k),
                        border: Border.all(color: TvdColors.inkSoft, width: 3 * k),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 222 * k,
                    top: 52 * k,
                    width: 80 * k,
                    height: 40 * k,
                    child: CustomPaint(painter: _WavePainter()),
                  ),
                  Positioned(
                    right: 22 * k,
                    top: 100 * k,
                    width: 40 * k,
                    height: 66 * k,
                    child: CustomPaint(painter: _KidPainter()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 80;
    final path = Path()
      ..moveTo(70 * k, 30 * k)
      ..quadraticBezierTo(56 * k, 8 * k, 24 * k, 8 * k);
    final paint = Paint()
      ..color = TvdColors.answerA
      ..strokeWidth = 4 * k
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12 * k) {
        canvas.drawPath(m.extractPath(d, d + 5 * k), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

class _KidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 60;
    const c = Color(0xFF33415F);
    canvas.drawCircle(Offset(30 * k, 14 * k), 12 * k, Paint()..color = c);
    final p = Paint()
      ..color = c
      ..strokeWidth = 8 * k
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(30 * k, 28 * k), Offset(30 * k, 62 * k), p);
    canvas.drawPath(
      Path()
        ..moveTo(10 * k, 36 * k)
        ..lineTo(30 * k, 44 * k)
        ..lineTo(50 * k, 36 * k),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(18 * k, 96 * k)
        ..lineTo(30 * k, 62 * k)
        ..lineTo(42 * k, 96 * k),
      p,
    );
  }

  @override
  bool shouldRepaint(_KidPainter oldDelegate) => false;
}

/// Thử camera trên điện thoại: bé đứng vào chỗ chơi, màn hiện khung xương và "Thấy con rồi".
class CameraCheckScreen extends StatefulWidget {
  const CameraCheckScreen({super.key});

  @override
  State<CameraCheckScreen> createState() => _CameraCheckScreenState();
}

class _CameraCheckScreenState extends State<CameraCheckScreen> with PoseScreenMixin {
  late final AppServices _app = AppScope.of(context);
  late bool _front;
  bool _safeMode = false;
  bool _switching = false;
  DateTime? _seenSince;
  double _luma = -1;

  /// Thấy bé liên tục ít nhất 1 giây.
  bool get _ready => _seenSince != null && DateTime.now().difference(_seenSince!) >= const Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _front = _app.settings.frontCamera;
    PoseService.instance.settings.frontCamera = _front;
    unawaited(_init());
  }

  Future<void> _init() async {
    final st = await PoseService.instance.status();
    if (!mounted) return;
    if (st.startCrashed) {
      setState(() => _safeMode = true);
      return;
    }
    await startPose();
  }

  @override
  void onPoseFrame(PoseFrame frame) {
    if (!mounted) return;
    setState(() {
      _luma = frame.luma;
      if (frame.hasPerson) {
        _seenSince ??= DateTime.now();
      } else {
        _seenSince = null;
      }
    });
  }

  Future<void> _switch() async {
    if (_switching) return;
    _switching = true;
    stopPose();
    setState(() {
      _front = !_front;
      _seenSince = null;
      startInfo = null;
      poseError = null;
      _safeMode = false;
    });
    PoseService.instance.settings.frontCamera = _front;
    await startPose();
    _switching = false;
  }

  Future<void> _retry() async {
    setState(() => _safeMode = false);
    await startPose();
  }

  @override
  void dispose() {
    stopPose();
    super.dispose();
  }

  String get _status {
    if (_safeMode) return 'Lần trước app bị dừng khi bật camera. Bấm "Vẫn thử" để thử lại.';
    if (poseError != null) return 'Chưa mở được camera: ${poseError!.split('\n').first}';
    if (startInfo == null) return 'Đang mở camera…';
    if (_ready) return 'Thấy con rồi! Sẵn sàng chơi.';
    if (_luma >= 0 && _luma < 45) return 'Phòng hơi tối, bật thêm đèn nhé.';
    return 'Chưa thấy con. Bé đứng lùi lại cho camera thấy cả người.';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready && poseError == null && !_safeMode;
    return Scaffold(
      backgroundColor: TvdColors.cream,
      appBar: AppBar(
        title: const Text('Thử camera'),
        backgroundColor: TvdColors.cream,
        scrolledUnderElevation: 0,
        notificationPredicate: (_) => false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TvdSpace.s4),
                child: Column(
                  children: [
                    Center(child: CamTile(frame: lastFrame, seen: ready, width: 240)),
                    const SizedBox(height: TvdSpace.s4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TinTin(state: ready ? TinTinState.happy : TinTinState.wait, size: 64),
                        const SizedBox(width: TvdSpace.s3),
                        Flexible(
                          child: Text(
                            _status,
                            key: const ValueKey('camera-check-status'),
                            style: PhoneText.item.copyWith(color: ready ? TvdColors.correctDark : TvdColors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TvdSpace.s3),
                    Text(
                      'Đổi camera ở đây chỉ để thử. Camera mặc định khi chơi chọn ở khu phụ huynh.',
                      style: PhoneText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(TvdSpace.s4, TvdSpace.s2, TvdSpace.s4, TvdSpace.s2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_safeMode)
                    TvdButton(label: 'Vẫn thử', icon: Icons.refresh_rounded, onPressed: _retry)
                  else
                    TvdButton(
                      label: _front ? 'Đổi sang camera sau' : 'Đổi sang camera trước',
                      icon: Icons.cameraswitch_rounded,
                      kind: TvdButtonKind.secondary,
                      onPressed: _switch,
                    ),
                  const SizedBox(height: TvdSpace.s2),
                  TvdButton(label: 'Xong', kind: TvdButtonKind.text, onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
