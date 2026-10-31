import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/navigation.dart';
import '../common/star_row.dart';
import '../sugarleaf/sugarleaf.dart';
import 'booster_row.dart';
import 'level_common.dart';

/// Kết quả một lượt chơi level: 3 sao bật lần lượt, xu kiếm được, khách hài lòng / bỏ đi, đơn đặc biệt, combo cao
/// nhất, bánh 5★. Thắng: [Màn tiếp] (nếu level sau đã mở — vào thẳng thẻ "Sẵn sàng") [Chơi lại] [Bản đồ]; thua:
/// tiêu đề an ủi + [Chơi lại] [Bản đồ]. Kết quả đã cộng vào ván ở `LevelScreen`; màn này chỉ hiển thị. Về bản đồ
/// kèm [progress] → bản đồ chạy hoạt cảnh (sao bay vào nút, mở khoá level/chương); [Chơi lại] / [Màn tiếp] cũng gộp
/// [progress] vào hàng chờ hoạt cảnh của bản đồ.
///
/// GĐ6: nút "×2 xu (xem quảng cáo)" một lần khi xu > 0 (thắng hay thua). Rời màn (bản đồ / màn tiếp / chơi lại) →
/// ghi một lượt chơi xong (`registerLevelPlayEnded`, đúng một lần) rồi, nếu `shouldShowInterstitialAfterResult`,
/// chiếu quảng cáo xen kẽ trước khi chuyển. Đây là CHỖ DUY NHẤT của app có quảng cáo xen kẽ.
class LevelResultScreen extends StatefulWidget {
  const LevelResultScreen({super.key, required this.result, this.progress});

  final LevelResult result;

  /// Tiến trình vừa đổi (null → về bản đồ không có hoạt cảnh).
  final LevelProgressDelta? progress;

  @override
  State<LevelResultScreen> createState() => _LevelResultScreenState();
}

class _LevelResultScreenState extends State<LevelResultScreen> {
  /// Đã bấm một nút chuyển màn: chặn bấm đúp.
  bool _leaving = false;

  /// Đã ghi lượt chơi xong (`registerLevelPlayEnded`) cho kết quả này.
  bool _playCounted = false;

  /// Đã xem quảng cáo thưởng ở chính màn này (không chiếu quảng cáo xen kẽ khi rời); đang xem quảng cáo.
  bool _watchedHere = false;
  bool _watching = false;

  /// Đã nhân đôi xu của kết quả này (lưu ở GameState: dựng lại màn không nhân lần hai).
  bool get _doubled => AppScope.read(context).state.isResultDoubled(_r);

  LevelResult get _r => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audio = AppScope.read(context).audio;
      _r.won ? audio.success() : audio.fail();
    });
  }

  Future<void> _double() async {
    if (_doubled || _watching || _leaving || _r.coins <= 0) return;
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    if (!services.ads.canShowRewarded()) {
      showToast(context, l.adsLimitReached, success: false);
      return;
    }
    setState(() => _watching = true);
    var watched = false;
    try {
      watched = await services.ads.showRewarded(context, AdPlacement.doubleCoins);
    } catch (e) {
      debugPrint('LevelResultScreen: quảng cáo ×2 xu lỗi ($e)');
    }
    if (!mounted) return;
    setState(() {
      _watching = false;
      if (watched) _watchedHere = true;
    });
    if (watched) {
      final added = services.state.doubleResultCoins(_r);
      services.audio.success();
      if (added > 0) showToast(context, l.levelResultDoubled(added));
    } else {
      showRewardedFailedToast(context, services.ads);
    }
  }

  /// Rời màn kết quả: ghi lượt chơi xong (một lần), quảng cáo xen kẽ nếu đủ điều kiện (§3), rồi [go].
  Future<void> _leave(VoidCallback go) async {
    if (_leaving || _watching) return;
    _leaving = true;
    final services = AppScope.read(context);
    final state = services.state;
    if (!_playCounted) {
      _playCounted = true;
      state.registerLevelPlayEnded();
    }
    final watched = _watchedHere;
    final unlockedChapter = widget.progress?.unlockedChapter != null;
    if (state.shouldShowInterstitialAfterResult(watchedRewardedHere: watched, unlockedChapter: unlockedChapter)) {
      try {
        // Tự kiểm lại điều kiện + ghi `registerInterstitialShown`.
        await services.ads.showInterstitial(context, watchedRewardedHere: watched, unlockedChapter: unlockedChapter);
      } catch (e) {
        debugPrint('LevelResultScreen: quảng cáo xen kẽ lỗi ($e)');
      }
      if (!mounted) return;
    }
    go();
  }

  void _play(int levelId) => _leave(() {
    // Chơi tiếp không qua bản đồ: tiến trình vẫn vào hàng chờ, lần tới về bản đồ sẽ chạy hoạt cảnh (gộp).
    queueMapReveal(widget.progress);
    Navigator.of(context).pushReplacementNamed(AppRoutes.level, arguments: LevelArgs(levelId));
  });

  void _toMap() => _leave(() => goToMenu(context, reveal: widget.progress));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final services = AppScope.of(context);
    final config = services.levels;
    // levels.json nạp lỗi → cấu hình rỗng: không có level nào để chơi tiếp, về bản đồ.
    if (config.levels.isEmpty) return const LevelRedirect();
    final level = config.hasLevel(_r.levelId) ? config.level(_r.levelId) : null;
    // "Màn tiếp" chỉ khi level sau đã mở (chương sau có thể còn khoá vì thiếu sao).
    final after = _r.won ? config.next(_r.levelId) : null;
    final next = after != null && services.state.isLevelUnlocked(after.id) ? after : null;
    final goal = level?.goal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toMap();
      },
      child: ColoredBox(
        color: SLColors.cream,
        child: SLScope(
          child: Stack(
            children: [
              // Bếp lúc đóng cửa (vẽ tay) phủ kem mờ; chưa có ảnh → tờ giấy kem vẽ tay.
              const Positioned.fill(
                child: RepaintBoundary(
                  child: SceneBackdrop(scene: ArtScene.daySummary, fallback: _PaperBackdrop(), tint: Color(0x40FFF4E6)),
                ),
              ),
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: SLNameTag(
                    _r.won ? l.levelResultWinTitle : l.levelResultLoseTitle,
                    icon: _r.won ? 'confetti' : 'heart',
                    color: _r.won ? SLColors.butter : SLColors.strawberryLight,
                    height: 72,
                    fontSize: 34,
                    maxWidth: 640,
                    seed: 0x1E5A,
                  ),
                ),
              ),
              Positioned(
                left: 250,
                right: 250,
                top: 104,
                child: SLPaperCard(
                  attach: SLAttach.tapeCorners,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                  seed: 0x1E5B,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        level == null
                            ? l.levelNumber(_r.levelId)
                            : '${l.levelNumber(_r.levelId)} · ${level.titleFor(levelLang(context))}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.title.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 8),
                      // Sao level bật lần lượt (tắt hiệu ứng → hiện ngay).
                      StarRow(
                        key: const ValueKey('level-result-stars'),
                        stars: _r.stars,
                        max: 3,
                        size: 72,
                        spacing: 14,
                        animate: !slReduceMotion(context),
                      ),
                      if (goal != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          l.levelResultGoal(l.levelGoalProgress(_r.goalValue, goal.target)),
                          style: styles.label.copyWith(fontSize: 19, color: SLColors.inkSoft),
                        ),
                      ],
                      const SizedBox(height: 6),
                      const SLRule(thickness: 2, echo: SLRuleEcho.partial, seed: 0x1E5C),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _StatRow(
                                  key: const ValueKey('level-result-coins'),
                                  label: l.levelResultCoins,
                                  value: formatInt(context, _doubled ? _r.coins * 2 : _r.coins),
                                  icon: const CoinIcon(size: 26),
                                ),
                                _StatRow(
                                  label: l.levelResultServed,
                                  value: formatInt(context, _r.served),
                                  icon: const SLIcon('heart', size: 26),
                                ),
                                _StatRow(
                                  label: l.levelResultLost,
                                  value: formatInt(context, _r.lost),
                                  icon: const SLIcon('customer', size: 26),
                                  valueColor: _r.lost > 0 ? SLColors.badDeep : SLColors.ink,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              children: [
                                _StatRow(
                                  label: l.levelResultSpecials,
                                  value: formatInt(context, _r.specialsDone),
                                  icon: const SLIcon('ticket', size: 26),
                                ),
                                _StatRow(
                                  label: l.levelResultBestCombo,
                                  value: formatInt(context, _r.bestCombo),
                                  icon: const SLIcon('flame', size: 26),
                                ),
                                _StatRow(
                                  label: l.levelResultFiveStar,
                                  value: formatInt(context, _r.fiveStarTreats),
                                  icon: const StarIcon(size: 26),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_ExtraRewards.has(widget.progress)) ...[
                        const SizedBox(height: 6),
                        _ExtraRewards(progress: widget.progress!),
                      ],
                    ],
                  ),
                ),
              ),
              // ×2 xu bằng quảng cáo (một lần, chỉ khi có xu): giữa thẻ số liệu và hàng nút chuyển màn.
              if (_r.coins > 0 && !_doubled)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 118,
                  child: Center(
                    child: _DoubleCoinsButton(
                      canWatch: services.ads.canShowRewarded(),
                      busy: _watching,
                      onPressed: _double,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SLButton(
                      key: const ValueKey('level-result-map'),
                      label: l.mapBackToMap,
                      icon: 'pin',
                      variant: SLButtonVariant.secondary,
                      width: 230,
                      height: 68,
                      onPressed: _toMap,
                    ),
                    const SizedBox(width: 18),
                    SLButton(
                      label: l.levelReplay,
                      icon: 'reset',
                      color: next == null ? SLColors.strawberry : SLColors.butter,
                      width: 230,
                      height: 68,
                      onPressed: () => _play(_r.levelId),
                    ),
                    if (next != null) ...[
                      const SizedBox(width: 18),
                      SLButton(
                        label: l.levelNext,
                        icon: 'forward',
                        color: SLColors.strawberry,
                        width: 260,
                        height: 68,
                        fontSize: 24,
                        onPressed: () => _play(next.id),
                      ),
                    ],
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

/// Hàng nhỏ "thưởng thêm" của lượt (chỉ mục > 0): kim cương, điểm Thẻ mùa, quà vật phẩm giới thiệu (lần đầu tới L4).
class _ExtraRewards extends StatelessWidget {
  const _ExtraRewards({required this.progress});

  final LevelProgressDelta progress;

  static bool has(LevelProgressDelta? p) => p != null && (p.gems > 0 || p.seasonPoints > 0 || p.boosterGift);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final state = AppScope.of(context).state;
    final text = styles.label.copyWith(fontSize: 18);
    Widget chip(Widget icon, String label, {String? semantics, required int seed}) => Semantics(
      label: semantics ?? label,
      child: ExcludeSemantics(
        child: SLSurface(
          spec: SLSurfaceSpec(shape: const SLRoundRect(14), material: SLMaterial.wash, color: SLColors.butterLight, seed: seed),
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 6), Text(label, style: text)],
          ),
        ),
      ),
    );
    final gift = state.boosterData(BoosterEffects.introGift);
    return Wrap(
      key: const ValueKey('level-result-extras'),
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        if (progress.gems > 0)
          chip(
            const GemIcon(size: 26),
            '+${formatInt(context, progress.gems)}',
            semantics: l.commonGems(progress.gems),
            seed: 0x1E61,
          ),
        if (progress.seasonPoints > 0)
          chip(
            const SLArtIcon(ArtSprites.ticket, 'ticket', size: 26),
            l.levelResultSeasonPoints(progress.seasonPoints),
            seed: 0x1E62,
          ),
        if (progress.boosterGift)
          chip(
            BoosterArt(booster: gift, size: 30),
            l.levelResultBoosterGift(gift.name(levelLang(context))),
            seed: 0x1E63,
          ),
      ],
    );
  }
}

/// Nút "×2 xu (xem quảng cáo)": xu + icon phát; hết lượt quảng cáo hôm nay → mờ kèm dòng "Hết lượt".
class _DoubleCoinsButton extends StatelessWidget {
  const _DoubleCoinsButton({required this.canWatch, required this.busy, required this.onPressed});

  final bool canWatch;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLButton(
      key: const ValueKey('level-result-double'),
      label: l.levelResultDoubleCoins,
      subtitle: canWatch ? null : l.adsLimitReached,
      leading: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [CoinIcon(size: 30), SizedBox(width: 4), SLIcon('play_video', size: 30)],
      ),
      color: SLColors.mint,
      width: 380,
      height: 62,
      fontSize: 22,
      loading: busy,
      onPressed: canWatch && !busy ? onPressed : null,
    );
  }
}

/// Nền dự phòng khi chưa có ảnh bếp: tờ giấy kem vẽ tay phủ kín.
class _PaperBackdrop extends StatelessWidget {
  const _PaperBackdrop();

  @override
  Widget build(BuildContext context) => const SLSurface(
        spec: SLSurfaceSpec(shape: SLRoundRect(0), color: SLColors.cream, outline: false, seed: 0x1E5D),
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor = SLColors.ink,
  });

  final String label;
  final String value;
  final Widget icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.body.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          Text(value, style: styles.number.copyWith(fontSize: 21, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }
}
