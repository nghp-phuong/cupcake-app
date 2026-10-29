import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/art/art_sprites.dart';
import 'paint/hand_drawn.dart';
import 'paint/sl_cache.dart';
import 'paint/sl_random.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_theme.dart';

// Vật dụng vẽ tay nhỏ dùng chung giữa các màn: đĩa, bao bột, bóng đổ mềm, khung cắt run tay, icon trên đĩa màu
// nước. Nét run theo seed cố định; hình phức tạp ghi một lần thành Picture trong `SLPaintCache.surfaces`.

/// Hình vật dụng đã ghi sẵn trong cache.
class _PropArt implements SLCachedArt {
  _PropArt(this.picture);

  final ui.Picture picture;

  @override
  void dispose() => picture.dispose();
}

ui.Picture _cached(Object key, void Function(Canvas c) draw) => (SLPaintCache.surfaces.obtain(key, () {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      return _PropArt(recorder.endRecording());
    }) as _PropArt)
        .picture;

const _umber = Color(0xFF6B4532);
const _white = Color(0xFFFFFFFF);

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _pen(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Nét mực run tay kèm nét phụ caramel lệch ~1px (giống viền của SLSurface).
void _ink(Canvas c, Path p, double w, {Color ink = SLColors.ink}) {
  c
    ..save()
    ..translate(0.9, 1.1)
    ..drawPath(p, _pen(SLColors.caramel.withValues(alpha: 0.45), w * 0.55))
    ..restore()
    ..drawPath(p, _pen(ink, w));
}

/// Vệt loang tròn méo trong suốt.
void _bloom(Canvas c, Offset center, double r, Color color, int seed) {
  final blob = wobblePath(Path()..addOval(Rect.fromCircle(center: center, radius: r)), seed: seed, amplitude: r * 0.2, step: 4);
  c.drawPath(blob, _fill(color));
}

// ---------------------------------------------------------------------------------------------------- Bóng mềm

/// Bóng mềm hình elip dưới chân đồ vật: quầng nâu nhạt tắt dần ra mép, không có mép cứng (cùng kiểu bóng đồ trang
/// trí trong cảnh tiệm). Phủ đúng vùng được cấp.
class SLGroundShadow extends StatelessWidget {
  const SLGroundShadow({super.key, this.color = const Color(0x555A3E36)});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _GroundShadowPainter(color)));
}

class _GroundShadowPainter extends CustomPainter {
  _GroundShadowPainter(this.color);

  final Color color;
  Paint? _paint;
  double _forWidth = -1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = size.width / 2;
    if (_forWidth != r) {
      _forWidth = r;
      _paint = Paint()
        ..shader = ui.Gradient.radial(Offset.zero, r, [color, color.withValues(alpha: color.a * 0.5), color.withValues(alpha: 0)], const [0, 0.55, 1]);
    }
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(1, size.height / size.width)
      ..drawCircle(Offset.zero, r, _paint!)
      ..restore();
  }

  @override
  bool shouldRepaint(_GroundShadowPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------------------------------- Khung cắt

/// Cắt [child] theo [shape] run tay (seed cố định) — thay `ClipOval`/`ClipRRect` để mép ảnh khớp với khung vẽ tay.
/// Path chỉ dựng lại khi đổi kích thước.
class SLHandClip extends StatelessWidget {
  const SLHandClip({super.key, required this.child, this.shape = const SLCircle(), this.seed = 0, this.amplitude});

  final Widget child;
  final SLShape shape;
  final int seed;

  /// Độ run (px); null = theo cỡ như SLSurface.
  final double? amplitude;

  @override
  Widget build(BuildContext context) => ClipPath(clipper: _HandClipper(shape, seed, amplitude), child: child);
}

class _HandClipper extends CustomClipper<Path> {
  _HandClipper(this.shape, this.seed, this.amplitude);

  final SLShape shape;
  final int seed;
  final double? amplitude;

  @override
  Path getClip(Size size) {
    final ideal = shape.ideal(Offset.zero & size);
    return wobblePath(ideal, seed: seed, amplitude: amplitude ?? slWobbleAmplitude(size, 1));
  }

  @override
  bool shouldReclip(_HandClipper old) => old.shape != shape || old.seed != seed || old.amplitude != amplitude;
}

// ---------------------------------------------------------------------------------------------------- Icon trên đĩa

/// Icon cỡ lớn làm hình minh hoạ: dán trên đĩa màu nước tròn (nhãn dán viền giấy, nét mực run, bóng mềm) để không
/// còn là một nét mực trơ trọi. Trang trí — không đọc màn hình.
class SLIconDisc extends StatelessWidget {
  const SLIconDisc(
    this.id, {
    super.key,
    this.size = 88,
    this.color = SLColors.butterLight,
    this.iconScale = 0.64,
    this.iconColor,
    this.lift = 3,
    this.seed,
  });

  final String id;
  final double size;
  final Color color;

  /// Cỡ icon so với đĩa.
  final double iconScale;
  final Color? iconColor;
  final double lift;
  final int? seed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: const SLCircle(),
            material: SLMaterial.wash,
            color: color,
            sticker: true,
            inkWidth: size >= 64 ? SLMetrics.inkWidth : 2,
            seed: slSeed(seed: seed, content: 'disc_$id'),
          ),
          lift: lift,
          child: Center(child: SLIcon(id, size: size * iconScale, color: iconColor)),
        ),
      );
}

// ---------------------------------------------------------------------------------------------------- Đĩa

const _porcelain = Color(0xFFFFFBF3);
const _porcelainWash = Color(0xFFF3E6D4);

/// Đĩa sứ nhìn nghiêng đặt dưới bánh (giống đĩa ở trạm làm bánh). Có ảnh vẽ tay [art] thì vẽ ảnh: rộng bằng ô,
/// ép dẹt theo [artAspect] (đĩa nhìn thấp như bản vẽ code), đáy đĩa sát đáy ô — phần trên có thể trồi khỏi ô, nằm
/// sau bánh — kèm bóng mềm. Chưa nạp xong / thiếu ảnh → bản vẽ code: bóng mềm, men kem, vành bạc hà loang màu
/// nước, chấm hồng nhỏ trên vành, lòng đĩa nét caramel, vệt sáng; viền mực run tay theo [seed]. Phủ vùng được cấp
/// (elip chiếm ~86% chiều cao, phần dưới là bóng). Ghi một lần theo cỡ.
class SLPlate extends StatelessWidget {
  const SLPlate({super.key, this.seed = 0x9A7E});

  final int seed;

  /// Ảnh đĩa phục vụ vẽ tay (512×512, nền trong suốt).
  static const art = ArtRef(ArtGroup.items, 'plate_serving');

  /// Cao / rộng của đĩa khi vẽ bằng ảnh.
  static const artAspect = 0.4;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _PlatePainter(seed)));
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.seed) : super(repaint: ArtSprites.changes);

  final int seed;

  /// Vùng có hình của đĩa trong ảnh 512×512 (bỏ phần trong suốt quanh đĩa).
  static const _artBox = Rect.fromLTRB(12 / 512, 104 / 512, 500 / 512, 407 / 512);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = SLPlate.art.image;
    if (image != null) {
      final h = size.width * SLPlate.artAspect;
      final dst = Rect.fromLTWH(0, size.height - h, size.width, h);
      _paintPlateShadow(canvas, dst.deflate(2));
      final iw = image.width.toDouble(), ih = image.height.toDouble();
      final src = Rect.fromLTRB(_artBox.left * iw, _artBox.top * ih, _artBox.right * iw, _artBox.bottom * ih);
      canvas.drawImageRect(image, src, dst, Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true);
      return;
    }
    final w = size.width.round(), h = size.height.round();
    canvas.drawPicture(_cached(('sl_plate', w, h, seed), (c) => _paintPlate(c, Size(w.toDouble(), h.toDouble()), seed)));
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.seed != seed;
}

/// Bóng mềm lệch xuống dưới đĩa elip [oval].
void _paintPlateShadow(Canvas c, Rect oval) {
  final shadow = Rect.fromCenter(center: oval.center.translate(0, oval.height * 0.32), width: oval.width * 1.04, height: oval.height * 0.9);
  c
    ..save()
    ..translate(shadow.center.dx, shadow.center.dy)
    ..scale(1, shadow.height / shadow.width)
    ..drawCircle(
      Offset.zero,
      shadow.width / 2,
      Paint()..shader = ui.Gradient.radial(Offset.zero, shadow.width / 2, const [Color(0x445A3E36), Color(0x225A3E36), Color(0x005A3E36)], const [0, 0.6, 1]),
    )
    ..restore();
}

void _paintPlate(Canvas c, Size size, int seed) {
  final rnd = SLRandom(seed);
  final oval = Rect.fromLTWH(2, 1, size.width - 4, size.height * 0.84);
  _paintPlateShadow(c, oval);

  final amp = math.min(1.4, oval.height * 0.05);
  final outline = wobblePath(Path()..addOval(oval), seed: seed, amplitude: amp);
  final well = oval.deflate(oval.height * 0.24).translate(0, oval.height * 0.03);
  final wellPath = wobblePath(Path()..addOval(well), seed: SLRandom.mix(seed, 3), amplitude: amp * 0.8);

  c.drawPath(outline, _fill(_porcelain));
  c
    ..save()
    ..clipPath(outline);
  // Men kem màu nước + vành bạc hà loang (lớp màu lệch khỏi nét mực một chút, mép đậm, vài vệt loang).
  c.drawPath(outline.shift(const Offset(0.6, 0.8)), _fill(_porcelainWash));
  final rim = Path.combine(PathOperation.difference, outline, wellPath.shift(const Offset(0, -0.6)));
  c.drawPath(rim, _fill(SLColors.mint.withValues(alpha: 0.42)));
  c.drawPath(outline, _pen(Color.lerp(SLColors.mint, _umber, 0.25)!.withValues(alpha: 0.28), oval.height * 0.16));
  c.drawPath(outline, _pen(Color.lerp(SLColors.mint, _umber, 0.35)!.withValues(alpha: 0.35), 1.6));
  for (var i = 0; i < 4; i++) {
    final a = rnd.range(0, 2 * math.pi);
    final p = oval.center + Offset(math.cos(a) * oval.width * 0.42, math.sin(a) * oval.height * 0.4);
    _bloom(c, p, oval.height * rnd.range(0.12, 0.2), (i.isEven ? SLColors.mint : _white).withValues(alpha: 0.22), rnd.nextInt32());
  }
  // Lòng đĩa: giấy sáng, nét caramel run tay.
  c.drawPath(wellPath, _fill(_porcelain.withValues(alpha: 0.92)));
  c.drawPath(wellPath.shift(Offset(0, well.height * 0.12)), _fill(_porcelainWash.withValues(alpha: 0.55)));
  c.restore();
  c.drawPath(wellPath, _pen(SLColors.caramel.withValues(alpha: 0.6), 1.4));

  // Chấm hồng nhỏ trên vành.
  final dots = math.max(8, (oval.width / 18).round());
  for (var i = 0; i < dots; i++) {
    final a = (i + 0.5) / dots * 2 * math.pi + rnd.range(-0.06, 0.06);
    final p = oval.center + Offset(math.cos(a) * oval.width * 0.44, math.sin(a) * oval.height * 0.38);
    final r = math.max(1.4, oval.height * 0.045) * rnd.range(0.85, 1.15);
    final dot = wobblePath(Path()..addOval(Rect.fromCircle(center: p, radius: r)), seed: rnd.nextInt32(), amplitude: r * 0.25, step: 1.5);
    c.drawPath(dot, _fill(SLColors.strawberry.withValues(alpha: 0.85)));
  }
  // Vệt sáng trên vành.
  final hl = wobblePath(
    Path()..addArc(oval.deflate(oval.height * 0.08), -math.pi * 0.86, math.pi * 0.28),
    seed: SLRandom.mix(seed, 5),
    amplitude: 0.5,
  );
  c.drawPath(hl, _pen(_white.withValues(alpha: 0.85), math.max(2, oval.height * 0.07)));
  _ink(c, outline, math.max(1.8, math.min(2.4, oval.height * 0.07)));
}

// ---------------------------------------------------------------------------------------------------- Bao bột

/// Bao vải bố vẽ tay (bao nguyên liệu) trong ô vuông [rect]: viền mực run, màu nước be có vân sợi, miệng bao
/// nhăn có bột trắng, dây buộc ruy-băng hồng, mảnh vá ngôi sao ([patch]), vài chấm bột. Ghi một lần theo cỡ/seed.
void paintSLSack(Canvas canvas, Rect rect, {int seed = 0, bool patch = true}) {
  final side = rect.shortestSide.round();
  if (side < 4) return;
  final s = side.toDouble();
  final picture = _cached(('sl_sack', side, seed, patch), (c) => _paintSack(c, s, seed, patch));
  canvas
    ..save()
    ..translate(rect.center.dx - s / 2, rect.center.dy - s / 2)
    ..drawPicture(picture)
    ..restore();
}

const _burlap = Color(0xFFE6CBA2);
const _burlapDark = Color(0xFFD5B386);

void _paintSack(Canvas c, double s, int seed, bool patch) {
  final rnd = SLRandom(SLRandom.mix(seed, 0x5AC));
  Offset u(double x, double y) => Offset(x * s, y * s);
  final w = math.max(1.4, s * 0.022);
  final amp = math.max(0.5, s * 0.008);

  // Bóng mềm dưới đáy.
  c
    ..save()
    ..translate(s * 0.5, s * 0.95)
    ..scale(1, 0.16)
    ..drawCircle(
      Offset.zero,
      s * 0.4,
      Paint()..shader = ui.Gradient.radial(Offset.zero, s * 0.4, const [Color(0x445A3E36), Color(0x005A3E36)]),
    )
    ..restore();

  // Thân bao phình, cổ thắt ở y 0,34.
  final bodyIdeal = Path()
    ..moveTo(0.37 * s, 0.34 * s)
    ..cubicTo(0.22 * s, 0.42 * s, 0.1 * s, 0.6 * s, 0.14 * s, 0.81 * s)
    ..quadraticBezierTo(0.17 * s, 0.94 * s, 0.32 * s, 0.95 * s)
    ..cubicTo(0.45 * s, 0.97 * s, 0.58 * s, 0.97 * s, 0.68 * s, 0.95 * s)
    ..quadraticBezierTo(0.84 * s, 0.94 * s, 0.87 * s, 0.81 * s)
    ..cubicTo(0.9 * s, 0.6 * s, 0.78 * s, 0.42 * s, 0.63 * s, 0.34 * s)
    ..close();
  // Miệng bao nhăn: loe ra trên cổ, mép trên lượn sóng (nếp vải).
  final mouthIdeal = Path()
    ..moveTo(0.38 * s, 0.35 * s)
    ..cubicTo(0.33 * s, 0.29 * s, 0.24 * s, 0.24 * s, 0.22 * s, 0.15 * s);
  const folds = [0.22, 0.36, 0.5, 0.64, 0.78];
  for (var i = 1; i < folds.length; i++) {
    final x0 = folds[i - 1], x1 = folds[i];
    mouthIdeal.quadraticBezierTo((x0 + x1) / 2 * s, (i.isEven ? 0.07 : 0.09) * s, x1 * s, (i == folds.length - 1 ? 0.15 : 0.13) * s);
  }
  mouthIdeal
    ..cubicTo(0.76 * s, 0.24 * s, 0.67 * s, 0.29 * s, 0.62 * s, 0.35 * s)
    ..close();
  final body = wobblePath(bodyIdeal, seed: rnd.nextInt32(), amplitude: amp);
  final mouth = wobblePath(mouthIdeal, seed: rnd.nextInt32(), amplitude: amp * 0.8);

  void burlap(Path p, Color base) {
    c.drawPath(p, _fill(SLColors.paper));
    c
      ..save()
      ..clipPath(p)
      ..drawPath(p.shift(Offset(rnd.range(-0.6, 0.6), rnd.range(0, 0.8))), _fill(base));
    // Vân sợi đan: hàng ngang + dọc rất mờ, hơi nghiêng.
    final b = p.getBounds();
    final step = math.max(2.4, s * 0.034);
    final weft = _pen(Color.lerp(base, _umber, 0.5)!.withValues(alpha: 0.16), math.max(0.6, s * 0.007));
    final warp = _pen(_white.withValues(alpha: 0.2), math.max(0.6, s * 0.007));
    for (var y = b.top + step / 2; y < b.bottom; y += step) {
      c.drawLine(Offset(b.left, y), Offset(b.right, y + rnd.range(-0.6, 0.6)), weft);
    }
    for (var x = b.left + step / 2; x < b.right; x += step) {
      c.drawLine(Offset(x, b.top), Offset(x + rnd.range(-0.8, 0.8), b.bottom), warp);
    }
    // Mép đọng màu đậm + vùng sáng phía trên trái, bóng phía dưới.
    c.drawPath(p, _pen(Color.lerp(base, _umber, 0.45)!.withValues(alpha: 0.12), s * 0.12));
    c.drawPath(p, _pen(Color.lerp(base, _umber, 0.45)!.withValues(alpha: 0.16), s * 0.05));
    _bloom(c, Offset(b.left + b.width * 0.36, b.top + b.height * 0.38), b.shortestSide * 0.24, _white.withValues(alpha: 0.2), rnd.nextInt32());
    _bloom(c, Offset(b.left + b.width * 0.62, b.bottom - b.height * 0.1), b.shortestSide * 0.26, _umber.withValues(alpha: 0.08), rnd.nextInt32());
    c.restore();
  }

  burlap(body, _burlap);
  burlap(mouth, _burlapDark);
  // Lòng miệng bao tối + đụn bột trắng nhô lên.
  final opening = wobblePath(
    Path()
      ..moveTo(0.28 * s, 0.15 * s)
      ..quadraticBezierTo(0.5 * s, 0.23 * s, 0.72 * s, 0.15 * s)
      ..quadraticBezierTo(0.5 * s, 0.1 * s, 0.28 * s, 0.15 * s)
      ..close(),
    seed: rnd.nextInt32(),
    amplitude: amp * 0.6,
  );
  c.drawPath(opening, _fill(_umber.withValues(alpha: 0.45)));
  final flour = wobblePath(
    Path()
      ..moveTo(0.33 * s, 0.16 * s)
      ..quadraticBezierTo(0.42 * s, 0.07 * s, 0.52 * s, 0.09 * s)
      ..quadraticBezierTo(0.62 * s, 0.08 * s, 0.67 * s, 0.16 * s)
      ..quadraticBezierTo(0.5 * s, 0.2 * s, 0.33 * s, 0.16 * s)
      ..close(),
    seed: rnd.nextInt32(),
    amplitude: amp * 0.7,
  );
  c.drawPath(flour, _fill(const Color(0xFFFFFDF7)));
  c.drawPath(flour, _pen(SLColors.caramel.withValues(alpha: 0.45), w * 0.5));

  // Nếp gấp bút chì: trên miệng bao và dưới cổ.
  final crease = _pen(Color.lerp(_burlap, _umber, 0.6)!.withValues(alpha: 0.7), w * 0.55);
  for (final (x0, y0, x1, y1, cx, cy) in const [
    (0.42, 0.33, 0.35, 0.2, 0.37, 0.27),
    (0.58, 0.33, 0.65, 0.2, 0.63, 0.27),
    (0.4, 0.39, 0.3, 0.55, 0.32, 0.45),
    (0.6, 0.39, 0.7, 0.53, 0.68, 0.44),
    (0.5, 0.4, 0.49, 0.5, 0.51, 0.45),
  ]) {
    final p = Path()
      ..moveTo(x0 * s, y0 * s)
      ..quadraticBezierTo(cx * s, cy * s, x1 * s, y1 * s);
    c.drawPath(wobblePath(p, seed: rnd.nextInt32(), amplitude: amp * 0.5), crease);
  }

  if (patch) {
    // Mảnh vá ngôi sao vàng bơ, khâu chỉ nét đứt.
    final center = u(0.66, 0.6);
    final ro = s * 0.11, ri = s * 0.05;
    final tilt = rnd.range(-0.3, 0.3);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + tilt + i * math.pi / 5;
      final r = i.isEven ? ro : ri;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    final starHand = wobblePath(star, seed: rnd.nextInt32(), amplitude: amp * 0.5, step: 2);
    c.drawPath(starHand, _fill(SLColors.butterLight));
    c
      ..save()
      ..clipPath(starHand)
      ..drawPath(starHand, _pen(Color.lerp(SLColors.butter, _umber, 0.2)!.withValues(alpha: 0.5), s * 0.03))
      ..restore();
    c.drawPath(starHand, _pen(SLColors.ink, w * 0.7));
  }

  // Dây buộc: dải ruy-băng hồng quấn cổ + nơ hai quai, hai đuôi.
  final band = wobblePath(
    Path()
      ..moveTo(0.345 * s, 0.305 * s)
      ..quadraticBezierTo(0.5 * s, 0.34 * s, 0.655 * s, 0.305 * s)
      ..lineTo(0.665 * s, 0.38 * s)
      ..quadraticBezierTo(0.5 * s, 0.415 * s, 0.335 * s, 0.38 * s)
      ..close(),
    seed: rnd.nextInt32(),
    amplitude: amp * 0.5,
  );
  final knot = u(0.57, 0.345);
  Path loop(double dx, double dy, double spread) => Path()
    ..moveTo(knot.dx, knot.dy)
    ..cubicTo(knot.dx + dx * s * 0.2 - spread * s, knot.dy + dy * s - 0.05 * s, knot.dx + dx * s + spread * s, knot.dy + dy * s + 0.02 * s,
        knot.dx, knot.dy)
    ..close();
  Path tail(double x1, double y1) => Path()
    ..moveTo(knot.dx - 0.012 * s, knot.dy)
    ..quadraticBezierTo((knot.dx + x1 * s) / 2 - 0.02 * s, (knot.dy + y1 * s) / 2, x1 * s - 0.018 * s, y1 * s)
    ..lineTo(x1 * s + 0.004 * s, y1 * s - 0.022 * s)
    ..lineTo(x1 * s + 0.022 * s, y1 * s + 0.004 * s)
    ..quadraticBezierTo((knot.dx + x1 * s) / 2 + 0.02 * s, (knot.dy + y1 * s) / 2, knot.dx + 0.012 * s, knot.dy)
    ..close();
  final ribbonParts = [
    band,
    for (final p in [tail(0.5, 0.53), tail(0.66, 0.52), loop(-0.17, -0.09, 0.05), loop(0.17, -0.1, 0.05)])
      wobblePath(p, seed: rnd.nextInt32(), amplitude: amp * 0.45, step: 2),
  ];
  for (final p in ribbonParts) {
    c.drawPath(p, _fill(SLColors.strawberry));
    c
      ..save()
      ..clipPath(p)
      ..drawPath(p, _pen(Color.lerp(SLColors.strawberry, _umber, 0.3)!.withValues(alpha: 0.35), s * 0.025))
      ..drawPath(p.shift(Offset(-s * 0.01, -s * 0.012)), _pen(_white.withValues(alpha: 0.35), s * 0.012))
      ..restore();
    c.drawPath(p, _pen(SLColors.ink, w * 0.65));
  }
  final knotPath = wobblePath(Path()..addOval(Rect.fromCircle(center: knot, radius: s * 0.032)), seed: rnd.nextInt32(), amplitude: amp * 0.3, step: 1.5);
  c.drawPath(knotPath, _fill(Color.lerp(SLColors.strawberry, _umber, 0.15)!));
  c.drawPath(knotPath, _pen(SLColors.ink, w * 0.6));

  _ink(c, body, w);
  _ink(c, mouth, w * 0.9);

  // Vài chấm bột rơi quanh miệng bao và trên thân.
  final dust = _fill(_white.withValues(alpha: 0.9));
  final dustInk = _pen(SLColors.caramel.withValues(alpha: 0.35), math.max(0.5, s * 0.005));
  for (final (x, y, r) in const [(0.3, 0.07, 0.016), (0.72, 0.06, 0.013), (0.62, 0.02, 0.01), (0.24, 0.52, 0.012), (0.42, 0.66, 0.01), (0.8, 0.4, 0.011)]) {
    final dot = wobblePath(Path()..addOval(Rect.fromCircle(center: u(x, y), radius: math.max(0.8, r * s))), seed: rnd.nextInt32(), amplitude: 0.3, step: 1.2);
    c
      ..drawPath(dot, dust)
      ..drawPath(dot, dustInk);
  }
}

// ---------------------------------------------------------------------------------------------------- Chấm mực

/// Chấm tô tay nhỏ (giọt mực, vệt sáng trên đinh ghim…): hình tròn méo run tay theo [seed], phủ vùng được cấp.
class SLInkDot extends StatelessWidget {
  const SLInkDot({super.key, required this.color, this.seed = 0});

  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _InkDotPainter(color, seed));
}

class _InkDotPainter extends CustomPainter {
  const _InkDotPainter(this.color, this.seed);

  final Color color;
  final int seed;

  static final _paths = <(int, int, int), Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = (size.width.round(), size.height.round(), seed);
    final path = _paths[key] ??= () {
      if (_paths.length > 64) _paths.clear();
      final r = Offset.zero & size;
      return wobblePath(Path()..addOval(r.deflate(r.shortestSide * 0.04)), seed: seed, amplitude: r.shortestSide * 0.07, step: 1.2);
    }();
    canvas.drawPath(path, _fill(color));
  }

  @override
  bool shouldRepaint(_InkDotPainter old) => old.color != color || old.seed != seed;
}
