import 'dart:math' as math;
import 'dart:typed_data';

import '../shop3d_layout.dart';

/// Va chạm + tìm đường cho nhân vật điều khiển được (V3, docs/v3/interaction-spec.md mục 2.1). Dart thuần, không
/// import thermion.
///
/// Mặt phẳng xz, đơn vị mét. Vùng đi được = phòng + khe cửa + vỉa hè (xem [Shop3dNav.walls]); mọi thứ còn lại là hộp
/// chặn. Hộp chặn dựng từ [Shop3dLayout.props] và [Shop3dLayout.outdoorProps] (chậu hoa, ghế băng ngoài cửa): khối
/// không `flat`, `minY < ` [Shop3dNav.blockMinY] (đèn thả 1,95 m không chặn; bục `flat` vẫn đi được) — xem
/// [Shop3dNav.fromLayout]. Muốn dựng từ nguồn khác thì đưa danh sách [NavBox] vào constructor chính.
///
/// Kiểm tra đứng được ([Shop3dNav.canStand]) là phép thử chính xác "hình tròn – hình chữ nhật" (không lượng tử theo
/// ô), có bucket 0,5 m để nhanh; lưới ô 0,1 m chỉ dùng cho A* ([Shop3dNav.findPath]) và dựng lười, một lần cho mỗi
/// giá trị khoảng hở.
///
/// Biên thế giới và cỡ ô A* là tham số ([NavBounds], `cellSize`): mặc định là biên cảnh tiệm 15 × 13 m, ô 0,1 m (hành vi
/// cũ); lớp phố thành phố V3 (quận 48 × 32 m) truyền biên quận, ô thô hơn và `addWalls: false` (`town3d/town_nav.dart`).

/// Hộp chặn (AABB trên xz) kèm khoảng cao [minY]..[maxY] cho vật bay. Tường dùng chiều cao 99 m.
class NavBox {
  const NavBox(this.minX, this.maxX, this.minZ, this.maxZ, {this.minY = 0, this.maxY = 99});

  factory NavBox.fromPart(Shop3dPart p) => NavBox(p.minX, p.maxX, p.minZ, p.maxZ, minY: p.minY, maxY: p.maxY);

  final double minX, maxX, minZ, maxZ;
  final double minY, maxY;
}

class NavPoint {
  const NavPoint(this.x, this.z);

  final double x, z;

  @override
  String toString() => 'NavPoint(${x.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Hình tròn động (NPC) mà nhân vật phải đi vòng qua. Có thể tái dùng đối tượng giữa các khung (trường mutable).
class NavCircle {
  NavCircle(this.x, this.z, this.r, {this.id});

  double x, z, r;
  String? id;
}

/// Kết quả [Shop3dNav.slide]: vị trí mới; [blocked] = có bị chặn / phải trượt. Tái dùng được (truyền `out`).
class NavMove {
  double x = 0, z = 0;
  bool blocked = false;
}

/// Biên thế giới (mặt phẳng xz) của một [Shop3dNav]: ngoài biên = không đứng được.
class NavBounds {
  const NavBounds(this.minX, this.maxX, this.minZ, this.maxZ);

  /// Biên cảnh tiệm (phòng + vỉa hè) — mặc định của [Shop3dNav].
  static const NavBounds shop =
      NavBounds(Shop3dNav.worldMinX, Shop3dNav.worldMaxX, Shop3dNav.worldMinZ, Shop3dNav.worldMaxZ);

  final double minX, maxX, minZ, maxZ;
}

class Shop3dNav {
  /// [bounds]: biên thế giới (mặc định [NavBounds.shop]); [cellSize]: cỡ ô lưới A* và bước tìm điểm trống (mặc định
  /// [cell] = 0,1 m); [addWalls]: thêm [walls] của tiệm (chỉ hợp với biên tiệm).
  Shop3dNav(
    Iterable<NavBox> boxes, {
    double Function(double x, double z)? floorHeight,
    bool addWalls = true,
    NavBounds bounds = NavBounds.shop,
    this.cellSize = cell,
  })  : assert(bounds.minX < bounds.maxX && bounds.minZ < bounds.maxZ && cellSize > 0),
        floorHeight = floorHeight ?? Shop3dLayout.floorHeightAt,
        minX = bounds.minX,
        maxX = bounds.maxX,
        minZ = bounds.minZ,
        maxZ = bounds.maxZ,
        _bw = ((bounds.maxX - bounds.minX) / _bucket).ceil(),
        _bh = ((bounds.maxZ - bounds.minZ) / _bucket).ceil(),
        _gw = ((bounds.maxX - bounds.minX) / cellSize).round(),
        _gh = ((bounds.maxZ - bounds.minZ) / cellSize).round() {
    _build([if (addWalls) ...walls, ...boxes]);
  }

  /// Dựng từ bố cục tiệm: vật thể bật theo [owned] (cờ `Shop3dRequires`, giống `Shop3dScene.owned`), bỏ vật `flat` và
  /// khối cao từ [blockMinY] trở lên.
  factory Shop3dNav.fromLayout({Set<String> owned = const {}, double Function(double x, double z)? floorHeight}) {
    final boxes = <NavBox>[];
    for (final prop in [...Shop3dLayout.props, ...Shop3dLayout.outdoorProps]) {
      if (prop.flat || !prop.enabledFor(owned)) continue;
      for (final part in prop.parts) {
        if (part.minY < blockMinY) boxes.add(NavBox.fromPart(part));
      }
    }
    return Shop3dNav(boxes, floorHeight: floorHeight);
  }

  /// Khối có đáy từ độ cao này trở lên không chặn người đi.
  static const double blockMinY = 1.4;

  /// Biên thế giới mặc định (cảnh tiệm, [NavBounds.shop]); ngoài biên = không đứng được.
  static const double worldMinX = -7.5, worldMaxX = 7.5, worldMinZ = -5.0, worldMaxZ = 8.0;

  /// Biên thế giới của lưới này ([NavBounds]).
  final double minX, maxX, minZ, maxZ;

  /// Vùng đi được (spec 2.1). Khe cửa: x ∈ [doorMinX, doorMaxX]; nối phòng (z = 4,0) với vỉa hè (z = 4,45) nên đoạn
  /// z ∈ [4,2; 4,45] của khe được coi là thông (spec chỉ ghi tới 4,2 — sai khác 0,25 m giữa tường và vỉa hè).
  static const double roomMinX = -5, roomMaxX = 5, roomMinZ = -4, roomMaxZ = 4;
  static const double doorMinX = 3.05, doorMaxX = 4.15;
  static const double walkMinX = -6.5, walkMaxX = 6.5, walkMinZ = 4.45, walkMaxZ = 6.7;

  /// Phần bù của vùng đi được, dưới dạng hộp chặn (cao 99 m).
  static const List<NavBox> walls = [
    NavBox(worldMinX, worldMaxX, worldMinZ, roomMinZ), // tường sau
    NavBox(worldMinX, roomMinX, roomMinZ, walkMinZ), // tường trái
    NavBox(roomMaxX, worldMaxX, roomMinZ, walkMinZ), // tường phải
    NavBox(roomMinX, doorMinX, roomMaxZ, walkMinZ), // tường trước, trái cửa
    NavBox(doorMaxX, roomMaxX, roomMaxZ, walkMinZ), // tường trước, phải cửa
    NavBox(worldMinX, walkMinX, walkMinZ, worldMaxZ), // ngoài mép vỉa hè bên trái
    NavBox(walkMaxX, worldMaxX, walkMinZ, worldMaxZ), // bên phải
    NavBox(worldMinX, worldMaxX, walkMaxZ, worldMaxZ), // mép ngoài vỉa hè
  ];

  /// Độ cao mặt đứng tại (x, z) (bục), mặc định [Shop3dLayout.floorHeightAt].
  final double Function(double x, double z) floorHeight;

  // ---- Hộp + bucket -----------------------------------------------------------------------------------------

  static const double _bucket = 0.5;
  final int _bw, _bh;

  late final int boxCount;
  late final Float64List _minX, _maxX, _minZ, _maxZ, _minY, _maxY;
  late final Int32List _bStart;
  late final Int32List _bItems;

  void _build(List<NavBox> list) {
    final n = boxCount = list.length;
    _minX = Float64List(n);
    _maxX = Float64List(n);
    _minZ = Float64List(n);
    _maxZ = Float64List(n);
    _minY = Float64List(n);
    _maxY = Float64List(n);
    for (var i = 0; i < n; i++) {
      final b = list[i];
      _minX[i] = b.minX;
      _maxX[i] = b.maxX;
      _minZ[i] = b.minZ;
      _maxZ[i] = b.maxZ;
      _minY[i] = b.minY;
      _maxY[i] = b.maxY;
    }
    final counts = Int32List(_bw * _bh + 1);
    for (var pass = 0; pass < 2; pass++) {
      final cursor = pass == 0 ? null : Int32List.fromList(counts);
      for (var i = 0; i < n; i++) {
        final x0 = _bx(_minX[i]), x1 = _bx(_maxX[i]), z0 = _bz(_minZ[i]), z1 = _bz(_maxZ[i]);
        for (var bz = z0; bz <= z1; bz++) {
          for (var bx = x0; bx <= x1; bx++) {
            final b = bz * _bw + bx;
            if (cursor == null) {
              counts[b + 1]++;
            } else {
              _bItems[cursor[b]++] = i;
            }
          }
        }
      }
      if (pass == 0) {
        for (var b = 0; b < _bw * _bh; b++) {
          counts[b + 1] += counts[b];
        }
        _bStart = counts;
        _bItems = Int32List(counts[_bw * _bh]);
      }
    }
  }

  int _bx(double x) => ((x - minX) / _bucket).floor().clamp(0, _bw - 1);
  int _bz(double z) => ((z - minZ) / _bucket).floor().clamp(0, _bh - 1);

  NavBox boxAt(int i) => NavBox(_minX[i], _maxX[i], _minZ[i], _maxZ[i], minY: _minY[i], maxY: _maxY[i]);

  // ---- Đứng được ---------------------------------------------------------------------------------------------

  /// Hình tròn bán kính [r] tại (x, z) nằm trong vùng đi được và không chạm hộp chặn nào (chạm mép thì vẫn được).
  bool canStand(double x, double z, double r) {
    if (x - r < minX || x + r > maxX || z - r < minZ || z + r > maxZ) return false;
    return _circleHit(x, z, r) < 0;
  }

  /// Chỉ số hộp đầu tiên chạm hình tròn, hoặc -1.
  int _circleHit(double x, double z, double r) {
    final r2 = r * r - 1e-9;
    final z0 = _bz(z - r), z1 = _bz(z + r), x0 = _bx(x - r), x1 = _bx(x + r);
    for (var bz = z0; bz <= z1; bz++) {
      for (var bx = x0; bx <= x1; bx++) {
        final b = bz * _bw + bx;
        for (var k = _bStart[b]; k < _bStart[b + 1]; k++) {
          final i = _bItems[k];
          final dx = x < _minX[i] ? _minX[i] - x : (x > _maxX[i] ? x - _maxX[i] : 0.0);
          final dz = z < _minZ[i] ? _minZ[i] - z : (z > _maxZ[i] ? z - _maxZ[i] : 0.0);
          if (dx * dx + dz * dz < r2) return i;
        }
      }
    }
    return -1;
  }

  bool _freeWith(double x, double z, double r, List<NavCircle>? others) {
    if (!canStand(x, z, r)) return false;
    if (others == null) return true;
    for (final c in others) {
      final d = r + c.r;
      final dx = x - c.x, dz = z - c.z;
      if (dx * dx + dz * dz < d * d - 1e-9) return false;
    }
    return true;
  }

  // ---- Trượt -------------------------------------------------------------------------------------------------

  /// Bước tối đa mỗi lần xét (m); bước dài hơn được chia nhỏ để không xuyên vật mỏng.
  static const double maxStep = 0.08;

  /// Di chuyển hình tròn bán kính [r] từ (x, z) thêm (dx, dz). Bị chặn thì trượt theo trục còn đi được; gặp NPC
  /// ([others]) thì đi vòng theo mép hình tròn của họ. Không cấp phát khi truyền [out]. Nếu điểm xuất phát nằm
  /// trong ô chặn thì dùng [nearestFree] trước.
  NavMove slide(double x, double z, double dx, double dz, double r, {NavMove? out, List<NavCircle>? others}) {
    final o = out ?? NavMove();
    o
      ..x = x
      ..z = z
      ..blocked = false;
    final len = math.sqrt(dx * dx + dz * dz);
    if (len < 1e-9) return o;
    final n = (len / maxStep).ceil();
    final sx = dx / n, sz = dz / n;
    for (var i = 0; i < n; i++) {
      final nx = o.x + sx, nz = o.z + sz;
      if (_freeWith(nx, nz, r, others)) {
        o
          ..x = nx
          ..z = nz;
        continue;
      }
      o.blocked = true;
      // Đi vòng NPC: bước thẳng hợp lệ với tường nhưng đè lên hình tròn → đẩy ra mép hình tròn.
      if (others != null && canStand(nx, nz, r)) {
        var px = nx, pz = nz;
        for (var it = 0; it < 2; it++) {
          for (final c in others) {
            final d = r + c.r;
            var ex = px - c.x, ez = pz - c.z;
            final dist2 = ex * ex + ez * ez;
            if (dist2 >= d * d - 1e-9) continue;
            var dist = math.sqrt(dist2);
            if (dist < 1e-6) {
              ex = -sx;
              ez = -sz;
              dist = math.sqrt(ex * ex + ez * ez);
              if (dist < 1e-9) continue;
            }
            px = c.x + ex / dist * d;
            pz = c.z + ez / dist * d;
          }
        }
        if (_freeWith(px, pz, r, others)) {
          o
            ..x = px
            ..z = pz;
          continue;
        }
      }
      // Trượt theo trục (thành phần lớn hơn trước).
      final xFirst = sx.abs() >= sz.abs();
      if (xFirst) {
        if (sx != 0 && _freeWith(nx, o.z, r, others)) {
          o.x = nx;
        } else if (sz != 0 && _freeWith(o.x, nz, r, others)) {
          o.z = nz;
        }
      } else {
        if (sz != 0 && _freeWith(o.x, nz, r, others)) {
          o.z = nz;
        } else if (sx != 0 && _freeWith(nx, o.z, r, others)) {
          o.x = nx;
        }
      }
    }
    return o;
  }

  // ---- Điểm trống gần nhất -----------------------------------------------------------------------------------

  /// Điểm đứng được gần (x, z) nhất (bước tìm = [cellSize], mặc định 0,1 m), tối đa [maxDist] m. null nếu không có.
  NavPoint? nearestFree(double x, double z, double r, {double maxDist = 4, List<NavCircle>? others}) {
    if (_freeWith(x, z, r, others)) return NavPoint(x, z);
    final s = cellSize;
    final maxK = (maxDist / s).ceil();
    double bestD = double.infinity;
    double bx = 0, bz = 0;
    for (var k = 1; k <= maxK; k++) {
      if (k * s > bestD) break;
      for (var i = -k; i <= k; i++) {
        for (var j = -k; j <= k; j++) {
          if (i.abs() != k && j.abs() != k) continue; // chỉ viền vòng k
          final px = x + i * s, pz = z + j * s;
          final d = math.sqrt((i * i + j * j).toDouble()) * s;
          if (d >= bestD || d > maxDist) continue;
          if (_freeWith(px, pz, r, others)) {
            bestD = d;
            bx = px;
            bz = pz;
          }
        }
      }
    }
    return bestD.isFinite ? NavPoint(bx, bz) : null;
  }

  // ---- Vật bay (hình cầu – hộp 3D) ----------------------------------------------------------------------------

  /// Hộp đầu tiên mà hình cầu (x, y, z, r) vừa **chạm mới** — chạm ở vị trí mới nhưng chưa chạm ở vị trí cũ
  /// (ox, oy, oz). -1 nếu không có. Vật phóng ra từ trong hộp (xuất phát chồng lên) thì hộp đó bị bỏ qua tới khi ra
  /// ngoài.
  int firstEntered(double ox, double oy, double oz, double x, double y, double z, double r) {
    final z0 = _bz(z - r), z1 = _bz(z + r), x0 = _bx(x - r), x1 = _bx(x + r);
    for (var bz = z0; bz <= z1; bz++) {
      for (var bx = x0; bx <= x1; bx++) {
        final b = bz * _bw + bx;
        for (var k = _bStart[b]; k < _bStart[b + 1]; k++) {
          final i = _bItems[k];
          if (_sphereHits(i, x, y, z, r) && !_sphereHits(i, ox, oy, oz, r)) return i;
        }
      }
    }
    return -1;
  }

  /// Hình cầu (x, y, z, r) đang chồng lên hộp nào đó không.
  bool sphereBlocked(double x, double y, double z, double r) => firstEntered(1e9, 1e9, 1e9, x, y, z, r) >= 0;

  bool _sphereHits(int i, double x, double y, double z, double r) {
    final dx = x < _minX[i] ? _minX[i] - x : (x > _maxX[i] ? x - _maxX[i] : 0.0);
    final dy = y < _minY[i] ? _minY[i] - y : (y > _maxY[i] ? y - _maxY[i] : 0.0);
    final dz = z < _minZ[i] ? _minZ[i] - z : (z > _maxZ[i] ? z - _maxZ[i] : 0.0);
    return dx * dx + dy * dy + dz * dz < r * r - 1e-9;
  }

  // ---- A* ----------------------------------------------------------------------------------------------------

  /// Kích thước ô lưới A* mặc định (m).
  static const double cell = 0.1;

  /// Kích thước ô lưới A* của lưới này (m).
  final double cellSize;

  final int _gw, _gh;

  /// Khoảng hở mặc định khi tìm đường (m).
  static const double defaultClearance = 0.3;

  Uint8List? _free;
  double _freeClearance = -1;
  Float32List? _gCost;
  Int32List? _parent, _seen, _closed;
  int _gen = 0;
  Float64List _heapKey = Float64List(4096);
  Int32List _heapVal = Int32List(4096);
  int _heapN = 0;

  void _ensureGrid(double clearance) {
    if (_free != null && (clearance - _freeClearance).abs() < 1e-9) return;
    final f = _free ??= Uint8List(_gw * _gh);
    for (var iz = 0; iz < _gh; iz++) {
      for (var ix = 0; ix < _gw; ix++) {
        f[iz * _gw + ix] = canStand(_cx(ix), _cz(iz), clearance) ? 1 : 0;
      }
    }
    _freeClearance = clearance;
    _gCost ??= Float32List(_gw * _gh);
    _parent ??= Int32List(_gw * _gh);
    _seen ??= Int32List(_gw * _gh);
    _closed ??= Int32List(_gw * _gh);
  }

  double _cx(int ix) => minX + (ix + 0.5) * cellSize;
  double _cz(int iz) => minZ + (iz + 0.5) * cellSize;
  int _ix(double x) => ((x - minX) / cellSize).floor().clamp(0, _gw - 1);
  int _iz(double z) => ((z - minZ) / cellSize).floor().clamp(0, _gh - 1);

  /// Ô trống gần ô (ix, iz) nhất (vòng Chebyshev tăng dần, chọn khoảng cách Euclid nhỏ nhất); -1 nếu không có trong
  /// [maxCells] ô.
  int _nearestFreeCell(int ix, int iz, int maxCells) {
    final f = _free!;
    if (f[iz * _gw + ix] == 1) return iz * _gw + ix;
    var best = -1;
    var bestD = double.infinity;
    for (var k = 1; k <= maxCells; k++) {
      if (k > bestD) break;
      for (var i = -k; i <= k; i++) {
        for (var j = -k; j <= k; j++) {
          if (i.abs() != k && j.abs() != k) continue;
          final cx = ix + i, cz = iz + j;
          if (cx < 0 || cz < 0 || cx >= _gw || cz >= _gh) continue;
          if (f[cz * _gw + cx] != 1) continue;
          final d = math.sqrt((i * i + j * j).toDouble());
          if (d < bestD) {
            bestD = d;
            best = cz * _gw + cx;
          }
        }
      }
    }
    return best;
  }

  /// Đường đi A* (8 hướng, không cắt góc) có khoảng hở [clearance] rồi làm thẳng (string pulling). Trả các điểm
  /// đến, **không gồm** điểm xuất phát, điểm cuối là đích (hoặc ô trống gần đích nhất nếu đích bị chặn). null nếu
  /// không có đường. Chỉ gọi khi cần (cấp phát một danh sách mỗi lần).
  List<NavPoint>? findPath(double fromX, double fromZ, double toX, double toZ, {double clearance = defaultClearance}) {
    _ensureGrid(clearance);
    final f = _free!;
    final sCell = _nearestFreeCell(_ix(fromX), _iz(fromZ), 12);
    if (sCell < 0) return null;
    // Đích: giữ nguyên nếu đứng được với khoảng hở, nếu không thì dời tới ô trống gần nhất.
    var goalX = toX, goalZ = toZ;
    var gCell = _iz(toZ) * _gw + _ix(toX);
    if (f[gCell] != 1 || !canStand(toX, toZ, clearance)) {
      gCell = _nearestFreeCell(_ix(toX), _iz(toZ), 40);
      if (gCell < 0) return null;
      goalX = _cx(gCell % _gw);
      goalZ = _cz(gCell ~/ _gw);
    }
    final cells = _astar(sCell, gCell);
    if (cells == null) return null;

    // Điểm: xuất phát thật, tâm các ô giữa, đích.
    final pts = <NavPoint>[NavPoint(fromX, fromZ)];
    for (var i = 1; i < cells.length - 1; i++) {
      pts.add(NavPoint(_cx(cells[i] % _gw), _cz(cells[i] ~/ _gw)));
    }
    pts.add(NavPoint(goalX, goalZ));
    // String pulling tham lam.
    final out = <NavPoint>[];
    var i = 0;
    final last = pts.length - 1;
    while (i < last) {
      var j = last;
      while (j > i + 1 && !_lineFree(pts[i], pts[j], clearance)) {
        j--;
      }
      out.add(pts[j]);
      i = j;
    }
    return out;
  }

  /// Đoạn thẳng a→b đi được với bán kính [r] (lấy mẫu 0,1 m; bỏ qua các mẫu sát đầu mút nếu đầu mút không đạt
  /// khoảng hở — vd. điểm xuất phát sát tường).
  bool _lineFree(NavPoint a, NavPoint b, double r) {
    final dx = b.x - a.x, dz = b.z - a.z;
    final len = math.sqrt(dx * dx + dz * dz);
    final n = math.max(1, (len / 0.1).ceil());
    final aOk = canStand(a.x, a.z, r), bOk = canStand(b.x, b.z, r);
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final d = t * len;
      if (!aOk && d < 0.2) continue;
      if (!bOk && len - d < 0.2) continue;
      if (!canStand(a.x + dx * t, a.z + dz * t, r)) return false;
    }
    return true;
  }

  static const double _diag = 1.41421356;

  List<int>? _astar(int start, int goal) {
    final f = _free!, g = _gCost!, parent = _parent!, seen = _seen!, closed = _closed!;
    if (++_gen > 0x3fffffff) {
      seen.fillRange(0, seen.length, 0);
      closed.fillRange(0, closed.length, 0);
      _gen = 1;
    }
    final gx = goal % _gw, gz = goal ~/ _gw;
    double h(int ix, int iz) {
      final dx = (ix - gx).abs(), dz = (iz - gz).abs();
      return (dx + dz) + (_diag - 2) * math.min(dx, dz);
    }

    _heapN = 0;
    g[start] = 0;
    seen[start] = _gen;
    parent[start] = -1;
    _push(h(start % _gw, start ~/ _gw), start);
    var found = false;
    while (_heapN > 0) {
      final cur = _pop();
      if (closed[cur] == _gen) continue;
      closed[cur] = _gen;
      if (cur == goal) {
        found = true;
        break;
      }
      final cx = cur % _gw, cz = cur ~/ _gw;
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          final nx = cx + dx, nz = cz + dz;
          if (nx < 0 || nz < 0 || nx >= _gw || nz >= _gh) continue;
          final ni = nz * _gw + nx;
          if (f[ni] != 1 || closed[ni] == _gen) continue;
          final diagonal = dx != 0 && dz != 0;
          if (diagonal && (f[cz * _gw + nx] != 1 || f[nz * _gw + cx] != 1)) continue; // không cắt góc
          final ng = g[cur] + (diagonal ? _diag : 1.0);
          if (seen[ni] != _gen || ng < g[ni]) {
            seen[ni] = _gen;
            g[ni] = ng;
            parent[ni] = cur;
            _push(ng + h(nx, nz), ni);
          }
        }
      }
    }
    if (!found) return null;
    final rev = <int>[];
    for (var c = goal; c >= 0; c = parent[c]) {
      rev.add(c);
    }
    return rev.reversed.toList();
  }

  void _push(double key, int val) {
    if (_heapN == _heapKey.length) {
      _heapKey = Float64List(_heapN * 2)..setRange(0, _heapN, _heapKey);
      _heapVal = Int32List(_heapN * 2)..setRange(0, _heapN, _heapVal);
    }
    var i = _heapN++;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_heapKey[p] <= key) break;
      _heapKey[i] = _heapKey[p];
      _heapVal[i] = _heapVal[p];
      i = p;
    }
    _heapKey[i] = key;
    _heapVal[i] = val;
  }

  int _pop() {
    final top = _heapVal[0];
    final key = _heapKey[--_heapN];
    final val = _heapVal[_heapN];
    var i = 0;
    while (true) {
      var c = 2 * i + 1;
      if (c >= _heapN) break;
      if (c + 1 < _heapN && _heapKey[c + 1] < _heapKey[c]) c++;
      if (_heapKey[c] >= key) break;
      _heapKey[i] = _heapKey[c];
      _heapVal[i] = _heapVal[c];
      i = c;
    }
    if (_heapN > 0) {
      _heapKey[i] = key;
      _heapVal[i] = val;
    }
    return top;
  }
}
