import 'dart:math' as math;
import 'dart:typed_data';

/// Lưới tam giác có **màu đỉnh** cho nhân vật chibi dựng bằng code — Dart thuần, không phụ thuộc engine.
///
/// Mỗi bộ phận nhân vật (đầu, thân, tay…) là MỘT lưới gộp từ nhiều khối tròn trịa (ellipsoid, capsule, trụ / nón,
/// xuyến, hộp, ngôi sao) mỗi khối một màu; màu nằm trong mảng màu đỉnh nên cả bộ phận chỉ cần một entity và một
/// material dùng chung (ubershader của Filament nhân `baseColor` với màu đỉnh). Mỗi khối có đỉnh riêng nên màu không
/// loang sang khối kề bên.
///
/// Toạ độ khi dựng: không gian "tư thế nghỉ" của nhân vật (mét, chân ở y = 0, mặt nhìn +z). [ChibiMeshBuilder.build]
/// trừ đi điểm xoay (pivot) của bộ phận → lưới nằm trong không gian cục bộ của khớp.
///
/// Quy ước tam giác như `Shop3dMesh`: ngược chiều kim đồng hồ nhìn từ phía pháp tuyến, pháp tuyến đơn vị; khối mượt
/// (pháp tuyến đỉnh) trừ hộp / nắp trụ / ngôi sao.
class ChibiMesh {
  ChibiMesh._(this.positions, this.normals, this.colors, this.indices, this.minX, this.minY, this.minZ, this.maxX,
      this.maxY, this.maxZ);

  /// x,y,z mỗi đỉnh (không gian cục bộ của khớp).
  final Float32List positions;

  /// Pháp tuyến đơn vị, 3 số mỗi đỉnh.
  final Float32List normals;

  /// Màu đỉnh RGBA **tuyến tính** (sRGB^2,2), 4 số mỗi đỉnh.
  final Float32List colors;

  /// 3 chỉ số mỗi tam giác.
  final Uint32List indices;

  /// Hộp bao cục bộ.
  final double minX, minY, minZ, maxX, maxY, maxZ;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  /// Bản phóng [sx], [sy], [sz] lần theo ba trục cục bộ (quanh điểm xoay = gốc lưới). Phóng không đều thì pháp tuyến
  /// đổi theo ma trận nghịch-chuyển vị (vẫn vuông góc mặt). Dùng chung mảng màu / chỉ số (không đổi).
  ChibiMesh scaled(double sx, double sy, double sz) {
    final pos = Float32List(positions.length);
    final nor = Float32List(normals.length);
    var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
    for (var k = 0; k < positions.length; k += 3) {
      final x = positions[k] * sx, y = positions[k + 1] * sy, z = positions[k + 2] * sz;
      pos[k] = x;
      pos[k + 1] = y;
      pos[k + 2] = z;
      if (x < x0) x0 = x;
      if (y < y0) y0 = y;
      if (z < z0) z0 = z;
      if (x > x1) x1 = x;
      if (y > y1) y1 = y;
      if (z > z1) z1 = z;
      final nx = normals[k] / sx, ny = normals[k + 1] / sy, nz = normals[k + 2] / sz;
      final l = math.sqrt(nx * nx + ny * ny + nz * nz);
      nor[k] = l == 0 ? 0 : nx / l;
      nor[k + 1] = l == 0 ? 1 : ny / l;
      nor[k + 2] = l == 0 ? 0 : nz / l;
    }
    if (positions.isEmpty) x0 = y0 = z0 = x1 = y1 = z1 = 0;
    return ChibiMesh._(pos, nor, colors, indices, x0, y0, z0, x1, y1, z1);
  }
}

/// Cơ sở trực chuẩn 3×3: [x], [y], [z] là ba trục cục bộ biểu diễn trong không gian cha.
class ChibiBasis {
  const ChibiBasis(this.xx, this.xy, this.xz, this.yx, this.yy, this.yz, this.zx, this.zy, this.zz);

  static const identity = ChibiBasis(1, 0, 0, 0, 1, 0, 0, 0, 1);

  /// Xoay theo thứ tự Z rồi X rồi Y (R = Ry · Rx · Rz), cùng chiều `Matrix4.rotationX/Y/Z`.
  factory ChibiBasis.euler(double rx, double ry, double rz) {
    final cx = math.cos(rx), sx = math.sin(rx);
    final cy = math.cos(ry), sy = math.sin(ry);
    final cz = math.cos(rz), sz = math.sin(rz);
    // Ry·Rx·Rz áp lên các trục đơn vị.
    (double, double, double) apply(double x, double y, double z) {
      // Rz
      final x1 = x * cz - y * sz, y1 = x * sz + y * cz, z1 = z;
      // Rx
      final y2 = y1 * cx - z1 * sx, z2 = y1 * sx + z1 * cx;
      // Ry
      return (x1 * cy + z2 * sy, y2, -x1 * sy + z2 * cy);
    }

    final (ax, ay, az) = apply(1, 0, 0);
    final (bx, by, bz) = apply(0, 1, 0);
    final (cx2, cy2, cz2) = apply(0, 0, 1);
    return ChibiBasis(ax, ay, az, bx, by, bz, cx2, cy2, cz2);
  }

  /// Trục z cục bộ = ([nx],[ny],[nz]) (chuẩn hoá); trục y cục bộ gần với +y thế giới nhất (dùng để đặt chi tiết lên
  /// mặt: mắt, má, kính… "dán" lên bề mặt đầu theo pháp tuyến).
  factory ChibiBasis.facing(double nx, double ny, double nz) {
    final l = math.sqrt(nx * nx + ny * ny + nz * nz);
    final zx = nx / l, zy = ny / l, zz = nz / l;
    // x = up × z, rồi y = z × x.
    var xx = zz, xy = 0.0, xz = -zx;
    var xl = math.sqrt(xx * xx + xz * xz);
    if (xl < 1e-6) {
      xx = 1;
      xz = 0;
      xl = 1;
    }
    xx /= xl;
    xz /= xl;
    final yx = zy * xz - zz * xy, yy = zz * xx - zx * xz, yz = zx * xy - zy * xx;
    return ChibiBasis(xx, xy, xz, yx, yy, yz, zx, zy, zz);
  }

  /// Trục y cục bộ dọc theo ([dx],[dy],[dz]) (cho khối dài: tay, chân, gậy); trục z cục bộ gần +z thế giới nhất.
  factory ChibiBasis.alongY(double dx, double dy, double dz) {
    final l = math.sqrt(dx * dx + dy * dy + dz * dz);
    final yx = dx / l, yy = dy / l, yz = dz / l;
    // x = y × (0,0,1) (nếu song song thì dùng (1,0,0)).
    var xx = yy, xy = -yx, xz = 0.0;
    var xl = math.sqrt(xx * xx + xy * xy);
    if (xl < 1e-6) {
      xx = 1;
      xy = 0;
      xz = 0;
      xl = 1;
    }
    xx /= xl;
    xy /= xl;
    final zx = xy * yz - xz * yy, zy = xz * yx - xx * yz, zz = xx * yy - xy * yx;
    return ChibiBasis(xx, xy, xz, yx, yy, yz, zx, zy, zz);
  }

  final double xx, xy, xz, yx, yy, yz, zx, zy, zz;

  /// this · [inner] (áp [inner] trước).
  ChibiBasis then(ChibiBasis inner) {
    (double, double, double) m(double x, double y, double z) =>
        (xx * x + yx * y + zx * z, xy * x + yy * y + zy * z, xz * x + yz * y + zz * z);
    final (ax, ay, az) = m(inner.xx, inner.xy, inner.xz);
    final (bx, by, bz) = m(inner.yx, inner.yy, inner.yz);
    final (cx, cy, cz) = m(inner.zx, inner.zy, inner.zz);
    return ChibiBasis(ax, ay, az, bx, by, bz, cx, cy, cz);
  }
}

/// sRGB 0xRRGGBB → tuyến tính (gamma 2,2) cho màu đỉnh / `baseColorFactor` của Filament.
double chibiLinear(int c8) => math.pow(c8 / 255, 2.2).toDouble();

/// Gom các khối có màu vào một lưới.
///
/// **Phân đoạn thích ứng** (quy chuẩn cute 03/11: "gấp đôi phân đoạn cho đầu, má, tay, chân, tóc"): số vòng / cạnh
/// truyền vào mỗi khối được nhân theo cỡ khối — khối to (bán kính ≥ [detailFullRadius]: đầu, thân, mũ) nhân
/// [detail] (mặc định 1,5 → viền đầu / thân tròn, hết gãy khúc), khối nhỏ (≤ [detailMinRadius]: tay chân, cụm lông,
/// cúc áo, chấm sáng) giữ nguyên — ngân sách ~4k tam giác / nhân vật cho 20–30 nhân vật trên điện thoại tầm trung. Mọi hàm dựng (kể cả ở thư viện khác) tự hưởng lợi, không phải sửa nơi gọi.
class ChibiMeshBuilder {
  /// Hệ số phân đoạn tối đa cho khối to (1 = như cũ).
  static double detail = 1.5;

  /// Bán kính (m, toạ độ dựng) từ đó trở lên nhân đủ [detail]; từ [detailMinRadius] trở xuống giữ nguyên.
  static const double detailFullRadius = 0.2;
  static const double detailMinRadius = 0.1;

  /// Số phân đoạn [n] sau khi nhân theo cỡ khối [r].
  static int seg(int n, double r) {
    if (detail <= 1) return n;
    final t = ((r - detailMinRadius) / (detailFullRadius - detailMinRadius)).clamp(0.0, 1.0);
    return (n * (1 + (detail - 1) * t)).round();
  }

  final _p = <double>[];
  final _n = <double>[];
  final _c = <double>[];
  final _i = <int>[];

  double _r = 1, _g = 1, _b = 1;

  int get vertexCount => _p.length ~/ 3;
  int get triangleCount => _i.length ~/ 3;
  bool get isEmpty => _i.isEmpty;

  void _color(int rgb) {
    _r = chibiLinear((rgb >> 16) & 0xFF);
    _g = chibiLinear((rgb >> 8) & 0xFF);
    _b = chibiLinear(rgb & 0xFF);
  }

  void _v(double x, double y, double z, double nx, double ny, double nz) {
    _p
      ..add(x)
      ..add(y)
      ..add(z);
    _n
      ..add(nx)
      ..add(ny)
      ..add(nz);
    _c
      ..add(_r)
      ..add(_g)
      ..add(_b)
      ..add(1);
  }

  /// Ellipsoid tâm ([cx],[cy],[cz]), bán trục [rx],[ry],[rz] theo trục của [basis]. [lat] vòng vĩ, [lon] vòng kinh.
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
    _color(rgb);
    final b = basis;
    final base = vertexCount;
    final rMax = math.max(rx, math.max(ry, rz));
    lat = seg(lat, rMax);
    lon = seg(lon, rMax);
    for (var j = 0; j <= lat; j++) {
      final phi = math.pi * j / lat;
      final y = math.cos(phi), ring = math.sin(phi);
      for (var k = 0; k <= lon; k++) {
        final theta = 2 * math.pi * k / lon;
        final x = ring * math.sin(theta), z = ring * math.cos(theta);
        final lx = rx * x, ly = ry * y, lz = rz * z;
        var nx = x / rx, ny = y / ry, nz = z / rz;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nl;
        ny /= nl;
        nz /= nl;
        _v(
            cx + b.xx * lx + b.yx * ly + b.zx * lz,
            cy + b.xy * lx + b.yy * ly + b.zy * lz,
            cz + b.xz * lx + b.yz * ly + b.zz * lz,
            b.xx * nx + b.yx * ny + b.zx * nz,
            b.xy * nx + b.yy * ny + b.zy * nz,
            b.xz * nx + b.yz * ny + b.zz * nz);
      }
    }
    _grid(base, lat, lon);
  }

  /// Cầu (ellipsoid đều).
  void sphere(double cx, double cy, double cz, double r, int rgb, {int lat = 6, int lon = 10}) =>
      ellipsoid(cx, cy, cz, r, r, r, rgb, lat: lat, lon: lon);

  /// Capsule (có thể thuôn) từ điểm a (bán kính [ra]) tới điểm b (bán kính [rb]); hai đầu bo tròn. [ovalX] < 1 làm
  /// dẹt theo trục x cục bộ (ví dụ cánh cú).
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
    _color(rgb);
    radial = seg(radial, math.max(ra, rb));
    capBands = seg(capBands, math.max(ra, rb));
    final dx = bx - ax, dy = by - ay, dz = bz - az;
    final b = ChibiBasis.alongY(dx, dy, dz);
    final len = math.sqrt(dx * dx + dy * dy + dz * dz);
    final base = vertexCount;
    // Hàng: nửa cầu dưới (quanh a) rồi nửa cầu trên (quanh b); cùng một lưới vĩ tuyến.
    final rows = 2 * capBands + 1;
    for (var j = 0; j <= rows; j++) {
      // j = 0 → cực dưới (−y), j = rows → cực trên.
      final bool top = j > capBands;
      final double phi = top ? math.pi / 2 * (j - capBands - 1) / capBands : -math.pi / 2 + math.pi / 2 * j / capBands;
      final y = math.sin(phi), ring = math.cos(phi);
      final r = top ? rb : ra;
      final oy = top ? len : 0.0;
      for (var k = 0; k <= radial; k++) {
        final theta = 2 * math.pi * k / radial;
        final x = ring * math.sin(theta) * ovalX, z = ring * math.cos(theta);
        final lx = r * x, ly = oy + r * y, lz = r * z;
        var nx = x / (ovalX * ovalX), ny = y, nz = z;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nl;
        ny /= nl;
        nz /= nl;
        _v(
            ax + b.xx * lx + b.yx * ly + b.zx * lz,
            ay + b.xy * lx + b.yy * ly + b.zy * lz,
            az + b.xz * lx + b.yz * ly + b.zz * lz,
            b.xx * nx + b.yx * ny + b.zx * nz,
            b.xy * nx + b.yy * ny + b.zy * nz,
            b.xz * nx + b.yz * ny + b.zz * nz);
      }
    }
    _grid(base, rows, radial);
  }

  /// Trụ / nón cụt từ a (bán kính [ra]) tới b ([rb]); [ra] hoặc [rb] = 0 → nón. [ovalX] / [ovalZ] làm tiết diện elip
  /// (trục x cục bộ gần x thế giới khi trục a→b đứng). [pleats] > 0: số nếp gấp (bán kính xen kẽ, mặt phẳng — váy xếp
  /// ly). [capA] / [capB]: nắp phẳng ở hai đầu.
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
    _color(rgb);
    final dx = bx - ax, dy = by - ay, dz = bz - az;
    final b = ChibiBasis.alongY(dx, dy, dz);
    final len = math.sqrt(dx * dx + dy * dy + dz * dz);
    final n = pleats > 0 ? pleats * 2 : seg(radial, math.max(ra, rb) * math.max(ovalX, ovalZ));
    (double, double, double) world(double lx, double ly, double lz) => (
          ax + b.xx * lx + b.yx * ly + b.zx * lz,
          ay + b.xy * lx + b.yy * ly + b.zy * lz,
          az + b.xz * lx + b.yz * ly + b.zz * lz
        );
    (double, double, double) dir(double lx, double ly, double lz) =>
        (b.xx * lx + b.yx * ly + b.zx * lz, b.xy * lx + b.yy * ly + b.zy * lz, b.xz * lx + b.yz * ly + b.zz * lz);
    double rad(int k) => pleats > 0 && k.isOdd ? 1 - pleatDepth : 1.0;
    final slope = (ra - rb) / (len == 0 ? 1 : len);
    final flat = pleats > 0;
    if (!flat) {
      // Thân mượt: mỗi góc 2 đỉnh.
      final side = vertexCount;
      for (var k = 0; k <= n; k++) {
        final t = 2 * math.pi * k / n;
        final sx = math.sin(t) * ovalX, sz = math.cos(t) * ovalZ;
        var nx = math.sin(t) / ovalX, nz = math.cos(t) / ovalZ;
        final hl = math.sqrt(nx * nx + nz * nz);
        nx /= hl;
        nz /= hl;
        final ny = slope;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        final (wnx, wny, wnz) = dir(nx / nl, ny / nl, nz / nl);
        final (x0, y0, z0) = world(ra * sx, 0, ra * sz + offsetZ);
        final (x1, y1, z1) = world(rb * sx, len, rb * sz + offsetZ);
        _v(x0, y0, z0, wnx, wny, wnz);
        _v(x1, y1, z1, wnx, wny, wnz);
      }
      for (var k = 0; k < n; k++) {
        final b0 = side + 2 * k, t0 = b0 + 1, b1 = b0 + 2, t1 = b0 + 3;
        _tri(b0, t1, t0);
        _tri(b0, b1, t1);
      }
    } else {
      // Nếp gấp: mỗi mặt phẳng riêng (pháp tuyến mặt).
      for (var k = 0; k < n; k++) {
        final t0 = 2 * math.pi * k / n, t1 = 2 * math.pi * (k + 1) / n;
        final r0 = rad(k), r1 = rad(k + 1);
        final p = [
          world(ra * r0 * math.sin(t0) * ovalX, 0, ra * r0 * math.cos(t0) * ovalZ + offsetZ),
          world(ra * r1 * math.sin(t1) * ovalX, 0, ra * r1 * math.cos(t1) * ovalZ + offsetZ),
          world(rb * r1 * math.sin(t1) * ovalX, len, rb * r1 * math.cos(t1) * ovalZ + offsetZ),
          world(rb * r0 * math.sin(t0) * ovalX, len, rb * r0 * math.cos(t0) * ovalZ + offsetZ),
        ];
        // Pháp tuyến mặt = (p1 − p0) × (p3 − p0), hướng ra ngoài (cùng phía với tâm → điểm giữa).
        final (e1x, e1y, e1z) = (p[1].$1 - p[0].$1, p[1].$2 - p[0].$2, p[1].$3 - p[0].$3);
        final (e2x, e2y, e2z) = (p[3].$1 - p[0].$1, p[3].$2 - p[0].$2, p[3].$3 - p[0].$3);
        var nx = e1y * e2z - e1z * e2y, ny = e1z * e2x - e1x * e2z, nz = e1x * e2y - e1y * e2x;
        var nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nl < 1e-12) nl = 1;
        nx /= nl;
        ny /= nl;
        nz /= nl;
        final (ox, oy, oz) = dir(math.sin((t0 + t1) / 2), 0, math.cos((t0 + t1) / 2));
        if (nx * ox + ny * oy + nz * oz < 0) {
          nx = -nx;
          ny = -ny;
          nz = -nz;
        }
        final base = vertexCount;
        for (final q in p) {
          _v(q.$1, q.$2, q.$3, nx, ny, nz);
        }
        _tri(base, base + 1, base + 2);
        _tri(base, base + 2, base + 3);
      }
    }
    for (final (bool want, double r, double ly, double sign) in [(capA, ra, 0.0, -1.0), (capB, rb, len, 1.0)]) {
      if (!want || r <= 0) continue;
      final (nx, ny, nz) = dir(0, sign, 0);
      final center = vertexCount;
      final (cx, cy, cz) = world(0, ly, offsetZ);
      _v(cx, cy, cz, nx, ny, nz);
      for (var k = 0; k < n; k++) {
        final t = 2 * math.pi * k / n;
        final (x, y, z) = world(r * rad(k) * math.sin(t) * ovalX, ly, r * rad(k) * math.cos(t) * ovalZ + offsetZ);
        _v(x, y, z, nx, ny, nz);
      }
      for (var k = 0; k < n; k++) {
        _tri(center, center + 1 + k, center + 1 + (k + 1) % n);
      }
    }
  }

  /// Xuyến (vòng) bán kính [ringR], ống [tubeR], nằm trong mặt phẳng xy cục bộ của [basis] (trục vòng = z cục bộ).
  /// [a0]..[a1]: cung (rad, 0 = +x cục bộ, ngược chiều kim đồng hồ khi nhìn từ +z) — miệng cười, lông mày, dây xích.
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
    _color(rgb);
    final b = basis;
    final full = (a1 - a0).abs() >= 2 * math.pi - 1e-9;
    segments = seg(segments, ringR);
    tube = seg(tube, tubeR * 3);
    final base = vertexCount;
    for (var s = 0; s <= segments; s++) {
      final u = a0 + (a1 - a0) * s / segments;
      final cu = math.cos(u), su = math.sin(u);
      for (var t = 0; t <= tube; t++) {
        final v = 2 * math.pi * t / tube;
        final cv = math.cos(v), sv = math.sin(v);
        final lx = (ringR + tubeR * cv) * cu, ly = (ringR + tubeR * cv) * su, lz = tubeR * sv * tubeScaleZ;
        var nx = cv * cu, ny = cv * su, nz = sv / tubeScaleZ;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nl;
        ny /= nl;
        nz /= nl;
        _v(
            cx + b.xx * lx + b.yx * ly + b.zx * lz,
            cy + b.xy * lx + b.yy * ly + b.zy * lz,
            cz + b.xz * lx + b.yz * ly + b.zz * lz,
            b.xx * nx + b.yx * ny + b.zx * nz,
            b.xy * nx + b.yy * ny + b.zy * nz,
            b.xz * nx + b.yz * ny + b.zz * nz);
      }
    }
    final row = tube + 1;
    for (var s = 0; s < segments; s++) {
      for (var t = 0; t < tube; t++) {
        final a = base + s * row + t, bb = a + row, c = bb + 1, d = a + 1;
        _tri(a, bb, c);
        _tri(a, c, d);
      }
    }
    if (!full) {
      // Bịt hai đầu cung bằng cầu nhỏ (đầu tròn, không hở).
      for (final u in [a0, a1]) {
        final lx = ringR * math.cos(u), ly = ringR * math.sin(u);
        final px = cx + b.xx * lx + b.yx * ly, py = cy + b.xy * lx + b.yy * ly, pz = cz + b.xz * lx + b.yz * ly;
        ellipsoid(px, py, pz, tubeR, tubeR, tubeR * tubeScaleZ, rgb, basis: b, lat: 2, lon: 4);
      }
    }
  }

  /// Hộp tâm ([cx],[cy],[cz]), kích thước [sx]×[sy]×[sz] theo trục của [basis]; cạnh sắc.
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
    _color(rgb);
    final b = basis;
    final hx = sx / 2, hy = sy / 2, hz = sz / 2;
    void face(double nx, double ny, double nz, double ux, double uy, double uz, double vx, double vy, double vz) {
      final base = vertexCount;
      final wnx = b.xx * nx + b.yx * ny + b.zx * nz;
      final wny = b.xy * nx + b.yy * ny + b.zy * nz;
      final wnz = b.xz * nx + b.yz * ny + b.zz * nz;
      for (final (p, q) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]) {
        final lx = (nx + ux * p + vx * q) * hx;
        final ly = (ny + uy * p + vy * q) * hy;
        final lz = (nz + uz * p + vz * q) * hz;
        _v(cx + b.xx * lx + b.yx * ly + b.zx * lz, cy + b.xy * lx + b.yy * ly + b.zy * lz,
            cz + b.xz * lx + b.yz * ly + b.zz * lz, wnx, wny, wnz);
      }
      _tri(base, base + 1, base + 2);
      _tri(base, base + 2, base + 3);
    }

    face(1, 0, 0, 0, 0, -1, 0, 1, 0);
    face(-1, 0, 0, 0, 0, 1, 0, 1, 0);
    face(0, 1, 0, 1, 0, 0, 0, 0, -1);
    face(0, -1, 0, 1, 0, 0, 0, 0, 1);
    face(0, 0, 1, 1, 0, 0, 0, 1, 0);
    face(0, 0, -1, -1, 0, 0, 0, 1, 0);
  }

  /// Ngôi sao 5 cánh dày [thick], nằm trong mặt phẳng xy cục bộ của [basis] (mặt trước hướng +z cục bộ).
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
    _color(rgb);
    final b = basis;
    (double, double, double) w(double lx, double ly, double lz) => (
          cx + b.xx * lx + b.yx * ly + b.zx * lz,
          cy + b.xy * lx + b.yy * ly + b.zy * lz,
          cz + b.xz * lx + b.yz * ly + b.zz * lz
        );
    (double, double, double) d(double lx, double ly, double lz) =>
        (b.xx * lx + b.yx * ly + b.zx * lz, b.xy * lx + b.yy * ly + b.zy * lz, b.xz * lx + b.yz * ly + b.zz * lz);
    final pts = [
      for (var k = 0; k < 10; k++)
        (
          (k.isEven ? outerR : innerR) * math.cos(math.pi / 2 + k * math.pi / 5),
          (k.isEven ? outerR : innerR) * math.sin(math.pi / 2 + k * math.pi / 5)
        ),
    ];
    for (final sign in const [1.0, -1.0]) {
      final (nx, ny, nz) = d(0, 0, sign);
      final center = vertexCount;
      final (x0, y0, z0) = w(0, 0, sign * thick / 2);
      _v(x0, y0, z0, nx, ny, nz);
      for (final (px, py) in pts) {
        final (x, y, z) = w(px, py, sign * thick / 2);
        _v(x, y, z, nx, ny, nz);
      }
      for (var k = 0; k < 10; k++) {
        _tri(center, center + 1 + k, center + 1 + (k + 1) % 10);
      }
    }
    for (var k = 0; k < 10; k++) {
      final (p0x, p0y) = pts[k];
      final (p1x, p1y) = pts[(k + 1) % 10];
      var nx = p1y - p0y, ny = -(p1x - p0x);
      final l = math.sqrt(nx * nx + ny * ny);
      nx /= l;
      ny /= l;
      final (wx, wy, wz) = d(nx, ny, 0);
      final base = vertexCount;
      for (final (px, py, pz) in [
        (p0x, p0y, -thick / 2),
        (p1x, p1y, -thick / 2),
        (p1x, p1y, thick / 2),
        (p0x, p0y, thick / 2),
      ]) {
        final (x, y, z) = w(px, py, pz);
        _v(x, y, z, wx, wy, wz);
      }
      _tri(base, base + 1, base + 2);
      _tri(base, base + 2, base + 3);
    }
  }

  /// Trái tim nhỏ (hai cầu + nón), mặt trước hướng +z cục bộ của [basis], cao ~[size].
  void heart(double cx, double cy, double cz, double size, int rgb, {ChibiBasis basis = ChibiBasis.identity}) {
    final b = basis;
    final r = size * 0.3;
    for (final s in const [-1.0, 1.0]) {
      final lx = s * r * 0.85, ly = size * 0.12;
      ellipsoid(cx + b.xx * lx + b.yx * ly, cy + b.xy * lx + b.yy * ly, cz + b.xz * lx + b.yz * ly, r, r, r * 0.6, rgb,
          basis: b, lat: 3, lon: 5);
    }
    final top = (cx + b.yx * size * 0.1, cy + b.yy * size * 0.1, cz + b.yz * size * 0.1);
    final tip = (cx - b.yx * size * 0.55, cy - b.yy * size * 0.55, cz - b.yz * size * 0.55);
    frustum(top.$1, top.$2, top.$3, tip.$1, tip.$2, tip.$3, size * 0.5, 0, rgb,
        radial: 5, ovalZ: 0.6, capA: false, capB: false);
  }

  /// Đĩa vòm dẹt (má hồng, túi áo, chấm sáng, tàn nhang…): viền elip [rx]×[ry] trong mặt phẳng xy cục bộ của
  /// [basis], đỉnh vòm nhô [h] theo +z cục bộ. Một mặt, pháp tuyến gần +z (như decal) — viền tròn đẹp hơn ellipsoid
  /// ít vòng (bị thành hình thoi). [segments] cạnh, 3·segments tam giác.
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
    _color(rgb);
    final b = basis;
    segments = seg(segments, math.max(rx, ry));
    void v(double lx, double ly, double lz, double nx, double ny, double nz) {
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      _v(
        cx + b.xx * lx + b.yx * ly + b.zx * lz,
        cy + b.xy * lx + b.yy * ly + b.zy * lz,
        cz + b.xz * lx + b.yz * ly + b.zz * lz,
        (b.xx * nx + b.yx * ny + b.zx * nz) / nl,
        (b.xy * nx + b.yy * ny + b.zy * nz) / nl,
        (b.xz * nx + b.yz * ny + b.zz * nz) / nl,
      );
    }

    final center = vertexCount;
    v(0, 0, h, 0, 0, 1);
    for (final (k, z, tilt) in [(0.62, h * 0.66, 0.25), (1.0, 0.0, 0.5)]) {
      for (var s = 0; s < segments; s++) {
        final a = 2 * math.pi * s / segments;
        final u = math.cos(a), w = math.sin(a);
        v(rx * k * u, ry * k * w, z, u * tilt, w * tilt, 1);
      }
    }
    for (var s = 0; s < segments; s++) {
      final s1 = (s + 1) % segments;
      _tri(center, center + 1 + s, center + 1 + s1);
      final i0 = center + 1 + s, i1 = center + 1 + s1, o0 = i0 + segments, o1 = i1 + segments;
      _tri(i0, o0, o1);
      _tri(i0, o1, i1);
    }
  }

  /// Tấm "quấn" quanh trục đứng qua ([cx], [cz]) — áo, tạp dề, gile, khăn: mỗi hàng `(y, rx, rz, a0, a1)` là một vòng
  /// elip bán kính rx / rz ở độ cao y, chỉ lấy cung góc a0..a1 (rad; 0 = +z phía trước, dương về +x). Các hàng có
  /// cung khác nhau → cổ chữ V, yếm tạp dề. [segments] cột. Một mặt nhìn từ ngoài; pháp tuyến mượt tính từ lưới.
  /// [basis] xoay cả tấm quanh điểm (cx, [pivotY], cz) (khăn nghiêng).
  void shell(
    double cx,
    double cz,
    List<(double, double, double, double, double)> rows,
    int rgb, {
    int segments = 12,
    ChibiBasis basis = ChibiBasis.identity,
    double pivotY = 0,
  }) {
    _color(rgb);
    final b = basis;
    segments = seg(segments, rows.fold(0.0, (m, r) => math.max(m, math.max(r.$2, r.$3))));
    final nr = rows.length, nc = segments + 1;
    final px = List<double>.filled(nr * nc, 0), py = List<double>.filled(nr * nc, 0);
    final pz = List<double>.filled(nr * nc, 0);
    for (var r = 0; r < nr; r++) {
      final (y, rx, rz, a0, a1) = rows[r];
      for (var c = 0; c < nc; c++) {
        final a = a0 + (a1 - a0) * c / segments;
        final lx = rx * math.sin(a), ly = y - pivotY, lz = rz * math.cos(a);
        px[r * nc + c] = cx + b.xx * lx + b.yx * ly + b.zx * lz;
        py[r * nc + c] = pivotY + b.xy * lx + b.yy * ly + b.zy * lz;
        pz[r * nc + c] = cz + b.xz * lx + b.yz * ly + b.zz * lz;
      }
    }
    final base = vertexCount;
    for (var r = 0; r < nr; r++) {
      for (var c = 0; c < nc; c++) {
        final i = r * nc + c;
        final int cl = r * nc + (c > 0 ? c - 1 : 0), cr = r * nc + (c < nc - 1 ? c + 1 : nc - 1);
        final int ru = (r < nr - 1 ? r + 1 : nr - 1) * nc + c, rd = (r > 0 ? r - 1 : 0) * nc + c;
        final ux = px[cr] - px[cl], uy = py[cr] - py[cl], uz = pz[cr] - pz[cl];
        final vx = px[ru] - px[rd], vy = py[ru] - py[rd], vz = pz[ru] - pz[rd];
        var nx = vy * uz - vz * uy, ny = vz * ux - vx * uz, nz = vx * uy - vy * ux;
        // Hướng ra ngoài trục.
        final ox = px[i] - cx, oz = pz[i] - cz;
        if (nx * ox + nz * oz < 0) {
          nx = -nx;
          ny = -ny;
          nz = -nz;
        }
        var nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nl < 1e-12) {
          nx = ox;
          ny = 0;
          nz = oz;
          nl = math.sqrt(nx * nx + nz * nz) + 1e-12;
        }
        _v(px[i], py[i], pz[i], nx / nl, ny / nl, nz / nl);
      }
    }
    for (var r = 0; r < nr - 1; r++) {
      for (var c = 0; c < segments; c++) {
        final a = base + r * nc + c, bb = a + nc, cc = bb + 1, d = a + 1;
        _tri(a, bb, cc);
        _tri(a, cc, d);
      }
    }
  }

  /// Lưới hai cực (lat × lon ô) bắt đầu ở đỉnh [base], mỗi hàng lon + 1 đỉnh.
  void _grid(int base, int rows, int cols) {
    final row = cols + 1;
    for (var j = 0; j < rows; j++) {
      for (var k = 0; k < cols; k++) {
        final a = base + j * row + k, b = a + row, c = b + 1, d = a + 1;
        _tri(a, b, c);
        _tri(a, c, d);
      }
    }
  }

  /// Thêm tam giác, tự đảo chiều theo pháp tuyến đỉnh trung bình; bỏ tam giác suy biến (ở cực cầu).
  void _tri(int a, int b, int c) {
    final ax = _p[3 * a], ay = _p[3 * a + 1], az = _p[3 * a + 2];
    final e1x = _p[3 * b] - ax, e1y = _p[3 * b + 1] - ay, e1z = _p[3 * b + 2] - az;
    final e2x = _p[3 * c] - ax, e2y = _p[3 * c + 1] - ay, e2z = _p[3 * c + 2] - az;
    final gx = e1y * e2z - e1z * e2y, gy = e1z * e2x - e1x * e2z, gz = e1x * e2y - e1y * e2x;
    if (gx * gx + gy * gy + gz * gz <= 1e-18) return;
    final nx = _n[3 * a] + _n[3 * b] + _n[3 * c];
    final ny = _n[3 * a + 1] + _n[3 * b + 1] + _n[3 * c + 1];
    final nz = _n[3 * a + 2] + _n[3 * b + 2] + _n[3 * c + 2];
    if (gx * nx + gy * ny + gz * nz >= 0) {
      _i.addAll([a, b, c]);
    } else {
      _i.addAll([a, c, b]);
    }
  }

  /// Biến dạng mọi đỉnh đã thêm: y → [y]`(y)` (đơn điệu tăng, đạo hàm [dy]), x / z phóng [sx] / [sz] quanh ([ox], [oz]);
  /// pháp tuyến đổi theo ma trận nghịch-chuyển vị của phép biến dạng (vẫn vuông góc mặt). Dùng khi chốt bộ phận theo
  /// khung tỉ lệ mới (co chân nhưng giữ nguyên giày, co thân, dời đầu…).
  void warp(
    double Function(double y) y,
    double Function(double y) dy, {
    double sx = 1,
    double sz = 1,
    double ox = 0,
    double oz = 0,
  }) {
    for (var k = 0; k < _p.length; k += 3) {
      final y0 = _p[k + 1];
      final d = dy(y0);
      _p[k] = ox + (_p[k] - ox) * sx;
      _p[k + 1] = y(y0);
      _p[k + 2] = oz + (_p[k + 2] - oz) * sz;
      final nx = _n[k] / sx, ny = _n[k + 1] / (d == 0 ? 1e-6 : d), nz = _n[k + 2] / sz;
      final l = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (l > 0) {
        _n[k] = nx / l;
        _n[k + 1] = ny / l;
        _n[k + 2] = nz / l;
      }
    }
  }

  /// Chốt thành mảng typed, dời gốc về điểm xoay ([px],[py],[pz]) của bộ phận rồi phóng đều [scale] lần.
  ChibiMesh build({double px = 0, double py = 0, double pz = 0, double scale = 1}) {
    final pos = Float32List(_p.length);
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (var k = 0; k < _p.length; k += 3) {
      final x = (_p[k] - px) * scale, y = (_p[k + 1] - py) * scale, z = (_p[k + 2] - pz) * scale;
      pos[k] = x;
      pos[k + 1] = y;
      pos[k + 2] = z;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    if (_p.isEmpty) minX = minY = minZ = maxX = maxY = maxZ = 0;
    return ChibiMesh._(pos, Float32List.fromList(_n), Float32List.fromList(_c), Uint32List.fromList(_i), minX, minY,
        minZ, maxX, maxY, maxZ);
  }
}
