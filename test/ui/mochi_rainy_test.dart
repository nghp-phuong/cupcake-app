import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/ui/common/sugar_button.dart';
import 'package:sugarleaf_bakery/ui/day/day_screen.dart';
import 'package:sugarleaf_bakery/ui/day/mochi_visit.dart';
import 'package:sugarleaf_bakery/ui/day/rain_overlay.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

/// Ván tiếng Anh đã xem mọi cảnh truyện + hướng dẫn, đang ở ngày [day] (ngày 5 luôn mưa, ngày 6 tạnh).
GameState _stateAtDay(int day, {LanguagePref lang = LanguagePref.en}) {
  final s = GameState.newGame()
    ..setLanguage(lang)
    ..claimLogin();
  for (final id in StorySceneId.values) {
    s.markSceneSeen(id);
  }
  for (final st in StationId.values) {
    s.markTutorialSeen(st);
  }
  for (var d = 1; d < day; d++) {
    s.completeDay();
  }
  return s;
}

BakeOutcome _perfectFor(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: o.recipeData.bakeTarget,
      frostCoverage: 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// Dựng app 1280×720, mở thẳng màn ngày với Random có seed. Không dùng pumpAndSettle khi trời mưa (mưa lặp mãi).
Future<void> _openDay(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MainMenuScreen.giftShownThisSession = true;
  await tester.pumpWidget(
    SugarleafApp(
      services: testServices(state),
      useGoogleFonts: false,
      onGenerateRoute: (settings) => settings.name == AppRoutes.day
          ? fadeRoute(settings, DayScreen(random: math.Random(11)))
          : onGenerateUiRoute(settings),
    ),
  );
  await tester.pumpAndSettle();
  navigator(tester).pushNamed(AppRoutes.day);
  await _wait(tester, 600);
}

/// Bơm khung hình [ms] mili giây theo bước 100 ms.
Future<void> _wait(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Khách hiện tại: bắt đầu làm bánh → trả kết quả hoàn hảo thẳng qua `onComplete` → thẻ kết quả → "Next customer".
Future<void> _serve(WidgetTester tester) async {
  await tester.tap(find.text('Start baking'));
  await _wait(tester, 300);
  final view = tester.widget<BakeSessionView>(find.byType(BakeSessionView));
  view.onComplete(_perfectFor(view.order));
  await _wait(tester, 1500);
  await tester.tap(find.text('Next customer'));
  await _wait(tester, 400);
}

/// Đọc số khách hôm nay từ HUD "Customer i/N".
int _total(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.startsWith('Customer '));
  return int.parse(text.split('/').last);
}

void main() {
  testWidgets('ngày mưa: nhãn ở giới thiệu, mưa ở quầy, Mochi ghé sau khách giữa ngày, vuốt ve có quà', (tester) async {
    final state = _stateAtDay(5);
    await _openDay(tester, state);

    expect(find.text('Day 5'), findsOneWidget);
    expect(find.text('Rainy day'), findsOneWidget);
    expect(find.byType(RainOverlay), findsNothing); // giới thiệu dùng nền mưa vẽ tay.

    await _wait(tester, 2400 + 900);
    expect(find.text('Start baking'), findsOneWidget);
    expect(find.byType(RainOverlay), findsOneWidget);
    final total = _total(tester);
    final half = total ~/ 2;

    for (var i = 0; i < half; i++) {
      expect(find.byType(MochiVisit), findsNothing, reason: 'trước khách thứ ${i + 1}');
      await _serve(tester);
    }

    // Sau khách thứ total ~/ 2: Mochi ghé (lần đầu), chưa có khách mới.
    expect(find.byType(MochiVisit), findsOneWidget);
    expect(find.text('Start baking'), findsNothing);
    expect(find.text('A little soaked cat is sheltering from the rain at your door…'), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);
    await _wait(tester, 1000);

    // Chạm → nhìn + 2 nút; vùng chạm ≥ 48.
    await tester.tapAt(const Offset(900, 400));
    await _wait(tester, 300);
    expect(find.text('Mochi looks up at you, tail swishing softly.'), findsOneWidget);
    expect(find.text('Let Mochi rest'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(SugarButton, 'Pet')).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(SugarButton, 'Let Mochi rest')).height, greaterThanOrEqualTo(48));

    final coins = state.coins, gems = state.gems;
    await tester.tap(find.text('Pet'));
    await _wait(tester, 400);
    expect(state.coins, coins + Economy.mochiPetCoins);
    expect(state.gems, gems + Economy.mochiFirstPetGems);
    expect(state.mochiPets, 1);
    expect(state.lastMochiDay, 5);
    expect(find.text('Mochi purrs happily!'), findsOneWidget);
    expect(find.text('Mochi left you 30 coins and 5 gems!'), findsOneWidget);

    // Chạm → Mochi rời đi → khách tiếp theo vào như cũ.
    await tester.tapAt(const Offset(900, 400));
    await _wait(tester, 1200);
    expect(find.byType(MochiVisit), findsNothing);
    expect(find.text('Start baking'), findsOneWidget);
    expect(find.text('Customer ${half + 1}/$total'), findsOneWidget);
    expect(state.coins, coins + Economy.mochiPetCoins); // không cộng lần hai.

    // Phục vụ nốt → tổng kết có dòng ngày mưa, Mochi không ghé lại.
    for (var i = half; i < total; i++) {
      expect(find.byType(MochiVisit), findsNothing);
      await _serve(tester);
    }
    await _wait(tester, 800);
    expect(find.text('Day 5 complete!'), findsOneWidget);
    expect(find.text('A rainy day — Mochi dropped by'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ngày tạnh: không mưa, không Mochi, tổng kết không có dòng ngày mưa', (tester) async {
    final state = _stateAtDay(6);
    await _openDay(tester, state);
    expect(find.text('Rainy day'), findsNothing);
    await _wait(tester, 2400 + 900);
    expect(find.byType(RainOverlay), findsNothing);
    final total = _total(tester);
    for (var i = 0; i < total; i++) {
      expect(find.byType(MochiVisit), findsNothing);
      await _serve(tester);
    }
    await _wait(tester, 800);
    expect(find.text('Day 6 complete!'), findsOneWidget);
    expect(find.text('A rainy day — Mochi dropped by'), findsNothing);
    expect(state.mochiVisits, 0);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mochi: "Để Mochi nghỉ" không cho quà; thoát ngày giữa lúc Mochi ghé không lỗi', (tester) async {
    final state = _stateAtDay(5, lang: LanguagePref.vi);
    await _openDay(tester, state);
    expect(find.text('Ngày mưa'), findsOneWidget);
    await _wait(tester, 2400 + 900);
    final hud = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.startsWith('Khách '));
    final total = int.parse(hud.split('/').last);
    for (var i = 0; i < total ~/ 2; i++) {
      await tester.tap(find.text('Bắt đầu làm bánh'));
      await _wait(tester, 300);
      final view = tester.widget<BakeSessionView>(find.byType(BakeSessionView));
      view.onComplete(_perfectFor(view.order));
      await _wait(tester, 1500);
      await tester.tap(find.text('Khách tiếp theo'));
      await _wait(tester, 400);
    }
    expect(find.text('Một chú mèo nhỏ ướt sũng đang trú mưa trước cửa tiệm…'), findsOneWidget);
    await tester.tapAt(const Offset(900, 400));
    await _wait(tester, 300);
    final coins = state.coins;
    await tester.tap(find.text('Để Mochi nghỉ'));
    await _wait(tester, 300);
    expect(find.text('Mochi cuộn tròn ngủ bên lò sưởi.'), findsOneWidget);
    expect(state.coins, coins);
    expect(state.mochiVisits, 1);
    expect(state.mochiPets, 0);

    // Thoát ngay khi Mochi còn ở quầy.
    await tester.tap(find.byTooltip('Tạm rời tiệm?').first);
    await _wait(tester, 400);
    await tester.tap(find.text('Đồng ý'));
    await _wait(tester, 800);
    expect(find.byType(MochiVisit), findsNothing);
    expect(find.byType(DayScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tổng kết ngày mưa (vi) dựng không tràn', (tester) async {
    final state = _stateAtDay(5, lang: LanguagePref.vi);
    await pumpSugarApp(tester, state);
    navigator(tester).pushReplacementNamed(
      AppRoutes.summary,
      arguments: DaySummaryArgs(
        const DaySummary(
          dayNumber: 5,
          isRainy: true,
          records: [],
          revenue: 0,
          tips: 0,
          costs: 0,
          net: 0,
          xpGained: 30,
          dayBonusXp: 30,
          levelBefore: 1,
          levelAfter: 1,
          unlocks: [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngày mưa — Mochi ghé chơi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
