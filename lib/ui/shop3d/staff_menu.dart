import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'shop3d_toasts.dart' show Shop3dPillButton, Shop3dPopIn;

/// Menu khi chạm nhân viên (đặc tả `docs/v3/interaction-spec.md` 2.3): 2 nút 168×48 xếp chồng trên đầu nhân vật —
/// "Điều khiển" và "Nói chuyện với khách". Chạm ra ngoài hoặc sau [autoClose] (5 s) → [onDismiss] (một lần).
///
/// Tự trả về `Positioned.fill` — đặt làm con của `Stack` phủ cảnh. Lớp nhận chạm ngoài menu trong suốt
/// (`HitTestBehavior.translucent`): chạm ra ngoài vừa đóng menu vừa tới cảnh bên dưới (xoay camera, chọn người khác).
/// [anchor] = điểm trên đỉnh đầu (toạ độ màn, đã chiếu); đổi mỗi khung được — trạng thái (bộ hẹn giờ) giữ nguyên,
/// chỉ cần bọc bằng `ValueListenableBuilder` và giữ cùng `key`. Đổi `key` (vd. theo id nhân vật) để đếm lại 5 s.
class Shop3dStaffMenu extends StatefulWidget {
  const Shop3dStaffMenu({
    super.key,
    required this.anchor,
    required this.controlLabel,
    required this.talkLabel,
    required this.onControl,
    required this.onTalk,
    required this.onDismiss,
    this.controlIcon = Icons.directions_walk_rounded,
    this.talkIcon = Icons.chat_bubble_rounded,
    this.autoClose = const Duration(seconds: 5),
    this.gap = 10,
  });

  static const buttonSize = Size(168, 48);
  static const spacing = 8.0;

  /// Lề tối thiểu tới mép màn khi kẹp vị trí.
  static const margin = 8.0;

  final Offset anchor;
  final String controlLabel;
  final String talkLabel;

  /// Chọn "Điều khiển". Menu không tự gọi [onDismiss] sau khi chọn — người nối gỡ menu.
  final VoidCallback onControl;

  /// Chọn "Nói chuyện với khách".
  final VoidCallback onTalk;

  /// Chạm ra ngoài hoặc hết giờ.
  final VoidCallback onDismiss;
  final IconData controlIcon;
  final IconData talkIcon;
  final Duration autoClose;

  /// Khoảng hở giữa đáy menu và [anchor].
  final double gap;

  @override
  State<Shop3dStaffMenu> createState() => _Shop3dStaffMenuState();
}

class _Shop3dStaffMenuState extends State<Shop3dStaffMenu> {
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoClose, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    widget.onDismiss();
  }

  void _pick(VoidCallback cb) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    const b = Shop3dStaffMenu.buttonSize;
    final menuH = b.height * 2 + Shop3dStaffMenu.spacing;
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.hasBoundedHeight && constraints.hasBoundedWidth
            ? constraints.biggest
            : MediaQuery.sizeOf(context);
        const m = Shop3dStaffMenu.margin;
        final left = (widget.anchor.dx - b.width / 2).clamp(m, math.max(m, size.width - b.width - m)).toDouble();
        final top = (widget.anchor.dy - widget.gap - menuH).clamp(m, math.max(m, size.height - menuH - m)).toDouble();
        return Stack(
          children: [
            // Chạm ngoài menu: đóng, và vẫn để chạm đi xuống cảnh.
            Positioned.fill(
              child: Listener(
                key: const ValueKey('shop3d-staff-menu-outside'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _dismiss(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: b.width,
              height: menuH,
              child: Shop3dPopIn(
                child: Column(
                  children: [
                    Shop3dPillButton(
                      key: const ValueKey('shop3d-staff-control'),
                      label: widget.controlLabel,
                      icon: widget.controlIcon,
                      onPressed: () => _pick(widget.onControl),
                      width: b.width,
                      height: b.height,
                      fontSize: 15,
                      maxLines: 2,
                    ),
                    const SizedBox(height: Shop3dStaffMenu.spacing),
                    Shop3dPillButton(
                      key: const ValueKey('shop3d-staff-talk'),
                      label: widget.talkLabel,
                      icon: widget.talkIcon,
                      onPressed: () => _pick(widget.onTalk),
                      color: AppColors.mint,
                      width: b.width,
                      height: b.height,
                      fontSize: 15,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
