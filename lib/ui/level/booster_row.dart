import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/monetization/booster.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/format.dart';
import '../sugarleaf/sugarleaf.dart';
import 'level_common.dart';

/// Icon vẽ code thay ảnh vật phẩm còn thiếu.
String boosterFallbackIcon(BoosterId id) => switch (id) {
  BoosterId.fullCase => 'cake_slice',
  BoosterId.patience => 'heart',
  BoosterId.ovenBoost => 'flame',
};

/// Ảnh một vật phẩm (thiếu → đĩa icon SL).
class BoosterArt extends StatelessWidget {
  const BoosterArt({super.key, required this.booster, required this.size});

  final BoosterData booster;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = SLIconDisc(
      boosterFallbackIcon(booster.id),
      size: size * 0.9,
      color: SLColors.butterLight,
      iconScale: 0.62,
      seed: 0xB005 + booster.id.index,
    );
    final path = booster.artPath;
    if (path == null) return SizedBox.square(dimension: size, child: Center(child: icon));
    return AssetArt(path, width: size, fallback: icon);
  }
}

/// Chọn vật phẩm nào được trả bằng lượt quảng cáo: ô đang chọn đắt nhất (phải trả kim cương), không có thì ô
/// chọn đầu tiên; chưa có lượt quảng cáo / chưa chọn gì → null.
BoosterId? pickAdFreeBooster({
  required bool adCredit,
  required Iterable<BoosterData> selected,
  required int Function(BoosterId id) owned,
}) {
  if (!adCredit || selected.isEmpty) return null;
  BoosterData? best;
  var bestCost = -1;
  for (final b in selected) {
    final cost = owned(b.id) > 0 ? 0 : b.gemPrice;
    if (cost > bestCost) {
      best = b;
      bestCost = cost;
    }
  }
  return best?.id;
}

/// Nút "Xem quảng cáo: 1 miễn phí" (một lần mỗi lượt; đặt cạnh nút "Bắt đầu"). Hết lượt quảng cáo hôm nay → mờ
/// kèm dòng "Hết lượt".
class BoosterAdButton extends StatelessWidget {
  const BoosterAdButton({super.key, required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canWatch = AppScope.of(context).ads.canShowRewarded();
    return SLButton(
      key: const ValueKey('level-booster-ad'),
      label: l.lvlBoosterAdFree,
      subtitle: canWatch ? null : l.adsLimitReached,
      icon: 'play_video',
      color: SLColors.mint,
      width: 270,
      height: 64,
      fontSize: 18,
      loading: busy,
      onPressed: canWatch && !busy ? onPressed : null,
    );
  }
}

/// Hàng chọn vật phẩm hỗ trợ trên thẻ "Sẵn sàng": 3 ô (ảnh, tên, số trong kho hoặc giá kim cương; chạm để
/// chọn/bỏ). Nút quảng cáo là [BoosterAdButton] (cạnh "Bắt đầu"). Chỉ hiển thị — chọn/trừ do `LevelScreen`.
class BoosterRow extends StatelessWidget {
  const BoosterRow({
    super.key,
    required this.boosters,
    required this.selected,
    required this.adFree,
    required this.adCredit,
    required this.onToggle,
    this.link,
  });

  final List<BoosterData> boosters;
  final Set<BoosterId> selected;

  /// Ô đang được trả bằng lượt quảng cáo (hiện "Miễn phí").
  final BoosterId? adFree;

  /// Đã xem quảng cáo lượt này (một vật phẩm miễn phí).
  final bool adCredit;
  final ValueChanged<BoosterId> onToggle;

  /// Neo cho chú thích giới thiệu lần đầu (bong bóng nằm ngoài thẻ).
  final LayerLink? link;

  static const tileWidth = 192.0;
  static const tileHeight = 74.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final state = AppScope.of(context).state;
    final row = Row(
      key: const ValueKey('level-ready-boosters'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in boosters) ...[
          if (b != boosters.first) const SizedBox(width: 10),
          _BoosterTile(
            booster: b,
            owned: state.boosterCount(b.id),
            selected: selected.contains(b.id),
            free: adFree == b.id,
            onTap: () => onToggle(b.id),
          ),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          adCredit && adFree == null ? l.lvlBoosterPickFree : l.lvlBoosterTitle,
          key: const ValueKey('level-ready-boosters-title'),
          style: styles.caption.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: adCredit && adFree == null ? SLColors.goodDeep : SLColors.inkSoft,
          ),
        ),
        const SizedBox(height: 8),
        if (link != null) CompositedTransformTarget(link: link!, child: row) else row,
      ],
    );
  }
}

class _BoosterTile extends StatelessWidget {
  const _BoosterTile({
    required this.booster,
    required this.owned,
    required this.selected,
    required this.free,
    required this.onTap,
  });

  final BoosterData booster;
  final int owned;
  final bool selected;
  final bool free;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final lang = levelLang(context);
    final name = booster.name(lang);
    final seed = 0xB010 + booster.id.index * 7;
    final Widget price;
    if (free) {
      price = Text(
        l.lvlBoosterFree,
        key: ValueKey('level-booster-free-${booster.id.name}'),
        style: styles.label.copyWith(fontSize: 15, color: SLColors.goodDeep),
      );
    } else if (owned > 0) {
      price = Text(
        '×${formatInt(context, owned)}',
        key: ValueKey('level-booster-owned-${booster.id.name}'),
        style: styles.number.copyWith(fontSize: 17, fontWeight: FontWeight.w900),
      );
    } else {
      price = Row(
        key: ValueKey('level-booster-price-${booster.id.name}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const GemIcon(size: 18),
          const SizedBox(width: 3),
          Text(
            formatInt(context, booster.gemPrice),
            style: styles.number.copyWith(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      );
    }
    return SLTooltip(
      message: '$name: ${booster.desc(lang)}',
      excludeFromSemantics: true,
      child: SLPressable(
        key: ValueKey('level-booster-${booster.id.name}'),
        onPressed: onTap,
        selected: selected,
        semanticLabel: selected ? l.lvlBoosterSelected(name) : name,
        builder: (context, press) => SizedBox(
          width: BoosterRow.tileWidth,
          height: BoosterRow.tileHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: SLSurface(
                  spec: SLSurfaceSpec(
                    shape: const SLRoundRect(14),
                    material: SLMaterial.wash,
                    color: selected ? SLColors.butter : SLColors.paper,
                    inkWidth: selected ? 2.6 : 1.8,
                    seed: seed,
                  ),
                  lift: selected ? 1 : 2.5,
                  press: press,
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  child: Row(
                    children: [
                      BoosterArt(booster: booster, size: 58),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styles.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w800, height: 1.05),
                            ),
                            const SizedBox(height: 2),
                            price,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  left: -8,
                  top: -8,
                  child: SLIconDisc('check', size: 28, color: SLColors.mint, iconScale: 0.66, seed: 0xB01F),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chú thích giới thiệu vật phẩm lần đầu (L4): bong bóng chữ đặt bên phải hàng vật phẩm.
class BoosterIntroBubble extends StatelessWidget {
  const BoosterIntroBubble({super.key, required this.link});

  final LayerLink link;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.centerRight,
      followerAnchor: Alignment.centerLeft,
      offset: const Offset(24, 0),
      child: IgnorePointer(
        child: SLBounceIn(
          child: SLSpeechBubble(
            key: const ValueKey('level-booster-intro'),
            tail: SLTail.left,
            tailAt: 0.5,
            maxWidth: 250,
            color: SLColors.butterLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            seed: 0xB0B0,
            child: Text(
              l.lvlBoosterIntro,
              style: SLTextStyles.of(context).body.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}
