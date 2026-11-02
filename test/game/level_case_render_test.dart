import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/game/level/level_art.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';

// Ảnh kiểm tra tủ kính / kệ tầng đầy bánh + khách đang gọi món, ở khung 1280 và 1600 (máy 20:9):
// `CASE_RENDER_DIR=<thư mục> CASE_RENDER_TAG=<nhãn> flutter test test/game/level_case_render_test.dart`
// → `level_case_<nhãn>_{1280,1600}.png`, `level_case_<nhãn>_stand_{1280,1600}.png`.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.muffinBlueberry, RecipeId.eggTart, RecipeId.macaron];

LevelData _level({int caseSlots = 3}) => LevelData(
      id: 8,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 600,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: _menu,
      caseSlots: caseSlots,
      startStock: 0,
      patienceSec: 900,
      spawn: const SpawnCurve(startEverySec: 0.8, endEverySec: 0.8, rushAtPct: 100, rushEverySec: 0.8),
      newRecipe: _menu.last,
      overrides: const {'maxQueue': 4},
    );

const _full = ShopSetup(caseSlotsBonus: 1, owned: {'case_stand', 'cafe_tables'});
const _decor = {DecorSlot.counter: DecorId.counterFlowers, DecorSlot.plant: DecorId.plantLemonTree};

const _dt = 1 / 60;

LevelGame _game({ShopSetup setup = ShopSetup.base, int caseSlots = 3, Map<DecorSlot, DecorId?> decor = const {}}) => LevelGame(
      session: LevelSession(
        level: _level(caseSlots: caseSlots),
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        setup: setup,
        random: math.Random(5),
      ),
      decor: decor,
    );

/// Làm trọn một mẻ [r] bằng hàm session.
void _bakeInto(LevelGame g, RecipeId r) {
  final s = g.session;
  if (!s.startBatch(r)) return;
  s.pickMould(s.kitchen.prep!.correctMould);
  s.finishMix(1);
  final oven = s.kitchen.ovens.indexWhere((b) => b != null && b.recipe == r && b.stage == BatchStage.baking);
  final b = s.kitchen.ovens[oven]!;
  for (var t = 0.0; b.ovenProgress < b.bakeTarget && t < 30; t += _dt) {
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

/// Lấp đầy mọi ô tủ (mỗi ô một món).
void _fillCase(LevelGame g) {
  final dc = g.session.displayCase;
  for (var i = 0; i < 40 && dc.items.any((s) => s.count < dc.slotCapacity); i++) {
    final empty = dc.items.indexWhere((s) => s.count < dc.slotCapacity);
    final r = dc.items[empty].recipe ?? _menu.firstWhere((m) => dc.countOf(m) == 0, orElse: () => _menu.first);
    _bakeInto(g, r);
  }
}

/// Chờ tới khi 3 khách đứng yên ở quầy (bong bóng hiện).
void _settle(LevelGame g) {
  final s = g.session;
  for (var t = 0.0; s.customers.where((c) => c.phase == CustomerPhase.atCounter && c.phaseT >= 1).length < 3 && t < 40; t += _dt) {
    g.step(_dt);
  }
  for (var t = 0.0; t < 1.5; t += _dt) {
    g.step(_dt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['CASE_RENDER_DIR'];
  final tag = Platform.environment['CASE_RENDER_TAG'] ?? 'after';

  Future<void> render(String name, LevelGame g, double width) async {
    g.inset = (width - 1280) / 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, 720), ui.Paint()..color = const Color(0xFFFFF4E6));
    g.paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), 720);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }

  test('ảnh tủ đầy + khách gọi món, 1280 / 1600', () async {
    await _loadFonts();
    LevelArt.debugReset();
    for (final (suffix, setup, slots, decor) in [
      ('', ShopSetup.base, 3, const <DecorSlot, DecorId?>{}),
      ('_stand', _full, 4, _decor),
    ]) {
      final g = _game(setup: setup, caseSlots: slots, decor: decor);
      await LevelGame.preloadFor(g.session.level, decor: decor).timeout(const Duration(seconds: 30), onTimeout: () => const []);
      g.setLabels(g.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      _fillCase(g);
      _settle(g);
      for (final w in const [1280.0, 1600.0]) {
        await render('level_case_$tag${suffix}_${w.round()}', g, w);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)), skip: dir == null ? 'đặt CASE_RENDER_DIR để xuất ảnh' : null);
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
