import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';
import 'package:sugarleaf_bakery/ui/intro/short_intro_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// QA smoke: mở app lần đầu (bản lưu SharedPreferences giả) → cảnh mở đầu dài có Bỏ qua → L1 → cảnh mở màn →
/// thẻ Sẵn sàng → chơi → kết quả → bản đồ; tắt app, mở lại với cùng bản lưu → intro ngắn → bản đồ, tiến trình còn.

/// Dịch vụ như main.dart nhưng lưu vào [saves] thật (SharedPreferences giả) và quảng cáo ngắn.
AppServices _services(GameState state, SaveRepository saves) {
  final base = testServices(state);
  state.attachAutosave(saves);
  return AppServices(
    state: state,
    saves: saves,
    ads: FakeAdService(state, duration: kTestAdDuration),
    iap: FakeIapService(state, delay: Duration.zero),
    audio: FakeAudioService(state),
    levels: base.levels,
    unlocks: base.unlocks,
    monetization: base.monetization,
  );
}

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Chạm qua hết cảnh truyện đang mở (nếu có).
Future<void> _skipStory(WidgetTester tester) async {
  for (var i = 0; i < 20 && find.byType(StoryOverlay).evaluate().isNotEmpty; i++) {
    await tester.tapAt(const Offset(640, 300));
    await qaFrames(tester, 3);
  }
}

/// Tự chơi như người: làm mẻ đúng khuôn / đủ vòng / lấy lò đúng lúc / phủ kín kem / đúng topping / đúng hộp, bán cho
/// mọi khách có bánh trong tủ, chạm ẩn bước hướng dẫn — tới hết giờ.
void _autoPlay(LevelSession s) {
  var guard = 0;
  while (!s.isOver && guard++ < 200000) {
    s.dismissTutorialStep();
    final k = s.kitchen;
    if (k.prep == null) s.startBatch(s.tutorial?.targetRecipe ?? s.level.menu.first);
    final prep = k.prep;
    if (prep != null && prep.stage == BatchStage.mould) s.pickMould(prep.correctMould);
    if (prep != null && prep.stage == BatchStage.mix) s.finishMix(1);
    for (var i = 0; i < k.ovens.length; i++) {
      final b = k.ovens[i];
      if (b != null && b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget) s.takeOut(i);
    }
    final fin = k.finish;
    if (fin != null && fin.stage == BatchStage.frost) s.finishFrost(1);
    if (fin != null && fin.stage == BatchStage.topping) s.addTopping(fin.correctTopping);
    if (fin != null && fin.stage == BatchStage.box) s.pickBox(fin.correctBox);
    for (final c in List.of(s.customers)) {
      s.sell(c.id);
    }
    s.advance(LevelSession.maxFrameDt);
  }
}

void main() {
  testWidgets('smoke: lần đầu → Bỏ qua → L1 → Sẵn sàng → kết quả → bản đồ; mở lại giữ tiến trình, intro ngắn',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await GameState.load(PrefsSaveRepository());
    expect(state.introSeen, isFalse);
    await pumpSugarApp(tester, state,
        services: _services(state, PrefsSaveRepository()), initialRoute: AppRoutes.initialFor(introSeen: false));

    // 1) Cảnh mở đầu dài, có nút Bỏ qua.
    expect(find.byType(IntroScreen), findsOneWidget);
    final skip = find.byKey(const ValueKey('intro-skip'));
    expect(skip, findsOneWidget);
    await qaFrames(tester, 20, 100);
    await tester.tap(skip);
    await qaFrames(tester, 20);
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(state.introSeen, isTrue);

    // 2) L1: cảnh mở màn (nếu có) → thẻ Sẵn sàng → chơi.
    await _skipStory(tester);
    final l = _l(tester);
    expect(find.text(l.levelStart), findsOneWidget);
    await tester.tap(find.text(l.levelStart));
    await qaFrames(tester, 6);
    final session = tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;
    _autoPlay(session);
    await qaFrames(tester, 10);
    if (find.text(l.levelExtraTimeNo).evaluate().isNotEmpty) {
      await tester.tap(find.text(l.levelExtraTimeNo));
    }
    await qaFrames(tester, 20);
    await tester.pumpAndSettle();

    // 3) Kết quả → bản đồ.
    expect(find.byType(LevelResultScreen), findsOneWidget);
    await tester.tap(find.text(l.mapBackToMap));
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    // Hộp quà ngày đầu (nếu có) → đóng bằng Back.
    for (var i = 0; i < 3 && navigator(tester).canPop(); i++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    final coins = state.coins;
    final stars = state.levelRecord(1)?.stars;
    final scenes = Set.of(state.seenScenes);
    final highest = state.highestCompletedLevel;
    await tester.pump(const Duration(seconds: 1)); // autosave debounce 300ms
    await state.flush();

    // 4) "Tắt app" rồi mở lại với cùng bản lưu.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    final again = await GameState.load(PrefsSaveRepository());
    expect(again.introSeen, isTrue);
    expect(again.coins, coins);
    expect(again.levelRecord(1)?.stars, stars);
    expect(again.seenScenes, scenes);
    expect(again.highestCompletedLevel, highest);
    await pumpSugarApp(tester, again,
        services: _services(again, PrefsSaveRepository()), initialRoute: AppRoutes.initialFor(introSeen: again.introSeen));
    expect(find.byType(ShortIntroScreen), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
    await qaFrames(tester, 10, 100);
    await tester.tapAt(const Offset(640, 600));
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });
}
