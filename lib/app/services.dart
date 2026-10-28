import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../audio/audio_service.dart';
import '../audio/platform_audio.dart';
import '../content/curriculum.dart';
import '../game/play_guard.dart';
import '../progress/play_settings.dart';
import '../progress/progress_store.dart';
import '../progress/sqlite_progress_store.dart';

/// Chương trình các lớp đã có nội dung.
class CurriculumLibrary {
  CurriculumLibrary(this.grades);

  /// Lớp có nội dung trong bản này (MVP: lớp 1, 2).
  static const availableGrades = [1, 2];

  final Map<int, Grade> grades;

  Grade? grade(int n) => grades[n];

  static Future<CurriculumLibrary> load(AssetBundle bundle) async {
    final grades = <int, Grade>{};
    for (final n in availableGrades) {
      grades[n] = Grade.parse(await bundle.loadString('assets/content/grade$n.json'));
    }
    return CurriculumLibrary(grades);
  }
}

/// Các dịch vụ dùng chung của app, tạo một lần khi khởi động.
class AppServices {
  AppServices({required this.store, required this.audio, required this.curriculum, required PlaySettings settings})
      : _settings = settings {
    _applyAudio();
  }

  final ProgressStore store;
  final AudioService audio;
  final CurriculumLibrary curriculum;
  PlaySettings _settings;

  /// Quy tắc thời gian chơi theo từng hồ sơ (tạo khi chọn hồ sơ).
  final Map<int, PlayGuard> _guards = {};
  final Map<int, DateTime> _guardDay = {};
  final Map<int, DateTime> _lastPlayEnd = {};

  PlaySettings get settings => _settings;

  Future<void> updateSettings(PlaySettings s) async {
    _settings = s;
    for (final g in _guards.values) {
      g.settings = s;
    }
    _applyAudio();
    await s.save(store);
  }

  void _applyAudio() {
    audio.voiceOn = _settings.voice;
    audio.sfxOn = _settings.soundEffects;
  }

  /// Quy tắc thời gian của một bé, nạp thời gian đã chơi hôm nay từ lịch sử.
  Future<PlayGuard> guardFor(int profileId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var g = _guards[profileId];
    if (g == null || _guardDay[profileId] != today) {
      g = PlayGuard(settings: _settings, playedToday: await store.playTimeOn(profileId, now));
      _guards[profileId] = g;
      _guardDay[profileId] = today;
    }
    // Thời gian rời màn chơi được tính là nghỉ.
    final last = _lastPlayEnd[profileId];
    if (last != null) g.idle(now.difference(last));
    return g;
  }

  /// Ghi nhận vừa chơi xong một level.
  void playedFor(int profileId, Duration playTime) {
    _guards[profileId]?.addPlay(playTime);
    _lastPlayEnd[profileId] = DateTime.now();
  }

  /// Khởi động: mở SQLite (lỗi thì lưu tạm trong bộ nhớ), âm thanh (lỗi thì im lặng), chương trình học.
  static Future<AppServices> create() async {
    ProgressStore store;
    try {
      store = await SqliteProgressStore.open();
    } on Object catch (e) {
      debugPrint('Không mở được SQLite, lưu tạm trong bộ nhớ: $e');
      store = MemoryProgressStore();
    }
    AudioService audio;
    try {
      audio = await createPlatformAudio();
    } on Object catch (e) {
      debugPrint('Không khởi động được âm thanh: $e');
      audio = AudioService.silent();
    }
    final curriculum = await CurriculumLibrary.load(rootBundle);
    final settings = await PlaySettings.load(store);
    return AppServices(store: store, audio: audio, curriculum: curriculum, settings: settings);
  }
}

/// Đưa [AppServices] xuống cây widget.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Thiếu AppScope phía trên cây widget');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
