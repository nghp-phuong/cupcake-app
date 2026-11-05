import 'dart:math' as math;

import 'shop3d_math.dart';

/// Bố cục tiệm 3D bằng hằng số — Dart thuần, không phụ thuộc engine. Người dựng cảnh (Thermion) đọc danh sách
/// [Shop3dProp] / [Shop3dPart] rồi tạo mesh low-poly.
///
/// Quy ước: đơn vị mét, trục Y hướng lên, sàn y = 0. Phòng 10 × 3,2 × 8: x ∈ [-5, 5], z ∈ [-4, 4].
/// Camera mặc định đứng ở +z nhìn về -z nên +x là bên phải màn hình:
/// - **Bếp** ở phía sau (z < -1,2): 2 lò, bàn trộn (đảo giữa), bồn/bàn chuẩn bị, tủ lạnh, kệ nguyên liệu.
/// - **Quầy dịch vụ** chạy dọc trục x tại z ≈ -0,5: tủ kính bánh (trái), quầy thu ngân (giữa), bàn đóng hộp (phải).
///   Khách đứng ở phía +z, nhân viên ở phía -z; lối cho nhân viên qua quầy ở x ∈ [-4,9; -2,8].
/// - **Khu ngồi** phía trước-trái (z ≈ 2,7) sát cửa sổ; **cửa ra vào** ở tường trước, x ≈ 3,6.
///
/// Góc quay [Shop3dSpot.facingYaw] dùng cùng quy ước với camera: hướng nhìn = (sin yaw, 0, cos yaw), yaw 0 nhìn +z.
/// Kích thước thật: bàn ~0,75 m, ghế ~0,9 m. Nhân vật chibi (03/11): Mai ~1,3 m, thú 0,55–0,85 × Mai → quầy dịch vụ hạ
/// xuống 0,72 m (bậc thu ngân giữ 0,95 m quanh máy tính tiền), bục gỗ 0,16 m chỗ khách đứng trước quầy + bục 0,18 m
/// sau quầy thu ngân cho nhân viên, bàn trộn 0,73 m + bục 0,16 m phía sau bàn — mặt thú không bị mặt quầy / bàn che
/// (docs/v3/character-cute-review.md, mục B).

/// Id mục mở khoá của v2 (`lib/core/unlock/unlock_config.dart` → `UnlockIds`) dùng làm cờ [Shop3dProp.requires].
/// Khớp `ShopSetup.owned`. Chép lại ở đây để file này không phải import `lib/core`.
abstract final class Shop3dRequires {
  static const caseStand = 'case_stand';
  static const oven2 = 'oven_2';
  static const cafeTables = 'cafe_tables';
  static const kitchen2 = 'kitchen_2';

  static const all = {caseStand, oven2, cafeTables, kitchen2};
}

/// Khoá màu: bảng màu CLAUDE.md + vài màu gỗ / sàn ấm. [argb] dạng 0xAARRGGBB (độ trong suốt riêng ở [Shop3dPart.alpha]).
enum Shop3dColor {
  cream(0xFFFFF4E6),
  strawberry(0xFFF49AB0),
  mint(0xFFA8DCC8),
  butter(0xFFFFD27A),
  caramel(0xFFB9805A),
  chocolate(0xFF5A3E36),
  correct(0xFF7BC47F),
  woodLight(0xFFE2B98C),
  woodDark(0xFF8A5A3C),
  floorWood(0xFFE9C9A0),
  floorTile(0xFFD3ECE0),
  rug(0xFFF8CFD9),
  wall(0xFFFBE9D0),
  // Tường trước sáng hơn một tông: mặt trong quay lưng nắng, chỉ nhận ánh sáng môi trường (P3).
  wallFront(0xFFFFF4E4),
  steel(0xFFCDD0D2),
  glass(0xFFCFEFF2),

  // Bài trí "tiệm bánh bên biển của bà" (04/11, decor-proposal.md): tông nhạt của bảng màu cho khăn bàn / ghế / lọ, sàn
  // ván hai tông + khe ván, bánh mì.
  pinkLight(0xFFFAD3DC),
  mintLight(0xFFCFEEE1),
  butterLight(0xFFFFEAB8),
  floorPlank(0xFFEFD4AF),
  floorGap(0xFFCDA27A),
  floorEdge(0xFFA9774F),
  bread(0xFFE2A865),

  // Tranh cảnh biển sau cửa sổ ([backdrop]: không chịu ánh sáng — mặt trong tường trước nằm trong bóng, tranh vẫn sáng
  // như trời thật): trời xanh thiên thanh nhạt → đào hồng ở chân trời, biển bạc hà hai tông, mây, mặt trời, thuyền buồm.
  sky(0xFFCDEBF5),
  peach(0xFFFFE8D6),
  seaLight(0xFFB4E4D6),
  sea(0xFF86D0C4),
  cloud(0xFFFFFDF8),
  sun(0xFFFFD98A),
  hull(0xFFC98B5E),

  // Đợt P3 (04/11): cây xanh nhiều tông (đậm / nhạt, cùng `correct` + `mint`), vỉa hè lát gạch hai tông.
  leafDeep(0xFF4F9A5E),
  leafLight(0xFFA5DE96),
  pavingLight(0xFFF9F0E1);

  const Shop3dColor(this.argb);
  final int argb;

  /// Màu của tranh cảnh ngoài cửa sổ — material không chịu ánh sáng (`Shop3dSurface.backdrop`).
  static const Set<Shop3dColor> backdrop = {sky, peach, seaLight, sea, cloud, sun, hull};
}

enum Shop3dShape {
  /// size = (rộng x, cao y, sâu z).
  box,

  /// Trục dọc theo y; size.x = size.z = đường kính, size.y = chiều cao.
  cylinder,

  /// Cầu; ba kích thước đều bằng đường kính.
  sphere,

  /// Lăng trụ hình thang: mặt cắt trong mặt phẳng xy cục bộ (rộng size.x ở đáy × [Shop3dPart.bottomScale], ở đỉnh ×
  /// [Shop3dPart.topScale], cao size.y), đùn theo z cục bộ dày size.z, xoay [Shop3dPart.rotY]. Đỉnh 0 = tam giác đỉnh
  /// nhọn lên (buồm, mái dốc), đáy 0 = tam giác nhọn xuống (cờ đuôi nheo).
  prism,

  /// Diềm sóng: nửa hình elip treo dưới cạnh trên phẳng (rộng size.x, sâu size.y), đùn theo z cục bộ dày size.z.
  scallop,
}

/// Một khối low-poly. [cx],[cy],[cz] là **tâm** khối; [sx],[sy],[sz] là kích thước (xem [Shop3dShape]); [rotY] xoay quanh
/// trục y (rad). [alpha] < 1 = trong suốt (kính). Các hàm tạo nhận **đáy** `y0` (cho dễ đặt vật lên sàn / mặt bàn).
/// [topScale] / [bottomScale] (0..1): thu nhỏ đỉnh / đáy của trụ (nón cụt) và lăng trụ — [sx] luôn là cỡ lớn nhất nên hộp
/// bao (chạm chọn, lối đi, kiểm tra chồng lấn) vẫn đúng.
class Shop3dPart {
  const Shop3dPart.box(
    this.color,
    this.cx,
    double y0,
    this.cz,
    double w,
    double h,
    double d, {
    this.rotY = 0,
    this.alpha = 1,
  })  : shape = Shop3dShape.box,
        cy = y0 + h / 2,
        sx = w,
        sy = h,
        sz = d,
        topScale = 1,
        bottomScale = 1;

  const Shop3dPart.cyl(this.color, this.cx, double y0, this.cz, double diameter, double h, {this.alpha = 1})
      : shape = Shop3dShape.cylinder,
        rotY = 0,
        cy = y0 + h / 2,
        sx = diameter,
        sy = h,
        sz = diameter,
        topScale = 1,
        bottomScale = 1;

  /// Nón cụt trục y: đường kính đáy [bottomDiameter], đỉnh [topDiameter] (cái nào lớn hơn là [sx]).
  const Shop3dPart.cone(this.color, this.cx, double y0, this.cz, double bottomDiameter, double topDiameter, double h,
      {this.alpha = 1})
      : shape = Shop3dShape.cylinder,
        rotY = 0,
        cy = y0 + h / 2,
        sx = bottomDiameter > topDiameter ? bottomDiameter : topDiameter,
        sy = h,
        sz = bottomDiameter > topDiameter ? bottomDiameter : topDiameter,
        topScale = bottomDiameter > topDiameter ? topDiameter / bottomDiameter : 1,
        bottomScale = bottomDiameter > topDiameter ? 1 : bottomDiameter / topDiameter;

  const Shop3dPart.ball(this.color, this.cx, double y0, this.cz, double diameter, {this.alpha = 1})
      : shape = Shop3dShape.sphere,
        rotY = 0,
        cy = y0 + diameter / 2,
        sx = diameter,
        sy = diameter,
        sz = diameter,
        topScale = 1,
        bottomScale = 1;

  /// Lăng trụ hình thang (xem [Shop3dShape.prism]): rộng [w] (cạnh lớn nhất), cao [h], dày [d].
  const Shop3dPart.prism(this.color, this.cx, double y0, this.cz, double w, double h, double d,
      {this.rotY = 0, this.topScale = 1, this.bottomScale = 1, this.alpha = 1})
      : shape = Shop3dShape.prism,
        cy = y0 + h / 2,
        sx = w,
        sy = h,
        sz = d;

  /// Diềm sóng (xem [Shop3dShape.scallop]): cạnh trên phẳng ở `y0 + h`, đáy cung ở `y0`.
  const Shop3dPart.scallop(this.color, this.cx, double y0, this.cz, double w, double h, double d,
      {this.rotY = 0, this.alpha = 1})
      : shape = Shop3dShape.scallop,
        cy = y0 + h / 2,
        sx = w,
        sy = h,
        sz = d,
        topScale = 1,
        bottomScale = 1;

  final Shop3dShape shape;
  final Shop3dColor color;
  final double cx, cy, cz;
  final double sx, sy, sz;
  final double rotY;
  final double alpha;
  final double topScale, bottomScale;

  bool get _boxLike => shape == Shop3dShape.box || shape == Shop3dShape.prism || shape == Shop3dShape.scallop;

  /// Nửa kích thước của AABB bao quanh theo x / z (có tính [rotY] cho hộp / lăng trụ).
  double get halfX => _boxLike ? (math.cos(rotY).abs() * sx + math.sin(rotY).abs() * sz) / 2 : sx / 2;
  double get halfZ => _boxLike ? (math.sin(rotY).abs() * sx + math.cos(rotY).abs() * sz) / 2 : sz / 2;

  double get minX => cx - halfX;
  double get maxX => cx + halfX;
  double get minY => cy - sy / 2;
  double get maxY => cy + sy / 2;
  double get minZ => cz - halfZ;
  double get maxZ => cz + halfZ;
}

enum Shop3dZone { kitchen, service, seating, entrance, decor }

/// Một vật thể = nhóm khối. [requires] null = luôn có; ngược lại chỉ hiện khi `ShopSetup.owned` chứa id đó.
/// [flat] = lớp phủ sàn (thảm, gạch) — không chiếm chỗ, bỏ qua khi kiểm tra chồng lấn / lối đi.
/// [pickable] = false: chạm không chọn được (đồ trang trí nhỏ) → cảnh gộp lưới của nó chung với mọi vật không chạm được
/// cùng [requires] (rẻ nhất: không thêm entity / draw call — `shop3d_batches.dart`). Vật [flat] cũng không chạm được.
class Shop3dProp {
  const Shop3dProp(this.id, this.zone, this.parts, {this.requires, this.flat = false, this.pickable = true});

  final String id;
  final Shop3dZone zone;
  final List<Shop3dPart> parts;
  final String? requires;
  final bool flat;
  final bool pickable;

  bool enabledFor(Set<String> owned) => requires == null || owned.contains(requires);
}

/// Điểm đứng / ngồi / đi qua. [x],[z] trên mặt sàn; [y] = 0 khi đứng, = độ cao mặt ngồi khi ngồi.
/// [facingYaw] theo quy ước ở đầu file. [requires] như [Shop3dProp.requires].
class Shop3dSpot {
  const Shop3dSpot(this.id, this.x, this.z, this.facingYaw, {this.y = 0, this.requires});

  final String id;
  final double x, y, z;
  final double facingYaw;
  final String? requires;

  Vec3 toVec3() => Vec3(x, y, z);
}

abstract final class Shop3dLayout {
  static const double wallThickness = 0.2;

  /// Mặt trong của phòng.
  static const RoomBox room = RoomBox(minX: -5, maxX: 5, minY: 0, maxY: 3.2, minZ: -4, maxZ: 4);

  /// Phòng + độ dày tường (cho kiểm tra biên của khối tường).
  static const RoomBox roomWithWalls = RoomBox(minX: -5.3, maxX: 5.3, minY: -0.2, maxY: 3.4, minZ: -4.3, maxZ: 4.3);

  /// Điểm camera nhìn vào (giữa tiệm, ngang tầm quầy). Tạo bản mới mỗi lần vì [Vec3] mutable.
  static Vec3 cameraTarget() => Vec3(0, 0.9, 0);

  /// Chiều cao người đứng, dùng khi đặt nhân vật billboard.
  static const double personHeight = 1.6;

  // ---- Điểm cho khách / nhân viên --------------------------------------------------------------------------

  /// Điểm khách xuất hiện ngoài cửa (ngoài phòng, z > 4).
  static const Shop3dSpot doorOutside = Shop3dSpot('doorOutside', 3.6, 5.4, math.pi);

  /// Ngay trong cửa. Từ đây khách đi tới cuối hàng chờ.
  static const Shop3dSpot entrance = Shop3dSpot('entrance', 3.6, 3.75, math.pi);

  /// Hàng chờ 5 chỗ: index 0 sát quầy (chờ tới lượt), index 4 gần cửa nhất. Mọi khách nhìn về phía quầy.
  /// (v2: `cafe_tables` +2 chỗ hàng chờ — ở 3D phần này được thể hiện bằng [seats], khách ngồi chờ.)
  static const List<Shop3dSpot> queue = [
    Shop3dSpot('queue0', 2.6, 0.45, math.pi),
    Shop3dSpot('queue1', 3.5, 1.15, math.pi),
    Shop3dSpot('queue2', 3.5, 1.85, math.pi),
    Shop3dSpot('queue3', 3.5, 2.55, math.pi),
    Shop3dSpot('queue4', 3.5, 3.25, math.pi),
  ];

  /// 3 chỗ đứng tại quầy (trước tủ kính và quầy thu ngân), nhìn vào quầy (-z).
  static const List<Shop3dSpot> counterSpots = [
    Shop3dSpot('counter0', -1.6, 0.45, math.pi),
    Shop3dSpot('counter1', 0.2, 0.45, math.pi),
    Shop3dSpot('counter2', 1.4, 0.45, math.pi),
  ];

  /// 6 chỗ ngồi (3 bàn × 2 ghế); y = độ cao mặt ngồi. Chỉ dùng khi đã có `cafe_tables`.
  static const List<Shop3dSpot> seats = [
    Shop3dSpot('seat0', -4.58, 2.7, math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
    Shop3dSpot('seat1', -3.02, 2.7, -math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
    Shop3dSpot('seat2', -2.38, 2.7, math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
    Shop3dSpot('seat3', -0.82, 2.7, -math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
    Shop3dSpot('seat4', -0.18, 2.7, math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
    Shop3dSpot('seat5', 1.38, 2.7, -math.pi / 2, y: 0.5, requires: Shop3dRequires.cafeTables),
  ];

  /// Điểm cho nhân viên (đứng làm việc). Nhìn về phía việc đang làm.
  static const Shop3dSpot staffCashier = Shop3dSpot('staffCashier', 1.0, -1.45, 0);
  static const Shop3dSpot staffCase = Shop3dSpot('staffCase', -1.6, -1.45, 0);
  static const Shop3dSpot staffMixer = Shop3dSpot('staffMixer', -2.0, -1.45, math.pi);
  static const Shop3dSpot staffOven1 = Shop3dSpot('staffOven1', -4.0, -2.75, math.pi);
  static const Shop3dSpot staffOven2 = Shop3dSpot('staffOven2', -2.7, -2.8, math.pi, requires: Shop3dRequires.oven2);
  static const Shop3dSpot staffPacker = Shop3dSpot('staffPacker', 3.65, -1.45, 0);
  static const Shop3dSpot staffWaiter = Shop3dSpot('staffWaiter', -3.6, 0.8, 0, requires: Shop3dRequires.cafeTables);

  /// Chỗ nhân viên đi qua quầy giữa bếp và phòng khách (khe hở x ∈ [-4,9; -2,8]).
  static const Shop3dSpot staffPassage = Shop3dSpot('staffPassage', -3.7, -0.5, 0);

  static const List<Shop3dSpot> staffSpots = [
    staffCashier,
    staffCase,
    staffMixer,
    staffOven1,
    staffOven2,
    staffPacker,
    staffWaiter,
    staffPassage,
  ];

  /// Mọi điểm đứng trên sàn trong phòng (để kiểm tra / debug).
  static List<Shop3dSpot> get floorSpots => [entrance, ...queue, ...counterSpots, ...staffSpots];

  // ---- Bục đứng -----------------------------------------------------------------------------------------------

  /// Mặt quầy dịch vụ phía khách (thấp) và bậc thu ngân quanh máy tính tiền (cao).
  static const double serviceCounterTop = 0.72;
  static const double cashierStepTop = 0.95;

  /// Bục gỗ trước quầy dịch vụ (khách đứng gọi món, cao [customerStepHeight]) và bục sau quầy thu ngân (nhân viên,
  /// [staffStepHeight]). Là lớp phủ sàn (`flat`, không chiếm chỗ); nhân vật đứng trên đó được nâng theo
  /// [floorHeightAt].
  static const double customerStepHeight = 0.16;
  static const double staffStepHeight = 0.18;
  static const Shop3dPart customerStep =
      Shop3dPart.box(Shop3dColor.woodLight, -0.25, 0, 0.385, 5.3, customerStepHeight, 0.83);
  static const Shop3dPart staffStep = Shop3dPart.box(Shop3dColor.woodLight, 1.15, 0, -1.36, 2.3, staffStepHeight, 0.78);

  /// Bục sau bàn trộn (phía lò) cho Mai / Bao nhào bột quay mặt ra phòng: mặt bàn không che mặt kể cả khi nhìn thấp.
  static const double kitchenStepHeight = 0.16;
  static const Shop3dPart kitchenStep =
      Shop3dPart.box(Shop3dColor.woodLight, -1.95, 0, -2.8, 2.0, kitchenStepHeight, 0.5);
  static const List<Shop3dPart> steps = [customerStep, staffStep, kitchenStep];

  /// Độ cao mặt đứng tại (x, z): mặt bục nếu nằm trên bục, ngược lại 0 (sàn).
  static double floorHeightAt(double x, double z) {
    var h = 0.0;
    for (final p in steps) {
      if (x >= p.minX && x <= p.maxX && z >= p.minZ && z <= p.maxZ && p.maxY > h) h = p.maxY;
    }
    return h;
  }

  // ---- Điểm trung gian cho nhân vật đi lại (tránh xuyên quầy / bàn / ghế) ----------------------------------

  /// Hàng ngang trước khu ngồi (phía quầy, z = 1,75): khách đi dọc hàng này tới đúng cột ghế rồi mới tiến vào.
  static const double seatAisleZ = 1.75;

  /// Đứng cạnh ghế (phía quầy) trước khi nhảy lên ghế / sau khi nhảy xuống.
  static const double seatApproachZ = 2.2;

  /// Lối ra: khúc quanh giữa khu ngồi và hàng chờ, rồi ra cửa ở làn x = 3,4 (lệch làn vào x = 3,6).
  static const Shop3dSpot exitAisle = Shop3dSpot('exitAisle', 2.7, 1.95, 0);
  static const Shop3dSpot exitInside = Shop3dSpot('exitInside', 3.4, 3.75, 0);
  static const Shop3dSpot exitOutside = Shop3dSpot('exitOutside', 3.4, 5.4, 0);

  /// Phía bên kia bàn trộn (sát lò), ở đầu bàn còn trống (máy trộn / bao bột không che mặt), quay mặt ra phòng —
  /// chỗ chủ tiệm nhào bột.
  static const Shop3dSpot staffMixerFar = Shop3dSpot('staffMixerFar', -1.3, -2.82, 0);

  /// Trước khay cupcake trên bàn chuẩn bị (quay vào tường bếp).
  static const Shop3dSpot staffPrepTray = Shop3dSpot('staffPrepTray', 0.4, -2.86, math.pi);

  /// Sau quầy thu ngân, lệch khỏi máy tính tiền (đứng ngay sau máy thì máy che mặt).
  static const Shop3dSpot staffCashierSide = Shop3dSpot('staffCashierSide', 1.5, -1.38, 0);

  /// Các điểm trung gian đứng trên sàn trong phòng (để kiểm tra).
  static List<Shop3dSpot> get walkSpots => [exitAisle, exitInside, staffMixerFar, staffPrepTray, staffCashierSide];

  // ---- Ô tủ kính -----------------------------------------------------------------------------------------

  /// Tâm tủ kính.
  static const double caseCenterX = -1.6;
  static const double caseCenterZ = -0.5;

  /// 12 ô bánh trong tủ (6 cột × 2 kệ), toạ độ thế giới của **mặt kệ** (đặt bánh ở y này). 0..5 kệ dưới trái → phải,
  /// 6..11 kệ trên. Dùng N ô đầu theo `LevelData.caseSlots + caseSlotsBonus` (v2: 3–4, +1 khi `case_stand`; tối đa 12).
  static const int caseSlotCount = 12;
  static const double caseShelfLowerY = 0.83;
  static const double caseShelfUpperY = 1.11;

  static List<Vec3> caseSlotPositions() {
    const dx = 0.36;
    return [
      for (final y in const [caseShelfLowerY, caseShelfUpperY])
        for (var i = 0; i < 6; i++) Vec3(caseCenterX + (i - 2.5) * dx, y, caseCenterZ),
    ];
  }

  // ---- Vật thể ------------------------------------------------------------------------------------------

  /// Sàn ván gỗ + caro bếp + thảm khu ngồi + thảm cửa + bục. Là các vật thể `flat`.
  static final List<Shop3dProp> floorProps = [
    Shop3dProp('floor', Shop3dZone.decor, _floorParts(), flat: true),
    Shop3dProp('kitchenTiles', Shop3dZone.kitchen, _kitchenTileParts(), flat: true),
    // thảm lùi khỏi dải viền mép sàn (cùng cao 2 cm → không chồng mặt)
    const Shop3dProp('seatingRug', Shop3dZone.seating, [Shop3dPart.box(Shop3dColor.rug, -1.54, 0, 2.7, 6.6, 0.02, 2.1)],
        flat: true, requires: Shop3dRequires.cafeTables),
    const Shop3dProp(
        'doorMat',
        Shop3dZone.entrance,
        [
          Shop3dPart.box(Shop3dColor.caramel, 3.6, 0, 3.58, 1.1, 0.02, 0.6),
        ],
        flat: true),
    const Shop3dProp(
        'customerStep',
        Shop3dZone.service,
        [
          customerStep,
          // nẹp viền sáng mép trước bục
          Shop3dPart.box(Shop3dColor.cream, -0.25, customerStepHeight, 0.785, 5.3, 0.012, 0.03),
        ],
        flat: true),
    const Shop3dProp('staffStep', Shop3dZone.service, [staffStep], flat: true),
    const Shop3dProp('kitchenStep', Shop3dZone.kitchen, [kitchenStep], flat: true),
  ];

  /// Vật thể đứng trên sàn (không gồm sàn và tường).
  static final List<Shop3dProp> props = [
    // --- Bếp ---
    _oven('oven1', -4.0, null),
    _oven('oven2', -2.7, Shop3dRequires.oven2),
    _prepCounter(),
    _fridge(),
    _mixingIsland(),
    _ingredientShelf(),
    _kitchen2Counter(),
    _kitchen2Island(),
    // --- Dịch vụ ---
    _pastryCase(),
    _cashierCounter(),
    _caseStand(),
    _packingCounter(),
    // --- Khu ngồi ---
    _seatingSet('seating1', -3.8, cloth: Shop3dColor.pinkLight, accent: Shop3dColor.strawberry, vase: Shop3dColor.mint),
    _seatingSet('seating2', -1.6, cloth: Shop3dColor.mintLight, accent: Shop3dColor.mint, vase: Shop3dColor.strawberry),
    _seatingSet('seating3', 0.6, cloth: Shop3dColor.butterLight, accent: Shop3dColor.butter, vase: Shop3dColor.mint),
    _pendantLamps(),
    _tableGlow(),
    // --- Trang trí ---
    _plant('plantDoor', 4.6, 3.5),
    _plant('plantCorner', -4.6, 3.5),
    _catBed(),
  ];

  /// Tường, theo mặt. Mỗi mặt gồm tấm tường + đồ gắn tường / khung cửa. Cảnh ẩn / làm mờ cả nhóm theo
  /// `RoomBox.hiddenWallMask` / `wallOpacity` (xem `OrbitCameraController.hiddenWallMask`).
  static final Map<RoomWall, List<Shop3dPart>> walls = {
    RoomWall.back: _backWall(),
    RoomWall.front: _frontWall(),
    RoomWall.left: _leftWall(),
    RoomWall.right: _rightWall(),
    RoomWall.ceiling: const [Shop3dPart.box(Shop3dColor.cream, 0, 3.2, 0, 10.4, 0.1, 8.4)],
  };

  /// Mặt tiền / vỉa hè ngoài cửa (P3): gạch lát vỉa hè, bậc thềm gỗ, hai chậu hoa hai bên cửa, ghế băng. Nằm NGOÀI phòng
  /// (z > 4,2) nên tách khỏi [props] (test "nằm trong phòng"); đều không chạm được → gộp vào lưới nền, 0 entity thêm
  /// ([Shop3dBatches.build]). Chậu / ghế là hộp chặn của `Shop3dNav.fromLayout` (vẫn chừa trọn khe cửa x ∈ [3,05; 4,15]
  /// và vỉa hè quanh vị trí sự kiện cãi nhau (2,2; 5,5)).
  static final List<Shop3dProp> outdoorProps = [
    Shop3dProp('sidewalkTiles', Shop3dZone.entrance, _sidewalkTileParts(), flat: true),
    const Shop3dProp('doorStoop', Shop3dZone.entrance, _stoopParts, flat: true),
    _doorPot('doorPotLeft', 2.8, Shop3dColor.strawberry, Shop3dColor.cream),
    _doorPot('doorPotRight', 4.42, Shop3dColor.butter, Shop3dColor.strawberry),
    _bench(),
  ];

  /// Vật thể (đứng trên sàn + phủ sàn) đang bật khi tiệm sở hữu [owned].
  static List<Shop3dProp> propsFor(Set<String> owned) => [
        for (final p in [...floorProps, ...props])
          if (p.enabledFor(owned)) p,
      ];

  /// Chỗ ngồi đang bật khi tiệm sở hữu [owned].
  static List<Shop3dSpot> seatsFor(Set<String> owned) => [
        for (final s in seats)
          if (s.requires == null || owned.contains(s.requires)) s,
      ];

  // ---- Dựng từng vật thể --------------------------------------------------------------------------------

  static Shop3dProp _oven(String id, double x, String? requires) {
    final parts = <Shop3dPart>[
      Shop3dPart.box(Shop3dColor.mint, x, 0, -3.55, 1.2, 1.3, 0.9),
      Shop3dPart.box(Shop3dColor.chocolate, x, 0.3, -3.075, 0.9, 0.6, 0.05),
      Shop3dPart.box(Shop3dColor.butter, x, 0.4, -3.045, 0.7, 0.4, 0.02, alpha: 0.85),
      Shop3dPart.box(Shop3dColor.caramel, x, 0.88, -3.06, 0.7, 0.04, 0.04),
      Shop3dPart.ball(Shop3dColor.cream, x - 0.35, 1.05, -3.08, 0.1),
      Shop3dPart.ball(Shop3dColor.cream, x, 1.05, -3.08, 0.1),
      Shop3dPart.ball(Shop3dColor.cream, x + 0.35, 1.05, -3.08, 0.1),
      Shop3dPart.cyl(Shop3dColor.steel, x + 0.3, 1.3, -3.8, 0.2, 0.4),
    ];
    return Shop3dProp(id, Shop3dZone.kitchen, parts, requires: requires);
  }

  static Shop3dProp _prepCounter() => const Shop3dProp('prepCounter', Shop3dZone.kitchen, [
        Shop3dPart.box(Shop3dColor.woodLight, -0.5, 0, -3.6, 3.0, 0.85, 0.8),
        Shop3dPart.box(Shop3dColor.cream, -0.5, 0.85, -3.58, 3.0, 0.05, 0.84),
        // bồn rửa + vòi
        Shop3dPart.cyl(Shop3dColor.steel, -1.2, 0.9, -3.6, 0.5, 0.02),
        Shop3dPart.cyl(Shop3dColor.steel, -1.2, 0.9, -3.85, 0.04, 0.3),
        Shop3dPart.box(Shop3dColor.steel, -1.2, 1.16, -3.75, 0.04, 0.04, 0.2),
        // khay cupcake
        Shop3dPart.box(Shop3dColor.steel, 0.4, 0.9, -3.6, 0.7, 0.02, 0.4),
        Shop3dPart.cyl(Shop3dColor.strawberry, 0.2, 0.92, -3.6, 0.1, 0.08),
        Shop3dPart.cyl(Shop3dColor.strawberry, 0.4, 0.92, -3.6, 0.1, 0.08),
        Shop3dPart.cyl(Shop3dColor.strawberry, 0.6, 0.92, -3.6, 0.1, 0.08),
        Shop3dPart.ball(Shop3dColor.cream, 0.2, 1.0, -3.6, 0.1),
        Shop3dPart.ball(Shop3dColor.cream, 0.4, 1.0, -3.6, 0.1),
        Shop3dPart.ball(Shop3dColor.cream, 0.6, 1.0, -3.6, 0.1),
        // giỏ bánh mì: giỏ mây + 2 bánh tròn + 2 bánh mì que dựng đứng
        Shop3dPart.cyl(Shop3dColor.caramel, -0.45, 0.9, -3.64, 0.3, 0.1),
        Shop3dPart.cyl(Shop3dColor.woodDark, -0.45, 0.98, -3.64, 0.32, 0.025),
        Shop3dPart.ball(Shop3dColor.bread, -0.53, 0.95, -3.6, 0.11),
        Shop3dPart.ball(Shop3dColor.bread, -0.39, 0.95, -3.57, 0.1),
        Shop3dPart.cyl(Shop3dColor.bread, -0.42, 0.95, -3.7, 0.055, 0.34),
        Shop3dPart.cyl(Shop3dColor.bread, -0.5, 0.95, -3.68, 0.05, 0.28),
      ]);

  static Shop3dProp _fridge() => const Shop3dProp('fridge', Shop3dZone.kitchen, [
        Shop3dPart.box(Shop3dColor.mint, 1.6, 0, -3.6, 1.0, 1.9, 0.8),
        Shop3dPart.box(Shop3dColor.chocolate, 1.6, 1.25, -3.19, 1.0, 0.02, 0.02),
        Shop3dPart.box(Shop3dColor.steel, 1.2, 0.9, -3.17, 0.04, 0.5, 0.04),
        Shop3dPart.box(Shop3dColor.steel, 1.2, 1.4, -3.17, 0.04, 0.3, 0.04),
        Shop3dPart.ball(Shop3dColor.strawberry, 1.8, 1.55, -3.2, 0.08),
      ]);

  /// Bàn trộn hạ còn 0,73 m (Mai / Bao đứng sau bàn vẫn lộ mặt).
  static Shop3dProp _mixingIsland() => const Shop3dProp('mixingIsland', Shop3dZone.kitchen, [
        Shop3dPart.box(Shop3dColor.woodLight, -2.0, 0, -2.15, 1.9, 0.68, 0.64),
        Shop3dPart.box(Shop3dColor.cream, -2.0, 0.68, -2.15, 2.0, 0.05, 0.7),
        // máy trộn đứng (giữa bàn, giữa chỗ Bao và Mai — không che mặt ai)
        Shop3dPart.box(Shop3dColor.strawberry, -1.95, 0.73, -2.15, 0.28, 0.04, 0.2),
        Shop3dPart.box(Shop3dColor.strawberry, -2.05, 0.77, -2.15, 0.08, 0.34, 0.1),
        Shop3dPart.box(Shop3dColor.strawberry, -1.95, 1.07, -2.15, 0.3, 0.1, 0.1),
        Shop3dPart.cyl(Shop3dColor.steel, -1.9, 0.77, -2.15, 0.22, 0.16),
        // tô bột + bao bột thấp
        Shop3dPart.cyl(Shop3dColor.cream, -2.55, 0.73, -2.05, 0.35, 0.14),
        Shop3dPart.box(Shop3dColor.cream, -2.27, 0.73, -2.25, 0.18, 0.16, 0.12),
      ]);

  static Shop3dProp _ingredientShelf() => const Shop3dProp('ingredientShelf', Shop3dZone.kitchen, [
        Shop3dPart.box(Shop3dColor.woodDark, -4.8, 0, -2.875, 0.4, 1.85, 0.05),
        Shop3dPart.box(Shop3dColor.woodDark, -4.8, 0, -1.325, 0.4, 1.85, 0.05),
        Shop3dPart.box(Shop3dColor.woodLight, -4.8, 0.4, -2.1, 0.4, 0.04, 1.6),
        Shop3dPart.box(Shop3dColor.woodLight, -4.8, 0.9, -2.1, 0.4, 0.04, 1.6),
        Shop3dPart.box(Shop3dColor.woodLight, -4.8, 1.4, -2.1, 0.4, 0.04, 1.6),
        Shop3dPart.box(Shop3dColor.woodLight, -4.8, 1.82, -2.1, 0.4, 0.04, 1.6),
        // bao bột / đường (kệ dưới)
        Shop3dPart.box(Shop3dColor.cream, -4.8, 0.44, -2.5, 0.3, 0.25, 0.3),
        Shop3dPart.box(Shop3dColor.cream, -4.8, 0.44, -1.9, 0.3, 0.25, 0.3),
        // lọ (kệ giữa)
        Shop3dPart.cyl(Shop3dColor.mint, -4.8, 0.94, -2.6, 0.2, 0.3),
        Shop3dPart.cyl(Shop3dColor.strawberry, -4.8, 0.94, -2.3, 0.2, 0.3),
        Shop3dPart.cyl(Shop3dColor.butter, -4.8, 0.94, -2.0, 0.2, 0.3),
        Shop3dPart.cyl(Shop3dColor.cream, -4.8, 0.94, -1.7, 0.2, 0.3),
        // giỏ (kệ trên)
        Shop3dPart.box(Shop3dColor.caramel, -4.8, 1.44, -2.3, 0.3, 0.2, 0.4),
        Shop3dPart.box(Shop3dColor.caramel, -4.8, 1.44, -1.7, 0.3, 0.2, 0.4),
        // đèn hải đăng nhỏ trên kệ trên cùng (chủ đề nhà bà ven biển): đế gỗ, 3 nón cụt sọc kem - hồng dâu chồng nhau,
        // ban công, đèn vàng bơ, mái hồng + núm (cao 0,53 m)
        Shop3dPart.cyl(Shop3dColor.woodDark, -4.8, 1.86, -2.1, 0.26, 0.02),
        Shop3dPart.cone(Shop3dColor.cream, -4.8, 1.88, -2.1, 0.22, 0.18, 0.125),
        Shop3dPart.cone(Shop3dColor.strawberry, -4.8, 2.005, -2.1, 0.18, 0.145, 0.125),
        Shop3dPart.cone(Shop3dColor.cream, -4.8, 2.13, -2.1, 0.145, 0.118, 0.11),
        Shop3dPart.cyl(Shop3dColor.woodDark, -4.8, 2.24, -2.1, 0.18, 0.02),
        Shop3dPart.cyl(Shop3dColor.butter, -4.8, 2.26, -2.1, 0.085, 0.07),
        Shop3dPart.cone(Shop3dColor.strawberry, -4.8, 2.33, -2.1, 0.14, 0.0, 0.06),
        Shop3dPart.ball(Shop3dColor.butter, -4.8, 2.39, -2.1, 0.03),
      ]);

  static Shop3dProp _kitchen2Counter() => const Shop3dProp(
      'kitchen2Counter',
      Shop3dZone.kitchen,
      [
        Shop3dPart.box(Shop3dColor.woodLight, 3.6, 0, -3.6, 2.5, 0.85, 0.8),
        Shop3dPart.box(Shop3dColor.cream, 3.6, 0.85, -3.58, 2.5, 0.05, 0.84),
        Shop3dPart.cyl(Shop3dColor.mint, 2.9, 0.9, -3.6, 0.4, 0.12),
        Shop3dPart.cyl(Shop3dColor.strawberry, 3.5, 0.9, -3.6, 0.35, 0.1),
        Shop3dPart.box(Shop3dColor.steel, 4.2, 0.9, -3.6, 0.7, 0.02, 0.4),
        Shop3dPart.cyl(Shop3dColor.butter, 4.0, 0.92, -3.6, 0.1, 0.08),
        Shop3dPart.cyl(Shop3dColor.butter, 4.2, 0.92, -3.6, 0.1, 0.08),
        Shop3dPart.cyl(Shop3dColor.butter, 4.4, 0.92, -3.6, 0.1, 0.08),
      ],
      requires: Shop3dRequires.kitchen2);

  static Shop3dProp _kitchen2Island() => const Shop3dProp(
      'kitchen2Island',
      Shop3dZone.kitchen,
      [
        Shop3dPart.box(Shop3dColor.woodLight, 2.3, 0, -2.15, 1.8, 0.68, 0.64),
        Shop3dPart.box(Shop3dColor.cream, 2.3, 0.68, -2.15, 1.8, 0.05, 0.7),
        Shop3dPart.cyl(Shop3dColor.cream, 1.9, 0.73, -2.15, 0.35, 0.14),
        Shop3dPart.cyl(Shop3dColor.woodDark, 2.5, 0.73, -2.15, 0.06, 0.4),
        Shop3dPart.box(Shop3dColor.strawberry, 2.8, 0.73, -2.15, 0.3, 0.06, 0.25),
      ],
      requires: Shop3dRequires.kitchen2);

  /// Độ trong suốt chung của kính (cửa sổ, tủ bánh) — một material kính cho cả tiệm.
  static const double glassAlpha = 0.15;

  /// Tủ kính bánh: thân hồng mặt trước caro hồng-kem, kệ dưới kem, kệ trên bằng kính (thấy bánh kệ dưới từ camera trên
  /// cao), nắp kính viền vàng mảnh (không còn tấm nắp đặc), 2 đèn nhỏ trên thanh sau, bánh trưng bày trong tủ.
  static Shop3dProp _pastryCase() {
    const cx = caseCenterX, cz = caseCenterZ;
    const x0 = cx - 1.2, front = cz + 0.45; // mép trái, mặt trước thân tủ (z -0,05)
    final parts = <Shop3dPart>[
      const Shop3dPart.box(Shop3dColor.strawberry, cx, 0, cz, 2.4, 0.8, 0.9),
      // kệ dưới (mặt kệ = caseShelfLowerY)
      const Shop3dPart.box(Shop3dColor.cream, cx, 0.8, cz, 2.3, caseShelfLowerY - 0.8, 0.8),
      // kệ trên bằng kính (mặt kệ = caseShelfUpperY) + nẹp vàng mép trước
      const Shop3dPart.box(Shop3dColor.glass, cx, caseShelfUpperY - 0.02, cz - 0.025, 2.3, 0.02, 0.55, alpha: glassAlpha),
      const Shop3dPart.box(Shop3dColor.butter, cx, caseShelfUpperY - 0.03, cz + 0.26, 2.3, 0.035, 0.02),
      // vách + nắp kính
      const Shop3dPart.box(Shop3dColor.glass, cx, 0.83, cz, 2.34, 0.47, 0.84, alpha: glassAlpha),
      // khung vàng mảnh: 4 cột + 4 thanh nắp + nẹp mép trên thân
      for (final (px, pz) in const [(-1.175, -0.415), (1.175, -0.415), (-1.175, 0.415), (1.175, 0.415)])
        Shop3dPart.box(Shop3dColor.butter, cx + px, 0.83, cz + pz, 0.04, 0.47, 0.04),
      for (final pz in const [-0.415, 0.415]) Shop3dPart.box(Shop3dColor.butter, cx, 1.285, cz + pz, 2.4, 0.03, 0.04),
      for (final px in const [-1.175, 1.175]) Shop3dPart.box(Shop3dColor.butter, cx + px, 1.285, cz, 0.04, 0.03, 0.8),
      const Shop3dPart.box(Shop3dColor.butter, cx, 0.77, front + 0.005, 2.4, 0.06, 0.02),
      // 2 đèn nhỏ trên thanh sau
      for (final px in const [-0.7, 0.7]) ...[
        Shop3dPart.cyl(Shop3dColor.woodDark, cx + px, 1.315, cz - 0.415, 0.02, 0.07),
        Shop3dPart.cone(Shop3dColor.butter, cx + px, 1.37, cz - 0.415, 0.09, 0.04, 0.05),
        Shop3dPart.ball(Shop3dColor.cream, cx + px, 1.35, cz - 0.415, 0.04),
      ],
    ];
    // caro kem trên mặt trước thân hồng (trên bục khách 0,16 m)
    const sq = 0.15;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 16; c++) {
        if ((r + c).isOdd) continue;
        parts.add(Shop3dPart.box(Shop3dColor.cream, x0 + (c + 0.5) * sq, 0.17 + r * sq, front + 0.006, sq, sq, 0.012));
      }
    }
    // bánh trưng bày (một số ô; ô bánh của màn chơi: caseSlotPositions)
    final slots = caseSlotPositions();
    double sx(int i) => slots[i].x;
    const lo = caseShelfLowerY, hi = caseShelfUpperY;
    parts
      ..addAll(_roundCake(sx(0), lo, cz, Shop3dColor.cream, Shop3dColor.strawberry))
      ..addAll(_cupcake(sx(1) - 0.08, lo, cz, Shop3dColor.strawberry, Shop3dColor.cream))
      ..addAll(_cupcake(sx(1) + 0.08, lo, cz, Shop3dColor.mint, Shop3dColor.pinkLight))
      ..addAll(_tart(sx(2), lo, cz))
      ..addAll(_roundCake(sx(3), lo, cz, Shop3dColor.mint, Shop3dColor.cream))
      ..addAll(_macarons(sx(4), lo, cz))
      ..addAll(_cupcake(sx(5) - 0.08, lo, cz, Shop3dColor.caramel, Shop3dColor.chocolate))
      ..addAll(_cupcake(sx(5) + 0.08, lo, cz, Shop3dColor.caramel, Shop3dColor.chocolate))
      ..addAll(_buns(sx(6), hi, cz))
      ..addAll(_cupcake(sx(7) - 0.08, hi, cz, Shop3dColor.butter, Shop3dColor.cream))
      ..addAll(_cupcake(sx(7) + 0.08, hi, cz, Shop3dColor.strawberry, Shop3dColor.pinkLight))
      ..addAll(_roundCake(sx(9), hi, cz, Shop3dColor.pinkLight, Shop3dColor.cream))
      ..addAll(_macarons(sx(11), hi, cz));
    return Shop3dProp('pastryCase', Shop3dZone.service, parts);
  }

  static List<Shop3dPart> _cupcake(double x, double y, double z, Shop3dColor liner, Shop3dColor frosting) => [
        Shop3dPart.cone(liner, x, y, z, 0.075, 0.095, 0.06),
        Shop3dPart.ball(frosting, x, y + 0.04, z, 0.09),
        Shop3dPart.ball(Shop3dColor.strawberry, x, y + 0.12, z, 0.028),
      ];

  static List<Shop3dPart> _roundCake(double x, double y, double z, Shop3dColor body, Shop3dColor top) => [
        Shop3dPart.cyl(Shop3dColor.cream, x, y, z, 0.28, 0.012),
        Shop3dPart.cyl(body, x, y + 0.012, z, 0.23, 0.09),
        Shop3dPart.cyl(top, x, y + 0.1, z, 0.235, 0.022),
        for (final (dx, dz) in const [(-0.06, 0.03), (0.06, 0.03), (0.0, -0.06)])
          Shop3dPart.ball(Shop3dColor.strawberry, x + dx, y + 0.115, z + dz, 0.04),
      ];

  static List<Shop3dPart> _tart(double x, double y, double z) => [
        Shop3dPart.cyl(Shop3dColor.caramel, x, y, z, 0.24, 0.035),
        Shop3dPart.cyl(Shop3dColor.butter, x, y + 0.035, z, 0.2, 0.012),
        for (final (dx, dz, c) in const [
          (-0.05, 0.0, Shop3dColor.strawberry),
          (0.05, 0.02, Shop3dColor.mint),
          (0.0, -0.05, Shop3dColor.strawberry),
        ])
          Shop3dPart.ball(c, x + dx, y + 0.04, z + dz, 0.035),
      ];

  static List<Shop3dPart> _macarons(double x, double y, double z) => [
        for (final (i, c) in const [(0, Shop3dColor.strawberry), (1, Shop3dColor.mint), (2, Shop3dColor.butter)]) ...[
          Shop3dPart.cyl(c, x - 0.09 + i * 0.09, y, z, 0.075, 0.022),
          Shop3dPart.cyl(Shop3dColor.cream, x - 0.09 + i * 0.09, y + 0.022, z, 0.068, 0.012),
          Shop3dPart.cyl(c, x - 0.09 + i * 0.09, y + 0.034, z, 0.075, 0.022),
        ],
      ];

  static List<Shop3dPart> _buns(double x, double y, double z) => [
        Shop3dPart.cyl(Shop3dColor.cream, x, y, z, 0.3, 0.012),
        Shop3dPart.ball(Shop3dColor.bread, x - 0.07, y, z + 0.03, 0.11),
        Shop3dPart.ball(Shop3dColor.bread, x + 0.07, y, z - 0.02, 0.11),
        Shop3dPart.ball(Shop3dColor.caramel, x, y + 0.04, z, 0.08),
      ];

  /// Mặt trước quầy (phía khách, z = [front]) dài từ [x0] tới [x1]: chân quầy caramel từ [y0] (trên bục khách nếu có),
  /// ván đứng màu sáng (khe lộ màu thân), viền vàng mép trên sát mặt quầy.
  static List<Shop3dPart> _counterFront(double x0, double x1, double front, double y0) {
    const top = serviceCounterTop - 0.04, kick = 0.1, trim = 0.05;
    final cx = (x0 + x1) / 2, w = x1 - x0;
    final parts = <Shop3dPart>[
      Shop3dPart.box(Shop3dColor.caramel, cx, y0, front + 0.01, w, kick, 0.02),
      Shop3dPart.box(Shop3dColor.butter, cx, top - trim, front + 0.01, w, trim, 0.02),
    ];
    final n = (w / 0.155).round();
    final pitch = w / n;
    for (var i = 0; i < n; i++) {
      parts.add(Shop3dPart.box(Shop3dColor.floorPlank, x0 + (i + 0.5) * pitch, y0 + kick, front + 0.006, pitch - 0.016,
          top - trim - y0 - kick, 0.012));
    }
    return parts;
  }

  /// Quầy thu ngân hai bậc: thân + mặt quầy thấp 0,72 m suốt chiều dài (khách thú lộ mặt, nhân viên sau quầy lộ mặt),
  /// bậc thu ngân 0,95 m chỉ quanh máy tính tiền (nửa sau quầy). Mặt trước ốp ván đứng; chuông + hộp tip hai bên bậc.
  static Shop3dProp _cashierCounter() => Shop3dProp('cashierCounter', Shop3dZone.service, [
        const Shop3dPart.box(Shop3dColor.woodLight, 1.0, 0, -0.5, 2.8, serviceCounterTop - 0.04, 0.9),
        const Shop3dPart.box(Shop3dColor.cream, 1.0, serviceCounterTop - 0.04, -0.5, 2.8, 0.04, 0.94),
        // bậc thu ngân (cao 0,95 m) quanh máy tính tiền
        const Shop3dPart.box(
            Shop3dColor.woodDark, 0.9, serviceCounterTop, -0.66, 0.66, cashierStepTop - serviceCounterTop - 0.03, 0.5),
        const Shop3dPart.box(Shop3dColor.cream, 0.9, cashierStepTop - 0.03, -0.66, 0.7, 0.03, 0.54),
        // máy tính tiền
        const Shop3dPart.box(Shop3dColor.chocolate, 0.9, cashierStepTop, -0.7, 0.45, 0.16, 0.38),
        const Shop3dPart.box(Shop3dColor.cream, 0.9, cashierStepTop + 0.16, -0.62, 0.3, 0.02, 0.15),
        const Shop3dPart.box(Shop3dColor.chocolate, 0.9, cashierStepTop + 0.16, -0.82, 0.3, 0.22, 0.04),
        // chuông vàng (đế gỗ + chuông + núm) bên trái bậc
        const Shop3dPart.cyl(Shop3dColor.woodDark, 0.4, serviceCounterTop, -0.3, 0.1, 0.015),
        const Shop3dPart.ball(Shop3dColor.butter, 0.4, serviceCounterTop - 0.025, -0.3, 0.08),
        const Shop3dPart.ball(Shop3dColor.butter, 0.4, serviceCounterTop + 0.05, -0.3, 0.024),
        // hộp tip bạc hà (khe chocolate + tim hồng) bên phải bậc, máy quẹt thẻ
        const Shop3dPart.box(Shop3dColor.mint, 1.45, serviceCounterTop, -0.32, 0.16, 0.11, 0.11),
        const Shop3dPart.box(Shop3dColor.chocolate, 1.45, serviceCounterTop + 0.11, -0.32, 0.08, 0.004, 0.016),
        const Shop3dPart.ball(Shop3dColor.strawberry, 1.45, serviceCounterTop + 0.035, -0.27, 0.04),
        const Shop3dPart.box(Shop3dColor.strawberry, 1.75, serviceCounterTop, -0.3, 0.1, 0.12, 0.16),
        ..._counterFront(-0.4, 2.4, -0.05, customerStepHeight),
      ]);

  static Shop3dProp _caseStand() => const Shop3dProp(
      'caseStand',
      Shop3dZone.service,
      [
        Shop3dPart.cyl(Shop3dColor.woodDark, 0.0, serviceCounterTop, -0.45, 0.04, 0.5),
        Shop3dPart.cyl(Shop3dColor.strawberry, 0.0, serviceCounterTop, -0.45, 0.4, 0.02),
        Shop3dPart.cyl(Shop3dColor.cream, 0.0, serviceCounterTop + 0.2, -0.45, 0.32, 0.02),
        Shop3dPart.cyl(Shop3dColor.mint, 0.0, serviceCounterTop + 0.4, -0.45, 0.24, 0.02),
      ],
      requires: Shop3dRequires.caseStand);

  static Shop3dProp _packingCounter() => Shop3dProp('packingCounter', Shop3dZone.service, [
        const Shop3dPart.box(Shop3dColor.woodLight, 3.65, 0, -0.5, 2.5, serviceCounterTop - 0.04, 0.9),
        const Shop3dPart.box(Shop3dColor.cream, 3.65, serviceCounterTop - 0.04, -0.5, 2.5, 0.04, 0.94),
        ..._counterFront(2.4, 4.9, -0.05, 0),
        // chồng hộp bánh
        const Shop3dPart.box(Shop3dColor.mint, 3.0, serviceCounterTop, -0.5, 0.35, 0.1, 0.35),
        const Shop3dPart.box(Shop3dColor.strawberry, 3.0, serviceCounterTop + 0.1, -0.5, 0.3, 0.1, 0.3),
        const Shop3dPart.box(Shop3dColor.cream, 3.0, serviceCounterTop + 0.2, -0.5, 0.25, 0.1, 0.25),
        // cuộn ruy băng + túi giấy
        const Shop3dPart.cyl(Shop3dColor.butter, 3.7, serviceCounterTop, -0.4, 0.2, 0.12),
        const Shop3dPart.box(Shop3dColor.caramel, 4.4, serviceCounterTop, -0.5, 0.3, 0.35, 0.2),
        const Shop3dPart.box(Shop3dColor.caramel, 4.0, serviceCounterTop, -0.6, 0.3, 0.3, 0.2),
      ]);

  /// Một bộ bàn tròn + 2 ghế. Ghế trái ở cx-0,78 (lưng tựa phía -x), ghế phải ở cx+0,78 (lưng tựa phía +x). Khăn trải
  /// bàn màu [cloth] (viền [accent]), lọ hoa nhỏ màu [vase], hũ đường; ghế sơn cùng tông khăn, đệm màu [accent]. Đèn thả:
  /// [_pendantLamps] (không chạm được, không nhún theo bàn).
  static Shop3dProp _seatingSet(String id, double cx,
      {required Shop3dColor cloth, required Shop3dColor accent, required Shop3dColor vase}) {
    const z = 2.7, clothTop = 0.75;
    final parts = <Shop3dPart>[
      // bàn
      Shop3dPart.cyl(Shop3dColor.woodDark, cx, 0, z, 0.4, 0.03),
      Shop3dPart.cyl(Shop3dColor.woodDark, cx, 0.03, z, 0.12, 0.67),
      Shop3dPart.cyl(Shop3dColor.cream, cx, 0.7, z, 0.9, 0.04),
      // khăn trải bàn rủ xuống + viền
      Shop3dPart.cyl(cloth, cx, 0.62, z, 0.98, clothTop - 0.62),
      Shop3dPart.cyl(accent, cx, 0.615, z, 0.99, 0.025),
      // lọ hoa nhỏ
      Shop3dPart.cyl(vase, cx - 0.14, clothTop, z - 0.1, 0.07, 0.1),
      Shop3dPart.ball(Shop3dColor.correct, cx - 0.16, clothTop + 0.09, z - 0.09, 0.05),
      Shop3dPart.ball(accent == Shop3dColor.strawberry ? Shop3dColor.butter : Shop3dColor.strawberry, cx - 0.13,
          clothTop + 0.1, z - 0.11, 0.06),
      // hũ đường
      Shop3dPart.cyl(Shop3dColor.cream, cx + 0.15, clothTop, z + 0.08, 0.08, 0.08),
      Shop3dPart.cyl(accent, cx + 0.15, clothTop + 0.08, z + 0.08, 0.088, 0.015),
      Shop3dPart.ball(accent, cx + 0.15, clothTop + 0.09, z + 0.08, 0.025),
      ..._chair(cx - 0.78, z, leftSide: true, paint: cloth, cushion: accent),
      ..._chair(cx + 0.78, z, leftSide: false, paint: cloth, cushion: accent),
    ];
    return Shop3dProp(id, Shop3dZone.seating, parts, requires: Shop3dRequires.cafeTables);
  }

  static List<Shop3dPart> _chair(double x, double z,
      {required bool leftSide, required Shop3dColor paint, required Shop3dColor cushion}) {
    final backX = x + (leftSide ? -0.185 : 0.185);
    return [
      Shop3dPart.box(paint, x, 0.42, z, 0.42, 0.06, 0.42),
      Shop3dPart.box(cushion, x, 0.48, z, 0.36, 0.04, 0.36),
      Shop3dPart.box(paint, backX, 0.48, z, 0.05, 0.45, 0.42),
      // nẹp màu đệm ngang lưng tựa
      Shop3dPart.box(cushion, backX, 0.8, z, 0.06, 0.06, 0.43),
      Shop3dPart.box(Shop3dColor.caramel, x - 0.17, 0, z - 0.17, 0.04, 0.42, 0.04),
      Shop3dPart.box(Shop3dColor.caramel, x + 0.17, 0, z - 0.17, 0.04, 0.42, 0.04),
      Shop3dPart.box(Shop3dColor.caramel, x - 0.17, 0, z + 0.17, 0.04, 0.42, 0.04),
      Shop3dPart.box(Shop3dColor.caramel, x + 0.17, 0, z + 0.17, 0.04, 0.42, 0.04),
    ];
  }

  /// Toạ độ x của 3 bàn khu ngồi (khớp [seats]).
  static const List<double> tableXs = [-3.8, -1.6, 0.6];

  /// Đèn thả trên 3 bàn: dây mảnh từ trần, đui caramel, chao nón cụt vàng bơ nhỏ (đường kính 0,22 m), bóng kem lộ dưới
  /// chao. Mép dưới bóng 2,25 m (P3: treo cao hơn + chao nhỏ hơn bản đầu — từ camera trên cao chao không còn che đầu
  /// nhân vật ở lối đi phía sau bàn). Không chạm được → gộp vào lưới nền của cờ `cafe_tables`.
  static Shop3dProp _pendantLamps() => Shop3dProp(
      'pendantLamps',
      Shop3dZone.seating,
      [
        for (final cx in tableXs) ...[
          Shop3dPart.cyl(Shop3dColor.chocolate, cx, 2.5, 2.7, 0.012, 3.2 - 2.5),
          Shop3dPart.cyl(Shop3dColor.caramel, cx, 2.46, 2.7, 0.045, 0.05),
          Shop3dPart.cone(Shop3dColor.butter, cx, 2.33, 2.7, 0.22, 0.07, 0.13),
          Shop3dPart.ball(Shop3dColor.cream, cx, 2.25, 2.7, 0.075),
        ],
      ],
      requires: Shop3dRequires.cafeTables,
      pickable: false);

  /// Quầng sáng giả dưới đèn thả: hai đĩa vàng bơ mờ chồng nhau trên khăn bàn (giữa sáng hơn mép), không đổ bóng thật.
  static Shop3dProp _tableGlow() => Shop3dProp(
      'tableGlow',
      Shop3dZone.seating,
      [
        for (final cx in tableXs) ...[
          Shop3dPart.cyl(Shop3dColor.butter, cx, 0.753, 2.7, 0.62, 0.003, alpha: tableGlowAlpha),
          Shop3dPart.cyl(Shop3dColor.butter, cx, 0.757, 2.7, 0.34, 0.003, alpha: tableGlowAlpha),
        ],
      ],
      flat: true,
      requires: Shop3dRequires.cafeTables,
      pickable: false);

  static const double tableGlowAlpha = 0.22;

  /// Cây trong chậu: chậu nón cụt có viền + đất, một tán lớn + 3 cụm lá nhỏ ba tông (đậm / nhạt / bạc hà).
  static Shop3dProp _plant(String id, double x, double z) => Shop3dProp(id, Shop3dZone.decor, [
        Shop3dPart.cone(Shop3dColor.caramel, x, 0, z, 0.3, 0.39, 0.36),
        Shop3dPart.cyl(Shop3dColor.woodDark, x, 0.36, z, 0.39, 0.05),
        Shop3dPart.cyl(Shop3dColor.chocolate, x, 0.41, z, 0.33, 0.012),
        Shop3dPart.ball(Shop3dColor.correct, x, 0.38, z, 0.6),
        Shop3dPart.ball(Shop3dColor.leafDeep, x - 0.17, 0.62, z + 0.1, 0.3),
        Shop3dPart.ball(Shop3dColor.leafLight, x + 0.17, 0.7, z + 0.02, 0.26),
        Shop3dPart.ball(Shop3dColor.mint, x - 0.02, 0.88, z - 0.12, 0.24),
      ]);

  /// Chậu cây nhỏ đặt trên mặt phẳng ở độ cao [y0] (bệ cửa sổ, kệ): chậu nón cụt [pot], tán lá [leaf] + chấm hoa
  /// [bloom] (tuỳ chọn), hai cụm lá rủ ra phía [trail] (hướng +z hoặc -z, 0 = không rủ).
  static List<Shop3dPart> _miniPot(double x, double y0, double z,
      {Shop3dColor pot = Shop3dColor.caramel,
      Shop3dColor leaf = Shop3dColor.correct,
      Shop3dColor? bloom,
      double trail = 0,
      double size = 1}) {
    final d = 0.14 * size;
    return [
      Shop3dPart.cone(pot, x, y0, z, d * 0.72, d, 0.1 * size),
      Shop3dPart.cyl(Shop3dColor.woodDark, x, y0 + 0.1 * size, z, d * 1.1, 0.015 * size),
      Shop3dPart.ball(leaf, x, y0 + 0.09 * size, z, d * 1.25),
      if (bloom != null) Shop3dPart.ball(bloom, x - d * 0.25, y0 + 0.2 * size, z + d * 0.15, 0.045 * size),
      if (trail != 0) ...[
        Shop3dPart.ball(Shop3dColor.leafDeep, x - d * 0.2, y0 + 0.02 * size, z + trail * d * 0.62, 0.075 * size),
        Shop3dPart.ball(Shop3dColor.correct, x + d * 0.25, y0 + 0.0, z + trail * d * 0.6, 0.06 * size),
      ],
    ];
  }

  /// Ổ nằm của mèo Mochi (ngày mưa).
  static Shop3dProp _catBed() => const Shop3dProp('mochiBed', Shop3dZone.decor, [
        Shop3dPart.cyl(Shop3dColor.cream, 4.4, 0, 1.5, 0.6, 0.12),
        Shop3dPart.cyl(Shop3dColor.strawberry, 4.4, 0.12, 1.5, 0.45, 0.06),
      ]);

  // ---- Mặt tiền / vỉa hè (ngoài phòng) -------------------------------------------------------------------

  /// Mặt trên vỉa hè ngoài cửa (`Shop3dBatches`: vỉa hè z ∈ [4,3; 6,9], mặt trên -3 cm so với sàn tiệm, đất quanh tiệm -4 cm).
  static const double sidewalkTop = -0.03;

  /// Gạch vỉa hè 1,4 × 0,65 m so le từng hàng: ô kem sáng dày 8 mm xen kẽ với ô lộ nền vỉa hè (kem ấm) — không cần ô
  /// thứ hai nên nửa số khối.
  static List<Shop3dPart> _sidewalkTileParts() {
    const x0 = -7.0, z0 = 4.3, w = 1.4, d = 0.65, gap = 0.02, h = 0.008;
    final parts = <Shop3dPart>[];
    for (var r = 0; r < 4; r++) {
      final shift = r.isOdd ? w / 2 : 0.0;
      for (var c = -1; c < 10; c++) {
        if ((r + c).isOdd) continue;
        final a = math.max(x0, x0 + c * w + shift), b = math.min(-x0, x0 + (c + 1) * w + shift);
        if (b - a < 0.05) continue;
        parts.add(Shop3dPart.box(
            Shop3dColor.pavingLight, (a + b) / 2, sidewalkTop, z0 + (r + 0.5) * d, b - a - gap, h, d - gap));
      }
    }
    return parts;
  }

  /// Bậc thềm: ngưỡng cửa gỗ tối trong bề dày tường (z 4,0–4,2) + bậc gỗ sáng trước cửa (z 4,2–4,5) có nẹp mép và 3 khe
  /// ván. Mặt trên ≤ 1 cm so với sàn tiệm — chân nhân vật đi ra không lún / không nhảy bậc.
  static const List<Shop3dPart> _stoopParts = [
    Shop3dPart.box(Shop3dColor.woodDark, 3.6, sidewalkTop, 4.1, 1.1, 0.04, 0.2),
    Shop3dPart.box(Shop3dColor.woodLight, 3.6, sidewalkTop, 4.35, 1.3, 0.035, 0.3),
    Shop3dPart.box(Shop3dColor.caramel, 3.6, 0, 4.475, 1.3, 0.012, 0.05),
    Shop3dPart.box(Shop3dColor.floorGap, 3.2, 0.005, 4.33, 0.008, 0.006, 0.26),
    Shop3dPart.box(Shop3dColor.floorGap, 3.6, 0.005, 4.33, 0.008, 0.006, 0.26),
    Shop3dPart.box(Shop3dColor.floorGap, 4.0, 0.005, 4.33, 0.008, 0.006, 0.26),
  ];

  /// Chậu hoa cạnh cửa: chậu nón cụt caramel có viền gỗ tối, tán lá ba tông, ba bông [bloom] + ba nụ nhỏ [bud].
  static Shop3dProp _doorPot(String id, double x, Shop3dColor bloom, Shop3dColor bud) {
    const z = 4.47, top = 0.36;
    return Shop3dProp(
        id,
        Shop3dZone.entrance,
        [
          Shop3dPart.cone(Shop3dColor.caramel, x, 0, z, 0.24, 0.34, top),
          Shop3dPart.cyl(Shop3dColor.woodDark, x, top, z, 0.38, 0.04),
          Shop3dPart.ball(Shop3dColor.correct, x, 0.34, z, 0.36),
          Shop3dPart.ball(Shop3dColor.leafDeep, x - 0.1, 0.46, z + 0.04, 0.2),
          Shop3dPart.ball(Shop3dColor.leafLight, x + 0.1, 0.5, z - 0.03, 0.17),
          for (final (dx, dy, dz) in const [(-0.12, 0.62, 0.1), (0.0, 0.7, 0.04), (0.12, 0.64, 0.08)])
            Shop3dPart.ball(bloom, x + dx, dy, z + dz, 0.08),
          for (final (dx, dy, dz) in const [(-0.04, 0.58, 0.16), (0.09, 0.57, 0.15), (-0.1, 0.72, -0.02)])
            Shop3dPart.ball(bud, x + dx, dy, z + dz, 0.055),
        ],
        pickable: false);
  }

  /// Ghế băng gỗ sát tường bên phải cửa (dài 0,8 m): hai ván ngồi, hai ván tựa, chân + tay vịn caramel, đệm hồng. Cao
  /// 0,78 m.
  static Shop3dProp _bench() {
    const cx = 5.1, z = 4.46, len = 0.8;
    return Shop3dProp(
        'bench',
        Shop3dZone.entrance,
        [
          for (final dz in const [0.02, 0.15]) Shop3dPart.box(Shop3dColor.woodLight, cx, 0.4, z + dz, len, 0.04, 0.12),
          for (final y in const [0.58, 0.69]) Shop3dPart.box(Shop3dColor.woodLight, cx, y, z - 0.14, len, 0.08, 0.03),
          for (final dx in const [-len / 2 + 0.04, len / 2 - 0.04]) ...[
            Shop3dPart.box(Shop3dColor.caramel, cx + dx, 0, z + 0.12, 0.05, 0.4, 0.05),
            Shop3dPart.box(Shop3dColor.caramel, cx + dx, 0, z - 0.14, 0.05, 0.78, 0.05),
            Shop3dPart.box(Shop3dColor.caramel, cx + dx, 0.55, z, 0.05, 0.04, 0.3),
          ],
          Shop3dPart.box(Shop3dColor.strawberry, cx - 0.2, 0.44, z + 0.06, 0.26, 0.05, 0.2),
        ],
        pickable: false);
  }

  // ---- Sàn ----------------------------------------------------------------------------------------------

  /// Bề rộng dải viền tối quanh mép sàn.
  static const double floorEdgeWidth = 0.12;

  /// Ranh giữa sàn caro bếp (z nhỏ hơn) và sàn ván phòng khách.
  static const double kitchenFloorZ = -1.25;

  /// Sàn phòng khách: nền màu khe ván, dải viền tối quanh mép sàn (cao 2 cm như thảm), ván gỗ hai tông chạy dọc z (về
  /// phía bếp) cao 6 mm, khe 1,2 cm lộ màu nền, mối nối so le; nẹp tối ở ranh sàn bếp. Các lớp không chồng mặt nhau.
  static List<Shop3dPart> _floorParts() {
    const e = floorEdgeWidth, edgeH = 0.02;
    const minX = -5 + e, maxX = 5 - e, maxZ = 4 - e, z0 = kitchenFloorZ + 0.03;
    // Thứ tự trong lưới gộp = thứ tự vẽ: ván trước, nền sau (kiểm tra độ sâu loại phần nền bị ván che — đỡ tô thừa).
    final parts = <Shop3dPart>[];
    const plankW = 0.28, gap = 0.012, plankH = 0.006;
    const joints = [0.36, 0.71, 0.18, 0.54, 0.88, 0.27, 0.63];
    final cols = ((maxX - minX) / plankW).round();
    final w = (maxX - minX) / cols;
    for (var i = 0; i < cols; i++) {
      final x = minX + (i + 0.5) * w;
      final color = i.isEven ? Shop3dColor.floorWood : Shop3dColor.floorPlank;
      final j = z0 + (maxZ - z0) * joints[i % joints.length];
      for (final (a, b) in [(z0, j), (j, maxZ)]) {
        parts.add(Shop3dPart.box(color, x, 0, (a + b) / 2, w - gap, plankH, b - a - gap));
      }
    }
    return parts
      ..addAll(const [
      Shop3dPart.box(Shop3dColor.floorGap, 0, -0.1, 0, 10, 0.1, 8),
      Shop3dPart.box(Shop3dColor.floorEdge, 0, 0, -4 + e / 2, 10, edgeH, e),
      Shop3dPart.box(Shop3dColor.floorEdge, 0, 0, 4 - e / 2, 10, edgeH, e),
      Shop3dPart.box(Shop3dColor.floorEdge, -5 + e / 2, 0, 0, e, edgeH, 8 - 2 * e),
      Shop3dPart.box(Shop3dColor.floorEdge, 5 - e / 2, 0, 0, e, edgeH, 8 - 2 * e),
      Shop3dPart.box(Shop3dColor.floorEdge, 0, 0, kitchenFloorZ + 0.015, maxX - minX, edgeH, 0.03),
    ]);
  }

  /// Sàn bếp caro bạc hà / kem: nền kem cao 1,4 cm + ô bạc hà dày 4 mm (mặt 1,8 cm — thấp hơn bóng tròn dưới chân
  /// nhân vật 2,6 cm, không chồng mặt).
  static List<Shop3dPart> _kitchenTileParts() {
    const e = floorEdgeWidth, base = 0.014;
    const minX = -5 + e, maxX = 5 - e, minZ = -4 + e, maxZ = kitchenFloorZ;
    const cols = 20, s = (maxX - minX) / cols;
    final parts = <Shop3dPart>[];
    for (var r = 0; minZ + r * s < maxZ - 1e-6; r++) {
      final za = minZ + r * s, zb = math.min(maxZ, za + s);
      for (var c = 0; c < cols; c++) {
        if ((r + c).isOdd) continue;
        parts.add(Shop3dPart.box(Shop3dColor.mint, minX + (c + 0.5) * s, base, (za + zb) / 2, s, 0.004, zb - za));
      }
    }
    // nền kem sau các ô (vẽ sau → phần bị ô che bị loại bởi kiểm tra độ sâu)
    return parts..add(const Shop3dPart.box(Shop3dColor.cream, 0, 0, (minZ + maxZ) / 2, maxX - minX, base, maxZ - minZ));
  }

  // ---- Tường ---------------------------------------------------------------------------------------------

  /// Ốp tường nửa dưới ([_wainscot]): chân tường gỗ cao [skirtingHeight], tấm kem sọc bạc hà tới [wainscotTop], nẹp
  /// caramel 5 cm phía trên; phào trần caramel cao [crownHeight] + gờ kem.
  static const double skirtingHeight = 0.12;
  static const double wainscotTop = 0.9;
  static const double crownHeight = 0.1;

  /// Sọc bạc hà: rộng [stripeWidth], lặp mỗi [stripePitch] theo lưới chung toạ độ (sọc hai bên ô cửa / góc phòng khớp).
  static const double stripePitch = 0.3;
  static const double stripeWidth = 0.14;

  /// Khối dán lên mặt trong tường [w]: dọc tường từ [u0] tới [u1] (x với tường trước / sau, z với tường trái / phải),
  /// đáy [y0], cao [h], cách mặt tường [t0], dày [d] (vào trong phòng).
  static Shop3dPart _onWall(RoomWall w, Shop3dColor c, double u0, double u1, double y0, double h, double t0, double d) {
    final u = (u0 + u1) / 2, len = u1 - u0;
    return switch (w) {
      RoomWall.back => Shop3dPart.box(c, u, y0, room.minZ + t0 + d / 2, len, h, d),
      RoomWall.front => Shop3dPart.box(c, u, y0, room.maxZ - t0 - d / 2, len, h, d),
      RoomWall.left => Shop3dPart.box(c, room.minX + t0 + d / 2, y0, u, d, h, len),
      RoomWall.right => Shop3dPart.box(c, room.maxX - t0 - d / 2, y0, u, d, h, len),
      RoomWall.ceiling => throw ArgumentError.value(w, 'w'),
    };
  }

  /// Toạ độ (x, z) của điểm [u] dọc tường [w], cách mặt tường [t] vào trong phòng.
  static (double, double) _wallPoint(RoomWall w, double u, double t) => switch (w) {
        RoomWall.back => (u, room.minZ + t),
        RoomWall.front => (u, room.maxZ - t),
        RoomWall.left => (room.minX + t, u),
        RoomWall.right => (room.maxX - t, u),
        RoomWall.ceiling => throw ArgumentError.value(w, 'w'),
      };

  /// [u0]..[u1] trừ các khoảng [holes].
  static List<(double, double)> _runs(double u0, double u1, List<(double, double)> holes) {
    var runs = [(u0, u1)];
    for (final (h0, h1) in holes) {
      runs = [
        for (final (a, b) in runs)
          if (h1 <= a || h0 >= b)
            (a, b)
          else ...[
            if (h0 > a) (a, h0),
            if (h1 < b) (h1, b),
          ],
      ];
    }
    return runs;
  }

  /// Ốp tường nửa dưới + phào trần dọc tường [w] từ [u0] tới [u1]. [gaps]: khoảng bỏ trống ốp (cửa ra vào); [railGaps]:
  /// khoảng chỉ bỏ nẹp (cửa sổ — bệ cửa thay nẹp). Lớp dán cách nhau ≥ 6 mm (không nhấp nháy z-fighting).
  static List<Shop3dPart> _wainscot(RoomWall w, double u0, double u1,
      {List<(double, double)> gaps = const [], List<(double, double)> railGaps = const []}) {
    const panelH = wainscotTop - skirtingHeight;
    final parts = <Shop3dPart>[];
    for (final (a, b) in _runs(u0, u1, gaps)) {
      // sọc trước tấm nền (thứ tự vẽ: phần nền sau sọc bị loại bởi kiểm tra độ sâu)
      for (var k = ((a + 0.04) / stripePitch).ceil(); k * stripePitch + stripeWidth <= b - 0.04; k++) {
        final s0 = k * stripePitch;
        parts.add(_onWall(w, Shop3dColor.mint, s0, s0 + stripeWidth, skirtingHeight, panelH, 0.012, 0.006));
      }
      parts
        ..add(_onWall(w, Shop3dColor.woodDark, a, b, 0, skirtingHeight, 0, 0.03))
        ..add(_onWall(w, Shop3dColor.cream, a, b, skirtingHeight, panelH, 0, 0.012));
    }
    for (final (a, b) in _runs(u0, u1, [...gaps, ...railGaps])) {
      parts.add(_onWall(w, Shop3dColor.caramel, a, b, wainscotTop, 0.05, 0, 0.03));
    }
    parts
      ..add(_onWall(w, Shop3dColor.cream, u0, u1, room.maxY - crownHeight - 0.035, 0.035, 0, 0.03))
      ..add(_onWall(w, Shop3dColor.caramel, u0, u1, room.maxY - crownHeight, crownHeight, 0, 0.06));
    return parts;
  }

  /// Dây cờ đuôi nheo sát tường [w] từ [u0] tới [u1]: [swags] nhịp võng sâu [sag], điểm treo (nút vàng) ở độ cao [top].
  /// Cờ tam giác (lăng trụ đáy 0) bốn màu xen kẽ; dây là các đoạn ngắn nằm ngang theo đường võng (mối nối nằm sau cờ).
  static List<Shop3dPart> _bunting(RoomWall w, double u0, double u1, double top, {int swags = 3, double sag = 0.14}) {
    const colors = [Shop3dColor.strawberry, Shop3dColor.butter, Shop3dColor.mint, Shop3dColor.cream];
    const flagW = 0.17, flagH = 0.23, step = 0.29, t = 0.05;
    final span = (u1 - u0) / swags;
    final perSwag = (span / step).floor();
    final yaw = w == RoomWall.left || w == RoomWall.right ? math.pi / 2 : 0.0;
    double cordY(double f) => top - sag * 4 * f * (1 - f);
    final parts = <Shop3dPart>[];
    var n = 0;
    for (var sw = 0; sw < swags; sw++) {
      final a = u0 + sw * span;
      // nút treo + các điểm của nhịp (f = vị trí trong nhịp 0..1)
      final (hx, hz) = _wallPoint(w, a, t);
      parts.add(Shop3dPart.ball(Shop3dColor.butter, hx, top - 0.03, hz, 0.05));
      final fs = [0.0, for (var i = 0; i < perSwag; i++) (i + 0.5) / perSwag, 1.0];
      for (var i = 0; i + 1 < fs.length; i++) {
        final y = (cordY(fs[i]) + cordY(fs[i + 1])) / 2;
        parts.add(_onWall(w, Shop3dColor.chocolate, a + fs[i] * span, a + fs[i + 1] * span, y - 0.006, 0.012, t - 0.004,
            0.008));
      }
      for (var i = 1; i + 1 < fs.length; i++) {
        final (x, z) = _wallPoint(w, a + fs[i] * span, t);
        final y = cordY(fs[i]);
        parts.add(Shop3dPart.prism(colors[n++ % colors.length], x, y - flagH, z, flagW, flagH, 0.012,
            rotY: yaw, bottomScale: 0));
      }
    }
    final (ex, ez) = _wallPoint(w, u1, t);
    parts.add(Shop3dPart.ball(Shop3dColor.butter, ex, top - 0.03, ez, 0.05));
    return parts;
  }

  /// Bảng phấn menu trên tường bếp (tâm x = [cx]): khung gỗ caramel dày 6 cm, nền chocolate lùi vào, khay phấn có hai
  /// viên phấn. Hình vẽ phấn là khối mảnh dày 8 mm dán trên nền (lớp 2 dán lên lớp 1, cách 8 mm — không nhấp nháy):
  /// tiêu đề + gạch lượn hồng, cupcake (cốc kẻ sọc, ba tầng kem, quả dâu), ly cà phê có tai + khói, ba dòng giả chữ kèm
  /// chấm giá, một dòng chữ dài dưới đáy. Chỉ là các vạch — không có chữ thật.
  static List<Shop3dPart> _chalkMenu(double cx) {
    const bz = -3.975, l1 = bz + 0.004, l2 = bz + 0.012, t = 0.008;
    Shop3dPart chalk(Shop3dColor c, double x, double y0, double w, double h, {double z = l1}) =>
        Shop3dPart.box(c, x, y0, z, w, h, t);
    // chuỗi "từ" giả chữ: các vạch độ rộng khác nhau, cách nhau [gap], bắt đầu từ [x0]
    List<Shop3dPart> words(Shop3dColor c, double x0, double y0, double h, List<double> ws, {double gap = 0.03}) {
      final out = <Shop3dPart>[];
      var x = x0;
      for (final w in ws) {
        out.add(chalk(c, x + w / 2, y0, w, h));
        x += w + gap;
      }
      return out;
    }

    const titleWs = [0.1, 0.06, 0.13, 0.08, 0.11, 0.07, 0.1];
    final titleW = titleWs.fold<double>(0, (a, b) => a + b) + 0.03 * (titleWs.length - 1);
    const ccx = -0.5, cupx = -0.1; // tâm cupcake / ly (so với cx)
    final x = cx + ccx, u = cx + cupx;
    return [
      // khung dày + nền + khay phấn
      Shop3dPart.box(Shop3dColor.caramel, cx, 2.1, -3.97, 1.8, 0.1, 0.06),
      Shop3dPart.box(Shop3dColor.caramel, cx, 1.2, -3.97, 1.8, 0.1, 0.06),
      Shop3dPart.box(Shop3dColor.caramel, cx - 0.85, 1.3, -3.97, 0.1, 0.8, 0.06),
      Shop3dPart.box(Shop3dColor.caramel, cx + 0.85, 1.3, -3.97, 0.1, 0.8, 0.06),
      Shop3dPart.box(Shop3dColor.chocolate, cx, 1.3, -3.985, 1.6, 0.8, 0.02),
      Shop3dPart.box(Shop3dColor.woodDark, cx, 1.16, -3.94, 1.7, 0.04, 0.12),
      Shop3dPart.box(Shop3dColor.cream, cx - 0.5, 1.2, -3.92, 0.09, 0.014, 0.014),
      Shop3dPart.box(Shop3dColor.strawberry, cx - 0.37, 1.2, -3.92, 0.07, 0.014, 0.014),
      // tiêu đề + hai ngôi sao + gạch lượn
      ...words(Shop3dColor.cream, cx - titleW / 2, 1.97, 0.045, titleWs),
      for (var i = 0; i < 9; i++)
        chalk(Shop3dColor.strawberry, cx - 0.28 + i * 0.07, 1.9 + (i.isOdd ? 0.012 : 0), 0.05, 0.012),
      // cupcake: cốc (thang) + sọc, 3 tầng kem (thang thu dần), quả dâu, cốm
      Shop3dPart.prism(Shop3dColor.strawberry, x, 1.44, l1, 0.26, 0.13, t, bottomScale: 0.72),
      for (final dx in const [-0.07, 0.0, 0.07]) chalk(Shop3dColor.cream, x + dx, 1.455, 0.014, 0.1, z: l2),
      Shop3dPart.prism(Shop3dColor.cream, x, 1.57, l1, 0.28, 0.06, t, topScale: 0.78),
      Shop3dPart.prism(Shop3dColor.cream, x, 1.63, l1, 0.22, 0.06, t, topScale: 0.7),
      Shop3dPart.prism(Shop3dColor.cream, x, 1.69, l1, 0.15, 0.07, t, topScale: 0),
      Shop3dPart.ball(Shop3dColor.strawberry, x, 1.755, l1, 0.045),
      chalk(Shop3dColor.butter, x - 0.07, 1.585, 0.02, 0.02, z: l2),
      chalk(Shop3dColor.mint, x + 0.06, 1.645, 0.02, 0.02, z: l2),
      // ly cà phê: đĩa, thân (thang), tai ba nét, khói ba nét lượn
      chalk(Shop3dColor.cream, u, 1.44, 0.28, 0.018),
      Shop3dPart.prism(Shop3dColor.butter, u, 1.458, l1, 0.2, 0.14, t, bottomScale: 0.72),
      chalk(Shop3dColor.cream, u + 0.12, 1.55, 0.07, 0.02, z: l2),
      chalk(Shop3dColor.cream, u + 0.145, 1.51, 0.02, 0.04, z: l2),
      chalk(Shop3dColor.cream, u + 0.1175, 1.49, 0.075, 0.02, z: l2),
      chalk(Shop3dColor.strawberry, u, 1.575, 0.14, 0.012, z: l2),
      for (var i = 0; i < 2; i++) ...[
        chalk(Shop3dColor.cream, u - 0.03 + i * 0.06, 1.63, 0.014, 0.05),
        chalk(Shop3dColor.cream, u - 0.015 + i * 0.06, 1.675, 0.014, 0.05),
      ],
      // ba dòng giả chữ bên phải: chấm đầu dòng hồng, hai "từ" kem, chấm giá vàng
      for (final (i, ws) in const [
        (0, [0.2, 0.1]),
        (1, [0.14, 0.14]),
        (2, [0.22, 0.07]),
      ]) ...[
        chalk(Shop3dColor.strawberry, cx + 0.22, 1.72 - i * 0.12, 0.035, 0.035),
        ...words(Shop3dColor.cream, cx + 0.29, 1.725 - i * 0.12, 0.025, ws, gap: 0.04),
        chalk(Shop3dColor.butter, cx + 0.72, 1.72 - i * 0.12, 0.06, 0.035),
      ],
      // dòng chữ dài dưới đáy
      ...words(Shop3dColor.cream, cx - 0.62, 1.34, 0.03, const [0.18, 0.1, 0.24, 0.08, 0.16, 0.12, 0.1], gap: 0.04),
    ];
  }

  static List<Shop3dPart> _backWall() => [
        const Shop3dPart.box(Shop3dColor.wall, 0, 0, -4.1, 10.4, 3.2, 0.2),
        ..._wainscot(RoomWall.back, -5, 5),
        // gạch ốp sau bàn bếp (trên nẹp ốp tường)
        const Shop3dPart.box(Shop3dColor.floorTile, -1.8, wainscotTop + 0.05, -3.99, 5.6, 0.6, 0.02),
        // kệ lọ kẹo phía trên bàn chuẩn bị: kệ gỗ + 2 con-sơn caramel, lọ màu nhạt nắp đậm + núm
        const Shop3dPart.box(Shop3dColor.woodDark, -0.5, 1.6, -3.85, 3.0, 0.04, 0.3),
        const Shop3dPart.box(Shop3dColor.caramel, -1.55, 1.46, -3.9, 0.04, 0.14, 0.2),
        const Shop3dPart.box(Shop3dColor.caramel, 0.55, 1.46, -3.9, 0.04, 0.14, 0.2),
        for (final (x, body, lid) in const [
          (-1.8, Shop3dColor.mintLight, Shop3dColor.mint),
          (-1.3, Shop3dColor.pinkLight, Shop3dColor.strawberry),
          (-0.8, Shop3dColor.butterLight, Shop3dColor.butter),
          (-0.2, Shop3dColor.cream, Shop3dColor.caramel),
          (0.3, Shop3dColor.mintLight, Shop3dColor.mint),
          (0.8, Shop3dColor.pinkLight, Shop3dColor.strawberry),
        ]) ...[
          Shop3dPart.cyl(body, x, 1.64, -3.85, 0.18, 0.24),
          Shop3dPart.cyl(lid, x, 1.88, -3.85, 0.19, 0.035),
          Shop3dPart.ball(lid, x, 1.9, -3.85, 0.055),
        ],
        // chậu cây nhỏ trên kệ (giữa hai lọ kẹo) + dây lá rủ qua mép kệ
        ..._miniPot(0.55, 1.64, -3.85, bloom: Shop3dColor.strawberry),
        const Shop3dPart.ball(Shop3dColor.leafDeep, 0.5, 1.545, -3.69, 0.085),
        const Shop3dPart.ball(Shop3dColor.correct, 0.6, 1.5, -3.7, 0.07),
        // bảng phấn menu: hình vẽ phấn bằng khối mảnh, không có chữ thật
        ..._chalkMenu(3.6),
        ..._bunting(RoomWall.back, -4.8, 4.8, 2.95),
      ];

  /// Khung ảnh bà trên tường trái, tâm dọc tường tại z = [z]: bốn thanh viền gỗ caramel dày 7 cm, nền kem lùi vào, hình
  /// bóng đơn giản dán nổi 1 cm (búi tóc, đầu, cổ, vai — KHÔNG có mặt) bằng lăng trụ mảnh, hai tông gỗ nâu. Lăng trụ xoay
  /// π/2 để mặt cắt nằm trong mặt phẳng yz (song song tường), dày theo x.
  static List<Shop3dPart> _grandmaFrame(double z) {
    const w = 0.62, y0 = 1.3, h = 0.78, rim = 0.08, rimX = -4.965, sx = -4.94, t = 0.01;
    const q = math.pi / 2;
    return [
      Shop3dPart.box(Shop3dColor.caramel, rimX, y0, z, 0.07, rim, w),
      Shop3dPart.box(Shop3dColor.caramel, rimX, y0 + h - rim, z, 0.07, rim, w),
      Shop3dPart.box(Shop3dColor.caramel, rimX, y0 + rim, z - (w - rim) / 2, 0.07, h - 2 * rim, rim),
      Shop3dPart.box(Shop3dColor.caramel, rimX, y0 + rim, z + (w - rim) / 2, 0.07, h - 2 * rim, rim),
      Shop3dPart.box(Shop3dColor.cream, -4.9725, y0 + rim, z, 0.055, h - 2 * rim, w - 2 * rim),
      // vai (thang thu dần) + cổ
      Shop3dPart.prism(Shop3dColor.woodDark, sx, 1.38, z, 0.4, 0.18, t, rotY: q, topScale: 0.55),
      Shop3dPart.box(Shop3dColor.woodDark, sx, 1.56, z, t, 0.07, 0.08),
      // đầu: ba khối liền nhau (cằm thu, thân, đỉnh thu) — lục giác bầu
      Shop3dPart.prism(Shop3dColor.woodDark, sx, 1.63, z, 0.15, 0.07, t, rotY: q, bottomScale: 0.6),
      Shop3dPart.box(Shop3dColor.woodDark, sx, 1.7, z, t, 0.06, 0.15),
      Shop3dPart.prism(Shop3dColor.chocolate, sx, 1.76, z, 0.15, 0.07, t, rotY: q, topScale: 0.65),
      // búi tóc trên đỉnh đầu
      Shop3dPart.prism(Shop3dColor.chocolate, sx, 1.83, z, 0.09, 0.035, t, rotY: q, bottomScale: 0.55),
      Shop3dPart.prism(Shop3dColor.chocolate, sx, 1.865, z, 0.09, 0.035, t, rotY: q, topScale: 0.55),
    ];
  }

  static List<Shop3dPart> _leftWall() => [
        const Shop3dPart.box(Shop3dColor.wall, -5.1, 0, 0, 0.2, 3.2, 8.0),
        ..._wainscot(RoomWall.left, -4, 4),
        // khung ảnh bà (z = 1,2) + khung tranh mint (z = 2,4)
        ..._grandmaFrame(1.2),
        const Shop3dPart.box(Shop3dColor.caramel, -4.97, 1.4, 2.4, 0.04, 0.55, 0.75),
        const Shop3dPart.box(Shop3dColor.mint, -4.95, 1.47, 2.4, 0.02, 0.4, 0.6),
        ..._bunting(RoomWall.left, -3.7, 3.7, 2.95),
      ];

  static List<Shop3dPart> _rightWall() => [
        const Shop3dPart.box(Shop3dColor.wall, 5.1, 0, 0, 0.2, 3.2, 8.0),
        ..._wainscot(RoomWall.right, -4, 4),
      ];

  /// Rèm hai bên cửa sổ tâm [wx] (rộng [winW]), gắn mặt trong tường trước: thanh treo + hai nút, mỗi bên hai lăng trụ hình
  /// thang (thân rèm thu dần xuống chỗ buộc, rồi xòe ra gấu rèm) + nếp sáng giữa + dây buộc có nút vàng. Cửa 0 và 2 rèm hồng
  /// dâu dây kem, cửa 1 rèm kem dây hồng dâu. Mỗi rèm rộng 0,34 m (cửa 1,6 m) — chừa giữa cửa cho tranh biển.
  static List<Shop3dPart> _curtains(double wx, double winW, int wi) {
    const rz = 3.93, cz = 3.95, t = 0.03, top = 2.33, tie = 1.55, hem = 0.99;
    final cloth = wi == 1 ? Shop3dColor.cream : Shop3dColor.strawberry;
    const fold = Shop3dColor.pinkLight;
    final cord = wi == 1 ? Shop3dColor.strawberry : Shop3dColor.cream;
    final parts = <Shop3dPart>[
      Shop3dPart.box(Shop3dColor.woodDark, wx, top, rz, winW + 0.1, 0.02, 0.02),
      for (final side in const [-1.0, 1.0])
        Shop3dPart.box(Shop3dColor.butter, wx + side * (winW / 2 + 0.07), top - 0.01, rz, 0.04, 0.04, 0.04),
    ];
    for (final side in const [-1.0, 1.0]) {
      final x = wx + side * (winW / 2 - 0.17);
      parts
        ..add(Shop3dPart.prism(cloth, x, tie, cz, 0.34, top - tie, t, bottomScale: 0.5))
        ..add(Shop3dPart.prism(cloth, x, hem, cz, 0.36, tie - hem, t, topScale: 0.47))
        ..add(Shop3dPart.prism(fold, x, tie, cz - 0.02, 0.12, top - tie - 0.05, 0.012, bottomScale: 0.5))
        ..add(Shop3dPart.prism(fold, x, hem + 0.03, cz - 0.02, 0.14, tie - hem - 0.03, 0.012, topScale: 0.4))
        ..add(Shop3dPart.box(cord, x, tie - 0.02, cz - 0.01, 0.2, 0.04, 0.05))
        ..add(Shop3dPart.box(Shop3dColor.butter, x - side * 0.1, tie - 0.03, cz - 0.03, 0.04, 0.05, 0.03));
    }
    return parts;
  }

  /// Chậu treo gần cửa sổ, ở đoạn tường đặc giữa cửa 1 và 2 (tâm x = [x]): giá đỡ ngang bắt vào tường, hai dây mảnh, chậu
  /// nón cụt caramel có viền, tán lá nhiều tông + hoa hồng, ba cụm lá rủ phía dưới. Đáy chậu 1,9 m, lá rủ tới 1,82 m (trên
  /// đầu mọi nhân vật), nhô khỏi tường 0,29 m — chậu cách hàng ghế sau bàn ≥ 1 m.
  static List<Shop3dPart> _hangingPot(double x) {
    const wallZ = 4.0, z = 3.72;
    return [
      Shop3dPart.box(Shop3dColor.woodDark, x, 2.33, wallZ - 0.16, 0.03, 0.03, 0.3),
      Shop3dPart.box(Shop3dColor.woodDark, x, 2.1, wallZ - 0.025, 0.03, 0.26, 0.03),
      Shop3dPart.cyl(Shop3dColor.chocolate, x - 0.05, 2.03, z, 0.01, 0.3),
      Shop3dPart.cyl(Shop3dColor.chocolate, x + 0.05, 2.03, z, 0.01, 0.3),
      Shop3dPart.cone(Shop3dColor.caramel, x, 1.9, z, 0.1, 0.17, 0.11),
      Shop3dPart.cyl(Shop3dColor.woodDark, x, 2.01, z, 0.19, 0.015),
      Shop3dPart.ball(Shop3dColor.correct, x, 1.98, z, 0.2),
      Shop3dPart.ball(Shop3dColor.leafLight, x + 0.06, 2.05, z - 0.02, 0.13),
      Shop3dPart.ball(Shop3dColor.strawberry, x - 0.05, 2.1, z + 0.04, 0.05),
      Shop3dPart.ball(Shop3dColor.leafDeep, x - 0.07, 1.855, z + 0.02, 0.09),
      Shop3dPart.ball(Shop3dColor.correct, x + 0.06, 1.835, z - 0.03, 0.08),
      Shop3dPart.ball(Shop3dColor.leafLight, x, 1.82, z + 0.07, 0.07),
    ];
  }

  /// Tường trước: 3 cửa sổ (đối diện 3 bàn) + cửa ra vào (x ≈ 3,6). Cửa sổ: khung + song bạc hà, kính trong
  /// ([glassAlpha]), bệ cửa dày, mái hiên mini sọc hồng-kem có diềm sóng phía trong, tranh cảnh biển ngay sau kính (trời
  /// đào → xanh nhạt, biển bạc hà, mây, thuyền, mặt trời — khối màu đỉnh, nằm trong bề dày tường nên chỉ thấy qua ô
  /// kính). Trên cửa ra vào: biển hiệu gỗ hình bánh cupcake cách điệu (không có chữ).
  static List<Shop3dPart> _frontWall() {
    const winCenters = tableXs;
    const winW = 1.6;
    const winBottom = 0.9;
    const winTop = 2.4;
    const doorX = 3.6;
    const doorW = 1.1;
    const doorTop = 2.3;
    const z = 4.1;
    const inner = 4.0; // mặt trong tường
    const scene = 4.235; // tranh cảnh biển (sau mặt ngoài tường 4,2)

    final parts = <Shop3dPart>[];
    // đoạn tường đặc, cao hết phòng, xen giữa các ô mở
    const solids = [(-5.2, -4.6), (-3.0, -2.4), (-0.8, -0.2), (1.4, 3.05), (4.15, 5.2)];
    for (final s in solids) {
      parts.add(Shop3dPart.box(Shop3dColor.wallFront, (s.$1 + s.$2) / 2, 0, z, s.$2 - s.$1, 3.2, 0.2));
    }
    for (var wi = 0; wi < winCenters.length; wi++) {
      final wx = winCenters[wi];
      parts
        ..add(Shop3dPart.box(Shop3dColor.wallFront, wx, 0, z, winW, winBottom, 0.2))
        ..add(Shop3dPart.box(Shop3dColor.wallFront, wx, winTop, z, winW, 3.2 - winTop, 0.2))
        ..add(Shop3dPart.box(Shop3dColor.glass, wx, winBottom, z, winW, winTop - winBottom, 0.03, alpha: glassAlpha))
        // khung bạc hà quanh ô cửa (mặt trong) + song chữ thập + bệ cửa dày
        ..add(Shop3dPart.box(Shop3dColor.mint, wx - winW / 2 - 0.03, winBottom, inner - 0.015, 0.06, winTop - winBottom + 0.06,
            0.03))
        ..add(Shop3dPart.box(Shop3dColor.mint, wx + winW / 2 + 0.03, winBottom, inner - 0.015, 0.06, winTop - winBottom + 0.06,
            0.03))
        ..add(Shop3dPart.box(Shop3dColor.mint, wx, winTop, inner - 0.015, winW + 0.12, 0.06, 0.03))
        ..add(Shop3dPart.box(Shop3dColor.mint, wx, winBottom, z, 0.05, winTop - winBottom, 0.08))
        ..add(Shop3dPart.box(Shop3dColor.mint, wx, 1.6, z, winW, 0.05, 0.08))
        ..add(Shop3dPart.box(Shop3dColor.caramel, wx, winBottom - 0.06, 3.94, winW + 0.16, 0.1, 0.34));
      // tranh cảnh biển: các dải màu liền nhau (không chồng), mây / thuyền / mặt trời nhô trước tranh, sau kính
      for (final (y0, y1, c) in const [
        (0.86, 1.2, Shop3dColor.sea),
        (1.2, 1.46, Shop3dColor.seaLight),
        (1.46, 1.8, Shop3dColor.peach),
        (1.8, 2.44, Shop3dColor.sky),
      ]) {
        parts.add(Shop3dPart.box(c, wx, y0, scene, winW + 0.12, y1 - y0, 0.02));
      }
      final (cloudX, cloudY) = const [(-0.35, 2.06), (0.3, 2.16), (-0.2, 2.0)][wi % 3];
      parts
        ..add(Shop3dPart.ball(Shop3dColor.cloud, wx + cloudX - 0.1, cloudY, scene - 0.02, 0.11))
        ..add(Shop3dPart.ball(Shop3dColor.cloud, wx + cloudX, cloudY + 0.02, scene - 0.02, 0.14))
        ..add(Shop3dPart.ball(Shop3dColor.cloud, wx + cloudX + 0.1, cloudY, scene - 0.02, 0.1));
      if (wi == 1) {
        parts
          ..add(Shop3dPart.prism(Shop3dColor.hull, wx - 0.3, 1.27, scene - 0.013, 0.17, 0.045, 0.01, bottomScale: 0.65))
          ..add(Shop3dPart.prism(Shop3dColor.cloud, wx - 0.3, 1.315, scene - 0.013, 0.1, 0.13, 0.01, topScale: 0));
      } else if (wi == 2) {
        parts.add(Shop3dPart.ball(Shop3dColor.sun, wx + 0.4, 1.56, scene - 0.01, 0.13));
      }
      parts.addAll(_curtains(wx, winW, wi));
      // chậu cây nhỏ trên bệ cửa sổ (cửa trái: lá rủ; cửa giữa: có hoa), cách rèm và thuyền buồm
      if (wi == 0) {
        parts.addAll(_miniPot(wx - 0.3, 0.94, 3.9, leaf: Shop3dColor.leafDeep, bloom: Shop3dColor.butter, trail: -1));
      }
      if (wi == 1) {
        parts.addAll(_miniPot(wx + 0.3, 0.94, 3.9,
            pot: Shop3dColor.strawberry, leaf: Shop3dColor.leafLight, bloom: Shop3dColor.strawberry));
      }
      // mái hiên mini sọc hồng-kem phía trong (nửa lăng trụ chìm trong tường) + diềm sóng
      const stripes = 11, valY = winTop + 0.04, valH = 0.2, valD = 0.5;
      const sw = (winW + 0.16) / stripes;
      for (var i = 0; i < stripes; i++) {
        final sx = wx - (winW + 0.16) / 2 + (i + 0.5) * sw;
        final c = i.isEven ? Shop3dColor.strawberry : Shop3dColor.cream;
        parts
          ..add(Shop3dPart.prism(c, sx, valY, inner, valD, valH, sw, rotY: math.pi / 2, topScale: 0))
          ..add(Shop3dPart.scallop(c, sx, valY - 0.07, inner - valD / 2 + 0.006, sw, 0.07, 0.012));
      }
    }
    parts
      // trên cửa ra vào + khung cửa
      ..add(Shop3dPart.box(Shop3dColor.wallFront, doorX, doorTop, z, doorW, 3.2 - doorTop, 0.2))
      ..add(Shop3dPart.box(Shop3dColor.caramel, doorX - doorW / 2 - 0.04, 0, z, 0.08, doorTop, 0.26))
      ..add(Shop3dPart.box(Shop3dColor.caramel, doorX + doorW / 2 + 0.04, 0, z, 0.08, doorTop, 0.26))
      ..add(Shop3dPart.box(Shop3dColor.caramel, doorX, doorTop, z, doorW + 0.2, 0.08, 0.26))
      // biển "mở cửa" treo ở cửa sổ giữa-phải
      ..add(const Shop3dPart.box(Shop3dColor.butter, 0.6, 1.9, 3.97, 0.4, 0.22, 0.03))
      // biển hiệu gỗ trên cửa: khung caramel, nền gỗ sáng, bánh cupcake (cốc hồng, kem, quả dâu) + lá bạc hà hai bên
      ..add(const Shop3dPart.box(Shop3dColor.caramel, doorX, 2.47, inner - 0.015, 1.0, 0.44, 0.03))
      ..add(const Shop3dPart.box(Shop3dColor.woodLight, doorX, 2.51, inner - 0.036, 0.9, 0.36, 0.012))
      ..add(const Shop3dPart.prism(Shop3dColor.strawberry, doorX, 2.56, inner - 0.06, 0.16, 0.1, 0.035, bottomScale: 0.7))
      ..add(const Shop3dPart.ball(Shop3dColor.cream, doorX - 0.045, 2.62, inner - 0.055, 0.085))
      ..add(const Shop3dPart.ball(Shop3dColor.cream, doorX + 0.045, 2.62, inner - 0.055, 0.085))
      ..add(const Shop3dPart.ball(Shop3dColor.cream, doorX, 2.67, inner - 0.055, 0.08))
      ..add(const Shop3dPart.ball(Shop3dColor.strawberry, doorX, 2.745, inner - 0.055, 0.035));
    parts.addAll(_hangingPot(-0.5));
    for (final side in const [-1.0, 1.0]) {
      parts
        ..add(Shop3dPart.ball(Shop3dColor.mint, doorX + side * 0.25, 2.64, inner - 0.045, 0.075))
        ..add(Shop3dPart.ball(Shop3dColor.correct, doorX + side * 0.32, 2.6, inner - 0.045, 0.055));
    }
    parts.addAll(_wainscot(RoomWall.front, -5, 5, gaps: const [
      (doorX - doorW / 2 - 0.08, doorX + doorW / 2 + 0.08),
    ], railGaps: [
      for (final wx in winCenters) (wx - winW / 2 - 0.08, wx + winW / 2 + 0.08),
    ]));
    return parts;
  }
}
