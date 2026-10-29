import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/paint/sl_cache.dart';
import '../../ui/sugarleaf/paint/sl_icon_art.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../../ui/sugarleaf/paint/sl_surface.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import 'game_paint.dart';

// Phong cách vẽ tay của bộ SL* (lib/ui/sugarleaf) cho phần "giao diện" vẽ trên canvas Flame: nhãn giấy, ô chọn
// (đĩa), nút Giữ, thanh đo, dấu sai, mũi tên gợi ý. Mọi nét run tay (wobblePath / buildSurfaceArt) dựng MỘT lần
// thành `ui.Picture` và giữ trong [gameArtCache]; mỗi khung hình chỉ drawPicture (+ vài lệnh vẽ đơn giản cho
// phần động: phần đã đầy của thanh đo, vòng tiến độ). Không sinh Path run tay trong lúc vẽ khung.

/// Cache LRU riêng của game (không chung với cache của widget SL* → hình của trạm không bị widget đẩy ra).
/// Khoảng 30 hình cho một phiên làm bánh (nhãn theo ngôn ngữ, đĩa, thanh đo theo món, nút Giữ 3 trạng thái).
final SLLru<Object, SLCachedArt> gameArtCache = SLLru<Object, SLCachedArt>(96);

/// Hình đã dựng: [picture] (vẽ dưới phần động) và [overlay] (vẽ trên phần động, có thể null). Gốc toạ độ của
/// hình là [origin] tính từ điểm đặt (hình có lề cho bóng / nét lố).
class GameArt implements SLCachedArt {
  GameArt(this.picture, this.size, {this.origin = Offset.zero, this.overlay, this.text, this.parts = const []});

  final ui.Picture picture;
  final ui.Picture? overlay;

  /// Kích thước phần chính (không tính lề).
  final Size size;
  final Offset origin;

  /// Giữ chữ đã vẽ vào hình (giải phóng cùng hình).
  final TextPainter? text;

  /// Hình con đã lồng vào [picture] (giữ sống tới khi hình bị đẩy khỏi cache).
  final List<SLCachedArt> parts;

  @override
  void dispose() {
    picture.dispose();
    overlay?.dispose();
    text?.dispose();
    for (final p in parts) {
      p.dispose();
    }
  }
}

/// Lấy hình [key] trong cache, chưa có thì dựng bằng [build].
GameArt cachedArt(Object key, GameArt Function() build) => gameArtCache.obtain(key, build) as GameArt;

/// Ghi các lệnh vẽ của [draw] thành một Picture.
ui.Picture recordArt(void Function(Canvas c) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording();
}

/// Vẽ [picture] với gốc toạ độ đặt tại [at].
void drawPictureAt(Canvas canvas, ui.Picture picture, Offset at) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.drawPicture(picture);
  canvas.restore();
}

const Color _umber = Color(0xFF6B4532);

Paint _inkPen(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

Paint _wash(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

/// Nét mực run tay theo [outline] (đã run): nét phụ caramel lệch ~1px + nét mực chính + một đoạn đè đậm.
void inkOutline(Canvas c, Path outline, {double width = SLMetrics.inkWidth, Color ink = SLColors.ink, int seed = 0}) {
  c.save();
  c.translate(1.1, 1.3);
  c.drawPath(outline, _inkPen(SLColors.caramel.withValues(alpha: 0.5), width * 0.55));
  c.restore();
  c.drawPath(outline, _inkPen(ink, width));
  final from = SLRandom(seed).nextDouble();
  c.drawPath(extractFraction(outline, from, math.min(1, from + 0.18)), _inkPen(ink, width * 1.45));
}

/// Dải màu nước trong khung [band] (mép dọc run tay, mép đọng màu đậm, vệt sáng giữa nếu [highlight]). Người gọi tự
/// cắt theo hình.
void paintWashBand(Canvas c, Rect band, Color color, int seed, {double alpha = 0.92, bool highlight = true}) {
  if (band.width <= 0.5) return;
  final p = wobblePath(Path()..addRect(band), seed: seed, amplitude: math.min(1.4, band.width * 0.08), step: 3);
  c.drawPath(p, _wash(color.withValues(alpha: alpha)));
  c.drawPath(p, _inkPen(Color.lerp(color, _umber, 0.45)!.withValues(alpha: 0.5), 1.6));
  final hl = Rect.fromLTWH(band.left + band.width * 0.2, band.top + band.height * 0.3, band.width * 0.6, band.height * 0.18);
  if (highlight && hl.width > 2) {
    final shine = wobblePath(Path()..addRRect(RRect.fromRectAndRadius(hl, Radius.circular(hl.height / 2))), seed: SLRandom.mix(seed, 5), amplitude: 0.5, step: 2);
    c.drawPath(shine, _wash(const Color(0x33FFFFFF)));
  }
}

// ------------------------------------------------------------------ Nhãn giấy

/// Nhãn giấy viền mực run tay chứa chữ [text] (đã layout). Gốc hình = góc trên trái của nhãn.
GameArt buildPaperTag(TextPainter text, {Color color = SLColors.paper, double padX = 10, double padY = 3.5, int seed = 0}) {
  final size = Size((text.width + padX * 2).ceilToDouble(), (text.height + padY * 2).ceilToDouble());
  final art = buildSurfaceArt(
    SLSurfaceSpec(shape: SLRoundRect(math.min(12, size.height / 2)), color: color, inkWidth: 1.8, seed: seed),
    size,
  );
  final picture = recordArt((c) {
    paintSLShadow(c, art.outline, 2.5);
    c.drawPicture(art.picture);
    text.paint(c, Offset((size.width - text.width) / 2, padY));
  });
  return GameArt(picture, size, text: text, parts: [art]);
}

// ------------------------------------------------------------------ Đĩa (ô chọn khuôn / topping)

/// Đĩa sứ tròn đựng đồ (khay khuôn, khay topping) vẽ tay, tâm [c] bán kính [r]; [glow] = quầng vàng khi nhắm tới.
void paintPlate(Canvas canvas, Offset c, double r, {double glow = 0}) {
  paintGlow(canvas, Rect.fromCircle(center: c, radius: r + 10), glow);
  final art = cachedArt(('plate', r), () => buildPlateArt(r));
  drawPictureAt(canvas, art.picture, c - art.origin);
}

const Color _porcelain = Color(0xFFFFFBF3);
const Color _porcelainWash = Color(0xFFF3E6D4);

/// Đĩa sứ vẽ tay bán kính [r]: màu nước kem, viền mực run tay, lòng đĩa nét caramel, chấm bạc hà. Gốc hình là
/// tâm đĩa trừ [GameArt.origin].
GameArt buildPlateArt(double r) {
  final m = r + 18; // lề cho bóng.
  final center = Offset(m, m);
  final seed = SLRandom.hashString('plate$r');
  final body = buildSurfaceArt(
    SLSurfaceSpec(
      shape: const SLCircle(),
      material: SLMaterial.wash,
      color: _porcelainWash,
      paper: _porcelain,
      inkWidth: 2.6,
      seed: seed,
    ),
    Size.square(r * 2),
  );
  final rnd = SLRandom(seed);
  final picture = recordArt((c) {
    paintShadow(c, center.translate(0, r * 0.25), r * 2.1, r * 0.9);
    c.save();
    c.translate(m - r, m - r);
    c.drawPicture(body.picture);
    c.restore();
    // Lòng đĩa lõm: giấy sáng + nét caramel run tay.
    final well = r * 0.72;
    final wellPath = wobblePath(Path()..addOval(Rect.fromCircle(center: center, radius: well)), seed: rnd.nextInt32(), amplitude: 1.1);
    c.drawPath(wellPath, _wash(_porcelain.withValues(alpha: 0.85)));
    c.drawPath(wellPath, _inkPen(SLColors.caramel.withValues(alpha: 0.55), 1.6));
    // Chấm bạc hà màu nước trên vành.
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi * 2 / 16 + rnd.range(-0.05, 0.05);
      final p = center + Offset(math.cos(a), math.sin(a)) * (r * 0.86);
      final dot = wobblePath(Path()..addOval(Rect.fromCircle(center: p, radius: math.max(2.0, r * 0.042))), seed: rnd.nextInt32(), amplitude: 0.5, step: 2);
      c.drawPath(dot, _wash(SLColors.mint.withValues(alpha: 0.9)));
    }
    // Vệt sáng trên-phải của vành (góc −0,42π..−0,12π): đoạn của vòng run tay.
    final rim = wobblePath(Path()..addOval(Rect.fromCircle(center: center, radius: r * 0.9)), seed: rnd.nextInt32(), amplitude: 1);
    c.drawPath(extractFraction(rim, 0.79, 0.94), _inkPen(const Color(0xB3FFFFFF), math.max(2, r * 0.05)));
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m, m), parts: [body]);
}

// ------------------------------------------------------------------ Thanh đo

/// Lớp tĩnh của thanh đo, vẽ trong toạ độ cục bộ [r] (0,0 → rộng×cao của thanh).
typedef MeterLayer = void Function(Canvas c, Rect r);

const double _meterMargin = 8;

/// Ống giấy viền mực run tay của thanh đo cỡ [size]: [GameArt.picture] = bóng + giấy + [back] (dưới phần động),
/// [GameArt.overlay] = [front] (vùng màu nước, vạch) + nét mực (trên phần động). Cả hai cắt theo đường viền run.
GameArt buildMeterArt(Size size, {MeterLayer? back, MeterLayer? front, int seed = 0}) {
  final local = Offset.zero & size;
  final tube = buildSurfaceArt(
    SLSurfaceSpec(shape: SLRoundRect(size.height / 2), color: _porcelain, outline: false, seed: seed),
    size,
  );
  final outline = tube.outline;
  final under = recordArt((c) {
    c.translate(_meterMargin, _meterMargin);
    paintSLShadow(c, outline, 3);
    c.drawPicture(tube.picture);
    if (back != null) {
      c.save();
      c.clipPath(outline);
      back(c, local);
      c.restore();
    }
    // Lõm nhẹ mép trên của ống.
    c.save();
    c.clipPath(outline);
    final lip = Path()
      ..moveTo(-4, -4)
      ..lineTo(size.width + 4, -4)
      ..lineTo(size.width + 4, size.height * 0.2)
      ..lineTo(-4, size.height * 0.22)
      ..close();
    c.drawPath(wobblePath(lip, seed: SLRandom.mix(seed, 9), amplitude: 0.8, step: 4), _wash(const Color(0x1F7A4A34)));
    c.restore();
  });
  final over = recordArt((c) {
    c.translate(_meterMargin, _meterMargin);
    if (front != null) {
      c.save();
      c.clipPath(outline);
      front(c, local);
      c.restore();
    }
    inkOutline(c, outline, width: 2.6, seed: seed);
  });
  return GameArt(under, size, origin: const Offset(_meterMargin, _meterMargin), overlay: over, parts: [tube]);
}

/// Vẽ thanh đo vẽ tay ở [rect]: phần tĩnh lấy từ cache theo [key] (+ cỡ), phần đã đầy [level] (0..1) tô
/// [fillColor] giữa hai lớp. [back]/[front] chỉ được gọi khi dựng hình.
void paintSketchMeter(
  Canvas canvas,
  Rect rect,
  Object key, {
  MeterLayer? back,
  MeterLayer? front,
  double level = 0,
  Color fillColor = SLColors.butterLight,
}) {
  final art = cachedArt(('meter', key, rect.width, rect.height), () => buildMeterArt(rect.size, back: back, front: front, seed: SLRandom.hashString('$key')));
  final at = rect.topLeft - art.origin;
  drawPictureAt(canvas, art.picture, at);
  final f = level.clamp(0.0, 1.0);
  if (f > 0) {
    final inner = rect.deflate(3);
    final x = rect.left + rect.width * f;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
    canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, x, rect.bottom), fill(fillColor));
    // Mép nước đọng màu đậm: nét run tay dựng sẵn theo chiều cao thanh, chỉ dời tới [x].
    canvas.save();
    canvas.translate(x, rect.top);
    canvas.drawPath(_meterEdge(rect.height), softStroke(Color.lerp(fillColor, _umber, 0.4)!.withValues(alpha: 0.6), 1.6));
    canvas.restore();
    canvas.restore();
  }
  final overlay = art.overlay;
  if (overlay != null) drawPictureAt(canvas, overlay, at);
}

final Map<double, Path> _meterEdges = {};

/// Mép phần đã đầy của thanh đo cao [h]: nét dọc run tay (gốc ở mép trên), dựng một lần theo chiều cao.
Path _meterEdge(double h) => _meterEdges[h] ??= wobblePath(Path()..moveTo(0, -2)..lineTo(-0.6, h * 0.5)..lineTo(0.4, h + 2), seed: 0xED6E, amplitude: 1.1, step: 3);

/// Kim chỉ vẽ tay (nét mực + mũi tam giác) trên thanh đo [meter] tại hoành độ [x].
void paintSketchMarker(Canvas canvas, Rect meter, double x) {
  final art = cachedArt(('marker', meter.height), () {
    final h = meter.height;
    const m = 16.0;
    final picture = recordArt((c) {
      c.translate(m, m);
      final rnd = SLRandom(0x4D4B);
      final needle = wobblePath(Path()..moveTo(0, 1)..lineTo(0, h - 1), seed: rnd.nextInt32(), amplitude: 0.6, step: 3);
      c.drawPath(needle, _inkPen(const Color(0xCCFFFBF3), 6.5));
      c.drawPath(needle, _inkPen(SLColors.ink, 3.6));
      final tri = wobblePath(
        Path()
          ..moveTo(-10, -15)
          ..lineTo(10, -15)
          ..lineTo(0, -3)
          ..close(),
        seed: rnd.nextInt32(),
        amplitude: 0.7,
        step: 2,
      );
      c.drawPath(tri, _wash(SLColors.butter));
      c.drawPath(tri, _inkPen(SLColors.ink, 2.4));
    });
    return GameArt(picture, Size(0, h), origin: const Offset(m, m));
  });
  drawPictureAt(canvas, art.picture, Offset(x, meter.top) - art.origin);
}

// ------------------------------------------------------------------ Nhãn dán tròn (nút, dấu)

/// Đĩa nhãn dán tròn bán kính [r] (màu nước [color], viền giấy + nét mực run tay); [content] vẽ thêm lên mặt
/// (tâm tại `Offset(r, r)`). Gốc hình = tâm trừ [GameArt.origin].
GameArt buildStickerDisc(double r, Color color, {int seed = 0, double inkWidth = 3, Color ink = SLColors.ink, void Function(Canvas c, Offset center)? content, TextPainter? text}) {
  const m = 6.0;
  final art = buildSurfaceArt(
    SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: color, ink: ink, inkWidth: inkWidth, sticker: true, seed: seed),
    Size.square(r * 2),
  );
  final picture = recordArt((c) {
    c.translate(m, m);
    c.drawPicture(art.picture);
    content?.call(c, Offset(r, r));
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m + r, m + r), text: text, parts: [art]);
}

/// Vẽ icon SL [id] (nét mực run tay) cỡ [size] căn giữa tại [center] — chỉ dùng khi dựng hình (Picture icon nằm
/// trong cache icon của bộ SL*).
void paintSLIcon(Canvas c, String id, Offset center, double size, {Color ink = SLColors.ink}) {
  final art = slIconArt(id, size, ink: ink);
  c.save();
  c.translate(center.dx - art.size / 2, center.dy - art.size / 2);
  c.drawPicture(art.picture);
  c.restore();
}

/// Dấu "sai" (nhãn dán đỏ nhạt có dấu ×) tâm [center].
void paintWrongMark(Canvas canvas, Offset center, {double radius = 16}) {
  final art = cachedArt(('wrong', radius), () => buildStickerDisc(radius, SLColors.dangerSoft, seed: 0xBAD, inkWidth: 2.2, content: (c, o) {
        final k = radius * 0.42;
        final rnd = SLRandom(0xBAD1);
        for (final (a, b) in [(Offset(-k, -k), Offset(k, k)), (Offset(k, -k), Offset(-k, k))]) {
          c.drawPath(wobblePath(Path()..moveTo(o.dx + a.dx, o.dy + a.dy)..lineTo(o.dx + b.dx, o.dy + b.dy), seed: rnd.nextInt32(), amplitude: 0.6, step: 2), _inkPen(SLColors.ink, 3.4));
        }
      }));
  drawPictureAt(canvas, art.picture, center - art.origin);
}

/// Mũi tên gợi ý kéo (nét bút caramel run tay, chĩa sang trái) với mũi tại [tip].
void paintHintArrow(Canvas canvas, Offset tip) {
  final art = cachedArt('hintArrow', () {
    const m = 10.0;
    final picture = recordArt((c) {
      c.translate(m, m + 16);
      final rnd = SLRandom(0xA770);
      final head = wobblePath(Path()..moveTo(30, -16)..lineTo(0, 0)..lineTo(30, 16), seed: rnd.nextInt32(), amplitude: 0.9, step: 3);
      final shaft = wobblePath(Path()..moveTo(4, 0)..quadraticBezierTo(40, -4, 64, 2), seed: rnd.nextInt32(), amplitude: 0.9, step: 3);
      for (final p in [head, shaft]) {
        c.drawPath(p, _inkPen(SLColors.caramel.withValues(alpha: 0.85), 6));
        c.drawPath(p, _inkPen(SLColors.ink.withValues(alpha: 0.35), 1.4));
      }
    });
    return GameArt(picture, const Size(64, 32), origin: const Offset(m, m + 16));
  });
  drawPictureAt(canvas, art.picture, tip - art.origin);
}

// ------------------------------------------------------------------ Khay nướng (trạm khuôn)

const Color _steelWash = Color(0xFFB9C5CE);
const Color _steelPaper = Color(0xFFE8EDF0);
const Color _steelDeep = Color(0xFF8E9DAA);
const Color _parchment = Color(0xFFFBF1DD);

/// Khay nướng vẽ tay cỡ [size]: vành thép màu nước xám xanh loang (vệt sáng mềm), quai cầm run tay hai bên,
/// lòng khay lõm, giấy nến kem có nếp gấp mềm và lưới bút chì rất nhạt. Gốc hình = góc trên trái khay trừ
/// [GameArt.origin].
GameArt buildBakingTrayArt(Size size) {
  const m = 34.0; // lề cho quai cầm + bóng.
  final seed = SLRandom.hashString('tray${size.width}x${size.height}');
  final rnd = SLRandom(seed);
  final rect = const Offset(m, m) & size;
  final rim = buildSurfaceArt(
    SLSurfaceSpec(shape: const SLRoundRect(26), material: SLMaterial.wash, color: _steelWash, paper: _steelPaper, inkWidth: 3, seed: seed),
    size,
  );
  final innerRect = rect.deflate(16);
  final inner = wobblePath(Path()..addRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(16))), seed: rnd.nextInt32(), amplitude: 1.4);
  final paperRect = innerRect.deflate(7);
  final parchment = buildSurfaceArt(
    SLSurfaceSpec(shape: const SLRoundRect(10), color: _parchment, ink: const Color(0xFFC9A57E), inkWidth: 1.5, seed: rnd.nextInt32()),
    paperRect.size,
  );
  final picture = recordArt((c) {
    paintShadow(c, Offset(rect.center.dx, rect.bottom - 6), size.width * 1.02, 40, alpha: 0.2);
    // Quai cầm hai bên: viên thuốc run tay, thép loang, nửa trái trong bóng, vệt sáng.
    for (final dx in [rect.left - 12, rect.right + 12]) {
      final h = Rect.fromCenter(center: Offset(dx, rect.center.dy), width: 26, height: 74);
      final p = wobblePath(Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(12))), seed: rnd.nextInt32(), amplitude: 1.1);
      c.drawPath(p, _wash(_steelWash));
      c.save();
      c.clipPath(p);
      c.drawPath(
        wobblePath(Path()..addOval(Rect.fromLTRB(h.left - 8, h.top, h.center.dx, h.bottom + 6)), seed: rnd.nextInt32(), amplitude: 1),
        _wash(_steelDeep.withValues(alpha: 0.4)),
      );
      c.restore();
      final shine = wobblePath(Path()..moveTo(dx + 5, h.top + 13)..lineTo(dx + 4.5, h.center.dy + 8), seed: rnd.nextInt32(), amplitude: 0.6);
      c.drawPath(shine, _inkPen(const Color(0xB3FFFFFF), 3));
      inkOutline(c, p, width: 2.4, seed: rnd.nextInt32());
    }
    // Vành thép.
    c.save();
    c.translate(rect.left, rect.top);
    c.drawPicture(rim.picture);
    c.clipPath(rim.outline);
    // Vệt phản chiếu: dải màu nước trắng loang chéo (mép run, không thẳng như kính).
    for (final (x, w, a) in [(0.6, 30.0, 0.34), (0.6 + 40 / size.width, 10.0, 0.28), (0.1, 16.0, 0.24)]) {
      final x0 = size.width * x;
      final band = Path()
        ..moveTo(x0, -4)
        ..lineTo(x0 + w, -4)
        ..lineTo(x0 + w - size.height * 0.5, size.height + 4)
        ..lineTo(x0 - size.height * 0.5, size.height + 4)
        ..close();
      c.drawPath(wobblePath(band, seed: rnd.nextInt32(), amplitude: 1.6, step: 4), _wash(Color.fromRGBO(255, 255, 255, a)));
    }
    c.restore();
    // Lòng khay lõm: thành trong phía trên-phải tối hơn.
    c.drawPath(inner, _wash(_steelDeep.withValues(alpha: 0.55)));
    c.save();
    c.clipPath(inner);
    c.drawPath(inner.shift(const Offset(-4, 5)), _wash(const Color(0xFFDCE3E8)));
    c.restore();
    // Giấy nến: bóng mềm lệch dưới-trái + giấy kem viền caramel.
    c.save();
    c.translate(paperRect.left, paperRect.top);
    for (final (o, a) in [(const Offset(-2, 3), 0.16), (const Offset(-1, 1.5), 0.12)]) {
      c.drawPath(parchment.outline.shift(o), _wash(Color.fromRGBO(128, 74, 52, a)));
    }
    c.drawPicture(parchment.picture);
    c.clipPath(parchment.outline);
    // Lưới bút chì rất nhạt, mỗi nét run một chút.
    final grid = _inkPen(const Color(0x14B9805A), 1.3);
    for (var x = 17.0; x < paperRect.width; x += 34) {
      c.drawPath(wobblePath(Path()..moveTo(x, 2)..lineTo(x + 1, paperRect.height - 2), seed: rnd.nextInt32(), amplitude: 1.2, step: 6), grid);
    }
    for (var y = 17.0; y < paperRect.height; y += 34) {
      c.drawPath(wobblePath(Path()..moveTo(2, y)..lineTo(paperRect.width - 2, y + 1), seed: rnd.nextInt32(), amplitude: 1.2, step: 6), grid);
    }
    // Nếp gấp mềm: vệt nâu nhạt + vệt sáng song song, cong nhẹ.
    final fold = wobblePath(
      Path()
        ..moveTo(paperRect.width * 0.08, 0)
        ..quadraticBezierTo(paperRect.width * 0.14, paperRect.height * 0.5, paperRect.width * 0.2, paperRect.height),
      seed: rnd.nextInt32(),
      amplitude: 1.4,
    );
    c.drawPath(fold, _inkPen(const Color(0x14804A34), 7));
    c.drawPath(fold.shift(const Offset(5, 0)), _inkPen(const Color(0x2EFFFFFF), 6));
    final fold2 = wobblePath(
      Path()
        ..moveTo(paperRect.width * 0.8, 0)
        ..quadraticBezierTo(paperRect.width * 0.7, paperRect.height * 0.55, paperRect.width * 0.66, paperRect.height),
      seed: rnd.nextInt32(),
      amplitude: 1.4,
    );
    c.drawPath(fold2, _inkPen(const Color(0x40FFFFFF), 11));
    c.drawPath(fold2.shift(const Offset(-6, 0)), _inkPen(const Color(0x0F804A34), 5));
    c.restore();
    inkOutline(c, inner, width: 2, ink: SLColors.ink.withValues(alpha: 0.7), seed: rnd.nextInt32());
  });
  return GameArt(picture, size, origin: const Offset(m, m), parts: [rim, parchment]);
}

// ------------------------------------------------------------------ Đĩa bầu dục dưới bánh (topping, hộp)

/// Đĩa sứ bầu dục vẽ tay cỡ [size] (khung elip mặt đĩa): bóng mềm + bóng tiếp xúc dưới đĩa (đĩa ngồi trên mặt
/// bàn), bề dày đĩa, mặt sứ màu nước viền mực run tay, vành bạc hà loang, chấm hồng nhỏ, lòng đĩa nét caramel,
/// vệt sáng. Gốc hình = góc trên trái khung elip trừ [GameArt.origin].
GameArt buildServingPlateArt(Size size) {
  const m = 30.0;
  final seed = SLRandom.hashString('servingPlate${size.width}x${size.height}');
  final rnd = SLRandom(seed);
  final oval = const Offset(m, m) & size;
  final h = size.height;
  final body = buildSurfaceArt(
    SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: _porcelainWash, paper: _porcelain, inkWidth: 2.6, seed: seed),
    size,
  );
  Path ring(Rect r, {double amp = 1.2}) => wobblePath(Path()..addOval(r), seed: rnd.nextInt32(), amplitude: amp, step: 4);
  final picture = recordArt((c) {
    // Bóng rộng mềm + bóng tiếp xúc đậm, hẹp ngay dưới mép đĩa.
    paintShadow(c, oval.center.translate(0, h * 0.34), size.width * 1.04, h * 0.85, alpha: 0.16);
    paintShadow(c, oval.center.translate(0, h * 0.2), size.width * 0.94, h * 0.62, alpha: 0.26);
    // Bề dày đĩa.
    final side = ring(oval.translate(0, h * 0.1));
    c.drawPath(side, _wash(const Color(0xFFE6D3BC)));
    inkOutline(c, side, width: 2.4, seed: rnd.nextInt32());
    c.save();
    c.translate(m, m);
    c.drawPicture(body.picture);
    c.restore();
    // Vành bạc hà loang (nét màu nước rộng, hai lớp lệch nhau) giữa mép và lòng đĩa.
    final band = ring(oval.deflate(h * 0.1), amp: 1.4);
    c.drawPath(band, _inkPen(SLColors.mint.withValues(alpha: 0.42), h * 0.075));
    c.drawPath(band.shift(const Offset(0.8, -0.6)), _inkPen(SLColors.mint.withValues(alpha: 0.3), h * 0.04));
    // Chấm hồng nhỏ trên vành.
    final rx = size.width / 2 - h * 0.1, ry = h / 2 - h * 0.1;
    for (var i = 0; i < 22; i++) {
      final a = i * math.pi * 2 / 22 + rnd.range(-0.04, 0.04);
      final p = oval.center + Offset(math.cos(a) * rx, math.sin(a) * ry);
      final dot = wobblePath(Path()..addOval(Rect.fromCircle(center: p, radius: math.max(1.6, h * 0.026))), seed: rnd.nextInt32(), amplitude: 0.4, step: 2);
      c.drawPath(dot, _wash(SLColors.strawberry.withValues(alpha: 0.85)));
    }
    // Lòng đĩa.
    final well = ring(oval.deflate(h * 0.2), amp: 1.1);
    c.drawPath(well, _wash(_porcelain.withValues(alpha: 0.8)));
    c.drawPath(well, _inkPen(SLColors.caramel.withValues(alpha: 0.5), 1.5));
    // Vệt sáng trên-phải của vành (góc −0,42π..−0,12π trên elip).
    c.drawPath(extractFraction(ring(oval.deflate(h * 0.06)), 0.79, 0.93), _inkPen(const Color(0xCCFFFFFF), math.max(2.2, h * 0.05)));
  });
  return GameArt(picture, size, origin: const Offset(m, m), parts: [body]);
}

// ------------------------------------------------------------------ Tờ giấy cột phải (vé đơn + gợi ý)

/// Tờ giấy kem phủ cột phải (x ≥ 940) toàn chiều cao vùng chơi: mép trái xé nhẹ run tay, vân giấy, mép đọng màu,
/// bóng mềm hắt sang trái. Toạ độ khung 1280×720 (gốc hình = 0,0); phần tràn ra ngoài khung bị cắt.
GameArt buildColumnSheetArt({double alpha = 0.78}) {
  final rnd = SLRandom(0xC01A);
  const left = 941.0, top = 62.0, right = 1300.0, bottom = 740.0;
  // Mép trái xé: lượn chậm + răng nhỏ không đều.
  final ideal = Path()
    ..moveTo(right, top)
    ..lineTo(left + 2, top);
  for (var y = top + 6; y < bottom; y += rnd.range(5, 9)) {
    final x = left + 2.2 * math.sin(y / 70) + 1.4 * math.sin(y / 23 + 1) + rnd.range(-1.3, 1.3);
    ideal.lineTo(x, y);
  }
  ideal
    ..lineTo(left, bottom)
    ..lineTo(right, bottom)
    ..close();
  final outline = wobblePath(ideal, seed: 0xC01B, amplitude: 0.7, step: 2.5);
  final picture = recordArt((c) {
    // Bóng mềm hắt sang trái: vài lớp mờ chồng nhau (rẻ hơn làm mờ).
    for (final (dx, a) in [(-7.0, 0.035), (-4.5, 0.05), (-2.5, 0.07)]) {
      c.drawPath(outline.shift(Offset(dx, 2)), _wash(Color.fromRGBO(106, 67, 52, a)));
    }
    c.drawPath(outline, _wash(const Color(0xFFFFF6EA).withValues(alpha: alpha)));
    c.save();
    c.clipPath(outline);
    // Mép giấy đọng màu (nét rộng trong suốt, cắt trong tờ).
    for (final (w, a) in [(18.0, 0.04), (9.0, 0.05), (3.0, 0.08)]) {
      c.drawPath(outline, _inkPen(SLColors.caramel.withValues(alpha: a), w));
    }
    // Vệt loang giấy.
    for (var i = 0; i < 5; i++) {
      final center = Offset(rnd.range(980, 1260), rnd.range(110, 700));
      final r = rnd.range(40, 90);
      c.drawPath(
        wobblePath(Path()..addOval(Rect.fromCircle(center: center, radius: r)), seed: rnd.nextInt32(), amplitude: r * 0.15, step: 6),
        _wash(SLColors.caramel.withValues(alpha: 0.03)),
      );
    }
    // Vân giấy: chấm sáng/tối li ti + sợi xơ ngắn.
    final dark = <Offset>[], light = <Offset>[], fibers = <Offset>[];
    for (var i = 0; i < 520; i++) {
      (i.isEven ? dark : light).add(Offset(rnd.range(left, 1280), rnd.range(72, 720)));
    }
    for (var i = 0; i < 46; i++) {
      final p = Offset(rnd.range(left, 1280), rnd.range(72, 720));
      final a = rnd.range(0, math.pi), l = rnd.range(3, 7);
      fibers
        ..add(p)
        ..add(p + Offset(math.cos(a) * l, math.sin(a) * l));
    }
    c.drawPoints(ui.PointMode.points, dark, _inkPen(_umber.withValues(alpha: 0.1), 1.3));
    c.drawPoints(ui.PointMode.points, light, _inkPen(const Color(0x59FFFFFF), 1.4));
    c.drawPoints(ui.PointMode.lines, fibers, _inkPen(_umber.withValues(alpha: 0.08), 0.8));
    c.restore();
    inkOutline(c, outline, width: 1.6, ink: SLColors.inkSoft.withValues(alpha: 0.55), seed: 0xC01C);
  });
  return GameArt(picture, const Size(right - left, bottom - top));
}

// ------------------------------------------------------------------ Chấm / vòng mực (gợi ý)

/// Số biến thể chấm gợi ý dựng sẵn (chấm cạnh nhau khác nét).
const int kGuideDotVariants = 4;

/// Chấm màu nước run tay bán kính [r] màu [color], biến thể [variant] (chấm cạnh nhau khác nét); gốc hình = tâm
/// chấm trừ [GameArt.origin].
GameArt buildInkDotArt(double r, Color color, int variant) {
  final m = r + 4;
  final rnd = SLRandom(SLRandom.mix(0xD07, variant));
  final picture = recordArt((c) {
    final center = Offset(m, m);
    // Chấm hơi bầu dục, méo theo biến thể.
    final oval = Rect.fromCenter(center: center, width: r * 2 * rnd.range(0.9, 1.12), height: r * 2 * rnd.range(0.88, 1.08));
    final p = wobblePath(Path()..addOval(oval), seed: rnd.nextInt32(), amplitude: r * 0.4, step: 1.5);
    c.drawPath(p, _wash(color));
    // Mép đọng màu + đốm sáng nhỏ.
    c.drawPath(p, _inkPen(Color.lerp(color, _umber, 0.5)!.withValues(alpha: color.a * 0.55), 0.9));
    c.drawCircle(center.translate(-r * 0.3, -r * 0.3), r * 0.28, _wash(Color.fromRGBO(255, 255, 255, 0.35 * color.a)));
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m, m));
}

/// Vòng mực run tay bán kính [r], nét [width] màu [color]; gốc hình = tâm vòng trừ [GameArt.origin].
GameArt buildInkRingArt(double r, Color color, double width, {int seed = 0}) {
  final m = r + width + 4;
  final picture = recordArt((c) {
    final p = wobblePath(Path()..addOval(Rect.fromCircle(center: Offset(m, m), radius: r)), seed: seed, amplitude: 1, step: 2.5);
    c.drawPath(p, _inkPen(color, width));
    // Đoạn đè đậm (lực tay) + nét lệch mảnh.
    c.drawPath(extractFraction(p, 0.15, 0.4), _inkPen(color, width * 1.35));
    c.drawPath(p.shift(const Offset(0.8, 0.9)), _inkPen(Color.lerp(color, _umber, 0.4)!.withValues(alpha: 0.35), width * 0.4));
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m, m));
}

// ------------------------------------------------------------------ Giá nướng trong ô kính lò

/// Giá nướng thép dài [width] vẽ tay: thanh mực run tay chỗ dày chỗ mảnh + thân thép + vệt sáng + hai thanh đỡ mờ
/// phía sau. Gốc hình = đầu trái mặt trên giá trừ [GameArt.origin].
GameArt buildOvenRackArt(double width) {
  const m = 20.0;
  final rnd = SLRandom(SLRandom.hashString('rack$width'));
  final picture = recordArt((c) {
    c.translate(m, m);
    // Hai thanh đỡ chéo mờ phía sau (chiều sâu của giá).
    for (final x in [width * 0.18, width * 0.82]) {
      final strut = wobblePath(Path()..moveTo(x, 0)..lineTo(x + (x < width / 2 ? 12 : -12), -14), seed: rnd.nextInt32(), amplitude: 0.5);
      c.drawPath(strut, _inkPen(const Color(0x995E4038), 2));
    }
    final bar = wobblePath(Path()..moveTo(-4, 0)..lineTo(width * 0.5, 0.6)..lineTo(width + 4, -0.4), seed: rnd.nextInt32(), amplitude: 1.3, step: 5);
    c.drawPath(bar, _inkPen(const Color(0xFF5E4038), 5.5));
    for (var i = 0; i < 3; i++) {
      final from = rnd.range(0, 0.8);
      c.drawPath(extractFraction(bar, from, from + rnd.range(0.08, 0.18)), _inkPen(const Color(0xFF5E4038), 7.5));
    }
    c.drawPath(bar.shift(const Offset(0, -0.6)), _inkPen(const Color(0xFFB9BEC6), 2.6));
    c.drawPath(extractFraction(bar.shift(const Offset(0, -1.6)), 0.1, 0.9), _inkPen(const Color(0x8CFFFFFF), 1));
  });
  return GameArt(picture, Size(width, 0), origin: const Offset(m, m));
}

/// Giá nướng vẽ tay từ [left] tới [right], mặt trên giá ở độ cao [y].
void paintOvenRack(Canvas canvas, double left, double right, double y) {
  final w = right - left;
  final art = cachedArt(('rack', w), () => buildOvenRackArt(w));
  drawPictureAt(canvas, art.picture, Offset(left, y) - art.origin);
}
