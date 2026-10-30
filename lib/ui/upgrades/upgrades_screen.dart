import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/economy.dart';
import '../../core/game_state.dart';
import '../../core/l10n_lookup.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart' show PurchaseResult, ToolId;
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/staff_portrait.dart';
import '../common/sugar_screen.dart';
import '../level/level_common.dart';
import '../sugarleaf/sugarleaf.dart';
import 'tool_art.dart';

part 'staff_tab.dart';

/// Tab của màn Nâng cấp.
enum UpgradesTab { expansion, equipment, staff }

/// Tham số route `AppRoutes.upgrades`: mở thẳng [tab], cuộn tới + làm nổi thẻ [focus] (id mở khoá hoặc id thiết bị).
class UpgradesArgs {
  const UpgradesArgs({this.tab = UpgradesTab.expansion, this.focus});

  /// Từ một id trong `LevelProgressDelta.newUnlocks` / `GameState.unseenUnlocks`: `"eq:<id>:<cấp>"` → tab Thiết
  /// bị, thẻ `<id>`; id thiết bị trần → tab Thiết bị; nhân viên → tab Nhân viên; còn lại → tab Mở rộng tiệm.
  factory UpgradesArgs.forUnlock(String id, UnlockConfig config) {
    final eq = UnlockKeys.parseEquipment(id);
    if (eq != null) return UpgradesArgs(tab: UpgradesTab.equipment, focus: eq.id);
    if (config.staffById(id) != null || config.unlock(id)?.kind == UnlockKind.staff) {
      return UpgradesArgs(tab: UpgradesTab.staff, focus: id);
    }
    if (config.unlock(id) == null && config.equipmentById(id) != null) {
      return UpgradesArgs(tab: UpgradesTab.equipment, focus: id);
    }
    return UpgradesArgs(focus: id);
  }

  final UpgradesTab tab;
  final String? focus;
}

/// Icon vẽ tay thay ảnh còn thiếu của một mở khoá theo loại.
String unlockFallbackIcon(UnlockKind kind) => switch (kind) {
  UnlockKind.expansion => 'storefront',
  UnlockKind.staff || UnlockKind.staffUpgrade => 'customer',
  UnlockKind.decorSet => 'decor_chair',
};

/// Dụng cụ V1 ứng với id thiết bị (`whisk`, `pipingBag`, `tongs`); khác → null.
ToolId? _toolOf(String id) {
  for (final t in ToolId.values) {
    if (t.name == id) return t;
  }
  return null;
}

/// Nâng cấp: 3 tab trên một tờ giấy lớn — **Mở rộng tiệm** (thẻ theo chương: ảnh, tên, mô tả, trạng thái "Qua màn X
/// để mở" / giá + Mua / "Đã có" / "Sắp có"; chương chưa mở hiện mờ), **Thiết bị** (mỗi thẻ: cấp hiện tại → cấp
/// sau, thông số trước/sau, giá, khoá theo màn) và **Nhân viên** (`staff_tab.dart`: thuê + nâng Tốc độ / Tay nghề).
/// Mở màn = đã xem mọi mục mới (`markUnlocksSeen`, chấm đỏ trên bản đồ tắt); các mục đó mang huy hiệu "Mới" trong
/// lần mở này.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key, this.initialTab = UpgradesTab.expansion, this.focus});

  final UpgradesTab initialTab;

  /// Id thẻ cần cuộn tới + làm nổi (mở khoá hoặc thiết bị); null = không.
  final String? focus;

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  late UpgradesTab _tab = widget.initialTab;

  /// Mục mới (chưa xem) lúc mở màn — huy hiệu "Mới"; thiết bị: id trần.
  Set<String> _fresh = const {};
  bool _freshRead = false;

  /// Khoá thẻ để cuộn tới (theo id).
  final Map<String, GlobalKey> _cardKeys = {};

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_freshRead) return;
    _freshRead = true;
    final state = AppScope.read(context).state;
    final unseen = state.unseenUnlocks;
    _fresh = {for (final id in unseen) UnlockKeys.parseEquipment(id)?.id ?? id};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Đã mở màn Nâng cấp → mọi mục mới coi như đã xem (chấm đỏ trên bản đồ tắt).
      if (unseen.isNotEmpty) state.markUnlocksSeen(unseen);
      _scrollToFocus();
    });
  }

  void _scrollToFocus() {
    final id = widget.focus;
    if (id == null) return;
    final ctx = _cardKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.4,
      duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final state = services.state;
    final config = state.unlockConfig;
    final lang = levelLang(context);
    final focus = widget.focus;

    final Widget content = switch (_tab) {
      UpgradesTab.expansion => _ExpansionTab(
        key: const ValueKey('upg-tab-expansion'),
        state: state,
        config: config,
        levels: services.levels,
        lang: lang,
        fresh: _fresh,
        focus: focus,
        keyFor: _keyFor,
      ),
      UpgradesTab.equipment => _EquipmentTab(
        key: const ValueKey('upg-tab-equipment'),
        state: state,
        config: config,
        lang: lang,
        fresh: _fresh,
        focus: focus,
        keyFor: _keyFor,
      ),
      UpgradesTab.staff => _StaffTab(
        key: const ValueKey('upg-tab-staff'),
        state: state,
        config: config,
        lang: lang,
        fresh: _fresh,
        focus: focus,
        keyFor: _keyFor,
      ),
    };

    return SugarScreen(
      title: l.upgradesTitle,
      titleIconId: 'oven',
      titleArt: ArtSprites.oven(1),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 0,
              width: 780,
              height: _tabsHeight,
              child: SLTabBar(
                key: const ValueKey('upg-tabs'),
                tabs: [
                  SLTabItem(l.upgTabExpansion, icon: 'storefront'),
                  SLTabItem(l.upgTabEquipment, icon: 'oven'),
                  SLTabItem(l.upgTabStaff, icon: 'customer'),
                ],
                selected: _tab.index,
                onChanged: (i) => setState(() => _tab = UpgradesTab.values[i]),
                expand: true,
                height: _tabsHeight,
                seed: 0x0A70,
              ),
            ),
            Positioned.fill(
              top: _tabsHeight - 6,
              child: SLSurface(
                spec: const SLSurfaceSpec(shape: SLRoundRect(26), color: SLColors.cream, seed: 0x0A7C),
                lift: 3,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: ClipRect(child: content),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _tabsHeight = 60.0;
}

// ==================================================================== Tab Mở rộng tiệm

class _ExpansionTab extends StatelessWidget {
  const _ExpansionTab({
    super.key,
    required this.state,
    required this.config,
    required this.levels,
    required this.lang,
    required this.fresh,
    required this.focus,
    required this.keyFor,
  });

  final GameState state;
  final UnlockConfig config;
  final LevelConfig levels;
  final String lang;
  final Set<String> fresh;
  final String? focus;
  final GlobalKey Function(String) keyFor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final byChapter = <int, List<UnlockData>>{};
    for (final u in config.unlocks) {
      // Nhân viên nằm ở tab riêng.
      if (u.kind == UnlockKind.staff) continue;
      byChapter.putIfAbsent(u.chapter, () => []).add(u);
    }
    final chapters = byChapter.keys.toList()..sort();
    if (chapters.isEmpty) return const SizedBox.expand();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ch in chapters) ...[
            _chapterHeader(context, l, styles, ch),
            const SizedBox(height: 8),
            Opacity(
              opacity: state.isChapterUnlocked(ch) ? 1 : 0.55,
              child: Wrap(
                spacing: 18,
                runSpacing: 14,
                children: [
                  for (final u in (byChapter[ch]!..sort((a, b) => a.level.compareTo(b.level))))
                    _ExpansionCard(
                      key: keyFor(u.id),
                      data: u,
                      state: state,
                      lang: lang,
                      fresh: fresh.contains(u.id),
                      focused: focus == u.id,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _chapterHeader(BuildContext context, AppLocalizations l, SLTextStyles styles, int ch) {
    final open = state.isChapterUnlocked(ch);
    final chapter = levels.chapter(ch);
    final title = chapter == null ? l.levelChapterLabel(ch) : '${l.levelChapterLabel(ch)} · ${chapter.titleFor(lang)}';
    return Row(
      children: [
        SLIcon(open ? 'book' : 'lock', size: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            key: ValueKey('upg-chapter-$ch'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.heading.copyWith(fontSize: 24, color: open ? SLColors.ink : SLColors.inkSoft),
          ),
        ),
        if (!open) ...[
          const SizedBox(width: 12),
          SLChip(label: l.mapChapterLockedTitle(ch), icon: 'lock', color: SLColors.paperShade, selected: true),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: SLRule(color: SLColors.caramel.withValues(alpha: 0.6), amplitude: 1.4, seed: 0x0AC0 + ch),
        ),
      ],
    );
  }
}

/// Thẻ một mở khoá (cố định 280×272): ảnh trên mảng màu nước, tên, mô tả, trạng thái ở chân thẻ. Vừa mua → dấu mộc ✓
/// nảy vào + lấp lánh. [focused] = thẻ được mở tới từ thông báo (giấy vàng bơ).
class _ExpansionCard extends StatefulWidget {
  const _ExpansionCard({
    super.key,
    required this.data,
    required this.state,
    required this.lang,
    required this.fresh,
    required this.focused,
  });

  final UnlockData data;
  final GameState state;
  final String lang;
  final bool fresh;
  final bool focused;

  static const width = 280.0;
  static const height = 272.0;

  @override
  State<_ExpansionCard> createState() => _ExpansionCardState();
}

class _ExpansionCardState extends State<_ExpansionCard> {
  int _shortTries = 0;
  bool _justBought = false;

  void _buy() {
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final result = services.state.buyUnlock(widget.data.id);
    switch (result) {
      case PurchaseResult.ok:
        services.audio.success();
        setState(() => _justBought = true);
        showToast(context, l.upgExpansionDone);
      case PurchaseResult.notEnoughCoins:
        services.audio.fail();
        setState(() => _shortTries++);
        showToast(context, l.commonNotEnoughCoins, success: false);
      case PurchaseResult.notEnoughGems:
        services.audio.fail();
        setState(() => _shortTries++);
        showToast(context, l.commonNotEnoughGems, success: false);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final u = widget.data;
    final state = widget.state;
    final status = state.unlockState(u.id);
    final seed = slSeed(content: u.id, salt: 0x0B10);
    final accent = switch (status) {
      UnlockState.owned => SLColors.mintLight,
      UnlockState.available => SLColors.butterLight,
      UnlockState.locked || UnlockState.comingSoon => SLColors.paperShade,
    };

    final Widget footer = switch (status) {
      UnlockState.owned => SLChip(
        key: ValueKey('upg-owned-${u.id}'),
        label: l.upgOwned,
        icon: 'check',
        selected: true,
        color: SLColors.mint,
      ),
      UnlockState.comingSoon => SLChip(
        key: ValueKey('upg-soon-${u.id}'),
        label: l.upgComingSoon,
        icon: 'clock',
        selected: true,
        color: SLColors.paperShade,
      ),
      UnlockState.locked => _LockLine(key: ValueKey('upg-locked-${u.id}'), level: u.level),
      UnlockState.available => SLShake(
        trigger: _shortTries,
        child: Row(
          children: [
            Expanded(
              child: _Prices(coins: u.price, gems: u.gemPrice, state: state),
            ),
            const SizedBox(width: 8),
            SLButton(
              key: ValueKey('upg-buy-${u.id}'),
              label: l.commonBuy,
              icon: 'basket',
              color: SLColors.strawberry,
              height: 50,
              fontSize: 19,
              onPressed: _buy,
            ),
          ],
        ),
      ),
    };

    final card = SLPaperCard(
      seed: seed,
      radius: 20,
      color: widget.focused ? SLColors.butterLight : null,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: SLSurface(
              spec: SLSurfaceSpec(
                shape: const SLRoundRect(14),
                material: SLMaterial.wash,
                color: accent,
                inkWidth: 1.6,
                seed: seed + 1,
              ),
              child: Center(
                child: Opacity(
                  opacity: status == UnlockState.locked || status == UnlockState.comingSoon ? 0.6 : 1,
                  child: UnlockArt(path: u.artPath, fallbackIcon: unlockFallbackIcon(u.kind), size: 96),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            u.name(widget.lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: styles.heading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              u.desc(widget.lang),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
          SizedBox(height: 50, child: Center(child: footer)),
        ],
      ),
    );

    return SizedBox(
      width: _ExpansionCard.width,
      height: _ExpansionCard.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: card),
          if (widget.fresh && status == UnlockState.available)
            Positioned(right: -6, top: -8, child: SLBadge.label(l.levelNewBadge, color: SLColors.mint, sparkle: true)),
          if (status == UnlockState.owned)
            Positioned(
              right: 4,
              top: 4,
              child: _justBought ? const SLBounceIn(child: _BoughtStamp()) : const _BoughtStamp(sparkle: false),
            ),
        ],
      ),
    );
  }
}

/// Dấu mộc ✓ ở góc thẻ đã mua; [sparkle] = kèm lấp lánh (vừa mua).
class _BoughtStamp extends StatelessWidget {
  const _BoughtStamp({this.sparkle = true});

  final bool sparkle;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const SLStamp(size: 52, seed: 0x0B5A),
      if (sparkle) ...[
        const Positioned(right: -12, top: -10, child: SLSparkle(size: 24)),
        const Positioned(left: -12, bottom: -6, child: SLSparkle(size: 18)),
      ],
    ],
  );
}

/// Dòng khoá "Qua màn X để mở" (ổ khoá + chữ), không phải nút.
class _LockLine extends StatelessWidget {
  const _LockLine({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SLIcon('lock', size: 26, color: SLColors.inkSoft),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            l.mapUnlockAfterLevel(level),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: SLTextStyles.of(context).label.copyWith(fontSize: 16, color: SLColors.inkSoft, height: 1.1),
          ),
        ),
      ],
    );
  }
}

/// Giá xu và/hoặc kim cương (giá 0 thì ẩn); thiếu tiền → chữ đỏ.
class _Prices extends StatelessWidget {
  const _Prices({required this.coins, required this.gems, required this.state});

  final int coins;
  final int gems;
  final GameState state;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (coins > 0 || gems <= 0) PriceTag(amount: coins, affordable: state.coins >= coins, size: 22),
        if (coins > 0 && gems > 0) const SizedBox(width: 8),
        if (gems > 0) PriceTag(amount: gems, gems: true, affordable: state.gems >= gems, size: 22),
      ],
    ),
  );
}

/// Ảnh một mục `unlocks.json` ([path] = `assets/art/<art>.webp`, giải mã nhỏ); thiếu / lỗi / null → đĩa icon vẽ tay
/// [fallbackIcon].
class UnlockArt extends StatelessWidget {
  const UnlockArt({super.key, required this.path, required this.fallbackIcon, this.size = 96});

  final String? path;
  final String fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = SLIconDisc(fallbackIcon, size: size * 0.8, color: SLColors.paper, iconScale: 0.6, seed: 0x0BA0);
    final p = path;
    if (p == null) return SizedBox.square(dimension: size, child: Center(child: fallback));
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox.square(
      dimension: size,
      child: Image(
        image: ResizeImage(AssetImage(p), width: px, policy: ResizeImagePolicy.fit),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => Center(child: fallback),
      ),
    );
  }
}

// ==================================================================== Tab Thiết bị

class _EquipmentTab extends StatelessWidget {
  const _EquipmentTab({
    super.key,
    required this.state,
    required this.config,
    required this.lang,
    required this.fresh,
    required this.focus,
    required this.keyFor,
  });

  final GameState state;
  final UnlockConfig config;
  final String lang;
  final Set<String> fresh;
  final String? focus;
  final GlobalKey Function(String) keyFor;

  @override
  Widget build(BuildContext context) {
    final items = config.equipment.isNotEmpty ? config.equipment : _fallbackEquipment(context, lang);
    // Lưới 4 cột × 2 hàng vừa khung 1280×720 (7 thiết bị); nhiều hơn thì cuộn.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), // chừa chỗ huy hiệu "Mới" thò lên mép thẻ
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          for (final e in items)
            _EquipmentCard(
              key: keyFor(e.id),
              data: e,
              state: state,
              lang: lang,
              fresh: fresh.contains(e.id),
              focused: focus == e.id,
            ),
        ],
      ),
    );
  }
}

/// unlocks.json nạp lỗi (cấu hình rỗng): lò vùng vàng + dụng cụ V1 theo bảng dự phòng của `Economy` (khớp
/// `GameState.buyEquipment`), tên/mô tả từ chuỗi giao diện cũ.
List<EquipmentData> _fallbackEquipment(BuildContext context, String lang) {
  final l = AppLocalizations.of(context);
  return [
    EquipmentData(
      id: EquipmentIds.goldenOven,
      names: {lang: l.upgradeOven},
      descs: {lang: l.upgradeOvenDesc},
      tiers: [
        for (final t in Economy.ovenTiers)
          EquipmentTier(level: t.requiredShopLevel, price: t.cost, value: t.perfectHalfWidth),
      ],
    ),
    for (final MapEntry(key: tool, value: tiers) in Economy.toolTiers.entries)
      EquipmentData(
        id: EquipmentIds.tool(tool),
        names: {lang: l.toolName(tool)},
        descs: {lang: l.toolDesc(tool)},
        tiers: [for (final t in tiers) EquipmentTier(level: t.requiredShopLevel, price: t.cost, value: t.value)],
      ),
  ];
}

/// Thẻ đứng một thiết bị (284×256): ảnh trên mảng màu nước, tên, mô tả (tối đa 2 dòng, co chữ cho đủ), "Cấp k/n" +
/// chấm cấp, thông số hiện tại → cấp sau; chân thẻ: giá + "Nâng cấp" / "Qua màn X để mở" / huy hiệu tối đa. Vừa mua →
/// dấu mộc ✓ nảy vào rồi mờ đi sau [_EquipmentCardState.stampFor].
class _EquipmentCard extends StatefulWidget {
  const _EquipmentCard({
    super.key,
    required this.data,
    required this.state,
    required this.lang,
    required this.fresh,
    required this.focused,
  });

  final EquipmentData data;
  final GameState state;
  final String lang;
  final bool fresh;
  final bool focused;

  static const width = 284.0;
  static const height = 256.0;

  @override
  State<_EquipmentCard> createState() => _EquipmentCardState();
}

class _EquipmentCardState extends State<_EquipmentCard> {
  int _shortTries = 0;
  int _bought = 0;

  /// Dấu mộc ✓ của lần mua vừa rồi đang hiện (tắt sau [stampFor]).
  bool _stampOn = false;

  /// Vừa mua xong: bỏ qua lần bấm trong [cooldown] (chạm đúp không mua hai cấp).
  bool _cooling = false;

  /// Cấp thiết bị lúc dựng gần nhất: chỉ mua khi khớp cấp hiện tại (lần bấm thứ hai trước khi thẻ dựng lại bị bỏ).
  int _shownTier = 0;
  Timer? _coolTimer;
  Timer? _stampTimer;

  static const cooldown = Duration(milliseconds: 400);
  static const stampFor = Duration(milliseconds: 1300);

  @override
  void dispose() {
    _coolTimer?.cancel();
    _stampTimer?.cancel();
    super.dispose();
  }

  void _buy() {
    final services = AppScope.read(context);
    if (_cooling || services.state.equipmentTier(widget.data.id) != _shownTier) return;
    final l = AppLocalizations.of(context);
    final result = services.state.buyEquipment(widget.data.id);
    switch (result) {
      case PurchaseResult.ok:
        services.audio.success();
        _cooling = true;
        _coolTimer?.cancel();
        _coolTimer = Timer(cooldown, () => _cooling = false);
        _stampTimer?.cancel();
        _stampTimer = Timer(stampFor, () {
          if (mounted) setState(() => _stampOn = false);
        });
        setState(() {
          _bought++;
          _stampOn = true;
        });
        showToast(context, l.upgradeDone);
      case PurchaseResult.notEnoughCoins:
        services.audio.fail();
        setState(() => _shortTries++);
        showToast(context, l.commonNotEnoughCoins, success: false);
      case PurchaseResult.notEnoughGems:
        services.audio.fail();
        setState(() => _shortTries++);
        showToast(context, l.commonNotEnoughGems, success: false);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final e = widget.data;
    final state = widget.state;
    final max = e.tiers.length;
    _shownTier = state.equipmentTier(e.id);
    final tier = _shownTier.clamp(1, max);
    final next = tier < max ? e.tiers[tier] : null;
    final locked = next != null && state.highestCompletedLevel < next.level;
    final seed = slSeed(content: e.id, salt: 0x0E10);

    final Widget action;
    if (next == null) {
      action = _MaxedBadge(label: l.upgradeMaxed, seed: seed + 3);
    } else if (locked) {
      action = _LockLine(key: ValueKey('upg-locked-${e.id}'), level: next.level);
    } else {
      action = SLShake(
        trigger: _shortTries,
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PriceTag(amount: next.price, affordable: state.coins >= next.price, size: 22),
              ),
            ),
            const SizedBox(width: 6),
            SLButton(
              key: ValueKey('upg-buy-${e.id}'),
              label: l.upgradeBuy,
              icon: 'arrow_up',
              color: SLColors.strawberry,
              height: 48,
              fontSize: 18,
              onPressed: _buy,
            ),
          ],
        ),
      );
    }

    final statNow = equipmentStatText(context, e.id, e.tiers[tier - 1].value);
    final statNext = next == null ? null : equipmentStatText(context, e.id, next.value);

    final card = SLPaperCard(
      seed: seed,
      radius: 20,
      color: widget.focused ? SLColors.butterLight : null,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: SLSurface(
              spec: SLSurfaceSpec(
                shape: const SLRoundRect(14),
                material: SLMaterial.wash,
                color: next == null ? SLColors.butterLight : SLColors.mintLight,
                inkWidth: 1.6,
                seed: seed + 1,
              ),
              child: Center(
                child: _EquipmentArt(data: e, tier: tier, size: 68),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            e.name(widget.lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: styles.heading.copyWith(fontSize: 21, height: 1.15),
          ),
          SizedBox(
            height: _descHeight,
            child: Center(
              child: _FitLines(
                e.desc(widget.lang),
                key: ValueKey('upg-desc-${e.id}'),
                maxLines: 2,
                minFontSize: 11,
                style: styles.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.upgTierOf(tier, max),
                  key: ValueKey('upg-tier-${e.id}'),
                  style: styles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(width: 8),
                _LevelPips(level: tier, max: max, seed: seed),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _StatLine(now: statNow, next: statNext),
          const Spacer(),
          SizedBox(height: 48, child: Center(child: action)),
        ],
      ),
    );

    return SizedBox(
      width: _EquipmentCard.width,
      height: _EquipmentCard.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: card),
          if (widget.fresh && next != null && !locked)
            Positioned(right: -6, top: -8, child: SLBadge.label(l.levelNewBadge, color: SLColors.mint, sparkle: true)),
          if (_bought > 0)
            Positioned(
              right: 8,
              top: 6,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 320),
                  child: _stampOn
                      ? SLBounceIn(key: ValueKey('bought$_bought'), child: const _BoughtStamp())
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Chỗ cho hai dòng mô tả (cỡ 14.5 × cao dòng 1.2).
  static const _descHeight = 36.0;
}

/// Chữ giữa, tối đa [maxLines] dòng: dài quá thì co cỡ chữ dần (tới [minFontSize]) cho đủ nội dung thay vì cắt "…";
/// tới cỡ nhỏ nhất vẫn dài mới cắt.
class _FitLines extends StatelessWidget {
  const _FitLines(
    this.text, {
    super.key,
    required this.style,
    required this.maxLines,
    required this.minFontSize,
    this.align = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minFontSize;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        var size = base.fontSize ?? 14;
        if (box.maxWidth.isFinite) {
          while (size > minFontSize) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: base.copyWith(fontSize: size)),
              textAlign: align,
              textDirection: direction,
              textScaler: scaler,
              maxLines: maxLines,
            )..layout(maxWidth: box.maxWidth);
            final fits = !painter.didExceedMaxLines;
            painter.dispose();
            if (fits) break;
            size = (size - 0.5).clamp(minFontSize, size);
          }
        }
        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: base.copyWith(fontSize: size),
        );
      },
    );
  }
}

/// Thông số dễ hiểu của một cấp thiết bị (vd. "Nướng trong 6,3 giây", "4 bánh mỗi khay"). [value] = `EquipmentTier.value`.
String equipmentStatText(BuildContext context, String id, num value) {
  final l = AppLocalizations.of(context);
  int pct(num v) => (v <= 1 ? v * 100 : v).round();
  return switch (id) {
    'fastOven' => l.upgStatOvenSec(formatDecimal1(context, value.toDouble())),
    'bigTray' => l.upgStatBatch(value.round()),
    'wideCase' => l.upgStatCaseSlot(value.round()),
    'goldenOven' => l.upgradeOvenPerfectZone(pct(value)),
    'whisk' => l.upgStatMixZone(pct(value)),
    'pipingBag' => l.upgStatStroke(value.round()),
    'tongs' => value <= 0 ? l.upgStatSnapNone : l.upgStatSnap(value.round()),
    _ => value == value.roundToDouble() ? formatInt(context, value.round()) : formatDecimal1(context, value.toDouble()),
  };
}

/// Ảnh thiết bị: lò vùng vàng / dụng cụ V1 theo [ToolArt] (ảnh vẽ tay + hình code dự phòng); còn lại theo `art` trong
/// unlocks.json (thiếu → icon).
class _EquipmentArt extends StatelessWidget {
  const _EquipmentArt({required this.data, required this.tier, required this.size});

  final EquipmentData data;
  final int tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tool = _toolOf(data.id);
    if (data.id == 'goldenOven' || tool != null) {
      final level = tool == null ? tier.clamp(1, 5) : tier;
      return ArtImage(
        ToolArt.art(tool, level: level),
        size: size,
        fallback: (c, s) => ToolArt.paint(c, Offset.zero & s, tool, level: level),
      );
    }
    return UnlockArt(path: data.artPath, fallbackIcon: _equipmentIcon(data.id), size: size);
  }

  static String _equipmentIcon(String id) => switch (id) {
    'bigTray' => 'cake_slice',
    'wideCase' => 'storefront',
    _ => 'oven',
  };
}

/// Rút gọn cặp thông số "hiện tại → cấp sau" bỏ chữ lặp: cùng đầu → bỏ ở vế sau ("Nướng 6,3 giây → 5,6 giây"); không
/// thì cùng đuôi → bỏ ở vế trước ("3 → 4 bánh mỗi khay"). Không có phần chung → giữ nguyên.
(String, String) compactStatPair(String now, String next) {
  final a = now.split(' ');
  final b = next.split(' ');
  var head = 0;
  while (head < a.length - 1 && head < b.length - 1 && a[head] == b[head]) {
    head++;
  }
  if (head > 0) return (now, b.skip(head).join(' '));
  var tail = 0;
  while (tail < a.length - 1 && tail < b.length - 1 && a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
    tail++;
  }
  if (tail > 0) return (a.take(a.length - tail).join(' '), next);
  return (now, next);
}

/// "hiện tại → cấp sau" (cấp sau xanh đậm; chữ lặp rút gọn theo [compactStatPair], đọc màn hình vẫn đọc đủ); tối đa →
/// chỉ hiện thông số hiện tại.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.now, required this.next});

  final String now;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final base = styles.body.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2);
    final full = next;
    final (nowShown, nextShown) = full == null ? (now, null) : compactStatPair(now, full);
    return RepaintBoundary(
      child: SLSurface(
        spec: const SLSurfaceSpec(
          shape: SLRoundRect(12),
          material: SLMaterial.wash,
          color: SLColors.butterLight,
          inkWidth: 1.6,
          seed: 0x0E7A,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: now,
                child: ExcludeSemantics(child: Text(nowShown, style: base)),
              ),
              if (full != null && nextShown != null) ...[
                const SizedBox(width: 6),
                Semantics(
                  label: l.upgStatNext(full),
                  child: const ExcludeSemantics(child: SLIcon('forward', size: 20, color: SLColors.goodDeep)),
                ),
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: Text(
                    nextShown,
                    style: base.copyWith(fontWeight: FontWeight.w900, color: SLColors.goodDeep),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chấm cấp vẽ tay: viên màu nước xanh (đã đạt) / giấy cũ (chưa). Chấm vừa đạt nảy vào.
class _LevelPips extends StatelessWidget {
  const _LevelPips({super.key, required this.level, required this.max, required this.seed});

  final int level;
  final int max;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= max; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: i <= level
                  ? SLBounceIn(key: ValueKey('pip$i-on'), child: _pip(i, true))
                  : KeyedSubtree(key: ValueKey('pip$i-off'), child: _pip(i, false)),
            ),
        ],
      ),
    );
  }

  Widget _pip(int i, bool on) => SizedBox(
    width: 20,
    height: 14,
    child: SLSurface(
      spec: SLSurfaceSpec(
        shape: const SLRoundRect(7),
        material: SLMaterial.wash,
        color: on ? SLColors.good : SLColors.paperShade,
        inkWidth: on ? 2 : 1.6,
        seed: seed + i,
      ),
    ),
  );
}

/// Huy hiệu "đã nâng cấp tối đa" (thay cho nút): dải màu nước vàng bơ + huân chương.
class _MaxedBadge extends StatelessWidget {
  const _MaxedBadge({required this.label, required this.seed});

  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(18),
          material: SLMaterial.wash,
          color: SLColors.butter,
          sticker: true,
          seed: seed,
        ),
        lift: 2,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SLIcon('medal_max', size: 28),
                const SizedBox(width: 8),
                Text(label, maxLines: 1, style: SLTextStyles.of(context).label.copyWith(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
