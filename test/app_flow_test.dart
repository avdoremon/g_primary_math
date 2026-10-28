import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/app/app.dart';
import 'package:g_primary_math/app/services.dart';
import 'package:g_primary_math/audio/audio_service.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/progress/play_settings.dart';
import 'package:g_primary_math/progress/progress_store.dart';
import 'package:g_primary_math/screens/play/play_widgets.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

Grade loadGrade(int n) => Grade.parse(File('assets/content/grade$n.json').readAsStringSync());

/// Máy test không có camera: lớp native báo lỗi khi bật, các lệnh khác không làm gì.
void mockNoCamera() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('tvd/pose'), (call) async {
    if (call.method == 'start') throw PlatformException(code: 'no_camera', message: 'Không có camera');
    return null;
  });
  messenger.setMockStreamHandler(
    const EventChannel('tvd/pose/stream'),
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );
}

/// Chạy đồng hồ [seconds] giây theo từng khung 100 ms (vòng lặp game giới hạn mỗi khung 0,1 giây).
Future<void> run(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 10).round(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('tạo hồ sơ → chủ đề → level → chơi hết 10 câu bằng chạm → lưu tiến độ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    mockNoCamera();

    final g1 = loadGrade(1);
    final store = MemoryProgressStore();
    final services = AppServices(
      store: store,
      audio: AudioService.silent(),
      curriculum: CurriculumLibrary({1: g1, 2: loadGrade(2)}),
      settings: const PlaySettings(breakEveryMinutes: 0),
    );

    await tester.pumpWidget(ToanVanDongApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('Tạo hồ sơ cho bé để bắt đầu'), findsOneWidget);

    // Tạo hồ sơ.
    await tester.tap(find.text('Thêm bé'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'An');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('An'), findsOneWidget);

    // Chủ đề → level.
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    final topic = g1.topics.first;
    await tester.tap(find.text(topic.title));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đạt 1 sao ở level 1'), findsOneWidget, reason: 'level 2 đang khoá');
    await tester.tap(find.textContaining('Level 1 ·'));
    await run(tester, 1);

    // Màn chơi: không có camera thì chạm để bắt đầu.
    expect(find.text('Chạm màn hình để bắt đầu'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(TvStage)));
    await run(tester, 0.5);

    for (var i = 0; i < topic.levels.first.questions; i++) {
      expect(find.byType(AnswerCard), findsWidgets, reason: 'câu ${i + 1} phải có ô đáp án');
      await tester.tap(find.byType(AnswerCard).first);
      await run(tester, 0.3);
      expect(find.byType(FeedbackPanel), findsOneWidget);
      await run(tester, 5);
    }

    expect(find.text('Chơi lại'), findsOneWidget);
    expect(find.text('Về menu'), findsOneWidget);
    final profile = (await store.profiles()).single;
    final rec = (await store.levelRecords(profile.id, 1))[(topic: topic.id, level: 1)];
    expect(rec, isNotNull);
    expect(rec!.plays, 1);
    expect((await store.recentAnswers(profile.id, limit: 100)).length, 10);
  });

  testWidgets('hết giới hạn chơi trong ngày thì không vào level mới', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    mockNoCamera();

    final g1 = loadGrade(1);
    final store = MemoryProgressStore();
    final p = await store.createProfile(name: 'Bình', grade: 1);
    // Hôm nay đã chơi 31 phút (giới hạn mặc định 30 phút).
    await store.saveSession(
      p.id,
      SessionResult(
        grade: 1,
        topicId: g1.topics.first.id,
        level: 1,
        total: 10,
        correct: 0,
        score: 0,
        maxStreak: 0,
        answers: const [],
        startedAt: DateTime.now(),
        playTime: const Duration(minutes: 31),
        practice: false,
      ),
    );
    final services = AppServices(
      store: store,
      audio: AudioService.silent(),
      curriculum: CurriculumLibrary({1: g1, 2: loadGrade(2)}),
      settings: const PlaySettings(),
    );

    await tester.pumpWidget(ToanVanDongApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bình'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(g1.topics.first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Level 1 ·'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay con chơi đủ rồi!'), findsOneWidget);
    expect(find.byType(TvStage), findsNothing, reason: 'không mở màn chơi');
  });
}
