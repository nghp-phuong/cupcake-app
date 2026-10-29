import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'sl_theme.dart';

/// Lắc ngang một lần mỗi khi [trigger] đổi (vd. bấm khi chưa đủ tiền). Lần dựng đầu không lắc.
/// Tắt hiệu ứng → không lắc.
class SLShake extends StatefulWidget {
  const SLShake({super.key, required this.trigger, required this.child, this.distance = 8});

  final Object? trigger;
  final Widget child;
  final double distance;

  @override
  State<SLShake> createState() => _SLShakeState();
}

class _SLShakeState extends State<SLShake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(SLShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !slReduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          if (t == 0 || t == 1) return child!;
          return Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * widget.distance * (1 - t), 0), child: child);
        },
        child: widget.child,
      );
}

/// Nảy vào khi xuất hiện (phóng 0,6 → 1 kiểu easeOutBack). Tắt hiệu ứng → hiện ngay.
class SLBounceIn extends StatelessWidget {
  const SLBounceIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (slReduceMotion(context)) return child;
    const total = Duration(milliseconds: 380);
    final d = delay.inMilliseconds / (delay + total).inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: delay + total,
      builder: (context, v, child) {
        final t = d >= 1 ? 1.0 : ((v - d) / (1 - d)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * Curves.easeOutBack.transform(t), child: child),
        );
      },
      child: child,
    );
  }
}
