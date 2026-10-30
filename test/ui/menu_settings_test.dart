import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

void main() {
  testWidgets('bản đồ dựng được (en), tự mở quà đăng nhập, nhận quà cộng xu', (tester) async {
    final state = GameState.newGame()..setLanguage(LanguagePref.en);
    await pumpSugarApp(tester, state);

    // Quà đăng nhập tự mở lần đầu trong phiên.
    expect(find.text('Day 1'), findsWidgets);
    expect(find.text('Claim'), findsOneWidget);
    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(state.coins, Economy.startCoins + 50);
    expect(find.text('Come back tomorrow for more!'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Thanh trên: tên chương đang xem, nút có nhãn; không còn cấp tiệm / XP.
    expect(find.text("Chapter 1 · Grandma's Kitchen"), findsOneWidget);
    expect(find.text('Bakery level 1'), findsNothing);
    expect(find.text('0/80 XP'), findsNothing);
    expect(find.text('Recipe book'), findsOneWidget);
    expect(find.text('Upgrades'), findsOneWidget);
    expect(find.text('Decor'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Quests'), findsOneWidget);
    expect(find.text('Gift'), findsOneWidget);
    expect(find.byTooltip('Daily quests'), findsOneWidget);
    expect(find.byTooltip('Daily gift'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bản đồ dựng được (vi), quà đã nhận thì không tự mở', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.vi)
      ..claimLogin();
    await pumpSugarApp(tester, state);

    expect(find.text('Chương 1 · Căn bếp của bà'), findsOneWidget);
    expect(find.text('Tiệm cấp 1'), findsNothing);
    expect(find.text('Sổ công thức'), findsOneWidget);
    expect(find.text('Nhận'), findsNothing);

    // Mở nhiệm vụ ngày.
    await tester.tap(find.byTooltip('Nhiệm vụ ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Mỗi ngày có nhiệm vụ mới'), findsOneWidget);
    expect(find.text('Nhận'), findsNWidgets(3)); // 3 nhiệm vụ, nút chưa bấm được
    expect(tester.takeException(), isNull);
  });

  testWidgets('đổi ngôn ngữ ở cài đặt đổi chữ ngay', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Version 0.1.0-alpha'), findsOneWidget);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    expect(state.language, LanguagePref.vi);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Phiên bản 0.1.0-alpha'), findsOneWidget);

    // Âm thanh: công tắc vẽ tay (Semantics toggled), chữ trạng thái Bật/Tắt bên cạnh.
    expect(find.text('Bật'), findsOneWidget);
    await tester.tap(find.byType(SLToggle));
    await tester.pumpAndSettle();
    expect(state.soundOn, isFalse);
    expect(find.text('Tắt'), findsOneWidget);
    expect(
      tester.getSemantics(find.descendant(of: find.byType(SLToggle), matching: find.byType(GestureDetector))),
      containsSemantics(label: 'Âm thanh', hasToggledState: true, isToggled: false, hasTapAction: true),
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(state.language, LanguagePref.en);
    expect(find.text('Settings'), findsOneWidget);

    // Quay lại bản đồ: bản đồ cũng đã theo ngôn ngữ mới.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text("Chapter 1 · Grandma's Kitchen"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('xoá dữ liệu: xác nhận → về ván mới và quay về menu', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin()
      ..addCoins(900);
    await pumpSugarApp(tester, state);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset game data').at(1)); // [0] = nhãn dòng, [1] = nút
    await tester.pumpAndSettle();
    expect(find.text('Reset all progress?'), findsOneWidget);
    await tester.tap(find.text('Reset game data').last);
    await tester.pumpAndSettle();

    expect(state.coins, Economy.startCoins);
    expect(state.language, LanguagePref.system);
    // Ván mới → về bản đồ, quà đăng nhập tự mở lại.
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });
}
