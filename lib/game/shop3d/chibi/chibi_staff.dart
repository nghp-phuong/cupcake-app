part of 'chibi_characters.dart';

// Nhân viên tiệm (docs/v3/character-3d-procedural.md, bảng "Quyết định 03/11"): Bao (gấu nâu, thợ bánh), Theo (chó
// corgi, phục vụ), Ami (gấu trúc, thợ bánh 2), Hạnh (mèo mướp xám, quản lý); bộ đồ lễ hội của Bao và Nora dùng chung
// thân với bản thường ("bộ đồ thay được": hàm dựng nhận cờ `fest`). Màu / đặc điểm theo ảnh 2D
// `assets/characters/staff_*_neutral.webp`.

// ---- Bao (gấu nâu) -----------------------------------------------------------------------------------------------

/// Bao: gấu nâu thợ bánh, to cao bụng tròn. Thân gấu dùng chung; bộ đồ làm việc (mũ thợ bánh trắng nhỏ, áo trắng xắn
/// tay, tạp dề caramel dính bột, khăn giắt dây tạp dề, quần xám, giày nâu) hoặc lễ hội ([fest]: mũ nồi nâu cài lá
/// phong, khăn quàng hồng, áo kem viền nâu hai hàng cúc, tạp dề vàng lá phong trên váy nâu). Cả hai cầm cây cán bột hai
/// tay.
ChibiModel _bao({bool fest = false}) {
  const fur = 0x8E5B3B;
  const muzzleC = 0xE6C6A2;
  const nose = 0x2A1C18;
  const innerEar = 0xD8A47E;
  const pin = 0xE0B482;
  const pinEnd = 0xC28C5A;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.292, 0.258, 0.255);
  // Bụng tròn hơn người thường.
  const torso = ChibiSurface(0, 0.49, 0, 0.214, 0.245, 0.182);
  const hips = ChibiSurface(0, 0.36, 0, 0.202, 0.1, 0.17);

  if (fest) {
    _baoFestOutfit(k, head, torso, hips, fur);
  } else {
    _baoWorkOutfit(k, head, torso, hips, fur);
  }

  // Đầu gấu: mõm sáng to, mũi đen, tai tròn hai bên đỉnh đầu, đuôi tròn nhỏ.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  _snout(k, const ChibiSurface(0, 0.878, 0.17, 0.135, 0.092, 0.105), muzzleC, nose,
      noseEl: 26, noseW: 0.038, noseH: 0.026, mouthEl: -16, mouthR: 0.013);
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3, w: 0.041, h: 0.055);
  _cheeks(k, head, 44, -16);
  for (final side in const [1.0, -1.0]) {
    _roundEar(k.head, side * 0.205, 1.135, -0.015, 0.08, fur, innerEar, ChibiBasis.facing(side * 0.4, 0.25, 1));
  }
  k.body.sphere(0, 0.33, -0.19, 0.05, fur, lat: 4, lon: 6);

  // Cây cán bột: hai tay cầm ngang trước bụng; lô gỗ giữa hai bàn tay, tay cầm nhỏ nhô ra hai bên.
  const h = ChibiHold(twoHands: true, forward: 0.62, raise: -0.1, workForward: 0.85);
  final f = _PropFrame(h);
  final (sx, sy, sz) = f.span;
  final a0 = f.at(0.045, 0.0, 0.01), a1 = f.at(sx - 0.045, sy, sz + 0.01);
  k.prop.capsule(a0.$1, a0.$2, a0.$3, a1.$1, a1.$2, a1.$3, 0.036, 0.036, pin, radial: 10, capBands: 2);
  for (final (from, to) in [((-0.085, 0.0), (0.05, 0.0)), ((sx - 0.05, sy), (sx + 0.085, sy))]) {
    final p0 = f.at(from.$1, from.$2, sz * 0.5 + 0.01), p1 = f.at(to.$1, to.$2, sz * 0.5 + 0.01);
    k.prop.capsule(p0.$1, p0.$2, p0.$3, p1.$1, p1.$2, p1.$3, 0.016, 0.016, pinEnd, radial: 6, capBands: 1);
  }

  return k.build(
    fest ? ChibiCharacters.baoFest : ChibiCharacters.bao,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ),
    gait: const ChibiGait(speed: 0.8, legSwing: 0.42, armSwing: 0.5, stride: 0.48, waddle: 0.085, bob: 0.03),
    scale: 1.16,
    radius: 0.28,
    hold: f.hold,
    crownY: head.cy + head.ry,
  );
}

/// Khăn lau giắt dây tạp dề bên hông phải: tấm vải kem có hai sọc hồng đất.
void _towel(_Sketch k, ChibiSurface torso, ChibiSurface hips) {
  const towel = 0xF5F1EB;
  const stripe = 0xE2A69C;
  final (x, y, z, b) = _wrapPoint(torso, hips, -1.12, 0.41, 0.025, 0.006);
  final tb = b.then(ChibiBasis.euler(0.0, 0, 0.12));
  k.body.box(x, y - 0.07, z, 0.085, 0.16, 0.014, towel, basis: tb);
  for (final dy in const [-0.115, -0.13]) {
    k.body.box(x + tb.yx * (dy + 0.07) + tb.zx * 0.008, y + tb.yy * (dy + 0.07) - 0.07 + 0.07 * (1 - tb.yy),
        z + tb.yz * (dy + 0.07) + tb.zz * 0.008, 0.087, 0.007, 0.004, stripe,
        basis: tb);
  }
  k.body.ellipsoid(x, y + 0.012, z, 0.05, 0.022, 0.018, towel, basis: tb, lat: 3, lon: 6);
}

void _baoWorkOutfit(_Sketch k, ChibiSurface head, ChibiSurface torso, ChibiSurface hips, int fur) {
  const jacket = 0xFBF6EC;
  const shade = 0xEDE3D2;
  const button = 0xC9A27A;
  // Tạp dề sáng hơn lông (không nâu trên nâu), quần xanh lam nhạt thay xám.
  const apron = 0xF4C98A;
  const flour = 0xFFF8EE;
  const trousers = 0x8494BC;
  const shoes = 0x6B4430;
  const sole = 0x4A3022;
  const cap = 0xFFFFFF;

  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, jacket, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  // Cổ áo đứng.
  k.body.torus(0, 0.695, 0.0, 0.112, 0.026, shade, basis: ChibiBasis.facing(0, 1, 0), segments: 10, tube: 3);
  final onApron = _apron(k, apron, torso, hips);
  // Cúc áo hai hàng lộ hai bên yếm tạp dề.
  for (final side in const [1.0, -1.0]) {
    for (final y in const [0.6, 0.655]) {
      final (x, py, z, _) = _wrapPoint(torso, hips, side * 0.66, y, 0.0, 0.004);
      k.body.sphere(x, py, z, 0.012, button, lat: 2, lon: 5);
    }
  }
  // Bột dính trên tạp dề.
  for (final (a, y, r) in const [
    (0.32, 0.33, 0.022),
    (-0.22, 0.27, 0.016),
    (0.12, 0.47, 0.014),
    (-0.38, 0.5, 0.019),
    (0.5, 0.24, 0.013),
    (-0.05, 0.36, 0.011),
  ]) {
    final (x, py, z, b) = onApron(a, y, 0.003);
    k.body.dome(x, py, z, r, r * 0.8, 0.003, flour, basis: b, segments: 7);
  }
  _towel(k, torso, hips);

  // Mũ thợ bánh trắng nhỏ giữa hai tai: thân mũ + chỏm phồng.
  k.head.frustum(0, 1.15, -0.015, 0, 1.245, -0.025, 0.125, 0.14, cap, radial: 12, capA: false, capB: false);
  k.head.ellipsoid(0, 1.262, -0.025, 0.158, 0.06, 0.152, cap, lat: 4, lon: 12);
  k.head.torus(0, 1.16, -0.015, 0.127, 0.012, shade, basis: ChibiBasis.facing(0, 1, 0), segments: 12, tube: 3);

  // Tay áo trắng xắn tới khuỷu + cẳng tay lông + bàn tay gấu.
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final ex = side * (_shoulderX + 0.02), ey = _shoulderY - 0.11, ez = 0.008;
    b.capsule(side * _shoulderX, _shoulderY, 0, ex, ey, ez, 0.066, 0.06, jacket, radial: 7, capBands: 2);
    _band(b, ex - side * 0.003, ey + 0.018, ez, ex + side * 0.003, ey - 0.022, ez + 0.002, 0.07, shade);
    final (wx, wy, wz) = _wrist(side);
    b.capsule(ex, ey, ez, wx, wy, wz, 0.052, 0.048, fur, radial: 6, capBands: 1);
    final (hx, hy, hz) = _handC(side);
    b.ellipsoid(hx, hy, hz, 0.058, 0.06, 0.056, fur, lat: 4, lon: 8);
  }
  _legs(k, leg: trousers, shoe: shoes, sole: sole);
}

void _baoFestOutfit(_Sketch k, ChibiSurface head, ChibiSurface torso, ChibiSurface hips, int fur) {
  const jacket = 0xFFF1DC;
  const piping = 0x9A6A40;
  const button = 0x8A5A34;
  const scarf = 0xE5747E;
  const apron = 0xF3D27A;
  // Không nâu trên nâu: váy + quần xô thơm nhạt, mũ nồi hồng như khăn quàng.
  const skirt = 0xAFC9A0;
  const trousers = 0xAFC9A0;
  const shoes = 0x7A4A30;
  const beret = 0xE5747E;
  const leaves = [0xE0782E, 0xD9542E, 0xE8A23A];

  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, jacket, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  // Áo hai hàng cúc: viền nâu dọc vạt + hai hàng cúc nâu.
  for (final side in const [1.0, -1.0]) {
    final (ax, ay, az, _) = _wrapPoint(torso, hips, side * 0.34, 0.44, 0.0, 0.003);
    final (bx, by, bz, _) = _wrapPoint(torso, hips, side * 0.3, 0.66, 0.0, 0.003);
    k.body.capsule(ax, ay, az, bx, by, bz, 0.007, 0.007, piping, radial: 4, capBands: 1);
    for (final y in const [0.47, 0.54, 0.61]) {
      final (x, py, z, _) = _wrapPoint(torso, hips, side * 0.2, y, 0.0, 0.005);
      k.body.sphere(x, py, z, 0.013, button, lat: 2, lon: 5);
    }
  }
  // Khăn quàng hồng thắt nút trước cổ, vạt tam giác buông xuống.
  k.body.torus(0, 0.69, 0.0, 0.11, 0.024, scarf, basis: ChibiBasis.facing(0, 1, 0), segments: 10, tube: 3);
  k.body.sphere(0, 0.675, 0.15, 0.03, scarf, lat: 3, lon: 6);
  k.body.frustum(0, 0.665, 0.158, 0, 0.555, 0.19, 0.062, 0, scarf, radial: 6, ovalZ: 0.3, capA: false, capB: false);
  // Váy ngắn xoè (lớp dưới) + tạp dề vàng phủ trước và hai bên, ngắn hơn, có lá phong.
  const top = 0.42, bottom = 0.235, rTop = 0.21, rBottom = 0.275;
  k.body.frustum(0, top, 0, 0, bottom, 0, rTop, rBottom, skirt, radial: 14, capA: false, capB: false);
  double rAt(double y) => rTop + (top - y) / (top - bottom) * (rBottom - rTop);
  k.body.shell(
      0,
      0,
      [
        for (final y in const [0.255, 0.3, 0.35, 0.39, 0.425]) (y, rAt(y) + 0.012, rAt(y) + 0.012, -1.85, 1.85),
      ],
      apron,
      segments: 14);
  k.body.frustum(0, 0.4, 0, 0, 0.44, 0, rTop + 0.014, rTop + 0.004, apron, radial: 14, capA: false, capB: false);
  var i = 0;
  for (final (a, y, s) in const [
    (0.35, 0.33, 0.036),
    (-0.15, 0.29, 0.03),
    (0.75, 0.3, 0.028),
    (-0.6, 0.34, 0.034),
    (0.05, 0.37, 0.026),
    (1.1, 0.32, 0.026),
  ]) {
    final r = rAt(y) + 0.016;
    final b = ChibiBasis.facing(math.sin(a), 0, math.cos(a)).then(ChibiBasis.euler(0, 0, a * 1.7 + i));
    k.body.star(r * math.sin(a), y, r * math.cos(a), s, s * 0.5, 0.004, leaves[i % leaves.length], basis: b);
    i++;
  }
  _towel(k, torso, hips);

  // Mũ nồi nâu đội lệch giữa hai tai, cài lá phong cam.
  k.head.ellipsoid(-0.015, 1.215, -0.01, 0.2, 0.065, 0.195, beret,
      basis: ChibiBasis.euler(0.06, 0, 0.14), lat: 5, lon: 14);
  k.head.sphere(-0.035, 1.282, -0.01, 0.018, beret, lat: 2, lon: 5);
  k.head.star(-0.13, 1.215, 0.13, 0.042, 0.02, 0.006, leaves[0],
      basis: ChibiBasis.facing(-0.4, 0.5, 0.75).then(ChibiBasis.euler(0, 0, 0.4)));

  // Tay áo kem dài, viền cổ tay nâu.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: jacket, hand: fur, cuff: piping, rTop: 0.066, rWrist: 0.054, rHand: 0.058);
  }
  _legs(k, leg: trousers, shoe: shoes);
}

// ---- Theo (chó corgi) --------------------------------------------------------------------------------------------

/// Theo: chó corgi phục vụ, dáng mảnh — lông cam vàng, mõm + vệt trán trắng, tai to dựng, chỏm lông xoăn nâu nhạt, tàn
/// nhang; sơ mi trắng, nơ hồng dâu, gile vàng bơ, tạp dề ngắn kem, quần be sẫm, giày thể thao nâu; tay phải bưng khay
/// gỗ tròn có tách trà ngang vai; đuôi xù ngắn (vẫy).
ChibiModel _theo() {
  const fur = 0xE59C55;
  const white = 0xFFF8EE;
  const innerEar = 0xF4BFB0;
  const nose = 0x2A1E1C;
  const curl = 0xD9A264;
  const freckle = 0xC4733E;
  const shirt = 0xFFFFFF;
  const shirtShade = 0xEFEAE2;
  const bow = 0xF49AB0;
  const vest = 0xFFD27A;
  const vestButton = 0xE0A848;
  const apron = 0xFFF4E6;
  const trousers = 0xA48A6A;
  const sneaker = 0x8E5E3E;
  const sole = 0xF6F1E8;
  const tray = 0xB57E4E;
  const trayRim = 0x9A6640;
  const cup = 0xFFFFFF;
  const cupBand = 0xF49AB0;
  const tea = 0xB8743E;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.29, 0.255, 0.252);
  const torso = ChibiSurface(0, 0.49, 0, 0.19, 0.238, 0.162);
  const hips = ChibiSurface(0, 0.36, 0, 0.182, 0.1, 0.152);

  // Thân: sơ mi trắng, quần, gile vàng cổ chữ V + cúc, nơ hồng, tạp dề ngắn kem.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, shirt, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  const vestRows = [
    (0.31, 0.04, 0.016),
    (0.36, 0.04, 0.012),
    (0.44, 0.06, 0.01),
    (0.52, 0.12, 0.01),
    (0.58, 0.3, 0.01),
    (0.63, 0.5, 0.01),
    (0.665, 0.68, 0.009),
  ];
  _openJacket(k, torso, hips, vestRows, vest);
  for (final y in const [0.37, 0.43, 0.49]) {
    final (x, py, z, _) = _wrapPoint(torso, hips, 0.0, y, 0.012, 0.005);
    k.body.sphere(x, py, z, 0.011, vestButton, lat: 2, lon: 5);
  }
  for (final side in const [1.0, -1.0]) {
    k.body.ellipsoid(side * 0.036, 0.672, 0.128, 0.038, 0.025, 0.016, bow,
        basis: ChibiBasis.euler(-0.5, 0, side * 0.15), lat: 3, lon: 6);
    // Cổ áo sơ mi.
    k.body.ellipsoid(side * 0.05, 0.692, 0.105, 0.04, 0.02, 0.014, shirtShade,
        basis: ChibiBasis.euler(-0.7, side * 0.5, side * 0.5), lat: 2, lon: 5);
  }
  k.body.sphere(0, 0.672, 0.137, 0.014, bow, lat: 2, lon: 5);
  k.body.shell(
    0,
    torso.cz,
    [
      for (final (y, half, off) in const [
        (0.2, 1.08, 0.034),
        (0.26, 1.06, 0.024),
        (0.33, 1.02, 0.016),
        (0.385, 0.98, 0.014),
      ])
        () {
          final (rx, rz) = _wrapRadius(torso, hips, y, off);
          return (y, rx, rz, -half, half);
        }(),
    ],
    apron,
    segments: 10,
  );

  // Đầu: lông cam, vệt trán trắng, mõm trắng to, tàn nhang, tai to dựng, chỏm lông xoăn.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  final (fx, fy, fz, fb) = head.at(0, 20, lift: -0.012);
  k.head.ellipsoid(fx, fy, fz, 0.04, 0.1, 0.03, white, basis: fb, lat: 4, lon: 8);
  const muzzle = ChibiSurface(0, 0.878, 0.158, 0.158, 0.096, 0.112);
  _snout(k, muzzle, white, nose, noseEl: 22, noseW: 0.032, noseH: 0.022, mouthEl: -14);
  for (final side in const [1.0, -1.0]) {
    final (bx, by, bz, bb) = muzzle.at(side * 54, 6, lift: -0.002);
    k.head.dome(bx, by, bz, 0.046, 0.031, 0.006, _blush, basis: bb, segments: 12);
    for (final (az, el) in const [(38.0, 20.0), (48.0, 16.0), (43.0, 8.0)]) {
      final (px, py, pz, pb) = muzzle.at(side * az, el, lift: 0.003);
      k.head.dome(px, py, pz, 0.0048, 0.0048, 0.002, freckle, basis: pb, segments: 5);
    }
    _pointEar(k.head, side * 0.14, 1.12, -0.02, side * 0.245, 1.4, -0.04, 0.1, fur, innerEar);
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3);
  for (final (az, el, r) in const [
    (-16.0, 50.0, 0.045),
    (6.0, 54.0, 0.048),
    (-4.0, 64.0, 0.042),
    (20.0, 46.0, 0.04),
    (-28.0, 42.0, 0.036),
    (10.0, 66.0, 0.036),
  ]) {
    final (x, y, z, _) = head.at(az, el, lift: -0.012);
    k.head.sphere(x, y, z, r, curl, lat: 4, lon: 6);
  }

  // Đuôi xù ngắn (bộ phận phụ, gắn thân): cam, chóp trắng.
  _tailChain(k.extra, const [(0.0, 0.35, -0.14), (0.0, 0.39, -0.23), (0.0, 0.46, -0.27)], const [0.062, 0.07],
      const [fur, white],
      lat: 5, lon: 8);

  // Tay: tay áo trắng + cổ tay áo, bàn chân trắng (corgi "đi tất").
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: shirt, hand: white, cuff: shirtShade, rTop: 0.06, rWrist: 0.05, rHand: 0.055);
  }
  _legs(k, leg: trousers, shoe: sneaker, sole: sole);

  // Khay gỗ tròn có tách trà trên bàn tay phải, ngang vai (khay luôn nằm ngang).
  const h = ChibiHold(side: -1, forward: 1.32, raise: 0.42);
  final f = _PropFrame(h);
  final (tx, ty, tz) = f.at(-0.06, 0.068, 0.02);
  k.prop.ellipsoid(tx, ty, tz, 0.165, 0.011, 0.165, tray, lat: 3, lon: 16);
  k.prop.torus(tx, ty + 0.008, tz, 0.158, 0.011, trayRim, basis: ChibiBasis.facing(0, 1, 0), segments: 16, tube: 3);
  final (cx, cy, cz) = (tx + 0.02, ty + 0.012, tz - 0.01);
  k.prop.ellipsoid(cx, cy + 0.004, cz, 0.055, 0.007, 0.055, cup, lat: 2, lon: 10);
  k.prop.frustum(cx, cy + 0.008, cz, cx, cy + 0.058, cz, 0.032, 0.043, cup, radial: 10, capB: false);
  k.prop.frustum(cx, cy + 0.03, cz, cx, cy + 0.042, cz, 0.0385, 0.0405, cupBand, radial: 10, capA: false, capB: false);
  k.prop.ellipsoid(cx, cy + 0.052, cz, 0.039, 0.005, 0.039, tea, lat: 2, lon: 10);
  k.prop.torus(cx - 0.047, cy + 0.035, cz, 0.014, 0.0045, cup,
      basis: ChibiBasis.facing(0, 0, 1), a0: math.pi * 0.5, a1: math.pi * 1.5, segments: 5, tube: 3);

  return k.build(
    ChibiCharacters.theo,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 0.35, extraZ: -0.14),
    gait: const ChibiGait(speed: 0.95, legSwing: 0.5, armSwing: 0.6, stride: 0.48, waddle: 0.06, bob: 0.035),
    extraKind: ChibiExtraKind.tail,
    scale: 1.08,
    hold: f.hold,
    crownY: head.cy + head.ry,
  );
}

// ---- Ami (gấu trúc) ----------------------------------------------------------------------------------------------

/// Ami: gấu trúc thợ bánh 2 — lông trắng, quầng mắt đen xếch xuống, tai đen, chân tay đen; búi tóc đen cao cài bút chì
/// gỗ, mái lệch; áo kem cộc tay, tạp dề hồng dâu có túi + găng nướng bạc hà treo ở túi, quần navy xắn gấu, guốc trắng;
/// hai tay bưng khay gỗ có 3 bánh bao.
ChibiModel _ami() {
  // Đen dịu (than tím), không đen thuần.
  const white = 0xFBF8F4;
  const black = 0x3E3846;
  const patch = 0x8A8096;
  const nose = 0x2A2430;
  const bun = 0x3A3442;
  const pencil = 0xE8B86A;
  const pencilWood = 0xF2D7A8;
  const lead = 0x4A4040;
  const eraser = 0xF49AB0;
  const blouse = 0xF6EBD6;
  const apron = 0xE8807F;
  const pocket = 0xD87072;
  const mitt = 0xA8DCC8;
  const mittLine = 0x88C2AC;
  const trousers = 0x3D4C72;
  const cuff = 0x56658C;
  const clog = 0xF6F4F0;
  const clogSole = 0xD8D3CC;
  const board = 0xBE8A58;
  const bunC = 0xDB9C52;
  const bunTop = 0xEFC07E;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.29, 0.256, 0.254);
  const torso = ChibiSurface(0, 0.49, 0, 0.2, 0.24, 0.17);
  const hips = ChibiSurface(0, 0.36, 0, 0.19, 0.1, 0.16);

  // Thân: áo kem, quần navy, tạp dề hồng có túi, găng nướng bạc hà treo ở túi.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, blouse, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  final onApron = _apron(k, apron, torso, hips);
  final (px, py, pz, pb) = onApron(0.0, 0.36, 0.003);
  k.body.dome(px, py, pz, 0.085, 0.045, 0.006, pocket, basis: pb, segments: 10);
  final (mx, my, mz, mb) = onApron(-0.38, 0.31, 0.012);
  final mittB = mb.then(ChibiBasis.euler(0, 0, -0.25));
  k.body.ellipsoid(mx, my - 0.03, mz, 0.042, 0.065, 0.016, mitt, basis: mittB, lat: 4, lon: 8);
  k.body.ellipsoid(mx - mittB.xx * 0.04, my - 0.02 - mittB.xy * 0.04, mz - mittB.xz * 0.04, 0.016, 0.03, 0.013, mitt,
      basis: mittB.then(ChibiBasis.euler(0, 0, 0.6)), lat: 3, lon: 6);
  for (final d in const [-0.025, 0.0, 0.025]) {
    k.body.capsule(
      mx + mittB.xx * d - mittB.yx * 0.075,
      my + mittB.xy * d - 0.03 - mittB.yy * 0.05,
      mz + mittB.zz * 0.016,
      mx + mittB.xx * d + mittB.yx * 0.03,
      my + mittB.xy * d - 0.03 + mittB.yy * 0.045,
      mz + mittB.zz * 0.016,
      0.003,
      0.003,
      mittLine,
      radial: 3,
      capBands: 1,
    );
  }

  // Đầu: trắng, mõm nhỏ, mũi đen, quầng mắt đen xếch xuống (mắt có viền trắng cho nổi trên quầng), tai đen tròn.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, white, lat: 10, lon: 16);
  _snout(k, const ChibiSurface(0, 0.884, 0.18, 0.112, 0.074, 0.08), white, nose,
      noseEl: 26, noseW: 0.03, noseH: 0.021, mouthEl: -16, mouthR: 0.011);
  for (final side in const [1.0, -1.0]) {
    // Quầng mắt hình giọt nước xếch xuống phía ngoài, màu than tím dịu (mắt đen vẫn nổi), không viền sáng — vòng 3:
    // viền + quầng đậm trông như kính râm.
    final (x, y, z, b) = head.at(side * 27, -9, lift: -0.003);
    k.head.dome(x, y, z, 0.088, 0.072, 0.012, patch, basis: b.then(ChibiBasis.euler(0, 0, -side * 0.5)), segments: 16);
    _roundEar(k.head, side * 0.205, 1.14, -0.015, 0.076, black, null, ChibiBasis.facing(side * 0.4, 0.25, 1));
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 24, -4, w: 0.04, h: 0.054, lift: 0.012);
  _cheeks(k, head, 47, -22, w: 0.042);
  // Búi tóc cao cài bút chì gỗ, mái lệch.
  k.head.sphere(0, 1.255, -0.035, 0.088, bun, lat: 5, lon: 9);
  k.head.ellipsoid(0, 1.2, -0.03, 0.1, 0.035, 0.095, bun, lat: 3, lon: 9);
  const p0 = (-0.15, 1.262, 0.0), p1 = (0.13, 1.295, -0.06);
  k.head.capsule(p0.$1, p0.$2, p0.$3, p1.$1, p1.$2, p1.$3, 0.011, 0.011, pencil, radial: 6, capBands: 1);
  k.head.frustum(p0.$1, p0.$2, p0.$3, p0.$1 - 0.03, p0.$2 - 0.004, p0.$3 + 0.006, 0.011, 0.003, pencilWood,
      radial: 6, capA: false, capB: false);
  k.head.sphere(p0.$1 - 0.031, p0.$2 - 0.004, p0.$3 + 0.006, 0.004, lead, lat: 2, lon: 4);
  k.head.sphere(p1.$1 + 0.006, p1.$2 + 0.001, p1.$3 - 0.001, 0.013, eraser, lat: 3, lon: 5);
  // Mái lệch: lọn tóc đen mảnh vuốt từ chân búi xuống thái dương phải (không phủ trán trắng).
  k.head.capsule(-0.06, 1.2, 0.02, -0.17, 1.12, 0.13, 0.026, 0.014, bun, radial: 6, capBands: 1);
  k.head.capsule(-0.03, 1.21, 0.0, -0.12, 1.16, 0.11, 0.022, 0.012, bun, radial: 6, capBands: 1);

  // Tay: tay áo cộc kem, cánh tay + bàn tay đen.
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final (wx, wy, wz) = _wrist(side);
    final sx = side * _shoulderX;
    b.capsule(sx, _shoulderY, 0, wx, wy, wz, 0.054, 0.046, black, radial: 7, capBands: 2);
    b.capsule(sx, _shoulderY, 0, sx + (wx - sx) * 0.38, _shoulderY + (wy - _shoulderY) * 0.38, wz * 0.38, 0.067, 0.062,
        blouse,
        radial: 7, capBands: 2);
    final (hx, hy, hz) = _handC(side);
    b.ellipsoid(hx, hy, hz, 0.055, 0.058, 0.054, black, lat: 4, lon: 8);
  }
  // Chân: quần navy xắn gấu, guốc trắng tròn.
  for (final side in const [1.0, -1.0]) {
    final b = k.leg(side);
    final x = side * _legX;
    b.capsule(x, 0.1, 0, x, _hipY + 0.03, 0, 0.064, 0.07, trousers, radial: 7, capBands: 1);
    _band(b, x, 0.13, 0, x, 0.165, 0, 0.071, cuff);
    b.capsule(x, 0.07, 0, x, 0.12, 0, 0.048, 0.05, black, radial: 6, capBands: 1);
    b.ellipsoid(x, 0.052, 0.03, 0.078, 0.052, 0.112, clog, lat: 4, lon: 9);
    b.ellipsoid(x, 0.018, 0.03, 0.08, 0.018, 0.114, clogSole, lat: 2, lon: 9);
  }

  // Khay gỗ có 3 bánh bao, hai tay bưng trước bụng.
  const h = ChibiHold(twoHands: true, forward: 0.74, raise: -0.12, workForward: 0.9);
  final f = _PropFrame(h);
  final (sx, sy, sz) = f.span;
  final (bx, by, bz) = f.at(sx / 2, sy / 2 + 0.05, sz / 2 + 0.035);
  k.prop.box(bx, by, bz, sx + 0.1, 0.022, 0.17, board);
  for (final d in const [-0.095, 0.0, 0.095]) {
    k.prop.ellipsoid(bx + d, by + 0.035, bz + (d == 0 ? -0.01 : 0.012), 0.05, 0.036, 0.05, bunC, lat: 4, lon: 9);
    k.prop.dome(bx + d - 0.008, by + 0.066, bz + (d == 0 ? -0.01 : 0.012) + 0.008, 0.022, 0.018, 0.006, bunTop,
        basis: ChibiBasis.facing(-0.2, 1, 0.3), segments: 7);
  }

  return k.build(ChibiCharacters.ami, ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ),
      gait: const ChibiGait(speed: 0.88, legSwing: 0.44, armSwing: 0.5, stride: 0.46, waddle: 0.075, bob: 0.032),
      hold: f.hold,
      crownY: head.cy + head.ry);
}

// ---- Hạnh (mèo mướp xám xanh) ------------------------------------------------------------------------------------

/// Hạnh: mèo mướp quản lý — bản cute 03/11: lông xám xanh nhạt sọc xám xanh đậm (vằn chữ M trên trán + vằn má), mõm
/// trắng, mũi hồng; búi thấp nhỏ có sợi bạc, kính tròn gọng mảnh nhỏ ôm mắt; áo len bạc hà pastel (cổ bo, gấu bo), váy
/// ngắn xoè caramel nhạt, giày nâu; tay trái ôm bìa kẹp hồ sơ nhỏ trước ngực; đuôi vằn. Bỏ cardigan, bút chì, đồng hồ,
/// khuyên.
ChibiModel _hanh() {
  const fur = 0xC9D3DF;
  const stripe = 0x9CA9BE;
  const white = 0xFAF8F6;
  const nose = 0xF0A0AC;
  const innerEar = 0xF6C8D0;
  const bunC = 0xB4BFCE;
  const silver = 0xF4F6FA;
  const frame = 0xB07A52;
  const sweater = 0xBFE6D4;
  const rib = 0xA6D8C2;
  const skirt = 0xE2B48A;
  const shoe = 0x8A5A3C;
  const board = 0xC08A5C;
  const paper = 0xFFFBF2;
  const clip = 0xD6D9DE;
  const line = 0xD7CEC2;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.288, 0.254, 0.252);
  const torso = ChibiSurface(0, 0.49, 0, 0.198, 0.24, 0.168);
  const hips = ChibiSurface(0, 0.36, 0, 0.188, 0.1, 0.158);

  // Thân: áo len bạc hà (thân + hông), cổ bo + gấu bo; váy ngắn xoè xếp ly.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, sweater, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, skirt, lat: 4, lon: 10);
  k.body.torus(0, 0.7, 0.0, 0.11, 0.026, rib, basis: ChibiBasis.facing(0, 1, 0), segments: 12, tube: 4);
  k.body.frustum(
      0, 0.4, 0, 0, 0.36, 0, _wrapRadius(torso, hips, 0.4, 0.012).$1, _wrapRadius(torso, hips, 0.36, 0.014).$1, rib,
      radial: 14, ovalZ: torso.rz / torso.rx, capA: false, capB: false);
  k.body.frustum(0, 0.37, 0, 0, 0.225, 0, 0.192, 0.262, skirt,
      pleats: 11, pleatDepth: 0.07, ovalZ: 0.9, capA: false, capB: false);

  // Đầu: lông xám xanh, vằn chữ M + vằn má, mõm trắng, mũi hồng, tai nhọn lòng hồng, kính tròn mảnh, búi thấp nhỏ.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  _snout(k, const ChibiSurface(0, 0.884, 0.17, 0.13, 0.08, 0.092), white, nose,
      noseEl: 26, noseW: 0.026, noseH: 0.018, mouthEl: -14);
  for (final (az, rot, len) in const [(-13.0, 0.25, 0.042), (0.0, 0.0, 0.048), (13.0, -0.25, 0.042)]) {
    final (x, y, z, b) = head.at(az, 36, lift: -0.002);
    k.head.dome(x, y, z, 0.011, len, 0.004, stripe, basis: b.then(ChibiBasis.euler(0, 0, rot)), segments: 8);
  }
  for (final side in const [1.0, -1.0]) {
    for (final (el, rot) in const [(4.0, 0.15), (-10.0, -0.1)]) {
      final (x, y, z, b) = head.at(side * 72, el, lift: -0.002);
      k.head.dome(x, y, z, 0.046, 0.011, 0.004, stripe, basis: b.then(ChibiBasis.euler(0, 0, side * rot)), segments: 8);
    }
    _pointEar(k.head, side * 0.15, 1.12, -0.02, side * 0.235, 1.37, -0.04, 0.09, fur, innerEar);
  }
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3);
  // Kính tròn gọng mảnh (~30% độ dày cũ), vòng vừa ôm mắt, nằm trong mặt.
  // Kính tròn gọng mảnh nằm NGOÀI vòng mắt (vòng 3: không đè lên mắt).
  _roundGlasses(k, head, 23, -3, 0.084, 0.0026, frame, lift: 0.024, templeAz: 72);
  _cheeks(k, head, 46, -19, w: 0.042);
  k.head.sphere(0, 0.88, -0.255, 0.085, bunC, lat: 6, lon: 10);
  k.head.torus(0, 0.885, -0.262, 0.07, 0.005, silver,
      basis: ChibiBasis.facing(0, 0.15, -1), a0: 0.5, a1: 2.4, segments: 7, tube: 3);

  // Đuôi mướp (bộ phận phụ): khúc xám xanh xen vằn.
  _tailChain(k.extra, const [(0.0, 0.36, -0.15), (0.0, 0.31, -0.26), (0.02, 0.37, -0.36), (0.03, 0.49, -0.39)],
      const [0.05, 0.05, 0.047], const [fur, stripe, fur],
      lat: 5, lon: 8);

  // Tay: tay áo len bạc hà + bo tay, bàn tay lông.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: sweater, hand: fur, cuff: rib, rTop: 0.066, rWrist: 0.056, rHand: 0.055);
  }

  // Chân: tất lông dưới váy + giày nâu tròn.
  _legs(k, leg: fur, shoe: shoe);

  // Bìa kẹp hồ sơ nhỏ ôm trước ngực bằng tay trái (khay đứng, mặt hướng ra trước, đỉnh ngả về ngực).
  const h = ChibiHold(side: 1, forward: 1.02, raise: -0.45);
  final f = _PropFrame(h);
  final (bx, by, bz) = f.at(-0.03, 0.07, 0.025);
  final bb = ChibiBasis.euler(-0.32, 0.12, 0.0);
  k.prop.box(bx, by, bz, 0.13, 0.17, 0.012, board, basis: bb);
  (double, double, double) on(double lx, double ly, double lz) => (
        bx + bb.xx * lx + bb.yx * ly + bb.zx * lz,
        by + bb.xy * lx + bb.yy * ly + bb.zy * lz,
        bz + bb.xz * lx + bb.yz * ly + bb.zz * lz
      );
  final (qx, qy, qz) = on(0, -0.008, 0.008);
  k.prop.box(qx, qy, qz, 0.11, 0.14, 0.004, paper, basis: bb);
  for (final ly in const [0.03, 0.0, -0.03]) {
    final (lx, lyy, lz) = on(0, ly, 0.011);
    k.prop.box(lx, lyy, lz, 0.08, 0.006, 0.002, line, basis: bb);
  }
  final (cx, cy, cz) = on(0, 0.078, 0.01);
  k.prop.box(cx, cy, cz, 0.054, 0.024, 0.016, clip, basis: bb);

  return k.build(
    ChibiCharacters.hanh,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 0.36, extraZ: -0.15),
    gait: const ChibiGait(speed: 0.82, legSwing: 0.36, armSwing: 0.42, stride: 0.42, waddle: 0.06, bob: 0.025),
    extraKind: ChibiExtraKind.tail,
    hold: f.hold,
    crownY: head.cy + head.ry,
  );
}

// ---- Nora: bộ đồ lễ hội --------------------------------------------------------------------------------------------

/// Bộ đồ lễ hội của Nora: cardigan bạc hà mở vạt, cổ sen trắng, váy yếm kem thêu lá phong, váy ngắn xoè xếp ly, tất
/// kem, giày lười nâu; hai tay cầm túi bánh giấy trước bụng (không cam trên cam). Trả về đồ cầm tay.
ChibiHold _noraFestOutfit(_Sketch k, ChibiSurface torso, ChibiSurface hips, int fur) {
  const cardigan = 0x9FD6C2;
  const cardiganDark = 0x84C2AC;
  const collar = 0xFFFFFF;
  const pinafore = 0xF6E4C8;
  const leafO = 0xE0782E;
  const leafY = 0xF0B84A;
  const socks = 0xF6EEDC;
  const loafer = 0x8A5A3C;
  const bag = 0xD9B98C;
  const bagFold = 0xC4A272;

  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, pinafore, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, pinafore, lat: 4, lon: 10);
  const rows = [
    (0.37, 0.62, 0.016),
    (0.44, 0.62, 0.012),
    (0.52, 0.64, 0.011),
    (0.58, 0.68, 0.01),
    (0.63, 0.74, 0.01),
    (0.668, 0.84, 0.009),
  ];
  _openJacket(k, torso, hips, rows, cardigan);
  _jacketEdges(k, torso, hips, rows, 0.009, cardiganDark);
  for (final y in const [0.42, 0.49, 0.56]) {
    final (x, py, z, _) = _wrapPoint(torso, hips, 0.66, y, 0.014, 0.006);
    k.body.sphere(x, py, z, 0.01, collar, lat: 2, lon: 5);
  }
  // Cổ sen trắng hai cánh tròn.
  for (final side in const [1.0, -1.0]) {
    k.body.ellipsoid(side * 0.052, 0.682, 0.112, 0.055, 0.03, 0.012, collar,
        basis: ChibiBasis.euler(-1.0, 0, -side * 0.25), lat: 3, lon: 8);
  }
  // Lá phong thêu trên yếm.
  for (final (a, y, s, c) in const [
    (-0.18, 0.6, 0.026, leafO),
    (0.14, 0.62, 0.022, leafY),
    (0.0, 0.55, 0.024, leafO),
  ]) {
    final (x, py, z, b) = _wrapPoint(torso, hips, a, y, 0.0, 0.004);
    k.body.star(x, py, z, s, s * 0.5, 0.003, c, basis: b.then(ChibiBasis.euler(0, 0, a * 3 + 0.3)));
  }
  k.body.frustum(0, 0.37, 0, 0, 0.225, 0, 0.192, 0.262, pinafore,
      pleats: 10, pleatDepth: 0.06, ovalZ: 0.92, capA: false, capB: false);

  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: cardigan, hand: fur, cuff: cardiganDark, rTop: 0.066, rWrist: 0.055, rHand: 0.054);
  }
  _legs(k, leg: socks, shoe: loafer);

  // Túi bánh giấy, hai tay cầm.
  const h = ChibiHold(twoHands: true, forward: 0.78, raise: -0.24);
  final f = _PropFrame(h);
  final (sx, sy, sz) = f.span;
  final (bx, by, bz) = f.at(sx / 2, sy / 2 + 0.035, sz / 2 + 0.045);
  k.prop.box(bx, by, bz, 0.12, 0.15, 0.075, bag);
  k.prop.box(bx, by + 0.088, bz, 0.124, 0.03, 0.05, bagFold);
  return f.hold;
}

/// Băng đô mù tạt qua đỉnh đầu (trước hai tai) + nơ nhỏ và lá phong cam bên phải.
void _noraFestHeadband(_Sketch k, ChibiSurface head) {
  const band = 0xF49AB0;
  const leaf = 0xE0782E;
  // Vòng cung đứng, ngả về trước một chút: đỉnh vòng nằm trước chân hai tai.
  final b = ChibiBasis.euler(0.12, 0, 0);
  k.head.torus(0, 0.958, 0.035, 0.262, 0.016, band,
      basis: b, a0: 0.1, a1: math.pi - 0.1, segments: 14, tube: 4, tubeScaleZ: 1.6);
  final (lx, ly, lz, lb) = head.at(-38, 40, lift: 0.03);
  k.head.star(lx, ly, lz, 0.04, 0.02, 0.006, leaf, basis: lb.then(ChibiBasis.euler(0, 0, 0.3)));
  for (final side in const [1.0, -1.0]) {
    k.head.ellipsoid(lx + side * 0.03 + 0.04, ly + 0.02, lz - 0.01, 0.026, 0.017, 0.01, band,
        basis: lb.then(ChibiBasis.euler(0, 0, side * 0.3)), lat: 2, lon: 6);
  }
}
