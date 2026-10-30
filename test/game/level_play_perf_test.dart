import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';

/// Đo khối lượng mỗi khung của màn chơi level với 25 khách trong cảnh: `step` (advance + hoạt cảnh) và `paint`
/// (ghi lệnh vẽ vào PictureRecorder). Assert lỏng — chủ yếu in số để so giữa các lần sửa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('25 khách: update + render nhiều khung', () async {
    const menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];
    const level = LevelData(
      id: 8,
      chapter: 1,
      title: {'en': 'Perf', 'vi': 'Đo'},
      durationSec: 600,
      goal: LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: 4,
      startStock: 6,
      patienceSec: 900,
      spawn: SpawnCurve(startEverySec: 0.35, endEverySec: 0.35, rushAtPct: 100, rushEverySec: 0.35),
      flexibleChance: 0.5,
      specials: [SpecialVisit(atSec: 1, who: SpecialWho.linh, recipe: RecipeId.cupcakeVanilla)],
      newRecipe: RecipeId.eggTart,
      overrides: {'maxQueue': 26},
    );
    final session = LevelSession(
      level: level,
      defaults: const LevelDefaults(jitterPct: 0),
      modifiers: BakeModifiers.base,
      random: math.Random(11),
    );
    final game = LevelGame(session: session);

    // Ảnh thật (giải mã sẵn) để phần vẽ đúng như trong app; quá hạn thì đo với phần ảnh đã có.
    await LevelGame.preloadFor(level).timeout(const Duration(seconds: 20), onTimeout: () => const []);

    const dt = 1 / 60;
    for (var i = 0; i < 60 * 30 && session.customers.length < 25; i++) {
      game.step(dt);
    }
    expect(session.customers.length, greaterThanOrEqualTo(25));
    // Bếp đang bận: một mẻ đang nướng, một mẻ ở trạm khuôn.
    session.startBatch(RecipeId.cupcakeVanilla);
    session.pickMould(session.kitchen.prep!.correctMould);
    session.finishMix(1);
    session.startBatch(RecipeId.eggTart);

    void frame() {
      game.step(dt);
      final recorder = PictureRecorder();
      game.paint(Canvas(recorder));
      recorder.endRecording().dispose();
    }

    for (var i = 0; i < 60; i++) {
      frame(); // làm nóng (dựng hình tĩnh vào cache)
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

    final sw2 = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      session.advance(dt);
      session.drainEvents();
    }
    final advanceMs = sw2.elapsedMicroseconds / frames / 1000;

    // ignore: avoid_print
    print('LevelPlay perf: ${session.customers.length} khách, ảnh nhân vật ${LevelCharacters.debugCachedCount}, '
        'step+paint TB ${avgMs.toStringAsFixed(3)} ms/khung (max ${(maxUs / 1000).toStringAsFixed(2)} ms), '
        'advance TB ${advanceMs.toStringAsFixed(4)} ms/khung');
    expect(avgMs, lessThan(8), reason: 'step + ghi lệnh vẽ phải nhẹ hơn nửa khung 60fps');
    expect(advanceMs, lessThan(0.5));
  });
}
