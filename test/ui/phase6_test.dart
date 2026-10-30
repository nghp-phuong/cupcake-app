import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/common/staff_portrait.dart';
import 'package:sugarleaf_bakery/ui/level/booster_row.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/season/season_pass_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'ui_test_helpers.dart';

/// GĐ6: vật phẩm hỗ trợ ở thẻ Sẵn sàng, ×2 xu + interstitial ở màn kết quả, cửa hàng V2, Thẻ mùa, trang phục lễ
/// hội, khôi phục giao dịch.

/// Đồng hồ giả (giữa mùa `s1_seaside_autumn` của monetization.json: 15/10 – 15/12/2026).
DateTime _now = DateTime(2026, 10, 28, 10);

GameState _state({int cleared = 0, int coins = 320}) {
  final state = GameState.newGame(clock: () => _now)
    ..setLanguage(LanguagePref.en)
    ..claimLogin();
  for (final s in StorySceneId.values) {
    state.markSceneSeen(s);
  }
  testServices(state);
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: coins);
  return state;
}

Finder _key(String k) => find.byKey(ValueKey(k));

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Cảnh chơi (Flame) chạy liên tục: không dùng pumpAndSettle khi LevelScreen đang mở.
Future<void> _frames(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openLevel(WidgetTester tester, int id) async {
  navigator(tester).pushNamed(AppRoutes.level, arguments: LevelArgs(id));
  await _frames(tester);
}

LevelSession _session(WidgetTester tester) => tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;

void _setGems(GameState state, int gems) {
  state.trySpendGems(state.gems);
  state.addGems(gems);
}

void main() {
  setUp(() => _now = DateTime(2026, 10, 28, 10));

  // ------------------------------------------------------------------ Thẻ Sẵn sàng: vật phẩm

  testWidgets('L1–L3 không có hàng vật phẩm; L4 có (lần đầu kèm chú thích giới thiệu)', (tester) async {
    final state = _state(cleared: 3);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 3);
    expect(_key('level-ready-boosters'), findsNothing);
    navigator(tester).pop();
    await _frames(tester);

    await _openLevel(tester, 4);
    expect(_key('level-ready-boosters'), findsOneWidget);
    for (final id in BoosterId.values) {
      expect(_key('level-booster-${id.name}'), findsOneWidget);
    }
    // Quà giới thiệu: patience ×1 trong kho; hai món kia hiện giá kim cương.
    expect(_key('level-booster-owned-patience'), findsOneWidget);
    expect(_key('level-booster-price-fullCase'), findsOneWidget);
    expect(_key('level-booster-intro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chọn vật phẩm: chỉ trừ khi bấm Bắt đầu (kho trước, rồi kim cương); thoát ở thẻ không mất', (tester) async {
    final state = _state(cleared: 3);
    _setGems(state, 20);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 4);
    final l = _l(tester);

    await tester.tap(_key('level-booster-patience'));
    await tester.tap(_key('level-booster-ovenBoost'));
    await _frames(tester, 4);
    expect(state.boosterCount(BoosterId.patience), 1);
    expect(state.gems, 20);
    // Bỏ chọn rồi chọn lại.
    await tester.tap(_key('level-booster-ovenBoost'));
    await _frames(tester, 2);
    await tester.tap(_key('level-booster-ovenBoost'));
    await _frames(tester, 2);

    await tester.tap(find.text(l.levelStart));
    await _frames(tester, 4);
    expect(state.boosterCount(BoosterId.patience), 0);
    expect(state.gems, 20 - state.boosterData(BoosterId.ovenBoost).gemPrice);
    expect(_session(tester).boosters, {BoosterId.patience, BoosterId.ovenBoost});
    expect(state.boosterIntroSeen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thoát ở thẻ Sẵn sàng sau khi chọn: không trừ gì', (tester) async {
    final state = _state(cleared: 3);
    _setGems(state, 20);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 4);
    await tester.tap(_key('level-booster-fullCase'));
    await _frames(tester, 2);
    await tester.binding.handlePopRoute();
    await _frames(tester, 10);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.gems, 20);
    expect(state.boosterCount(BoosterId.patience), 1);
  });

  testWidgets('không đủ kim cương → toast + mở cửa hàng', (tester) async {
    final state = _state(cleared: 3);
    _setGems(state, 0);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 4);
    final l = _l(tester);
    await tester.tap(_key('level-booster-fullCase'));
    await _frames(tester, 10);
    expect(find.text(l.commonNotEnoughGems), findsOneWidget);
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(state.gems, 0);
    // Màn chơi (Flame) vẫn chạy dưới cửa hàng: không pumpAndSettle.
    await _frames(tester, 80);
  });

  testWidgets('xem quảng cáo: một vật phẩm miễn phí, nút chỉ dùng một lần mỗi lượt', (tester) async {
    final state = _state(cleared: 3);
    _setGems(state, 0);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 4);
    final l = _l(tester);

    await tester.tap(_key('level-booster-ad'));
    await tester.pump();
    await tester.pump(kTestAdDuration);
    await _frames(tester, 10);
    expect(state.rewardedToday, 1);
    expect(_key('level-booster-ad'), findsNothing);

    // Chưa chọn ô nào → tự chọn ô đắt nhất chưa có trong kho, trả bằng lượt quảng cáo (không phí lượt).
    expect(_key('level-booster-free-fullCase'), findsOneWidget);
    // Món thứ hai cần kim cương (đang 0) → không chọn được (mở cửa hàng); quay lại thẻ.
    await tester.tap(_key('level-booster-ovenBoost'));
    await _frames(tester, 10);
    navigator(tester).pop();
    await _frames(tester, 10);

    await tester.tap(find.text(l.levelStart));
    await _frames(tester, 4);
    expect(state.gems, 0);
    expect(_session(tester).boosters, {BoosterId.fullCase});
    expect(tester.takeException(), isNull);
  });

  testWidgets('tạm dừng → Thoát trước khi bán: vật phẩm trả lại vào kho, hộp tạm dừng báo trước', (tester) async {
    final state = _state(cleared: 3);
    _setGems(state, 20);
    await pumpSugarApp(tester, state);
    await _openLevel(tester, 4);
    final l = _l(tester);
    await tester.tap(_key('level-booster-patience'));
    await tester.tap(_key('level-booster-ovenBoost'));
    await _frames(tester, 2);
    await tester.tap(find.text(l.levelStart));
    await _frames(tester, 4);
    final gems = state.gems;
    expect(state.boosterCount(BoosterId.patience), 0);
    expect(_session(tester).hasSold, isFalse);

    await tester.tap(find.byTooltip(l.levelPause));
    await _frames(tester, 10);
    expect(_key('level-pause-boosters'), findsOneWidget);
    expect(find.text(l.levelPauseBoosterRefund), findsOneWidget);
    await tester.tap(find.text(l.levelQuit));
    await _frames(tester, 20);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    // Mỗi loại đã dùng +1 vào kho; kim cương không trả lại.
    expect(state.boosterCount(BoosterId.patience), 1);
    expect(state.boosterCount(BoosterId.ovenBoost), 1);
    expect(state.gems, gems);
    expect(find.text(l.levelBoostersRefunded), findsOneWidget);
    await settleToasts(tester);
  });

  // ------------------------------------------------------------------ Màn kết quả: ×2 xu + interstitial

  testWidgets('×2 xu: một lần, cộng đúng số xu của lượt; xu = 0 thì không có nút', (tester) async {
    final state = _state(cleared: 2);
    await pumpSugarApp(tester, state);
    final coins = state.coins;
    navigator(tester).pushNamed(
      AppRoutes.levelResult,
      arguments: LevelResultArgs(fakeLevelResult(2, won: true, stars: 2, coins: 320)),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('level-result-double'));
    await waitForAd(tester);
    expect(state.coins, coins + 320);
    expect(state.rewardedToday, 1);
    expect(_key('level-result-double'), findsNothing);
    expect(find.text('640'), findsOneWidget);
    await settleToasts(tester);

    navigator(tester).pushReplacementNamed(
      AppRoutes.levelResult,
      arguments: LevelResultArgs(fakeLevelResult(2, won: false, coins: 0)),
    );
    await tester.pumpAndSettle();
    expect(_key('level-result-double'), findsNothing);
  });

  testWidgets('màn kết quả: hàng thưởng thêm (kim cương, điểm mùa, quà vật phẩm) chỉ khi > 0', (tester) async {
    final state = _state(cleared: 2);
    await pumpSugarApp(tester, state);
    final delta = state.applyLevelResult(fakeLevelResult(3, won: true, stars: 3));
    expect(delta.boosterGift, isTrue);
    navigator(tester).pushNamed(
      AppRoutes.levelResult,
      arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3), progress: delta),
    );
    await tester.pumpAndSettle();
    final l = _l(tester);
    expect(_key('level-result-extras'), findsOneWidget);
    if (delta.seasonPoints > 0) expect(find.text(l.levelResultSeasonPoints(delta.seasonPoints)), findsOneWidget);
    if (delta.gems > 0) expect(find.text('+${delta.gems}'), findsOneWidget);
    expect(
      find.text(l.levelResultBoosterGift(state.boosterData(BoosterEffects.introGift).name('en'))),
      findsOneWidget,
    );

    navigator(tester).pushReplacementNamed(
      AppRoutes.levelResult,
      arguments: LevelResultArgs(fakeLevelResult(3, won: false, coins: 0)),
    );
    await tester.pumpAndSettle();
    expect(_key('level-result-extras'), findsNothing);
  });

  testWidgets('interstitial chỉ khi rời màn kết quả, đủ 3 lượt từ sau L5; đếm lượt đúng một lần', (tester) async {
    final state = _state(cleared: 6);
    state.registerLevelPlayEnded();
    state.registerLevelPlayEnded();
    expect(state.playsSinceInterstitial, 2);
    await pumpSugarApp(tester, state);

    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(6, won: true, stars: 3)));
    await tester.pumpAndSettle();
    // Đang ở màn kết quả: chưa có quảng cáo.
    expect(find.byType(SimulatedAdDialog), findsNothing);
    expect(state.playsSinceInterstitial, 2);

    await tester.tap(_key('level-result-map'));
    await tester.pump();
    expect(find.byType(SimulatedAdDialog), findsOneWidget);
    // Bấm lại trong lúc quảng cáo: không đếm thêm.
    await tester.pump(kTestAdDuration);
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.playsSinceInterstitial, 0);
  });

  testWidgets('interstitial không hiện: vừa xem ×2 xu ở màn kết quả; chưa qua L5', (tester) async {
    final state = _state(cleared: 6);
    state.registerLevelPlayEnded();
    state.registerLevelPlayEnded();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(6, won: true, stars: 3)));
    await tester.pumpAndSettle();
    await tester.tap(_key('level-result-double'));
    await waitForAd(tester);
    await settleToasts(tester);
    await tester.tap(_key('level-result-map'));
    await tester.pump();
    expect(find.byType(SimulatedAdDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    // Lượt vẫn được đếm (3), để dành tới lần rời kết quả sau.
    expect(state.playsSinceInterstitial, 3);

    final early = _state(cleared: 3);
    await pumpSugarApp(tester, early);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3)));
    await tester.pumpAndSettle();
    await tester.tap(_key('level-result-map'));
    await tester.pump();
    expect(find.byType(SimulatedAdDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(early.playsSinceInterstitial, 0);
  });

  testWidgets('interstitial không hiện khi đã mua Bỏ quảng cáo', (tester) async {
    final state = _state(cleared: 6)..grantIap(IapProductId.removeAds);
    for (var i = 0; i < 5; i++) {
      state.registerLevelPlayEnded();
    }
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(6, won: true, stars: 3)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l(tester).levelReplay));
    await tester.pump();
    expect(find.byType(SimulatedAdDialog), findsNothing);
    await _frames(tester);
  });

  // ------------------------------------------------------------------ Cửa hàng V2

  testWidgets('cửa hàng V2: nhãn Chế độ thử, ẩn gói V1, mua gói kim cương / trang phục (giả lập)', (tester) async {
    final state = _state(cleared: 1);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    final l = _l(tester);

    expect(_key('store-test-mode'), findsOneWidget);
    expect(find.text(l.storeTestMode), findsOneWidget);
    for (final id in [IapProductId.pantryS, IapProductId.pantryM, IapProductId.pantryL, IapProductId.decorSetSeaside]) {
      expect(_key('store-product-${id.name}'), findsNothing);
    }
    // Chưa tới L4: chưa có gói khởi đầu.
    expect(_key('store-product-starterPack'), findsNothing);
    for (final id in [IapProductId.gemsS, IapProductId.gemsM, IapProductId.gemsL, IapProductId.removeAds,
      IapProductId.staffOutfits, IapProductId.seasonPass]) {
      expect(_key('store-product-${id.name}'), findsOneWidget);
    }

    final gems = state.gems;
    await tester.tap(find.descendant(of: _key('store-product-gemsS'), matching: find.text(l.commonBuy)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.commonBuy).last);
    await tester.pumpAndSettle();
    expect(state.gems, gems + 80);
    await settleToasts(tester);

    await tester.tap(find.descendant(of: _key('store-product-staffOutfits'), matching: find.text(l.commonBuy)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.commonBuy).last);
    await tester.pumpAndSettle();
    expect(state.outfitsOwned, isTrue);
    expect(find.descendant(of: _key('store-product-staffOutfits'), matching: find.text(l.storeOwned)), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cửa hàng: gói khởi đầu nổi bật từ L4 tới khi mua', (tester) async {
    final state = _state(cleared: 3);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    final l = _l(tester);
    expect(_key('store-product-starterPack'), findsOneWidget);
    expect(_key('store-starter-badge'), findsOneWidget);

    await tester.tap(find.descendant(of: _key('store-product-starterPack'), matching: find.text(l.commonBuy)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.commonBuy).last);
    await tester.pumpAndSettle();
    expect(state.ownedIap, contains(IapProductId.starterPack));
    expect(state.boosterCount(BoosterId.fullCase), 3);
    expect(_key('store-product-starterPack'), findsNothing);
    await settleToasts(tester);
  });

  testWidgets('cửa hàng: hết mùa → thẻ Thẻ mùa khoá, ghi "Chưa có mùa mới"', (tester) async {
    _now = DateTime(2027, 3, 1, 10);
    final state = _state();
    expect(state.canBuyIap(IapProductId.seasonPass), isFalse);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    final l = _l(tester);
    final card = _key('store-product-seasonPass');
    expect(find.descendant(of: card, matching: find.text(l.storeSeasonNone)), findsOneWidget);
    await tester.tap(find.descendant(of: card, matching: find.text(l.commonBuy)));
    await tester.pumpAndSettle();
    expect(find.text(l.storeConfirmTitle), findsNothing);
  });

  testWidgets('cửa hàng: +1 kim cương bằng quảng cáo vẫn còn', (tester) async {
    final state = _state();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    final gems = state.gems;
    await tester.tap(find.text(_l(tester).commonWatchAd));
    await waitForAd(tester);
    expect(state.gems, gems + 1);
    await settleToasts(tester);
  });

  // ------------------------------------------------------------------ Thẻ mùa

  testWidgets('bản đồ: nút Thẻ mùa có chấm đỏ khi có thưởng chờ → mở màn Thẻ mùa', (tester) async {
    final state = _state(cleared: 2);
    expect(state.seasonClaimable, isNotEmpty);
    LevelMapScreen.giftShownThisSession = true;
    await pumpSugarApp(tester, state);
    await tester.pumpAndSettle();
    expect(_key('map-season'), findsOneWidget);
    expect(seasonHasPending(state), isTrue);
    await tester.tap(_key('map-season'));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonPassScreen), findsOneWidget);
    expect(_key('season-track'), findsOneWidget);
    expect(_key('season-time-left'), findsOneWidget);
  });

  testWidgets('thẻ mùa: nhận từng bậc, nhận tất cả, mua cao cấp (giả lập)', (tester) async {
    final state = _state(cleared: 4);
    final tier = state.seasonTier;
    expect(tier, greaterThanOrEqualTo(2));
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(UiRoutes.season);
    await tester.pumpAndSettle();
    final l = _l(tester);

    final season = state.activeSeason!;
    final coins = state.coins;
    // Màn mở ở gần bậc đang tới: cuộn về bậc 1.
    await tester.drag(_key('season-track'), const Offset(3000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: _key('season-cell-1-free'), matching: find.text(l.commonClaim)));
    await tester.pumpAndSettle();
    expect(state.coins, coins + season.tiers[0].free.coins);
    expect(state.seasonClaimed(1, premium: false), isTrue);
    expect(find.descendant(of: _key('season-cell-1-free'), matching: find.text(l.commonClaim)), findsNothing);
    await settleToasts(tester);

    // Ô cao cấp đã đạt nhưng chưa mua: không có nút Nhận.
    expect(find.descendant(of: _key('season-cell-1-premium'), matching: find.text(l.commonClaim)), findsNothing);

    await tester.tap(_key('season-buy-premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.commonBuy).last);
    await tester.pumpAndSettle();
    expect(state.seasonPremium, isTrue);
    expect(_key('season-premium-active'), findsOneWidget);
    await settleToasts(tester);

    await tester.tap(_key('season-claim-all'));
    await tester.pumpAndSettle();
    expect(state.seasonClaimable, isEmpty);
    for (var t = 1; t <= tier; t++) {
      expect(state.seasonCanClaim(t, premium: true), isFalse);
    }
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thẻ mùa: ô có 3 thưởng (bậc 18 cao cấp) hiện đủ cả 3', (tester) async {
    final state = _state(cleared: 1);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(UiRoutes.season);
    await tester.pumpAndSettle();
    final cell = _key('season-cell-18-premium');
    await tester.scrollUntilVisible(cell, 300, scrollable: find.descendant(of: _key('season-track'), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    final rewards = state.activeSeason!.tiers[17].premium;
    expect(find.descendant(of: cell, matching: find.byType(BoosterArt)), findsNWidgets(rewards.boosters.length));
    expect(rewards.boosters.length, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hết mùa: thưởng còn chờ tự nhận, bản đồ báo một lần', (tester) async {
    final state = _state(cleared: 4);
    expect(state.seasonClaimable, isNotEmpty);
    final coins = state.coins;
    _now = DateTime(2026, 12, 16, 10);
    state.refreshSeason();
    expect(state.seasonAutoClaim, isNotNull);
    expect(state.coins, greaterThan(coins));
    LevelMapScreen.giftShownThisSession = true;
    state.claimLogin();
    await pumpSugarApp(tester, state);
    await tester.pumpAndSettle();
    expect(_key('season-ended'), findsOneWidget);
    expect(find.text(_l(tester).seasonEnded), findsOneWidget);
    await tester.tap(find.text(_l(tester).commonOk));
    await tester.pumpAndSettle();
    expect(state.seasonAutoClaim, isNull);
    expect(_key('season-ended'), findsNothing);

    // Không còn mùa: màn Thẻ mùa báo "chưa có mùa".
    navigator(tester).pushNamed(UiRoutes.season);
    await tester.pumpAndSettle();
    expect(_key('season-none'), findsOneWidget);
  });

  // ------------------------------------------------------------------ Trang phục + khôi phục

  testWidgets('tab Nhân viên: công tắc trang phục lễ hội khi đã mua (Nora), ảnh _fest', (tester) async {
    final state = _state(cleared: testUnlockConfig().unlock(StaffIds.cashier)!.level);
    state.addCoins(testUnlockConfig().unlock(StaffIds.cashier)!.price);
    expect(state.buyUnlock(StaffIds.cashier), PurchaseResult.ok);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.upgrades, arguments: const UpgradesArgs(tab: UpgradesTab.staff));
    await tester.pumpAndSettle();
    expect(_key('staff-outfit-${StaffIds.cashier}'), findsNothing);
    navigator(tester).pop();
    await tester.pumpAndSettle();

    state.grantIap(IapProductId.staffOutfits);
    expect(state.outfitsEnabled, isTrue);
    navigator(tester).pushNamed(AppRoutes.upgrades, arguments: const UpgradesArgs(tab: UpgradesTab.staff));
    await tester.pumpAndSettle();
    expect(_key('staff-outfit-${StaffIds.cashier}'), findsOneWidget);
    StaffPortrait portrait() => tester.widget<StaffPortrait>(_key('staff-portrait-${StaffIds.cashier}'));
    expect(portrait().character, 'staff_nora_fest');

    await tester.tap(_key('staff-outfit-${StaffIds.cashier}'));
    await tester.pumpAndSettle();
    expect(state.outfitsEnabled, isFalse);
    expect(portrait().character, 'staff_nora');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cài đặt: Khôi phục giao dịch → toast số gói / không có gì', (tester) async {
    final state = _state();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();
    final l = _l(tester);
    await tester.tap(_key('settings-restore'));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsRestoreNone), findsOneWidget);
    await settleToasts(tester);

    state
      ..grantIap(IapProductId.removeAds)
      ..grantIap(IapProductId.staffOutfits);
    await tester.tap(_key('settings-restore'));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsRestoreDone(2)), findsOneWidget);
    await settleToasts(tester);
  });
}
