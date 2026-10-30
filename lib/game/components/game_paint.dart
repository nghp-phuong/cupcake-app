import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../logic/bake_record.dart';
import '../logic/cake_geometry.dart';
import 'hand_paint.dart';

// Hình riêng của các trạm (tô trộn, lò, túi kem, khay…) + tiện ích vẽ. Hình dùng chung nằm ở core/art.

/// Vùng chơi trong khung 1280×720 (bên phải là vé đơn + gợi ý, bên trên là thanh bước).
const Rect kPlayArea = Rect.fromLTWH(0, 72, 940, 648);

double easeOutCubic(double t) {
  final x = 1 - t.clamp(0.0, 1.0);
  return 1 - x * x * x;
}

double easeInOut(double t) {
  final x = t.clamp(0.0, 1.0);
  return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
}

double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t.clamp(0.0, 1.0) - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// Tiến gần [target] theo hàm mũ (mượt, không phụ thuộc fps).
double approach(double value, double target, double dt, {double speed = 12}) =>
    target + (value - target) * math.exp(-speed * dt);

Offset approachOffset(Offset value, Offset target, double dt, {double speed = 12}) =>
    Offset(approach(value.dx, target.dx, dt, speed: speed), approach(value.dy, target.dy, dt, speed: speed));

// ------------------------------------------------------------------ Bộ đệm Paint
// Các trạm vẽ lại mỗi khung hình → không tạo Paint mới cho từng lệnh vẽ. Paint trả về từ [fill],
// [stroke], [softStroke] được DÙNG CHUNG theo (màu, độ dày): chỉ truyền thẳng vào lệnh vẽ, KHÔNG sửa
// thuộc tính của nó. Cần Paint riêng (shader, maskFilter…) thì tự tạo và giữ làm trường của lớp.

const int _paintCacheLimit = 384;
final Map<int, Paint> _fillCache = {};
final Map<int, Map<double, Paint>> _strokeCache = {};
final Map<int, Map<double, Paint>> _softStrokeCache = {};

/// Paint tô đặc dùng chung theo màu.
Paint fill(Color c) {
  final key = c.toARGB32();
  final hit = _fillCache[key];
  if (hit != null) return hit;
  // Màu động (alpha chạy theo thời gian) sinh nhiều khoá → xoá bớt cho bộ đệm không phình mãi.
  if (_fillCache.length >= _paintCacheLimit) _fillCache.clear();
  return _fillCache[key] = ItemArt.fill(c);
}

Paint _cachedStroke(Map<int, Map<double, Paint>> cache, Color c, double w, Paint Function() create) {
  final key = c.toARGB32();
  var byWidth = cache[key];
  if (byWidth == null) {
    if (cache.length >= _paintCacheLimit) cache.clear();
    byWidth = cache[key] = <double, Paint>{};
  }
  final hit = byWidth[w];
  if (hit != null) return hit;
  if (byWidth.length >= 32) byWidth.clear();
  return byWidth[w] = create();
}

/// Paint nét viền dùng chung theo (màu, độ dày).
Paint stroke(Color c, double w) => _cachedStroke(_strokeCache, c, w, () => ItemArt.stroke(c, w));

// ------------------------------------------------------------------ Ngôn ngữ hình vẽ của bếp
// Vẽ tay ấm: viền nâu sô-cô-la (không đen), tô phẳng + một lớp bóng mềm + một lớp sáng. Nắng chiều
// chiếu từ cửa sổ phía trên bên phải → mặt sáng hướng lên-phải, bóng nằm dưới-trái.

/// Viền nâu sô-cô-la ấm cho đồ vật của trạm.
const Color kInk = Color(0xFF6A4334);

/// Màu bóng đổ (nâu ấm, không xám).
const Color kShadowTint = Color(0xFF7A4A34);

/// Lớp bóng: pha [c] về nâu đỏ ấm (không pha đen để màu không bị xỉn).
Color shadeOf(Color c, [double k = 0.2]) => Color.lerp(c, const Color(0xFF8A4F3C), k)!;

/// Lớp sáng: pha [c] về trắng kem nắng.
Color lightOf(Color c, [double k = 0.4]) => Color.lerp(c, const Color(0xFFFFFBEF), k)!;

/// Bút mềm có viền tròn (vệt sáng, nét vân). Dùng chung theo (màu, độ dày) như [stroke].
Paint softStroke(Color c, double w) => _cachedStroke(
      _softStrokeCache,
      c,
      w,
      () => Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

/// Vẽ lớp bóng mềm bên trong [shape]: phần của [shape] không bị bản dịch [offset] của nó che.
/// Ví dụ offset (6, -6) → bóng nằm ở mép dưới-trái (ánh sáng từ trên-phải).
void paintInnerShade(Canvas canvas, Path shape, Offset offset, Color color) {
  canvas.save();
  canvas.clipPath(shape);
  canvas.drawPath(Path.combine(PathOperation.difference, shape, shape.shift(offset)), fill(color));
  canvas.restore();
}

/// Bộ đệm chữ vẽ lên canvas (nhãn khuôn, topping, hộp). Chữ mực nâu; nhãn có nền là nhãn giấy viền mực run tay
/// (dựng một lần thành Picture, xem `hand_paint.dart`).
class CanvasText {
  CanvasText({this.fontFamily});

  /// Font nội dung (Nunito) — null trong test.
  String? fontFamily;

  /// Font tiêu đề theo ngôn ngữ (Fredoka / Baloo 2) và font dự phòng từng ký tự.
  String? titleFontFamily;
  List<String>? titleFallback;

  final Map<String, TextPainter> _cache = {};

  void clear() {
    for (final p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
  }

  /// Dựng chữ (không cache) theo kiểu của nhãn trên canvas; [title] = font tiêu đề.
  TextPainter layout(
    String text, {
    double size = 16,
    Color color = AppColors.chocolate,
    FontWeight weight = FontWeight.w700,
    double maxWidth = 160,
    int maxLines = 1,
    bool title = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          fontFamily: title ? titleFontFamily : fontFamily,
          fontFamilyFallback: title ? titleFallback : null,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Vẽ [text] căn giữa tại [center]; chữ dài xuống dòng trong [maxWidth] (tối đa [maxLines] dòng, thừa thì "…").
  /// [backing] khác null → nhãn giấy màu đó, viền mực run tay (cả nhãn lẫn chữ là một Picture trong cache).
  void draw(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 16,
    Color color = AppColors.chocolate,
    FontWeight weight = FontWeight.w700,
    double maxWidth = 160,
    int maxLines = 1,
    Color? backing,
  }) {
    if (backing != null) {
      final art = cachedArt(('tag', text, size, color, weight, maxWidth, maxLines, backing, fontFamily), () {
        final p = layout(text, size: size, color: color, weight: weight, maxWidth: maxWidth, maxLines: maxLines);
        return buildPaperTag(p, color: backing, seed: SLRandom.hashString(text));
      });
      drawPictureAt(canvas, art.picture, center - Offset(art.size.width / 2, art.size.height / 2));
      return;
    }
    final key = '$text|$size|${color.toARGB32()}|${weight.value}|$maxWidth|$maxLines';
    final p = _cache.putIfAbsent(key, () => layout(text, size: size, color: color, weight: weight, maxWidth: maxWidth, maxLines: maxLines));
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  /// Nền nhãn mặc định: giấy ngà (chữ mực trên giấy > 10:1).
  static const Color labelBacking = SLColors.paper;
}

// ------------------------------------------------------------------ Ảnh vẽ tay (ArtSprites)
// Ảnh lấy từ `ArtSprites` MỖI khung hình (không giữ `ui.Image` làm trường: cache LRU có thể giải phóng ảnh).
// Ảnh null (chưa nạp / thiếu file) → người gọi vẽ hình code dự phòng.

final Paint _artPaint = Paint()
  ..filterQuality = FilterQuality.medium
  ..isAntiAlias = true;

/// Vẽ ảnh vẽ tay [image] vào [rect] (mặc định vừa khung, giữ tỉ lệ, căn giữa). Dùng chung một Paint
/// (không cấp phát mỗi lệnh như `paintImage`). [colorFilter] nên là hằng / được giữ sẵn, không tạo mỗi khung.
void drawArt(Canvas canvas, ui.Image image, Rect rect, {double opacity = 1, ColorFilter? colorFilter, BoxFit fit = BoxFit.contain}) {
  if (rect.isEmpty || opacity <= 0) return;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(fit, size, rect.size);
  final src = Alignment.center.inscribe(fitted.source, Offset.zero & size);
  final dst = Alignment.center.inscribe(fitted.destination, rect);
  _artPaint
    ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0))
    ..colorFilter = colorFilter;
  canvas.drawImageRect(image, src, dst, _artPaint);
}

/// Vẽ ảnh [image] xoay [angle] rad quanh điểm [anchor] của ảnh (toạ độ pixel của ảnh), đặt điểm đó tại [at];
/// [scale] = số đơn vị canvas trên một pixel ảnh.
void drawArtRotated(Canvas canvas, ui.Image image, Offset at, Offset anchor, double angle, double scale) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  canvas.scale(scale);
  _artPaint
    ..color = const Color(0xFF000000)
    ..colorFilter = null;
  canvas.drawImage(image, -anchor, _artPaint);
  canvas.restore();
}

// Paint làm mờ tái sử dụng: chỉ đổi màu rồi vẽ ngay (lệnh vẽ chép Paint lúc gọi nên dùng lại an toàn).
final Paint _shadowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
final Paint _glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
final Paint _trayGlowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

/// Bóng mềm hình elip dưới đồ vật (nâu ấm, hơi lệch trái theo hướng nắng).
void paintShadow(Canvas canvas, Offset center, double width, double height, {double alpha = 0.16}) {
  _shadowPaint.color = kShadowTint.withValues(alpha: alpha);
  canvas.drawOval(Rect.fromCenter(center: center.translate(-width * 0.03, 0), width: width, height: height), _shadowPaint);
}

/// Quầng sáng vàng mềm (đồ vật đang được nhắm tới).
void paintGlow(Canvas canvas, Rect r, double strength, {Color color = AppColors.butter}) {
  if (strength <= 0) return;
  _glowPaint.color = color.withValues(alpha: 0.75 * strength.clamp(0.0, 1.0));
  canvas.drawOval(r, _glowPaint);
}

const Color _porcelain = Color(0xFFFFFBF3);
const Color _porcelainShade = Color(0xFFEEDFCB);
const Color _steel = Color(0xFFC6CCD4);
const Color _steelShade = Color(0xFFA2AAB5);

/// Vẽ cả ảnh [image] (ảnh gốc 512×512, toạ độ [src] tính theo ảnh gốc) sao cho vùng [src] của ảnh rơi đúng vào
/// [dst] (co giãn riêng ngang/dọc).
void _drawArtMapped(Canvas canvas, ui.Image image, Rect src, Rect dst) {
  final kx = dst.width / src.width, ky = dst.height / src.height;
  final full = Rect.fromLTWH(dst.left - src.left * kx, dst.top - src.top * ky, 512 * kx, 512 * ky);
  _artPaint
    ..color = const Color(0xFF000000)
    ..colorFilter = null;
  canvas.drawImageRect(image, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()), full, _artPaint);
}

// Đo trên ảnh `items/plate_serving` (512×512, PIL): mặt đĩa (mép ngoài, không tính bề dày) và lòng đĩa xanh sứ.
const Rect _plateArtRim = Rect.fromLTRB(15, 107, 496, 397);
const Offset _plateArtWell = Offset(253, 256);

/// Mặt đĩa ảnh nhìn cao hơn bàn của trạm: ép dọc còn chừng này (đĩa nằm phẳng như hình code cũ).
const double _plateArtSquash = 0.5;

/// Đĩa sứ hình elip đặt dưới bánh (trạm topping, đóng hộp). Có ảnh `items/plate_serving` thì vẽ ảnh: mép đĩa rộng
/// bằng [oval], tâm lòng đĩa trùng tâm [oval] (chỗ bánh ngồi — `seatedCakeRect`), thêm bóng mềm + bóng tiếp xúc.
/// Chưa có ảnh → đĩa vẽ tay (dựng một lần theo cỡ [oval], mỗi khung chỉ drawPicture).
void paintServingPlate(Canvas canvas, Rect oval) {
  final image = ArtSprites.servingPlate.image;
  if (image == null) {
    final art = cachedArt(('servingPlate', oval.width, oval.height), () => buildServingPlateArt(oval.size));
    drawPictureAt(canvas, art.picture, oval.topLeft - art.origin);
    return;
  }
  final kx = oval.width / _plateArtRim.width;
  final ky = kx * _plateArtSquash;
  final rim = Rect.fromLTWH(
    oval.center.dx - (_plateArtWell.dx - _plateArtRim.left) * kx,
    oval.center.dy - (_plateArtWell.dy - _plateArtRim.top) * ky,
    oval.width,
    _plateArtRim.height * ky,
  );
  // Bóng rộng mềm + bóng tiếp xúc đậm, hẹp ngay dưới mép đĩa.
  paintShadow(canvas, rim.center.translate(0, rim.height * 0.3), rim.width * 1.04, rim.height * 0.8, alpha: 0.16);
  paintShadow(canvas, rim.center.translate(0, rim.height * 0.16), rim.width * 0.94, rim.height * 0.66, alpha: 0.26);
  _drawArtMapped(canvas, image, _plateArtRim, rim);
}

/// Đế xoay bánh: chân sứ thon + mặt đế dày có viền bạc hà. [top] = elip mặt đế.
void paintCakeStand(Canvas canvas, Rect top) {
  final cx = top.center.dx;
  final cy = top.center.dy;
  final foot = Rect.fromCenter(center: Offset(cx, cy + 62), width: 130, height: 22);
  canvas.drawOval(foot, fill(_porcelainShade));
  canvas.drawOval(foot.translate(2, -2).deflate(1), fill(_porcelain));
  canvas.drawOval(foot, stroke(kInk, 2.5));
  final stem = Path()
    ..moveTo(cx - 24, cy + 4)
    ..quadraticBezierTo(cx - 14, cy + 36, cx - 36, cy + 60)
    ..lineTo(cx + 36, cy + 60)
    ..quadraticBezierTo(cx + 14, cy + 36, cx + 24, cy + 4)
    ..close();
  canvas.drawPath(stem, fill(_porcelain));
  canvas.save();
  canvas.clipPath(stem);
  canvas.drawRect(Rect.fromLTRB(cx - 40, cy, cx - 6, cy + 64), fill(_porcelainShade));
  canvas.drawLine(Offset(cx + 12, cy + 14), Offset(cx + 16, cy + 50), softStroke(const Color(0xFFFFFFFF), 4));
  canvas.restore();
  canvas.drawPath(stem, stroke(kInk, 2.5));
  // Mặt đế dày.
  final side = top.translate(0, 12);
  final sideColor = shadeOf(_porcelainShade, 0.1);
  canvas.drawOval(side, fill(sideColor));
  canvas.drawRect(Rect.fromLTRB(top.left, cy, top.right, cy + 12), fill(sideColor));
  canvas.drawOval(side, stroke(kInk, 3));
  canvas.drawRect(Rect.fromLTRB(top.left + 2, cy, top.right - 2, cy + 12), fill(sideColor));
  canvas.drawLine(Offset(top.left, cy), Offset(top.left, cy + 12), stroke(kInk, 3));
  canvas.drawLine(Offset(top.right, cy), Offset(top.right, cy + 12), stroke(kInk, 3));
  canvas.drawOval(top, fill(_porcelainShade));
  canvas.save();
  canvas.clipRRect(RRect.fromRectXY(top, top.width / 2, top.height / 2));
  canvas.drawOval(top.translate(4, -4), fill(_porcelain));
  canvas.restore();
  final ring = top.deflate(12);
  canvas.drawOval(ring, stroke(AppColors.mint, 4));
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi * 2 / 24;
    canvas.drawCircle(Offset(cx + math.cos(a) * (ring.width / 2 + 6), cy + math.sin(a) * (ring.height / 2 + 2.5)), 1.6, fill(AppColors.strawberry));
  }
  canvas.drawArc(top.deflate(4), -math.pi * 0.4, math.pi * 0.28, false, softStroke(const Color(0xE6FFFFFF), 3));
  canvas.drawOval(top, stroke(kInk, 3));
}

// Đo trên ảnh `items/baking_tray` (512×512, PIL): khung bao lòng giấy nến (vùng kem phẳng) và 4 góc viền khay
// (trái, trên, phải, dưới — khay nhìn chéo).
const Rect _trayArtPaper = Rect.fromLTRB(45, 134, 466, 334);
const List<Offset> _trayArtCorners = [Offset(15, 236), Offset(285, 117), Offset(496, 207), Offset(224, 393)];

/// Khung giấy nến của khay vẽ tay cỡ [r] (`buildBakingTrayArt`: lòng khay lùi 16, giấy lùi thêm 7).
Rect bakingTrayPaper(Rect r) => r.deflate(23);

/// Khay nướng (trạm khuôn). Có ảnh `items/baking_tray` thì vẽ ảnh, co đều để lòng giấy nến của ảnh nằm đúng khung
/// giấy nến của khay vẽ tay ([bakingTrayPaper]) — vùng thả không đổi — kèm bóng mềm theo dáng khay. Chưa có ảnh →
/// khay vẽ tay (vành thép màu nước, quai cầm, giấy nến; dựng một lần theo cỡ [r]). [glow] = quầng vàng khi khuôn
/// đang kéo nằm trên khay.
void paintBakingTray(Canvas canvas, Rect r, {double glow = 0}) {
  final image = ArtSprites.bakingTray.image;
  if (image != null) {
    final paper = bakingTrayPaper(r);
    final k = math.min(paper.width / _trayArtPaper.width, paper.height / _trayArtPaper.height);
    final dst = Rect.fromCenter(center: paper.center, width: _trayArtPaper.width * k, height: _trayArtPaper.height * k);
    Offset at(Offset p) => dst.topLeft + (p - _trayArtPaper.topLeft) * k;
    final corners = [for (final c in _trayArtCorners) at(c)];
    _shadowPaint.color = kShadowTint.withValues(alpha: 0.24);
    canvas.drawPath(Path()..addPolygon([for (final p in corners) p.translate(-6, 12)], true), _shadowPaint);
    if (glow > 0) {
      // Quầng: dáng khay nở ra ~18 px mỗi góc để lộ khỏi mép ảnh.
      final c = dst.center;
      final halo = [for (final p in corners) c + (p - c) * (1 + 18 / (p - c).distance)];
      _trayGlowPaint.color = AppColors.butter.withValues(alpha: 0.8 * glow.clamp(0.0, 1.0));
      canvas.drawPath(Path()..addPolygon(halo, true), _trayGlowPaint);
    }
    _drawArtMapped(canvas, image, _trayArtPaper, dst);
    return;
  }
  if (glow > 0) {
    _trayGlowPaint.color = AppColors.butter.withValues(alpha: 0.7 * glow.clamp(0.0, 1.0));
    canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(10), const Radius.circular(34)), _trayGlowPaint);
  }
  final art = cachedArt(('bakingTray', r.width, r.height), () => buildBakingTrayArt(r.size));
  drawPictureAt(canvas, art.picture, r.topLeft - art.origin);
}

/// Tô trộn sứ nhìn từ trên xuống: vành ngoài [rim] có dây lá bạc hà vẽ tay, lòng tô [inner].
void paintBowl(Canvas canvas, Offset c, double rim, double inner) {
  paintShadow(canvas, c.translate(-rim * 0.04, rim * 0.1), rim * 2.15, rim * 2.05, alpha: 0.22);
  final outer = Rect.fromCircle(center: c, radius: rim);
  canvas.drawOval(outer, fill(_porcelainShade));
  canvas.save();
  canvas.clipRRect(RRect.fromRectXY(outer, outer.width / 2, outer.height / 2));
  canvas.drawCircle(c.translate(5, -5), rim, fill(_porcelain));
  canvas.restore();
  // Dây lá bạc hà lượn quanh vành + chấm dâu.
  final mid = (rim + inner) / 2;
  final vine = Path();
  const steps = 144;
  for (var i = 0; i <= steps; i++) {
    final a = i * math.pi * 2 / steps;
    final rr = mid + 3.5 * math.sin(a * 14);
    final p = c + Offset(math.cos(a), math.sin(a)) * rr;
    if (i == 0) {
      vine.moveTo(p.dx, p.dy);
    } else {
      vine.lineTo(p.dx, p.dy);
    }
  }
  canvas.drawPath(vine, softStroke(const Color(0xFF8CCBB2), 3));
  final leaf = fill(AppColors.mint);
  final berry = fill(AppColors.strawberry);
  for (var i = 0; i < 14; i++) {
    final a = (i + 0.25) * math.pi * 2 / 14;
    final p = c + Offset(math.cos(a), math.sin(a)) * (mid + 3.5);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a + math.pi / 2);
    canvas.drawOval(const Rect.fromLTWH(-8, -4, 16, 8), leaf);
    canvas.restore();
    final q = c + Offset(math.cos(a + math.pi / 14), math.sin(a + math.pi / 14)) * (mid - 3.5);
    canvas.drawCircle(q, 3, berry);
  }
  // Vệt sáng vành phía trên-phải.
  canvas.drawArc(Rect.fromCircle(center: c, radius: rim - 5), -math.pi * 0.43, math.pi * 0.3, false, softStroke(const Color(0xF2FFFFFF), 4));
  canvas.drawArc(Rect.fromCircle(center: c, radius: rim - 5), -math.pi * 0.08, math.pi * 0.05, false, softStroke(const Color(0xF2FFFFFF), 4));
  canvas.drawOval(outer, stroke(kInk, 3.5));
  // Lòng tô lõm: thành trong phía trên-phải trong bóng.
  final well = Rect.fromCircle(center: c, radius: inner);
  canvas.drawOval(well, fill(const Color(0xFFE6D6C2)));
  canvas.save();
  canvas.clipRRect(RRect.fromRectXY(well, well.width / 2, well.height / 2));
  canvas.drawCircle(c.translate(-9, 9), inner, fill(const Color(0xFFF6EEE3)));
  canvas.restore();
  canvas.drawOval(well, stroke(const Color(0xFFCDB49A), 2.5));
}

/// Phới lồng: [tip] = đầu phới (nơi chạm bột), [angle] = hướng cán (rad).
void paintWhisk(Canvas canvas, Offset tip, double angle, {double scale = 1}) {
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(angle);
  canvas.scale(scale);
  paintShadow(canvas, const Offset(70, 18), 170, 22, alpha: 0.12);
  // Nan thép: viền nâu mảnh, thân thép, ánh sáng nửa trên.
  for (var i = 0; i < 4; i++) {
    final h = 46.0 - i * 13;
    canvas.drawOval(Rect.fromLTWH(-6, -h / 2, 72, h.abs() + 3), stroke(kInk.withValues(alpha: 0.85), 5.5));
  }
  for (var i = 0; i < 4; i++) {
    final h = 46.0 - i * 13;
    final o = Rect.fromLTWH(-6, -h / 2, 72, h.abs() + 3);
    canvas.drawOval(o, stroke(const Color(0xFFAEB6C0), 3));
    canvas.drawArc(o, math.pi * 1.1, math.pi * 0.6, false, softStroke(const Color(0xE6FFFFFF), 1.3));
  }
  final collar = RRect.fromRectAndRadius(const Rect.fromLTWH(58, -9, 16, 18), const Radius.circular(4));
  canvas.drawRRect(collar, fill(_steelShade));
  canvas.drawRect(const Rect.fromLTWH(60, -7, 12, 7), fill(_steel));
  canvas.drawLine(const Offset(62, -5), const Offset(70, -5), softStroke(const Color(0xFFFFFFFF), 2));
  canvas.drawRRect(collar, stroke(kInk, 2.5));
  // Cán gỗ có vân, khoen dâu gần cổ.
  final handle = RRect.fromRectAndRadius(const Rect.fromLTWH(72, -12, 104, 24), const Radius.circular(12));
  canvas.drawRRect(handle, fill(const Color(0xFFC48A55)));
  canvas.save();
  canvas.clipRRect(handle);
  canvas.drawRRect(handle.shift(const Offset(0, -5)), fill(const Color(0xFFDDA86F)));
  final grain = softStroke(const Color(0x59935A30), 1.3);
  canvas.drawPath(
    Path()
      ..moveTo(96, -3)
      ..quadraticBezierTo(120, -6, 146, -2)
      ..quadraticBezierTo(158, 0, 170, -3),
    grain,
  );
  canvas.drawPath(
    Path()
      ..moveTo(104, 4)
      ..quadraticBezierTo(124, 2, 140, 5),
    grain,
  );
  canvas.drawRect(const Rect.fromLTWH(74, -14, 12, 28), fill(AppColors.strawberry));
  canvas.drawRect(const Rect.fromLTWH(74, 4, 12, 10), fill(shadeOf(AppColors.strawberry, 0.2)));
  canvas.restore();
  canvas.drawLine(const Offset(94, -7), const Offset(150, -7), softStroke(const Color(0xA6FFF1D9), 2.5));
  canvas.drawLine(const Offset(86, -11), const Offset(86, 11), stroke(kInk.withValues(alpha: 0.6), 1.5));
  canvas.drawRRect(handle, stroke(kInk, 3));
  canvas.drawCircle(const Offset(160, 0), 4.5, fill(const Color(0xFFFFF4E6)));
  canvas.drawCircle(const Offset(160, 0), 4.5, stroke(kInk, 2));
  canvas.restore();
}

/// Túi bắt kem vải: đầu túi tại [tip], nghiêng [tilt] rad.
void paintPipingBag(Canvas canvas, Offset tip, Color cream, {double tilt = -0.45, double squeeze = 0}) {
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(tilt);
  final w = 40 - squeeze * 6;
  final bag = Path()
    ..moveTo(-8, -18)
    ..lineTo(-w, -122)
    ..quadraticBezierTo(0, -146, w, -122)
    ..lineTo(8, -18)
    ..close();
  canvas.drawPath(bag, fill(const Color(0xF5FFFCF5)));
  canvas.save();
  canvas.clipPath(bag);
  // Kem bên trong nhìn qua vải mỏng.
  final level = -84 + squeeze * 10;
  canvas.drawRect(Rect.fromLTWH(-48, level, 96, 70), fill(cream));
  canvas.drawRect(Rect.fromLTWH(-48, level, 96, 70), fill(const Color(0x26FFFFFF)));
  canvas.drawPath(
    Path()
      ..moveTo(-48, level)
      ..quadraticBezierTo(-16, level - 6, 0, level)
      ..quadraticBezierTo(18, level + 6, 48, level - 2),
    softStroke(shadeOf(cream, 0.25).withValues(alpha: 0.6), 2),
  );
  // Bóng mềm nửa trái + nếp vải xoắn gần miệng túi.
  canvas.drawPath(
    Path()
      ..moveTo(-w - 4, -126)
      ..lineTo(-12, -126)
      ..lineTo(-4, -14)
      ..lineTo(-12, -14)
      ..close(),
    fill(const Color(0x247A4A34)),
  );
  final fold = softStroke(kInk.withValues(alpha: 0.28), 1.6);
  canvas.drawPath(
    Path()
      ..moveTo(-w * 0.5, -124)
      ..quadraticBezierTo(-10, -108, -4, -92),
    fold,
  );
  canvas.drawPath(
    Path()
      ..moveTo(w * 0.35, -126)
      ..quadraticBezierTo(6, -112, 4, -98),
    fold,
  );
  canvas.restore();
  canvas.drawLine(const Offset(18, -110), const Offset(8, -40), softStroke(const Color(0xB3FFFFFF), 4));
  canvas.drawPath(bag, stroke(kInk, 3));
  // Đui bắt kem hình sao: thép có rãnh + vệt sáng.
  final nozzle = Path()
    ..moveTo(-10, -22)
    ..lineTo(10, -22)
    ..lineTo(4, 0)
    ..lineTo(-4, 0)
    ..close();
  canvas.drawPath(nozzle, fill(_steel));
  canvas.save();
  canvas.clipPath(nozzle);
  canvas.drawRect(const Rect.fromLTRB(-12, -24, -3, 2), fill(_steelShade));
  for (final x in [-4.0, 0.0, 4.0]) {
    canvas.drawLine(Offset(x * 1.6, -22), Offset(x * 0.6, 0), stroke(const Color(0x667A4A34), 1));
  }
  canvas.drawLine(const Offset(5, -20), const Offset(2.5, -4), softStroke(const Color(0xFFFFFFFF), 1.8));
  canvas.restore();
  canvas.drawPath(nozzle, stroke(kInk, 2.5));
  // Nơ dâu buộc miệng túi.
  const knot = Offset(0, -133);
  for (final s in [-1.0, 1.0]) {
    final loop = Path()
      ..moveTo(knot.dx, knot.dy)
      ..quadraticBezierTo(knot.dx + s * 18, knot.dy - 16, knot.dx + s * 22, knot.dy - 2)
      ..quadraticBezierTo(knot.dx + s * 16, knot.dy + 8, knot.dx, knot.dy)
      ..close();
    canvas.drawPath(loop, fill(AppColors.strawberry));
    canvas.drawPath(loop, stroke(kInk, 2));
    final tail = Path()
      ..moveTo(knot.dx, knot.dy)
      ..lineTo(knot.dx + s * 12, knot.dy + 16)
      ..lineTo(knot.dx + s * 6, knot.dy + 18)
      ..close();
    canvas.drawPath(tail, fill(shadeOf(AppColors.strawberry, 0.15)));
    canvas.drawPath(tail, stroke(kInk, 1.8));
  }
  canvas.drawCircle(knot, 4.5, fill(AppColors.strawberry));
  canvas.drawCircle(knot, 4.5, stroke(kInk, 2));
  canvas.restore();
}

/// Đáy thân bánh (điểm thấp nhất) theo khuôn: ×cạnh khung vuông, tính từ tâm khung. Trùng số đo của
/// `CakeArt` (ảnh đế đã nướng được đặt cho đáy trùng hình code dự phòng).
double cakeBottomFactor(MouldType m, {RecipeId? recipe}) => CakeArt.bottomFactor(m, recipe: recipe);

/// Bánh "ngồi" lên mặt phẳng: mép trước của đáy thấp hơn mặt đỡ một đoạn (×cạnh khung) — bánh đáy rộng
/// (khuôn tròn) thấp hơn nhiều, cốc giấy đáy hẹp gần như bằng.
double _cakeSeatFactor(MouldType m) => switch (m) {
      MouldType.cupcakeLiner || MouldType.muffinCup => 0,
      MouldType.tartShell => 0.02,
      MouldType.macaronMat => 0.03,
      MouldType.roundPan || MouldType.springformPan || MouldType.tallPan => 0.05,
      MouldType.pastryTray || MouldType.shellMould || MouldType.eclairTray => 0.02,
      MouldType.piePan || MouldType.mooncakeMould || MouldType.logPan => 0.04,
    };

/// Khung vuông cạnh [size] để bánh khuôn [m] ngồi lên mặt đỡ ở độ cao [surfaceY], tâm ngang [cx].
/// [seat] co giãn độ lún của đáy (mặt đỡ nhìn gần như ngang, như giá lò, thì nhỏ hơn). [recipe]: món có số đo ảnh
/// riêng (`CakeArt.bottomFactor`).
Rect seatedCakeRect(MouldType m, double cx, double surfaceY, double size, {double seat = 1, RecipeId? recipe}) {
  final bottom = surfaceY + _cakeSeatFactor(m) * size * seat;
  return Rect.fromCenter(center: Offset(cx, bottom - cakeBottomFactor(m, recipe: recipe) * size), width: size, height: size);
}

/// Bánh + topping đặt theo vị trí người chơi (vị trí lưu dạng toạ độ chuẩn hoá trên elip mặt bánh).
void paintCakeWithToppings(Canvas canvas, Rect rect, CakeVisual v, List<PlacedTopping> placed, {double bounceTime = 0.32}) {
  CakeArt.paint(canvas, rect, v.copyWith(toppings: const {}));
  final top = CakeArt.topSurface(rect, v.mould, recipe: v.recipe);
  final size = toppingSize(top);
  final sorted = [...placed]..sort((a, b) => a.unit.dy.compareTo(b.unit.dy));
  for (final t in sorted) {
    final p = fromEllipseUnit(t.unit, top);
    final k = t.age < bounceTime ? 1 + 0.3 * math.sin(t.age / bounceTime * math.pi) : 1.0;
    paintToppingAt(canvas, p, t.topping, size * k);
  }
}

/// Cỡ topping theo mặt bánh (cùng tỉ lệ ở mọi kích thước bánh). Mặt bánh cao (tart, bánh tròn nhìn
/// nghiêng) thì giới hạn theo bề rộng để topping không quá to.
double toppingSize(Rect top) => math.max(18, math.min(top.height * 0.42, top.width * 0.19));

/// Vẽ một topping có "chân" đặt ở [p] (topping hơi nhô lên khỏi mặt bánh).
void paintToppingAt(Canvas canvas, Offset p, ToppingId t, double size) {
  final h = t == ToppingId.candle ? size * 1.6 : size;
  final rect = Rect.fromCenter(center: p.translate(0, -h * 0.3), width: h, height: h);
  final image = ArtSprites.topping(t).image;
  if (image != null) {
    drawArt(canvas, image, rect);
  } else {
    ItemArt.paintTopping(canvas, rect, t);
  }
}

/// Trái tim nhỏ (dây cờ của nền bếp vẽ code dự phòng).
void paintHeart(Canvas canvas, Offset c, double s, Color color) {
  final path = Path()
    ..moveTo(c.dx, c.dy + s * 0.35)
    ..cubicTo(c.dx - s * 0.6, c.dy - s * 0.05, c.dx - s * 0.3, c.dy - s * 0.55, c.dx, c.dy - s * 0.2)
    ..cubicTo(c.dx + s * 0.3, c.dy - s * 0.55, c.dx + s * 0.6, c.dy - s * 0.05, c.dx, c.dy + s * 0.35)
    ..close();
  canvas.drawPath(path, fill(color));
}
