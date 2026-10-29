import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_pressable.dart';
import 'sl_props.dart';
import 'sl_theme.dart';
import 'sl_tooltip.dart';

/// Kiểu nút chữ.
enum SLButtonVariant {
  /// Màu nước hồng dâu (hành động chính).
  primary,

  /// Giấy ngà (hành động phụ).
  secondary,
}

/// Nút nhãn dán vẽ tay: viền mực run tay, tô màu nước, viền giấy + bóng nâu mềm lệch xuống; nhấn lún 3px (bóng
/// thu lại), thả nảy nhẹ. Không ripple. Vùng chạm ≥ 48.
///
/// - `SLButton(label: …)`: nút chữ, icon tuỳ chọn ([icon] = id của [SLIcon] hoặc [leading]), [subtitle],
///   [loading] (chấm chạy, chặn bấm), tắt khi [onPressed] null; [tooltip] (mẩu giấy khi giữ lâu) và
///   [semanticLabel] (thay chữ nút khi đọc màn hình) tuỳ chọn.
/// - `SLButton.icon(icon: …, tooltip: …)`: nút tròn chỉ có icon; [tooltip] bắt buộc (cũng là nhãn đọc màn hình,
///   tìm được bằng `find.byTooltip`), [badge] (vd. `SLBadge.dot()`) gắn góc trên phải.
class SLButton extends StatelessWidget {
  const SLButton({
    super.key,
    required String this.label,
    required this.onPressed,
    this.variant = SLButtonVariant.primary,
    this.icon,
    this.leading,
    this.subtitle,
    this.color,
    this.width,
    this.height = 56,
    this.fontSize,
    this.radius,
    this.loading = false,
    this.tooltip,
    this.semanticLabel,
    this.seed,
    this.debugPressed = false,
  }) : badge = null,
       iconChild = null,
       size = 56;

  const SLButton.icon({
    super.key,
    required String this.icon,
    required String this.tooltip,
    required this.onPressed,
    this.size = 56,
    this.badge,
    this.iconChild,
    this.color,
    this.seed,
    this.debugPressed = false,
  }) : label = null,
       semanticLabel = tooltip,
       variant = SLButtonVariant.secondary,
       leading = null,
       subtitle = null,
       width = null,
       height = 56,
       fontSize = null,
       radius = null,
       loading = false;

  final String? label;
  final VoidCallback? onPressed;
  final SLButtonVariant variant;

  /// Id icon ([kSLIconIds]).
  final String? icon;

  /// Hình tuỳ ý đặt trước chữ (ưu tiên hơn [icon]).
  final Widget? leading;
  final String? subtitle;

  /// Màu nền thay cho màu của [variant] (vd. `SLColors.mint`, `SLColors.dangerSoft`).
  final Color? color;
  final double? width;
  final double height;

  /// Cỡ chữ nhãn; null → theo chiều cao (0,34 × cao, 16–24).
  final double? fontSize;

  /// Bo góc; null → [SLMetrics.radiusButton] (không quá nửa chiều cao).
  final double? radius;
  final bool loading;

  /// Seed nét run tay; null → suy từ key/nhãn (ổn định).
  final int? seed;

  /// Giữ trạng thái lún (chỉ để trình bày trong Gallery).
  final bool debugPressed;

  /// Chữ mẩu giấy hiện khi giữ lâu / rê chuột ([SLTooltip]). Nút tròn: bắt buộc, cũng là nhãn đọc màn hình.
  final String? tooltip;

  /// Nhãn đọc màn hình thay cho chữ trên nút (nút chữ); nút tròn = [tooltip].
  final String? semanticLabel;
  final Widget? badge;

  /// Hình tuỳ ý thay cho [SLIcon] của nút tròn (vd. ảnh vẽ tay đã nạp); null → `SLIcon(icon)`.
  final Widget? iconChild;

  /// Đường kính nút tròn.
  final double size;

  bool get _enabled => onPressed != null && !loading;

  Color _fill() {
    if (onPressed == null) return SLColors.disabledFill;
    return color ?? (variant == SLButtonVariant.primary ? SLColors.strawberry : SLColors.paper);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: label == null ? _buildIcon(context) : _buildLabel(context));

  Widget _buildLabel(BuildContext context) {
    final theme = SLTheme.of(context);
    final ink = onPressed == null ? SLColors.disabledInk : theme.ink;
    final styles = SLTextStyles.of(context);
    final h = math.max(height, SLMetrics.minTap);
    final fontSize = this.fontSize ?? (h * 0.34).clamp(16.0, 24.0);
    final spec = SLSurfaceSpec(
      shape: SLRoundRect(math.min(radius ?? SLMetrics.radiusButton, h / 2)),
      material: SLMaterial.wash,
      color: _fill(),
      ink: ink,
      sticker: true,
      roughness: theme.roughness,
      inkWidth: theme.inkWidth,
      seed: slSeed(seed: seed, key: key, content: label),
    );
    final lead = loading
        ? SLLoadingDots(color: ink)
        : leading ?? (icon == null ? null : SLIcon(icon!, size: fontSize * 1.45, color: ink, dimmed: onPressed == null));
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: lead == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          maxLines: 1,
          style: styles.label.copyWith(fontSize: fontSize, color: ink, height: 1.1),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            style: styles.caption.copyWith(fontSize: fontSize * 0.68, color: ink, height: 1.1),
          ),
      ],
    );
    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minWidth: SLMetrics.minTap, minHeight: h, maxHeight: h),
      child: SizedBox(
        width: width,
        child: SLPressable(
          onPressed: _enabled ? onPressed : null,
          semanticLabel: semanticLabel,
          debugPressed: debugPressed,
          builder: (context, press) => SLSurface(
            spec: spec,
            lift: onPressed == null ? 1.5 : SLMetrics.buttonLift,
            press: press,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Center(
              widthFactor: 1,
              child: ExcludeSemantics(
                excluding: semanticLabel != null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lead != null) ...[lead, const SizedBox(width: 10)],
                      text,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) button = SLTooltip(message: tooltip!, child: button);
    return button;
  }

  Widget _buildIcon(BuildContext context) {
    final theme = SLTheme.of(context);
    final ink = onPressed == null ? SLColors.disabledInk : theme.ink;
    final d = math.max(size, SLMetrics.minTap);
    final spec = SLSurfaceSpec(
      shape: const SLCircle(),
      material: SLMaterial.wash,
      color: _fill(),
      ink: ink,
      sticker: true,
      roughness: theme.roughness,
      inkWidth: theme.inkWidth,
      seed: slSeed(seed: seed, key: key, content: '$icon|$tooltip'),
    );
    final button = SizedBox.square(
      dimension: d,
      child: SLPressable(
        onPressed: onPressed,
        semanticLabel: tooltip,
        debugPressed: debugPressed,
        builder: (context, press) => SLSurface(
          spec: spec,
          lift: onPressed == null ? 1.5 : SLMetrics.buttonLift,
          press: press,
          child: Center(
            child: iconChild ?? SLIcon(icon!, size: d * 0.56, color: ink, dimmed: onPressed == null),
          ),
        ),
      ),
    );
    return SLTooltip(
      message: tooltip!,
      excludeFromSemantics: true,
      child: badge == null
          ? button
          : Stack(
              clipBehavior: Clip.none,
              children: [
                button,
                Positioned(right: -2, top: -2, child: badge!),
              ],
            ),
    );
  }
}

/// Ba chấm mực nhảy lần lượt (đang tải), 30×22. Tắt hiệu ứng → ba chấm đứng yên. [color] mặc định mực của theme.
class SLLoadingDots extends StatefulWidget {
  const SLLoadingDots({super.key, this.color});

  final Color? color;

  @override
  State<SLLoadingDots> createState() => _SLLoadingDotsState();
}

class _SLLoadingDotsState extends State<SLLoadingDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (slReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SLTheme.of(context).ink;
    return SizedBox(
      width: 30,
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, -4 * math.max(0, math.sin((_c.value - i / 6) * 2 * math.pi))),
                child: SizedBox.square(dimension: 7, child: SLInkDot(color: color, seed: 0xD0 + i)),
              ),
          ],
        ),
      ),
    );
  }
}
