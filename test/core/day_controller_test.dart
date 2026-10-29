import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/day_controller.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

GameState _stateAtLevel(int level, {Set<StorySceneId> seen = const {}}) {
  final s = GameState.newGame(clock: _clock);
  s.addXp(Economy.xpToReachLevel(level));
  for (final id in seen) {
    s.markSceneSeen(id);
  }
  return s;
}

/// Mọi cảnh truyện đã xem → không có cảnh chờ, không bạn quen bị ép.
const _allSeen = {...StorySceneId.values};

BakeOutcome _perfectFor(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: o.recipeData.bakeTarget,
      frostCoverage: 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

void main() {
  test('số khách theo cấp', () {
    for (final (level, count) in [(1, 4), (3, 4), (4, 5), (9, 5), (10, 6), (15, 6)]) {
      final c = DayController(state: _stateAtLevel(level, seen: _allSeen), random: Random(level));
      expect(c.total, count, reason: 'cấp $level');
      expect(c.customers.length, count);
      expect(c.orders.length, count);
      expect(c.index, 0);
      expect(c.isFinished, isFalse);
    }
  });

  test('đơn hợp lệ: món/topping đã mở, kem đúng món, VIP → hộp quà', () {
    for (final level in [1, 2, 5, 7, 9, 12, 15]) {
      final state = _stateAtLevel(level, seen: {StorySceneId.prologue, StorySceneId.hoa1, StorySceneId.linh1, StorySceneId.kenji1});
      for (var seed = 0; seed < 40; seed++) {
        final c = DayController(state: state, random: Random(seed * 31 + level));
        for (var i = 0; i < c.total; i++) {
          final o = c.orders[i];
          final cust = c.customers[i];
          final recipe = Catalog.recipe(o.recipe);
          expect(o.id, i);
          expect(state.isRecipeUnlocked(o.recipe), isTrue, reason: '${o.recipe} ở cấp $level');
          expect(recipe.frostings, contains(o.frosting));
          expect(o.toppings, isNotEmpty);
          expect(o.toppings.length, lessThanOrEqualTo(level < 5 ? 1 : 2));
          for (final t in o.toppings) {
            expect(state.isToppingUnlocked(t.topping), isTrue);
            expect(recipe.toppings, contains(t.topping));
            final max = t.topping == ToppingId.candle ? 3 : (level < 7 ? 3 : 4);
            expect(t.count, inInclusiveRange(1, max));
          }
          expect(o.toppings.map((t) => t.topping).toSet().length, o.toppings.length);
          if (cust.kind == CustomerKind.vip) {
            expect(level, greaterThanOrEqualTo(7));
            expect(o.box, BoxType.gift);
            expect(o.line, OrderLineKind.vip);
          } else {
            expect(o.box, recipe.box);
          }
          if (cust.kind == CustomerKind.friend) {
            expect(cust.friend, isNotNull);
            expect(o.line.name, cust.friend!.name);
          } else {
            expect(cust.friend, isNull);
          }
        }
        final friends = c.customers.where((x) => x.kind == CustomerKind.friend).length;
        expect(friends, lessThanOrEqualTo(1));
      }
    }
  });

  test('có khách VIP ở cấp 9 (xác suất 30%)', () {
    final state = _stateAtLevel(9, seen: _allSeen);
    var vip = 0;
    for (var seed = 0; seed < 30; seed++) {
      vip += DayController(state: state, random: Random(seed)).customers.where((c) => c.isVip).length;
    }
    expect(vip, greaterThan(0));
  });

  test('cảnh truyện: prologue ngày 1, hoa1 ngày 2 với khách đầu là ông Hòa', () {
    final state = GameState.newGame(clock: _clock);
    final day1 = DayController(state: state, random: Random(1));
    expect(day1.pendingScene?.id, StorySceneId.prologue);
    expect(day1.customers.every((c) => c.kind != CustomerKind.friend), isTrue);
    day1.markSceneShown();
    expect(day1.pendingScene, isNull);
    expect(state.seenScenes, contains(StorySceneId.prologue));
    // Cùng ngày 1, hoa1 cần ngày 2 → không có cảnh.
    expect(DayController(state: state, random: Random(2)).pendingScene, isNull);

    state.completeDay();
    final day2 = DayController(state: state, random: Random(3));
    expect(day2.pendingScene?.id, StorySceneId.hoa1);
    expect(day2.customers.first.friend, FriendId.hoa);
    expect(day2.orders.first.recipe, RecipeId.cupcakeVanilla);
    expect(day2.orders.first.line, OrderLineKind.hoa);
  });

  test('kenji3 ép topping việt quất ×3', () {
    final state = _stateAtLevel(10, seen: {...StorySceneId.values}..removeAll({StorySceneId.kenji3, StorySceneId.finale}));
    final c = DayController(state: state, random: Random(9));
    expect(c.pendingScene?.id, StorySceneId.kenji3);
    expect(c.orders.first.recipe, RecipeId.cheesecake);
    expect(c.orders.first.toppings, const [ToppingRequest(ToppingId.blueberry, 3)]);
  });

  test('evaluate thuần; commit cộng xu/xp; finishDay tăng ngày', () {
    final state = _stateAtLevel(1, seen: _allSeen);
    final coins0 = state.coins;
    final xp0 = state.xp;
    final c = DayController(state: state, random: Random(5));
    final r0 = c.evaluate(_perfectFor(c.currentOrder));
    expect(state.coins, coins0); // evaluate chưa đổi state
    expect(r0.stars, 5);
    expect(c.canRemake(r0), isFalse);

    var expectedNet = 0;
    var expectedXp = 0;
    while (!c.isFinished) {
      final r = c.evaluate(_perfectFor(c.currentOrder));
      expectedNet += r.net;
      expectedXp += r.xp;
      c.commit(r);
    }
    expect(c.index, c.total);
    expect(state.totalServed, c.total);
    expect(state.xp, xp0 + expectedXp);

    final summary = c.finishDay();
    expect(state.dayNumber, 2);
    expect(summary.dayNumber, 1);
    expect(summary.records.length, c.total);
    expect(summary.net, expectedNet);
    expect(summary.revenue + summary.tips - summary.costs, summary.net);
    expect(summary.xpGained, expectedXp + Economy.dayBonusXp);
    expect(summary.averageStars, 5);
    expect(state.xp, xp0 + expectedXp + Economy.dayBonusXp);
    expect(summary.levelBefore, 1);
    expect(summary.levelAfter, state.level);
    final levelUpCoins = [for (var l = 2; l <= state.level; l++) Economy.levelUpCoins(l)].fold<int>(0, (a, b) => a + b);
    expect(state.coins, coins0 + expectedNet + levelUpCoins);
    if (summary.levelAfter > 1) {
      expect(summary.unlocks, contains(Economy.unlocksAtLevel(2).first));
    }
    // Gọi lại không cộng thêm lần nữa.
    expect(identical(c.finishDay(), summary), isTrue);
    expect(state.dayNumber, 2);
  });

  test('thành thạo món + gem lần đầu đạt 3', () {
    final state = _stateAtLevel(1, seen: _allSeen);
    final c = DayController(state: state, random: Random(8));
    final recipe = c.currentOrder.recipe;
    final gems0 = state.gems;
    c.commit(c.evaluate(_perfectFor(c.currentOrder)));
    expect(state.recipeMastery(recipe), 3);
    expect(state.gems, gems0 + Economy.masteryGemReward);
  });

  test('làm lại: chỉ khi ≤ 2★, 1 lần/đơn, còn lượt quảng cáo', () {
    final state = _stateAtLevel(1, seen: _allSeen);
    final c = DayController(state: state, random: Random(4));
    final o = c.currentOrder;
    final bad = c.evaluate(BakeOutcome(
      wrongMouldDrops: 3,
      mixTurns: 0,
      bakeRelease: 1,
      frostCoverage: 0,
      toppingsPlaced: const {},
      boxChosen: o.box == BoxType.gift ? BoxType.small : BoxType.gift,
    ));
    expect(bad.stars, 1);
    expect(c.canRemake(bad), isTrue);
    c.markRemakeUsed();
    expect(c.canRemake(bad), isFalse);
    c.commit(bad);
    expect(c.canRemake(bad), isTrue); // đơn kế tiếp
    for (var i = 0; i < Economy.maxRewardedPerDay; i++) {
      state.registerRewardedShown();
    }
    expect(c.canRemake(bad), isFalse);
  });
}
