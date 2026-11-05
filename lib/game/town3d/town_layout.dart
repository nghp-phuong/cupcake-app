import 'dart:math' as math;

import '../../core/city/city_config.dart';
import '../shop3d/interact/shop3d_nav.dart' show NavBox;
import '../shop3d/shop3d_layout.dart';

/// Bố cục thành phố V3 bằng hằng số — Dart thuần, không phụ thuộc engine (docs/v3/city-gd1-spec.md).
///
/// Hệ toạ độ lớp phố (mét, y hướng lên, mặt đường y ≈ 0), độc lập với nội thất. Hướng nhìn của [TownPoint.yaw] cùng
/// quy ước với `Shop3dSpot.facingYaw`: hướng nhìn = (sin yaw, 0, cos yaw), yaw 0 nhìn +z.
///
/// Quận 1 "Phố Tiệm Bánh" (`bakery_street`): lòng đường z ∈ [-3, 3] chạy dọc trục x, vỉa hè hai bên tới |z| = 5,5; hàng
/// lô bắc (cửa quay +z) và hàng lô nam (cửa quay -z). Mọi hình đều là khối màu đỉnh low-poly (`Shop3dPart`), không chữ,
/// không texture; đồ tĩnh gộp lưới theo ô 16 m ở `town_batches.dart`.
///
/// Mặt tiền mỗi lô dựng trong "khung lô" (l = sang phải khi nhìn từ phố vào, d = độ sâu từ mép lô giáp vỉa hè, lô bắc
/// d = -z - 5,5, lô nam d = z - 5,5) rồi đổi sang toạ độ thế giới. Nhà cao ~4,4 m, mái tới ~5,6 m, mặt tiền lùi 0,9 m so
/// với mép lô (hiên nhỏ có thể đi lên, cửa không bị tường chắn). Quầy quán ăn / tiệm tóc: ô cửa ở mặt tiền, chủ quán
/// đứng trong hốc (keeper), Mai đứng trên vỉa hè trước ô cửa (counter).
class TownPoint {
  const TownPoint(this.x, this.z, [this.yaw = 0]);

  final double x, z, yaw;

  @override
  String toString() =>
      'TownPoint(${x.toStringAsFixed(2)}, ${z.toStringAsFixed(2)}, yaw ${yaw.toStringAsFixed(2)})';
}

/// Các điểm tương tác của một lô. [yaw] của từng điểm là hướng nhìn của người đứng ở đó:
/// - [door]: Mai đứng ở mép lô (đúng `LotDef.doorX/doorZ`), quay vào lô;
/// - [counter]: Mai đứng trên vỉa hè trước ô cửa quầy, quay vào ô cửa (chỉ quán ăn, tiệm tóc);
/// - [keeper]: chủ quán NPC đứng trong hốc sau ô cửa, quay ra phố — nằm trong hộp chặn (Mai không tới được);
/// - [seat]: ghế hiên của quán ăn, Mai ngồi, quay vào bàn.
class TownLotSpots {
  const TownLotSpots({
    required this.lotId,
    required this.door,
    this.counter,
    this.keeper,
    this.seat,
  });

  final String lotId;
  final TownPoint door;
  final TownPoint? counter;
  final TownPoint? keeper;
  final TownPoint? seat;
}

/// Một hình hộp phẳng của mặt đất (đường, vỉa hè, cỏ, cát, biển). Màu tuỳ ý [argb] (0xAARRGGBB, chỉ dùng RGB): màu
/// của `Shop3dColor.backdrop` (vd. `sea`) sẽ tự thành bề mặt không chịu ánh sáng. Mặt trên ở [top], đáy ở [bottom].
class TownGroundTile {
  TownGroundTile(
    this.argb,
    this.minX,
    this.maxX,
    this.minZ,
    this.maxZ, {
    this.top = 0,
    double? bottom,
  }) : bottom = bottom ?? top - 0.12;

  final int argb;
  final double minX, maxX, minZ, maxZ;
  final double top, bottom;
}

/// Bố cục tĩnh của một quận: đồ dựng, mặt đất, hộp chặn điều hướng, điểm tương tác. Dựng một lần cho mỗi quận
/// ([forDistrict] nhớ kết quả); danh sách trả về không được sửa.
class TownLayout {
  TownLayout._(
    this.district,
    this.props,
    this.ground,
    this.blockers,
    this.spots,
    this.spawn,
    this.bus,
  );

  static final Expando<TownLayout> _cache = Expando<TownLayout>('TownLayout');

  /// Bố cục của quận [d] (quận không có lô vẫn có đường, vỉa hè, đất, biên).
  static TownLayout forDistrict(DistrictDef d) =>
      _cache[d] ??= _TownBuilder(d).build();

  final DistrictDef district;

  /// Đồ tĩnh (mặt tiền, cây, đèn, ghế…), toàn bộ `pickable: false` → gộp lưới (`town_batches.dart`).
  final List<Shop3dProp> props;

  /// Mặt đất: đường, vỉa hè, cỏ, cát, biển (gồm cả phần ngoài biên quận để cảnh không lơ lửng).
  final List<TownGroundTile> ground;

  /// Hộp chặn điều hướng (mặt phẳng xz): nhà, hàng rào, cây, bàn ghế, cột đèn và biên quận. Dùng cho bộ điều hướng
  /// thành phố (`Shop3dNav(blockers, addWalls: false)` có biên thế giới cứng 15 × 13 m nên KHÔNG dùng được cho quận).
  final List<NavBox> blockers;

  /// Điểm tương tác theo id lô (`LotDef.id`); mọi lô có mục, `counter` / `keeper` / `seat` chỉ khi có.
  final Map<String, TownLotSpots> spots;

  /// Chỗ Mai xuất hiện (`DistrictDef.spawnX/spawnZ`), quay vào cửa tiệm của bà.
  final TownPoint spawn;

  /// Điểm đứng chờ xe buýt (`DistrictDef.busX/busZ`), quay ra đường.
  final TownPoint bus;

  double get minX => district.minX;
  double get maxX => district.maxX;
  double get minZ => district.minZ;
  double get maxZ => district.maxZ;
}

typedef _C = Shop3dColor;

// ---- Màu mặt đất (ngoài bảng Shop3dColor) ------------------------------------------------------------------------
const int _roadArgb = 0xFFBFCBD3; // xám xanh nhạt
const int _sidewalkArgb = 0xFFEBDCC4; // kem ấm
const int _curbArgb = 0xFFFBF1E0;
const int _paverArgb = 0xFFF9F0E1; // = Shop3dColor.pavingLight
const int _grassArgb = 0xFFC3E6AE;
const int _sandArgb = 0xFFF5E3B8;
const int _paving = 0xFFF2E6D2;
const int _deckArgb = 0xFFEFD4AF; // ván hiên
const int _plazaArgb = 0xFFF5E8D2;

const double _roadTop = -0.03;
const double _grassTop = -0.02;

/// Khung đổi toạ độ: thế giới x = [ox] + [sx]·l, z = [oz] + [sz]·d.
class _F {
  const _F(this.ox, this.oz, this.sx, this.sz);
  const _F.world() : this(0, 0, 1, 1);

  final double ox, oz, sx, sz;

  double x(double l) => ox + sx * l;
  double z(double d) => oz + sz * d;

  (double, double, double, double) rect(
    double l0,
    double l1,
    double d0,
    double d1,
  ) {
    final xa = x(l0), xb = x(l1), za = z(d0), zb = z(d1);
    return (
      math.min(xa, xb),
      math.max(xa, xb),
      math.min(za, zb),
      math.max(za, zb),
    );
  }
}

/// Nơi gom khối / hộp chặn / mặt đất của một nhóm đồ, dựng theo khung [f].
class _Sink {
  _Sink(this.f, this.parts, this.blockers, this.ground);

  final _F f;
  final List<Shop3dPart> parts;
  final List<NavBox> blockers;
  final List<TownGroundTile> ground;

  /// Hộp tâm (l, d), đáy y0, rộng w (theo x thế giới), cao h, sâu dd (theo z thế giới).
  void box(
    _C c,
    double l,
    double y0,
    double d,
    double w,
    double h,
    double dd, {
    double rotY = 0,
  }) => parts.add(Shop3dPart.box(c, f.x(l), y0, f.z(d), w, h, dd, rotY: rotY));

  /// Hộp theo khoảng [l0, l1] × [y0, y1] × [d0, d1].
  void boxR(
    _C c,
    double l0,
    double l1,
    double y0,
    double y1,
    double d0,
    double d1,
  ) => box(c, (l0 + l1) / 2, y0, (d0 + d1) / 2, l1 - l0, y1 - y0, d1 - d0);

  void cyl(_C c, double l, double y0, double d, double dia, double h) =>
      parts.add(Shop3dPart.cyl(c, f.x(l), y0, f.z(d), dia, h));

  void cone(
    _C c,
    double l,
    double y0,
    double d,
    double bottomDia,
    double topDia,
    double h,
  ) => parts.add(Shop3dPart.cone(c, f.x(l), y0, f.z(d), bottomDia, topDia, h));

  void ball(_C c, double l, double y0, double d, double dia) =>
      parts.add(Shop3dPart.ball(c, f.x(l), y0, f.z(d), dia));

  void prism(
    _C c,
    double l,
    double y0,
    double d,
    double w,
    double h,
    double dd, {
    double rotY = 0,
    double topScale = 1,
    double bottomScale = 1,
  }) => parts.add(
    Shop3dPart.prism(
      c,
      f.x(l),
      y0,
      f.z(d),
      w,
      h,
      dd,
      rotY: rotY,
      topScale: topScale,
      bottomScale: bottomScale,
    ),
  );

  /// Bông hoa / nụ nhỏ dạng khối lập phương xoay 45° (12 tam giác, rẻ hơn cầu 64 tam giác), đáy ở [y0].
  void bloom(_C c, double l, double y0, double d, double size) =>
      box(c, l, y0, d, size, size, size, rotY: math.pi / 4);

  void scallop(
    _C c,
    double l,
    double y0,
    double d,
    double w,
    double h,
    double dd,
  ) => parts.add(Shop3dPart.scallop(c, f.x(l), y0, f.z(d), w, h, dd));

  void block(double l0, double l1, double d0, double d1) {
    final (a, b, c, e) = f.rect(l0, l1, d0, d1);
    blockers.add(NavBox(a, b, c, e));
  }

  void blockC(double l, double d, double w, double dd) =>
      block(l - w / 2, l + w / 2, d - dd / 2, d + dd / 2);

  void tile(
    int argb,
    double l0,
    double l1,
    double d0,
    double d1, {
    double top = 0,
    double? bottom,
  }) {
    final (a, b, c, e) = f.rect(l0, l1, d0, d1);
    ground.add(TownGroundTile(argb, a, b, c, e, top: top, bottom: bottom));
  }
}

class _TownBuilder {
  _TownBuilder(this.d);

  final DistrictDef d;
  final props = <Shop3dProp>[];
  final ground = <TownGroundTile>[];
  final blockers = <NavBox>[];
  final spots = <String, TownLotSpots>{};

  static const double _pi = math.pi;

  TownLayout build() {
    _terrain();
    _street();
    for (final lot in d.lots) {
      _lot(lot);
    }
    _busStop();
    _boundary();
    _beach();
    return TownLayout._(
      d,
      List.unmodifiable(props),
      List.unmodifiable(ground),
      List.unmodifiable(blockers),
      Map.unmodifiable(spots),
      TownPoint(d.spawnX, d.spawnZ, _pi),
      TownPoint(d.busX, d.busZ, 0),
    );
  }

  _Sink _sink(_F f, List<Shop3dPart> parts) =>
      _Sink(f, parts, blockers, ground);

  void _emit(
    String id,
    List<Shop3dPart> parts, [
    Shop3dZone zone = Shop3dZone.decor,
  ]) {
    if (parts.isEmpty) return;
    props.add(Shop3dProp(id, zone, List.unmodifiable(parts), pickable: false));
  }

  // ---- Mặt đất -------------------------------------------------------------------------------------------------

  void _terrain() {
    final so = d.sidewalkOuter;
    const far = 64.0;
    ground
      // trong biên: cỏ sau hai hàng vỉa hè
      ..add(
        TownGroundTile(_grassArgb, d.minX, d.maxX, d.minZ, -so, top: _grassTop),
      )
      ..add(
        TownGroundTile(_grassArgb, d.minX, d.maxX, so, d.maxZ, top: _grassTop),
      )
      // ngoài biên: cỏ phía tây / đông / bắc
      ..add(
        TownGroundTile(
          _grassArgb,
          d.minX - far,
          d.minX,
          d.minZ - far,
          d.maxZ,
          top: _grassTop,
        ),
      )
      ..add(
        TownGroundTile(
          _grassArgb,
          d.maxX,
          d.maxX + far,
          d.minZ - far,
          d.maxZ,
          top: _grassTop,
        ),
      )
      ..add(
        TownGroundTile(
          _grassArgb,
          d.minX,
          d.maxX,
          d.minZ - far,
          d.minZ,
          top: _grassTop,
        ),
      );
  }

  /// Dải cát + biển phẳng phía nam ngoài hàng lô (biển và bọt sóng không chịu ánh sáng), vài đồ bãi biển.
  void _beach() {
    const far = 64.0, sand = 3.5;
    final z0 = d.maxZ;
    ground
      ..add(
        TownGroundTile(
          _sandArgb,
          d.minX - far,
          d.maxX + far,
          z0,
          z0 + sand,
          top: _grassTop,
        ),
      )
      ..add(
        TownGroundTile(
          _C.sea.argb,
          d.minX - far,
          d.maxX + far,
          z0 + sand,
          z0 + far,
          top: -0.1,
        ),
      )
      ..add(
        TownGroundTile(
          _C.cloud.argb,
          d.minX - far,
          d.maxX + far,
          z0 + sand - 0.2,
          z0 + sand + 0.4,
          top: -0.06,
        ),
      );
    final w = _F.world();
    final parts = <Shop3dPart>[];
    final s = _sink(w, parts);
    final zb = z0 + sand + 2.4;
    // thuyền buồm nhỏ trên biển (thân lăng trụ, cột, buồm tam giác)
    for (final x in [d.minX * 0.55, d.maxX * 0.6]) {
      s.prism(_C.caramel, x, -0.08, zb, 2.0, 0.42, 0.8, bottomScale: 0.55);
      s.boxR(_C.woodLight, x - 0.5, x + 0.5, 0.3, 0.36, zb - 0.28, zb + 0.28);
      s.cyl(_C.woodDark, x - 0.1, 0.4, zb, 0.06, 1.7);
      s.prism(_C.cream, x - 0.1, 0.65, zb, 1.0, 1.3, 0.04, topScale: 0.0);
      s.prism(_C.strawberry, x - 0.62, 0.55, zb, 0.5, 0.9, 0.04, topScale: 0.0);
    }
    // ô dù + khăn trải trên cát
    for (final (x, c1, c2) in [
      (d.minX * 0.2, _C.strawberry, _C.cream),
      (d.maxX * 0.35, _C.mint, _C.butterLight),
    ]) {
      final z = z0 + 1.7;
      s.cyl(_C.woodLight, x, 0, z, 0.05, 1.8);
      s.cone(c1, x, 1.5, z, 1.7, 0.1, 0.32);
      s.ball(c2, x, 1.8, z, 0.09);
      s.boxR(c2, x + 0.4, x + 1.5, 0, 0.012, z - 0.5, z + 0.5);
    }
    _emit('beach', parts);
  }

  // ---- Phố: đường, vỉa hè, vạch, đèn, bồn hoa -----------------------------------------------------------------------

  void _street() {
    final rh = d.roadHalfWidth, so = d.sidewalkOuter;
    ground.add(
      TownGroundTile(_roadArgb, d.minX, d.maxX, -rh, rh, top: _roadTop),
    );
    for (final north in [true, false]) {
      final a = north ? -so : rh, b = north ? -rh : so;
      ground.add(TownGroundTile(_sidewalkArgb, d.minX, d.maxX, a, b));
      // lề bó vỉa
      final c0 = north ? -rh - 0.14 : rh, c1 = north ? -rh : rh + 0.14;
      ground.add(TownGroundTile(_curbArgb, d.minX, d.maxX, c0, c1, top: 0.02));
      // gạch lát kem so le (chỉ ô sáng, ô còn lại lộ nền vỉa hè), 2 hàng
      final za = north ? -so : rh + 0.14, zb = north ? -rh - 0.14 : so;
      const w = 2.0, gap = 0.03;
      final rowD = (zb - za) / 2;
      for (var r = 0; r < 2; r++) {
        final shift = r.isOdd ? w / 2 : 0.0;
        for (var c = -1; c < (d.maxX - d.minX) / w + 1; c++) {
          if ((r + c).isOdd) continue;
          final x0 = math.max(d.minX, d.minX + c * w + shift),
              x1 = math.min(d.maxX, d.minX + (c + 1) * w + shift);
          if (x1 - x0 < 0.1) continue;
          ground.add(
            TownGroundTile(
              _paverArgb,
              x0 + gap / 2,
              x1 - gap / 2,
              za + r * rowD + gap / 2,
              za + (r + 1) * rowD - gap / 2,
              top: 0.012,
              bottom: -0.01,
            ),
          );
        }
      }
    }

    final parts = <Shop3dPart>[];
    final s = _sink(_F.world(), parts);
    // vạch qua đường trắng (6 vạch) + vạch tim đường đứt
    final crossX = [for (var k = 1; k <= 3; k++) d.minX + 12.0 * k];
    for (final cx in crossX) {
      for (var i = 0; i < 6; i++) {
        s.boxR(
          _C.cream,
          cx + (i - 2.5) * 0.8 - 0.21,
          cx + (i - 2.5) * 0.8 + 0.21,
          _roadTop - 0.01,
          _roadTop + 0.015,
          -rh + 0.25,
          rh - 0.25,
        );
      }
    }
    for (var x = d.minX + 1.0; x + 1.4 < d.maxX - 1; x += 3.2) {
      if (crossX.any((cx) => (x + 0.7 - cx).abs() < 3.3)) continue;
      s.boxR(
        _C.butterLight,
        x,
        x + 1.4,
        _roadTop - 0.01,
        _roadTop + 0.015,
        -0.06,
        0.06,
      );
    }
    _emit('street:markings', parts);

    // cột đèn kiểu cổ thấp ở chỗ giữa hai lô
    final lamps = <Shop3dPart>[];
    final ls = _sink(_F.world(), lamps);
    for (final x in crossX) {
      for (final zSide in [-1.0, 1.0]) {
        _lamp(ls, x, zSide * (rh + 0.5));
      }
    }
    _emit('street:lamps', lamps);

    // bồn hoa dọc lề đường
    final beds = <Shop3dPart>[];
    final bs = _sink(_F.world(), beds);
    var k = 0;
    for (final x in [
      for (final o in const [9.0, 21.0, 39.0]) d.minX + o,
    ]) {
      _planter(bs, x, -(rh + 0.6), k++);
    }
    for (final x in [
      for (final o in const [15.0, 27.0, 39.0]) d.minX + o,
    ]) {
      _planter(bs, x, rh + 0.6, k++);
    }
    _emit('street:planters', beds);
  }

  /// Cột đèn cổ: chân nón cụt, thân mảnh, chao đèn vàng ấm (không chịu ánh sáng), mũ nón + núm.
  void _lamp(_Sink s, double x, double z) {
    s.cone(_C.woodDark, x, 0, z, 0.34, 0.18, 0.25);
    s.cyl(_C.woodDark, x, 0.25, z, 0.09, 1.95);
    s.box(_C.caramel, x, 2.15, z, 0.22, 0.06, 0.22);
    s.box(_C.sun, x, 2.21, z, 0.26, 0.34, 0.26);
    s.cone(_C.woodDark, x, 2.55, z, 0.42, 0.0, 0.2);
    s.bloom(_C.butter, x, 2.73, z, 0.08);
    s.blockC(x, z, 0.3, 0.3);
  }

  /// Bồn hoa gỗ dài 1,6 m: đất, ba bụi lá hình nón cụt, ba bông; [k] đổi màu hoa.
  void _planter(_Sink s, double x, double z, int k) {
    const cols = [
      [_C.strawberry, _C.butter, _C.pinkLight],
      [_C.butter, _C.strawberry, _C.cream],
      [_C.pinkLight, _C.mint, _C.strawberry],
    ];
    final bloom = cols[k % cols.length];
    s.boxR(_C.woodLight, x - 0.8, x + 0.8, 0, 0.4, z - 0.25, z + 0.25);
    s.boxR(_C.chocolate, x - 0.74, x + 0.74, 0.4, 0.43, z - 0.19, z + 0.19);
    for (var i = 0; i < 3; i++) {
      final lx = x + (i - 1) * 0.5;
      s.cone(i == 1 ? _C.leafLight : _C.leafDeep, lx, 0.43, z, 0.44, 0.22, 0.3);
      s.bloom(bloom[i], lx - 0.04, 0.7, z + 0.02, 0.13);
    }
    s.block(x - 0.8, x + 0.8, z - 0.25, z + 0.25);
  }

  // ---- Biên quận + hai đầu phố ----------------------------------------------------------------------------------

  void _boundary() {
    // Hộp chặn quanh biên (mép trong lùi 0,4 m — hàng rào / bụi cây ở sát biên).
    const e = 0.4, far = 40.0;
    blockers
      ..add(NavBox(d.minX - far, d.minX + e, d.minZ - far, d.maxZ + far))
      ..add(NavBox(d.maxX - e, d.maxX + far, d.minZ - far, d.maxZ + far))
      ..add(NavBox(d.minX, d.maxX, d.minZ - far, d.minZ + e))
      ..add(NavBox(d.minX, d.maxX, d.maxZ - e, d.maxZ + far));
    final rh = d.roadHalfWidth, so = d.sidewalkOuter;
    for (final sgn in [-1.0, 1.0]) {
      final parts = <Shop3dPart>[];
      final s = _sink(_F.world(), parts);
      // l = khoảng lùi vào trong quận tính từ biên (x thế giới = biên - sgn·l).
      final bx = sgn < 0 ? d.minX : d.maxX;
      double x(double l) => bx - sgn * l;
      // bụi cây thấp trên hai vỉa hè
      for (final zs in [-1.0, 1.0]) {
        final z0 = zs * (rh + 0.14), z1 = zs * so;
        s.boxR(
          _C.leafDeep,
          math.min(x(0), x(0.4)),
          math.max(x(0), x(0.4)),
          0,
          0.7,
          math.min(z0, z1),
          math.max(z0, z1),
        );
        s.boxR(
          _C.leafLight,
          math.min(x(0.02), x(0.34)),
          math.max(x(0.02), x(0.34)),
          0.7,
          0.84,
          math.min(z0, z1) + 0.04,
          math.max(z0, z1) - 0.04,
        );
      }
      // thanh chắn sọc hồng - kem chắn ngang lòng đường
      final xb = x(0.2);
      for (final z in [-rh + 0.3, 0.0, rh - 0.3]) {
        s.boxR(_C.cream, xb - 0.07, xb + 0.07, 0, 0.95, z - 0.07, z + 0.07);
      }
      for (var i = 0; i < 6; i++) {
        final z0 = -rh + i * (2 * rh / 6), z1 = z0 + 2 * rh / 6;
        final c = i.isEven ? _C.strawberry : _C.cream;
        s.boxR(c, xb - 0.04, xb + 0.04, 0.68, 0.8, z0, z1);
        s.boxR(c, xb - 0.04, xb + 0.04, 0.4, 0.5, z0, z1);
      }
      _emit('boundary:${sgn < 0 ? 'west' : 'east'}', parts);
    }
  }

  // ---- Lô ------------------------------------------------------------------------------------------------------

  void _lot(LotDef lot) {
    final north = math.cos(lot.yaw) > 0;
    final f = _F(lot.doorX, lot.doorZ, north ? 1 : -1, north ? -1 : 1);
    // Quay vào trong lô: lô bắc nhìn -z (yaw π), lô nam nhìn +z (yaw 0).
    final inYaw = north ? _pi : 0.0;
    final door = TownPoint(lot.doorX, lot.doorZ, inYaw);
    final parts = <Shop3dPart>[];
    final s = _sink(f, parts);
    TownLotSpots lotSpots = TownLotSpots(lotId: lot.id, door: door);
    switch (lot.kind) {
      case LotKind.home:
        _home(s);
      case LotKind.restaurant:
        lotSpots = _restaurant(s, f, lot, door, inYaw);
      case LotKind.salon:
        lotSpots = _salon(s, f, lot, door, inYaw);
      case LotKind.realty:
        _realty(s);
      case LotKind.park:
        _park(s, f, lot);
      case LotKind.branch:
        _emptyLot(s, lot);
    }
    spots[lot.id] = lotSpots;
    // Bụi cây chắn khe 1 m giữa hai lô cạnh nhau (ở lô cuối hàng thì chắn bên trái: biên quận đã chặn bên kia).
    _gapBush(lot, f);
    _emit('lot:${lot.id}', parts, Shop3dZone.entrance);
  }

  /// Bụi cây ở khe giữa lô này và lô kế bên phải (theo trục x thế giới), chỉ ở mép vỉa hè.
  void _gapBush(LotDef lot, _F f) {
    final right = lot.x + lot.w / 2;
    if (right > d.maxX - 1) return;
    final north = f.sz < 0;
    final parts = <Shop3dPart>[];
    final s = _sink(_F.world(), parts);
    final gx = right + 0.5; // tâm khe (lô rộng 11, cách nhau 1 m)
    final z0 = north ? lot.doorZ - 1.5 : lot.doorZ,
        z1 = north ? lot.doorZ : lot.doorZ + 1.5;
    final zc = (z0 + z1) / 2;
    s.boxR(_C.leafDeep, gx - 0.7, gx + 0.7, 0, 0.75, z0, z1);
    if (north) {
      // phía bắc nhìn kỹ từ phố: thêm hai chỏm lá tròn + bông
      s.ball(_C.leafLight, gx - 0.28, 0.6, zc, 0.44);
      s.ball(_C.correct, gx + 0.28, 0.62, zc - 0.1, 0.42);
      s.bloom(_C.strawberry, gx, 0.9, zc + 0.35, 0.12);
    } else {
      s.boxR(_C.leafLight, gx - 0.6, gx + 0.6, 0.75, 0.9, z0 + 0.1, z1 - 0.1);
    }
    s.blockC(gx, zc, 1.4, z1 - z0);
    _emit('gap:${lot.id}', parts);
  }

  // ---- Hạng mục dùng chung ------------------------------------------------------------------------------------------

  /// Thân nhà: tường [wall] cao [h] trên [l0, l1] × [d0, d1], chân tường [plinth] cao 0,5 m, gờ mái [trim].
  void _shell(
    _Sink s,
    _C wall,
    _C plinth,
    _C trim,
    double l0,
    double l1,
    double d0,
    double d1,
    double h,
  ) {
    s.boxR(wall, l0, l1, 0, h, d0, d1);
    s.boxR(plinth, l0 - 0.06, l1 + 0.06, 0, 0.5, d0 - 0.06, d1 + 0.06);
    s.boxR(trim, l0 - 0.1, l1 + 0.1, h - 0.2, h, d0 - 0.1, d1 + 0.1);
  }

  /// Mái hai dốc, nóc chạy dọc theo l (hiên quay ra phố), đặt trên tường cao [y].
  void _roofSide(
    _Sink s,
    _C c,
    _C trim,
    double l0,
    double l1,
    double d0,
    double d1,
    double y,
    double rise,
  ) {
    s.prism(
      c,
      (l0 + l1) / 2,
      y,
      (d0 + d1) / 2,
      d1 - d0,
      rise,
      l1 - l0,
      rotY: _pi / 2,
      topScale: 0,
    );
    s.boxR(trim, l0, l1, y - 0.04, y + 0.1, d0, d0 + 0.07);
  }

  /// Mái hai dốc, nóc chạy dọc theo d (đầu hồi quay ra phố).
  void _roofFront(
    _Sink s,
    _C c,
    _C trim,
    double l0,
    double l1,
    double d0,
    double d1,
    double y,
    double rise,
  ) {
    s.prism(
      c,
      (l0 + l1) / 2,
      y,
      (d0 + d1) / 2,
      l1 - l0,
      rise,
      d1 - d0,
      topScale: 0,
    );
    s.boxR(trim, l0, l1, y - 0.04, y + 0.08, d0, d0 + 0.07);
  }

  /// Mái hiên sọc: những nêm lăng trụ hai màu nhô ra phố [proj] m từ mặt tường (d = [fd]), diềm sóng ở mép.
  void _awning(
    _Sink s,
    _C a,
    _C b,
    double l0,
    double l1,
    double fd,
    double y, {
    double proj = 0.85,
    double rise = 0.55,
    double stripe = 0.6,
  }) {
    final n = math.max(1, ((l1 - l0) / stripe).round());
    final w = (l1 - l0) / n;
    for (var i = 0; i < n; i++) {
      final c = i.isEven ? a : b;
      final l = l0 + (i + 0.5) * w;
      s.prism(c, l, y, fd, 2 * proj, rise, w, rotY: _pi / 2, topScale: 0);
      s.scallop(c, l, y - 0.18, fd - proj, w, 0.18, 0.04);
    }
  }

  /// Cửa sổ có ánh ấm (mặt đục không chịu ánh sáng, không kính trong suốt): khung, ô sáng, nan chữ thập, bệ.
  void _window(
    _Sink s,
    double l,
    double fd, {
    double y0 = 0.95,
    double w = 1.7,
    double h = 1.4,
    _C frame = _C.cream,
    _C sill = _C.woodDark,
  }) {
    s.box(frame, l, y0 - 0.1, fd - 0.05, w + 0.2, h + 0.2, 0.1);
    s.box(_C.sun, l, y0, fd - 0.11, w, h, 0.02);
    s.box(frame, l, y0, fd - 0.135, 0.06, h, 0.03);
    s.box(frame, l, y0 + h / 2 - 0.03, fd - 0.135, w, 0.06, 0.03);
    s.box(sill, l, y0 - 0.18, fd - 0.2, w + 0.4, 0.08, 0.25);
  }

  /// Cửa ra vào: khung, cánh [leaf] có ô sáng nhỏ, tay nắm, bậc gỗ thấp (3 cm).
  void _door(
    _Sink s,
    double l,
    double fd,
    _C leaf, {
    _C frame = _C.cream,
    bool pane = true,
  }) {
    s.box(frame, l, 0, fd - 0.05, 1.5, 2.4, 0.1);
    s.box(leaf, l, 0, fd - 0.125, 1.2, 2.2, 0.05);
    if (pane) s.box(_C.sun, l, 1.3, fd - 0.16, 0.7, 0.6, 0.02);
    s.bloom(_C.butter, l + 0.42, 0.9, fd - 0.17, 0.08);
    s.box(_C.woodLight, l, 0, fd - 0.4, 1.7, 0.03, 0.6);
  }

  /// Chậu hoa nón cụt (cao ~0,7 m).
  void _pot(_Sink s, double l, double d, _C bloom) {
    s.cone(_C.caramel, l, 0, d, 0.24, 0.34, 0.36);
    s.cyl(_C.woodDark, l, 0.36, d, 0.38, 0.04);
    s.ball(_C.correct, l, 0.34, d, 0.36);
    s.bloom(bloom, l - 0.1, 0.6, d + 0.08, 0.1);
    s.bloom(bloom, l + 0.06, 0.66, d + 0.04, 0.1);
    s.blockC(l, d, 0.42, 0.42);
  }

  /// Biển hiệu gỗ gắn tường: khung nâu, nền [back], rộng [w] × cao [h] đáy ở [y0], d = [fd]. Hình trên biển do người gọi
  /// thêm ở độ sâu `fd - 0.12`.
  void _signBoard(
    _Sink s,
    double l,
    double fd,
    double y0,
    double w,
    double h,
    _C back,
  ) {
    s.box(_C.woodDark, l, y0, fd - 0.04, w, h, 0.08);
    s.box(back, l, y0 + 0.06, fd - 0.09, w - 0.12, h - 0.12, 0.02);
  }

  // ---- Tiệm của bà (n2) --------------------------------------------------------------------------------------------

  void _home(_Sink s) {
    const fd = 0.9, h = 4.4, back = 9.3;
    s.tile(_deckArgb, -5.4, 5.4, 0, fd + 0.1, top: 0.012);
    _shell(s, _C.wall, _C.woodLight, _C.cream, -5.4, 5.4, fd, back, h);
    _roofSide(s, _C.caramel, _C.cream, -5.9, 5.9, fd - 0.5, back + 0.4, h, 1.2);
    // ống khói nhỏ
    s.boxR(_C.caramel, 3.4, 4.0, h + 0.3, h + 1.5, 5.6, 6.2);
    s.boxR(_C.woodDark, 3.34, 4.06, h + 1.5, h + 1.62, 5.54, 6.26);
    _window(s, -3.1, fd);
    _window(s, 3.1, fd);
    _door(s, 0, fd, _C.strawberry);
    _awning(s, _C.strawberry, _C.cream, -5.4, 5.4, fd, 2.55);
    // biển cupcake (không chữ)
    _signBoard(s, 0, fd, 3.25, 1.5, 0.85, _C.pinkLight);
    s.prism(_C.caramel, 0, 3.33, fd - 0.12, 0.5, 0.22, 0.04, bottomScale: 0.7);
    s.prism(_C.cream, 0, 3.54, fd - 0.12, 0.54, 0.14, 0.04, topScale: 0.65);
    s.prism(_C.cream, 0, 3.67, fd - 0.12, 0.36, 0.12, 0.04, topScale: 0.5);
    s.bloom(_C.strawberry, 0, 3.76, fd - 0.12, 0.09);
    // chậu hoa hai bên cửa
    _pot(s, -1.35, 0.45, _C.strawberry);
    _pot(s, 1.35, 0.45, _C.butter);
    s.block(-5.4, 5.4, fd - 0.06, back);
  }

  // ---- Quán ăn "Bếp Hải Đăng" (n3) ----------------------------------------------------------------------------------

  TownLotSpots _restaurant(
    _Sink s,
    _F f,
    LotDef lot,
    TownPoint door,
    double inYaw,
  ) {
    const fd = 0.9, rf = 2.4, h = 4.4, back = 9.3;
    const hc = -3.0, hw = 2.4; // ô cửa quầy: tâm, rộng
    const hl0 = hc - hw / 2, hl1 = hc + hw / 2;
    const wall = _C.mintLight, trim = _C.cream;
    s.tile(_paving, -5.4, -0.9, 0, fd + 0.1, top: 0);
    s.tile(_deckArgb, -0.9, 5.4, 0, rf + 0.1, top: 0.012);
    // khối sau + cánh trái (có hốc ô cửa) + chân tường, gờ mái
    s.boxR(wall, -5.4, 5.4, 0, h, rf, back);
    s.boxR(wall, -5.4, hl0, 0, h, fd, rf);
    s.boxR(wall, hl1, -0.9, 0, h, fd, rf);
    s.boxR(_C.mint, -5.46, -0.84, 0, 0.5, fd - 0.06, rf);
    s.boxR(_C.mint, -0.96, 5.46, 0, 0.5, rf - 0.06, back + 0.06);
    s.boxR(trim, -5.5, -0.8, h - 0.2, h, fd - 0.1, back + 0.1);
    s.boxR(trim, -0.9, 5.5, h - 0.2, h, rf - 0.1, back + 0.1);
    _hatch(s, hc, hw, fd, rf, h, wall, trim);
    _awning(
      s,
      _C.strawberry,
      _C.cream,
      hl0 - 0.3,
      hl1 + 0.3,
      fd,
      2.55,
      proj: 0.6,
      rise: 0.4,
      stripe: 0.5,
    );
    // mái: cánh trái đầu hồi quay ra phố (có hải đăng), cánh phải hai dốc
    _roofFront(
      s,
      _C.strawberry,
      trim,
      -5.8,
      -0.4,
      fd - 0.5,
      back + 0.4,
      h,
      1.5,
    );
    _roofSide(s, _C.strawberry, trim, -0.4, 5.9, rf - 0.4, back + 0.4, h, 1.2);
    _lighthouse(s, -3.1, 1.4, h + 1.5);
    // mặt tiền phần lùi: cửa sổ + cửa
    _window(s, 0.65, rf, y0: 1.0, w: 1.1, h: 1.2, frame: trim, sill: _C.mint);
    _window(s, 4.8, rf, y0: 1.0, w: 1.0, h: 1.2, frame: trim, sill: _C.mint);
    _door(s, 3.0, rf, _C.mint, frame: trim);
    // hiên: 2 bàn tròn + ghế + dù
    _table(s, 1.6, 1.35, _C.butterLight, _C.strawberry);
    _table(s, 4.3, 1.35, _C.pinkLight, _C.mint);
    _chair(
      s,
      0.85,
      1.35,
      1,
      0,
      _C.mint,
      blocking: false,
    ); // ghế của Mai (quay vào bàn)
    _chair(s, 2.35, 1.35, -1, 0, _C.pinkLight);
    _chair(s, 3.55, 1.35, 1, 0, _C.butterLight);
    _chair(s, 5.05, 1.35, -1, 0, _C.mint);
    // hộp chặn: khối nhà (cả hốc ô cửa), bệ quầy nhô ra
    s.block(-5.4, -0.84, fd - 0.06, rf);
    s.block(-5.46, 5.46, rf - 0.06, back + 0.1);
    s.block(hl0 - 0.25, hl1 + 0.25, fd - 0.55, fd);
    return TownLotSpots(
      lotId: lot.id,
      door: door,
      counter: TownPoint(f.x(hc), f.z(-0.5), inYaw),
      keeper: TownPoint(f.x(hc), f.z(fd + 0.8), inYaw == _pi ? 0.0 : _pi),
      seat: TownPoint(f.x(0.85), f.z(1.35), f.sx > 0 ? _pi / 2 : -_pi / 2),
    );
  }

  /// Ô cửa quầy ở mặt tiền (d = [fd]), hốc sâu tới [rf]: dầm trên, ván dưới, sàn gỗ, nền sau + kệ lọ + đèn, viền, bệ quầy.
  void _hatch(
    _Sink s,
    double lc,
    double w,
    double fd,
    double rf,
    double h,
    _C wall,
    _C trim,
  ) {
    final l0 = lc - w / 2, l1 = lc + w / 2;
    const y0 = 0.9, y1 = 2.3;
    s.boxR(wall, l0, l1, y1, h, fd, rf); // dầm
    s.boxR(wall, l0, l1, 0, y0, fd, fd + 0.25); // ván dưới ô cửa
    s.boxR(_C.woodLight, l0, l1, 0, 0.02, fd + 0.25, rf); // sàn hốc
    s.boxR(_C.butterLight, l0, l1, y0, y1, rf - 0.04, rf); // nền sau ấm
    // viền ô cửa nhô 6 cm
    s.boxR(trim, l0 - 0.12, l0, y0 - 0.1, y1 + 0.12, fd - 0.06, fd);
    s.boxR(trim, l1, l1 + 0.12, y0 - 0.1, y1 + 0.12, fd - 0.06, fd);
    s.boxR(trim, l0 - 0.12, l1 + 0.12, y1, y1 + 0.12, fd - 0.06, fd);
    // bệ quầy gỗ nhô ra phía vỉa hè (mặt 0,93 m)
    s.boxR(_C.woodLight, l0 - 0.25, l1 + 0.25, 0.86, 0.93, fd - 0.55, fd);
    s.boxR(_C.caramel, l0 - 0.2, l1 + 0.2, 0.0, 0.86, fd - 0.04, fd);
    // trong hốc: kệ + lọ + đèn
    s.boxR(_C.woodLight, l0 + 0.15, l1 - 0.15, 1.55, 1.6, rf - 0.3, rf - 0.04);
    const jars = [_C.mint, _C.strawberry, _C.butter, _C.cream];
    for (var i = 0; i < jars.length; i++) {
      s.cyl(jars[i], l0 + 0.4 + i * (w - 0.8) / 3, 1.6, rf - 0.17, 0.16, 0.22);
    }
    s.cyl(_C.woodDark, lc, 2.0, fd + 0.8, 0.02, 0.3);
    s.cone(_C.butter, lc, 1.9, fd + 0.8, 0.4, 0.1, 0.12);
    s.ball(_C.sun, lc, 1.84, fd + 0.8, 0.1);
  }

  /// Hải đăng nhỏ trên nóc: bệ, ba nón cụt kem - hồng dâu, ban công, đèn vàng (không chịu ánh sáng), mái nón + núm.
  void _lighthouse(_Sink s, double l, double d, double ridgeY) {
    s.boxR(
      _C.cream,
      l - 0.5,
      l + 0.5,
      ridgeY - 0.35,
      ridgeY + 0.08,
      d - 0.5,
      d + 0.5,
    );
    final y = ridgeY + 0.08;
    s.cone(_C.cream, l, y, d, 0.56, 0.5, 0.24);
    s.cone(_C.strawberry, l, y + 0.24, d, 0.5, 0.44, 0.24);
    s.cone(_C.cream, l, y + 0.48, d, 0.44, 0.38, 0.24);
    s.cyl(_C.woodDark, l, y + 0.72, d, 0.5, 0.04);
    s.cyl(_C.sun, l, y + 0.76, d, 0.28, 0.2);
    s.cone(_C.strawberry, l, y + 0.96, d, 0.4, 0.0, 0.22);
    s.ball(_C.butter, l, y + 1.16, d, 0.07);
  }

  /// Bàn tròn có dù: chân, mặt khăn, cột dù, mặt dù hình nón, núm.
  void _table(_Sink s, double l, double d, _C cloth, _C canopy) {
    s.cyl(_C.woodDark, l, 0, d, 0.1, 0.72);
    s.cyl(cloth, l, 0.72, d, 0.9, 0.05);
    s.cyl(_C.woodLight, l, 0.77, d, 0.05, 1.4);
    s.cone(canopy, l, 2.05, d, 1.7, 0.12, 0.3);
    s.ball(_C.cream, l, 2.33, d, 0.1);
    s.blockC(l, d, 0.84, 0.84);
  }

  /// Ghế quay về hướng ([fl] theo l, [fz] theo d) (một trong 4 hướng trục): mặt ngồi cao 0,42 m, tựa lưng phía sau.
  void _chair(
    _Sink s,
    double l,
    double d,
    double fl,
    double fz,
    _C c, {
    bool blocking = true,
  }) {
    s.box(c, l, 0.4, d, 0.42, 0.05, 0.42);
    for (final (a, b) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      s.box(_C.woodDark, l + a * 0.17, 0, d + b * 0.17, 0.04, 0.4, 0.04);
    }
    if (fl != 0) {
      s.box(c, l - fl * 0.19, 0.45, d, 0.04, 0.45, 0.42);
    } else {
      s.box(c, l, 0.45, d - fz * 0.19, 0.42, 0.45, 0.04);
    }
    if (blocking) s.blockC(l, d, 0.42, 0.42);
  }

  // ---- Tiệm tóc "Vỏ Sò" (n4) -----------------------------------------------------------------------------------------

  TownLotSpots _salon(_Sink s, _F f, LotDef lot, TownPoint door, double inYaw) {
    const fd = 0.9, rf = 2.4, h = 4.4, back = 9.3;
    const hc = 3.0, hw = 2.4;
    const hl0 = hc - hw / 2, hl1 = hc + hw / 2;
    const wall = _C.pinkLight, trim = _C.cream;
    s.tile(_paving, -5.4, 5.4, 0, fd + 0.1, top: 0);
    s.boxR(wall, -5.4, 5.4, 0, h, rf, back);
    s.boxR(wall, -5.4, hl0, 0, h, fd, rf);
    s.boxR(wall, hl1, 5.4, 0, h, fd, rf);
    s.boxR(_C.mint, -5.46, 5.46, 0, 0.5, fd - 0.06, back + 0.06);
    s.boxR(trim, -5.5, 5.5, h - 0.2, h, fd - 0.1, back + 0.1);
    _hatch(s, hc, hw, fd, rf, h, wall, trim);
    _awning(
      s,
      _C.strawberry,
      _C.cream,
      hl0 - 0.3,
      hl1 + 0.3,
      fd,
      2.55,
      proj: 0.6,
      rise: 0.4,
      stripe: 0.5,
    );
    _roofSide(s, _C.mint, trim, -5.9, 5.9, fd - 0.5, back + 0.4, h, 1.2);
    _window(s, -3.4, fd, frame: trim, sill: _C.mint);
    _door(s, 0, fd, _C.mint, frame: trim);
    _awning(
      s,
      _C.mint,
      _C.cream,
      -5.0,
      -0.95,
      fd,
      2.55,
      proj: 0.7,
      rise: 0.45,
      stripe: 0.5,
    );
    // biển hình vỏ sò (không chữ) trên cửa
    _signBoard(s, 0, fd, 2.95, 1.3, 1.1, _C.mintLight);
    s.prism(_C.strawberry, 0, 3.25, fd - 0.12, 0.84, 0.52, 0.04, topScale: 0.3);
    s.scallop(_C.strawberry, 0, 3.07, fd - 0.12, 0.84, 0.19, 0.04);
    s.box(_C.cream, 0, 3.36, fd - 0.14, 0.05, 0.36, 0.02);
    s.box(_C.cream, -0.2, 3.36, fd - 0.14, 0.04, 0.24, 0.02);
    s.box(_C.cream, 0.2, 3.36, fd - 0.14, 0.04, 0.24, 0.02);
    s.bloom(_C.cream, 0, 3.1, fd - 0.16, 0.1);
    // cột sọc pastel kiểu tiệm tóc hai bên cửa
    _pole(s, -1.35, 0.5);
    _pole(s, 1.35, 0.5);
    s.block(-5.46, 5.46, fd - 0.06, back + 0.1);
    s.block(hl0 - 0.25, hl1 + 0.25, fd - 0.55, fd);
    return TownLotSpots(
      lotId: lot.id,
      door: door,
      counter: TownPoint(f.x(hc), f.z(-0.5), inYaw),
      keeper: TownPoint(f.x(hc), f.z(fd + 0.8), inYaw == _pi ? 0.0 : _pi),
    );
  }

  /// Cột sọc pastel (hồng dâu - kem - bạc hà) cao ~2,5 m, đế + nắp gỗ, chỏm tròn.
  void _pole(_Sink s, double l, double d) {
    s.cyl(_C.woodDark, l, 0, d, 0.36, 0.12);
    const cols = [_C.strawberry, _C.cream, _C.mint];
    for (var i = 0; i < 6; i++) {
      s.cyl(cols[i % 3], l, 0.12 + i * 0.34, d, 0.26, 0.34);
    }
    s.cyl(_C.woodDark, l, 2.16, d, 0.36, 0.08);
    s.ball(_C.butterLight, l, 2.24, d, 0.28);
    s.blockC(l, d, 0.36, 0.36);
  }

  // ---- Văn phòng địa ốc (n1) ----------------------------------------------------------------------------------------

  void _realty(_Sink s) {
    const fd = 0.9, h = 4.2, back = 7.2;
    s.tile(_paving, -5.4, 5.4, 0, fd + 0.1, top: 0);
    _shell(s, _C.butterLight, _C.woodLight, _C.cream, -5.4, 5.4, fd, back, h);
    _roofSide(s, _C.mint, _C.cream, -5.9, 5.9, fd - 0.5, back + 0.4, h, 1.1);
    _window(s, -3.2, fd, y0: 0.95, w: 1.6, h: 1.3, sill: _C.caramel);
    _window(s, 3.2, fd, y0: 0.95, w: 1.6, h: 1.3, sill: _C.caramel);
    _door(s, 0, fd, _C.woodDark, pane: false); // cửa đóng
    _awning(
      s,
      _C.mint,
      _C.cream,
      -1.3,
      1.3,
      fd,
      2.55,
      proj: 0.7,
      rise: 0.45,
      stripe: 0.65,
    );
    // biển ngôi nhà + chìa khoá (không chữ)
    _signBoard(s, 0, fd, 3.2, 1.5, 0.72, _C.cream);
    s.box(_C.butter, -0.38, 3.3, fd - 0.12, 0.3, 0.2, 0.04);
    s.prism(
      _C.strawberry,
      -0.38,
      3.5,
      fd - 0.12,
      0.44,
      0.17,
      0.04,
      topScale: 0.0,
    );
    s.box(_C.woodDark, -0.38, 3.3, fd - 0.14, 0.07, 0.12, 0.02);
    s.ball(_C.caramel, 0.18, 3.38, fd - 0.12, 0.17);
    s.box(_C.caramel, 0.45, 3.44, fd - 0.12, 0.38, 0.045, 0.04);
    s.box(_C.caramel, 0.58, 3.37, fd - 0.12, 0.045, 0.07, 0.04);
    s.box(_C.caramel, 0.5, 3.37, fd - 0.12, 0.045, 0.07, 0.04);
    _pot(s, -1.5, 0.45, _C.pinkLight);
    _pot(s, 1.5, 0.45, _C.strawberry);
    s.block(-5.4, 5.4, fd - 0.06, back + 0.1);
  }

  // ---- Lô trống bán (s1, s3, s4) ------------------------------------------------------------------------------------

  /// Hàng rào gỗ trắng thấp chạy dọc l ([alongL]) hoặc dọc d, từ [a] tới [b], ở vị trí [fixed] của trục kia.
  void _fence(_Sink s, bool alongL, double fixed, double a, double b) {
    final n = math.max(1, ((b - a) / 1.5).ceil());
    final step = (b - a) / n;
    for (var i = 0; i <= n; i++) {
      final p = a + i * step;
      if (alongL) {
        s.box(_C.cream, p, 0, fixed, 0.1, 0.85, 0.1);
      } else {
        s.box(_C.cream, fixed, 0, p, 0.1, 0.85, 0.1);
      }
    }
    for (final y in const [0.27, 0.57]) {
      if (alongL) {
        s.boxR(_C.cream, a, b, y, y + 0.07, fixed - 0.025, fixed + 0.025);
      } else {
        s.boxR(_C.cream, fixed - 0.025, fixed + 0.025, y, y + 0.07, a, b);
      }
    }
    if (alongL) {
      s.block(a - 0.05, b + 0.05, fixed - 0.06, fixed + 0.06);
    } else {
      s.block(fixed - 0.06, fixed + 0.06, a - 0.05, b + 0.05);
    }
  }

  void _emptyLot(_Sink s, LotDef lot) {
    const gate = 1.0, fy = 0.3, edge = 5.4, depth = 9.9;
    // hàng rào trước có lối vào ở giữa, hai bên + sau kín
    _fence(s, true, fy, -edge, -gate);
    _fence(s, true, fy, gate, edge);
    _fence(s, false, -edge, fy, depth);
    _fence(s, false, edge, fy, depth);
    _fence(s, true, depth, -edge, edge);
    for (final l in const [-gate, gate]) {
      s.box(_C.cream, l, 0, fy, 0.14, 1.15, 0.14);
      s.box(_C.butterLight, l, 1.15, fy, 0.2, 0.08, 0.2);
    }
    // bảng gỗ nhỏ không chữ trên hai cọc: viền vàng bơ, hình lá cờ nhỏ
    final accent = lot.id == 's1'
        ? _C.strawberry
        : lot.id == 's3'
        ? _C.mint
        : _C.butter;
    for (final l in const [-3.4, -2.4]) {
      s.box(_C.woodDark, l, 0, 1.1, 0.1, 1.2, 0.1);
      s.blockC(l, 1.1, 0.14, 0.14);
    }
    s.box(_C.woodLight, -2.9, 0.6, 1.1, 1.3, 0.6, 0.06);
    for (final side in const [-1.0, 1.0]) {
      // hai mặt bảng đều có sọc màu (camera nhìn được từ cả phố lẫn phía sau lô)
      for (final l in const [-3.2, -2.9, -2.6]) {
        s.box(accent, l, 0.72, 1.1 + side * 0.03, 0.12, 0.36, 0.02);
      }
      s.box(_C.butter, -2.9, 0.6, 1.1 + side * 0.03, 1.3, 0.05, 0.02);
      s.box(_C.butter, -2.9, 1.15, 1.1 + side * 0.03, 1.3, 0.05, 0.02);
    }
    // cây non + đám hoa dại cho đỡ trống
    s.cyl(_C.woodDark, 4.3, 0, 7.4, 0.18, 1.1);
    s.ball(_C.leafLight, 4.3, 0.95, 7.4, 1.3);
    s.blockC(4.3, 7.4, 0.3, 0.3);
    const wild = [
      _C.strawberry,
      _C.butter,
      _C.cream,
      _C.pinkLight,
      _C.butter,
      _C.strawberry,
    ];
    for (var i = 0; i < wild.length; i++) {
      s.bloom(
        wild[i],
        -4.6 + (i % 3) * 0.35,
        0.0,
        6.0 + (i ~/ 3) * 0.4 + (i % 2) * 0.12,
        0.12,
      );
    }
    // vài bụi cây trong lô
    for (final (l, dd, c) in const [
      (-4.4, 2.2, _C.leafDeep),
      (4.4, 2.6, _C.correct),
    ]) {
      s.ball(c, l, 0, dd, 0.8);
      s.bloom(_C.pinkLight, l + 0.2, 0.68, dd + 0.2, 0.12);
      s.blockC(l, dd, 0.7, 0.7);
    }
  }

  // ---- Công viên (s2) --------------------------------------------------------------------------------------------

  void _park(_Sink s, _F f, LotDef lot) {
    const gate = 1.1, edge = 5.4, depth = 9.9;
    const hedgeY = 0.55;
    // lối đi + quảng trường kem dẫn tới đài phun nước
    s.tile(_paving, -0.8, 0.8, 0, 3.4, top: 0);
    s.tile(_plazaArgb, -2.6, 2.6, 2.6, 7.8, top: 0);
    s.tile(_paving, -4.6, -2.6, 4.4, 6.0, top: 0);
    s.tile(_paving, 2.6, 4.6, 4.4, 6.0, top: 0);
    // hàng bụi thấp quanh công viên: hai khúc ở mặt trước, hai bên, phía sau
    void hedge(double l0, double l1, double d0, double d1) {
      s.boxR(_C.leafDeep, l0, l1, 0, hedgeY, d0, d1);
      s.boxR(
        _C.leafLight,
        l0 + 0.04,
        l1 - 0.04,
        hedgeY,
        hedgeY + 0.13,
        d0 + 0.04,
        d1 - 0.04,
      );
      s.block(l0, l1, d0, d1);
    }

    hedge(-edge, -gate, 0.2, 0.7);
    hedge(gate, edge, 0.2, 0.7);
    hedge(-edge, -edge + 0.5, 0.7, depth);
    hedge(edge - 0.5, edge, 0.7, depth);
    hedge(-edge + 0.5, edge - 0.5, depth - 0.5, depth);
    // cột cổng
    for (final l in const [-gate, gate]) {
      s.box(_C.caramel, l, 0, 0.45, 0.2, 1.25, 0.2);
      s.box(_C.butter, l, 1.25, 0.45, 0.28, 0.1, 0.28);
      s.blockC(l, 0.45, 0.24, 0.24);
    }
    // luống hoa hai bên lối vào
    for (final l in const [-3.0, 3.0]) {
      s.boxR(_C.woodLight, l - 1.0, l + 1.0, 0, 0.22, 1.2, 2.0);
      s.boxR(_C.leafDeep, l - 0.94, l + 0.94, 0.22, 0.32, 1.26, 1.94);
      const cols = [_C.strawberry, _C.butter, _C.pinkLight, _C.cream];
      for (var i = 0; i < 6; i++) {
        s.bloom(
          cols[(i + (l > 0 ? 1 : 0)) % 4],
          l - 0.75 + i * 0.3,
          0.32,
          1.45 + (i.isEven ? 0.0 : 0.22),
          0.14,
        );
      }
      s.block(l - 1.0, l + 1.0, 1.2, 2.0);
    }
    // cây tròn (thân + tán hai tầng) ở bốn góc
    for (final (l, dd) in const [
      (-4.0, 3.3),
      (4.0, 3.0),
      (-3.9, 8.2),
      (3.9, 8.4),
    ]) {
      s.cyl(_C.woodDark, l, 0, dd, 0.26, 1.5);
      s.ball(_C.leafDeep, l, 1.45, dd, 1.8);
      s.ball(_C.leafLight, l + 0.15, 2.55, dd - 0.1, 1.1);
      s.blockC(l, dd, 0.4, 0.4);
    }
    // ghế băng hai bên đài phun nước, quay vào đài
    _parkBench(s, -3.2, 5.2, 1);
    _parkBench(s, 3.2, 5.2, -1);
    // đài phun nước nhỏ (dựng trực tiếp theo toạ độ thế giới: vành bát giác cần góc xoay)
    final wx = f.x(0), wz = f.z(5.2);
    final fountain = <Shop3dPart>[];
    _fountain(_sink(_F.world(), fountain), wx, wz);
    s.blockC(0, 5.2, 2.3, 2.3);
    _emit('lot:${lot.id}:fountain', fountain, Shop3dZone.entrance);
  }

  /// Ghế băng dài 1,4 m dọc theo d, mặt hướng [face] (±1 theo l), tựa lưng ở phía đối diện.
  void _parkBench(_Sink s, double l, double dd, double face) {
    s.box(_C.woodLight, l, 0.42, dd, 0.42, 0.05, 1.4);
    s.box(_C.woodLight, l - face * 0.2, 0.62, dd, 0.04, 0.3, 1.4);
    for (final z in const [-0.6, 0.6]) {
      s.box(_C.caramel, l, 0, dd + z, 0.4, 0.42, 0.06);
      s.box(_C.caramel, l - face * 0.2, 0.42, dd + z, 0.04, 0.5, 0.06);
    }
    s.box(_C.strawberry, l + face * 0.02, 0.47, dd - 0.3, 0.3, 0.05, 0.5);
    s.blockC(l, dd, 0.5, 1.5);
  }

  /// Đài phun nước: đáy kem, vành bát giác, mặt nước (không chịu ánh sáng), trụ, bát trên, tia nước.
  void _fountain(_Sink s, double x, double z) {
    s.cyl(_C.pavingLight, x, 0, z, 2.2, 0.12);
    for (var k = 0; k < 8; k++) {
      final a = k * _pi / 4;
      s.box(
        _C.cream,
        x + math.cos(a) * 1.06,
        0,
        z + math.sin(a) * 1.06,
        0.92,
        0.34,
        0.2,
        rotY: -(a + _pi / 2),
      );
    }
    s.cyl(_C.seaLight, x, 0.1, z, 1.75, 0.14);
    s.cyl(_C.cream, x, 0.2, z, 0.3, 0.75);
    s.cone(_C.pavingLight, x, 0.88, z, 0.35, 0.95, 0.22);
    s.cyl(_C.seaLight, x, 1.08, z, 0.8, 0.04);
    s.cone(_C.seaLight, x, 1.12, z, 0.16, 0.0, 0.34);
    s.ball(_C.seaLight, x, 1.44, z, 0.08);
  }

  // ---- Trạm xe buýt -------------------------------------------------------------------------------------------------

  /// Mái chờ nhỏ + ghế (chỉ trang trí ở giai đoạn 1): 2 cột trước, vách sau bạc hà, ghế băng, mái hồng sọc kem, biển
  /// tròn có hình xe buýt nhỏ (không chữ). [DistrictDef.busX]/[busZ] nằm giữa mái, đứng được.
  void _busStop() {
    final s = _sink(_F.world(), <Shop3dPart>[]);
    final parts = s.parts;
    final x = d.busX, z = d.busZ;
    final xl = x - 0.95, xr = x + 1.55; // mái: lệch phải vì sát biên phía tây
    // vách sau + ghế
    s.boxR(_C.mint, x - 0.9, x + 1.5, 0, 1.9, z - 1.3, z - 1.22);
    s.boxR(_C.mintLight, x - 0.9, x + 1.5, 1.9, 2.25, z - 1.3, z - 1.22);
    s.boxR(_C.woodLight, x - 0.6, x + 0.9, 0.42, 0.47, z - 1.2, z - 0.82);
    s.boxR(_C.woodLight, x - 0.6, x + 0.9, 0.6, 1.0, z - 1.22, z - 1.18);
    for (final px in [x - 0.55, x + 0.85]) {
      s.boxR(_C.caramel, px - 0.04, px + 0.04, 0, 0.42, z - 1.15, z - 0.9);
    }
    s.boxR(_C.strawberry, x - 0.35, x + 0.45, 0.47, 0.52, z - 1.16, z - 0.88);
    // hai cột trước + mái
    for (final px in [x - 0.55, x + 1.45]) {
      s.cyl(_C.woodDark, px, 0, z + 0.55, 0.12, 2.3);
      s.blockC(px, z + 0.55, 0.2, 0.2);
    }
    s.boxR(_C.strawberry, xl, xr, 2.3, 2.42, z - 1.4, z + 0.8);
    s.boxR(_C.cream, xl + 0.05, xr - 0.05, 2.42, 2.46, z - 1.3, z + 0.7);
    for (var i = 0; i < 5; i++) {
      s.scallop(
        i.isEven ? _C.strawberry : _C.cream,
        xl + (i + 0.5) * (xr - xl) / 5,
        2.12,
        z + 0.8,
        (xr - xl) / 5,
        0.18,
        0.04,
      );
    }
    s.block(x - 0.9, x + 1.5, z - 1.3, z - 0.8);
    // biển cột tròn + xe buýt nhỏ
    final px = x + 2.0, pz = z + 0.6;
    s.cyl(_C.woodDark, px, 0, pz, 0.08, 2.1);
    s.box(
      _C.mint,
      px,
      1.7,
      pz + 0.05,
      0.6,
      0.55,
      0.05,
    ); // mặt biển quay ra đường (+z)
    s.box(_C.butter, px, 1.82, pz + 0.09, 0.44, 0.22, 0.03);
    s.box(_C.cream, px, 1.9, pz + 0.115, 0.34, 0.07, 0.02);
    s.bloom(_C.chocolate, px - 0.12, 1.77, pz + 0.1, 0.08);
    s.bloom(_C.chocolate, px + 0.12, 1.77, pz + 0.1, 0.08);
    s.blockC(px, pz, 0.2, 0.2);
    _emit('busStop', parts);
  }
}
