import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/map/offline_dialog.dart';
import 'package:sugarleaf_bakery/ui/menu/login_gift_dialog.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/upgrades/unlock_notice.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'ui_test_helpers.dart';

/// Đồng hồ giả của ván (đổi được trong test: vắng nhà).
DateTime _now = DateTime(2026, 10, 28, 10);

/// levels.json thật + chương thử tới L40 (mốc phục vụ L25, quản lý L32).
final _levels = testExtendedLevelConfig();
final _unlocks = testUnlockConfig();

StaffData _staff(String id) => _unlocks.staffById(id)!;
int _price(String id) => _unlocks.unlock(id)!.price;

/// Ván mới (en) theo đồng hồ giả, đã xem cảnh mở màn; đã qua L1..[cleared] (mỗi lượt +[coins] xu, trung bình xu
/// một màn cho quản lý); [claimLogin] = đã nhận quà hôm nay.
GameState _state({int cleared = 0, int coins = 0, bool claimLogin = true}) {
  final state = GameState.newGame(clock: () => _now)
    ..setLanguage(LanguagePref.en)
    ..markSceneSeen(StorySceneId.prologue);
  if (claimLogin) state.claimLogin();
  testServices(state, levels: _levels);
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: coins);
  return state;
}

/// Đã thuê quản lý (qua L32, đủ xu), mốc hoạt động = bây giờ.
GameState _withManager({bool claimLogin = true}) {
  final state = _state(cleared: _unlocks.unlock(StaffIds.manager)!.level, coins: 300, claimLogin: claimLogin);
  state.addCoins(_price(StaffIds.manager));
  expect(state.buyUnlock(StaffIds.manager), PurchaseResult.ok);
  state.refreshOffline(_now);
  return state;
}

/// Vắng nhà [away] (như main.dart khi app quay lại: `refreshOffline`).
void _goAway(GameState state, Duration away) {
  _now = _now.add(away);
  state.refreshOffline(_now);
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, GameState state) =>
    pumpSugarApp(tester, state, services: testServices(state, levels: _levels));

Future<void> _openStaffTab(WidgetTester tester, {String? focus}) async {
  navigator(tester).pushNamed(AppRoutes.upgrades, arguments: UpgradesArgs(tab: UpgradesTab.staff, focus: focus));
  await tester.pumpAndSettle();
}

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Cảnh chơi (Flame) chạy liên tục: không dùng pumpAndSettle khi LevelScreen đang mở.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => _now = DateTime(2026, 10, 28, 10));

  // ------------------------------------------------------------------ Tab Nhân viên

  testWidgets('tab Nhân viên: trạng thái theo tiến trình (thuê được / qua màn X / cần mục trước); tab Mở rộng bỏ '
      'nhân viên', (tester) async {
    final baker = _staff(StaffIds.baker);
    final state = _state(cleared: _unlocks.unlock(StaffIds.baker)!.level);
    await _pump(tester, state);
    await _openStaffTab(tester);
    final l = _l(tester);

    expect(tester.widget<SLTabBar>(_key('upg-tabs')).selected, 2);
    // Đủ 5 người, theo thứ tự unlocks.json.
    for (final s in _unlocks.staff) {
      expect(_key('staff-name-${s.id}'), findsOneWidget, reason: s.id);
      expect(_key('staff-portrait-${s.id}'), findsOneWidget, reason: s.id);
    }
    expect(find.text(baker.name('en')), findsOneWidget);
    expect(find.text(baker.bio('en')), findsOneWidget);
    expect(find.text(l.staffRoleBaker), findsNWidgets(2)); // Bảo + Ami
    // Qua mốc → giá + "Thuê".
    expect(_key('staff-hire-${StaffIds.cashier}'), findsOneWidget);
    expect(_key('staff-hire-${StaffIds.baker}'), findsOneWidget);
    // Chưa tới mốc → "Qua màn X để mở".
    final waiter = _unlocks.unlock(StaffIds.waiter)!;
    expect(_key('staff-locked-${StaffIds.waiter}'), findsOneWidget);
    expect(find.text(l.mapUnlockAfterLevel(waiter.level)), findsOneWidget);
    expect(_key('staff-locked-${StaffIds.manager}'), findsOneWidget);
    // Chưa thuê: xem trước thông số cấp 1, không có nút nâng.
    expect(find.text(l.staffBakerSpeed('24')), findsNWidgets(2)); // Bảo + Ami
    expect(find.byKey(const ValueKey('staff-up-staff_baker-speed')), findsNothing);

    // Tab Mở rộng tiệm không còn thẻ nhân viên.
    await tester.tap(find.text(l.upgTabExpansion));
    await tester.pumpAndSettle();
    expect(_key('upg-soon-${StaffIds.cashier}'), findsNothing);
    expect(_key('upg-locked-${StaffIds.waiter}'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phục vụ: qua mốc nhưng chưa có bàn ghế → "Cần có … trước"; mua bàn ghế → thuê được', (tester) async {
    final state = _state(cleared: _unlocks.unlock(StaffIds.waiter)!.level);
    await _pump(tester, state);
    await _openStaffTab(tester);
    final l = _l(tester);
    final tables = _unlocks.unlock('cafe_tables')!;
    expect(_key('staff-requires-${StaffIds.waiter}'), findsOneWidget);
    expect(find.text(l.staffRequires(tables.name('en'))), findsOneWidget);
    expect(_key('staff-hire-${StaffIds.waiter}'), findsNothing);

    state
      ..addCoins(tables.price)
      ..buyUnlock('cafe_tables');
    await tester.pumpAndSettle();
    expect(_key('staff-requires-${StaffIds.waiter}'), findsNothing);
    expect(_key('staff-hire-${StaffIds.waiter}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thuê → nâng Tốc độ / Tay nghề: xu giảm đúng giá, chấm cấp + thông số trước → sau', (tester) async {
    final nora = _staff(StaffIds.cashier);
    final state = _state(cleared: _unlocks.unlock(StaffIds.cashier)!.level);
    await _pump(tester, state);
    await _openStaffTab(tester);
    final l = _l(tester);

    // Thiếu xu → toast, chưa thuê.
    await tester.tap(_key('staff-hire-${nora.id}'));
    await tester.pumpAndSettle();
    expect(find.text(l.commonNotEnoughCoins), findsOneWidget);
    expect(state.isStaffHired(nora.id), isFalse);
    await settleToasts(tester);

    final speedPrice = nora.priceTo(StaffStat.speed, 2)!;
    final skillPrice = nora.priceTo(StaffStat.skill, 2)!;
    state.addCoins(_price(nora.id) + speedPrice + skillPrice);
    await tester.pump();
    var coins = state.coins;
    await tester.tap(_key('staff-hire-${nora.id}'));
    await tester.pumpAndSettle();
    expect(state.isStaffHired(nora.id), isTrue);
    expect(state.coins, coins - _price(nora.id));
    expect(find.text(l.staffHired), findsOneWidget);
    expect(_key('staff-hire-${nora.id}'), findsNothing);
    expect(find.byType(SLStamp), findsOneWidget);
    // Thông số cấp 1 → cấp 2 (vế sau rút gọn chữ lặp).
    expect(find.text(l.staffCashierSpeed('3.2')), findsOneWidget);
    expect(find.text('2.8s'), findsOneWidget);
    await settleToasts(tester);

    coins = state.coins;
    await tester.tap(_key('staff-up-${nora.id}-speed'));
    await tester.pumpAndSettle();
    expect(state.staffLevel(nora.id, StaffStat.speed), 2);
    expect(state.coins, coins - speedPrice);
    expect(find.text(l.staffCashierSpeed('2.8')), findsOneWidget);
    await settleToasts(tester);

    coins = state.coins;
    await tester.tap(_key('staff-up-${nora.id}-skill'));
    await tester.pumpAndSettle();
    expect(state.staffLevel(nora.id, StaffStat.skill), 2);
    expect(state.coins, coins - skillPrice);
    // Vế trước rút gọn chữ lặp ở đuôi ("+8%"), vế sau đủ chữ.
    expect(find.text(l.staffCashierSkill(12)), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chạm đúp "Thuê" / nút nâng chỉ mua một lần; tối đa → huy hiệu thay nút', (tester) async {
    final bao = _staff(StaffIds.baker);
    final state = _state(cleared: _unlocks.unlock(bao.id)!.level);
    state.addCoins(_price(bao.id) + bao.speedPrices.fold<int>(0, (a, b) => a + b) + 100);
    await _pump(tester, state);
    await _openStaffTab(tester);

    final coins = state.coins;
    final hireAt = tester.getCenter(_key('staff-hire-${bao.id}'));
    await tester.tapAt(hireAt);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(hireAt); // nút đã đổi thành chỉ số → chạm vào chỗ cũ không thuê lần nữa
    await tester.pump(const Duration(milliseconds: 60));
    expect(state.coins, coins - _price(bao.id));
    await tester.pump(const Duration(milliseconds: 500)); // hết khoảng nghỉ

    final before = state.coins;
    await tester.tap(_key('staff-up-${bao.id}-speed'));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(_key('staff-up-${bao.id}-speed'));
    await tester.pump(const Duration(milliseconds: 90));
    expect(state.staffLevel(bao.id, StaffStat.speed), 2);
    expect(state.coins, before - bao.priceTo(StaffStat.speed, 2)!);

    // Hết khoảng nghỉ → bấm tiếp tới tối đa.
    for (var lv = 3; lv <= bao.maxLevel; lv++) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(_key('staff-up-${bao.id}-speed'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.staffLevel(bao.id, StaffStat.speed), lv);
    }
    await tester.pumpAndSettle();
    expect(_key('staff-up-${bao.id}-speed'), findsNothing);
    expect(_key('staff-max-${bao.id}-speed'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('khoảng nghỉ chống chạm đúp theo từng chỉ số: nâng Tốc độ xong bấm Tay nghề ngay được', (tester) async {
    final bao = _staff(StaffIds.baker);
    final speedPrice = bao.priceTo(StaffStat.speed, 2)!;
    final skillPrice = bao.priceTo(StaffStat.skill, 2)!;
    final state = _state(cleared: _unlocks.unlock(bao.id)!.level);
    state.addCoins(_price(bao.id) + speedPrice + skillPrice + bao.priceTo(StaffStat.speed, 3)! + 100);
    await _pump(tester, state);
    await _openStaffTab(tester);
    await tester.tap(_key('staff-hire-${bao.id}'));
    await tester.pump(const Duration(milliseconds: 500)); // hết khoảng nghỉ của "Thuê"

    final before = state.coins;
    await tester.tap(_key('staff-up-${bao.id}-speed'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(_key('staff-up-${bao.id}-skill')); // ngay sau Tốc độ, chỉ số khác → mua được
    await tester.pump(const Duration(milliseconds: 60));
    expect(state.staffLevel(bao.id, StaffStat.speed), 2);
    expect(state.staffLevel(bao.id, StaffStat.skill), 2);
    expect(state.coins, before - speedPrice - skillPrice);

    // Tốc độ vẫn trong khoảng nghỉ của chính nó → chạm lại không mua.
    await tester.tap(_key('staff-up-${bao.id}-speed'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(state.staffLevel(bao.id, StaffStat.speed), 2);
    expect(state.coins, before - speedPrice - skillPrice);
    await tester.pumpAndSettle();
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staffStatText: đơn vị theo vai trò (phần trăm nguyên / tỉ lệ 0..1), kể cả giá trị 1', (tester) async {
    final state = _state();
    await _pump(tester, state);
    final context = tester.element(find.byType(LevelMapScreen));
    final l = _l(tester);
    // Tip thu ngân / kiên nhẫn phục vụ: phần trăm nguyên → 1 = 1% (không phải 100%).
    expect(staffStatText(context, StaffRole.cashier, StaffStat.skill, 1), l.staffCashierSkill(1));
    expect(staffStatText(context, StaffRole.cashier, StaffStat.skill, 8), l.staffCashierSkill(8));
    expect(staffStatText(context, StaffRole.waiter, StaffStat.skill, 1), l.staffWaiterSkill(1));
    expect(staffStatText(context, StaffRole.waiter, StaffStat.skill, 25), l.staffWaiterSkill(25));
    // Tốc độ quản lý: tỉ lệ → 1 = 100%, 0,25 = 25%.
    expect(staffStatText(context, StaffRole.manager, StaffStat.speed, 1), l.staffManagerSpeed(100));
    expect(staffStatText(context, StaffRole.manager, StaffStat.speed, 0.25), l.staffManagerSpeed(25));
    expect(staffStatText(context, StaffRole.manager, StaffStat.skill, 1), l.staffManagerSkill(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('thông báo mở khoá nhân viên → "Xem" mở tab Nhân viên đúng thẻ', (tester) async {
    final state = _state(cleared: _unlocks.unlock(StaffIds.cashier)!.level);
    await _pump(tester, state);
    expect(UpgradesArgs.forUnlock(StaffIds.cashier, state.unlockConfig).tab, UpgradesTab.staff);
    UpgradesArgs? args;
    showUnlockNotice(tester.element(find.byType(LevelMapScreen)), [StaffIds.cashier]).then((a) => args = a);
    await tester.pumpAndSettle();
    expect(_key('unlock-notice-name-${StaffIds.cashier}'), findsOneWidget);
    await tester.tap(_key('unlock-notice-view'));
    await tester.pumpAndSettle();
    expect(args?.tab, UpgradesTab.staff);
    expect(args?.focus, StaffIds.cashier);

    navigator(tester).pushNamed(AppRoutes.upgrades, arguments: args);
    await tester.pumpAndSettle();
    expect(tester.widget<SLTabBar>(_key('upg-tabs')).selected, 2);
    expect(_key('staff-hire-${StaffIds.cashier}'), findsOneWidget);
    // Thẻ được mở tới: giấy vàng bơ, nằm trong màn.
    final card = tester.getRect(_key('staff-hire-${StaffIds.cashier}'));
    expect(card.bottom, lessThan(720));
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------------ Khi bạn vắng nhà

  test('offlineDurationText: phút / giờ / giờ + phút / ngày', () async {
    final l = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(offlineDurationText(l, const Duration(minutes: 25)), l.offlineDurationMinutes(25));
    expect(offlineDurationText(l, const Duration(hours: 3)), l.offlineDurationHours(3));
    expect(offlineDurationText(l, const Duration(hours: 2, minutes: 15)), l.offlineDurationHoursMinutes(2, 15));
    expect(offlineDurationText(l, const Duration(days: 2, hours: 5)), l.offlineDurationDays(2));
  });

  testWidgets('không có thu nhập vắng nhà → không hiện hộp', (tester) async {
    final state = _withManager();
    _goAway(state, const Duration(minutes: 3)); // dưới 10 phút: không tính
    expect(state.pendingOffline, isNull);
    await _pump(tester, state);
    expect(_key('offline-dialog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vắng nhà: hộp hiện khi vào bản đồ → "Nhận" cộng xu, không hiện lại', (tester) async {
    final state = _withManager();
    _goAway(state, const Duration(hours: 2, minutes: 30));
    final pending = state.pendingOffline!;
    expect(pending.capped, isFalse);
    await _pump(tester, state);
    final l = _l(tester);
    final manager = _staff(StaffIds.manager);

    expect(_key('offline-dialog'), findsOneWidget);
    expect(find.text(l.offlineTitle), findsOneWidget);
    expect(_key('offline-portrait'), findsOneWidget);
    expect(find.text(l.offlineBody(manager.name('en'), l.offlineDurationHoursMinutes(2, 30))), findsOneWidget);
    expect(_key('offline-capped'), findsNothing);
    expect(find.text('+${pending.coins}'), findsOneWidget);
    expect(_key('offline-double'), findsOneWidget);

    final coins = state.coins;
    await tester.tap(_key('offline-claim'));
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsNothing);
    expect(state.coins, coins + pending.coins);
    expect(state.pendingOffline, isNull);

    // Vào / ra màn khác → không hiện lại.
    navigator(tester).pushNamed(AppRoutes.recipes);
    await tester.pumpAndSettle();
    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vắng lâu hơn trần giờ: ghi rõ đã cắt; "x2" xem quảng cáo → cộng gấp đôi + tính lượt rewarded', (
    tester,
  ) async {
    final state = _withManager();
    _goAway(state, const Duration(hours: 10));
    final pending = state.pendingOffline!;
    expect(pending.capped, isTrue);
    await _pump(tester, state);
    final l = _l(tester);
    expect(_key('offline-capped'), findsOneWidget);
    expect(find.text(l.offlineCapped(pending.capHours)), findsOneWidget);
    expect(find.text(l.offlineBody(_staff(StaffIds.manager).name('en'), l.offlineDurationHours(10))), findsOneWidget);

    final coins = state.coins;
    final ads = state.rewardedToday;
    await tester.tap(_key('offline-double'));
    await waitForAd(tester);
    expect(_key('offline-dialog'), findsNothing);
    expect(state.coins, coins + pending.coins * 2);
    expect(state.rewardedToday, ads + 1);
    expect(find.text(l.offlineDoubled), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hết lượt quảng cáo thưởng hôm nay → ẩn nút x2', (tester) async {
    final state = _withManager();
    while (state.rewardedToday < Economy.maxRewardedPerDay) {
      state.registerRewardedShown();
    }
    _goAway(state, const Duration(hours: 1));
    await _pump(tester, state);
    expect(_key('offline-dialog'), findsOneWidget);
    expect(_key('offline-double'), findsNothing);
    expect(_key('offline-claim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app quay lại từ nền khi đang ở bản đồ → hiện hộp vắng nhà', (tester) async {
    final state = _withManager();
    await _pump(tester, state);
    expect(_key('offline-dialog'), findsNothing);

    // Như main.dart: đang mở → nhịp ghi mốc; ẩn → tắt nhịp + markActive; quay lại → refreshOffline + bật lại nhịp;
    // rồi bản đồ nghe onResume.
    addTearDown(state.stopActiveHeartbeat);
    state.startActiveHeartbeat();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    state.markActive();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    state
      ..stopActiveHeartbeat()
      ..markActive();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    state.markActive();
    _now = _now.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    state
      ..refreshOffline(_now)
      ..startActiveHeartbeat();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsOneWidget);
    await tester.tap(_key('offline-claim'));
    await tester.pumpAndSettle();
    expect(state.pendingOffline, isNull);
    state.stopActiveHeartbeat(); // không để Timer chờ khi test kết thúc
    expect(tester.takeException(), isNull);
  });

  testWidgets('nút Back Android = "Nhận" thường: cộng xu đúng một lần, hộp đóng', (tester) async {
    final state = _withManager();
    _goAway(state, const Duration(hours: 2));
    final pending = state.pendingOffline!;
    await _pump(tester, state);
    expect(_key('offline-dialog'), findsOneWidget);

    final coins = state.coins;
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute(); // Back lần hai (hộp đang đóng) không nhận thêm
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsNothing);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.coins, coins + pending.coins);
    expect(state.pendingOffline, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hộp đang mở: thu nhập chờ đổi (vắng thêm / nâng quản lý) → hiện số mới; nhận ở nơi khác → tự đóng', (
    tester,
  ) async {
    final manager = _staff(StaffIds.manager);
    final state = _withManager();
    _goAway(state, const Duration(hours: 1));
    final first = state.pendingOffline!;
    await _pump(tester, state);
    expect(find.text('+${first.coins}'), findsOneWidget);

    // App ẩn/hiện lần nữa khi hộp còn mở → vắng thêm 1 giờ.
    _goAway(state, const Duration(hours: 1));
    final second = state.pendingOffline!;
    expect(second.coins, greaterThan(first.coins));
    await tester.pump();
    expect(find.text('+${first.coins}'), findsNothing);
    expect(find.text('+${second.coins}'), findsOneWidget);
    expect(find.text(_l(tester).offlineBody(manager.name('en'), _l(tester).offlineDurationHours(2))), findsOneWidget);

    // Nâng tốc độ quản lý → tỉ lệ cao hơn.
    state.addCoins(manager.priceTo(StaffStat.speed, 2)!);
    expect(state.upgradeStaff(manager.id, StaffStat.speed), PurchaseResult.ok);
    final third = state.pendingOffline!;
    expect(third.coins, greaterThan(second.coins));
    await tester.pump();
    expect(find.text('+${third.coins}'), findsOneWidget);

    // Nhận ở nơi khác → hộp tự đóng, không cộng lần hai.
    final coins = state.coins;
    expect(state.claimOffline(), third.coins);
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsNothing);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.coins, coins + third.coins);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thứ tự hộp trên bản đồ: lời chào → vắng nhà → quà đăng nhập', (tester) async {
    // Bản lưu V1 (ngày 4, chưa có `progress`) → quy đổi + lời chào; rồi thuê quản lý và vắng nhà.
    final v1 = GameState.newGame().toJson()
      ..remove('progress')
      ..['v'] = 1
      ..['day'] = 4;
    final repo = MemorySaveRepository(jsonEncode(v1));
    final state = (await tester.runAsync(() => GameState.load(repo, clock: () => _now)))!..setLanguage(LanguagePref.en);
    testServices(state, levels: _levels);
    winLevels(state, [for (var id = 1; id <= _unlocks.unlock(StaffIds.manager)!.level; id++) id], coins: 300);
    state.addCoins(_price(StaffIds.manager));
    expect(state.buyUnlock(StaffIds.manager), PurchaseResult.ok);
    state.refreshOffline(_now);
    _goAway(state, const Duration(hours: 1));
    expect(state.welcomeGiftPending, isTrue);
    expect(state.pendingOffline, isNotNull);
    expect(state.pendingLoginReward, isNotNull);

    await _pump(tester, state);
    final l = _l(tester);
    expect(_key('map-welcome-back'), findsOneWidget);
    expect(_key('offline-dialog'), findsNothing);
    expect(find.byType(LoginGiftDialog), findsNothing);

    await tester.tap(find.text(l.mapChapterUnlockedGo));
    await tester.pumpAndSettle();
    expect(_key('map-welcome-back'), findsNothing);
    expect(_key('offline-dialog'), findsOneWidget);
    expect(find.byType(LoginGiftDialog), findsNothing);

    await tester.tap(_key('offline-claim'));
    await tester.pumpAndSettle();
    expect(_key('offline-dialog'), findsNothing);
    expect(find.byType(LoginGiftDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------------ Thẻ Sẵn sàng

  testWidgets('thẻ Sẵn sàng: hàng chân dung nhân viên làm trong màn (bỏ quản lý)', (tester) async {
    final state = _withManager();
    for (final id in [StaffIds.cashier, StaffIds.baker]) {
      state.addCoins(_price(id));
      expect(state.buyUnlock(id), PurchaseResult.ok);
    }
    expect(state.pendingOffline, isNull);
    await _pump(tester, state);
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(33));
    await _pumpFrames(tester);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(_key('level-ready-staff'), findsOneWidget);
    expect(_key('level-ready-staff-${StaffIds.cashier}'), findsOneWidget);
    expect(_key('level-ready-staff-${StaffIds.baker}'), findsOneWidget);
    expect(_key('level-ready-staff-${StaffIds.manager}'), findsNothing);
    final l = _l(tester);
    expect(find.text(l.levelReadyStaff), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thẻ Sẵn sàng: chưa thuê ai → không có hàng nhân viên', (tester) async {
    final state = _state(cleared: 3);
    await _pump(tester, state);
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(4));
    await _pumpFrames(tester);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(_key('level-ready-staff'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
