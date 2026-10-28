import 'dart:async';

import 'speech_planner.dart';

/// Hiệu ứng âm thanh. File giữ chỗ trong `assets/audio/sfx/`, thay bằng âm thanh thật khi có design âm thanh.
enum Sfx {
  tap('tap'),
  correct('correct'),
  wrong('wrong'),
  timeUp('time_up'),
  levelDone('level_done'),
  star('star');

  const Sfx(this.file);

  final String file;

  String get asset => 'audio/sfx/$file.wav';
}

/// Giọng tổng hợp của máy.
abstract class TtsEngine {
  /// Chuẩn bị (chọn giọng tiếng Việt). Trả về false nếu máy không có giọng tiếng Việt.
  Future<bool> init();

  /// Đọc và chờ đọc xong.
  Future<void> speak(String text);
  Future<void> stop();
}

/// Phát file âm thanh trong assets.
abstract class ClipPlayer {
  /// Phát [asset] (tính từ thư mục `assets/`); với giọng đọc thì chờ phát xong.
  Future<void> play(String asset);
  Future<void> stop();
  Future<void> dispose();
}

class SilentTts implements TtsEngine {
  final List<String> spoken = [];

  @override
  Future<bool> init() async => true;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class SilentPlayer implements ClipPlayer {
  final List<String> played = [];

  @override
  Future<void> play(String asset) async => played.add(asset);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Dịch vụ âm thanh của app: đọc đề / lời giải thích và phát hiệu ứng.
///
/// - [say] đọc một câu: ghép ghi âm sẵn nếu đủ đoạn, còn lại dùng TTS tiếng Việt.
///   Gọi [say] mới sẽ ngắt câu đang đọc.
/// - [play] phát hiệu ứng, không chờ, không ngắt giọng đọc.
class AudioService {
  AudioService({
    required this.tts,
    required this.voicePlayer,
    required this.sfxPlayer,
    SpeechPlanner? planner,
  }) : planner = planner ?? SpeechPlanner();

  /// Không phát gì (test, máy chưa cài lớp native).
  factory AudioService.silent() =>
      AudioService(tts: SilentTts(), voicePlayer: SilentPlayer(), sfxPlayer: SilentPlayer());

  final TtsEngine tts;
  final ClipPlayer voicePlayer;
  final ClipPlayer sfxPlayer;
  SpeechPlanner planner;

  bool voiceOn = true;
  bool sfxOn = true;

  /// false khi máy không có giọng tiếng Việt (vẫn phát được ghi âm và hiệu ứng).
  bool ttsAvailable = true;

  int _generation = 0;
  bool _speaking = false;

  bool get speaking => _speaking;

  Future<void> init() async {
    try {
      ttsAvailable = await tts.init();
    } on Object {
      ttsAvailable = false;
    }
  }

  /// Đọc [text]; trả về khi đọc xong hoặc bị ngắt.
  Future<void> say(String text) async {
    final gen = ++_generation;
    await _stopVoice();
    if (!voiceOn || text.trim().isEmpty) return;
    _speaking = true;
    try {
      for (final part in planner.plan(text)) {
        if (gen != _generation) return;
        switch (part) {
          case ClipPart(:final asset):
            await voicePlayer.play(asset);
          case TtsPart(text: final sentence):
            if (ttsAvailable) await tts.speak(sentence);
          case PausePart(:final duration):
            await Future<void>.delayed(duration);
        }
      }
    } on Object {
      // Âm thanh lỗi không được làm hỏng lượt chơi.
    } finally {
      if (gen == _generation) _speaking = false;
    }
  }

  void play(Sfx sfx) {
    if (!sfxOn) return;
    unawaited(sfxPlayer.play(sfx.asset).catchError((Object _) {}));
  }

  Future<void> stop() async {
    _generation++;
    _speaking = false;
    await _stopVoice();
  }

  Future<void> _stopVoice() async {
    try {
      await voicePlayer.stop();
      await tts.stop();
    } on Object {
      // bỏ qua
    }
  }

  Future<void> dispose() async {
    await stop();
    await voicePlayer.dispose();
    await sfxPlayer.dispose();
  }
}
