import 'dart:math' as math;

/// Vec3 nhỏ, thay `vector_math` (gói này chỉ là phụ thuộc gián tiếp, chưa khai báo trong pubspec nên không import
/// thẳng được). Có thể thay: trường x/y/z là mutable để camera tái dùng, không cấp phát mỗi khung hình.
class Vec3 {
  Vec3([this.x = 0, this.y = 0, this.z = 0]);

  double x;
  double y;
  double z;

  void setValues(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void copyFrom(Vec3 o) => setValues(o.x, o.y, o.z);

  Vec3 clone() => Vec3(x, y, z);

  double distanceTo(Vec3 o) {
    final dx = x - o.x, dy = y - o.y, dz = z - o.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  @override
  String toString() => 'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Các mặt bao quanh phòng. Quy ước nhìn từ camera mặc định (yaw 0, đứng ở +z nhìn về -z): `front` là tường gần
/// camera (cửa sổ + cửa ra vào, z = maxZ), `back` là tường bếp (z = minZ), `right` là x = maxX, `left` là x = minX.
enum RoomWall {
  back,
  front,
  left,
  right,
  ceiling;

  /// Bit trong mặt nạ của [RoomBox.hiddenWallMask].
  int get bit => 1 << index;
}

/// Hộp phòng (AABB, mét, y hướng lên, sàn y = 0). Mặt trong của tường nằm đúng trên các biên này.
class RoomBox {
  const RoomBox({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
  });

  final double minX, maxX, minY, maxY, minZ, maxZ;

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get depth => maxZ - minZ;

  bool contains(double x, double y, double z, {double margin = 0}) =>
      x >= minX - margin &&
      x <= maxX + margin &&
      y >= minY - margin &&
      y <= maxY + margin &&
      z >= minZ - margin &&
      z <= maxZ + margin;

  /// Khoảng cách [p] vượt ra **ngoài** mặt [w] (dương = ở ngoài mặt đó, âm = ở trong).
  double outwardDistance(RoomWall w, Vec3 p) {
    switch (w) {
      case RoomWall.back:
        return minZ - p.z;
      case RoomWall.front:
        return p.z - maxZ;
      case RoomWall.left:
        return minX - p.x;
      case RoomWall.right:
        return p.x - maxX;
      case RoomWall.ceiling:
        return p.y - maxY;
    }
  }

  /// Độ mờ (0..1) nên dùng cho mặt [w] khi camera ở [eye]: 1 khi camera ở sâu trong phòng (cách mặt ≥ [margin]+[fade]),
  /// 0 khi camera đã ra tới ngoài (cách mặt < [margin] về phía trong, hoặc ở ngoài). 0 nghĩa là ẩn hẳn.
  double wallOpacity(RoomWall w, Vec3 eye, {double margin = 0, double fade = 1}) {
    final inside = -outwardDistance(w, eye) - margin;
    if (inside <= 0) return 0;
    if (fade <= 0 || inside >= fade) return 1;
    return inside / fade;
  }

  /// Mặt nạ bit các mặt nằm giữa camera và phòng (cảnh nên ẩn / làm mờ). Không cấp phát.
  int hiddenWallMask(Vec3 eye, {double margin = 0}) {
    var mask = 0;
    for (final w in RoomWall.values) {
      if (outwardDistance(w, eye) > -margin) mask |= w.bit;
    }
    return mask;
  }

  /// Danh sách các mặt cần ẩn (bản tiện dụng, có cấp phát danh sách).
  List<RoomWall> wallsFacing(Vec3 eye, {double margin = 0}) {
    final mask = hiddenWallMask(eye, margin: margin);
    return [
      for (final w in RoomWall.values)
        if (mask & w.bit != 0) w,
    ];
  }
}
