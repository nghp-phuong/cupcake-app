import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import 'sl_button.dart';
import 'sl_name_tag.dart';
import 'sl_panel.dart';
import 'sl_theme.dart';

/// Mở hộp thoại SL*: nền tối nhẹ màu mực, hộp nảy ra (phóng 0,85 → 1 kiểu easeOutBack + mờ dần); tắt hiệu ứng
/// → hiện ngay. [dismissible] = chạm nền để đóng.
Future<T?> showSLDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  final reduce = slReduceMotion(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: SLColors.barrier,
    transitionDuration: reduce ? Duration.zero : SLMetrics.dialogIn,
    pageBuilder: (ctx, animation, secondary) => SLScope(child: Center(child: builder(ctx))),
    transitionBuilder: (ctx, animation, secondary, child) {
      if (reduce) return child;
      final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(scale), child: child),
      );
    },
  );
}

/// Hộp thoại vẽ tay: panel giấy (hoặc khung gỗ) + băng tiêu đề trên mép, nút đóng tròn tuỳ chọn (tooltip
/// `commonClose`), hàng nút [actions] ở dưới (tự xuống hàng nếu chật). Nội dung dài thì cuộn.
class SLDialog extends StatelessWidget {
  const SLDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 580,
    this.showClose = false,
    this.onClose,
    this.titleColor,
    this.style = SLPanelStyle.paper,
    this.titleIcon,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final bool showClose;

  /// Mặc định: `Navigator.pop()`.
  final VoidCallback? onClose;
  final Color? titleColor;
  final SLPanelStyle style;
  final String? titleIcon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: width, maxWidth: width, maxHeight: 660),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SLPanel(
              title: title,
              titleColor: titleColor,
              titleIcon: titleIcon,
              titleStyle: SLNameTagStyle.ribbon,
              style: style,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle.merge(
                        style: styles.body.copyWith(fontSize: 19, height: 1.35),
                        textAlign: TextAlign.center,
                        child: child,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 14,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
            if (showClose)
              Positioned(
                top: 18,
                right: -12,
                child: SLButton.icon(
                  icon: 'close',
                  tooltip: l.commonClose,
                  size: 48,
                  onPressed: onClose ??
                      () {
                        // Hai chạm cùng khung hình: route đã đang đóng thì bỏ qua, không pop nhầm màn dưới.
                        if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
                      },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
