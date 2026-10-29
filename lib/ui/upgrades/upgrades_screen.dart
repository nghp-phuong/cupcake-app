import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/economy.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/sugar_button.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';
import 'tool_art.dart';

/// Nâng cấp: 4 thẻ giấy ngang — lò nướng, phới lồng, túi bắt kem, kẹp gắp.
class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SugarScreen(
      title: l.upgradesTitle,
      titleIconId: 'oven',
      titleArt: ArtSprites.oven(1),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _UpgradeCard(tool: null)),
            for (final t in ToolId.values) ...[const SizedBox(width: 20), Expanded(child: _UpgradeCard(tool: t))],
          ],
        ),
      ),
    );
  }
}

/// Thẻ giấy một món nâng cấp: mảng màu nước có hình + tên, nét bút chì, mô tả, cấp, nhãn giá, nút.
/// [tool] null = lò nướng.
class _UpgradeCard extends StatefulWidget {
  const _UpgradeCard({required this.tool});

  final ToolId? tool;

  @override
  State<_UpgradeCard> createState() => _UpgradeCardState();
}

class _UpgradeCardState extends State<_UpgradeCard> {
  /// Tăng mỗi lần mua hụt tiền → nhãn giá lắc.
  int _shortTries = 0;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final state = services.state;

    final oven = tool == null;
    final level = oven ? state.ovenLevel : state.toolLevel(tool);
    final maxLevel = oven ? Economy.maxOvenLevel : Economy.maxToolLevel(tool);
    final maxed = level >= maxLevel;
    int? cost;
    int? requiredLevel;
    if (!maxed) {
      if (oven) {
        final next = Economy.ovenTiers[level];
        cost = next.cost;
        requiredLevel = next.requiredShopLevel;
      } else {
        final next = Economy.toolTiers[tool]![level];
        cost = next.cost;
        requiredLevel = next.requiredShopLevel;
      }
    }
    final locked = requiredLevel != null && state.level < requiredLevel;

    final name = oven ? l.upgradeOven : l.toolName(tool);
    final desc = oven ? l.upgradeOvenDesc : l.toolDesc(tool);
    final accent = switch (tool) {
      null => const Color(0xFFFFE0D6),
      ToolId.whisk => SLColors.mintLight,
      ToolId.pipingBag => SLColors.strawberryLight,
      ToolId.tongs => SLColors.butterLight,
    };
    final seed = 0x0A71 + (tool?.index ?? -1) * 31;

    void buy() {
      final result = oven ? state.buyOvenUpgrade() : state.buyToolUpgrade(tool);
      switch (result) {
        case PurchaseResult.ok:
          services.audio.success();
          showToast(context, l.upgradeDone);
        case PurchaseResult.notEnoughCoins:
          services.audio.fail();
          setState(() => _shortTries++);
          showToast(context, l.commonNotEnoughCoins, success: false);
        case PurchaseResult.notEnoughGems:
          setState(() => _shortTries++);
          showToast(context, l.commonNotEnoughGems, success: false);
        case PurchaseResult.locked:
        case PurchaseResult.maxed:
        case PurchaseResult.alreadyOwned:
          break;
      }
    }

    final styles = SLTextStyles.of(context);
    return SLPaperCard(
      seed: seed,
      radius: 22,
      tilt: (tool?.index ?? -1).isEven ? 0.006 : -0.006,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hình + tên trên mảng màu nước.
          Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: SLSurface(
                  spec: SLSurfaceSpec(
                    shape: const SLRoundRect(16),
                    material: SLMaterial.wash,
                    color: accent,
                    inkWidth: 1.6,
                    seed: seed + 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  children: [
                    ArtImage(
                      ToolArt.art(tool, level: level),
                      size: 140,
                      fallback: (c, s) => ToolArt.paint(c, Offset.zero & s, tool, level: level),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: styles.heading.copyWith(fontSize: 26),
                    ),
                  ],
                ),
              ),
              if (maxed)
                Positioned(
                  right: -6,
                  top: -8,
                  child: Transform.rotate(
                    angle: 0.18,
                    child: const Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SLIconDisc('medal_max', size: 60, color: SLColors.butterLight, iconScale: 0.74, lift: 2, seed: 0x3EDA),
                        Positioned(right: -6, top: -4, child: SLSparkle(size: 20)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SLRule(color: SLColors.caramel.withValues(alpha: 0.75), amplitude: 1.6, inset: 6, rise: 1, seed: seed),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.body.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.upgradeLevelOf(level, maxLevel),
                    textAlign: TextAlign.center,
                    style: styles.label.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  _LevelPips(level: level, max: maxLevel),
                  if (oven) ...[const SizedBox(height: 10), _OvenZone(level: level)],
                  const Spacer(),
                  if (cost != null && !locked)
                    Center(
                      child: SLShake(
                        trigger: _shortTries,
                        child: _PriceLabel(amount: cost, affordable: state.coins >= cost, seed: seed + 2),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (maxed)
                    _MaxedBadge(label: l.upgradeMaxed, seed: seed + 3)
                  else
                    SugarButton(
                      label: locked ? l.commonUnlockAtLevel(requiredLevel) : l.upgradeBuy,
                      iconId: locked ? 'lock' : 'arrow_up',
                      color: SLColors.strawberry,
                      height: 58,
                      fontSize: 19,
                      onPressed: locked ? null : buy,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chấm cấp vẽ tay: viên màu nước xanh (đã đạt) / giấy cũ (chưa). Chấm vừa đạt nảy vào.
class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level, required this.max});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= max; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: i <= level
                  ? SLBounceIn(key: ValueKey('pip$i-on'), child: _pip(i, true))
                  : KeyedSubtree(key: ValueKey('pip$i-off'), child: _pip(i, false)),
            ),
        ],
      ),
    );
  }

  Widget _pip(int i, bool on) => SizedBox(
        width: 30,
        height: 16,
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: const SLRoundRect(8),
            material: SLMaterial.wash,
            color: on ? SLColors.good : SLColors.paperShade,
            inkWidth: on ? 2 : 1.6,
            seed: 0x919 + i,
          ),
        ),
      );
}

/// Nhãn giá treo (giấy vàng bơ có lỗ xỏ dây); thiếu tiền → giấy hồng, số đỏ đậm.
class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.amount, required this.affordable, required this.seed});

  final int amount;
  final bool affordable;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(12),
          material: SLMaterial.wash,
          color: affordable ? SLColors.butterLight : SLColors.strawberryLight,
          inkWidth: 1.8,
          seed: seed,
        ),
        lift: 2.5,
        padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lỗ xỏ dây của nhãn.
            const SizedBox.square(
              dimension: 10,
              child: SLSurface(spec: SLSurfaceSpec(shape: SLCircle(), color: SLColors.cream, inkWidth: 1.4, seed: 5)),
            ),
            const SizedBox(width: 8),
            PriceTag(amount: amount, affordable: affordable, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Huy hiệu "đã nâng cấp tối đa" (thay cho nút): dải màu nước vàng bơ + huân chương.
class _MaxedBadge extends StatelessWidget {
  const _MaxedBadge({required this.label, required this.seed});

  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(18),
          material: SLMaterial.wash,
          color: SLColors.butter,
          sticker: true,
          seed: seed,
        ),
        lift: 2,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SLIcon('medal_max', size: 28),
                const SizedBox(width: 8),
                Text(label, maxLines: 1, style: SLTextStyles.of(context).label.copyWith(fontSize: 19)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vùng hoàn hảo của lò hiện tại → cấp kế (mẩu giấy ghi chú màu nước vàng).
class _OvenZone extends StatelessWidget {
  const _OvenZone({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    int pct(int lv) => (Economy.ovenTiers[lv - 1].perfectHalfWidth * 100).round();
    final hasNext = level < Economy.maxOvenLevel;
    return RepaintBoundary(
      child: SLSurface(
        spec: const SLSurfaceSpec(
          shape: SLRoundRect(14),
          material: SLMaterial.wash,
          color: SLColors.butterLight,
          inkWidth: 1.8,
          seed: 0x0E7A,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Text(
              l.upgradeOvenPerfectZone(pct(level)),
              textAlign: TextAlign.center,
              style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (hasNext)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SLIcon('arrow_down', size: 18, color: SLColors.goodDeep),
                  const SizedBox(width: 2),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.upgradeOvenPerfectZone(pct(level + 1)),
                        style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: SLColors.goodDeep),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
