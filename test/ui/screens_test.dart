import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/ui/day/day_screen.dart';
import 'package:sugarleaf_bakery/ui/day/result_card.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

GameState _englishState() => GameState.newGame()
  ..setLanguage(LanguagePref.en)
  ..claimLogin();

void main() {
  testWidgets('nâng cấp: thiếu xu báo lỗi, đủ xu thì lên cấp lò', (tester) async {
    final state = _englishState()..addXp(80); // lên cấp 2 (+100 xu)
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.upgrades);
    await tester.pumpAndSettle();

    expect(find.text('Oven'), findsOneWidget);
    expect(find.text('Whisk'), findsOneWidget);
    expect(find.text('Perfect zone ±5%'), findsOneWidget);
    expect(find.text('Unlocks at level 3'), findsNWidgets(2)); // phới, túi kem

    await tester.tap(find.text('Upgrade').first);
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.ovenLevel, 1);

    state.addCoins(1000);
    await settleToasts(tester);
    await tester.tap(find.text('Upgrade').first);
    await tester.pumpAndSettle();
    expect(state.ovenLevel, 2);
    expect(find.text('Upgraded!'), findsOneWidget);
    expect(find.text('Level 2/5'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang trí: mua bình hoa thì tự đặt, tổng % tip tăng', (tester) async {
    final state = _englishState()..addCoins(400);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.decor);
    await tester.pumpAndSettle();

    expect(find.text('Total tip bonus: +0%'), findsOneWidget);
    await tester.tap(find.text('Counter'));
    await tester.pumpAndSettle();
    expect(find.text('Flower vase'), findsOneWidget);
    expect(find.text('Unlocks at level 5'), findsOneWidget); // kệ bánh
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
    expect(find.text('Missing page. Unlocks at level 12'), findsOneWidget);

    await tester.tap(find.text('Missing page. Unlocks at level 12'));
    await tester.pumpAndSettle();
    expect(find.text('Missing page. Unlocks at level 12'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ngày kinh doanh: cảnh mở đầu → giới thiệu ngày → khách gọi món → thoát', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MainMenuScreen.giftShownThisSession = true;
    final state = _englishState();
    await tester.pumpWidget(
      SugarleafApp(
        services: testServices(state),
        useGoogleFonts: false,
        onGenerateRoute: (settings) => settings.name == AppRoutes.day
            ? fadeRoute(settings, DayScreen(random: math.Random(7)))
            : onGenerateUiRoute(settings),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open the bakery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Chapter 1: The Seaside Bakery'), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);

    // Chạm qua 1 dòng rồi bỏ qua phần còn lại.
    await tester.tap(find.text('Tap to continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mai'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.seenScenes, contains(StorySceneId.prologue));
    expect(find.text('4 customers are coming today'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Start baking'), findsOneWidget);
    expect(find.text('Order'), findsOneWidget);
    expect(find.text('Customer 1/4'), findsOneWidget);

    await tester.tap(find.byTooltip('Leave for now?'));
    await tester.pumpAndSettle();
    expect(find.text("Coins earned so far are kept, but today won't count as completed."), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(state.dayNumber, 1);
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
    MainMenuScreen.giftShownThisSession = true;
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
      ..addXp(1400); // cấp 8: nhiều thẻ ở trạng thái mua được
    await pumpSugarApp(tester, state);
    for (final route in [AppRoutes.upgrades, AppRoutes.decor, AppRoutes.recipes, AppRoutes.store, AppRoutes.settings]) {
      navigator(tester).pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
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
