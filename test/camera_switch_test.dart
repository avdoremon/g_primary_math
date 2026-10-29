import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/app/app.dart';
import 'package:g_primary_math/app/services.dart';
import 'package:g_primary_math/audio/audio_service.dart';
import 'package:g_primary_math/pose/pose_service.dart';
import 'package:g_primary_math/progress/play_settings.dart';
import 'package:g_primary_math/progress/progress_store.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

import 'app_flow_test.dart' show loadGrade, run;

/// Camera giả: bật được (không có khung hình), ghi lại các lệnh gửi xuống lớp native.
List<MethodCall> mockCamera({bool startCrashed = false}) {
  final calls = <MethodCall>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('tvd/pose'), (call) async {
    calls.add(call);
    switch (call.method) {
      case 'status':
        return {'startCrashed': startCrashed, 'lastCrash': startCrashed ? 'lỗi native' : null};
      case 'start':
        final front = (call.arguments as Map)['front'] == true;
        return {'gpu': false, 'zoom': 1.0, 'minZoom': 1.0, 'camera': front ? 'front' : 'back'};
      default:
        return null;
    }
  });
  messenger.setMockStreamHandler(
    const EventChannel('tvd/pose/stream'),
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );
  return calls;
}

Future<void> openFirstLevel(WidgetTester tester, {PlaySettings settings = const PlaySettings(breakEveryMinutes: 0)}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final g1 = loadGrade(1);
  final store = MemoryProgressStore();
  await store.createProfile(name: 'An', grade: 1);
  final services = AppServices(
    store: store,
    audio: AudioService.silent(),
    curriculum: CurriculumLibrary({1: g1, 2: loadGrade(2)}),
    settings: settings,
  );
  await tester.pumpWidget(ToanVanDongApp(services: services));
  await tester.pumpAndSettle();
  await tester.tap(find.text('An'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(g1.topics.first.title));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Level 1 ·'));
  await run(tester, 1);
}

void main() {
  test('mặc định dùng camera trước, nhận diện chạy bằng CPU', () {
    expect(const PlaySettings().frontCamera, isTrue);
    expect(PoseSettings().gpu, isFalse);
  });

  test('lưu và đọc lại camera mặc định', () async {
    final store = MemoryProgressStore();
    await const PlaySettings(frontCamera: false).save(store);
    expect((await PlaySettings.load(store)).frontCamera, isFalse);
  });

  testWidgets('vào chơi bật camera mặc định (trước)', (tester) async {
    final calls = mockCamera();
    await openFirstLevel(tester);
    final start = calls.firstWhere((c) => c.method == 'start');
    expect((start.arguments as Map)['front'], isTrue);
    expect((start.arguments as Map)['gpu'], isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('đổi camera khi đang chơi: tạm dừng, đo lại, chạm để chơi tiếp', (tester) async {
    final calls = mockCamera();
    await openFirstLevel(tester);
    // Bắt đầu bằng chạm (camera giả không có khung hình).
    await tester.tapAt(tester.getCenter(find.byType(TvStage)) + const Offset(0, 200));
    await run(tester, 0.5);
    expect(find.byKey(const ValueKey('answer-0')), findsOneWidget);

    calls.clear();
    await tester.tap(find.byKey(const ValueKey('switch-camera-corner')));
    await run(tester, 0.5);
    expect(calls.map((c) => c.method), containsAllInOrder(['stop', 'start']));
    expect((calls.lastWhere((c) => c.method == 'start').arguments as Map)['front'], isFalse);
    expect(find.text('Con giơ hai tay lên để chơi tiếp nhé!'), findsOneWidget);

    // Chạm để bỏ qua bước đo lại, câu hỏi vẫn còn.
    await tester.tapAt(tester.getCenter(find.byType(TvStage)));
    await run(tester, 0.3);
    expect(find.text('Con giơ hai tay lên để chơi tiếp nhé!'), findsNothing);
    expect(find.byKey(const ValueKey('answer-0')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lần trước bật camera bị văng: không tự bật lại, có nút Thử lại camera', (tester) async {
    final calls = mockCamera(startCrashed: true);
    await openFirstLevel(tester);
    expect(calls.where((c) => c.method == 'start'), isEmpty);
    expect(find.byKey(const ValueKey('retry-camera')), findsOneWidget);
    expect(find.text('Chạm màn hình để bắt đầu'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retry-camera')));
    await run(tester, 0.5);
    expect(calls.where((c) => c.method == 'start'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
