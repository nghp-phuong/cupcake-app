import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/gallery/ui_gallery_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'sl_test_helpers.dart';

/// Mọi thành phần SL* với chuỗi thật (dài nhất có thể) — dựng trong một Wrap 1280 rộng.
Widget _catalog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 20,
      runSpacing: 30,
      children: [
        SLButton(label: l.menuPlay, subtitle: l.menuDayLabel(7), icon: 'play_video', onPressed: () {}),
        SizedBox(width: 220, child: SLButton(label: l.dayRemakeWithAd, icon: 'play_video', onPressed: () {})),
        SizedBox(width: 200, child: SLButton(label: l.settingsResetData, color: SLColors.dangerSoft, icon: 'trash', onPressed: () {})),
        SLButton(label: l.commonBuy, onPressed: () {}, loading: true),
        SLButton(label: l.commonLocked, onPressed: null),
        SLButton.icon(icon: 'settings', tooltip: l.menuSettings, onPressed: () {}, badge: const SLBadge.dot()),
        SLButton.icon(icon: 'close', tooltip: l.commonClose, size: 40, onPressed: () {}),
        SLChip(label: l.settingsLanguageSystem, icon: 'phone', onPressed: () {}),
        SLChip(label: l.settingsLanguageVi, selected: true, onPressed: () {}),
        SLChip(label: l.dayRainy, icon: 'umbrella'),
        SizedBox(width: 160, child: SLChip(label: l.storeRemoveAdsDesc, onPressed: () {})),
        SLToggle(value: true, semanticLabel: l.settingsSound, onChanged: (_) {}),
        const SLBadge.count(120),
        const SLBadge.vip(),
        SLBadge.label(l.commonMax),
        SizedBox(
          width: 600,
          child: SLTabBar(
            tabs: [SLTabItem(l.menuRecipeBook, icon: 'leaf_logo'), SLTabItem(l.menuUpgrades), SLTabItem(l.menuDecor), SLTabItem(l.menuStore)],
            selected: 1,
            onChanged: (_) {},
            expand: true,
          ),
        ),
        SizedBox(width: 360, child: SLPanel(title: l.settingsResetConfirmTitle, child: Text(l.settingsResetConfirmBody))),
        SizedBox(width: 360, child: SLPanel(style: SLPanelStyle.wood, title: l.questsTitle, child: Text(l.storeRemoveAdsDesc))),
        SizedBox(width: 220, child: SLPaperCard(attach: SLAttach.tapeCorners, child: Text(l.storeSimulatedNotice))),
        SLOrderTicket(width: 240, header: Text(l.dayOrderTitle, maxLines: 1, overflow: TextOverflow.ellipsis), child: Text(l.orderLineVip('macaron'))),
        SLSpeechBubble(maxWidth: 300, child: Text(l.dayExitConfirmBody)),
        SLSpeechBubble(tail: SLTail.left, maxWidth: 260, child: Text(l.dayRemakeLine)),
        SLNameTag(l.storeDecorSet, icon: 'sparkle', maxWidth: 260),
        SLNameTag(l.dayExitConfirmTitle, style: SLNameTagStyle.wood, maxWidth: 220),
        SizedBox(width: 260, child: SLProgressBar(value: 0.4, label: l.menuXpProgress(45, 320))),
        SizedBox(
          width: 1200,
          child: SLTopBar(
            leading: SLButton.icon(icon: 'back', tooltip: l.commonBack, onPressed: () {}),
            title: SLNameTag(l.menuShopLevel(12)),
            children: [
              SLTopBarItem(value: '12.828', icon: 'heart', onPressed: () {}, semanticLabel: l.commonCoins(12828)),
              const SLTopBarItem(value: '67', icon: 'sparkle'),
            ],
          ),
        ),
        SLDialog(
          title: l.settingsResetConfirmTitle,
          showClose: true,
          actions: [
            SLButton(label: l.commonCancel, variant: SLButtonVariant.secondary, onPressed: () {}),
            SLButton(label: l.settingsResetData, color: SLColors.dangerSoft, onPressed: () {}),
          ],
          child: Text(l.settingsResetConfirmBody),
        ),
      ],
    ),
  );
}

void main() {
  for (final locale in [kEn, kVi]) {
    testWidgets('mọi thành phần dựng được, không tràn ($locale)', (tester) async {
      await pumpSL(tester, _catalog, locale: locale, size: const Size(1280, 2400));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byType(SLButton), findsWidgets);
    });

    testWidgets('Gallery: mọi trang dựng được ($locale)', (tester) async {
      for (var p = 0; p < UiGalleryScreen.pages.length; p++) {
        await pumpSL(tester, (_) => UiGalleryScreen(key: ValueKey(p), initialPage: p, initialLocale: locale), locale: locale);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'trang $p');
      }
    });
  }

  testWidgets('vùng chạm ≥ 48 (Android tap target guideline)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSL(
      tester,
      (context) => Center(
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            SLButton(label: 'OK', height: 30, onPressed: () {}),
            SLButton.icon(icon: 'close', tooltip: 'Close', size: 30, onPressed: () {}),
            SLChip(label: 'A', onPressed: () {}),
            SLToggle(value: false, semanticLabel: 'Sound', onChanged: (_) {}),
            SLTabBar(tabs: const [SLTabItem('A'), SLTabItem('B')], selected: 0, onChanged: (_) {}),
            SLTopBarItem(value: '1', icon: 'heart', semanticLabel: 'coins', onPressed: () {}),
          ],
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    for (final f in [find.byType(SLButton), find.byType(SLChip), find.byType(SLToggle)]) {
      for (final e in f.evaluate()) {
        final size = (e.renderObject! as RenderBox).size;
        expect(size.width >= 48 && size.height >= 48, isTrue, reason: '${e.widget.runtimeType} $size');
      }
    }
    handle.dispose();
  });

  testWidgets('SLButton: bấm gọi onPressed; tắt / đang tải thì không', (tester) async {
    var taps = 0;
    await pumpSL(
      tester,
      (_) => Column(
        children: [
          SLButton(label: 'Go', onPressed: () => taps++),
          SLButton(label: 'Off', onPressed: null),
          SLButton(label: 'Wait', loading: true, onPressed: () => taps += 100),
          SLButton.icon(icon: 'settings', tooltip: 'Settings', onPressed: () => taps += 10),
        ],
      ),
    );
    // Có nút đang tải (chấm chạy lặp) → không dùng pumpAndSettle.
    await tester.tap(find.text('Go'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, 1);
    await tester.tap(find.text('Off'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Wait'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, 11);
  });

  testWidgets('SLButton: nhấn lún xuống rồi nảy về', (tester) async {
    await pumpSL(tester, (_) => Center(child: SLButton(label: 'Go', onPressed: () {})));
    final before = tester.getTopLeft(find.text('Go'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 110)); // hạn chờ chạm (kPressTimeout).
    await tester.pump(const Duration(milliseconds: 100)); // lún xong.
    final pressed = tester.getTopLeft(find.text('Go'));
    expect(pressed.dy - before.dy, closeTo(SLMetrics.pressDepth, 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Go')), before);
  });

  testWidgets('tắt hiệu ứng: nhấn không chạy animation', (tester) async {
    await pumpSL(tester, (_) => Center(child: SLButton(label: 'Go', onPressed: () {})), reduceMotion: true);
    final before = tester.getTopLeft(find.text('Go'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 150)); // quá hạn chờ chạm.
    expect(tester.getTopLeft(find.text('Go')).dy - before.dy, closeTo(SLMetrics.pressDepth, 0.01));
    await gesture.up();
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('SLButton.icon: tooltip + nhãn Semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSL(tester, (_) => Center(child: SLButton.icon(icon: 'back', tooltip: 'Back', onPressed: () {})));
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Back')), containsSemantics(label: 'Back', isButton: true, isEnabled: true, hasTapAction: true));
    handle.dispose();
  });

  testWidgets('SLToggle: đổi trạng thái + Semantics toggled', (tester) async {
    final handle = tester.ensureSemantics();
    var value = false;
    await pumpSL(
      tester,
      (_) => StatefulBuilder(
        builder: (context, setState) => Center(
          child: SLToggle(value: value, semanticLabel: 'Sound', onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('Sound')), containsSemantics(hasToggledState: true, isToggled: false));
    await tester.tap(find.byType(SLToggle));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Sound')), containsSemantics(hasToggledState: true, isToggled: true));
    await tester.tap(find.byType(SLToggle));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    handle.dispose();
  });

  testWidgets('SLChip / SLTabBar: Semantics selected, bấm đổi lựa chọn', (tester) async {
    final handle = tester.ensureSemantics();
    var tab = 0;
    await pumpSL(
      tester,
      (_) => StatefulBuilder(
        builder: (context, setState) => Column(
          children: [
            SLChip(label: 'Chip', selected: true, onPressed: () {}),
            SLTabBar(tabs: const [SLTabItem('One'), SLTabItem('Two')], selected: tab, onChanged: (i) => setState(() => tab = i)),
          ],
        ),
      ),
    );
    expect(tester.getSemantics(find.text('Chip')), containsSemantics(isSelected: true, isButton: true));
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(tab, 1);
    expect(tester.getSemantics(find.text('Two')), containsSemantics(isSelected: true));
    handle.dispose();
  });

  testWidgets('showSLDialog: mở nảy, đóng bằng nút Close', (tester) async {
    await pumpSL(
      tester,
      (context) => Center(
        child: SLButton(
          label: 'Open',
          onPressed: () => showSLDialog<void>(context, builder: (_) => const SLDialog(title: 'Title', showClose: true, child: Text('Body'))),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Body'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsNothing);
  });

  testWidgets('SLToast: hiện qua Overlay rồi tự ẩn', (tester) async {
    await pumpSL(
      tester,
      (context) => Center(child: SLButton(label: 'Toast', onPressed: () => SLToast.show(context, 'Saved!'))),
    );
    await tester.tap(find.text('Toast'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved!'), findsOneWidget);
    await tester.pump(SLMetrics.toastShow);
    await tester.pumpAndSettle();
    expect(find.text('Saved!'), findsNothing);
  });

  testWidgets('seed mặc định ổn định giữa các lần dựng', (tester) async {
    expect(slSeed(content: 'Play'), slSeed(content: 'Play'));
    expect(slSeed(key: const ValueKey('a'), content: 'Play'), isNot(slSeed(content: 'Play')));
    expect(slSeed(seed: 3, content: 'Play'), 3);
  });

  testWidgets('SLPanel có tiêu đề: thân nhận bề ngang của cha (không co theo nội dung)', (tester) async {
    await pumpSL(
      tester,
      (_) => const Center(
        child: SizedBox(
          width: 500,
          child: SLPanel(key: ValueKey('panel'), title: 'Title', child: Text('Hi')),
        ),
      ),
    );
    final surface = find.descendant(of: find.byKey(const ValueKey('panel')), matching: find.byType(SLSurface)).first;
    expect(tester.getSize(surface).width, 500);
  });

  testWidgets('SLTabBar iconAbove: icon trên chữ, chữ 2 dòng, selected', (tester) async {
    final handle = tester.ensureSemantics();
    var tab = 0;
    await pumpSL(
      tester,
      (_) => StatefulBuilder(
        builder: (context, setState) => Center(
          child: SizedBox(
            width: 420,
            height: 82,
            child: SLTabBar(
              tabs: const [SLTabItem('Wallpaper', icon: 'slot_wallpaper'), SLTabItem('Long counter label', icon: 'slot_counter')],
              selected: tab,
              onChanged: (i) => setState(() => tab = i),
              expand: true,
              iconAbove: true,
              height: 82,
            ),
          ),
        ),
      ),
    );
    final icon = tester.getRect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'slot_counter'));
    final label = tester.getRect(find.text('Long counter label'));
    expect(icon.bottom, lessThanOrEqualTo(label.top));
    expect(tester.widget<Text>(find.text('Long counter label')).maxLines, 2);
    await tester.tap(find.text('Long counter label'));
    await tester.pumpAndSettle();
    expect(tab, 1);
    expect(tester.getSemantics(find.text('Long counter label')), containsSemantics(isSelected: true));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('SLButton chữ: tooltip giấy + nhãn đọc màn hình riêng', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSL(
      tester,
      (_) => Center(child: SLButton(label: 'Buy', tooltip: 'Simulated', semanticLabel: 'Buy pack', onPressed: () {})),
    );
    expect(find.byTooltip('Simulated'), findsOneWidget);
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).decoration, isA<SLTooltipDecoration>());
    expect(find.bySemanticsLabel('Buy pack'), findsOneWidget);
    expect(find.bySemanticsLabel('Buy'), findsNothing);
    handle.dispose();
  });

  testWidgets('SLRule / SLStamp / SLLoadingDots / SLArtIcon dựng được', (tester) async {
    await pumpSL(
      tester,
      (_) => const Column(
        children: [
          SizedBox(width: 300, child: SLRule(echo: SLRuleEcho.partial)),
          SizedBox(width: 300, child: SLRule(height: 28, echo: SLRuleEcho.full, rise: 1)),
          SLStamp(),
          SLLoadingDots(),
          SLArtIcon(ArtRef(ArtGroup.items, 'book'), 'book', size: 40, dimmed: true),
        ],
      ),
    );
    expect(tester.getSize(find.byType(SLRule).first), const Size(300, 14));
    expect(tester.getSize(find.byType(SLStamp)), const Size(48, 48));
    // Chưa nạp ảnh → icon vẽ bằng code theo id.
    expect(tester.widget<SLIcon>(find.descendant(of: find.byType(SLArtIcon), matching: find.byType(SLIcon))).id, 'book');
    expect(tester.takeException(), isNull);
  });
}
