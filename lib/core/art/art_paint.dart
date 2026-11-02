import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui show Gradient;

import 'package:flutter/painting.dart';

/// Vẽ ảnh vẽ tay (`ArtSprites`) vào [rect] theo [fit] (mặc định vừa khung, giữ tỉ lệ) và [alignment].
/// Hàm thuần cho CustomPainter / Flame `render`: gọi một dòng, không cần widget.
void paintArt(
  Canvas canvas,
  Rect rect,
  Image image, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  double opacity = 1,
  ColorFilter? colorFilter,
  bool flipHorizontally = false,
}) {
  if (rect.isEmpty || opacity <= 0) return;
  paintImage(
    canvas: canvas,
    rect: rect,
    image: image,
    fit: fit,
    alignment: alignment,
    opacity: opacity,
    colorFilter: colorFilter,
    flipHorizontally: flipHorizontally,
    filterQuality: FilterQuality.medium,
    isAntiAlias: true,
  );
}

/// Phủ [rect] bằng hoạ tiết lặp [image] (giấy dán tường, sàn), mỗi ô vuông cạnh [tileSize] (đơn vị của
/// canvas, vd. toạ độ khung 1280×720), gốc lặp ở [origin] (mặc định góc trên trái của [rect]).
void paintArtTiled(Canvas canvas, Rect rect, Image image, {required double tileSize, Offset? origin, double opacity = 1}) {
  if (rect.isEmpty || tileSize <= 0 || opacity <= 0) return;
  final o = origin ?? rect.topLeft;
  final sx = tileSize / image.width, sy = tileSize / image.height;
  final matrix = Float64List(16)
    ..[0] = sx
    ..[5] = sy
    ..[10] = 1
    ..[12] = o.dx
    ..[13] = o.dy
    ..[15] = 1;
  final paint = Paint()
    ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, matrix, filterQuality: FilterQuality.medium)
    ..color = Color.fromRGBO(0, 0, 0, opacity)
    ..isAntiAlias = true;
  canvas.drawRect(rect, paint);
}

/// Vùng 16:9 ở giữa [size] (cao bằng [size], rộng = cao × 16/9) — nơi đặt ảnh nền gốc 1280×720 khi khung rộng hơn
/// 16:9. [size] hẹp hơn hoặc đúng 16:9 → trả cả [size].
Rect wideCenterRect(Size size) {
  final w = size.height * 16 / 9;
  if (w >= size.width) return Offset.zero & size;
  return Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
}

/// Nền ảnh cho khung rộng (máy 20:9): vẽ [image] (vùng [src], mặc định cả ảnh) vào [center1280], rồi lấp hai dải
/// trái/phải tới mép [full] bằng ảnh soi gương của dải mép ảnh (liền mạch ở đường nối), tối nhẹ dần ra ngoài để mắt
/// không bám vào phần lặp. [full] == [center1280] → chỉ vẽ ảnh như thường. FilterQuality.low: rẻ, nền không cần nét.
void paintWideBackdrop(Canvas canvas, Image image, {required Rect center1280, required Rect full, Rect? src}) {
  if (center1280.isEmpty) return;
  final s = src ?? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final paint = Paint()..filterQuality = FilterQuality.low;
  canvas.drawImageRect(image, s, center1280, paint);
  final kx = s.width / center1280.width; // điểm ảnh nguồn / đơn vị đích
  void side(double width, {required bool left}) {
    if (width <= 0) return;
    final w = math.min(width, center1280.width);
    final seam = left ? center1280.left : center1280.right;
    final strip = left
        ? Rect.fromLTWH(s.left, s.top, w * kx, s.height)
        : Rect.fromLTWH(s.right - w * kx, s.top, w * kx, s.height);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left ? seam - width : seam, full.top, left ? seam : seam + width, full.bottom));
    // Lật quanh đường nối: điểm ảnh ở mép ảnh nằm sát đường nối, đi ra ngoài là đi vào trong ảnh.
    canvas.translate(seam, 0);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      strip,
      left ? Rect.fromLTWH(0, center1280.top, w, center1280.height) : Rect.fromLTWH(-w, center1280.top, w, center1280.height),
      paint,
    );
    canvas.restore();
    // Tối nhẹ: 0 ở đường nối → ~10% ở 40% dải → 12% ở mép ngoài (mờ dần, không thấy vạch nối).
    final outer = left ? seam - width : seam + width;
    final shade = Rect.fromLTRB(math.min(seam, outer), full.top, math.max(seam, outer), full.bottom);
    canvas.drawRect(
      shade,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(seam, 0),
          Offset(outer, 0),
          const [Color(0x002A1A12), Color(0x1A2A1A12), Color(0x1F2A1A12)],
          const [0, 0.4, 1],
        ),
    );
  }

  side(center1280.left - full.left, left: true);
  side(full.right - center1280.right, left: false);
}
