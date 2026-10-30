import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/common/art.dart';
import 'package:sugarleaf_bakery/ui/common/currency_bar.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/map/map_art.dart';
import 'package:sugarleaf_bakery/ui/map/map_node.dart';
import 'package:sugarleaf_bakery/ui/recipes/recipe_book_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

/// GĐ8B: nền truyện mới + bà Rosa trong hội thoại, Bí quyết của bà trong sổ công thức, bản đồ chương 3–5.

final _config = testLevelConfig();

/// Ván đã qua L1..L[cleared] (3★, không thêm xu), đã nhận quà hôm nay.
GameState _state({LanguagePref lang = LanguagePref.en, int cleared = 41, Map<RecipeId, int> recipeStars = const {}}) {
  final state = GameState.newGame()
    ..setLanguage(lang)
    ..claimLogin()
    ..markSceneSeen(StorySceneId.prologue);
  state
    ..attachLevelConfig(_config)
    ..attachUnlockConfig(testUnlockConfig());
  winLevels(state, [for (var id = 1; id < cleared; id++) id], coins: 0);
  if (cleared > 0) {
    state.applyLevelResult(
      LevelResult(
        levelId: cleared,
        won: true,
        stars: 3,
        coins: 0,
        served: 7,
        lost: 0,
        specialsDone: 1,
        bestCombo: 4,
        perfectBakes: 1,
        recipeStars: recipeStars,
        goalValue: 9,
        fiveStarTreats: 1,
      ),
    );
  }
  return state;
}

AppLocalizations _l(WidgetTester tester, Type on) => AppLocalizations.of(tester.element(find.byType(on)));

// ------------------------------------------------------------------ Truyện

Future<void> _pumpStory(WidgetTester tester, StorySceneId id) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  LevelMapScreen.giftShownThisSession = true;
  final state = GameState.newGame()
    ..setLanguage(LanguagePref.vi)
    ..claimLogin();
  await tester.pumpWidget(
    SugarleafApp(
      services: testServices(state),
      useGoogleFonts: false,
      onGenerateRoute: (settings) => fadeRoute(settings, StoryOverlay(scene: Catalog.storyScene(id), onFinished: () {})),
    ),
  );
  // Mũi tên "chạm để tiếp" nhún liên tục → không pumpAndSettle.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ------------------------------------------------------------------ Sổ công thức

Future<void> _openBook(WidgetTester tester, GameState state) async {
  await pumpSugarApp(tester, state, services: testServices(state, levels: _config));
  navigator(tester).pushNamed(AppRoutes.recipes);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, RecipeId id) async {
  final tiles = find.descendant(of: find.byType(RecipeGrid), matching: find.byType(SLPressable));
  await tester.tap(tiles.at(Catalog.recipes.indexWhere((r) => r.id == id)));
  await tester.pumpAndSettle();
}

const _buy = ValueKey('recipe-secret-buy');

double _buyOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.ancestor(of: find.byKey(_buy), matching: find.byType(Opacity)).first).opacity;

// ------------------------------------------------------------------ Bản đồ

Finder _node(int id) => find.byKey(ValueKey('map-level-$id'));

Future<void> _pumpMap(WidgetTester tester, GameState state) async {
  await pumpSugarApp(tester, state, services: testServices(state, levels: _config));
  LevelMapScreen.giftShownThisSession = true;
}

Future<void> _nextChapter(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('map-next')));
  await tester.pumpAndSettle();
}

void main() {
  group('truyện GĐ8', () {
    test('nền: ảnh vườn / gác / lễ hội chưa có → nền dự phòng; nền có sẵn giữ nguyên', () {
      for (final id in [StorySceneId.ch3Open, StorySceneId.ch4Open, StorySceneId.ch5Open, StorySceneId.hoa4]) {
        final scene = Catalog.storyScene(id);
        expect(scene.backdrop.fallback, isNotNull, reason: id.name);
        // Trong test ảnh không nạp được (chưa có / chưa nạp) → luôn ra nền dự phòng, không bao giờ trống.
        expect(backdropOf(scene), scene.backdrop.fallback, reason: id.name);
      }
      expect(backdropOf(Catalog.storyScene(StorySceneId.prologue)), ArtScene.storyTown);
      expect(backdropOf(Catalog.storyScene(StorySceneId.hoa1)), ArtScene.storyGrandmaKitchen);
      expect(backdropOf(Catalog.storyScene(StorySceneId.rosa1)), Catalog.storyScene(StorySceneId.rosa1).backdrop);
    });

    test('người đứng trái: bạn quen của cảnh, bà Rosa khi bà có thoại, không ai ở cảnh chỉ Mai + người kể', () {
      expect(guestSpeakerOf(Catalog.storyScene(StorySceneId.hoa1)), Speaker.hoa);
      expect(guestSpeakerOf(Catalog.storyScene(StorySceneId.rosa1)), Speaker.rosa);
      expect(guestSpeakerOf(Catalog.storyScene(StorySceneId.rosa2)), Speaker.rosa);
      expect(guestSpeakerOf(Catalog.storyScene(StorySceneId.ch3Open)), isNull);
    });

    testWidgets('cảnh bà Rosa: ảnh Rosa bên trái, Mai bên phải, dải tên "Bà Rosa", chạm sang dòng Mai', (tester) async {
      await _pumpStory(tester, StorySceneId.rosa1);
      final l = _l(tester, StoryOverlay);
      final scene = Catalog.storyScene(StorySceneId.rosa1);
      expect(scene.lines.first.speaker, Speaker.rosa);

      final rosa = find.byWidgetPredicate((w) => w is SpeakerImage && w.speaker == Speaker.rosa);
      final mai = find.byWidgetPredicate((w) => w is SpeakerImage && w.speaker == Speaker.mai);
      expect(rosa, findsOneWidget);
      expect(mai, findsOneWidget);
      expect(tester.getCenter(rosa).dx, lessThan(640));
      expect(tester.getCenter(mai).dx, greaterThan(640));
      expect(find.text(l.charRosa), findsOneWidget);
      expect(l.charRosa, 'Bà Rosa');
      // Người đang nói sáng (1), người kia mờ.
      double opacityOf(Finder f) => tester.widget<AnimatedOpacity>(find.ancestor(of: f, matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacityOf(rosa), 1);
      expect(opacityOf(mai), lessThan(1));

      final maiLine = scene.lines.indexWhere((x) => x.speaker == Speaker.mai);
      for (var i = 0; i < maiLine; i++) {
        await tester.tap(find.byType(SLSpeechBubble));
        for (var k = 0; k < 6; k++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
      expect(find.text(l.charMai), findsOneWidget);
      expect(opacityOf(mai), 1);
      expect(opacityOf(rosa), lessThan(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cảnh lễ hội (ảnh chưa có): dựng nền dự phòng phố biển, không lỗi', (tester) async {
      await _pumpStory(tester, StorySceneId.ch5Open);
      final backdrop = tester.widget<SceneBackdrop>(find.byType(SceneBackdrop).first);
      expect(backdrop.scene, ArtScene.storyFestival.fallback);
      expect(find.byType(SLSpeechBubble), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bí quyết của bà (sổ công thức)', () {
    testWidgets('trước màn 41: khoá + dòng giải thích, không có nút học', (tester) async {
      final state = _state(cleared: 20);
      await _openBook(tester, state);
      final l = _l(tester, RecipeBookScreen);
      expect(state.recipeSecretsUnlocked, isFalse);
      expect(find.text(l.recipeSecretsTitle), findsOneWidget);
      expect(find.text(l.recipeSecretsLocked(41)), findsOneWidget);
      expect(find.byKey(const ValueKey('recipe-secret-hint')), findsOneWidget);
      expect(find.byKey(_buy), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('đã qua màn 41, đủ xu: học 3 bậc, giá món tăng, rồi "đã học hết"', (tester) async {
      final state = _state()..addCoins(200000);
      await _openBook(tester, state);
      final l = _l(tester, RecipeBookScreen);
      const id = RecipeId.cupcakeVanilla;
      expect(state.recipeSecretsUnlocked, isTrue);
      expect(find.text(l.recipeSecretsTier(0, 3)), findsOneWidget);
      expect(find.text(l.recipesPrice(Catalog.recipe(id).price)), findsOneWidget);
      expect(_buyOpacity(tester), 1);
      expect(tester.getSize(find.byKey(_buy)).height, greaterThanOrEqualTo(48));

      for (var tier = 1; tier <= 3; tier++) {
        final price = state.recipeSecretPrice(id)!;
        final coins = state.coins;
        await tester.tap(find.byKey(_buy));
        await tester.pumpAndSettle();
        expect(state.coins, coins - price);
        expect(state.recipeSecretTier(id), tier);
        expect(find.text(l.recipesPrice(state.recipeSellPrice(id))), findsOneWidget);
        if (tier < 3) expect(find.text(l.recipeSecretsTier(tier, 3)), findsWidgets);
      }
      expect(state.recipeSellPrice(id), greaterThan(Catalog.recipe(id).price));
      expect(find.byKey(_buy), findsNothing);
      expect(find.byKey(const ValueKey('recipe-secret-maxed')), findsOneWidget);
      expect(find.text(l.recipeSecretsMaxed), findsOneWidget);
      await settleToasts(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('thiếu xu: nút mờ, bấm → nhắc "Không đủ xu", không mua', (tester) async {
      final state = _state();
      const id = RecipeId.cupcakeVanilla;
      final price = state.recipeSecretPrice(id)!;
      expect(state.coins, lessThan(price), reason: 'ván test cần thiếu xu');
      await _openBook(tester, state);
      final l = _l(tester, RecipeBookScreen);
      expect(_buyOpacity(tester), lessThan(1));
      await tester.tap(find.byKey(_buy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.commonNotEnoughCoins), findsOneWidget);
      expect(state.recipeSecretTier(id), 0);
      await settleToasts(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('món chưa mở (bánh Trung thu ở màn 43): trang khoá ghi "tìm lại công thức trước"', (tester) async {
      final state = _state();
      expect(state.isRecipeUnlocked(RecipeId.mooncake), isFalse);
      await _openBook(tester, state);
      await _select(tester, RecipeId.mooncake);
      final l = _l(tester, RecipeBookScreen);
      expect(find.byKey(const ValueKey('recipe-secret-recipe-locked')), findsOneWidget);
      expect(find.text(l.recipeSecretsRecipeLocked), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final lang in [LanguagePref.vi, LanguagePref.en]) {
      testWidgets('trang chi tiết ${lang.name}: chip "Thành thạo!" không cắt chữ, khu bí quyết nằm trọn, không tràn', (
        tester,
      ) async {
        final state = _state(lang: lang, recipeStars: const {RecipeId.cupcakeVanilla: 5})..addCoins(200000);
        expect(state.recipeMastery(RecipeId.cupcakeVanilla), 3);
        await _openBook(tester, state);
        final l = _l(tester, RecipeBookScreen);
        final chip = find.text(l.recipesMasteryReward(Economy.masteryGemReward));
        expect(chip, findsOneWidget);
        expect(tester.renderObject<RenderParagraph>(chip).didExceedMaxLines, isFalse);

        final page = Offset.zero & const Size(1280, 720);
        for (final key in ['recipe-mastery-chip', 'recipe-secret-buy', 'recipe-secret-bonus', 'recipe-secret-tier']) {
          final r = tester.getRect(find.byKey(ValueKey(key)));
          expect(page.contains(r.topLeft) && page.contains(r.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: key);
          expect(r.left, greaterThanOrEqualTo(816), reason: key);
          expect(r.bottom, lessThanOrEqualTo(720 - 24), reason: key);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('bản đồ chương 3–5', () {
    test('levels.json có 5 chương, mốc sao mở chương tăng dần (số cụ thể đọc từ config)', () {
      final need = _config.chapters.map((c) => c.starsToUnlock).toList();
      expect(need, hasLength(5));
      expect(need.first, 0);
      for (var i = 1; i < need.length; i++) {
        expect(need[i], greaterThan(need[i - 1]), reason: 'chương ${i + 1}');
      }
      expect(_config.levels.length, 50);
    });

    testWidgets('qua hết 50 màn: chuyển tới chương 3, 4, 5 — biển tên đúng, không khoá, ảnh thiếu không lỗi', (tester) async {
      final state = _state(cleared: 50);
      await _pumpMap(tester, state);
      final l = _l(tester, LevelMapScreen);
      // Bản đồ mở ở chương của level hiện tại (chương 5) → lùi về chương 1 rồi đi tới.
      while (find.byKey(const ValueKey('map-prev')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('map-prev')));
        await tester.pumpAndSettle();
      }
      for (final chapter in _config.chapters.skip(1)) {
        await _nextChapter(tester);
        expect(find.text('${l.levelChapterLabel(chapter.id)} · ${chapter.titleFor('en')}'), findsOneWidget);
        expect(find.byKey(const ValueKey('map-chapter-locked')), findsNothing);
        for (final lv in _config.levelsInChapter(chapter.id)) {
          expect(_node(lv.id), findsOneWidget, reason: 'L${lv.id}');
        }
        expect(tester.takeException(), isNull, reason: 'chương ${chapter.id}');
      }
      expect(find.byKey(const ValueKey('map-next')), findsNothing);
    });

    testWidgets('chương 3 khoá khi chưa đủ sao: phủ mờ "Cần N ★"', (tester) async {
      final state = GameState.newGame()
        ..setLanguage(LanguagePref.en)
        ..claimLogin()
        ..markSceneSeen(StorySceneId.prologue);
      state.attachLevelConfig(_config);
      winLevels(state, [for (var id = 1; id <= 20; id++) id], stars: 1, coins: 0);
      expect(state.isChapterUnlocked(3), isFalse);
      await _pumpMap(tester, state);
      while (find.byKey(const ValueKey('map-next')).evaluate().isNotEmpty &&
          find.byKey(const ValueKey('map-chapter-locked')).evaluate().isEmpty) {
        await _nextChapter(tester);
      }
      final l = _l(tester, LevelMapScreen);
      expect(find.byKey(const ValueKey('map-chapter-locked')), findsOneWidget);
      expect(find.text(l.mapChapterLockedTitle(3)), findsOneWidget);
      expect(find.textContaining('${_config.chapter(3)!.starsToUnlock}'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    for (final chapterId in [3, 4, 5]) {
      testWidgets('thắng màn cuối chương ${chapterId - 1} đủ sao → hộp "Chương $chapterId đã mở!" + vào chương mới', (tester) async {
        final prev = [for (final lv in _config.levelsInChapter(chapterId - 1)) lv.id];
        final state = _state(cleared: prev.last - 1);
        await _pumpMap(tester, state);
        final result = fakeLevelResult(prev.last, won: true, stars: 3, coins: 0);
        final delta = state.applyLevelResult(result);
        expect(delta.unlockedChapter, chapterId);
        navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(result, progress: delta));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('level-result-map')));
        await tester.pumpAndSettle();

        final l = _l(tester, LevelMapScreen);
        expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsOneWidget);
        expect(find.text(l.mapChapterUnlockedTitle(chapterId)), findsOneWidget);
        await tester.tap(find.text(l.mapChapterUnlockedGo));
        await tester.pumpAndSettle();
        final chapter = _config.chapter(chapterId)!;
        expect(find.text('${l.levelChapterLabel(chapterId)} · ${chapter.titleFor('en')}'), findsOneWidget);
        expect(find.byKey(const ValueKey('map-chapter-locked')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('chỉnh sau quality-gate GĐ8', () {
    testWidgets('bí quyết: huy hiệu lá (khác sao), giá nằm trong nút, bậc kế đậm/lớn hơn; thiếu xu → nút mờ + giá đỏ', (
      tester,
    ) async {
      final state = _state();
      const id = RecipeId.cupcakeVanilla;
      final price = state.recipeSecretPrice(id)!;
      expect(state.coins, lessThan(price));
      await _openBook(tester, state);
      final l = _l(tester, RecipeBookScreen);

      final leaves = find.byWidgetPredicate((w) => w is SLIconDisc && w.id == 'leaf_logo');
      expect(leaves, findsNWidgets(state.recipeSecretMaxTier));
      final tag = find.descendant(of: find.byKey(_buy), matching: find.byType(PriceTag));
      expect(tag, findsOneWidget);
      expect(tester.widget<PriceTag>(tag).amount, price);
      expect(tester.widget<PriceTag>(tag).affordable, isFalse);
      expect(_buyOpacity(tester), lessThan(1));
      expect(find.descendant(of: find.byKey(_buy), matching: find.text(l.recipeSecretsBuy)), findsOneWidget);

      double size(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).style!.fontSize!;
      expect(size('recipe-secret-bonus-next'), greaterThan(size('recipe-secret-bonus-now')));
      expect(find.text(l.recipeSecretsBonus(state.recipeSecretNextPricePct(id)!)), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Đủ xu → giá không còn đỏ, nút rõ.
      state.addCoins(price);
      await tester.pumpAndSettle();
      expect(tester.widget<PriceTag>(tag).affordable, isTrue);
      expect(_buyOpacity(tester), 1);
    });

    testWidgets('ô món khoá trong lưới: nhãn ngắn "Màn N", chữ ≥ 14, màu mực', (tester) async {
      final state = _state(lang: LanguagePref.vi);
      await _openBook(tester, state);
      final l = _l(tester, RecipeBookScreen);
      final first = _config.levels.firstWhere((lv) => lv.menu.contains(RecipeId.mooncake)).id;
      final label = find.descendant(of: find.byType(RecipeGrid), matching: find.text(l.levelNumber(first)));
      expect(label, findsOneWidget);
      final style = tester.widget<Text>(label).style!;
      expect(style.fontSize, greaterThanOrEqualTo(14));
      expect(style.color, SLColors.ink);
      expect(tester.takeException(), isNull);
    });

    testWidgets('truyện: gợi ý "Chạm để tiếp tục" ≥ 16 px, màu mực', (tester) async {
      await _pumpStory(tester, StorySceneId.rosa1);
      final hint = tester.widget<Text>(find.byKey(const ValueKey('story-tap-hint')));
      expect(hint.style!.fontSize, greaterThanOrEqualTo(16));
      expect(hint.style!.color, SLColors.ink);
    });

    test('đường đi bản đồ: viền kem ~6–7 px mỗi bên quanh lõi nâu', () {
      final side = (MapTrail.casingWidth - MapTrail.coreWidth) / 2;
      expect(side, inInclusiveRange(6, 7));
      expect(MapTrail.casing.a, 1.0);
    });

    for (final chapterId in [1, 2, 4, 5]) {
      testWidgets('bản đồ chương $chapterId: nút ≥ 48 dp, số ≥ 14 px đậm, vòng sáng màn đang tới, màn khoá mờ', (tester) async {
        // Đang tới màn đầu chương thứ hai trở đi / màn 3 ở chương 1.
        final levels = _config.levelsInChapter(chapterId);
        final current = chapterId == 1 ? 3 : levels.first.id;
        final state = _state(cleared: current - 1);
        await _pumpMap(tester, state);
        expect(state.currentLevelId, current);
        expect(find.text('${_l(tester, LevelMapScreen).levelChapterLabel(chapterId)} · ${_config.chapter(chapterId)!.titleFor('en')}'),
            findsOneWidget);

        final node = find.byKey(ValueKey('map-level-$current'));
        final hit = find.descendant(of: node, matching: find.byType(SLPressable)).first;
        expect(tester.getSize(hit).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(hit).height, greaterThanOrEqualTo(48));
        final number = tester.widget<Text>(find.descendant(of: node, matching: find.text('$current')));
        expect(number.style!.fontSize, greaterThanOrEqualTo(14));
        expect(number.style!.fontWeight!.value, greaterThanOrEqualTo(700));
        expect(find.descendant(of: node, matching: find.byKey(const ValueKey('map-node-glow'))), findsOneWidget);

        final locked = find.byKey(ValueKey('map-level-${levels.last.id}'));
        final fade = find.descendant(of: locked, matching: find.byType(Opacity));
        expect(tester.widget<Opacity>(fade.first).opacity, MapLevelNode.lockedOpacity);
        expect(tester.widget<MapLevelNode>(locked).state, MapNodeState.locked);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
