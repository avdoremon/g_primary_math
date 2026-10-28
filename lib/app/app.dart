import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../ui/theme/theme.dart';

class ToanVanDongApp extends StatelessWidget {
  const ToanVanDongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toán Vận Động',
      debugShowCheckedModeBanner: false,
      theme: buildTvdTheme(),
      home: const HomeScreen(),
    );
  }
}
