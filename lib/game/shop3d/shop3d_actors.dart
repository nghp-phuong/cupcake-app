import 'dart:math' as math;
import 'dart:typed_data';

import 'shop3d_layout.dart';
import 'shop3d_math.dart';

/// Nhân vật billboard trong cảnh tiệm 3D: ảnh 2D Gemini (`assets/characters/<id>_<nét mặt>.webp`, 480×640, nền trong
/// suốt) dán lên tấm đứng luôn quay về camera (chỉ quanh trục y). Dart thuần: chọn chỗ đứng, kích thước thật, xử lý
/// điểm ảnh (cắt viền trong suốt, loang màu mép, mipmap). Không có hình nhân vật vẽ bằng code.

enum Shop3dActorRole { customer, staff }

/// Một nhân vật đứng mẫu (GĐ a). GĐ (b) sẽ thay bằng khách / nhân viên thật của `LevelSession`.
class Shop3dActor {
  const Shop3dActor(this.id, this.sprite, this.role, this.x, this.z, {this.expression = 'neutral', this.requires});

  /// Id duy nhất trong cảnh (cũng là nhãn khi chạm chọn).
  final String id;

  /// Id ảnh: `assets/characters/<sprite>_<expression>.webp`.
  final String sprite;
  final String expression;
  final Shop3dActorRole role;

  /// Chân chạm sàn tại (x, 0, z).
  final double x, z;

  /// Như `Shop3dProp.requires`: null = luôn có.
  final String? requires;

  String get assetPath => Shop3dActors.assetPath(sprite, expression);

  bool enabledFor(Set<String> owned) => requires == null || owned.contains(requires);
}

abstract final class Shop3dActors {
  static const spriteDir = 'assets/characters/';

  static String assetPath(String sprite, String expression) => '$spriteDir${sprite}_$expression.webp';

  /// Tỉ lệ ảnh → mét. Thân người trong ảnh 480×640 cao ~560 px (đo vùng alpha của khách thường: 561 px) ↔ người lớn
  /// [Shop3dLayout.personHeight] = 1,6 m. Một tỉ lệ chung cho mọi ảnh để giữ chênh lệch chiều cao giữa các nhân vật
  /// như trong tranh (ông Hòa, khách VIP cao hơn chút), và đúng tỉ lệ thật so với quầy ~1 m.
  static const double pixelsPerMeter = 561 / Shop3dLayout.personHeight;

  /// Khách đứng cạnh bàn khu ngồi: chưa có ảnh tư thế ngồi, đặt ảnh đứng lên ghế sẽ trông như đứng trên ghế. Đứng ở
  /// phía cửa sổ của ghế, cách tâm ghế 0,62 m (ngoài mép ghế 0,21 m + nửa bề ngang người).
  static const double tableSideOffsetZ = 0.62;

  /// Dàn nhân vật mẫu: 5 khách (2 ở quầy + 3 hàng chờ), 2 khách bên bàn (khi có `cafe_tables`), 2 nhân viên.
  static final List<Shop3dActor> all = [
    Shop3dActor(
        'linh', 'linh', Shop3dActorRole.customer, Shop3dLayout.counterSpots[1].x, Shop3dLayout.counterSpots[1].z,
        expression: 'smile'),
    Shop3dActor('regular_03', 'regular_03', Shop3dActorRole.customer, Shop3dLayout.counterSpots[0].x,
        Shop3dLayout.counterSpots[0].z),
    Shop3dActor('hoa', 'hoa', Shop3dActorRole.customer, Shop3dLayout.queue[1].x, Shop3dLayout.queue[1].z),
    Shop3dActor('regular_00', 'regular_00', Shop3dActorRole.customer, Shop3dLayout.queue[2].x, Shop3dLayout.queue[2].z),
    Shop3dActor('kenji', 'kenji', Shop3dActorRole.customer, Shop3dLayout.queue[3].x, Shop3dLayout.queue[3].z),
    Shop3dActor('regular_07', 'regular_07', Shop3dActorRole.customer, Shop3dLayout.seats[1].x,
        Shop3dLayout.seats[1].z + tableSideOffsetZ,
        expression: 'joy', requires: Shop3dRequires.cafeTables),
    Shop3dActor('vip_00', 'vip_00', Shop3dActorRole.customer, Shop3dLayout.seats[4].x,
        Shop3dLayout.seats[4].z + tableSideOffsetZ,
        expression: 'smile', requires: Shop3dRequires.cafeTables),
    Shop3dActor(
        'staff_nora', 'staff_nora', Shop3dActorRole.staff, Shop3dLayout.staffCashier.x, Shop3dLayout.staffCashier.z,
        expression: 'smile'),
    Shop3dActor('staff_bao', 'staff_bao', Shop3dActorRole.staff, Shop3dLayout.staffMixer.x, Shop3dLayout.staffMixer.z),
  ];

  static List<Shop3dActor> actorsFor(Set<String> owned) => [
        for (final a in all)
          if (a.enabledFor(owned)) a,
      ];

  /// Góc quay quanh y của tấm billboard để mặt tấm (+z cục bộ) hướng về camera: song song mặt phẳng nhìn, mọi tấm
  /// cùng góc (không méo khi ở mép màn). Bằng `OrbitCameraController.yaw`. Hướng mặt tấm = (sin yaw, 0, cos yaw).
  static double billboardYaw(Vec3 eye, Vec3 target) => math.atan2(eye.x - target.x, eye.z - target.z);

  /// Đường kính bóng mềm dưới chân.
  static const double shadowDiameter = 0.62;
}

/// Hộp chứa điểm ảnh có alpha > ngưỡng, toạ độ pixel [left, right) × [top, bottom).
class Shop3dSpriteBounds {
  const Shop3dSpriteBounds(this.left, this.top, this.right, this.bottom);

  final int left, top, right, bottom;

  int get width => right - left;
  int get height => bottom - top;

  @override
  String toString() => 'Shop3dSpriteBounds($left, $top, $right, $bottom)';
}

/// Ảnh RGBA 8 bit, alpha thẳng (không nhân sẵn).
class Shop3dRgbaImage {
  Shop3dRgbaImage(this.width, this.height, this.pixels) : assert(pixels.length == width * height * 4);

  final int width, height;
  final Uint8List pixels;

  /// Kích thước thật (m) khi đặt trong cảnh với [Shop3dActors.pixelsPerMeter] (ảnh gốc 480×640, đã cắt viền).
  double widthMeters([double scale = 1]) => width / (Shop3dActors.pixelsPerMeter * scale);
  double heightMeters([double scale = 1]) => height / (Shop3dActors.pixelsPerMeter * scale);
}

abstract final class Shop3dSprite {
  /// Hộp alpha > [threshold] của ảnh; null nếu ảnh trong suốt hoàn toàn. Ngưỡng bỏ vùng bóng mờ quanh chân.
  static Shop3dSpriteBounds? alphaBounds(Shop3dRgbaImage img, {int threshold = 24}) {
    var left = img.width, top = img.height, right = -1, bottom = -1;
    final p = img.pixels;
    for (var y = 0; y < img.height; y++) {
      final row = y * img.width * 4;
      for (var x = 0; x < img.width; x++) {
        if (p[row + x * 4 + 3] > threshold) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          bottom = y;
        }
      }
    }
    if (right < 0) return null;
    return Shop3dSpriteBounds(left, top, right + 1, bottom + 1);
  }

  /// Cắt [img] theo [b] nới thêm [pad] px mỗi phía (kẹp trong ảnh), riêng mép dưới không nới để chân chạm sàn.
  static Shop3dRgbaImage crop(Shop3dRgbaImage img, Shop3dSpriteBounds b, {int pad = 2}) {
    final l = math.max(0, b.left - pad), t = math.max(0, b.top - pad);
    final r = math.min(img.width, b.right + pad), btm = b.bottom;
    final w = r - l, h = btm - t;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final src = ((t + y) * img.width + l) * 4;
      out.setRange(y * w * 4, (y + 1) * w * 4, img.pixels, src);
    }
    return Shop3dRgbaImage(w, h, out);
  }

  /// Đổi RGBA nhân sẵn alpha (premultiplied, như `ImageByteFormat.rawRgba`) sang alpha thẳng, tại chỗ.
  static void unpremultiply(Uint8List p) {
    for (var i = 0; i < p.length; i += 4) {
      final a = p[i + 3];
      if (a == 0 || a == 255) continue;
      p[i] = math.min(255, (p[i] * 255 + a ~/ 2) ~/ a);
      p[i + 1] = math.min(255, (p[i + 1] * 255 + a ~/ 2) ~/ a);
      p[i + 2] = math.min(255, (p[i + 2] * 255 + a ~/ 2) ~/ a);
    }
  }

  /// Loang màu của điểm ảnh có alpha ra các điểm trong suốt kề bên ([passes] vòng, 4 lân cận), giữ alpha = 0. Lọc
  /// tuyến tính / mipmap khi đó không kéo màu nền (đen / trắng) vào mép nhân vật. Tại chỗ.
  static void bleedEdges(Shop3dRgbaImage img, {int passes = 2}) {
    final w = img.width, h = img.height, p = img.pixels;
    var filled = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      if (p[i * 4 + 3] > 0) filled[i] = 1;
    }
    for (var pass = 0; pass < passes; pass++) {
      final next = Uint8List.fromList(filled);
      var changed = false;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = y * w + x;
          if (filled[i] != 0) continue;
          var r = 0, g = 0, b = 0, n = 0;
          void take(int j) {
            if (filled[j] == 0) return;
            r += p[j * 4];
            g += p[j * 4 + 1];
            b += p[j * 4 + 2];
            n++;
          }

          if (x > 0) take(i - 1);
          if (x < w - 1) take(i + 1);
          if (y > 0) take(i - w);
          if (y < h - 1) take(i + w);
          if (n == 0) continue;
          p[i * 4] = r ~/ n;
          p[i * 4 + 1] = g ~/ n;
          p[i * 4 + 2] = b ~/ n;
          next[i] = 1;
          changed = true;
        }
      }
      filled = next;
      if (!changed) break;
    }
  }

  /// Số mức mipmap đầy đủ cho ảnh [w]×[h] (tới 1×1).
  static int mipLevelCount(int w, int h) {
    var n = 1, s = math.max(w, h);
    while (s > 1) {
      s >>= 1;
      n++;
    }
    return n;
  }

  /// Chuỗi mipmap (mức 0 = [img]): mỗi mức `max(1, w >> l)` × `max(1, h >> l)`, lọc hộp 2×2 có trọng số alpha
  /// (màu điểm trong suốt không lẫn vào). Giới hạn [maxLevels] mức.
  static List<Shop3dRgbaImage> mipChain(Shop3dRgbaImage img, {int? maxLevels}) {
    final count = math.min(maxLevels ?? 1 << 20, mipLevelCount(img.width, img.height));
    final levels = <Shop3dRgbaImage>[img];
    var src = img;
    for (var l = 1; l < count; l++) {
      final w = math.max(1, img.width >> l), h = math.max(1, img.height >> l);
      final out = Uint8List(w * h * 4);
      final sp = src.pixels, sw = src.width, sh = src.height;
      for (var y = 0; y < h; y++) {
        final y0 = math.min(sh - 1, y * 2), y1 = math.min(sh - 1, y * 2 + 1);
        for (var x = 0; x < w; x++) {
          final x0 = math.min(sw - 1, x * 2), x1 = math.min(sw - 1, x * 2 + 1);
          var r = 0, g = 0, b = 0, a = 0, rs = 0, gs = 0, bs = 0;
          for (final j in [(y0 * sw + x0) * 4, (y0 * sw + x1) * 4, (y1 * sw + x0) * 4, (y1 * sw + x1) * 4]) {
            final aj = sp[j + 3];
            r += sp[j] * aj;
            g += sp[j + 1] * aj;
            b += sp[j + 2] * aj;
            a += aj;
            rs += sp[j];
            gs += sp[j + 1];
            bs += sp[j + 2];
          }
          final o = (y * w + x) * 4;
          if (a > 0) {
            out[o] = (r + a ~/ 2) ~/ a;
            out[o + 1] = (g + a ~/ 2) ~/ a;
            out[o + 2] = (b + a ~/ 2) ~/ a;
          } else {
            out[o] = rs ~/ 4;
            out[o + 1] = gs ~/ 4;
            out[o + 2] = bs ~/ 4;
          }
          out[o + 3] = (a + 2) ~/ 4;
        }
      }
      src = Shop3dRgbaImage(w, h, out);
      levels.add(src);
    }
    return levels;
  }

  /// Chuẩn bị ảnh nhân vật cho texture: cắt viền trong suốt, loang màu mép. null nếu ảnh trống.
  static Shop3dRgbaImage? prepare(Shop3dRgbaImage img) {
    final b = alphaBounds(img);
    if (b == null) return null;
    final out = crop(img, b);
    bleedEdges(out);
    return out;
  }
}
