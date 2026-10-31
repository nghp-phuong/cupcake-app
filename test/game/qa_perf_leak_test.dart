import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/staff/staff.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/game/level/staff_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

// QA hiệu năng + rò rỉ của màn chơi level:
// 1. 25+ khách + 10 nhân viên + bếp do bot chơi: thời gian step+paint mỗi khung (TB / p95 / p99 / max).
// 2. 10 màn thật (levels.json 1–10) liên tiếp, headless: thời gian khung không tăng dần, bộ đệm tĩnh có trần.
// 3. 10 màn liên tiếp gắn/gỡ LevelPlayView: ticker, listener ArtSprites, pool khách, lớp chữ bay không tăng dần.
// Số đo in ra (`QA perf`) — chép vào docs/qa/raw/game.md.

const _dt = 1 / 60;

void _paintOnce(LevelGame g) {
  final recorder = PictureRecorder();
  g.paint(Canvas(recorder));
  recorder.endRecording().dispose();
}

double _pct(List<int> us, double p) {
  final sorted = [...us]..sort();
  return sorted[math.min(sorted.length - 1, (sorted.length * p).floor())] / 1000;
}

String _ms(double v) => v.toStringAsFixed(3);

LevelConfig _config() => LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

StaffMember _member(int i) {
  const roles = [StaffRole.cashier, StaffRole.baker, StaffRole.baker, StaffRole.waiter, StaffRole.cashier];
  const chars = ['staff_nora', 'staff_bao', 'staff_ami', 'staff_theo', 'staff_hanh'];
  return StaffMember(id: 'qa_$i', role: roles[i % 5], character: chars[i % 5], speedValue: 3, skillValue: 1, lane: i ~/ 5);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('perf: 25+ khách + 10 nhân viên + bếp bot chơi — TB / p95 / p99 mỗi khung', () async {
    const menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];
    const level = LevelData(
      id: 20,
      chapter: 2,
      title: {'en': 'QA perf', 'vi': 'QA perf'},
      durationSec: 900,
      goal: LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: 4,
      startStock: 6,
      patienceSec: 900,
      spawn: SpawnCurve(startEverySec: 0.3, endEverySec: 0.3, rushAtPct: 100, rushEverySec: 0.3),
      specials: [SpecialVisit(atSec: 1, who: SpecialWho.linh, recipe: RecipeId.cupcakeVanilla)],
      newRecipe: RecipeId.eggTart,
      overrides: {'maxQueue': 30},
    );
    const setup = ShopSetup(caseSlotsBonus: 1, ovens: 2, maxQueueBonus: 2, owned: {'case_stand', 'oven_2', 'cafe_tables'});
    final s = LevelSession(
      level: level,
      defaults: const LevelDefaults(jitterPct: 0),
      modifiers: BakeModifiers.base,
      setup: setup,
      random: math.Random(17),
    );
    final g = LevelGame(session: s);
    final poses = [for (var i = 0; i < 10; i++) StaffPose(_member(i), working: menu[i % 4], progress: i / 10)];
    g.debugStaffPoses = poses;
    await LevelGame.preloadFor(level, ovenLevel: 3, staff: [for (final p in poses) p.member])
        .timeout(const Duration(seconds: 20), onTimeout: () => const []);
    for (var i = 0; i < 60 * 30 && s.customers.length < 25; i++) {
      g.step(_dt);
    }
    expect(s.customers.length, greaterThanOrEqualTo(25));
    expect(g.shop.staff.count, 10);

    // Bot chỉ làm bếp (sellBias 0) để hàng khách vẫn đông; thỉnh thoảng bán cho khách đầu.
    final bot = LevelBot(const BotSkill(accuracy: 0.9, reactionSec: 0.3, sellBias: 0), random: math.Random(2));
    var frameNo = 0;
    var minCustomers = 999;
    final eventsAt = <int, List<String>>{};
    g.onEvent = (e) => (eventsAt[frameNo] ??= []).add(e.type.name);
    void frame() {
      frameNo++;
      for (final p in poses) {
        p.progress = (p.progress + _dt / 6) % 1;
      }
      if (frameNo % 20 == 0) {
        final i = frameNo ~/ 20 % poses.length;
        if (poses[i].member.role == StaffRole.baker) {
          g.showStaffBatch(i, menu[i % 4], 4);
        } else if (s.customers.isNotEmpty) {
          g.showStaffSold(i, s.customers.first.id, 30);
        }
      }
      bot.step(s);
      g.step(_dt);
      _paintOnce(g);
      minCustomers = math.min(minCustomers, s.customers.length);
    }

    for (var i = 0; i < 120; i++) {
      frame();
    }
    const frames = 1200;
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      final t0 = sw.elapsedMicroseconds;
      frame();
      times.add(sw.elapsedMicroseconds - t0);
    }
    final avg = times.reduce((a, b) => a + b) / frames / 1000;
    final p95 = _pct(times, 0.95), p99 = _pct(times, 0.99), max = _pct(times, 1);
    // ignore: avoid_print
    print('QA perf [25+ khách, 10 nhân viên, bot bếp]: khách ≥ $minCustomers (cuối ${s.customers.length}), '
        'đã bán ${s.served}, step+paint TB ${_ms(avg)} ms · p95 ${_ms(p95)} · p99 ${_ms(p99)} · max ${_ms(max)} ms; '
        'khung > 16.7 ms: ${times.where((t) => t > 16700).length}/$frames (sự kiện ở khung chậm: ${[for (var i = 0; i < frames; i++) if (times[i] > 16700) eventsAt[i + 121] ?? const []]})');
    expect(minCustomers, greaterThanOrEqualTo(20));
    expect(avg, lessThan(8), reason: 'TB phải dưới nửa khung 60 fps');
    expect(p95, lessThan(16), reason: 'p95 phải dưới một khung 60 fps');
  });

  test('10 màn thật liên tiếp (headless, bot chơi): thời gian khung không tăng dần, bộ đệm tĩnh có trần', () async {
    final config = _config();
    final levels = config.levels.take(10).toList();
    expect(levels, hasLength(10));
    final avgs = <double>[];
    final charCache = <int>[];
    final artCache = <int>[];
    for (final level in levels) {
      final s = LevelSession(level: level, defaults: config.defaults, modifiers: BakeModifiers.base, random: math.Random(level.id));
      final g = LevelGame(session: s);
      await LevelGame.preloadFor(level).timeout(const Duration(seconds: 20), onTimeout: () => const []);
      final bot = LevelBot(BotSkill.of(0.8), random: math.Random(level.id));
      final times = <int>[];
      final sw = Stopwatch()..start();
      var frames = 0;
      while (!s.isOver && frames < 60 * 40) {
        final t0 = sw.elapsedMicroseconds;
        bot.step(s);
        g.step(_dt);
        _paintOnce(g);
        times.add(sw.elapsedMicroseconds - t0);
        frames++;
      }
      avgs.add(times.reduce((a, b) => a + b) / times.length / 1000);
      charCache.add(LevelCharacters.debugCachedCount);
      artCache.add(ArtSprites.debugCachedCount);
      g.onRemove();
      s.dispose();
    }
    // ignore: avoid_print
    print('QA perf [10 màn liên tiếp]: TB step+paint (ms) ${avgs.map(_ms).join(' · ')}; ảnh nhân vật giữ '
        '${charCache.join('/')}; ảnh ArtSprites ${artCache.join('/')}');
    // Bỏ màn 1 (làm nóng): màn sau không chậm hơn gấp đôi trung bình 3 màn đầu (+0.5 ms).
    final base = (avgs[1] + avgs[2] + avgs[3]) / 3;
    for (var i = 4; i < avgs.length; i++) {
      expect(avgs[i], lessThan(base * 2 + 0.5), reason: 'màn ${i + 1} chậm dần: ${avgs.map(_ms).join(' · ')}');
    }
    expect(charCache.last, lessThanOrEqualTo(charCache.reduce(math.max)));
    expect(charCache.reduce(math.max), lessThan(200), reason: 'bộ nhớ ảnh nhân vật không có trần');
  });

  testWidgets('10 màn liên tiếp gắn / gỡ LevelPlayView: ticker, listener ảnh, pool khách, chữ bay không tăng dần',
      (tester) async {
    final config = _config();
    final levels = config.levels.take(10).toList();
    final baseTickers = tester.binding.transientCallbackCount;
    final games = <LevelGame>[];
    final liveTickers = <int>[];
    final views = <String>[];
    for (final level in levels) {
      final s = LevelSession(level: level, defaults: config.defaults, modifiers: BakeModifiers.base, random: math.Random(level.id));
      final bot = LevelBot(BotSkill.of(0.8), random: math.Random(level.id));
      await tester.pumpWidget(MaterialApp(
        key: ValueKey('lv${level.id}'),
        theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LevelPlayView(session: s, onSpecialTap: (_) {})),
      ));
      final g = tester.widget<GameWidget<LevelGame>>(find.byType(GameWidget<LevelGame>)).game!;
      games.add(g);
      for (var i = 0; i < 60 * 20 && !s.isOver; i++) {
        bot.step(s);
        await tester.pump(const Duration(milliseconds: 16));
      }
      liveTickers.add(tester.binding.transientCallbackCount);
      // Khách đã rời cảnh phải trả hình về pool: số hình ≤ khách đang có (+ khách đặc biệt).
      expect(g.shop.viewCount, lessThanOrEqualTo(s.customers.length + 1), reason: 'màn ${level.id}');
      expect(g.floats.liveCount, lessThanOrEqualTo(64));
      views.add('${g.shop.viewCount}/${s.customers.length}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      s.dispose();
    }
    // ignore: avoid_print
    print('QA leak [10 màn gắn/gỡ]: ticker khi đang chơi ${liveTickers.join('/')}, sau khi gỡ '
        '${tester.binding.transientCallbackCount} (gốc $baseTickers); hình khách/khách ${views.join(' ')}');
    expect(tester.binding.transientCallbackCount, baseTickers, reason: 'ticker của game không được huỷ khi gỡ màn');
    expect(liveTickers.toSet(), hasLength(1), reason: 'số ticker tăng dần theo số màn đã chơi: $liveTickers');

    // Listener ArtSprites.changes của game đã gỡ phải được bỏ: báo ảnh mới → artGeneration của game cũ không đổi.
    final gens = [for (final g in games) g.artGeneration];
    ArtSprites.debugReset();
    await tester.runAsync(() => ArtSprites.preload([ArtSprites.coin, ArtSprites.starOn]).timeout(const Duration(seconds: 20)));
    expect(ArtSprites.coin.image ?? ArtSprites.starOn.image, isNotNull, reason: 'ảnh không nạp được: không kiểm được listener');
    expect([for (final g in games) g.artGeneration], gens, reason: 'game đã gỡ vẫn nghe ArtSprites.changes (rò listener)');
  });
}
