import 'dart:math' as math;

import '../shop3d_layout.dart';
import 'shop3d_nav.dart';

/// Vật tương tác nhặt / đặt / ném được và vật lý ném (V3, docs/v3/interaction-spec.md mục 2.2). Dart thuần.
///
/// Quy ước: [ShopItem.x]/[ShopItem.z] là tâm vật trên mặt phẳng xz, [ShopItem.y] là độ cao **đáy** vật (mặt đỡ phía
/// dưới); khi đang cầm thì người nối ghi toạ độ bàn tay vào đây mỗi khung. Hướng nhìn theo quy ước layout:
/// (sin yaw, cos yaw). Không có Future / I/O; [ItemBoard.update] tái dùng danh sách sự kiện, không cấp phát mỗi khung.

enum ItemKind { yarn, cakeBox, flourSack }

/// Đặc tính cố định của từng loại vật.
class ItemSpec {
  const ItemSpec({
    required this.kind,
    required this.radius,
    required this.throwable,
    required this.twoHands,
    required this.speedFactor,
    required this.canRun,
  });

  final ItemKind kind;

  /// Bán kính cầu va chạm (m).
  final double radius;
  final bool throwable;
  final bool twoHands;

  /// Hệ số nhân tốc độ đi tối đa khi đang cầm.
  final double speedFactor;
  final bool canRun;

  /// Cuộn len Ø0,14 m, cầm một tay, ném được.
  static const yarn =
      ItemSpec(kind: ItemKind.yarn, radius: 0.07, throwable: true, twoHands: false, speedFactor: 1, canRun: true);

  /// Hộp bánh: một tay, không ném (chỉ để mời bánh).
  static const cakeBox =
      ItemSpec(kind: ItemKind.cakeBox, radius: 0.13, throwable: false, twoHands: false, speedFactor: 1, canRun: true);

  /// Bao bột: hai tay, tốc độ ≤ 0,7×, không chạy, không ném.
  static const flourSack = ItemSpec(
      kind: ItemKind.flourSack, radius: 0.2, throwable: false, twoHands: true, speedFactor: 0.7, canRun: false);

  static ItemSpec of(ItemKind k) => switch (k) {
        ItemKind.yarn => yarn,
        ItemKind.cakeBox => cakeBox,
        ItemKind.flourSack => flourSack,
      };
}

enum ItemPhase {
  /// Nằm yên trên sàn hoặc trên mặt đặt.
  rest,

  /// Đang được [ShopItem.holderId] cầm.
  held,

  /// Đang bay / nảy / lăn.
  flying,

  /// Đã biến mất (tặng khách), chờ hiện lại ở chỗ ban đầu.
  hidden,
}

class ShopItem {
  ShopItem(this.id, this.kind,
      {required this.homeX,
      required this.homeY,
      required this.homeZ,
      this.homeSurface,
      this.staffSideMaxZ})
      : x = homeX,
        y = homeY,
        z = homeZ,
        surfaceId = homeSurface;

  final String id;
  final ItemKind kind;
  ItemSpec get spec => ItemSpec.of(kind);

  /// Chỗ ban đầu (đáy vật). [homeSurface]: id mặt đỡ ở đó (null = sàn / kệ).
  final double homeX, homeY, homeZ;
  final String? homeSurface;

  /// Khi còn ở chỗ ban đầu, chỉ lấy được từ phía z ≤ giá trị này (hộp bánh: phía nhân viên sau quầy).
  final double? staffSideMaxZ;

  ItemPhase phase = ItemPhase.rest;
  double x, y, z;
  double vx = 0, vy = 0, vz = 0;
  String? holderId;

  /// Id mặt đang đỡ vật khi [phase] = rest (null = nằm trên sàn).
  String? surfaceId;

  /// Người ném gần nhất (không bị chính vật này trúng).
  String? thrownBy;

  /// Đếm ngược (giây) tới khi vật về chỗ ban đầu (khi [phase] = hidden hoặc đang đặt trên mặt "tạm"). 0 = không.
  double returnIn = 0;

  int _bounces = 0;
  bool _rolling = false;
  double _rolled = 0;
  double _age = 0;
  bool _hitDone = false;

  bool get isLoose => phase == ItemPhase.rest;
  bool get visible => phase != ItemPhase.hidden;

  /// Người đứng ở (px, pz) lấy được vật này không: cách ≤ [reach] và đúng phía (nếu còn ở chỗ ban đầu).
  bool reachableFrom(double px, double pz, {double reach = 0.9}) {
    if (phase != ItemPhase.rest) return false;
    final dx = px - x, dz = pz - z;
    if (dx * dx + dz * dz > reach * reach) return false;
    final maxZ = staffSideMaxZ;
    if (maxZ != null && homeSurface != null && surfaceId == homeSurface && pz > maxZ) return false;
    return true;
  }

  void _toHome() {
    phase = ItemPhase.rest;
    x = homeX;
    y = homeY;
    z = homeZ;
    vx = vy = vz = 0;
    holderId = null;
    surfaceId = homeSurface;
    returnIn = 0;
    _bounces = 0;
    _rolling = false;
    _rolled = 0;
    _age = 0;
    _hitDone = false;
  }
}

// ---- Mặt đặt được ---------------------------------------------------------------------------------------------

/// Mặt phẳng nằm ngang đặt vật lên được (bàn đóng hộp, quầy thấp, bàn trộn, bàn khách).
class PlaceSurface {
  const PlaceSurface(this.id, this.minX, this.maxX, this.minZ, this.maxZ, this.top, {this.requires});

  final String id;
  final double minX, maxX, minZ, maxZ;

  /// Độ cao mặt.
  final double top;
  final String? requires;
}

/// Chỗ đặt vật: toạ độ (x, z) và độ cao đáy [y].
class PlaceTarget {
  const PlaceTarget(this.surface, this.x, this.y, this.z);

  final PlaceSurface surface;
  final double x, y, z;
}

abstract final class PlaceSurfaces {
  static const packingCounter = 'packingCounter';
  static const cashierCounter = 'cashierCounter';
  static const mixingIsland = 'mixingIsland';

  /// Kích thước theo [Shop3dLayout] (bàn đóng hộp x 2,4..4,9; quầy thu ngân x -0,4..2,4, z -0,97..-0,03; bàn trộn
  /// x -3..-1, z -2,5..-1,8, mặt 0,73; bàn khách đường kính 0,9, mặt 0,74).
  static const List<PlaceSurface> all = [
    PlaceSurface(packingCounter, 2.4, 4.9, -0.97, -0.03, Shop3dLayout.serviceCounterTop),
    PlaceSurface(cashierCounter, -0.4, 2.4, -0.97, -0.03, Shop3dLayout.serviceCounterTop),
    PlaceSurface(mixingIsland, -3.0, -1.0, -2.5, -1.8, 0.73),
    PlaceSurface('cafeTable1', -4.25, -3.35, 2.25, 3.15, 0.74, requires: Shop3dRequires.cafeTables),
    PlaceSurface('cafeTable2', -2.05, -1.15, 2.25, 3.15, 0.74, requires: Shop3dRequires.cafeTables),
    PlaceSurface('cafeTable3', 0.15, 1.05, 2.25, 3.15, 0.74, requires: Shop3dRequires.cafeTables),
  ];

  static PlaceSurface? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Mặt đặt được mà người đứng ở (x, z) quay mặt theo [yaw] đang "hướng vào": điểm gần nhất của mặt cách ≤
  /// [reach] và nằm trong ±[halfAngle] so với hướng nhìn. Trả chỗ đặt (điểm gần nhất, lùi vào trong mặt nửa kích
  /// thước vật [itemRadius]). null nếu không có.
  static PlaceTarget? find(double x, double z, double yaw, Set<String> owned,
      {double reach = 0.6, double halfAngle = math.pi / 3, double itemRadius = 0.1}) {
    PlaceSurface? best;
    double bestD = double.infinity, bx = 0, bz = 0;
    final fx = math.sin(yaw), fz = math.cos(yaw);
    final cosLimit = math.cos(halfAngle);
    for (final s in all) {
      if (s.requires != null && !owned.contains(s.requires)) continue;
      final px = x.clamp(s.minX, s.maxX).toDouble(), pz = z.clamp(s.minZ, s.maxZ).toDouble();
      final dx = px - x, dz = pz - z;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d > reach || d >= bestD) continue;
      if (d > 0.05 && (dx * fx + dz * fz) / d < cosLimit) continue;
      best = s;
      bestD = d;
      bx = px;
      bz = pz;
    }
    if (best == null) return null;
    final mx = math.min(itemRadius, (best.maxX - best.minX) / 2);
    final mz = math.min(itemRadius, (best.maxZ - best.minZ) / 2);
    return PlaceTarget(best, bx.clamp(best.minX + mx, best.maxX - mx).toDouble(),
        best.top, bz.clamp(best.minZ + mz, best.maxZ - mz).toDouble());
  }
}

// ---- Mục tiêu của vật bay -------------------------------------------------------------------------------------

enum TargetKind { guest, staff, mochi }

/// Hình trụ của một nhân vật cho kiểm tra ném trúng (cầu – trụ). [mochi] không bao giờ bị trúng.
class ItemTarget {
  const ItemTarget(this.id, this.kind, this.x, this.z, this.radius, this.height, {this.baseY = 0});

  final String id;
  final TargetKind kind;
  final double x, z, radius, height, baseY;
}

enum ItemEventKind { hitTarget, landed }

class ItemEvent {
  const ItemEvent(this.kind, this.itemId, {this.targetId, this.targetKind});

  final ItemEventKind kind;
  final String itemId;
  final String? targetId;
  final TargetKind? targetKind;
}

// ---- Chống phá: ném trúng một khách nhiều lần --------------------------------------------------------------------

enum ThrowHitReaction {
  /// Giật mình ("Ơ!") rồi cười.
  surprised,

  /// Đủ [ThrowHitTracker.limit] lần trong [ThrowHitTracker.window]: "Thôi mà!", phụng phịu 20 s, −1♥.
  pout,

  /// Đang phụng phịu: không phản ứng thêm.
  alreadyPouting,
}

class ThrowHitTracker {
  ThrowHitTracker({this.window = 30, this.limit = 3, this.poutSeconds = 20});

  final double window;
  final int limit;
  final double poutSeconds;

  /// Số thiện cảm bị trừ khi phụng phịu.
  static const int poutHearts = -1;

  final Map<String, List<double>> _hits = {};
  final Map<String, double> _poutUntil = {};

  /// Ghi một lần trúng [guestId] lúc [now] (giây, đồng hồ chạy liên tục) rồi trả phản ứng.
  ThrowHitReaction register(String guestId, double now) {
    if (isPouting(guestId, now)) return ThrowHitReaction.alreadyPouting;
    final list = _hits.putIfAbsent(guestId, () => <double>[]);
    list.removeWhere((t) => now - t > window);
    list.add(now);
    if (list.length >= limit) {
      list.clear();
      _poutUntil[guestId] = now + poutSeconds;
      return ThrowHitReaction.pout;
    }
    return ThrowHitReaction.surprised;
  }

  bool isPouting(String guestId, double now) => (_poutUntil[guestId] ?? -1) > now;

  void reset() {
    _hits.clear();
    _poutUntil.clear();
  }
}

// ---- Vật lý ném ---------------------------------------------------------------------------------------------------

abstract final class ItemPhysics {
  static const double gravity = 9.8;
  static const double throwAngle = math.pi / 6;
  static const double releaseHeight = 0.8;
  static const double minThrow = 1.5, maxThrow = 4.0, quickThrow = 2.5;

  /// Vật rời tay cách người chừng này (m) theo hướng nhìn.
  static const double handReach = 0.3;

  /// Bật ngang khi va prop / tường / mục tiêu.
  static const double wallBounce = 0.3;

  /// Nảy lần đầu khi chạm sàn (hệ số vận tốc đứng) và tỉ lệ vận tốc ngang còn lại; sau đó lăn.
  static const double groundBounce = 0.35, groundSlow = 0.5;
  static const double rollStartScale = 0.6, rollDecel = 3.0, maxRoll = 0.5;

  /// Bán kính "đứng được" của chỗ vật dừng (m).
  static const double restRadius = 0.2;

  static const double subStep = 1 / 120;
  static const double maxFlightSeconds = 8;

  /// Nạp lực: giữ 0,2–0,8 s ↔ 1,5–4,0 m; chạm nhanh (< 0,2 s) ↔ 2,5 m.
  static double distanceForHold(double seconds) {
    if (seconds < 0.2) return quickThrow;
    final t = ((seconds - 0.2) / 0.6).clamp(0.0, 1.0);
    return minThrow + (maxThrow - minThrow) * t;
  }

  /// Tốc độ ban đầu để vật rời tay ở [releaseHeight] rồi chạm sàn cách [distance] m (ngang) với góc [throwAngle].
  static double speedForDistance(double distance) {
    final d = distance.clamp(minThrow, maxThrow).toDouble();
    final c = math.cos(throwAngle), s = math.sin(throwAngle);
    double range(double v) {
      final vy = v * s;
      final t = (vy + math.sqrt(vy * vy + 2 * gravity * releaseHeight)) / gravity;
      return v * c * t;
    }

    var lo = 0.1, hi = 20.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (range(mid) < d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

// ---- Bảng vật ------------------------------------------------------------------------------------------------------

/// Quản lý các vật tương tác: trạng thái, nhặt / đặt / ném, mô phỏng bay, hẹn giờ về chỗ cũ.
class ItemBoard {
  ItemBoard(this.nav, {Set<String> owned = const {}}) : _owned = {...owned} {
    items = defaultItems();
  }

  final Shop3dNav nav;
  Set<String> _owned;
  late final List<ShopItem> items;

  /// Sự kiện của lần [update] gần nhất (danh sách tái dùng, xoá ở đầu mỗi lần gọi).
  final List<ItemEvent> events = <ItemEvent>[];

  static const double flourReturnSeconds = 10;
  static const double cakeBoxReturnSeconds = 8;

  set owned(Set<String> v) => _owned = {...v};

  /// Mặt đặt được mà người ở (x, z) quay mặt [yaw] đang hướng vào ([PlaceSurfaces.find] theo tập đã mở khoá).
  PlaceTarget? findPlaceTarget(double x, double z, double yaw, {double itemRadius = 0.1}) =>
      PlaceSurfaces.find(x, z, yaw, _owned, itemRadius: itemRadius);

  /// Cuộn len cạnh ổ Mochi; 2 hộp bánh trên bàn đóng hộp; bao bột ở kệ dưới.
  static List<ShopItem> defaultItems() => [
        ShopItem('yarn', ItemKind.yarn, homeX: 4.0, homeY: 0, homeZ: 1.6),
        ShopItem('cakeBox0', ItemKind.cakeBox,
            homeX: 3.55,
            homeY: Shop3dLayout.serviceCounterTop,
            homeZ: -0.5,
            homeSurface: PlaceSurfaces.packingCounter,
            staffSideMaxZ: -0.5),
        ShopItem('cakeBox1', ItemKind.cakeBox,
            homeX: 3.95,
            homeY: Shop3dLayout.serviceCounterTop,
            homeZ: -0.5,
            homeSurface: PlaceSurfaces.packingCounter,
            staffSideMaxZ: -0.5),
        ShopItem('flour', ItemKind.flourSack, homeX: -4.8, homeY: 0.44, homeZ: -1.9),
      ];

  ShopItem? byId(String id) {
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  ShopItem? heldBy(String holderId) {
    for (final it in items) {
      if (it.phase == ItemPhase.held && it.holderId == holderId) return it;
    }
    return null;
  }

  /// Đưa mọi vật về chỗ ban đầu (nút debug "reset items").
  void reset() {
    for (final it in items) {
      it._toHome();
    }
    events.clear();
  }

  /// Vật nhặt được gần nhất cho người đứng ở (x, z); null nếu không có.
  ShopItem? nearestPickable(double x, double z, {double reach = 0.9}) {
    ShopItem? best;
    var bestD = double.infinity;
    for (final it in items) {
      if (!it.reachableFrom(x, z, reach: reach)) continue;
      final d = (it.x - x) * (it.x - x) + (it.z - z) * (it.z - z);
      if (d < bestD) {
        bestD = d;
        best = it;
      }
    }
    return best;
  }

  /// Nhặt: vật đang nằm yên → [holderId] cầm. false nếu không nhặt được hoặc người đó đang cầm vật khác.
  bool pickUp(ShopItem it, String holderId) {
    if (it.phase != ItemPhase.rest || heldBy(holderId) != null) return false;
    it
      ..phase = ItemPhase.held
      ..holderId = holderId
      ..surfaceId = null
      ..returnIn = 0
      ..vx = 0
      ..vy = 0
      ..vz = 0;
    return true;
  }

  /// Đặt xuống sàn cách 0,4 m trước mặt (hướng [yaw]); nếu chỗ đó bị chặn thì dời tới điểm trống gần nhất.
  void putDown(ShopItem it, double x, double z, double yaw) {
    var px = x + math.sin(yaw) * 0.4, pz = z + math.cos(yaw) * 0.4;
    if (!nav.canStand(px, pz, ItemPhysics.restRadius)) {
      final p = nav.nearestFree(px, pz, ItemPhysics.restRadius, maxDist: 3) ??
          nav.nearestFree(x, z, ItemPhysics.restRadius, maxDist: 3);
      if (p != null) {
        px = p.x;
        pz = p.z;
      }
    }
    _setRest(it, px, nav.floorHeight(px, pz), pz, null);
  }

  /// Đặt lên mặt [target]. Bao bột đặt lên bàn trộn thì tự về kệ sau [flourReturnSeconds]; trả true khi đó (để
  /// nhân viên nói "Cảm ơn nha!").
  bool placeOn(ShopItem it, PlaceTarget target) {
    _setRest(it, target.x, target.y, target.z, target.surface.id);
    if (it.kind == ItemKind.flourSack && target.surface.id == PlaceSurfaces.mixingIsland) {
      it.returnIn = flourReturnSeconds;
      return true;
    }
    return false;
  }

  /// Tặng hộp bánh cho khách: biến mất, [seconds] giây sau hiện lại ở chỗ ban đầu.
  void consume(ShopItem it, {double seconds = cakeBoxReturnSeconds}) {
    it
      ..phase = ItemPhase.hidden
      ..holderId = null
      ..surfaceId = null
      ..returnIn = seconds;
  }

  void _setRest(ShopItem it, double x, double y, double z, String? surfaceId) {
    it
      ..phase = ItemPhase.rest
      ..holderId = null
      ..x = x
      ..y = y
      ..z = z
      ..vx = 0
      ..vy = 0
      ..vz = 0
      ..surfaceId = surfaceId
      ..returnIn = 0;
  }

  /// Ném [it] (đang cầm) từ người đứng ở (x, z) quay mặt [yaw], quãng chạm sàn [distance] m (kẹp 1,5–4,0). false nếu
  /// vật không ném được.
  bool throwItem(ShopItem it, double x, double z, double yaw, double distance) {
    if (!it.spec.throwable || it.phase != ItemPhase.held) return false;
    final holder = it.holderId;
    final v = ItemPhysics.speedForDistance(distance);
    final h = v * math.cos(ItemPhysics.throwAngle);
    final fx = math.sin(yaw), fz = math.cos(yaw);
    final r = it.spec.radius;
    final cy = nav.floorHeight(x, z) + ItemPhysics.releaseHeight;
    // Tay sát tường / quầy: lùi điểm rời tay về phía người cho tới khi không chồng lên hộp nào.
    var reach = ItemPhysics.handReach;
    while (reach > 0 && nav.sphereBlocked(x + fx * reach, cy, z + fz * reach, r)) {
      reach -= 0.1;
    }
    if (reach < 0) reach = 0;
    it
      ..phase = ItemPhase.flying
      ..thrownBy = holder
      ..holderId = null
      ..x = x + fx * reach
      ..z = z + fz * reach
      ..y = cy - r
      ..vx = fx * h
      ..vz = fz * h
      ..vy = v * math.sin(ItemPhysics.throwAngle)
      ..surfaceId = null
      .._bounces = 0
      .._rolling = false
      .._rolled = 0
      .._age = 0
      .._hitDone = false;
    return true;
  }

  /// Tiến [dt] giây: hẹn giờ về chỗ cũ + mô phỏng vật đang bay (chia bước nhỏ). [targets]: hình trụ nhân vật để kiểm
  /// tra ném trúng (loại Mochi tự động bị bỏ qua). Trả [events] (tái dùng).
  List<ItemEvent> update(double dt, List<ItemTarget> targets) {
    events.clear();
    for (final it in items) {
      if (it.returnIn > 0 && (it.phase == ItemPhase.hidden || it.phase == ItemPhase.rest)) {
        it.returnIn -= dt;
        if (it.returnIn <= 0) it._toHome();
      }
      if (it.phase != ItemPhase.flying) continue;
      var left = dt;
      while (left > 1e-9 && it.phase == ItemPhase.flying) {
        final h = math.min(left, ItemPhysics.subStep);
        left -= h;
        it._age += h;
        _sub(it, h, targets);
        if (it.phase == ItemPhase.flying && it._age > ItemPhysics.maxFlightSeconds) _finish(it);
      }
    }
    return events;
  }

  void _sub(ShopItem it, double h, List<ItemTarget> targets) {
    final r = it.spec.radius;
    if (it._rolling) {
      _roll(it, h);
      return;
    }
    it.vy -= ItemPhysics.gravity * h;
    final ox = it.x, oy = it.y + r, oz = it.z;
    var nx = ox + it.vx * h, ny = oy + it.vy * h, nz = oz + it.vz * h;

    // Trúng nhân vật (cầu – trụ), một lần cho mỗi lần ném.
    if (!it._hitDone) {
      for (final t in targets) {
        if (t.kind == TargetKind.mochi || t.id == it.thrownBy) continue;
        final dx = nx - t.x, dz = nz - t.z, rr = t.radius + r;
        if (dx * dx + dz * dz >= rr * rr) continue;
        if (ny < t.baseY - r || ny > t.baseY + t.height + r) continue;
        it._hitDone = true;
        events.add(ItemEvent(ItemEventKind.hitTarget, it.id, targetId: t.id, targetKind: t.kind));
        it.vx *= -ItemPhysics.wallBounce;
        it.vz *= -ItemPhysics.wallBounce;
        nx = ox;
        nz = oz;
        break;
      }
    }

    // Va prop / tường: bật ngang ×0,3 rồi rơi. Chạm mặt trên của prop thì coi như chạm sàn ở độ cao đó.
    var support = nav.floorHeight(nx, nz);
    final bi = nav.firstEntered(ox, oy, oz, nx, ny, nz, r);
    if (bi >= 0) {
      final b = nav.boxAt(bi);
      final gx = math.max(b.minX - ox, ox - b.maxX);
      final gz = math.max(b.minZ - oz, oz - b.maxZ);
      final gy = math.max(b.minY - oy, oy - b.maxY);
      if (gy >= gx && gy >= gz && oy > b.maxY) {
        support = math.max(support, b.maxY); // đáp xuống mặt trên prop
      } else if (gx >= gz && gx >= gy) {
        it.vx = -it.vx * ItemPhysics.wallBounce;
        it.vz *= ItemPhysics.wallBounce;
        nx = ox;
        nz = oz;
      } else if (gz >= gy) {
        it.vz = -it.vz * ItemPhysics.wallBounce;
        it.vx *= ItemPhysics.wallBounce;
        nx = ox;
        nz = oz;
      } else {
        it.vy = -it.vy * ItemPhysics.wallBounce; // đụng mặt dưới
        it.vx *= ItemPhysics.wallBounce;
        it.vz *= ItemPhysics.wallBounce;
        nx = ox;
        ny = oy;
        nz = oz;
      }
    }

    // Chạm sàn.
    if (it.vy < 0 && ny - r <= support) {
      ny = support + r;
      _groundContact(it);
    }
    it
      ..x = nx
      ..y = ny - r
      ..z = nz;
  }

  void _groundContact(ShopItem it) {
    if (it._bounces == 0 && -it.vy > 1.0) {
      it._bounces = 1;
      it.vy = -it.vy * ItemPhysics.groundBounce;
      it.vx *= ItemPhysics.groundSlow;
      it.vz *= ItemPhysics.groundSlow;
    } else {
      it._rolling = true;
      it._rolled = 0;
      it.vx *= ItemPhysics.rollStartScale;
      it.vz *= ItemPhysics.rollStartScale;
      it.vy = 0;
    }
  }

  void _roll(ShopItem it, double h) {
    final sp = math.sqrt(it.vx * it.vx + it.vz * it.vz);
    final nsp = sp - ItemPhysics.rollDecel * h;
    if (nsp <= 0.05) {
      _finish(it);
      return;
    }
    final dirX = it.vx / sp, dirZ = it.vz / sp;
    var step = nsp * h;
    var last = false;
    if (it._rolled + step >= ItemPhysics.maxRoll) {
      step = ItemPhysics.maxRoll - it._rolled;
      last = true;
    }
    final nx = it.x + dirX * step, nz = it.z + dirZ * step;
    if (!nav.canStand(nx, nz, it.spec.radius)) {
      _finish(it);
      return;
    }
    it
      ..x = nx
      ..z = nz
      ..y = nav.floorHeight(nx, nz)
      ..vx = dirX * nsp
      ..vz = dirZ * nsp;
    it._rolled += step;
    if (last) _finish(it);
  }

  /// Dừng hẳn: bảo đảm nằm trên ô đi được trong biên (đẩy ra điểm trống gần nhất), đặt sát sàn / bục.
  void _finish(ShopItem it) {
    var x = it.x, z = it.z;
    if (!nav.canStand(x, z, ItemPhysics.restRadius)) {
      final p = nav.nearestFree(x, z, ItemPhysics.restRadius, maxDist: 8);
      if (p != null) {
        x = p.x;
        z = p.z;
      } else {
        it._toHome();
        events.add(ItemEvent(ItemEventKind.landed, it.id));
        return;
      }
    }
    _setRest(it, x, nav.floorHeight(x, z), z, null);
    it
      .._rolling = false
      .._bounces = 0;
    events.add(ItemEvent(ItemEventKind.landed, it.id));
  }
}
