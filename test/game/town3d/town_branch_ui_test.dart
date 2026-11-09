import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/till_clock.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/game/town3d/town_branch_ui.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_meshes.dart';
import 'package:sugarleaf_bakery/game/town3d/town_rules.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

/// Ghép chi nhánh vào phố (docs/v3/city-gd4-spec.md §4, §5 — G2): phần Dart thuần `TownBranchUi` + biểu tượng két đầy.
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final layout = TownLayout.forDistrict(district);

  var wall = DateTime.utc(2026, 11, 5, 9);
  var mono = Duration.zero;
  CityGame game({int level = 20, int coins = 200000}) => CityGame(
        wallet: CityWallet(coins: coins, xp: PlayerLevel.xpToReach(level)),
        clock: () => wall,
        mono: () => mono,
      );
  void play(Duration d) {
    wall = wall.add(d);
    mono += d;
  }

  setUp(() {
    wall = DateTime.utc(2026, 11, 5, 9);
    mono = Duration.zero;
  });

  test('biểu tượng két đầy ở (l 2,5; d 1,4; y 2,3) trong lô, khác chỗ nhân viên đứng', () {
    for (final lot in district.lots.where((l) => l.kind == LotKind.branch)) {
      final p = TownBranchUi.iconAt(lot);
      expect(p.y, 2.3);
      expect(p.x, inInclusiveRange(lot.minX, lot.maxX), reason: lot.id);
      expect(p.z, inInclusiveRange(lot.minZ, lot.maxZ), reason: lot.id);
      // Lô nam: l = −x, d = +z.
      expect(p.x, closeTo(lot.doorX - 2.5, 1e-9));
      expect(p.z, closeTo(lot.doorZ + 1.4, 1e-9));
    }
  });

  test('biểu tượng ẩn ở lô Mai đang đứng ở vùng cửa, các lô khác vẫn hiện', () {
    final zones = TownRules.zonesOf(layout);
    final door = zones.firstWhere((z) => z.lotId == 's1' && z.kind == TownZoneKind.door);
    final other = zones.firstWhere((z) => z.lotId == 'n3' && z.kind == TownZoneKind.counter);
    const full = {'s1', 's3'};
    expect(TownBranchUi.visibleIcons(full, null), full);
    expect(TownBranchUi.visibleIcons(full, door), {'s3'});
    expect(TownBranchUi.visibleIcons(full, other), full);
    expect(TownBranchUi.visibleIcons(const {'s3'}, door), {'s3'});
  });

  test('nút A ở cửa chi nhánh: "Thu tiền" khi két ≥ 25% trần (hoặc đầy), không thì "Chi nhánh"', () {
    final g = game();
    final b = g.branches;
    expect(b.buy('s1'), BranchBuy.ok); // 150 xu/giờ, trần 1 200 → 25% = 300 xu = 2 giờ
    expect(TownBranchUi.collectable(null), isFalse);
    expect(TownBranchUi.collectable(b.view('s1')), isFalse, reason: 'vừa mua: két 0');
    play(const Duration(minutes: 1)); // 2,5 xu
    expect(TownBranchUi.collectable(b.view('s1')), isFalse, reason: 'có xu nhưng < 25% trần');
    play(const Duration(minutes: 119)); // tròn 2 giờ: 300 xu
    expect(b.view('s1')!.till, 300);
    expect(TownBranchUi.collectable(b.view('s1')), isTrue, reason: 'đúng 25% trần');
    play(const Duration(hours: 10));
    expect(b.view('s1')!.full, isTrue);
    expect(TownBranchUi.collectable(b.view('s1')), isTrue, reason: 'két đầy');
    expect(b.collect('s1').ok, isTrue);
    expect(TownBranchUi.collectable(b.view('s1')), isFalse, reason: 'vừa thu: còn phần lẻ < 1 xu');
  });

  test('góc cận bảng chi nhánh: nhìn từ phía đường (yaw ≈ π − 0,5), mặt tiền nằm nửa trái màn', () {
    for (final lot in district.lots.where((l) => l.kind == LotKind.branch)) {
      final c = TownBranchUi.closeUp(lot);
      expect(c.yaw, closeTo(math.pi - 0.5, 1e-9), reason: lot.id);
      final cp = math.cos(c.pitch);
      final ex = c.x + c.distance * math.sin(c.yaw) * cp, ez = c.z + c.distance * math.cos(c.yaw) * cp;
      expect(ez, lessThan(lot.doorZ), reason: 'mắt camera ở phía đường (bắc) của lô nam');
      // Tâm mặt tiền lệch sang trái so với điểm nhìn (véc-tơ phải của màn = (cos yaw, −sin yaw)).
      final (fx, fz) = TownBranchUi.lotPoint(lot, 0.8, 2.2);
      final right = (fx - c.x) * math.cos(c.yaw) + (fz - c.z) * -math.sin(c.yaw);
      expect(right, lessThan(-1.5), reason: lot.id);
      // Mắt không lọt vào trong lô.
      expect(ex < lot.minX || ex > lot.maxX || ez < lot.minZ, isTrue, reason: lot.id);
    }
  });

  test('cấp mặt tiền, dữ liệu minimap, nhân viên theo lô', () {
    final g = game();
    final b = g.branches;
    expect(TownBranchUi.levels(district, b), {'s1': 0, 's3': 0, 's4': 0});
    expect(TownBranchUi.marks(b).owned, isEmpty);
    b
      ..buy('s1')
      ..buy('s3')
      ..upgrade('s3')
      ..upgrade('s3');
    expect(b.hire('ami', 's3'), StaffHire.ok);
    expect(b.hire('biscuit', 's3'), StaffHire.ok);
    expect(b.hire('hanh', 's1'), StaffHire.ok);
    expect(TownBranchUi.levels(district, b), {'s1': 1, 's3': 3, 's4': 0});
    play(const Duration(hours: 9));
    final m = TownBranchUi.marks(b);
    expect(m.owned, {'s1', 's3'});
    expect(m.levels, {'s1': 1, 's3': 3});
    expect(m.full, {'s3'}, reason: 's1 có quản lý gửi 25% về ví → đầy sau ~10,7 giờ');
    final byLot = TownBranchUi.staffByLot(b.staff);
    expect(byLot['s3']!.map((s) => s.id), ['ami', 'biscuit']);
    expect(byLot['s1']!.map((s) => s.id), ['hanh']);
    expect(byLot.containsKey('s4'), isFalse);
  });

  test('toast vắng nhà: đã bán / quản lý gửi về / giờ máy lùi', () {
    final l = lookupAppLocalizations(const Locale('vi'));
    expect(TownBranchUi.awayToasts(l, null), isEmpty);
    expect(TownBranchUi.awayToasts(l, const BranchAway()), isEmpty);
    expect(
      TownBranchUi.awayToasts(l, const BranchAway(away: Duration(minutes: 10), sold: 500)),
      isEmpty,
      reason: 'vắng < 30 phút',
    );
    final both = TownBranchUi.awayToasts(l, const BranchAway(away: Duration(hours: 5), sold: 600, deposited: 200));
    expect(both, [l.branchAwayToast(600), l.branchDepositToast(200)]);
    expect(
      TownBranchUi.awayToasts(l, const BranchAway(away: Duration(hours: 12), deposited: 200)),
      [l.branchDepositToast(200)],
      reason: 'két đã đầy từ trước: chỉ báo tiền gửi về',
    );
    expect(TownBranchUi.awayToasts(l, const BranchAway(anomaly: ClockAnomaly.behind)), [l.branchClockBehind]);
  });

  test('takeAway sau khi vắng 10 giờ → toast vắng nhà một lần', () {
    final g = game();
    g.branches.buy('s1');
    wall = wall.add(const Duration(hours: 10));
    g.branches.resume();
    final l = lookupAppLocalizations(const Locale('en'));
    final t = TownBranchUi.awayToasts(l, g.branches.takeAway());
    expect(t, [l.branchAwayToast(1200)]);
    expect(TownBranchUi.awayToasts(l, g.branches.takeAway()), isEmpty);
  });

  test('lưới biểu tượng két đầy: ≤ ngân sách tam giác, gốc ở tâm bóng, gọn trong 0,9 m', () {
    final m = TownMeshes.tillFull();
    // ignore: avoid_print
    print('tillFull: ${m.triangleCount} tris');
    expect(m.triangleCount, greaterThan(60));
    expect(m.triangleCount, lessThanOrEqualTo(TownMeshes.tillFullMaxTriangles));
    expect(m.colors.length ~/ 4, m.positions.length ~/ 3);
    expect(m.minX, greaterThan(-0.45));
    expect(m.maxX, lessThan(0.45));
    expect(m.minY, greaterThan(-0.45));
    expect(m.maxY, lessThan(0.35));
    // Xu nhô ra cả hai mặt bóng (thấy từ camera phố lẫn góc cận).
    expect(m.minZ, lessThan(-0.1));
    expect(m.maxZ, greaterThan(0.1));
  });
}
