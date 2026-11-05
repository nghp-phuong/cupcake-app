import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/city/mai_look.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';
import 'town_l10n.dart';

/// Màu ô chọn (chép từ màu tóc chibi trong cảnh 3D; không import lib/game).
Color salonSwatch(MaiHairColor c) => switch (c) {
  MaiHairColor.chestnut => const Color(0xFFA06A45),
  MaiHairColor.caramel => const Color(0xFFC98B4E),
  MaiHairColor.black => const Color(0xFF3B2E2A),
  MaiHairColor.strawberry => const Color(0xFFF5A8BC),
};

/// Bảng tiệm tóc "Vỏ Sò": panel bên phải, chọn 4 kiểu × 4 màu. Mỗi lần chọn gọi [onPreview] (cảnh đổi tóc Mai ngay
/// để xem); hiện giá `SalonPrices.priceFor(current, chọn)`. "Xác nhận" → [onConfirm] với kiểu đang chọn (mờ nếu
/// thiếu xu; nơi gọi gọi `wallet.buyLook`); "Huỷ" → [onCancel] (cảnh trả lại kiểu cũ [current]). Giữ trạng thái chọn
/// trong widget; [coins] đổi từ ngoài thì cập nhật nút. Tự bọc `Positioned` sát mép phải — đặt làm con của `Stack`.
class SalonSheet extends StatefulWidget {
  const SalonSheet({
    super.key,
    required this.current,
    required this.coins,
    required this.onPreview,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Kiểu tóc đang có của Mai (điểm tính giá, và là kiểu được trả lại khi huỷ).
  final MaiLook current;
  final int coins;
  final void Function(MaiLook look) onPreview;
  final void Function(MaiLook look) onConfirm;
  final VoidCallback onCancel;

  @override
  State<SalonSheet> createState() => _SalonSheetState();
}

class _SalonSheetState extends State<SalonSheet> {
  late MaiLook _pick = widget.current;

  void _set(MaiLook look) {
    if (look == _pick) return;
    setState(() => _pick = look);
    widget.onPreview(look);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final s = Shop3dStyle.scaleOf(size);
    final price = SalonPrices.priceFor(widget.current, _pick);
    final enough = widget.coins >= price;
    return Positioned(
      top: 10 + pad.top,
      bottom: 10 + pad.bottom,
      right: 10 + pad.right,
      width: math.min(400 * s, size.width * 0.6),
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.all(12 * s),
          decoration: Shop3dStyle.box(color: AppColors.cream, radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.citySalonTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Shop3dStyle.title(context, 24 * s),
              ),
              SizedBox(height: 6 * s),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(l.cityHairStyle, s),
                      Wrap(
                        spacing: 8 * s,
                        runSpacing: 8 * s,
                        children: [
                          for (final h in MaiHair.values)
                            _StyleChip(
                              label: hairText(l, h),
                              selected: _pick.hair == h,
                              onTap: () => _set(_pick.copyWith(hair: h)),
                              scale: s,
                            ),
                        ],
                      ),
                      SizedBox(height: 12 * s),
                      _SectionLabel(l.cityHairColor, s),
                      Wrap(
                        spacing: 10 * s,
                        runSpacing: 8 * s,
                        children: [
                          for (final c in MaiHairColor.values)
                            _Swatch(
                              label: hairColorText(l, c),
                              color: salonSwatch(c),
                              selected: _pick.hairColor == c,
                              onTap: () => _set(_pick.copyWith(hairColor: c)),
                              scale: s,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8 * s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinIcon(size: 24 * s),
                  SizedBox(width: 6 * s),
                  Text(
                    l.cityPrice(price),
                    key: const ValueKey('salon-price'),
                    style: Shop3dStyle.title(
                      context,
                      20 * s,
                      color: enough ? AppColors.chocolate : SLColors.badDeep,
                    ),
                  ),
                ],
              ),
              if (!enough)
                Text(
                  l.cityNotEnoughCoins,
                  textAlign: TextAlign.center,
                  style: Shop3dStyle.body(
                    14 * s,
                    weight: FontWeight.w800,
                    color: SLColors.badDeep,
                  ),
                ),
              SizedBox(height: 8 * s),
              Row(
                children: [
                  Expanded(
                    child: Shop3dPillButton(
                      label: l.cityCancel,
                      color: Colors.white,
                      onPressed: widget.onCancel,
                      width: double.infinity,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Shop3dPillButton(
                      label: l.cityConfirm,
                      color: AppColors.good,
                      onPressed: enough ? () => widget.onConfirm(_pick) : null,
                      width: double.infinity,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.scale);

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 6 * scale),
    child: Text(
      text,
      style: Shop3dStyle.body(
        15 * scale,
        weight: FontWeight.w800,
        color: AppColors.caramel,
      ),
    ),
  );
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Shop3dPillButton(
      label: label,
      color: selected ? AppColors.strawberry : Colors.white,
      onPressed: onTap,
      fontSize: 15,
      width: 150 * scale,
      semanticsLabel: label,
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final d = 48 * scale;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: math.max(d, SLMetrics.minTap) + 6,
          height: math.max(d, SLMetrics.minTap) + 6,
          child: Center(
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.chocolate : AppColors.caramel,
                  width: selected ? 4 : 2,
                ),
                boxShadow: selected ? Shop3dStyle.circle().boxShadow : null,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
