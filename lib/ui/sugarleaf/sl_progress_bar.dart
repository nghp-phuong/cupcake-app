import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_theme.dart';

/// Thanh tiến độ: ống giấy viền mực run tay, màu nước chảy bên trong (mép nước cong, đọng màu đậm).
/// Giá trị đổi → chạy tới trong [SLMetrics.progress] (tắt hiệu ứng → nhảy ngay). [label] in giữa ống.
class SLProgressBar extends StatelessWidget {
  const SLProgressBar({
    super.key,
    required this.value,
    this.color = SLColors.mint,
    this.height = 26,
    this.width,
    this.label,
    this.semanticLabel,
    this.seed,
  });

  /// 0..1.
  final double value;
  final Color color;
  final double height;
  final double? width;
  final String? label;
  final String? semanticLabel;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: 'progress');
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final tube = SLSurfaceSpec(
      shape: SLRoundRect(height / 2),
      color: SLColors.paperShade,
      ink: theme.ink,
      inkWidth: theme.inkWidth - 0.4,
      roughness: theme.roughness,
      seed: s,
    );
    final fill = SLSurfaceSpec(
      shape: SLRoundRect(height / 2),
      material: SLMaterial.wash,
      color: color,
      paper: SLColors.paperShade,
      outline: false,
      roughness: theme.roughness,
      seed: s + 1,
    );
    final text = label == null
        ? null
        : Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(label!, maxLines: 1, style: SLTextStyles.of(context).caption.copyWith(fontSize: height * 0.56, height: 1)),
              ),
            ),
          );
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: width,
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: slReduceMotion(context) ? Duration.zero : SLMetrics.progress,
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => CustomPaint(painter: _ProgressPainter(tube, fill, t), child: child),
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.tube, this.fill, this.value);

  final SLSurfaceSpec tube;
  final SLSurfaceSpec fill;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(slSurfaceArt(tube, size).picture);
    if (value <= 0) return;
    final inner = (Offset.zero & size).deflate(3.5);
    if (inner.isEmpty) return;
    final art = slSurfaceArt(fill, inner.size);
    final x = inner.left + inner.width * value;
    final edge = Path()
      ..moveTo(x, inner.top - 2)
      ..quadraticBezierTo(x + 3, inner.center.dy, x, inner.bottom + 2);
    final clip = Path()
      ..moveTo(inner.left - 2, inner.top - 2)
      ..lineTo(x, inner.top - 2)
      ..quadraticBezierTo(x + 3, inner.center.dy, x, inner.bottom + 2)
      ..lineTo(inner.left - 2, inner.bottom + 2)
      ..close();
    canvas
      ..save()
      ..clipPath(clip)
      ..translate(inner.left, inner.top)
      ..drawPicture(art.picture)
      ..restore();
    if (value < 1) {
      canvas
        ..save()
        ..clipPath(Path()..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2))));
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color.lerp(fill.color, SLColors.ink, 0.35)!.withValues(alpha: 0.55),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.value != value || old.tube != tube || old.fill != fill;
}
