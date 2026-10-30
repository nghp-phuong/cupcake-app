import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';

DateTime _clock() => DateTime(2026, 10, 29, 10);

String _asset() => File(LevelConfigLoader.assetPath).readAsStringSync();

final _config = LevelConfigLoader.parse(_asset(), strict: true);

LevelSession _session(LevelData level, {bool tutorial = true, int seed = 1, ShopSetup setup = ShopSetup.base}) =>
    LevelSession(
      level: level,
      defaults: _config.defaults,
      modifiers: BakeModifiers.base,
      setup: setup,
      tutorialActive: tutorial,
      random: math.Random(seed),
    );

/// Thợ bánh nhanh (giữ tủ đầy).
const _baker = StaffMember(
  id: 'staff_baker',
  role: StaffRole.baker,
  character: 'staff_bao',
  speedValue: 2,
  skillValue: 3,
);

/// Bản sao [l] với vài trường khác (test dựng level ngắn).
LevelData _copy(LevelData l, {int? durationSec, int? startStock}) => LevelData(
      id: l.id,
      chapter: l.chapter,
      title: l.title,
      durationSec: durationSec ?? l.durationSec,
      goal: l.goal,
      menu: l.menu,
      caseSlots: l.caseSlots,
      startStock: startStock ?? l.startStock,
      patienceSec: l.patienceSec,
      spawn: l.spawn,
      flexibleChance: l.flexibleChance,
      specials: l.specials,
      introScene: l.introScene,
      outroScene: l.outroScene,
      isSpecial: l.isSpecial,
      newRecipe: l.newRecipe,
      overrides: l.overrides,
      mapPos: l.mapPos,
      tutorial: l.tutorial,
    );

List<String> _ids(String script) => [for (final s in TutorialSteps.of(script)) s.id];

/// Lái một session có hướng dẫn: gom sự kiện + thứ tự các bước đã hiện.
class _Driver {
  _Driver(this.s) : t = s.tutorial!;

  final LevelSession s;
  final TutorialRunner t;
  final log = <SessionEvent>[];
  final shown = <String>[];

  /// Gom sự kiện, ghi bước mới (gọi sau mỗi thao tác / bước logic).
  void note() {
    log.addAll(s.drainEvents());
    final id = t.current?.id;
    if (id != null && (shown.isEmpty || shown.last != id)) shown.add(id);
  }

  void tick([int steps = 1]) {
    for (var i = 0; i < steps; i++) {
      s.advance(LevelSession.step);
      note();
    }
  }

  void seconds(double sec) => tick((sec / LevelSession.step).round());

  /// Chạy tới khi [cond] đúng, tối đa [maxSec] giây thật (giờ màn có thể đang dừng). [each] chạy trước mỗi bước.
  void until(bool Function() cond, {double maxSec = 60, void Function()? each}) {
    var n = (maxSec / LevelSession.step).round();
    while (!cond()) {
      if (n-- <= 0 || s.isOver) fail('quá $maxSec s mà điều kiện chưa đúng (elapsed ${s.elapsed}, ${s.tutorial})');
      each?.call();
      if (cond()) break;
      tick();
    }
  }

  /// Bán cho mọi khách đứng quầy mua được.
  void sellAll() {
    for (final c in List<LevelCustomer>.of(s.customers)) {
      if (c.canBuy && s.displayCase.countOf(c.want) > 0) {
        s.sell(c.id);
        note();
      }
    }
  }

  int count(SessionEventType type) => log.where((e) => e.type == type).length;

  /// L1: bước 1 (bán) → bán tiếp tới khi tủ ≤ 1 → bước thẻ bánh.
  void basicsToBake() {
    until(() => t.current != null);
    expect(t.current, TutorialSteps.basicsSell);
    expect(s.sell(t.targetCustomer!), SellResult.sold);
    note();
    until(() => t.current != null, each: sellAll);
    expect(t.current, TutorialSteps.basicsBake);
  }

  /// L1 từ bước thẻ bánh tới lời chúc cuối (mẻ hoàn hảo).
  Batch basicsBakeToDone() {
    expect(s.startBatch(t.targetRecipe!), isTrue);
    note();
    return basicsMouldToDone();
  }

  /// L1 từ bước Khuôn (mẻ đã bắt đầu) tới lời chúc cuối.
  Batch basicsMouldToDone() {
    final b = s.kitchen.prep!;
    expect(t.current, TutorialSteps.basicsMould);
    expect(s.pickMould(t.targetMould!), isTrue);
    note();
    expect(t.current, TutorialSteps.basicsMix);
    s.finishMix(1.0);
    note();
    until(() => t.current != null);
    expect(t.current, TutorialSteps.basicsOven);
    until(() => b.ovenProgress >= b.bakeTarget);
    expect(s.takeOut(t.targetOven!), isTrue);
    note();
    expect(t.current, TutorialSteps.basicsFrost);
    s.finishFrost(1.0);
    note();
    for (var i = 0; i < 3; i++) {
      s.addTopping(t.targetTopping!);
      note();
    }
    expect(t.current, TutorialSteps.basicsBox);
    expect(s.pickBox(t.targetBox!), isTrue);
    note();
    expect(t.current, TutorialSteps.basicsDone);
    return b;
  }
}

void main() {
  group('levels.json + loader', () {
    test('L1 basics, L2 combo, L3 patience; level khác không có hướng dẫn', () {
      expect(_config.level(1).tutorial, TutorialIds.basics);
      expect(_config.level(2).tutorial, TutorialIds.combo);
      expect(_config.level(3).tutorial, TutorialIds.patience);
      for (final l in _config.levels.skip(3)) {
        expect(l.tutorial, isNull, reason: 'level ${l.id}');
      }
      // Bước 1 của L1 cần tủ có sẵn cupcake + khách tới sớm.
      final l1 = _config.level(1);
      expect(l1.menu.first, RecipeId.cupcakeVanilla);
      expect(l1.startStock, greaterThanOrEqualTo(2));
      expect(TutorialSteps.of('nope'), isEmpty);
    });

    test('id lạ: chặt → ném ghi rõ level + trường; khoan dung → giữ level, bỏ hướng dẫn, có báo', () {
      for (final bad in <Object>['tutorialX', 5, true]) {
        final json = jsonDecode(_asset()) as Map<String, dynamic>;
        ((json['levels'] as List)[1] as Map<String, dynamic>)['tutorial'] = bad;
        final raw = jsonEncode(json);
        expect(
          () => LevelConfigLoader.parse(raw, strict: true),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('level 2'), contains('tutorial')))),
          reason: '$bad',
        );
        final reasons = <String>[];
        final lenient = LevelConfigLoader.parse(raw, strict: false, onSkip: reasons.add);
        expect(lenient.hasLevel(2), isTrue);
        expect(lenient.level(2).tutorial, isNull);
        expect(lenient.level(1).tutorial, TutorialIds.basics);
        expect(reasons.where((r) => r.contains('tutorial')), hasLength(1), reason: '$reasons');
      }
    });
  });

  group('tạo runner', () {
    test('chỉ khi level có hướng dẫn và người gọi bật tutorialActive', () {
      expect(_session(_config.level(1), tutorial: false).tutorial, isNull);
      expect(_session(_config.level(4)).tutorial, isNull);
      final t = _session(_config.level(1)).tutorial!;
      expect(t.id, TutorialIds.basics);
      expect(t.current, isNull);
      expect(t.finished, isFalse);
    });

    test('chơi lại sau khi xong → không có runner (UI tính tutorialActive từ GameState)', () {
      final state = GameState.newGame(clock: _clock);
      final l1 = _config.level(1);
      expect(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)).tutorial, isNotNull);
      state.markTutorialDone(l1.tutorial!);
      expect(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)).tutorial, isNull);
    });
  });

  group('L1 basics', () {
    test('9 bước đúng thứ tự với thao tác giả, mục tiêu cụ thể, xong → tutorialDone một lần', () {
      final d = _Driver(_session(_config.level(1)));
      final s = d.s, t = d.t;

      // 1. Khách đầu tiên tới quầy (sớm) muốn cupcake vani.
      d.until(() => t.current != null);
      expect(t.current, TutorialSteps.basicsSell);
      expect(s.elapsed, lessThan(4.0));
      final first = t.targetCustomer!;
      expect(s.customer(first)!.canBuy, isTrue);
      expect(t.targetRecipe, RecipeId.cupcakeVanilla);
      expect(s.tutorialBlocking, isTrue);
      expect(s.dismissTutorialStep(), isFalse, reason: 'bước thao tác không ẩn bằng chạm');

      // Bước dừng giờ: không trừ giờ, không sinh khách, kiên nhẫn đứng yên.
      final elapsed = s.elapsed, timeLeft = s.timeLeft, onScene = s.customers.length;
      final patience = s.customer(first)!.patience;
      final logAt = d.log.length;
      d.seconds(20);
      expect(s.elapsed, elapsed);
      expect(s.timeLeft, timeLeft);
      expect(s.customers.length, onScene);
      expect(s.customer(first)!.patience, patience);
      expect(d.log.skip(logAt).where((e) => e.type == SessionEventType.customerArrived), isEmpty);
      expect(t.current, TutorialSteps.basicsSell);

      expect(s.sell(first), SellResult.sold);
      d.note();
      expect(t.current, isNull, reason: 'tủ còn 2 → chưa nhắc làm mẻ');
      expect(s.tutorialBlocking, isFalse);

      // 2. Tủ còn ≤ 1 → chỉ thẻ bánh.
      d.until(() => t.current != null, each: d.sellAll);
      expect(t.current, TutorialSteps.basicsBake);
      expect(t.targetRecipe, RecipeId.cupcakeVanilla);
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), lessThanOrEqualTo(1));
      expect(s.tutorialBlocking, isTrue);

      // 3. Khuôn → Trộn → Lò → Kem → Topping → Hộp.
      expect(s.startBatch(RecipeId.cupcakeVanilla), isTrue);
      d.note();
      final b = s.kitchen.prep!;
      expect(t.current, TutorialSteps.basicsMould);
      expect(t.targetMould, b.correctMould);
      expect(s.pickMould(b.mouldChoices.firstWhere((m) => m != b.correctMould)), isFalse);
      d.note();
      expect(t.current, TutorialSteps.basicsMould, reason: 'khuôn sai → ở lại bước');
      expect(s.pickMould(b.correctMould), isTrue);
      d.note();
      expect(t.current, TutorialSteps.basicsMix);
      expect(t.targetMould, isNull);
      s.finishMix(1.0);
      d.note();
      expect(b.stage, BatchStage.baking);
      expect(t.current, isNull, reason: 'kim còn xa vạch → chưa hiện bước Lò');
      expect(s.tutorialBlocking, isFalse);

      final beforeOven = s.elapsed;
      d.until(() => t.current != null);
      expect(t.current, TutorialSteps.basicsOven);
      expect(s.elapsed, greaterThan(beforeOven), reason: 'giờ chạy trong lúc chờ kim');
      expect(b.ovenProgress, greaterThanOrEqualTo(b.bakeTarget - 0.1 - 1e-9));
      expect(b.ovenProgress, lessThan(b.bakeTarget));
      expect(t.targetOven, b.oven);
      expect(s.tutorialBlocking, isTrue);
      // Lò vẫn chạy khi bước dừng giờ.
      final frozen = s.elapsed;
      d.until(() => b.ovenProgress >= b.bakeTarget, maxSec: 3);
      expect(s.elapsed, frozen);
      expect(s.takeOut(b.oven), isTrue);
      d.note();

      expect(t.current, TutorialSteps.basicsFrost);
      s.finishFrost(1.0);
      d.note();
      expect(t.current, TutorialSteps.basicsTopping);
      expect(t.targetTopping, b.correctTopping);
      s.addTopping(b.correctTopping);
      d.note();
      expect(t.current, TutorialSteps.basicsTopping, reason: 'cần đủ 3 lần');
      s.addTopping(b.correctTopping);
      s.addTopping(b.correctTopping);
      d.note();
      expect(t.current, TutorialSteps.basicsBox);
      expect(t.targetBox, b.correctBox);
      expect(s.pickBox(b.correctBox), isTrue);
      d.note();
      expect(d.count(SessionEventType.batchReady), 1);

      // 4. Mẻ vào tủ → xong ngay (tutorialDone), lời chúc là bước phụ: không dừng giờ, tự ẩn sau 3 s.
      expect(t.current, TutorialSteps.basicsDone);
      expect(t.targetRecipe, RecipeId.cupcakeVanilla);
      expect(s.tutorialBlocking, isFalse);
      expect(t.finished, isTrue);
      expect(d.count(SessionEventType.tutorialDone), 1);
      final doneAt = s.elapsed;
      d.seconds(2.9);
      expect(t.current, TutorialSteps.basicsDone);
      expect(s.elapsed, greaterThan(doneAt + 2.8));
      d.seconds(0.2);
      expect(t.current, isNull);
      expect(t.finished, isTrue);

      expect(d.shown, _ids(TutorialIds.basics));
      expect(d.count(SessionEventType.tutorialStep), 9);
      expect(d.count(SessionEventType.tutorialDone), 1);

      // Sau đó màn chạy bình thường, không còn bước nào.
      d.seconds(20);
      expect(t.current, isNull);
      expect(d.count(SessionEventType.tutorialStep), 9);
      expect(d.count(SessionEventType.tutorialDone), 1);
    });

    test('người chơi làm mẻ trước khi được nhắc → bỏ bước thẻ bánh; huỷ mẻ → quay lại thẻ bánh', () {
      final d = _Driver(_session(_config.level(1)));
      final s = d.s, t = d.t;
      d.until(() => t.current != null);
      expect(t.current, TutorialSteps.basicsSell);
      // Bắt đầu mẻ ngay trong bước 1: chưa được bỏ qua bước bán.
      expect(s.startBatch(RecipeId.cupcakeVanilla), isTrue);
      d.note();
      expect(t.current, TutorialSteps.basicsSell);
      expect(s.sell(t.targetCustomer!), SellResult.sold);
      d.note();
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), 2);
      expect(t.current, TutorialSteps.basicsMould, reason: 'đã có mẻ → thẳng bước Khuôn');

      s.cancelPrep();
      d.note();
      expect(t.current, TutorialSteps.basicsBake, reason: 'huỷ mẻ → nhắc làm mẻ mới ngay');
      expect(s.startBatch(RecipeId.cupcakeVanilla), isTrue);
      d.note();
      expect(t.current, TutorialSteps.basicsMould);
      d.basicsMouldToDone();
      d.seconds(3.1);
      expect(t.finished, isTrue);
      expect(d.shown, [
        'basicsSell', 'basicsMould', 'basicsBake', 'basicsMould', 'basicsMix', 'basicsOven', 'basicsFrost', //
        'basicsTopping', 'basicsBox', 'basicsDone',
      ]);
      expect(d.count(SessionEventType.tutorialDone), 1);
    });

    test('bán trước khi bước Bán kịp hiện (thao tác chen giữa bước logic) → vẫn tiến tới bước thẻ bánh', () {
      // Tủ trống lúc mở màn: khách đứng quầy chờ, chưa có bước nào. Thợ bánh đưa mẻ lên tủ; người nghe hudRevision bán
      // ngay trong cùng bước logic (HUD đổi giây sau phần nhân viên, trước `_update` của hướng dẫn). Thử nhiều tốc độ
      // thợ (lệch nhau 1 bước logic) để chắc có lượt mẻ lên tủ đúng bước HUD đổi giây.
      var early = 0;
      for (var k = 0; k < 40; k++) {
        final baker = StaffMember(
          id: 'staff_baker',
          role: StaffRole.baker,
          character: 'staff_bao',
          speedValue: 2 + k * LevelSession.step,
          skillValue: 3,
        );
        final d = _Driver(_session(_copy(_config.level(1), startStock: 0), setup: ShopSetup.base.withStaff([baker])));
        final s = d.s, t = d.t;
        var sold = false;
        void sellFirst() {
          if (sold || t.current != null) return;
          for (final c in s.customers) {
            if (c.canBuy && s.displayCase.countOf(c.want) > 0) {
              sold = s.sell(c.id) == SellResult.sold;
              return;
            }
          }
        }

        s.hudRevision.addListener(sellFirst);
        d.until(() => sold || t.current != null);
        s.hudRevision.removeListener(sellFirst);
        if (!sold) continue; // Bước Bán hiện trước: luồng thường, đã có test khác.
        early++;
        d.note();
        expect(d.shown, isEmpty, reason: 'k $k');
        expect(t.current, isNull);
        // Bước Bán coi như xong → bước thẻ bánh (tủ ≤ 1 hoặc hết 20 s), không hiện bước Bán nữa.
        d.until(() => t.current != null, maxSec: 25);
        expect(t.current, TutorialSteps.basicsBake, reason: 'k $k');
        d.basicsBakeToDone();
        expect(t.finished, isTrue);
        expect(d.shown, isNot(contains('basicsSell')));
        expect(d.count(SessionEventType.tutorialDone), 1);
      }
      expect(early, greaterThan(0), reason: 'không lượt nào bán được trước khi bước Bán hiện');
    });

    test('tủ còn nhiều (có thợ bánh) → bước thẻ bánh vẫn hiện 20 s sau bước Bán nếu chưa làm mẻ', () {
      // Không nhân viên, tủ đầy, không bán thêm: tủ không bao giờ ≤ 1 → nhắc đúng lúc hết 20 s.
      final full = _Driver(_session(_copy(_config.level(1), startStock: 6)));
      full.until(() => full.t.current != null);
      expect(full.t.current, TutorialSteps.basicsSell);
      expect(full.s.sell(full.t.targetCustomer!), SellResult.sold);
      full.note();
      final soldAt = full.s.elapsed;
      full.until(() => full.t.current != null, maxSec: 25);
      expect(full.t.current, TutorialSteps.basicsBake);
      expect(full.s.elapsed - soldAt, closeTo(20.0, 0.05));
      expect(full.s.displayCase.countOf(RecipeId.cupcakeVanilla), greaterThan(1));

      // Có thợ bánh, khách tới dày (×3): khách xếp hàng → thợ làm mẻ, tủ luôn > 1 cái; bước vẫn tới sau 20 s.
      final d = _Driver(_session(_config.level(1), setup: const ShopSetup(spawnRatePct: 200).withStaff(const [_baker])));
      final s = d.s, t = d.t;
      d.until(() => t.current != null);
      expect(t.current, TutorialSteps.basicsSell);
      expect(s.sell(t.targetCustomer!), SellResult.sold);
      d.note();
      final at = s.elapsed;
      var minStock = 1 << 30;
      d.until(() => t.current != null, maxSec: 25, each: () {
        minStock = math.min(minStock, s.displayCase.countOf(RecipeId.cupcakeVanilla));
      });
      expect(t.current, TutorialSteps.basicsBake);
      expect(s.elapsed - at, closeTo(20.0, 0.05));
      expect(minStock, greaterThan(1), reason: 'tủ chưa bao giờ ≤ 1');
      expect(d.count(SessionEventType.staffBatchReady), greaterThan(0), reason: 'thợ đã làm mẻ');
      expect(s.kitchen.prep, isNull);
      d.basicsBakeToDone();
      expect(t.finished, isTrue);
    });

    test('thoát khi lời chúc còn hiện → đã phát tutorialDone, lưu được', () {
      final state = GameState.newGame(clock: _clock);
      final l1 = _config.level(1);
      final d = _Driver(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)));
      d.basicsToBake();
      d.basicsBakeToDone();
      expect(d.t.current, TutorialSteps.basicsDone);
      for (final e in d.log) {
        if (e.type == SessionEventType.tutorialDone) state.markTutorialDone(d.t.id);
      }
      d.s.dispose();
      expect(state.isTutorialDone(TutorialIds.basics), isTrue);
      expect(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)).tutorial, isNull);
    });

    test('hết giờ (thua) ngay sau bước cuối vẫn tính là xong', () {
      // Đo giây màn chơi lúc tới lời chúc, rồi chơi lại y hệt với màn chỉ dài hơn chừng đó 1 s.
      double reachDone(LevelData level) {
        final d = _Driver(_session(level));
        d.basicsToBake();
        d.basicsBakeToDone();
        return d.s.elapsed;
      }

      final base = _copy(_config.level(1), startStock: 1);
      final at = reachDone(base);
      final short = _copy(base, durationSec: at.ceil() + 1);
      final d = _Driver(_session(short));
      d.basicsToBake();
      d.basicsBakeToDone();
      expect(d.s.elapsed, closeTo(at, 1e-6));
      expect(d.s.timeLeft, lessThan(TutorialSteps.basicsDone.autoHide!.inSeconds));
      d.until(() => d.s.isOver, maxSec: 3);
      expect(d.t.finished, isTrue);
      final doneIdx = d.log.indexWhere((e) => e.type == SessionEventType.tutorialDone);
      final timeUpIdx = d.log.indexWhere((e) => e.type == SessionEventType.timeUp);
      expect(doneIdx, isNonNegative);
      expect(doneIdx, lessThan(timeUpIdx), reason: 'UI lưu trước khi sang màn kết quả');
      expect(d.s.finish().won, isFalse);
    });

    test('thoát giữa chừng → không phát tutorialDone, không lưu; lần sau chạy lại từ đầu', () {
      final state = GameState.newGame(clock: _clock);
      final l1 = _config.level(1);
      final d = _Driver(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)));
      d.basicsToBake();
      expect(d.s.startBatch(RecipeId.cupcakeVanilla), isTrue);
      d.note();
      expect(d.t.current, TutorialSteps.basicsMould);
      // Thoát: UI chỉ lưu khi nhận tutorialDone.
      for (final e in d.log) {
        if (e.type == SessionEventType.tutorialDone) state.markTutorialDone(d.t.id);
      }
      d.s.dispose();
      expect(d.t.finished, isFalse);
      expect(state.isTutorialDone(TutorialIds.basics), isFalse);

      final again = _Driver(_session(l1, tutorial: !state.isTutorialDone(l1.tutorial!)));
      again.until(() => again.t.current != null);
      expect(again.t.current, TutorialSteps.basicsSell);
    });
  });

  group('L2 combo', () {
    test('hai bước (combo, món khác nhau) đều hiện, dừng giờ + cửa sổ combo, chạm để ẩn, xong một lần', () {
      final s = _session(_config.level(2));
      final d = _Driver(s);
      final t = d.t;
      final bot = LevelBot(BotSkill.of(0.75), random: math.Random(7));
      var checkedCombo = false, checkedVariety = false;
      var n = (120 / LevelSession.step).round();
      while (!t.finished) {
        if (n-- <= 0 || s.isOver) fail('L2: hướng dẫn chưa xong (${d.shown})');
        bot.step(s);
        d.note();
        final step = t.current;
        if (identical(step, TutorialSteps.comboMeter) && !checkedCombo) {
          checkedCombo = true;
          expect(s.combo, greaterThanOrEqualTo(2));
          expect(s.tutorialBlocking, isTrue);
          final elapsed = s.elapsed, window = s.comboTimeLeft, combo = s.combo;
          d.seconds(2);
          expect(s.elapsed, elapsed);
          expect(s.comboTimeLeft, window, reason: 'cửa sổ combo đứng yên');
          expect(s.combo, combo);
          expect(s.dismissTutorialStep(), isTrue);
          d.note();
          expect(identical(t.current, TutorialSteps.comboMeter), isFalse);
        } else if (identical(step, TutorialSteps.comboVariety) && !checkedVariety) {
          checkedVariety = true;
          final c = s.customer(t.targetCustomer!)!;
          expect(c.canBuy, isTrue);
          expect(c.want, RecipeId.cupcakeChocolate);
          expect(t.targetRecipe, RecipeId.cupcakeChocolate);
          final elapsed = s.elapsed, patience = c.patience;
          d.seconds(3.9);
          expect(t.current, TutorialSteps.comboVariety);
          expect(s.elapsed, elapsed);
          expect(c.patience, patience);
          d.seconds(0.2);
          expect(identical(t.current, TutorialSteps.comboVariety), isFalse, reason: 'tự ẩn sau 4 s');
        }
      }
      expect(checkedCombo && checkedVariety, isTrue);
      expect(d.shown.toSet(), _ids(TutorialIds.combo).toSet());
      expect(d.count(SessionEventType.tutorialStep), 2);
      expect(d.count(SessionEventType.tutorialDone), 1);
      d.seconds(20);
      expect(d.count(SessionEventType.tutorialStep), 2, reason: 'mỗi bước một lần');
    });
  });

  group('L3 patience', () {
    test('vòng kiên nhẫn < 50% (dừng giờ) → xong; khách bỏ đi → nhắc không dừng giờ, không phát xong lần hai', () {
      final d = _Driver(_session(_config.level(3)));
      final s = d.s, t = d.t;
      // Không bán gì: khách đứng quầy hết kiên nhẫn dần.
      d.until(() => t.current != null, maxSec: 60);
      expect(t.current, TutorialSteps.patienceRing);
      final c = s.customer(t.targetCustomer!)!;
      expect(c.canBuy, isTrue);
      expect(c.patienceFrac, lessThan(0.5));
      expect(c.patienceFrac, greaterThan(0.45), reason: 'hiện ngay khi vừa qua 50%');
      expect(s.tutorialBlocking, isTrue);
      final elapsed = s.elapsed, patience = c.patience, onScene = s.customers.length;
      d.seconds(3.9);
      expect(s.elapsed, elapsed);
      expect(c.patience, patience);
      expect(s.customers.length, onScene);
      expect(t.finished, isFalse);
      d.seconds(0.2);
      expect(t.current, isNull);
      expect(t.finished, isTrue);
      expect(d.count(SessionEventType.tutorialDone), 1);

      // Bước tuỳ chọn: khách đầu tiên bỏ đi.
      d.until(() => t.current != null, maxSec: 60);
      expect(t.current, TutorialSteps.patienceWalkout);
      expect(d.count(SessionEventType.walkedOut), 1);
      final gone = d.log.lastWhere((e) => e.type == SessionEventType.walkedOut).customerId;
      expect(t.targetCustomer, gone);
      expect(s.tutorialBlocking, isFalse);
      final at = s.elapsed;
      d.seconds(1);
      expect(s.elapsed, greaterThan(at + 0.9), reason: 'không dừng giờ');
      d.seconds(2.1);
      expect(t.current, isNull);
      expect(d.shown, _ids(TutorialIds.patience));
      expect(d.count(SessionEventType.tutorialDone), 1);
      d.seconds(30);
      expect(d.count(SessionEventType.tutorialStep), 2);
    });
  });

  group('bot cân bằng', () {
    test('không hướng dẫn: kết quả y hệt session tạo như trước GĐ5', () {
      for (final id in [1, 2, 3]) {
        final level = _config.level(id);
        final a = LevelBot(BotSkill.of(0.75), random: math.Random(3)).play(_session(level, tutorial: false));
        final b = LevelBot(BotSkill.of(0.75), random: math.Random(3)).play(LevelSession(
              level: level,
              defaults: _config.defaults,
              modifiers: BakeModifiers.base,
              random: math.Random(1),
            ));
        expect(a.coins, b.coins);
        expect(a.served, b.served);
        expect(a.lost, b.lost);
      }
    });
  });

  group('GameState', () {
    test('introSeen: mặc định false, mark/reset, báo thay đổi một lần', () {
      final s = GameState.newGame(clock: _clock);
      var notified = 0;
      s.addListener(() => notified++);
      expect(s.introSeen, isFalse);
      s.markIntroSeen();
      s.markIntroSeen();
      expect(s.introSeen, isTrue);
      expect(notified, 1);
      s.resetIntro();
      s.resetIntro();
      expect(s.introSeen, isFalse);
      expect(notified, 2);
    });

    test('tutorialsDone: mark/reset, id lạ vẫn giữ', () {
      final s = GameState.newGame(clock: _clock);
      var notified = 0;
      s.addListener(() => notified++);
      for (final id in TutorialIds.all) {
        expect(s.isTutorialDone(id), isFalse);
      }
      s.markTutorialDone(TutorialIds.basics);
      s.markTutorialDone(TutorialIds.basics);
      s.markTutorialDone('future_script');
      expect(s.isTutorialDone(TutorialIds.basics), isTrue);
      expect(s.isTutorialDone(TutorialIds.combo), isFalse);
      expect(s.tutorialsDone, {'basics', 'future_script'});
      expect(notified, 2);
      s.resetTutorials();
      expect(s.tutorialsDone, isEmpty);
      expect(notified, 3);
    });

    test('lưu bất đồng bộ (autosave) → đọc lại; hai trường đọc độc lập', () async {
      final repo = MemorySaveRepository();
      final s = GameState.newGame(clock: _clock)..attachAutosave(repo);
      s.markIntroSeen();
      s.markTutorialDone(TutorialIds.combo);
      expect(repo.writeCount, 0, reason: 'không ghi đồng bộ');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(repo.writeCount, 1);
      final json = jsonDecode(repo.data!) as Map<String, dynamic>;
      expect(json['introSeen'], isTrue);
      expect(json['tutorialsDone'], ['combo']);
      final again = await GameState.load(repo, clock: _clock);
      expect(again.introSeen, isTrue);
      expect(again.isTutorialDone(TutorialIds.combo), isTrue);
      expect(again.isTutorialDone(TutorialIds.basics), isFalse);
      s.dispose();

      // `introSeen` hỏng không ảnh hưởng `tutorialsDone` và ngược lại; phần tử hỏng bị bỏ.
      final base = GameState.newGame(clock: _clock).toJson();
      final a = GameState.fromJson({...base, 'introSeen': 'yes', 'tutorialsDone': ['basics', 3, '', 'patience']});
      expect(a.introSeen, isFalse);
      expect(a.tutorialsDone, {'basics', 'patience'});
      final b = GameState.fromJson({...base, 'introSeen': true, 'tutorialsDone': 'basics'});
      expect(b.introSeen, isTrue);
      expect(b.tutorialsDone, isEmpty);
      // Bản v2 trước GĐ5 (không có hai trường, không phải người chơi V1) → người chơi mới của GĐ5.
      final old = GameState.fromJson({...base}..remove('introSeen')..remove('tutorialsDone'));
      expect(old.introSeen, isFalse);
      expect(old.tutorialsDone, isEmpty);
    });

    test('quy đổi v1 → introSeen = true, cả 3 hướng dẫn xong; bản v2 đã quy đổi trước GĐ5 cũng vậy', () async {
      final v1 = GameState.newGame(clock: _clock).toJson()
        ..remove('progress')
        ..remove('shop')
        ..remove('introSeen')
        ..remove('tutorialsDone');
      v1['v'] = 1;
      v1['day'] = 4;
      final repo = MemorySaveRepository(jsonEncode(v1));
      final s = await GameState.load(repo, clock: _clock);
      expect(s.introSeen, isTrue);
      for (final id in TutorialIds.all) {
        expect(s.isTutorialDone(id), isTrue, reason: id);
      }
      // Bản v2 vừa ghi sau quy đổi giữ nguyên khi đọc lại.
      final again = await GameState.load(repo, clock: _clock);
      expect(again.introSeen, isTrue);
      expect(again.tutorialsDone, TutorialIds.all.toSet());

      // Người chơi V1 đã quy đổi ở GĐ2–4 (bản v2 có migratedFromV1, chưa có hai trường GĐ5).
      final pre5 = again.toJson()
        ..remove('introSeen')
        ..remove('tutorialsDone');
      final migrated = GameState.fromJson(pre5);
      expect(migrated.introSeen, isTrue);
      expect(migrated.tutorialsDone, TutorialIds.all.toSet());

      // Đã reset trong Cài đặt rồi lưu → giữ đúng lựa chọn, không quy đổi lại.
      again
        ..resetIntro()
        ..resetTutorials();
      final reread = GameState.fromJson(again.toJson());
      expect(reread.introSeen, isFalse);
      expect(reread.tutorialsDone, isEmpty);
    });

    test('bản v2 trước GĐ5 đã có tiến trình level (không phải V1) → đã xem intro + xong 3 hướng dẫn', () {
      final played = GameState.newGame(clock: _clock);
      final r = _session(_config.level(1), tutorial: false);
      while (!r.isOver) {
        r.advance(LevelSession.maxFrameDt);
      }
      played.applyLevelResult(r.finish());
      final json = played.toJson()
        ..remove('introSeen')
        ..remove('tutorialsDone');
      final progress = json['progress'] as Map<String, dynamic>;
      expect(progress['migratedFromV1'], isFalse);
      expect(progress['levels'], isNotEmpty);
      final old = GameState.fromJson(json);
      expect(old.introSeen, isTrue);
      expect(old.tutorialsDone, TutorialIds.all.toSet());

      // Có trường (kể cả sau reset) → giữ nguyên, không suy ra.
      final kept = GameState.fromJson({...json, 'introSeen': false, 'tutorialsDone': <String>[]});
      expect(kept.introSeen, isFalse);
      expect(kept.tutorialsDone, isEmpty);
      final partial = GameState.fromJson({...json, 'tutorialsDone': ['basics']});
      expect(partial.introSeen, isTrue);
      expect(partial.tutorialsDone, {'basics'});
    });

    test('resetAll → chưa xem cảnh mở đầu, chưa xong hướng dẫn', () async {
      final s = GameState.newGame(clock: _clock)
        ..markIntroSeen()
        ..markTutorialDone(TutorialIds.basics);
      await s.resetAll();
      expect(s.introSeen, isFalse);
      expect(s.tutorialsDone, isEmpty);
    });
  });

  test('AppRoutes: cảnh mở đầu / intro ngắn', () {
    expect(AppRoutes.intro, '/intro');
    expect(AppRoutes.shortIntro, '/splash');
    expect(AppRoutes.initialFor(introSeen: false), AppRoutes.intro);
    expect(AppRoutes.initialFor(introSeen: true), AppRoutes.shortIntro);
    expect(AppRoutes.isIntro(AppRoutes.menu), isFalse);
  });
}
