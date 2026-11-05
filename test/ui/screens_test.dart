import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/ui/city_routes.dart';
import 'package:sugarleaf_bakery/ui/day/result_card.dart';

import 'city_test_helpers.dart';

void main() {
  testWidgets(
    'thẻ kết quả: sao, khen, chê đỏ + trạm cần cải thiện, tiền/tip/XP, nút làm lại',
    (tester) async {
      const order = Order(
        id: 0,
        recipe: RecipeId.cupcakeVanilla,
        frosting: FrostingId.strawberryCream,
        toppings: [
          ToppingRequest(ToppingId.cherry, 2),
          ToppingRequest(ToppingId.sprinkles, 3),
        ],
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
      await tester.pumpWidget(
        SugarleafApp(
          services: await cityServices(),
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
    },
  );
}
