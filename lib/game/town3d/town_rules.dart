import 'dart:math' as math;

import '../../core/city/city_config.dart';
import '../shop3d/shop3d_layout.dart';
import 'town_layout.dart';

/// Luật tương tác ngoài phố (thành phố V3, giai đoạn 1 — docs/v3/city-gd1-spec.md): vùng quanh cửa / quầy của từng lô,
/// nút A theo vùng gần nhất, băng tên khi bước vào vùng, lần ghé đầu. Dart thuần (test được không cần engine).
///
/// - Cửa tiệm của bà (`home`) → A "Vào tiệm" (`townEnterShop`).
/// - Quầy quán ăn (`restaurant`) → A "Gọi món" (`cityOrderFood`); quầy tiệm tóc (`salon`) → A "Làm tóc"
///   (`cityGetHaircut`).
/// - Cửa các lô khác (và cửa quán ăn / tiệm tóc): chỉ hiện băng tên (+ "Sắp mở" / "Mở ở cấp N"), A không có thao tác.
///
/// Vùng có trễ ([hysteresis]): đang ở vùng nào thì giữ tới khi ra xa hơn bán kính + trễ — đi men mép vùng không làm băng
/// tên nhấp nháy.

/// Loại vùng: cửa lô (mép lô giáp vỉa hè) hoặc chỗ đứng trước quầy (quán ăn, tiệm tóc).
enum TownZoneKind { door, counter }

/// Thao tác của nút A ngoài phố.
enum TownAction {
  /// Không có thao tác (A mờ).
  none,

  /// Vào tiệm của bà (`townEnterShop`).
  enterShop,

  /// Mở bảng thực đơn quán ăn (`cityOrderFood`).
  orderFood,

  /// Mở bảng làm tóc (`cityGetHaircut`).
  getHaircut,

  /// Mở bảng lô đất ở quầy văn phòng địa ốc (`townActionRealty`).
  realty,

  /// Cửa chi nhánh đã mua: thu tiền / mở bảng chi nhánh (`townActionCollect` / `townActionBranch`, view chọn theo két).
  branch,
}

/// Một vùng tương tác: tâm ([x], [z]) bán kính [radius] (m, toạ độ lớp phố).
class TownZone {
  const TownZone(this.lot, this.kind, this.x, this.z, this.radius);

  final LotDef lot;
  final TownZoneKind kind;
  final double x, z, radius;

  String get lotId => lot.id;

  /// Khoá ổn định (`n3:counter`).
  String get id => '${lot.id}:${kind.name}';

  double distanceTo(double px, double pz) {
    final dx = px - x, dz = pz - z;
    return math.sqrt(dx * dx + dz * dz);
  }

  @override
  String toString() => 'TownZone($id)';
}

/// Dòng phụ của băng tên.
enum TownBannerNote {
  /// Không có dòng phụ (lô mở / tiệm của bà).
  none,

  /// "Sắp mở" (`townComingSoon`).
  comingSoon,

  /// "Mở ở cấp N" (`townLotLocked`, N = [TownBanner.level]).
  locked,

  /// Lô chi nhánh đã đủ cấp (`townLotUnlocked`).
  unlocked,

  /// Chi nhánh đã mua (view ghép "Chi nhánh n" + cấp / két).
  branch,
}

/// Băng tên khi bước vào vùng của một lô: tên ([nameKey], khoá AppLocalizations — `cityText`) + dòng phụ.
class TownBanner {
  const TownBanner(this.nameKey, this.note, {this.level = 0});

  final String nameKey;
  final TownBannerNote note;

  /// Cấp cần (khi [note] = [TownBannerNote.locked]).
  final int level;

  @override
  bool operator ==(Object other) =>
      other is TownBanner && other.nameKey == nameKey && other.note == note && other.level == level;

  @override
  int get hashCode => Object.hash(nameKey, note, level);

  @override
  String toString() => 'TownBanner($nameKey, ${note.name}${note == TownBannerNote.locked ? ' $level' : ''})';
}

abstract final class TownRules {
  /// Bán kính vùng cửa / vùng quầy (m) và độ trễ khi ra khỏi vùng.
  static const double doorRadius = 1.5;
  static const double counterRadius = 1.15;
  static const double hysteresis = 0.35;

  /// Đường bao chiều cao của mặt tiền chi nhánh (docs/v3/city-gd4-spec.md §0): khối ở độ sâu [d] (m, tính từ mép vỉa
  /// hè vào trong lô) cao tối đa `0,6 + 0,8·d` m — nhà lô nam không che Mai trước camera phố.
  static double branchEnvelope(double d) => 0.6 + 0.8 * d;

  /// Các vùng của quận (mỗi lô một vùng cửa; quán ăn / tiệm tóc thêm vùng quầy).
  static List<TownZone> zonesOf(TownLayout t) => [
        for (final lot in t.district.lots)
          if (t.spots[lot.id] case final s?) ...[
            TownZone(lot, TownZoneKind.door, s.door.x, s.door.z, doorRadius),
            if (s.counter case final c?) TownZone(lot, TownZoneKind.counter, c.x, c.z, counterRadius),
          ],
      ];

  /// Vùng chứa (x, z): đang ở [current] và chưa ra quá bán kính + [hysteresis] thì giữ; không thì vùng gần nhất (theo
  /// tỉ lệ khoảng cách / bán kính) mà (x, z) nằm trong bán kính. null = ngoài mọi vùng.
  static TownZone? zoneAt(List<TownZone> zones, double x, double z, {TownZone? current}) {
    if (current != null && current.distanceTo(x, z) <= current.radius + hysteresis) return current;
    TownZone? best;
    var bestK = double.infinity;
    for (final zone in zones) {
      final k = zone.distanceTo(x, z) / zone.radius;
      if (k <= 1 && k < bestK) {
        bestK = k;
        best = zone;
      }
    }
    return best;
  }

  /// Thao tác nút A trong vùng [zone]; [owned] = các lô chi nhánh đã mua (cửa lô đã mua -> [TownAction.branch]).
  static TownAction actionFor(TownZone? zone, {Set<String> owned = const {}}) {
    if (zone == null) return TownAction.none;
    return switch ((zone.lot.kind, zone.kind)) {
      (LotKind.home, TownZoneKind.door) => TownAction.enterShop,
      (LotKind.realty, TownZoneKind.counter) => TownAction.realty,
      (LotKind.branch, TownZoneKind.door) when owned.contains(zone.lotId) => TownAction.branch,
      (LotKind.restaurant, TownZoneKind.counter) => TownAction.orderFood,
      (LotKind.salon, TownZoneKind.counter) => TownAction.getHaircut,
      _ => TownAction.none,
    };
  }

  /// Thao tác nút A khi Mai đứng ở (x, z) (không có vùng đang giữ).
  static TownAction actionAt(List<TownZone> zones, double x, double z, {Set<String> owned = const {}}) =>
      actionFor(zoneAt(zones, x, z), owned: owned);

  /// Băng tên của lô [lot] với cấp Mai [level]: tiệm của bà / quán ăn / tiệm tóc / văn phòng địa ốc không có dòng phụ;
  /// công viên "Sắp mở"; lô chi nhánh đã mua ([owned]) -> [TownBannerNote.branch], chưa đủ cấp "Mở ở cấp N", đủ cấp
  /// [TownBannerNote.unlocked] (đang bán ở văn phòng địa ốc).
  static TownBanner bannerFor(LotDef lot, int level, {bool owned = false}) => switch (lot.kind) {
        LotKind.home || LotKind.restaurant || LotKind.salon || LotKind.realty =>
          TownBanner(lot.nameKey, TownBannerNote.none),
        LotKind.park => TownBanner(lot.nameKey, TownBannerNote.comingSoon),
        LotKind.branch => owned
            ? TownBanner(lot.nameKey, TownBannerNote.branch)
            : level < lot.requiresLevel
                ? TownBanner(lot.nameKey, TownBannerNote.locked, level: lot.requiresLevel)
                : TownBanner(lot.nameKey, TownBannerNote.unlocked),
      };

  /// Các lô chi nhánh vừa mở khi cấp tăng từ [from] lên [to] (`from < requiresLevel <= to`), theo cấp tăng dần.
  static List<LotDef> newlyUnlocked(DistrictDef d, int from, int to) {
    if (from >= to) return const [];
    final list = [
      for (final lot in d.lots)
        if (lot.kind == LotKind.branch && lot.requiresLevel > from && lot.requiresLevel <= to) lot,
    ];
    list.sort((a, b) => a.requiresLevel.compareTo(b.requiresLevel));
    return list;
  }

  /// Bước vào vùng của lô này tính là "ghé tiệm" (thưởng lần đầu `CityWallet.markFirstVisit`): quán ăn, tiệm tóc. Tiệm
  /// của bà là nhà (Mai xuất hiện ngay trước cửa), các lô khác chưa mở.
  static bool countsAsVisit(LotDef lot) => lot.kind == LotKind.restaurant || lot.kind == LotKind.salon;

  // ---- Trong tiệm của bà (toạ độ nội thất `Shop3dLayout`) ------------------------------------------------------

  /// Khe cửa trong tiệm (`Shop3dNav.doorMinX..doorMaxX`, nới mỗi bên ~15 cm) và mép trong của vùng "ở cửa" (thảm cửa,
  /// cách mặt trong tường trước 0,65 m — khách ra vào hay đứng chắn khe cửa): Mai đứng
  /// ở đây thì nút A = "Ra phố" (`townExitShop`).
  static const double shopDoorMinX = 2.9, shopDoorMaxX = 4.3, shopDoorMinZ = 3.35;

  /// Bước quá mép này (ra vỉa hè giả của cảnh tiệm, z ≥ 4,45) = ra phố luôn.
  static const double shopStreetZ = 4.6;

  /// Chỗ Mai xuất hiện khi vào tiệm (trong phòng, ngay sau khe cửa, ngoài vùng "ở cửa"), quay vào trong.
  static const double shopEntryX = 3.6, shopEntryZ = 2.95, shopEntryYaw = math.pi;

  /// Mai (toạ độ nội thất) đang đứng ở khe cửa.
  static bool atShopDoor(double x, double z) =>
      x >= shopDoorMinX && x <= shopDoorMaxX && z >= shopDoorMinZ && z < shopStreetZ;

  /// Mai đã bước ra vỉa hè của cảnh tiệm.
  static bool outsideShop(double x, double z) => z >= shopStreetZ;

  // ---- Quầy trong tiệm của bà: mở ca bán (docs/v3/city-gd3-spec.md §5) ------------------------------------------

  /// Vùng quầy: phía khách (z ∈ [0,1; 1,2]) và phía bếp (z ∈ [−1,9; −1,0]), cùng khoảng x ∈ [−2,2; 2,0].
  static const double shopCounterMinX = -2.2, shopCounterMaxX = 2.0;
  static const double shopCounterCustomerMinZ = 0.1, shopCounterCustomerMaxZ = 1.2;
  static const double shopCounterKitchenMinZ = -1.9, shopCounterKitchenMaxZ = -1.0;

  /// Mai (toạ độ nội thất) đang đứng trong vùng quầy: nút A = "Mở ca" (`shiftOpen`). Cửa được ưu tiên hơn quầy: đang
  /// ở khe cửa ([atShopDoor]) thì không tính là ở quầy.
  static bool atShopCounter(double x, double z) {
    if (atShopDoor(x, z)) return false;
    if (x < shopCounterMinX || x > shopCounterMaxX) return false;
    return (z >= shopCounterCustomerMinZ && z <= shopCounterCustomerMaxZ) ||
        (z >= shopCounterKitchenMinZ && z <= shopCounterKitchenMaxZ);
  }

  /// Chỗ đứng trong ca bán: Mai ở sau quầy thu ngân (`staffCashier`, quay ra phòng), Nora ở tủ kính (`staffCase`).
  static final double shiftMaiX = Shop3dLayout.staffCashier.x,
      shiftMaiZ = Shop3dLayout.staffCashier.z,
      shiftMaiYaw = Shop3dLayout.staffCashier.facingYaw;
  static final double shiftNoraX = Shop3dLayout.staffCase.x,
      shiftNoraZ = Shop3dLayout.staffCase.z,
      shiftNoraYaw = Shop3dLayout.staffCase.facingYaw;
}
