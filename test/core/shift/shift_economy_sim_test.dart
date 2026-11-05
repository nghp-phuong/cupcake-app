// Mô phỏng kinh tế ca bán (docs/v3/city-gd3-spec.md §4, §7-14): in bảng số liệu.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/core/shift/shift_economy.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';

import 'shift_test_helpers.dart';

class _Run {
  int? level5, coins8000;
  final rows = <String>[];
}

/// Bot chơi đều 3,5★ (xen kẽ 4★ / 3★), mỗi ngày (một ca) ăn một bữa [dish] trước khi mở ca; [hair] = làm tóc một lần
/// mỗi ngày (đổi kiểu, 300 xu).
_Run _simulate({
  required int seed,
  required Dish dish,
  bool hair = false,
  int shifts = 24,
}) {
  var now = DateTime(2026, 11, 4, 9);
  final g = CityGame(clock: () => now)..refreshDay();
  final run = _Run();
  var order = 0;
  for (var n = 1; n <= shifts; n++) {
    if (n > 1) {
      now = now.add(const Duration(days: 1));
      g.refreshDay();
    }
    g.wallet.eat(dish);
    if (hair) {
      final look = g.wallet.look;
      g.wallet.buyLook(
        look.copyWith(
          hair: MaiHair.values[(look.hair.index + 1) % MaiHair.values.length],
        ),
      );
    }
    final s = ShiftSession(game: g, random: math.Random(seed * 1000 + n));
    while (s.phase != ShiftPhase.finished) {
      s.customerArrived();
      s.startBaking();
      final stars = order++ % 2 == 0 ? 4 : 3;
      s.completeBake(outcomeFor(s.current.order, stars));
      s.next();
    }
    final sum = s.summary!;
    run.rows.add(
      '${'$n'.padLeft(3)} | ${'${sum.levelBefore}→${sum.levelAfter}'.padLeft(6)} | '
      '${'${sum.total}'.padLeft(5)} | ${'${sum.net}'.padLeft(6)} | ${'${sum.buffTips}'.padLeft(4)} | '
      '${'${sum.xp}'.padLeft(5)} | ${'${g.wallet.xp}'.padLeft(6)} | ${'${g.wallet.coins}'.padLeft(7)}',
    );
    if (run.level5 == null && g.wallet.level >= 5) run.level5 = n;
    if (run.coins8000 == null && g.wallet.coins >= 8000) run.coins8000 = n;
  }
  return run;
}

void main() {
  test(
    '§7-14 mô phỏng 3,5★, mỗi ngày ăn một bữa: cấp 5 ở ca 3–6, 8 000 xu ở ca 10–16',
    () {
      expect(ShiftEconomy.coinMult, 4);
      expect(ShiftEconomy.completeBonusXp, 30);
      final soup = RestaurantMenu.dishes.first; // 120 xu, 40 XP
      final main = _simulate(seed: 1, dish: soup);
      print('Mô phỏng (seed 1, 3,5★, mỗi ngày 1 ca + 1 ${soup.id}):');
      print('  ca |  cấp   | khách |  ròng | buff |  XP ca | XP tổng |     xu');
      for (final r in main.rows) {
        print('  $r');
      }
      final variants = <String, _Run Function(int)>{
        'súp cá': (s) => _simulate(seed: s, dish: soup),
        'mì hải sản': (s) =>
            _simulate(seed: s, dish: RestaurantMenu.dishes.last),
        'súp cá + làm tóc': (s) => _simulate(seed: s, dish: soup, hair: true),
      };
      final level5 = <int>[], coins8000 = <int>[];
      for (final e in variants.entries) {
        final runs = [for (var seed = 1; seed <= 8; seed++) e.value(seed)];
        print(
          '${e.key.padRight(18)} cấp 5 ở ca ${runs.map((r) => r.level5).join(',')}; '
          '8000 xu ở ca ${runs.map((r) => r.coins8000).join(',')}',
        );
        if (e.key == 'súp cá') {
          level5.addAll(runs.map((r) => r.level5!));
          coins8000.addAll(runs.map((r) => r.coins8000!));
        }
      }
      for (final l in level5) {
        expect(l, inInclusiveRange(3, 6));
      }
      for (final c in coins8000) {
        expect(c, inInclusiveRange(10, 16));
      }
    },
  );
}
