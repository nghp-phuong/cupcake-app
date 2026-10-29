import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../sugarleaf/sugarleaf.dart';

/// Màu "trắng" cũ của nút/ô chọn → giấy ngà của bộ SL*.
Color? _slFill(Color color) => color == Colors.white ? null : color;

/// Nút chữ kiểu nhãn dán vẽ tay — vẽ bằng [SLButton] (viền mực run tay, tô màu nước, nhấn lún, kêu tiếng chạm,
/// chạm ≥ 48px). Giữ API cũ để các màn chưa phải sửa: [icon] (Material) được đổi sang id icon vẽ tay qua
/// [slIconIdFor]; truyền thẳng [iconId] thì ưu tiên hơn.
class SugarButton extends StatelessWidget {
  const SugarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.icon,
    this.iconId,
    this.leading,
    this.color = AppColors.butter,
    this.width,
    this.height = 56,
    this.fontSize = 20,
    this.radius = AppTheme.buttonRadius,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;

  /// Icon Material cũ (đổi sang icon vẽ tay qua [slIconIdFor]).
  final IconData? icon;

  /// Id icon vẽ tay ([kSLIconIds]); ưu tiên hơn [icon].
  final String? iconId;

  /// Hình vẽ đặt trước chữ (ưu tiên hơn [icon]/[iconId]).
  final Widget? leading;

  /// Màu nền (màu nước); `Colors.white` = giấy ngà.
  final Color color;
  final double? width;
  final double height;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final white = color == Colors.white;
    return SLButton(
      label: label,
      subtitle: subtitle,
      onPressed: onPressed,
      variant: white ? SLButtonVariant.secondary : SLButtonVariant.primary,
      color: _slFill(color),
      icon: iconId ?? (icon == null ? null : slIconIdFor(icon!)),
      leading: leading,
      width: width,
      height: height,
      fontSize: fontSize,
      radius: radius,
    );
  }
}

/// Nút tròn chỉ có icon — vẽ bằng [SLButton.icon]; [tooltip] là nhãn đọc màn hình (tìm được bằng
/// `find.byTooltip`); [badge] = chấm báo có việc chờ ([SLBadge.dot]).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconId,
    this.color = Colors.white,
    this.size = 56,
    this.badge = false,
    this.art,
  }) : assert(icon != null || iconId != null, 'cần iconId hoặc icon');

  /// Icon Material cũ (đổi sang icon vẽ tay qua [slIconIdFor]); bỏ qua khi có [iconId].
  final IconData? icon;

  /// Id icon vẽ tay; ưu tiên hơn [icon].
  final String? iconId;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  final double size;
  final bool badge;

  /// Ảnh vẽ tay thay cho icon (chưa nạp/thiếu → icon vẽ bằng code).
  final ArtRef? art;

  @override
  Widget build(BuildContext context) {
    final id = iconId ?? slIconIdFor(icon!);
    final d = size < SLMetrics.minTap ? SLMetrics.minTap : size;
    return SLButton.icon(
      icon: id,
      tooltip: tooltip,
      onPressed: onPressed,
      size: d,
      color: _slFill(color),
      badge: badge ? const SLBadge.dot() : null,
      iconChild: art == null
          ? null
          : SLArtIcon(
              art!,
              id,
              size: d * 0.56,
              color: onPressed == null ? SLColors.disabledInk : null,
              dimmed: onPressed == null,
            ),
    );
  }
}

/// Ô chọn kiểu viên kẹo (ngôn ngữ, âm thanh, tab ô trang trí…) — vẽ bằng [SLChip]: đang chọn tô màu nước hồng
/// dâu + dấu tích; Semantics button + selected.
class PillChoice extends StatelessWidget {
  const PillChoice({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.iconId});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Icon Material cũ (đổi sang icon vẽ tay qua [slIconIdFor]).
  final IconData? icon;

  /// Id icon vẽ tay; ưu tiên hơn [icon].
  final String? iconId;

  @override
  Widget build(BuildContext context) => SLChip(
        label: label,
        selected: selected,
        onPressed: onTap,
        icon: iconId ?? (icon == null ? null : slIconIdFor(icon!)),
      );
}
