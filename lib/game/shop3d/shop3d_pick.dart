import 'dart:math' as math;

import 'shop3d_layout.dart';
import 'shop3d_math.dart';

/// Chạm chọn vật + chiếu 3D → màn hình, tính hoàn toàn phía Dart (Dart thuần, không phụ thuộc engine).
///
/// Không dùng `View.pick` của thermion: trên web nó làm treo luồng chính (docs/v3/thermion-api-notes.md mục 7).
/// Camera do ta tự đặt (`lookAt(eye, focus: target)`, up = +y, góc nhìn dọc cố định qua tiêu cự) nên dựng lại được
/// tia qua điểm chạm và phép chiếu mà không cần hỏi Filament.

/// Hệ trục camera nhìn từ [eye] vào [target] (up = +y), góc nhìn dọc [fovDeg], khung [viewportWidth]×[viewportHeight]
/// (pixel logic, gốc trên-trái). Dựng lại mỗi khi camera đổi bằng [set] — không cấp phát.
class Shop3dCameraBasis {
  double eyeX = 0, eyeY = 0, eyeZ = 0;
  double fx = 0, fy = 0, fz = -1; // forward
  double rx = 1, ry = 0, rz = 0; // right
  double ux = 0, uy = 1, uz = 0; // up
  double tanHalf = 1, aspect = 1, width = 1, height = 1;

  void set(Vec3 eye, Vec3 target, double fovDeg, double viewportWidth, double viewportHeight) {
    eyeX = eye.x;
    eyeY = eye.y;
    eyeZ = eye.z;
    var dx = target.x - eye.x, dy = target.y - eye.y, dz = target.z - eye.z;
    var l = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (l < 1e-9) {
      dx = 0;
      dy = 0;
      dz = -1;
      l = 1;
    }
    fx = dx / l;
    fy = dy / l;
    fz = dz / l;
    // right = forward × (0,1,0)
    var cx = -fz, cz = fx;
    final cl = math.sqrt(cx * cx + cz * cz);
    if (cl < 1e-9) {
      cx = 1;
      cz = 0;
    } else {
      cx /= cl;
      cz /= cl;
    }
    rx = cx;
    ry = 0;
    rz = cz;
    // up = right × forward
    ux = ry * fz - rz * fy;
    uy = rz * fx - rx * fz;
    uz = rx * fy - ry * fx;
    tanHalf = math.tan(fovDeg * math.pi / 360);
    width = viewportWidth < 1 ? 1 : viewportWidth;
    height = viewportHeight < 1 ? 1 : viewportHeight;
    aspect = width / height;
  }

  /// Tia từ mắt qua điểm ([px],[py]) trên màn: ghi vào [out] (hướng đã chuẩn hoá) và trả về chính [out].
  Shop3dRay rayThrough(double px, double py, [Shop3dRay? out]) {
    final ray = out ?? Shop3dRay();
    final nx = (2 * px / width - 1) * tanHalf * aspect;
    final ny = (1 - 2 * py / height) * tanHalf;
    var dx = fx + rx * nx + ux * ny, dy = fy + ry * nx + uy * ny, dz = fz + rz * nx + uz * ny;
    final l = math.sqrt(dx * dx + dy * dy + dz * dz);
    dx /= l;
    dy /= l;
    dz /= l;
    ray
      ..ox = eyeX
      ..oy = eyeY
      ..oz = eyeZ
      ..dx = dx
      ..dy = dy
      ..dz = dz;
    return ray;
  }

  /// Chiếu điểm thế giới lên màn (pixel logic). null nếu điểm nằm sau (hoặc sát) mắt.
  ({double x, double y})? project(double x, double y, double z) {
    final px = x - eyeX, py = y - eyeY, pz = z - eyeZ;
    final depth = px * fx + py * fy + pz * fz;
    if (depth <= 1e-3) return null;
    final sx = (px * rx + py * ry + pz * rz) / (depth * tanHalf * aspect);
    final sy = (px * ux + py * uy + pz * uz) / (depth * tanHalf);
    return (x: (sx + 1) * width / 2, y: (1 - sy) * height / 2);
  }
}

/// Tia: gốc (o) + hướng đơn vị (d).
class Shop3dRay {
  double ox = 0, oy = 0, oz = 0;
  double dx = 0, dy = 0, dz = -1;

  /// Khoảng cách t ≥ 0 tới hộp [minX..maxX]×[minY..maxY]×[minZ..maxZ] (phương pháp slab); null nếu trượt. Gốc tia
  /// nằm trong hộp → 0.
  double? hitAabb(double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
    var tMin = 0.0, tMax = double.infinity;
    bool slab(double o, double d, double lo, double hi) {
      if (d.abs() < 1e-12) return o >= lo && o <= hi;
      var t0 = (lo - o) / d, t1 = (hi - o) / d;
      if (t0 > t1) {
        final t = t0;
        t0 = t1;
        t1 = t;
      }
      if (t0 > tMin) tMin = t0;
      if (t1 < tMax) tMax = t1;
      return tMin <= tMax;
    }

    if (!slab(ox, dx, minX, maxX) || !slab(oy, dy, minY, maxY) || !slab(oz, dz, minZ, maxZ)) return null;
    return tMin;
  }
}

enum Shop3dPickKind { prop, actor }

/// Một hộp chạm được, thuộc về vật thể / nhân vật [id].
class Shop3dPickBox {
  const Shop3dPickBox(this.id, this.kind, this.minX, this.minY, this.minZ, this.maxX, this.maxY, this.maxZ);

  /// Hộp bao của một khối [part] của vật thể [propId].
  factory Shop3dPickBox.ofPart(String propId, Shop3dPart part) =>
      Shop3dPickBox(propId, Shop3dPickKind.prop, part.minX, part.minY, part.minZ, part.maxX, part.maxY, part.maxZ);

  final String id;
  final Shop3dPickKind kind;
  final double minX, minY, minZ, maxX, maxY, maxZ;

  double get centerX => (minX + maxX) / 2;
  double get centerZ => (minZ + maxZ) / 2;
}

/// Hộp gần mắt nhất mà [ray] cắt; null nếu không trúng gì.
Shop3dPickBox? pickNearest(Shop3dRay ray, Iterable<Shop3dPickBox> boxes) {
  Shop3dPickBox? best;
  var bestT = double.infinity;
  for (final b in boxes) {
    final t = ray.hitAabb(b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ);
    if (t != null && t < bestT) {
      bestT = t;
      best = b;
    }
  }
  return best;
}

/// Hộp chạm cho vật thể [prop]: mỗi khối một hộp (chính xác hơn một hộp bao chung — chạm vào khe giữa bàn và ghế
/// không trúng cả bộ). Bỏ tấm kính mỏng gần như trong suốt (alpha ≤ 0,35, cạnh nhỏ nhất < 5 cm, ví dụ kệ kính trong
/// tủ: chạm qua thì trúng bánh / khung phía sau); khối kính (vách + nắp tủ bánh, nắp trong suốt từ 04/11) vẫn chạm được.
/// Vật phủ sàn / không chạm được ([Shop3dProp.pickable] = false) không có hộp.
Iterable<Shop3dPickBox> pickBoxesForProp(Shop3dProp prop) sync* {
  if (prop.flat || !prop.pickable) return;
  for (final part in prop.parts) {
    if (part.alpha <= 0.35 && math.min(part.sx, math.min(part.sy, part.sz)) < 0.05) continue;
    yield Shop3dPickBox.ofPart(prop.id, part);
  }
}

/// Đỉnh trên-giữa của nhóm [boxes] cùng [id] (để đặt nhãn); null nếu không có.
({double x, double y, double z})? topCenterOf(String id, Iterable<Shop3dPickBox> boxes) {
  var minX = double.infinity, maxX = -double.infinity, minZ = double.infinity, maxZ = -double.infinity;
  var maxY = -double.infinity;
  for (final b in boxes) {
    if (b.id != id) continue;
    minX = math.min(minX, b.minX);
    maxX = math.max(maxX, b.maxX);
    minZ = math.min(minZ, b.minZ);
    maxZ = math.max(maxZ, b.maxZ);
    maxY = math.max(maxY, b.maxY);
  }
  if (maxY == -double.infinity) return null;
  return (x: (minX + maxX) / 2, y: maxY, z: (minZ + maxZ) / 2);
}
