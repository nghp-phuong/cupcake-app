import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/game_state.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/sugar_screen.dart';
import '../level/booster_row.dart';
import '../level/level_common.dart';
import '../sugarleaf/sugarleaf.dart';

/// Ảnh thẻ mùa (nút bản đồ, cửa hàng, màn Thẻ mùa).
const kSeasonTicketAsset = 'assets/art/items/season_ticket.webp';

/// Có thưởng thẻ mùa chờ nhận (chấm đỏ trên nút bản đồ) hoặc thông báo hết mùa chưa xem.
bool seasonHasPending(GameState state) => state.seasonClaimable.isNotEmpty || state.seasonAutoClaim != null;

/// Màn Thẻ mùa: đầu trang (tên mùa, đồng hồ còn lại, tiến độ tới bậc kế, cách kiếm điểm, nút mua cao cấp), thanh bậc
/// cuộn ngang với hai hàng thưởng Miễn phí / Cao cấp (chạm "Nhận" từng ô), nút "Nhận tất cả". Không có mùa → lời
/// báo. Mùa vừa kết thúc → hộp thoại "đã tự nhận" (một lần). Đồng hồ tự cập nhật mỗi 30 giây.
class SeasonPassScreen extends StatefulWidget {
  const SeasonPassScreen({super.key});

  /// Bề ngang một cột bậc.
  static const tierWidth = 128.0;

  @override
  State<SeasonPassScreen> createState() => _SeasonPassScreenState();
}

class _SeasonPassScreenState extends State<SeasonPassScreen> {
  Timer? _tick;
  ScrollController? _scroll;
  bool _buying = false;

  /// Hộp xác nhận mua đang mở (khoá ngay khi chạm, trước `await`).
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppScope.read(context).state.seasonAutoClaim != null) unawaited(showSeasonEndedDialog(context));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scroll != null) return;
    // Mở ở bậc đang tới (bậc đã đạt cuối cùng nằm gần mép trái).
    final tier = AppScope.read(context).state.seasonTier;
    _scroll = ScrollController(initialScrollOffset: ((tier - 2).clamp(0, 999)) * SeasonPassScreen.tierWidth);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll?.dispose();
    super.dispose();
  }

  void _claim(int tier, {required bool premium}) {
    final services = AppScope.read(context);
    if (!services.state.claimSeason(tier, premium: premium)) return;
    services.audio.success();
    showToast(context, AppLocalizations.of(context).seasonClaimedToast(1));
  }

  void _claimAll() {
    final services = AppScope.read(context);
    final n = services.state.claimAllSeason();
    if (n <= 0) return;
    services.audio.success();
    showToast(context, AppLocalizations.of(context).seasonClaimedToast(n));
  }

  Future<void> _buyPremium() async {
    if (_buying || _confirming) return;
    final l = AppLocalizations.of(context);
    final services = AppScope.read(context);
    final product = services.state.monetizationConfig.product(IapProductId.seasonPass);
    // Khoá trước khi mở hộp xác nhận: hai chạm cùng khung hình không mở hai hộp chồng nhau (UI-03).
    _confirming = true;
    bool ok;
    try {
      ok = await showConfirmDialog(
        context,
        title: l.storeConfirmTitle,
        body: l.storeConfirmBody(l.iapName(product.id, fallback: product.name(levelLang(context))), product.displayPrice),
        confirmLabel: l.commonBuy,
        titleColor: SLColors.butter,
        illustration: const _TicketArt(size: 96),
      );
    } finally {
      _confirming = false;
    }
    if (!ok || !mounted) return;
    setState(() => _buying = true);
    final bought = await services.iap.buy(IapProductId.seasonPass);
    if (!mounted) return;
    setState(() => _buying = false);
    if (bought) {
      services.audio.success();
      showToast(context, l.storePurchaseSuccess);
    } else {
      services.audio.fail();
      showToast(context, l.storePurchaseFailed, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final state = services.state;
    final season = state.activeSeason;
    return SugarScreen(
      title: l.seasonTitle,
      titleIconId: 'ticket',
      body: season == null
          ? Center(
              child: SLPaperCard(
                key: const ValueKey('season-none'),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                seed: 0x5EA0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TicketArt(size: 120),
                    const SizedBox(height: 12),
                    Text(l.seasonNone, style: SLTextStyles.of(context).title.copyWith(fontSize: 24)),
                  ],
                ),
              ),
            )
          : _body(context, state, season),
    );
  }

  Widget _body(BuildContext context, GameState state, SeasonData season) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final product = state.monetizationConfig.product(IapProductId.seasonPass);
    final premium = state.seasonPremium;
    // Số ô (bậc × hàng) đang chờ nhận.
    var claimable = 0;
    for (final t in state.seasonClaimable) {
      if (state.seasonCanClaim(t, premium: false)) claimable++;
      if (state.seasonCanClaim(t, premium: true)) claimable++;
    }
    final tier = state.seasonTier;
    final points = state.seasonPoints;
    final next = season.tier(tier + 1);
    final prevPoints = tier == 0 ? 0 : season.tier(tier)!.points;
    return Stack(
      children: [
        // ---- Đầu trang: vé + tên mùa + đồng hồ | tiến độ | mua cao cấp.
        Positioned(
          left: 24,
          right: 24,
          top: 8,
          height: 104,
          child: SLPaperCard(
            radius: 22,
            seed: 0x5EA1,
            padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
            child: Row(
              children: [
                const _TicketArt(size: 84),
                const SizedBox(width: 10),
                SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.name(levelLang(context)).isEmpty ? l.seasonTitle : season.name(levelLang(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.heading.copyWith(fontSize: 26, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SLIcon('clock', size: 24),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l.seasonTimeLeft(_timeLeft(l, state.seasonTimeLeft ?? Duration.zero)),
                              key: const ValueKey('season-time-left'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.label.copyWith(fontSize: 18, color: SLColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SLBadge.label(l.seasonTierLabel(tier), color: SLColors.butter),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              next == null ? l.seasonPointsMax(points) : l.seasonPoints(points, next.points),
                              key: const ValueKey('season-points'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.number.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SLProgressBar(
                        value: next == null
                            ? 1
                            : ((points - prevPoints) / (next.points - prevPoints).clamp(1, 1 << 30)).clamp(0.0, 1.0),
                        height: 18,
                        color: SLColors.butter,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.seasonHowTo(season.pointsPerNewStar, season.pointsPerWin),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SLColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (premium)
                  SLChip(
                    key: const ValueKey('season-premium-active'),
                    label: l.seasonPremiumActive,
                    icon: 'check',
                    selected: true,
                    color: SLColors.mint,
                  )
                else
                  SLButton(
                    key: const ValueKey('season-buy-premium'),
                    label: l.seasonBuyPremium(product.displayPrice),
                    icon: 'vip',
                    color: SLColors.strawberry,
                    width: 260,
                    height: 60,
                    fontSize: 19,
                    loading: _buying,
                    onPressed: _buying ? null : _buyPremium,
                  ),
              ],
            ),
          ),
        ),
        // ---- Thanh bậc cuộn ngang: nhãn hai hàng cố định bên trái.
        Positioned(
          left: 24,
          top: 124,
          width: 132,
          bottom: 92,
          child: Column(
            children: [
              const SizedBox(height: _TierColumn.headHeight),
              Expanded(
                child: Center(
                  child: _RowLabel(label: l.seasonFreeRow, color: SLColors.mintLight, icon: 'gift'),
                ),
              ),
              Expanded(
                child: Center(
                  child: _RowLabel(label: l.seasonPremiumRow, color: SLColors.butterLight, icon: 'vip'),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 164,
          right: 16,
          top: 124,
          bottom: 92,
          child: ListView.builder(
            key: const ValueKey('season-track'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemExtent: SeasonPassScreen.tierWidth,
            itemCount: season.tiers.length,
            itemBuilder: (context, i) {
              final t = i + 1;
              final data = season.tiers[i];
              final reached = tier >= t;
              _CellState cell(bool isPremium) {
                if (!reached) return _CellState.locked;
                if (isPremium && !premium) return _CellState.needPremium;
                return state.seasonCanClaim(t, premium: isPremium) ? _CellState.claimable : _CellState.claimed;
              }

              return _TierColumn(
                tier: t,
                points: data.points,
                reached: reached,
                current: t == tier + 1,
                free: data.free,
                premium: data.premium,
                freeState: cell(false),
                premiumState: cell(true),
                onClaim: (isPremium) => _claim(t, premium: isPremium),
              );
            },
          ),
        ),
        // ---- Nhận tất cả.
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SLButton(
                  key: const ValueKey('season-claim-all'),
                  label: l.seasonClaimAll,
                  icon: 'gift',
                  color: SLColors.strawberry,
                  width: 300,
                  height: 64,
                  fontSize: 24,
                  onPressed: claimable == 0 ? null : _claimAll,
                ),
                if (claimable > 0) Positioned(right: -6, top: -8, child: SLBadge.count(claimable)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Thời gian còn lại dạng "12 ngày 4 giờ" / "5 giờ 20 phút".
String _timeLeft(AppLocalizations l, Duration d) {
  if (d.inDays >= 1) return l.seasonDaysHours(d.inDays, d.inHours % 24);
  return l.seasonHoursMinutes(d.inHours, d.inMinutes % 60);
}

enum _CellState { locked, needPremium, claimable, claimed }

/// Ảnh vé thẻ mùa; thiếu → icon vé vẽ tay.
class _TicketArt extends StatelessWidget {
  const _TicketArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => AssetArt(
    kSeasonTicketAsset,
    width: size,
    fallback: SLArtIcon(ArtSprites.ticket, 'ticket', size: size * 0.8),
  );
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) => SLSurface(
    spec: SLSurfaceSpec(shape: const SLRoundRect(16), material: SLMaterial.wash, color: color, seed: slSeed(content: label, salt: 0x5EA9)),
    lift: 2,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SLIcon(icon, size: 34),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, style: SLTextStyles.of(context).label.copyWith(fontSize: 19)),
        ),
      ],
    ),
  );
}

/// Một cột bậc: số bậc trên vòng tròn (đạt = vàng bơ) + điểm cần, ô thưởng miễn phí, ô thưởng cao cấp.
class _TierColumn extends StatelessWidget {
  const _TierColumn({
    required this.tier,
    required this.points,
    required this.reached,
    required this.current,
    required this.free,
    required this.premium,
    required this.freeState,
    required this.premiumState,
    required this.onClaim,
  });

  final int tier;
  final int points;
  final bool reached;

  /// Bậc đang tới (viền nhấn).
  final bool current;
  final Reward free;
  final Reward premium;
  final _CellState freeState;
  final _CellState premiumState;
  final ValueChanged<bool> onClaim;

  static const headHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          SizedBox(
            height: headHeight,
            child: Semantics(
              label: l.seasonTierLabel(tier),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: SLSurface(
                        spec: SLSurfaceSpec(
                          shape: const SLCircle(),
                          material: SLMaterial.wash,
                          color: reached ? SLColors.butter : (current ? SLColors.strawberryLight : SLColors.paper),
                          inkWidth: current ? 2.6 : 1.8,
                          seed: 0x5EB0 + tier,
                        ),
                        child: Center(
                          child: Text(
                            formatInt(context, tier),
                            style: styles.number.copyWith(fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatInt(context, points),
                      style: styles.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SLColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _RewardCell(
              key: ValueKey('season-cell-$tier-free'),
              reward: free,
              state: freeState,
              color: SLColors.mintLight,
              seed: 0x5EC0 + tier * 2,
              onClaim: () => onClaim(false),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _RewardCell(
              key: ValueKey('season-cell-$tier-premium'),
              reward: premium,
              state: premiumState,
              color: SLColors.butterLight,
              seed: 0x5EC1 + tier * 2,
              onClaim: () => onClaim(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô thưởng: mọi dòng thưởng (xu / kim cương / vật phẩm / khung chân dung) + chân ô theo trạng thái — "Nhận" (chờ
/// nhận), dấu ✓ (đã nhận), khoá (chưa đạt bậc / cần cao cấp).
class _RewardCell extends StatelessWidget {
  const _RewardCell({
    super.key,
    required this.reward,
    required this.state,
    required this.color,
    required this.seed,
    required this.onClaim,
  });

  final Reward reward;
  final _CellState state;
  final Color color;
  final int seed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final services = AppScope.of(context);
    final lang = levelLang(context);
    final number = styles.number.copyWith(fontSize: 17, fontWeight: FontWeight.w900);
    final lines = <(Widget, String, String)>[
      if (reward.coins > 0)
        (const CoinIcon(size: 30), '+${formatInt(context, reward.coins)}', l.commonCoins(reward.coins)),
      if (reward.gems > 0) (const GemIcon(size: 30), '+${formatInt(context, reward.gems)}', l.commonGems(reward.gems)),
      for (final e in reward.boosters.entries)
        if (e.value > 0)
          (
            BoosterArt(booster: services.state.boosterData(e.key), size: 36),
            '×${formatInt(context, e.value)}',
            l.seasonRewardBooster(services.state.boosterData(e.key).name(lang), e.value),
          ),
      if (reward.frame != null) (const SLIcon('decor_chair', size: 30), '', l.seasonRewardFrame),
    ];
    final dim = state == _CellState.locked || state == _CellState.claimed;
    final Widget foot = switch (state) {
      _CellState.claimable => SLButton(
        label: l.commonClaim,
        color: SLColors.strawberry,
        height: 44,
        fontSize: 17,
        onPressed: onClaim,
      ),
      _CellState.claimed => const SLIconDisc('check', size: 34, color: SLColors.mint, iconScale: 0.66, seed: 0x5ED0),
      _CellState.needPremium => SLTooltip(
        message: l.seasonPremiumHint,
        child: const SLIcon('lock', size: 28, color: SLColors.inkSoft),
      ),
      _CellState.locked => const SLIcon('lock', size: 26, color: SLColors.disabledInk),
    };
    final tooltip = lines.map((e) => e.$3).join(' · ');
    return Semantics(
      label: tooltip,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(14),
          material: SLMaterial.wash,
          color: state == _CellState.claimable ? color : (dim ? SLColors.paperShade : SLColors.paper),
          inkWidth: state == _CellState.claimable ? 2.4 : 1.6,
          seed: seed,
        ),
        lift: state == _CellState.claimable ? 3 : 1,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Opacity(
          opacity: dim ? 0.6 : 1,
          child: Column(
            children: [
              Expanded(
                child: reward.isEmpty
                    ? const SizedBox.shrink()
                    : SLTooltip(
                        message: tooltip,
                        excludeFromSemantics: true,
                        // Mọi thưởng của ô (tới 3–4 dòng ở bậc cao): cả khối co lại cho vừa ô, không bỏ dòng nào.
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (icon, text, _) in lines)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        icon,
                                        if (text.isNotEmpty) ...[const SizedBox(width: 3), Text(text, style: number)],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 44, child: Center(child: foot)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mùa vừa kết thúc: hộp thoại "thưởng chưa nhận đã được tự động cộng" (kèm tổng xu / kim cương), rồi
/// `ackSeasonAutoClaim` (chỉ hiện một lần).
Future<void> showSeasonEndedDialog(BuildContext context) async {
  final state = AppScope.read(context).state;
  final claim = state.seasonAutoClaim;
  if (claim == null) return;
  final l = AppLocalizations.of(context);
  AppScope.read(context).audio.success();
  await showSLDialog<void>(
    context,
    builder: (ctx) {
      final number = SLTextStyles.of(ctx).number.copyWith(fontSize: 24, fontWeight: FontWeight.w900);
      return SLDialog(
        key: const ValueKey('season-ended'),
        title: l.seasonTitle,
        titleIcon: 'ticket',
        titleColor: SLColors.butter,
        width: 620,
        actions: [
          SLButton(
            label: l.commonOk,
            icon: 'check',
            color: SLColors.strawberry,
            width: 220,
            height: 64,
            fontSize: 24,
            onPressed: () => popDialogOnce(ctx),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TicketArt(size: 104),
            const SizedBox(height: 10),
            Text(l.seasonEnded, textAlign: TextAlign.center),
            if (claim.coins > 0 || claim.gems > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (claim.coins > 0) ...[
                    const CoinIcon(size: 36),
                    const SizedBox(width: 6),
                    Text('+${formatInt(ctx, claim.coins)}', style: number),
                    const SizedBox(width: 24),
                  ],
                  if (claim.gems > 0) ...[
                    const GemIcon(size: 36),
                    const SizedBox(width: 6),
                    Text('+${formatInt(ctx, claim.gems)}', style: number),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
  state.ackSeasonAutoClaim();
}
