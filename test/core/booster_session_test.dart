import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

/// GĐ6 §1: vật phẩm hỗ trợ áp vào `LevelSession` (tham số, không đọc GameState) + topping thật của bánh trong tủ.
const _defaults = LevelDefaults(jitterPct: 0);

LevelData _level({
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate],
  int caseSlots = 3,
  int startStock = 3,
  double patienceSec = 40,
  double every = 10,
  Map<String, num> overrides = const {},
}) =>
    LevelData(
      id: 4,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 120,
      goal: const LevelGoal(type: GoalType.customers, stars: [2, 4, 6]),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: patienceSec,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      specials: const [SpecialVisit(atSec: 200, who: SpecialWho.hoa, recipe: RecipeId.eggTart)],
      newRecipe: menu.last,
      overrides: overrides,
    );

LevelSession _session(LevelData level, {Set<BoosterId> boosters = const {}, ShopSetup setup = ShopSetup.base}) =>
    LevelSession(
      level: level,
      defaults: _defaults,
      modifiers: BakeModifiers.base,
      setup: setup,
      boosters: boosters,
      random: math.Random(1),
    );

void _until(LevelSession s, bool Function() cond, {double maxSec = 60}) {
  final end = s.elapsed + maxSec;
  while (!cond()) {
    if (s.elapsed >= end || s.isOver) fail('quá $maxSec s mà điều kiện chưa đúng');
    s.advance(LevelSession.step);
    s.drainEvents();
  }
}

/// Mẻ qua 6 trạm với topping [topping] (3 lần chạm) — `null` = topping đúng; các trạm khác đúng hết.
Batch _batch(LevelSession s, RecipeId r, {ToppingId? topping}) {
  expect(s.startBatch(r), isTrue);
  final b = s.kitchen.prep!;
  s.pickMould(b.correctMould);
  s.finishMix(1.0);
  _until(s, () => b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget);
  s.takeOut(b.oven);
  s.finishFrost(1.0);
  for (var i = 0; i < 3; i++) {
    s.addTopping(topping ?? b.correctTopping);
  }
  expect(s.pickBox(b.correctBox), isTrue);
  return b;
}

void main() {
  group('booster trong LevelSession', () {
    test('không có vật phẩm: thông số như cũ, tủ chỉ có startStock', () {
      final s = _session(_level());
      expect(s.boosters, isEmpty);
      expect(s.tuning.patienceMult, 1.0);
      expect(s.tuning.ovenSec, _defaults.ovenSec);
      expect(s.displayCase.totalCount, 3);
      expect(s.finish().boosters, isEmpty);
    });

    test('fullCase: mỗi ô một món menu (lặp vòng), đủ sức chứa, bánh 4★ topping chuẩn — kể cả ô thêm của tiệm', () {
      const setup = ShopSetup(caseSlotsBonus: 1, slotCapacity: 8);
      final s = _session(_level(), boosters: {BoosterId.fullCase}, setup: setup);
      final dc = s.displayCase;
      expect(dc.slots, 4);
      expect(dc.slotCapacity, 8);
      // Món mới của level (cupcakeChocolate) xếp trước, rồi lặp vòng theo menu.
      expect([for (final slot in dc.items) slot.recipe],
          [RecipeId.cupcakeChocolate, RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.cupcakeVanilla]);
      for (final slot in dc.items) {
        expect(slot.count, 8);
        expect(slot.countWithStars(4), 8);
        expect(slot.allDefaultTopping, isTrue);
      }
      expect(dc.totalCount, 32); // thay startStock (3 cái 3★)
      expect(dc.roomFor(RecipeId.cupcakeVanilla), 0);
      expect(s.finish().boosters, {BoosterId.fullCase});
    });

    test('fullCase: menu nhiều món hơn số ô → chừa một ô trống cho món còn lại', () {
      const menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];
      final s = _session(_level(menu: menu), boosters: {BoosterId.fullCase});
      final dc = s.displayCase;
      expect([for (final slot in dc.items) slot.recipe], [RecipeId.eggTart, RecipeId.cupcakeVanilla, null]);
      expect(dc.totalCount, 2 * dc.slotCapacity);
      expect(dc.roomFor(RecipeId.muffinBlueberry), dc.slotCapacity);
    });

    test('patience: kiên nhẫn khách vãng lai ×1.3 (nhân dồn với tiệm), khách đặc biệt không đổi', () {
      final base = _session(_level(), setup: const ShopSetup(patienceMult: 1.15));
      final s = _session(_level(), boosters: {BoosterId.patience}, setup: const ShopSetup(patienceMult: 1.15));
      expect(s.tuning.patienceMult, closeTo(1.15 * 1.3, 1e-9));
      expect(s.tuning.specialPatienceSec, base.tuning.specialPatienceSec);
      _until(s, () => s.customers.isNotEmpty);
      expect(s.customers.first.patienceMax, closeTo(40 * 1.15 * 1.3, 1e-6));
      expect(s.tuning.ovenSec, base.tuning.ovenSec);
    });

    test('ovenBoost: kim chạy gấp đôi tới mép vùng "được", từ đó như thường — vùng vàng / lúc cháy theo giây không đổi',
        () {
      final level = _level(overrides: const {'ovenSec': 8});
      final base = _session(level, setup: const ShopSetup(ovenSec: 5.6));
      final s = _session(level, boosters: {BoosterId.ovenBoost}, setup: const ShopSetup(ovenSec: 5.6));
      expect(s.tuning.ovenSec, closeTo(base.tuning.ovenSec * 0.5, 1e-9));
      expect(s.tuning.patienceMult, base.tuning.patienceMult);
      expect(s.tuning.specialPatienceSec, base.tuning.specialPatienceSec);
      expect(s.tuning.specialRewardMult, base.tuning.specialRewardMult);
      expect(s.modifiers, base.modifiers, reason: 'đơn đặc biệt 6 trạm dùng cùng vùng như không có vật phẩm');

      /// Giây (từ lúc vào lò) kim chạm: mép vùng "được", vạch chuẩn, cháy.
      (double, double, double) marks(LevelSession x) {
        x.startBatch(RecipeId.cupcakeVanilla);
        final b = x.kitchen.prep!;
        x.pickMould(b.correctMould);
        x.finishMix(1.0);
        final t0 = x.elapsed;
        final edge = b.bakeTarget - x.modifiers.bakeOkHalfWidth;
        expect(x.ovenSecondsUntil(b, b.bakeTarget), greaterThan(0));
        _until(x, () => b.ovenProgress >= edge - 1e-9);
        final tEdge = x.elapsed - t0;
        _until(x, () => b.ovenProgress >= b.bakeTarget - 1e-9);
        final tTarget = x.elapsed - t0;
        _until(x, () => b.burnt);
        return (tEdge, tTarget, x.elapsed - t0);
      }

      final (bEdge, bTarget, bBurn) = marks(base);
      final (edge, target, burn) = marks(s);
      expect(edge, closeTo(bEdge / 2, 0.05), reason: 'đoạn chờ trước vùng nhanh gấp đôi');
      expect(target - edge, closeTo(bTarget - bEdge, 0.05), reason: 'vùng tới vạch: cùng số giây');
      expect(burn - target, closeTo(bBurn - bTarget, 0.05), reason: 'từ vạch tới cháy: cùng số giây');
      expect(target, lessThan(bTarget * 0.75));
    });

    test('hasSold: false tới lần bán đầu tiên (để UI hoàn vật phẩm khi Thoát / Chơi lại)', () {
      final s = _session(_level(startStock: 3, menu: const [RecipeId.cupcakeVanilla], patienceSec: 500, every: 2),
          boosters: {BoosterId.patience});
      expect(s.hasSold, isFalse);
      _until(s, () => s.customers.any((c) => c.canBuy));
      expect(s.hasSold, isFalse);
      s.sell(s.customers.firstWhere((c) => c.canBuy).id);
      expect(s.hasSold, isTrue);
    });

    test('ba vật phẩm cùng lúc; tập vật phẩm chỉ đọc; kết quả ghi đủ', () {
      final all = {...BoosterId.values};
      final s = _session(_level(), boosters: all);
      expect(() => s.boosters.add(BoosterId.patience), throwsUnsupportedError);
      expect(s.finish().boosters, all);
    });
  });

  group('topping thật của bánh trong tủ', () {
    test('mẻ chọn hũ nhiễu → ô tủ ghi đúng topping đó; startStock / mẻ topping đúng → topping chuẩn', () {
      final s = _session(_level(startStock: 3, menu: const [RecipeId.cupcakeVanilla]));
      final slot = s.displayCase.items.first;
      expect(slot.count, 3);
      expect(slot.defaultTopping, Catalog.recipe(RecipeId.cupcakeVanilla).toppings.first);
      expect([for (var i = 0; i < 3; i++) slot.isDefaultToppingAt(i)], [true, true, true]);

      final correct = Catalog.recipe(RecipeId.cupcakeVanilla).toppings.first;
      final wrong = ToppingId.values.firstWhere((t) => t != correct && t != ToppingId.candle);
      final b = _batch(s, RecipeId.cupcakeVanilla, topping: wrong);
      expect(b.placedTopping, wrong);
      expect(slot.count, 6);
      expect([for (var i = 0; i < 6; i++) slot.toppingAt(i)], [...List.filled(3, correct), ...List.filled(3, wrong)]);
      expect(slot.isDefaultToppingAt(5), isFalse);
      expect(slot.allDefaultTopping, isFalse);
      expect(() => slot.toppingAt(6), throwsRangeError);
    });

    test('2 chạm hũ nhiễu + 1 chạm hũ đúng → topping nhiễu (hũ chạm nhiều nhất)', () {
      final s = _session(_level(startStock: 0, menu: const [RecipeId.cupcakeVanilla]));
      s.startBatch(RecipeId.cupcakeVanilla);
      final b = s.kitchen.prep!;
      s.pickMould(b.correctMould);
      s.finishMix(1.0);
      _until(s, () => b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget);
      s.takeOut(b.oven);
      s.finishFrost(1.0);
      final wrong = b.toppingChoices.firstWhere((t) => t != b.correctTopping);
      s
        ..addTopping(wrong)
        ..addTopping(b.correctTopping)
        ..addTopping(wrong);
      expect(b.placedTopping, wrong);
      s.pickBox(b.correctBox);
      final slot = s.displayCase.items.first;
      expect([for (var i = 0; i < slot.count; i++) slot.toppingAt(i)], List.filled(3, wrong));
    });

    test('bán lấy cái sao cao nhất trước (dù topping khác), các cái còn lại giữ thứ tự + topping', () {
      final s = _session(_level(startStock: 3, menu: const [RecipeId.cupcakeVanilla], patienceSec: 500, every: 2));
      final b = _batch(s, RecipeId.cupcakeVanilla); // 5★ topping đúng
      expect(b.stars, 5);
      final slot = s.displayCase.items.first;
      expect([for (var i = 0; i < slot.count; i++) slot.starsAt(i)], [3, 3, 3, 5, 5, 5]);
      _until(s, () => s.customers.any((c) => c.canBuy));
      final c = s.customers.firstWhere((c) => c.canBuy);
      expect(s.sell(c.id), SellResult.sold);
      expect(s.drainEvents().firstWhere((e) => e.type == SessionEventType.sold).stars, 5);
      expect([for (var i = 0; i < slot.count; i++) slot.starsAt(i)], [3, 3, 3, 5, 5]);
    });

    test('bánh sai topping sao thấp hơn vẫn bán được (sau bánh sao cao)', () {
      final s = _session(_level(startStock: 0, menu: const [RecipeId.cupcakeVanilla], patienceSec: 500, every: 2));
      final correct = Catalog.recipe(RecipeId.cupcakeVanilla).toppings.first;
      final wrong = ToppingId.values.firstWhere((t) => t != correct && t != ToppingId.candle);
      final bad = _batch(s, RecipeId.cupcakeVanilla, topping: wrong);
      final good = _batch(s, RecipeId.cupcakeVanilla);
      final slot = s.displayCase.items.first;
      expect(slot.count, 6);
      expect(bad.placedTopping, wrong);
      expect(bad.stars, lessThan(good.stars));
      final sold = <int>[];
      for (var k = 0; k < 6; k++) {
        _until(s, () => s.customers.any((c) => c.canBuy), maxSec: 100);
        s.sell(s.customers.firstWhere((c) => c.canBuy).id);
        sold.add(s.drainEvents().firstWhere((e) => e.type == SessionEventType.sold).stars);
      }
      expect(sold, [...List.filled(3, good.stars), ...List.filled(3, bad.stars)]);
      expect(slot.isEmpty, isTrue);
    });
  });
}
