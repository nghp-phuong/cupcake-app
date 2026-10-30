import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/upgrades/unlock_notice.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'ui_test_helpers.dart';

/// Ván mới (en) đã nhận quà hôm nay, đã xem cảnh mở màn; đã qua L1..L[cleared] (không thêm xu).
GameState _state({int cleared = 0}) {
  final state = GameState.newGame()
    ..setLanguage(LanguagePref.en)
    ..claimLogin()
    ..markSceneSeen(StorySceneId.prologue);
  testServices(state); // gắn levels.json + unlocks.json thật
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: 0);
  return state;
}

final _unlocks = testUnlockConfig();
UnlockData _u(String id) => _unlocks.unlock(id)!;
EquipmentData _eq(String id) => _unlocks.equipmentById(id)!;

Finder _key(String k) => find.byKey(ValueKey(k));

/// Chấm đỏ trên nút Nâng cấp của thanh bản đồ.
Finder get _upgradesDot => find.descendant(of: _key('map-upgrades'), matching: find.byType(SLBadge));

Future<void> _openUpgrades(WidgetTester tester, {UpgradesArgs? args}) async {
  navigator(tester).pushNamed(AppRoutes.upgrades, arguments: args);
  await tester.pumpAndSettle();
}

/// Thắng [levelId] như khi chơi thật: màn kết quả → "Bản đồ" → hoạt cảnh bản đồ (+ thông báo nếu có).
Future<LevelProgressDelta> _winViaResult(WidgetTester tester, GameState state, int levelId) async {
  final result = fakeLevelResult(levelId, won: true, stars: 3, coins: 0);
  final delta = state.applyLevelResult(result);
  navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(result, progress: delta));
  await tester.pumpAndSettle();
  await tester.tap(_key('level-result-map'));
  await tester.pumpAndSettle();
  return delta;
}

void main() {
  testWidgets('mở rộng tiệm: trạng thái theo tiến trình (mua được / Sắp có / khoá theo màn / chương chưa mở mờ)', (
    tester,
  ) async {
    final caseStand = _u('case_stand');
    final state = _state(cleared: caseStand.level);
    await pumpSugarApp(tester, state);
    await _openUpgrades(tester);

    // Tab mặc định = Mở rộng tiệm.
    expect(tester.widget<SLTabBar>(_key('upg-tabs')).selected, 0);
    expect(find.text(caseStand.name('en')), findsOneWidget);
    expect(_key('upg-buy-case_stand'), findsOneWidget);
    expect(state.unlockState('case_stand'), UnlockState.available);
    // Nhân viên ở tab riêng (GĐ4); mục chương sau chưa hỗ trợ vẫn "Sắp có".
    expect(_key('upg-soon-staff_cashier'), findsNothing);
    expect(find.text('Coming soon'), findsWidgets);
    // Lò thứ 2: khoá tới khi qua màn của nó.
    final oven2 = _u('oven_2');
    expect(_key('upg-locked-oven_2'), findsOneWidget);
    expect(find.text('Clear level ${oven2.level} to unlock'), findsOneWidget);
    // Chương 2 chưa mở → nhãn + thẻ mờ.
    expect(find.text('Chapter ${oven2.chapter} is locked'), findsOneWidget);
    final dim = tester.widget<Opacity>(
      find.ancestor(of: _key('upg-locked-oven_2'), matching: find.byType(Opacity)).last,
    );
    expect(dim.opacity, lessThan(1));
    // Chương 1 (đang mở) không mờ.
    final open = tester.widgetList<Opacity>(
      find.ancestor(of: _key('upg-buy-case_stand'), matching: find.byType(Opacity)),
    );
    expect(open.every((o) => o.opacity == 1), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mua mở rộng: thiếu xu → toast, đủ xu → "Đã có" + xu giảm + dấu ✓', (tester) async {
    final caseStand = _u('case_stand');
    final state = _state(cleared: caseStand.level);
    await pumpSugarApp(tester, state);
    await _openUpgrades(tester);

    await tester.tap(_key('upg-buy-case_stand'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.unlockState('case_stand'), UnlockState.available);
    await settleToasts(tester);

    state.addCoins(caseStand.price + 50);
    await tester.pump();
    final before = state.coins;
    await tester.tap(_key('upg-buy-case_stand'));
    await tester.pumpAndSettle();
    expect(state.unlockState('case_stand'), UnlockState.owned);
    expect(state.coins, before - caseStand.price);
    expect(state.shopSetup.caseSlotsBonus, greaterThan(0));
    expect(_key('upg-owned-case_stand'), findsOneWidget);
    expect(_key('upg-buy-case_stand'), findsNothing);
    expect(find.text('Added to your bakery!'), findsOneWidget);
    expect(find.byType(SLStamp), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thiết bị: cấp hiện tại → cấp sau, khoá theo màn, nâng cấp trừ xu', (tester) async {
    final oven = _eq('fastOven');
    final tray = _eq('bigTray');
    final cleared = oven.tiers[1].level;
    expect(tray.tiers[1].level, greaterThan(cleared), reason: 'khay lớn cấp 2 cần mốc muộn hơn lò nhanh cấp 2');
    final state = _state(cleared: cleared);
    await pumpSugarApp(tester, state);
    await _openUpgrades(tester, args: const UpgradesArgs(tab: UpgradesTab.equipment));

    expect(tester.widget<SLTabBar>(_key('upg-tabs')).selected, 1);
    expect(find.text(oven.name('en')), findsOneWidget);
    expect(find.text('Tier 1/${oven.maxTier}'), findsWidgets);
    // Thông số "hiện tại → cấp sau" bỏ chữ lặp: "Bakes in 7.0s → 6.3s", "3 → 4 cakes per tray".
    expect(find.text('Bakes in 7.0s'), findsOneWidget);
    expect(find.text('6.3s'), findsOneWidget);
    expect(find.text('${tray.tiers[1].value.round()} cakes per tray'), findsOneWidget);
    expect(find.bySemanticsLabel('Next: Bakes in 6.3s'), findsOneWidget);
    expect(_key('upg-locked-bigTray'), findsOneWidget);
    expect(find.text('Clear level ${tray.tiers[1].level} to unlock'), findsWidgets);
    // Mọi thẻ thiết bị nằm gọn trong khung 1280×720 (không phải cuộn).
    for (final e in _unlocks.equipment) {
      final r = tester.getRect(_key('upg-tier-${e.id}'));
      expect(r.bottom, lessThan(720), reason: e.id);
    }

    // Thiếu xu → toast; đủ xu → cấp 2, xu giảm.
    await tester.tap(_key('upg-buy-fastOven'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.equipmentTier('fastOven'), 1);
    await settleToasts(tester);
    state.addCoins(oven.tiers[1].price);
    await tester.pump();
    final before = state.coins;
    await tester.tap(_key('upg-buy-fastOven'));
    await tester.pumpAndSettle();
    expect(state.equipmentTier('fastOven'), 2);
    expect(state.coins, before - oven.tiers[1].price);
    expect(state.shopSetup.ovenSec, oven.tiers[1].value);
    expect(find.text('Tier 2/${oven.maxTier}'), findsOneWidget);
    // Cấp 3 cần qua màn muộn hơn → khoá.
    expect(_key('upg-locked-fastOven'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlocks.json rỗng: tab thiết bị vẫn có lò + 3 dụng cụ V1 (bảng dự phòng)', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state, services: testServices(state, unlocks: UnlockConfig.empty()));
    await _openUpgrades(tester, args: const UpgradesArgs(tab: UpgradesTab.equipment));
    expect(find.text('Oven'), findsOneWidget);
    expect(find.text('Whisk'), findsOneWidget);
    expect(find.text('Perfect zone ±5%'), findsOneWidget);
    // Tab mở rộng rỗng vẫn dựng được.
    await tester.tap(find.text('Expand the bakery'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('thắng L5 → sau hoạt cảnh bản đồ hiện "Mở khoá mới!" (kệ bánh tầng) → Xem → Nâng cấp đúng thẻ', (
    tester,
  ) async {
    final caseStand = _u('case_stand');
    final state = _state(cleared: caseStand.level - 1);
    // Cấp thiết bị đã tới mốc trước L5 coi như đã xem (chấm đỏ chỉ vì mục mới của L5).
    state.markUnlocksSeen(state.unseenUnlocks);
    await pumpSugarApp(tester, state);
    expect(_upgradesDot, findsNothing);

    final delta = await _winViaResult(tester, state, caseStand.level);
    expect(delta.newUnlocks, contains('case_stand'));
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(_key('unlock-notice'), findsOneWidget);
    expect(find.text('New unlock!'), findsOneWidget);
    expect(_key('unlock-notice-name-case_stand'), findsOneWidget);
    expect(find.text(caseStand.name('en')), findsOneWidget);
    expect(_upgradesDot, findsOneWidget); // chấm đỏ đã bật (sau dialog)

    await tester.tap(_key('unlock-notice-view'));
    await tester.pumpAndSettle();
    expect(_key('unlock-notice'), findsNothing);
    final screen = tester.widget<UpgradesScreen>(find.byType(UpgradesScreen));
    expect(screen.initialTab, UpgradesTab.expansion);
    expect(screen.focus, 'case_stand');
    // Thẻ không tự đánh dấu đã xem: màn Nâng cấp đánh dấu khi mở và vẫn gắn huy hiệu "Mới" cho mục vừa mở.
    expect(find.text('New'), findsOneWidget);
    expect(state.unseenUnlocks, isEmpty);
    // Thẻ được cuộn tới và nằm trong màn.
    final card = tester.getRect(_key('upg-buy-case_stand'));
    expect(card.top, greaterThan(0));
    expect(card.bottom, lessThan(720));

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(_upgradesDot, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Để sau": thẻ đóng, chấm đỏ còn tới khi mở màn Nâng cấp; thông báo không hiện lại', (tester) async {
    final caseStand = _u('case_stand');
    final state = _state(cleared: caseStand.level - 1);
    // Cấp thiết bị đã tới mốc trước L5 coi như đã xem (chấm đỏ chỉ vì mục mới của L5).
    state.markUnlocksSeen(state.unseenUnlocks);
    await pumpSugarApp(tester, state);
    expect(_upgradesDot, findsNothing);
    await _winViaResult(tester, state, caseStand.level);
    expect(_key('unlock-notice'), findsOneWidget);

    await tester.tap(_key('unlock-notice-later'));
    await tester.pumpAndSettle();
    expect(_key('unlock-notice'), findsNothing);
    expect(_upgradesDot, findsOneWidget);
    expect(state.unseenUnlocks, contains('case_stand'));

    // Vào / ra màn khác → không hiện lại thẻ.
    navigator(tester).pushNamed(AppRoutes.recipes);
    await tester.pumpAndSettle();
    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(_key('unlock-notice'), findsNothing);

    // Mở Nâng cấp từ thanh bản đồ → đã xem → chấm đỏ tắt; thẻ mang huy hiệu "Mới" trong lần mở này.
    await tester.tap(find.byTooltip(AppLocalizations.of(tester.element(find.byType(LevelMapScreen))).menuUpgrades));
    await tester.pumpAndSettle();
    expect(find.byType(UpgradesScreen), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(state.unseenUnlocks, isEmpty);
    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(_upgradesDot, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thông báo nhiều mục: danh sách + cấp thiết bị; Xem → tab Thiết bị khi mục đầu là thiết bị', (
    tester,
  ) async {
    final state = _state(cleared: 3);
    await pumpSugarApp(tester, state);
    final ctx = tester.element(find.byType(LevelMapScreen));
    final ids = ['eq:fastOven:2', 'eq:tongs:2', 'staff_cashier', 'case_stand', 'không_có'];
    final items = unlockNoticeItems(state.unlockConfig, ids, 'en');
    expect(items.map((i) => i.id), ['eq:fastOven:2', 'eq:tongs:2', 'staff_cashier', 'case_stand']);
    UpgradesArgs? args;
    showUnlockNotice(ctx, ids).then((a) => args = a);
    await tester.pumpAndSettle();
    expect(_key('unlock-notice'), findsOneWidget);
    expect(find.text('Tier 2 unlocked'), findsNWidgets(2));
    expect(find.text('+1 more'), findsOneWidget);
    await tester.tap(_key('unlock-notice-view'));
    await tester.pumpAndSettle();
    expect(args?.tab, UpgradesTab.equipment);
    expect(args?.focus, 'fastOven');
    // "Xem" chưa đánh dấu; mở màn Nâng cấp → huy hiệu "Mới" trên các thiết bị vừa tới mốc, rồi mới đánh dấu.
    expect(state.unseenUnlocks, containsAll(['eq:fastOven:2', 'eq:tongs:2']));
    await _openUpgrades(tester, args: args);
    expect(tester.widget<SLTabBar>(_key('upg-tabs')).selected, 1);
    expect(find.text('New'), findsWidgets);
    expect(state.unseenUnlocks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thiết bị: chạm đúp "Nâng cấp" chỉ lên 1 cấp; dấu ✓ tắt sau hiệu ứng', (tester) async {
    final oven = _eq('goldenOven');
    final state = _state(cleared: oven.tiers[2].level)..addCoins(oven.tiers[1].price + oven.tiers[2].price + 100);
    await pumpSugarApp(tester, state);
    await _openUpgrades(tester, args: const UpgradesArgs(tab: UpgradesTab.equipment));
    expect(state.equipmentTier('goldenOven'), 1);
    final before = state.coins;

    await tester.tap(_key('upg-buy-goldenOven'));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(_key('upg-buy-goldenOven'));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(_key('upg-buy-goldenOven'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.equipmentTier('goldenOven'), 2);
    expect(state.coins, before - oven.tiers[1].price);
    expect(find.byType(SLStamp), findsOneWidget);

    // Dấu ✓ chỉ cho lần mua vừa rồi: tắt sau ~1,3 s.
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    expect(find.byType(SLStamp), findsNothing);

    // Hết khoảng nghỉ → bấm lại mua được cấp kế.
    await tester.tap(_key('upg-buy-goldenOven'));
    await tester.pumpAndSettle();
    expect(state.equipmentTier('goldenOven'), 3);
    expect(find.byType(SLStamp), findsOneWidget);
    await settleToasts(tester);
    expect(find.byType(SLStamp), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('compactStatPair: bỏ chữ lặp ở đầu (vế sau) hoặc ở đuôi (vế trước)', () {
    expect(compactStatPair('Nướng 6,3 giây', 'Nướng 5,6 giây'), ('Nướng 6,3 giây', '5,6 giây'));
    expect(compactStatPair('Vùng hoàn hảo ±7%', 'Vùng hoàn hảo ±8%'), ('Vùng hoàn hảo ±7%', '±8%'));
    expect(compactStatPair('3 bánh mỗi khay', '4 bánh mỗi khay'), ('3', '4 bánh mỗi khay'));
    expect(compactStatPair('No snapping', 'Snap range 16'), ('No snapping', 'Snap range 16'));
    expect(compactStatPair('Same', 'Same'), ('Same', 'Same'));
  });

  testWidgets('thẻ Sẵn sàng: dòng tóm tắt tiệm theo đồ đã mua (ô tủ · lò · khay)', (tester) async {
    final caseStand = _u('case_stand');
    final state = _state(cleared: caseStand.level)..addCoins(caseStand.price);
    expect(state.buyUnlock('case_stand'), PurchaseResult.ok);
    await pumpSugarApp(tester, state);
    final next = caseStand.level + 1;
    navigator(tester).pushNamed(AppRoutes.level, arguments: LevelArgs(next));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(LevelScreen), findsOneWidget);
    final slots = testLevelConfig().level(next).caseSlots + state.shopSetup.caseSlotsBonus;
    final line = tester.widget<Text>(find.descendant(of: _key('level-ready-shop'), matching: find.byType(Text)));
    expect(line.data, '$slots case slots · 1 oven · Tray of ${state.shopSetup.batchSize}');
    expect(tester.takeException(), isNull);
  });
}
