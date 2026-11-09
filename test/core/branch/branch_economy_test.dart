import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/branch_economy.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';

void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final s1 = district.lot('s1'), s3 = district.lot('s3'), s4 = district.lot('s4');

  group('bảng số §3', () {
    test('baseIncome và số chi nhánh', () {
      expect([s1.baseIncome, s3.baseIncome, s4.baseIncome], [150, 250, 400]);
      expect(district.lot('n1').baseIncome, 0);
      expect(district.branchNumber('s1'), 1);
      expect(district.branchNumber('s3'), 2);
      expect(district.branchNumber('s4'), 3);
      expect(district.branchNumber('s2'), 0);
    });

    test('xu/giờ cấp 1..5', () {
      List<int> rates(LotDef l) => [for (var v = 1; v <= 5; v++) BranchEconomy.ratePerHour(l, v)];
      expect(rates(s1), [150, 188, 225, 263, 300]);
      expect(rates(s3), [250, 313, 375, 438, 500]);
      expect(rates(s4), [400, 500, 600, 700, 800]);
    });

    test('két 8 giờ cấp 1..5', () {
      List<int> caps(LotDef l) => [for (var v = 1; v <= 5; v++) BranchEconomy.capMilli(l, v) ~/ 1000];
      expect(caps(s1), [1200, 1500, 1800, 2100, 2400]);
      expect(caps(s3), [2000, 2500, 3000, 3500, 4000]);
      expect(caps(s4), [3200, 4000, 4800, 5600, 6400]);
    });

    test('giá nâng cấp làm tròn tới 500', () {
      List<int> costs(LotDef l) => [for (var v = 2; v <= 5; v++) BranchEconomy.upgradeCost(l, v)];
      expect(costs(s1), [2000, 3000, 5000, 7000]);
      expect(costs(s3), [5000, 8000, 12000, 17000]);
      expect(costs(s4), [11500, 18000, 27000, 38500]);
    });

    test('cấp Mai cần để nâng', () {
      List<int> reqs(LotDef l) => [for (var v = 2; v <= 5; v++) BranchEconomy.upgradeLevelReq(l, v)];
      expect(reqs(s1), [5, 7, 10, 13]);
      expect(reqs(s3), [10, 12, 15, 18]);
      expect(reqs(s4), [15, 17, 20, 23]);
    });

    test('số chỗ nhân viên', () {
      expect([for (var v = 1; v <= 5; v++) BranchEconomy.slotsFor(v)], [1, 1, 2, 2, 2]);
    });

    test('bảng nhân viên', () {
      expect(StaffRoster.all.map((d) => d.id), ['biscuit', 'nutmeg', 'ami', 'hanh', 'cocoa', 'maple']);
      expect(StaffRoster.all.map((d) => d.nameKey), [
        'charBiscuit',
        'charNutmeg',
        'charAmi',
        'charHanh',
        'charCocoa',
        'charMaple',
      ]);
      expect(StaffRoster.all.map((d) => d.hireCost), [1500, 1500, 3500, 6000, 3500, 3500]);
      expect(StaffRoster.all.map((d) => d.requiresLevel), [5, 5, 8, 10, 12, 16]);
      expect(StaffRoster.byId('hanh')!.role, StaffRole.manager);
      expect(StaffRoster.byId('hanh')!.depositPct, 25);
      expect(StaffRoster.byId('zzz'), isNull);
    });

    test('thưởng nhân viên cộng dồn', () {
      // s1 cấp 1 + Biscuit (10) + Ami (20) = 150 × 1,3 = 195 xu/giờ.
      expect(BranchEconomy.rateMilliPerHour(s1, 1, bonusPct: 30), 195000);
      expect(BranchEconomy.ratePerHour(s1, 1, bonusPct: 30), 195);
      expect(BranchEconomy.capMilli(s1, 1, bonusPct: 30), 195000 * 8);
      // cấp 5 + 2 thợ bánh (40): 150 × 2 × 1,4 = 420.
      expect(BranchEconomy.ratePerHour(s1, 5, bonusPct: 40), 420);
    });
  });

  group('produce', () {
    final rate = BranchEconomy.rateMilliPerHour(s1, 1); // 150 000 mili-xu/giờ
    final cap = BranchEconomy.capMilli(s1, 1);

    test('tăng tuyến tính', () {
      final r1 = BranchEconomy.produce(tillMilli: 0, rateMilliPerHour: rate, capMilli: cap, ms: 3600000);
      expect(r1.tillMilli, 150000);
      expect(r1.depositMilli, 0);
      expect(r1.usedMs, 3600000);
      final r2 = BranchEconomy.produce(tillMilli: 0, rateMilliPerHour: rate, capMilli: cap, ms: 7200000);
      expect(r2.tillMilli, 300000);
      final r3 = BranchEconomy.produce(tillMilli: 10000, rateMilliPerHour: rate, capMilli: cap, ms: 1800000);
      expect(r3.tillMilli, 85000);
    });

    test('dừng ở trần', () {
      final r = BranchEconomy.produce(tillMilli: 0, rateMilliPerHour: rate, capMilli: cap, ms: 20 * 3600000);
      expect(r.tillMilli, cap);
      expect(r.usedMs, 8 * 3600000);
      final full = BranchEconomy.produce(tillMilli: cap, rateMilliPerHour: rate, capMilli: cap, ms: 3600000);
      expect(full.tillMilli, cap);
      expect(full.depositMilli, 0);
      expect(full.usedMs, 0);
    });

    test('quản lý chia 75/25', () {
      final r = BranchEconomy.produce(
        tillMilli: 0,
        rateMilliPerHour: rate,
        capMilli: cap,
        depositPct: 25,
        ms: 3600000,
      );
      expect(r.tillMilli, 112500);
      expect(r.depositMilli, 37500);
      // két đầy sau 8 / 0,75 giờ ≈ 10,67 giờ; ví không nhận thêm sau đó.
      final long = BranchEconomy.produce(
        tillMilli: 0,
        rateMilliPerHour: rate,
        capMilli: cap,
        depositPct: 25,
        ms: 24 * 3600000,
      );
      expect(long.tillMilli, cap);
      expect(long.depositMilli, closeTo(cap / 3, 1));
      expect(long.usedMs, closeTo(8 * 3600000 / 0.75, 1000));
    });

    test('3 600 bước × 1 s bằng 1 bước 1 giờ', () {
      for (final pct in [0, 25]) {
        final lot = s3;
        final rt = BranchEconomy.rateMilliPerHour(lot, 2, bonusPct: 20); // 375 xu/giờ -> số lẻ
        final cp = BranchEconomy.capMilli(lot, 2, bonusPct: 20);
        var till = 0, dep = 0, carry = 0;
        for (var i = 0; i < 3600; i++) {
          final r = BranchEconomy.produce(
            tillMilli: till,
            rateMilliPerHour: rt,
            capMilli: cp,
            depositPct: pct,
            ms: 1000,
            carry: carry,
          );
          till = r.tillMilli;
          dep += r.depositMilli;
          carry = r.carry;
        }
        final one = BranchEconomy.produce(
          tillMilli: 0,
          rateMilliPerHour: rt,
          capMilli: cp,
          depositPct: pct,
          ms: 3600000,
        );
        expect((till + dep - one.tillMilli - one.depositMilli).abs(), lessThanOrEqualTo(1000));
        expect((till - one.tillMilli).abs(), lessThanOrEqualTo(1000));
        expect((dep - one.depositMilli).abs(), lessThanOrEqualTo(1000));
      }
    });
  });
}
