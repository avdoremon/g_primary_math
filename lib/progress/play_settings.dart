import 'progress_store.dart';

/// Cài đặt phụ huynh. Lưu trong bảng settings, dùng chung cho mọi hồ sơ trên máy.
class PlaySettings {
  const PlaySettings({
    this.dailyLimitMinutes = 30,
    this.breakEveryMinutes = 15,
    this.voice = true,
    this.soundEffects = true,
    this.practiceMode = false,
    this.frontCamera = true,
    this.unlockAllTopics = false,
  });

  /// Giới hạn chơi mỗi ngày của mỗi bé; 0 = không giới hạn.
  final int dailyLimitMinutes;

  /// Nhắc nghỉ sau ngần này phút chơi liên tục; 0 = không nhắc.
  final int breakEveryMinutes;

  /// Đọc đề và lời giải thích thành tiếng.
  final bool voice;
  final bool soundEffects;

  /// Chế độ luyện tập: bỏ đếm giờ ở mọi level.
  final bool practiceMode;

  /// Camera mặc định khi vào chơi: true = camera trước (màn hình quay về phía bé, cách thử quen thuộc nhất),
  /// false = camera sau (đặt máy cạnh TV, góc rộng và nét hơn).
  final bool frontCamera;

  /// Mở mọi chủ đề trên Đường phiêu lưu (khi trên lớp học khác thứ tự, hoặc bé học trước).
  final bool unlockAllTopics;

  static const dailyLimitChoices = [0, 15, 20, 30, 45, 60];
  static const breakChoices = [0, 10, 15, 20, 30];

  PlaySettings copyWith({
    int? dailyLimitMinutes,
    int? breakEveryMinutes,
    bool? voice,
    bool? soundEffects,
    bool? practiceMode,
    bool? frontCamera,
    bool? unlockAllTopics,
  }) =>
      PlaySettings(
        dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
        breakEveryMinutes: breakEveryMinutes ?? this.breakEveryMinutes,
        voice: voice ?? this.voice,
        soundEffects: soundEffects ?? this.soundEffects,
        practiceMode: practiceMode ?? this.practiceMode,
        frontCamera: frontCamera ?? this.frontCamera,
        unlockAllTopics: unlockAllTopics ?? this.unlockAllTopics,
      );

  static const _kDaily = 'play.dailyLimitMinutes';
  static const _kBreak = 'play.breakEveryMinutes';
  static const _kVoice = 'play.voice';
  static const _kSfx = 'play.soundEffects';
  static const _kPractice = 'play.practiceMode';
  static const _kFront = 'play.frontCamera';
  static const _kUnlockAll = 'play.unlockAllTopics';

  static Future<PlaySettings> load(ProgressStore store) async {
    const d = PlaySettings();
    int intOf(String? v, int fallback) => int.tryParse(v ?? '') ?? fallback;
    bool boolOf(String? v, bool fallback) => v == null ? fallback : v == '1';
    return PlaySettings(
      dailyLimitMinutes: intOf(await store.setting(_kDaily), d.dailyLimitMinutes),
      breakEveryMinutes: intOf(await store.setting(_kBreak), d.breakEveryMinutes),
      voice: boolOf(await store.setting(_kVoice), d.voice),
      soundEffects: boolOf(await store.setting(_kSfx), d.soundEffects),
      practiceMode: boolOf(await store.setting(_kPractice), d.practiceMode),
      frontCamera: boolOf(await store.setting(_kFront), d.frontCamera),
      unlockAllTopics: boolOf(await store.setting(_kUnlockAll), d.unlockAllTopics),
    );
  }

  Future<void> save(ProgressStore store) async {
    await store.setSetting(_kDaily, '$dailyLimitMinutes');
    await store.setSetting(_kBreak, '$breakEveryMinutes');
    await store.setSetting(_kVoice, voice ? '1' : '0');
    await store.setSetting(_kSfx, soundEffects ? '1' : '0');
    await store.setSetting(_kPractice, practiceMode ? '1' : '0');
    await store.setSetting(_kFront, frontCamera ? '1' : '0');
    await store.setSetting(_kUnlockAll, unlockAllTopics ? '1' : '0');
  }
}
