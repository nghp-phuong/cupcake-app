import 'dart:math' as math;

import '../../core/branch/city_branches.dart';
import '../../core/branch/staff.dart';
import '../../core/branch/till_clock.dart';
import '../../core/city/city_config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/town/minimap.dart' show TownBranchMarks;
import '../shop3d/orbit_camera.dart' show degToRad;
import 'town_camera.dart';
import 'town_rules.dart';

/// Phần Dart thuần của việc ghép chi nhánh vào phố (docs/v3/city-gd4-spec.md §4, §5 — đợt G2): chỗ đặt biểu tượng két
/// đầy, lô nào hiện biểu tượng, nút A ở cửa chi nhánh, góc cận khi mở bảng chi nhánh, dữ liệu minimap, toast khi vắng
/// nhà. Không gọi Thermion — `Town3dView` / `TownScene` dùng, test được không cần engine.
abstract final class TownBranchUi {
  /// Biểu tượng két đầy trong khung lô: l = +2,5, d = 1,4, tâm bóng ở y = 2,3.
  static const double iconL = 2.5, iconD = 1.4, iconY = 2.3;

  /// Lắc nhẹ: biên độ nghiêng (rad), nhấp nhô (m), tần số (Hz).
  static const double iconRock = 0.12, iconBob = 0.05, iconHz = 0.8;

  /// Toast vắng nhà / gửi về / giờ lùi: mỗi toast hiện chừng này, nối tiếp nhau.
  static const Duration awayToastDuration = Duration(milliseconds: 4200);

  /// Điểm (l, d) trong khung lô → toạ độ lớp phố. Như `TownLayout`: lô bắc l = +x, d = −z; lô nam l = −x, d = +z.
  static (double, double) lotPoint(LotDef lot, double l, double d) {
    final north = lot.z < 0;
    return (lot.doorX + (north ? l : -l), lot.doorZ + (north ? -d : d));
  }

  /// Tâm biểu tượng két đầy của lô [lot] (toạ độ lớp phố, y = [iconY]).
  static ({double x, double y, double z}) iconAt(LotDef lot) {
    final (x, z) = lotPoint(lot, iconL, iconD);
    return (x: x, y: iconY, z: z);
  }

  /// Lô hiện biểu tượng: két đầy, trừ lô Mai đang đứng ở vùng cửa ([zone]) — đứng ở cửa thì nút A đã báo "Thu tiền".
  static Set<String> visibleIcons(Set<String> full, TownZone? zone) {
    if (zone == null || zone.kind != TownZoneKind.door || !full.contains(zone.lotId)) return full;
    return {...full}..remove(zone.lotId);
  }

  /// Nút A "Thu tiền" khi két ≥ [collectPct]% trần (hoặc đầy); dưới mức đó là "Chi nhánh" (mở bảng — trong bảng vẫn thu
  /// được). Lô cấp cao bán ~1 xu / 3–4 s nên ngưỡng 1 xu làm A gần như luôn là "Thu tiền", khó mở bảng.
  static const int collectPct = 25;

  static bool collectable(BranchView? v) =>
      v != null && v.till >= 1 && (v.full || v.till * 100 >= v.cap * collectPct);

  /// Góc cận khi mở bảng chi nhánh: nhìn mặt tiền từ phía đường, lệch [yawOffset] (lô nam: yaw ≈ π − 0,5), điểm nhìn
  /// dời sang phải màn [shift] m để mặt tiền nằm phần trái (bảng chiếm mép phải).
  static const double yawOffset = 0.5, closeDistance = 12, shift = 2.6;
  static final double closePitch = degToRad(30);

  static TownCloseUp closeUp(LotDef lot) {
    final yaw = (lot.z > 0 ? math.pi : 0.0) - yawOffset;
    final (fx, fz) = lotPoint(lot, 0.8, 2.2);
    // Véc-tơ phải của màn với camera ở yaw (TownCamera: mắt = điểm nhìn + d·(sin yaw, …, cos yaw)).
    final rx = math.cos(yaw), rz = -math.sin(yaw);
    return TownCloseUp(
      x: fx + rx * shift,
      y: 1.3,
      z: fz + rz * shift,
      yaw: yaw,
      pitch: closePitch,
      distance: closeDistance,
    );
  }

  /// Cấp mặt tiền của mọi lô chi nhánh trong [d] (0 = chưa mua).
  static Map<String, int> levels(DistrictDef d, CityBranches b) => {
        for (final lot in d.lots)
          if (lot.kind == LotKind.branch) lot.id: b.view(lot.id)?.level ?? 0,
      };

  /// Dữ liệu minimap / bản đồ lớn.
  static TownBranchMarks marks(CityBranches b) {
    final owned = b.owned;
    return TownBranchMarks(
      owned: owned.toSet(),
      full: b.fullLots,
      levels: {for (final id in owned) id: b.view(id)?.level ?? 1},
    );
  }

  /// Nhân viên theo lô (thứ tự vào làm giữ nguyên).
  static Map<String, List<StaffMember>> staffByLot(List<StaffMember> staff) {
    final out = <String, List<StaffMember>>{};
    for (final m in staff) {
      out.putIfAbsent(m.lotId, () => []).add(m);
    }
    return out;
  }

  /// Toast sau khi vắng nhà ([CityBranches.takeAway]): đã bán (khi đáng báo và két có thêm xu), quản lý gửi về, giờ
  /// máy lùi. Rỗng = không báo.
  static List<String> awayToasts(AppLocalizations l, BranchAway? a) {
    if (a == null) return const [];
    return [
      if (a.worthToast && a.sold > 0) l.branchAwayToast(a.sold),
      if (a.worthToast && a.deposited > 0) l.branchDepositToast(a.deposited),
      if (a.anomaly == ClockAnomaly.behind) l.branchClockBehind,
    ];
  }
}
