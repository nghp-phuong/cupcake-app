import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/format.dart';
import '../shop3d/shop3d_toasts.dart';

/// Chip "x2 (xem quảng cáo) +N" hiện trên nút A sau khi thu tiền chi nhánh. Tự ẩn sau [visibleFor] (rồi gọi
/// [onExpired]); chạm → [onTap]. Widget thường (nơi gọi tự đặt vị trí); vùng chạm cao ≥ 48.
class BranchDoubleChip extends StatefulWidget {
  const BranchDoubleChip({
    super.key,
    required this.coins,
    required this.onTap,
    this.visibleFor = const Duration(seconds: 8),
    this.onExpired,
  });

  /// Số xu được thêm nếu xem quảng cáo (bằng số vừa thu).
  final int coins;
  final VoidCallback onTap;
  final Duration visibleFor;
  final VoidCallback? onExpired;

  @override
  State<BranchDoubleChip> createState() => _BranchDoubleChipState();
}

class _BranchDoubleChipState extends State<BranchDoubleChip> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.visibleFor, _expire);
  }

  void _expire() {
    if (!mounted) return;
    setState(() => _visible = false);
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final label = '${l.offlineDouble} ${formatSigned(context, widget.coins)}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Shop3dStyle.minTap),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: Shop3dStyle.box(color: AppColors.mint, radius: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ondemand_video_rounded, size: 20, color: AppColors.chocolate),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Shop3dStyle.body(15, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
