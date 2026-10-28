import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';

/// Theme Material cho các màn điện thoại. Màn TV vẽ trong TvStage với TvText.
ThemeData buildTvdTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TvdColors.answerA,
    primary: TvdColors.answerA,
    onPrimary: TvdColors.white,
    secondary: TvdColors.answerB,
    onSecondary: TvdColors.ink,
    error: TvdColors.encourage,
    surface: TvdColors.white,
    onSurface: TvdColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TvdColors.cream,
    fontFamily: TvdFonts.body,
    textTheme: TextTheme(
      headlineMedium: PhoneText.titleLarge,
      titleLarge: PhoneText.title,
      titleMedium: PhoneText.item,
      bodyLarge: PhoneText.body,
      bodyMedium: PhoneText.body,
      labelLarge: PhoneText.button,
      bodySmall: PhoneText.caption,
    ),
    dividerColor: TvdColors.line,
  );
}
