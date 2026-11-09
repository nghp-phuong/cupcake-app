// §7-12 mô phỏng kinh tế chi nhánh (docs/v3/city-gd4-spec.md §3, §7-12): in bảng số liệu.
// Mỗi ngày 2 phiên (9 h và 21 h, cách 12 giờ) × 4 ca 4,5 phút; bot chơi đều 3,5★ (xen kẽ 4★ / 3★) như mô phỏng GĐ3,
// mỗi phiên ăn một bát súp cá trước ca đầu. Đầu phiên và sau mỗi ca: thu mọi két rồi quyết định mua / nâng cấp / thuê.
//
// Mục tiêu (trưởng phòng chốt 05/11, giữ baseIncome 150/250/400): dồn tiền s3 ở ca 22–36, s4 ở ca 42–70, két 8 giờ
// của s1 cấp 1 = 1,15–2,0 ca ở cấp Mai 5–9. Nới so với bản đầu (24–36 / 50–70 / 1,2–2,0) vì ca bán thực tế ròng
// ~820–1 020 xu ở cấp 5–9 (~1 150–1 300 xu ở cấp 11–23), cao hơn mức ~700 xu mà bảng tay §3 giả định; cổng cấp của lô
// không bao giờ chặn (Mai cấp 15 quanh ca 24) nên chỉ xu là nút thắt.
// Phần chi nhánh khi cân bằng: ≤ 50% (chốt tạm 05/11, chờ chủ dự án; đặc tả gốc ≤ 40%, đo được 48–50%). Bot cân bằng
// nâng tối đa và thuê đủ người trước khi mua lô kế, nên chi nhánh chạy ở cấp 5 + 2 nhân viên suốt lúc chờ s4. Quét
// levelPct / upgradeCostFrac (cân bằng: s3 / s4 / phần chi nhánh):
//   levelPct 100/125/150/175/200, giá 25/40/60/85 (hiện tại) → 32–35 / 60–63 / 48–50%
//   cùng levelPct, giá 40/65/95/130 → 38–40 / 72–75 / 49–50%; giá 50/80/120/170 → s4 80–84 (vượt) / 48–50%
//   levelPct 100/115/130/145/160 → 34–36 / 64–68 / 44–46%; 100/110/…/140 → 40–44%
//   levelPct 100/104/108/112/116 → 36–38 / 70–72 / 37–40,1% (nâng cấp gần như vô nghĩa: +6 xu/giờ cho 2 000 xu)
// Tăng giá nâng không hạ được tỉ lệ (bot vẫn nâng hết, chỉ chậm hơn); chỉ levelPct gần phẳng mới chạm 40%.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/branch_economy.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';

import '../shift/shift_test_helpers.dart';
import 'branch_test_helpers.dart';

enum _Plan {
  /// Chỉ dồn tiền mua lô kế tiếp.
  hoard,

  /// Vừa mua vừa nâng cấp: luôn làm việc rẻ nhất đang làm được (mua lô kế, nâng cấp, thuê người).
  balanced,
}

class _Run {
  _Run(this.plan, this.seed);

  final _Plan plan;
  final int seed;

  /// Ca (đã chơi xong) lúc mua s1 / s3 / s4.
  final bought = <String, int>{};

  /// Thu nhập tới lúc có s4: ca bán (ròng), chi nhánh (thu két + quản lý gửi về).
  int shiftIncome = 0, branchIncome = 0;

  /// Xu ròng các ca ở cấp Mai 5–9.
  final midShifts = <int>[];
  final rows = <String>[];

  double get branchShare => branchIncome / (shiftIncome + branchIncome);
  double get tillInShifts => 1200 / (midShifts.reduce((a, b) => a + b) / midShifts.length);
}

final _district = CityConfig.alpha.district('bakery_street');
const _order = ['s1', 's3', 's4'];

class _Spend {
  const _Spend(this.label, this.cost, this.apply);

  final String label;
  final int cost;
  final void Function() apply;
}

/// Nâng cấp / thuê người đang làm được (đủ cấp Mai, còn chỗ). Mỗi lô còn chỗ: thợ bánh nếu có, không thì người đầu
/// tiên còn rảnh theo bảng (phục vụ, quản lý).
List<_Spend> _improvements(CityBranches b, CityGame g) {
  final out = <_Spend>[];
  for (final id in b.owned) {
    final v = b.view(id)!;
    if (v.nextCost != null && g.wallet.level >= v.nextLevelReq!) {
      out.add(_Spend('nâng $id lên cấp ${v.level + 1}', v.nextCost!, () => b.upgrade(id)));
    }
    if (b.staffAt(id).length < v.slots) {
      final free = StaffRoster.all.where((d) => g.wallet.level >= d.requiresLevel && !b.staff.any((m) => m.id == d.id));
      final pick = free.where((d) => d.role == StaffRole.baker).firstOrNull ?? free.firstOrNull;
      if (pick != null) out.add(_Spend('thuê ${pick.id} ở $id', pick.hireCost, () => b.hire(pick.id, id)));
    }
  }
  return out;
}

_Run _simulate(_Plan plan, int seed, {int maxShifts = 160}) {
  final t = FakeTime(DateTime.utc(2026, 11, 5, 9));
  final g = CityGame(clock: t.now, mono: t.monoNow)..refreshDay();
  final b = g.branches;
  final run = _Run(plan, seed);
  final soup = RestaurantMenu.dishes.first;
  var shifts = 0, stars = 0;

  /// Thao tác chi nhánh: phần ví tăng ngoài giá phải trả là thu nhập chi nhánh (thu két, quản lý gửi về).
  void op(int cost, void Function() f) {
    final before = g.wallet.coins;
    f();
    if (!run.bought.containsKey('s4')) run.branchIncome += g.wallet.coins - before + cost;
  }

  void decide() {
    for (final id in b.owned) {
      op(0, () => b.collect(id));
    }
    while (true) {
      final next = _order.where((id) => !b.owns(id)).firstOrNull;
      final lot = next == null ? null : _district.lot(next);
      final all = [
        if (lot != null && g.wallet.level >= lot.requiresLevel)
          _Spend('mua ${lot.id}', lot.price, () {
            b.buy(lot.id);
            run.bought[lot.id] = shifts;
          }),
        if (plan == _Plan.balanced) ..._improvements(b, g),
      ]..sort((a, c) => a.cost.compareTo(c.cost));
      final best = all.firstOrNull;
      if (best == null || g.wallet.coins < best.cost) return;
      op(best.cost, best.apply);
      run.rows.add(
        '  ca ${'$shifts'.padLeft(3)}: ${best.label} (${best.cost} xu; cấp Mai ${g.wallet.level}, còn ${g.wallet.coins} xu)',
      );
    }
  }

  for (var day = 0; shifts < maxShifts && !run.bought.containsKey('s4'); day++) {
    for (final hourOfDay in [9, 21]) {
      final start = DateTime.utc(2026, 11, 5 + day, hourOfDay);
      if (start.isAfter(t.wall)) t.off(start.difference(t.wall));
      op(0, () => g.resume());
      decide();
      g.wallet.eat(soup);
      for (var k = 0; k < 4; k++) {
        final level = g.wallet.level;
        final s = ShiftSession(game: g, random: math.Random(seed * 1000 + shifts));
        while (s.phase != ShiftPhase.finished) {
          s.customerArrived();
          s.startBaking();
          s.completeBake(outcomeFor(s.current.order, stars++ % 2 == 0 ? 4 : 3));
          s.next();
        }
        shifts++;
        final net = s.summary!.net;
        if (!run.bought.containsKey('s4')) run.shiftIncome += net;
        if (level >= 5 && level <= 9) run.midShifts.add(net);
        t.play(const Duration(minutes: 4, seconds: 30));
        decide();
      }
    }
  }
  return run;
}

final _runs = {
  for (final p in _Plan.values) p: [for (var seed = 1; seed <= 8; seed++) _simulate(p, seed)],
};

void main() {
  test('§7-12 mô phỏng: in bảng, kiểm mục tiêu', () {
    expect(BranchEconomy.levelPct, [100, 125, 150, 175, 200]);
    final runs = _runs;
    for (final p in _Plan.values) {
      print('Mô phỏng ${p.name} (seed 1):');
      runs[p]!.first.rows.forEach(print);
    }
    print('');
    print('kiểu      seed | s1 | s3 | s4 | chi nhánh/tổng tới s4 | két s1 = ca (cấp 5–9)');
    for (final p in _Plan.values) {
      for (final r in runs[p]!) {
        print(
          '${p.name.padRight(9)} ${'${r.seed}'.padLeft(4)} | ${'${r.bought['s1']}'.padLeft(2)} | '
          '${'${r.bought['s3']}'.padLeft(2)} | ${'${r.bought['s4']}'.padLeft(2)} | '
          '${(r.branchShare * 100).toStringAsFixed(1).padLeft(20)}% | ${r.tillInShifts.toStringAsFixed(2)}',
        );
      }
    }
    for (final r in runs[_Plan.balanced]!) {
      expect(r.bought['s3'], inInclusiveRange(28, 40), reason: 'cân bằng seed ${r.seed}: s3');
      expect(r.bought['s4'], inInclusiveRange(58, 80), reason: 'cân bằng seed ${r.seed}: s4');
      expect(r.branchShare, lessThanOrEqualTo(0.50), reason: 'cân bằng seed ${r.seed}');
    }
    for (final r in runs[_Plan.hoard]!) {
      expect(r.bought['s3'], inInclusiveRange(22, 36), reason: 'dồn tiền seed ${r.seed}: s3');
      expect(r.bought['s4'], inInclusiveRange(42, 70), reason: 'dồn tiền seed ${r.seed}: s4');
      expect(r.branchShare, lessThanOrEqualTo(0.40), reason: 'dồn tiền seed ${r.seed}');
      expect(r.tillInShifts, inInclusiveRange(1.15, 2.0), reason: 'két s1, seed ${r.seed}');
    }
  });
}
