import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/content/generators/generator.dart';
import 'package:g_primary_math/content/generators/registry.dart';
import 'package:g_primary_math/content/question.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/screens/play/hud.dart';
import 'package:g_primary_math/screens/play/mini_game_view.dart';
import 'package:g_primary_math/screens/play/views/cards_view.dart';
import 'package:g_primary_math/screens/play/views/simon_says_view.dart';
import 'package:g_primary_math/ui/theme/theme.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

Level simonLevel(int n, {List<String> types = const ['pose', 'step', 'touch', 'compound']}) => Level(
      level: n,
      questions: 10,
      secondsPerQuestion: 12,
      generator: 'position',
      params: {'types': types, 'scenes': ['shelf', 'table', 'tree', 'box']},
      answers: 3,
      miniGame: MiniGames.simonSays,
    );

AnswerRecord record(Question q, AnswerOutcome o, {int? chosen}) => AnswerRecord(
      index: 0,
      question: q,
      chosen: chosen ?? (o == AnswerOutcome.correct ? q.answer : null),
      outcome: o,
      elapsed: const Duration(seconds: 2),
      points: o == AnswerOutcome.correct ? 145 : 0,
      streak: o == AnswerOutcome.correct ? 1 : 0,
    );

/// Vẽ cảnh + HUD của một khung trong khung TV; lỗi bố cục (tràn, ràng buộc vô hạn) làm test hỏng.
Future<void> render(WidgetTester tester, MiniGameView view, PlayFrame f) async {
  final cam = view.camTile(f);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TvStage(
        child: Builder(
          builder: (context) => Stack(
            children: [
              ...view.scene(context, f),
              if (cam != null) cam,
              Positioned.fill(
                child: GameHud(
                  index: 2,
                  total: 10,
                  score: 300,
                  streak: 2,
                  prompt: f.question.prompt,
                  keyword: view.keyword(f),
                  remaining: .6,
                  easy: f.easy,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '${f.question.prompt} (${f.feedback?.outcome})');
}

void main() {
  testWidgets('Con nói, con làm: mọi loại lệnh, hai mức gợi ý, đúng / chưa đúng đều vẽ được', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final gen = Generators.find('position')!;
    final r = math.Random(3);
    const view = SimonSaysView();
    final seen = <String>{};
    for (final levelNo in [2, 5]) {
      final level = simonLevel(levelNo);
      for (var i = 0; i < 40; i++) {
        final q = gen.generate(level.genParams, r);
        final type = q.data['type']! as String;
        final scene = q.data['scene'] as String? ?? '';
        seen.add('$type$scene${level.hints.name}');
        final mech = AnswerMechanic.forQuestion(level, q);
        final base = PlayFrame(level: level, question: q, mechanic: mech);
        await render(tester, view, base);
        await render(tester, view, PlayFrame(level: level, question: q, mechanic: mech, feedback: record(q, AnswerOutcome.correct)));
        final wrong = q.options.length > 1 ? (q.answer + 1) % q.options.length : null;
        await render(
          tester,
          view,
          PlayFrame(level: level, question: q, mechanic: mech, feedback: record(q, AnswerOutcome.wrong, chosen: wrong)),
        );
        await render(tester, view, PlayFrame(level: level, question: q, mechanic: mech, feedback: record(q, AnswerOutcome.timeUp)));
      }
    }
    for (final k in ['pose', 'step', 'touchshelf', 'touchtree', 'touchtable', 'touchbox']) {
      expect(seen.any((s) => s.startsWith(k)), isTrue, reason: 'chưa vẽ thử "$k"');
    }
  });

  testWidgets('màn giới thiệu Con nói, con làm', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final t in [0.0, 3.0, 6.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvStage(
            child: Builder(builder: (context) => Stack(children: const SimonSaysView().intro(context, simonLevel(2), t)!)),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Con nói, con làm'), findsOneWidget);
  });

  test('vùng chạm đồ vật đủ lớn (≥ 220×200), không chồng nhau, trong màn hình', () {
    final gen = Generators.find('position')!;
    final r = math.Random(9);
    const view = SimonSaysView();
    final level = simonLevel(4, types: ['touch']);
    for (var i = 0; i < 60; i++) {
      final q = gen.generate(level.genParams, r);
      final f = PlayFrame(level: level, question: q, mechanic: AnswerMechanic.forQuestion(level, q));
      final hits = view.targets(f);
      expect(hits.length, q.options.length, reason: q.prompt);
      for (var a = 0; a < hits.length; a++) {
        expect(hits[a].width, greaterThanOrEqualTo(220), reason: q.prompt);
        expect(hits[a].height, greaterThanOrEqualTo(200), reason: q.prompt);
        expect(const Rect.fromLTWH(0, 0, TvLayout.width, TvLayout.height).intersect(hits[a]), hits[a]);
        for (var b = a + 1; b < hits.length; b++) {
          final o = hits[a].intersect(hits[b]);
          expect(o.width <= 0 || o.height <= 0, isTrue, reason: '${q.prompt}: ô $a và $b chồng nhau');
        }
      }
    }
  });

  test('từ khoá: mức dễ tô "trái"/"phải"/"tầng giữa", mức khó không tô', () {
    const view = SimonSaysView();
    const q = Question(
      generator: 'position',
      prompt: 'Chạm vào bạn thỏ ở tầng giữa',
      speech: '',
      options: ['a', 'b', 'c'],
      answer: 1,
      explanation: '',
      explanationSpeech: '',
      data: {'type': 'touch', 'scene': 'shelf', 'keyword': 'giữa'},
    );
    expect(view.keyword(PlayFrame(level: simonLevel(2), question: q))!.text, 'tầng giữa');
    expect(view.keyword(PlayFrame(level: simonLevel(5), question: q)), isNull);
    const q2 = Question(
      generator: 'position',
      prompt: 'Con giơ tay phải lên!',
      speech: '',
      options: ['Tay trái', 'Tay phải', 'Hai tay'],
      answer: 1,
      explanation: '',
      explanationSpeech: '',
      data: {'type': 'pose', 'keyword': 'phải'},
    );
    expect(view.keyword(PlayFrame(level: simonLevel(2), question: q2))!.side, 'r');
  });

  testWidgets('ô đáp án: mọi level lớp 1–2 dùng CardsView vẽ được', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = math.Random(5);
    for (final n in [1, 2]) {
      final grade = Grade.parse(File('assets/content/grade$n.json').readAsStringSync());
      for (final t in grade.topics) {
        for (final l in t.levels) {
          final view = MiniGameView.of(l);
          if (view is! CardsView) continue;
          final q = l.generate(r);
          final mech = AnswerMechanic.forQuestion(l, q);
          await render(tester, view, PlayFrame(level: l, question: q, mechanic: mech));
          await render(
            tester,
            view,
            PlayFrame(level: l, question: q, mechanic: mech, feedback: record(q, AnswerOutcome.wrong, chosen: null)),
          );
        }
      }
    }
  });

  test('dạng bài sinh đề có tham số hợp lệ cho Con nói, con làm', () {
    expect(Generators.find('position')!.validate(GenParams(simonLevel(5).params)), isEmpty);
  });
}
