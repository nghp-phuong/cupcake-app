part of 'chibi_characters.dart';

// Khách quen / VIP (docs/v3/character-3d-procedural.md, bảng "Quyết định 03/11"): Kenji (gấu trúc đỏ), bà Rosa
// (mèo Ba Tư, VIP), quý ông hươu (VIP), quý cô cừu non (VIP), mèo Mochi (đi bốn chân). Màu / đặc điểm theo ảnh 2D
// `assets/characters/<id>_neutral.webp`.

// ---- Kenji (gấu trúc đỏ) -----------------------------------------------------------------------------------------

/// Kenji: gấu trúc đỏ nhiếp ảnh gia — bản cute 03/11 (vòng 3): lông cam đào, mặt nạ trắng (mõm, má, chấm trên mắt), vệt "nước
/// mắt" nhỏ, tai viền trắng, mũ bucket be nhỏ vành bo tròn, không kính; áo
/// thun trắng, áo khoác ngắn xô thơm–be mở vạt có túi, quần be, giày vải nâu đế trắng; tay cam đỏ sáng; hai tay cầm máy
/// ảnh film nhỏ; đuôi khoanh đỏ–nâu. Bỏ khuyên, đồng hồ.
ChibiModel _kenji() {
  // Cam đào (giảm bão hoà, hợp tông pastel).
  const fur = 0xEC9C78;
  const furDark = 0xF4AE88;
  const ring = 0xC27A5E;
  const mask = 0xFFF6EC;
  const nose = 0x2A1E1C;
  const hat = 0xE6D7B8;
  const hatBand = 0xCDB994;
  const jacket = 0xC3CB9E;
  const jacketDark = 0xA9B384;
  const tee = 0xFBF7EE;
  const jeans = 0xE2D2B2;
  const shoe = 0x8A604A;
  const sole = 0xF6F2EA;
  const camBody = 0x3A3638;
  const camSilver = 0xCFD2D6;
  const lens = 0x161515;
  const glass = 0x5A6A7A;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.29, 0.255, 0.252);
  const torso = ChibiSurface(0, 0.49, 0, 0.198, 0.24, 0.168);
  const hips = ChibiSurface(0, 0.36, 0, 0.19, 0.1, 0.16);

  // Thân: áo thun trắng, jean, áo khoác olive mở vạt (dài tới hông), cổ áo, túi ngực + túi hông.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, tee, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, jeans, lat: 4, lon: 10);
  const rows = [
    (0.36, 0.3, 0.016),
    (0.41, 0.3, 0.012),
    (0.47, 0.32, 0.011),
    (0.55, 0.37, 0.01),
    (0.61, 0.44, 0.01),
    (0.66, 0.56, 0.009),
  ];
  _openJacket(k, torso, hips, rows, jacket, segments: 12);
  _jacketEdges(k, torso, hips, [rows[0], rows[2], rows[3], rows[5]], 0.008, jacketDark);
  k.body.torus(0, 0.688, -0.012, 0.125, 0.03, jacketDark,
      basis: ChibiBasis.facing(0, 1, 0), a0: -0.45, a1: math.pi + 0.45, segments: 10, tube: 3, tubeScaleZ: 0.7);
  for (final side in const [1.0, -1.0]) {
    for (final (a, y, w, hh) in const [(0.75, 0.56, 0.05, 0.04), (0.82, 0.42, 0.052, 0.04)]) {
      final (x, py, z, b) = _wrapPoint(torso, hips, side * a, y, 0.012, 0.004);
      k.body.dome(x, py, z, w, hh, 0.005, jacketDark, basis: b, segments: 8);
      k.body.box(x, py + hh * 0.9, z, w * 2, 0.016, 0.01, jacketDark, basis: b);
    }
  }

  // Đầu: lông đỏ, mặt nạ trắng (mõm + hai má + chấm trên mắt), vệt nâu dưới mắt, mũi, ω.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  for (final side in const [1.0, -1.0]) {
    // Má trắng (vòm dán mặt, viền tròn gọn), chấm trắng trên mắt, vệt "nước mắt" nâu sẫm từ khoé mắt xuống mép mõm.
    final (x, y, z, b) = head.at(side * 44, -18, lift: -0.003);
    k.head.dome(x, y, z, 0.086, 0.078, 0.012, mask, basis: b, segments: 18);
    final (bx, by, bz, bb) = head.at(side * 22, 25, lift: -0.002);
    k.head.dome(bx, by, bz, 0.034, 0.024, 0.006, mask, basis: bb, segments: 10);
    final (tx, ty, tz, tb) = head.at(side * 27, -26, lift: 0.002);
    k.head
        .dome(tx, ty, tz, 0.013, 0.028, 0.004, ring, basis: tb.then(ChibiBasis.euler(0, 0, -side * 0.3)), segments: 8);
  }
  _snout(k, const ChibiSurface(0, 0.875, 0.17, 0.115, 0.075, 0.09), mask, nose,
      noseEl: 24, noseW: 0.028, noseH: 0.019, mouthEl: -17, mouthR: 0.0075, mouthTube: 0.0034);
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3);
  _cheeks(k, head, 46, -21, w: 0.04);
  // Kính tròn gọng mảnh ôm ngoài mắt (không to hơn mắt nhiều, không che mắt).

  // Tai viền trắng nhô qua mũ; khuyên bạc tai trái.
  for (final side in const [1.0, -1.0]) {
    final b = ChibiBasis.facing(side * 0.5, 0.2, 1).then(ChibiBasis.euler(0, 0, -side * 0.25));
    k.head.ellipsoid(side * 0.215, 1.2, -0.03, 0.068, 0.078, 0.034, fur, basis: b, lat: 4, lon: 8);
    k.head.dome(side * 0.215 + b.zx * 0.03, 1.195 + b.zy * 0.03, -0.03 + b.zz * 0.03, 0.05, 0.058, 0.008, mask,
        basis: b, segments: 10);
  }

  // Mũ bucket be nhỏ (ngả ra sau, đội cao — không che mắt).
  final up = ChibiBasis.alongY(0, 1, -0.22);
  (double, double, double) hatAt(double ly) => (0, 1.11 + up.yy * ly, -0.03 + up.yz * ly);
  final c0 = hatAt(0.02), c1 = hatAt(0.15), b0 = hatAt(0.03), b1 = hatAt(-0.022);
  k.head.frustum(c0.$1, c0.$2, c0.$3, c1.$1, c1.$2, c1.$3, 0.24, 0.19, hat, radial: 13, capA: false);
  k.head.frustum(b0.$1, b0.$2, b0.$3, b1.$1, b1.$2, b1.$3, 0.24, 0.3, hat, radial: 16, capA: false, capB: false);
  // Mép vành bo tròn (xuyến mảnh) — hết cạnh sắc.
  k.head.torus(b1.$1, b1.$2, b1.$3, 0.3, 0.008, hat,
      basis: ChibiBasis.facing(up.yx, up.yy, up.yz), segments: 16, tube: 3);
  final band0 = hatAt(0.035), band1 = hatAt(0.065);
  k.head.frustum(band0.$1, band0.$2, band0.$3, band1.$1, band1.$2, band1.$3, 0.24, 0.232, hatBand,
      radial: 11, capA: false, capB: false);
  // Đuôi khoanh đỏ–nâu (bộ phận phụ, gắn thân).
  _tailChain(
      k.extra,
      const [(0.0, 0.33, -0.15), (0.0, 0.34, -0.26), (0.01, 0.43, -0.36), (0.02, 0.56, -0.4), (0.025, 0.68, -0.38)],
      const [0.07, 0.085, 0.08, 0.068],
      const [fur, ring, fur, ring],
      lat: 5,
      lon: 8,
      overlap: 0.66);

  // Tay: tay áo khoác + xắn gấu, bàn tay cam đỏ sáng.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: jacket, hand: furDark, cuff: jacketDark, rTop: 0.065, rWrist: 0.055, rHand: 0.055);
  }
  // Chân: quần be, giày vải nâu đế trắng + mũi trắng.
  for (final side in const [1.0, -1.0]) {
    final b = k.leg(side);
    final x = side * _legX;
    b.capsule(x, 0.1, 0, x, _hipY + 0.03, 0, 0.074, 0.08, jeans, radial: 7, capBands: 1);
    b.ellipsoid(x, 0.058, 0.035, 0.086, 0.06, 0.112, shoe, lat: 4, lon: 9);
    b.ellipsoid(x, 0.02, 0.035, 0.088, 0.02, 0.114, sole, lat: 2, lon: 9);
    b.ellipsoid(x, 0.036, 0.118, 0.054, 0.032, 0.036, sole, lat: 3, lon: 6);
  }

  // Máy ảnh film hai tay cầm ngang bụng (làm việc = giơ lên ngang mắt).
  const h = ChibiHold(twoHands: true, forward: 0.8, raise: -0.24, workForward: 2.45);
  final f = _PropFrame(h);
  final (sx, sy, sz) = f.span;
  // Máy ảnh nhỏ đi 25%.
  final (cx, cy, cz) = f.at(sx / 2, sy / 2 + 0.02, sz / 2 + 0.03);
  k.prop.box(cx, cy, cz, 0.12, 0.068, 0.053, camBody);
  k.prop.box(cx, cy + 0.039, cz, 0.12, 0.012, 0.053, camSilver);
  k.prop.box(cx - 0.026, cy + 0.054, cz, 0.038, 0.021, 0.038, camSilver);
  k.prop.frustum(cx + 0.009, cy - 0.003, cz + 0.026, cx + 0.009, cy - 0.003, cz + 0.064, 0.026, 0.023, camSilver,
      radial: 12, capA: false);
  k.prop.frustum(cx + 0.009, cy - 0.003, cz + 0.045, cx + 0.009, cy - 0.003, cz + 0.066, 0.023, 0.023, lens,
      radial: 12, capA: false);
  k.prop.ellipsoid(cx + 0.009, cy - 0.003, cz + 0.067, 0.017, 0.017, 0.003, glass, lat: 2, lon: 10);
  k.prop.sphere(cx + 0.045, cy + 0.053, cz, 0.009, camSilver, lat: 2, lon: 6);

  return k.build(
    ChibiCharacters.kenji,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 0.34, extraZ: -0.15),
    gait: const ChibiGait(speed: 0.88, legSwing: 0.45, armSwing: 0.5, stride: 0.5, waddle: 0.06, bob: 0.03),
    extraKind: ChibiExtraKind.tail,
    hold: f.hold,
    crownY: head.cy + head.ry,
  );
}

// ---- Bà Rosa (mèo Ba Tư, VIP) ------------------------------------------------------------------------------------

/// Bà Rosa (vip_00): mèo Ba Tư trắng — bản cute 03/11: mặt tròn phẳng, má lông xù, mũi hồng nhỏ, mắt tròn đối xứng có mi
/// trên mảnh, tai nhỏ; búi = một cục tròn kem bạc nhỏ trên đỉnh + một chiếc trâm vàng; áo khoác ngắn hồng mận nhạt viền
/// vàng (VIP), áo kem, một chuỗi ngọc; váy ngắn xoè kem có hoa nhỏ, giày lười nâu; đuôi xù; đi chậm, dáng thanh lịch.
ChibiModel _rosa() {
  const fur = 0xF7F3EF;
  const bunC = 0xEDE6E2;
  const bunShade = 0xDCD3D0;
  const nose = 0xEC9EAA;
  const innerEar = 0xF6C6CE;
  const gold = 0xE0B24A;
  const coat = 0xE6A9C2;
  const blouse = 0xFFF4E6;
  const pearl = 0xFDF9F2;
  const skirt = 0xFBEEDD;
  const floralPink = 0xF0A6B4;
  const floralGreen = 0xA9CDB2;
  const loafer = 0x8A5A3C;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.958, 0, 0.298, 0.25, 0.25);
  const torso = ChibiSurface(0, 0.49, 0, 0.196, 0.24, 0.166);
  const hips = ChibiSurface(0, 0.36, 0, 0.19, 0.1, 0.158);

  // Thân: áo kem, áo khoác ngắn hồng mận nhạt mở chữ V viền vàng (vạt tới giữa bụng), một chuỗi ngọc, váy ngắn xoè.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, blouse, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, skirt, lat: 4, lon: 10);
  const rows = [(0.45, 0.3, 0.014), (0.5, 0.32, 0.011), (0.555, 0.38, 0.01), (0.605, 0.48, 0.01), (0.65, 0.62, 0.009)];
  _openJacket(k, torso, hips, rows, coat, segments: 12);
  _jacketEdges(k, torso, hips, rows, 0.0075, gold, lift: 0.005);
  _openJacket(k, torso, hips, const [(0.445, 0.3, 0.017), (0.462, 0.3, 0.016)], gold);
  _beads(k, torso, hips, 9, 0.9, 0.64, 0.035, 0.0135, pearl);
  const top = 0.37, bottom = 0.225, rTop = 0.192, rBottom = 0.27;
  k.body.frustum(0, top, 0, 0, bottom, 0, rTop, rBottom, skirt, radial: 16, ovalZ: 0.92, capA: false, capB: false);
  // Gấu váy bo tròn (xuyến dẹt) — hết mép cắt sắc.
  k.body.torus(0, bottom + 0.004, 0, rBottom * 0.97, 0.009, skirt,
      basis: ChibiBasis.facing(0, 1, 0), segments: 14, tube: 3, tubeScaleZ: 1);
  for (final (a, y, c) in const [
    (0.3, 0.3, floralPink),
    (-0.4, 0.26, floralPink),
    (0.9, 0.25, floralGreen),
    (-0.05, 0.25, floralGreen),
    (-1.0, 0.31, floralPink),
    (1.25, 0.3, floralGreen),
  ]) {
    final r = rTop + (top - y) / (top - bottom) * (rBottom - rTop);
    final nx = math.sin(a), nz = math.cos(a) * 0.92;
    k.body.dome(r * nx + nx * 0.003, y, r * nz + nz * 0.003, 0.018, 0.016, 0.003, c,
        basis: ChibiBasis.facing(nx, 0.1, nz), segments: 6);
  }

  // Đầu: mặt tròn phẳng, má lông xù hai bên, mõm phồng nhỏ, mũi hồng, ω, má hồng, mắt tròn + mi mảnh, tai nhỏ.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  for (final side in const [1.0, -1.0]) {
    for (final (az, el, r) in const [(72.0, -18.0, 0.078), (60.0, -33.0, 0.066)]) {
      final (x, y, z, b) = head.at(side * az, el, lift: -0.035);
      k.head.ellipsoid(x, y, z, r, r * 0.85, r * 0.8, fur, basis: b, lat: 5, lon: 9);
    }
    final (mx, my, mz, mb) = head.at(side * 9, -21, lift: -0.018);
    k.head.ellipsoid(mx, my, mz, 0.042, 0.034, 0.03, fur, basis: mb, lat: 3, lon: 7);
  }
  final (nx, ny, nz, nb) = head.at(0, -12, lift: 0.006);
  k.head.ellipsoid(nx, ny, nz, 0.024, 0.017, 0.013, nose, basis: nb, lat: 3, lon: 6);
  _omega(k, head, -21, r: 0.011);
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3, w: 0.046, h: 0.054);
  _lashes(k, head, 23, -3, w: 0.046, h: 0.054, color: 0x6A5450);
  _cheeks(k, head, 43, -18);
  for (final side in const [1.0, -1.0]) {
    _pointEar(k.head, side * 0.18, 1.1, -0.01, side * 0.27, 1.27, -0.03, 0.08, fur, innerEar, flat: 0.5);
  }
  // Búi: một cục tròn kem bạc nhỏ trên đỉnh, sau chân tai; một chiếc trâm vàng cài chéo.
  k.head.sphere(0, 1.25, -0.07, 0.1, bunC, lat: 7, lon: 12);
  k.head.ellipsoid(0, 1.2, -0.06, 0.12, 0.035, 0.11, bunShade, lat: 3, lon: 10);
  k.head.capsule(-0.13, 1.3, -0.02, 0.06, 1.25, -0.12, 0.007, 0.007, gold, radial: 5, capBands: 1);
  k.head.star(-0.135, 1.302, -0.018, 0.024, 0.011, 0.008, gold, basis: ChibiBasis.facing(-0.6, 0.3, 0.75));

  // Đuôi Ba Tư xù (bộ phận phụ, gắn thân): trắng, chóp kem bạc.
  _tailChain(k.extra, const [(0.0, 0.36, -0.15), (0.0, 0.3, -0.27), (0.02, 0.36, -0.38), (0.03, 0.48, -0.42)],
      const [0.074, 0.084, 0.078], const [fur, fur, bunC],
      lat: 5, lon: 8);

  // Tay: tay áo khoác + cổ tay áo kem, bàn tay trắng.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: coat, hand: fur, cuff: blouse, rTop: 0.066, rWrist: 0.056, rHand: 0.055);
  }
  _legs(k, leg: fur, shoe: loafer);

  return k.build(
    ChibiCharacters.rosa,
    ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ, extraX: 0, extraY: 0.36, extraZ: -0.15),
    gait: const ChibiGait(speed: 0.62, legSwing: 0.3, armSwing: 0.28, stride: 0.36, waddle: 0.05, bob: 0.016),
    extraKind: ChibiExtraKind.tail,
    radius: 0.29,
    crownY: head.cy + head.ry,
  );
}

// ---- Quý ông hươu (VIP) ------------------------------------------------------------------------------------------

/// vip_01: hươu sao quý ông — bản cute 03/11: lông nâu ấm có chấm trắng (hươu sao), mõm kem tròn, mũi to tròn, tai lá
/// ngang lòng hồng, gạc ngắn (~40% đầu) chóp tròn, mắt to; áo khoác ngắn bạc hà cài một cúc + ghim sao vàng (VIP), sơ mi
/// kem, quần caramel nhạt, giày nâu. Bỏ lông mày, ria, kính, lông vuốt sẫm, đồng hồ.
ChibiModel _stag() {
  const fur = 0xB57A50;
  const light = 0xF2DEC2;
  const spot = 0xFFF4E4;
  const nose = 0x4A3228;
  const innerEar = 0xF4CABA;
  const antler = 0xEEDCB4;
  const antlerTip = 0xFAF1DC;
  const gold = 0xE0B24A;
  const coat = 0x92CFB6;
  const coatEdge = 0x7CBDA2;
  const shirt = 0xFFF6EA;
  const trousers = 0xDDB88E;
  const shoe = 0x8A5A3C;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.962, 0, 0.275, 0.255, 0.258);
  const torso = ChibiSurface(0, 0.49, 0, 0.19, 0.242, 0.162);
  const hips = ChibiSurface(0, 0.36, 0, 0.182, 0.1, 0.152);

  // Thân: sơ mi kem, quần caramel nhạt, áo khoác ngắn bạc hà (vạt tới giữa bụng, mở chữ V nhỏ), cúc + ghim sao vàng.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, shirt, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, trousers, lat: 4, lon: 10);
  const rows = [(0.43, 0.08, 0.014), (0.48, 0.08, 0.011), (0.54, 0.16, 0.01), (0.6, 0.32, 0.01), (0.655, 0.52, 0.009)];
  _openJacket(k, torso, hips, rows, coat);
  _jacketEdges(k, torso, hips, rows, 0.007, coatEdge);
  _openJacket(k, torso, hips, const [(0.425, 0.08, 0.017), (0.445, 0.08, 0.016)], coatEdge);
  final (bx0, by0, bz0, _) = _wrapPoint(torso, hips, 0.0, 0.5, 0.014, 0.006);
  k.body.sphere(bx0, by0, bz0, 0.014, gold, lat: 3, lon: 6);
  final (gx, gy, gz, gb) = _wrapPoint(torso, hips, 0.5, 0.6, 0.014, 0.01);
  k.body.star(gx, gy, gz, 0.024, 0.011, 0.006, gold, basis: gb);

  // Đầu: lông nâu ấm + chấm trắng, mõm kem tròn, mũi to tròn, ω, mắt to, má hồng.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  const muzzle = ChibiSurface(0, 0.876, 0.18, 0.118, 0.082, 0.105);
  _snout(k, muzzle, light, nose,
      noseEl: 26, noseW: 0.033, noseH: 0.022, mouthEl: -15, mouthR: 0.0078, mouthTube: 0.0036);
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -2, w: 0.044, h: 0.059);
  _cheeks(k, head, 46, -15, w: 0.042);
  for (final (az, el, r) in const [
    (58.0, 34.0, 0.017),
    (72.0, 18.0, 0.015),
    (-60.0, 30.0, 0.016),
    (-74.0, 14.0, 0.015),
    (40.0, 52.0, 0.014),
    (-38.0, 54.0, 0.014),
    (0.0, 62.0, 0.015),
    (150.0, 30.0, 0.017),
    (-150.0, 32.0, 0.017),
  ]) {
    final (x, y, z, b) = head.at(az, el, lift: -0.002);
    k.head.dome(x, y, z, r, r, 0.004, spot, basis: b, segments: 8);
  }
  // Tai lá chĩa ngang, lòng tai hồng.
  for (final side in const [1.0, -1.0]) {
    final b = ChibiBasis.facing(side * 0.25, 0.25, 1).then(ChibiBasis.euler(0, 0, side * 0.3));
    k.head.ellipsoid(side * 0.3, 1.06, -0.02, 0.115, 0.054, 0.032, fur, basis: b, lat: 5, lon: 9);
    k.head.dome(side * 0.3 + b.zx * 0.028, 1.06 + b.zy * 0.028, -0.02 + b.zz * 0.028, 0.082, 0.034, 0.006, innerEar,
        basis: b, segments: 10);
  }
  // Gạc ngắn (~40% đầu): nhánh chính mập + một nhánh phụ, chóp tròn.
  for (final side in const [1.0, -1.0]) {
    final a = (side * 0.1, 1.17, -0.04), b = (side * 0.16, 1.33, -0.06);
    k.head.capsule(a.$1, a.$2, a.$3, b.$1, b.$2, b.$3, 0.03, 0.024, antler, radial: 7, capBands: 2);
    k.head.sphere(b.$1, b.$2, b.$3, 0.03, antlerTip, lat: 4, lon: 7);
    final px = a.$1 + (b.$1 - a.$1) * 0.5, py = a.$2 + (b.$2 - a.$2) * 0.5, pz = a.$3 + (b.$3 - a.$3) * 0.5;
    k.head.capsule(px, py, pz, px + side * 0.06, py + 0.05, pz + 0.02, 0.02, 0.018, antler, radial: 6, capBands: 1);
    k.head.sphere(px + side * 0.06, py + 0.05, pz + 0.02, 0.022, antlerTip, lat: 3, lon: 6);
  }

  // Tay: tay áo khoác + cổ tay sơ mi kem, bàn tay nâu.
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: coat, hand: fur, cuff: shirt, rTop: 0.066, rWrist: 0.056, rHand: 0.055);
  }
  _legs(k, leg: trousers, shoe: shoe);

  return k.build(ChibiCharacters.stag, ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ),
      gait: const ChibiGait(speed: 0.78, legSwing: 0.38, armSwing: 0.35, stride: 0.46, waddle: 0.04, bob: 0.02),
      scale: 1.18,
      crownY: head.cy + head.ry);
}

// ---- Quý cô cừu non (VIP) ----------------------------------------------------------------------------------------

/// vip_02: cừu non quý cô — bản cute 03/11: mặt kem, lông xoăn = đám mây tròn màu caramel sáng (mái + quanh đầu), tai cụp
/// ngang lòng hồng; mũ nhỏ (~30% cũ) kem gắn hoa nhỏ đội trên đỉnh đầu (lộ mắt); áo choàng ngắn hồng đào có khuy vàng,
/// váy ngắn xoè kem, tất trắng, giày búp bê nâu. Bỏ găng, khuyên.
ChibiModel _lamb() {
  const face = 0xF9ECDF;
  const wool = 0xC98E66;
  const woolHi = 0xDAA47C;
  const innerEar = 0xF4BAC2;
  const nose = 0xE095A0;
  const hat = 0xF7ECD8;
  const hatBand = 0xF2A7B0;
  const petalPink = 0xF4A7B9;
  const petalPeach = 0xF7C59F;
  const petalCenter = 0xFFD27A;
  const cape = 0xF4AFAA;
  const capeDark = 0xE69890;
  const gold = 0xE0B24A;
  const dress = 0xFBF1E4;
  const sock = 0xFFFFFF;
  const shoe = 0x9A6040;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.958, 0, 0.272, 0.252, 0.246);
  const torso = ChibiSurface(0, 0.49, 0, 0.19, 0.238, 0.162);
  const hips = ChibiSurface(0, 0.36, 0, 0.182, 0.1, 0.152);

  // Thân: thân váy kem + chân váy ngắn xoè xếp mềm; áo choàng ngắn hồng đào phủ vai, khuy vàng + nơ nhỏ.
  k.body.ellipsoid(torso.cx, torso.cy, torso.cz, torso.rx, torso.ry, torso.rz, dress, lat: 7, lon: 10);
  k.body.ellipsoid(hips.cx, hips.cy, hips.cz, hips.rx, hips.ry, hips.rz, dress, lat: 4, lon: 10);
  k.body.frustum(0, 0.38, 0, 0, 0.23, 0, 0.186, 0.285, dress,
      pleats: 14, pleatDepth: 0.035, ovalZ: 0.9, capA: false, capB: false);
  k.body.shell(
      0,
      0,
      [
        for (final (y, rx, rz) in const [
          (0.715, 0.1, 0.09),
          (0.69, 0.17, 0.15),
          (0.645, 0.235, 0.19),
          (0.59, 0.262, 0.205),
          (0.53, 0.272, 0.212),
          (0.5, 0.276, 0.215),
        ])
          (y, rx, rz, 0.16, 2 * math.pi - 0.16),
      ],
      cape,
      segments: 11);
  k.body.torus(0, 0.715, 0.0, 0.1, 0.016, capeDark, basis: ChibiBasis.facing(0, 1, 0), segments: 10, tube: 3);
  k.body.sphere(0, 0.68, 0.15, 0.017, gold, lat: 3, lon: 5);
  for (final side in const [1.0, -1.0]) {
    k.body.ellipsoid(side * 0.03, 0.68, 0.15, 0.028, 0.017, 0.01, gold,
        basis: ChibiBasis.euler(-0.4, 0, side * 0.2), lat: 3, lon: 5);
  }

  // Đầu: mặt kem, mõm phồng nhẹ, mũi hồng, ω, mắt, má; tai cụp ngang; lông xoăn đám mây (mái + quanh đầu + sau gáy);
  // mũ nhỏ trên đỉnh, dải băng + hoa nhỏ.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, face, lat: 10, lon: 16);
  _snout(k, const ChibiSurface(0, 0.884, 0.168, 0.1, 0.07, 0.085), face, nose,
      noseEl: 22, noseW: 0.026, noseH: 0.017, mouthEl: -16, mouthR: 0.011);
  final (eyeY, eyeZ) = _eyesOn(k, head, 23, -3);
  _cheeks(k, head, 43, -18);
  for (final side in const [1.0, -1.0]) {
    final b = ChibiBasis.facing(side * 0.2, 0.1, 1).then(ChibiBasis.euler(0, 0, -side * 0.38));
    k.head.ellipsoid(side * 0.315, 0.98, 0.02, 0.105, 0.048, 0.034, face, basis: b, lat: 5, lon: 9);
    k.head.dome(side * 0.315 + b.zx * 0.03, 0.98 + b.zy * 0.03, 0.02 + b.zz * 0.03, 0.074, 0.03, 0.006, innerEar,
        basis: b, segments: 10);
  }
  // Mây lông xoăn: mái tròn trên trán + vòng cụm quanh đỉnh / hai bên đầu + sau gáy (không buông dài như tóc).
  for (final (az, el, r) in const [
    (-34.0, 30.0, 0.066),
    (-12.0, 36.0, 0.07),
    (12.0, 36.0, 0.07),
    (34.0, 30.0, 0.066),
    (-54.0, 42.0, 0.07),
    (54.0, 42.0, 0.07),
    (-110.0, 30.0, 0.074),
    (110.0, 30.0, 0.074),
    (180.0, 30.0, 0.084),
    (-145.0, 40.0, 0.08),
    (145.0, 40.0, 0.08),
  ]) {
    final (x, y, z, _) = head.at(az, el, lift: -0.026);
    k.head.sphere(x, y, z, r, (az.abs() > 60 && az.abs() < 120) || el > 50 ? woolHi : wool, lat: 5, lon: 9);
  }
  final hb = ChibiBasis.euler(-0.12, 0, 0.12);
  (double, double, double) hatAt(double lx, double ly, double lz) => (
        0.02 + hb.xx * lx + hb.yx * ly + hb.zx * lz,
        1.215 + hb.xy * lx + hb.yy * ly + hb.zy * lz,
        -0.03 + hb.xz * lx + hb.yz * ly + hb.zz * lz
      );
  final (h0x, h0y, h0z) = hatAt(0, 0, 0);
  k.head.ellipsoid(h0x, h0y, h0z, 0.24, 0.014, 0.23, hat, basis: hb, lat: 3, lon: 16);
  final (h1x, h1y, h1z) = hatAt(0, 0.05, 0);
  k.head.ellipsoid(h1x, h1y, h1z, 0.15, 0.08, 0.145, hat, basis: hb, lat: 4, lon: 11);
  final (bnx, bny, bnz) = hatAt(0, 0.01, 0);
  final (bmx, bmy, bmz) = hatAt(0, 0.04, 0);
  k.head.frustum(bnx, bny, bnz, bmx, bmy, bmz, 0.151, 0.143, hatBand, radial: 14, capA: false, capB: false);
  for (final (a, y, c) in const [(0.55, 0.03, petalPink), (0.95, 0.032, petalPeach), (0.2, 0.032, petalPeach)]) {
    final (fx, fy, fz) = hatAt(0.152 * math.sin(a), y, 0.146 * math.cos(a));
    final fb = hb.then(ChibiBasis.facing(math.sin(a), 0.2, math.cos(a)));
    k.head.star(fx, fy, fz, 0.03, 0.018, 0.008, c, basis: fb);
    k.head.sphere(fx + fb.zx * 0.006, fy + fb.zy * 0.006, fz + fb.zz * 0.006, 0.009, petalCenter, lat: 2, lon: 5);
  }

  // Tay: tay áo kem ngắn dưới áo choàng, bàn tay kem (không găng).
  for (final side in const [1.0, -1.0]) {
    _arm(k, side, sleeve: dress, hand: face, cuff: capeDark, rTop: 0.064, rWrist: 0.054, rHand: 0.055);
  }
  _legs(k, leg: sock, shoe: shoe);

  return k.build(ChibiCharacters.lamb, ChibiRigSpec(eyeY: eyeY, eyeZ: eyeZ),
      gait: const ChibiGait(speed: 0.78, legSwing: 0.38, armSwing: 0.36, stride: 0.42, waddle: 0.065, bob: 0.025),
      radius: 0.3,
      crownY: head.cy + head.ry);
}

// ---- Mèo Mochi (bốn chân) ----------------------------------------------------------------------------------------

/// Mochi: mèo chibi thật đi bốn chân — lông kem, mảng caramel trên đầu / lưng / đùi, đuôi khoanh caramel dựng cao, mũi
/// hồng, ω, má hồng, vòng cổ đỏ có chuông vàng, ngực lông xù. Khung xương bốn chân ([ChibiRigSpec.quadruped]): hai
/// "tay" là chân trước, hai "chân" là chân sau; thân nằm ngang, khớp thân ở hông sau (ngồi = ngả thân lên). Dựng thẳng
/// theo mét (không phóng), dài ~0,45 m, chóp tai ~0,6 m.
ChibiModel _mochi() {
  const fur = 0xFDF4E6;
  const patch = 0xE3AA6A;
  const patchDark = 0xD39555;
  const innerEar = 0xF6BFC6;
  const nose = 0xEE9AA8;
  const collar = 0xE0606A;
  const bell = 0xF1C45A;
  const bellDark = 0x9A6A2A;
  const pad = 0xF2B4BE;

  const hipY = 0.16, hindZ = -0.12;
  const shoulderY = 0.17, shoulderZ = 0.11, shoulderX = 0.072, legX = 0.07;
  const neckY = 0.27, neckZ = 0.16;

  final k = _Sketch();
  const head = ChibiSurface(0, 0.39, 0.205, 0.172, 0.152, 0.152);

  // Thân: tròn mập nằm ngang, ngực lông xù, mảng caramel trên lưng.
  k.body.ellipsoid(0, 0.2, -0.005, 0.128, 0.112, 0.195, fur, lat: 8, lon: 12);
  k.body.ellipsoid(0, 0.215, 0.12, 0.1, 0.1, 0.07, fur, lat: 5, lon: 8);
  const bodyS = ChibiSurface(0, 0.2, -0.005, 0.128, 0.112, 0.195);
  for (final (az, el, rx, ry) in const [
    (160.0, 55.0, 0.09, 0.07),
    (200.0, 40.0, 0.07, 0.05),
    (110.0, 30.0, 0.06, 0.05),
  ]) {
    final (x, y, z, b) = bodyS.at(az, el, lift: -0.026);
    k.body.ellipsoid(x, y, z, rx, ry, 0.034, patch, basis: b, lat: 4, lon: 9);
  }
  // Vòng cổ đỏ + chuông vàng.
  k.body.torus(0, 0.275, 0.15, 0.085, 0.014, collar, basis: ChibiBasis.facing(0, 0.75, 0.66), segments: 14, tube: 4);
  k.body.sphere(0, 0.22, 0.215, 0.024, bell, lat: 4, lon: 8);
  k.body.box(0, 0.212, 0.238, 0.024, 0.004, 0.004, bellDark);

  // Đầu: to tròn, má phúng phính, mảng caramel hai bên đỉnh (bên trái to hơn), tai nhọn, mắt to, mũi hồng, ω.
  k.head.ellipsoid(head.cx, head.cy, head.cz, head.rx, head.ry, head.rz, fur, lat: 10, lon: 16);
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = head.at(side * 62, -22, lift: -0.03);
    k.head.ellipsoid(x, y, z, 0.07, 0.055, 0.05, fur, basis: b, lat: 4, lon: 9);
  }
  for (final (az, el, rx, ry) in const [(46.0, 40.0, 0.11, 0.08), (-48.0, 44.0, 0.08, 0.06), (0.0, 72.0, 0.06, 0.05)]) {
    final (x, y, z, b) = head.at(az, el, lift: -0.002);
    k.head.dome(x, y, z, rx, ry, 0.008, patch, basis: b, segments: 12);
  }
  for (final side in const [1.0, -1.0]) {
    _pointEar(k.head, side * 0.09, 0.5, 0.18, side * 0.15, 0.61, 0.165, 0.062, side > 0 ? patch : patchDark, innerEar,
        flat: 0.5);
  }
  final (nx, ny, nz, nb) = head.at(0, -12, lift: 0.004);
  k.head.ellipsoid(nx, ny, nz, 0.016, 0.011, 0.009, nose, basis: nb, lat: 3, lon: 6);
  for (final side in const [1.0, -1.0]) {
    final (mx, my, mz, mb) = head.at(side * 9, -21, lift: -0.014);
    k.head.ellipsoid(mx, my, mz, 0.027, 0.021, 0.019, fur, basis: mb, lat: 4, lon: 8);
  }
  _omega(k, head, -19, r: 0.0082, tube: 0.0033, color: 0x9A5A50);
  var eyeY = 0.0, eyeZ = 0.0;
  for (final side in const [1.0, -1.0]) {
    final (x, y, z, b) = head.at(side * 27, -2, lift: -0.001);
    _eye(k, x, y, z, b, w: 0.028, h: 0.036, d: 0.011);
    eyeY += y / 2;
    eyeZ += z / 2;
  }
  _cheeks(k, head, 46, -18, w: 0.03);

  // Chân trước: thẳng, bàn chân tròn (đệm hồng dưới).
  for (final side in const [1.0, -1.0]) {
    final b = k.arm(side);
    final x = side * shoulderX;
    b.capsule(x, shoulderY + 0.02, shoulderZ, x, 0.05, shoulderZ + 0.01, 0.042, 0.037, fur, radial: 7, capBands: 2);
    b.ellipsoid(x, 0.03, shoulderZ + 0.025, 0.045, 0.03, 0.054, fur, lat: 4, lon: 8);
    b.dome(x, 0.004, shoulderZ + 0.03, 0.025, 0.02, 0.003, pad, basis: ChibiBasis.facing(0, -1, 0), segments: 6);
  }
  // Chân sau: đùi tròn (mảng caramel bên trái) + cẳng chân + bàn chân.
  for (final side in const [1.0, -1.0]) {
    final b = k.leg(side);
    final x = side * legX;
    b.ellipsoid(x + side * 0.012, 0.15, hindZ - 0.005, 0.058, 0.08, 0.078, side > 0 ? patch : fur, lat: 5, lon: 8);
    b.capsule(x, 0.12, hindZ - 0.02, x, 0.05, hindZ + 0.0, 0.036, 0.034, fur, radial: 6, capBands: 1);
    b.ellipsoid(x, 0.03, hindZ + 0.015, 0.042, 0.03, 0.054, fur, lat: 4, lon: 8);
  }

  // Đuôi dựng cao, khoanh caramel, chóp cong.
  _tailChain(
      k.extra,
      const [(0.0, 0.25, -0.17), (0.0, 0.31, -0.23), (0.0, 0.41, -0.27), (0.0, 0.51, -0.27), (0.0, 0.58, -0.23)],
      const [0.042, 0.044, 0.044, 0.04],
      const [fur, patch, fur, patch],
      lat: 5,
      lon: 8,
      overlap: 0.7);

  return k.build(
    ChibiCharacters.mochi,
    ChibiRigSpec(
        hipY: hipY,
        legX: legX,
        neckY: neckY,
        shoulderX: shoulderX,
        shoulderY: shoulderY,
        eyeY: eyeY,
        eyeZ: eyeZ,
        extraX: 0,
        extraY: 0.25,
        extraZ: -0.17,
        seatDrop: 0,
        neckZ: neckZ,
        hindZ: hindZ,
        shoulderZ: shoulderZ,
        quadruped: true),
    gait: const ChibiGait(speed: 0.7, legSwing: 0.5, armSwing: 0.5, stride: 0.3, waddle: 0.025, bob: 0.01),
    extraKind: ChibiExtraKind.tail,
    scale: 1.0,
    radius: 0.2,
    reframe: false,
  );
}
