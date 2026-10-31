import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

// QA: màn chơi level (bếp nhanh + sân tiệm) với thao tác biên: bấm loạn nhiều ngón, hai ngón cùng khuấy, tạm dừng giữa
// lúc kéo, hết giờ, app vào nền, đổi cỡ cửa sổ giữa màn.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.muffinBlueberry, RecipeId.eggTart, RecipeId.macaron];

LevelData _level({double every = 2, int durationSec = 300, int startStock = 4, List<RecipeId> menu = _menu}) => LevelData(
      id: 12,
      chapter: 2,
      title: const {'en': 'QA', 'vi': 'QA'},
      durationSec: durationSec,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: 4,
      startStock: startStock,
      patienceSec: 120,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 60, rushEverySec: every / 2),
      specials: const [SpecialVisit(atSec: 20, who: SpecialWho.linh, recipe: RecipeId.macaron)],
      newRecipe: menu.last,
    );

LevelSession _session(LevelData level, {int seed = 5}) => LevelSession(
      level: level,
      defaults: const LevelDefaults(jitterPct: 0),
      modifiers: BakeModifiers.base,
      random: math.Random(seed),
    );

const _dt = 1 / 60;

void _paintOnce(LevelGame g) {
  final recorder = PictureRecorder();
  g.paint(Canvas(recorder));
  recorder.endRecording().dispose();
}

void _tap(LevelGame g, Offset p, {int pointer = 1}) {
  g.pointerDown(pointer, p);
  g.pointerUp(pointer, p);
}

void _until(LevelGame g, bool Function() cond, {double maxSec = 30}) {
  for (var t = 0.0; !cond(); t += _dt) {
    if (t > maxSec) fail('quá $maxSec s mà điều kiện chưa đúng');
    g.step(_dt);
  }
}

/// Đưa một mẻ cupcake vani tới trạm trộn.
Batch _toMix(LevelGame g) {
  final s = g.session;
  _tap(g, LevelLayout.cardRect(0, s.level.menu.length).center);
  final b = s.kitchen.prep!;
  _tap(g, LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.mouldTile), b.mouldChoices.indexOf(b.correctMould)).center);
  expect(b.stage, BatchStage.mix);
  return b;
}

Offset _onBowl(double turns, {double r = 50}) {
  final a = turns * 2 * math.pi;
  return LevelLayout.bowlCenter() + Offset(math.cos(a), math.sin(a)) * r;
}

void _stir(LevelGame g, int pointer, double from, double to, {int stepsPerTurn = 40}) {
  final n = ((to - from) * stepsPerTurn).ceil();
  for (var i = 1; i <= n; i++) {
    g.pointerMove(pointer, _onBowl(from + (to - from) * i / n));
  }
}

/// Kiểm các bất biến của bếp + tủ sau mỗi bước.
void _checkInvariants(LevelSession s) {
  final dc = s.displayCase;
  for (var i = 0; i < dc.slots; i++) {
    expect(dc.items[i].count, inInclusiveRange(0, dc.slotCapacity), reason: 'ô tủ $i');
  }
  final f = s.kitchen.finish;
  if (f != null) {
    expect(f.toppingsPlaced, inInclusiveRange(0, Batch.toppingTaps));
    expect(f.stage.index, greaterThanOrEqualTo(BatchStage.frost.index));
  }
  final p = s.kitchen.prep;
  if (p != null) expect(p.stage.index, lessThanOrEqualTo(BatchStage.waitingOven.index));
  for (final b in s.kitchen.ovens) {
    if (b != null) expect(b.stage, anyOf(BatchStage.baking, BatchStage.ovenDone));
  }
  expect(s.coins, greaterThanOrEqualTo(0));
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Offset _map(WidgetTester tester, Offset p) {
  final rect = tester.getRect(find.byKey(const ValueKey('level-play-input')));
  return rect.topLeft + p * (rect.width / 1280);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bấm loạn 4 ngón (6000 sự kiện: chạm, kéo, huỷ, khung hình xen kẽ) → không lỗi, bếp / tủ luôn hợp lệ', () {
    final g = LevelGame(session: _session(_level(every: 1.2)));
    final s = g.session;
    final rnd = math.Random(42);
    final down = <int>{};
    Offset any() => Offset(rnd.nextDouble() * 1280, 40 + rnd.nextDouble() * 680);
    Offset kitchen() => Offset(10 + rnd.nextDouble() * 1260, LevelLayout.kitchenTop + rnd.nextDouble() * 280);
    for (var i = 0; i < 6000; i++) {
      final pointer = 1 + rnd.nextInt(4);
      final roll = rnd.nextDouble();
      if (!down.contains(pointer)) {
        g.pointerDown(pointer, roll < 0.75 ? kitchen() : any());
        down.add(pointer);
      } else if (roll < 0.55) {
        // Khuấy / quẹt: một đoạn trên âu hoặc trên bánh kem.
        final c = rnd.nextBool() ? LevelLayout.bowlCenter() : LevelLayout.frostCake().center;
        g.pointerMove(pointer, c + Offset(rnd.nextDouble() * 120 - 60, rnd.nextDouble() * 120 - 60));
      } else if (roll < 0.95) {
        g.pointerUp(pointer, kitchen());
        down.remove(pointer);
      } else {
        g.pointerCancel(pointer);
        down.remove(pointer);
      }
      if (i % 3 == 0) g.step(_dt);
      if (i % 200 == 0) {
        s.paused = !s.paused && rnd.nextDouble() < 0.3;
        _paintOnce(g);
      }
      _checkInvariants(s);
    }
    s.paused = false;
    for (var i = 0; i < 120; i++) {
      g.step(_dt);
    }
    _paintOnce(g);
    _checkInvariants(s);
  });

  test('hai ngón cùng khuấy: chỉ ngón chạm trước được tính', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 0)));
    g.step(_dt);
    final b = _toMix(g);
    g.pointerDown(1, _onBowl(0));
    g.pointerDown(2, _onBowl(0.5));
    _stir(g, 2, 0.5, 3.5); // ngón 2 xoay 3 vòng
    expect(g.kitchen.mixTurns, 0);
    _stir(g, 1, 0, 1);
    expect(g.kitchen.mixTurns, closeTo(1, 0.05));
    g.pointerUp(2, _onBowl(3.5));
    expect(b.stage, BatchStage.mix, reason: 'nhấc ngón 2 (bị bỏ qua) không chốt mẻ');
    g.pointerUp(1, _onBowl(1));
    expect(b.stage, isNot(BatchStage.mix));
  });

  test('tạm dừng giữa lúc khuấy: ngón bị nhả, kéo trong lúc dừng không tính, mẻ không bị chốt; chạy tiếp khuấy lại được', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 0)));
    final s = g.session;
    g.step(_dt);
    final b = _toMix(g);
    g.pointerDown(1, _onBowl(0));
    _stir(g, 1, 0, 0.3);
    final before = g.kitchen.mixTurns;
    s.paused = true;
    g.step(_dt);
    _stir(g, 1, 0.3, 2.3); // kéo khi đang dừng
    g.pointerUp(1, _onBowl(2.3)); // nhấc khi đang dừng → huỷ, không finishMix
    expect(g.kitchen.mixTurns, closeTo(before, 1e-9));
    expect(b.stage, BatchStage.mix);
    // Bấm thẻ món / lò / khách khi đang dừng: không làm gì.
    _tap(g, LevelLayout.cardRect(1, s.level.menu.length).center, pointer: 3);
    _tap(g, LevelLayout.cancelPrep().center, pointer: 3);
    expect(s.kitchen.prep, same(b));
    s.paused = false;
    g.step(_dt);
    // Ngón cũ (đã bị nhả) di chuyển tiếp: không tính.
    _stir(g, 1, 2.3, 3.3);
    expect(g.kitchen.mixTurns, closeTo(before, 1e-9));
    g.pointerDown(4, _onBowl(0));
    _stir(g, 4, 0, 0.8);
    g.pointerUp(4, _onBowl(0.8));
    expect(b.stage, isNot(BatchStage.mix));
    g.step(_dt);
    _paintOnce(g);
  });

  test('tạm dừng giữa lúc quẹt kem: quẹt khi dừng không cộng độ phủ', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 0)));
    final s = g.session;
    g.step(_dt);
    final b = _toMix(g);
    s.finishMix(1);
    _until(g, () => b.ovenProgress >= b.bakeTarget);
    _tap(g, LevelLayout.ovenSlot(0, 1).center);
    expect(b.stage, BatchStage.frost);
    final cake = LevelLayout.frostCake();
    g.pointerDown(1, cake.centerLeft);
    g.pointerMove(1, cake.center);
    final before = g.kitchen.frostCoverage;
    expect(before, greaterThan(0));
    s.paused = true;
    g.step(_dt);
    for (var k = 0; k < 10; k++) {
      g.pointerMove(1, cake.centerLeft);
      g.pointerMove(1, cake.centerRight);
    }
    g.pointerUp(1, cake.centerRight);
    expect(g.kitchen.frostCoverage, closeTo(before, 1e-9));
    expect(b.stage, BatchStage.frost);
    s.paused = false;
    g.step(_dt);
  });

  test('chạm liên tục: hũ topping 10 lần → đúng 3 lần; lò 2 lần → lấy 1 lần; hộp 5 lần → vào tủ 1 mẻ', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 0)));
    final s = g.session;
    final events = <SessionEvent>[];
    g.onEvent = events.add;
    g.step(_dt);
    final b = _toMix(g);
    s.finishMix(1);
    _until(g, () => b.ovenProgress >= b.bakeTarget);
    _tap(g, LevelLayout.ovenSlot(0, 1).center, pointer: 1);
    _tap(g, LevelLayout.ovenSlot(0, 1).center, pointer: 2);
    expect(b.stage, BatchStage.frost);
    expect(b.oven, -1);
    _tap(g, LevelLayout.frostDone().center);
    final jar = LevelLayout.toppingJar(b.toppingChoices.indexOf(b.correctTopping));
    for (var k = 0; k < 10; k++) {
      _tap(g, jar.center, pointer: 1 + k % 3);
    }
    expect(b.toppingsPlaced, 3);
    expect(b.stage, BatchStage.box);
    final row = LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.boxTile), b.boxChoices.indexOf(b.correctBox));
    for (var k = 0; k < 5; k++) {
      _tap(g, row.center, pointer: 1 + k % 2);
    }
    g.step(_dt);
    expect(events.where((e) => e.type == SessionEventType.batchReady), hasLength(1));
    expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), s.tuning.batchSize);
    _checkInvariants(s);
  });

  test('hết giờ giữa lúc khuấy: ngón bị nhả, mọi chạm sau đó không đổi gì', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 2, durationSec: 5)));
    final s = g.session;
    g.step(_dt);
    final b = _toMix(g);
    g.pointerDown(1, _onBowl(0));
    _stir(g, 1, 0, 0.4);
    _until(g, () => s.isOver, maxSec: 10);
    _stir(g, 1, 0.4, 2);
    g.pointerUp(1, _onBowl(2));
    expect(b.stage, BatchStage.mix);
    final coins = s.coins;
    for (var k = 0; k < 50; k++) {
      _tap(g, Offset(20 + k * 25.0, 460 + (k % 5) * 50.0), pointer: k);
    }
    expect(s.coins, coins);
    expect(s.kitchen.prep, same(b));
    g.step(_dt);
    _paintOnce(g);
  });

  test('đổi lượt chơi (attachSession) giữa lúc khuấy: nhấc ngón không chốt mẻ của lượt mới', () {
    final g = LevelGame(session: _session(_level(every: 100, startStock: 0)));
    g.step(_dt);
    _toMix(g);
    g.pointerDown(1, _onBowl(0));
    _stir(g, 1, 0, 1);
    final next = _session(_level(every: 100, startStock: 0), seed: 9);
    g.attachSession(next);
    g.step(_dt);
    final b2 = _toMix(g);
    _stir(g, 1, 1, 2);
    g.pointerUp(1, _onBowl(2));
    expect(b2.stage, BatchStage.mix);
    expect(g.kitchen.mixTurns, 0);
    g.step(_dt);
    _paintOnce(g);
  });

  group('LevelPlayView', () {
    testWidgets('app vào nền giữa màn: giờ màn đứng yên; quay lại không nhảy giờ', (tester) async {
      final s = _session(_level());
      await tester.pumpWidget(_host(LevelPlayView(session: s, onSpecialTap: (_) {})));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final t0 = s.elapsed;
      expect(t0, greaterThan(1.5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(s.elapsed, closeTo(t0, 0.25), reason: 'giờ màn chạy khi app ở nền');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(s.elapsed - t0, lessThan(LevelSession.maxFrameDt + 0.1));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s.elapsed, greaterThan(t0 + 0.5));
      s.dispose();
    });

    testWidgets('đổi cỡ cửa sổ giữa màn: chạm vẫn trúng thẻ món / khuôn / âu theo khung mới', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      final s = _session(_level(every: 100, startStock: 0));
      await tester.pumpWidget(_host(LevelPlayView(session: s, onSpecialTap: (_) {})));
      await tester.pump(const Duration(milliseconds: 16));
      final game = tester.widget<GameWidget<LevelGame>>(find.byType(GameWidget<LevelGame>)).game!;
      for (final size in const [Size(1920, 1080), Size(640, 360), Size(1280, 1000), Size(2400, 1080)]) {
        tester.view.physicalSize = size;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tapAt(_map(tester, LevelLayout.cardRect(0, _menu.length).center));
        await tester.pump(const Duration(milliseconds: 16));
        final b = s.kitchen.prep;
        expect(b, isNotNull, reason: 'cỡ $size: chạm thẻ món không trúng');
        await tester.tapAt(
            _map(tester, LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.mouldTile), b!.mouldChoices.indexOf(b.correctMould)).center));
        await tester.pump(const Duration(milliseconds: 16));
        expect(b.stage, BatchStage.mix, reason: 'cỡ $size');
        await tester.tapAt(_map(tester, LevelLayout.cancelPrep().center));
        await tester.pump(const Duration(milliseconds: 16));
        expect(s.kitchen.prep, isNull, reason: 'cỡ $size');
      }
      expect(game.session, same(s));
      s.dispose();
    });
  });
}
