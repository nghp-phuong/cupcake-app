import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';

const _regular = Customer(kind: CustomerKind.regular, appearanceSeed: 1);
const _vip = Customer(kind: CustomerKind.vip, appearanceSeed: 2);

Order _order(RecipeId recipe, {BoxType box = BoxType.small, List<ToppingRequest>? toppings}) => Order(
      id: 0,
      recipe: recipe,
      frosting: FrostingId.vanillaCream,
      toppings: toppings ?? const [ToppingRequest(ToppingId.sprinkles, 2)],
      box: box,
      line: OrderLineKind.generic1,
    );

BakeOutcome _perfect(Order o, {int wrongMould = 0, double? frost, double? release, double? mix, BoxType? box}) =>
    BakeOutcome(
      wrongMouldDrops: wrongMould,
      mixTurns: mix ?? o.recipeData.mixTurns.toDouble(),
      bakeRelease: release ?? o.recipeData.bakeTarget,
      frostCoverage: frost ?? 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: box ?? o.box,
    );

void main() {
  group('trạm', () {
    test('mould', () {
      expect(Scoring.mould(0).score, 1);
      expect(Scoring.mould(0).issue, StationIssue.none);
      expect(Scoring.mould(1).score, closeTo(0.65, 1e-9));
      expect(Scoring.mould(1).issue, StationIssue.wrongMould);
      expect(Scoring.mould(5).score, 0.3);
    });

    test('mix', () {
      expect(Scoring.mix(3, 3, 0.1).score, 1);
      expect(Scoring.mix(3.3, 3, 0.1).score, 1); // d = 0.1 đúng biên
      final under = Scoring.mix(2.4, 3, 0.1); // d = 0.2 → 1 − 0.1·2 = 0.8
      expect(under.score, closeTo(0.8, 1e-9));
      expect(under.issue, StationIssue.underMixed);
      final over = Scoring.mix(4.5, 3, 0.1); // d = 0.5 → 0.2
      expect(over.score, closeTo(0.2, 1e-9));
      expect(over.issue, StationIssue.overMixed);
      expect(Scoring.mix(0, 3, 0.1).score, 0);
    });

    test('bake', () {
      expect(Scoring.bake(0.70, 0.65, 0.05, 0.15).score, 1); // biên perfect (dấu phẩy động)
      expect(Scoring.bake(0.65, 0.65, 0.05, 0.15).issue, StationIssue.none);
      final ok = Scoring.bake(0.75, 0.65, 0.05, 0.15); // d 0.1 → 1 − 0.4·0.5 = 0.8
      expect(ok.score, closeTo(0.8, 1e-9));
      expect(ok.issue, StationIssue.burnt);
      expect(Scoring.bake(0.80, 0.65, 0.05, 0.15).score, closeTo(0.6, 1e-9));
      final raw = Scoring.bake(0.40, 0.65, 0.05, 0.15); // d 0.25 → 0.6 − 0.3 = 0.3
      expect(raw.score, closeTo(0.3, 1e-9));
      expect(raw.issue, StationIssue.underBaked);
      expect(Scoring.bake(1.0, 0.65, 0.05, 0.15).score, 0); // giữ tới cuối → cháy hẳn
      expect(Scoring.bake(1.0, 0.65, 0.05, 0.15).issue, StationIssue.burnt);
    });

    test('frost', () {
      expect(Scoring.frost(0.95).score, 1);
      expect(Scoring.frost(0.9).score, 1);
      expect(Scoring.frost(0.6).score, closeTo(0.5, 1e-9));
      expect(Scoring.frost(0.6).issue, StationIssue.patchy);
      expect(Scoring.frost(0.1).score, 0);
    });

    test('topping', () {
      const req = [ToppingRequest(ToppingId.sprinkles, 2), ToppingRequest(ToppingId.cherry, 2)];
      expect(Scoring.topping({ToppingId.sprinkles: 2, ToppingId.cherry: 2}, req).score, 1);
      final missing = Scoring.topping({ToppingId.sprinkles: 2, ToppingId.cherry: 1}, req);
      expect(missing.score, closeTo(0.75, 1e-9));
      expect(missing.issue, StationIssue.missingTopping);
      // thừa 1 cherry + 1 loại lạ: correct 4/4 − 0.15·2 = 0.7
      final wrong = Scoring.topping({ToppingId.sprinkles: 2, ToppingId.cherry: 3, ToppingId.candle: 1}, req);
      expect(wrong.score, closeTo(0.7, 1e-9));
      expect(wrong.issue, StationIssue.wrongTopping);
      expect(Scoring.topping({}, req).score, 0);
    });

    test('box', () {
      expect(Scoring.box(BoxType.cake, BoxType.cake).score, 1);
      final wrong = Scoring.box(BoxType.small, BoxType.gift);
      expect(wrong.score, 0.3);
      expect(wrong.issue, StationIssue.wrongBox);
    });
  });

  test('ngưỡng sao', () {
    expect(Scoring.starsFor(1), 5);
    expect(Scoring.starsFor(0.90), 5);
    expect(Scoring.starsFor(0.8999), 4);
    expect(Scoring.starsFor(0.75), 4);
    expect(Scoring.starsFor(0.7499), 3);
    expect(Scoring.starsFor(0.60), 3);
    expect(Scoring.starsFor(0.5999), 2);
    expect(Scoring.starsFor(0.40), 2);
    expect(Scoring.starsFor(0.3999), 1);
    expect(Scoring.starsFor(0), 1);
  });

  group('evaluate', () {
    test('ví dụ 1: cupcakeVanilla 4★ khách thường, decor 0%', () {
      final o = _order(RecipeId.cupcakeVanilla);
      // frost 0.5 → điểm 1/3 → quality 0.75 + 0.25/3 ≈ 0.833 → 4★
      final r = Scoring.evaluate(
        order: o,
        customer: _regular,
        outcome: _perfect(o, frost: 0.5),
        modifiers: BakeModifiers.base,
        decorTipBonusPct: 0,
      );
      expect(r.stars, 4);
      expect(r.payment, 30);
      expect(r.tip, 6);
      expect(r.cost, 8);
      expect(r.net, 28);
      expect(r.xp, 35);
      expect(r.weakest, StationId.frost);
      expect(r.complaint, FeedbackKey.frostPatchy);
      expect(r.praise, FeedbackKey.bakeGood); // hoà 1.0 → ưu tiên bake
      expect(r.stations.length, 6);
    });

    test('ví dụ 2: cheesecake 5★ VIP, decor 28%', () {
      final o = _order(RecipeId.cheesecake, box: BoxType.gift, toppings: const [ToppingRequest(ToppingId.blueberry, 3)]);
      final r = Scoring.evaluate(
        order: o,
        customer: _vip,
        outcome: _perfect(o),
        modifiers: BakeModifiers.base,
        decorTipBonusPct: 28,
      );
      expect(r.quality, 1);
      expect(r.stars, 5);
      expect(r.payment, 88);
      expect(r.tip, 72);
      expect(r.xp, 60);
      expect(r.praise, FeedbackKey.allGood);
      expect(r.complaint, isNull);
      expect(r.isPerfectBake, isTrue);
    });

    test('trần % tip decor = 30', () {
      final o = _order(RecipeId.cheesecake, box: BoxType.gift, toppings: const [ToppingRequest(ToppingId.blueberry, 3)]);
      BakeResult eval(int pct) => Scoring.evaluate(
            order: o,
            customer: _vip,
            outcome: _perfect(o),
            modifiers: BakeModifiers.base,
            decorTipBonusPct: pct,
          );
      expect(eval(80).tip, eval(30).tip);
      expect(eval(30).tip, (80 * 0.35 * 2 * 1.3).round());
    });

    test('dưới 3★ không có tip; bánh cháy bị chê bake', () {
      final o = _order(RecipeId.cupcakeVanilla);
      final r = Scoring.evaluate(
        order: o,
        customer: _regular,
        outcome: _perfect(o, release: 1.0, frost: 0.4, box: BoxType.cake),
        modifiers: BakeModifiers.base,
        decorTipBonusPct: 0,
      );
      expect(r.stars, lessThan(3));
      expect(r.tip, 0);
      expect(r.weakest, StationId.bake);
      expect(r.complaint, FeedbackKey.bakeBurnt);
      expect(r.praise, isNot(FeedbackKey.allGood));
    });

    test('thả sai khuôn: trừ 0.05/lần (tối đa 0.10) và bị chê khuôn', () {
      final o = _order(RecipeId.cupcakeVanilla);
      final one = Scoring.evaluate(
          order: o, customer: _regular, outcome: _perfect(o, wrongMould: 1), modifiers: BakeModifiers.base, decorTipBonusPct: 0);
      expect(one.quality, closeTo(0.95, 1e-9));
      expect(one.stars, 5);
      expect(one.weakest, StationId.mould);
      expect(one.complaint, FeedbackKey.mouldWrong);
      expect(one.praise, FeedbackKey.bakeGood); // có complaint → không allGood
      final many = Scoring.evaluate(
          order: o, customer: _regular, outcome: _perfect(o, wrongMould: 4), modifiers: BakeModifiers.base, decorTipBonusPct: 0);
      expect(many.quality, closeTo(0.90, 1e-9));
    });

    test('hoà điểm: ưu tiên bake > frost > topping > mix > box > mould', () {
      final o = _order(RecipeId.cupcakeVanilla);
      final all = Scoring.evaluate(
          order: o, customer: _regular, outcome: _perfect(o), modifiers: BakeModifiers.base, decorTipBonusPct: 0);
      expect(all.weakest, StationId.bake);
      expect(all.complaint, isNull);
      // frost và topping cùng 0 → yếu nhất là frost (đứng trước topping).
      final tie = Scoring.evaluate(
        order: o,
        customer: _regular,
        outcome: BakeOutcome(
          wrongMouldDrops: 0,
          mixTurns: 3,
          bakeRelease: o.recipeData.bakeTarget,
          frostCoverage: 0,
          toppingsPlaced: const {},
          boxChosen: o.box,
        ),
        modifiers: BakeModifiers.base,
        decorTipBonusPct: 0,
      );
      expect(tie.weakest, StationId.frost);
      expect(tie.complaint, FeedbackKey.frostPatchy);
      expect(tie.praise, FeedbackKey.bakeGood);
    });

    test('nâng cấp nới vùng: lò 5 coi d=0.1 là hoàn hảo', () {
      final o = _order(RecipeId.cupcakeVanilla);
      const oven5 = BakeModifiers(
          bakePerfectHalfWidth: 0.10, bakeOkHalfWidth: 0.20, mixPerfectBand: 0.2, frostBrushRadius: 32, toppingSnapRadius: 32);
      final r = Scoring.evaluate(
          order: o, customer: _regular, outcome: _perfect(o, release: 0.75), modifiers: oven5, decorTipBonusPct: 0);
      expect(r.stations[StationId.bake]!.score, 1);
    });
  });
}
