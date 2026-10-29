import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_theme.dart';

/// Tooltip mẩu giấy vẽ tay (viền mực run tay, bóng nâu mềm) thay hộp xám của Material: giữ lâu / rê chuột hiện
/// [message]. Vẫn là `Tooltip` bên trong → tìm được bằng `find.byTooltip`. [excludeFromSemantics] = true khi
/// [message] đã là nhãn đọc màn hình của [child] (vd. nút chỉ có icon).
class SLTooltip extends StatelessWidget {
  const SLTooltip({super.key, required this.message, required this.child, this.excludeFromSemantics = false});

  final String message;
  final Widget child;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: message,
        excludeFromSemantics: excludeFromSemantics,
        decoration: const SLTooltipDecoration(),
        textStyle: SLTextStyles.of(context).caption.copyWith(fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      );
}

/// Nền mẩu giấy vẽ tay cho `Tooltip` (dùng khi cần tự dựng `Tooltip`; thường dùng [SLTooltip]).
class SLTooltipDecoration extends Decoration {
  const SLTooltipDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _SLTooltipPainter();
}

class _SLTooltipPainter extends BoxPainter {
  static final _painter = SLSurfacePainter(
    spec: const SLSurfaceSpec(shape: SLRoundRect(10), color: SLColors.paper, inkWidth: 1.8, seed: 0x7001),
    lift: 2.5,
  );

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    _painter.paint(canvas, size);
    canvas.restore();
  }
}
