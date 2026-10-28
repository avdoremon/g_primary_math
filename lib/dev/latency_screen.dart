import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pose/pose_frame.dart';
import '../pose/pose_service.dart';
import 'pose_screen_mixin.dart';

/// Màn 3: đo độ trễ "màn hình -> camera".
///
/// Màn hình nháy trắng; camera nhìn vào màn hình (TV đang phản chiếu, hoặc gương)
/// và báo lúc thấy sáng lên. Đo cả hai cách kết nối rồi lấy hiệu số để biết
/// phản chiếu Wifi chậm hơn cáp HDMI bao nhiêu.
class LatencyScreen extends StatefulWidget {
  const LatencyScreen({super.key});

  @override
  State<LatencyScreen> createState() => _LatencyScreenState();
}

class _LatencyScreenState extends State<LatencyScreen> with PoseScreenMixin {
  static const _trials = 10;
  static const _lumaJump = 35.0;

  final _random = math.Random();
  final List<double> _recentLuma = [];
  final List<int> _recentProcessing = [];
  final List<int?> _results = [];

  bool _running = false;
  bool _white = false;
  Duration _t0 = Duration.zero;
  double _threshold = 999;
  Completer<int?>? _pending;

  @override
  void initState() {
    super.initState();
    startPose();
  }

  @override
  void dispose() {
    _running = false;
    stopPose();
    super.dispose();
  }

  @override
  void onPoseFrame(PoseFrame frame) {
    _recentLuma.add(frame.luma);
    if (_recentLuma.length > 20) _recentLuma.removeAt(0);
    _recentProcessing.add(frame.processingMs);
    if (_recentProcessing.length > 30) _recentProcessing.removeAt(0);

    final p = _pending;
    if (p != null && !p.isCompleted && frame.luma > _threshold) {
      p.complete((frame.arrival - _t0).inMilliseconds);
    }
    if (!_running && mounted) setState(() {});
  }

  double _median(List<num> v) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[s.length ~/ 2].toDouble();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    for (var i = 0; i < _trials; i++) {
      if (!mounted || !_running) return;
      setState(() => _white = false);
      await Future<void>.delayed(Duration(milliseconds: 1000 + _random.nextInt(1000)));
      if (!mounted || !_running) return;

      _threshold = _median(_recentLuma) + _lumaJump;
      final completer = Completer<int?>();
      setState(() => _white = true);
      // Mốc thời gian lấy ngay sau khi khung hình trắng được dựng.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _t0 = PoseService.instance.clock.elapsed;
        _pending = completer;
      });

      final r = await completer.future.timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
      _pending = null;
      if (!mounted) return;
      setState(() {
        _white = false;
        _results.add(r);
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _results.whereType<int>().toList();
    final median = _median(ok);
    final processing = _median(_recentProcessing);
    final textColor = _white ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: _white ? Colors.white : Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (!_running)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(72, 24, 24, 24),
                  child: DefaultTextStyle(
                    style: TextStyle(color: textColor, fontSize: 16, height: 1.4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              const Text('Đo độ trễ màn hình → camera',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              const Text('Đo với TV (Wifi hoặc HDMI):', style: TextStyle(fontWeight: FontWeight.w700)),
                              const Text('1. Bật phản chiếu màn hình điện thoại lên TV.\n'
                                  '2. Dùng camera sau, hướng camera vào giữa màn hình TV, cách khoảng 1 m.\n'
                                  '3. Bấm "Bắt đầu đo" và giữ yên máy khoảng 25 giây.'),
                              const SizedBox(height: 12),
                              const Text('Đo mốc không qua TV:', style: TextStyle(fontWeight: FontWeight.w700)),
                              const Text('Bật "Dùng camera trước" ở màn hình chính, tắt phản chiếu, '
                                  'cầm máy soi vào gương để camera trước nhìn thấy màn hình của chính nó.'),
                              const SizedBox(height: 12),
                              const Text('Lấy kết quả TV trừ kết quả mốc = độ trễ do phản chiếu.'),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: startInfo == null ? null : _run,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Bắt đầu đo'),
                                ),
                              ),
                              if (poseError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text('Lỗi: $poseError', style: const TextStyle(color: Color(0xFFFF9C6B))),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 300,
                          child: ListView(
                            children: [
                              const Text('Kết quả', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text('Độ sáng hiện tại: ${_median(_recentLuma).toStringAsFixed(0)}'),
                              Text('Thời gian nhận diện: ${processing.toStringAsFixed(0)} ms'),
                              const SizedBox(height: 8),
                              for (var i = 0; i < _results.length; i++)
                                Text('Lần ${i + 1}: ${_results[i] == null ? 'không bắt được' : '${_results[i]} ms'}'),
                              if (ok.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Trung vị: ${median.toStringAsFixed(0)} ms',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                Text('Trừ thời gian nhận diện: ≈ ${(median - processing).toStringAsFixed(0)} ms'),
                                Text('Bắt được ${ok.length}/${_results.length} lần'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_running)
              Positioned(
                left: 16,
                bottom: 12,
                child: Text('Đang đo ${_results.length + 1}/$_trials…',
                    style: TextStyle(color: _white ? Colors.black26 : Colors.white24)),
              ),
            Positioned(
              left: 8,
              top: 8,
              child: IconButton.filledTonal(
                onPressed: () {
                  _running = false;
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
