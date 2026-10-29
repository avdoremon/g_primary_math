import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'audio_service.dart';
import 'speech_planner.dart';

/// TTS tiếng Việt của Android (Google Text-to-Speech). Đọc chậm, giọng hơi cao cho trẻ nhỏ.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();

  static const language = 'vi-VN';
  static const rate = 0.42;
  static const pitch = 1.1;

  @override
  Future<bool> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final available = await _tts.isLanguageAvailable(language);
      if (available != true) return false;
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Phát file trong assets bằng audioplayers.
class AssetClipPlayer implements ClipPlayer {
  AssetClipPlayer({this.waitForCompletion = true, this.maxClip = const Duration(seconds: 8)});

  /// Giọng đọc: chờ phát xong mới phát đoạn sau. Hiệu ứng: không chờ.
  final bool waitForCompletion;
  final Duration maxClip;
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String asset) async {
    try {
      if (!waitForCompletion) {
        await _player.stop();
        await _player.play(AssetSource(asset));
        return;
      }
      final done = _player.onPlayerComplete.first;
      await _player.play(AssetSource(asset));
      await done.timeout(maxClip, onTimeout: () {});
    } on MissingPluginException {
      // Chưa cài plugin (chạy test / máy dev): bỏ qua.
    } on PlatformException {
      // File lỗi hoặc thiếu: bỏ qua, không làm hỏng lượt chơi.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on MissingPluginException {
      // bỏ qua
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } on MissingPluginException {
      // bỏ qua
    }
  }
}

/// Tạo dịch vụ âm thanh cho máy thật: đọc danh sách ghi âm có sẵn
/// (`assets/audio/voice/manifest.json`), còn lại dùng TTS.
Future<AudioService> createPlatformAudio() async {
  var clips = const <String>[];
  try {
    final raw = await rootBundle.loadString('assets/audio/voice/manifest.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    clips = [for (final c in json['clips'] as List<dynamic>? ?? const []) c.toString()];
  } on Object {
    // Chưa có ghi âm: dùng TTS cho mọi câu.
  }
  final service = AudioService(
    tts: FlutterTtsEngine(),
    voicePlayer: AssetClipPlayer(),
    sfxPlayer: AssetClipPlayer(waitForCompletion: false),
    planner: SpeechPlanner(clips: clips),
  );
  await service.init();
  return service;
}
