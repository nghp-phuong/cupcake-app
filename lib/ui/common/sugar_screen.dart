import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../l10n/gen/app_localizations.dart';
import '../sugarleaf/sugarleaf.dart';
import 'art.dart';
import 'currency_bar.dart';
import 'panel.dart';
import 'sugar_button.dart';

/// Chiều cao thanh trên (tấm ván gỗ) của các màn phụ.
const double kScreenHeaderHeight = 88;

/// Khung chung cho màn phụ (nâng cấp, trang trí, sổ công thức, cửa hàng, cài đặt): nền giấy dán tường hoa vẽ tay
/// (phủ lớp kem cho dịu; chưa nạp ảnh → nền kem chấm bi), tấm ván gỗ trên cùng mang nút quay lại tròn, dải vải
/// tiêu đề và nhãn xu/gem. Có `Material` trong suốt (widget Material cũ trong màn vẫn chạy) và [SLScope] (chữ mực
/// nâu, font nội dung). [body] được đặt trong vùng 1280 × (720 − [kScreenHeaderHeight]).
class SugarScreen extends StatelessWidget {
  const SugarScreen({
    super.key,
    required this.title,
    required this.body,
    this.showCurrency = true,
    this.titleIcon,
    this.titleIconId,
    this.titleArt,
  });

  final String title;
  final Widget body;
  final bool showCurrency;

  /// Icon Material cũ của tiêu đề (đổi sang icon vẽ tay qua [slIconIdFor]).
  final IconData? titleIcon;

  /// Id icon vẽ tay của tiêu đề; ưu tiên hơn [titleIcon].
  final String? titleIconId;

  /// Ảnh vẽ tay thay cho icon tiêu đề (chưa nạp/thiếu → icon vẽ bằng code).
  final ArtRef? titleArt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: SLColors.cream,
      child: SLScope(
        child: Stack(
          children: [
            const Positioned.fill(child: RepaintBoundary(child: WallpaperBackdrop())),
            const Positioned(left: -14, right: -14, top: -16, height: kScreenHeaderHeight + 4, child: _HeaderPlank()),
            Positioned(left: 0, right: 0, top: kScreenHeaderHeight, bottom: 0, child: body),
            Positioned(
              left: 20,
              right: 24,
              top: 10,
              height: 64,
              child: Row(
                children: [
                  RoundIconButton(
                    iconId: 'back',
                    tooltip: l.commonBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 18),
                  Flexible(child: TitleRibbon(title, icon: titleIcon, iconId: titleIconId, art: titleArt)),
                  const Spacer(),
                  if (showCurrency) const CurrencyBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tấm ván gỗ sáng chạy ngang mép trên (thanh tiêu đề của màn phụ).
class _HeaderPlank extends StatelessWidget {
  const _HeaderPlank();

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: SLRoundRect(16),
            material: SLMaterial.wood,
            color: SLColors.woodLight,
            inkWidth: SLMetrics.inkWidth + 0.4,
            seed: 0x91A4,
          ),
          lift: 4,
        ),
      );
}

/// Nền giấy dán tường hoa vẽ tay lặp lại (ô 320), phủ lớp kem mờ để nội dung nổi lên; chưa nạp ảnh →
/// [CozyBackground]. Phủ kín vùng được cấp — nền chung của các màn phụ ([SugarScreen]); màn khác muốn cùng nền thì
/// đặt trong `Positioned.fill` (nên bọc `RepaintBoundary`).
class WallpaperBackdrop extends StatelessWidget {
  const WallpaperBackdrop({super.key});

  /// Hoạ tiết giấy dán tường (nạp sẵn ở menu: cũng là nền chờ ảnh của màn ngày).
  static const tile = ArtRef(ArtGroup.tiles, 'wallpaperFloral');

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const CozyBackground(),
          ArtCanvas(
            repaintKey: tile,
            repaint: ArtSprites.changes,
            paint: (c, s) {
              final image = tile.image;
              if (image == null) return;
              final rect = Offset.zero & s;
              paintArtTiled(c, rect, image, tileSize: 320);
              c.drawRect(rect, Paint()..color = const Color(0xB3FFF4E6));
            },
          ),
        ],
      );
}
