import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/models/quest.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';

const _defaults = LevelDefaults(jitterPct: 0);

LevelData _level({
  int id = 1,
  int durationSec = 120,
  GoalType goal = GoalType.customers,
  List<int> stars = const [2, 4, 6],
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla],
  int caseSlots = 3,
  int startStock = 0,
  double patienceSec = 40,
  double every = 10,
  double endEvery = 10,
  double rushAtPct = 100,
  double rushEvery = 10,
  List<SpecialVisit> specials = const [],
  Map<String, num> overrides = const {},
}) =>
    LevelData(
      id: id,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: durationSec,
      goal: LevelGoal(type: goal, stars: stars),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: patienceSec,
      spawn: SpawnCurve(startEverySec: every, endEverySec: endEvery, rushAtPct: rushAtPct, rushEverySec: rushEvery),
      specials: specials,
      newRecipe: menu.last,
      overrides: overrides,
    );

LevelSession _session(LevelData level, {int seed = 1}) =>
    LevelSession(level: level, defaults: _defaults, modifiers: BakeModifiers.base, random: math.Random(seed));

/// Chạy từng bước tới khi [cond] đúng (tối đa [maxSec] giây màn chơi); trả sự kiện đã gom.
List<SessionEvent> _until(LevelSession s, bool Function() cond, {double maxSec = 60}) {
  final events = <SessionEvent>[];
  final end = s.elapsed + maxSec;
  while (!cond()) {
    if (s.elapsed >= end || s.isOver) fail('quá $maxSec s mà điều kiện chưa đúng (elapsed ${s.elapsed})');
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  events.addAll(s.drainEvents());
  return events;
}

List<SessionEvent> _run(LevelSession s, double sec) {
  final events = <SessionEvent>[];
  final n = (sec / LevelSession.step).round();
  for (var i = 0; i < n; i++) {
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  return events;
}

LevelCustomer? _atCounter(LevelSession s) {
  for (final c in s.customers) {
    if (c.canBuy) return c;
  }
  return null;
}

/// Một mẻ hoàn hảo (khuôn đúng, trộn 1 vòng, lấy lò đúng vạch, phủ kín, topping đúng, hộp đúng) → vào tủ / chờ tủ.
void _perfectBatch(LevelSession s, RecipeId r) {
  expect(s.startBatch(r), isTrue);
  final b = s.kitchen.prep!;
  expect(s.pickMould(b.correctMould), isTrue);
  s.finishMix(1.0);
  _until(s, () => b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget);
  expect(s.takeOut(b.oven), isTrue);
  expect(b.stage, BatchStage.frost);
  s.finishFrost(1.0);
  for (var i = 0; i < 3; i++) {
    s.addTopping(b.correctTopping);
  }
  expect(b.stage, BatchStage.box);
  expect(s.pickBox(b.correctBox), isTrue);
}

void main() {
  group('sinh khách', () {
    test('SpawnCurve: thưa → dày → cao điểm', () {
      const curve = SpawnCurve(startEverySec: 14, endEverySec: 10, rushAtPct: 80, rushEverySec: 7);
      expect(curve.intervalAt(0), 14);
      expect(curve.intervalAt(0.4), closeTo(12, 1e-9));
      expect(curve.intervalAt(0.79), lessThan(10.1));
      expect(curve.intervalAt(0.8), 7);
      expect(curve.intervalAt(1.2), 7); // sau +30 giây vẫn cao điểm
      expect(curve.isRushAt(0.79), isFalse);
      expect(curve.isRushAt(0.8), isTrue);
    });

    test('mật độ khách tăng dần, có sự kiện cao điểm, ngừng sinh khi còn < 6 s', () {
      final s = _session(_level(
        durationSec: 100,
        every: 10,
        endEvery: 4,
        rushAtPct: 60,
        rushEvery: 2,
        patienceSec: 500,
        overrides: const {'maxQueue': 100},
      ));
      final arrivals = <double>[];
      var rushAt = -1.0;
      while (!s.isOver) {
        s.advance(LevelSession.step);
        for (final e in s.drainEvents()) {
          if (e.type == SessionEventType.customerArrived) arrivals.add(s.elapsed);
          if (e.type == SessionEventType.rushStarted) rushAt = s.elapsed;
        }
      }
      int count(double a, double b) => arrivals.where((t) => t >= a && t < b).length;
      expect(count(0, 30), lessThan(count(30, 60)));
      expect(count(30, 60), lessThan(count(60, 90)));
      expect(rushAt, closeTo(60, 0.1));
      expect(s.isRush, isTrue);
      expect(arrivals.last, lessThanOrEqualTo(94 + 1e-6));
    });

    test('hàng đầy → khách quay đi, tính lost', () {
      final s = _session(
        _level(every: 1, endEvery: 1, rushEvery: 1, patienceSec: 500, overrides: const {'maxQueue': 4}),
      );
      final events = _run(s, 10);
      expect(events.where((e) => e.type == SessionEventType.turnedAway), isNotEmpty);
      expect(s.lost, greaterThan(0));
      final waiting = s.customers.where((c) => !c.isLeaving).length;
      expect(waiting, lessThanOrEqualTo(4));
      expect(s.customers.where((c) => c.turnedAway).every((c) => c.slot == -1), isTrue);
      expect(() => s.customers.first.wants.add(RecipeId.macaron), throwsUnsupportedError);
      expect(() => s.customers.removeLast(), throwsUnsupportedError);
      expect(identical(s.customers.first.wants, s.customers.first.wants), isTrue, reason: 'không cấp phát mỗi lần đọc');
    });

    test('khách ở quầy theo chỗ 0..2, hàng chờ đánh số từ 0', () {
      final s = _session(
        _level(every: 1, endEvery: 1, rushEvery: 1, patienceSec: 500, overrides: const {'maxQueue': 10}),
      );
      _run(s, 9);
      final counter = s.customers.where((c) => c.phase == CustomerPhase.atCounter).map((c) => c.slot).toSet();
      expect(counter, {0, 1, 2});
      final queued = s.customers.where((c) => c.phase == CustomerPhase.queued).map((c) => c.slot).toList()..sort();
      expect(queued, [for (var i = 0; i < queued.length; i++) i]);
    });
  });

  group('kiên nhẫn + combo', () {
    test('hết kiên nhẫn → bỏ đi, lost++, combo về 0', () {
      final s = _session(_level(
        startStock: 1,
        patienceSec: 8,
        every: 2,
        endEvery: 2,
        rushEvery: 2,
        overrides: const {'comboWindowSec': 100},
      ));
      final first = _until(s, () => _atCounter(s) != null);
      expect(first.any((e) => e.type == SessionEventType.customerArrived), isTrue);
      expect(s.sell(_atCounter(s)!.id), SellResult.sold);
      expect(s.combo, 1);
      final events = _until(s, () => s.lost > 0, maxSec: 20);
      expect(events.any((e) => e.type == SessionEventType.walkedOut), isTrue);
      expect(events.any((e) => e.type == SessionEventType.comboLost && e.combo == 1), isTrue);
      expect(s.combo, 0);
      expect(s.lost, 1);
    });

    test('kiên nhẫn trong hàng chờ giảm 50%, ở quầy 100%; dừng thì không giảm', () {
      final s = _session(_level(patienceSec: 40));
      _until(s, () => _atCounter(s) != null);
      final c = _atCounter(s)!;
      final before = c.patience;
      _run(s, 2);
      expect(before - c.patience, closeTo(2, 0.05));
      s.paused = true;
      final p = c.patience;
      final t = s.elapsed;
      s.advance(1);
      expect(c.patience, p);
      expect(s.elapsed, t);
      // Lúc vào cửa (1.2 s) giảm nửa tốc độ.
      expect(c.patienceMax - before, closeTo(LevelCustomer.enterSec * 0.5, 0.1));
    });

    test('combo tăng khi bán liên tiếp trong cửa sổ, tắt khi quá cửa sổ; xu theo công thức', () {
      final s = _session(_level(startStock: 6, every: 2, endEvery: 2, rushEvery: 2, patienceSec: 500));
      final sold = <SessionEvent>[];
      for (var k = 0; k < 3; k++) {
        _until(s, () => _atCounter(s) != null);
        expect(s.sell(_atCounter(s)!.id), SellResult.sold);
        sold.addAll(s.drainEvents().where((e) => e.type == SessionEventType.sold));
      }
      expect([for (final e in sold) e.combo], [1, 2, 3]);
      expect(s.combo, 3);
      expect(s.comboMult, closeTo(1.2, 1e-9));
      expect(s.bestCombo, 3);
      // 3★, kiên nhẫn đầy: (30 × 0.85 + 30 × 0.10) × 1.0 = 28.5 → 29.
      final price = Catalog.recipe(RecipeId.cupcakeVanilla).price;
      expect(sold.first.coins, ((price * Economy.payMult[3]! + price * Economy.tipRate[3]!) * 1.0).round());
      expect(sold[2].coins, ((price * Economy.payMult[3]! + price * Economy.tipRate[3]!) * 1.2).round());
      expect(s.coins, sold.fold<int>(0, (a, e) => a + e.coins));
      final events = _run(s, s.tuning.comboWindowSec + 0.2);
      expect(s.combo, 0);
      expect(events.any((e) => e.type == SessionEventType.comboLost && e.combo == 3), isTrue);
      expect(s.comboMult, 1.0);
    });
  });

  group('bán', () {
    test('đúng món / không có trong tủ / chưa tới quầy', () {
      final s = _session(_level(
        menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate],
        startStock: 3, // 3 cái vani 3★ của món đầu
        every: 1,
        endEvery: 1,
        rushEvery: 1,
        patienceSec: 500,
        overrides: const {'maxQueue': 10},
      ));
      _run(s, 8);
      final queued = s.customers.firstWhere((c) => c.phase == CustomerPhase.queued);
      expect(s.sell(queued.id), SellResult.invalid);
      expect(s.sell(9999), SellResult.invalid);
      final atCounter = s.customers.where((c) => c.canBuy).toList();
      final wantsChoc = atCounter.where((c) => c.want == RecipeId.cupcakeChocolate).toList();
      final wantsVan = atCounter.where((c) => c.want == RecipeId.cupcakeVanilla).toList();
      if (wantsChoc.isNotEmpty) expect(s.sell(wantsChoc.first.id), SellResult.notInCase);
      if (wantsVan.isNotEmpty) {
        final before = s.displayCase.countOf(RecipeId.cupcakeVanilla);
        expect(s.sell(wantsVan.first.id), SellResult.sold);
        expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), before - 1);
        expect(s.served, 1);
        expect(s.customer(wantsVan.first.id)!.phase, CustomerPhase.leavingHappy);
      }
      expect(wantsChoc.isNotEmpty || wantsVan.isNotEmpty, isTrue);
    });

    test('lấy bánh sao cao nhất trước', () {
      final s = _session(_level(startStock: 3, patienceSec: 500, every: 2, endEvery: 2, rushEvery: 2));
      _perfectBatch(s, RecipeId.cupcakeVanilla); // +3 cái 5★
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), 6);
      _until(s, () => _atCounter(s) != null);
      expect(s.sell(_atCounter(s)!.id), SellResult.sold);
      final sold = s.drainEvents().firstWhere((e) => e.type == SessionEventType.sold);
      expect(sold.stars, 5);
    });
  });

  group('bếp nhanh', () {
    test('mẻ hoàn hảo: khuôn sai được tính, lò báo vạch, 5★ vào tủ, perfectBakes', () {
      final s = _session(_level(patienceSec: 500));
      expect(s.startBatch(RecipeId.cheesecake), isFalse, reason: 'không thuộc menu');
      expect(s.startBatch(RecipeId.cupcakeVanilla), isTrue);
      expect(s.startBatch(RecipeId.cupcakeVanilla), isFalse, reason: 'khu chuẩn bị đang bận');
      final b = s.kitchen.prep!;
      expect(() => s.kitchen.ovens[0] = null, throwsUnsupportedError);
      expect(b.mouldChoices, hasLength(3));
      expect(b.mouldChoices, contains(b.correctMould));
      expect(b.toppingChoices, hasLength(2));
      expect(b.toppingChoices, contains(b.correctTopping));
      expect(b.boxChoices.toSet(), BoxType.values.toSet());
      final wrong = b.mouldChoices.firstWhere((m) => m != b.correctMould);
      expect(s.pickMould(wrong), isFalse);
      expect(b.wrongMoulds, 1);
      expect(b.stage, BatchStage.mould);
      s.cancelPrep();
      expect(s.kitchen.prep, isNull);

      _perfectBatch(s, RecipeId.cupcakeVanilla);
      final events = s.drainEvents();
      expect(events.any((e) => e.type == SessionEventType.batchReady && e.stars == 5 && e.count == 3), isTrue);
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), 3);
      expect(s.displayCase.items.first.bestStars, 5);
      expect(s.kitchen.finish, isNull);
      final r = s.finish();
      expect(r.perfectBakes, 1);
      expect(r.recipeStars, {RecipeId.cupcakeVanilla: 5});
    });

    test('lò: kim tới vạch đúng lúc ovenSec, để quá → cháy, tự ra', () {
      final s = _session(_level(patienceSec: 500));
      s.startBatch(RecipeId.cupcakeVanilla);
      final b = s.kitchen.prep!;
      s.pickMould(b.correctMould);
      s.finishMix(1);
      expect(b.stage, BatchStage.baking);
      expect(s.kitchen.ovens.single, same(b));
      var readyAt = -1.0;
      var burntAt = -1.0;
      final start = s.elapsed;
      while (burntAt < 0) {
        s.advance(LevelSession.step);
        for (final e in s.drainEvents()) {
          if (e.type == SessionEventType.ovenReady) readyAt = s.elapsed - start;
          if (e.type == SessionEventType.burnt) burntAt = s.elapsed - start;
        }
      }
      expect(readyAt, closeTo(s.tuning.ovenSec, 0.05));
      expect(burntAt, closeTo(s.tuning.ovenSec / b.bakeTarget, 0.05));
      expect(b.burnt, isTrue);
      expect(s.kitchen.finish, same(b), reason: 'khu hoàn thiện trống → mẻ cháy sang Kem');
      expect(s.kitchen.ovens.single, isNull);
      s.finishFrost(1);
      for (var i = 0; i < 3; i++) {
        s.addTopping(b.correctTopping);
      }
      s.pickBox(b.correctBox);
      expect(b.result!.complaint, FeedbackKey.bakeBurnt);
      expect(b.stars, lessThan(5));
    });

    test('tủ đầy chặn trạm Hộp; lò giữ mẻ khi khu hoàn thiện bận; bán bớt thì mẻ vào tủ', () {
      final s = _session(_level(
        caseSlots: 1,
        startStock: 3,
        patienceSec: 500,
        every: 1,
        endEvery: 1,
        rushEvery: 1,
        overrides: const {'slotCapacity': 3, 'maxQueue': 3},
      ));
      _perfectBatch(s, RecipeId.cupcakeVanilla);
      final first = s.kitchen.finish!;
      expect(first.stage, BatchStage.waitingCase);
      expect(s.drainEvents().any((e) => e.type == SessionEventType.caseFull), isTrue);

      // Mẻ thứ 2: lấy ra khi khu hoàn thiện bận → nằm trong lò (lò bận).
      s.startBatch(RecipeId.cupcakeVanilla);
      final second = s.kitchen.prep!;
      s.pickMould(second.correctMould);
      s.finishMix(1);
      _until(s, () => second.ovenProgress >= second.bakeTarget);
      expect(s.takeOut(0), isTrue);
      expect(second.stage, BatchStage.ovenDone);
      expect(s.kitchen.ovens[0], same(second));
      _run(s, 1);
      expect(second.ovenProgress, closeTo(second.bakeTarget, 0.02), reason: 'đã lấy ra thì không nướng tiếp');

      // Bán hết 3 cái → mẻ đầu vào tủ, mẻ hai sang khu hoàn thiện.
      var sold = 0;
      while (sold < 3) {
        _until(s, () => _atCounter(s) != null);
        expect(s.sell(_atCounter(s)!.id), SellResult.sold);
        sold++;
      }
      final events = _run(s, 0.1);
      expect(events.any((e) => e.type == SessionEventType.batchReady), isTrue);
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), 3);
      expect(s.kitchen.finish, same(second));
      expect(second.stage, BatchStage.frost);
      expect(s.kitchen.ovens[0], isNull);
    });
  });

  group('khách đặc biệt', () {
    const visit =
        SpecialVisit(atSec: 3, who: SpecialWho.kenji, recipe: RecipeId.cheesecake, scene: StorySceneId.kenji3);

    test('tới đúng giờ, beginSpecial tự dừng, finishSpecial cộng xu ×2 và bỏ dừng', () {
      final s = _session(_level(id: 10, goal: GoalType.specialOrders, stars: const [1, 2, 3], specials: const [visit]));
      final events = _until(s, () => s.specialCustomer?.phase == CustomerPhase.atCounter, maxSec: 10);
      final arrived = events.firstWhere((e) => e.type == SessionEventType.specialArrived);
      final c = s.specialCustomer!;
      expect(arrived.customerId, c.id);
      expect(c.isSpecial, isTrue);
      expect(c.look.friend, FriendId.kenji);
      expect(c.canBuy, isFalse);
      expect(s.sell(c.id), SellResult.invalid);

      final order = s.beginSpecial(c.id)!;
      expect(order.recipe, RecipeId.cheesecake);
      expect(order.toppings, const [ToppingRequest(ToppingId.blueberry, 3)], reason: 'topping cố định của cảnh kenji3');
      expect(s.paused, isTrue);
      expect(s.beginSpecial(c.id), isNull);
      final t = s.elapsed;
      final p = c.patience;
      s.advance(5);
      expect(s.elapsed, t);
      expect(c.patience, p);

      final result = Scoring.evaluate(
        order: order,
        customer: c.look,
        outcome: BakeOutcome(
          wrongMouldDrops: 0,
          mixTurns: order.recipeData.mixTurns.toDouble(),
          bakeRelease: order.recipeData.bakeTarget,
          frostCoverage: 1,
          toppingsPlaced: {for (final r in order.toppings) r.topping: r.count},
          boxChosen: order.box,
        ),
        modifiers: s.modifiers,
        decorTipBonusPct: 0,
      );
      s.finishSpecial(c.id, result);
      expect(s.paused, isFalse);
      expect(s.coins, ((result.payment + result.tip) * 2.0).round());
      expect(s.specialsDone, 1);
      expect(result.stars, greaterThanOrEqualTo(LevelSession.specialGoodStars));
      expect(s.specialsGood, 1);
      expect(s.goalValue, 1);
      expect(s.starsNow, 1);
      expect(c.phase, CustomerPhase.leavingHappy);
      expect(s.drainEvents().any((e) => e.type == SessionEventType.specialDone), isTrue);
      expect(s.finish().recipeStars[RecipeId.cheesecake], result.stars);
    });

    test('đơn đặc biệt dưới 3★ vẫn xong nhưng không tính vào mục tiêu', () {
      final s = _session(_level(goal: GoalType.specialOrders, stars: const [1, 2, 3], specials: const [visit]));
      _until(s, () => s.specialCustomer?.phase == CustomerPhase.atCounter, maxSec: 10);
      final c = s.specialCustomer!;
      final order = s.beginSpecial(c.id)!;
      final bad = Scoring.evaluate(
        order: order,
        customer: c.look,
        outcome: const BakeOutcome(
          wrongMouldDrops: 2,
          mixTurns: 0,
          bakeRelease: 1,
          frostCoverage: 0.2,
          toppingsPlaced: {},
          boxChosen: BoxType.small,
        ),
        modifiers: s.modifiers,
        decorTipBonusPct: 0,
      );
      expect(bad.stars, lessThan(LevelSession.specialGoodStars));
      s.finishSpecial(c.id, bad);
      expect(s.specialsDone, 1);
      expect(s.specialsGood, 0);
      expect(s.goalValue, 0);
      final r = s.finish();
      expect(r.specialsDone, 1);
      expect(r.specialsGood, 0);
      expect(r.won, isFalse);
    });

    test('afterServed: khách đặc biệt chỉ tới khi đã phục vụ đủ khách', () {
      const gated = SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cupcakeVanilla, afterServed: 2);
      final s = _session(
        _level(startStock: 6, every: 2, endEvery: 2, rushEvery: 2, patienceSec: 500, specials: const [gated]),
      );
      _run(s, 10);
      expect(s.specialCustomer, isNull);
      for (var k = 0; k < 2; k++) {
        _until(s, () => _atCounter(s) != null);
        expect(s.sell(_atCounter(s)!.id), SellResult.sold);
      }
      final events = _run(s, 0.1);
      expect(events.any((e) => e.type == SessionEventType.specialArrived), isTrue);
      expect(s.specialCustomer!.look.isVip, isTrue);
      expect(s.specialCustomer!.order!.box, BoxType.gift);
    });

    test('ảnh VIP: không ghi look → không bao giờ vip_00; look "vip_02" → vip_02', () {
      int vipSprite(SpecialVisit v, int seed) {
        final s = LevelSession(
          level: _level(specials: [v]),
          defaults: _defaults,
          modifiers: BakeModifiers.base,
          random: math.Random(seed),
        );
        _until(s, () => s.specialCustomer != null, maxSec: 5);
        return s.specialCustomer!.look.appearanceSeed % SpecialVisit.vipLooks;
      }

      const plain = SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cupcakeVanilla);
      final seen = {for (var seed = 1; seed <= 40; seed++) vipSprite(plain, seed)};
      expect(seen, {1, 2});
      const lady = SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cupcakeVanilla, look: 'vip_02');
      expect(vipSprite(lady, 3), 2);
      const rosa = SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cupcakeVanilla, look: 'vip_00');
      expect(vipSprite(rosa, 3), SpecialVisit.reservedVipLook);
    });

    test('bySec: quá hạn mà chưa đủ khách → bỏ lượt, lượt sau vẫn tới', () {
      const late = SpecialVisit(
        atSec: 1,
        who: SpecialWho.hoa,
        recipe: RecipeId.cupcakeVanilla,
        afterServed: 5,
        bySec: 6,
      );
      const next = SpecialVisit(atSec: 2, who: SpecialWho.linh, recipe: RecipeId.cupcakeVanilla);
      final s = _session(_level(specials: const [late, next]));
      expect(s.nextSpecialVisit, same(late));
      final events = _until(s, () => s.specialCustomer != null, maxSec: 10);
      expect(s.elapsed, greaterThan(6));
      expect(s.specialsSkipped, 1);
      expect(s.specialCustomer!.look.friend, FriendId.linh);
      expect(s.nextSpecialVisit, isNull);
      expect(events.where((e) => e.type == SessionEventType.specialArrived), hasLength(1));
    });

    test('cancelSpecial: bỏ dừng, khách vẫn chờ; hết kiên nhẫn thì rời đi', () {
      final s = _session(_level(specials: const [visit], overrides: const {'specialPatienceSec': 10}));
      _until(s, () => s.specialCustomer != null, maxSec: 10);
      final c = s.specialCustomer!;
      expect(s.beginSpecial(c.id), isNotNull);
      s.cancelSpecial(c.id);
      expect(s.paused, isFalse);
      expect(s.specialCustomer, same(c));
      final events = _until(s, () => s.specialCustomer == null, maxSec: 15);
      expect(events.any((e) => e.type == SessionEventType.specialLeft), isTrue);
      expect(s.finish().specialsMissed, 1);
    });
  });

  group('hết giờ + kết quả', () {
    test('addTime chỉ một lần; hết giờ → finish', () {
      final s = _session(_level(durationSec: 20, stars: const [5, 6, 7]));
      final events = _run(s, 25);
      expect(s.isOver, isTrue);
      expect(s.timeLeft, 0);
      expect(events.where((e) => e.type == SessionEventType.timeUp), hasLength(1));
      expect(s.canAddTime, isTrue);
      s.addTime(30);
      expect(s.isOver, isFalse);
      expect(s.timeLeft, closeTo(30, 1e-6));
      expect(s.canAddTime, isFalse);
      s.addTime(30);
      expect(s.timeLeft, closeTo(30, 1e-6));
      _run(s, 31);
      expect(s.isOver, isTrue);
      final r = s.finish();
      expect(identical(r, s.finish()), isTrue);
      expect(r.won, isFalse);
      expect(r.stars, 0);
      expect(r.timeAdded, isTrue);
      expect(r.levelId, 1);
    });

    test('hudRevision tăng theo giây và khi bán', () {
      final s = _session(_level(startStock: 3));
      var n = 0;
      s.hudRevision.addListener(() => n++);
      _run(s, 3);
      expect(n, inInclusiveRange(3, 5));
      s.dispose();
    });
  });

  group('GameState.applyLevelResult', () {
    test('cộng xu, khách, thành thạo, nhiệm vụ; notify một lần', () {
      final state = GameState.newGame(clock: () => DateTime(2026, 10, 29));
      var notified = 0;
      state.addListener(() => notified++);
      final coins = state.coins;
      final gems = state.gems;
      const r = LevelResult(
        levelId: 3,
        won: false,
        stars: 0,
        coins: 120,
        served: 5,
        lost: 2,
        specialsDone: 1,
        bestCombo: 3,
        perfectBakes: 2,
        recipeStars: {RecipeId.cupcakeVanilla: 5, RecipeId.muffinBlueberry: 4, RecipeId.cupcakeChocolate: 2},
        tips: 15,
        treatStars: 20,
        fiveStarTreats: 1,
      );
      state.applyLevelResult(r);
      expect(notified, 1);
      expect(state.coins, coins + 120, reason: 'thua vẫn nhận xu đã kiếm');
      expect(state.gems, gems + Economy.masteryGemReward);
      expect(state.totalServed, 5);
      expect(state.recipeMastery(RecipeId.cupcakeVanilla), 3);
      expect(state.recipeMastery(RecipeId.muffinBlueberry), 2);
      expect(state.recipeMastery(RecipeId.cupcakeChocolate), 1);
      expect(state.recipeMastery(RecipeId.eggTart), 0);
      expect(state.xp, 0);
      int expected(QuestType t) => math.min(Catalog.quest(t).target, switch (t) {
            QuestType.serveCustomers => 5,
            QuestType.earnStars => 20,
            QuestType.perfectBakes => 2,
            QuestType.fiveStarTreats => 1,
            QuestType.earnCoins => 120,
            QuestType.earnTips => 15,
          });
      for (final QuestProgress q in state.quests) {
        expect(q.progress, expected(q.type), reason: q.type.name);
      }
    });
  });

  test('hiệu năng: 25 khách trong cảnh, 180 s mô phỏng', () {
    final level = _level(
      durationSec: 200,
      every: 0.3,
      endEvery: 0.3,
      rushEvery: 0.3,
      patienceSec: 10000,
      startStock: 6,
      overrides: const {'maxQueue': 25},
    );
    final s = _session(level);
    final sw = Stopwatch();
    var frames = 0;
    var maxUs = 0;
    var maxCustomers = 0;
    const dt = 1 / 60;
    // Khởi động (JIT) ngoài phần đo.
    _run(s, 2);
    for (var i = 0; i < 180 * 60; i++) {
      if (i % 120 == 0) {
        final c = _atCounter(s);
        if (c != null && s.displayCase.countOf(RecipeId.cupcakeVanilla) > 0) s.sell(c.id);
      }
      final before = sw.elapsedMicroseconds;
      sw.start();
      s.advance(dt);
      sw.stop();
      final us = sw.elapsedMicroseconds - before;
      if (us > maxUs) maxUs = us;
      frames++;
      s.drainEvents();
      maxCustomers = math.max(maxCustomers, s.customers.length);
    }
    final avgMs = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('LevelSession.advance: $frames khung, trung bình ${avgMs.toStringAsFixed(4)} ms, '
        'tối đa ${(maxUs / 1000).toStringAsFixed(3)} ms, khách trong cảnh tối đa $maxCustomers');
    expect(maxCustomers, greaterThanOrEqualTo(25));
    expect(avgMs, lessThan(2.0), reason: 'mục tiêu < 0.5 ms trên máy dev; assert lỏng cho máy CI');
  });
}
