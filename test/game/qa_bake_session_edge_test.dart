import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/logic/frost.dart';
import 'package:sugarleaf_bakery/game/logic/station_setup.dart';
import 'package:sugarleaf_bakery/game/stations/bake_station.dart';
import 'package:sugarleaf_bakery/game/stations/box_station.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/game/stations/station.dart';
import 'package:sugarleaf_bakery/game/stations/topping_station.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

// QA: màn làm bánh 6 trạm (BakeSessionView) khi app vào nền giữa lúc nhấn giữ, và khi cửa sổ đổi cỡ giữa màn (thay
// cho xoay máy — app khoá ngang). Cử chỉ thật qua Listener, toạ độ đổi theo khung đang hiển thị.

const _order = Order(
  id: 3,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

BakeryGame _game(WidgetTester tester) => tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;

/// Khung 1280×720 → toạ độ màn hình hiện tại (đọc lại mỗi lần: cửa sổ có thể vừa đổi cỡ).
Offset _map(WidgetTester tester, Offset p) {
  final rect = tester.getRect(find.byKey(const ValueKey('bake-session-input')));
  return rect.topLeft + p * (rect.width / 1280);
}

Future<void> _run(WidgetTester tester, double sec) async {
  for (var i = 0; i < (sec / 0.016).ceil(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<T> _until<T extends Station>(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    final s = _game(tester).currentStation;
    if (s is T && s.acceptsInput) return s;
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('chưa tới trạm $T');
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to, {int steps = 12}) async {
  final g = await tester.startGesture(_map(tester, from));
  for (var i = 1; i <= steps; i++) {
    await g.moveTo(_map(tester, Offset.lerp(from, to, i / steps)!));
  }
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('app vào nền khi đang giữ nút nướng: kim lò đứng yên (không cháy), quay lại thả đúng vạch', (tester) async {
    final outcomes = <BakeOutcome>[];
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: outcomes.add)));
    final mould = await _until<MouldStation>(tester);
    await _drag(tester, MouldStation.slotCenter(mould.choices.indexOf(MouldType.cupcakeLiner)), MouldStation.trayRect.center);
    await _until<MixStation>(tester);
    final mix = await tester.startGesture(_map(tester, MixStation.center + const Offset(150, 0)));
    for (var i = 1; i <= 108; i++) {
      final a = i * 2 * math.pi / 36;
      await mix.moveTo(_map(tester, MixStation.center + Offset(math.cos(a), math.sin(a)) * 150));
    }
    await mix.up();
    await tester.pump();
    await tester.tap(find.text('Done'));
    final bake = await _until<BakeStation>(tester);

    final hold = await tester.startGesture(_map(tester, BakeStation.buttonCenter));
    await _run(tester, 1.0);
    final before = bake.meter.value;
    expect(before, closeTo(1 / 3, 0.03));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _run(tester, 10); // 10 s ở nền
    expect(bake.meter.value, closeTo(before, 0.02), reason: 'kim lò chạy trong lúc app ở nền');
    expect(bake.meter.released, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    while (bake.meter.value < 0.65 - 0.002) {
      await tester.pump(const Duration(milliseconds: 4));
    }
    await hold.up();
    await tester.pump();
    expect(_game(tester).record.bakeRelease, closeTo(0.65, 0.01));
    await _until<FrostStation>(tester);
  });

  testWidgets('đổi cỡ cửa sổ giữa màn (800×600 → 1920×1080 → 640×360): thao tác vẫn trúng, ra kết quả đúng', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    final outcomes = <BakeOutcome>[];
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: outcomes.add)));
    final mould = await _until<MouldStation>(tester);
    final correct = mould.choices.indexOf(MouldType.cupcakeLiner);

    // Đổi cỡ ngay giữa lúc kéo khuôn: Flutter giữ phép biến đổi lúc chạm xuống cho cả cử chỉ, nên cử chỉ đang dở có
    // thể lệch chỗ thả (giới hạn của framework) — chỉ yêu cầu không lỗi, không tính sai khuôn, kéo lại được.
    final g = await tester.startGesture(_map(tester, MouldStation.slotCenter(correct)));
    await g.moveTo(_map(tester, const Offset(600, 300)));
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump();
    await g.moveTo(_map(tester, const Offset(640, 650)));
    await g.up();
    await _run(tester, 1.2);
    expect(_game(tester).currentStation, same(mould));
    await _drag(tester, MouldStation.slotCenter(correct), MouldStation.trayRect.center);
    await _until<MixStation>(tester);
    expect(_game(tester).record.wrongMouldDrops, 0);

    final mix = await tester.startGesture(_map(tester, MixStation.center + const Offset(150, 0)));
    for (var i = 1; i <= 108; i++) {
      final a = i * 2 * math.pi / 36;
      await mix.moveTo(_map(tester, MixStation.center + Offset(math.cos(a), math.sin(a)) * 150));
    }
    await mix.up();
    await tester.pump();
    tester.view.physicalSize = const Size(640, 360);
    await tester.pump();
    await tester.tap(find.text('Done'));
    final bake = await _until<BakeStation>(tester);
    final hold = await tester.startGesture(_map(tester, BakeStation.buttonCenter));
    while (bake.meter.value < 0.65 - 0.002) {
      await tester.pump(const Duration(milliseconds: 4));
    }
    await hold.up();
    await _until<FrostStation>(tester);
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pump();
    final guide = spiralGuide(CakeArt.topSurface(FrostStation.cakeRectFor(MouldType.cupcakeLiner), MouldType.cupcakeLiner));
    final frost = await tester.startGesture(_map(tester, guide.first));
    for (final p in guide.skip(1)) {
      await frost.moveTo(_map(tester, p));
    }
    await frost.up();
    final topping = await _until<ToppingStation>(tester);
    tester.view.physicalSize = const Size(1000, 700);
    await tester.pump();
    final tray = topping.trays.indexOf(ToppingId.strawberry);
    await _drag(tester, ToppingStation.trayCenter(tray), topping.top.center.translate(-40, 0));
    await _drag(tester, ToppingStation.trayCenter(tray), topping.top.center.translate(40, 0));
    await tester.tap(find.text('Done'));
    await _until<BoxStation>(tester);
    await _drag(tester, BoxStation.cakeHome, BoxStation.boxCenter(boxChoices.indexOf(BoxType.small)));
    await _run(tester, 1.5);
    expect(outcomes, hasLength(1));
    final o = outcomes.single;
    expect(o.wrongMouldDrops, 0);
    expect(o.mixTurns, closeTo(3, 0.05));
    expect(o.bakeRelease, closeTo(0.65, 0.01));
    expect(o.frostCoverage, greaterThanOrEqualTo(0.98));
    expect(o.toppingsPlaced, {ToppingId.strawberry: 2});
    expect(o.boxChosen, BoxType.small);
  });
}
