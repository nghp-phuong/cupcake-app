import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/customer_art.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/day_summary.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../day/mochi_visit.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/navigation.dart';
import '../common/panel.dart';
import '../common/star_row.dart';
import '../common/sugar_button.dart';
import '../sugarleaf/sugarleaf.dart';

/// Tổng kết ngày: danh sách đơn (trái), số liệu (phải), băng lên cấp + mở khoá, nhân đôi xu (rewarded),
/// "Tiếp tục" → interstitial (nếu đúng luật) → menu.
class DaySummaryScreen extends StatefulWidget {
  const DaySummaryScreen({super.key, required this.summary});

  final DaySummary summary;

  @override
  State<DaySummaryScreen> createState() => _DaySummaryScreenState();
}

class _DaySummaryScreenState extends State<DaySummaryScreen> {
  bool _doubled = false;
  bool _busy = false;

  DaySummary get _s => widget.summary;

  @override
  void initState() {
    super.initState();
    // Ảnh mặt Mochi cho dòng "ngày mưa" (thường đã có trong cache từ màn ngày).
    if (_s.isRainy) unawaited(CustomerArt.preloadMochi());
  }

  Future<void> _double() async {
    if (_busy || _doubled || _s.net <= 0) return;
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    var watched = false;
    try {
      watched = await services.ads.showRewarded(context, AdPlacement.doubleCoins);
    } catch (e) {
      debugPrint('DaySummaryScreen: quảng cáo nhân đôi lỗi ($e)');
    }
    if (!mounted) return;
    if (watched) {
      services.state.addCoins(_s.net);
      services.audio.success();
      showToast(context, l.summaryDoubled);
    } else {
      showToast(context, l.adsLimitReached, success: false);
    }
    setState(() {
      _busy = false;
      _doubled = watched;
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ads = AppScope.read(context).ads;
    try {
      if (ads.shouldShowInterstitial(_s.dayNumber)) await ads.showInterstitial(context, _s.dayNumber);
    } catch (e) {
      // Quảng cáo lỗi không được giữ người chơi ở lại màn tổng kết.
      debugPrint('DaySummaryScreen: interstitial lỗi ($e)');
    } finally {
      // `_busy` giữ nguyên: màn này sắp bị bỏ, chặn bấm lần hai.
      if (mounted) goToMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final canDouble = _s.net > 0 && !_doubled && services.ads.canShowRewarded();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continue();
      },
      // Khung không Material: nền kem + SLScope (chữ mực nâu, font nội dung). Toast/quảng cáo giả lập đi qua Overlay.
      child: ColoredBox(
        color: SLColors.cream,
        child: SLScope(
          child: Stack(
            children: [
              // Bếp lúc đóng cửa (vẽ tay) phủ lớp kem mờ cho chữ dễ đọc; chưa có ảnh → tờ giấy kem vẽ tay.
              const Positioned.fill(
                child: RepaintBoundary(
                  child: SceneBackdrop(scene: ArtScene.daySummary, fallback: _PaperBackdrop(), tint: Color(0x40FFF4E6)),
                ),
              ),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: SLNameTag(
                    l.summaryTitle(_s.dayNumber),
                    icon: 'confetti',
                    color: SLColors.butter,
                    height: 72,
                    fontSize: 36,
                    maxWidth: 560,
                    seed: 0x5A11,
                  ),
                ),
              ),
              // Ngày mưa: nhãn nhỏ góc trái, ngang hàng băng tiêu đề (tiêu đề ở giữa rộng tối đa ~560px).
              if (_s.isRainy)
                Positioned(
                  left: 32,
                  top: 28,
                  child: _RainyDayNote(text: l.summaryRainyDay),
                ),
              // Trái: danh sách đơn — các mẩu giấy trên một tờ giấy lớn.
              Positioned(
                left: 32,
                top: 108,
                width: 500,
                bottom: 24,
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: _s.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _OrderRow(record: _s.records[i], index: i),
                  ),
                ),
              ),
              // Phải: số liệu + lên cấp + nút.
              Positioned(
                left: 560,
                top: 108,
                right: 32,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Panel(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: Column(
                        children: [
                          _StatRow(label: l.summaryCustomers, value: formatInt(context, _s.records.length)),
                          _StatRow(
                            label: l.summaryAvgStars,
                            value: formatDecimal1(context, _s.averageStars),
                            trailing: const StarIcon(size: 26),
                          ),
                          _StatRow(label: l.summaryRevenue, value: formatInt(context, _s.revenue), coin: true),
                          _StatRow(label: l.summaryTips, value: formatInt(context, _s.tips), coin: true),
                          _StatRow(
                            label: l.summaryCosts,
                            value: formatSigned(context, -_s.costs),
                            coin: true,
                            valueColor: SLColors.badDeep,
                          ),
                          // Nét kẻ bút chì trước dòng tổng.
                          const SLRule(thickness: 2.2, echo: SLRuleEcho.partial, seed: 0x707A),
                          _StatRow(
                            label: l.summaryNet,
                            value: formatInt(context, _doubled ? _s.net * 2 : _s.net),
                            coin: true,
                            big: true,
                          ),
                          _StatRow(
                            label: l.summaryXp,
                            value: formatInt(context, _s.xpGained),
                            note: l.summaryDayBonusXp(_s.dayBonusXp),
                            trailing: const SLIcon('sparkle', size: 26),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _s.leveledUp ? _LevelUpBanner(summary: _s) : const SizedBox.shrink()),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _doubled
                              ? const _DoubledNote()
                              : SugarButton(
                                  label: l.summaryDouble,
                                  iconId: 'play_video',
                                  color: SLColors.mint,
                                  height: 64,
                                  onPressed: canDouble && !_busy ? _double : null,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SugarButton(
                            label: l.commonContinue,
                            iconId: 'forward',
                            color: SLColors.strawberry,
                            height: 64,
                            fontSize: 24,
                            onPressed: _busy ? null : _continue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nền dự phòng khi chưa có ảnh bếp: một tờ giấy kem vẽ tay phủ kín (vân giấy, mép ngả nâu, không viền mực).
class _PaperBackdrop extends StatelessWidget {
  const _PaperBackdrop();

  @override
  Widget build(BuildContext context) => const SLSurface(
        spec: SLSurfaceSpec(shape: SLRoundRect(0), color: SLColors.cream, outline: false, seed: 0x5B6D),
      );
}

/// "Đã nhân đôi xu!": nhãn dán bạc hà có dấu tích (thay chỗ nút nhân đôi).
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
          seed: 0xD0B1,
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

/// "Ngày mưa — Mochi ghé chơi": mẩu giấy xanh mưa dán băng dính, mặt Mochi trong khung tròn vẽ tay.
class _RainyDayNote extends StatelessWidget {
  const _RainyDayNote({required this.text});

  final String text;

  static const _ring = 46.0;
  static const _face = 40.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 350, minHeight: 52),
      child: SLPaperCard(
        attach: SLAttach.tape,
        color: const Color(0xFFE3EDF3),
        radius: 18,
        tilt: -0.015,
        padding: const EdgeInsets.fromLTRB(4, 3, 14, 3),
        seed: 0x3A1D,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phóng ảnh để đầu Mochi (≈ 46% bề ngang, tâm ở ~34% chiều cao ảnh) lấp đầy vòng tròn.
            SizedBox.square(
              dimension: _ring,
              child: SLSurface(
                spec: const SLSurfaceSpec(shape: SLCircle(), color: SLColors.cream, inkWidth: 1.8, seed: 0x3A1E),
                padding: const EdgeInsets.all((_ring - _face) / 2),
                child: SLHandClip(
                  seed: 0x3A1F,
                  amplitude: 0.7,
                  child: ArtCanvas(
                    repaintKey: 'mochi-face',
                    repaint: CustomerArt.repaint,
                    paint: (c, s) {
                      const w = _face * 2.2;
                      paintMochiFace(c, Rect.fromLTWH(_face / 2 - w / 2, _face / 2 - w / 0.75 * 0.34, w, w / 0.75), MochiFace.joy);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SLIcon('raindrop', size: 20),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTextStyles.of(context).caption.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một đơn trong ngày: mẩu giấy nhỏ (xen kẽ giấy ngà / kem, nghiêng rất nhẹ so le).
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.record, required this.index});

  final OrderRecord record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final r = record.result;
    return SizedBox(
      height: 76,
      child: SLPaperCard(
        color: index.isEven ? SLColors.paper : SLColors.cream,
        radius: 10,
        tilt: index.isEven ? -0.004 : 0.004,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        seed: 0x0A0 + index,
        child: Row(
          children: [
            CakeImage(visual: CakeVisual.order(record.order), recipe: record.order.recipe, size: 62),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.recipeName(record.order.recipe),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.label.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l.customerName(record.customer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.caption.copyWith(color: SLColors.inkSoft),
                  ),
                ],
              ),
            ),
            StarRow(stars: r.stars, size: 22, spacing: 1),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CoinIcon(size: 20),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      formatSigned(context, r.net),
                      maxLines: 1,
                      style: styles.number.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: r.net < 0 ? SLColors.badDeep : SLColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  style: big
                      ? styles.title.copyWith(fontSize: size)
                      : styles.body.copyWith(fontSize: size, fontWeight: FontWeight.w700),
                ),
                if (note != null)
                  Text(
                    note!,
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

/// Lên cấp: tờ giấy vàng bơ dán băng dính hai góc, cúp + lấp lánh (một lần), các mở khoá là nhãn giấy.
class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return SLBounceIn(
      delay: const Duration(milliseconds: 200),
      child: SLPaperCard(
        color: SLColors.butterLight,
        attach: SLAttach.tapeCorners,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        seed: 0x1E7E,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SLIcon('trophy', size: 36),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l.summaryLevelUp(summary.levelAfter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.title.copyWith(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 6),
                const SLSparkle(size: 26),
              ],
            ),
            if (summary.unlocks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l.summaryNewUnlocks,
                style: styles.caption.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final u in summary.unlocks) SLChip(label: l.unlockText(u), selected: true, color: SLColors.paper),
                    ],
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
