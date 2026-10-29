import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/ui/day/mochi_visit.dart';
import 'package:sugarleaf_bakery/ui/day/order_ticket.dart';
import 'package:sugarleaf_bakery/ui/day/result_card.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

/// Bước 3 (đợt 2): vé đơn, thẻ kết quả, Mochi, tổng kết vẽ bằng bộ SL* — không còn Material Icons/Scaffold/Divider,
/// không tràn ở vi/en, không hiệu ứng lặp vô hạn (pumpAndSettle dừng được).

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.strawberryCream,
  toppings: [ToppingRequest(ToppingId.chocolateChips, 4), ToppingRequest(ToppingId.sugarPearl, 3)],
  box: BoxType.gift,
  line: OrderLineKind.vip,
);
const _vip = Customer(kind: CustomerKind.vip, appearanceSeed: 3);
const _bad = BakeOutcome(
  wrongMouldDrops: 1,
  mixTurns: 3,
  bakeRelease: 0.98,
  frostCoverage: 0.5,
  toppingsPlaced: {ToppingId.chocolateChips: 1},
  boxChosen: BoxType.small,
);

GameState _state(LanguagePref lang) => GameState.newGame()
  ..setLanguage(lang)
  ..claimLogin();

/// Dựng [page] làm route đầu trong app thật (l10n + theme + SLScope), khung 1280×720.
Future<void> _pumpPage(WidgetTester tester, LanguagePref lang, Widget page) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MainMenuScreen.giftShownThisSession = true;
  await tester.pumpWidget(
    SugarleafApp(
      services: testServices(_state(lang)),
      useGoogleFonts: false,
      onGenerateRoute: (settings) => fadeRoute(settings, page),
    ),
  );
}

void _expectNoMaterialChrome() {
  expect(find.byType(Icon), findsNothing);
  expect(find.byType(Scaffold), findsNothing);
  expect(find.byType(Divider), findsNothing);
}

void main() {
  for (final lang in [LanguagePref.en, LanguagePref.vi]) {
    testWidgets('vé đơn VIP 2 topping (${lang.name}): vé giấy SL, nhãn VIP, không tràn', (tester) async {
      await _pumpPage(
        tester,
        lang,
        const Center(child: SizedBox(width: 580, child: OrderTicket(order: _order, customer: _vip))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SLOrderTicket), findsOneWidget);
      expect(find.byType(SLBadge), findsOneWidget);
      expect(find.byType(SLRule), findsNWidgets(2));
      expect(tester.getSize(find.byType(OrderTicket)).height, 420);
      _expectNoMaterialChrome();
      expect(tester.takeException(), isNull);
    });

    testWidgets('thẻ kết quả buồn (${lang.name}): icon lỗi vẽ tay, chữ chê đỏ đậm, không tràn', (tester) async {
      final result = Scoring.evaluate(
        order: _order,
        customer: _vip,
        outcome: _bad,
        modifiers: BakeModifiers.base,
        decorTipBonusPct: 0,
      );
      await _pumpPage(
        tester,
        lang,
        Center(
          child: ResultCard(
            order: _order,
            customer: _vip,
            outcome: _bad,
            result: result,
            canRemake: true,
            onNext: () {},
            onRemake: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SLPaperCard), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'error'), findsOneWidget);
      // Lời chê + "Cần cải thiện: …" đều chữ đỏ đậm (đạt AA trên giấy), không dùng đỏ gốc #E86A5C.
      expect(result.complaint, isNotNull);
      final red = tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == SLColors.badDeep);
      expect(red.length, 2);
      expect(tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == SLColors.bad), isEmpty);
      _expectNoMaterialChrome();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tổng kết lên cấp, 6 đơn (${lang.name}): nét bút chì, không Scaffold/Divider, settle được', (tester) async {
      final records = [
        for (var i = 0; i < 6; i++)
          OrderRecord(
            order: _order,
            customer: i.isEven ? _vip : const Customer(kind: CustomerKind.friend, friend: FriendId.hoa, appearanceSeed: 1),
            result: Scoring.evaluate(
              order: _order,
              customer: _vip,
              outcome: _bad,
              modifiers: BakeModifiers.base,
              decorTipBonusPct: 0,
            ),
          ),
      ];
      final state = _state(lang);
      await pumpSugarApp(tester, state);
      navigator(tester).pushNamed(
        AppRoutes.summary,
        arguments: DaySummaryArgs(
          DaySummary(
            dayNumber: 5,
            isRainy: true,
            records: records,
            revenue: 300,
            tips: 20,
            costs: 40,
            net: 280,
            xpGained: 150,
            dayBonusXp: 30,
            levelBefore: 1,
            levelAfter: 2,
            unlocks: Economy.unlocksAtLevel(2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SLRule), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'trophy'), findsOneWidget);
      _expectNoMaterialChrome();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Mochi: "chạm để tiếp tục" không nhấp nháy mãi (pumpAndSettle dừng), không Material Icons', (tester) async {
    await _pumpPage(
      tester,
      LanguagePref.en,
      MochiVisit(firstVisit: true, onPet: () {}, onRest: () {}, onDone: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tap to continue'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'tap'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mochi: tắt hiệu ứng → ngồi sẵn, không tim bay', (tester) async {
    await _pumpPage(
      tester,
      LanguagePref.en,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: MochiVisit(firstVisit: false, onPet: () {}, onRest: () {}, onDone: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(900, 400));
    await tester.pump();
    await tester.tap(find.text('Pet'));
    await tester.pump();
    expect(find.text('Mochi purrs happily!'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'heart'), findsNothing); // nút đã ẩn, không tim bay.
    expect(tester.takeException(), isNull);
  });
}
