// §7-13 CityDebugParams cho chi nhánh (chỉ khi dùng save bộ nhớ).
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/till_clock.dart';
import 'package:sugarleaf_bakery/core/debug_params.dart';

import 'branch_test_helpers.dart';

void main() {
  test('đọc query; bật memory; giá trị hỏng bị bỏ', () {
    final p = CityDebugParams.fromQuery(const {
      'branches': 's1:3,s3:1',
      'staff': 'ami@s1',
      'till': 'full',
      'away': '9',
    });
    expect(p.memorySave, isTrue);
    expect(p.branches, {'s1': 3, 's3': 1});
    expect(p.staff, {'ami': 's1'});
    expect(p.tillFull, isTrue);
    expect(p.away, 9);

    for (final k in ['branches', 'staff', 'till', 'away']) {
      expect(CityDebugParams.fromQuery({k: 'x'}).memorySave, isTrue, reason: k);
    }
    final bad = CityDebugParams.fromQuery(const {
      'branches': 's1:9,s4,:2,s3:x',
      'staff': 'ami,@s1,hanh@,cocoa@s3',
      'till': '1',
      'away': '-2',
    });
    expect(bad.branches, {'s1': 5, 's4': 1, 's3': 1});
    expect(bad.staff, {'cocoa': 's3'});
    expect(bad.tillFull, isFalse);
    expect(bad.away, isNull);
    expect(CityDebugParams.fromQuery(const {'away': 'Infinity'}).away, isNull);
    expect(CityDebugParams.fromQuery(const {'branches': ','}).branches, isNull);
    expect(CityDebugParams.none.branches, isNull);
    expect(CityDebugParams.none.staff, isNull);
    expect(CityDebugParams.none.tillFull, isFalse);
    expect(CityDebugParams.none.away, isNull);
  });

  test('branches=s1:3,s3:1 staff=ami@s1 till=full: lô, cấp, nhân viên, két đầy', () {
    final t = FakeTime();
    final g = branchGame(t, level: 1, coins: 1500);
    CityDebugParams.fromQuery(const {
      'branches': 's1:3,s3:1,n3:2,zz:1',
      'staff': 'ami@s1,hanh@s4,pierre@s1',
      'till': 'full',
    }).applyTo(g, now: t.wall);
    final b = g.branches;
    expect(b.owned, ['s1', 's3']);
    expect(b.view('s1')!.level, 3);
    expect(b.view('s3')!.level, 1);
    expect(b.staff.map((m) => m.id), ['ami']);
    expect(b.fullLots, {'s1', 's3'});
    expect(b.view('s1')!.till, 2160); // 150 × 1,5 × 1,2 × 8
    expect(b.view('s3')!.till, 2000);
    expect(b.snapshot().clock, t.ms);
    expect(g.wallet.coins, 1500);
    expect(g.resume().sold, 0);
  });

  test('away=9: lần resume kế tiếp bù 9 giờ như vừa vắng nhà', () {
    final t = FakeTime();
    final g = branchGame(t);
    CityDebugParams.fromQuery(const {'branches': 's1', 'away': '9'}).applyTo(g, now: t.wall);
    final a = g.resume();
    expect(a.away, const Duration(hours: 9));
    expect(a.sold, 1200);
    expect(a.anomaly, ClockAnomaly.none);
    expect(a.worthToast, isTrue);
    expect(g.branches.takeAway(), a);
  });

  test('dựng tay không bật memory → không áp', () {
    final t = FakeTime();
    final g = branchGame(t);
    const CityDebugParams(branches: {'s1': 2}, tillFull: true, away: 9).applyTo(g, now: t.wall);
    expect(g.branches.owned, isEmpty);
    expect(g.resume(), const BranchAway());
  });
}
