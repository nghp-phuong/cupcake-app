import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/common/art.dart';
import 'package:sugarleaf_bakery/ui/common/currency_bar.dart';
import 'package:sugarleaf_bakery/ui/common/sugar_screen.dart';
import 'package:sugarleaf_bakery/ui/common/wide_layout.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// Khung rộng (máy 20:9): khung cao 720, rộng W = 1280–1600. Nền trải hết W, thanh trên / nút quay lại / tiền bám
/// mép (lùi khỏi tai thỏ), nội dung ở vùng 1280 giữa; khung 1280 giữ nguyên bố cục cũ.

/// Màn phụ dùng [SugarScreen] (thanh gỗ + thân 1280 giữa).
final _sugarRoutes = <String, (int, String, Object?)>{
  'nâng cấp': (40, AppRoutes.upgrades, null),
  'trang trí': (20, AppRoutes.decor, null),
  'sổ công thức': (45, AppRoutes.recipes, null),
  'cửa hàng': (5, AppRoutes.store, null),
  'vé mùa': (8, UiRoutes.season, null),
  'cài đặt': (1, AppRoutes.settings, null),
};

Future<void> _open(WidgetTester tester, Size size, {int cleared = 12, String? route, Object? args}) async {
  final state = qaState(LanguagePref.vi, cleared: cleared);
  await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
  if (route != null) {
    navigator(tester).pushNamed(route, arguments: args);
    await tester.pumpAndSettle();
  }
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Cảnh chơi (Flame) chạy liên tục: không dùng pumpAndSettle khi LevelScreen đang mở.
Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Nút level đầu tiên đang hiện trên bản đồ (key `map-level-<id>`).
Key _firstNode(WidgetTester tester) => tester
    .widgetList(find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('map-level-')))
    .first
    .key!;

void main() {
  setUp(() => qaNow = DateTime(2026, 10, 28, 10));

  group('màn phụ (SugarScreen)', () {
    for (final e in _sugarRoutes.entries) {
      testWidgets('${e.key}: 1280 như cũ; 1600 thanh bám mép, thân 1280 giữa, không tràn', (tester) async {
        final errors = await qaCatchErrors(() async {
          await _open(tester, const Size(1280, 720), cleared: e.value.$1, route: e.value.$2, args: e.value.$3);
        });
        expect(errors, isEmpty);
        final screen = find.byType(SugarScreen);
        final back = find.byTooltip(_l(tester).commonBack);
        final currency = find.descendant(of: screen, matching: find.byType(CurrencyBar));
        final body = find.descendant(of: screen, matching: find.byType(RefContent)).first;
        // 1280: thân phủ cả khung dưới thanh gỗ, nút quay lại ở x = 20.
        expect(MediaQuery.sizeOf(tester.element(screen)), const Size(1280, 720));
        expect(tester.getRect(back).left, closeTo(20, 1));
        expect(tester.getRect(body), const Rect.fromLTWH(0, kScreenHeaderHeight, 1280, 720 - kScreenHeaderHeight));
        final coins1280 = currency.evaluate().isEmpty ? null : tester.getRect(currency.first);

        errors.addAll(await qaCatchErrors(() async {
          tester.view.physicalSize = const Size(1600, 720);
          await tester.pumpAndSettle();
        }));
        expect(errors, isEmpty);
        expect(MediaQuery.sizeOf(tester.element(screen)), const Size(1600, 720));
        // Nút quay lại bám mép trái; tiền dời đúng W − 1280 (giữ khoảng cách tới mép phải như khung 1280).
        expect(tester.getRect(back).left, closeTo(20, 1));
        if (coins1280 != null) {
          final coins = tester.getRect(currency.first);
          expect(coins.right, closeTo(coins1280.right + 320, 0.5));
          expect(coins.top, closeTo(coins1280.top, 0.5));
        }
        // Thân màn: vùng 1280 giữa, MediaQuery bên trong 1280×720 (nội dung không giãn).
        expect(tester.getRect(body), const Rect.fromLTWH(160, kScreenHeaderHeight, 1280, 720 - kScreenHeaderHeight));
        final inner = find.descendant(of: body, matching: find.byWidgetPredicate((_) => true)).evaluate().last;
        expect(MediaQuery.sizeOf(inner), const Size(1280, 720));
        await _close(tester);
      });
    }
  });

  group('bản đồ', () {
    testWidgets('1600×720: nút màn trong vùng 1280 giữa, thanh trên + mũi tên chương bám mép', (tester) async {
      await _open(tester, const Size(1280, 720));
      final key = _firstNode(tester);
      final node1280 = tester.getCenter(find.byKey(key));
      final stars1280 = tester.getRect(find.byKey(const ValueKey('map-total-stars')));
      final settings1280 = tester.getRect(find.byTooltip(_l(tester).menuSettings).first);
      final errors = await qaCatchErrors(() async {
        tester.view.physicalSize = const Size(1600, 720);
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
      expect(MediaQuery.sizeOf(tester.element(find.byType(LevelMapScreen))), const Size(1600, 720));
      final node = tester.getCenter(find.byKey(key));
      expect(node.dx, closeTo(node1280.dx + 160, 0.5));
      expect(node.dy, closeTo(node1280.dy, 0.5));
      // Nhãn sao bám mép trái như cũ; nút Cài đặt bám mép phải W.
      expect(tester.getRect(find.byKey(const ValueKey('map-total-stars'))).left, closeTo(stars1280.left, 0.5));
      expect(tester.getRect(find.byTooltip(_l(tester).menuSettings).first).right, closeTo(settings1280.right + 320, 0.5));
      for (final (k, edge) in const [('map-prev', 14.0), ('map-next', 1600 - 14.0)]) {
        final arrow = find.byKey(ValueKey(k));
        if (arrow.evaluate().isEmpty) continue;
        final r = tester.getRect(arrow);
        expect(k == 'map-prev' ? r.left : r.right, closeTo(edge, 1));
      }
      await _close(tester);
    });
  });

  group('màn chơi', () {
    testWidgets('1600×720: HUD bám mép (pause trái, ô xu dời W − 1280), thẻ Sẵn sàng giữa', (tester) async {
      Future<(Offset, Rect, Rect)> hud(Size size) async {
        await _open(tester, size, cleared: 1);
        navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2));
        await _frames(tester);
        final l = _l(tester);
        final start = tester.getCenter(find.text(l.levelStart));
        expect(tester.getRect(find.byTooltip(l.commonBack)).left, closeTo(20, 1));
        await tester.tap(find.text(l.levelStart));
        await _frames(tester);
        expect(MediaQuery.sizeOf(tester.element(find.byType(LevelScreen))), size);
        final pause = tester.getRect(find.byTooltip(l.levelPause));
        // Ô xu của HUD (màn chơi không có CurrencyBar).
        final coins = tester.getRect(find.byWidgetPredicate((w) => w is SLTopBarItem && w.leading is CoinIcon));
        await _close(tester);
        return (start, pause, coins);
      }

      final (start1280, pause1280, coins1280) = await hud(const Size(1280, 720));
      final (start, pause, coins) = await hud(const Size(1600, 720));
      expect(start.dx, closeTo(start1280.dx + 160, 0.5));
      expect(pause.left, closeTo(pause1280.left, 0.5));
      expect(coins.left, closeTo(coins1280.left + 320, 0.5));
      expect(coins.top, closeTo(coins1280.top, 0.5));
    });
  });

  group('tai thỏ', () {
    // Máy 20:9 thật có tai thỏ ngang: khung rộng (nền tràn dưới tai thỏ), nút bám mép lùi vào vùng an toàn.
    const devices = [
      qaNotch20x9,
      QaViewport('2340x1080@2.75+notch', Size(2340, 1080), dpr: 2.75, notch: 48),
    ];
    for (final vp in devices) {
      testWidgets('$vp: nút quay lại / tiền lùi khỏi tai thỏ ở màn phụ', (tester) async {
        await _open(tester, const Size(1280, 720), cleared: 40, route: AppRoutes.upgrades);
        vp.apply(tester);
        await tester.pumpAndSettle();
        final w = vp.logical.width;
        expect(tester.getRect(find.byTooltip(_l(tester).commonBack)).left, greaterThanOrEqualTo(vp.notch));
        expect(tester.getRect(find.byType(CurrencyBar).first).right, lessThanOrEqualTo(w - vp.notch));
        await _close(tester);
      });
    }
  });
}
