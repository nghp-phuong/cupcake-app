// §7-3 (qua CityBranches), §7-4 … §7-9 (docs/v3/city-gd4-spec.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/branch_state.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/branch/till_clock.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';

import 'branch_test_helpers.dart';

void main() {
  group('§7-5 buy', () {
    test('đủ 5 kết quả; lô đầu đặt mốc; notify 1 lần', () {
      final t = FakeTime();
      final g = branchGame(t, level: 4, coins: 7000);
      final b = g.branches;
      var n = 0;
      b.addListener(() => n++);
      expect(b.buy('n3'), BranchBuy.notBranch);
      expect(b.buy('s2'), BranchBuy.notBranch); // công viên
      expect(b.buy('zz'), BranchBuy.notBranch);
      expect(b.buy('s1'), BranchBuy.levelTooLow);
      g.wallet.addXp(PlayerLevel.xpToReach(5) - g.wallet.xp);
      expect(b.buy('s1'), BranchBuy.notEnoughCoins);
      expect(n, 0);
      expect(b.snapshot().clock, 0);

      g.wallet.earn(coins: 1000);
      expect(b.buy('s1'), BranchBuy.ok);
      expect(n, 1);
      expect(g.wallet.coins, 0);
      expect(b.owns('s1'), isTrue);
      expect(b.owned, ['s1']);
      final book = b.snapshot();
      expect(book.clock, t.ms);
      expect(book.lots['s1'], BranchState(lotId: 's1', boughtAt: t.ms));
      expect(b.buy('s1'), BranchBuy.owned);
      expect(n, 1);
    });

    test('lô thứ hai không đặt lại mốc; két lô đầu được bù trước khi mua', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final mark = t.ms;
      t.play(hour);
      expect(b.buy('s3'), BranchBuy.ok);
      final book = b.snapshot();
      expect(book.clock, mark + hour.inMilliseconds);
      expect(book.lots['s1']!.tillMilli, 150000);
      expect(book.lots['s3']!.tillMilli, 0);
      expect(b.owned, ['s1', 's3']);
      expect(g.wallet.coins, 100000 - 8000 - 20000);
    });
  });

  group('đọc: view / fullLots / totalTill', () {
    test('số liệu đúng, không notify, không đụng ví', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      t.play(hour);
      b.buy('s3');
      t.play(const Duration(hours: 7));
      final n0 = g.wallet.coins;
      var n = 0;
      b.addListener(() => n++);
      expect(b.fullLots, {'s1'});
      expect(b.totalTill, 1200 + 1750);
      final v3 = b.view('s3')!;
      expect(
        v3,
        const BranchView(
          lotId: 's3',
          branchNo: 2,
          level: 1,
          till: 1750,
          cap: 2000,
          ratePerHour: 250,
          slots: 1,
          fullIn: hour,
          full: false,
          nextCost: 5000,
          nextLevelReq: 10,
          nextRatePerHour: 313,
          nextCap: 2500,
        ),
      );
      final v1 = b.view('s1')!;
      expect(v1.full, isTrue);
      expect(v1.fullIn, Duration.zero);
      expect(v1.till, 1200);
      expect(b.view('s4'), isNull);
      expect(n, 0);
      expect(g.wallet.coins, n0);
    });

    test('cấp tối đa: không có cấp kế', () {
      final t = FakeTime();
      final b = branchGame(t).branches
        ..restore(BranchBook(clock: t.ms, lots: {'s1': const BranchState(lotId: 's1', level: 5)}));
      final v = b.view('s1')!;
      expect(v.level, 5);
      expect(v.slots, 2);
      expect([v.nextCost, v.nextLevelReq, v.nextRatePerHour, v.nextCap], [null, null, null, null]);
    });
  });

  group('§7-6 collect / x2', () {
    test('phần nguyên và phần lẻ; earned; két rỗng không đổi gì', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final c0 = g.wallet.coins;
      t.play(minute); // 2,5 xu
      var n = 0;
      b.addListener(() => n++);
      final c1 = b.collect('s1');
      expect(c1, const BranchCollect(coins: 2));
      expect(c1.ok, isTrue);
      expect(n, 1);
      expect(g.wallet.coins, c0 + 2);
      expect(b.snapshot().lots['s1']!.tillMilli, 500);
      t.play(minute); // 0,5 + 2,5 = 3 xu
      expect(b.collect('s1').coins, 3);
      expect(b.snapshot().lots['s1']!.tillMilli, 0);
      expect(b.snapshot().lots['s1']!.earned, 5);
      expect(n, 2);
      final empty = b.collect('s1');
      expect(empty, const BranchCollect());
      expect(empty.ok, isFalse);
      expect(b.collect('s3'), const BranchCollect());
      expect(n, 2);
    });

    test('x2: chỉ khi lần thu ≥ 50% trần; mỗi lần thu một lần; mỗi ngày một lần', () {
      final t = FakeTime(DateTime.utc(2026, 11, 5, 0, 30));
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      t.play(const Duration(hours: 3, minutes: 59)); // 597,5 xu
      expect(b.collect('s1').coins, 597);
      expect(b.canDouble('s1'), isFalse);
      expect(b.applyDouble('s1'), 0);

      t.play(const Duration(hours: 4)); // 0,5 + 600
      final c = b.collect('s1');
      expect(c, const BranchCollect(coins: 600));
      expect(b.canDouble('s1'), isTrue);
      final before = g.wallet.coins;
      var n = 0;
      b.addListener(() => n++);
      expect(b.applyDouble('s1'), 600);
      expect(n, 1);
      expect(g.wallet.coins, before + 600);
      expect(b.snapshot().lots['s1']!.adDate, '2026-11-05');
      expect(b.canDouble('s1'), isFalse);
      expect(b.applyDouble('s1'), 0);
      expect(g.wallet.coins, before + 600);

      // Cùng ngày: két đầy vẫn không x2 được nữa.
      t.play(const Duration(hours: 9));
      expect(b.collect('s1'), const BranchCollect(coins: 1200, wasFull: true));
      expect(b.canDouble('s1'), isFalse);

      // Hôm sau: được lại. Lần thu nhỏ sau đó xoá cơ hội x2.
      t.play(const Duration(hours: 9));
      expect(cityDay(t), '2026-11-06');
      expect(b.collect('s1').coins, 1200);
      expect(b.canDouble('s1'), isTrue);
      t.play(minute);
      expect(b.collect('s1').coins, 2);
      expect(b.canDouble('s1'), isFalse);
      expect(b.snapshot().lots['s1']!.earned, 597 + 600 + 1200 + 1200 + 2);
      expect(b.canDouble('s3'), isFalse);
    });
  });

  group('§7-7 upgrade', () {
    test('các trường hợp bị chặn; bù theo tốc độ cũ trước khi nâng', () {
      final t = FakeTime();
      final g = branchGame(t, level: 5);
      final b = g.branches;
      expect(b.upgrade('s1'), BranchUpgrade.notOwned);
      b.buy('s1');
      t.play(hour); // 150 xu ở cấp 1
      var n = 0;
      b.addListener(() => n++);
      expect(b.upgrade('s1'), BranchUpgrade.ok);
      expect(n, 1);
      expect(g.wallet.coins, 100000 - 8000 - 2000);
      expect(b.view('s1')!.till, 150);
      t.play(hour); // + 187,5 ở cấp 2
      expect(b.snapshot().lots['s1']!.tillMilli, 337500);

      expect(b.upgrade('s1'), BranchUpgrade.levelTooLow); // cấp 3 cần Mai 7
      g.wallet.addXp(PlayerLevel.xpToReach(13) - g.wallet.xp);
      g.wallet.earn(coins: 2999 - g.wallet.coins);
      expect(b.upgrade('s1'), BranchUpgrade.notEnoughCoins);
      expect(n, 1);
      g.wallet.earn(coins: 1 + 5000 + 7000);
      expect(b.upgrade('s1'), BranchUpgrade.ok);
      expect(b.upgrade('s1'), BranchUpgrade.ok);
      expect(b.upgrade('s1'), BranchUpgrade.ok);
      expect(g.wallet.coins, 0);
      expect(b.view('s1')!.level, 5);
      expect(b.upgrade('s1'), BranchUpgrade.maxLevel);
      expect(n, 4);
      expect(b.snapshot().lots['s1']!.tillMilli, 337500); // két giữ nguyên
    });
  });

  group('§7-8 hire / dismiss', () {
    test('trùng người, hết chỗ, thiếu cấp, thiếu xu; thưởng cộng dồn', () {
      final t = FakeTime();
      final g = branchGame(t, level: 9);
      final b = g.branches;
      expect(b.hire('zz', 's1'), StaffHire.unknown);
      expect(b.hire('ami', 's1'), StaffHire.notOwned);
      b.buy('s1');
      var n = 0;
      b.addListener(() => n++);
      expect(b.hire('ami', 's1'), StaffHire.ok);
      expect(n, 1);
      expect(g.wallet.coins, 100000 - 8000 - 3500);
      expect(b.hire('ami', 's1'), StaffHire.taken);
      expect(b.hire('biscuit', 's1'), StaffHire.noSlot);
      b
        ..upgrade('s1')
        ..upgrade('s1'); // cấp 3: 2 chỗ
      expect(b.view('s1')!.slots, 2);
      expect(b.hire('hanh', 's1'), StaffHire.levelTooLow); // Hạnh cần cấp 10
      g.wallet.earn(coins: 1499 - g.wallet.coins);
      expect(b.hire('biscuit', 's1'), StaffHire.notEnoughCoins);
      expect(n, 3);
      g.wallet.earn(coins: 1);
      expect(b.hire('biscuit', 's1'), StaffHire.ok);
      expect(g.wallet.coins, 0);
      // cấp 3 (150%) + Ami 20 + Biscuit 10 = 150 × 1,5 × 1,3 = 292,5 → 293 xu/giờ.
      final v = b.view('s1')!;
      expect(v.bonusPct, 30);
      expect(v.ratePerHour, 293);
      expect(v.cap, 2340);
      expect(b.staffAt('s1').map((m) => m.id), ['ami', 'biscuit']);
      expect(b.staff.first, StaffMember(id: 'ami', lotId: 's1', since: t.ms));
      expect(b.hire('nutmeg', 's1'), StaffHire.noSlot);
      expect(() => b.staff.add(b.staff.first), throwsUnsupportedError);
    });

    test('quản lý gửi 25% về ví; cho nghỉ thì thu két, hoàn 50%, trả chỗ', () {
      final t = FakeTime();
      final g = branchGame(t, level: 10);
      final b = g.branches..buy('s1');
      expect(b.hire('hanh', 's1'), StaffHire.ok);
      final v = b.view('s1')!;
      expect(v.depositPct, 25);
      expect(v.ratePerHour, 150);
      final coins0 = g.wallet.coins;
      t.play(hour);
      // Đọc: két nhận 75%, ví chưa nhận (trả ở lần ghi kế tiếp / snapshot).
      expect(b.snapshot().lots['s1']!.tillMilli, 112500);
      expect(g.wallet.coins, coins0 + 37); // snapshot đã trả 37 xu (giữ 0,5)
      t.play(hour);
      expect(b.view('s1')!.till, 225);
      expect(g.wallet.coins, coins0 + 37);
      // Đầy sau (1200 − 225) / 112,5 giờ.
      expect(b.view('s1')!.fullIn, Duration(milliseconds: (975000 * 3600000 / 112500).ceil()));

      final before = g.wallet.coins;
      var n = 0;
      b.addListener(() => n++);
      final d = b.dismiss('hanh');
      expect(d, const StaffDismiss(ok: true, collected: 225, refund: 3000));
      expect(n, 1);
      // + 38 xu quản lý gửi về (0,5 + 37,5) trả trước khi đổi trạng thái.
      expect(g.wallet.coins, before + 38 + 225 + 3000);
      expect(b.staffAt('s1'), isEmpty);
      expect(b.view('s1')!.till, 0);
      expect(b.snapshot().lots['s1']!.earned, 225);
      expect(b.dismiss('hanh'), const StaffDismiss());
      expect(b.dismiss('zz'), const StaffDismiss());
      expect(n, 1);
      expect(b.hire('ami', 's1'), StaffHire.ok); // chỗ đã trả
    });
  });

  group('§7-9 resume / takeAway', () {
    test('trả BranchAway; takeAway một lần; không cộng hai lần; cộng dồn khi chưa lấy', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches;
      expect(g.resume(), const BranchAway()); // chưa có lô: không đổi gì
      expect(b.takeAway(), const BranchAway());
      expect(b.takeAway(), isNull);
      b.buy('s1');
      t.off(const Duration(hours: 2));
      var n = 0;
      b.addListener(() => n++);
      final a = g.resume();
      expect(a, const BranchAway(away: Duration(hours: 2), sold: 300));
      expect(a.worthToast, isTrue);
      expect(n, 1);
      expect(b.takeAway(), a);
      expect(b.takeAway(), isNull);

      expect(g.resume().sold, 0); // ngay sau đó: không cộng hai lần
      // App ở nền 1 giờ, tiến trình còn sống (đồng hồ đơn điệu vẫn chạy) → chỉ 1 giờ.
      t.play(hour);
      final a2 = g.resume();
      expect(a2, const BranchAway(away: hour, sold: 150));
      t.off(const Duration(minutes: 20));
      final a3 = g.resume();
      expect(a3.sold, 50);
      expect(a3.worthToast, isFalse); // vắng < 30 phút
      expect(b.takeAway(), const BranchAway(away: Duration(minutes: 80), sold: 200));
      expect(b.view('s1')!.till, 300 + 150 + 50);
    });

    test('quản lý gửi về lúc vắng nhà', () {
      final t = FakeTime();
      final g = branchGame(t, level: 10);
      final b = g.branches
        ..buy('s1')
        ..hire('hanh', 's1');
      final coins0 = g.wallet.coins;
      t.off(const Duration(hours: 4));
      final a = g.resume();
      expect(a, const BranchAway(away: Duration(hours: 4), sold: 450, deposited: 150));
      expect(g.wallet.coins, coins0 + 150);
      expect(a.worthToast, isTrue);
      expect(b.view('s1')!.till, 450);
    });

    test('giờ máy lùi: két tạm nghỉ, đuổi kịp thì chạy tiếp', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final mark = t.ms;
      t.setWall(t.wall.subtract(const Duration(hours: 2)));
      final a = g.resume();
      expect(a.anomaly, ClockAnomaly.behind);
      expect(a.sold, 0);
      expect(b.anomaly, ClockAnomaly.behind);
      t.play(hour); // vẫn chậm 1 giờ
      expect(b.view('s1')!.till, 0);
      expect(b.anomaly, ClockAnomaly.behind);
      t.play(hour); // giờ máy = mốc
      expect(b.view('s1')!.till, 0);
      expect(b.anomaly, ClockAnomaly.none);
      expect(b.snapshot().clock, mark);
      t.play(hour);
      expect(b.view('s1')!.till, 150);
    });
  });

  group('§7-3 qua CityBranches', () {
    test('+1 năm → chỉ đầy két (quản lý: ví nhận ≤ 1/3 két)', () {
      final t = FakeTime();
      final g = branchGame(t, level: 10);
      final b = g.branches
        ..buy('s1')
        ..hire('hanh', 's1');
      final coins0 = g.wallet.coins;
      t.off(const Duration(days: 365));
      final a = g.resume();
      expect(a.sold, 1200);
      expect(a.deposited, 400);
      expect(g.wallet.coins, coins0 + 400);
      expect(b.fullLots, {'s1'});
    });

    test('năm 1970: rescued, két giữ nguyên; sửa giờ lại chỉ được tối đa một két', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final real = t.wall;
      t.off(const Duration(hours: 2));
      g.resume(); // 300 xu
      t.setWall(DateTime.utc(1970, 1, 1, 0, 0, 5));
      final a = g.resume();
      expect(a.anomaly, ClockAnomaly.rescued);
      expect(a.sold, 0);
      expect(b.view('s1')!.till, 300);
      expect(b.snapshot().clock, 5000);
      t.setWall(real.add(const Duration(hours: 3)));
      expect(g.resume().sold, lessThanOrEqualTo(1200));
      expect(b.fullLots, {'s1'});
    });

    test('đổi múi giờ (cùng một thời điểm) → 0', () {
      final t = FakeTime(DateTime.utc(2026, 11, 5, 3));
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      for (final w in [DateTime.parse('2026-11-05T10:00:00+07:00'), DateTime.utc(2026, 11, 5, 3).toLocal()]) {
        t.setWall(w);
        expect(g.resume().sold, 0);
      }
      expect(b.view('s1')!.till, 0);
    });
  });

  group('§7-4 gian lận', () {
    test('chỉnh giờ tới 8 giờ, thu, rồi lùi lại → 16 giờ thật vẫn ra bằng chơi thật (±1 két)', () {
      // Chơi thật: mở app ở giờ 8 và 16, thu cả hai lần.
      final th = FakeTime();
      final gh = branchGame(th);
      gh.branches.buy('s1');
      var honest = 0;
      for (var i = 0; i < 2; i++) {
        th.off(const Duration(hours: 8));
        gh.resume();
        honest += gh.branches.collect('s1').coins;
      }

      // Gian lận: ở giờ 0 chỉnh máy +8 giờ, thu, chỉnh về giờ thật; rồi mở app ở giờ 8 và 16 thật.
      final tc = FakeTime();
      final gc = branchGame(tc);
      final b = gc.branches..buy('s1');
      final start = tc.wall;
      var cheat = 0;
      tc.setWall(start.add(const Duration(hours: 8)));
      gc.resume();
      cheat += b.collect('s1').coins;
      tc.setWall(start.add(minute));
      expect(gc.resume().anomaly, ClockAnomaly.behind);
      for (final h in [8, 16]) {
        tc.setWall(start.add(Duration(hours: h)));
        gc.resume();
        cheat += b.collect('s1').coins;
      }
      expect(honest, 2400);
      expect((cheat - honest).abs(), lessThanOrEqualTo(1200));
    });

    test('lùi giờ nhiều lần → 0', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final real = t.wall;
      for (final back in [5, 9, 30, 90, 600, 3000]) {
        t.setWall(real.subtract(Duration(minutes: back)));
        expect(g.resume().sold, 0, reason: '$back');
        t.setWall(real);
        expect(g.resume().sold, 0, reason: '$back');
      }
      expect(b.collect('s1').coins, 0);
      expect(b.snapshot().clock, real.millisecondsSinceEpoch);
    });

    test('mỗi vòng chỉnh giờ (tới tương lai rồi lùi quá 72 giờ) chỉ thêm tối đa 1 két', () {
      final t = FakeTime();
      final g = branchGame(t);
      final b = g.branches..buy('s1');
      final real = t.wall;
      var got = 0;
      for (var round = 1; round <= 3; round++) {
        t.setWall(real.add(const Duration(days: 400)));
        g.resume();
        got += b.collect('s1').coins;
        t.setWall(real);
        expect(g.resume().anomaly, ClockAnomaly.rescued);
        expect(got, lessThanOrEqualTo(round * 1200));
      }
    });
  });

  test('restore: lô ngoài quận / nhân viên lạ giữ nguyên, nhân viên sai bị bỏ, két kẹp ≤ trần', () {
    final t = FakeTime();
    final g = branchGame(t);
    final b = g.branches;
    var n = 0;
    b.addListener(() => n++);
    b.restore(
      BranchBook(
        clock: t.ms,
        lots: {
          's1': const BranchState(lotId: 'x', level: 1, tillMilli: 9000000),
          'z9': const BranchState(lotId: 'z9', level: 2),
        },
        staff: [
          const StaffMember(id: 'ami', lotId: 's1', since: 1),
          const StaffMember(id: 'biscuit', lotId: 's1', since: 2), // vượt số chỗ
          const StaffMember(id: 'hanh', lotId: 's3', since: 3), // lô chưa mua
          const StaffMember(id: 'cocoa', lotId: 'z9', since: 4), // ở lô lạ
          const StaffMember(id: 'pierre', lotId: 's1', since: 5), // id lạ
        ],
        extraLots: {'q1': 1},
      ),
    );
    expect(n, 1);
    expect(b.owned, ['s1']);
    expect(b.staff.map((m) => m.id), ['ami']);
    expect(b.view('s1')!.till, 1440); // trần cấp 1 + Ami 20%
    final book = b.snapshot();
    expect(book.lots['s1']!.lotId, 's1');
    expect(book.extraLots, {
      'q1': 1,
      'z9': {'lv': 2, 'till': 0, 'bought': 0, 'earned': 0, 'ad': ''},
    });
    expect(book.extraStaff, [
      {'id': 'cocoa', 'lot': 'z9', 'since': 4},
      {'id': 'pierre', 'lot': 's1', 'since': 5},
    ]);
  });
}

String cityDay(FakeTime t) =>
    '${t.wall.year}-${t.wall.month.toString().padLeft(2, '0')}-${t.wall.day.toString().padLeft(2, '0')}';
