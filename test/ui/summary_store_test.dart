import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/routes.dart';

import 'ui_test_helpers.dart';

BakeResult _result({required int stars, required int payment, required int tip, required int cost, required int xp}) =>
    BakeResult(
      stations: {for (final s in StationId.values) s: StationScore(s, 1, StationIssue.none)},
      quality: stars / 5,
      stars: stars,
      payment: payment,
      tip: tip,
      cost: cost,
      xp: xp,
      praise: FeedbackKey.bakeGood,
      complaint: null,
      weakest: StationId.mix,
    );

OrderRecord _record(int id, RecipeId recipe, BakeResult r) => OrderRecord(
  order: Order(
    id: id,
    recipe: recipe,
    frosting: FrostingId.vanillaCream,
    toppings: const [ToppingRequest(ToppingId.sprinkles, 2)],
    box: BoxType.small,
    line: OrderLineKind.generic1,
  ),
  customer: Customer(kind: CustomerKind.regular, appearanceSeed: id),
  result: r,
);

/// Ngày mẫu: 2 đơn (4★ và 2★), lên cấp 1 → 2.
DaySummary _sampleSummary({int day = 3}) {
  final records = [
    _record(0, RecipeId.cupcakeVanilla, _result(stars: 4, payment: 30, tip: 6, cost: 8, xp: 35)),
    _record(1, RecipeId.cupcakeChocolate, _result(stars: 2, payment: 24, tip: 0, cost: 9, xp: 25)),
  ];
  return DaySummary(
    dayNumber: day,
    records: records,
    revenue: 54,
    tips: 6,
    costs: 17,
    net: 43,
    xpGained: 90,
    dayBonusXp: Economy.dayBonusXp,
    levelBefore: 1,
    levelAfter: 2,
    unlocks: Economy.unlocksAtLevel(2),
  );
}

GameState _englishState() => GameState.newGame()
  ..setLanguage(LanguagePref.en)
  ..claimLogin();

void main() {
  testWidgets('tổng kết hiện đúng số từ DaySummary, nhân đôi xu cộng đúng net', (tester) async {
    final state = _englishState();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.summary, arguments: DaySummaryArgs(_sampleSummary()));
    await tester.pumpAndSettle();

    expect(find.text('Day 3 complete!'), findsOneWidget);
    expect(find.text('Customers served'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3.0'), findsOneWidget); // (4 + 2) / 2
    expect(find.text('54'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('-17'), findsOneWidget);
    expect(find.text('43'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Day bonus +30 XP'), findsOneWidget);
    // Từng đơn: tên món + net có dấu.
    expect(find.text('Vanilla cupcake'), findsOneWidget);
    expect(find.text('Chocolate cupcake'), findsOneWidget);
    expect(find.text('+28'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    // Lên cấp + mở khoá.
    expect(find.text('Level up! Bakery level 2'), findsOneWidget);
    expect(find.text('New unlocks'), findsOneWidget);
    expect(find.text('New recipe: Blueberry muffin'), findsOneWidget);
    expect(find.text('New topping: Blueberry'), findsOneWidget);

    final coinsBefore = state.coins;
    await tester.tap(find.text('Double coins (watch ad)'));
    await tester.pump();
    expect(find.text('Ad (simulated)'), findsOneWidget);
    await waitForAd(tester);
    expect(state.coins, coinsBefore + 43);
    expect(state.rewardedToday, 1);
    expect(find.text('Coins doubled!'), findsWidgets);
    expect(find.text('86'), findsOneWidget);
    expect(find.text('Double coins (watch ad)'), findsNothing);

    // Ngày 3 < 4 → không interstitial, về menu.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Ad (simulated)'), findsNothing);
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(state.lastInterstitialDay, isNull);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tổng kết ngày 4: "Tiếp tục" hiện interstitial giả lập rồi về menu', (tester) async {
    final state = _englishState();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.summary, arguments: DaySummaryArgs(_sampleSummary(day: 4)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Ad (simulated)'), findsOneWidget);
    await waitForAd(tester);
    expect(state.lastInterstitialDay, 4);
    expect(find.text('Open the bakery'), findsOneWidget);
  });

  testWidgets('tổng kết hiện đúng ở tiếng Việt (định dạng số vi)', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.vi)
      ..claimLogin();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.summary, arguments: DaySummaryArgs(_sampleSummary()));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành ngày 3!'), findsOneWidget);
    expect(find.text('3,0'), findsOneWidget);
    expect(find.text('Lên cấp! Tiệm cấp 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cửa hàng: mua giả lập gói S cộng xu, gói một lần thành "Đã sở hữu"', (tester) async {
    final state = _englishState();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();

    expect(find.text('Test store: purchases are simulated and no money is charged.'), findsOneWidget);
    expect(find.text('Pantry pack S'), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
    final coinsBefore = state.coins;

    // Thứ tự thẻ: starterPack, pantryS, pantryM, pantryL, decorSetSeaside, removeAds.
    await tester.tap(find.text('Buy').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Simulated purchase'), findsOneWidget);
    expect(find.text(r'Buy Pantry pack S for $0.99? No real money will be charged.'), findsOneWidget);
    await tester.tap(find.text('Buy').last);
    await tester.pumpAndSettle();
    expect(state.coins, coinsBefore + 500);
    expect(find.text('Thank you! Your items have been added.'), findsOneWidget);

    // Gói khởi đầu (một lần): mua → xu + gem, thẻ hiện "Owned".
    final gemsBefore = state.gems;
    await tester.tap(find.text('Buy').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy').last);
    await tester.pumpAndSettle();
    expect(state.coins, coinsBefore + 500 + 1000);
    expect(state.gems, gemsBefore + 30);
    expect(find.text('Owned'), findsOneWidget);

    // Huỷ xác nhận → không mua.
    await tester.tap(find.text('Buy').first); // giờ là pantryS
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.coins, coinsBefore + 1500);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cửa hàng: xem quảng cáo nhận 1 gem', (tester) async {
    final state = _englishState();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();

    final gemsBefore = state.gems;
    await tester.tap(find.text('Watch ad'));
    await waitForAd(tester);
    expect(state.gems, gemsBefore + 1);
    expect(state.rewardedToday, 1);
    await settleToasts(tester);
  });
}
