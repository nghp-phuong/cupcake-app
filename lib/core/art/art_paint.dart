import 'dart:typed_data';
import 'dart:ui';

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
