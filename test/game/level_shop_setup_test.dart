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
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/level_paint.dart';
import 'package:sugarleaf_bakery/game/level/shop_look.dart';
import 'package:sugarleaf_bakery/game/level/shop_view.dart';

// GĐ3: cảnh tiệm vẽ theo `session.setup` (kệ bánh tầng, lò thứ 2, bàn ghế, ảnh lò theo lò nhanh) + đồ trang trí đặt.
//
// Ảnh kiểm tra (PNG 1280×720): `P3_RENDER_DIR=<thư mục> flutter test test/game/level_shop_setup_test.dart`.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];

LevelData _level({int caseSlots = 3, double every = 100, int startStock = 3, int maxQueue = 5, List<RecipeId> menu = _menu}) =>
    LevelData(
      id: 8,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 600,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: 900,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      newRecipe: menu.last,
      overrides: {'maxQueue': maxQueue},
    );

const _full = ShopSetup(
  caseSlotsBonus: 1,
  ovens: 2,
  maxQueueBonus: 2,
  patienceMult: 1.15,
  owned: {'case_stand', 'oven_2', 'cafe_tables'},
  equipmentTiers: {'fastOven': 3},
);

/// Tủ rộng (`wideCase` cấp cao nhất: ô 10 cái) + kệ tầng, mẻ 4 cái.
const _wide = ShopSetup(caseSlotsBonus: 1, batchSize: 4, slotCapacity: 10, owned: {'case_stand'});

const _decor = {DecorSlot.counter: DecorId.counterFlowers, DecorSlot.plant: DecorId.plantLemonTree};

LevelGame _game(LevelData level, {ShopSetup setup = ShopSetup.base, Map<DecorSlot, DecorId?> decor = const {}, int seed = 3}) =>
    LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        setup: setup,
        random: math.Random(seed),
      ),
      decor: decor,
    );

const _dt = 1 / 60;

void _paintOnce(LevelGame g) {
  final recorder = ui.PictureRecorder();
  g.paint(ui.Canvas(recorder));
  recorder.endRecording().dispose();
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

/// Đưa một mẻ [r] qua lò: chọn khuôn đúng, trộn 1 vòng (mẻ tự vào lò trống đầu tiên).
void _toOven(LevelGame g, RecipeId r) {
  final s = g.session;
  expect(s.startBatch(r), isTrue);
  s.pickMould(s.kitchen.prep!.correctMould);
  s.finishMix(1);
}

/// Làm trọn một mẻ [r] (bằng hàm session) để có bánh trong tủ.
void _bakeInto(LevelGame g, RecipeId r) {
  final s = g.session;
  _toOven(g, r);
  final oven = s.kitchen.ovens.indexWhere((b) => b != null && b.recipe == r && b.stage == BatchStage.baking);
  expect(oven, greaterThanOrEqualTo(0));
  final b = s.kitchen.ovens[oven]!;
  for (var t = 0.0; b.ovenProgress < b.bakeTarget; t += _dt) {
    if (t > 30) fail('lò không chạy');
    g.step(_dt);
  }
  s.takeOut(oven);
  s.finishFrost(1);
  for (var k = 0; k < 3; k++) {
    s.addTopping(b.correctTopping);
  }
  s.pickBox(b.correctBox);
  g.step(_dt);
}

/// Làm mẻ xoay vòng menu tới khi mọi ô tủ có bánh (món lặp lại tràn sang ô mới khi ô cũ đầy).
void _fillCase(LevelGame g) {
  final dc = g.session.displayCase;
  for (var i = 0; dc.items.any((s) => s.isEmpty); i++) {
    if (i > 16) fail('không lấp đủ tủ');
    _bakeInto(g, _menu[i % _menu.length]);
  }
}

/// Lấp tủ [_wide] (5 ô: 4 trong tủ + 1 trên kệ) với số bánh khác nhau: 10, 2, 8, 4, 4.
void _fillWide(LevelGame g) {
  for (final r in const [
    RecipeId.cupcakeVanilla, RecipeId.cupcakeVanilla, RecipeId.cupcakeVanilla, //
    RecipeId.cupcakeChocolate, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart,
  ]) {
    _bakeInto(g, r);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShopLook', () {
    test('tiệm gốc: không kệ, không bàn, ảnh lò cấp 1', () {
      final g = _game(_level());
      expect(g.look, ShopLook.base);
      expect(g.ovenLevel, 1);
      expect(g.look.mainSlots(3), 3);
    });

    test('case_stand: ô cộng thêm lên kệ; tủ gốc 4 ô + kệ → 4 + 1; tủ > 4 ô chưa mua kệ → ô dư lên kệ', () {
      expect(ShopLook.resolve(caseSlots: 4, owned: {'case_stand'}, caseSlotsBonus: 1).standSlots, 1);
      expect(ShopLook.resolve(caseSlots: 5, owned: {'case_stand'}, caseSlotsBonus: 1).standSlots, 1);
      expect(ShopLook.resolve(caseSlots: 4).standSlots, 0);
      expect(ShopLook.resolve(caseSlots: 5).standSlots, 1);
      expect(ShopLook.resolve(caseSlots: 6, owned: {'case_stand'}, caseSlotsBonus: 1).standSlots, 2);
      expect(ShopLook.resolve(caseSlots: 9).standSlots, ShopLook.standMax);
      expect(ShopLook.resolve(caseSlots: 1, owned: {'case_stand'}, caseSlotsBonus: 1).standSlots, 0);
    });

    test('ảnh lò = ShopSetup.ovenArtLevel (lò nhanh / lò vùng vàng, kẹp 1..5); đồ trang trí chỉ nhận ô quầy / cây', () {
      for (final setup in const [
        ShopSetup(equipmentTiers: {'fastOven': 3}),
        ShopSetup(equipmentTiers: {'fastOven': 2, 'goldenOven': 4}),
        ShopSetup(equipmentTiers: {'fastOven': 9}),
      ]) {
        final g = _game(_level(), setup: setup);
        expect(g.ovenLevel, setup.ovenArtLevel);
        expect(g.ovenLevel, inInclusiveRange(1, 5));
      }
      expect(_game(_level(), setup: const ShopSetup(equipmentTiers: {'fastOven': 3})).ovenLevel, 3);
      final l = ShopLook.resolve(caseSlots: 3, decor: {
        DecorSlot.counter: DecorId.counterCakeStand,
        DecorSlot.plant: DecorId.plantFern,
        DecorSlot.window: DecorId.windowSeaView,
      });
      expect(l.counterDecor, DecorId.counterCakeStand);
      expect(l.plantDecor, DecorId.plantFern);
    });
  });

  group('vẽ + chạm theo setup', () {
    setUp(() => LevelArt.debugReset());

    test('setup gốc: vẽ không lỗi, chạm khách vẫn bán', () {
      final g = _game(_level(every: 1, menu: const [RecipeId.cupcakeVanilla]));
      final s = g.session;
      for (var t = 0.0; s.customers.every((c) => !(c.canBuy && c.phaseT >= 1)); t += _dt) {
        if (t > 20) fail('không có khách ở quầy');
        g.step(_dt);
        _paintOnce(g);
      }
      final c = s.customers.firstWhere((c) => c.canBuy && c.phaseT >= 1);
      _tap(g, g.customerHitPoint(c.id)!);
      expect(s.served, 1);
      _paintOnce(g);
    });

    test('case_stand + 4–5 ô: ô cuối trên kệ tầng, bánh / huy hiệu nằm trên kệ, bánh bay về đúng kệ', () {
      for (final base in [3, 4]) {
        final g = _game(_level(caseSlots: base, startStock: 0), setup: const ShopSetup(caseSlotsBonus: 1, owned: {'case_stand'}));
        final s = g.session;
        expect(s.displayCase.slots, base + 1);
        expect(g.look.standSlots, 1);
        expect(g.look.mainSlots(base + 1), base);
        _fillCase(g);
        _paintOnce(g);
        final last = s.displayCase.items.last;
        expect(last.count, greaterThan(0));
        final at = g.shop.cellCenterOf(last.recipe!);
        expect(LevelLayout.standRect.contains(at), isTrue, reason: 'ô cuối (base $base) phải ở trên kệ tầng');
        expect(LevelLayout.caseRect.contains(g.shop.slotCakeCenter(0)), isTrue);
        for (var i = 0; i < base; i++) {
          expect(LevelLayout.caseGlass.contains(g.shop.slotCakeCenter(i)), isTrue);
        }
        final badge = g.shop.slotBadgeAt(base, 3);
        expect(LevelLayout.standRect.inflate(14).contains(badge), isTrue);
        // Kệ không đè lên tủ kính và nằm trên quầy phải (dưới HUD, trong sân tiệm).
        expect(LevelLayout.standRect.left, greaterThanOrEqualTo(LevelLayout.caseRect.right));
        expect(LevelLayout.standRect.top, greaterThan(LevelLayout.hudBottom));
        expect(LevelLayout.standRect.bottom, lessThan(LevelLayout.kitchenTop));
        _run(g, 1);
        _paintOnce(g);
      }
    });

    test('kệ 2 ô: mỗi ô một tầng', () {
      final g = _game(_level(caseSlots: 4, startStock: 0), setup: const ShopSetup(caseSlotsBonus: 2, owned: {'case_stand'}));
      expect(g.look.standSlots, 2);
      final lower = g.shop.slotCakeCenter(4), upper = g.shop.slotCakeCenter(5);
      expect(upper.dy, lessThan(lower.dy));
      _paintOnce(g);
    });

    test('2 lò: hai ô lò không chồng nhau, nằm trong ô Lò; chạm lò 2 lấy đúng mẻ ở lò 2', () {
      final g = _game(_level(startStock: 0), setup: const ShopSetup(ovens: 2, owned: {'oven_2'}));
      final s = g.session;
      expect(s.kitchen.ovens.length, 2);
      final a = LevelLayout.ovenSlot(0, 2), b = LevelLayout.ovenSlot(1, 2);
      final tile = LevelLayout.tile(LevelLayout.ovenTile);
      expect(a.overlaps(b), isFalse);
      for (final r in [a, b]) {
        expect(tile.contains(r.topLeft) && tile.contains(r.bottomRight - const Offset(0.1, 0.1)), isTrue);
        expect(r.width, greaterThanOrEqualTo(64));
        expect(r.height, greaterThanOrEqualTo(64));
      }
      // Hai ô lò không lấn sang ô Trộn / ô Kem.
      expect(a.left, greaterThanOrEqualTo(LevelLayout.tile(LevelLayout.mixTile).right));
      expect(a.right, lessThanOrEqualTo(LevelLayout.tile(LevelLayout.frostTile).left));

      _toOven(g, RecipeId.cupcakeVanilla);
      g.step(_dt);
      _toOven(g, RecipeId.cupcakeChocolate);
      g.step(_dt);
      final first = s.kitchen.ovens[0]!, second = s.kitchen.ovens[1]!;
      expect(first.recipe, RecipeId.cupcakeVanilla);
      expect(second.recipe, RecipeId.cupcakeChocolate);
      _run(g, 1);
      _paintOnce(g);
      _tap(g, b.center);
      expect(second.stage, isNot(BatchStage.baking), reason: 'chạm lò 2 → lấy mẻ lò 2');
      expect(first.stage, BatchStage.baking, reason: 'mẻ lò 1 vẫn nướng');
      expect(s.kitchen.finish, same(second));
      g.step(_dt);
      _paintOnce(g);
    });

    test('bàn ghế: 2 bộ trên sàn hai bên (không che tủ / bong bóng quầy); khách chờ đứng quanh bàn phải', () {
      final g = _game(_level(every: 0.5, maxQueue: 9), setup: _full, decor: _decor);
      final s = g.session;
      expect(g.look.cafeTables, isTrue);
      for (var i = 0; i < 2; i++) {
        final r = ShopView.tableRect(i);
        expect(r.overlaps(LevelLayout.caseRect), isFalse);
        expect(r.overlaps(LevelLayout.standRect), isFalse);
        expect(r.top, greaterThan(LevelLayout.hudBottom));
      }
      expect(ShopView.tableRect(0).right, lessThan(LevelLayout.register.left));
      expect(ShopView.tableRect(1).left, greaterThan(LevelLayout.standRect.right));
      // Chỗ chờ thứ 1–4 nằm trong dải bàn phải (± nửa bề ngang khách).
      final right = ShopView.tableRect(1);
      for (var k = 1; k <= 4; k++) {
        final (x, _) = LevelLayout.queueSpot(k, stand: true, tables: true);
        expect(x, inInclusiveRange(right.left - 60, right.right + 60), reason: 'chỗ chờ $k cạnh bàn');
      }
      for (var t = 0.0; s.customers.length < 9; t += _dt) {
        if (t > 30) fail('không đủ khách');
        g.step(_dt);
      }
      _run(g, 2);
      _paintOnce(g);
    });

    test('hoa quầy không chồng cây; hai chỗ chờ đầu cách đủ xa ở mọi kiểu tiệm', () {
      expect(LevelLayout.counterDecorRect.overlaps(LevelLayout.plantRect), isFalse);
      expect(LevelLayout.counterDecorRect.right, lessThan(LevelLayout.register.left));
      for (final stand in [false, true]) {
        for (final tables in [false, true]) {
          final (x0, s0) = LevelLayout.queueSpot(0, stand: stand, tables: tables);
          final (x1, s1) = LevelLayout.queueSpot(1, stand: stand, tables: tables);
          expect(x1 - x0, greaterThanOrEqualTo(stand ? LevelLayout.standQueueGap : LevelLayout.queueGap), reason: 'kệ $stand, bàn $tables');
          expect(s1, lessThanOrEqualTo(s0));
          if (stand) expect(x0 - 40, greaterThan(LevelLayout.standRect.right - 12), reason: 'chỗ đầu không đứng sau kệ');
        }
      }
    });

    test('wideCase: ô 6 / 8 / 10 cái → 3 / 4 / 5 cái một tầng; hai hàng chặt vừa cột và khe kệ', () {
      expect([for (final c in [1, 6, 7, 8, 9, 10, 14]) caseShelfCapacityFor(c)], [3, 3, 4, 4, 5, 5, 5]);
      for (var slots = 1; slots <= 6; slots++) {
        for (var i = 0; i < slots; i++) {
          final cell = caseCell(i, slots);
          final s = caseCakeSize(cell);
          for (var k = 1; k <= caseShelfMax; k++) {
            expect(caseShelfStack[k].length, k);
            final w = s * caseShelfCakeScale(k);
            for (final o in caseShelfStack[k]) {
              expect(cell.center.dx + o.dx * s - w / 2, greaterThanOrEqualTo(cell.left - 0.5), reason: 'slots $slots k $k');
              expect(cell.center.dx + o.dx * s + w / 2, lessThanOrEqualTo(cell.right + 0.5), reason: 'slots $slots k $k');
              expect(LevelLayout.lowerShelfY - w + o.dy * s, greaterThanOrEqualTo(LevelLayout.upperShelfBottom - 1));
              expect(LevelLayout.upperShelfY - w + o.dy * 0.4 * s, greaterThanOrEqualTo(LevelLayout.caseGlass.top - 4));
            }
          }
          for (final n in [5, 8, 10]) {
            expect(LevelLayout.caseRect.contains(caseBadgeAt(cell, n, perShelf: 5)), isTrue);
          }
        }
      }
    });

    test('wideCase 10: vẽ đủ ô đầy (tủ + kệ tầng) không lỗi, huy hiệu đúng tầng', () {
      final g = _game(_level(caseSlots: 4, startStock: 0), setup: _wide);
      final dc = g.session.displayCase;
      expect(dc.slotCapacity, 10);
      _fillWide(g);
      _paintOnce(g);
      for (var i = 0; i < dc.slots; i++) {
        final n = dc.items[i].count;
        if (n == 0) continue;
        expect(g.shop.slotBadgeAt(i, n).dy, lessThan(LevelLayout.kitchenTop));
      }
      final full = [for (var i = 0; i < dc.slots; i++) if (dc.items[i].count == 10) i];
      expect(full, isNotEmpty);
      expect(g.shop.slotBadgeAt(full.first, 10).dy, lessThan(g.shop.slotBadgeAt(full.first, 5).dy));
    });

    test('thiếu ảnh kệ / bàn → vẽ hình code dự phòng, không lỗi', () async {
      LevelArt.debugReset(bundle: _MissingBundle());
      await LevelArt.preload();
      expect(LevelArt.isMissing(LevelArtId.caseStand), isTrue);
      expect(LevelArt.isMissing(LevelArtId.cafeTable), isTrue);
      final g = _game(_level(caseSlots: 4, every: 0.6), setup: _full, decor: _decor);
      _run(g, 6);
      _paintOnce(g);
      LevelArt.debugReset();
    });
  });

  test('perf: 25 khách + 2 lò + kệ + bàn ghế + trang trí — step+paint TB < 1 ms/khung', () async {
    final level = _level(caseSlots: 4, every: 0.35, startStock: 6, maxQueue: 26);
    final g = _game(level, setup: _full, decor: _decor, seed: 11);
    final s = g.session;
    await LevelGame.preloadFor(level, ovenLevel: 3, decor: _decor).timeout(const Duration(seconds: 20), onTimeout: () => const []);
    for (var i = 0; i < 60 * 30 && s.customers.length < 25; i++) {
      g.step(_dt);
    }
    expect(s.customers.length, greaterThanOrEqualTo(25));
    _toOven(g, RecipeId.cupcakeVanilla);
    g.step(_dt);
    _toOven(g, RecipeId.eggTart);
    g.step(_dt);
    expect(s.kitchen.ovens.where((b) => b != null).length, 2);

    void frame() {
      g.step(_dt);
      _paintOnce(g);
    }

    for (var i = 0; i < 60; i++) {
      frame();
    }
    const frames = 600;
    final sw = Stopwatch()..start();
    var maxUs = 0;
    for (var i = 0; i < frames; i++) {
      final t0 = sw.elapsedMicroseconds;
      frame();
      maxUs = math.max(maxUs, sw.elapsedMicroseconds - t0);
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('LevelPlay GĐ3 perf: ${s.customers.length} khách, ảnh nhân vật ${LevelCharacters.debugCachedCount}, '
        'step+paint TB ${avgMs.toStringAsFixed(3)} ms/khung (max ${(maxUs / 1000).toStringAsFixed(2)} ms)');
    expect(avgMs, lessThan(1));
  });

  final renderDir = Platform.environment['P3_RENDER_DIR'];
  group('ảnh kiểm tra', () {
    setUpAll(_loadFonts);

    Future<void> render(String name, LevelGame g, void Function() setupScene,
        {Map<DecorSlot, DecorId?> decor = _decor, AssetBundle? levelArt}) async {
      LevelArt.debugReset(bundle: levelArt);
      await LevelGame.preloadFor(g.session.level, ovenLevel: g.ovenLevel, decor: decor).timeout(const Duration(seconds: 30), onTimeout: () => const []);
      g.setLabels(g.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      setupScene();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1280, 720), ui.Paint()..color = const Color(0xFFFFF4E6));
      g.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1280, 720);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$renderDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }


    test('p3_shop_base / full / stand2 / queue3 / widecase / fallback', () async {
      final base = _game(_level(every: 1.2, startStock: 0, maxQueue: 8), seed: 5);
      await render('p3_shop_base', base, () {
        _fillCase(base);
        _toOven(base, RecipeId.eggTart);
        _run(base, 7);
      });

      final full = _game(_level(every: 1.0, startStock: 0, maxQueue: 9), setup: _full, decor: _decor, seed: 5);
      await render('p3_shop_full', full, () {
        _fillCase(full);
        _toOven(full, RecipeId.cupcakeVanilla);
        full.step(_dt);
        _toOven(full, RecipeId.eggTart);
        _run(full, 8);
      });

      const fern = {DecorSlot.counter: DecorId.counterCakeStand, DecorSlot.plant: DecorId.plantFern};
      final stand2 = _game(_level(caseSlots: 4, every: 1.4, startStock: 0, maxQueue: 6),
          setup: const ShopSetup(caseSlotsBonus: 2, owned: {'case_stand'}), decor: fern, seed: 7);
      await render('p3_shop_stand2', stand2, () {
        _fillCase(stand2);
        _run(stand2, 5);
      }, decor: fern);

      // Đủ đồ: hoa quầy + cây + bàn ghế + kệ tầng; 3 khách ở quầy + đúng 3 khách chờ (đã đứng yên).
      final queue3 = _game(_level(every: 0.8, startStock: 0, maxQueue: 4), setup: _full, decor: _decor, seed: 5);
      await render('p3_shop_queue3', queue3, () {
        _fillCase(queue3);
        final qs = queue3.session;
        bool settled() =>
            qs.customers.where((c) => c.phase == CustomerPhase.queued && c.phaseT >= 1).length == 3 &&
            qs.customers.where((c) => c.phase == CustomerPhase.atCounter && c.phaseT >= 1).length == 3;
        for (var t = 0.0; !settled(); t += _dt) {
          if (t > 40) fail('không đủ 3 khách chờ');
          queue3.step(_dt);
        }
        _run(queue3, 0.6);
      });

      // Tủ rộng (ô 10 cái) + kệ tầng: ô đầy 10 / 8 cái xếp hai hàng chặt.
      final wide = _game(_level(caseSlots: 4, startStock: 0), setup: _wide, decor: _decor, seed: 9);
      await render('p3_shop_widecase', wide, () {
        _fillWide(wide);
        _run(wide, 1);
      });

      // Thiếu ảnh kệ / bàn (và các ảnh `level/` khác) → hình code dự phòng.
      final fallback = _game(_level(every: 1.0, startStock: 0, maxQueue: 9), setup: _full, decor: _decor, seed: 5);
      await render('p3_shop_fallback', fallback, () {
        _fillCase(fallback);
        _run(fallback, 8);
      }, levelArt: _MissingBundle());
      LevelArt.debugReset();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, skip: renderDir == null ? 'đặt P3_RENDER_DIR để xuất ảnh kiểm tra' : null);
}

/// Bundle không có ảnh nào (thiếu file → LevelArt vẽ dự phòng).
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
