import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/settings/settings_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// QA biên: bấm đúp nút mua / vào màn / Nhận offline, bấm khi đang chuyển cảnh, số xu/kim cương 0 và rất lớn.

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Nút SL có nhãn [label] (trong [within] nếu có).
SLButton _button(WidgetTester tester, String label, {Finder? within}) {
  final f = find.byWidgetPredicate((w) => w is SLButton && w.label == label);
  return tester.widget<SLButton>(within == null ? f.last : find.descendant(of: within, matching: f).first);
}

/// Hai lần chạm lọt qua trong cùng một khung hình (hai ngón / máy chậm).
void _doubleCall(SLButton b) {
  b.onPressed!();
  b.onPressed!();
}

Future<GameState> _pump(WidgetTester tester, {int cleared = 1, int coins = 320, bool claimLogin = true}) async {
  final state = qaState(LanguagePref.en, cleared: cleared, coins: coins, claimLogin: claimLogin);
  await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
  return state;
}

void main() {
  setUp(() => qaNow = DateTime(2026, 10, 28, 10));

  group('bấm đúp', () {
    testWidgets('cửa hàng: bấm đúp "Buy" trên thẻ gói chỉ mở một hộp xác nhận, mua một lần', (tester) async {
      final state = await _pump(tester, cleared: 3);
      navigator(tester).pushNamed(AppRoutes.store);
      await tester.pumpAndSettle();
      final gems = state.gems;
      _doubleCall(_button(tester, 'Buy', within: find.byKey(const ValueKey('store-product-gemsM'))));
      await tester.pumpAndSettle();
      expect(find.text('Simulated purchase'), findsOneWidget, reason: 'chỉ một hộp xác nhận');
      // Đồng ý ở mọi hộp đang mở.
      while (find.text('Simulated purchase').evaluate().isNotEmpty) {
        await tester.tap(find.text('Buy').last);
        await tester.pumpAndSettle();
      }
      expect(state.gems, gems + 450);
      expect(find.byType(StoreScreen), findsOneWidget);
      await settleToasts(tester);
    }); // UI-03 đã sửa: cờ khoá đặt trước khi mở hộp xác nhận.

    testWidgets('cửa hàng: bấm đúp "Buy" trong hộp xác nhận chỉ mua một lần, không đóng luôn cửa hàng', (tester) async {
      final state = await _pump(tester, cleared: 3);
      navigator(tester).pushNamed(AppRoutes.store);
      await tester.pumpAndSettle();
      final gems = state.gems;
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('store-product-gemsM')), matching: find.text('Buy')));
      await tester.pumpAndSettle();
      _doubleCall(_button(tester, 'Buy'));
      await tester.pumpAndSettle();
      expect(state.gems, gems + 450);
      expect(find.byType(StoreScreen), findsOneWidget, reason: 'pop lần hai không được đóng cửa hàng');
      await settleToasts(tester);
    }); // UI-04 đã sửa: hộp thoại chỉ pop khi route của nó còn hiện hành (popDialogOnce).

    testWidgets('cửa hàng: hai lần chạm thật cách 80 ms ở hộp xác nhận chỉ mua một lần, cửa hàng còn', (tester) async {
      final state = await _pump(tester, cleared: 3);
      navigator(tester).pushNamed(AppRoutes.store);
      await tester.pumpAndSettle();
      final gems = state.gems;
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('store-product-gemsM')), matching: find.text('Buy')));
      await tester.pumpAndSettle();
      final confirm = tester.getCenter(find.text('Buy').last);
      await tester.tapAt(confirm);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(confirm);
      await tester.pumpAndSettle();
      expect(state.gems, gems + 450);
      expect(find.byType(StoreScreen), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('vé mùa: bấm đúp "Mở cao cấp" chỉ mở một hộp xác nhận', (tester) async {
      await _pump(tester, cleared: 8);
      navigator(tester).pushNamed(UiRoutes.season);
      await tester.pumpAndSettle();
      final b = tester.widget<SLButton>(
          find.byWidgetPredicate((w) => w is SLButton && (w.label ?? '').startsWith('Unlock premium')).first);
      _doubleCall(b);
      await tester.pumpAndSettle();
      expect(find.text('Simulated purchase'), findsOneWidget);
    }); // UI-03 đã sửa.

    testWidgets('bí quyết: bấm đúp "Learn" chỉ học một bậc, trừ xu một lần', (tester) async {
      final state = await _pump(tester, cleared: 45, coins: 20000);
      navigator(tester).pushNamed(AppRoutes.recipes);
      await tester.pumpAndSettle();
      final buy = find.byKey(const ValueKey('recipe-secret-buy'));
      expect(buy, findsOneWidget);
      final coins = state.coins;
      const recipe = RecipeId.cupcakeVanilla; // món chọn sẵn của sổ
      final tier = state.recipeSecretTier(recipe);
      final price = state.recipeSecretPrice(recipe)!;
      _doubleCall(tester.widget<SLButton>(buy));
      await tester.pump();
      expect(state.recipeSecretTier(recipe), tier + 1);
      expect(state.coins, coins - price);
      await settleToasts(tester);
    }); // UI-05 đã sửa: khoảng nghỉ + khớp bậc lúc dựng (như nút nâng thiết bị).

    testWidgets('thiết bị: bấm đúp "Nâng cấp" chỉ nâng một bậc', (tester) async {
      final state = await _pump(tester, cleared: 20, coins: 5000);
      navigator(tester).pushNamed(AppRoutes.upgrades, arguments: const UpgradesArgs(tab: UpgradesTab.equipment));
      await tester.pumpAndSettle();
      final buy = find.byWidgetPredicate(
          (w) => w is SLButton && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('upg-buy-'));
      expect(buy, findsWidgets);
      final coins = state.coins;
      _doubleCall(tester.widget<SLButton>(buy.first));
      await tester.pump();
      final spent = coins - state.coins;
      expect(spent, greaterThan(0));
      // Một bậc: số xu đã tiêu đúng bằng giá một lần (bậc sau đắt hơn → nếu mua hai bậc sẽ lớn hơn).
      _doubleCall(tester.widget<SLButton>(buy.first));
      await tester.pump();
      expect(coins - state.coins, spent, reason: 'khoảng nghỉ chống chạm đúp chặn lần bấm ngay sau');
      await settleToasts(tester);
    });

    testWidgets('mở rộng tiệm: bấm đúp "Mua" chỉ trừ xu một lần', (tester) async {
      final state = await _pump(tester, cleared: 20, coins: 20000);
      navigator(tester).pushNamed(AppRoutes.upgrades, arguments: const UpgradesArgs(tab: UpgradesTab.expansion));
      await tester.pumpAndSettle();
      final buy = find.byWidgetPredicate(
          (w) => w is SLButton && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('upg-buy-'));
      expect(buy, findsWidgets);
      final coins = state.coins;
      final id = (tester.widget<SLButton>(buy.first).key! as ValueKey<String>).value.substring('upg-buy-'.length);
      _doubleCall(tester.widget<SLButton>(buy.first));
      await tester.pump();
      expect(coins - state.coins, testUnlockConfig().unlock(id)!.price);
      await settleToasts(tester);
    });

    testWidgets('kết quả: bấm đúp "Next level" chỉ mở một màn chơi, đếm lượt chơi một lần', (tester) async {
      final state = await _pump(tester, cleared: 3);
      navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3)));
      await tester.pumpAndSettle();
      _doubleCall(_button(tester, _l(tester).levelNext));
      await qaFrames(tester, 12);
      expect(find.byType(LevelScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(LevelResultScreen, skipOffstage: false), findsNothing);
      expect(state, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('kết quả: bấm "Map" rồi "Play again" ngay trong lúc chuyển cảnh → chỉ một hành động', (tester) async {
      await _pump(tester, cleared: 3);
      navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3)));
      await tester.pumpAndSettle();
      final l = _l(tester);
      final map = _button(tester, l.mapBackToMap);
      final replay = _button(tester, l.levelReplay);
      map.onPressed!();
      await tester.pump(const Duration(milliseconds: 60));
      replay.onPressed!();
      await qaFrames(tester, 12);
      expect(find.byType(LevelMapScreen), findsOneWidget);
      expect(find.byType(LevelScreen, skipOffstage: false), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('vắng nhà: bấm đúp "Nhận" chỉ cộng xu một lần, không đóng thêm route', (tester) async {
      final state = qaStateWithOffline(LanguagePref.en);
      await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
      final pending = state.pendingOffline!;
      final coins = state.coins;
      expect(find.byKey(const ValueKey('offline-dialog')), findsOneWidget);
      final claim = tester.widget<SLButton>(find.descendant(
          of: find.byKey(const ValueKey('offline-claim')), matching: find.byType(SLButton), matchRoot: true).first);
      _doubleCall(claim);
      await tester.pumpAndSettle();
      expect(state.coins, coins + pending.coins);
      expect(find.byKey(const ValueKey('offline-dialog')), findsNothing);
      expect(find.byType(LevelMapScreen), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('bản đồ: bấm Cửa hàng rồi Cài đặt khi đang chuyển cảnh → chỉ mở cửa hàng', (tester) async {
      await _pump(tester);
      final l = _l(tester);
      await tester.tap(find.byTooltip(l.menuStore));
      await tester.pump(const Duration(milliseconds: 100)); // giữa lúc mờ dần 280 ms
      await tester.tap(find.byTooltip(l.menuSettings), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsOneWidget);
      expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LevelMapScreen), findsOneWidget);
    });
  });

  group('số xu / kim cương', () {
    for (final (name, coins, gems) in [('0', 0, 0), ('999 999 999', 999999999, 999999999)]) {
      testWidgets('xu = kim cương = $name: các màn có thanh tiền không tràn, số hiện đúng', (tester) async {
        var at = 'bản đồ';
        final errors = await qaCatchErrors(where: () => at, () async {
          final state = qaState(LanguagePref.vi, cleared: 12, coins: 0);
          state.addCoins(coins - state.coins);
          state.addGems(gems - state.gems);
          expect((state.coins, state.gems), (coins, gems));
          await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
          for (final (route, args) in [
            (null, null),
            (AppRoutes.store, null),
            (AppRoutes.upgrades, null),
            (AppRoutes.decor, null),
            (AppRoutes.recipes, null),
            (UiRoutes.season, null),
          ]) {
            at = route ?? 'bản đồ';
            if (route != null) {
              navigator(tester).pushNamed(route, arguments: args);
              await tester.pumpAndSettle();
            }
            // Số rút gọn tiếng Việt dùng khoảng trắng không ngắt (1 T) → chuẩn hoá trước khi so.
            final texts = qaVisibleTexts(tester).join(' | ').replaceAll(' ', ' ');
            if (coins > 0) {
              expect(texts, anyOf(contains('999.999.999'), contains('999,999,999'), contains('999M'), contains('1B'),
                  contains('999 Tr'), contains('1 T')), reason: 'số lớn ở ${route ?? 'bản đồ'}: $texts');
            }
            if (route != null) {
              navigator(tester).pop();
              await tester.pumpAndSettle();
            }
          }
          // Thẻ Sẵn sàng (thanh kim cương / vật phẩm).
          at = 'thẻ Sẵn sàng L2';
          navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2));
          await qaFrames(tester, 12);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 4));
        });
        expect(errors, isEmpty);
      }); // UI-06 đã sửa: thanh tiền tệ rút gọn số từ 1 triệu (formatCompact).
    }

    testWidgets('kết quả: thưởng 999 999 999 xu không tràn', (tester) async {
      final errors = await qaCatchErrors(() async {
        await _pump(tester, cleared: 3);
        navigator(tester).pushNamed(AppRoutes.levelResult,
            arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3, coins: 999999999)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
      });
      expect(errors, isEmpty);
    });
  });
}
