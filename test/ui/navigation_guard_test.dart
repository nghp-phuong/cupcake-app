import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

LevelResult _lost(int levelId) => LevelResult(
      levelId: levelId,
      won: false,
      stars: 0,
      coins: 40,
      served: 2,
      lost: 3,
      specialsDone: 0,
      bestCombo: 1,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: 2,
      fiveStarTreats: 0,
    );

void main() {
  testWidgets('bản đồ: bấm đúp nút chỉ mở một màn', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state);

    // Gọi thẳng 2 lần trong cùng một khung hình (hai lần chạm lọt qua trước khi route mới kịp che nút).
    final store = tester.widget<SLButton>(find.byWidgetPredicate((w) => w is SLButton && w.tooltip == 'Store'));
    store.onPressed!();
    store.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen, skipOffstage: false), findsOneWidget);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(find.byType(StoreScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bản đồ: bấm đúp nút level chỉ mở một màn chơi', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin()
      ..markSceneSeen(StorySceneId.prologue);
    await pumpSugarApp(tester, state);

    final node = tester.widget<SLPressable>(
      find.descendant(of: find.byKey(const ValueKey('map-level-1')), matching: find.byType(SLPressable)),
    );
    node.onPressed!();
    node.onPressed!();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(LevelScreen, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn chơi → kết quả (pushReplacement) → bản đồ: làm mới ngày lịch và tự mở quà', (tester) async {
    var now = DateTime(2026, 3, 10, 23, 50);
    final state = GameState.newGame(clock: () => now)
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state);
    expect(find.text('Claim'), findsNothing);

    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(_lost(1)));
    await tester.pumpAndSettle();
    expect(find.text('Map'), findsOneWidget);

    // Qua nửa đêm trong lúc xem kết quả.
    now = DateTime(2026, 3, 11, 0, 5);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.quests.map((q) => q.type), GameState.questTypesFor('2026-03-11'));
    expect(find.text('Claim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
