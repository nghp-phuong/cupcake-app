import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_pressable.dart';
import 'sl_theme.dart';

/// Chip vẽ tay dạng viên kẹo.
/// - Có [onPressed]: chọn được (cao 48, Semantics button + selected); đang chọn → tô màu nước [color] + dấu tích.
/// - [onPressed] null: nhãn tĩnh (cao 36, không phải nút); [selected] = tô màu nước [color] (không mang nghĩa
///   "đang chọn" khi đọc màn hình).
/// - [enabled] false: chip chọn được nhưng đang tắt.
class SLChip extends StatelessWidget {
  const SLChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onPressed,
    this.enabled = true,
    this.color = SLColors.strawberry,
    this.seed,
    this.debugPressed = false,
  });

  final String label;

  /// Id icon ([SLIcon]); khi đang chọn icon được thay bằng dấu tích.
  final String? icon;
  final bool selected;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Màu khi chọn (chip tĩnh: màu nền nếu [selected]).
  final Color color;
  final int? seed;
  final bool debugPressed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final interactive = onPressed != null;
    final off = interactive && !enabled;
    final ink = off ? SLColors.disabledInk : theme.ink;
    final h = interactive ? SLMetrics.minTap : 36.0;
    final fill = off ? SLColors.disabledFill : (selected ? color : SLColors.paper);
    final spec = SLSurfaceSpec(
      shape: SLRoundRect(h / 2),
      material: SLMaterial.wash,
      color: fill,
      ink: ink,
      inkWidth: selected ? theme.inkWidth + 0.4 : theme.inkWidth - 0.4,
      roughness: theme.roughness,
      sticker: interactive,
      seed: slSeed(seed: seed, key: key, content: label),
    );
    final styles = SLTextStyles.of(context);
    final lead = selected && interactive ? 'check' : icon;
    Widget content(Animation<double>? press) => SLSurface(
          spec: spec,
          lift: interactive ? (selected ? 3.5 : 2.5) : 0,
          press: press,
          padding: EdgeInsets.symmetric(horizontal: lead == null ? 18 : 14),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[SLIcon(lead, size: h * 0.46, color: ink, dimmed: off), const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.label.copyWith(fontSize: interactive ? 17 : 15, color: ink),
                  ),
                ),
              ],
            ),
          ),
        );
    if (!interactive) {
      return SizedBox(height: h, child: RepaintBoundary(child: content(null)));
    }
    return RepaintBoundary(
      child: SizedBox(
        height: h,
        child: SLPressable(
          onPressed: enabled ? onPressed : null,
          selected: selected,
          debugPressed: debugPressed,
          builder: (context, press) => content(press),
        ),
      ),
    );
  }
}

/// Một tab của [SLTabBar].
@immutable
class SLTabItem {
  const SLTabItem(this.label, {this.icon});

  final String label;
  final String? icon;
}

/// Hàng tab vẽ tay kiểu thẻ đánh dấu trang: tab đang chọn nhô cao, tô màu nước [color]; các tab khác là giấy cũ
/// thấp hơn. Mỗi tab cao ≥ 48, Semantics selected. [expand] = chia đều chiều rộng.
///
/// [iconAbove] = kiểu tab hẹp: icon nằm trên chữ, chữ 14 tối đa 2 dòng (co lại nếu vẫn chật), tab khác thấp hơn
/// 8 thay vì 6 — để nhiều tab vừa bề ngang hẹp (vd. 5 ô trang trí; nên đặt [height] ~80).
class SLTabBar extends StatelessWidget {
  const SLTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.color = SLColors.butter,
    this.expand = false,
    this.height = 56,
    this.iconAbove = false,
    this.spacing = 6,
    this.seed,
  });

  final List<SLTabItem> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool expand;
  final double height;
  final bool iconAbove;

  /// Khoảng cách giữa các tab.
  final double spacing;

  /// Seed nét run tay của tab đầu (tab i = seed + i); null → theo nhãn.
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final styles = SLTextStyles.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Flexible(
              fit: expand ? FlexFit.tight : FlexFit.loose,
              child: _tab(context, i, theme, styles),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int i, SLTheme theme, SLTextStyles styles) {
    final on = i == selected;
    final tab = tabs[i];
    final h = on ? height : height - (iconAbove ? 8 : 6);
    final spec = SLSurfaceSpec(
      shape: const SLRoundRect(14, topOnly: true),
      material: SLMaterial.wash,
      color: on ? color : SLColors.paperShade,
      ink: theme.ink,
      inkWidth: on ? theme.inkWidth : theme.inkWidth - 0.5,
      roughness: theme.roughness,
      seed: seed == null ? slSeed(content: tab.label, salt: i) : seed! + i,
    );
    final Widget content;
    if (iconAbove) {
      content = Column(
        children: [
          if (tab.icon != null) ...[SLIcon(tab.icon!, size: on ? 28 : 26), const SizedBox(height: 2)],
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: c.maxWidth,
                    child: Text(
                      tab.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: styles.label.copyWith(fontSize: 14, height: 1.05),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = Center(
        widthFactor: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.icon != null) ...[SLIcon(tab.icon!, size: 24), const SizedBox(width: 6)],
              Text(tab.label, maxLines: 1, style: styles.label.copyWith(fontSize: on ? 18 : 16)),
            ],
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 64, minHeight: h, maxHeight: h),
        child: SLPressable(
          onPressed: () => onChanged(i),
          selected: on,
          bounce: !on,
          builder: (context, press) => SLSurface(
            spec: spec,
            press: on ? null : press,
            padding: iconAbove ? const EdgeInsets.fromLTRB(4, 6, 4, 10) : const EdgeInsets.symmetric(horizontal: 14),
            child: content,
          ),
        ),
      ),
    );
  }
}
