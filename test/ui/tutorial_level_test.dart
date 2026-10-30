import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';

import 'ui_test_helpers.dart';

GameState _state(LanguagePref lang) => GameState.newGame()
  ..setLanguage(lang)
  ..claimLogin()
  ..markIntroSeen();

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<LevelPlayView> _openLevel(WidgetTester tester, int id) async {
  navigator(tester).pushNamed(AppRoutes.level, arguments: LevelArgs(id));
  await _frames(tester);
  return tester.widget<LevelPlayView>(find.byType(LevelPlayView));
}

void main() {
  testWidgets('L1 lần đầu: bật hướng dẫn "basics", câu hướng dẫn đã dịch truyền vào LevelPlayView', (tester) async {
    final state = _state(LanguagePref.vi);
    for (final s in StorySceneId.values) {
      state.markSceneSeen(s);
    }
    await pumpSugarApp(tester, state);
    final view = await _openLevel(tester, 1);
    expect(view.session.tutorial, isNotNull);
    expect(view.session.tutorial!.id, TutorialIds.basics);
    final text = view.tutorialText!;
    expect(text(TutorialSteps.basicsSell.id), 'Khách muốn bánh này. Chạm khách để bán!');
    expect(text(TutorialSteps.basicsBake.id), 'Chạm thẻ bánh để làm mẻ mới nhé!');
    expect(text(TutorialSteps.basicsTopping.id), 'Chạm hũ đúng 3 lần');
    expect(text(TutorialSteps.basicsDone.id), 'Bánh đã lên tủ. Cứ thế phục vụ thật nhiều khách nhé!');
    expect(text(TutorialSteps.comboMeter.id), 'Bán liên tục để nhân combo — tiền nhiều hơn!');
    expect(text(TutorialSteps.patienceRing.id), contains('kiên nhẫn'));
    expect(text('unknown'), '');
    // Mọi bước của 3 kịch bản đều có chữ.
    for (final id in [TutorialIds.basics, TutorialIds.combo, TutorialIds.patience]) {
      for (final step in TutorialSteps.of(id)) {
        expect(text(step.id), isNotEmpty, reason: step.id);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('hướng dẫn đã xong → chơi lại không bật; "Hướng dẫn lại" → bật lại', (tester) async {
    final state = _state(LanguagePref.en)..markTutorialDone(TutorialIds.combo);
    winLevels(state, [1]);
    await pumpSugarApp(tester, state);
    var view = await _openLevel(tester, 2);
    expect(view.session.tutorial, isNull);

    await _back(tester);
    await _frames(tester);
    state.resetTutorials();
    view = await _openLevel(tester, 2);
    expect(view.session.tutorial?.id, TutorialIds.combo);
  });

  testWidgets('thẻ Sẵn sàng L3 (mục tiêu xu): dòng nhắc "tính theo xu"; L2 không có', (tester) async {
    final state = _state(LanguagePref.en);
    winLevels(state, [1, 2]);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 3);
    expect(find.byKey(const ValueKey('level-ready-coins-hint')), findsOneWidget);
    expect(find.text('This level counts the coins you earn'), findsOneWidget);

    await _back(tester);
    await _frames(tester);
    await _openLevel(tester, 2);
    expect(find.byKey(const ValueKey('level-ready-coins-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Rời màn level (thẻ Sẵn sàng → nút Back của máy về bản đồ).
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}
