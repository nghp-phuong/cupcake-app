import 'package:flutter/widgets.dart';

import '../../core/l10n_lookup.dart';
import '../../core/shift/shift_session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/format.dart';
import '../common/sugar_button.dart';
import '../sugarleaf/sugarleaf.dart';

/// Thẻ tổng kết ca (docs/v3/city-gd3-spec.md §5.7): tờ giấy dán băng dính, cỡ cố định [sizeFor] (đơn vị ref, lớp ca
/// co giãn bằng `FittedBox`). Trái: số liệu (khách, sao TB, doanh thu, tip + dòng buff "No bụng", nguyên liệu, tổng,
/// XP + thưởng hết ca); phải (chỉ khi lên cấp): "Lên cấp!" + "Mở mới". Dưới: x2 xu (quảng cáo) / "Đã nhân đôi", Xong.
class ShiftSummaryCard extends StatelessWidget {
  const ShiftSummaryCard({
    super.key,
    required this.summary,
    required this.canDouble,
    required this.onDouble,
    required this.onDone,
    this.busy = false,
  });

  final ShiftSummary summary;

  /// Hiện nút x2 (`ShiftSession.canDouble`).
  final bool canDouble;
  final VoidCallback onDouble;
  final VoidCallback onDone;

  /// Đang chờ quảng cáo: khoá các nút.
  final bool busy;

  static const _statsWidth = 440.0;
  static const _height = 520.0;

  /// Có cột "Lên cấp!" thì rộng 760, không thì 500.
  static Size sizeFor(ShiftSummary s) => Size(s.leveledUp ? 760 : 500, _height);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final s = summary;
    final doubled = s.doubledCoins > 0;
    return SizedBox.fromSize(
      size: sizeFor(s),
      child: SLPaperCard(
        attach: SLAttach.tapeCorners,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        seed: 0x5F1C,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SLIcon('confetti', size: 36),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l.shiftSummaryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.title.copyWith(fontSize: 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Số liệu: co lại (không tràn) nếu chữ dài.
                  SizedBox(
                    width: _statsWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: _statsWidth, child: _stats(context, l)),
                    ),
                  ),
                  if (s.leveledUp) ...[
                    const SizedBox(width: 20),
                    Expanded(child: _LevelUp(summary: s)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (doubled || canDouble) ...[
                  Expanded(
                    child: doubled
                        ? const _DoubledNote()
                        : SugarButton(
                            key: const ValueKey('shift-summary-double'),
                            label: l.summaryDouble,
                            iconId: 'play_video',
                            color: SLColors.mint,
                            height: 64,
                            fontSize: 18,
                            onPressed: busy ? null : onDouble,
                          ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: SugarButton(
                    key: const ValueKey('shift-summary-done'),
                    label: l.commonDone,
                    iconId: 'forward',
                    color: SLColors.strawberry,
                    height: 64,
                    fontSize: 24,
                    onPressed: busy ? null : onDone,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(BuildContext context, AppLocalizations l) {
    final s = summary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatRow(label: l.summaryCustomers, value: '${formatInt(context, s.served)}/${formatInt(context, s.total)}'),
        _StatRow(
          label: l.summaryAvgStars,
          value: formatDecimal1(context, s.averageStars),
          trailing: const StarIcon(size: 24),
        ),
        _StatRow(label: l.summaryRevenue, value: formatInt(context, s.revenue), coin: true),
        _StatRow(
          label: l.summaryTips,
          value: formatInt(context, s.tips),
          coin: true,
          note: s.buffTips > 0 ? l.shiftBuffTip(s.buffTips) : null,
        ),
        _StatRow(
          label: l.summaryCosts,
          value: formatSigned(context, -s.costs),
          coin: true,
          valueColor: SLColors.badDeep,
        ),
        // Nét kẻ bút chì trước dòng tổng.
        const SLRule(thickness: 2.2, echo: SLRuleEcho.partial, seed: 0x707B),
        _StatRow(label: l.summaryNet, value: formatInt(context, s.totalCoins), coin: true, big: true),
        _StatRow(
          label: l.summaryXp,
          value: formatInt(context, s.xp),
          note: s.bonusXp > 0 ? l.summaryDayBonusXp(s.bonusXp) : null,
          trailing: const SLIcon('sparkle', size: 24),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.coin = false,
    this.big = false,
    this.trailing,
    this.note,
    this.valueColor = SLColors.ink,
  });

  final String label;
  final String value;
  final bool coin;
  final bool big;
  final Widget? trailing;
  final String? note;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    final size = big ? 24.0 : 19.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: big
                      ? styles.title.copyWith(fontSize: size)
                      : styles.body.copyWith(fontSize: size, fontWeight: FontWeight.w700),
                ),
                if (note != null)
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.caption.copyWith(fontWeight: FontWeight.w700, color: SLColors.inkSoft),
                  ),
              ],
            ),
          ),
          if (coin) ...[CoinIcon(size: size * 1.2), const SizedBox(width: 6)],
          Text(
            value,
            style: styles.number.copyWith(fontSize: size, fontWeight: FontWeight.w900, color: valueColor),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// Lên cấp: tờ giấy vàng bơ, cúp + lấp lánh; "Mở mới" là các nhãn giấy (món, topping, thêm khách, khách VIP).
class _LevelUp extends StatelessWidget {
  const _LevelUp({required this.summary});

  final ShiftSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final s = summary;
    final unlocks = [
      for (final r in s.newRecipes) l.unlockRecipe(l.recipeName(r)),
      for (final t in s.newToppings) l.unlockTopping(l.toppingName(t)),
      if (s.moreCustomers) l.unlockMoreCustomers,
      if (s.vipGuests) l.unlockVipGuests,
    ];
    return SLBounceIn(
      delay: const Duration(milliseconds: 200),
      child: SLPaperCard(
        color: SLColors.butterLight,
        attach: SLAttach.tape,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        seed: 0x1E7F,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SLIcon('trophy', size: 34),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.summaryLevelUp(s.levelAfter),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.title.copyWith(fontSize: 21, height: 1.15),
                  ),
                ),
                const SizedBox(width: 4),
                const SLSparkle(size: 24),
              ],
            ),
            if (unlocks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l.summaryNewUnlocks,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.caption.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [for (final u in unlocks) SLChip(label: u, selected: true, color: SLColors.paper)],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Đã nhân đôi xu!": nhãn dán bạc hà có dấu tích (thay chỗ nút x2).
class _DoubledNote extends StatelessWidget {
  const _DoubledNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 64,
      child: SLSurface(
        spec: const SLSurfaceSpec(
          shape: SLRoundRect(18),
          material: SLMaterial.wash,
          color: SLColors.mint,
          sticker: true,
          seed: 0xD0B2,
        ),
        lift: 2,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SLIcon('check', size: 28),
                const SizedBox(width: 8),
                Text(l.summaryDoubled, style: SLTextStyles.of(context).label.copyWith(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
