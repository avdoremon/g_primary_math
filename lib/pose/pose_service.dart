import 'dart:async';

import 'package:flutter/services.dart';

import 'pose_frame.dart';

/// Cài đặt nhận diện, chỉnh ở màn hình chính.
class PoseSettings {
  bool frontCamera = false;
  bool fullModel = false;
  /// GPU tắt mặc định: lỗi khởi tạo GPU nằm trong thư viện C++ nên không bắt được và làm app văng
  /// trên một số máy. CPU đủ nhanh cho mô hình lite. Bật lại ở công cụ phát triển.
  bool gpu = false;
  bool wideAngle = true;

  Map<String, Object> toMap() => {
        'front': frontCamera,
        'model': fullModel ? 'full' : 'lite',
        'gpu': gpu,
        'wide': wideAngle,
      };
}

/// Tình trạng lớp nhận diện native lúc mở app.
class PoseNativeStatus {
  const PoseNativeStatus({this.startCrashed = false, this.lastCrash});

  /// Lần trước app bị dừng khi đang bật camera: không tự bật lại, chờ người lớn bấm "Thử lại camera".
  final bool startCrashed;

  /// Mô tả lần app dừng bất thường gần nhất (để phụ huynh sao chép gửi đội phát triển).
  final String? lastCrash;
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

  /// Đọc tình trạng native; lỗi kênh (test, máy không có lớp native) coi như bình thường.
  Future<PoseNativeStatus> status() async {
    try {
      final m = await _method.invokeMapMethod<String, dynamic>('status');
      if (m == null) return const PoseNativeStatus();
      return PoseNativeStatus(startCrashed: m['startCrashed'] == true, lastCrash: m['lastCrash'] as String?);
    } catch (_) {
      return const PoseNativeStatus();
    }
  }

  /// Xoá báo lỗi lần trước sau khi phụ huynh đã xem.
  Future<void> clearCrash() async {
    try {
      await _method.invokeMethod<void>('clearCrash');
    } catch (_) {
      // Không có lớp native: bỏ qua.
    }
  }

  Future<void> stop() async {
    lastStart = null;
    _recentArrivals.clear();
    fps = 0;
    try {
      await _method.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Chạy test hoặc nền tảng chưa có lớp native: bỏ qua.
    }
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
