import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show FontWeight, TextPainter;

import '../../core/constants.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../../ui/sugarleaf/paint/sl_surface.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import 'level_layout.dart';

// Hình vẽ tay tĩnh của màn chơi level (dựng MỘT lần thành Picture, giữ trong `gameArtCache`): ô trạm, thẻ món, nhãn,
// bong bóng, khung tủ kính, nền bếp, nền tiệm dự phòng. Mỗi khung hình chỉ drawPicture.

const double _m = 8; // lề cho bóng

/// Mặt giấy / màu nước bo góc cỡ [size] có bóng mềm. Gốc hình = góc trên trái của mặt trừ [GameArt.origin].
GameArt buildCardArt(
  Size size, {
  Color color = SLColors.paper,
  SLMaterial material = SLMaterial.paper,
  double radius = 16,
  double inkWidth = 2,
  double lift = 3,
  int seed = 0,
}) {
  final art = buildSurfaceArt(
    SLSurfaceSpec(shape: SLRoundRect(radius), material: material, color: color, inkWidth: inkWidth, seed: seed),
    size,
  );
  final picture = recordArt((c) {
    c.translate(_m, _m);
    if (lift > 0) paintSLShadow(c, art.outline, lift);
    c.drawPicture(art.picture);
  });
  return GameArt(picture, size, origin: const Offset(_m, _m), parts: [art]);
}

/// Nhãn bo tròn hai đầu (nền chữ "+xu").
GameArt buildTagArt(Size size, Color color, {int seed = 0}) =>
    buildCardArt(size, color: color, material: SLMaterial.wash, radius: size.height / 2, inkWidth: 1.8, lift: 2, seed: seed);

/// Nút giấy màu nước có chữ [text] (đã layout; giải phóng cùng hình).
GameArt buildButtonArt(Size size, Color color, TextPainter text, {int seed = 0}) {
  final card = buildCardArt(size, color: color, material: SLMaterial.wash, radius: 16, inkWidth: 2, lift: 3, seed: seed);
  final picture = recordArt((c) {
    c.drawPicture(card.picture);
    text.paint(c, Offset(_m + (size.width - text.width) / 2, _m + (size.height - text.height) / 2));
  });
  return GameArt(picture, size, origin: card.origin, text: text, parts: [card]);
}

/// Bong bóng ý nghĩ tròn bán kính [r] + hai chấm đuôi về phía dưới-trái (đầu khách). Gốc = tâm bong bóng.
GameArt buildBubbleArt(double r, {Color color = SLColors.paper, Color ink = SLColors.ink, int seed = 0xB0B}) {
  final art = buildSurfaceArt(
    SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.paper, color: color, ink: ink, inkWidth: 2.2, seed: seed),
    Size.square(r * 2),
  );
  final m = r + 24;
  final rnd = SLRandom(seed);
  final picture = recordArt((c) {
    c.translate(m, m);
    for (final (o, rr) in [(Offset(-r * 0.95, r * 0.95), r * 0.2), (Offset(-r * 1.32, r * 1.36), r * 0.12)]) {
      final dot = wobblePath(Path()..addOval(Rect.fromCircle(center: o, radius: rr)), seed: rnd.nextInt32(), amplitude: 0.5, step: 2);
      c.drawPath(dot, fill(color));
      c.drawPath(dot, stroke(ink, 1.8));
    }
    c.save();
    c.translate(-r, -r);
    paintSLShadow(c, art.outline, 2.5);
    c.drawPicture(art.picture);
    c.restore();
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m, m), parts: [art]);
}

/// Nền bếp nhanh: mặt bàn gỗ sáng có gờ caramel phía trên (khung y 436..720).
GameArt buildKitchenBackdrop() {
  const size = Size(1300, 290);
  final art = buildSurfaceArt(
    const SLSurfaceSpec(shape: SLRoundRect(4), material: SLMaterial.wood, color: SLColors.woodLight, inkWidth: 2, seed: 0xB17C),
    size,
  );
  final picture = recordArt((c) {
    c.translate(-10, LevelLayout.kitchenTop - 4);
    c.drawPicture(art.picture);
    // Gờ bàn: dải gỗ đậm + nét mực run tay.
    final edge = wobblePath(Path()..addRect(const Rect.fromLTWH(0, 0, 1300, 11)), seed: 0xB17D, amplitude: 0.8, step: 4);
    c.drawPath(edge, fill(AppColors.caramel));
    c.drawPath(edge, stroke(SLColors.ink, 2));
    // Bóng đổ của gờ xuống mặt bàn.
    c.drawRect(const Rect.fromLTWH(0, 11, 1300, 6), fill(const Color(0x267A4A34)));
  });
  return GameArt(picture, size, parts: [art]);
}

/// Nền tiệm vẽ code khi chưa có ảnh `shop_base` (không vẽ nhân vật): tường kem, cửa sổ, quầy gỗ hai bên tủ.
GameArt buildShopFallback() {
  const size = Size(1280, LevelLayout.kitchenTop);
  final wood = buildSurfaceArt(
    const SLSurfaceSpec(shape: SLRoundRect(6), material: SLMaterial.wood, color: SLColors.wood, inkWidth: 2, seed: 0x5A0F),
    const Size(1300, 200),
  );
  final picture = recordArt((c) {
    c.drawRect(Offset.zero & size, fill(AppColors.cream));
    c.drawRect(const Rect.fromLTWH(0, 0, 1280, 22), fill(SLColors.paperShade));
    // Cửa sổ bên phải.
    const win = Rect.fromLTRB(1030, 30, 1230, 240);
    c.drawRect(win, fill(const Color(0xFFDDEFF2)));
    c.drawRect(win, stroke(SLColors.woodDark, 6));
    c.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), stroke(SLColors.woodDark, 4));
    // Kệ trên tường.
    for (final r in const [Rect.fromLTWH(200, 60, 210, 10), Rect.fromLTWH(650, 60, 210, 10)]) {
      c.drawRect(r, fill(SLColors.wood));
      c.drawRect(r, stroke(SLColors.ink, 1.6));
    }
    // Quầy gỗ.
    c.save();
    c.translate(-10, LevelLayout.leftCounterTop - 14);
    c.drawPicture(wood.picture);
    c.restore();
  });
  return GameArt(picture, size, parts: [wood]);
}

/// Tủ kính vẽ code (dự phòng khi chưa có ảnh nền `shop_base_empty`), cùng hình học với tủ trong ảnh: viền
/// [LevelLayout.caseOutline] gỗ caramel, lòng kính gần đục (che khách đứng sau), hai tầng kệ kính. Toạ độ khung.
GameArt buildCaseFrameArt() {
  const r = LevelLayout.caseRect;
  const glass = LevelLayout.caseGlass;
  final outline = LevelLayout.caseOutline;
  final glassPath = wobblePath(Path()..addRRect(RRect.fromRectAndCorners(glass, topLeft: const Radius.circular(14), topRight: const Radius.circular(14))),
      seed: 0xCA51, amplitude: 0.7, step: 4);
  final picture = recordArt((c) {
    c.drawPath(outline, fill(AppColors.caramel));
    c.drawPath(glassPath, fill(const Color(0xF4F7FBF6)));
    c.save();
    c.clipPath(glassPath);
    c.drawRect(Rect.fromLTWH(glass.left, glass.top, glass.width, glass.height * 0.55), fill(const Color(0x1FA8DCC8)));
    // Bóng gỗ đổ xuống mép trên lòng tủ.
    c.drawRect(Rect.fromLTWH(glass.left, glass.top, glass.width, 10), fill(const Color(0x2E7A4A34)));
    // Hai tầng kệ kính: mặt kệ (hình thang) + mép trước.
    for (final (y, bottom) in const [(LevelLayout.upperShelfY, LevelLayout.upperShelfBottom), (LevelLayout.lowerShelfY, LevelLayout.lowerShelfBottom)]) {
      final top = y - 12;
      final plate = Path()
        ..moveTo(glass.left + 14, top)
        ..lineTo(glass.right - 14, top)
        ..lineTo(glass.right, bottom - 6)
        ..lineTo(glass.left, bottom - 6)
        ..close();
      c.drawPath(plate, fill(const Color(0x40A8DCC8)));
      c.drawRect(Rect.fromLTRB(glass.left, bottom - 6, glass.right, bottom), fill(const Color(0x66DDEFF2)));
      c.drawLine(Offset(glass.left, bottom - 6), Offset(glass.right, bottom - 6), stroke(SLColors.inkSoft, 1.4));
      c.drawLine(Offset(glass.left, bottom), Offset(glass.right, bottom), stroke(SLColors.inkSoft, 1.4));
      c.drawLine(Offset(glass.left + 14, top), Offset(glass.right - 14, top), stroke(SLColors.pencil, 1.2));
    }
    c.restore();
    c.drawPath(glassPath, stroke(SLColors.ink, 1.6));
    c.drawPath(outline, stroke(SLColors.ink, 2));
  });
  return GameArt(picture, r.size);
}

/// Kệ bánh gỗ hai tầng vẽ code (dự phòng khi chưa có ảnh `level/case_stand`), cùng hình học với ảnh trong khung [r]
/// (toạ độ khung): chân đế, trụ giữa, hai đĩa gỗ có giấy lót ren. [upperPlateOnly] → chỉ đĩa tầng trên (vẽ đè lên bánh
/// tầng dưới).
GameArt buildCaseStandFallback(Rect r, {bool upperPlateOnly = false}) {
  final cx = r.center.dx;
  double y(double f) => r.top + r.height * f;
  final ink = stroke(SLColors.ink, 1.8);
  void plate(Canvas c, double surface, double halfW, int seed) {
    final top = Rect.fromCenter(center: Offset(cx, surface - 4), width: halfW * 2, height: halfW * 0.42);
    final rim = Rect.fromLTRB(top.left, top.center.dy, top.right, top.center.dy + 9);
    final body = wobblePath(Path()..addRect(rim), seed: seed, amplitude: 0.5, step: 4);
    c.drawPath(body, fill(SLColors.woodDark));
    c.drawPath(body, ink);
    final face = wobblePath(Path()..addOval(top), seed: seed + 1, amplitude: 0.6, step: 4);
    c.drawPath(face, fill(SLColors.woodLight));
    c.drawPath(face, ink);
    final doily = Rect.fromCenter(center: top.center, width: top.width * 0.62, height: top.height * 0.55);
    c.drawOval(doily, fill(const Color(0xFFFFFBF3)));
    c.drawOval(doily, stroke(SLColors.pencil, 1.2));
  }

  final picture = recordArt((c) {
    if (!upperPlateOnly) {
      // Chân đế + trụ.
      final foot = Rect.fromCenter(center: Offset(cx, r.bottom - 10), width: r.width * 0.5, height: 16);
      c.drawOval(foot, fill(SLColors.wood));
      c.drawOval(foot, ink);
      final pole = Rect.fromLTRB(cx - 5, y(0.04), cx + 5, r.bottom - 14);
      c.drawRect(pole, fill(SLColors.wood));
      c.drawRect(pole, ink);
      c.drawCircle(Offset(cx, y(0.04)), 7, fill(SLColors.woodLight));
      c.drawCircle(Offset(cx, y(0.04)), 7, ink);
      plate(c, y(LevelLayout.standLowerY), r.width * LevelLayout.standLowerHalfW + 6, 0x57A0);
    }
    plate(c, y(LevelLayout.standUpperY), r.width * LevelLayout.standUpperHalfW + 6, 0x57A4);
  });
  return GameArt(picture, r.size);
}

/// Bộ bàn tròn + 2 ghế gỗ vẽ code (dự phòng khi chưa có ảnh `level/cafe_table`) cỡ [size]; gốc = góc trên trái.
GameArt buildCafeTableFallback(Size size) {
  final w = size.width, h = size.height;
  final ink = stroke(SLColors.ink, 1.8);
  final picture = recordArt((c) {
    // Hai ghế: lưng cong + đệm hồng.
    for (final (x, seed) in [(w * 0.13, 0xCAF0), (w * 0.87, 0xCAF4)]) {
      final back = wobblePath(
        Path()
          ..moveTo(x - w * 0.1, h * 0.62)
          ..lineTo(x - w * 0.1, h * 0.2)
          ..quadraticBezierTo(x, h * 0.04, x + w * 0.1, h * 0.2)
          ..lineTo(x + w * 0.1, h * 0.62),
        seed: seed,
        amplitude: 0.6,
        step: 4,
      );
      c.drawPath(back, softStroke(SLColors.wood, 6));
      c.drawPath(back, stroke(SLColors.ink, 1.2));
      for (final dx in [-0.09, 0.09]) {
        c.drawLine(Offset(x + w * dx, h * 0.62), Offset(x + w * dx, h * 0.97), softStroke(SLColors.wood, 5));
      }
      final seat = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, h * 0.6), width: w * 0.28, height: h * 0.12), const Radius.circular(8));
      c.drawRRect(seat, fill(SLColors.strawberryLight));
      c.drawRRect(seat, ink);
    }
    // Bàn: trụ, chân đế, mặt tròn + khăn ren.
    final pole = Rect.fromLTRB(w * 0.47, h * 0.36, w * 0.53, h * 0.9);
    c.drawRect(pole, fill(SLColors.wood));
    c.drawRect(pole, ink);
    final foot = Rect.fromCenter(center: Offset(w / 2, h * 0.92), width: w * 0.36, height: h * 0.1);
    c.drawOval(foot, fill(SLColors.wood));
    c.drawOval(foot, ink);
    final top = Rect.fromCenter(center: Offset(w / 2, h * 0.3), width: w * 0.54, height: h * 0.28);
    final face = wobblePath(Path()..addOval(top), seed: 0xCAF8, amplitude: 0.6, step: 4);
    c.drawPath(face, fill(SLColors.woodLight));
    c.drawPath(face, ink);
    final doily = Rect.fromCenter(center: top.center, width: top.width * 0.5, height: top.height * 0.5);
    c.drawOval(doily, fill(const Color(0xFFFFFBF3)));
    c.drawOval(doily, stroke(SLColors.pencil, 1.2));
  });
  return GameArt(picture, size);
}

/// Vệt sáng mờ trên kính tủ (vẽ đè lên bánh để bánh nằm "trong" kính). Toạ độ khung.
GameArt buildCaseShineArt() {
  const glass = LevelLayout.caseGlass;
  final picture = recordArt((c) {
    c.save();
    c.clipRect(glass);
    for (final (x, w) in [(glass.left + glass.width * 0.58, 30.0), (glass.left + glass.width * 0.7, 10.0)]) {
      final p = Path()
        ..moveTo(x, glass.top)
        ..lineTo(x + w, glass.top)
        ..lineTo(x + w - 110, glass.bottom)
        ..lineTo(x - 110, glass.bottom)
        ..close();
      c.drawPath(p, fill(const Color(0x22FFFFFF)));
    }
    c.restore();
  });
  return GameArt(picture, glass.size);
}

/// Cột thứ [i] trong [slots] cột của tủ: mỗi ô tủ là một cột trong lòng kính, đủ hai tầng kệ. Toạ độ khung.
Rect caseCell(int i, int slots) {
  final area = LevelLayout.caseGlass.deflate(4);
  final cw = area.width / math.max(1, slots);
  return Rect.fromLTWH(area.left + i * cw, area.top, cw, area.height);
}

/// Số bánh tối đa trên một tầng kệ của một cột ở sức chứa gốc (ô 6 cái; kệ dưới đầy trước, rồi kệ trên).
const int caseShelfCapacity = 3;

/// Số bánh vẽ tối đa trên một tầng kệ (ô sức chứa 10 — thiết bị `wideCase` cấp cao nhất).
const int caseShelfMax = 5;

/// Số bánh vẽ tối đa trên một tầng kệ của ô chứa [slotCapacity] cái: 6 → 3, 8 → 4, 10 → 5 (hai tầng chia đều).
int caseShelfCapacityFor(int slotCapacity) => ((slotCapacity + 1) ~/ 2).clamp(caseShelfCapacity, caseShelfMax);

/// Vị trí (theo cạnh bánh gốc, so với tâm cột trên mặt kệ) của từng cái khi xếp [k] cái trên một tầng kệ: cái ở sau
/// (cao hơn) vẽ trước. 4–5 cái (ô `wideCase`): hai hàng chặt — hai cái hàng sau lộ nửa trên giữa khe hàng trước, mọi
/// cái nhỏ lại theo [caseShelfCakeScale]. Hằng số, không cấp phát.
const List<List<Offset>> caseShelfStack = [
  [],
  [Offset(0, 0)],
  [Offset(-0.36, 0), Offset(0.36, 0)],
  [Offset(0, -0.12), Offset(-0.42, 0.02), Offset(0.42, 0.02)],
  [Offset(-0.26, -0.28), Offset(0.26, -0.28), Offset(-0.52, 0.03), Offset(0.52, 0.03)],
  [Offset(-0.26, -0.28), Offset(0.26, -0.28), Offset(-0.52, 0.03), Offset(0.52, 0.03), Offset(0, 0.06)],
];

/// Cỡ bánh (theo cạnh gốc) khi một tầng kệ có [k] cái.
double caseShelfCakeScale(int k) => k > caseShelfCapacity ? 0.8 : 1;

/// Cỡ một cái bánh trong cột [cell] (vừa ba cái một tầng; cao vừa khe giữa hai tầng kệ).
double caseCakeSize(Rect cell) => math.min(50, cell.width / 1.84);

/// Tâm cái bánh "đại diện" của cột [cell] (cái đầu tiên ở kệ dưới).
Offset caseCakeCenter(Rect cell) => Offset(cell.center.dx, LevelLayout.lowerShelfY - caseCakeSize(cell) / 2);

/// Huy hiệu số của cột [cell] có [count] cái (mỗi tầng tối đa [perShelf] cái): góc trên phải của tầng kệ cao nhất
/// đang có bánh.
Offset caseBadgeAt(Rect cell, int count, {int perShelf = caseShelfCapacity}) {
  final s = caseCakeSize(cell);
  final shelf = count > perShelf ? LevelLayout.upperShelfY : LevelLayout.lowerShelfY;
  return Offset(math.min(cell.right - 12, cell.center.dx + s * 0.9), math.max(LevelLayout.caseGlass.top + 12, shelf - s * 1.05));
}

/// Huy hiệu số (nhãn dán tròn màu bơ): số bánh trong ô tủ / trên thẻ món. Gốc = tâm trừ [GameArt.origin].
GameArt buildCountBadge(CanvasText text, int n, {double r = 14}) {
  final tp = text.layout('$n', size: 15, weight: FontWeight.w800, maxWidth: 48, title: true);
  return buildStickerDisc(r, SLColors.butterLight, seed: 0xBAD6 + n, inkWidth: 2, text: tp, content: (c, o) {
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  });
}

/// Mũi tên vòng vẽ tay (nét bút caramel run tay, ~300°, mũi chĩa theo chiều kim đồng hồ) bán kính [r] quanh gốc
/// (0, 0) — gợi ý xoay ở trạm trộn; vẽ xoay theo thời gian. Gốc hình = tâm vòng trừ [GameArt.origin].
GameArt buildCircleArrowArt(double r) {
  final m = r + 20;
  final picture = recordArt((c) {
    c.translate(m, m);
    const sweep = math.pi * 1.65;
    final arc = wobblePath(Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: r), 0, sweep), seed: 0xA2C0, amplitude: 1, step: 4);
    final end = Offset(math.cos(sweep), math.sin(sweep)) * r;
    final tangent = Offset(-math.sin(sweep), math.cos(sweep)); // hướng đi theo chiều kim đồng hồ
    final normal = Offset(math.cos(sweep), math.sin(sweep));
    final tip = end + tangent * 14;
    final head = wobblePath(
      Path()
        ..moveTo((end + normal * 12).dx, (end + normal * 12).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((end - normal * 12).dx, (end - normal * 12).dy),
      seed: 0xA2C1,
      amplitude: 0.8,
      step: 3,
    );
    for (final p in [arc, head]) {
      c.drawPath(p, softStroke(const Color(0xE6FFFBEF), 10));
      c.drawPath(p, softStroke(AppColors.caramel, 6));
      c.drawPath(p, softStroke(SLColors.ink.withValues(alpha: 0.4), 1.4));
    }
  });
  return GameArt(picture, Size.square(r * 2), origin: Offset(m, m));
}

/// Số mức sáng dựng sẵn của quầng phát sáng (nhấp nháy = đổi mức, không làm mờ lúc vẽ).
const int kGlowLevels = 6;

/// Quầng vàng bơ mềm quanh khung [size] (gốc = góc trên trái khung) ở mức [level] / ([kGlowLevels] − 1): các vòng bo
/// tròn nhạt dần ra ngoài — không dùng MaskFilter.blur (rẻ khi vẽ mỗi khung).
GameArt buildGlowArt(Size size, int level, {double radius = 16, Color color = const Color(0xFFFFC23D)}) {
  final strength = 0.6 + 0.4 * level / (kGlowLevels - 1);
  final picture = recordArt((c) {
    for (var i = 7; i >= 0; i--) {
      final d = 1.5 + i * 1.8;
      final a = strength * 0.9 * math.pow(1 - i / 8, 1.4);
      c.drawRRect(
        RRect.fromRectAndRadius((Offset.zero & size).inflate(d), Radius.circular(radius + d)),
        softStroke(color.withValues(alpha: a.toDouble()), 3.4),
      );
    }
  });
  return GameArt(picture, size);
}

/// Chữ [text] (đã layout) ghi thành hình; gốc = góc trên trái chữ.
GameArt buildTextArt(TextPainter text) =>
    GameArt(recordArt((c) => text.paint(c, Offset.zero)), Size(text.width, text.height), text: text);

/// Kim chỉ của thanh đo cao [h] (nét mực + mũi tam giác bơ, như `paintSketchMarker`). Gốc = đỉnh kim trừ origin.
GameArt buildMarkerArt(double h) {
  const m = 16.0;
  final picture = recordArt((c) {
    c.translate(m, m);
    final rnd = SLRandom(0x4D4B);
    final needle = wobblePath(Path()..moveTo(0, 1)..lineTo(0, h - 1), seed: rnd.nextInt32(), amplitude: 0.6, step: 3);
    c.drawPath(needle, softStroke(const Color(0xCCFFFBF3), 6.5));
    c.drawPath(needle, softStroke(SLColors.ink, 3.6));
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
    c.drawPath(tri, fill(SLColors.butter));
    c.drawPath(tri, stroke(SLColors.ink, 2.4));
  });
  return GameArt(picture, Size(0, h), origin: const Offset(m, m));
}

/// Mũi tên gợi ý chĩa sang trái (nét bút caramel run tay, như `paintHintArrow`); gốc = mũi tên.
GameArt buildHintArrowArt() {
  const m = 10.0;
  final picture = recordArt((c) {
    c.translate(m, m + 16);
    final rnd = SLRandom(0xA770);
    final head = wobblePath(Path()..moveTo(30, -16)..lineTo(0, 0)..lineTo(30, 16), seed: rnd.nextInt32(), amplitude: 0.9, step: 3);
    final shaft = wobblePath(Path()..moveTo(4, 0)..quadraticBezierTo(40, -4, 64, 2), seed: rnd.nextInt32(), amplitude: 0.9, step: 3);
    for (final p in [head, shaft]) {
      c.drawPath(p, softStroke(SLColors.caramel.withValues(alpha: 0.85), 6));
      c.drawPath(p, softStroke(SLColors.ink.withValues(alpha: 0.35), 1.4));
    }
  });
  return GameArt(picture, const Size(64, 32), origin: const Offset(m, m + 16));
}
