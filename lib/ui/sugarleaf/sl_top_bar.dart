import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_panel.dart';
import 'sl_pressable.dart';
import 'sl_theme.dart';

/// Thanh trên của màn: [leading] (vd. nút quay lại) + [children] (thường là [SLTopBarItem]) dồn phải.
/// Cao 72; mỗi phần tử cách nhau 12.
class SLTopBar extends StatelessWidget {
  const SLTopBar({super.key, this.leading, this.title, this.children = const []});

  final Widget? leading;

  /// Phần giữa-trái (vd. `SLNameTag`).
  final Widget? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            if (title != null) Flexible(child: Align(alignment: Alignment.centerLeft, child: title)) else const Spacer(),
            for (final c in children) ...[const SizedBox(width: 12), c],
          ],
        ),
      ),
    );
  }
}

/// Nhãn giấy dán trên thanh trên: icon ([icon] = id [SLIcon] hoặc [leading]) + giá trị (tiền, đá quý, cấp…).
/// Có [onPressed] → bấm được (Semantics button, nhãn [semanticLabel]). Nghiêng nhẹ theo seed, băng dính ở góc.
class SLTopBarItem extends StatelessWidget {
  const SLTopBarItem({
    super.key,
    required this.value,
    this.icon,
    this.leading,
    this.onPressed,
    this.semanticLabel,
    this.color,
    this.minWidth = 110,
    this.seed,
  });

  final String value;
  final String? icon;
  final Widget? leading;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? color;
  final double minWidth;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: icon ?? semanticLabel ?? 'item');
    final tilt = ((s % 5) - 2) * 0.008;
    final spec = SLSurfaceSpec(
      shape: const SLRoundRect(10),
      color: color ?? theme.paper,
      ink: theme.ink,
      inkWidth: theme.inkWidth - 0.2,
      roughness: theme.roughness,
      sticker: true,
      seed: s,
    );
    final lead = leading ?? (icon == null ? null : SLIcon(icon!, size: 32));
    Widget sticker(Animation<double>? press) => SLSurface(
          spec: spec,
          lift: 3,
          press: press,
          padding: const EdgeInsets.fromLTRB(10, 4, 14, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 8)],
              Flexible(
                child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: SLTextStyles.of(context).number),
              ),
            ],
          ),
        );
    Widget item = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: SLMetrics.minTap, maxHeight: 56),
      child: onPressed == null
          ? Semantics(label: semanticLabel, child: sticker(null))
          : SLPressable(onPressed: onPressed, semanticLabel: semanticLabel, builder: (context, press) => sticker(press)),
    );
    item = Stack(
      clipBehavior: Clip.none,
      children: [item, Positioned(left: -8, top: -7, child: SLTapeStrip(angle: -0.6, width: 30, height: 13, seed: s))],
    );
    return RepaintBoundary(child: Transform.rotate(angle: tilt, child: item));
  }
}
