import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pose/pose_frame.dart';
import '../pose/pose_service.dart';

/// Dùng chung cho các màn hình cần nhận diện: bật khi vào, tắt khi rời.
mixin PoseScreenMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<PoseFrame>? _poseSub;
  StreamSubscription<String>? _errorSub;

  PoseFrame? lastFrame;
  PoseStartInfo? startInfo;
  String? poseError;

  /// Ghi đè để xử lý từng khung hình.
  void onPoseFrame(PoseFrame frame) {}

  Future<void> startPose() async {
    final service = PoseService.instance;
    _poseSub = service.frames.listen((f) {
      lastFrame = f;
      onPoseFrame(f);
    });
    _errorSub = service.errors.listen((e) {
      if (mounted) setState(() => poseError = e);
    });
    try {
      final info = await service.start();
      if (mounted) {
        setState(() {
          startInfo = info;
          poseError = null;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => poseError = e.message ?? e.code);
    } on MissingPluginException {
      if (mounted) {
        setState(() => poseError = 'Lớp nhận diện native chưa được cài (chạy lại setup).');
      }
    }
  }

  void stopPose() {
    _poseSub?.cancel();
    _errorSub?.cancel();
    PoseService.instance.stop();
  }
}
