import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/art/art_paint.dart';
import '../../core/ref_frame.dart';
import '../../core/theme.dart';
import '../common/wide_layout.dart';
import '../sugarleaf/sugarleaf.dart';

/// Phần vẽ 2D của cảnh mở đầu (`IntroScreen`, lớp phủ trên cảnh 3D): ảnh có nền dự phòng, nền giấy, logo, lớp lấp
/// lánh vẽ bằng code.
///
/// Hạt: mỗi lớp giữ một BỂ CỐ ĐỊNH (mảng số sinh một lần theo seed); mỗi khung chỉ tính vị trí theo thời gian rồi
/// vẽ bằng các `Paint` dựng sẵn (bảng độ mờ lượng tử hoá) — không cấp phát đối tượng mỗi khung.

/// Ảnh của cảnh mở đầu (Gemini). Thiếu file → hình vẽ tay dự phòng, không lỗi.
abstract final class IntroAssets {
  static const emblem = 'assets/art/level/logo_emblem.webp';
}

/// Hệ số từ toạ độ khung (rộng W = 1280–1600, xem `RefMetrics`) sang điểm ảnh thật của màn (để giải mã ảnh đúng cỡ
/// hiện).
double introPixelScale(BuildContext context) =>
    (View.of(context).physicalSize.width / RefMetrics.of(context).width).clamp(0.5, 3.0);

/// Rộng khung (đơn vị ref, cao 720) của vùng cảnh cỡ [size]: 1280 khi 16:9 hoặc hẹp hơn; khung rộng (máy 20:9) →
/// 720 × rộng/cao.
double introFrameWidth(Size size) =>
    size.height > 0 && wideCenterRect(size).width < size.width ? size.width * 720 / size.height : 1280;

/// Đặt lớp vẽ theo toạ độ khung 1280×720 ([child]: hạt lấp lánh…) vào vùng 1280 giữa khung rộng [width] —
/// khớp với ảnh nền [IntroImage] (ảnh ở vùng 16:9 giữa, hai bên soi gương). [width] 1280 → trả thẳng [child].
Widget introStage(double width, Widget child) {
  if (width <= 1280) return child;
  return Stack(
    clipBehavior: Clip.none,
    children: [Positioned(left: (width - 1280) / 2, top: 0, bottom: 0, width: 1280, child: child)],
  );
}

/// Ảnh vật (huy hiệu logo) giải mã theo bề ngang hiện [logicalWidth].
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
  Widget build(BuildContext context) {
    if (fit != BoxFit.cover) return _image();
    // Ảnh nền cảnh: vùng rộng hơn 16:9 → ảnh ở vùng 16:9 giữa, hai bên soi gương dải mép (không cắt mất cảnh).
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        if (size.isFinite && wideCenterRect(size).width < size.width) {
          return WideImageBackdrop(image: image, fallback: fallback);
        }
        return _image();
      },
    );
  }

  Widget _image() => Image(
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
