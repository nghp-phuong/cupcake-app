import '../../core/branch/staff.dart';
import '../../core/city/city_config.dart';
import 'town_layout.dart';

/// Một nhân viên đứng ở sân chi nhánh (docs/v3/city-gd4-spec.md §5): [at] là toạ độ lớp phố + hướng nhìn (ra đường).
class TownBranchActor {
  const TownBranchActor({required this.lotId, required this.staffId, required this.chibiId, required this.at});

  final String lotId, staffId, chibiId;
  final TownPoint at;

  @override
  String toString() => 'TownBranchActor($lotId, $staffId, $chibiId)';
}

/// Chọn nhân viên nào đứng ở sân chi nhánh nào (Dart thuần, không gọi Thermion): mỗi lô tối đa 1 chibi, ưu tiên
/// quản lý > thợ bánh > phục vụ rồi tới người vào làm trước; chỉ lô gần Mai (hoặc lô đang xem cận) mới có; tối đa
/// [maxVisible] chibi cùng lúc.
abstract final class TownBranchCast {
  /// Chibi của từng nhân viên (`StaffRoster`).
  static const Map<String, String> chibiOf = {
    'biscuit': 'regular_01',
    'nutmeg': 'regular_04',
    'ami': 'staff_ami',
    'hanh': 'staff_hanh',
    'cocoa': 'regular_11',
    'maple': 'regular_07',
  };

  /// Chỉ đưa vào cảnh khi |Mai.x − lô.x| ≤ [lodRange] m và Mai.z ≥ [lodMinZ] (Mai ở giữa đường / phía bắc).
  static const double lodRange = 12.0;
  static const double lodMinZ = -1.0;
  static const int maxVisible = 2;

  /// Chỗ đứng trong khung lô: l = −1,6, d = 1,0.
  static const double standL = -1.6, standD = 1.0;

  static int _rank(StaffRole r) => switch (r) {
        StaffRole.manager => 0,
        StaffRole.baker => 1,
        StaffRole.server => 2,
      };

  /// Danh sách chibi cần đứng ở sân, theo thứ tự ưu tiên: lô [focusLot] trước, rồi lô gần Mai hơn.
  static List<TownBranchActor> plan(
    TownLayout t,
    Map<String, List<StaffMember>> staffByLot,
    double maiX,
    double maiZ, {
    String? focusLot,
  }) {
    final picks = <(LotDef, StaffMember)>[];
    for (final lot in t.district.lots) {
      if (lot.baseIncome <= 0) continue;
      StaffMember? best;
      for (final m in staffByLot[lot.id] ?? const <StaffMember>[]) {
        final def = StaffRoster.byId(m.id);
        if (def == null || !chibiOf.containsKey(m.id)) continue;
        if (best == null) {
          best = m;
          continue;
        }
        final c = _rank(def.role).compareTo(_rank(StaffRoster.byId(best.id)!.role));
        if (c < 0 || (c == 0 && m.since < best.since)) best = m;
      }
      if (best == null) continue;
      final near = (maiX - lot.x).abs() <= lodRange && maiZ >= lodMinZ;
      if (near || lot.id == focusLot) picks.add((lot, best));
    }
    picks.sort((a, b) {
      final fa = a.$1.id == focusLot ? 0 : 1, fb = b.$1.id == focusLot ? 0 : 1;
      if (fa != fb) return fa.compareTo(fb);
      final c = (maiX - a.$1.x).abs().compareTo((maiX - b.$1.x).abs());
      return c != 0 ? c : a.$1.id.compareTo(b.$1.id);
    });
    return [
      for (final (lot, m) in picks.take(maxVisible))
        TownBranchActor(lotId: lot.id, staffId: m.id, chibiId: chibiOf[m.id]!, at: _standAt(lot)),
    ];
  }

  /// Khung lô như `TownLayout` (`_F`): lô bắc l = +x, d = −z, lô nam l = −x, d = +z; nhân viên quay ra đường.
  static TownPoint _standAt(LotDef lot) {
    final north = lot.z < 0;
    final sx = north ? 1.0 : -1.0, sz = north ? -1.0 : 1.0;
    return TownPoint(lot.doorX + sx * standL, lot.doorZ + sz * standD, north ? 0.0 : 3.141592653589793);
  }
}
