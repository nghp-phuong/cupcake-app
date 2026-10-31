import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';

import 'qa_helpers.dart';

/// QA việc 1 + 2: mốc sao / xu / kết quả màn, nhịp khách theo levels.json, bán từ tủ, hàng chờ, kiên nhẫn, đơn đặc
/// biệt sai từng trạm.

/// Một khách duy nhất (tới lúc 1.5 s), tủ có [stock] bánh vani 3★; bán khi khách tới quầy; chạy tới hết giờ.
LevelResult _oneSale(List<int> stars, GoalType goal, {int stock = 1, bool sell = true}) {
  final s = qaSession(qaLevel(
    durationSec: 30,
    goal: goal,
    stars: stars,
    startStock: stock,
    every: 1000,
    endEvery: 1000,
    rushEvery: 1000,
    patienceSec: 100,
  ));
  qaUntil(s, () => qaAtCounter(s) != null);
  if (sell) expect(s.sell(qaAtCounter(s)!.id), SellResult.sold);
  qaRunToEnd(s);
  final r = s.finish();
  s.dispose();
  return r;
}

/// Kết quả hoàn hảo cho [order].
BakeOutcome _perfect(Order order) {
  final placed = <ToppingId, int>{};
  for (final t in order.toppings) {
    placed[t.topping] = (placed[t.topping] ?? 0) + t.count;
  }
  return BakeOutcome(
    wrongMouldDrops: 0,
    mixTurns: order.recipeData.mixTurns.toDouble(),
    bakeRelease: order.recipeData.bakeTarget,
    frostCoverage: 1.0,
    toppingsPlaced: placed,
    boxChosen: order.box,
  );
}

BakeOutcome _with(
  BakeOutcome o, {
  int? wrongMouldDrops,
  double? mixTurns,
  double? bakeRelease,
  double? frostCoverage,
  Map<ToppingId, int>? toppingsPlaced,
  BoxType? boxChosen,
}) =>
    BakeOutcome(
      wrongMouldDrops: wrongMouldDrops ?? o.wrongMouldDrops,
      mixTurns: mixTurns ?? o.mixTurns,
      bakeRelease: bakeRelease ?? o.bakeRelease,
      frostCoverage: frostCoverage ?? o.frostCoverage,
      toppingsPlaced: toppingsPlaced ?? o.toppingsPlaced,
      boxChosen: boxChosen ?? o.boxChosen,
    );

void main() {
  group('mốc sao theo levels.json', () {
    test('mọi level: đúng bằng mốc → đủ sao, thiếu 1 đơn vị → thiếu sao; thắng ⇔ đạt mốc 1★', () {
      expect(qaLevels.levels, hasLength(50));
      for (final l in qaLevels.levels) {
        final st = l.goal.stars;
        expect(st, hasLength(3), reason: 'L${l.id}');
        expect(l.goal.target, st.first, reason: 'L${l.id}');
        expect(l.goal.starsFor(0), 0, reason: 'L${l.id}');
        for (var i = 0; i < 3; i++) {
          expect(l.goal.starsFor(st[i]), i + 1, reason: 'L${l.id}: đúng bằng mốc ${i + 1}');
          expect(l.goal.starsFor(st[i] - 1), i, reason: 'L${l.id}: thiếu 1 so với mốc ${i + 1}');
        }
        expect(l.goal.starsFor(st.last * 100), 3, reason: 'L${l.id}: vượt xa vẫn 3★');
      }
    });

    test('mục tiêu xu trên session thật: xu đúng bằng mốc → thắng 1★; thiếu 1 xu → thua 0★', () {
      final probe = _oneSale(const [1000, 1001, 1002], GoalType.coins);
      final x = probe.coins;
      expect(x, greaterThan(0));
      expect(probe.won, isFalse);

      final exact = _oneSale([x, x + 1, x + 2], GoalType.coins);
      expect(exact.coins, x, reason: 'cùng seed → cùng diễn biến');
      expect((exact.won, exact.stars, exact.goalValue), (true, 1, x));

      final short = _oneSale([x + 1, x + 2, x + 3], GoalType.coins);
      expect((short.won, short.stars), (false, 0));

      final three = _oneSale([x - 2, x - 1, x], GoalType.coins);
      expect((three.won, three.stars), (true, 3));
    });

    test('mục tiêu khách: phục vụ 1 khách, mốc [1,2,3] thắng 1★; mốc [2,3,4] thua; không bán → 0★', () {
      expect(_oneSale(const [1, 2, 3], GoalType.customers).stars, 1);
      final lose = _oneSale(const [2, 3, 4], GoalType.customers);
      expect((lose.won, lose.stars, lose.served), (false, 0, 1));
      final none = _oneSale(const [1, 2, 3], GoalType.customers, sell: false);
      expect((none.won, none.stars, none.served, none.coins), (false, 0, 0, 0));
    });
  });

  group('hết giờ', () {
    test('timeUp đúng một lần ở đúng durationSec; sau đó mọi thao tác vô hiệu, finish ổn định', () {
      final s = qaSession(qaLevel(durationSec: 20, startStock: 3, every: 2, endEvery: 2, rushEvery: 2));
      final events = qaRunToEnd(s);
      expect(events.where((e) => e.type == SessionEventType.timeUp), hasLength(1));
      expect(s.elapsed, 20);
      expect(s.timeLeft, 0);
      final c = qaAtCounter(s);
      if (c != null) expect(s.sell(c.id), SellResult.invalid);
      expect(s.startBatch(RecipeId.cupcakeVanilla), isFalse);
      expect(s.takeOut(0), isFalse);
      s.advance(5);
      expect(s.elapsed, 20);
      expect(s.drainEvents(), isEmpty);
      final r1 = s.finish();
      expect(identical(s.finish(), r1), isTrue);
      s.dispose();
    });

    test('+30 giây sau hết giờ: chơi tiếp, hết giờ lần 2 ở 50 s; dùng lần hai bị bỏ qua; kết quả ghi timeAdded', () {
      final s = qaSession(qaLevel(durationSec: 20, startStock: 6, every: 3, endEvery: 3, rushEvery: 3, patienceSec: 500));
      qaRunToEnd(s);
      final before = s.finish();
      expect(before.timeAdded, isFalse);
      expect(s.canAddTime, isTrue);
      s.addTime(30);
      expect(s.isOver, isFalse);
      expect(s.duration, 50);
      s.addTime(30);
      expect(s.duration, 50, reason: 'chỉ một lần mỗi lượt');
      expect(s.canAddTime, isFalse);
      var sold = 0;
      while (!s.isOver) {
        final c = qaAtCounter(s);
        if (c != null && s.sell(c.id) == SellResult.sold) sold++;
        s.advance(LevelSession.step);
        s.drainEvents();
      }
      expect(s.elapsed, 50);
      expect(sold, greaterThan(0), reason: 'khách vẫn tới trong 30 giây thêm');
      final after = s.finish();
      expect(after.timeAdded, isTrue);
      expect(after.served, before.served + sold);
      s.dispose();
    });
  });

  group('combo + khách bỏ đi', () {
    test('combo tăng tới trần x2.0 (combo 11+); xu của lượt bán đúng = round(giá cơ bản × hệ số)', () {
      final s = qaSession(qaLevel(
        durationSec: 200,
        startStock: 18,
        every: 0.5,
        endEvery: 0.5,
        rushEvery: 0.5,
        patienceSec: 500,
        overrides: const {'comboWindowSec': 100, 'maxQueue': 100},
      ));
      final price = Catalog.recipe(RecipeId.cupcakeVanilla).price;
      final base = price * Economy.payMult[3]! + price * Economy.tipRate[3]!;
      final coinsByCombo = <int, int>{};
      for (var k = 0; k < 14; k++) {
        qaUntil(s, () => qaAtCounter(s) != null);
        final c = qaAtCounter(s)!;
        expect(c.patienceFrac, greaterThanOrEqualTo(0.5));
        expect(s.sell(c.id), SellResult.sold);
        final e = s.drainEvents().lastWhere((e) => e.type == SessionEventType.sold);
        coinsByCombo[e.combo] = e.coins;
      }
      expect(s.combo, 14);
      expect(s.comboMult, 2.0);
      for (final MapEntry(key: combo, value: coins) in coinsByCombo.entries) {
        final mult = combo <= 1 ? 1.0 : 1 + 0.1 * (combo - 1).clamp(0, LevelSession.comboCap);
        expect(coins, (base * mult).round(), reason: 'combo $combo');
      }
      expect(coinsByCombo[14], coinsByCombo[11], reason: 'quá trần không tăng nữa');
      s.dispose();
    });

    test('tủ trống: bán → notInCase, khách đứng chờ ở quầy tới hết kiên nhẫn rồi bỏ đi (lost++)', () {
      final s = qaSession(qaLevel(durationSec: 100, every: 1000, endEvery: 1000, rushEvery: 1000, patienceSec: 20));
      qaUntil(s, () => qaAtCounter(s) != null);
      final c = qaAtCounter(s)!;
      final id = c.id;
      expect(s.sell(id), SellResult.notInCase);
      expect(c.phase, CustomerPhase.atCounter);
      final events = qaUntil(s, () => s.lost > 0, maxSec: 30);
      expect(events.where((e) => e.type == SessionEventType.walkedOut && e.customerId == id), hasLength(1));
      // Vào cửa 1.2 s ở nửa tốc độ (−0.6), còn lại ở quầy tốc độ 1 → bỏ đi lúc ≈ 1.5 + 1.2 + 19.4 = 22.1 s.
      expect(s.elapsed, closeTo(22.1, 0.15));
      expect(s.sell(id), SellResult.invalid);
      s.dispose();
    });

    test('mọi khách mất (bỏ đi + quay đi ở cửa) đều đếm vào lost và kết quả', () {
      final s = qaSession(qaLevel(
        durationSec: 90,
        every: 1.5,
        endEvery: 1.5,
        rushEvery: 1.5,
        patienceSec: 10,
        overrides: const {'maxQueue': 4},
      ));
      final events = qaRunToEnd(s);
      final walked = events.where((e) => e.type == SessionEventType.walkedOut).length;
      final turned = events.where((e) => e.type == SessionEventType.turnedAway).length;
      expect(turned, greaterThan(0), reason: 'hàng đầy');
      expect(walked, greaterThan(0));
      final r = s.finish();
      expect(r.lost, walked + turned);
      expect((r.served, r.coins, r.won), (0, 0, false));
      s.dispose();
    });
  });

  group('bán từ tủ: trừ đúng bánh, cộng đúng xu theo kiên nhẫn', () {
    test('tip đủ khi kiên nhẫn ≥ 50%, nửa khi ≥ 25%, không tip khi < 25%', () {
      final price = Catalog.recipe(RecipeId.cupcakeVanilla).price;
      int expected(double share) =>
          (price * Economy.payMult[3]! + price * Economy.tipRate[3]! * share).round();

      for (final (frac, share) in [(1.0, 1.0), (0.49, 0.5), (0.24, 0.0)]) {
        final s = qaSession(qaLevel(
          durationSec: 100,
          startStock: 1,
          every: 1000,
          endEvery: 1000,
          rushEvery: 1000,
          patienceSec: 40,
        ));
        qaUntil(s, () => qaAtCounter(s) != null);
        final c = qaAtCounter(s)!;
        qaUntil(s, () => c.patienceFrac <= frac);
        final stock = s.displayCase.countOf(RecipeId.cupcakeVanilla);
        expect(s.sell(c.id), SellResult.sold);
        expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), stock - 1);
        expect(s.coins, expected(share), reason: 'kiên nhẫn ≤ $frac');
        expect(s.served, 1);
        s.dispose();
      }
    });
  });

  group('nhịp khách theo levels.json', () {
    test('dữ liệu: mọi level thưa → dày → cao điểm (start ≥ end ≥ rush), rushAtPct trong 0..100', () {
      for (final l in qaLevels.levels) {
        final sp = l.spawn;
        expect(sp.startEverySec, greaterThanOrEqualTo(sp.endEverySec), reason: 'L${l.id}');
        expect(sp.endEverySec, greaterThanOrEqualTo(sp.rushEverySec), reason: 'L${l.id}');
        expect(sp.rushAtPct, inInclusiveRange(0, 100), reason: 'L${l.id}');
      }
    });

    test('L1–L10 trên session (jitter 0): khoảng cách khách = intervalAt(tiến độ), cao điểm đúng mốc, ngừng sinh 6 s cuối',
        () {
      final defaults = qaLevels.defaults.overriddenBy(const {'jitterPct': 0, 'maxQueue': 1000});
      for (var id = 1; id <= 10; id++) {
        final l = qaLevels.level(id);
        final s = qaSession(l, defaults: defaults);
        final arrivals = <double>[];
        var rushAt = -1.0;
        while (!s.isOver) {
          s.advance(LevelSession.step);
          for (final e in s.drainEvents()) {
            if (e.type == SessionEventType.customerArrived) arrivals.add(s.elapsed);
            if (e.type == SessionEventType.rushStarted) rushAt = s.elapsed;
          }
        }
        expect(arrivals.first, closeTo(LevelSession.firstSpawnSec, LevelSession.step + 1e-6), reason: 'L$id');
        for (var i = 1; i < arrivals.length; i++) {
          final want = l.spawn.intervalAt(arrivals[i - 1] / l.durationSec);
          expect(arrivals[i] - arrivals[i - 1], closeTo(want, LevelSession.step + 1e-6), reason: 'L$id khách #$i');
        }
        expect(rushAt, closeTo(l.durationSec * l.spawn.rushAtPct / 100, LevelSession.step + 1e-6), reason: 'L$id');
        expect(arrivals.last, lessThanOrEqualTo(l.durationSec - LevelSession.stopSpawnBeforeEndSec + 1e-6));
        final third = l.durationSec / 3;
        int count(double a, double b) => arrivals.where((t) => t >= a && t < b).length;
        expect(count(0, third), lessThanOrEqualTo(count(2 * third, 3 * third)), reason: 'L$id: dày dần');
        s.dispose();
      }
    });
  });

  group('đơn đặc biệt sai từng trạm', () {
    const visit = SpecialVisit(atSec: 2, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla);

    /// Chạy một đơn đặc biệt với [outcome] (dựng từ đơn); trả (kết quả chấm, xu session nhận, specialsGood).
    (BakeResult, int, int) play(BakeOutcome Function(Order order) outcome) {
      final s = qaSession(qaLevel(
        durationSec: 60,
        goal: GoalType.specialOrders,
        stars: const [1, 1000, 1001],
        every: 1000,
        endEvery: 1000,
        rushEvery: 1000,
        specials: const [visit],
      ));
      qaUntil(s, () => s.specialCustomer?.phase == CustomerPhase.atCounter);
      final c = s.specialCustomer!;
      final order = s.beginSpecial(c.id)!;
      expect(s.paused, isTrue);
      final r = Scoring.evaluate(
        order: order,
        customer: c.look,
        outcome: outcome(order),
        modifiers: s.modifiers,
        decorTipBonusPct: s.decorTipBonusPct,
      );
      s.finishSpecial(c.id, r);
      expect(s.paused, isFalse);
      final e = s.drainEvents().lastWhere((e) => e.type == SessionEventType.specialDone);
      expect(e.stars, r.stars);
      expect(e.coins, s.coins);
      final good = s.specialsGood;
      s.dispose();
      return (r, s.coins, good);
    }

    test('hoàn hảo: 5★, không chê, xu = (trả + tip) × specialRewardMult, tính vào mục tiêu', () {
      final (r, coins, good) = play(_perfect);
      expect(r.stars, 5);
      expect(r.complaint, isNull);
      expect(r.praise, FeedbackKey.allGood);
      expect(coins, ((r.payment + r.tip) * const LevelDefaults().specialRewardMult).round());
      expect(good, 1);
    });

    final cases = <String, (BakeOutcome Function(Order), FeedbackKey, StationId, int)>{
      'chưa chín (lấy sớm 0.3)': (
        (o) => _with(_perfect(o), bakeRelease: o.recipeData.bakeTarget - 0.3),
        FeedbackKey.bakeUnder,
        StationId.bake,
        3, // nướng 0.15 → chất lượng 0.745
      ),
      'cháy (để tới 1.0)': ((o) => _with(_perfect(o), bakeRelease: 1.0), FeedbackKey.bakeBurnt, StationId.bake, 3),
      'kem loang (phủ 50%)': ((o) => _with(_perfect(o), frostCoverage: 0.5), FeedbackKey.frostPatchy, StationId.frost, 4),
      'thiếu topping': ((o) => _with(_perfect(o), toppingsPlaced: const {}), FeedbackKey.toppingMissing, StationId.topping, 4),
      'sai topping': (
        (o) {
          final need = o.toppings.fold<int>(0, (a, t) => a + t.count);
          final wrong = ToppingId.values.firstWhere((t) => o.toppings.every((r) => r.topping != t));
          return _with(_perfect(o), toppingsPlaced: {wrong: need});
        },
        FeedbackKey.toppingWrong,
        StationId.topping,
        4, // topping 0 → chất lượng đúng 0.75
      ),
      'sai hộp': (
        (o) => _with(_perfect(o), boxChosen: BoxType.values.firstWhere((b) => b != o.box)),
        FeedbackKey.boxWrong,
        StationId.box,
        5,
      ),
      'trộn thiếu (nửa số vòng)': (
        (o) => _with(_perfect(o), mixTurns: o.recipeData.mixTurns * 0.5),
        FeedbackKey.mixUnder,
        StationId.mix,
        5,
      ),
      'trộn quá (gấp đôi)': (
        (o) => _with(_perfect(o), mixTurns: o.recipeData.mixTurns * 2.0),
        FeedbackKey.mixOver,
        StationId.mix,
        5,
      ),
      'sai khuôn 2 lần': ((o) => _with(_perfect(o), wrongMouldDrops: 2), FeedbackKey.mouldWrong, StationId.mould, 5),
    };

    for (final MapEntry(key: name, value: (outcome, complaint, weakest, stars)) in cases.entries) {
      test('$name → chê đúng trạm ($complaint), $stars★, xu và mục tiêu khớp', () {
        final (r, coins, good) = play(outcome);
        expect(r.complaint, complaint);
        expect(r.weakest, weakest);
        expect(r.stars, stars);
        expect(coins, ((r.payment + r.tip) * const LevelDefaults().specialRewardMult).round());
        expect(good, r.stars >= LevelSession.specialGoodStars ? 1 : 0);
        if (r.stars < 3) expect(r.tip, 0);
      });
    }

    test('đơn đặc biệt 2★ (nhiều lỗi) vẫn xong nhưng không tính mục tiêu, không tip', () {
      final (r, coins, good) = play((o) => _with(_perfect(o), bakeRelease: 1.0, frostCoverage: 0.3, toppingsPlaced: const {}));
      expect(r.stars, lessThan(3));
      expect(r.tip, 0);
      expect(good, 0);
      expect(coins, (r.payment * const LevelDefaults().specialRewardMult).round());
    });

    test('khách đặc biệt hết kiên nhẫn: tính specialsMissed, KHÔNG tính lost', () {
      final s = qaSession(qaLevel(
        durationSec: 200,
        every: 1000,
        endEvery: 1000,
        rushEvery: 1000,
        patienceSec: 1000,
        specials: const [visit],
        overrides: const {'specialPatienceSec': 10},
      ));
      final events = qaRun(s, 20);
      expect(events.where((e) => e.type == SessionEventType.specialLeft), hasLength(1));
      qaRunToEnd(s);
      final r = s.finish();
      expect(r.specialsMissed, 1);
      expect(r.lost, 0, reason: 'thiết kế hiện tại: khách đặc biệt bỏ đi không vào lost');
      s.dispose();
    });
  });
}
