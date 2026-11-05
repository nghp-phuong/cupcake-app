import 'dart:math' as math;

import '../../../core/city/mai_look.dart';
import 'chibi_mesh.dart';
import 'chibi_rig.dart';

part 'chibi_guests.dart';
part 'chibi_staff.dart';

/// Nhân vật chibi dựng bằng code (V3, docs/v3/character-3d-procedural.md) — Dart thuần. Bốn nhân vật thử đầu tiên ở
/// file này; nhân viên (Bao, Theo, Ami, Hạnh, bản lễ hội) ở `chibi_staff.dart`, khách (Kenji, ba khách VIP, mèo Mochi)
/// ở `chibi_guests.dart`. Quyết định 03/11: Mai là người, mọi nhân vật khác là thú chibi.
///
/// - `mai`: người chibi (chủ tiệm) — khăn bandana hồng, kẹp lá, đuôi ngựa thấp, áo blouse kem xắn tay, tạp dề vàng
///   bơ có túi, quần be, giày trắng, đồng hồ da nâu.
/// - `linh`: thỏ trắng — tai dài (kẹp dâu + kẹp sao vàng, khuyên tim), hoodie lavender dây rút, váy xếp ly trắng,
///   giày pastel đế dày, ba lô thỏ nhỏ.
/// - `hoa`: cú già (ông Hòa) — mũ beret nâu, kính tròn gọng vàng, lông mày + ria trắng, gile xanh xô thơm, nơ đỏ sẫm,
///   dây đồng hồ vàng, gậy gỗ, đi chậm hơi gù.
/// - `staff_nora`: cáo đỏ (thu ngân) — mõm kem, tàn nhang, kẹp bạc hà trên tai, áo sọc hồng–kem, tạp dề bạc hà có
///   bảng tên trơn, lắc tay bạc, đuôi chóp kem.
///
/// Tỉ lệ chung: cao ~1,3 m × [ChibiCharacters.scale] (không tính tai), đầu ~42% chiều cao, tay chân ngắn mập, bàn tay tròn. Mặt: mắt hạt đậu
/// đen có hai chấm sáng, má hồng, miệng nhỏ. Màu theo bảng màu dự án + ảnh 2D gốc (assets/characters).
abstract final class ChibiCharacters {
  static const mai = 'mai';
  static const linh = 'linh';
  static const hoa = 'hoa';
  static const nora = 'staff_nora';

  static const ids = [mai, linh, hoa, nora];

  // Nhân viên.
  static const bao = 'staff_bao';
  static const theo = 'staff_theo';
  static const ami = 'staff_ami';
  static const hanh = 'staff_hanh';
  static const baoFest = 'staff_bao_fest';
  static const noraFest = 'staff_nora_fest';

  // Khách quen / VIP.
  static const kenji = 'kenji';
  static const rosa = 'vip_00';
  static const stag = 'vip_01';
  static const lamb = 'vip_02';
  static const mochi = 'mochi';

  /// Đội tiệm (chủ tiệm + nhân viên + bản lễ hội).
  static const staffIds = [mai, nora, bao, theo, ami, hanh, baoFest, noraFest];

  /// Khách VIP.
  static const vipIds = [rosa, stag, lamb];

  /// Khách quen trong truyện (ông Hòa, Linh, Kenji, mèo Mochi).
  static const friendIds = [linh, hoa, kenji, mochi];

  /// Mọi nhân vật dựng sẵn trong thư viện này (không gồm khách thường đăng ký thêm — xem `ChibiRoster`).
  static const allIds = [...ids, bao, theo, ami, hanh, baoFest, noraFest, kenji, rosa, stag, lamb, mochi];

  /// Hệ số phóng chung khi dựng (mọi số đo trong file viết cho chibi ~1,3 m). 1,1 → ~1,43 m, mắt ~1,02 m: mặt nhô hẳn
  /// trên quầy 0,95 m và đồ trên quầy (bao bột, máy tính tiền) không che mặt khi nhìn chếch; đầu vẫn ~42% chiều cao.
  static const double scale = 1.1;

  static ChibiModel build(String id) => switch (id) {
    mai => buildMai(MaiLook.defaults),
    linh => _linh(),
    hoa => _hoa(),
    nora => _nora(),
    noraFest => _nora(fest: true),
    bao => _bao(),
    baoFest => _bao(fest: true),
    theo => _theo(),
    ami => _ami(),
    hanh => _hanh(),
    kenji => _kenji(),
    rosa => _rosa(),
    stag => _stag(),
    lamb => _lamb(),
    mochi => _mochi(),
    _ => throw ArgumentError.value(id, 'id', 'unknown chibi'),
  };

  static List<ChibiModel> buildAll() => [for (final id in ids) build(id)];
}

// ---- Màu dùng chung ----------------------------------------------------------------------------------------------

const _eyeDark = 0x2B201E;
const _shine = 0xFFFFFF;
const _blush = 0xF7A3AC;
const _mouthDark = 0x8A4A44;

/// Phân phối khối vào từng bộ phận, rồi dựng [ChibiModel].
class _Sketch {
  final _b = {for (final p in ChibiPart.values) p: ChibiMeshBuilder()};

  ChibiMeshBuilder get body => _b[ChibiPart.body]!;
  ChibiMeshBuilder get head => _b[ChibiPart.head]!;
  ChibiMeshBuilder get eyes => _b[ChibiPart.eyes]!;
  ChibiMeshBuilder get extra => _b[ChibiPart.extra]!;
  ChibiMeshBuilder get prop => _b[ChibiPart.prop]!;
  ChibiMeshBuilder arm(double side) => _b[side > 0 ? ChibiPart.armL : ChibiPart.armR]!;
  ChibiMeshBuilder leg(double side) => _b[side > 0 ? ChibiPart.legL : ChibiPart.legR]!;

  /// [hold]: đồ cầm tay (điểm xoay đã đặt, xem [_PropFrame]); [scale]: hệ số phóng (mặc định chung); [radius]: bán
  /// kính chiếm chỗ trước khi phóng; [reframe]: dời / co bộ phận về khung tỉ lệ cute (xem [_hipNew]; mèo bốn chân tắt);
  /// [crownY]: đỉnh sọ ở khung cũ (không tai / mũ) — `ChibiSizes` dùng để đo đầu.
  ChibiModel build(
    String id,
    ChibiRigSpec rig, {
    ChibiGait gait = const ChibiGait(),
    ChibiExtraKind extraKind = ChibiExtraKind.none,
    double scale = ChibiCharacters.scale,
    double radius = 0.27,
    ChibiHold? hold,
    bool reframe = true,
    double? crownY,
  }) {
    final s = scale;
    var r = hold == null ? rig : rig.withHold(hold);
    if (reframe) r = _reframe(r, extraKind, crownY);
    final meshes = <ChibiPart, ChibiMesh>{};
    for (final e in _b.entries) {
      if (e.value.isEmpty) continue;
      if (e.key == ChibiPart.prop && hold == null) continue;
      final (px, py, pz) = r.pivotOf(e.key);
      meshes[e.key] = e.value.build(px: px, py: py, pz: pz, scale: s);
    }
    return ChibiModel(
      id: id,
      meshes: meshes,
      rig: r.scaled(s),
      gait: gait.scaled(s),
      extraKind: extraKind,
      radius: radius * s,
    );
  }

  /// Dời / co lưới mọi bộ phận từ khung cũ (viết số đo) sang khung tỉ lệ cute, trả về khung xương mới.
  ChibiRigSpec _reframe(ChibiRigSpec r, ChibiExtraKind extraKind, double? crownY) {
    final neck = _bodyY(r.neckY);
    final shoulder = _bodyY(r.shoulderY);
    final dHead = neck - r.neckY, dArm = shoulder - r.shoulderY;
    double one(double _) => 1;
    double toHead(double y) => y + dHead;
    double toArm(double y) => y + dArm;
    final tail = extraKind == ChibiExtraKind.tail;
    body.warp(_bodyY, (_) => _bodyK);
    head.warp(toHead, one);
    eyes.warp(toHead, one);
    if (tail) {
      extra.warp(_bodyY, (_) => _bodyK);
    } else {
      extra.warp(toHead, one);
    }
    for (final side in const [1.0, -1.0]) {
      arm(side).warp(toArm, one, sx: _armThick, sz: _armThick, ox: side * r.shoulderX, oz: r.shoulderZ);
      leg(side).warp(_legY, (y) => y <= _shoeTop ? 1 : _legK);
    }
    prop.warp(toArm, one);
    final h = r.hold;
    return ChibiRigSpec(
      hipY: _legY(r.hipY),
      legX: r.legX,
      neckY: neck,
      shoulderX: r.shoulderX,
      shoulderY: shoulder,
      eyeY: r.eyeY + dHead,
      eyeZ: r.eyeZ,
      extraX: r.extraX,
      extraY: tail ? _bodyY(r.extraY) : r.extraY + dHead,
      extraZ: r.extraZ,
      seatDrop: _bodyY(r.seatDrop),
      neckZ: r.neckZ,
      hindZ: r.hindZ,
      shoulderZ: r.shoulderZ,
      quadruped: r.quadruped,
      hold: h?.at(h.x, h.y + dArm, h.z),
      crownY: crownY == null ? null : crownY + dHead,
    );
  }
}

// ---- Khung tỉ lệ cute (quy chuẩn 03/11, docs/v3/character-cute-review.md mục A3–A4) ------------------------------
//
// Mọi nhân vật trong thư viện vẫn VIẾT số đo ở khung cũ (hông 0,34, vai 0,635, cổ 0,70 — mọi helper bên dưới); lúc
// chốt lưới [_Sketch.build] dời / co từng bộ phận:
// - chân: hông 0,34 → [_hipNew] (đáy mông ~66% cũ); phần giày (y ≤ [_shoeTop]) giữ nguyên → bàn chân to tròn;
// - thân: co 15% theo y quanh hông ([_bodyK]) → bụng tròn, gần như không cổ;
// - đầu, mắt, tai / đuôi tóc: dời xuống theo cổ mới, cỡ giữ nguyên → đầu ~49% chiều cao;
// - tay: dời theo vai mới, mập hơn ([_armThick] theo x / z), dài giữ nguyên (bàn tay tới hông); đồ cầm tay dời theo.

const _hipNew = 0.24;
const _shoeTop = 0.11;
const _bodyK = 0.85;
const _armThick = 1.15;
const _legK = (_hipNew - _shoeTop) / (_hipY - _shoeTop);

double _bodyY(double y) => _hipNew + (y - _hipY) * _bodyK;
double _legY(double y) => y <= _shoeTop ? y : _shoeTop + (y - _shoeTop) * _legK;

// ---- Khối xương chung --------------------------------------------------------------------------------------------

const _hipY = 0.34;
const _shoulderX = 0.175;
const _shoulderY = 0.635;
const _legX = 0.085;

/// Điểm trên tay: vai → cổ tay → tâm bàn tay (bên [side]: +1 trái = +x, −1 phải).
(double, double, double) _wrist(double side) => (side * (_shoulderX + 0.034), _shoulderY - 0.2, 0.014);
(double, double, double) _handC(double side) => (side * (_shoulderX + 0.04), _shoulderY - 0.24, 0.02);

/// Dải trụ ngắn (cổ tay áo, ống xắn, dây đồng hồ, lắc tay) từ a tới b, bán kính [r]; 8 cạnh, không nắp.
void _band(ChibiMeshBuilder b, double ax, double ay, double az, double bx, double by, double bz, double r, int color) =>
    b.frustum(ax, ay, az, bx, by, bz, r, r * 0.97, color, radial: 8, capA: false, capB: false);

/// Tay: ống tay từ vai tới cổ tay (màu [sleeve]), bàn tay tròn ([hand]); [cuff] = viền / ống xắn ở cổ tay.
void _arm(
  _Sketch k,
  double side, {
  required int sleeve,
  required int hand,
  int? cuff,
  double rTop = 0.06,
  double rWrist = 0.05,
  double rHand = 0.057,
}) {
  final b = k.arm(side);
  final (wx, wy, wz) = _wrist(side);
  b.capsule(side * _shoulderX, _shoulderY, 0, wx, wy, wz, rTop, rWrist, sleeve, radial: 7, capBands: 2);
  if (cuff != null) {
    final dx = wx - side * _shoulderX, dy = wy - _shoulderY, dz = wz;
    _band(
      b,
      wx - dx * 0.12,
      wy - dy * 0.12,
      wz - dz * 0.12,
      wx + dx * 0.04,
      wy + dy * 0.04,
      wz + dz * 0.04,
      rWrist + 0.012,
      cuff,
    );
  }
  final (hx, hy, hz) = _handC(side);
  b.ellipsoid(hx, hy, hz, rHand * 1.08, rHand * 1.08, rHand * 1.08, hand, lat: 5, lon: 9);
}

/// Chân: ống chân (màu [leg]) + giày tròn ([shoe]); [sole] đế giày, [chunky] giày đế dày (Linh).
void _legs(_Sketch k, {required int leg, required int shoe, int? sole, bool chunky = false, int? accent}) {
  for (final side in const [1.0, -1.0]) {
    final b = k.leg(side);
    final x = side * _legX;
    b.capsule(x, chunky ? 0.13 : 0.1, 0, x, _hipY + 0.03, 0, 0.074, 0.08, leg, radial: 7, capBands: 1);
    if (chunky) {
      b.ellipsoid(x, 0.032, 0.035, 0.092, 0.034, 0.128, sole ?? 0xFFFFFF, lat: 3, lon: 10);
      b.ellipsoid(x, 0.082, 0.03, 0.084, 0.062, 0.11, shoe, lat: 5, lon: 10);
      if (accent != null) {
        b.ellipsoid(x + side * 0.064, 0.08, 0.03, 0.022, 0.03, 0.06, accent, lat: 3, lon: 6);
      }
    } else {
      // Giày tròn kiểu bánh bao (quy chuẩn A4).
      b.ellipsoid(x, 0.058, 0.035, 0.086, 0.06, 0.112, shoe, lat: 4, lon: 9);
      if (sole != null) b.ellipsoid(x, 0.02, 0.035, 0.088, 0.02, 0.114, sole, lat: 2, lon: 9);
    }
  }
}

/// Mắt to hơn 22% so với số truyền vào (quy chuẩn cute A2: rộng ≈ 18–20% bề rộng đầu).
const _eyeK = 1.22;

/// Mắt hạt đậu đen (+ 2 chấm sáng: to trên-phải, nhỏ dưới-trái) ở điểm ([x],[y],[z]) với cơ sở [b] (z = pháp tuyến bề
/// mặt). Vào lưới mắt. [w] / [h] tính trước hệ số [_eyeK].
void _eye(
  _Sketch k,
  double x,
  double y,
  double z,
  ChibiBasis b, {
  double w = 0.042,
  double h = 0.057,
  int color = _eyeDark,
  double d = 0.02,
}) {
  w *= _eyeK;
  h *= _eyeK;
  d *= 1.1;
  k.eyes.ellipsoid(x, y, z, w, h, d, color, basis: b, lat: 8, lon: 14);
  // Chấm sáng lớn trên-phải (cùng phía ở cả hai mắt, như có nguồn sáng), chấm nhỏ dưới-trái.
  (double, double, double) at(double lx, double ly, double lz) => (
    x + b.xx * lx + b.yx * ly + b.zx * lz,
    y + b.xy * lx + b.yy * ly + b.zy * lz,
    z + b.xz * lx + b.yz * ly + b.zz * lz,
  );
  final (ax, ay, az) = at(w * 0.3, h * 0.34, d * 0.8);
  k.eyes.dome(ax, ay, az, w * 0.4, w * 0.4, 0.006, _shine, basis: b, segments: 9);
  final (bx, by, bz) = at(-w * 0.34, -h * 0.42, d * 0.7);
  k.eyes.dome(bx, by, bz, w * 0.2, w * 0.2, 0.004, _shine, basis: b, segments: 7);
}

/// Hai mắt trên bề mặt [s] (góc phương vị ±[az], góc cao [el]); trả về (eyeY, eyeZ) cho khớp chớp mắt.
(double, double) _eyesOn(
  _Sketch k,
  ChibiSurface s,
  double az,
  double el, {
  double w = 0.042,
  double h = 0.057,
  double lift = 0.004,
}) {
  var sy = 0.0, sz = 0.0;
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = s.at(side * az, el, lift: lift);
    _eye(k, x, y, z, b, w: w, h: h);
    sy += y / 2;
    sz += z / 2;
  }
  return (sy, sz);
}

/// Mi trên mảnh (người: Mai) — cung mảnh ôm mép trên mỗi mắt + một vệt hất ở đuôi mắt; vào lưới mắt (chớp cùng mắt).
void _lashes(
  _Sketch k,
  ChibiSurface s,
  double az,
  double el, {
  double w = 0.042,
  double h = 0.057,
  int color = _eyeDark,
}) {
  final rw = w * _eyeK, rh = h * _eyeK;
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = s.at(side * az, el, lift: 0.006);
    (double, double, double) at(double lx, double ly, double lz) => (
      x + b.xx * lx + b.yx * ly + b.zx * lz,
      y + b.xy * lx + b.yy * ly + b.zy * lz,
      z + b.xz * lx + b.yz * ly + b.zz * lz,
    );
    // Cung mi: xuyến một phần (ít tam giác), tâm đặt cao hơn tâm mắt để đỉnh cung ôm mép trên mắt elip.
    final rr = rw * 1.1, dy = rh * 1.03 - rr;
    final (cx, cy, cz) = at(0, dy, 0.004);
    k.eyes.torus(cx, cy, cz, rr, 0.0042, color, basis: b, a0: math.pi * 0.1, a1: math.pi * 0.9, segments: 8, tube: 3);
    final a0 = side > 0 ? math.pi * 0.1 : math.pi * 0.9;
    final (ox, oy, oz) = at(rr * math.cos(a0), dy + rr * math.sin(a0), 0.004);
    // Đuôi mi hất ra ngoài (phía thái dương).
    final (tx, ty, tz) = at(side * rw * 1.4, rh * 0.62, 0.0);
    k.eyes.capsule(ox, oy, oz, tx, ty, tz, 0.0042, 0.0025, color, radial: 4, capBands: 1);
  }
}

/// Má hồng to mềm (quy chuẩn A8: +25% so với số truyền vào), đĩa dẹt chìm một nửa vào mặt, dưới-ngoài mắt.
void _cheeks(_Sketch k, ChibiSurface s, double az, double el, {int color = _blush, double w = 0.048}) {
  w *= 1.25;
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = s.at(side * az, el, lift: -0.003);
    k.head.dome(x, y, z, w, w * 0.66, 0.008, color, basis: b, segments: 12);
  }
}

/// Miệng cười (cung) ở góc cao [el] trên bề mặt [s].
void _smile(_Sketch k, ChibiSurface s, double el, {double r = 0.022, int color = _mouthDark, double az = 0}) {
  final (x, y, z, b) = s.at(az, el, lift: 0.002);
  // Tâm vòng ở trên điểm miệng một bán kính → cung dưới chạm điểm miệng.
  k.head.torus(
    x + b.yx * r,
    y + b.yy * r,
    z + b.yz * r,
    r,
    0.0062,
    color,
    basis: b,
    a0: math.pi * 1.18,
    a1: math.pi * 1.82,
    segments: 6,
    tube: 3,
    tubeScaleZ: 0.6,
  );
}

/// Miệng "ω" (hai cung nhỏ) — thú.
void _omega(_Sketch k, ChibiSurface s, double el, {double r = 0.0125, int color = _mouthDark, double tube = 0.0052}) {
  final (x, y, z, b) = s.at(0, el, lift: 0.002);
  for (final side in const [1.0, -1.0]) {
    final ox = side * r, oy = r * 0.9;
    k.head.torus(
      x + b.xx * ox + b.yx * oy,
      y + b.xy * ox + b.yy * oy,
      z + b.xz * ox + b.yz * oy,
      r,
      tube,
      color,
      basis: b,
      a0: math.pi * 1.0,
      a1: math.pi * 2.0,
      segments: 5,
      tube: 3,
      tubeScaleZ: 0.6,
    );
  }
}

/// Thân áo = ellipsoid thân [torso] ∪ ellipsoid hông [hips]: bán kính (rx, rz) ở độ cao [y] (dưới đáy hông giữ như
/// ở đáy hông) + [offset].
(double, double) _wrapRadius(ChibiSurface torso, ChibiSurface hips, double y, double offset) {
  (double, double) r(ChibiSurface s, double yy) {
    final t = (yy - s.cy) / s.ry;
    final k = math.sqrt(math.max(0, 1 - t * t));
    return (s.rx * k, s.rz * k);
  }

  final yy = math.max(y, hips.cy - hips.ry * 0.9);
  final (ax, az) = r(torso, yy);
  final (bx, bz) = r(hips, yy);
  return (math.max(ax, bx) + offset, math.max(az, bz) + offset);
}

/// Điểm trên tấm quấn ở góc [a] (rad, 0 = trước) độ cao [y], nhô [lift]; cơ sở z = pháp tuyến (gần đúng, ngang).
(double, double, double, ChibiBasis) _wrapPoint(
  ChibiSurface torso,
  ChibiSurface hips,
  double a,
  double y,
  double offset,
  double lift,
) {
  final (rx, rz) = _wrapRadius(torso, hips, y, offset);
  final nx = math.sin(a) / rx, nz = math.cos(a) / rz;
  final nl = math.sqrt(nx * nx + nz * nz);
  return (
    rx * math.sin(a) + nx / nl * lift,
    y,
    torso.cz + rz * math.cos(a) + nz / nl * lift,
    ChibiBasis.facing(nx / nl, 0.15, nz / nl),
  );
}

/// Tạp dề: tấm quấn phía trước thân (váy rộng dần ở gấu, yếm hẹp phía trên), dây đeo qua vai, nơ sau lưng.
/// Trả về hàm đặt chi tiết lên tạp dề (góc rad, độ cao, độ nhô).
(double, double, double, ChibiBasis) Function(double a, double y, double lift) _apron(
  _Sketch k,
  int color,
  ChibiSurface torso,
  ChibiSurface hips,
) {
  // (y, nửa cung, độ nhô thêm): gấu loe → thân → vai yếm thu hẹp → mép yếm.
  const rows = [
    (0.205, 1.3, 0.024),
    (0.245, 1.29, 0.018),
    (0.3, 1.27, 0.013),
    (0.38, 1.24, 0.011),
    (0.46, 1.21, 0.01),
    (0.535, 1.15, 0.01),
    (0.565, 0.62, 0.01),
    (0.625, 0.53, 0.01),
    (0.672, 0.48, 0.008),
  ];
  k.body.shell(
    0,
    torso.cz,
    [
      for (final (y, half, off) in rows)
        () {
          final (rx, rz) = _wrapRadius(torso, hips, y, off);
          return (y, rx, rz, -half, half);
        }(),
    ],
    color,
    segments: 10,
  );
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, _) = _wrapPoint(torso, hips, side * 0.46, 0.672, 0.008, 0.003);
    k.body.capsule(x, y, z, side * 0.115, 0.722, -0.02, 0.013, 0.013, color, radial: 4, capBands: 1);
  }
  // Nơ buộc sau lưng.
  for (final side in const [1.0, -1.0]) {
    k.body.ellipsoid(
      side * 0.04,
      0.42,
      -0.168,
      0.04,
      0.026,
      0.018,
      color,
      basis: ChibiBasis.euler(0, 0, side * 0.35),
      lat: 3,
      lon: 6,
    );
  }
  return (a, y, lift) => _wrapPoint(torso, hips, a, y, 0.01, lift);
}

// ---- Tiện ích dùng chung cho nhân vật mới ------------------------------------------------------------------------

/// Khung dựng đồ cầm tay ([ChibiHold]): toạ độ cục bộ (x ngang — trái nhân vật là +x, y lên, z trước) quanh tâm bàn
/// tay mang đồ **ở tư thế cầm** → toạ độ tư thế nghỉ cho lưới [ChibiPart.prop] (rig đặt điểm xoay = tâm bàn tay nghỉ,
/// nên lưới cục bộ = lưới tư thế cầm khi đồ [ChibiHold.level]). [span]: từ tay mang tới tay kia ở tư thế cầm (đồ hai
/// tay nằm giữa hai bàn tay).
class _PropFrame {
  factory _PropFrame(ChibiHold h) {
    final side = h.twoHands ? -1.0 : h.side;
    final rest = _handC(side);
    final hold = h.at(rest.$1, rest.$2, rest.$3);
    final rig = ChibiRig(const ChibiRigSpec(eyeY: 1, eyeZ: 0.2));
    final pose = ChibiPose()
      ..armSwingL = 0.06
      ..armSwingR = 0.06
      ..armRaiseL = 0.12
      ..armRaiseR = 0.12;
    if (h.twoHands || side > 0) {
      pose
        ..armSwingL = h.forward
        ..armRaiseL = h.raise;
    }
    if (h.twoHands || side < 0) {
      pose
        ..armSwingR = h.forward
        ..armRaiseR = h.raise;
    }
    rig.compute(pose);
    final l = ChibiM4.transformPoint(rig[ChibiPart.armL], 0.04, -0.24, 0.02);
    final r = ChibiM4.transformPoint(rig[ChibiPart.armR], -0.04, -0.24, 0.02);
    final (c, o) = side > 0 ? (l, r) : (r, l);
    return _PropFrame._(hold, (o.$1 - c.$1, o.$2 - c.$2, o.$3 - c.$3), c);
  }

  _PropFrame._(this.hold, this.span, this.carrier);

  /// Đồ cầm tay đã đặt điểm xoay (truyền vào [_Sketch.build]).
  final ChibiHold hold;

  /// Tay mang đồ → tay kia (tư thế cầm).
  final (double, double, double) span;

  /// Tâm bàn tay mang đồ ở tư thế cầm (không gian nhân vật, gốc tại 0).
  final (double, double, double) carrier;

  /// Điểm cục bộ → toạ độ tư thế nghỉ của lưới đồ.
  (double, double, double) at(double lx, double ly, double lz) => (hold.x + lx, hold.y + ly, hold.z + lz);
}

/// Tai nhọn (mèo, cáo, chó corgi): nón dẹt từ gốc ([bx],[by],[bz]) tới chóp ([tx],[ty],[tz]), bán kính gốc [r]; lòng
/// tai [inner] (nón nhỏ hơn nhô ra trước); [tip] (nếu có) = màu chóp tai.
void _pointEar(
  ChibiMeshBuilder b,
  double bx,
  double by,
  double bz,
  double tx,
  double ty,
  double tz,
  double r,
  int fur,
  int inner, {
  int? tip,
  double flat = 0.45,
}) {
  // Tai to thêm ~15% (quy chuẩn A11), giữ gốc tai.
  tx = bx + (tx - bx) * 1.15;
  ty = by + (ty - by) * 1.15;
  tz = bz + (tz - bz) * 1.15;
  r *= 1.15;
  _softCone(b, bx, by, bz, tx, ty, tz, r, fur, flat: flat);
  b.frustum(
    bx,
    by + r * 0.15,
    bz + r * 0.32,
    bx + (tx - bx) * 0.86,
    by + (ty - by) * 0.86,
    tz + r * 0.3,
    r * 0.58,
    0,
    inner,
    radial: 11,
    ovalZ: flat * 0.66,
    capA: false,
    capB: false,
  );
  if (tip != null) {
    const f = 0.72;
    b.frustum(
      bx + (tx - bx) * f,
      by + (ty - by) * f,
      bz + (tz - bz) * f,
      tx,
      ty + 0.004,
      tz,
      r * (1 - f) + 0.007,
      0,
      tip,
      radial: 8,
      ovalZ: flat * 1.1,
      capA: false,
      capB: false,
    );
  }
}

/// Nón tai bo tròn chóp: nón cụt từ gốc ([bx],[by],[bz], bán kính [r]) tới gần chóp ([tx],[ty],[tz]) + chỏm elip tròn
/// (không nhọn như kim, viền mượt 12 cạnh); [flat] = độ dẹt theo z.
void _softCone(
  ChibiMeshBuilder b,
  double bx,
  double by,
  double bz,
  double tx,
  double ty,
  double tz,
  double r,
  int color, {
  double flat = 0.45,
}) {
  const f = 0.86;
  final ex = bx + (tx - bx) * f, ey = by + (ty - by) * f, ez = bz + (tz - bz) * f;
  final rt = math.max(r * 0.2, 0.008);
  b.frustum(bx, by, bz, ex, ey, ez, r, rt, color, radial: 12, ovalZ: flat, capA: false, capB: false);
  b.ellipsoid(
    ex,
    ey,
    ez,
    rt,
    rt * 1.3,
    rt * flat,
    color,
    basis: ChibiBasis.alongY(tx - bx, ty - by, tz - bz),
    lat: 4,
    lon: 8,
  );
}

/// Tai tròn (gấu, gấu trúc): đĩa dày [r] dựng đứng, mặt trước hướng theo [basis] (z = pháp tuyến), lòng tai [inner].
void _roundEar(ChibiMeshBuilder b, double x, double y, double z, double r, int fur, int? inner, ChibiBasis basis) {
  r *= 1.15;
  b.ellipsoid(x, y, z, r, r * 0.92, r * 0.5, fur, basis: basis, lat: 5, lon: 9);
  if (inner != null) {
    b.dome(
      x + basis.zx * r * 0.42,
      y + basis.zy * r * 0.42 - r * 0.08,
      z + basis.zz * r * 0.42,
      r * 0.58,
      r * 0.5,
      r * 0.12,
      inner,
      basis: basis,
      segments: 9,
    );
  }
}

/// Mõm tròn nhô ra trước mặt (gấu, chó, hươu…): ellipsoid [muzzle] + mũi ([nose], ở góc cao [noseEl] trên mõm) +
/// miệng ω dưới mũi. Trả về bề mặt mõm để đặt thêm chi tiết.
ChibiSurface _snout(
  _Sketch k,
  ChibiSurface muzzle,
  int color,
  int nose, {
  double noseEl = 22,
  double noseW = 0.03,
  double noseH = 0.02,
  double mouthEl = -14,
  double mouthR = 0.012,
  double mouthTube = 0.0052,
}) {
  // Mũi to thêm 20%, tròn (quy chuẩn A8).
  noseW *= 1.2;
  noseH *= 1.2;
  k.head.ellipsoid(muzzle.cx, muzzle.cy, muzzle.cz, muzzle.rx, muzzle.ry, muzzle.rz, color, lat: 5, lon: 10);
  final (nx, ny, nz, nb) = muzzle.at(0, noseEl, lift: 0.004);
  k.head.ellipsoid(nx, ny, nz, noseW, noseH, noseH * 0.9, nose, basis: nb, lat: 3, lon: 7);
  // Chấm sáng nhỏ trên mũi.
  final (sx, sy, sz, sb) = muzzle.at(-6, noseEl + 6, lift: 0.004 + noseH * 0.8);
  k.head.dome(sx, sy, sz, noseW * 0.28, noseH * 0.3, 0.002, _shine, basis: sb, segments: 5);
  final (mx, my, mz, mb) = muzzle.at(0, mouthEl, lift: 0.0);
  final m2 = ChibiSurface(mx - mb.zx * 0.1, my - mb.zy * 0.1, mz - mb.zz * 0.1, 0.1, 0.1, 0.1);
  _omega(k, m2, 0, r: mouthR, tube: mouthTube);
  return muzzle;
}

/// Kính tròn trên mặt [head]: hai vòng quanh hai mắt (góc ±[az], [el]), cầu nối, gọng tai chạy ra sau tới
/// [templeAz]; [spots]: chấm đồi mồi trên gọng.
void _roundGlasses(
  _Sketch k,
  ChibiSurface head,
  double az,
  double el,
  double ringR,
  double tube,
  int color, {
  double lift = 0.03,
  double templeAz = 80,
  int? spots,
}) {
  final centers = <(double, double, double)>[];
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = head.at(side * az, el, lift: lift);
    k.head.torus(x, y, z, ringR, tube, color, basis: b, segments: 12, tube: 3);
    if (spots != null) {
      for (final a in const [0.6, 2.2, 3.9, 5.3]) {
        k.head.sphere(
          x + (b.xx * math.cos(a) + b.yx * math.sin(a)) * ringR,
          y + (b.xy * math.cos(a) + b.yy * math.sin(a)) * ringR,
          z + (b.xz * math.cos(a) + b.yz * math.sin(a)) * ringR,
          tube * 1.15,
          spots,
          lat: 2,
          lon: 4,
        );
      }
    }
    centers.add((x - side * ringR * b.xx, y - side * ringR * b.xy, z - side * ringR * b.xz));
    // Gọng tai.
    final ox = x + side * ringR * b.xx, oy = y + side * ringR * b.xy, oz = z + side * ringR * b.xz;
    final (tx, ty, tz, _) = head.at(side * templeAz, el + 4, lift: 0.004);
    k.head.capsule(ox, oy, oz, tx, ty, tz, tube * 0.8, tube * 0.8, color, radial: 4, capBands: 1);
  }
  final (a, b) = (centers[0], centers[1]);
  k.head.capsule(
    a.$1,
    a.$2 + 0.008,
    a.$3,
    b.$1,
    b.$2 + 0.008,
    b.$3,
    tube * 0.85,
    tube * 0.85,
    color,
    radial: 4,
    capBands: 1,
  );
}

/// Chuỗi hạt (ngọc trai) vòng trước ngực trên tấm quấn quanh thân: [n] hạt, góc ±[a] (rad), cao [y] ở giữa, võng
/// xuống [sag] ở giữa so với hai đầu.
void _beads(
  _Sketch k,
  ChibiSurface torso,
  ChibiSurface hips,
  int n,
  double a,
  double y,
  double sag,
  double r,
  int color, {
  double offset = 0.012,
}) {
  for (var i = 0; i < n; i++) {
    final t = -1 + 2 * i / (n - 1);
    final yy = y + sag * t * t;
    final (x, py, z, _) = _wrapPoint(torso, hips, a * t, yy, offset, r * 0.6);
    k.body.sphere(x, py, z, r, color, lat: 3, lon: 5);
  }
}

/// Đuôi nhiều khúc (ellipsoid nối các điểm [pts]), mỗi khúc một màu ([colors], lặp lại), bán kính [radii] theo khúc.
void _tailChain(
  ChibiMeshBuilder b,
  List<(double, double, double)> pts,
  List<double> radii,
  List<int> colors, {
  int lat = 5,
  int lon = 8,
  double overlap = 0.62,
}) {
  for (var i = 0; i < pts.length - 1; i++) {
    final (ax, ay, az) = pts[i];
    final (bx, by, bz) = pts[i + 1];
    final r = radii[math.min(i, radii.length - 1)];
    final len = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2) + math.pow(bz - az, 2));
    b.ellipsoid(
      (ax + bx) / 2,
      (ay + by) / 2,
      (az + bz) / 2,
      r,
      len * overlap + r * 0.3,
      r,
      colors[i % colors.length],
      basis: ChibiBasis.alongY(bx - ax, by - ay, bz - az),
      lat: lat,
      lon: lon,
    );
  }
}

/// Áo khoác / gile mở vạt trước: tấm quấn quanh thân, hở phía trước nửa góc `v` (rad) theo từng hàng (y, v, độ nhô).
void _openJacket(
  _Sketch k,
  ChibiSurface torso,
  ChibiSurface hips,
  List<(double, double, double)> rows,
  int color, {
  int segments = 16,
}) {
  k.body.shell(
    0,
    0,
    [
      for (final (y, v, off) in rows)
        () {
          final (rx, rz) = _wrapRadius(torso, hips, y, off);
          return (y, rx, rz, v, 2 * math.pi - v);
        }(),
    ],
    color,
    segments: segments,
  );
}

/// Hai mép vạt áo (viền / ve áo): capsule chạy dọc mép hở của [_openJacket] (cùng các hàng), độ nhô [lift].
void _jacketEdges(
  _Sketch k,
  ChibiSurface torso,
  ChibiSurface hips,
  List<(double, double, double)> rows,
  double r,
  int color, {
  double lift = 0.004,
}) {
  for (final side in const [1.0, -1.0]) {
    for (var i = 0; i < rows.length - 1; i++) {
      final (y0, v0, o0) = rows[i];
      final (y1, v1, o1) = rows[i + 1];
      final (ax, ay, az, _) = _wrapPoint(torso, hips, side * v0, y0, o0, lift);
      final (bx, by, bz, _) = _wrapPoint(torso, hips, side * v1, y1, o1, lift);
      k.body.capsule(ax, ay, az, bx, by, bz, r, r, color, radial: 4, capBands: 1);
    }
  }
}

// ---- Mai (người chibi) -------------------------------------------------------------------------------------------

/// Màu tóc Mai (core không chứa màu). `chestnut` = màu tóc gốc của Mai; đen mềm (không đen tuyền) và hồng dâu pastel
/// đủ sáng để khác khăn bandana hồng (0xE8848F).
int maiHairRgb(MaiHairColor c) => switch (c) {
  MaiHairColor.chestnut => 0xA06A45,
  MaiHairColor.caramel => 0xC98B4E,
  MaiHairColor.black => 0x3B2E2A,
  MaiHairColor.strawberry => 0xF5A8BC,
};

/// Mai với kiểu tóc / màu tóc tuỳ chọn. Mọi kiểu giữ nguyên: mặt, thân, tay chân, khăn bandana + kẹp lá, mái trước,
/// cùng khung xương (bộ phận phụ `extra` vẫn là `ChibiExtraKind.ponytail`, cùng điểm xoay) và <= 4100 tam giác — nên
/// đổi kiểu chỉ cần thay lưới (head + extra), không đổi số entity. `MaiLook.defaults` (đuôi ngựa thấp, nâu hạt dẻ) ra
/// lưới y hệt Mai trước đây.
///
/// - `ponytail`: đuôi ngựa thấp (extra), hai lọn bên mặt.
/// - `bob`: tóc ngắn ngang cằm ôm đầu (head), extra = hai lọn cong đuôi tóc sau gáy.
/// - `bun`: búi tròn trên đỉnh (head, nhô khỏi khăn), extra = một lọn con buông sau gáy.
/// - `twinTails`: hai bím hai bên (extra), không lọn bên.
ChibiModel buildMai(MaiLook look) {
  // Da / tóc sáng hơn bản đầu (quy chuẩn cute, mục B: Mai).
  const skin = 0xFCE5D6;
  final hair = maiHairRgb(look.hairColor);
  final style = look.hair;
  const bandana = 0xE8848F;
  const leaf = 0x86BE78;
  const blouse = 0xFFF4E6;
  const blouseShade = 0xF1E2CC;
  const apron = 0xFFD27A;
  const pocket = 0xF2BE58;
  const pants = 0xE7D6BC;
  const shoe = 0xFBFAF6;
  const sole = 0xD8CFC4;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.965, 0, 0.275, 0.258, 0.248);

  // Thân: áo blouse (thân + hông), tạp dề vàng bơ có túi.
  const torso = ChibiSurface(0, 0.49, 0, 0.195, 0.235, 0.165);
  const hips = ChibiSurface(0, 0.36, 0, 0.185, 0.1, 0.155);
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, blouse, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, pants, lat: 4, lon: 10);
  final onApron = _apron(k, apron, torso, hips);
  final (px, py, pz, pb) = onApron(0.4, 0.4, 0.003);
  k.body.dome(px, py, pz, 0.05, 0.038, 0.005, pocket, basis: pb, segments: 8);

  // Đầu: mặt, tai, tóc (mái + chỏm sau + hai lọn bên), khăn bandana + nút buộc, kẹp lá.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, skin, lat: 10, lon: 16);
  for (final side in const [1.0, -1.0]) {
    k.head.sphere(side * 0.272, 0.93, 0.0, 0.036, skin, lat: 3, lon: 5);
  }
  k.head.ellipsoid(0, 1.03, -0.035, 0.296, 0.25, 0.268, hair, lat: 6, lon: 12);
  // Mái tóc = các cụm tròn (không tấm cắt sắc), hai cụm ngoài thấp hơn.
  for (final (az, el, r) in const [
    (-44.0, 14.0, 0.062),
    (-23.0, 20.0, 0.07),
    (0.0, 22.0, 0.072),
    (23.0, 20.0, 0.07),
    (44.0, 14.0, 0.062),
  ]) {
    final (x, y, z, b) = head.at(az, el, lift: -0.034);
    k.head.ellipsoid(x, y, z, r, r * 0.9, r * 0.75, hair, basis: b, lat: 6, lon: 9);
  }
  if (style == MaiHair.ponytail || style == MaiHair.bun) {
    for (final side in const [1.0, -1.0]) {
      k.head.capsule(side * 0.255, 1.0, 0.07, side * 0.25, 0.85, 0.1, 0.044, 0.03, hair, radial: 6, capBands: 1);
    }
  }
  if (style == MaiHair.bob) {
    // Tóc ngắn ôm đầu: khối tròn rộng hơn mặt ở hai bên / sau, thấp tới cằm; mặt (z > 0,15) nhô ra trước nó.
    k.head.ellipsoid(0, 0.9, -0.075, 0.322, 0.2, 0.256, hair, lat: 4, lon: 11);
  }
  if (style == MaiHair.bun) {
    // Búi tròn trên đỉnh, hơi lùi ra sau; nửa dưới chìm trong chỏm tóc nên không hở khe.
    k.head.sphere(0, 1.255, -0.13, 0.082, hair, lat: 6, lon: 10);
  }
  // Khăn bandana: tấm quấn ôm sát chỏm tóc (dày ~1–2 cm để tóc không xuyên khi nghiêng), nghiêng — mép trước cao (lộ mái), mép sau thấp; nút + hai
  // đuôi khăn sau gáy.
  const hairRx = 0.296, hairRy = 0.25, hairRz = 0.268, hairY = 1.03, hairZ = -0.035;
  k.head.shell(
    0,
    hairZ,
    [
      for (final f in const [0.1, 0.3, 0.5, 0.68, 0.83, 0.94, 1.0])
        () {
          final k2 = math.sqrt(math.max(0, 1 - f * f));
          return (hairY + (hairRy + 0.022) * f, (hairRx + 0.009) * k2, (hairRz + 0.009) * k2, 0.0, 2 * math.pi);
        }(),
    ],
    bandana,
    segments: 14,
    basis: ChibiBasis.euler(-0.5, 0, 0),
    pivotY: hairY,
  );
  k.head.sphere(0, 1.0, -0.31, 0.034, bandana, lat: 3, lon: 6);
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(
      side * 0.045,
      0.94,
      -0.315,
      0.032,
      0.066,
      0.015,
      bandana,
      basis: ChibiBasis.euler(0.25, 0, side * 0.45),
      lat: 3,
      lon: 6,
    );
  }
  final (lx, ly, lz, lb) = head.at(42, 24, lift: 0.04);
  k.head.ellipsoid(lx, ly, lz, 0.042, 0.02, 0.01, leaf, basis: lb.then(ChibiBasis.euler(0, 0, 0.6)), lat: 2, lon: 6);
  k.head.ellipsoid(
    lx + 0.02,
    ly - 0.025,
    lz,
    0.036,
    0.018,
    0.01,
    leaf,
    basis: lb.then(ChibiBasis.euler(0, 0, -0.3)),
    lat: 2,
    lon: 6,
  );

  // Mặt: mắt to (2 chấm sáng) + mi trên mảnh, má hồng, miệng cười nhỏ.
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -6);
  _lashes(k, head, 23, -6);
  _cheeks(k, head, 40, -20);
  _smile(k, head, -23, r: 0.019);

  // Bộ phận phụ (đung đưa theo kiểu tóc; cùng điểm xoay ở mọi kiểu).
  switch (style) {
    case MaiHair.ponytail:
      // Đuôi ngựa thấp.
      k.extra.ellipsoid(0.05, 0.875, -0.3, 0.075, 0.09, 0.07, hair, lat: 5, lon: 8);
      k.extra.ellipsoid(0.07, 0.775, -0.31, 0.068, 0.085, 0.062, hair, lat: 5, lon: 8);
      k.extra.ellipsoid(0.08, 0.695, -0.29, 0.046, 0.058, 0.044, hair, lat: 4, lon: 7);
      k.extra.ellipsoid(
        0.04,
        0.935,
        -0.275,
        0.03,
        0.016,
        0.01,
        leaf,
        basis: ChibiBasis.facing(0, 0, -1).then(ChibiBasis.euler(0, 0, 0.5)),
        lat: 2,
        lon: 5,
      );
    case MaiHair.bob:
      // Hai lọn cong ra ở đuôi tóc sau gáy.
      for (final side in const [1.0, -1.0]) {
        k.extra.ellipsoid(side * 0.12, 0.75, -0.285, 0.075, 0.07, 0.06, hair, lat: 4, lon: 7);
      }
    case MaiHair.bun:
      // Một lọn con buông sau gáy + dây buộc nhỏ.
      k.extra.ellipsoid(0.04, 0.84, -0.3, 0.05, 0.11, 0.045, hair, lat: 5, lon: 8);
      k.extra.ellipsoid(
        0.04,
        0.935,
        -0.275,
        0.03,
        0.016,
        0.01,
        leaf,
        basis: ChibiBasis.facing(0, 0, -1).then(ChibiBasis.euler(0, 0, 0.5)),
        lat: 2,
        lon: 5,
      );
    case MaiHair.twinTails:
      // Hai bím rủ hai bên sau tai (lùi ra sau để quay quanh điểm xoay chung vẫn gần như đứng yên), kẹp lá dưới bím.
      for (final side in const [1.0, -1.0]) {
        k.extra.ellipsoid(side * 0.27, 0.86, -0.1, 0.06, 0.085, 0.058, hair, lat: 4, lon: 8);
        k.extra.ellipsoid(side * 0.275, 0.73, -0.11, 0.054, 0.075, 0.052, hair, lat: 4, lon: 8);
        k.extra.ellipsoid(side * 0.275, 0.63, -0.11, 0.032, 0.03, 0.03, leaf, lat: 3, lon: 6);
      }
  }

  // Tay: tay áo kem xắn tới khuỷu (ống xắn) + cẳng tay da.
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final ex = side * (_shoulderX + 0.02), ey = _shoulderY - 0.11, ez = 0.008;
    b.capsule(side * _shoulderX, _shoulderY, 0, ex, ey, ez, 0.062, 0.056, blouse, radial: 7, capBands: 2);
    _band(b, ex - side * 0.003, ey + 0.018, ez, ex + side * 0.003, ey - 0.022, ez + 0.002, 0.066, blouseShade);
    final (wx, wy, wz) = _wrist(side);
    b.capsule(ex, ey, ez, wx, wy, wz, 0.048, 0.045, skin, radial: 6, capBands: 1);
    final (hx, hy, hz) = _handC(side);
    b.ellipsoid(hx, hy, hz, 0.052, 0.055, 0.052, skin, lat: 4, lon: 8);
  }
  _legs(k, leg: pants, shoe: shoe, sole: sole);

  return k.build(
    ChibiCharacters.mai,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0.05, extraY: 0.93, extraZ: -0.26),
    extraKind: ChibiExtraKind.ponytail,
    crownY: head.cy + head.ry,
  );
}

// ---- Linh (thỏ trắng) --------------------------------------------------------------------------------------------

ChibiModel _linh() {
  const fur = 0xFBF6EF;
  const innerEar = 0xF7B5C4;
  const nose = 0xF08FA6;
  const hoodie = 0xC9B4E8;
  const hoodieDark = 0xB49CDC;
  const string = 0xFFFFFF;
  const skirt = 0xFFFFFF;
  const shoe = 0xF7BFCD;
  const mint = 0xA8DCC8;
  const strawberry = 0xE9505E;
  const leafGreen = 0x6CBF68;
  const starYellow = 0xFFD45A;
  const heart = 0xF28AA8;
  const pack = 0xF5B9C8;
  const packDark = 0xEDA2B5;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.965, 0, 0.285, 0.262, 0.25);

  // Thân: hoodie (thân + hông), mũ trùm sau gáy, dây rút, túi trước, viền gấu; váy xếp ly; đuôi bông; ba lô thỏ.
  k.body.ellipsoid(0, 0.49, 0, 0.2, 0.24, 0.17, hoodie, lat: 7, lon: 10);
  k.body.ellipsoid(0, 0.37, 0, 0.19, 0.11, 0.16, hoodie, lat: 4, lon: 10);
  k.body.torus(0, 0.715, -0.025, 0.115, 0.042, hoodieDark, basis: ChibiBasis.facing(0, 1, 0), segments: 8, tube: 3);
  k.body.ellipsoid(0, 0.765, -0.15, 0.14, 0.095, 0.07, hoodie, lat: 4, lon: 8);
  for (final side in const [1.0, -1.0]) {
    k.body.capsule(
      side * 0.035,
      0.68,
      0.122,
      side * 0.042,
      0.585,
      0.168,
      0.0075,
      0.0075,
      string,
      radial: 4,
      capBands: 1,
    );
    k.body.sphere(side * 0.042, 0.578, 0.17, 0.013, string, lat: 2, lon: 5);
  }
  const torso = ChibiSurface(0, 0.49, 0, 0.2, 0.24, 0.17);
  final (qx, qy, qz, qb) = torso.at(0, -16, lift: -0.002);
  k.body.dome(qx, qy, qz, 0.105, 0.052, 0.01, hoodieDark, basis: qb, segments: 10);
  k.body.frustum(
    0,
    0.355,
    0,
    0,
    0.212,
    0,
    0.165,
    0.228,
    skirt,
    pleats: 9,
    pleatDepth: 0.1,
    ovalZ: 0.88,
    capA: false,
    capB: false,
  );
  k.body.sphere(0, 0.3, -0.205, 0.055, fur, lat: 4, lon: 6);
  k.body.ellipsoid(0, 0.52, -0.2, 0.12, 0.125, 0.065, pack, lat: 4, lon: 8);
  k.body.ellipsoid(0, 0.585, -0.218, 0.11, 0.055, 0.06, packDark, lat: 3, lon: 8);
  k.body.sphere(0.0, 0.672, -0.212, 0.047, fur, lat: 4, lon: 6);
  for (final side in const [1.0, -1.0]) {
    k.body.capsule(side * 0.02, 0.7, -0.212, side * 0.032, 0.775, -0.215, 0.014, 0.012, fur, radial: 4, capBands: 1);
    // Quai ba lô: từ vai vòng xuống ngực (đoạn sau lưng bị ba lô che).
    k.body.capsule(
      side * 0.112,
      0.69,
      -0.05,
      side * 0.118,
      0.53,
      0.172,
      0.017,
      0.017,
      packDark,
      radial: 4,
      capBands: 1,
    );
  }

  // Đầu: lông trắng, mũi hồng, miệng ω, má hồng.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  final (nx, ny, nz, nb) = head.at(0, -14, lift: 0.006);
  k.head.ellipsoid(nx, ny, nz, 0.024, 0.017, 0.014, nose, basis: nb, lat: 3, lon: 6);
  // Hai má phúng phính quanh miệng.
  for (final side in const [1.0, -1.0]) {
    final (mx, my, mz, mb) = head.at(side * 9, -22, lift: -0.02);
    k.head.ellipsoid(mx, my, mz, 0.04, 0.032, 0.03, fur, basis: mb, lat: 3, lon: 6);
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -5);
  _cheeks(k, head, 41, -18);
  _omega(k, head, -22);

  // Tai thỏ (bộ phận phụ): ngoài trắng, trong hồng; kẹp dâu (tai trái), kẹp sao vàng (tai phải), khuyên tim.
  for (final side in const [1.0, -1.0]) {
    final b = ChibiBasis.euler(-0.12, 0, -side * 0.2);
    final cx = side * 0.1, cy = 1.37, cz = -0.03;
    k.extra.ellipsoid(cx, cy, cz, 0.064, 0.18, 0.042, fur, basis: b, lat: 6, lon: 8);
    // Lòng tai: vòm hồng trên mặt trước tai (viền tròn, không răng cưa như ellipsoid cắt nhau).
    k.extra.dome(
      cx + b.zx * 0.04 - b.yx * 0.012,
      cy + b.zy * 0.04 - b.yy * 0.012,
      cz + b.zz * 0.04,
      0.034,
      0.128,
      0.006,
      innerEar,
      basis: b,
      segments: 12,
    );
    final (hx, hy, hz, hb) = head.at(side * 62, 2, lift: 0.012);
    k.extra.heart(hx, hy - 0.02, hz, 0.04, heart, basis: hb);
  }
  k.extra.ellipsoid(0.125, 1.235, 0.085, 0.031, 0.037, 0.028, strawberry, lat: 4, lon: 7);
  k.extra.star(0.125, 1.272, 0.083, 0.026, 0.011, 0.008, leafGreen, basis: ChibiBasis.facing(0, 1, 0.2));
  k.extra.star(
    -0.125,
    1.24,
    0.085,
    0.044,
    0.02,
    0.016,
    starYellow,
    basis: ChibiBasis.facing(-0.2, 0.15, 1).then(ChibiBasis.euler(0, 0, 0.25)),
  );

  // Tay: tay áo hoodie phồng + viền tay, bàn tay trắng.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: hoodie, hand: fur, cuff: hoodieDark, rTop: 0.066, rWrist: 0.058, rHand: 0.054);
  }
  _legs(k, leg: fur, shoe: shoe, sole: 0xFFFFFF, chunky: true, accent: mint);

  return k.build(
    ChibiCharacters.linh,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 1.17, extraZ: -0.02),
    extraKind: ChibiExtraKind.ears,
    crownY: head.cy + head.ry,
  );
}

// ---- Ông Hòa (cú già) --------------------------------------------------------------------------------------------

ChibiModel _hoa() {
  // Bản cute 03/11 (vòng 3): lông nâu kem ấm, đĩa mặt kem tròn đối xứng, mỏ nhỏ tròn đặt thấp, lông mày = 2 vệt trắng
  // dẹt sát mặt, mắt to, bỏ kính; gile xô thơm nhạt, nơ dâu nhạt, mũ beret nhỏ hồng nhạt; gậy ngắn mập. Bỏ ria, dây
  // đồng hồ.
  const feather = 0xC49A74;
  const featherDark = 0xA87E5C;
  const disc = 0xFCF2E4;
  const beak = 0xF2B45C;
  const white = 0xFFFFFF;
  const beret = 0xEBA3AA;
  const vest = 0xC2D6AA;
  const shirt = 0xFFF4E6;
  const bow = 0xF28C98;
  const trousers = 0xE2D0B4;
  const shoes = 0x8A5A3C;
  const cane = 0xA0704A;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.965, 0, 0.3, 0.262, 0.258);

  // Thân: sơ mi kem, quần be (hông), gile xô thơm nhạt + nơ dâu nhạt, đuôi lông.
  const torso = ChibiSurface(0, 0.49, 0, 0.205, 0.24, 0.178);
  const hips = ChibiSurface(0, 0.37, 0, 0.198, 0.115, 0.17);
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, shirt, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  // Gile: tấm quấn kín quanh thân, cổ chữ V mở dần lên trên, vạt ngắn (tới hông).
  const vestRows = [
    (0.33, 0.04, 0.014),
    (0.41, 0.05, 0.01),
    (0.49, 0.08, 0.01),
    (0.55, 0.22, 0.01),
    (0.6, 0.42, 0.01),
    (0.645, 0.6, 0.009),
  ];
  k.body.shell(
    0,
    0,
    [
      for (final (y, v, off) in vestRows)
        () {
          final (rx, rz) = _wrapRadius(torso, hips, y, off);
          return (y, rx, rz, v, 2 * math.pi - v);
        }(),
    ],
    vest,
    segments: 16,
  );
  for (final side in const [1.0, -1.0]) {
    k.body.ellipsoid(
      side * 0.04,
      0.672,
      0.13,
      0.042,
      0.028,
      0.017,
      bow,
      basis: ChibiBasis.euler(-0.5, 0, side * 0.15),
      lat: 3,
      lon: 7,
    );
  }
  k.body.sphere(0, 0.672, 0.138, 0.016, bow, lat: 3, lon: 5);
  for (final side in const [1.0, 0.0, -1.0]) {
    k.body.ellipsoid(
      side * 0.05,
      0.31,
      -0.19,
      0.045,
      0.08,
      0.02,
      featherDark,
      basis: ChibiBasis.euler(-0.9, 0, side * 0.35),
      lat: 3,
      lon: 6,
    );
  }

  // Đầu: lông nâu kem, hai đĩa mặt kem tròn, mắt to, mỏ nhỏ tròn, lông mày trắng dẹt, má hồng, mũ beret nhỏ, chỏm
  // tai.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, feather, lat: 10, lon: 16);
  var eyeY = 0.0, eyeZ = 0.0;
  for (final side in const [1.0, -1.0]) {
    // Mảng kem quanh mắt: đĩa tròn đối xứng dán sát mặt (không kính — vòng 3).
    final (dx, dy, dz, db) = head.at(side * 22, -6, lift: -0.002);
    k.head.dome(dx, dy, dz, 0.104, 0.104, 0.01, disc, basis: db, segments: 18);
    final ex = dx + db.zx * 0.012, ey = dy + db.zy * 0.012, ez = dz + db.zz * 0.012;
    _eye(k, ex, ey, ez, db, w: 0.046, h: 0.056);
    eyeY += ey / 2;
    eyeZ += ez / 2;
  }
  // Mỏ nhỏ tròn, đặt thấp giữa hai đĩa mặt.
  final (bx, by, bz, bb) = head.at(0, -16, lift: 0.004);
  k.head.ellipsoid(bx, by, bz, 0.024, 0.021, 0.018, beak, basis: bb, lat: 5, lon: 8);
  k.head.ellipsoid(
    bx + bb.zx * 0.008,
    by + bb.zy * 0.008 - 0.012,
    bz + bb.zz * 0.008,
    0.012,
    0.011,
    0.01,
    beak,
    basis: bb,
    lat: 3,
    lon: 6,
  );
  // Lông mày: 2 vệt trắng dẹt mềm, dán sát mặt ngay trên đĩa kem (không nhô khỏi đường viền đầu).
  for (final side in const [1.0, -1.0]) {
    final (wx, wy, wz, wb) = head.at(side * 21, 17, lift: -0.001);
    k.head.dome(
      wx,
      wy,
      wz,
      0.044,
      0.013,
      0.005,
      white,
      basis: wb.then(ChibiBasis.euler(0, 0, -side * 0.12)),
      segments: 12,
    );
  }
  _cheeks(k, head, 47, -21, w: 0.04);
  // Mũ beret nhỏ (nhỏ hơn đầu, không che mắt), đội lệch.
  k.head.ellipsoid(
    0.03,
    1.212,
    -0.03,
    0.2,
    0.058,
    0.194,
    beret,
    basis: ChibiBasis.euler(0.08, 0, -0.14),
    lat: 5,
    lon: 14,
  );
  k.head.sphere(0.045, 1.272, -0.03, 0.018, beret, lat: 3, lon: 5);
  for (final side in const [1.0, -1.0]) {
    // Chỏm tai lông: ngắn, chóp tròn, gần như dựng thẳng (không chĩa ngang như cánh quạt).
    _softCone(k.head, side * 0.17, 1.14, -0.03, side * 0.21, 1.235, -0.04, 0.045, featherDark, flat: 0.5);
  }

  // Tay: tay áo sơ mi + đầu cánh lông; tay phải cầm gậy gỗ ngắn mập có móc tròn.
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final (wx, wy, wz) = _wrist(side);
    b.capsule(side * _shoulderX, _shoulderY, 0, wx, wy, wz, 0.062, 0.054, shirt, radial: 7, capBands: 2);
    final (hx, hy, hz) = _handC(side);
    b.ellipsoid(hx, hy, hz, 0.054, 0.066, 0.05, feather, basis: ChibiBasis.euler(0, 0, side * 0.15), lat: 4, lon: 8);
  }
  final arm = k.arm(-1);
  final (hx, hy, hz) = _handC(-1);
  final caneTop = (hx - 0.004, hy + 0.04, hz + 0.02);
  // Đáy gậy ở khung cũ y ≈ 0,13 → sau khi dời tay theo vai mới chạm sàn.
  arm.capsule(caneTop.$1, caneTop.$2, caneTop.$3, -0.262, 0.14, 0.05, 0.021, 0.019, cane, radial: 7, capBands: 2);
  arm.torus(
    caneTop.$1,
    caneTop.$2,
    caneTop.$3 + 0.034,
    0.034,
    0.019,
    cane,
    basis: ChibiBasis.facing(1, 0, 0),
    a0: 0,
    a1: math.pi,
    segments: 7,
    tube: 4,
  );
  _legs(k, leg: trousers, shoe: shoes);

  return k.build(
    ChibiCharacters.hoa,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ),
    gait: const ChibiGait(
      speed: 0.6,
      legSwing: 0.3,
      armSwing: 0.28,
      stride: 0.36,
      waddle: 0.055,
      bob: 0.02,
      lean: 0.1,
      cane: true,
    ),
    crownY: head.cy + head.ry,
  );
}

/// ---- Nora (cáo đỏ) -----------------------------------------------------------------------------------------------

/// Nora: thân cáo (đầu, tai, mõm, đuôi) dùng chung; bộ đồ thay được — thường (áo sọc hồng–kem, tạp dề bạc hà, quần be,
/// giày lười) hoặc lễ hội ([fest]: băng đô mù tạt lá phong, cổ sen trắng, cardigan hồng, váy yếm nâu dài, tất kem,
/// cầm túi bánh giấy bằng hai tay — xem [_noraFestOutfit]).
ChibiModel _nora({bool fest = false}) {
  const fur = 0xE8946A;
  const furDark = 0x6A4436;
  const cream = 0xFFF1E0;
  const innerEar = 0xFFE0CC;
  const nose = 0x3A2A26;
  const freckle = 0xC9805C;
  const clip = 0x86D2B4;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.285, 0.252, 0.25);
  const torso = ChibiSurface(0, 0.49, 0, 0.198, 0.24, 0.168);
  const hips = ChibiSurface(0, 0.36, 0, 0.188, 0.1, 0.158);

  final hold = fest ? _noraFestOutfit(k, torso, hips, fur) : _noraWorkOutfit(k, torso, hips, fur);

  // Đầu: lông cam đỏ, má lông xù, mõm kem, mũi đen, ω, má hồng + tàn nhang, tai nhọn (trong kem, chóp nâu), kẹp
  // bạc hà (bản lễ hội: băng đô thay kẹp).
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  for (final side in const [1.0, -1.0]) {
    k.head.frustum(
      side * 0.21,
      0.885,
      0.03,
      side * 0.33,
      0.85,
      0.02,
      0.07,
      0,
      fur,
      radial: 7,
      ovalZ: 0.6,
      capA: false,
      capB: false,
    );
  }
  const muzzle = ChibiSurface(0, 0.882, 0.165, 0.14, 0.088, 0.105);
  k.head.ellipsoid(muzzle.cx, muzzle.cy, muzzle.cz, muzzle.rx, muzzle.ry, muzzle.rz, cream, lat: 5, lon: 10);
  final (nx, ny, nz, nb) = muzzle.at(0, 18, lift: 0.004);
  k.head.ellipsoid(nx, ny, nz, 0.028, 0.019, 0.018, nose, basis: nb, lat: 3, lon: 6);
  final (mx, my, mz, mb) = muzzle.at(0, -12, lift: 0.0);
  final m2 = ChibiSurface(mx - mb.zx * 0.1, my - mb.zy * 0.1, mz - mb.zz * 0.1, 0.1, 0.1, 0.1);
  _omega(k, m2, 0, r: 0.012);
  for (final side in const [1.0, -1.0]) {
    final (bx, by, bz, bb) = muzzle.at(side * 52, 8, lift: -0.002);
    k.head.dome(bx, by, bz, 0.046, 0.031, 0.006, _blush, basis: bb, segments: 12);
    for (final (az, el) in const [(40.0, 20.0), (50.0, 17.0), (45.0, 9.0)]) {
      final (fx, fy, fz, fb) = muzzle.at(side * az, el, lift: 0.003);
      k.head.dome(fx, fy, fz, 0.0048, 0.0048, 0.002, freckle, basis: fb, segments: 5);
    }
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3);
  for (final side in const [1.0, -1.0]) {
    final bx = side * 0.15, by = 1.13, bz = -0.02;
    final tipX = side * 0.225, tipY = 1.39, tipZ = -0.035;
    _softCone(k.head, bx, by, bz, tipX, tipY, tipZ, 0.088, fur, flat: 0.45);
    k.head.frustum(
      bx,
      by + 0.015,
      bz + 0.03,
      side * 0.212,
      1.355,
      -0.0,
      0.05,
      0,
      innerEar,
      radial: 11,
      ovalZ: 0.3,
      capA: false,
      capB: false,
    );
    final f = 0.74;
    k.head.frustum(
      bx + (tipX - bx) * f,
      by + (tipY - by) * f,
      bz + (tipZ - bz) * f,
      tipX + side * 0.002,
      tipY + 0.004,
      tipZ,
      0.088 * (1 - f) + 0.007,
      0.012,
      furDark,
      radial: 12,
      ovalZ: 0.5,
      capA: false,
      capB: false,
    );
    k.head.ellipsoid(tipX + side * 0.002, tipY + 0.004, tipZ, 0.012, 0.012, 0.007, furDark, lat: 4, lon: 8);
  }
  if (fest) {
    _noraFestHeadband(k, head);
  } else {
    k.head.capsule(0.125, 1.18, 0.07, 0.195, 1.225, 0.05, 0.017, 0.017, clip, radial: 5, capBands: 1);
  }

  // Đuôi cáo (bộ phận phụ, gắn thân): to xù, chóp kem.
  const tail = [(0.0, 0.35, -0.16), (0.0, 0.39, -0.31), (0.02, 0.53, -0.43), (0.03, 0.69, -0.45)];
  for (final (i, r, color) in const [(0, 0.075, fur), (1, 0.122, fur), (2, 0.092, cream)]) {
    final (ax, ay, az) = tail[i];
    final (bx, by, bz) = tail[i + 1];
    final len = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2) + math.pow(bz - az, 2));
    k.extra.ellipsoid(
      (ax + bx) / 2,
      (ay + by) / 2,
      (az + bz) / 2,
      r,
      len * 0.62 + r * 0.25,
      r,
      color,
      basis: ChibiBasis.alongY(bx - ax, by - ay, bz - az),
      lat: 6,
      lon: 9,
    );
  }

  return k.build(
    fest ? ChibiCharacters.noraFest : ChibiCharacters.nora,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 0.36, extraZ: -0.15),
    extraKind: ChibiExtraKind.tail,
    hold: hold,
    crownY: head.cy + head.ry,
  );
}

/// Bộ đồ làm việc của Nora: áo sọc hồng–kem, quần be, tạp dề bạc hà + bảng tên trơn, tay áo sọc xắn, giày lười nâu.
/// Không cầm gì.
ChibiHold? _noraWorkOutfit(_Sketch k, ChibiSurface torso, ChibiSurface hips, int fur) {
  const pink = 0xF2A2AE;
  const shirt = 0xFFF4E6;
  const apron = 0xA8DCC8;
  const tag = 0xFFFFFF;
  const trousers = 0xEADBB8;
  const loafer = 0x8A5A3C;

  // Thân: áo sọc hồng–kem, quần be, tạp dề bạc hà + bảng tên trơn.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, shirt, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  double rAt(double y) => torso.rx * math.sqrt(math.max(0, 1 - math.pow((y - torso.cy) / torso.ry, 2)));
  for (final y in const [0.45, 0.52, 0.59, 0.655]) {
    const t = 0.028;
    k.body.frustum(
      0,
      y,
      0,
      0,
      y + t,
      0,
      rAt(y) + 0.003,
      rAt(y + t) + 0.003,
      pink,
      radial: 12,
      ovalZ: torso.rz / torso.rx,
      capA: false,
      capB: false,
    );
  }
  final onApron = _apron(k, apron, torso, hips);
  final (tx, ty, tz, tb) = onApron(-0.26, 0.6, 0.004);
  k.body.box(tx, ty, tz, 0.064, 0.026, 0.008, tag, basis: tb);

  // Tay: tay áo sọc xắn (ống xắn kem), bàn tay lông, lắc bạc tay trái.
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final (wx, wy, wz) = _wrist(side);
    final sx = side * _shoulderX;
    b.capsule(sx, _shoulderY, 0, wx, wy, wz, 0.06, 0.05, shirt, radial: 7, capBands: 2);
    for (final t in const [0.2, 0.5]) {
      final ax = sx + (wx - sx) * t, ay = _shoulderY + (wy - _shoulderY) * t, az = wz * t;
      final bx = sx + (wx - sx) * (t + 0.13), by = _shoulderY + (wy - _shoulderY) * (t + 0.13), bz = wz * (t + 0.13);
      final r0 = 0.06 + (0.05 - 0.06) * t + 0.003, r1 = 0.06 + (0.05 - 0.06) * (t + 0.13) + 0.003;
      b.frustum(ax, ay, az, bx, by, bz, r0, r1, pink, radial: 7, capA: false, capB: false);
    }
    final rx = sx + (wx - sx) * 0.78, ry = _shoulderY + (wy - _shoulderY) * 0.78, rz = wz * 0.78;
    final ddx = wx - sx, ddy = wy - _shoulderY, ddz = wz;
    _band(
      b,
      rx - ddx * 0.07,
      ry - ddy * 0.07,
      rz - ddz * 0.07,
      rx + ddx * 0.07,
      ry + ddy * 0.07,
      rz + ddz * 0.07,
      0.066,
      shirt,
    );
    final (hx, hy, hz) = _handC(side);
    b.ellipsoid(hx, hy, hz, 0.054, 0.057, 0.054, fur, lat: 4, lon: 8);
  }
  _legs(k, leg: trousers, shoe: loafer);
  return null;
}
