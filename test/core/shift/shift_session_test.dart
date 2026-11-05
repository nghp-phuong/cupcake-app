import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/city/recipe_unlocks.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/core/shift/shift_economy.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';

import 'shift_test_helpers.dart';

final _now = DateTime(2026, 11, 4, 10);

CityGame _game({int xp = 0, bool fullBuff = false, int coins = 1500}) =>
    CityGame(
      wallet: CityWallet(xp: xp, fullBuff: fullBuff, coins: coins),
      clock: () => _now,
    )..refreshDay();

ShiftSession _open(CityGame g, [int seed = 1]) =>
    ShiftSession(game: g, random: math.Random(seed));

/// Đưa khách hiện tại tới `result` với [stars] sao.
ShiftServed _serve(ShiftSession s, int stars) {
  s.customerArrived();
  s.startBaking();
  return s.completeBake(outcomeFor(s.current.order, stars))!;
}

int _notifies(Listenable l, void Function() act) {
  var n = 0;
  void count() => n++;
  l.addListener(count);
  act();
  l.removeListener(count);
  return n;
}

void main() {
  test('outcomeFor cho đúng số sao với mọi món', () {
    for (var level = 1; level <= PlayerLevel.maxLevel; level += 3) {
      final s = _open(_game(xp: PlayerLevel.xpToReach(level)), level);
      for (final o in s.orders) {
        for (var stars = 1; stars <= 5; stars++) {
          final r = Scoring.evaluate(
            order: o.order,
            customer: o.customer,
            outcome: outcomeFor(o.order, stars),
            modifiers: BakeModifiers.base,
            decorTipBonusPct: 0,
          );
          expect(r.stars, stars, reason: '${o.order} $stars');
        }
      }
    }
  });

  test(
    '§7-2 plan theo seed: 4/5/6 khách, chỉ món + topping đã mở, không khách quen, không VIP dưới cấp 7',
    () {
      for (final (level, count) in [(1, 4), (3, 4), (4, 5), (9, 5), (10, 6)]) {
        expect(ShiftEconomy.customersFor(level), count);
        for (var seed = 0; seed < 30; seed++) {
          final s = _open(_game(xp: PlayerLevel.xpToReach(level)), seed);
          expect(s.levelAtStart, level);
          expect(s.total, count);
          expect(s.orders.map((o) => o.index), List.generate(count, (i) => i));
          for (final o in s.orders) {
            expect(RecipeUnlocks.recipesAt(level), contains(o.order.recipe));
            for (final t in o.order.toppings) {
              expect(RecipeUnlocks.toppingsAt(level), contains(t.topping));
            }
            expect(o.customer.kind, isNot(CustomerKind.friend));
            if (level < 7) expect(o.customer.kind, CustomerKind.regular);
          }
        }
      }
      // Cùng seed → cùng plan.
      final a = _open(_game(), 7), b = _open(_game(), 7);
      expect(
        [for (final o in a.orders) o.order],
        [for (final o in b.orders) o.order],
      );
      // Từ cấp 7 có VIP.
      var vip = 0;
      for (var seed = 0; seed < 40; seed++) {
        final s = _open(_game(xp: PlayerLevel.xpToReach(7)), seed);
        vip += s.orders.where((o) => o.customer.isVip).length;
      }
      expect(vip, greaterThan(0));
    },
  );

  test('§7-3 gọi hàm sai pha thì không làm gì', () {
    final g = _game();
    final s = _open(g);
    final o = outcomeFor(s.current.order, 4);
    void expectNoop(void Function() act) {
      final phase = s.phase, index = s.index, coins = g.wallet.coins;
      expect(_notifies(s, act), 0);
      expect(s.phase, phase);
      expect(s.index, index);
      expect(g.wallet.coins, coins);
    }

    expect(s.phase, ShiftPhase.arriving);
    expectNoop(s.startBaking);
    expect(s.completeBake(o), isNull);
    expect(s.next(), isNull);
    expectNoop(s.remake);
    expectNoop(s.applyDouble);
    s.customerArrived();
    expect(s.phase, ShiftPhase.ordering);
    expectNoop(s.customerArrived);
    expect(s.completeBake(o), isNull);
    expect(s.next(), isNull);
    s.startBaking();
    expect(s.phase, ShiftPhase.baking);
    expectNoop(s.customerArrived);
    expectNoop(s.startBaking);
    expect(s.next(), isNull);
    expectNoop(s.applyDouble);
    expect(s.completeBake(o), isNotNull);
    expect(s.phase, ShiftPhase.result);
    expect(s.completeBake(o), isNull);
    expectNoop(s.customerArrived);
    expectNoop(s.startBaking);
    expectNoop(s.remake); // 4★: không được làm lại
    expect(s.summary, isNull);
  });

  test('§7-4 chấm điểm: xu ×4, XP giữ nguyên, không buff thì buffTip = 0', () {
    final s = _open(_game());
    expect(s.buffActive, isFalse);
    expect(s.modifiers, BakeModifiers.base);
    final cur = s.current;
    final served = _serve(s, 4);
    final raw = Scoring.evaluate(
      order: cur.order,
      customer: cur.customer,
      outcome: outcomeFor(cur.order, 4),
      modifiers: BakeModifiers.base,
      decorTipBonusPct: 0,
    );
    expect(served.order, same(cur));
    expect(s.served, same(served));
    final r = served.result;
    expect(r.stars, 4);
    expect(r.payment, raw.payment * 4);
    expect(r.tip, raw.tip * 4);
    expect(r.cost, raw.cost * 4);
    expect(r.net, raw.net * 4);
    expect(r.xp, raw.xp);
    expect(r.xp, 15 + 5 * 4);
    expect(r.quality, raw.quality);
    expect(r.praise, raw.praise);
    expect(r.complaint, raw.complaint);
    expect(r.weakest, raw.weakest);
    expect(r.stations.length, 6);
    expect(served.buffTip, 0);
  });

  test(
    '§7-4 buff "No bụng": tip ×1,1 cho mọi đơn, buffTip đúng, VIP XP ×1,5',
    () {
      // Cấp 9: có VIP (tip ×2, XP ×1,5) để kiểm cả hai loại khách.
      final g = _game(xp: PlayerLevel.xpToReach(9), fullBuff: true);
      final s = _open(g, 3);
      expect(s.buffActive, isTrue);
      var buffTips = 0;
      while (s.phase != ShiftPhase.finished) {
        final cur = s.current;
        final stars = 5 - cur.index % 3; // 5, 4, 3
        final served = _serve(s, stars);
        final recipe = cur.order.recipeData;
        final kind = Economy.tipKindMult[cur.customer.kind]!;
        final rate = Economy.tipRate[stars]!;
        final withBuff = (recipe.price * rate * kind * 1.1).round();
        final plain = (recipe.price * rate * kind).round();
        expect(served.result.tip, withBuff * 4, reason: '$cur');
        expect(served.buffTip, (withBuff - plain) * 4);
        expect(
          served.result.xp,
          ((15 + 5 * stars) * (cur.customer.isVip ? 1.5 : 1)).round(),
        );
        buffTips += served.buffTip;
        s.next();
      }
      expect(s.summary!.buffTips, buffTips);
      expect(buffTips, greaterThan(0));
      // Dưới 3★ không tip → buffTip = 0.
      final s2 = _open(_game(fullBuff: true));
      final low = _serve(s2, 2);
      expect(low.result.tip, 0);
      expect(low.buffTip, 0);
    },
  );

  test(
    '§7-5 next(): cộng ví + thống kê, trả cấp mới, tắt fullBuff ở lần tính đơn đầu',
    () {
      final g = _game(xp: PlayerLevel.xpToReach(2) - 1, fullBuff: true);
      final s = _open(g);
      expect(g.wallet.level, 1);
      final first = _serve(s, 5);
      expect(g.wallet.fullBuff, isTrue); // chưa tính đơn
      expect(g.wallet.coins, 1500);
      final level = s.next();
      expect(level, 2);
      expect(g.wallet.fullBuff, isFalse);
      expect(g.wallet.coins, 1500 + first.result.net);
      expect(g.wallet.xp, PlayerLevel.xpToReach(2) - 1 + first.result.xp);
      expect(g.bakery.orders, 1);
      expect(g.bakery.stars, 5);
      expect(g.bakery.five, 1);
      expect(g.bakery.coins, first.result.net);
      expect(s.records, [first]);
      expect(s.served, isNull);
      expect(s.index, 1);
      expect(s.phase, ShiftPhase.arriving);
      // Đơn sau vẫn có buff (buff tính cho cả ca), không lên cấp → null.
      final second = _serve(s, 4);
      expect(s.buffActive, isTrue);
      expect(second.buffTip, greaterThanOrEqualTo(0));
      expect(s.next(), isNull);
      expect(g.bakery.orders, 2);
      expect(g.bakery.stars, 9);
      expect(g.bakery.five, 1);
    },
  );

  test('§7-6 remake: chỉ khi ≤2★, mỗi đơn một lần, không tính đơn hai lần', () {
    final g = _game();
    final s = _open(g);
    _serve(s, 2);
    expect(s.canRemake, isTrue);
    s.remake();
    expect(s.phase, ShiftPhase.baking);
    expect(s.served, isNull);
    expect(g.bakery.orders, 0);
    expect(g.wallet.coins, 1500);
    s.completeBake(outcomeFor(s.current.order, 1));
    expect(s.canRemake, isFalse); // đã làm lại một lần
    final phase = s.phase;
    s.remake();
    expect(s.phase, phase);
    s.next();
    expect(g.bakery.orders, 1);
    expect(s.records.length, 1);

    // 3★ không được làm lại.
    _serve(s, 3);
    expect(s.canRemake, isFalse);
    s.next();

    // Hết lượt quảng cáo → không hiện nút; quảng cáo cuối vừa xem xong vẫn làm lại được.
    _serve(s, 1);
    for (var i = 0; i < CityGame.maxRewardedPerDay - 1; i++) {
      g.registerRewardedShown();
    }
    expect(s.canRemake, isTrue);
    g.registerRewardedShown();
    expect(s.canRemake, isFalse);
    s.remake();
    expect(s.phase, ShiftPhase.baking);
  });

  test(
    '§7-7 hết ca: +30 XP, tổng tiền khớp, sao trung bình, món mới, shifts++, best',
    () {
      // Cấp 4, sát cấp 5 → lên cấp trong ca, mở macaron + sugarPearl.
      final g = _game(xp: PlayerLevel.xpToReach(5) - 40);
      final s = _open(g, 5);
      expect(s.levelAtStart, 4);
      final coins0 = g.wallet.coins, xp0 = g.wallet.xp;
      final stars = [5, 4, 3, 2, 4];
      int? lastLevel;
      final levels = <int>[];
      for (final st in stars) {
        _serve(s, st);
        lastLevel = s.next();
        if (lastLevel != null) levels.add(lastLevel);
      }
      expect(levels, [5]);
      expect(s.phase, ShiftPhase.finished);
      expect(s.index, s.total);
      expect(s.current, same(s.orders.last));
      final sum = s.summary!;
      expect(sum.completed, isTrue);
      expect(sum.served, 5);
      expect(sum.total, 5);
      expect(sum.bonusXp, 30);
      final recs = s.records;
      expect(sum.records, recs);
      expect(sum.revenue, recs.fold<int>(0, (a, r) => a + r.result.payment));
      expect(sum.tips, recs.fold<int>(0, (a, r) => a + r.result.tip));
      expect(sum.costs, recs.fold<int>(0, (a, r) => a + r.result.cost));
      expect(sum.net, sum.revenue + sum.tips - sum.costs);
      expect(sum.totalCoins, sum.net);
      expect(sum.xp, recs.fold<int>(0, (a, r) => a + r.result.xp) + 30);
      expect(g.wallet.coins, coins0 + sum.net);
      expect(g.wallet.xp, xp0 + sum.xp);
      expect(sum.averageStars, closeTo(18 / 5, 1e-9));
      expect(sum.levelBefore, 4);
      expect(sum.levelAfter, 5);
      expect(sum.leveledUp, isTrue);
      expect(sum.newRecipes, [RecipeId.macaron]);
      expect(sum.newToppings, [ToppingId.sugarPearl]);
      expect(sum.moreCustomers, isFalse);
      expect(sum.vipGuests, isFalse);
      expect(g.bakery.shifts, 1);
      expect(g.bakery.best, sum.net);
      expect(g.bakery.coins, sum.net);
      expect(g.recipeSeen, 5); // tổng kết đã báo tới cấp 5
      // Không còn gì để làm ngoài x2.
      expect(s.next(), isNull);
      s.abort();
      expect(s.phase, ShiftPhase.finished);
      expect(g.bakery.shifts, 1);

      // Ca sau kém hơn: best giữ kỷ lục.
      final s2 = _open(g, 6);
      while (s2.phase != ShiftPhase.finished) {
        _serve(s2, 1);
        s2.next();
      }
      expect(g.bakery.shifts, 2);
      expect(g.bakery.best, sum.net);
    },
  );

  test('§4 tổng kết: thêm khách (cấp 4, 10) và khách VIP (cấp 7)', () {
    for (final (from, more, vip) in [
      (3, true, false),
      (6, false, true),
      (9, true, false),
    ]) {
      final g = _game(xp: PlayerLevel.xpToReach(from + 1) - 1);
      final s = _open(g);
      expect(s.levelAtStart, from);
      while (s.phase != ShiftPhase.finished) {
        _serve(s, 5);
        s.next();
      }
      final sum = s.summary!;
      expect(sum.levelAfter, greaterThan(from), reason: '$from');
      expect(sum.moreCustomers, more, reason: '$from');
      expect(sum.vipGuests, vip, reason: '$from');
    }
  });

  test('§7-8 applyDouble một lần; không áp khi aborted hoặc net == 0', () {
    final g = _game();
    final s = _open(g);
    while (s.phase != ShiftPhase.finished) {
      _serve(s, 4);
      s.next();
    }
    final net = s.summary!.net;
    expect(net, greaterThan(0));
    expect(s.canDouble, isTrue);
    final coins = g.wallet.coins;
    s.applyDouble();
    expect(g.wallet.coins, coins + net);
    expect(s.summary!.doubledCoins, net);
    expect(s.summary!.totalCoins, net * 2);
    expect(g.bakery.coins, net * 2);
    expect(g.bakery.best, net); // kỷ lục không tính x2
    expect(s.canDouble, isFalse);
    expect(_notifies(s, s.applyDouble), 0);
    expect(g.wallet.coins, coins + net);

    // Đóng sớm (có đơn): không x2.
    final a = _open(g, 2);
    _serve(a, 4);
    a.next();
    a.abort();
    expect(a.summary!.net, greaterThan(0));
    expect(a.canDouble, isFalse);
    final c2 = g.wallet.coins;
    a.applyDouble();
    expect(g.wallet.coins, c2);

    // Đóng sớm khi chưa có đơn: net == 0.
    final b = _open(g, 3)..abort();
    expect(b.summary!.net, 0);
    expect(b.canDouble, isFalse);

    // Hết lượt quảng cáo: không hiện nút, nhưng quảng cáo cuối vừa xem xong vẫn x2 được.
    final d = _open(g, 4);
    while (d.phase != ShiftPhase.finished) {
      _serve(d, 4);
      d.next();
    }
    for (var i = 0; i < CityGame.maxRewardedPerDay; i++) {
      g.registerRewardedShown();
    }
    expect(d.canDouble, isFalse);
    d.applyDouble();
    expect(d.summary!.doubledCoins, d.summary!.net);
  });

  test(
    '§7-9 abort: đơn ở result vẫn tính; không thưởng; buff còn nếu huỷ trước đơn đầu',
    () {
      // Huỷ lúc đang làm bánh đơn đầu: không tính gì, buff còn.
      final g = _game(fullBuff: true);
      final s = _open(g);
      s.customerArrived();
      s.startBaking();
      s.abort();
      expect(s.phase, ShiftPhase.aborted);
      expect(g.wallet.fullBuff, isTrue);
      expect(g.wallet.coins, 1500);
      expect(g.wallet.xp, 0);
      final sum = s.summary!;
      expect(sum.completed, isFalse);
      expect(sum.served, 0);
      expect(sum.bonusXp, 0);
      expect(sum.xp, 0);
      expect(sum.averageStars, 0);
      expect(g.bakery.shifts, 1);
      expect(g.bakery.best, 0);
      expect(g.bakery.orders, 0);
      // Gọi lại không làm gì.
      expect(_notifies(s, s.abort), 0);
      expect(g.bakery.shifts, 1);

      // Huỷ khi đơn thứ hai đang ở result: tính 2 đơn, không thưởng hết ca, buff đã dùng.
      final s2 = _open(g, 9);
      expect(s2.buffActive, isTrue);
      _serve(s2, 4);
      s2.next();
      final second = _serve(s2, 3);
      final coins = g.wallet.coins, xp = g.wallet.xp;
      s2.abort();
      expect(s2.phase, ShiftPhase.aborted);
      expect(g.wallet.coins, coins + second.result.net);
      expect(g.wallet.xp, xp + second.result.xp);
      expect(g.wallet.fullBuff, isFalse);
      expect(s2.summary!.served, 2);
      expect(s2.summary!.bonusXp, 0);
      expect(
        s2.summary!.totalCoins,
        s2.records.fold<int>(0, (a, r) => a + r.result.net),
      );
      expect(g.bakery.orders, 2);
      expect(g.bakery.shifts, 2);
      expect(g.bakery.best, 0); // đóng sớm không lập kỷ lục
      // Sau khi huỷ, các hàm khác không làm gì.
      expect(s2.next(), isNull);
      s2.customerArrived();
      expect(s2.phase, ShiftPhase.aborted);
    },
  );

  test('hướng dẫn trạm và thẻ "Mở mới!"', () {
    final g = _game();
    final s = _open(g);
    expect(s.tutorialFor, StationId.values.toSet());
    s.tutorialShown(StationId.mould);
    s.tutorialShown(StationId.mix);
    expect(g.tutorialSeen, {StationId.mould, StationId.mix});
    expect(
      s.tutorialFor,
      StationId.values.toSet()..removeAll([StationId.mould, StationId.mix]),
    );
    // recipeSeen = 0 → lấy cấp hiện tại, không báo bù.
    expect(g.recipeSeen, 1);
    expect(s.recipeNews, isEmpty);

    // Lên cấp ngoài tiệm (1 → 6) → ca sau báo món mở từ cấp 2 tới 6.
    g.wallet.addXp(PlayerLevel.xpToReach(6));
    final s2 = _open(g);
    expect(s2.recipeNews, RecipeUnlocks.newRecipes(1, 6));
    expect(s2.recipeNews.length, 5);
    expect(_notifies(s2, s2.acknowledgeRecipeNews), 1);
    expect(s2.recipeNews, isEmpty);
    expect(g.recipeSeen, 6);
    expect(_open(g).recipeNews, isEmpty);

    // Save cũ chưa có mốc (0) ở cấp cao → không báo bù.
    final g3 = _game(xp: PlayerLevel.xpToReach(12));
    expect(g3.recipeSeen, 0);
    expect(_open(g3).recipeNews, isEmpty);
    expect(g3.recipeSeen, 12);
  });
}
