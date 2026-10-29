// Màn trình bày bộ SL* — CHỈ bản debug (route chỉ đăng ký khi kDebugMode, lối vào ở màn Cài đặt chỉ hiện khi
// kDebugMode). Chuỗi riêng của Gallery (tiêu đề mục, chú thích) viết cứng tiếng Việt vì là công cụ nội bộ, không
// qua AppLocalizations; chuỗi mẫu trong các thành phần lấy từ AppLocalizations để thấy độ dài thật en/vi.
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../../../core/art/art_sprites.dart';
import '../../../core/l10n_lookup.dart';
import '../../../core/models/ids.dart';
import '../../../core/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../common/art.dart';
import '../paint/sl_cache.dart';
import '../paint/sl_surface.dart';
import '../sugarleaf.dart';

class UiGalleryScreen extends StatefulWidget {
  const UiGalleryScreen({super.key, this.initialPage = 0, this.initialLocale});

  final int initialPage;

  /// Ngôn ngữ ban đầu (null = theo app).
  final Locale? initialLocale;

  static const pages = ['Nút & chọn', 'Khung', 'Thanh & hộp thoại', 'Icon', 'Màu', 'Trên nền ảnh'];

  @override
  State<UiGalleryScreen> createState() => _UiGalleryScreenState();
}

class _UiGalleryScreenState extends State<UiGalleryScreen> {
  late int _page = widget.initialPage;
  late Locale? _locale = widget.initialLocale;
  bool _reduceMotion = false;
  String _bench = '';

  @override
  Widget build(BuildContext context) {
    final appLocale = Localizations.localeOf(context);
    final locale = _locale ?? appLocale;
    final base = Theme.of(context);
    // Theme theo ngôn ngữ đang xem (font tiêu đề vi/en khác nhau); giữ cờ font đóng gói như theme của app.
    final bundledFonts = base.textTheme.bodyMedium?.fontFamily == AppTheme.nunito;
    final theme = AppTheme.build(locale: locale, useGoogleFonts: bundledFonts);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(disableAnimations: _reduceMotion || mq.disableAnimations),
      child: Localizations.override(
        context: context,
        locale: locale,
        child: Theme(
          data: theme,
          child: SLScope(
            child: ColoredBox(
              color: SLColors.cream,
              child: Builder(builder: (context) => _body(context, locale)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Locale locale) {
    final l = AppLocalizations.of(context);
    final vi = locale.languageCode == 'vi';
    return Column(
      children: [
        SLTopBar(
          leading: SLButton.icon(icon: 'back', tooltip: l.commonBack, onPressed: () => Navigator.of(context).maybePop()),
          title: const SLNameTag('UI Gallery', style: SLNameTagStyle.wood, icon: 'sparkle', seed: 11),
          children: [
            SLChip(label: 'EN', selected: !vi, onPressed: () => setState(() => _locale = const Locale('en'))),
            SLChip(label: 'VI', selected: vi, onPressed: () => setState(() => _locale = const Locale('vi'))),
            const SizedBox(width: 8),
            const Text('Tắt hiệu ứng'),
            SLToggle(value: _reduceMotion, semanticLabel: 'Tắt hiệu ứng', onChanged: (v) => setState(() => _reduceMotion = v)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SLTabBar(
              tabs: [for (final p in UiGalleryScreen.pages) SLTabItem(p)],
              selected: _page,
              onChanged: (i) => setState(() => _page = i),
            ),
          ),
        ),
        Container(height: 2.5, margin: const EdgeInsets.symmetric(horizontal: 12), color: SLColors.ink),
        Expanded(
          child: _page == 5
              ? const _OnScenePage()
              : SingleChildScrollView(
                  key: PageStorageKey('gallery-$_page'),
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                  child: switch (_page) {
                    0 => const _ButtonsPage(),
                    1 => const _FramesPage(),
                    2 => const _BarsPage(),
                    3 => const _IconsPage(),
                    _ => const _ColorsPage(),
                  },
                ),
        ),
        _perfBar(context),
      ],
    );
  }

  Widget _perfBar(BuildContext context) {
    final style = SLTextStyles.of(context).caption.copyWith(fontSize: 12, color: SLColors.inkSoft);
    return Container(
      height: 30,
      color: SLColors.paperShade,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: Text('Cache ${SLPaintCache.describe()}  $_bench', maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          GestureDetector(
            onTap: () => setState(() => _bench = _benchmark()),
            child: Text('[đo dựng 40 khung]', style: style.copyWith(color: SLColors.ink)),
          ),
        ],
      ),
    );
  }

  /// Đo thời gian dựng (cache lạnh) 40 khung 240×64 khác seed — chạy trên luồng UI, chỉ bấm tay trong debug.
  String _benchmark() {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      buildSurfaceArt(
        SLSurfaceSpec(shape: const SLRoundRect(18), material: SLMaterial.wash, color: SLColors.strawberry, sticker: true, seed: 9000 + i),
        const Size(240, 64),
      ).dispose();
    }
    return '· dựng lạnh ${(sw.elapsedMicroseconds / 40 / 1000).toStringAsFixed(2)} ms/khung';
  }
}

// ------------------------------------------------------------------------------------------------ Khung mục

class _Section extends StatelessWidget {
  const _Section(this.title, this.children, {this.spacing = 18});

  final String title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SLTextStyles.of(context).title.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
          Wrap(spacing: spacing, runSpacing: 22, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        ],
      ),
    );
  }
}

/// Thành phần + chú thích trạng thái bên dưới.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 8),
          Text(label, style: SLTextStyles.of(context).caption.copyWith(color: SLColors.inkSoft)),
        ],
      );
}

void _noop() {}

// ------------------------------------------------------------------------------------------------ Trang 1

class _ButtonsPage extends StatefulWidget {
  const _ButtonsPage();

  @override
  State<_ButtonsPage> createState() => _ButtonsPageState();
}

class _ButtonsPageState extends State<_ButtonsPage> {
  int _lang = 2;
  bool _sound = true;
  int _tab = 0;
  int _slot = 0;
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('SLButton — chính / phụ', [
          _Labeled('thường', SLButton(label: l.menuPlay, subtitle: l.menuDayLabel(7), icon: 'play_video', onPressed: () => setState(() => _taps++))),
          _Labeled('đang nhấn', SLButton(label: l.menuPlay, onPressed: _noop, debugPressed: true)),
          _Labeled('tắt', SLButton(label: l.menuPlay, onPressed: null)),
          _Labeled('đang tải', SLButton(label: l.commonBuy, onPressed: _noop, loading: true)),
          _Labeled('phụ', SLButton(label: l.commonCancel, variant: SLButtonVariant.secondary, onPressed: _noop)),
          _Labeled('bạc hà', SLButton(label: l.menuUpgrades, color: SLColors.mint, icon: 'sparkle', onPressed: _noop)),
          _Labeled('vàng bơ', SLButton(label: l.menuRecipeBook, color: SLColors.butter, icon: 'bulb', onPressed: _noop)),
          _Labeled('nguy hiểm', SLButton(label: l.settingsResetData, color: SLColors.dangerSoft, icon: 'trash', onPressed: _noop)),
          _Labeled('dài, rộng cố định 220', SizedBox(width: 220, child: SLButton(label: l.dayRemakeWithAd, icon: 'play_video', onPressed: _noop))),
          _Labeled('đã bấm: $_taps', SLButton(label: l.commonOk, height: 48, onPressed: () => setState(() => _taps++))),
          _Labeled(
            'tooltip + nhãn đọc riêng (giữ lâu)',
            SLButton(
              label: l.commonBuy,
              icon: 'basket',
              tooltip: l.storeSimulatedNotice,
              semanticLabel: '${l.commonBuy} — ${l.storeSimulatedNotice}',
              onPressed: _noop,
            ),
          ),
          const _Labeled('SLLoadingDots', SLLoadingDots()),
        ]),
        _Section('SLButton.icon (+ SLBadge)', [
          _Labeled('settings', SLButton.icon(icon: 'settings', tooltip: l.menuSettings, onPressed: _noop)),
          _Labeled('back', SLButton.icon(icon: 'back', tooltip: l.commonBack, onPressed: _noop)),
          _Labeled('close 48', SLButton.icon(icon: 'close', tooltip: l.commonClose, size: 48, onPressed: _noop)),
          _Labeled('chấm báo', SLButton.icon(icon: 'quest_board', tooltip: l.menuQuests, badge: const SLBadge.dot(), onPressed: _noop)),
          _Labeled('số', SLButton.icon(icon: 'heart', tooltip: 'heart', color: SLColors.strawberryLight, badge: const SLBadge.count(3), onPressed: _noop)),
          _Labeled('đang nhấn', SLButton.icon(icon: 'sound_on', tooltip: l.settingsSound, onPressed: _noop, debugPressed: true)),
          _Labeled('tắt', SLButton.icon(icon: 'lock', tooltip: l.commonLocked, onPressed: null)),
          _Labeled('72', SLButton.icon(icon: 'play_video', tooltip: l.commonWatchAd, size: 72, color: SLColors.butter, onPressed: _noop)),
        ]),
        _Section('SLChip', [
          for (final (i, label) in [l.settingsLanguageSystem, l.settingsLanguageEn, l.settingsLanguageVi].indexed)
            SLChip(label: label, icon: i == 0 ? 'phone' : null, selected: _lang == i, onPressed: () => setState(() => _lang = i)),
          _Labeled('tắt', SLChip(label: l.commonLocked, icon: 'lock', onPressed: _noop, enabled: false)),
          _Labeled('đang nhấn', SLChip(label: l.settingsOn, onPressed: _noop, debugPressed: true)),
          _Labeled('tĩnh', SLChip(label: l.dayRainy, icon: 'umbrella')),
          _Labeled('tĩnh, chọn', SLChip(label: l.dayOrderToppings, selected: true, color: SLColors.mintLight)),
        ]),
        _Section('SLToggle', [
          _Labeled(_sound ? 'bật' : 'tắt', SLToggle(value: _sound, semanticLabel: l.settingsSound, onChanged: (v) => setState(() => _sound = v))),
          _Labeled('bật', SLToggle(value: true, semanticLabel: 'on', onChanged: (_) {})),
          _Labeled('tắt', SLToggle(value: false, semanticLabel: 'off', onChanged: (_) {})),
          const _Labeled('vô hiệu', SLToggle(value: true, semanticLabel: 'disabled', onChanged: null)),
        ]),
        _Section('SLTabBar', [
          SLTabBar(
            tabs: [
              SLTabItem(l.menuRecipeBook, icon: 'leaf_logo'),
              SLTabItem(l.menuUpgrades, icon: 'flame'),
              SLTabItem(l.menuDecor, icon: 'decor_chair'),
              SLTabItem(l.menuStore, icon: 'shop_bag'),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
            color: SLColors.mint,
          ),
        ]),
        _Section('SLTabBar — icon trên chữ (tab hẹp, chữ tối đa 2 dòng)', [
          SizedBox(
            width: 430,
            height: 82,
            child: SLTabBar(
              tabs: [
                for (final (i, s) in DecorSlot.values.indexed)
                  SLTabItem(l.decorSlotName(s), icon: const ['slot_wallpaper', 'slot_floor', 'slot_counter', 'slot_window', 'slot_plant'][i]),
              ],
              selected: _slot,
              onChanged: (i) => setState(() => _slot = i),
              expand: true,
              iconAbove: true,
              height: 82,
              spacing: 4,
            ),
          ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ Trang 2

class _FramesPage extends StatelessWidget {
  const _FramesPage();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = SLTextStyles.of(context).body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('SLPanel — giấy / gỗ', [
          SizedBox(
            width: 380,
            child: SLPanel(
              title: l.settingsTitle,
              titleIcon: 'settings',
              child: Text(l.settingsResetConfirmBody, style: body, textAlign: TextAlign.center),
            ),
          ),
          SizedBox(
            width: 380,
            child: SLPanel(
              style: SLPanelStyle.wood,
              title: l.questsTitle,
              titleStyle: SLNameTagStyle.wood,
              child: Column(
                children: [
                  Text(l.questServeCustomers(5), style: body),
                  const SizedBox(height: 10),
                  const SLProgressBar(value: 0.6, color: SLColors.butter, label: '3/5'),
                ],
              ),
            ),
          ),
          SizedBox(width: 300, child: SLPanel(child: Text(l.storeRemoveAdsDesc, style: body))),
        ], spacing: 26),
        _Section('SLPaperCard — ghim / băng dính / nghiêng', [
          SizedBox(width: 220, child: SLPaperCard(attach: SLAttach.pin, child: Text(l.menuTagline, style: body))),
          SizedBox(width: 220, child: SLPaperCard(attach: SLAttach.tape, tilt: -0.03, child: Text(l.questsResetHint, style: body))),
          SizedBox(
            width: 240,
            child: SLPaperCard(attach: SLAttach.tapeCorners, color: SLColors.butterLight, child: Text(l.storeSimulatedNotice, style: body)),
          ),
          SizedBox(width: 200, child: SLPaperCard(color: SLColors.mintLight, tilt: 0.025, child: Text(l.questsAllDone, style: body))),
        ], spacing: 30),
        _Section('SLRule — một nét / đi lại một đoạn / hai nét / caramel lệch', [
          for (final (label, rule) in [
            ('một nét', const SLRule(seed: 1)),
            ('partial', const SLRule(echo: SLRuleEcho.partial, seed: 2)),
            ('full, cao 28', SLRule(height: 28, echo: SLRuleEcho.full, amplitude: 1.6, inset: 4, seed: 3)),
            ('caramel, rise 1', SLRule(color: SLColors.caramel.withValues(alpha: 0.75), amplitude: 1.6, inset: 6, rise: 1, seed: 4)),
          ])
            SizedBox(width: 260, child: _Labeled(label, rule)),
        ]),
        _Section('SLStamp — dấu mộc đóng nghiêng', [
          const _Labeled('mặc định (đã nhận)', SLStamp()),
          const _Labeled(
            'đỏ, nghiêng phải',
            SLStamp(icon: 'heart', color: SLColors.badDeep, fill: Color(0x99FAD3DD), angle: 0.18, seed: 3),
          ),
          const _Labeled('72', SLStamp(icon: 'star', size: 72, seed: 5)),
          SizedBox(
            width: 140,
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: SLPaperCard(child: Text(l.loginDay(2), style: body))),
                const Positioned(right: 0, bottom: 0, child: SLStamp()),
              ],
            ),
          ),
        ], spacing: 30),
        _Section('SLOrderTicket', [
          SLOrderTicket(
            header: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(l.dayOrderTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: SLTextStyles.of(context).title.copyWith(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                const SLBadge.vip(),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (icon, text) in [('leaf_logo', l.dayOrderFrosting), ('sparkle', l.dayOrderToppings), ('pin', l.dayOrderBox)])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [SLIcon(icon, size: 26), const SizedBox(width: 8), Expanded(child: Text(text, style: body))]),
                  ),
              ],
            ),
          ),
          SLOrderTicket(
            width: 230,
            tilt: 0.03,
            color: SLColors.butterLight,
            header: Text('Kenji', style: SLTextStyles.of(context).title.copyWith(fontSize: 22)),
            child: Text(l.orderLineVip('macaron'), style: body),
          ),
        ], spacing: 30),
        _Section('SLSpeechBubble — đuôi dưới / trên / trái / phải', [
          SLSpeechBubble(maxWidth: 300, child: Text(l.dayRemakeLine)),
          SLSpeechBubble(tail: SLTail.top, tailAt: 0.8, maxWidth: 260, child: Text(l.menuTagline)),
          SLSpeechBubble(tail: SLTail.left, tailAt: 0.3, maxWidth: 280, child: Text(l.orderLineVip('éclair'))),
          SLSpeechBubble(tail: SLTail.right, maxWidth: 200, color: SLColors.mintLight, child: Text(l.questsAllDone)),
        ]),
        _Section('SLNameTag — dải vải / ván gỗ', [
          SLNameTag(l.menuQuests),
          SLNameTag(l.storeDecorSet, color: SLColors.mint, icon: 'sparkle'),
          SLNameTag(l.settingsTitle, style: SLNameTagStyle.wood),
          SLNameTag(l.dayExitConfirmTitle, style: SLNameTagStyle.wood, maxWidth: 300),
          const SLNameTag('Sugarleaf Bakery', color: SLColors.butter, icon: 'leaf_logo', height: 64),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ Trang 3

class _BarsPage extends StatefulWidget {
  const _BarsPage();

  @override
  State<_BarsPage> createState() => _BarsPageState();
}

class _BarsPageState extends State<_BarsPage> {
  double _value = 0.14;
  int _count = 3;
  int _shake = 0;
  int _sparkle = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('SLTopBar + SLTopBarItem', [
          SizedBox(
            width: 1200,
            child: SLTopBar(
              leading: SLButton.icon(icon: 'back', tooltip: l.commonBack, onPressed: _noop),
              title: SLNameTag(l.menuShopLevel(7), style: SLNameTagStyle.wood, height: 50),
              children: [
                SLTopBarItem(value: l.commonLevelShort(7), icon: 'trophy', seed: 1),
                SLTopBarItem(value: '2.828', leading: ArtImage(ArtSprites.coin, size: 34), semanticLabel: l.commonCoins(2828), onPressed: _noop, seed: 2),
                SLTopBarItem(value: '67', leading: ArtImage(ArtSprites.gem, size: 34), semanticLabel: l.commonGems(67), color: SLColors.mintLight, seed: 3),
                SLButton.icon(icon: 'settings', tooltip: l.menuSettings, onPressed: _noop),
              ],
            ),
          ),
        ]),
        _Section('SLProgressBar', [
          SizedBox(width: 300, child: SLProgressBar(value: _value, label: l.menuXpProgress((_value * 320).round(), 320))),
          const SizedBox(width: 200, child: SLProgressBar(value: 0)),
          const SizedBox(width: 200, child: SLProgressBar(value: 0.6, color: SLColors.butter)),
          const SizedBox(width: 200, child: SLProgressBar(value: 1, color: SLColors.strawberry, height: 18)),
          SLButton(label: '+10%', height: 48, variant: SLButtonVariant.secondary, onPressed: () => setState(() => _value = (_value + 0.1) % 1.05)),
        ]),
        _Section('SLBadge', [
          _Labeled('số', SLBadge.count(_count)),
          const _Labeled('2 chữ số', SLBadge.count(12)),
          const _Labeled('> 99', SLBadge.count(120)),
          const _Labeled('chấm', SLBadge.dot()),
          const _Labeled('VIP', SLBadge.vip()),
          _Labeled('nhãn', SLBadge.label(l.commonMax, color: SLColors.mint, icon: 'check')),
          SLButton(label: '+1', height: 48, variant: SLButtonVariant.secondary, onPressed: () => setState(() => _count++)),
        ]),
        _Section('SLDialog / SLToast', [
          SLButton(
            label: l.settingsResetData,
            color: SLColors.dangerSoft,
            icon: 'warning',
            onPressed: () => showSLDialog<void>(context, builder: (ctx) => _sampleDialog(ctx)),
          ),
          SLButton(
            label: l.questsTitle,
            variant: SLButtonVariant.secondary,
            onPressed: () => showSLDialog<void>(
              context,
              builder: (ctx) => SLDialog(
                title: l.questsTitle,
                showClose: true,
                style: SLPanelStyle.wood,
                child: Column(children: [for (var i = 0; i < 12; i++) Text('${l.questEarnStars(i + 3)} · ${l.questProgress(i, 12)}')]),
              ),
            ),
          ),
          SLButton(label: 'Toast OK', height: 48, color: SLColors.mint, onPressed: () => SLToast.show(context, l.settingsResetDone)),
          SLButton(
            label: 'Toast i',
            height: 48,
            color: SLColors.butter,
            onPressed: () => SLToast.show(context, l.storeSimulatedNotice, kind: SLToastKind.info),
          ),
          SLButton(
            label: 'Toast !',
            height: 48,
            color: SLColors.dangerSoft,
            onPressed: () => SLToast.show(context, l.commonNotEnoughCoins, kind: SLToastKind.warning),
          ),
        ]),
        _Section('SLTooltip — mẩu giấy (giữ lâu / rê chuột)', [
          SLTooltip(message: l.storeSimulatedNotice, child: SLChip(label: l.dayOrderToppings, icon: 'info')),
          _Labeled(
            'xem tĩnh (SLTooltipDecoration)',
            DecoratedBox(
              decoration: const SLTooltipDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(l.storeSimulatedNotice, style: SLTextStyles.of(context).caption.copyWith(fontSize: 15)),
              ),
            ),
          ),
        ]),
        _Section('Hiệu ứng (lắc / lấp lánh / nảy vào)', [
          SLShake(
            trigger: _shake,
            child: SLButton(label: l.commonNotEnoughCoins, color: SLColors.butter, onPressed: () => setState(() => _shake++)),
          ),
          SLSparkle(size: 40, trigger: _sparkle),
          SLButton(label: 'Lấp lánh', height: 48, variant: SLButtonVariant.secondary, onPressed: () => setState(() => _sparkle++)),
          SLBounceIn(key: ValueKey(_sparkle), child: SLPaperCard(attach: SLAttach.pin, child: Text(l.commonClaimed))),
        ]),
        _Section('SLDialog (xem tĩnh)', [_sampleDialog(context)]),
      ],
    );
  }

  Widget _sampleDialog(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLDialog(
      title: l.settingsResetConfirmTitle,
      titleColor: SLColors.dangerSoft,
      showClose: true,
      actions: [
        SLButton(label: l.commonCancel, variant: SLButtonVariant.secondary, width: 180, onPressed: () => Navigator.of(context).maybePop()),
        SLButton(label: l.settingsResetData, color: SLColors.dangerSoft, onPressed: () => Navigator.of(context).maybePop()),
      ],
      child: Column(
        children: [
          const SLIcon('warning', size: 56),
          const SizedBox(height: 10),
          Text(l.settingsResetConfirmBody),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ Trang 4

class _IconsPage extends StatelessWidget {
  const _IconsPage();

  @override
  Widget build(BuildContext context) {
    final caption = SLTextStyles.of(context).caption;
    String source(String id) => switch (slIconSource(id)) {
          SLIconSource.image => 'ảnh',
          SLIconSource.drawn => 'code',
          SLIconSource.generic => 'chung',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('${kSLIconIds.length} icon — "ảnh" = ảnh vẽ tay, "code" = vẽ bằng code, "chung" = hình dự phòng chung', [
          for (final id in kSLIconIds)
            SizedBox(
              width: 104,
              child: Column(
                children: [
                  SLIcon(id, size: 48),
                  const SizedBox(height: 4),
                  Text(id, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption.copyWith(fontSize: 12)),
                  Text(source(id), style: caption.copyWith(fontSize: 11, color: SLColors.inkSoft)),
                ],
              ),
            ),
        ], spacing: 6),
        _Section('SLArtIcon — ảnh vẽ tay khi đã nạp, chưa có → SLIcon; mờ', [
          for (final (art, id) in [(ArtSprites.book, 'book'), (ArtSprites.giftDaily, 'gift'), (ArtSprites.oven(1), 'oven'), (ArtSprites.ticket, 'ticket')])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SLArtIcon(art, id, size: 48),
                const SizedBox(width: 6),
                SLArtIcon(art, id, size: 48, dimmed: true),
                const SizedBox(width: 6),
                SLIcon(id, size: 48),
              ],
            ),
        ]),
        _Section('Cỡ 20 / 28 / 40 / 64 và trạng thái mờ', [
          for (final id in const ['settings', 'heart', 'umbrella', 'paw', 'sun'])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in const [20.0, 28.0, 40.0, 64.0]) SLIcon(id, size: s),
                SLIcon(id, size: 40, dimmed: true),
              ],
            ),
        ]),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ Trang 5

class _ColorsPage extends StatelessWidget {
  const _ColorsPage();

  static const _tokens = <(String, Color)>[
    ('cream', SLColors.cream),
    ('paper', SLColors.paper),
    ('paperShade', SLColors.paperShade),
    ('woodLight', SLColors.woodLight),
    ('wood', SLColors.wood),
    ('woodDark', SLColors.woodDark),
    ('strawberry', SLColors.strawberry),
    ('strawberryLight', SLColors.strawberryLight),
    ('mint', SLColors.mint),
    ('mintLight', SLColors.mintLight),
    ('butter', SLColors.butter),
    ('butterLight', SLColors.butterLight),
    ('caramel', SLColors.caramel),
    ('dangerSoft', SLColors.dangerSoft),
    ('good', SLColors.good),
    ('bad', SLColors.bad),
    ('disabledFill', SLColors.disabledFill),
    ('badDeep', SLColors.badDeep),
    ('goodDeep', SLColors.goodDeep),
    ('inkSoft', SLColors.inkSoft),
    ('ink', SLColors.ink),
  ];

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('Token màu — tỉ lệ tương phản với chữ mực (#5A3E36) / chữ kem', [
          for (final (name, c) in _tokens)
            SizedBox(
              width: 180,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 56,
                    child: SLSurface(
                      spec: SLSurfaceSpec(shape: const SLRoundRect(12), material: SLMaterial.wash, color: c, seed: name.length),
                      child: Center(child: Text('Aa', style: styles.label.copyWith(color: slContrastRatio(SLColors.ink, c) >= 4.5 ? SLColors.ink : SLColors.cream))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: styles.caption),
                        Text(hex(c), style: styles.caption.copyWith(color: SLColors.inkSoft, fontSize: 12)),
                        Text(_ratio(c), style: styles.caption.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ]),
        _Section('Chữ', [
          Text('Tiêu đề / Title', style: styles.heading),
          Text('Tiêu đề hộp thoại', style: styles.title),
          Text('Chữ nút', style: styles.label),
          Text('Nội dung: Tiệm bánh nhỏ xinh bên bờ biển', style: styles.body),
          Text('Chú thích', style: styles.caption),
          Text('Chữ phụ (inkSoft)', style: styles.body.copyWith(color: SLColors.inkSoft)),
        ]),
      ],
    );
  }

  static String _ratio(Color c) {
    final ink = slContrastRatio(SLColors.ink, c), cream = slContrastRatio(SLColors.cream, c);
    String tag(double r) => r >= 4.5 ? 'AA' : (r >= 3 ? 'AA lớn' : 'không');
    return 'mực ${ink.toStringAsFixed(1)} ${tag(ink)} · kem ${cream.toStringAsFixed(1)} ${tag(cream)}';
  }
}

// ------------------------------------------------------------------------------------------------ Trang 6

/// Thử độ hợp của bộ SL* với ảnh nền màu nước `menu_bg`.
class _OnScenePage extends StatelessWidget {
  const _OnScenePage();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ArtCanvas(
            repaintKey: 'menu_bg',
            repaint: ArtSprites.changes,
            paint: (c, s) => paintArtRef(c, Offset.zero & s, ArtSprites.scene(ArtScene.menu), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          left: 40,
          top: 40,
          width: 520,
          child: SLPanel(
            title: 'Sugarleaf Bakery',
            titleColor: SLColors.butter,
            titleIcon: 'leaf_logo',
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
            child: Text(l.menuTagline, textAlign: TextAlign.center, style: SLTextStyles.of(context).body.copyWith(fontSize: 20)),
          ),
        ),
        Positioned(
          right: 36,
          top: 24,
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SLButton(label: l.menuPlay, subtitle: l.menuDayLabel(7), icon: 'shop_bag', height: 84, onPressed: _noop),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: SLButton(label: l.menuRecipeBook, color: SLColors.butter, icon: 'leaf_logo', onPressed: _noop)),
                  const SizedBox(width: 14),
                  Expanded(child: SLButton(label: l.menuUpgrades, color: SLColors.mint, icon: 'flame', onPressed: _noop)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: SLButton(label: l.menuDecor, color: SLColors.strawberryLight, icon: 'decor_chair', onPressed: _noop)),
                  const SizedBox(width: 14),
                  Expanded(child: SLButton(label: l.menuStore, variant: SLButtonVariant.secondary, icon: 'shop_bag', onPressed: _noop)),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 330,
          top: 230,
          child: SLSpeechBubble(tail: SLTail.left, tailAt: 0.6, maxWidth: 300, child: Text(l.dayRemakeLine)),
        ),
        Positioned(
          right: 60,
          bottom: 30,
          child: SLOrderTicket(
            width: 240,
            tilt: -0.03,
            header: Text(l.dayOrderTitle, style: SLTextStyles.of(context).title.copyWith(fontSize: 22)),
            child: Text(l.orderLineVip('macaron'), style: SLTextStyles.of(context).body),
          ),
        ),
        Positioned(
          left: 40,
          bottom: 30,
          child: Row(
            children: [
              SLButton.icon(icon: 'quest_board', tooltip: l.menuQuests, badge: const SLBadge.dot(), onPressed: _noop),
              const SizedBox(width: 16),
              SLButton.icon(icon: 'heart', tooltip: l.menuLoginGift, color: SLColors.strawberryLight, onPressed: _noop),
              const SizedBox(width: 16),
              SizedBox(width: 260, child: SLProgressBar(value: 0.14, color: SLColors.butter, label: l.menuXpProgress(45, 320))),
            ],
          ),
        ),
      ],
    );
  }
}
