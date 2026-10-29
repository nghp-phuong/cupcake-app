import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../sl_theme.dart';
import 'hand_drawn.dart';
import 'sl_cache.dart';
import 'sl_random.dart';

/// Chất liệu bề mặt.
enum SLMaterial {
  /// Giấy: màu giấy, mép ngả nâu nhẹ, vân giấy.
  paper,

  /// Màu nước tô trên giấy: lớp màu lệch khỏi nét mực một chút, mép đậm, giữa nhạt, vệt loang.
  wash,

  /// Gỗ: vân gỗ lượn, mắt gỗ, mép đậm.
  wood,

  /// Vải: sợi đan chéo + đường chỉ khâu chạy dọc mép.
  fabric,

  /// Băng dính trong mờ (màu đã có alpha), không vân.
  tape,
}

/// Mô tả đầy đủ một bề mặt vẽ tay — là giá trị (có ==) và là một phần khoá cache.
@immutable
class SLSurfaceSpec {
  const SLSurfaceSpec({
    required this.shape,
    this.material = SLMaterial.paper,
    this.color = SLColors.paper,
    this.paper = SLColors.paper,
    this.ink = SLColors.ink,
    this.inkWidth = SLMetrics.inkWidth,
    this.outline = true,
    this.sticker = false,
    this.roughness = 1,
    this.seed = 0,
  });

  final SLShape shape;
  final SLMaterial material;

  /// Màu chính (màu nước / giấy / gỗ / vải).
  final Color color;

  /// Giấy nền dưới lớp màu nước, cũng là viền "nhãn dán".
  final Color paper;
  final Color ink;
  final double inkWidth;

  /// Có nét mực viền không.
  final bool outline;

  /// Viền giấy trắng bên ngoài nét mực (cảm giác nhãn dán bóc ra).
  final bool sticker;
  final double roughness;
  final int seed;

  SLSurfaceSpec copyWith({Color? color, Color? ink, SLShape? shape, int? seed, bool? outline}) => SLSurfaceSpec(
        shape: shape ?? this.shape,
        material: material,
        color: color ?? this.color,
        paper: paper,
        ink: ink ?? this.ink,
        inkWidth: inkWidth,
        outline: outline ?? this.outline,
        sticker: sticker,
        roughness: roughness,
        seed: seed ?? this.seed,
      );

  @override
  bool operator ==(Object other) =>
      other is SLSurfaceSpec &&
      other.shape == shape &&
      other.material == material &&
      other.color == color &&
      other.paper == paper &&
      other.ink == ink &&
      other.inkWidth == inkWidth &&
      other.outline == outline &&
      other.sticker == sticker &&
      other.roughness == roughness &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(shape, material, color, paper, ink, inkWidth, outline, sticker, roughness, seed);
}

/// Bề mặt đã dựng: [outline] (đường viền run tay, dùng vẽ bóng / cắt) và [picture] (toàn bộ nền + nét).
class SLSurfaceArt implements SLCachedArt {
  SLSurfaceArt(this.size, this.outline, this.picture);

  final Size size;
  final Path outline;
  final ui.Picture picture;

  @override
  void dispose() => picture.dispose();
}

/// Lấy bề mặt từ cache (khoá: spec + kích thước làm tròn 1px); trượt thì dựng mới.
SLSurfaceArt slSurfaceArt(SLSurfaceSpec spec, Size size) {
  final w = math.max(1, size.width.round()), h = math.max(1, size.height.round());
  return SLPaintCache.surfaces.obtain((spec, w, h), () => buildSurfaceArt(spec, Size(w.toDouble(), h.toDouble()))) as SLSurfaceArt;
}

/// Độ run của viền theo cạnh ngắn (nút nhỏ run ít, panel lớn run nhiều hơn chút).
double slWobbleAmplitude(Size size, double roughness) => (size.shortestSide * 0.025).clamp(0.7, 1.8) * roughness;

Color _toward(Color c, Color target, double t) => Color.lerp(c, target, t)!;
const _umber = Color(0xFF6B4532);
const _white = Color(0xFFFFFFFF);

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Dựng bề mặt (không cache) — ghi vào một `ui.Picture`.
SLSurfaceArt buildSurfaceArt(SLSurfaceSpec spec, Size size) {
  final rect = Offset.zero & size;
  final rnd = SLRandom(spec.seed);
  final amp = slWobbleAmplitude(size, spec.roughness);
  final ideal = spec.shape.ideal(rect);
  final outline = spec.roughness <= 0 ? ideal : wobblePath(ideal, seed: spec.seed, amplitude: amp);
  final k = (size.shortestSide / 80).clamp(0.35, 1.0); // co hiệu ứng theo cỡ.

  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);

  if (spec.sticker) c.drawPath(outline, _stroke(spec.paper, spec.inkWidth + 5));

  switch (spec.material) {
    case SLMaterial.wash:
      c.drawPath(outline, _fill(spec.paper));
      // Lớp màu nước lệch khỏi nét mực một chút (lộ chút giấy ở vài chỗ), run theo seed khác.
      final inset = 1.4 + spec.inkWidth * 0.3;
      // Lệch ≤ 1px; lớp màu luôn bị cắt trong đường viền mực (không tràn ra ngoài hình).
      final shift = Offset(rnd.range(-0.7, 0.7), rnd.range(-0.4, 0.7));
      final washIdeal = spec.shape.ideal(rect.deflate(inset).shift(shift));
      final wash = wobblePath(washIdeal, seed: SLRandom.mix(spec.seed, 17), amplitude: amp * 1.3 + 0.4);
      c
        ..save()
        ..clipPath(outline);
      _watercolor(c, wash, rect, spec.color, rnd, k);
      c.restore();
      _grain(c, outline, rect, rnd, spec.color, density: 0.6);
    case SLMaterial.paper:
      c.drawPath(outline, _fill(spec.color));
      c
        ..save()
        ..clipPath(outline);
      _pooledEdge(c, outline, _toward(spec.color, SLColors.caramel, 0.5), k, strength: 0.55);
      // Vệt loang giấy nhỏ, nhạt và nằm hẳn trong lòng giấy (vệt to sát mép trông như mảng màu tràn).
      _blooms(c, rect.deflate(rect.shortestSide * 0.12), rnd, _toward(spec.color, SLColors.caramel, 0.35),
          count: 2, alpha: 0.045, minR: 0.08, maxR: 0.18);
      c.restore();
      _grain(c, outline, rect, rnd, spec.color, density: 1);
    case SLMaterial.wood:
      c.drawPath(outline, _fill(spec.color));
      c
        ..save()
        ..clipPath(outline);
      _woodGrain(c, rect, rnd, spec.color);
      _pooledEdge(c, outline, _toward(spec.color, _umber, 0.55), k, strength: 0.9);
      c.restore();
      _grain(c, outline, rect, rnd, spec.color, density: 0.5);
    case SLMaterial.fabric:
      c.drawPath(outline, _fill(spec.color));
      c
        ..save()
        ..clipPath(outline);
      _weave(c, rect, spec.color);
      _pooledEdge(c, outline, _toward(spec.color, _umber, 0.4), k, strength: 0.7);
      c.restore();
      // Đường chỉ khâu chạy trong mép.
      final stitchInset = math.min(5.0, size.shortestSide * 0.16);
      final stitchIdeal = spec.shape.ideal(rect.deflate(stitchInset));
      final stitch = wobblePath(stitchIdeal, seed: SLRandom.mix(spec.seed, 29), amplitude: amp * 0.6);
      c.drawPath(dashPath(stitch, dash: 5, gap: 3.5), _stroke(_toward(spec.color, _white, 0.75).withValues(alpha: 0.9), 1.3));
    case SLMaterial.tape:
      c.drawPath(outline, _fill(spec.color));
      c.drawPath(outline, _stroke(_toward(spec.color, _umber, 0.3).withValues(alpha: spec.color.a * 0.6), 0.8));
  }

  if (spec.outline && spec.material != SLMaterial.tape) _inkOutline(c, spec, ideal, outline, rect, rnd, amp);

  return SLSurfaceArt(size, outline, recorder.endRecording());
}

/// Màu nước: nền màu, mép đọng màu đậm (nhiều nét trong suốt chồng nhau + "đường thuỷ triều"), vệt loang
/// đậm/nhạt, một vùng sáng phía trên như giấy lộ ra.
void _watercolor(Canvas c, Path wash, Rect rect, Color color, SLRandom rnd, double k) {
  c.drawPath(wash, _fill(color));
  c
    ..save()
    ..clipPath(wash);
  // Vùng sáng (giấy lộ) phía trên lệch trái/phải theo seed.
  final hl = Rect.fromCenter(
    center: Offset(rect.left + rect.width * rnd.range(0.3, 0.7), rect.top + rect.height * rnd.range(0.2, 0.38)),
    width: rect.width * rnd.range(0.55, 0.85),
    height: rect.height * rnd.range(0.35, 0.55),
  );
  final hlPath = wobblePath(Path()..addOval(hl), seed: rnd.nextInt32(), amplitude: math.min(6, hl.shortestSide * 0.12));
  c.drawPath(hlPath, _fill(_white.withValues(alpha: 0.2)));
  _blooms(c, rect, rnd, _toward(color, _umber, 0.25), count: 3, alpha: 0.1);
  _blooms(c, rect, rnd, _toward(color, _white, 0.5), count: 2, alpha: 0.18);
  _pooledEdge(c, wash, _toward(color, _umber, 0.4), k, strength: 1);
  c.restore();
}

/// Mép đậm của màu nước: nét viền rộng → hẹp, trong suốt, cắt bên trong hình.
void _pooledEdge(Canvas c, Path p, Color edge, double k, {double strength = 1}) {
  const widths = [18.0, 11.0, 6.0];
  const alphas = [0.07, 0.09, 0.12];
  for (var i = 0; i < widths.length; i++) {
    c.drawPath(p, _stroke(edge.withValues(alpha: alphas[i] * strength), widths[i] * k));
  }
  c.drawPath(p, _stroke(edge.withValues(alpha: 0.32 * strength), 1.6));
}

/// Vệt loang: vài đốm tròn méo trong suốt, vị trí theo seed.
void _blooms(Canvas c, Rect rect, SLRandom rnd, Color color,
    {required int count, required double alpha, double minR = 0.18, double maxR = 0.42}) {
  if (rect.isEmpty) return;
  for (var i = 0; i < count; i++) {
    final r = rect.shortestSide * rnd.range(minR, maxR);
    final center = Offset(rect.left + rect.width * rnd.nextDouble(), rect.top + rect.height * rnd.nextDouble());
    final blob = wobblePath(Path()..addOval(Rect.fromCircle(center: center, radius: r)), seed: rnd.nextInt32(), amplitude: r * 0.18, step: 5);
    c.drawPath(blob, _fill(color.withValues(alpha: alpha * rnd.range(0.6, 1.2))));
  }
}

/// Vân giấy: chấm sáng/tối li ti + vài sợi xơ ngắn, mật độ theo diện tích (giới hạn để rẻ).
void _grain(Canvas c, Path clip, Rect rect, SLRandom rnd, Color base, {double density = 1}) {
  final area = rect.width * rect.height;
  final dots = (area / 420 * density).clamp(4, 360).round();
  final dark = <Offset>[], light = <Offset>[];
  for (var i = 0; i < dots; i++) {
    final p = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height);
    (i.isEven ? dark : light).add(p);
  }
  final fibers = <Offset>[];
  final nf = (area / 5200 * density).clamp(0, 50).round();
  for (var i = 0; i < nf; i++) {
    final p = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height);
    final a = rnd.range(0, math.pi), l = rnd.range(3, 7);
    fibers
      ..add(p)
      ..add(p + Offset(math.cos(a) * l, math.sin(a) * l));
  }
  c
    ..save()
    ..clipPath(clip);
  c.drawPoints(ui.PointMode.points, dark, _stroke(_toward(base, _umber, 0.6).withValues(alpha: 0.13), 1.3));
  c.drawPoints(ui.PointMode.points, light, _stroke(_white.withValues(alpha: 0.35), 1.4));
  if (fibers.isNotEmpty) c.drawPoints(ui.PointMode.lines, fibers, _stroke(_toward(base, _umber, 0.5).withValues(alpha: 0.1), 0.8));
  c.restore();
}

/// Vân gỗ: các đường lượn ngang (mỗi đường run theo seed), mắt gỗ, mối ghép ván nếu cao.
void _woodGrain(Canvas c, Rect rect, SLRandom rnd, Color base) {
  final line = _toward(base, _umber, 0.55);
  var y = rect.top + rnd.range(2, 6);
  while (y < rect.bottom) {
    final p = Path()..moveTo(rect.left - 6, y);
    final waves = math.max(2, (rect.width / 90).round());
    final seg = (rect.width + 12) / waves;
    for (var i = 0; i < waves; i++) {
      final x0 = rect.left - 6 + seg * i;
      p.quadraticBezierTo(x0 + seg / 2, y + rnd.range(-2.4, 2.4), x0 + seg, y + rnd.range(-0.8, 0.8));
    }
    c.drawPath(p, _stroke(line.withValues(alpha: rnd.range(0.18, 0.4)), rnd.range(0.7, 1.4)));
    y += rnd.range(5, 10);
  }
  final knots = math.max(1, (rect.width * rect.height / 40000).round());
  for (var i = 0; i < knots; i++) {
    final center = Offset(rect.left + rect.width * rnd.range(0.12, 0.88), rect.top + rect.height * rnd.range(0.2, 0.8));
    final r = math.min(9.0, rect.shortestSide * 0.12);
    for (var ring = 0; ring < 2; ring++) {
      c.drawOval(Rect.fromCenter(center: center, width: r * (2.6 - ring), height: r * (1.2 - ring * 0.45)),
          _stroke(line.withValues(alpha: 0.35), 1));
    }
  }
  if (rect.height > 90) {
    for (var sy = rect.top + 46.0; sy < rect.bottom - 20; sy += 46) {
      c.drawLine(Offset(rect.left, sy), Offset(rect.right, sy + rnd.range(-1, 1)), _stroke(line.withValues(alpha: 0.45), 1.6));
    }
  }
}

/// Sợi vải đan chéo hai chiều, rất mờ.
void _weave(Canvas c, Rect rect, Color base) {
  final dark = _stroke(_toward(base, _umber, 0.5).withValues(alpha: 0.07), 1);
  final light = _stroke(_white.withValues(alpha: 0.12), 1);
  final span = rect.width + rect.height;
  for (var d = 0.0; d < span; d += 4) {
    c.drawLine(Offset(rect.left + d, rect.top), Offset(rect.left + d - rect.height, rect.bottom), dark);
    c.drawLine(Offset(rect.left + d - rect.height, rect.top), Offset(rect.left + d, rect.bottom), light);
  }
}

/// Nét mực: nét phụ caramel lệch ~1px, nét chính, vài đoạn đè đậm (lực tay), nét tô lại mảnh lệch seed, nét lố góc.
void _inkOutline(Canvas c, SLSurfaceSpec spec, Path ideal, Path outline, Rect rect, SLRandom rnd, double amp) {
  final w = spec.inkWidth;
  c
    ..save()
    ..translate(1.1, 1.3)
    ..drawPath(outline, _stroke(SLColors.caramel.withValues(alpha: 0.5 * spec.ink.a), w * 0.55))
    ..restore();
  c.drawPath(outline, _stroke(spec.ink, w));
  for (var i = 0; i < 2; i++) {
    final from = rnd.nextDouble(), len = rnd.range(0.1, 0.24);
    c.drawPath(extractFraction(outline, from, math.min(1, from + len)), _stroke(spec.ink, w * 1.5));
  }
  if (spec.roughness > 0) {
    final retrace = wobblePath(ideal, seed: SLRandom.mix(spec.seed, 41), amplitude: amp * 0.8);
    final from = rnd.nextDouble();
    c.drawPath(extractFraction(retrace, from, math.min(1, from + 0.45)), _stroke(spec.ink.withValues(alpha: 0.55 * spec.ink.a), w * 0.45));
    final anchors = spec.shape.overshootAnchors(rect, rnd);
    if (anchors.isNotEmpty) {
      c.drawPath(overshootStrokes(outline, anchors, rnd), _stroke(spec.ink.withValues(alpha: 0.75 * spec.ink.a), w * 0.55));
    }
  }
}

/// Vẽ bóng nâu mềm (đường viền dịch xuống [lift]) — vẽ trực tiếp mỗi frame (rẻ: 2 lệnh vẽ Path đã cache).
void paintSLShadow(Canvas canvas, Path outline, double lift, {Color color = SLColors.shadow}) {
  if (lift <= 0) return;
  canvas
    ..save()
    ..translate(lift * 0.25, lift);
  canvas.drawPath(outline, _stroke(color.withValues(alpha: color.a * 0.45), 3));
  canvas.drawPath(outline, _fill(color));
  canvas.restore();
}

/// Painter của một bề mặt: bóng (cố định dưới đất, lệch [lift]) + bề mặt (dịch xuống [pressDepth] × press).
/// [press] là Animation (0 = nổi, 1 = lún) → vẽ lại không cần dựng lại widget.
class SLSurfacePainter extends CustomPainter {
  SLSurfacePainter({required this.spec, this.lift = 0, this.press, this.pressDepth = SLMetrics.pressDepth})
      : super(repaint: press);

  final SLSurfaceSpec spec;
  final double lift;
  final Animation<double>? press;
  final double pressDepth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final art = slSurfaceArt(spec, size);
    final sx = size.width / art.size.width, sy = size.height / art.size.height;
    final p = press?.value ?? 0;
    canvas.save();
    if (sx != 1 || sy != 1) canvas.scale(sx, sy);
    // Bóng thu lại theo độ lún (bề mặt tiến gần "mặt đất").
    paintSLShadow(canvas, art.outline, lift);
    canvas
      ..translate(0, pressDepth * p)
      ..drawPicture(art.picture)
      ..restore();
  }

  @override
  bool shouldRepaint(SLSurfacePainter old) =>
      old.spec != spec || old.lift != lift || old.press != press || old.pressDepth != pressDepth;
}

/// Widget bề mặt vẽ tay chứa [child]. [press] (tuỳ chọn) làm cả bề mặt lẫn [child] lún xuống.
class SLSurface extends StatelessWidget {
  const SLSurface({
    super.key,
    required this.spec,
    this.child,
    this.padding = EdgeInsets.zero,
    this.lift = 0,
    this.press,
    this.pressDepth = SLMetrics.pressDepth,
  });

  final SLSurfaceSpec spec;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double lift;
  final Animation<double>? press;
  final double pressDepth;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    final anim = press;
    if (anim != null) {
      content = AnimatedBuilder(
        animation: anim,
        builder: (context, child) => Transform.translate(offset: Offset(0, pressDepth * anim.value), child: child),
        child: content,
      );
    }
    return CustomPaint(
      painter: SLSurfacePainter(spec: spec, lift: lift, press: press, pressDepth: pressDepth),
      child: content,
    );
  }
}
