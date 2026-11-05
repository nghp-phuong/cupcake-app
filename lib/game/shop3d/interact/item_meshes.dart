import 'dart:math' as math;

import '../chibi/chibi_mesh.dart';
import 'shop3d_items.dart';

/// Lưới 3 loại vật tương tác (V3, đặc tả 2.2) dựng bằng code cùng phong cách chibi: khối tròn trịa, màu đỉnh (dùng
/// chung MỘT material chibi). Dart thuần. Gốc lưới ở **đáy giữa** vật (khớp quy ước [ShopItem.y] = độ cao đáy), mặt
/// trước +z; cảnh chỉ việc đặt `T(x, y, z) · Ry(yaw)` mỗi khung.
abstract final class Shop3dItemMeshes {
  /// Bảng màu (sRGB): hồng dâu, bạc hà, kem, nâu caramel, vàng bơ.
  static const int strawberry = 0xF49AB0;
  static const int strawberryDeep = 0xE27A96;
  static const int strawberryLight = 0xF9C3D0;
  static const int mint = 0xA8DCC8;
  static const int mintDeep = 0x86C7AE;
  static const int cream = 0xFFF4E6;
  static const int caramel = 0xB9805A;
  static const int butter = 0xFFD27A;
  static const int sack = 0xF1E4CC;
  static const int sackShade = 0xE2D1B1;

  static ChibiMesh of(ItemKind kind) => switch (kind) {
        ItemKind.yarn => yarn(),
        ItemKind.cakeBox => cakeBox(),
        ItemKind.flourSack => flourSack(),
      };

  /// Cuộn len Ø0,14 m hồng dâu, quấn vài vòng sợi đậm / nhạt, một đầu sợi thò ra.
  static ChibiMesh yarn() {
    final r = ItemSpec.yarn.radius;
    final b = ChibiMeshBuilder()..sphere(0, r, 0, r, strawberry, lat: 8, lon: 12);
    // Các vòng sợi quấn (xuyến mảnh sát mặt cầu, nhiều góc).
    for (final (rx, ry, rz, c) in const [
      (0.0, 0.0, 0.0, strawberryDeep),
      (1.1, 0.0, 0.3, strawberryLight),
      (0.5, 1.2, 0.0, strawberryDeep),
      (-0.7, 0.4, 1.0, strawberryLight),
    ]) {
      b.torus(0, r, 0, r * 0.93, r * 0.09, c, basis: ChibiBasis.euler(rx, ry, rz), segments: 16, tube: 4);
    }
    // Đầu sợi thò ra, cong xuống sàn.
    b.capsule(r * 0.7, r * 0.55, r * 0.55, r * 1.35, r * 0.08, r * 0.9, r * 0.07, r * 0.06, strawberryDeep,
        radial: 6, capBands: 1);
    return b.build();
  }

  /// Hộp bánh bạc hà ~0,22 × 0,17 × 0,22 m, nắp nhô nhẹ, ruy băng kem chéo hai chiều và nơ trên nắp.
  static ChibiMesh cakeBox() {
    const w = 0.22, h = 0.17;
    final b = ChibiMeshBuilder()
      ..box(0, h * 0.45, 0, w, h * 0.9, w, mint)
      // Nắp rộng hơn thân 1 cm.
      ..box(0, h * 0.93, 0, w + 0.012, h * 0.16, w + 0.012, mintDeep)
      // Ruy băng kem: hai dải vòng quanh hộp.
      ..box(0, h * 0.5, 0, w + 0.016, h + 0.012, 0.035, cream)
      ..box(0, h * 0.5, 0, 0.035, h + 0.012, w + 0.016, cream);
    // Nơ: hai cánh + nút giữa.
    for (final s in const [1.0, -1.0]) {
      b.ellipsoid(s * 0.035, h + 0.03, 0, 0.038, 0.024, 0.018, cream,
          basis: ChibiBasis.euler(0, 0, s * 0.35), lat: 5, lon: 8);
    }
    b.sphere(0, h + 0.026, 0, 0.016, strawberry, lat: 4, lon: 6);
    return b.build();
  }

  /// Bao bột tròn trịa (vải kem), miệng túm dây caramel, nhãn vàng bơ hình bông lúa đơn giản.
  static ChibiMesh flourSack() {
    final r = ItemSpec.flourSack.radius;
    final b = ChibiMeshBuilder()
      ..ellipsoid(0, r * 1.15, 0, r, r * 1.15, r * 0.72, sack, lat: 9, lon: 14)
      // Đáy phẳng hơn: một đĩa bóng nhẹ ở dưới.
      ..ellipsoid(0, r * 0.18, 0, r * 0.92, r * 0.2, r * 0.68, sackShade, lat: 4, lon: 12)
      // Miệng túm + dây buộc.
      ..frustum(0, r * 2.15, 0, 0, r * 2.55, 0, r * 0.22, r * 0.34, sackShade, radial: 10)
      ..torus(0, r * 2.2, 0, r * 0.24, r * 0.06, caramel, basis: ChibiBasis.euler(math.pi / 2, 0, 0), segments: 12);
    // Nhãn phía trước.
    b.dome(0, r * 1.2, r * 0.7, r * 0.42, r * 0.36, 0.008, butter, segments: 14);
    for (final s in const [1.0, -1.0]) {
      b.ellipsoid(s * r * 0.1, r * 1.22, r * 0.73, r * 0.06, r * 0.16, 0.01, caramel,
          basis: ChibiBasis.euler(0, 0, s * 0.5), lat: 3, lon: 6);
    }
    return b.build();
  }
}
