import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/ui/day/result_card.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'ui_test_helpers.dart';

GameState _englishState() => GameState.newGame()
  ..setLanguage(LanguagePref.en)
  ..claimLogin();

void main() {
  testWidgets('nâng cấp (thiết bị): thiếu xu báo lỗi, đủ xu thì lên cấp lò vùng vàng', (tester) async {
    // Qua L1–2 (+100 xu mỗi lượt): lò vùng vàng cấp 2 (qua L2) mở nhưng chưa đủ xu; phới cấp 2 cần qua L4.
    final state = _englishState();
    winLevels(state, [1, 2], coins: 100);
    final oven = testUnlockConfig().equipmentById('goldenOven')!;
    expect(state.coins, lessThan(oven.tiers[1].price));
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.upgrades, arguments: const UpgradesArgs(tab: UpgradesTab.equipment));
    await tester.pumpAndSettle();

    expect(find.text(oven.name('en')), findsOneWidget);
    expect(find.text(testUnlockConfig().equipmentById('whisk')!.name('en')), findsOneWidget);
    expect(find.text('Perfect zone ±5%'), findsOneWidget);
    expect(find.text('±6%'), findsOneWidget); // cấp sau (bỏ chữ lặp: "Perfect zone ±5% → ±6%")
    final whisk2 = testUnlockConfig().equipmentById('whisk')!.tiers[1].level;
    expect(find.byKey(const ValueKey('upg-locked-whisk')), findsOneWidget);
    expect(find.text('Clear level $whisk2 to unlock'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('upg-buy-goldenOven')));
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.equipmentTier('goldenOven'), 1);

    state.addCoins(1000);
    await settleToasts(tester);
    final before = state.coins;
    await tester.tap(find.byKey(const ValueKey('upg-buy-goldenOven')));
    await tester.pumpAndSettle();
    expect(state.equipmentTier('goldenOven'), 2);
    expect(state.coins, before - oven.tiers[1].price);
    expect(find.text('Upgraded!'), findsOneWidget);
    expect(find.text('Tier 2/${oven.maxTier}'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang trí: mua bình hoa thì tự đặt, tổng % tip tăng', (tester) async {
    final state = _englishState();
    winLevels(state, [1], coins: 300); // đồ trang trí khoá theo màn đã qua

    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.decor);
    await tester.pumpAndSettle();

    expect(find.text('Total tip bonus: +0%'), findsOneWidget);
    await tester.tap(find.text('Counter'));
    await tester.pumpAndSettle();
    expect(find.text('Flower vase'), findsOneWidget);
    // Kệ bánh: khoá tới khi qua màn `unlockLevel` của nó.
    expect(find.text('Clear level ${Catalog.decorItem(DecorId.counterCakeStand).unlockLevel} to unlock'), findsOneWidget);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(state.ownedDecor, contains(DecorId.counterFlowers));
    expect(state.equippedDecor[DecorSlot.counter], DecorId.counterFlowers);
    expect(find.text('Total tip bonus: +2%'), findsOneWidget);

    // Đặt lại "Cơ bản".
    await tester.tap(find.text('Place'));
    await tester.pumpAndSettle();
    expect(state.equippedDecor[DecorSlot.counter], isNull);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sổ công thức: món mở hiện chi tiết, món khoá là trang còn thiếu', (tester) async {
    await pumpSugarApp(tester, _englishState());
    navigator(tester).pushNamed(AppRoutes.recipes);
    await tester.pumpAndSettle();

    expect(find.text('Vanilla cupcake'), findsNWidgets(2)); // ô lưới + trang chi tiết
    expect(find.text('Price: 30'), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);
    // Món mở theo level đã mở: bánh sinh nhật có từ L12 — ô lưới ghi ngắn "Level 12", trang chi tiết ghi câu đầy đủ.
    expect(find.text('Level 12'), findsOneWidget);
    expect(find.text('Missing page. Reach level 12 to find it'), findsNothing);

    await tester.tap(find.text('Level 12'));
    await tester.pumpAndSettle();
    expect(find.text('Level 12'), findsOneWidget);
    expect(find.text('Missing page. Reach level 12 to find it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thẻ kết quả: sao, khen, chê đỏ + trạm cần cải thiện, tiền/tip/XP, nút làm lại', (tester) async {
    const order = Order(
      id: 0,
      recipe: RecipeId.cupcakeVanilla,
      frosting: FrostingId.strawberryCream,
      toppings: [ToppingRequest(ToppingId.cherry, 2), ToppingRequest(ToppingId.sprinkles, 3)],
      box: BoxType.gift,
      line: OrderLineKind.vip,
    );
    const customer = Customer(kind: CustomerKind.vip, appearanceSeed: 3);
    const outcome = BakeOutcome(
      wrongMouldDrops: 1,
      mixTurns: 3,
      bakeRelease: 0.98,
      frostCoverage: 0.5,
      toppingsPlaced: {ToppingId.cherry: 1},
      boxChosen: BoxType.small,
    );
    final result = Scoring.evaluate(
      order: order,
      customer: customer,
      outcome: outcome,
      modifiers: BakeModifiers.base,
      decorTipBonusPct: 0,
    );
    expect(result.complaint, isNotNull);
    var next = 0, remake = 0;

    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LevelMapScreen.giftShownThisSession = true;
    await tester.pumpWidget(
      SugarleafApp(
        services: testServices(_englishState()),
        useGoogleFonts: false,
        onGenerateRoute: (settings) => fadeRoute(
          settings,
          Scaffold(
            body: Center(
              child: ResultCard(
                order: order,
                customer: customer,
                outcome: outcome,
                result: result,
                canRemake: true,
                onNext: () => next++,
                onRemake: () => remake++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Needs work: Baking'), findsOneWidget);
    expect(find.text("Oops, it's a little burnt!"), findsOneWidget);
    expect(find.text('Paid ${result.payment}'), findsOneWidget);
    expect(find.text('+${result.xp} XP'), findsOneWidget);
    await tester.tap(find.text('Remake (watch ad)'));
    await tester.tap(find.text('Next customer'));
    expect(remake, 1);
    expect(next, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mọi màn phụ dựng được ở tiếng Việt không tràn bố cục', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.vi)
      ..claimLogin()
      ..addCoins(3000);
    winLevels(state, [for (var id = 1; id <= 13; id++) id]); // nhiều thẻ mua được
    await pumpSugarApp(tester, state);
    for (final route in [AppRoutes.upgrades, AppRoutes.decor, AppRoutes.recipes, AppRoutes.store, AppRoutes.settings]) {
      navigator(tester).pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      if (route == AppRoutes.upgrades) {
        await tester.tap(find.text('Thiết bị'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'thiết bị');
      }
      navigator(tester).pop();
      await tester.pumpAndSettle();
    }
    for (final slot in ['Sàn nhà', 'Quầy', 'Cửa sổ', 'Cây xanh']) {
      if (slot == 'Sàn nhà') {
        navigator(tester).pushNamed(AppRoutes.decor);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(slot));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: slot);
    }
  });
}
