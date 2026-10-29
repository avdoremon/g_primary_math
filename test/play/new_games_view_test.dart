import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/content/curriculum.dart';
import 'package:g_primary_math/content/generators/registry.dart';
import 'package:g_primary_math/game/mechanics.dart';
import 'package:g_primary_math/game/session.dart';
import 'package:g_primary_math/screens/play/mini_game_view.dart';
import 'package:g_primary_math/ui/widgets/tv_stage.dart';

Level lv(String game, String gen, int answers, Map<String, Object?> params) => Level(
      level: 2,
      questions: 10,
      secondsPerQuestion: 12,
      generator: gen,
      params: params,
      answers: answers,
      miniGame: game,
    );

void main() {
  final cases = <Level>[
    lv(MiniGames.starCatch, 'add_sub', 3, {'max': 10, 'ops': ['+']}),
    lv(MiniGames.hopTiles, 'add_sub', 3, {'max': 10, 'ops': ['+']}),
    lv(MiniGames.touchOrder, 'order_numbers', 4, {'max': 100, 'count': 4, 'ask': 'order'}),
    lv(MiniGames.tintinSays, 'add_sub', 3, {'max': 10, 'ops': ['+']}),
    lv(MiniGames.balance, 'compare', 2, {'max': 10, 'format': 'side', 'ask': 'mixed'}),
    lv(MiniGames.runRace, 'compare', 2, {'max': 10, 'format': 'side', 'ask': 'mixed'}),
    lv(MiniGames.squatGate, 'add_sub', 2, {'max': 10, 'ops': ['+', '-'], 'format': 'true_false'}),
    lv(MiniGames.clapCount, 'skip_count', 1, {'steps': [1], 'format': 'jump', 'minJumps': 3, 'maxJumps': 5}),
  ];

  for (final level in cases) {
    testWidgets('${level.miniGame}: cảnh vẽ được lúc đang hỏi và lúc có phản hồi', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final r = math.Random(5);
      final view = MiniGameView.of(level);
      for (var i = 0; i < 6; i++) {
        final q = Generators.find(level.generator)!.generate(level.genParams, r);
        final mech = AnswerMechanic.forQuestion(level, q);
        for (final fb in [false, true]) {
          final record = fb
              ? AnswerRecord(
                  index: 0,
                  question: q,
                  chosen: q.answer,
                  outcome: AnswerOutcome.correct,
                  elapsed: const Duration(seconds: 2),
                  points: 145,
                  streak: 1,
                )
              : null;
          final f = PlayFrame(level: level, question: q, mechanic: mech, feedback: record);
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: TvStage(child: Builder(builder: (c) => Stack(children: view.scene(c, f)))),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${level.miniGame} ${q.prompt}');
          // Vùng chạm màn hình khớp số đáp án (trừ Nhảy đếm / Vỗ tay không có ô).
          if (level.miniGame != MiniGames.clapCount) {
            expect(view.tapTargets(f).length, q.options.length, reason: level.miniGame);
          }
        }
      }
    });
  }
}
