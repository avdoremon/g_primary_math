import 'package:flutter/material.dart';

import '../pose/pose_frame.dart';
import '../pose/pose_service.dart';
import 'pose_screen_mixin.dart';
import 'skeleton_painter.dart';

/// Màn 1: khung xương thời gian thực + chỉ số hiệu năng + kiểm tra "đứng vào khung".
class SkeletonScreen extends StatefulWidget {
  const SkeletonScreen({super.key});

  @override
  State<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends State<SkeletonScreen> with PoseScreenMixin {
  final List<int> _processing = [];
  final List<double> _luma = [];

  @override
  void initState() {
    super.initState();
    startPose();
  }

  @override
  void dispose() {
    stopPose();
    super.dispose();
  }

  @override
  void onPoseFrame(PoseFrame frame) {
    _processing.add(frame.processingMs);
    if (_processing.length > 30) _processing.removeAt(0);
    _luma.add(frame.luma);
    if (_luma.length > 30) _luma.removeAt(0);
    if (mounted) setState(() {});
  }

  double _avg(List<num> v) => v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

  @override
  Widget build(BuildContext context) {
    final f = lastFrame;
    final fps = PoseService.instance.fps;
    final lightOk = _avg(_luma) >= 50;
    final ready = f != null && f.seesWholeBody && lightOk;

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SkeletonPainter(f, color: const Color(0xFF7FE3B0), showFrame: true),
                    ),
                  ),
                  if (f != null && !f.hasPerson)
                    const Center(
                      child: Text('Chưa thấy người trong khung hình',
                          style: TextStyle(color: Colors.white70, fontSize: 22)),
                    ),
                  if (poseError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Lỗi: $poseError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFF9C6B), fontSize: 18)),
                      ),
                    ),
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
            ),
            Expanded(
              flex: 2,
              child: Container(
                color: const Color(0xFF17232E),
                padding: const EdgeInsets.all(20),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  child: ListView(
                    children: [
                      _stat('Khung hình/giây', fps.toStringAsFixed(0), good: fps >= 25),
                      _stat('Thời gian xử lý (TB 30 khung)', '${_avg(_processing).toStringAsFixed(0)} ms',
                          good: _avg(_processing) <= 60),
                      _stat('Bộ xử lý', startInfo == null ? '…' : (startInfo!.gpu ? 'GPU' : 'CPU')),
                      _stat('Camera',
                          startInfo == null ? '…' : '${startInfo!.camera == 'front' ? 'trước' : 'sau'} · zoom ${startInfo!.zoom.toStringAsFixed(2)}x'),
                      _stat('Ảnh phân tích', f == null ? '…' : '${f.imageWidth}×${f.imageHeight}'),
                      const Divider(color: Colors.white24, height: 28),
                      const Text('Đứng vào khung', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 8),
                      _check('Thấy đầu', f?.seesHead ?? false),
                      _check('Thấy hai tay', f?.seesBothHands ?? false),
                      _check('Thấy hai chân', f?.seesBothFeet ?? false),
                      _check('Đủ sáng (vùng giữa khung)', lightOk),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ready ? const Color(0xFF1FA35B) : const Color(0xFF3A4A58),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ready ? 'Sẵn sàng chơi!' : 'Lùi ra xa hoặc chỉnh góc máy cho đến khi đủ 4 mục',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool? good}) {
    final color = good == null ? Colors.white : (good ? const Color(0xFF7FE3B0) : const Color(0xFFFFB36B));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _check(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              color: ok ? const Color(0xFF7FE3B0) : Colors.white38),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
