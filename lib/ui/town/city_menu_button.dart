import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shop3d/shop3d_toasts.dart';

/// Nút tròn bánh răng mở bảng cài đặt (đặt bên trái minimap). Vùng chạm ≥ 48 dp dù [size] nhỏ hơn.
class CityMenuButton extends StatelessWidget {
  const CityMenuButton({super.key, required this.onPressed, this.size = 48});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = math.max(size, Shop3dStyle.minTap);
    return Semantics(
      button: true,
      label: l.settingsTitle,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: Shop3dStyle.circle(color: AppColors.butter),
          child: Icon(
            Icons.settings_rounded,
            size: d * 0.55,
            color: AppColors.chocolate,
          ),
        ),
      ),
    );
  }
}
