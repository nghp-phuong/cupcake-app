import 'dart:async';

import 'package:flutter/widgets.dart';

import 'sl_icon.dart';
import 'sl_panel.dart';
import 'sl_theme.dart';

/// Loại thông báo (đổi icon).
enum SLToastKind { success, info, warning }

/// Thông báo ngắn kiểu mẩu giấy dán băng dính ở cuối màn (qua Overlay, thay SnackBar sau này): hiện bằng trượt
/// lên + nghiêng nhẹ, tự ẩn sau [SLMetrics.toastShow]. Chỉ một toast một lúc (toast mới thay toast cũ).
abstract final class SLToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message, {SLToastKind kind = SLToastKind.success, Duration? duration}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _SLToastView(
        message: message,
        kind: kind,
        duration: duration ?? SLMetrics.toastShow,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Ẩn ngay toast đang hiện (nếu có).
  static void hide() {
    final e = _current;
    _current = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _SLToastView extends StatefulWidget {
  const _SLToastView({required this.message, required this.kind, required this.duration, required this.onDone});

  final String message;
  final SLToastKind kind;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_SLToastView> createState() => _SLToastViewState();
}

class _SLToastViewState extends State<_SLToastView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), reverseDuration: const Duration(milliseconds: 180));
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed && _timer == null) {
      if (slReduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
      _timer = Timer(widget.duration, _close);
    }
  }

  Future<void> _close() async {
    if (!mounted) return;
    if (!slReduceMotion(context)) await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.kind) {
      SLToastKind.success => 'check',
      SLToastKind.info => 'info',
      SLToastKind.warning => 'warning',
    };
    return Positioned(
      left: 0,
      right: 0,
      bottom: 36,
      child: Center(
        child: SLScope(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = Curves.easeOutBack.transform(_c.value);
              return Opacity(
                opacity: _c.value,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 40),
                  child: Transform.rotate(angle: -0.012 - (1 - t) * 0.05, child: child),
                ),
              );
            },
            child: Semantics(
              liveRegion: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, minWidth: 260),
                child: SLPaperCard(
                  attach: SLAttach.tape,
                  padding: const EdgeInsets.fromLTRB(16, 12, 22, 12),
                  seed: 0x7057,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SLIcon(icon, size: 30, color: widget.kind == SLToastKind.success ? SLColors.goodDeep : null),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: SLTextStyles.of(context).body.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
