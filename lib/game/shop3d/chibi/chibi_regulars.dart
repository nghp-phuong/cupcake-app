import 'dart:math' as math;

import 'chibi_characters.dart';
import 'chibi_mesh.dart';
import 'chibi_rig.dart';

/// 15 khách thường dạng thú chibi (V3, docs/v3/character-3d-procedural.md) — Dart thuần, dựng bằng code.
/// Chỉnh "cute" theo docs/v3/character-cute-review.md (quy chuẩn A): đầu ~49% chiều cao, thân ngắn bụng tròn, gần như
/// không cổ, chân ngắn bàn chân tròn to, tay mập tới hông hơi dang, mắt to cách nhau ~1,1 bề rộng mắt, má hồng to, màu
/// pastel, đầu nghiêng nhẹ, không kính/ria/blazer/phụ kiện nhỏ.
///
/// | id | thú | đặc điểm chính |
/// |---|---|---|
/// | `regular_00` | mèo trắng, chóp tai hồng | mũ len nhỏ, hoodie bạc hà, jean nhạt |
/// | `regular_01` | hamster | nơ hồng, má phúng phính, váy yếm jean trên áo bơ, tất trắng |
/// | `regular_02` | cocker spaniel | tai dài gợn sóng mật ong, áo len kem viền hồng, jean nhạt |
/// | `regular_03` | nhím | mái gai tròn xếp đều, mặt kem, áo thun in cupcake |
/// | `regular_04` | sóc | đuôi to cong, hai bím ngắn, mũ bucket nhỏ vàng bơ, áo khoác jean ngắn, váy xoè ngắn |
/// | `regular_05` | shiba | mũ lưỡi trai nhỏ, áo thun in mặt trời, quần short, đuôi cuộn |
/// | `regular_06` | mèo tím than, chấm mòng két trên trán | hoodie lavender, má + tai hồng |
/// | `regular_07` | koala xám xanh nhạt | tai tròn to, áo sọc xanh pastel, ba lô vải |
/// | `regular_08` | mèo xiêm | mặt nạ be nhỏ, beret mint nhỏ, áo sọc Breton, váy xoè ngắn |
/// | `regular_09` | voi nhỏ lavender-xám (bà ~50) | vòi ngắn mập, tai to tròn, búi kem-bạc, áo khoác ngắn hồng, trâm hoa nhỏ (không kính) |
/// | `regular_10` | poodle kem hồng | lông xù cụm tròn đối xứng, áo cổ lọ vàng bơ, khăn len |
/// | `regular_11` | thỏ tai cụp kem hồng | mũ cói nhỏ lộ tai cụp, áo len mint, giỏ bánh mì |
/// | `regular_12` | schnauzer bạc sáng (thú lớn) | tai cụp to, lông mày mềm, áo yếm denim nhạt |
/// | `regular_13` | hải mã nâu kem | mascot mặt tròn, mũi to hồng, hai nhú nanh, beret nhỏ, áo len kem |
/// | `regular_14` | sư tử vàng mật ong | bờm = mây tròn quanh đầu, áo len cổ tròn mint |
///
/// Cùng khung xương và hệ số [ChibiCharacters.scale] như bốn nhân vật mẫu. Kích thước theo loài (thú nhỏ hơn Mai) do
/// nơi gọi áp thêm; mô hình dựng ở kích thước gốc với tỉ lệ đầu/thân mới.
///
/// Helper dựng (ánh xạ bộ phận, mắt, má, miệng…) viết lại riêng trong file này vì bản trong `chibi_characters.dart` là
/// private. Phần thân / đầu viết ở toạ độ "cũ" (đầu tâm y = 0,965, thân 0,26–0,73) rồi [_B] ánh xạ sang tỉ lệ mới: thân
/// co 14%, đầu hạ xuống sát vai và nghiêng nhẹ; tay, chân viết thẳng ở toạ độ mới.
abstract final class ChibiRegulars {
  static const ids = [
    'regular_00',
    'regular_01',
    'regular_02',
    'regular_03',
    'regular_04',
    'regular_05',
    'regular_06',
    'regular_07',
    'regular_08',
    'regular_09',
    'regular_10',
    'regular_11',
    'regular_12',
    'regular_13',
    'regular_14',
  ];

  static List<ChibiModel>? _all;

  /// Cả 15 khách (dựng một lần, dùng lại). Muốn bản riêng thì gọi [build].
  static List<ChibiModel> get all => _all ??= buildAll();

  /// Khách theo id (`regular_00` … `regular_14`) từ danh sách [all]; id lạ → [ArgumentError].
  static ChibiModel byId(String id) {
    final i = ids.indexOf(id);
    if (i < 0) throw ArgumentError.value(id, 'id', 'unknown regular');
    return all[i];
  }

  /// Dựng mới một khách.
  static ChibiModel build(String id) => switch (id) {
        'regular_00' => _r00(),
        'regular_01' => _r01(),
        'regular_02' => _r02(),
        'regular_03' => _r03(),
        'regular_04' => _r04(),
        'regular_05' => _r05(),
        'regular_06' => _r06(),
        'regular_07' => _r07(),
        'regular_08' => _r08(),
        'regular_09' => _r09(),
        'regular_10' => _r10(),
        'regular_11' => _r11(),
        'regular_12' => _r12(),
        'regular_13' => _r13(),
        'regular_14' => _r14(),
        _ => throw ArgumentError.value(id, 'id', 'unknown regular'),
      };

  static List<ChibiModel> buildAll() => [for (final id in ids) build(id)];
}

// ---- Màu và số đo dùng chung -------------------------------------------------------------------------------------

const _eyeDark = 0x2B201E;
const _shine = 0xFFFFFF;
const _blush = 0xF7A3AC;
const _mouthDark = 0x8A4A44;

// Số đo MỚI (tỉ lệ cute): hông, chân, vai, cổ — đã tính sẵn từ bản cũ (thân co ×0,86, chân ×0,62, đầu hạ 0,165).
const _hipYn = 0.21;
const _legXn = 0.095;
const _shoulderXn = 0.185;
const _shoulderYn = 0.49;
const _neckYn = 0.535;
const _headDrop = 0.165;

// Toạ độ dựng (cũ) của thân, hông, đầu — bụng tròn hơn bản cũ.
const _torso = ChibiSurface(0, 0.48, 0, 0.215, 0.245, 0.19);
const _hips = ChibiSurface(0, 0.37, 0, 0.205, 0.11, 0.18);
const _headStd = ChibiSurface(0, 0.965, 0, 0.285, 0.26, 0.25);

/// Phép biến đổi dựng: toạ độ dựng → toạ độ mới của một bộ phận. y' = [y1] + (y − [y0])·[sy], rồi nghiêng [roll] (rad,
/// quanh trục z) quanh điểm (0, [pivY]).
class _Xf {
  const _Xf({this.y0 = 0, this.y1 = 0, this.sy = 1, this.roll = 0, this.pivY = 0});

  static const none = _Xf();

  final double y0, y1, sy, roll, pivY;

  (double, double, double) pt(double x, double y, double z) {
    var nx = x, ny = y1 + (y - y0) * sy;
    if (roll != 0) {
      final dy = ny - pivY, c = math.cos(roll), s = math.sin(roll);
      nx = x * c - dy * s;
      ny = pivY + x * s + dy * c;
    }
    return (nx, ny, z);
  }
}

/// Bọc [ChibiMeshBuilder]: mọi khối đi qua [_Xf] của bộ phận (dịch, co thân, nghiêng đầu) trước khi vào lưới.
class _B {
  _B(this.xf) : _rot = xf.roll == 0 ? null : ChibiBasis.euler(0, 0, xf.roll);

  final _Xf xf;
  final ChibiBasis? _rot;
  final ChibiMeshBuilder _m = ChibiMeshBuilder();

  bool get isEmpty => _m.isEmpty;

  ChibiBasis _bs(ChibiBasis b) {
    final r = _rot;
    return r == null ? b : r.then(b);
  }

  bool _id(ChibiBasis b) => identical(b, ChibiBasis.identity);

  void ellipsoid(
    double cx,
    double cy,
    double cz,
    double rx,
    double ry,
    double rz,
    int rgb, {
    ChibiBasis basis = ChibiBasis.identity,
    int lat = 8,
    int lon = 12,
  }) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.ellipsoid(x, y, z, rx, _id(basis) ? ry * xf.sy : ry, rz, rgb, basis: _bs(basis), lat: lat, lon: lon);
  }

  void sphere(double cx, double cy, double cz, double r, int rgb, {int lat = 6, int lon = 10}) =>
      ellipsoid(cx, cy, cz, r, r, r, rgb, lat: lat, lon: lon);

  void capsule(
    double ax,
    double ay,
    double az,
    double bx,
    double by,
    double bz,
    double ra,
    double rb,
    int rgb, {
    int radial = 8,
    int capBands = 3,
    double ovalX = 1,
  }) {
    final (x0, y0, z0) = xf.pt(ax, ay, az);
    final (x1, y1, z1) = xf.pt(bx, by, bz);
    _m.capsule(x0, y0, z0, x1, y1, z1, ra, rb, rgb, radial: radial, capBands: capBands, ovalX: ovalX);
  }

  void frustum(
    double ax,
    double ay,
    double az,
    double bx,
    double by,
    double bz,
    double ra,
    double rb,
    int rgb, {
    int radial = 10,
    double ovalX = 1,
    double ovalZ = 1,
    int pleats = 0,
    double pleatDepth = 0.12,
    bool capA = true,
    bool capB = true,
    double offsetZ = 0,
  }) {
    final (x0, y0, z0) = xf.pt(ax, ay, az);
    final (x1, y1, z1) = xf.pt(bx, by, bz);
    _m.frustum(x0, y0, z0, x1, y1, z1, ra, rb, rgb,
        radial: radial,
        ovalX: ovalX,
        ovalZ: ovalZ,
        pleats: pleats,
        pleatDepth: pleatDepth,
        capA: capA,
        capB: capB,
        offsetZ: offsetZ);
  }

  void torus(
    double cx,
    double cy,
    double cz,
    double ringR,
    double tubeR,
    int rgb, {
    ChibiBasis basis = ChibiBasis.identity,
    double a0 = 0,
    double a1 = 2 * math.pi,
    int segments = 12,
    int tube = 5,
    double tubeScaleZ = 1,
  }) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.torus(x, y, z, ringR, tubeR, rgb,
        basis: _bs(basis), a0: a0, a1: a1, segments: segments, tube: tube, tubeScaleZ: tubeScaleZ);
  }

  void box(
    double cx,
    double cy,
    double cz,
    double sx,
    double sy,
    double sz,
    int rgb, {
    ChibiBasis basis = ChibiBasis.identity,
  }) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.box(x, y, z, sx, _id(basis) ? sy * xf.sy : sy, sz, rgb, basis: _bs(basis));
  }

  void star(
    double cx,
    double cy,
    double cz,
    double outerR,
    double innerR,
    double thick,
    int rgb, {
    ChibiBasis basis = ChibiBasis.identity,
  }) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.star(x, y, z, outerR, innerR, thick, rgb, basis: _bs(basis));
  }

  void heart(double cx, double cy, double cz, double size, int rgb, {ChibiBasis basis = ChibiBasis.identity}) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.heart(x, y, z, size, rgb, basis: _bs(basis));
  }

  void dome(
    double cx,
    double cy,
    double cz,
    double rx,
    double ry,
    double h,
    int rgb, {
    ChibiBasis basis = ChibiBasis.identity,
    int segments = 10,
  }) {
    final (x, y, z) = xf.pt(cx, cy, cz);
    _m.dome(x, y, z, rx, ry, h, rgb, basis: _bs(basis), segments: segments);
  }

  /// Tấm quấn thân (chỉ dùng cho bộ phận không nghiêng): các hàng đổi độ cao theo [xf].
  void shell(double cx, double cz, List<(double, double, double, double, double)> rows, int rgb, {int segments = 12}) {
    _m.shell(cx, cz, [for (final (y, rx, rz, a0, a1) in rows) (xf.pt(0, y, 0).$2, rx, rz, a0, a1)], rgb,
        segments: segments);
  }

  ChibiMesh build({double px = 0, double py = 0, double pz = 0, double scale = 1}) =>
      _m.build(px: px, py: py, pz: pz, scale: scale);
}

/// Phân phối khối vào từng bộ phận, rồi dựng [ChibiModel]. [tilt] = độ nghiêng đầu (rad). [earExtra] = bộ phận phụ là tai (đi theo đầu); sai = đuôi (đi theo thân).
class _Sketch {
  _Sketch({this.tilt = 0.1, this.earExtra = false}) {
    for (final p in ChibiPart.values) {
      _b[p] = _B(_xfOf(p));
    }
  }

  /// Nâng thân + đầu + tay lên (chân dài ra); mọi khách thường dùng 0 — chiều cao theo loài do nơi gọi áp.
  final double rise = 0;
  final double tilt;
  final bool earExtra;
  final _b = <ChibiPart, _B>{};

  static const _bodyXf = _Xf(y0: 0.26, y1: 0.17, sy: 0.86);
  late final _headXf = _Xf(y1: -_headDrop, roll: tilt, pivY: _neckYn);

  _Xf _xfOf(ChibiPart p) => switch (p) {
        ChibiPart.body => _bodyXf,
        ChibiPart.head || ChibiPart.eyes => _headXf,
        ChibiPart.extra => earExtra ? _headXf : _bodyXf,
        _ => _Xf.none,
      };

  _B get body => _b[ChibiPart.body]!;
  _B get head => _b[ChibiPart.head]!;
  _B get eyes => _b[ChibiPart.eyes]!;
  _B get extra => _b[ChibiPart.extra]!;
  _B arm(double side) => _b[side > 0 ? ChibiPart.armL : ChibiPart.armR]!;
  _B leg(double side) => _b[side > 0 ? ChibiPart.legL : ChibiPart.legR]!;

  ChibiModel build(
    String id, {
    required double eyeY,
    required double eyeZ,
    double extraX = 0,
    double extraY = 0,
    double extraZ = 0,
    ChibiGait gait = const ChibiGait(),
    ChibiExtraKind extraKind = ChibiExtraKind.none,
    double radius = 0.27,
  }) {
    const s = ChibiCharacters.scale;
    final (_, eyeYn, _) = _headXf.pt(0, eyeY, eyeZ);
    final (exn, eyn, ezn) = _xfOf(ChibiPart.extra).pt(extraX, extraY, extraZ);
    final base = ChibiRigSpec(
        hipY: _hipYn,
        legX: _legXn,
        neckY: _neckYn,
        shoulderX: _shoulderXn,
        shoulderY: _shoulderYn,
        eyeY: eyeYn,
        eyeZ: eyeZ,
        extraX: exn,
        extraY: eyn,
        extraZ: ezn);
    final real = ChibiRigSpec(
        hipY: _hipYn + rise,
        legX: _legXn,
        neckY: _neckYn + rise,
        shoulderX: _shoulderXn,
        shoulderY: _shoulderYn + rise,
        eyeY: eyeYn + rise,
        eyeZ: eyeZ,
        extraX: exn,
        extraY: eyn + rise,
        extraZ: ezn,
        seatDrop: 0.17 + rise);
    final meshes = <ChibiPart, ChibiMesh>{};
    for (final e in _b.entries) {
      if (e.value.isEmpty) continue;
      // Chân dựng thẳng ở toạ độ thật (đã tính rise) nên xoay quanh khớp thật; phần còn lại dựng ở toạ độ chuẩn.
      final legPart = e.key == ChibiPart.legL || e.key == ChibiPart.legR;
      final (px, py, pz) = (legPart ? real : base).pivotOf(e.key);
      meshes[e.key] = e.value.build(px: px, py: py, pz: pz, scale: s);
    }
    return ChibiModel(
        id: id, meshes: meshes, rig: real.scaled(s), gait: gait.scaled(s), extraKind: extraKind, radius: radius * s);
  }
}

// ---- Dựng chung: thân, tay, chân ---------------------------------------------------------------------------------

/// Cổ tay / bàn tay (toạ độ mới, tương đối vai): tay hơi dang, dài tới hông; [spread] dang thêm (váy xoè).
(double, double, double) _wrist(double side, [double spread = 0]) =>
    (side * (_shoulderXn + 0.07 + spread * 0.7), _shoulderYn - 0.205, 0.03);
(double, double, double) _handC(double side, [double spread = 0]) =>
    (side * (_shoulderXn + 0.088 + spread), _shoulderYn - 0.255, 0.04);

void _sph(_B b, double x, double y, double z, double r, int color, {int lat = 3, int lon = 6}) =>
    b.ellipsoid(x, y, z, r, r, r, color, lat: lat, lon: lon);

/// Dải trụ ngắn từ a tới b, bán kính [r]; không nắp.
void _band(_B b, double ax, double ay, double az, double bx, double by, double bz, double r, int color) =>
    b.frustum(ax, ay, az, bx, by, bz, r, r * 0.97, color, radial: 8, capA: false, capB: false);

/// Tay mập: ống tay (màu [sleeve], dài [sleeveLen] phần quãng vai → cổ tay; phần còn lại là [skin]) + bàn tay tròn
/// to ([hand]); [cuff] = viền cổ tay. [handScale] phóng bàn tay (chân chèo hải mã).
void _arm(
  _Sketch k,
  double side, {
  required int sleeve,
  required int hand,
  double sleeveLen = 1,
  int? skin,
  int? cuff,
  double rTop = 0.074,
  double rWrist = 0.064,
  double rHand = 0.075,
  double handLong = 1.04,
  double spread = 0,
}) {
  final b = k.arm(side);
  final (wx, wy, wz) = _wrist(side, spread);
  final sx = side * _shoulderXn;
  if (sleeveLen >= 1) {
    b.capsule(sx, _shoulderYn, 0, wx, wy, wz, rTop, rWrist, sleeve, radial: 7, capBands: 2);
  } else {
    final t = sleeveLen;
    final mx = sx + (wx - sx) * t, my = _shoulderYn + (wy - _shoulderYn) * t, mz = wz * t;
    final rm = rTop + (rWrist - rTop) * t;
    b.capsule(mx, my, mz, wx, wy, wz, rm * 0.92, rWrist * 0.94, skin ?? hand, radial: 7, capBands: 1);
    b.capsule(sx, _shoulderYn, 0, mx, my, mz, rTop, rm + 0.004, sleeve, radial: 7, capBands: 2);
  }
  if (cuff != null) {
    final dx = wx - sx, dy = wy - _shoulderYn, dz = wz;
    _band(b, wx - dx * 0.12, wy - dy * 0.12, wz - dz * 0.12, wx + dx * 0.04, wy + dy * 0.04, wz + dz * 0.04,
        rWrist + 0.012, cuff);
  }
  final (hx, hy, hz) = _handC(side, spread);
  b.ellipsoid(hx, hy, hz, rHand, rHand * handLong, rHand, hand, lat: 5, lon: 9);
}

/// Chân ngắn: ống chân mập (màu [leg], bán kính [r]) + bàn chân bánh bao to tròn hơi chụm ([shoe], bàn phải [shoeR] nếu
/// khác) + đế [sole]; [shorts] = ống quần short phủ phần trên, [sock] = tất cổ ngắn. Chân dựng theo [_Sketch.rise].
void _legs(
  _Sketch k, {
  required int leg,
  required int shoe,
  int? shoeR,
  int? sole,
  double r = 0.076,
  int? shorts,
  double shortsLen = 0.08,
  int? sock,
}) {
  final top = _hipYn + k.rise + 0.03;
  for (final side in const [1.0, -1.0]) {
    final b = k.leg(side);
    final x = side * _legXn;
    b.capsule(x, 0.1, 0, x, top, 0, r, r + 0.006, leg, radial: 7, capBands: 1);
    if (shorts != null) {
      b.frustum(x, top - 0.01, 0, x, top - 0.01 - shortsLen, 0, r + 0.014, r + 0.024, shorts,
          radial: 8, capA: false, capB: false);
    }
    if (sock != null) {
      b.frustum(x, 0.07, 0.01, x, 0.15, 0.0, r + 0.008, r + 0.006, sock, radial: 8, capA: false, capB: false);
    }
    final toe = ChibiBasis.euler(0, -side * 0.12, 0);
    b.ellipsoid(x, 0.068, 0.04, 0.1, 0.072, 0.128, side < 0 ? (shoeR ?? shoe) : shoe, basis: toe, lat: 5, lon: 9);
    if (sole != null) b.ellipsoid(x, 0.022, 0.04, 0.104, 0.024, 0.132, sole, basis: toe, lat: 2, lon: 9);
  }
}

/// Thân (ellipsoid thân + hông) màu [top] / [bottom].
void _torsoParts(_Sketch k, int top, int bottom) {
  k.body.ellipsoid(_torso.cx, _torso.cy, _torso.cz, _torso.rx, _torso.ry, _torso.rz, top, lat: 7, lon: 10);
  k.body.ellipsoid(_hips.cx, _hips.cy, _hips.cz, _hips.rx, _hips.ry, _hips.rz, bottom, lat: 4, lon: 10);
}

/// Bán kính (rx, rz) thân + hông ở độ cao [y] (+ [offset]).
(double, double) _wrapRadius(double y, double offset) {
  (double, double) r(ChibiSurface s, double yy) {
    final t = (yy - s.cy) / s.ry;
    final k = math.sqrt(math.max(0, 1 - t * t));
    return (s.rx * k, s.rz * k);
  }

  final yy = math.max(y, _hips.cy - _hips.ry * 0.9);
  final (ax, az) = r(_torso, yy);
  final (bx, bz) = r(_hips, yy);
  return (math.max(ax, bx) + offset, math.max(az, bz) + offset);
}

/// Điểm trên tấm quấn ở góc [a] (rad, 0 = trước) độ cao [y], nhô [lift]; cơ sở z = pháp tuyến (gần đúng, ngang).
(double, double, double, ChibiBasis) _wrapPoint(double a, double y, double offset, double lift) {
  final (rx, rz) = _wrapRadius(y, offset);
  final nx = math.sin(a) / rx, nz = math.cos(a) / rz;
  final nl = math.sqrt(nx * nx + nz * nz);
  return (
    rx * math.sin(a) + nx / nl * lift,
    y,
    rz * math.cos(a) + nz / nl * lift,
    ChibiBasis.facing(nx / nl, 0.15, nz / nl)
  );
}

/// Dải quanh thân (sọc áo, thắt lưng) từ [y] dày [h], nhô [off].
void _bandAt(_B b, double y, double h, int color, {double off = 0.003}) {
  final (rx0, rz0) = _wrapRadius(y, off);
  final (rx1, _) = _wrapRadius(y + h, off);
  b.frustum(0, y, 0, 0, y + h, 0, rx0, rx1, color, radial: 12, ovalZ: rz0 / rx0, capA: false, capB: false);
}

/// Áo khoác ngắn mở trước: tấm quấn từ [hemY] tới [topY], cổ chữ V rộng dần ([vLow] → [vHigh] rad), loe thêm [flare] ở
/// gấu.
void _jacket(
  _Sketch k,
  int color, {
  double hemY = 0.3,
  double topY = 0.655,
  double vLow = 0.05,
  double vHigh = 0.6,
  double off = 0.012,
  double flare = 0.0,
}) {
  const n = 7;
  final rows = <(double, double, double, double, double)>[];
  for (var i = 0; i < n; i++) {
    final t = i / (n - 1);
    final y = hemY + (topY - hemY) * t;
    final v = vLow + (vHigh - vLow) * math.pow(t, 1.6);
    final (rx, rz) = _wrapRadius(y, off + flare * (1 - t) * (1 - t));
    rows.add((y, rx, rz, v.toDouble(), 2 * math.pi - v));
  }
  k.body.shell(0, 0, rows, color, segments: 18);
}

/// Váy xoè ngắn quấn kín quanh hông: gấu ở [hemY] loe [flare], eo ở [waistY]; [pleats] > 0 → xếp ly.
void _skirt(_Sketch k, int color, {double hemY = 0.25, double waistY = 0.42, double flare = 0.08, int pleats = 0}) {
  final (wx, wz) = _wrapRadius(waistY, 0.012);
  final r = (_hips.rx + flare + 0.03);
  k.body.frustum(0, hemY, 0, 0, waistY, 0, r, wx, color,
      pleats: pleats, pleatDepth: 0.1, ovalZ: (wz / wx) * 0.92, radial: 14, capA: false, capB: false);
}

/// Mũ trùm + dây rút + túi trước + viền gấu của hoodie (thân + hông cùng màu [color]).
void _hoodie(_Sketch k, int color, int dark, int string) {
  _torsoParts(k, color, color);
  k.body.torus(0, 0.715, -0.025, 0.115, 0.042, dark, basis: ChibiBasis.facing(0, 1, 0), segments: 8, tube: 3);
  k.body.ellipsoid(0, 0.765, -0.15, 0.14, 0.095, 0.07, color, lat: 4, lon: 8);
  for (final side in const [1.0, -1.0]) {
    k.body
        .capsule(side * 0.035, 0.68, 0.138, side * 0.042, 0.585, 0.182, 0.0075, 0.0075, string, radial: 4, capBands: 1);
    k.body.sphere(side * 0.042, 0.578, 0.184, 0.013, string, lat: 2, lon: 5);
  }
  final (qx, qy, qz, qb) = _torso.at(0, -16, lift: -0.002);
  k.body.dome(qx, qy, qz, 0.105, 0.052, 0.01, dark, basis: qb, segments: 10);
}

// ---- Mặt ---------------------------------------------------------------------------------------------------------

/// Mắt hạt to (+ 2 chấm sáng) tại ([x],[y],[z]) với cơ sở [b]; [iris] ≠ null → tròng màu + đồng tử (thú lông sẫm màu,
/// mắt đen sẽ chìm vào lông).
void _eye(
  _Sketch k,
  double x,
  double y,
  double z,
  ChibiBasis b, {
  double w = 0.056,
  double h = 0.074,
  int color = _eyeDark,
  int? iris,
}) {
  const d = 0.022;
  (double, double, double) at(double lx, double ly, double lz) => (
        x + b.xx * lx + b.yx * ly + b.zx * lz,
        y + b.xy * lx + b.yy * ly + b.zy * lz,
        z + b.xz * lx + b.yz * ly + b.zz * lz
      );
  var shineZ = d * 0.8;
  if (iris != null) {
    k.eyes.ellipsoid(x, y, z, w, h, d, iris, basis: b, lat: 4, lon: 8);
    final (px, py, pz) = at(0, -h * 0.04, 0.006);
    k.eyes.ellipsoid(px, py, pz, w * 0.6, h * 0.84, d, color, basis: b, lat: 4, lon: 8);
    shineZ = d * 1.25;
  } else {
    k.eyes.ellipsoid(x, y, z, w, h, d, color, basis: b, lat: 4, lon: 8);
  }
  final (ax, ay, az) = at(w * 0.28, h * 0.36, shineZ);
  k.eyes.dome(ax, ay, az, w * 0.38, w * 0.38, 0.007, _shine, basis: b, segments: 8);
  final (bx, by, bz) = at(-w * 0.32, -h * 0.4, shineZ - d * 0.1);
  k.eyes.dome(bx, by, bz, w * 0.2, w * 0.2, 0.005, _shine, basis: b, segments: 6);
}

/// Hai mắt trên bề mặt [s]; trả về (eyeY, eyeZ) cho khớp chớp mắt.
(double, double) _eyesOn(
  _Sketch k,
  ChibiSurface s,
  double az,
  double el, {
  double w = 0.056,
  double h = 0.074,
  double lift = 0.004,
  int? iris,
}) {
  var sy = 0.0, sz = 0.0;
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = s.at(side * az, el, lift: lift);
    _eye(k, x, y, z, b, w: w, h: h, iris: iris);
    sy += y / 2;
    sz += z / 2;
  }
  return (sy, sz);
}

/// Má hồng to (đĩa dẹt chìm một nửa vào mặt), dưới-ngoài mắt.
void _cheeks(_Sketch k, ChibiSurface s, double az, double el, {int color = _blush, double w = 0.06}) {
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = s.at(side * az, el, lift: -0.003);
    k.head.dome(x, y, z, w, w * 0.66, 0.009, color, basis: b, segments: 10);
  }
}

/// Miệng "ω" (hai cung nhỏ).
void _omega(_Sketch k, ChibiSurface s, double el, {double r = 0.0125, int color = _mouthDark, double az = 0}) {
  final (x, y, z, b) = s.at(az, el, lift: 0.002);
  for (final side in const [1.0, -1.0]) {
    final ox = side * r, oy = r * 0.9;
    k.head.torus(x + b.xx * ox + b.yx * oy, y + b.xy * ox + b.yy * oy, z + b.xz * ox + b.yz * oy, r, 0.0052, color,
        basis: b, a0: math.pi * 1.0, a1: math.pi * 2.0, segments: 6, tube: 3, tubeScaleZ: 0.6);
  }
}

/// Miệng ω trên mõm [m] ở góc cao [el] — tâm vòng đặt lệch vào trong mõm để cung nằm sát bề mặt (như Nora).
void _muzzleMouth(_Sketch k, ChibiSurface m, {double el = -12, double r = 0.012, int color = _mouthDark}) {
  final (mx, my, mz, mb) = m.at(0, el, lift: 0.0);
  final m2 = ChibiSurface(mx - mb.zx * 0.1, my - mb.zy * 0.1, mz - mb.zz * 0.1, 0.1, 0.1, 0.1);
  _omega(k, m2, 0, r: r, color: color);
}

/// Mõm = ellipsoid [m] màu [color] + mũi to tròn ([nose]) ở góc cao [noseEl].
void _muzzle(
  _Sketch k,
  ChibiSurface m,
  int color,
  int nose, {
  double noseEl = 18,
  double noseW = 0.036,
  double noseH = 0.026,
  int lat = 6,
}) {
  k.head.ellipsoid(m.cx, m.cy, m.cz, m.rx, m.ry, m.rz, color, lat: lat, lon: 12);
  final (nx, ny, nz, nb) = m.at(0, noseEl, lift: 0.004);
  k.head.ellipsoid(nx, ny, nz, noseW, noseH, 0.02, nose, basis: nb, lat: 4, lon: 8);
}

/// Mũi tròn to cho mặt không mõm (mèo, thỏ, hamster).
void _nose(_Sketch k, ChibiSurface head, int color, {double el = -15, double w = 0.027, double h = 0.02}) {
  final (nx, ny, nz, nb) = head.at(0, el, lift: 0.006);
  k.head.ellipsoid(nx, ny, nz, w, h, 0.017, color, basis: nb, lat: 4, lon: 8);
}

/// Hai má phúng phính quanh miệng (thỏ, hamster, mèo).
void _puffCheeks(_Sketch k, ChibiSurface head, int color, {double az = 9, double el = -23, double r = 0.045}) {
  for (final side in const [1.0, -1.0]) {
    final (mx, my, mz, mb) = head.at(side * az, el, lift: -0.02);
    k.head.ellipsoid(mx, my, mz, r, r * 0.8, r * 0.75, color, basis: mb, lat: 4, lon: 8);
  }
}

/// Tàn nhang: vài chấm nhỏ trên má.
void _freckles(_Sketch k, ChibiSurface s, int color, {double az = 44, double el = -14, double spread = 8}) {
  for (final side in const [1.0, -1.0]) {
    for (final (da, de) in [(-spread, 3.0), (spread * 0.1, 5.0), (spread, 2.0), (spread * 0.1, -5.0)]) {
      final (fx, fy, fz, fb) = s.at(side * (az + da), el + de, lift: 0.003);
      k.head.dome(fx, fy, fz, 0.0055, 0.0055, 0.002, color, basis: fb, segments: 5);
    }
  }
}

// ---- Tai, đuôi, mũ ------------------------------------------------------------------------------------------------

/// Tai nhọn (nón dẹt) từ gốc ([bx],[by],[bz]) tới đỉnh ([tx],[ty],[tz]); [tip] = màu chóp (từ [tipFrom] của chiều
/// dài), [inner] = lòng tai.
void _coneEar(
  _B b,
  double bx,
  double by,
  double bz,
  double tx,
  double ty,
  double tz,
  double r,
  int fur, {
  int? inner,
  int? tip,
  double tipFrom = 0.72,
  double ovalZ = 0.55,
  double innerScale = 0.62,
  double tipR = 0.022,
}) {
  // Đỉnh tai bo tròn (không nhọn như kim): nón cụt kết thúc bằng bán kính [tipR].
  b.frustum(bx, by, bz, tx, ty, tz, r, tipR, fur, radial: 8, ovalZ: ovalZ, capA: false);
  if (inner != null) {
    final zOff = r * ovalZ - r * innerScale * ovalZ * 0.7 + 0.008;
    b.frustum(bx, by + 0.012, bz + zOff, bx + (tx - bx) * 0.93, by + (ty - by) * 0.9, bz + (tz - bz) * 0.93 + zOff,
        r * innerScale, tipR * 0.5, inner,
        radial: 7, ovalZ: ovalZ * 0.7, capA: false);
  }
  if (tip != null) {
    final f = tipFrom;
    b.frustum(bx + (tx - bx) * f, by + (ty - by) * f, bz + (tz - bz) * f, tx + (tx - bx) * 0.002, ty + 0.004, tz,
        r * (1 - f) + tipR * f + 0.004, tipR + 0.002, tip,
        radial: 8, ovalZ: ovalZ * 1.05, capA: false);
  }
}

/// Tai tròn (gấu, hamster, koala, sư tử): ellipsoid dẹt + lòng tai (vòm).
void _roundEar(
  _B b,
  double cx,
  double cy,
  double cz,
  double r,
  int fur,
  int inner, {
  double tilt = 0,
  double depth = 0.5,
  double innerScale = 0.62,
}) {
  final basis = ChibiBasis.euler(0, 0, tilt);
  b.ellipsoid(cx, cy, cz, r, r, r * depth, fur, basis: basis, lat: 4, lon: 8);
  final z = basis.zz * r * depth * 0.9;
  b.dome(cx + basis.zx * r * depth * 0.9, cy + basis.zy * r * depth * 0.9, cz + z, r * innerScale, r * innerScale,
      0.009, inner,
      basis: basis, segments: 8);
}

/// Dải ellipsoid dọc theo các điểm [pts] (đuôi, tai dài): đoạn i có bán kính [radii][i], màu [colors][i]; [flat] = tỉ lệ
/// dày theo z so với bán kính.
void _chain(
  _B b,
  List<(double, double, double)> pts,
  List<double> radii,
  List<int> colors, {
  double flat = 1,
  int lat = 4,
  int lon = 7,
  double ovalX = 1,
}) {
  for (var i = 0; i < pts.length - 1; i++) {
    final (ax, ay, az) = pts[i];
    final (bx, by, bz) = pts[i + 1];
    final len = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2) + math.pow(bz - az, 2));
    final r = radii[i];
    b.ellipsoid((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2, r * ovalX, len * 0.62 + r * 0.25, r * flat, colors[i],
        basis: ChibiBasis.alongY(bx - ax, by - ay, bz - az), lat: lat, lon: lon);
  }
}

/// Mũ beret nhỏ: ellipsoid dẹt nghiêng + cuống.
void _beret(_Sketch k, int color, {double y = 1.2, double tiltZ = -0.12, double r = 0.18}) {
  k.head.ellipsoid(0.025, y, -0.015, r, 0.065, r - 0.006, color,
      basis: ChibiBasis.euler(0.05, 0, tiltZ), lat: 5, lon: 14);
  k.head.sphere(0.035, y + 0.068, -0.01, 0.02, color, lat: 3, lon: 6);
}

/// Mũ len nhỏ (beanie): vòm + viền gập quanh + bông; ngồi trên đỉnh đầu.
void _beanie(_Sketch k, int color, int cuff, {double y = 1.13, double r = 0.205}) {
  k.head.ellipsoid(0, y + 0.03, -0.012, r, r * 0.66, r * 0.97, color, lat: 6, lon: 14);
  k.head.frustum(0, y - 0.03, -0.012, 0, y + 0.04, -0.012, r + 0.008, r, cuff,
      radial: 14, ovalZ: 0.97, capA: false, capB: false);
  k.head.sphere(0, y + 0.03 + r * 0.66, -0.012, 0.038, cuff, lat: 4, lon: 8);
}

/// Mũ bucket nhỏ: thân nón cụt + vành loe, ngồi trên đỉnh đầu.
void _bucketHat(_Sketch k, int color, int band, {double y = 1.16, double r = 0.185}) {
  k.head.frustum(0, y, -0.012, 0, y + 0.1, -0.012, r, r * 0.88, color, radial: 14, ovalZ: 0.96, capA: false);
  k.head.frustum(0, y - 0.025, -0.012, 0, y + 0.012, -0.012, r + 0.075, r, color, radial: 14, ovalZ: 0.96);
  k.head.frustum(0, y + 0.004, -0.012, 0, y + 0.042, -0.012, r + 0.004, r + 0.002, band,
      radial: 14, ovalZ: 0.96, capA: false, capB: false);
}

/// Khăn len quấn cổ: vòng + hai đuôi rủ trước ngực; [colors] xen kẽ theo chiều dài đuôi.
void _scarf(_Sketch k, List<int> colors, {double ringR = 0.12, double tube = 0.048, double y = 0.7}) {
  for (var i = 0; i < 3; i++) {
    k.body.torus(0, y - 0.004, -0.01, ringR, tube, colors[i % colors.length],
        basis: ChibiBasis.facing(0, 1, 0),
        a0: math.pi * 2 * i / 3,
        a1: math.pi * 2 * (i + 1) / 3 + 0.05,
        segments: 6,
        tube: 6);
  }
  for (final (side, len) in const [(1.0, 0.2), (-1.0, 0.15)]) {
    const n = 4;
    for (var i = 0; i < n; i++) {
      final t0 = i / n, t1 = (i + 1) / n;
      final y0 = 0.66 - len * t0, y1 = 0.66 - len * t1;
      k.body.box(side * 0.07, (y0 + y1) / 2, 0.19 - 0.01 * t0, 0.075, (y0 - y1) * 1.02, 0.03, colors[i % colors.length],
          basis: ChibiBasis.euler(0.18, 0, side * 0.1));
    }
  }
}

// ---- regular_00: mèo trắng, chóp tai hồng ------------------------------------------------------------------------

ChibiModel _r00() {
  const fur = 0xFFFBF6;
  const tipPink = 0xF7A9BF;
  const innerEar = 0xFFD3DC;
  const nose = 0xF28FA6;
  const beanie = 0xE3D9EC;
  const beanieCuff = 0xF3B9CE;
  const hoodie = 0xA8DCC8;
  const hoodieDark = 0x8DC8B0;
  const jeans = 0xBFD6EC;

  final k = _Sketch(tilt: 0.1);
  const head = _headStd;
  _hoodie(k, hoodie, hoodieDark, 0xFFFFFF);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  _nose(k, head, nose);
  _puffCheeks(k, head, fur, az: 10, el: -23, r: 0.042);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -4);
  _cheeks(k, head, 45, -23);
  _omega(k, head, -23);
  // Tai mèo to: nón bo tròn đỉnh, lòng hồng, chóp nhuộm hồng; thò ra hai bên mũ len.
  for (final side in const [1.0, -1.0]) {
    _coneEar(k.head, side * 0.205, 1.09, -0.01, side * 0.285, 1.4, -0.03, 0.15, fur,
        inner: innerEar, tip: tipPink, tipFrom: 0.8, ovalZ: 0.55, tipR: 0.02, innerScale: 0.66);
  }
  _beanie(k, beanie, beanieCuff, y: 1.135, r: 0.19);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: hoodie, hand: fur, cuff: hoodieDark);
  }
  _legs(k, leg: jeans, shoe: 0xFFFFFF, sole: 0xE3DFD8);
  // Đuôi to cong.
  _chain(
      k.extra,
      const [(0, 0.35, -0.16), (0, 0.41, -0.32), (0, 0.55, -0.41), (0.01, 0.72, -0.39), (0.05, 0.84, -0.33)],
      const [0.056, 0.058, 0.056, 0.054],
      const [fur, fur, fur, tipPink],
      lat: 5,
      lon: 9);

  return k.build('regular_00', eyeY: eyeY, eyeZ: eyeZ, extraY: 0.36, extraZ: -0.16, extraKind: ChibiExtraKind.tail);
}

// ---- regular_01: hamster -----------------------------------------------------------------------------------------

ChibiModel _r01() {
  const fur = 0xF8DDB0;
  const cream = 0xFFF3E2;
  const inner = 0xF6B5B5;
  const nose = 0xE98A9A;
  const bow = 0xF5A9C0;
  const bowDark = 0xE58FAB;
  const mint = 0xBFE5CC;
  const butter = 0xFBE7A4;
  const denim = 0xAFC8E3;
  const denimDark = 0x98B4D6;

  final k = _Sketch(tilt: -0.09);
  // Đầu to tròn, má phúng phính.
  const head = ChibiSurface(0, 0.965, 0, 0.3, 0.265, 0.26);
  // Áo thun mint, yếm váy jean (thân trên hẹp + váy xoè ngắn), dây yếm.
  _torsoParts(k, mint, denim);
  _skirt(k, denim, hemY: 0.26, waistY: 0.45, flare: 0.05);
  // Yếm: miếng ngực + dây đeo vai + túi + khuy.
  k.body.shell(
    0,
    0,
    [
      for (final (y, off) in const [(0.44, 0.016), (0.5, 0.012), (0.56, 0.011), (0.61, 0.01)])
        () {
          final (rx, rz) = _wrapRadius(y, off);
          return (y, rx, rz, -0.62, 0.62);
        }(),
    ],
    denim,
    segments: 10,
  );
  final (px, py, pz, pb) = _wrapPoint(0, 0.52, 0.012, 0.004);
  k.body.dome(px, py, pz, 0.058, 0.045, 0.006, denimDark, basis: pb, segments: 10);
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, _) = _wrapPoint(side * 0.5, 0.605, 0.01, 0.003);
    k.body.capsule(x, y, z, side * 0.115, 0.69, -0.02, 0.016, 0.016, denim, radial: 5, capBands: 1);
    final (bx, by, bz, bb) = _wrapPoint(side * 0.5, 0.592, 0.01, 0.012);
    k.body.dome(bx, by, bz, 0.013, 0.013, 0.005, 0xF2D58A, basis: bb, segments: 6);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Hai bầu má kem to, mũi hồng to tròn.
  for (final side in const [1.0, -1.0]) {
    final (cx, cy, cz, cb) = head.at(side * 30, -30, lift: -0.04);
    k.head.ellipsoid(cx, cy, cz, 0.105, 0.082, 0.075, cream, basis: cb, lat: 5, lon: 10);
  }
  _nose(k, head, nose, el: -15, w: 0.027, h: 0.019);
  final (eyeY, eyeZ) = _eyesOn(k, head, 26, -3);
  _cheeks(k, head, 46, -17);
  _omega(k, head, -25);
  _freckles(k, head, 0xDDA070, az: 44, el: -9, spread: 5);
  // Tai tròn.
  for (final side in const [1.0, -1.0]) {
    _roundEar(k.head, side * 0.205, 1.175, -0.03, 0.095, fur, inner, tilt: -side * 0.2);
  }
  // Nơ hồng giữa đỉnh đầu.
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(side * 0.09, 1.255, 0.02, 0.09, 0.065, 0.032, bow,
        basis: ChibiBasis.euler(0, 0, side * 0.32), lat: 6, lon: 10);
    k.head.ellipsoid(side * 0.09, 1.258, 0.043, 0.055, 0.037, 0.012, bowDark,
        basis: ChibiBasis.euler(0, 0, side * 0.32), lat: 3, lon: 8);
  }
  k.head.sphere(0, 1.25, 0.022, 0.032, bowDark, lat: 4, lon: 8);

  // Tay: áo thun ngắn tay bơ, cẳng tay lông.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: butter, hand: fur, sleeveLen: 0.4, spread: 0.02);
  }
  _legs(k, leg: fur, shoe: 0xFFFFFF, sole: 0xF4B8C4, sock: 0xFFFFFF);

  return k.build('regular_01', eyeY: eyeY, eyeZ: eyeZ, radius: 0.25);
}

// ---- regular_02: cocker spaniel ----------------------------------------------------------------------------------

ChibiModel _r02() {
  const fur = 0xF2C88C;
  const brown = 0xD59E66;
  const muzzleC = 0xFFEBCB;
  const nose = 0x5A3F3C;
  const sweater = 0xFFF1DE;
  const sweaterDark = 0xF7B8C6;
  const jeans = 0xBFD8E6;

  final k = _Sketch(tilt: 0.09, earExtra: true);
  const head = ChibiSurface(0, 0.965, 0, 0.285, 0.26, 0.25);
  // Thân: áo len kem một mảnh (gộp croptop + cardigan), viền hồng ở gấu, jean nhạt ở hông.
  _torsoParts(k, sweater, jeans);
  _bandAt(k.body, 0.36, 0.04, sweaterDark, off: 0.006);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Mái lông mật ong đậm hơn trên đầu (ombre).
  k.head.ellipsoid(0, 1.05, -0.03, 0.288, 0.19, 0.258, brown, lat: 6, lon: 12);
  const muzzle = ChibiSurface(0, 0.875, 0.175, 0.125, 0.085, 0.125);
  _muzzle(k, muzzle, muzzleC, nose, noseEl: 22, noseW: 0.04, noseH: 0.029);
  _muzzleMouth(k, muzzle, el: -14);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -2);
  _cheeks(k, head, 46, -20);
  for (final side in const [1.0, -1.0]) {
    final (bx, by, bz, bb) = head.at(side * 26, 18, lift: 0.01);
    k.head.dome(bx, by, bz, 0.02, 0.014, 0.006, muzzleC, basis: bb, segments: 8);
  }

  // Tai dài nhỏ hơn, thẳng hơn (bộ phận phụ — ve vẩy): nâu ở gốc, mật ong ở đuôi tai.
  for (final side in const [1.0, -1.0]) {
    final pts = [
      (side * 0.27, 1.09, 0.0),
      (side * 0.3, 0.99, 0.0),
      (side * 0.312, 0.89, 0.012),
      (side * 0.316, 0.79, 0.02),
      (side * 0.31, 0.7, 0.025),
    ];
    _chain(k.extra, pts, const [0.07, 0.075, 0.075, 0.07], const [brown, brown, fur, fur],
        flat: 0.85, ovalX: 0.78, lat: 4, lon: 7);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: sweater, hand: fur, cuff: sweaterDark);
  }
  _legs(k, leg: jeans, shoe: 0xFFF6E6, sole: 0xE2D6C2);
  // Đuôi ngắn xù (tĩnh).
  _chain(k.body, const [(0, 0.34, -0.17), (0, 0.4, -0.27), (0, 0.5, -0.31)], const [0.058, 0.052], const [fur, fur],
      lat: 5, lon: 8);

  return k.build('regular_02',
      eyeY: eyeY, eyeZ: eyeZ, extraY: 1.09, extraZ: 0.0, extraKind: ChibiExtraKind.ears, radius: 0.3);
}

// ---- regular_03: nhím --------------------------------------------------------------------------------------------

ChibiModel _r03() {
  const spine = 0xB59A84;
  const spineTip = 0xD2BBA6;
  const face = 0xFFEBD3;
  const nose = 0x5A403A;
  const tee = 0xFFF6E6;
  const jeans = 0xB4CBE2;

  final k = _Sketch(tilt: -0.1);
  const head = ChibiSurface(0, 0.965, 0, 0.285, 0.262, 0.255);
  _torsoParts(k, tee, jeans);
  // In cupcake trước ngực (một phụ kiện nhận diện).
  final (px, py, pz, pb) = _wrapPoint(0, 0.5, 0.012, 0.003);
  k.body.frustum(px, py - 0.04, pz, px, py + 0.0, pz, 0.052, 0.06, 0xB8D8A8,
      radial: 10, ovalZ: 0.3, capA: false, capB: false);
  k.body.ellipsoid(px, py + 0.012, pz + 0.004, 0.066, 0.033, 0.014, 0xF4A9C0, lat: 4, lon: 10);
  k.body.ellipsoid(px, py + 0.032, pz + 0.006, 0.044, 0.024, 0.012, 0xF8BCD0, lat: 3, lon: 10);
  _sph(k.body, px, py + 0.053, pz + 0.008, 0.014, 0xE0505E, lat: 4, lon: 6);
  // Lưng nhím: hàng cục tròn sau thân.
  k.body.ellipsoid(0, 0.5, -0.15, 0.17, 0.21, 0.09, spine, lat: 5, lon: 10);
  for (final (x, y) in const [
    (-0.09, 0.6),
    (0.0, 0.62),
    (0.09, 0.6),
    (-0.1, 0.48),
    (0.1, 0.48),
    (0.0, 0.5),
    (-0.07, 0.38),
    (0.07, 0.38),
  ]) {
    _sph(k.body, x, y, -0.2, 0.07, spine, lat: 3, lon: 6);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, face, lat: 9, lon: 14);
  // Mũi tròn nhô ra; chóp mũi nâu đậm.
  const muzzle = ChibiSurface(0, 0.895, 0.185, 0.1, 0.075, 0.125);
  k.head.ellipsoid(muzzle.cx, muzzle.cy, muzzle.cz, muzzle.rx, muzzle.ry, muzzle.rz, face, lat: 6, lon: 12);
  final (nx, ny, nz, nb) = muzzle.at(0, 12, lift: 0.004);
  k.head.ellipsoid(nx, ny, nz, 0.038, 0.029, 0.026, nose, basis: nb, lat: 4, lon: 8);
  _muzzleMouth(k, muzzle, el: -18, r: 0.011);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -2);
  _cheeks(k, head, 46, -20);
  // Mái gai ngắn đầu tròn xếp đều như mái tròn: cụm cầu phủ đỉnh và sau đầu, chừa mặt.
  k.head.ellipsoid(0, 1.0, -0.06, 0.285, 0.25, 0.24, spine, lat: 7, lon: 14);
  for (final (el, step, r) in const [(68.0, 120.0, 0.09), (48.0, 60.0, 0.09), (28.0, 60.0, 0.09), (8.0, 60.0, 0.085)]) {
    for (var az = -180.0 + step / 2; az < 180; az += step) {
      final front = az.abs() < 56 && el < 44 || az.abs() < 70 && el < 14;
      if (front) continue;
      final (x, y, z, _) = head.at(az, el, lift: -0.02);
      final tipOdd = ((az + el) ~/ 25).isOdd;
      _sph(k.head, x, y, z, r, tipOdd ? spine : spineTip, lat: 3, lon: 6);
    }
  }
  // Tai tròn nhỏ.
  for (final side in const [1.0, -1.0]) {
    _roundEar(k.head, side * 0.225, 1.115, 0.0, 0.065, face, 0xF9C7B8, tilt: -side * 0.3);
  }

  // Tay: tay áo thun cộc, cẳng tay lông kem.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: tee, hand: face, sleeveLen: 0.45, skin: face);
  }
  _legs(k, leg: jeans, shoe: 0xFFF3E0, sole: 0xE2D6C2);

  return k.build('regular_03', eyeY: eyeY, eyeZ: eyeZ, radius: 0.27);
}

// ---- regular_04: sóc ---------------------------------------------------------------------------------------------

ChibiModel _r04() {
  const fur = 0xD9985E;
  const cream = 0xFFEFDA;
  const dark = 0x9A6A4C;
  const inner = 0xF8CDB8;
  const nose = 0x5A3A30;
  const braid = 0xA8704E;
  const tie = 0xF4A9B8;
  const hat = 0xFFDF8A;
  const hatBand = 0xF6B08C;
  const jacket = 0xA9C8E6;
  const jacketDark = 0x92B2D4;
  const mint = 0xC5EAD4;
  const skirt = 0xF7C6CF;

  final k = _Sketch(tilt: 0.1);
  const head = _headStd;
  // Áo mint, áo khoác jean ngắn mở trước, váy xoè ngắn.
  _torsoParts(k, mint, skirt);
  _skirt(k, skirt, hemY: 0.25, waistY: 0.42, flare: 0.07);
  _jacket(k, jacket, hemY: 0.38, vLow: 0.12, vHigh: 0.55, off: 0.014);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  const muzzle = ChibiSurface(0, 0.89, 0.155, 0.1, 0.072, 0.1);
  _muzzle(k, muzzle, cream, nose, noseEl: 20, noseW: 0.027, noseH: 0.02);
  _muzzleMouth(k, muzzle, el: -14);
  // Má kem phúng phính.
  _puffCheeks(k, head, cream, az: 17, el: -22, r: 0.05);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -3);
  _cheeks(k, head, 45, -21);
  // Tai nhọn to có chùm lông ngắn (thò ra hai bên mũ).
  for (final side in const [1.0, -1.0]) {
    _coneEar(k.head, side * 0.22, 1.04, -0.02, side * 0.345, 1.235, -0.03, 0.105, fur, inner: inner, ovalZ: 0.5);
    k.head.frustum(side * 0.332, 1.215, -0.03, side * 0.358, 1.275, -0.03, 0.03, 0, dark,
        radial: 6, ovalZ: 0.6, capA: false, capB: false);
  }
  _bucketHat(k, hat, hatBand, y: 1.15, r: 0.18);
  // Hai bím ngắn: hai đốt mỗi bên, buộc dây hồng ở cuối.
  for (final side in const [1.0, -1.0]) {
    for (final (i, y, r) in const [(0, 0.93, 0.062), (1, 0.84, 0.056)]) {
      k.head.ellipsoid(side * (0.275 + i * 0.012), y, 0.015, r, 0.056, r * 0.9, braid, lat: 4, lon: 8);
    }
    k.head.sphere(side * 0.292, 0.785, 0.015, 0.027, tie, lat: 4, lon: 7);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: jacket, hand: fur, cuff: jacketDark, spread: 0.035);
  }
  _legs(k, leg: fur, shoe: 0xE6DEF4, sole: 0xFFFFFF);
  // Đuôi to xù (bộ phận phụ, vẫy): cong hình chữ S lên trên lưng, sọc kem.
  const tail = [
    (0.0, 0.35, -0.16),
    (0.0, 0.4, -0.32),
    (0.0, 0.56, -0.43),
    (0.0, 0.78, -0.46),
    (0.0, 0.97, -0.38),
    (0.0, 1.08, -0.25),
  ];
  _chain(k.extra, tail, const [0.13, 0.165, 0.19, 0.175, 0.125], const [fur, fur, cream, fur, dark],
      lat: 6, lon: 10, flat: 0.9);

  return k.build('regular_04',
      eyeY: eyeY, eyeZ: eyeZ, extraY: 0.36, extraZ: -0.16, extraKind: ChibiExtraKind.tail, radius: 0.28);
}

// ---- regular_05: shiba -------------------------------------------------------------------------------------------

ChibiModel _r05() {
  const fur = 0xF0B572;
  const cream = 0xFFF3DE;
  const inner = 0xFFE2C6;
  const nose = 0x4A3A36;
  const cap = 0xB7B0E8;
  const capDark = 0xA29BD8;
  const tee = 0xFFFBF2;
  const sun = 0xFFA84A;
  const shorts = 0xF0DDB4;

  final k = _Sketch(tilt: -0.1);
  const head = ChibiSurface(0, 0.965, 0, 0.29, 0.258, 0.252);
  _torsoParts(k, tee, shorts);
  // Hình mặt trời nhỏ trước ngực.
  final (sx, sy, sz, sb) = _wrapPoint(0.5, 0.56, 0.012, 0.002);
  k.body.dome(sx, sy, sz, 0.03, 0.03, 0.005, sun, basis: sb, segments: 12);
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final (rx, ry, rz) = (
      sx + sb.xx * math.cos(a) * 0.048 + sb.yx * math.sin(a) * 0.048,
      sy + sb.xy * math.cos(a) * 0.048 + sb.yy * math.sin(a) * 0.048,
      sz + sb.xz * math.cos(a) * 0.048 + sb.yz * math.sin(a) * 0.048
    );
    k.body.dome(rx, ry, rz, 0.009, 0.009, 0.004, sun, basis: sb, segments: 5);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Má trắng (urajiro) to, mõm kem ngắn.
  for (final side in const [1.0, -1.0]) {
    final (cx, cy, cz, cb) = head.at(side * 36, -22, lift: -0.04);
    k.head.ellipsoid(cx, cy, cz, 0.105, 0.088, 0.072, cream, basis: cb, lat: 5, lon: 10);
    final (bx, by, bz, bb) = head.at(side * 27, 22, lift: 0.008);
    k.head.dome(bx, by, bz, 0.028, 0.018, 0.006, cream, basis: bb, segments: 8);
  }
  const muzzle = ChibiSurface(0, 0.875, 0.165, 0.115, 0.08, 0.105);
  _muzzle(k, muzzle, cream, nose, noseEl: 20, noseW: 0.037, noseH: 0.026);
  _muzzleMouth(k, muzzle, el: -14);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -2);
  _cheeks(k, head, 52, -20);
  // Tai nhọn dựng to, lòng kem (thò ra hai bên mũ).
  for (final side in const [1.0, -1.0]) {
    _coneEar(k.head, side * 0.2, 1.09, -0.02, side * 0.245, 1.39, -0.03, 0.118, fur, inner: inner, ovalZ: 0.55);
  }
  // Mũ lưỡi trai nhỏ trên đỉnh đầu: vòm + lưỡi trai ngắn + nút.
  k.head.ellipsoid(0, 1.155, -0.02, 0.2, 0.1, 0.2, cap, lat: 7, lon: 16);
  k.head
      .frustum(0, 1.115, -0.02, 0, 1.17, -0.02, 0.205, 0.2, capDark, radial: 14, ovalZ: 0.98, capA: false, capB: false);
  k.head.ellipsoid(0, 1.14, 0.2, 0.11, 0.014, 0.095, capDark, basis: ChibiBasis.euler(0.28, 0, 0), lat: 3, lon: 12);
  k.head.sphere(0, 1.25, -0.02, 0.02, 0xFFFFFF, lat: 3, lon: 6);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: tee, hand: fur, sleeveLen: 0.42);
  }
  _legs(k, leg: fur, shoe: 0xFFFFFF, sole: 0xA8DCC8, shorts: shorts, shortsLen: 0.1, sock: 0xFFFFFF);
  // Đuôi cuộn tròn trên lưng to hơn: cung vòng, mặt dưới kem.
  const tail = [(0.0, 0.35, -0.16), (0.0, 0.46, -0.3), (0.0, 0.63, -0.35), (0.0, 0.77, -0.25), (0.0, 0.77, -0.1)];
  _chain(k.extra, tail, const [0.095, 0.12, 0.12, 0.105], const [fur, fur, fur, cream], lat: 6, lon: 10);

  return k.build('regular_05', eyeY: eyeY, eyeZ: eyeZ, extraY: 0.36, extraZ: -0.16, extraKind: ChibiExtraKind.tail);
}

// ---- regular_06: mèo tím than, chấm mòng két trên trán ------------------------------------------------------------

ChibiModel _r06() {
  const fur = 0x4A3F5C;
  const inner = 0xF0A5BE;
  const nose = 0xF08FAB;
  const teal = 0x2DB5A8;
  const eye = 0xF4C542;
  const hoodie = 0xD2BFEF;
  const hoodieDark = 0xBBA4E0;
  const jeans = 0xC5D6EC;

  final k = _Sketch(tilt: 0.1);
  const head = _headStd;
  _hoodie(k, hoodie, hoodieDark, 0xFFFFFF);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Chấm mòng két nhỏ trên trán.
  final (tx, ty, tz, tb) = head.at(-10, 44, lift: -0.004);
  k.head.dome(tx, ty, tz, 0.026, 0.026, 0.009, teal, basis: tb, segments: 10);
  _nose(k, head, nose);
  _puffCheeks(k, head, fur, az: 10, el: -23, r: 0.038);
  // Mắt tròn to, tròng vàng + đồng tử.
  final (eyeY, eyeZ) = _eyesOn(k, head, 29.5, -4, w: 0.062, h: 0.07, iris: eye);
  _cheeks(k, head, 45, -23, color: 0xF08DA2, w: 0.064);
  _omega(k, head, -23, color: 0xE59AAB);
  // Tai nhọn to, lòng hồng sáng.
  for (final side in const [1.0, -1.0]) {
    _coneEar(k.head, side * 0.175, 1.115, -0.02, side * 0.225, 1.4, -0.035, 0.12, fur,
        inner: inner, ovalZ: 0.44, innerScale: 0.66);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: hoodie, hand: fur, cuff: hoodieDark);
  }
  _legs(k, leg: jeans, shoe: 0xFFFFFF, sole: 0xE6E0F0);
  _chain(k.extra, const [(0, 0.35, -0.16), (0, 0.42, -0.31), (0, 0.58, -0.4), (0.0, 0.78, -0.39), (0.04, 0.93, -0.33)],
      const [0.055, 0.057, 0.055, 0.052], const [fur, fur, fur, fur],
      lat: 5, lon: 9);

  return k.build('regular_06', eyeY: eyeY, eyeZ: eyeZ, extraY: 0.36, extraZ: -0.16, extraKind: ChibiExtraKind.tail);
}

// ---- regular_07: koala -------------------------------------------------------------------------------------------

ChibiModel _r07() {
  const fur = 0xB9C6D8;
  const fluff = 0xE8EEF6;
  const innerEar = 0xF7EAEE;
  const nose = 0x4B4553;
  const cream = 0xFFF3E2;
  const stripeC = 0xA9CBEB;
  const chino = 0xEAD9BC;
  const pack = 0xB5C8A0;
  const packFlap = 0xD7B58C;

  final k = _Sketch(tilt: -0.09);
  const head = ChibiSurface(0, 0.965, 0, 0.3, 0.265, 0.258);
  _torsoParts(k, cream, chino);
  for (final y in const [0.4, 0.47, 0.54, 0.61]) {
    _bandAt(k.body, y, 0.032, stripeC);
  }
  // Ba lô vải sage nhỏ (quai nâu nhạt chéo trước ngực).
  k.body.ellipsoid(0, 0.5, -0.21, 0.115, 0.13, 0.065, pack, lat: 5, lon: 10);
  k.body.ellipsoid(0, 0.57, -0.235, 0.115, 0.055, 0.06, packFlap, lat: 3, lon: 10);
  for (final side in const [1.0, -1.0]) {
    k.body.capsule(side * 0.115, 0.69, -0.05, side * 0.122, 0.5, 0.195, 0.016, 0.016, packFlap, radial: 5, capBands: 1);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Mõm xám nhạt, mũi bầu dục to tròn (không quá đen).
  final (mx, my, mz, mb) = head.at(0, -10, lift: -0.006);
  k.head.ellipsoid(mx, my, mz, 0.095, 0.075, 0.052, fluff, basis: mb, lat: 5, lon: 10);
  final (nx, ny, nz, nb) = head.at(0, -2, lift: 0.01);
  k.head.ellipsoid(nx, ny, nz, 0.05, 0.07, 0.04, nose, basis: nb, lat: 5, lon: 10);
  final (sx, sy, sz, sb) = head.at(-3, 3, lift: 0.045);
  k.head.dome(sx - 0.018, sy + 0.025, sz, 0.014, 0.019, 0.007, 0xF3F6FA, basis: sb, segments: 8);
  final (eyeY, eyeZ) = _eyesOn(k, head, 26, 0, w: 0.056, h: 0.072);
  _cheeks(k, head, 49, -22);
  _omega(k, head, -29, r: 0.011);
  // Tai tròn to (+25%) xù, lòng sáng.
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(side * 0.225, 1.17, -0.045, 0.158, 0.158, 0.05, fluff,
        basis: ChibiBasis.euler(0, 0, -side * 0.25), lat: 5, lon: 10);
    _roundEar(k.head, side * 0.225, 1.17, -0.02, 0.138, fur, innerEar, tilt: -side * 0.25, innerScale: 0.7);
  }
  // Mái xù xám xanh.
  k.head.ellipsoid(0, 1.2, -0.01, 0.2, 0.06, 0.2, 0xA9B7CA, lat: 5, lon: 12);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: cream, hand: fur, sleeveLen: 0.48, skin: fur);
  }
  _legs(k, leg: chino, shoe: 0xCDB08A, sole: 0xF1E8D8);

  return k.build('regular_07', eyeY: eyeY, eyeZ: eyeZ, radius: 0.28);
}

// ---- regular_08: mèo xiêm ----------------------------------------------------------------------------------------

ChibiModel _r08() {
  const fur = 0xFAEEDB;
  const point = 0xB8987C;
  const mask = 0xCDAE92;
  const innerEar = 0xF3C2C0;
  const beret = 0xA8DCC8;
  const top = 0xFFF3E4;
  const stripe = 0xA9CBEB;
  const skirt = 0xF6C3CE;
  const shoe = 0xFFFFFF;

  final k = _Sketch(tilt: 0.1);
  const head = _headStd;
  _torsoParts(k, top, skirt);
  for (final y in const [0.4, 0.47, 0.54, 0.61]) {
    _bandAt(k.body, y, 0.03, stripe);
  }
  _skirt(k, skirt, hemY: 0.25, waistY: 0.4, flare: 0.08, pleats: 8);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Mặt nạ be nhỏ quanh mũi, không phủ miệng.
  const muzzle = ChibiSurface(0, 0.895, 0.16, 0.088, 0.058, 0.09);
  _muzzle(k, muzzle, mask, 0x8A6A5A, noseEl: 22, noseW: 0.03, noseH: 0.022);
  _muzzleMouth(k, muzzle, el: -17, color: 0x8A5A50);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -3);
  _cheeks(k, head, 45, -22, color: 0xF3A0AD);
  // Tai nhọn be đậm, lòng hồng.
  for (final side in const [1.0, -1.0]) {
    _coneEar(k.head, side * 0.17, 1.09, -0.02, side * 0.215, 1.375, -0.035, 0.12, point, inner: innerEar, ovalZ: 0.44);
  }
  // Beret mint nhỏ lệch, trên đỉnh đầu.
  _beret(k, beret, y: 1.2, tiltZ: 0.1, r: 0.17);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: top, hand: point, cuff: stripe, spread: 0.03);
  }
  _legs(k, leg: fur, shoe: shoe, sole: 0xE6D9C6, sock: 0xFFF1D8);
  const tail = [(0.0, 0.35, -0.16), (0.0, 0.4, -0.32), (0.0, 0.53, -0.43), (0.0, 0.7, -0.41), (0.03, 0.85, -0.33)];
  _chain(k.extra, tail, const [0.055, 0.056, 0.054, 0.05], const [point, point, point, point], lat: 5, lon: 9);

  return k.build('regular_08', eyeY: eyeY, eyeZ: eyeZ, extraY: 0.36, extraZ: -0.16, extraKind: ChibiExtraKind.tail);
}

// ---- regular_09: voi nhỏ (bà ~50) --------------------------------------------------------------------------------

ChibiModel _r09() {
  const fur = 0xCFC6DC;
  const innerEar = 0xF6CCD8;
  const hair = 0xEDE5EE;
  const gold = 0xEAC16A;
  const cardi = 0xF3B8C4;
  const blouse = 0xFFF4E4;
  const skirt = 0xFBE7A4;
  const shoe = 0xE5C7A8;

  final k = _Sketch(tilt: -0.09);
  const head = ChibiSurface(0, 0.965, 0, 0.29, 0.262, 0.254);
  _torsoParts(k, blouse, skirt);
  _skirt(k, skirt, hemY: 0.25, waistY: 0.42, flare: 0.07, pleats: 9);
  _jacket(k, cardi, hemY: 0.36, vLow: 0.1, vHigh: 0.58, off: 0.013);
  // Trâm hoa nhỏ ở ve áo (một phụ kiện).
  final (bx, by, bz, bb) = _wrapPoint(-0.55, 0.57, 0.013, 0.006);
  for (var i = 0; i < 5; i++) {
    final a = i * 2 * math.pi / 5;
    k.body.ellipsoid(bx + math.cos(a) * 0.02, by + math.sin(a) * 0.02, bz + 0.002, 0.013, 0.013, 0.009, 0xFFFFFF,
        basis: bb, lat: 3, lon: 6);
  }
  k.body.sphere(bx, by, bz + 0.005, 0.009, gold, lat: 3, lon: 6);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Vòi ngắn mập rủ trước mặt, chóp cong có hai lỗ mũi.
  _chain(k.head, const [(0, 0.925, 0.2), (0, 0.84, 0.27), (0, 0.765, 0.295)], const [0.108, 0.098], const [fur, fur],
      lat: 6, lon: 10, flat: 0.95);
  k.head.ellipsoid(0, 0.73, 0.305, 0.076, 0.062, 0.062, fur, lat: 5, lon: 10);
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(side * 0.022, 0.71, 0.358, 0.012, 0.01, 0.008, 0x8A7F96, lat: 3, lon: 6);
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 28, -2);
  _cheeks(k, head, 52, -20, w: 0.058);
  // Tai voi to tròn hai bên, lòng hồng.
  for (final side in const [1.0, -1.0]) {
    final b = ChibiBasis.euler(0, side * 0.5, side * 0.1);
    k.head.ellipsoid(side * 0.325, 0.99, -0.03, 0.05, 0.2, 0.17, fur, basis: b, lat: 6, lon: 12);
    k.head.dome(side * 0.325 + b.zx * 0.04, 0.985, -0.03 + b.zz * 0.04, 0.15, 0.17, 0.011, innerEar,
        basis: ChibiBasis.facing(side * 0.9, 0, 0.45), segments: 12);
  }
  // Tóc kem-bạc: mái ôm đầu + búi tròn nhỏ ở đỉnh sau.
  k.head.ellipsoid(0, 1.07, -0.07, 0.296, 0.19, 0.245, hair, lat: 7, lon: 14);
  k.head.sphere(0, 1.2, -0.17, 0.09, hair, lat: 6, lon: 10);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: cardi, hand: fur, spread: 0.03);
  }
  _legs(k, leg: fur, shoe: shoe, sole: 0xE9DAC6);
  // Đuôi nhỏ xíu (tĩnh).
  k.body.ellipsoid(0, 0.3, -0.2, 0.03, 0.065, 0.03, fur, basis: ChibiBasis.euler(-0.5, 0, 0), lat: 4, lon: 7);

  return k.build('regular_09',
      eyeY: eyeY,
      eyeZ: eyeZ,
      gait: const ChibiGait(speed: 0.8, legSwing: 0.4, armSwing: 0.45, stride: 0.46, waddle: 0.06, bob: 0.03),
      radius: 0.3);
}

// ---- regular_10: poodle kem hồng ---------------------------------------------------------------------------------

ChibiModel _r10() {
  const fur = 0xF4E4DE;
  const furLight = 0xFFF8F2;
  const nose = 0x5A4650;
  const butter = 0xFBE3A0;
  const butterDark = 0xF2D07E;
  const pants = 0xBCD3EC;
  const shoe = 0xF1B8C4;

  final k = _Sketch(tilt: 0.1);
  const head = ChibiSurface(0, 0.965, 0, 0.285, 0.26, 0.25);
  // Áo len cổ lọ vàng bơ nhạt, quần xanh nhạt, khăn len sọc.
  _torsoParts(k, butter, pants);
  for (final y in const [0.43, 0.5, 0.57]) {
    _bandAt(k.body, y, 0.014, butterDark, off: 0.002);
  }
  k.body.torus(0, 0.7, -0.01, 0.112, 0.036, butter, basis: ChibiBasis.facing(0, 1, 0), segments: 12, tube: 5);
  _scarf(k, const [0xFFF1DC, 0xF3B5C2, 0xBFE5CC], ringR: 0.128, tube: 0.04, y: 0.668);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  const muzzle = ChibiSurface(0, 0.875, 0.165, 0.11, 0.08, 0.105);
  _muzzle(k, muzzle, furLight, nose, noseEl: 20, noseW: 0.037, noseH: 0.026);
  _muzzleMouth(k, muzzle, el: -14);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -2);
  _cheeks(k, head, 46, -20);
  // Lông uốn xù: chỏm cụm tròn đối xứng trên đầu, hai tai lông rủ, mỗi bên một cục lông mép.
  for (final (x, y, z, r) in const [
    (0.0, 1.22, 0.0, 0.12),
    (0.115, 1.18, 0.0, 0.105),
    (-0.115, 1.18, 0.0, 0.105),
    (0.0, 1.17, 0.105, 0.1),
    (0.0, 1.17, -0.105, 0.1),
    (0.18, 1.12, 0.08, 0.085),
    (-0.18, 1.12, 0.08, 0.085),
    (0.18, 1.12, -0.09, 0.085),
    (-0.18, 1.12, -0.09, 0.085),
  ]) {
    _sph(k.head, x, y, z, r, fur, lat: 3, lon: 6);
  }
  for (final side in const [1.0, -1.0]) {
    for (final (y, r) in const [(1.0, 0.1), (0.9, 0.105), (0.8, 0.098)]) {
      _sph(k.head, side * 0.3, y, 0.0, r, fur, lat: 3, lon: 6);
    }
    _sph(k.head, side * 0.24, 0.9, 0.06, 0.06, fur, lat: 3, lon: 6);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: butter, hand: fur, cuff: butterDark);
  }
  _legs(k, leg: pants, shoe: shoe, sole: 0xFFF3E6);
  // Đuôi: cuống mảnh + cục lông tròn to (poodle).
  _chain(k.extra, const [(0, 0.35, -0.16), (0, 0.42, -0.27)], const [0.036], const [fur], lat: 4, lon: 7);
  _sph(k.extra, 0, 0.48, -0.3, 0.1, fur, lat: 6, lon: 10);

  return k.build('regular_10',
      eyeY: eyeY,
      eyeZ: eyeZ,
      extraY: 0.36,
      extraZ: -0.16,
      extraKind: ChibiExtraKind.tail,
      gait: const ChibiGait(speed: 0.8, legSwing: 0.4, armSwing: 0.45, stride: 0.46, waddle: 0.06, bob: 0.03),
      radius: 0.3);
}

// ---- regular_11: thỏ tai cụp kem hồng ----------------------------------------------------------------------------

ChibiModel _r11() {
  const fur = 0xF8E6D8;
  const inner = 0xF8C8C0;
  const nose = 0xEF9A94;
  const strawC = 0xF0D79A;
  const hatBand = 0xF7B8C6;
  const sweater = 0xBFE5CC;
  const linen = 0xFFF1DC;
  const shoe = 0xE9B8A0;
  const basket = 0xE0BB78;
  const basketDark = 0xC8A05C;
  const bread = 0xE9B468;

  final k = _Sketch(tilt: -0.09, earExtra: true);
  const head = _headStd;
  _torsoParts(k, sweater, linen);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  _nose(k, head, nose);
  _puffCheeks(k, head, fur, az: 9, el: -23, r: 0.043);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -4);
  _cheeks(k, head, 45, -23);
  _omega(k, head, -23);
  // Mái nhỏ kem hồng đậm hơn dưới mũ.
  k.head.ellipsoid(0, 1.1, -0.04, 0.27, 0.15, 0.24, 0xEED2C0, lat: 6, lon: 14);
  // Mũ cói nhỏ trên đỉnh đầu: vành dẹt + chóp + dải hồng; lộ tai cụp.
  k.head.ellipsoid(0, 1.19, -0.01, 0.285, 0.026, 0.285, strawC, basis: ChibiBasis.euler(0.06, 0, 0), lat: 3, lon: 18);
  k.head.ellipsoid(0, 1.225, -0.02, 0.17, 0.095, 0.165, strawC, lat: 6, lon: 14);
  k.head.frustum(0, 1.185, -0.02, 0, 1.23, -0.02, 0.18, 0.176, hatBand,
      radial: 14, ovalZ: 0.97, capA: false, capB: false);

  // Tai cụp to hơn (bộ phận phụ): rủ dọc hai bên mặt từ dưới vành mũ, lòng hồng.
  for (final side in const [1.0, -1.0]) {
    final pts = [
      (side * 0.215, 1.1, -0.01),
      (side * 0.31, 0.98, -0.01),
      (side * 0.345, 0.84, 0.005),
      (side * 0.345, 0.7, 0.02),
    ];
    _chain(k.extra, pts, const [0.082, 0.095, 0.09], const [fur, fur, fur], flat: 0.7, ovalX: 0.82, lat: 5, lon: 8);
    k.extra.dome(side * 0.336, 0.86, 0.074, 0.042, 0.12, 0.014, inner,
        basis: ChibiBasis.facing(side * 0.25, 0, 1), segments: 10);
  }

  _arm(k, 1, sleeve: sweater, hand: fur, cuff: 0xA8D7BC);
  _arm(k, -1, sleeve: sweater, hand: fur, cuff: 0xA8D7BC);
  // Giỏ cói xách ở tay trái (xoay theo tay): thân giỏ + quai + ổ bánh mì (nhỏ 25%).
  final (hx, hy, hz) = _handC(1);
  final ba = k.arm(1);
  ba.torus(hx, hy + 0.045, hz, 0.04, 0.007, basketDark,
      basis: ChibiBasis.facing(0, 0, 1).then(ChibiBasis.euler(0, math.pi / 2, 0)),
      a0: 0,
      a1: math.pi,
      segments: 8,
      tube: 3);
  ba.ellipsoid(hx + 0.01, hy - 0.045, hz, 0.08, 0.066, 0.056, basket, lat: 5, lon: 10);
  ba.capsule(hx + 0.01, hy - 0.03, hz, hx + 0.04, hy + 0.08, hz - 0.03, 0.021, 0.019, bread, radial: 6, capBands: 1);
  _legs(k, leg: linen, shoe: shoe, sole: 0xF3E6D2);
  // Đuôi bông tròn (tĩnh).
  k.body.sphere(0, 0.33, -0.2, 0.07, 0xFFFFFF, lat: 5, lon: 8);

  return k.build('regular_11',
      eyeY: eyeY, eyeZ: eyeZ, extraY: 1.1, extraZ: -0.01, extraKind: ChibiExtraKind.ears, radius: 0.31);
}

// ---- regular_12: schnauzer bạc sáng (thú lớn) --------------------------------------------------------------------

ChibiModel _r12() {
  const fur = 0xDDE0E8;
  const furSoft = 0xEFF1F5;
  const earC = 0xC4C9D6;
  const face = 0xFFF3E6;
  const nose = 0x5A4C54;
  const shirt = 0xFFF4E6;
  const overalls = 0x93ADD8;
  const overallsDark = 0x7F9AC8;
  const shoe = 0xF3E3CF;

  final k = _Sketch(tilt: 0.08);
  const head = ChibiSurface(0, 0.965, 0, 0.29, 0.265, 0.255);
  // Áo cổ tròn kem + yếm denim nhạt (quần yếm ở hông, miếng ngực + dây vai + túi).
  _torsoParts(k, shirt, overalls);
  k.body.shell(
    0,
    0,
    [
      for (final (y, off) in const [(0.4, 0.016), (0.48, 0.012), (0.56, 0.011), (0.62, 0.01)])
        () {
          final (rx, rz) = _wrapRadius(y, off);
          return (y, rx, rz, -0.66, 0.66);
        }(),
    ],
    overalls,
    segments: 12,
  );
  final (px, py, pz, pb) = _wrapPoint(0, 0.5, 0.012, 0.004);
  k.body.dome(px, py, pz, 0.06, 0.046, 0.006, overallsDark, basis: pb, segments: 10);
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, _) = _wrapPoint(side * 0.55, 0.615, 0.01, 0.003);
    k.body.capsule(x, y, z, side * 0.12, 0.7, -0.02, 0.017, 0.017, overalls, radial: 5, capBands: 1);
    final (bx, by, bz, bb) = _wrapPoint(side * 0.55, 0.6, 0.01, 0.012);
    k.body.dome(bx, by, bz, 0.014, 0.014, 0.005, 0xFFE9A8, basis: bb, segments: 6);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Mặt kem tròn quanh mõm (không ria, không râu), mũi to tròn.
  const muzzle = ChibiSurface(0, 0.88, 0.17, 0.12, 0.085, 0.11);
  _muzzle(k, muzzle, face, nose, noseEl: 22, noseW: 0.04, noseH: 0.029);
  _muzzleMouth(k, muzzle, el: -14);
  final (eyeY, eyeZ) = _eyesOn(k, head, 27, -2);
  _cheeks(k, head, 47, -20, w: 0.062);
  // Lông mày: hai vệt dẹt nhỏ dán sát mặt, đuôi rủ xuống (hiền), không nhô.
  for (final side in const [1.0, -1.0]) {
    final (wx, wy, wz, wb) = head.at(side * 27, 18, lift: -0.001);
    k.head.dome(wx, wy, wz, 0.04, 0.012, 0.004, furSoft,
        basis: wb.then(ChibiBasis.euler(0, 0, -side * 0.18)), segments: 12);
  }
  // Cụm lông xù trên đỉnh đầu (mây tròn) + tai cụp to gập về trước.
  for (final (x, y, z, r) in const [(0.0, 1.2, 0.02, 0.11), (0.1, 1.17, -0.02, 0.095), (-0.1, 1.17, -0.02, 0.095)]) {
    _sph(k.head, x, y, z, r, furSoft, lat: 4, lon: 8);
  }
  for (final side in const [1.0, -1.0]) {
    _chain(k.head, [(side * 0.17, 1.15, 0.03), (side * 0.275, 1.07, 0.08), (side * 0.325, 0.95, 0.12)],
        const [0.105, 0.08], const [earC, earC],
        flat: 0.5, ovalX: 1.0, lat: 5, lon: 8);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: shirt, hand: fur, cuff: furSoft);
  }
  _legs(k, leg: overalls, shoe: shoe, sole: 0xE2D4BE);
  k.body.sphere(0, 0.33, -0.19, 0.06, fur, lat: 5, lon: 8);

  return k.build('regular_12', eyeY: eyeY, eyeZ: eyeZ, radius: 0.3);
}

// ---- regular_13: hải mã (mascot) ---------------------------------------------------------------------------------

ChibiModel _r13() {
  const skin = 0xD9B99C;
  const pad = 0xF3E1CC;
  const tusk = 0xFFF8E8;
  const beret = 0xBBD3EE;
  const sweater = 0xFFF1DE;
  const coral = 0xF2A58F;
  const shorts = 0xDCC29C;
  const shoe = 0xB98E70;

  final k = _Sketch(tilt: 0.1);
  const head = ChibiSurface(0, 0.955, 0, 0.3, 0.255, 0.265);
  k.body.ellipsoid(_torso.cx, _torso.cy, _torso.cz, 0.225, _torso.ry, 0.2, sweater, lat: 7, lon: 10);
  k.body.ellipsoid(_hips.cx, _hips.cy, _hips.cz, 0.21, _hips.ry, 0.185, shorts, lat: 4, lon: 10);
  // Hai dải san hô quanh ngực áo len (ít màu).
  for (final y in const [0.5, 0.58]) {
    final t = (y - 0.48) / 0.245;
    final kk = math.sqrt(math.max(0, 1 - t * t));
    k.body.frustum(0, y, 0, 0, y + 0.028, 0, 0.225 * kk + 0.004, 0.225 * kk + 0.004, coral,
        radial: 14, ovalZ: 0.89, capA: false, capB: false);
  }

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, skin, lat: 9, lon: 14);
  // Hai bầu mõm kem tròn, mũi to hồng, hai nhú nanh nhỏ.
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(side * 0.065, 0.855, 0.205, 0.11, 0.085, 0.095, pad, lat: 5, lon: 10);
    k.head.capsule(side * 0.075, 0.8, 0.278, side * 0.078, 0.765, 0.288, 0.019, 0.015, tusk, radial: 6, capBands: 2);
  }
  k.head.ellipsoid(0, 0.9, 0.268, 0.058, 0.04, 0.034, 0xF2A0AE, lat: 4, lon: 10);
  final (eyeY, eyeZ) = _eyesOn(k, head, 25, 0, w: 0.054, h: 0.072);
  _cheeks(k, head, 50, -17, w: 0.062);
  // Mái nhẹ + beret xanh nhạt nhỏ lệch.
  k.head.ellipsoid(0, 1.07, -0.05, 0.285, 0.17, 0.24, 0xC9A486, lat: 6, lon: 14);
  _beret(k, beret, y: 1.2, tiltZ: -0.14, r: 0.17);

  // Tay: tay áo len kem; bàn tay như chân chèo (dẹt, to).
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: sweater, hand: skin, rHand: 0.07, handLong: 0.92);
  }
  _legs(k, leg: shorts, shoe: shoe, sole: 0xF1E4D0, r: 0.08);

  return k.build('regular_13',
      eyeY: eyeY,
      eyeZ: eyeZ,
      gait: const ChibiGait(speed: 0.8, legSwing: 0.4, armSwing: 0.45, stride: 0.46, waddle: 0.07, bob: 0.03),
      radius: 0.32);
}

// ---- regular_14: sư tử vàng mật ong ------------------------------------------------------------------------------

ChibiModel _r14() {
  const fur = 0xF6D390;
  const muzzleC = 0xFFF3DC;
  const mane = 0xE6AE6E;
  const maneDark = 0xD79A58;
  const nose = 0xC9726A;
  const inner = 0xF9CDB0;
  const sweater = 0xBFE5CC;
  const sweaterDark = 0xA8D7BC;
  const trousers = 0xC1D7EE;
  const shoe = 0xE9C9A6;

  final k = _Sketch(tilt: -0.1);
  const head = ChibiSurface(0, 0.965, 0, 0.3, 0.27, 0.262);
  // Áo len cổ tròn mint (thân + hông cùng màu), quần xanh nhạt ở hông dưới.
  _torsoParts(k, sweater, trousers);
  k.body.torus(0, 0.7, -0.01, 0.114, 0.038, sweaterDark, basis: ChibiBasis.facing(0, 1, 0), segments: 12, tube: 5);
  _bandAt(k.body, 0.36, 0.036, sweaterDark, off: 0.006);

  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 9, lon: 14);
  // Bờm = mây tròn quanh đầu (phía sau, hở mặt): vòng cầu từ tai quanh đỉnh xuống cằm, mặt to hơn bờm.
  k.head.ellipsoid(0, 0.96, -0.1, 0.33, 0.29, 0.14, mane, lat: 6, lon: 14);
  for (var i = 0; i < 12; i++) {
    final a = i * 2 * math.pi / 12;
    final x = math.sin(a) * 0.3, y = 0.955 + math.cos(a) * 0.285;
    _sph(k.head, x, y, -0.04, 0.1, i.isEven ? mane : maneDark, lat: 3, lon: 6);
  }
  // Mõm kem + mũi hồng to tròn.
  const muzzle = ChibiSurface(0, 0.88, 0.165, 0.105, 0.075, 0.1);
  _muzzle(k, muzzle, muzzleC, nose, noseEl: 20, noseW: 0.04, noseH: 0.028);
  _muzzleMouth(k, muzzle, el: -16);
  final (eyeY, eyeZ) = _eyesOn(k, head, 26, -2);
  _cheeks(k, head, 45, -20, w: 0.062);
  // Tai tròn.
  for (final side in const [1.0, -1.0]) {
    _roundEar(k.head, side * 0.235, 1.2, -0.02, 0.082, fur, inner, tilt: -side * 0.25);
  }

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: sweater, hand: fur, cuff: sweaterDark);
  }
  _legs(k, leg: trousers, shoe: shoe, sole: 0xF1E4D0);
  // Đuôi sư tử: cuống + chùm lông chóp to (bộ phận phụ).
  _chain(k.extra, const [(0, 0.35, -0.16), (0, 0.4, -0.31), (0, 0.5, -0.42), (0, 0.62, -0.47)],
      const [0.044, 0.044, 0.042], const [fur, fur, fur],
      lat: 5, lon: 8);
  k.extra.ellipsoid(0, 0.72, -0.48, 0.07, 0.1, 0.07, mane, lat: 6, lon: 10);

  return k.build('regular_14',
      eyeY: eyeY,
      eyeZ: eyeZ,
      extraY: 0.36,
      extraZ: -0.16,
      extraKind: ChibiExtraKind.tail,
      gait: const ChibiGait(speed: 0.8, legSwing: 0.4, armSwing: 0.45, stride: 0.46, waddle: 0.06, bob: 0.03),
      radius: 0.32);
}
