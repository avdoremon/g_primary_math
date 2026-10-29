import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/app/app.dart';
import 'package:g_primary_math/app/services.dart';
import 'package:g_primary_math/audio/audio_service.dart';
import 'package:g_primary_math/content/question.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/progress/models.dart';
import 'package:g_primary_math/progress/play_settings.dart';
import 'package:g_primary_math/progress/progress_rules.dart';
import 'package:g_primary_math/progress/progress_store.dart';
import 'package:g_primary_math/screens/connect_tv_screen.dart';
import 'package:g_primary_math/screens/play/hud.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

import 'app_flow_test.dart' show loadGrade, mockNoCamera, run;

/// Mở app với một bé "An" lớp 1 (đã xem hướng dẫn TV).
Future<(MemoryProgressStore, Profile, AppServices)> openApp(
  WidgetTester tester, {
  PlaySettings settings = const PlaySettings(breakEveryMinutes: 0),
  Future<void> Function(MemoryProgressStore store, Profile p)? seed,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  mockNoCamera();
  final store = MemoryProgressStore();
  final p = await store.createProfile(name: 'An', grade: 1);
  await store.setSetting(ConnectTvScreen.seenKey, '1');
  if (seed != null) await seed(store, p);
  final services = AppServices(
    store: store,
    audio: AudioService.silent(),
    curriculum: CurriculumLibrary({1: loadGrade(1), 2: loadGrade(2)}),
    settings: settings,
  );
  await tester.pumpWidget(ToanVanDongApp(services: services));
  await tester.pumpAndSettle();
  return (store, p, services);
}

/// Lượt chơi có [wrong] câu sai dạng [generator] trong chủ đề [topic].
SessionResult sessionWith(String topic, String generator, {int wrong = 6, int total = 10}) {
  final q = Question(
    generator: generator,
    prompt: '1 + 1 = ?',
    speech: '',
    options: const ['2', '3'],
    answer: 0,
    explanation: '1 + 1 = 2',
    explanationSpeech: '',
  );
  return SessionResult(
    grade: 1,
    topicId: topic,
    level: 1,
    total: total,
    correct: total - wrong,
    score: 0,
    maxStreak: 0,
    answers: [
      for (var i = 0; i < total; i++)
        AnswerRecord(
          index: i,
          question: q,
          chosen: i < wrong ? 1 : 0,
          outcome: i < wrong ? AnswerOutcome.wrong : AnswerOutcome.correct,
          elapsed: const Duration(seconds: 3),
          points: 0,
          streak: 0,
        ),
    ],
    startedAt: DateTime.now(),
    playTime: const Duration(minutes: 2),
    practice: false,
  );
}

void main() {
  final g1 = loadGrade(1);

  testWidgets('Đường phiêu lưu: chủ đề sau khoá, bấm vào báo cần 3 sao; phụ huynh mở tất cả thì hết khoá', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    expect(find.text('Đường phiêu lưu · Lớp 1'), findsOneWidget);
    expect(find.text('0/${ProgressRules.maxTopicStars(g1.topics.first)}'), findsOneWidget, reason: 'chủ đề 1 mở');
    expect(find.text('Khoá'), findsWidgets);

    await tester.tap(find.text(g1.topics[1].title));
    await tester.pump();
    expect(find.textContaining('Đạt 3 sao ở chủ đề'), findsOneWidget);
    expect(find.textContaining('Level 1 ·'), findsNothing, reason: 'chủ đề khoá không mở được');

    await tester.pumpWidget(const SizedBox());
    await openApp(tester, settings: const PlaySettings(breakEveryMinutes: 0, unlockAllTopics: true));
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    expect(find.text('Khoá'), findsNothing);
    await tester.tap(find.text(g1.topics[1].title));
    await tester.pumpAndSettle();
    expect(find.textContaining('Level 1 ·'), findsOneWidget, reason: 'vào được chủ đề 2');
  });

  testWidgets('Luyện tập thêm: 10 câu, có nút Luyện tiếp, không cộng sao level', (tester) async {
    final (store, p, _) = await openApp(tester);
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(g1.topics.first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-more')));
    await run(tester, 1);

    expect(find.textContaining('Luyện tập thêm ·'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(TvStage)));
    await run(tester, 0.5);
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(const ValueKey('answer-0')), findsOneWidget, reason: 'câu ${i + 1}');
      await tester.tap(find.byKey(const ValueKey('answer-0')));
      await run(tester, 0.3);
      expect(find.byType(HudFeedbackCard), findsOneWidget);
      await run(tester, 5);
    }
    expect(find.text('Luyện tiếp'), findsOneWidget);
    expect(find.text('Chơi lại'), findsNothing);

    final records = await store.levelRecords(p.id, 1);
    final topic = g1.topics.first;
    expect(records[(topic: topic.id, level: 1)], isNull, reason: 'luyện tập không ghi vào level 1');
    expect(records[(topic: topic.id, level: GameSession.practiceLevel)], isNotNull);
    expect(await store.recentAnswers(p.id, limit: 100), hasLength(10));
  });

  testWidgets('Luyện chỗ còn sai hiện khi bé vừa sai, khu phụ huynh liệt kê dạng bài cần luyện thêm', (tester) async {
    final topic = g1.topics[0];
    await openApp(tester, seed: (store, p) => store.saveSession(p.id, sessionWith(topic.id, 'count_objects')));
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-mistakes')), findsOneWidget);
    expect(find.text('Luyện chỗ còn sai'), findsOneWidget);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-parent')));
    await tester.pumpAndSettle();
    final question = tester.widget<Text>(find.textContaining(' × ')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(question)!;
    await tester.enterText(find.byType(TextField), '${int.parse(m[1]!) * int.parse(m[2]!)}');
    await tester.tap(find.text('Vào'));
    await tester.pumpAndSettle();

    expect(find.text('An · Lớp 1'), findsOneWidget);
    expect(find.text('Cần luyện thêm'), findsOneWidget);
    expect(find.text('Đếm số đồ vật'), findsOneWidget);
    expect(find.text('4/10 đúng'), findsOneWidget);
    expect(find.text('Xem lịch sử trả lời'), findsOneWidget);
  });

  testWidgets('Kết nối TV: mở từ màn đầu, máy không mở được Smart View thì chỉ cách làm tay', (tester) async {
    await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('open-connect-tv')));
    await tester.pumpAndSettle();
    expect(find.text('Phản chiếu màn hình lên TV'), findsOneWidget);
    expect(find.text('Đặt điện thoại cạnh TV'), findsOneWidget);
    expect(find.text('Bé đứng cách 2–3 m'), findsOneWidget);

    // Kênh native giả trả về null: không có màn phản chiếu.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('tvd/pose'), (call) async => null);
    await tester.ensureVisible(find.byKey(const ValueKey('open-cast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cast')));
    await tester.pump();
    expect(find.textContaining('Kéo thanh thông báo xuống'), findsOneWidget);
  });

  testWidgets('Thử camera: không có camera thì báo lỗi, không văng', (tester) async {
    await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('open-connect-tv')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('camera-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('camera-check')));
    await tester.pumpAndSettle();
    final status = tester.widget<Text>(find.byKey(const ValueKey('camera-check-status'))).data!;
    expect(status, startsWith('Chưa mở được camera'));
    expect(tester.takeException(), isNull);
  });
}
