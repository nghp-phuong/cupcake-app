import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_theme.dart';

/// Kiểu bảng tên.
enum SLNameTagStyle {
  /// Dải vải có đuôi cắt chữ V, chỉ khâu dọc mép.
  ribbon,

  /// Tấm ván gỗ sáng đóng hai đinh.
  wood,
}

/// Bảng tên / băng tiêu đề vẽ tay: dải vải hoặc ván gỗ, chữ font tiêu đề màu mực (một dòng, tự co khi dài).
class SLNameTag extends StatelessWidget {
  const SLNameTag(
    this.text, {
    super.key,
    this.style = SLNameTagStyle.ribbon,
    this.color,
    this.icon,
    this.leading,
    this.seed,
    this.maxWidth = 460,
    this.height = 54,
    this.fontSize,
  });

  final String text;
  final SLNameTagStyle style;

  /// Màu vải / gỗ (mặc định hồng dâu / gỗ sáng).
  final Color? color;

  /// Id icon đặt trước chữ.
  final String? icon;

  /// Hình tuỳ ý đặt trước chữ (ưu tiên hơn [icon]).
  final Widget? leading;
  final int? seed;
  final double maxWidth;
  final double height;

  /// Cỡ chữ; null → 0,44 × [height] (16–30).
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: text);
    final ribbon = style == SLNameTagStyle.ribbon;
    final notch = height * 0.32;
    final spec = SLSurfaceSpec(
      shape: ribbon ? const SLRibbon() : const SLRoundRect(9),
      material: ribbon ? SLMaterial.fabric : SLMaterial.wood,
      color: color ?? (ribbon ? SLColors.fabric : SLColors.woodLight),
      ink: theme.ink,
      inkWidth: theme.inkWidth,
      roughness: theme.roughness,
      seed: s,
    );
    final titleStyle = SLTextStyles.of(context).title.copyWith(fontSize: fontSize ?? (height * 0.44).clamp(16.0, 30.0), height: 1.1);
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          ...[leading!, const SizedBox(width: 8)]
        else if (icon != null)
          ...[SLIcon(icon!, size: height * 0.55), const SizedBox(width: 8)],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, maxLines: 1, style: titleStyle),
          ),
        ),
      ],
    );
    if (!ribbon) {
      // Hai đầu đinh.
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [const _Nail(), const SizedBox(width: 10), Flexible(child: content), const SizedBox(width: 10), const _Nail()],
      );
    }
    return Semantics(
      header: true,
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: height, maxHeight: height),
          child: SLSurface(
            spec: spec,
            lift: 3,
            padding: EdgeInsets.symmetric(horizontal: ribbon ? notch + 16 : 10, vertical: 4),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

class _Nail extends StatelessWidget {
  const _Nail();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 9,
        child: SLSurface(
          spec: SLSurfaceSpec(shape: SLCircle(), material: SLMaterial.wash, color: Color(0xFFB8A79A), inkWidth: 1.2, seed: 3),
        ),
      );
}
