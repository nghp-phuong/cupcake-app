import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/game/level/level_art.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_labels.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/tutorial_layer.dart';

// GĐ5: lớp hướng dẫn L1–L3 trong màn chơi (vùng sáng, tay chỉ, nhãn chữ) với bước giả lập (`debugTutorial`).
//
// Ảnh kiểm tra (PNG 1280×720): `P5_RENDER_DIR=<thư mục> flutter test test/game/level_tutorial_test.dart`.

LevelData _level({
  int startStock = 2,
  double every = 100,
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla],
  String? tutorial,
}) =>
    LevelData(
      id: 1,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 600,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: 3,
      startStock: startStock,
      patienceSec: 120,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      newRecipe: menu.last,
      tutorial: tutorial,
    );

LevelGame _game(LevelData level, {int seed = 3}) => LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        tutorialActive: level.tutorial != null,
        random: math.Random(seed),
      ),
    );

const _dt = 1 / 60;
const _frame = Rect.fromLTWH(0, 0, 1280, 720);

void _until(LevelGame g, bool Function() cond, {double maxSec = 40}) {
  for (var t = 0.0; !cond(); t += _dt) {
    if (t > maxSec) fail('quá $maxSec s mà điều kiện chưa đúng');
    g.step(_dt);
  }
}

void _run(LevelGame g, double sec) {
  for (var t = 0.0; t < sec; t += _dt) {
    g.step(_dt);
  }
}

void _tap(LevelGame g, Offset p, {int pointer = 1}) {
  g.pointerDown(pointer, p);
  g.pointerUp(pointer, p);
}

void _paintOnce(LevelGame g) {
  final recorder = ui.PictureRecorder();
  g.paint(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

LevelCustomer? _atCounter(LevelSession s) {
  for (final c in s.customers) {
    if (c.canBuy && c.phaseT >= 1) return c;
  }
  return null;
}

/// Kiểm một khung: đang hiện, đầu ngón trong vùng sáng (và trong [hit] nếu có), nhãn + tay trong khung, nhãn không
/// che vùng sáng / tay.
void _expectLayout(LevelGame g, String step, {Rect? hit, bool hasTarget = true}) {
  final t = g.tutorial;
  expect(t.visible, isTrue, reason: '$step: phải đang hiện');
  final bubble = t.bubbleRect;
  expect(bubble, isNotNull, reason: '$step: có nhãn chữ');
  expect(_frame.deflate(4).contains(bubble!.topLeft) && _frame.deflate(4).contains(bubble.bottomRight), isTrue,
      reason: '$step: nhãn $bubble tràn khung');
  expect(bubble.top, greaterThanOrEqualTo(LevelLayout.hudBottom), reason: '$step: nhãn bị HUD che');
  if (!hasTarget) {
    expect(t.targetRect, isNull);
    expect(t.handTip, isNull);
    return;
  }
  final target = t.targetRect!;
  final tip = t.handTip!;
  expect(target.contains(tip), isTrue, reason: '$step: đầu ngón $tip ngoài vùng sáng $target');
  if (hit != null) expect(hit.contains(tip), isTrue, reason: '$step: đầu ngón $tip ngoài vùng chạm $hit');
  final hand = t.handRect!;
  expect(hand.left >= -1 && hand.right <= 1281 && hand.top >= -1 && hand.bottom <= 721, isTrue, reason: '$step: tay $hand tràn khung');
  expect(bubble.overlaps(target.inflate(4)), isFalse, reason: '$step: nhãn $bubble che vùng sáng $target');
  expect(bubble.overlaps(hand), isFalse, reason: '$step: nhãn $bubble che tay $hand');
}

/// Kiểm [step] ở nhiều pha của hoạt cảnh tay (nhún / xoay / quẹt).
void _expectOverTime(LevelGame g, String step, {Rect? hit}) {
  for (var i = 0; i < 24; i++) {
    g.step(_dt * 3);
    _expectLayout(g, step, hit: hit);
  }
}

/// Chạy đủ kịch bản L1 với bước giả lập; [onStep] gọi ở mỗi bước khi lớp hướng dẫn đã hiện đủ (ảnh kiểm tra).
Future<void> _playL1(LevelGame g, {Future<void> Function(String step)? onStep}) async {
  final s = g.session;
  Future<void> shown(String step) async {
    _run(g, TutorialLayer.fadeSec + 0.05);
    if (onStep != null) await onStep(step);
  }

  // 1. Bán cho khách đầu tiên.
  g.step(_dt);
  _until(g, () => _atCounter(s) != null);
  final first = _atCounter(s)!;
  g.debugTutorial = TutorialPose('basicsSell', TutorialSpot.customer, customerId: first.id);
  await shown('sell');
  _expectOverTime(g, 'basicsSell', hit: g.shop.counterFrameOf(first.id));
  final served = s.served;
  _tap(g, g.tutorial.handTip!);
  expect(s.served, served + 1, reason: 'chạm đúng chỗ tay chỉ → bán được');

  // 2. Tủ sắp hết → thẻ bánh ở bếp.
  g.debugTutorial = TutorialPose('basicsBake', TutorialSpot.treatCard, recipe: RecipeId.cupcakeVanilla);
  await shown('bake');
  _expectOverTime(g, 'basicsBake', hit: LevelLayout.cardRect(0, 1));
  _tap(g, g.tutorial.handTip!);
  final b = s.kitchen.prep;
  expect(b, isNotNull, reason: 'chạm thẻ bánh → startBatch');

  // 3. Khuôn đúng.
  g.debugTutorial = TutorialPose('basicsMould', TutorialSpot.mould);
  await shown('mould');
  final mouldRow = LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.mouldTile), b!.mouldChoices.indexOf(b.correctMould));
  _expectOverTime(g, 'mould', hit: mouldRow);
  _tap(g, g.tutorial.handTip!);
  expect(b.stage, BatchStage.mix);
  expect(b.wrongMoulds, 0, reason: 'ngón tay chỉ đúng khuôn');

  // Trộn: tay đi vòng quanh âu, luôn trong ô Trộn.
  g.debugTutorial = TutorialPose('basicsMix', TutorialSpot.mix);
  await shown('mix');
  final tips = <Offset>{};
  for (var i = 0; i < 40; i++) {
    g.step(_dt * 2);
    _expectLayout(g, 'mix', hit: LevelLayout.tile(LevelLayout.mixTile));
    tips.add(g.tutorial.handTip!);
  }
  final xs = tips.map((p) => p.dx);
  expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(60), reason: 'tay xoay vòng');
  s.finishMix(1);

  // Lò: chỉ hiện khi kim gần vạch vàng.
  g.debugTutorial = TutorialPose('basicsOven', TutorialSpot.oven);
  g.step(_dt);
  expect(g.tutorial.visible, isFalse, reason: 'kim còn xa vạch → chưa hiện');
  _until(g, () => g.tutorial.visible);
  expect(b.ovenProgress, lessThan(b.bakeTarget));
  _until(g, () => b.ovenProgress >= b.bakeTarget - s.modifiers.bakePerfectHalfWidth * 0.5);
  if (onStep != null) await onStep('oven');
  _expectLayout(g, 'oven', hit: LevelLayout.ovenSlot(0, s.kitchen.ovens.length));
  _tap(g, g.tutorial.handTip!);
  expect(b.stage, BatchStage.frost, reason: 'chạm đúng lò → lấy ra');

  // Kem: tay quẹt ngang qua bánh.
  g.debugTutorial = TutorialPose('basicsFrost', TutorialSpot.frost);
  await shown('frost');
  _expectOverTime(g, 'frost', hit: LevelLayout.frostCake());
  s.finishFrost(1);

  // Topping: hũ đúng 3 lần.
  g.debugTutorial = TutorialPose('basicsTopping', TutorialSpot.topping);
  await shown('topping');
  final jar = LevelLayout.toppingJar(b.toppingChoices.indexOf(b.correctTopping));
  _expectOverTime(g, 'topping', hit: jar);
  for (var i = 0; i < 3; i++) {
    _tap(g, g.tutorial.handTip!);
    g.step(_dt);
  }
  expect(b.toppingsPlaced, 3);
  expect(b.stage, BatchStage.box);

  // Hộp đúng.
  g.debugTutorial = TutorialPose('basicsBox', TutorialSpot.box);
  await shown('box');
  final boxRow = LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.boxTile), b.boxChoices.indexOf(b.correctBox));
  _expectOverTime(g, 'box', hit: boxRow);
  _tap(g, g.tutorial.handTip!);
  expect(b.boxChosen, b.correctBox);

  // Mẻ vào tủ: chỉ vào ô tủ của món (như kịch bản core).
  g.debugTutorial = TutorialPose('basicsDone', TutorialSpot.caseSlot, recipe: RecipeId.cupcakeVanilla);
  await shown('done');
  _expectLayout(g, 'done');
  expect(g.tutorial.targetRect!.contains(g.shop.cellCenterOf(RecipeId.cupcakeVanilla)), isTrue);

  // Bước không có mục tiêu (vd. khách bỏ đi đã rời cảnh): chỉ nhãn chữ, không tay / không vùng sáng.
  g.debugTutorial = TutorialPose('patienceWalkout', TutorialSpot.none);
  await shown('walkout_text_only');
  _expectLayout(g, 'walkout', hasTarget: false);
  g.debugTutorial = null;
  _run(g, TutorialLayer.fadeSec + 0.05);
  expect(g.tutorial.visible, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mỗi bước L1: đầu ngón trong vùng chạm của mục tiêu, chạm đúng chỗ tay chỉ làm đúng thao tác, nhãn trong khung', () async {
    final g = _game(_level());
    await _playL1(g);
    for (var i = 0; i < 3; i++) {
      _paintOnce(g);
    }
  });

  test('kịch bản thật (session.tutorial, L1 basics): mỗi bước vẽ đúng mục tiêu, chạm đầu ngón làm xong bước', () {
    final g = _game(_level(tutorial: TutorialIds.basics, every: 6));
    final s = g.session;
    final runner = s.tutorial!;
    String? cur() => runner.current?.id;

    void at(TutorialStep step, {Rect? hit}) {
      _until(g, () => runner.current == step && g.tutorial.visible, maxSec: 60);
      _run(g, TutorialLayer.fadeSec);
      expect(g.tutorialPose!.step, step.id);
      _expectLayout(g, step.id, hit: hit);
    }

    at(TutorialSteps.basicsSell);
    final buyer = runner.targetCustomer!;
    expect(g.shop.counterFrameOf(buyer)!.contains(g.tutorial.handTip!), isTrue);
    _tap(g, g.tutorial.handTip!);
    expect(cur(), isNot(TutorialSteps.basicsSell.id));

    at(TutorialSteps.basicsBake, hit: LevelLayout.cardRect(0, 1));
    _tap(g, g.tutorial.handTip!);
    final b = s.kitchen.prep!;

    at(TutorialSteps.basicsMould);
    _tap(g, g.tutorial.handTip!);
    expect(b.wrongMoulds, 0);
    expect(b.stage, BatchStage.mix);

    at(TutorialSteps.basicsMix, hit: LevelLayout.tile(LevelLayout.mixTile));
    // Khuấy một vòng quanh âu bằng con trỏ.
    final c = LevelLayout.bowlCenter();
    g.pointerDown(2, c + const Offset(50, 0));
    for (var i = 1; i <= 40; i++) {
      final a = i / 40 * math.pi * 2.2;
      g.pointerMove(2, c + Offset(math.cos(a), math.sin(a)) * 50);
    }
    g.pointerUp(2, c + Offset(math.cos(math.pi * 2.2), math.sin(math.pi * 2.2)) * 50);
    g.step(_dt);
    expect(b.stage, anyOf(BatchStage.baking, BatchStage.waitingOven));

    at(TutorialSteps.basicsOven, hit: LevelLayout.ovenSlot(b.oven, s.kitchen.ovens.length));
    expect(b.ovenProgress, lessThan(b.bakeTarget));
    _until(g, () => b.ovenProgress >= b.bakeTarget - s.modifiers.bakePerfectHalfWidth * 0.5);
    _tap(g, g.tutorial.handTip!);
    expect(b.stage, BatchStage.frost);

    at(TutorialSteps.basicsFrost, hit: LevelLayout.frostCake());
    s.finishFrost(1);

    at(TutorialSteps.basicsTopping, hit: LevelLayout.toppingJar(b.toppingChoices.indexOf(b.correctTopping)));
    for (var i = 0; i < 3 && b.stage == BatchStage.topping; i++) {
      _tap(g, g.tutorial.handTip!);
      g.step(_dt);
    }
    expect(b.stage, BatchStage.box);

    at(TutorialSteps.basicsBox);
    _tap(g, g.tutorial.handTip!);
    expect(b.boxChosen, b.correctBox);

    at(TutorialSteps.basicsDone);
    // Bước thông tin chỉ vào ô tủ có món; chạm bất kỳ đâu → ẩn (chạm vẫn đi xuống cảnh).
    expect(g.tutorial.targetRect!.contains(g.shop.cellCenterOf(RecipeId.cupcakeVanilla)), isTrue);
    _tap(g, const Offset(1200, 600));
    g.step(_dt);
    expect(runner.current, isNull);
    expect(runner.finished, isTrue);
    _run(g, TutorialLayer.fadeSec + 0.05);
    expect(g.tutorial.visible, isFalse);
    _paintOnce(g);
  });

  test('L2 / L3: ô combo HUD, vòng kiên nhẫn, khách khác nhau', () {
    final g = _game(_level(startStock: 3, every: 0.8, menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate]), seed: 5);
    final s = g.session;
    // Vòng kiên nhẫn của khách ở quầy.
    _until(g, () => _atCounter(s) != null);
    final c = _atCounter(s)!;
    g.debugTutorial = TutorialPose('patienceRing', TutorialSpot.patienceRing, customerId: c.id);
    _run(g, 0.3);
    final bubble = g.shop.bubbleOf(c.id)!;
    _expectLayout(g, 'patience', hit: Rect.fromCircle(center: bubble, radius: LevelLayout.bubbleRadius + 18));
    expect(g.tutorial.targetRect!.contains(bubble), isTrue);

    g.debugTutorial = TutorialPose('comboVariety', TutorialSpot.customer, customerId: c.id);
    _run(g, 0.3);
    _expectLayout(g, 'variety', hit: g.shop.counterFrameOf(c.id));

    // Combo: chưa có combo → chưa hiện; bán 2 lượt liền → chỉ ô combo HUD (từ bên dưới HUD).
    g.debugTutorial = TutorialPose('comboMeter', TutorialSpot.comboMeter);
    g.step(_dt);
    expect(g.tutorial.visible, isFalse);
    for (var sold = 0; s.combo < 2;) {
      final buyer = s.customers.where((c) => c.canBuy && s.displayCase.countOf(c.want) > 0).firstOrNull;
      if (buyer != null && s.sell(buyer.id) == SellResult.sold) sold++;
      g.step(_dt);
      if (sold > 6) fail('không lên combo');
    }
    _run(g, 0.25);
    _expectLayout(g, 'combo');
    expect(g.tutorial.handTip!.dy, greaterThan(LevelLayout.hudBottom - 12), reason: 'tay nằm dưới HUD');
    expect(g.tutorial.handRect!.top, greaterThanOrEqualTo(LevelLayout.hudBottom - 12));
    expect(TutorialLayer.hudCombo.contains(g.tutorial.targetRect!.center), isTrue);
  });

  test('chạm sai chỗ: không chặn, tay nhấp nháy; bước exclusive thì nuốt chạm', () {
    final g = _game(_level(startStock: 2));
    final s = g.session;
    _until(g, () => _atCounter(s) != null);
    g.debugTutorial = TutorialPose('basicsBake', TutorialSpot.treatCard, recipe: RecipeId.cupcakeVanilla);
    _run(g, 0.3);
    expect(g.tutorial.flashing, isFalse);
    // Chạm khách (ngoài vùng sáng) → vẫn bán được, tay nhấp nháy.
    final c = _atCounter(s)!;
    final served = s.served;
    _tap(g, g.customerHitPoint(c.id)!);
    expect(s.served, served + 1);
    expect(g.tutorial.flashing, isTrue);
    _run(g, TutorialLayer.flashSec + 0.05);
    expect(g.tutorial.flashing, isFalse);
    // Chạm trong vùng sáng: không nhấp nháy.
    _tap(g, g.tutorial.handTip!);
    expect(g.tutorial.flashing, isFalse);
    expect(s.kitchen.prep, isNotNull);

    // Bước exclusive: chạm ngoài bị nuốt.
    final b = s.kitchen.prep!;
    g.debugTutorial = TutorialPose('basicsMould', TutorialSpot.mould, exclusive: true);
    _run(g, 0.3);
    final wrong = b.mouldChoices.indexWhere((m) => m != b.correctMould);
    _tap(g, LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.mouldTile), wrong).center);
    // Hàng khuôn sai nằm ngoài vùng sáng (hàng khuôn đúng) → bị nuốt, không tính sai.
    expect(b.wrongMoulds, 0);
    expect(g.tutorial.flashing, isTrue);
  });

  test('đổi bước: mờ dần 200 ms; nền tối + nhãn chỉ dựng lại khi đổi bước', () {
    final g = _game(_level());
    final s = g.session;
    _until(g, () => _atCounter(s) != null);
    final pose = TutorialPose('basicsSell', TutorialSpot.customer, customerId: _atCounter(s)!.id);
    g.debugTutorial = pose;
    g.step(_dt);
    expect(g.tutorial.fade, lessThan(0.2));
    _run(g, 0.1);
    expect(g.tutorial.fade, inInclusiveRange(0.4, 0.7));
    _run(g, 0.12);
    expect(g.tutorial.fade, 1);
    final dims = g.tutorial.debugDimBuilds, tags = g.tutorial.debugTagBuilds;
    for (var i = 0; i < 120; i++) {
      g.step(_dt);
      _paintOnce(g);
    }
    expect(g.tutorial.debugDimBuilds, dims, reason: 'không dựng lại mỗi khung');
    expect(g.tutorial.debugTagBuilds, tags);

    // Sang bước khác (cùng đối tượng pose, đổi trường): bước mới mờ dần vào.
    pose
      ..step = 'basicsBake'
      ..spot = TutorialSpot.treatCard
      ..customerId = null;
    g.step(_dt);
    expect(g.tutorial.fade, lessThan(0.2));
    _paintOnce(g); // bước cũ đang mờ ra + bước mới mờ vào
    _run(g, 0.25);
    expect(g.tutorial.fade, 1);
    expect(g.tutorial.debugDimBuilds, dims + 1);
    expect(g.tutorial.debugTagBuilds, tags + 1);

    // Đổi chuỗi (ngôn ngữ) → dựng lại nhãn.
    g.setLabels(LevelLabels.fallback);
    g.step(_dt);
    expect(g.tutorial.debugTagBuilds, tags + 2);

    // Tạm dừng / hết màn → ẩn.
    s.paused = true;
    g.step(_dt);
    expect(g.tutorial.visible, isFalse);
    s.paused = false;
    g.step(_dt);
    expect(g.tutorial.visible, isTrue);
  });

  test('chuỗi rỗng → không có nhãn; id lạ → chuỗi rỗng', () {
    expect(LevelLabels.fallbackTutorial('???'), isEmpty);
    for (final script in const [TutorialIds.basics, TutorialIds.combo, TutorialIds.patience]) {
      for (final step in TutorialSteps.of(script)) {
        expect(LevelLabels.fallbackTutorial(step.id), isNotEmpty, reason: step.id);
      }
    }
    final g = _game(_level());
    _until(g, () => _atCounter(g.session) != null);
    g.debugTutorial = TutorialPose('???', TutorialSpot.treatCard);
    _run(g, 0.3);
    expect(g.tutorial.visible, isTrue);
    expect(g.tutorial.bubbleRect, isNull);
    _paintOnce(g);
  });

  test('thiếu ảnh tay chỉ → tay vẽ code, không lỗi', () async {
    LevelArt.debugReset(bundle: _MissingBundle());
    await LevelArt.preload();
    expect(LevelArt.isMissing(LevelArtId.tutorialHand), isTrue);
    final g = _game(_level());
    _until(g, () => _atCounter(g.session) != null);
    g.debugTutorial = TutorialPose('basicsSell', TutorialSpot.customer);
    for (var i = 0; i < 30; i++) {
      g.step(_dt);
      _paintOnce(g);
    }
    expect(g.tutorial.visible, isTrue);
    expect(g.tutorial.targetRect!.contains(g.tutorial.handTip!), isTrue);
    _tap(g, const Offset(1200, 600)); // nhấp nháy (vẽ qua lớp mờ)
    for (var i = 0; i < 10; i++) {
      g.step(_dt);
      _paintOnce(g);
    }
    LevelArt.debugReset();
  });

  test('ảnh tay chỉ nạp được', () async {
    LevelArt.debugReset();
    await LevelArt.preload().timeout(const Duration(seconds: 20));
    expect(LevelArt.image(LevelArtId.tutorialHand), isNotNull);
    LevelArt.debugReset();
  });

  test('perf: lớp hướng dẫn thêm không đáng kể vào step + paint', () async {
    final level = _level(startStock: 6, every: 0.5, menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate]);
    await LevelGame.preloadFor(level).timeout(const Duration(seconds: 20), onTimeout: () => const []);
    double measure(bool withTutorial) {
      final g = _game(level, seed: 9);
      _until(g, () => _atCounter(g.session) != null);
      _run(g, 4);
      g.session.startBatch(RecipeId.cupcakeVanilla);
      if (withTutorial) g.debugTutorial = TutorialPose('basicsMould', TutorialSpot.mould);
      void frame() {
        g.step(_dt);
        _paintOnce(g);
      }

      for (var i = 0; i < 60; i++) {
        frame();
      }
      if (withTutorial) expect(g.tutorial.visible, isTrue);
      const frames = 600;
      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        frame();
      }
      return sw.elapsedMicroseconds / frames / 1000;
    }

    final base = measure(false);
    final tut = measure(true);
    // ignore: avoid_print
    print('LevelPlay GĐ5 perf: không hướng dẫn ${base.toStringAsFixed(3)} ms/khung, có hướng dẫn ${tut.toStringAsFixed(3)} ms/khung');
    expect(tut, lessThan(2));
    expect(tut - base, lessThan(0.5));
  });

  final renderDir = Platform.environment['P5_RENDER_DIR'];
  group('ảnh kiểm tra', () {
    setUpAll(_loadFonts);

    Future<void> shot(String name, LevelGame g) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(_frame, ui.Paint()..color = const Color(0xFFFFF4E6));
      g.paint(canvas);
      // HUD giả (ô combo) để thấy vùng sáng nằm đúng chỗ ô combo của ui.
      if (g.tutorialPose?.spot == TutorialSpot.comboMeter) {
        canvas.drawRRect(ui.RRect.fromRectAndRadius(TutorialLayer.hudCombo.deflate(2), const ui.Radius.circular(14)),
            ui.Paint()..color = const Color(0xFFFFE8B5));
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1280, 720);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(renderDir!).createSync(recursive: true);
      File('$renderDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    test('p5_tut_* (các bước L1 + combo + kiên nhẫn)', () async {
      LevelArt.debugReset();
      LevelCharacters.debugReset();
      final level = _level(startStock: 2, every: 100);
      await LevelGame.preloadFor(level).timeout(const Duration(seconds: 30), onTimeout: () => const []);
      final g = _game(level);
      g.setLabels(g.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      await _playL1(g, onStep: (step) => shot('p5_tut_l1_$step', g));

      final g2 = _game(_level(startStock: 3, every: 0.8, menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate]), seed: 5);
      g2.setLabels(g2.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      final s = g2.session;
      _until(g2, () => _atCounter(s) != null);
      for (var sold = 0; s.combo < 2;) {
        final buyer = s.customers.where((c) => c.canBuy && s.displayCase.countOf(c.want) > 0).firstOrNull;
        if (buyer != null && s.sell(buyer.id) == SellResult.sold) sold++;
        g2.step(_dt);
        if (sold > 6) fail('không lên combo');
      }
      g2.debugTutorial = TutorialPose('comboMeter', TutorialSpot.comboMeter);
      _run(g2, 0.3);
      await shot('p5_tut_l2_combo', g2);
      _until(g2, () => _atCounter(s) != null);
      g2.debugTutorial = TutorialPose('patienceRing', TutorialSpot.patienceRing, customerId: _atCounter(s)!.id);
      _run(g2, 0.3);
      await shot('p5_tut_l3_patience', g2);

      LevelArt.debugReset(bundle: _MissingBundle());
      await LevelArt.preload();
      g2.debugTutorial = TutorialPose('comboVariety', TutorialSpot.customer, customerId: _atCounter(s)!.id);
      _run(g2, 0.3);
      await shot('p5_tut_fallback_hand', g2);
      LevelCharacters.debugReset();
      LevelArt.debugReset();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, skip: renderDir == null ? 'đặt P5_RENDER_DIR để xuất ảnh kiểm tra' : null);
}

/// Bundle không có ảnh nào.
class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(StateError('thiếu $key'));
}

Future<void> _loadFonts() async {
  for (final (family, files) in const [
    ('Nunito', ['Nunito-Regular', 'Nunito-SemiBold', 'Nunito-Bold', 'Nunito-ExtraBold']),
    ('Fredoka', ['Fredoka-Medium', 'Fredoka-SemiBold', 'Fredoka-Bold']),
  ]) {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('assets/fonts/$name.ttf');
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      any = true;
    }
    if (any) await loader.load();
  }
}
