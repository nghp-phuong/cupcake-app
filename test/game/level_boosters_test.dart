import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/staff/staff.dart';
import 'package:sugarleaf_bakery/game/level/booster_fx.dart';
import 'package:sugarleaf_bakery/game/level/level_art.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/staff_view.dart';

// GĐ6: hiệu ứng vật phẩm hỗ trợ trong màn (tủ đầy lấp lánh, lò ×2 tia lửa, viền vàng vòng kiên nhẫn, hàng biểu
// tượng) + trang phục lễ hội của nhân viên, perf.
//
// Ảnh kiểm tra (PNG 1280×720): `P6_RENDER_DIR=<thư mục> flutter test test/game/level_boosters_test.dart`.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];

LevelData _level({double every = 100, int startStock = 3, int caseSlots = 4, int maxQueue = 5}) => LevelData(
      id: 12,
      chapter: 2,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 600,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: _menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: 900,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      newRecipe: _menu.last,
      overrides: {'maxQueue': maxQueue},
    );

StaffMember _member(String id, StaffRole role, String character) =>
    StaffMember(id: id, role: role, character: character, speedValue: 3, skillValue: 1);

final _cashier = _member(StaffIds.cashier, StaffRole.cashier, 'staff_nora');
final _baker = _member(StaffIds.baker, StaffRole.baker, 'staff_bao');

const _all = LevelBoosts(fullCase: true, patience: true, ovenBoost: true);

LevelGame _game(LevelData level,
        {ShopSetup setup = ShopSetup.base,
        List<StaffMember> staff = const [],
        int seed = 3,
        bool festive = false,
        Set<BoosterId> boosters = const {}}) =>
    LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        setup: setup.withStaff(staff),
        random: math.Random(seed),
        boosters: boosters,
      ),
      festiveOutfits: festive,
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

/// Cho một mẻ vào lò 0 (đang nướng).
void _bake(LevelGame g, RecipeId r) {
  final s = g.session;
  s.startBatch(r);
  s.pickMould(s.kitchen.prep!.correctMould);
  s.finishMix(1);
}

/// Làm trọn một mẻ [r] ở bếp nhanh, ba lần chạm cùng một hũ: hũ topping đúng ([wrong] false) hoặc hũ nhiễu → bánh vào
/// tủ. Trả topping đã đặt.
ToppingId _batchWith(LevelGame g, RecipeId r, {required bool wrong}) {
  final s = g.session;
  _bake(g, r);
  final b = s.kitchen.ovens.firstWhere((o) => o != null && o.recipe == r)!;
  for (var t = 0.0; b.ovenProgress < b.bakeTarget; t += _dt) {
    if (t > 60) fail('lò không chín');
    g.step(_dt);
  }
  s.takeOut(s.kitchen.ovens.indexOf(b));
  s.finishFrost(1);
  final topping = wrong ? b.toppingChoices.firstWhere((t) => t != b.correctTopping) : b.correctTopping;
  for (var i = 0; i < 3; i++) {
    s.addTopping(topping);
  }
  expect(s.pickBox(b.correctBox), isTrue);
  return topping;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cờ vật phẩm', () {
    test('LevelBoosts.of theo BoosterId; mặc định không vật phẩm', () {
      expect(LevelBoosts.of(const {}), LevelBoosts.none);
      expect(LevelBoosts.of(BoosterId.values.toSet()), _all);
      expect(LevelBoosts.of(const {BoosterId.patience}), const LevelBoosts(patience: true));
      expect(LevelBoosts.of(const {BoosterId.ovenBoost}).count, 1);
      expect(LevelBoosts.none.any, isFalse);
      final g = _game(_level());
      expect(g.boosts, LevelBoosts.none);
      g.debugBoosts = _all;
      expect(g.boosts.count, 3);
      // Đọc từ `LevelSession.boosters`; đổi session → đọc lại.
      final s = _game(_level(), boosters: const {BoosterId.ovenBoost, BoosterId.fullCase});
      expect(s.boosts, const LevelBoosts(fullCase: true, ovenBoost: true));
      s.attachSession(_game(_level()).session);
      expect(s.boosts, LevelBoosts.none);
    });
  });

  group('hiệu ứng', () {
    setUp(() => LevelArt.debugReset());

    test('tủ đầy: lấp lánh ~1.5 s đầu rồi tắt; không vật phẩm → không lấp lánh', () {
      final g = _game(_level(startStock: 0), boosters: const {BoosterId.fullCase});
      expect(g.session.displayCase.items.where((i) => !i.isEmpty).length, greaterThan(0), reason: 'tủ đầy từ đầu (core)');
      g.step(_dt);
      _run(g, 0.2);
      expect(g.boosterFx.caseSparkle, greaterThan(0.5));
      _paintOnce(g);
      _run(g, BoosterFx.caseSparkleSec);
      expect(g.session.elapsed, greaterThanOrEqualTo(BoosterFx.caseSparkleSec));
      expect(g.boosterFx.caseSparkle, 0);
      _paintOnce(g);

      final plain = _game(_level(startStock: 6));
      _run(plain, 0.3);
      expect(plain.boosterFx.caseSparkle, 0);
    });

    test('lò ×2 + kiên nhẫn: vẽ cảnh có lò đang nướng và khách ở quầy không lỗi (ảnh có / thiếu)', () async {
      for (final missing in [false, true]) {
        LevelArt.debugReset(bundle: missing ? _MissingBundle() : null);
        await LevelArt.preload();
        final g = _game(_level(every: 1, startStock: 6))..debugBoosts = _all;
        _run(g, 4);
        _bake(g, RecipeId.cupcakeVanilla);
        _run(g, 0.3);
        expect(g.session.kitchen.ovens[0]?.stage, BatchStage.baking);
        expect(g.session.customers.any((c) => c.phase == CustomerPhase.atCounter), isTrue);
        _paintOnce(g);
      }
      LevelArt.debugReset();
    });

    test('hàng biểu tượng: góc dưới trái sân tiệm, trên dải bếp, không chồng tủ / khách đặc biệt / chỗ quầy', () {
      final r = BoosterFx.iconsRect(3);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(LevelLayout.kitchenTop));
      // Dưới mặt quầy trái: khách / thợ bánh bị cắt từ đây xuống nên biểu tượng không che ai.
      expect(r.top, greaterThan(LevelLayout.leftCounterTop));
      expect(r.overlaps(LevelLayout.caseRect), isFalse);
      expect(r.overlaps(LevelLayout.register), isFalse);
      // Không chồng thân khách đặc biệt (x 300 ± nửa khung ảnh) ở mép trái quầy.
      const specialHalfW = LevelLayout.customerHeight * LevelLayout.counterScale * 0.75 / 2;
      expect(r.right, lessThan(LevelLayout.specialX - specialHalfW * 0.5));
      expect(BoosterFx.iconsRect(0), Rect.zero);
      expect(BoosterFx.iconsRect(1).width, BoosterFx.iconRadius * 2);
    });
  });

  group('topping thật trong tủ', () {
    setUp(() => LevelArt.debugReset());

    test('mẻ đặt topping khác → ô tủ ghi topping đó; vẽ bánh ghép (cache theo món + topping), bánh bay cũng vậy', () {
      final g = _game(_level(startStock: 0));
      const r = RecipeId.cupcakeVanilla;
      final wrong = _batchWith(g, r, wrong: true);
      expect(wrong, isNot(Catalog.recipe(r).toppings.first));
      g.step(_dt); // sự kiện batchReady → bánh bay
      final slot = g.session.displayCase.items.firstWhere((i) => i.recipe == r);
      expect(slot.count, greaterThan(0));
      expect(slot.isDefaultToppingAt(0), isFalse);
      expect(g.shop.newestToppingOf(r), wrong);
      for (var i = 0; i < 5; i++) {
        g.step(_dt);
        _paintOnce(g);
      }
      expect(g.toppedCakes.cachedCount, 1, reason: 'một hình ghép cho (món, topping), dựng một lần');

      // Topping chuẩn → không dựng hình ghép.
      final ok = _game(_level(startStock: 0));
      _batchWith(ok, r, wrong: false);
      for (var i = 0; i < 5; i++) {
        ok.step(_dt);
        _paintOnce(ok);
      }
      expect(ok.shop.newestToppingOf(r), isNull);
      expect(ok.toppedCakes.cachedCount, 0);
    });
  });

  group('trang phục lễ hội', () {
    tearDown(() {
      LevelCharacters.debugReset();
      LevelArt.debugReset();
    });

    test('id ảnh lễ hội + danh sách nạp (bỏ quản lý)', () {
      expect(StaffView.festCharacter('staff_nora'), 'staff_nora_fest');
      final manager = _member(StaffIds.manager, StaffRole.manager, 'staff_hanh');
      final sprites = StaffView.festSpritesFor([_cashier, _baker, manager]);
      expect(sprites, contains(('staff_nora_fest', LevelCharacters.neutral)));
      expect(sprites, contains(('staff_bao_fest', LevelCharacters.smile)));
      expect(sprites.any((s) => s.$1.startsWith('staff_hanh')), isFalse);
    });

    test('bật: dùng ảnh lễ hội; tắt hoặc thiếu ảnh lễ hội → ảnh thường', () async {
      // Bundle thay ảnh lễ hội bằng ảnh của nhân vật khác (staff_ami) để phân biệt được.
      LevelCharacters.debugReset(bundle: _FestBundle(), pixelScale: 1);
      final g = _game(_level(), staff: [_cashier, _baker], festive: true);
      await LevelGame.preloadFor(g.session.level, staff: g.session.setup.staff, festiveOutfits: true)
          .timeout(const Duration(seconds: 30), onTimeout: () => const []);
      g.step(_dt);
      final fest = LevelCharacters.cached('staff_nora_fest', LevelCharacters.neutral);
      final plain = LevelCharacters.cached('staff_nora', LevelCharacters.neutral);
      expect(fest, isNotNull);
      expect(plain, isNotNull);
      expect(g.shop.staff.figures.first.image, same(fest));
      _paintOnce(g);

      g.festiveOutfits = false;
      g.step(_dt);
      expect(g.shop.staff.figures.first.image, same(plain));

      // Bundle thật: chưa có ảnh lễ hội thì vẫn vẽ ảnh thường.
      LevelCharacters.debugReset(pixelScale: 1);
      final real = _game(_level(), staff: [_cashier], festive: true);
      await LevelGame.preloadFor(real.session.level, staff: real.session.setup.staff, festiveOutfits: true)
          .timeout(const Duration(seconds: 30), onTimeout: () => const []);
      real.step(_dt);
      final hasFest = File('assets/characters/staff_nora_fest_neutral.webp').existsSync();
      expect(real.shop.staff.figures.first.image,
          same(LevelCharacters.cached(hasFest ? 'staff_nora_fest' : 'staff_nora', LevelCharacters.neutral)));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  test('perf: đủ vật phẩm + nhân viên lễ hội, 15 khách — step+paint nhẹ như cũ', () async {
    final g = _game(_level(every: 0.35, startStock: 6, maxQueue: 16),
        setup: const ShopSetup(ovens: 2, owned: {'oven_2'}), staff: [_cashier, _baker], seed: 11, festive: true)
      ..debugBoosts = _all;
    await LevelGame.preloadFor(g.session.level, staff: g.session.setup.staff, festiveOutfits: true)
        .timeout(const Duration(seconds: 20), onTimeout: () => const []);
    final s = g.session;
    for (var i = 0; i < 60 * 30 && s.customers.length < 15; i++) {
      g.step(_dt);
    }
    _bake(g, RecipeId.cupcakeVanilla);
    void frame() {
      g.step(_dt);
      _paintOnce(g);
    }

    for (var i = 0; i < 60; i++) {
      frame();
    }
    const frames = 600;
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      frame();
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('LevelPlay GĐ6 perf: ${s.customers.length} khách + ${g.shop.staff.count} nhân viên, vật phẩm ${g.boosts.count}, '
        'step+paint TB ${avgMs.toStringAsFixed(3)} ms/khung');
    expect(avgMs, lessThan(8));
  }, timeout: const Timeout(Duration(minutes: 2)));

  final renderDir = Platform.environment['P6_RENDER_DIR'];
  group('ảnh kiểm tra', () {
    setUpAll(_loadFonts);

    Future<void> render(String name, LevelGame g, void Function() setupScene) async {
      await LevelGame.preloadFor(g.session.level,
              ovenLevel: g.ovenLevel, staff: g.session.setup.staff, festiveOutfits: g.festiveOutfits)
          .timeout(const Duration(seconds: 30), onTimeout: () => const []);
      g.setLabels(g.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      setupScene();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1280, 720), ui.Paint()..color = const Color(0xFFFFF4E6));
      g.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1280, 720);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(renderDir!).createSync(recursive: true);
      File('$renderDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    test('p6_boosters / p6_outfits', () async {
      LevelArt.debugReset();
      LevelCharacters.debugReset();
      // Tủ đầy ở khung đầu (lấp lánh đang hiện) + lò ×2 đang nướng + khách quầy viền vàng + 3 biểu tượng.
      final boost = _game(_level(every: 0.8, startStock: 0), seed: 5, boosters: BoosterId.values.toSet());
      await render('p6_boosters', boost, () {
        _bake(boost, RecipeId.cupcakeChocolate);
        _run(boost, 0.8); // còn trong 1.5 s lấp lánh
      });
      // Sau lấp lánh: khách vãng lai ở quầy có viền vàng vòng kiên nhẫn, lò vẫn có tia lửa.
      final boostLater = _game(_level(every: 0.8, startStock: 0), seed: 5, boosters: BoosterId.values.toSet());
      await render('p6_boosters_counter', boostLater, () {
        _run(boostLater, 4);
        _bake(boostLater, RecipeId.cupcakeChocolate);
        _run(boostLater, 0.6);
      });

      final outfits = _game(_level(every: 1.2, startStock: 6), staff: [_cashier, _baker], seed: 7, festive: true);
      await render('p6_outfits', outfits, () {
        outfits.debugStaffPoses = [StaffPose(_cashier), StaffPose(_baker, working: RecipeId.muffinBlueberry, progress: 0.6)];
        _run(outfits, 4);
      });
      // Ô tủ đầu: 3 cupcake vani mang topping khác topping chuẩn (bánh ghép), ô sau: món thường.
      final topped = _game(_level(startStock: 0), seed: 5);
      await render('p6_case_topping', topped, () {
        final t = _batchWith(topped, RecipeId.cupcakeVanilla, wrong: true);
        // ignore: avoid_print
        print('p6_case_topping: cupcake vani mang ${t.name} (chuẩn: ${Catalog.recipe(RecipeId.cupcakeVanilla).toppings.first.name})');
        _batchWith(topped, RecipeId.cupcakeChocolate, wrong: false);
        _run(topped, 1.0);
      });
      // Chưa có ảnh lễ hội thật: thêm một ảnh với ảnh giả lập (staff_ami) để thấy đường đổi ảnh hoạt động.
      if (!File('assets/characters/staff_nora_fest_neutral.webp').existsSync()) {
        LevelCharacters.debugReset(bundle: _FestBundle());
        final standIn = _game(_level(every: 1.2, startStock: 6), staff: [_cashier, _baker], seed: 7, festive: true);
        await render('p6_outfits_standin', standIn, () {
          standIn.debugStaffPoses = [StaffPose(_cashier), StaffPose(_baker, working: RecipeId.muffinBlueberry, progress: 0.6)];
          _run(standIn, 4);
        });
      }
      LevelCharacters.debugReset();
      LevelArt.debugReset();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, skip: renderDir == null ? 'đặt P6_RENDER_DIR để xuất ảnh kiểm tra' : null);
}

/// Bundle không có ảnh nào (thiếu file → biểu tượng vẽ code).
class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(StateError('thiếu $key'));
}

/// Bundle thật + ảnh lễ hội giả lập của Nora / Bảo (ảnh của `staff_ami`) khi chưa có file thật; manifest có thêm các
/// khoá đó để `LevelCharacters` coi là có.
class _FestBundle extends CachingAssetBundle {
  static const _fest = {
    'assets/characters/staff_nora_fest_neutral.webp': 'assets/characters/staff_ami_neutral.webp',
    'assets/characters/staff_nora_fest_smile.webp': 'assets/characters/staff_ami_smile.webp',
    'assets/characters/staff_bao_fest_neutral.webp': 'assets/characters/staff_ami_neutral.webp',
    'assets/characters/staff_bao_fest_smile.webp': 'assets/characters/staff_ami_smile.webp',
  };

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final raw = await rootBundle.load(key);
      final map = Map<Object?, Object?>.of(const StandardMessageCodec().decodeMessage(raw)! as Map<Object?, Object?>);
      for (final e in _fest.entries) {
        map[e.key] ??= map[e.value];
      }
      return const StandardMessageCodec().encodeMessage(map)!;
    }
    final stand = _fest[key];
    if (stand != null) return rootBundle.load(stand);
    return rootBundle.load(key);
  }
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
