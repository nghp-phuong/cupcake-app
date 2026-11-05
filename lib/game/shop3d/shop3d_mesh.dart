import 'dart:math' as math;
import 'dart:typed_data';

import 'shop3d_layout.dart';

/// Lưới tam giác low-poly cho cảnh tiệm 3D — Dart thuần, không phụ thuộc engine. Cảnh Thermion chỉ việc đưa mảng
/// xuống `Geometry(...)`.
///
/// Vì sao không dùng thẳng `CubeGeometry` / `CylinderGeometry` / `SphereGeometry` của Thermion cho từng khối:
/// - mỗi khối một entity → 219 entity / draw call cho cả tiệm (mỗi entity ~10 lệnh gửi luồng render lúc dựng). Gộp
///   theo (vật thể, màu) còn 114; nay màu nằm trong **màu đỉnh** ([Shop3dMesh.colors]) nên gộp theo (vật thể, loại bề
///   mặt [Shop3dSurface]) — mỗi vật thể 1–3 lưới, vẫn bật/tắt, chạm chọn, nhún theo từng vật thể; vật không chạm được
///   (sàn, thảm…) gộp chung theo cờ mở rộng (xem [buildMeshesBySurface], `shop3d_batches.dart`);
/// - `CylinderGeometry.cylinder` của thermion 0.5.0 dùng chung đỉnh viền (pháp tuyến hướng ngang) cho nắp, và mảng
///   pháp tuyến dài hơn mảng đỉnh → mặt trên trụ (mặt bàn, khay…) bị tô sai.
///
/// Quy ước: tam giác ngược chiều kim đồng hồ khi nhìn từ phía pháp tuyến (mặt trước của Filament), pháp tuyến đơn vị.
/// Hộp và nắp trụ phẳng (cạnh sắc, kiểu low-poly), thân trụ và cầu mượt.
class Shop3dMesh {
  Shop3dMesh._(
    this.positions,
    this.normals,
    this.colors,
    this.indices,
    this.minX,
    this.minY,
    this.minZ,
    this.maxX,
    this.maxY,
    this.maxZ,
  );

  /// x,y,z mỗi đỉnh (toạ độ thế giới).
  final Float32List positions;

  /// Pháp tuyến đơn vị, 3 số mỗi đỉnh.
  final Float32List normals;

  /// Màu đỉnh RGBA **tuyến tính** (sRGB^2,2; alpha giữ nguyên), 4 số mỗi đỉnh — material màu đỉnh dùng chung
  /// (`hasVertexColors`, baseColorFactor trắng) tô đúng màu này. Mặc định trắng.
  final Float32List colors;

  /// 3 chỉ số mỗi tam giác.
  final Uint32List indices;

  /// Hộp bao (AABB thế giới).
  final double minX, minY, minZ, maxX, maxY, maxZ;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// Gom nhiều khối vào một lưới.
class Shop3dMeshBuilder {
  final _p = <double>[];
  final _n = <double>[];
  final _c = <double>[];
  final _i = <int>[];

  // Màu đỉnh tuyến tính cho các khối thêm sau ([setColor]); mặc định trắng.
  double _r = 1, _g = 1, _b = 1, _a = 1;

  int get vertexCount => _p.length ~/ 3;
  bool get isEmpty => _i.isEmpty;

  /// Màu đỉnh cho các khối thêm sau: [argb] sRGB (chỉ dùng RGB) → tuyến tính, độ trong suốt [alpha].
  void setColor(int argb, [double alpha = 1]) {
    final k = Shop3dMaterialKey(argb, alpha);
    _r = k.linearR;
    _g = k.linearG;
    _b = k.linearB;
    _a = alpha;
  }

  /// Thêm một [Shop3dPart] (hộp / trụ / cầu), màu đỉnh theo màu + alpha của khối.
  void addPart(Shop3dPart part) {
    setColor(part.color.argb, part.alpha);
    switch (part.shape) {
      case Shop3dShape.box:
        addBox(part.cx, part.cy, part.cz, part.sx, part.sy, part.sz, rotY: part.rotY);
      case Shop3dShape.cylinder:
        addCylinder(
          part.cx,
          part.cy,
          part.cz,
          part.sx,
          part.sy,
          topScale: part.topScale,
          bottomScale: part.bottomScale,
        );
      case Shop3dShape.sphere:
        addSphere(part.cx, part.cy, part.cz, part.sx);
      case Shop3dShape.prism:
        addPrism(
          part.cx,
          part.cy,
          part.cz,
          part.sx,
          part.sy,
          part.sz,
          rotY: part.rotY,
          topScale: part.topScale,
          bottomScale: part.bottomScale,
        );
      case Shop3dShape.scallop:
        addScallop(part.cx, part.cy, part.cz, part.sx, part.sy, part.sz, rotY: part.rotY);
    }
  }

  /// Tô màu hiện tại cho các đỉnh vừa thêm (chưa có màu).
  void _paint() {
    for (var v = _c.length ~/ 4; v < vertexCount; v++) {
      _c
        ..add(_r)
        ..add(_g)
        ..add(_b)
        ..add(_a);
    }
  }

  /// Hộp tâm ([cx],[cy],[cz]), kích thước [sx]×[sy]×[sz], xoay [rotY] quanh trục y (cùng chiều `Matrix4.rotationY`:
  /// x' = x·cos + z·sin, z' = −x·sin + z·cos). 24 đỉnh, mỗi mặt pháp tuyến riêng.
  void addBox(double cx, double cy, double cz, double sx, double sy, double sz, {double rotY = 0}) {
    final hx = sx / 2, hy = sy / 2, hz = sz / 2;
    final c = math.cos(rotY), s = math.sin(rotY);
    // (pháp tuyến, trục u, trục v) với u × v = pháp tuyến; nửa kích thước nhân vào sau.
    void face(double nx, double ny, double nz, double ux, double uy, double uz, double vx, double vy, double vz) {
      final base = vertexCount;
      for (final (a, b) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]) {
        final lx = (nx + ux * a + vx * b) * hx;
        final ly = (ny + uy * a + vy * b) * hy;
        final lz = (nz + uz * a + vz * b) * hz;
        _p
          ..add(cx + lx * c + lz * s)
          ..add(cy + ly)
          ..add(cz - lx * s + lz * c);
        _n
          ..add(nx * c + nz * s)
          ..add(ny)
          ..add(-nx * s + nz * c);
      }
      _i.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    face(1, 0, 0, 0, 0, -1, 0, 1, 0); // +x
    face(-1, 0, 0, 0, 0, 1, 0, 1, 0); // -x
    face(0, 1, 0, 1, 0, 0, 0, 0, -1); // +y
    face(0, -1, 0, 1, 0, 0, 0, 0, 1); // -y
    face(0, 0, 1, 1, 0, 0, 0, 1, 0); // +z
    face(0, 0, -1, -1, 0, 0, 0, 1, 0); // -z
    _paint();
  }

  /// Số cạnh của trụ theo đường kính: vật nhỏ ít cạnh hơn (low-poly, đỡ đỉnh).
  static int cylinderSegments(double diameter) => diameter < 0.1 ? 8 : (diameter < 0.4 ? 12 : 16);

  /// Trụ đứng (trục y) tâm ([cx],[cy],[cz]), [diameter], cao [h]; có hai nắp phẳng. [topScale] / [bottomScale] thu nhỏ
  /// bán kính đỉnh / đáy (nón cụt; 0 = nón nhọn, bỏ nắp đó).
  void addCylinder(
    double cx,
    double cy,
    double cz,
    double diameter,
    double h, {
    int? segments,
    double topScale = 1,
    double bottomScale = 1,
  }) {
    final n = segments ?? cylinderSegments(diameter);
    final r0 = diameter / 2 * bottomScale, r1 = diameter / 2 * topScale, y0 = cy - h / 2, y1 = cy + h / 2;
    // Thân: mỗi góc 2 đỉnh (dưới, trên); pháp tuyến ngang (trụ) hoặc nghiêng theo độ dốc (nón cụt).
    final side = vertexCount;
    final nl = math.sqrt(h * h + (r0 - r1) * (r0 - r1));
    final sh = nl == 0 ? 1.0 : h / nl, sv = nl == 0 ? 0.0 : (r0 - r1) / nl;
    for (var k = 0; k <= n; k++) {
      final a = 2 * math.pi * k / n;
      final x = math.cos(a), z = math.sin(a);
      _p.addAll([cx + r0 * x, y0, cz + r0 * z, cx + r1 * x, y1, cz + r1 * z]);
      _n.addAll([x * sh, sv, z * sh, x * sh, sv, z * sh]);
    }
    for (var k = 0; k < n; k++) {
      final b0 = side + 2 * k, t0 = b0 + 1, b1 = b0 + 2, t1 = b0 + 3;
      _tri(b0, t0, t1, 0);
      _tri(b0, t1, b1, 0);
    }
    // Nắp trên / dưới: tâm + viền riêng (pháp tuyến dọc).
    for (final (y, ny, r) in [(y1, 1.0, r1), (y0, -1.0, r0)]) {
      if (r <= 0) continue;
      final center = vertexCount;
      _p.addAll([cx, y, cz]);
      _n.addAll([0, ny, 0]);
      for (var k = 0; k < n; k++) {
        final a = 2 * math.pi * k / n;
        _p.addAll([cx + r * math.cos(a), y, cz + r * math.sin(a)]);
        _n.addAll([0, ny, 0]);
      }
      for (var k = 0; k < n; k++) {
        _tri(center, center + 1 + k, center + 1 + (k + 1) % n, 0);
      }
    }
    _paint();
  }

  /// Lăng trụ hình thang tâm ([cx],[cy],[cz]): mặt cắt trong mặt phẳng xy cục bộ rộng [sx] × [bottomScale] ở đáy,
  /// [sx] × [topScale] ở đỉnh, cao [sy]; dày [sz] theo z cục bộ; xoay [rotY] như [addBox]. Mặt phẳng, cạnh sắc.
  void addPrism(
    double cx,
    double cy,
    double cz,
    double sx,
    double sy,
    double sz, {
    double rotY = 0,
    double topScale = 1,
    double bottomScale = 1,
  }) {
    final hy = sy / 2, b = sx * bottomScale / 2, t = sx * topScale / 2;
    _extrude([(-b, -hy), (b, -hy), (t, hy), (-t, hy)], cx, cy, cz, sz, rotY);
  }

  /// Diềm sóng tâm ([cx],[cy],[cz]): cạnh trên phẳng rộng [sx] ở `cy + sy/2`, nửa elip sâu [sy] xuống dưới, [segments]
  /// đoạn; dày [sz] theo z cục bộ; xoay [rotY].
  void addScallop(
    double cx,
    double cy,
    double cz,
    double sx,
    double sy,
    double sz, {
    double rotY = 0,
    int segments = 4,
  }) {
    final hy = sy / 2, r = sx / 2;
    _extrude(
      [
        for (var k = 0; k <= segments; k++)
          (-r * math.cos(math.pi * k / segments), hy - sy * math.sin(math.pi * k / segments)),
      ],
      cx,
      cy,
      cz,
      sz,
      rotY,
    );
  }

  /// Đùn đa giác lồi [profile] (toạ độ xy cục bộ quanh tâm, theo vòng) dày [depth] theo z cục bộ, xoay [rotY] quanh y
  /// rồi dời tới ([cx],[cy],[cz]). Bỏ đỉnh trùng nhau (cạnh độ dài 0 của tam giác); hai mặt đầu + mỗi cạnh một mặt bên,
  /// pháp tuyến phẳng.
  void _extrude(List<(double, double)> profile, double cx, double cy, double cz, double depth, double rotY) {
    final pts = <(double, double)>[];
    for (final p in profile) {
      if (pts.isNotEmpty && (pts.last.$1 - p.$1).abs() < 1e-9 && (pts.last.$2 - p.$2).abs() < 1e-9) continue;
      pts.add(p);
    }
    if (pts.length > 2 && (pts.first.$1 - pts.last.$1).abs() < 1e-9 && (pts.first.$2 - pts.last.$2).abs() < 1e-9) {
      pts.removeLast();
    }
    if (pts.length < 3) return;
    // Chiều vòng: diện tích có dấu > 0 = ngược chiều kim đồng hồ (nhìn từ +z) → pháp tuyến cạnh (ey, -ex) hướng ra ngoài.
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      area += a.$1 * b.$2 - b.$1 * a.$2;
    }
    final sign = area >= 0 ? 1.0 : -1.0;
    final c = math.cos(rotY), s = math.sin(rotY), hz = depth / 2;
    void vert(double lx, double ly, double lz, double nx, double ny, double nz) {
      _p
        ..add(cx + lx * c + lz * s)
        ..add(cy + ly)
        ..add(cz - lx * s + lz * c);
      _n
        ..add(nx * c + nz * s)
        ..add(ny)
        ..add(-nx * s + nz * c);
    }

    // Hai mặt đầu (±z cục bộ): quạt tam giác từ đỉnh 0.
    for (final nz in const [1.0, -1.0]) {
      final base = vertexCount;
      for (final (x, y) in pts) {
        vert(x, y, nz * hz, 0, 0, nz);
      }
      for (var k = 1; k < pts.length - 1; k++) {
        _tri(base, base + k, base + k + 1, 1e-14);
      }
    }
    // Mặt bên.
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      final ex = b.$1 - a.$1, ey = b.$2 - a.$2;
      final l = math.sqrt(ex * ex + ey * ey);
      final nx = sign * ey / l, ny = -sign * ex / l;
      final base = vertexCount;
      vert(a.$1, a.$2, -hz, nx, ny, 0);
      vert(b.$1, b.$2, -hz, nx, ny, 0);
      vert(b.$1, b.$2, hz, nx, ny, 0);
      vert(a.$1, a.$2, hz, nx, ny, 0);
      _tri(base, base + 1, base + 2, 0);
      _tri(base, base + 2, base + 3, 0);
    }
    _paint();
  }

  /// Số vòng vĩ tuyến / kinh tuyến của cầu theo đường kính (hạt nhỏ — quả dâu, núm lọ, bánh trong tủ — 36 tam giác; cụm
  /// lá / bông hoa dưới 25 cm 64; tán cây vừa dưới 45 cm 100; cầu lớn 168).
  static (int, int) sphereBands(double diameter) => switch (diameter) {
        < 0.06 => (4, 6),
        < 0.25 => (5, 8),
        < 0.45 => (6, 10),
        _ => (8, 12),
      };

  /// Cầu tâm ([cx],[cy],[cz]), [diameter].
  void addSphere(double cx, double cy, double cz, double diameter, {int? latBands, int? lonBands}) {
    final (defLat, defLon) = sphereBands(diameter);
    final lat = latBands ?? defLat, lon = lonBands ?? defLon;
    final r = diameter / 2;
    final base = vertexCount;
    for (var j = 0; j <= lat; j++) {
      final phi = math.pi * j / lat;
      final y = math.cos(phi), ring = math.sin(phi);
      for (var k = 0; k <= lon; k++) {
        final theta = 2 * math.pi * k / lon;
        final x = ring * math.cos(theta), z = ring * math.sin(theta);
        _p.addAll([cx + r * x, cy + r * y, cz + r * z]);
        _n.addAll([x, y, z]);
      }
    }
    final row = lon + 1;
    for (var j = 0; j < lat; j++) {
      for (var k = 0; k < lon; k++) {
        final a = base + j * row + k, b = a + row, c = b + 1, d = a + 1;
        // Ở hai cực một trong hai tam giác suy biến (diện tích 0) → [_tri] bỏ qua.
        _tri(a, b, c, 1e-12);
        _tri(a, c, d, 1e-12);
      }
    }
    _paint();
  }

  /// Thêm tam giác (a, b, c), tự đảo chiều nếu pháp tuyến hình học ngược pháp tuyến đỉnh trung bình; bỏ tam giác có
  /// |tích có hướng|² ≤ [minArea2] (suy biến).
  void _tri(int a, int b, int c, double minArea2) {
    final ax = _p[3 * a], ay = _p[3 * a + 1], az = _p[3 * a + 2];
    final e1x = _p[3 * b] - ax, e1y = _p[3 * b + 1] - ay, e1z = _p[3 * b + 2] - az;
    final e2x = _p[3 * c] - ax, e2y = _p[3 * c + 1] - ay, e2z = _p[3 * c + 2] - az;
    final gx = e1y * e2z - e1z * e2y, gy = e1z * e2x - e1x * e2z, gz = e1x * e2y - e1y * e2x;
    if (gx * gx + gy * gy + gz * gz <= minArea2) return;
    final nx = _n[3 * a] + _n[3 * b] + _n[3 * c];
    final ny = _n[3 * a + 1] + _n[3 * b + 1] + _n[3 * c + 1];
    final nz = _n[3 * a + 2] + _n[3 * b + 2] + _n[3 * c + 2];
    if (gx * nx + gy * ny + gz * nz >= 0) {
      _i.addAll([a, b, c]);
    } else {
      _i.addAll([a, c, b]);
    }
  }

  /// Chốt thành mảng typed (cấp phát một lần). Builder rỗng → hộp bao toàn 0.
  Shop3dMesh build() {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (var k = 0; k < _p.length; k += 3) {
      final x = _p[k], y = _p[k + 1], z = _p[k + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    if (_p.isEmpty) minX = minY = minZ = maxX = maxY = maxZ = 0;
    _paint();
    return Shop3dMesh._(
      Float32List.fromList(_p),
      Float32List.fromList(_n),
      Float32List.fromList(_c),
      Uint32List.fromList(_i),
      minX,
      minY,
      minZ,
      maxX,
      maxY,
      maxZ,
    );
  }
}

/// Khoá material: cùng màu ([argb], 0xAARRGGBB — chỉ dùng RGB) + cùng độ trong suốt [alpha] thì dùng chung một
/// material instance.
class Shop3dMaterialKey {
  const Shop3dMaterialKey(this.argb, this.alpha);

  factory Shop3dMaterialKey.of(Shop3dPart part) => Shop3dMaterialKey(part.color.argb, part.alpha);

  final int argb;
  final double alpha;

  bool get transparent => alpha < 1;

  /// Màu sRGB 0..1 → tuyến tính (gamma 2,2) cho `baseColorFactor` của Filament.
  double get linearR => _lin((argb >> 16) & 0xFF);
  double get linearG => _lin((argb >> 8) & 0xFF);
  double get linearB => _lin(argb & 0xFF);

  static double _lin(int c) => math.pow(c / 255, 2.2).toDouble();

  @override
  bool operator ==(Object other) => other is Shop3dMaterialKey && other.argb == argb && other.alpha == alpha;

  @override
  int get hashCode => Object.hash(argb, alpha);

  @override
  String toString() => '0x${argb.toRadixString(16)}${transparent ? '@$alpha' : ''}';
}

/// Độ nhám của bề mặt tĩnh (giữ như khi mỗi màu một material): gỗ / bột / sơn gần như không bóng, kim loại bóng vừa,
/// kính bóng.
enum Shop3dSurface {
  /// Mặt mờ (mặc định).
  matte(0.85),

  /// Kim loại (inox).
  steel(0.45),

  /// Kính (trong suốt; màu kính đục cũng giữ độ bóng này).
  glass(0.15),

  /// Trong suốt khác (cửa lò, quầng sáng giả trên bàn).
  clear(0.3),

  /// Tranh cảnh ngoài cửa sổ ([Shop3dColor.backdrop]): material màu đỉnh **không chịu ánh sáng** (unlit) — luôn sáng
  /// đúng màu dù mặt trong tường trước nằm trong bóng.
  backdrop(1);

  const Shop3dSurface(this.roughness);

  final double roughness;

  bool get unlit => this == backdrop;

  static final Set<int> _backdropArgb = {for (final c in Shop3dColor.backdrop) c.argb};

  /// Loại bề mặt của màu [argb] với độ trong suốt [alpha].
  static Shop3dSurface of(int argb, double alpha) {
    if (argb == Shop3dColor.glass.argb) return glass;
    if (argb == Shop3dColor.steel.argb) return steel;
    if (alpha < 1) return clear;
    if (_backdropArgb.contains(argb)) return backdrop;
    return matte;
  }
}

/// Khoá material của một lưới tĩnh.
/// - Mặt **đục**: MỘT material màu đỉnh dùng chung cho cả tiệm theo [surface] (độ nhám); màu từng khối nằm trong
///   [Shop3dMesh.colors] → mọi khối đục của một vật thể (cùng độ nhám) gộp được thành một lưới / một entity.
/// - Mặt **trong suốt** ([tint] khác null): material một màu (màu + alpha ở `baseColorFactor`) như trước, cảnh gửi màu
///   đỉnh trắng (ubershader vẫn nhân màu đỉnh) — không phụ thuộc cách ubershader trộn alpha của màu đỉnh với alpha nhân
///   trước (chưa kiểm được trên Filament 1.69).
class Shop3dSurfaceKey {
  const Shop3dSurfaceKey.opaque(this.surface) : tint = null;

  const Shop3dSurfaceKey._tinted(this.surface, Shop3dMaterialKey this.tint);

  factory Shop3dSurfaceKey.of(int argb, double alpha) {
    final s = Shop3dSurface.of(argb, alpha);
    return alpha < 1 ? Shop3dSurfaceKey._tinted(s, Shop3dMaterialKey(argb, alpha)) : Shop3dSurfaceKey.opaque(s);
  }

  factory Shop3dSurfaceKey.ofPart(Shop3dPart part) => Shop3dSurfaceKey.of(part.color.argb, part.alpha);

  final Shop3dSurface surface;
  final Shop3dMaterialKey? tint;

  bool get transparent => tint != null;

  @override
  bool operator ==(Object other) => other is Shop3dSurfaceKey && other.surface == surface && other.tint == tint;

  @override
  int get hashCode => Object.hash(surface, tint);

  @override
  String toString() => tint == null ? surface.name : '${surface.name}:$tint';
}

/// Gộp [parts] theo [Shop3dSurfaceKey]: mặt đục theo độ nhám (màu ở màu đỉnh), mặt trong suốt theo (màu, alpha). Thứ tự
/// khoá theo lần xuất hiện đầu tiên (ổn định).
Map<Shop3dSurfaceKey, Shop3dMesh> buildMeshesBySurface(Iterable<Shop3dPart> parts) {
  final builders = <Shop3dSurfaceKey, Shop3dMeshBuilder>{};
  for (final part in parts) {
    builders.putIfAbsent(Shop3dSurfaceKey.ofPart(part), Shop3dMeshBuilder.new).addPart(part);
  }
  return {
    for (final e in builders.entries)
      if (!e.value.isEmpty) e.key: e.value.build(),
  };
}

/// Mặt phẳng nằm ngang (thảm, bóng mềm dưới chân) — một hình tròn [segments] cạnh, pháp tuyến +y, ở độ cao [y].
Shop3dMesh buildDisc(double cx, double y, double cz, double diameter, {int segments = 16}) {
  final b = Shop3dMeshBuilder();
  final center = b.vertexCount;
  b._p.addAll([cx, y, cz]);
  b._n.addAll([0, 1, 0]);
  final r = diameter / 2;
  for (var k = 0; k < segments; k++) {
    final a = 2 * math.pi * k / segments;
    b._p.addAll([cx + r * math.cos(a), y, cz + r * math.sin(a)]);
    b._n.addAll([0, 1, 0]);
  }
  for (var k = 0; k < segments; k++) {
    b._tri(center, center + 1 + k, center + 1 + (k + 1) % segments, 0);
  }
  return b.build();
}

/// Tấm billboard đứng: rộng [width], cao [height], đáy ở y = 0 giữa x = 0, nằm trong mặt phẳng z = 0, pháp tuyến +z.
/// UV: v = 0 ở mép trên (hàng ảnh đầu tiên), v = 1 ở chân — như `QuadGeometry.quad()` của thermion.
/// Trả về (vị trí, pháp tuyến, uv, chỉ số).
(Float32List, Float32List, Float32List, Uint32List) buildBillboardQuad(double width, double height) {
  final hw = width / 2;
  return (
    Float32List.fromList([-hw, 0, 0, hw, 0, 0, hw, height, 0, -hw, height, 0]),
    Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
    Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    Uint32List.fromList([0, 1, 2, 0, 2, 3]),
  );
}
