import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import 'sl_tap_target.dart';
import 'sl_theme.dart';

/// Hành vi bấm chung của SL*: không ripple. Nhấn → lún (press 0→1 trong [SLMetrics.pressIn]); thả → nổi lại và
/// nảy nhẹ (phóng 1 → 1,04 → 1). Kêu tiếng chạm (nếu có AppScope). Tôn trọng `disableAnimations`.
/// [builder] nhận Animation press để painter vẽ lại mà không dựng lại widget.
class SLPressable extends StatefulWidget {
  const SLPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.isButton = true,
    this.debugPressed = false,
    this.bounce = true,
  });

  final VoidCallback? onPressed;
  final Widget Function(BuildContext context, Animation<double> press) builder;

  /// Nhãn đọc màn hình (nút chỉ có icon bắt buộc có).
  final String? semanticLabel;
  final bool? selected;
  final bool? toggled;
  final bool isButton;

  /// Giữ ở trạng thái lún (chỉ để trình bày trong Gallery / ảnh chụp).
  final bool debugPressed;

  /// Nảy khi thả.
  final bool bounce;

  @override
  State<SLPressable> createState() => _SLPressableState();
}

class _SLPressableState extends State<SLPressable> with TickerProviderStateMixin {
  late final _press = AnimationController(vsync: this, lowerBound: -0.3, upperBound: 1, value: widget.debugPressed ? 1 : 0);
  late final _pop = AnimationController(vsync: this, duration: SLMetrics.bounce);
  bool _down = false;

  /// Cờ tắt hiệu ứng, đọc lại mỗi lần dựng (không tra context trong callback — có thể đến lúc đang gỡ widget).
  bool _reduce = false;

  bool get _enabled => widget.onPressed != null;

  @override
  void didUpdateWidget(SLPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugPressed != widget.debugPressed) _press.value = widget.debugPressed ? 1 : 0;
    if (!_enabled && _down) _release(bounce: false);
  }

  @override
  void dispose() {
    _press.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!_enabled || _down) return;
    _down = true;
    if (_reduce) {
      _press.value = 1;
    } else {
      _press.animateTo(1, duration: SLMetrics.pressIn, curve: Curves.easeOut);
    }
  }

  void _release({bool bounce = true}) {
    if (!_down) return;
    _down = false;
    if (widget.debugPressed || !mounted) return;
    if (_reduce) {
      _press.value = 0;
      return;
    }
    _press.animateTo(0, duration: SLMetrics.pressOut, curve: Curves.easeOutBack);
    if (bounce && widget.bounce) _pop.forward(from: 0);
  }

  void _tap() {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    scope?.services.audio.tap();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    _reduce = slReduceMotion(context);
    Widget child = widget.builder(context, _press);
    if (widget.bounce) {
      child = AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final v = _pop.value;
          if (v == 0 || v == 1) return child!;
          return Transform.scale(scale: 1 + 0.04 * math.sin(math.pi * v), child: child);
        },
        child: child,
      );
    }
    // Vùng chạm nới tới ≥ 48 dp thật (hình giữ nguyên) — xem SLTapTarget.
    return SLTapTarget(
      enabled: _enabled,
      child: Semantics(
        button: widget.isButton,
        enabled: _enabled,
        selected: widget.selected,
        toggled: widget.toggled,
        label: widget.semanticLabel,
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => _pressDown() : null,
            onTapUp: _enabled ? (_) => _release() : null,
            onTapCancel: _enabled ? () => _release(bounce: false) : null,
            onTap: _enabled ? _tap : null,
            child: child,
          ),
        ),
      ),
    );
  }
}
