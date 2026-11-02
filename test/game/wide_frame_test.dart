import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

// Khung rộng (máy 20:9, W = 1600): thế giới 1280×720 nằm giữa, lệch inset = 160. Chạm ở màn x + inset trúng cùng điểm
// thế giới như khung 1280; cửa (điểm sinh khách) ở ngoài mép phải màn; đồng xu bay tới ô xu HUD đã dời.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.muffinBlueberry];

LevelData _level() => const LevelData(
      id: 3,
      chapter: 1,
      title: {'en': 'Wide', 'vi': 'Wide'},
      durationSec: 300,
      goal: LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: _menu,
      caseSlots: 4,
      startStock: 4,
      patienceSec: 120,
      spawn: SpawnCurve(startEverySec: 1.5, endEverySec: 1.5, rushAtPct: 60, rushEverySec: 1),
      specials: [],
      newRecipe: RecipeId.muffinBlueberry,
    );

LevelSession _session() => LevelSession(
      level: _level(),
      defaults: const LevelDefaults(jitterPct: 0),
      modifiers: BakeModifiers.base,
      random: math.Random(7),
    );

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

Widget _host(Widget child, {double width = 1600}) => MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RefScope(metrics: RefMetrics(width: width), child: child)),
    );

/// Toạ độ thế giới 1280×720 → toạ độ màn test, qua lớp nhận con trỏ [key] (khung W×720 bị FittedBox thu nhỏ).
Offset Function(Offset) _mapper(WidgetTester tester, String key, double width) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  final k = rect.width / width;
  final inset = (width - 1280) / 2;
  return (p) => rect.topLeft + Offset(p.dx + inset, p.dy) * k;
}

/// Theo dõi lần đầu thấy từng khách: cạnh trái khung ảnh khi khách vừa vào phải ở ngoài mép phải màn (thế giới
/// 1280 + inset).
void _expectSpawnOffscreen(double inset) {
  final g = LevelGame(session: _session())..inset = inset;
  final s = g.session;
  final seen = <int>{};
  var checked = 0;
  for (var i = 0; i < 60 * 12 && checked < 4; i++) {
    g.step(1 / 60);
    for (final c in s.customers) {
      if (c.isSpecial || !seen.add(c.id)) continue;
      final head = g.shop.headOf(c.id);
      expect(head, isNotNull);
      expect(c.phase, CustomerPhase.entering);
      // Nửa bề ngang khung ảnh ở cửa: 240 × 0.8 × 0.75 / 2 = 72.
      const half = LevelLayout.customerHeight * LevelLayout.doorScale * 0.75 / 2;
      expect(head!.dx - half, greaterThanOrEqualTo(1280 + inset - 2), reason: 'khách ${c.id} hiện ra trong màn');
      checked++;
    }
  }
  expect(checked, greaterThan(0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelLayout khung rộng', () {
    test('cửa ngoài mép phải màn: inset 0 → 1360 như cũ; inset 160 → 1520', () {
      expect(LevelLayout.doorXFor(0), LevelLayout.doorX);
      expect(LevelLayout.doorXFor(160), 1520);
      expect(LevelLayout.doorXFor(-5), LevelLayout.doorX);
    });

    test('ô xu HUD: inset 0 → hudCoins; inset 160 → dời +160 trong toạ độ thế giới', () {
      expect(LevelLayout.hudCoinsFor(0), LevelLayout.hudCoins);
      expect(LevelLayout.hudCoinsFor(160), const Offset(1171, 30));
      // Trên màn: 1171 + 160 = 1331 = 1011 + (1600 − 1280) → ô xu bám mép phải khung W.
      expect(LevelLayout.hudCoinsFor(160).dx + 160, LevelLayout.hudCoins.dx + 320);
    });

    test('ô xu HUD lùi theo tai thỏ phải: (1011 + inset − safeRight, 30)', () {
      expect(LevelLayout.hudCoinsFor(160, safeRight: 40), const Offset(1131, 30));
      expect(LevelLayout.hudCoinsFor(160, safeRight: 0), LevelLayout.hudCoinsFor(160));
      expect(LevelLayout.hudCoinsFor(0, safeRight: 0), LevelLayout.hudCoins);
      // Trên màn: 1131 + 160 = 1291 = 1011 + (1600 − 1280) − 40.
      expect(LevelLayout.hudCoinsFor(160, safeRight: 40).dx + 160, LevelLayout.hudCoins.dx + 320 - 40);
    });

    test('vùng vẽ khách mở ra hai bên theo inset; inset 0 → đúng path cũ', () {
      expect(identical(LevelLayout.customerClipFor(0), LevelLayout.customerClip), isTrue);
      final wide = LevelLayout.customerClipFor(160);
      expect(wide.contains(const Offset(-150, 100)), isTrue);
      expect(wide.contains(const Offset(1430, 100)), isTrue);
      expect(LevelLayout.customerClip.contains(const Offset(1300, 100)), isFalse);
      // Máy tính tiền vẫn che khách.
      expect(wide.contains(LevelLayout.register.center), isFalse);
    });

    test('LevelGame.insetFor: (W − 1280) / 2, không âm', () {
      expect(LevelGame.insetFor(1280), 0);
      expect(LevelGame.insetFor(1600), 160);
      expect(LevelGame.insetFor(1000), 0);
    });

    test('hệ số màn ảnh nhân vật theo khung W×720 (máy 20:9 1080p → 1.6, 720p → 1.0)', () {
      expect(LevelCharacters.scaleFor(const Size(2400, 1080)), 1.6);
      expect(LevelCharacters.scaleFor(const Size(1600, 720)), 1.0);
      expect(LevelCharacters.scaleFor(const Size(1280, 720)), 1.0);
    });
  });

  group('điểm sinh khách ngoài mép màn', () {
    test('khung 1280 (inset 0): khách vào từ ngoài x 1280', () => _expectSpawnOffscreen(0));
    test('khung 1600 (inset 160): khách vào từ ngoài x 1440 (thế giới)', () => _expectSpawnOffscreen(160));
  });

  test('vẽ ở khung rộng không lỗi (nền tiệm / bếp dự phòng trải hai bên)', () {
    final g = LevelGame(session: _session())..inset = 160;
    for (var i = 0; i < 120; i++) {
      g.step(1 / 60);
    }
    final recorder = PictureRecorder();
    g.paint(Canvas(recorder));
    recorder.endRecording().dispose();
    g.inset = 0;
    final again = PictureRecorder();
    g.paint(Canvas(again));
    again.endRecording().dispose();
  });

  testWidgets('màn chơi level W = 1600: game rộng 1600, chạm ở màn x + 160 trúng thẻ món', (tester) async {
    final s = _session();
    await tester.pumpWidget(_host(LevelPlayView(session: s, onSpecialTap: (_) {})));
    await tester.pump();
    final game = tester.widget<GameWidget<LevelGame>>(find.byType(GameWidget<LevelGame>)).game!;
    expect(game.inset, 160);
    expect(game.hudSafeRight, 0);
    final g = _mapper(tester, 'level-play-input', 1600);
    final card = LevelLayout.cardRect(0, _menu.length).center;
    // Chạm ở toạ độ chưa trừ inset (thế giới x − 160) → không trúng thẻ.
    final rect = tester.getRect(find.byKey(const ValueKey('level-play-input')));
    await tester.tapAt(rect.topLeft + card * (rect.width / 1600));
    await tester.pump();
    expect(s.kitchen.prep, isNull);
    await tester.tapAt(g(card));
    await tester.pump();
    expect(s.kitchen.prep, isNotNull);
    expect(s.kitchen.prep!.recipe, _menu.first);
  });

  testWidgets('màn chơi level W = 1600 có tai thỏ phải: game nhận safe.right để đích đồng xu lùi theo HUD', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RefScope(
          metrics: const RefMetrics(width: 1600, safe: EdgeInsets.only(right: 40)),
          child: LevelPlayView(session: _session(), onSpecialTap: (_) {}),
        ),
      ),
    ));
    await tester.pump();
    final game = tester.widget<GameWidget<LevelGame>>(find.byType(GameWidget<LevelGame>)).game!;
    expect(game.hudSafeRight, 40);
    expect(LevelLayout.hudCoinsFor(game.inset, safeRight: game.hudSafeRight), const Offset(1131, 30));
  });

  testWidgets('màn chơi level W = 1280: không lệch (inset 0)', (tester) async {
    final s = _session();
    await tester.pumpWidget(_host(LevelPlayView(session: s, onSpecialTap: (_) {}), width: 1280));
    await tester.pump();
    final game = tester.widget<GameWidget<LevelGame>>(find.byType(GameWidget<LevelGame>)).game!;
    expect(game.inset, 0);
    await tester.tapAt(_mapper(tester, 'level-play-input', 1280)(LevelLayout.cardRect(0, _menu.length).center));
    await tester.pump();
    expect(s.kitchen.prep, isNotNull);
  });

  testWidgets('làm bánh W = 1600: kéo khuôn đúng (màn x + 160) qua trạm; thanh bước chạm mép phải khung', (tester) async {
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {})));
    await tester.pump();
    final game = tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;
    for (var i = 0; i < 60 && game.currentStation == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.inset, 160);
    final rect = tester.getRect(find.byKey(const ValueKey('bake-session-input')));
    final k = rect.width / 1600;
    // Chữ "Step 1/6" ở mép phải thanh bước: nằm trong dải mở rộng bên phải (sau vùng 1280 giữa).
    final step = tester.getRect(find.text('Step 1/6'));
    expect(step.right, greaterThan(rect.left + (160 + 1280) * k));
    expect(step.right, lessThanOrEqualTo(rect.right));
    // Dải thanh bước lộ tới y 72 (khung): nút thoát bếp đơn đặc biệt của ui (top 84, bám mép trái) không đè lên.
    final bar = tester.getRect(find.ancestor(of: find.text('Step 1/6'), matching: find.byType(IgnorePointer)).first);
    expect(bar.left, lessThan(rect.left));
    expect(bar.right, greaterThan(rect.right));
    expect(bar.bottom, lessThanOrEqualTo(rect.top + 72 * k + 0.01));
    expect(bar.bottom, lessThan(rect.top + 84 * k));

    final g = _mapper(tester, 'bake-session-input', 1600);
    final mould = game.currentStation! as MouldStation;
    final correct = mould.choices.indexOf(MouldType.cupcakeLiner);
    final gesture = await tester.startGesture(g(MouldStation.slotCenter(correct)));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(g(Offset.lerp(MouldStation.slotCenter(correct), MouldStation.trayRect.center, i / steps)!));
    }
    await gesture.up();
    for (var i = 0; i < 32; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.record.wrongMouldDrops, 0);
    expect(game.currentStation, isA<MixStation>());
    // Nút Xong (trạm trộn) nằm trong vùng 1280 giữa: x 1060..1240 thế giới.
    final done = tester.getRect(find.text('Done'));
    expect(done.center.dx, inInclusiveRange(rect.left + (160 + 1060) * k, rect.left + (160 + 1240) * k));
  });
}
