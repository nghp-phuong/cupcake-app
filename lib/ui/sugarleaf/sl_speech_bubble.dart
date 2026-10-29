import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_theme.dart';

/// Bong bóng thoại giấy viền mực run tay, đuôi ở cạnh [tail] tại vị trí [tailAt] (0..1 dọc cạnh).
/// Nội dung mặc định kiểu chữ nội dung màu mực; [maxWidth] giới hạn để chữ tự xuống dòng.
class SLSpeechBubble extends StatelessWidget {
  const SLSpeechBubble({
    super.key,
    required this.child,
    this.tail = SLTail.bottom,
    this.tailAt = 0.25,
    this.tailSize = 20,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.maxWidth = 420,
    this.seed,
  });

  final Widget child;
  final SLTail tail;
  final double tailAt;
  final double tailSize;
  final Color? color;
  final EdgeInsets padding;
  final double maxWidth;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final t = tail == SLTail.none ? 0.0 : tailSize;
    final extra = switch (tail) {
      SLTail.none => EdgeInsets.zero,
      SLTail.bottom => EdgeInsets.only(bottom: t),
      SLTail.top => EdgeInsets.only(top: t),
      SLTail.left => EdgeInsets.only(left: t),
      SLTail.right => EdgeInsets.only(right: t),
    };
    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 96, minHeight: 56 + t),
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: SLBubble(tail: tail, tailAt: tailAt, tailSize: t),
            color: color ?? theme.paper,
            ink: theme.ink,
            inkWidth: theme.inkWidth,
            roughness: theme.roughness,
            seed: slSeed(seed: seed, key: key, content: 'bubble'),
          ),
          lift: 3,
          padding: padding + extra,
          child: DefaultTextStyle.merge(style: SLTextStyles.of(context).body.copyWith(fontSize: 19, height: 1.3), child: child),
        ),
      ),
    );
  }
}
