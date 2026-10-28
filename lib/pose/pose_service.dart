import 'dart:async';

import 'package:flutter/services.dart';

import 'pose_frame.dart';

/// Cài đặt nhận diện, chỉnh ở màn hình chính.
class PoseSettings {
  bool frontCamera = false;
  bool fullModel = false;
  bool gpu = true;
  bool wideAngle = true;

  Map<String, Object> toMap() => {
        'front': frontCamera,
        'model': fullModel ? 'full' : 'lite',
        'gpu': gpu,
        'wide': wideAngle,
      };
}

class PoseStartInfo {
  const PoseStartInfo({
    required this.gpu,
    required this.zoom,
    required this.minZoom,
    required this.camera,
  });

  final bool gpu;
  final double zoom;
  final double minZoom;
  final String camera;

  factory PoseStartInfo.fromMap(Map<String, dynamic> m) => PoseStartInfo(
        gpu: m['gpu'] == true,
        zoom: (m['zoom'] as num?)?.toDouble() ?? 1,
        minZoom: (m['minZoom'] as num?)?.toDouble() ?? 1,
        camera: m['camera'] as String? ?? 'back',
      );
}

/// Cầu nối tới lớp nhận diện native (Kotlin + MediaPipe).
class PoseService {
  PoseService._();

  static final PoseService instance = PoseService._();

  static const _method = MethodChannel('tvd/pose');
  static const _events = EventChannel('tvd/pose/stream');

  final PoseSettings settings = PoseSettings();

  /// Đồng hồ chung cho mọi phép đo thời gian phía Dart.
  final Stopwatch clock = Stopwatch()..start();

  final _frames = StreamController<PoseFrame>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final List<Duration> _recentArrivals = [];
  StreamSubscription<dynamic>? _sub;

  double fps = 0;
  PoseStartInfo? lastStart;

  Stream<PoseFrame> get frames => _frames.stream;
  Stream<String> get errors => _errors.stream;

  Future<PoseStartInfo> start() async {
    _sub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        _errors.add(e is PlatformException ? (e.message ?? e.code) : e.toString());
      },
    );
    final res = await _method.invokeMapMethod<String, dynamic>('start', settings.toMap());
    final info = PoseStartInfo.fromMap(res ?? const {});
    lastStart = info;
    return info;
  }

  Future<void> stop() async {
    lastStart = null;
    _recentArrivals.clear();
    fps = 0;
    await _method.invokeMethod<void>('stop');
  }

  /// Giữ màn hình luôn sáng (dùng khi vào chế độ TV).
  Future<void> keepScreenOn(bool on) async {
    try {
      await _method.invokeMethod<void>('keepScreenOn', on);
    } on MissingPluginException {
      // Chạy test hoặc nền tảng chưa có lớp native: bỏ qua.
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final now = clock.elapsed;
    _recentArrivals.add(now);
    while (_recentArrivals.isNotEmpty && now - _recentArrivals.first > const Duration(seconds: 1)) {
      _recentArrivals.removeAt(0);
    }
    fps = _recentArrivals.length.toDouble();
    _frames.add(PoseFrame.fromMap(event, now));
  }
}
