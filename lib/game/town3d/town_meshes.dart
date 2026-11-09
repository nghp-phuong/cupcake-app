import 'dart:math' as math;

import '../shop3d/chibi/chibi_mesh.dart';

/// Lưới động nhỏ của lớp phố (thành phố V3) dựng bằng code cùng phong cách chibi: khối tròn trịa, màu đỉnh (dùng chung
/// MỘT material chibi). Dart thuần. Gốc lưới ở **đáy giữa**, mặt trước +z; cảnh đặt `T(x, y, z) · Ry(yaw)`.
abstract final class TownMeshes {
  /// Bảng màu món (sRGB).
  static const int plate = 0xFFF8EE;
  static const int plateRim = 0xA8DCC8; // viền bạc hà
  static const int bowl = 0xFFF4E6;
  static const int bowlBand = 0xF49AB0;
  static const int soup = 0xF2B36B;
  static const int fish = 0xF7C6A0;
  static const int herb = 0x86BE78;
  static const int egg = 0xFFD27A;
  static const int ketchup = 0xE86A5C;
  static const int rice = 0xFFFDF7;
  static const int curry = 0xC98B4E;
  static const int carrot = 0xF39A4E;
  static const int pea = 0x9CCB74;
  static const int broth = 0xF3D9A8;
  static const int noodle = 0xFBE7B0;
  static const int shrimp = 0xF5998C;
  static const int spoon = 0xD8CFC4;

  /// Ngân sách tam giác mỗi món ("vài trăm").
  static const int maxTriangles = 600;

  /// Biểu tượng két đầy: kem bóng nói, xu vàng bơ, cạnh xu caramel nhạt.
  static const int bubble = 0xFFF4E6;
  static const int coin = 0xFFD27A;
  static const int coinEdge = 0xE0A84E;

  /// Ngân sách tam giác của biểu tượng két đầy (docs/v3/city-gd4-spec.md §5: "khoảng 150").
  static const int tillFullMaxTriangles = 200;

  /// Biểu tượng két đầy trên sân chi nhánh (docs/v3/city-gd4-spec.md §5): bóng nói kem dẹt (mặt phẳng xy, đuôi chĩa
  /// xuống trái) + chồng 3 đồng xu nằm ngang xuyên qua bóng — thấy được cả từ camera phố (+z) lẫn góc cận (−z). Gốc ở
  /// **tâm bóng** (khác món ăn); cảnh đặt ở y ≈ 2,3 và lắc quanh trục z.
  static ChibiMesh tillFull() {
    final b = ChibiMeshBuilder()
      ..ellipsoid(0, 0, 0, 0.36, 0.27, 0.085, bubble, lat: 3, lon: 6)
      ..frustum(-0.12, -0.18, 0, -0.24, -0.41, 0, 0.085, 0, bubble, radial: 4, capB: false);
    for (var i = 0; i < 3; i++) {
      final x = 0.015 * (i - 1), y = -0.085 + i * 0.055;
      b.frustum(x, y, 0, x, y + 0.042, 0, 0.145, 0.145, i.isEven ? coin : coinEdge, radial: 6);
    }
    return b.build();
  }

  /// Món ăn đặt trên bàn hiên quán "Bếp Hải Đăng" theo id món (`RestaurantMenu`); id lạ → đĩa trứng chiên cơm.
  static ChibiMesh dish(String dishId) => switch (dishId) {
        'fish_soup' => fishSoup(),
        'veggie_curry' => veggieCurry(),
        'seafood_noodles' => seafoodNoodles(),
        _ => omeletteRice(),
      };

  /// Đĩa dẹt Ø0,26 m viền bạc hà (đáy ở y = 0, mặt đĩa ở y ≈ 0,018).
  static void _plate(ChibiMeshBuilder b) {
    b
      ..frustum(0, 0, 0, 0, 0.016, 0, 0.09, 0.13, plate, radial: 16)
      ..torus(0, 0.017, 0, 0.125, 0.007, plateRim, basis: _flat, segments: 16, tube: 3);
  }

  /// Bát Ø0,2 m (miệng ở y = 0,075) có dải hồng dâu; [fill] = màu nước dùng.
  static void _bowl(ChibiMeshBuilder b, int fill) {
    b
      ..frustum(0, 0, 0, 0, 0.075, 0, 0.055, 0.1, bowl, radial: 14)
      ..frustum(0, 0.045, 0, 0, 0.055, 0, 0.086, 0.092, bowlBand, radial: 14, capA: false, capB: false)
      ..torus(0, 0.075, 0, 0.098, 0.006, bowl, basis: _flat, segments: 14, tube: 3)
      ..ellipsoid(0, 0.068, 0, 0.092, 0.008, 0.092, fill, lat: 2, lon: 12);
  }

  /// Mặt phẳng vòng xuyến nằm ngang (trục vòng = y).
  static final _flat = ChibiBasis.euler(math.pi / 2, 0, 0);

  /// Súp cá: bát nước dùng cam nhạt, lát cá, rau thơm, thìa.
  static ChibiMesh fishSoup() {
    final b = ChibiMeshBuilder();
    _bowl(b, soup);
    b
      ..ellipsoid(-0.02, 0.078, 0.01, 0.042, 0.012, 0.026, fish, lat: 3, lon: 8)
      ..ellipsoid(0.035, 0.077, -0.025, 0.03, 0.01, 0.02, fish, lat: 3, lon: 8)
      ..sphere(0.03, 0.08, 0.03, 0.009, herb, lat: 2, lon: 4)
      ..sphere(-0.045, 0.08, -0.03, 0.009, herb, lat: 2, lon: 4)
      ..capsule(0.06, 0.08, 0.05, 0.13, 0.05, 0.1, 0.008, 0.006, spoon, radial: 5, capBands: 1);
    return b.build();
  }

  /// Cơm trứng chiên: đĩa, trứng bọc vàng bơ hình gối, sốt cà chua ngoằn ngoèo, lá rau.
  static ChibiMesh omeletteRice() {
    final b = ChibiMeshBuilder();
    _plate(b);
    b.ellipsoid(0, 0.045, 0, 0.085, 0.034, 0.055, egg, lat: 5, lon: 12);
    for (var i = 0; i < 3; i++) {
      final x0 = -0.05 + i * 0.035;
      b.capsule(x0, 0.079, -0.015, x0 + 0.03, 0.079, 0.015, 0.006, 0.006, ketchup, radial: 4, capBands: 1);
    }
    b
      ..sphere(0.08, 0.026, 0.06, 0.016, herb, lat: 3, lon: 5)
      ..sphere(0.095, 0.024, 0.045, 0.012, herb, lat: 3, lon: 5);
    return b.build();
  }

  /// Cà ri rau: đĩa, gò cơm trắng, sốt cà ri, cà rốt, đậu Hà Lan.
  static ChibiMesh veggieCurry() {
    final b = ChibiMeshBuilder();
    _plate(b);
    b
      ..ellipsoid(-0.035, 0.03, 0, 0.055, 0.035, 0.06, rice, lat: 4, lon: 10)
      ..ellipsoid(0.045, 0.022, 0, 0.06, 0.012, 0.08, curry, lat: 3, lon: 10);
    for (final (x, z) in const [(0.04, 0.03), (0.06, -0.03), (0.025, -0.04)]) {
      b.box(x, 0.036, z, 0.018, 0.016, 0.018, carrot);
    }
    for (final (x, z) in const [(0.07, 0.02), (0.035, 0.0), (0.075, -0.045)]) {
      b.sphere(x, 0.037, z, 0.008, pea, lat: 2, lon: 4);
    }
    return b.build();
  }

  /// Mì hải sản: bát nước dùng, sợi mì, hai con tôm, nửa quả trứng.
  static ChibiMesh seafoodNoodles() {
    final b = ChibiMeshBuilder();
    _bowl(b, broth);
    for (var i = 0; i < 3; i++) {
      b.torus(0, 0.076 + i * 0.002, 0, 0.03 + i * 0.018, 0.006, noodle, basis: _flat, segments: 10, tube: 3);
    }
    for (final s in const [1.0, -1.0]) {
      b.torus(s * 0.045, 0.085, -0.02, 0.022, 0.009, shrimp,
          basis: ChibiBasis.euler(0, s * 0.6, 0), a0: 0.2, a1: math.pi * 1.3, segments: 7, tube: 4);
    }
    b
      ..ellipsoid(-0.01, 0.082, 0.045, 0.026, 0.014, 0.02, rice, lat: 3, lon: 8)
      ..ellipsoid(-0.01, 0.09, 0.045, 0.012, 0.006, 0.01, egg, lat: 2, lon: 6)
      ..sphere(0.04, 0.083, 0.04, 0.008, herb, lat: 2, lon: 4);
    return b.build();
  }
}
