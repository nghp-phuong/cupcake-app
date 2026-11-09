import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/town3d/town_branch_cast.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';

/// Nhân viên đứng ở sân chi nhánh (town_branch_cast.dart). Dart thuần.
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final town = TownLayout.forDistrict(district);

  StaffMember m(String id, String lot, int since) => StaffMember(id: id, lotId: lot, since: since);

  test('chibiOf phủ đủ StaffRoster', () {
    expect({for (final d in StaffRoster.all) d.id}, TownBranchCast.chibiOf.keys.toSet());
    expect(TownBranchCast.lodRange, 12.0);
    expect(TownBranchCast.maxVisible, 2);
  });

  test('lô không có nhân viên thì không có chibi', () {
    expect(TownBranchCast.plan(town, const {}, -6, 0), isEmpty);
    expect(TownBranchCast.plan(town, {'s1': const []}, -6, 0), isEmpty);
    expect(TownBranchCast.plan(town, {'zz': [m('ami', 'zz', 1)]}, -6, 0), isEmpty);
  });

  test('ưu tiên quản lý > thợ bánh > phục vụ, rồi người vào làm trước', () {
    String pick(List<StaffMember> list) =>
        TownBranchCast.plan(town, {'s1': list}, -6, 0).single.staffId;
    expect(pick([m('biscuit', 's1', 1), m('ami', 's1', 5)]), 'ami');
    expect(pick([m('ami', 's1', 1), m('hanh', 's1', 9)]), 'hanh');
    expect(pick([m('cocoa', 's1', 7), m('ami', 's1', 3)]), 'ami');
    expect(pick([m('cocoa', 's1', 3), m('ami', 's1', 7)]), 'cocoa');
    expect(pick([m('nutmeg', 's1', 3), m('biscuit', 's1', 2)]), 'biscuit');
    final a = TownBranchCast.plan(town, {'s1': [m('hanh', 's1', 1)]}, -6, 0).single;
    expect(a.chibiId, 'staff_hanh');
    expect(a.lotId, 's1');
  });

  test('chỗ đứng: l -1,6, d 1,0 so với lô, quay ra đường', () {
    // s1 (lô nam, cửa -18; 5,5): l = -x, d = +z.
    final a = TownBranchCast.plan(town, {'s1': [m('ami', 's1', 1)]}, -18, 0).single;
    expect(a.at.x, closeTo(-18 + 1.6, 1e-9));
    expect(a.at.z, closeTo(5.5 + 1.0, 1e-9));
    expect(a.at.yaw, closeTo(3.141592653589793, 1e-9));
  });

  test('khoảng LOD: |Mai.x - lô.x| <= 12 và Mai.z >= -1; lô đang xem cận luôn có', () {
    final staff = {'s1': [m('ami', 's1', 1)]}; // s1.x = -18
    int n(double x, double z, {String? focus}) =>
        TownBranchCast.plan(town, staff, x, z, focusLot: focus).length;
    expect(n(-18, 0), 1);
    expect(n(-6, 0), 1); // đúng 12 m
    expect(n(-5.9, 0), 0);
    expect(n(-18, -1), 1);
    expect(n(-18, -1.1), 0); // Mai ở vỉa hè bắc
    expect(n(20, -4, focus: 's1'), 1);
    expect(n(20, -4, focus: 's3'), 0);
  });

  test('tối đa 2 chibi; lô xem cận trước, rồi lô gần Mai hơn', () {
    final staff = {
      's1': [m('ami', 's1', 1)],
      's3': [m('hanh', 's3', 1)],
      's4': [m('cocoa', 's4', 1)],
    };
    // s1.x = -18, s3.x = 6, s4.x = 18. Mai x = 10: s3 (4 m), s4 (8 m); s1 (28 m) ngoài LOD.
    expect(TownBranchCast.plan(town, staff, 10, 0).map((e) => e.lotId), ['s3', 's4']);
    // Mai x = 12: s3 và s4 cùng 6 m -> theo id.
    expect(TownBranchCast.plan(town, staff, 12, 0).map((e) => e.lotId), ['s3', 's4']);
    // Mai x = 14: s4 gần hơn.
    expect(TownBranchCast.plan(town, staff, 14, 0).map((e) => e.lotId), ['s4', 's3']);
    // Lô xem cận đứng đầu dù xa; vẫn tối đa 2.
    final f = TownBranchCast.plan(town, staff, 10, 0, focusLot: 's1');
    expect(f.map((e) => e.lotId), ['s1', 's3']);
    expect(f.length, TownBranchCast.maxVisible);
  });
}
