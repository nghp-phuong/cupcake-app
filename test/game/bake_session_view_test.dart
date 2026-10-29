import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
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
import 'package:sugarleaf_bakery/game/stations/topping_station.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2), ToppingRequest(ToppingId.sprinkles, 1)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.build(locale: locale, useGoogleFonts: false),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Đổi toạ độ khung 1280×720 → toạ độ màn hình test (view bị FittedBox thu nhỏ, có letterbox).
Offset Function(Offset) _mapper(WidgetTester tester) {
  final rect = tester.getRect(find.byKey(const ValueKey('bake-session-input')));
  final k = rect.width / 1280;
  return (p) => rect.topLeft + p * k;
}

BakeryGame _game(WidgetTester tester) =>
    tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;

Future<void> _run(WidgetTester tester, double seconds) async {
  final steps = (seconds / 0.05).ceil();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Chờ trạm 1 hiện (game chờ ảnh của trạm 1 tối đa `BakeryGame.maxArtWait`; ảnh không giải mã được trong
/// thời gian giả của test nên thường chờ hết hạn) rồi chờ hoạt cảnh vào trạm.
Future<void> _start(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 60 && _game(tester).currentStation == null; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await _run(tester, 0.8);
}

Future<void> _drag(WidgetTester tester, Offset Function(Offset) g, Offset from, Offset to, {int steps = 12}) async {
  final gesture = await tester.startGesture(g(from));
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(g(Offset.lerp(from, to, i / steps)!));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('chơi hết 6 trạm bằng cử chỉ thật (khung bị thu nhỏ), onComplete đúng 1 lần', (tester) async {
    final outcomes = <BakeOutcome>[];
    await tester.pumpWidget(_host(BakeSessionView(
      order: _order,
      modifiers: BakeModifiers.base,
      onComplete: outcomes.add,
    )));
    await _start(tester);
    final g = _mapper(tester);
    // Khung 1280×720 bị thu nhỏ trong màn test 800×600 → kiểm luôn đổi toạ độ con trỏ.
    expect(tester.getRect(find.byKey(const ValueKey('bake-session-input'))).width, lessThan(1280));
    final game = _game(tester);
    expect(find.text('Step 1/6'), findsOneWidget);

    // 1. Khuôn: thả sai một lần rồi thả đúng.
    final mould = game.currentStation! as MouldStation;
    final correct = mould.choices.indexOf(MouldType.cupcakeLiner);
    final wrong = (correct + 1) % 4;
    await _drag(tester, g, MouldStation.slotCenter(wrong), MouldStation.trayRect.center);
    expect(game.record.wrongMouldDrops, 1);
    await tester.pump();
    expect(find.text('Not this one!'), findsOneWidget);
    await _run(tester, 0.8);
    await _drag(tester, g, MouldStation.slotCenter(correct), MouldStation.trayRect.center);
    await _run(tester, 1.6);
    expect(game.currentStation, isA<MixStation>());
    expect(find.text('Step 2/6'), findsOneWidget);

    // 2. Trộn: đúng 3 vòng (mục tiêu của cupcake vani) rồi bấm Xong.
    expect(tester.widget<SLButton>(find.widgetWithText(SLButton, 'Done')).onPressed, isNull);
    final mixGesture = await tester.startGesture(g(MixStation.center + const Offset(150, 0)));
    for (var i = 1; i <= 108; i++) {
      final a = i * 2 * math.pi / 36;
      await mixGesture.moveTo(g(MixStation.center + Offset(math.cos(a), math.sin(a)) * 150));
    }
    await mixGesture.up();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SLButton>(find.widgetWithText(SLButton, 'Done')).onPressed, isNotNull);
    await tester.tap(find.text('Done'));
    await _run(tester, 1.5);
    expect(game.record.mixTurns, closeTo(3, 0.02));
    expect(game.currentStation, isA<BakeStation>());

    // 3. Nướng: giữ chuột ~1.95 s (mục tiêu 0.65 × 3 s).
    final hold = await tester.startGesture(g(BakeStation.buttonCenter), kind: PointerDeviceKind.mouse);
    await _run(tester, 1.95);
    await hold.up();
    await _run(tester, 1.8);
    expect(game.record.bakeRelease, closeTo(0.65, 0.05));
    expect(game.currentStation, isA<FrostStation>());

    // 4. Phủ kem: vẽ theo đường gợi ý → tự dừng khi ≥ 98%.
    final guide = spiralGuide(CakeArt.topSurface(FrostStation.cakeRectFor(MouldType.cupcakeLiner), MouldType.cupcakeLiner));
    final frost = await tester.startGesture(g(guide.first));
    for (final p in guide.skip(1)) {
      await frost.moveTo(g(p));
    }
    await frost.up();
    await _run(tester, 1.9);
    expect(game.record.frostCoverage, greaterThanOrEqualTo(0.98));
    expect(game.currentStation, isA<ToppingStation>());

    // 5. Topping: 2 dâu + 1 cốm; thêm 1 mồi rồi chạm để gỡ; 1 cái thả ngoài bánh bị bỏ.
    final topping = game.currentStation! as ToppingStation;
    final top = CakeArt.topSurface(ToppingStation.cakeRectFor(MouldType.cupcakeLiner), MouldType.cupcakeLiner);
    final spots = [top.center + const Offset(-60, 0), top.center + const Offset(60, 0), top.center + const Offset(0, -20)];
    final wanted = [ToppingId.strawberry, ToppingId.strawberry, ToppingId.sprinkles];
    for (var i = 0; i < wanted.length; i++) {
      await _drag(tester, g, ToppingStation.trayCenter(topping.trays.indexOf(wanted[i])), spots[i]);
    }
    final decoy = topping.trays.firstWhere((t) => !wanted.contains(t));
    final decoyAt = top.center + const Offset(0, 22);
    await _drag(tester, g, ToppingStation.trayCenter(topping.trays.indexOf(decoy)), decoyAt);
    await _drag(tester, g, ToppingStation.trayCenter(topping.trays.indexOf(decoy)), const Offset(100, 690));
    expect(game.record.toppingCounts, {ToppingId.strawberry: 2, ToppingId.sprinkles: 1, decoy: 1});
    final size = math.max(18, math.min(top.height * 0.42, top.width * 0.19));
    await tester.tapAt(g(decoyAt.translate(0, -size * 0.3)));
    await tester.pump();
    expect(game.record.toppingCounts, {ToppingId.strawberry: 2, ToppingId.sprinkles: 1});
    await tester.tap(find.text('Done'));
    await _run(tester, 1.5);
    expect(game.currentStation, isA<BoxStation>());
    expect(find.text('Step 6/6'), findsOneWidget);

    // 6. Hộp: kéo bánh vào hộp nhỏ.
    expect(outcomes, isEmpty);
    await _drag(tester, g, BoxStation.cakeHome, BoxStation.boxCenter(boxChoices.indexOf(BoxType.small)));
    await _run(tester, 0.3);
    expect(outcomes, isEmpty, reason: 'chờ hoạt cảnh đóng hộp 0.6 s');
    await _run(tester, 0.6);
    expect(outcomes, hasLength(1));
    await _run(tester, 2);
    expect(outcomes, hasLength(1));

    final o = outcomes.single;
    expect(o.wrongMouldDrops, 1);
    expect(o.mixTurns, closeTo(3, 0.02));
    expect(o.bakeRelease, closeTo(0.65, 0.05));
    expect(o.frostCoverage, greaterThanOrEqualTo(0.98));
    expect(o.toppingsPlaced, {ToppingId.strawberry: 2, ToppingId.sprinkles: 1});
    expect(o.boxChosen, BoxType.small);
    // Game chỉ đo; chấm điểm ở core — chơi chuẩn (trừ 1 lần sai khuôn) vẫn được 5★.
    final result = Scoring.evaluate(
      order: _order,
      customer: const Customer(kind: CustomerKind.regular, appearanceSeed: 1),
      outcome: o,
      modifiers: BakeModifiers.base,
      decorTipBonusPct: 0,
    );
    expect(result.stars, 5);
  });

  testWidgets('thẻ hướng dẫn: hiện, báo onTutorialShown, chặn thao tác tới khi bấm Got it', (tester) async {
    final shown = <StationId>[];
    await tester.pumpWidget(_host(
      BakeSessionView(
        order: _order,
        modifiers: BakeModifiers.base,
        onComplete: (_) {},
        tutorialFor: const {StationId.mould},
        onTutorialShown: shown.add,
      ),
      locale: const Locale('vi'),
    ));
    await _start(tester);
    final g = _mapper(tester);
    final game = _game(tester);
    expect(shown, [StationId.mould]);
    expect(find.text('Đã hiểu!'), findsOneWidget);
    expect(find.text('Kéo đúng khuôn vào khay'), findsWidgets);

    final mould = game.currentStation! as MouldStation;
    final correct = mould.choices.indexOf(MouldType.cupcakeLiner);
    // Thẻ đang che: kéo không có tác dụng.
    await _drag(tester, g, MouldStation.slotCenter(correct), MouldStation.trayRect.center);
    await _run(tester, 1.6);
    expect(game.currentStation, isA<MouldStation>());

    await tester.tap(find.text('Đã hiểu!'));
    await tester.pump();
    expect(find.text('Đã hiểu!'), findsNothing);
    await _drag(tester, g, MouldStation.slotCenter(correct), MouldStation.trayRect.center);
    await _run(tester, 1.6);
    expect(game.currentStation, isA<MixStation>());
    expect(shown, [StationId.mould]);
  });

  testWidgets('trạm 1 chờ ảnh của nó tối đa maxArtWait (nền giấy vẽ tay trong lúc chờ) rồi vẫn vào', (tester) async {
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {})));
    await tester.pump();
    final game = _game(tester);
    expect(game.waitingForArt, game.currentStation == null);
    await _run(tester, BakeryGame.maxArtWait + 0.2);
    expect(game.waitingForArt, isFalse);
    expect(game.currentStation, isA<MouldStation>());
  });
}
