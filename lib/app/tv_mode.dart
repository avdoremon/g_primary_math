import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pose/pose_service.dart';

/// Chế độ hiển thị của app.
///
/// - Điện thoại (menu, hồ sơ, phụ huynh): màn hình dọc, thanh hệ thống bình thường.
/// - TV (mọi màn chơi, được phản chiếu lên TV): tự xoay ngang 16:9, ẩn thanh hệ thống,
///   giữ màn hình luôn sáng.
abstract class TvMode {
  static int _depth = 0;

  static Future<void> enter() async {
    _depth++;
    if (_depth > 1) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await PoseService.instance.keepScreenOn(true);
  }

  static Future<void> exit() async {
    if (_depth == 0) return;
    _depth--;
    if (_depth > 0) return;
    await PhoneMode.apply();
    await PoseService.instance.keepScreenOn(false);
  }
}

abstract class PhoneMode {
  static Future<void> apply() async {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

/// Bọc một màn hình chơi: vào là xoay ngang, rời đi là trả về dọc.
class TvModeScope extends StatefulWidget {
  const TvModeScope({super.key, required this.child});

  final Widget child;

  @override
  State<TvModeScope> createState() => _TvModeScopeState();
}

class _TvModeScopeState extends State<TvModeScope> {
  @override
  void initState() {
    super.initState();
    TvMode.enter();
  }

  @override
  void dispose() {
    TvMode.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
