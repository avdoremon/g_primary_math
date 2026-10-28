import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/tv_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Menu và màn phụ huynh chạy dọc trên điện thoại; màn chơi tự xoay ngang qua TvModeScope.
  await PhoneMode.apply();
  runApp(const ToanVanDongApp());
}
