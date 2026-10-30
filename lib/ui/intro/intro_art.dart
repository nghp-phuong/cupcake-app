import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/theme.dart';
import '../sugarleaf/sugarleaf.dart';

/// Phần vẽ dùng chung của cảnh mở đầu (`IntroScreen`) và intro ngắn (`ShortIntroScreen`): đường dẫn ảnh, ảnh có nền
/// dự phòng, logo, và các lớp hạt vẽ bằng code (bụi nắng, hơi nước, lấp lánh) + tia nắng.
///
/// Hạt: mỗi lớp giữ một BỂ CỐ ĐỊNH (mảng số sinh một lần theo seed); mỗi khung chỉ tính vị trí theo thời gian rồi
/// vẽ bằng các `Paint` dựng sẵn (bảng độ mờ lượng tử hoá) — không cấp phát đối tượng mỗi khung.

/// Ảnh của cảnh mở đầu (Gemini). Thiếu file → nền giấy + chữ, không lỗi.
abstract final class IntroAssets {
  static const kitchen = 'assets/art/scenes/intro_kitchen.webp';
  static const door = 'assets/art/scenes/intro_door.webp';
  static const shop = 'assets/art/shop/shop_base.webp';
  static const openSign = 'assets/art/level/open_sign.webp';
  static const doorBell = 'assets/art/level/door_bell.webp';
  static const emblem = 'assets/art/level/logo_emblem.webp';

  // Mai ở cảnh 3 (480×640). walk_b / reach có thể chưa có: thiếu → walk_a / neutral.
  static const maiNeutral = 'assets/characters/mai_neutral.webp';
  static const maiSmile = 'assets/characters/mai_smile.webp';
  static const maiJoy = 'assets/characters/mai_joy.webp';
  static const maiWalkA = 'assets/characters/mai_walk_a.webp';
  static const maiWalkB = 'assets/characters/mai_walk_b.webp';
  static const maiReach = 'assets/characters/mai_reach.webp';

  /// Ảnh đi bộ / với tay vẽ nhìn sang TRÁI.
  static const maiSideFacesLeft = true;

  /// Mai đi từ mép phải sang trái, dừng bên phải bảng, với tay trái-trước chạm mép phải bảng.
  static const maiWalksLeft = true;

  /// Đáy giày (y) và tâm đầu (x) trong ảnh 480×640 của từng dáng — đo từ kênh alpha. Ảnh lệch so với ảnh đứng thẳng
  /// ([maiNeutral]) được dịch cho trùng chân đế + đầu.
  static const _maiAnchors = <String, (double, double)>{
    maiWalkA: (599, 251),
    maiWalkB: (600, 252),
    maiReach: (604, 252),
    maiNeutral: (612, 245),
    maiSmile: (612, 245),
    maiJoy: (612, 244),
  };

  /// Độ dịch (toạ độ hiện, ảnh cỡ [size]) để [asset] trùng chân đế + đầu với ảnh đứng thẳng.
  static Offset maiAlign(String asset, Size size) {
    final a = _maiAnchors[asset];
    if (a == null) return Offset.zero;
    // Ảnh nghiêng bị lật (đổi hướng đi) thì phép dịch nằm trong phép lật — cần đo lại tâm đầu.
    final k = size.height / 640;
    return Offset((245 - a.$2) * k, (612 - a.$1) * k);
  }

  /// Ảnh của Mai nạp trước khi chạy intro (walk_b nạp riêng để biết có hay chưa).
  static const maiPoses = [maiNeutral, maiWalkA, maiReach, maiJoy];
}

/// Toạ độ trong khung 1280×720 của các ảnh nền (đổi ở đây khi ảnh thật khác bố cục).
abstract final class IntroLayout {
  // ---- Cảnh 1: intro_kitchen.webp (lò gạch bên trái, cửa sổ nắng x 770–1000)
  /// Miệng lò gạch (gốc hơi nước; hơi bốc lên tới y ~170).
  static const ovenMouth = Offset(215, 300);

  /// Vùng bụi nắng (dải nắng xiên từ cửa sổ xuống bàn bột).
  static const dustRegion = Rect.fromLTWH(430, 50, 520, 470);

  /// Gốc tia nắng (mép trên cửa sổ) và hướng chiếu (xiên xuống trái).
  static const rayOrigin = Offset(860, 20);
  static const rayDirection = Offset(-0.72, 0.69);

  // ---- Cảnh 2: shop/shop_base.webp
  /// Tâm tủ kính (đích phóng của máy quay).
  static const caseCenter = Offset(642, 482);

  /// Mặt kính tủ (chỗ lấp lánh).
  static const caseGlass = Rect.fromLTWH(462, 398, 366, 168);

  /// Đèn treo (lớp đèn trượt lệch với nền — parallax).
  static const lamps = [Offset(305, 140), Offset(838, 140), Offset(1020, 186), Offset(1142, 156)];

  // ---- Cảnh 3: intro_door.webp (cửa mint x 515–778, kính x 548–745 / y 165–440)
  /// Móc treo bảng trên kính cửa: đỉnh dây của `open_sign.webp` treo vào đây.
  static const signHook = Offset(646, 183);

  /// Cỡ hiện của bảng (ảnh 384×420).
  static const signSize = Size(196, 214);

  /// Điểm treo trong ảnh bảng (đinh trên đỉnh dây), tỉ lệ theo khung ảnh.
  static const signPivot = Offset(0.49, 0.03);

  /// Mặt kem trống trên ảnh bảng (tỉ lệ: trái, trên, phải, dưới) — chỗ vẽ chữ "Mở cửa" / "Open".
  static const signTextRect = Rect.fromLTRB(0.13, 0.46, 0.87, 0.88);

  /// Giá chuông trên tường cạnh cửa: mép trên trái ảnh `door_bell.webp` (172×260, tay treo cong ở trên) đặt ở đây.
  static const bellTopLeft = Offset(470, 104);
  static const bellSize = Size(100, 151);

  /// Điểm xoay của chuông (khoen nối tay treo), tỉ lệ theo khung ảnh chuông.
  static const bellPivot = Offset(0.42, 0.30);

  /// Tâm ngang của Mai khi tới cửa: đứng bên phải bảng (bảng x 550–746, y 177–391), ảnh `mai_reach` (nhìn trái,
  /// đầu ngón tay ở (95, 125)/480×640 → lệch tâm −112, y ≈ 340 khi hiện) chạm mép phải khung bảng ở x ≈ 728. Người
  /// Mai nằm ở x ≈ 733–934 nên không che chữ "Mở cửa".
  static const maiDoorX = 840.0;

  /// Mai đứng trước cửa hơi lệch trái: tâm ngang lúc đứng yên, cỡ hiện (ảnh 480×640, chân ở ~95% chiều cao), mép
  /// dưới ảnh (chân chạm sàn ở y ~690).
  static const maiCenterX = 500.0;
  static const maiSize = Size(353, 470);
  static const maiBottom = 712.0;
}

/// Hệ số từ toạ độ khung 1280×720 sang điểm ảnh thật của màn (để giải mã ảnh đúng cỡ hiện).
double introPixelScale(BuildContext context) => (View.of(context).physicalSize.width / 1280).clamp(0.5, 3.0);

/// Ảnh nền cảnh 1280×720 giải mã tối đa theo bề ngang thật của màn.
ImageProvider introSceneImage(BuildContext context, String asset) => ResizeImage(
      AssetImage(asset),
      width: View.of(context).physicalSize.width.round().clamp(640, 2560),
      policy: ResizeImagePolicy.fit,
    );

/// Ảnh vật (bảng, chuông, huy hiệu, nhân vật) giải mã theo bề ngang hiện [logicalWidth].
ImageProvider introObjectImage(BuildContext context, String asset, double logicalWidth) => ResizeImage(
      AssetImage(asset),
      width: (logicalWidth * introPixelScale(context)).round(),
      policy: ResizeImagePolicy.fit,
    );

/// Ảnh [image]; đang nạp / thiếu → [fallback].
class IntroImage extends StatelessWidget {
  const IntroImage({super.key, required this.image, required this.fallback, this.fit = BoxFit.cover});

  final ImageProvider image;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image(
        image: image,
        fit: fit,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, sync) => frame == null && !sync ? fallback : child,
        errorBuilder: (context, error, stack) => fallback,
      );
}

/// Nền giấy dự phòng của một cảnh (thiếu ảnh): giấy kem vân giấy + icon vẽ tay lớn mờ ở giữa.
class IntroPaperBackdrop extends StatelessWidget {
  const IntroPaperBackdrop({super.key, this.icon, this.seed = 0x1A70});

  final String? icon;
  final int seed;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          SLSurface(
            spec: SLSurfaceSpec(
              shape: const SLRoundRect(0),
              material: SLMaterial.paper,
              color: SLColors.cream,
              outline: false,
              seed: seed,
            ),
          ),
          if (icon case final id?)
            Center(child: Opacity(opacity: 0.35, child: SLIcon(id, size: 220))),
        ],
      );
}

/// Logo: huy hiệu tròn (`logo_emblem.webp` 420×397, có dải ruy băng hồng trống) với chữ `appTitle` viền nâu đặt trên
/// ruy băng. Thiếu ảnh → đĩa vẽ tay có lá + dải ruy băng vẽ tay ở cùng chỗ.
class IntroLogo extends StatelessWidget {
  const IntroLogo({super.key, required this.title, this.width = 420});

  final String title;

  /// Bề ngang huy hiệu (cao = 397/420 bề ngang).
  final double width;

  static const _aspect = 397 / 420;

  /// Mặt ruy băng (tỉ lệ theo khung ảnh) — chỗ đặt chữ.
  static const _ribbon = Rect.fromLTRB(0.2, 0.635, 0.8, 0.82);

  @override
  Widget build(BuildContext context) {
    final height = width * _aspect;
    final ribbon = Rect.fromLTRB(_ribbon.left * width, _ribbon.top * height, _ribbon.right * width, _ribbon.bottom * height);
    final fallback = Stack(
      children: [
        Positioned(
          left: width * 0.08,
          right: width * 0.08,
          top: 0,
          bottom: height * 0.1,
          child: Center(child: SLIconDisc('leaf_logo', size: width * 0.8, color: SLColors.mintLight, seed: 0x1060)),
        ),
        Positioned(
          left: width * 0.04,
          right: width * 0.04,
          top: ribbon.top - 6,
          height: ribbon.height + 12,
          child: const SLSurface(
            spec: SLSurfaceSpec(shape: SLRibbon(), material: SLMaterial.wash, color: SLColors.strawberryLight, seed: 0x1061),
          ),
        ),
      ],
    );
    return Semantics(
      label: title,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IntroImage(
                  image: introObjectImage(context, IntroAssets.emblem, width),
                  fit: BoxFit.contain,
                  fallback: fallback,
                ),
              ),
              Positioned.fromRect(
                rect: ribbon,
                child: FittedBox(child: IntroTitleText(title, fontSize: 64)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chữ tiêu đề viền nâu (nét chữ dày dưới, ruột giấy trên). [fredoka]: ép Fredoka (chữ không dấu như tên app);
/// false → font tiêu đề theo ngôn ngữ của theme (tiếng Việt → Baloo 2).
class IntroTitleText extends StatelessWidget {
  const IntroTitleText(this.text, {super.key, required this.fontSize, this.fredoka = true, this.fill = SLColors.paper});

  final String text;
  final double fontSize;
  final bool fredoka;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final base = SLTextStyles.of(context).heading;
    final style = base.copyWith(
      fontFamily: fredoka && base.fontFamily != null ? AppTheme.fredoka : null,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = SLColors.ink,
            shadows: const [Shadow(color: SLColors.shadow, offset: Offset(0, 4), blurRadius: 5)],
          ),
        ),
        Text(text, maxLines: 1, style: style.copyWith(color: fill)),
      ],
    );
  }
}

// ==================================================================== Thời gian

/// Hoạt ảnh con: `fn(parent.value)` (vd. giây trong cảnh, độ mờ nhấp nháy). Không tạo controller riêng.
class IntroMapped extends Animation<double> with AnimationWithParentMixin<double> {
  IntroMapped(this.parent, this.fn);

  @override
  final Animation<double> parent;
  final double Function(double v) fn;

  @override
  double get value => fn(parent.value);
}

// ==================================================================== Hạt

/// Bảng [steps] Paint cùng màu [color], độ mờ tăng dần 0..[maxAlpha] (chọn theo độ mờ lượng tử hoá).
List<Paint> _alphaPaints(Color color, {int steps = 8, double maxAlpha = 1, double blur = 0}) => [
      for (var i = 0; i < steps; i++)
        Paint()
          ..color = color.withValues(alpha: maxAlpha * (i + 1) / steps)
          ..isAntiAlias = true
          ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null,
    ];

Paint? _pick(List<Paint> paints, double alpha) {
  if (alpha <= 0.02) return null;
  final i = (alpha.clamp(0.0, 1.0) * paints.length).ceil() - 1;
  return paints[i.clamp(0, paints.length - 1)];
}

/// Bể hạt cố định: mỗi hạt 5 số ngẫu nhiên trong [0, 1) sinh một lần theo [seed].
class _Pool {
  _Pool(this.count, int seed) : r = Float32List(count * 5) {
    final rnd = math.Random(seed);
    for (var i = 0; i < r.length; i++) {
      r[i] = rnd.nextDouble();
    }
  }

  final int count;
  final Float32List r;

  double at(int i, int k) => r[i * 5 + k];
}

/// Bụi nắng: chấm sáng nhỏ trôi chậm trong [region] (toạ độ khung 1280×720, vẽ theo cỡ [size] / 1280), lấp lánh.
class IntroDustPainter extends CustomPainter {
  IntroDustPainter({required this.time, this.region = IntroLayout.dustRegion, int count = 46, int seed = 0xD057})
      : _pool = _Pool(count, seed),
        super(repaint: time);

  /// Giây trong cảnh.
  final Animation<double> time;
  final Rect region;
  final _Pool _pool;
  final List<Paint> _paints = _alphaPaints(const Color(0xFFFFF6DC), maxAlpha: 0.85);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final k = size.width / 1280;
    for (var i = 0; i < _pool.count; i++) {
      final rx = _pool.at(i, 0), ry = _pool.at(i, 1), ph = _pool.at(i, 2) * math.pi * 2;
      final speed = 6 + 14 * _pool.at(i, 3);
      // Trôi xuống chậm, quay vòng trong vùng; lắc ngang theo sin.
      final y = region.top + (ry * region.height + speed * t) % region.height;
      final x = region.left + rx * region.width + 16 * math.sin(t * 0.45 + ph);
      final twinkle = 0.45 + 0.55 * math.sin(t * (1.1 + _pool.at(i, 4)) + ph);
      final paint = _pick(_paints, twinkle);
      if (paint == null) continue;
      canvas.drawCircle(Offset(x * k, y * k), (1.4 + 2.2 * _pool.at(i, 4)) * k, paint);
    }
  }

  @override
  bool shouldRepaint(IntroDustPainter oldDelegate) => oldDelegate.time != time;
}

/// Hơi nước bốc từ [origin]: các cụm mờ lớn dần, lắc nhẹ, mờ đi khi lên cao (chu kỳ lặp, lệch pha đều).
class IntroSteamPainter extends CustomPainter {
  IntroSteamPainter({required this.time, this.origin = IntroLayout.ovenMouth, int count = 14, int seed = 0x57EA})
      : _pool = _Pool(count, seed),
        super(repaint: time);

  final Animation<double> time;
  final Offset origin;
  final _Pool _pool;
  final List<Paint> _paints = _alphaPaints(const Color(0xFFFFFFFF), maxAlpha: 0.38, blur: 7);

  static const _life = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final k = size.width / 1280;
    final n = _pool.count;
    for (var i = 0; i < n; i++) {
      final age = (t + _life * i / n) % _life;
      final u = age / _life;
      final ph = _pool.at(i, 0) * math.pi * 2;
      final x = origin.dx + (_pool.at(i, 1) - 0.5) * 34 + 18 * u * math.sin(u * 4 + ph);
      final y = origin.dy - u * (130 + 50 * _pool.at(i, 2));
      final paint = _pick(_paints, math.sin(math.pi * u) * (0.6 + 0.4 * _pool.at(i, 3)));
      if (paint == null) continue;
      canvas.drawCircle(Offset(x * k, y * k), (9 + 30 * u) * k, paint);
    }
  }

  @override
  bool shouldRepaint(IntroSteamPainter oldDelegate) => oldDelegate.time != time;
}

/// Ngôi sao 4 cánh đơn vị (bán kính 1), dựng một lần.
final Path _starPath = () {
  final p = Path();
  const inner = 0.24;
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + i * math.pi / 4;
    final r = i.isEven ? 1.0 : inner;
    final o = Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}();

/// Lấp lánh: sao 4 cánh nhấp nháy (phóng lên rồi tắt) ở vị trí cố định trong [region] (toạ độ khung 1280×720).
class IntroSparklePainter extends CustomPainter {
  IntroSparklePainter({
    required this.time,
    required this.region,
    int count = 12,
    int seed = 0x5A2C,
    this.maxRadius = 14,
    this.color = const Color(0xFFFFFFFF),
  })  : _pool = _Pool(count, seed),
        _paints = _alphaPaints(color, steps: 6),
        _glow = _alphaPaints(color, steps: 6, maxAlpha: 0.45, blur: 6),
        super(repaint: time);

  final Animation<double> time;
  final Rect region;
  final double maxRadius;
  final Color color;
  final _Pool _pool;
  final List<Paint> _paints;
  final List<Paint> _glow;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final k = size.width / 1280;
    for (var i = 0; i < _pool.count; i++) {
      final period = 1.4 + 1.6 * _pool.at(i, 3);
      final u = (t / period + _pool.at(i, 2)) % 1.0;
      // Nhấp nháy trong 40% đầu chu kỳ, còn lại tắt.
      if (u > 0.4) continue;
      final s = math.sin(math.pi * u / 0.4);
      final x = (region.left + _pool.at(i, 0) * region.width) * k;
      final y = (region.top + _pool.at(i, 1) * region.height) * k;
      final r = maxRadius * (0.5 + 0.5 * _pool.at(i, 4)) * s * k;
      final glow = _pick(_glow, s);
      if (glow != null) canvas.drawCircle(Offset(x, y), r * 0.7, glow);
      final paint = _pick(_paints, s);
      if (paint == null) continue;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(0.3 * _pool.at(i, 0) + 0.4 * u)
        ..scale(r)
        ..drawPath(_starPath, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(IntroSparklePainter oldDelegate) => oldDelegate.time != time || oldDelegate.region != region;
}

/// Tia nắng xiên: vài dải sáng gradient từ [origin] theo [direction], cộng sáng (`BlendMode.plus`) lên ảnh nền ở
/// CÙNG lớp vẽ (không bọc Opacity/RepaintBoundary — lớp riêng trong suốt sẽ làm mất hoà màu). Độ sáng [brightness]
/// (0..1) đưa vào alpha của Paint và là nguồn vẽ lại; đường tia + shader dựng lại chỉ khi đổi cỡ.
class IntroRaysPainter extends CustomPainter {
  IntroRaysPainter({
    this.brightness = const AlwaysStoppedAnimation(1),
    this.origin = IntroLayout.rayOrigin,
    this.direction = IntroLayout.rayDirection,
  }) : super(repaint: brightness);

  final Animation<double> brightness;
  final Offset origin;
  final Offset direction;

  static const _beams = [(-0.16, 70.0, 0.55), (-0.02, 110.0, 0.75), (0.12, 60.0, 0.5), (0.22, 90.0, 0.4)];

  Size? _builtFor;
  final List<(Path, Paint)> _built = [];

  void _build(Size size) {
    _builtFor = size;
    _built.clear();
    final k = size.width / 1280;
    final o = origin * k;
    final base = math.atan2(direction.dy, direction.dx);
    final len = 1100 * k;
    for (final (da, width, strength) in _beams) {
      final a = base + da;
      final dir = Offset(math.cos(a), math.sin(a));
      final n = Offset(-dir.dy, dir.dx);
      final end = o + dir * len;
      final w0 = width * 0.35 * k, w1 = width * k;
      final path = Path()
        ..moveTo(o.dx + n.dx * w0, o.dy + n.dy * w0)
        ..lineTo(end.dx + n.dx * w1, end.dy + n.dy * w1)
        ..lineTo(end.dx - n.dx * w1, end.dy - n.dy * w1)
        ..lineTo(o.dx - n.dx * w0, o.dy - n.dy * w0)
        ..close();
      // Cộng sáng nên alpha thấp hơn kiểu "screen" để vùng sáng không cháy trắng.
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * k)
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF1C9).withValues(alpha: 0.5 * strength),
            const Color(0xFFFFE8B5).withValues(alpha: 0.18 * strength),
            const Color(0x00FFE8B5),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromPoints(o, end));
      _built.add((path, paint));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.value.clamp(0.0, 1.0);
    if (b <= 0.01) return;
    if (_builtFor != size) _build(size);
    // Alpha của Paint nhân vào shader: đổi độ sáng không cần dựng lại gradient.
    final color = Color.fromRGBO(0, 0, 0, b);
    for (final (path, paint) in _built) {
      canvas.drawPath(path, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(IntroRaysPainter oldDelegate) =>
      oldDelegate.brightness != brightness || oldDelegate.origin != origin || oldDelegate.direction != direction;
}

/// Quầng đèn ấm (lớp đèn của cảnh tủ kính): quầng tròn màu nước vàng bơ quanh từng đèn. Tĩnh — lớp được dịch lệch
/// với ảnh nền khi máy quay lia (parallax), không vẽ lại mỗi khung. Lớp riêng (có thể được cache thành ảnh trong
/// suốt) nên vẽ alpha thường, không dùng chế độ hoà màu.
class IntroLampGlowPainter extends CustomPainter {
  const IntroLampGlowPainter({this.lamps = IntroLayout.lamps});

  final List<Offset> lamps;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 1280;
    for (final l in lamps) {
      final c = l * k;
      final r = 120 * k;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x66FFE8B0), Color(0x26FFD27A), Color(0x00FFD27A)],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(IntroLampGlowPainter oldDelegate) => oldDelegate.lamps != lamps;
}

/// Vòng sóng nhỏ quanh chuông khi rung: 2 vòng mực nhạt nở ra rồi mờ (theo [time] = giây kể từ lúc rung).
class IntroRipplePainter extends CustomPainter {
  IntroRipplePainter({required this.time}) : super(repaint: time);

  final Animation<double> time;
  final List<Paint> _paints = [
    for (var i = 1; i <= 6; i++)
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = SLColors.butter.withValues(alpha: i / 6),
  ];

  static const _duration = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var ring = 0; ring < 2; ring++) {
      final u = (time.value - ring * 0.22) / _duration;
      if (u <= 0 || u >= 1) continue;
      final paint = _pick(_paints, 1 - u);
      if (paint == null) continue;
      final r = size.shortestSide * (0.2 + 0.32 * u);
      // Ba cung ngắn hai bên (như vạch rung), không vẽ vòng kín.
      for (final side in const [-1.0, 1.0]) {
        final start = side < 0 ? math.pi * 0.72 : -math.pi * 0.28;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, math.pi * 0.56, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(IntroRipplePainter oldDelegate) => oldDelegate.time != time;
}
