import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/models/recipe.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/components/game_paint.dart';
import 'package:sugarleaf_bakery/game/logic/cake_geometry.dart';
import 'package:sugarleaf_bakery/game/logic/station_setup.dart';
import 'package:sugarleaf_bakery/game/stations/bake_station.dart';
import 'package:sugarleaf_bakery/game/stations/box_station.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/game/stations/station.dart';
import 'package:sugarleaf_bakery/game/stations/topping_station.dart';

// QA: 6 trạm của đơn đặc biệt (BakeryGame) chơi bằng con trỏ thật trên game đang chạy (GameWidget, đồng hồ giả của
// test) → số đo thô → `Scoring.evaluate` → lời chê của khách phải chỉ đúng trạm chưa đạt. Chạy cho cả 18 món.

const _customer = Customer(kind: CustomerKind.regular, appearanceSeed: 1);

/// Đơn chuẩn của món: kem đầu tiên, 2 cái topping đầu tiên, hộp chuẩn của món.
Order _orderFor(Recipe r, {int id = 7, List<ToppingRequest>? toppings, BoxType? box}) => Order(
      id: id,
      recipe: r.id,
      frosting: r.frostings.first,
      toppings: toppings ?? [ToppingRequest(r.toppings.first, 2)],
      box: box ?? r.box,
      line: OrderLineKind.generic1,
    );

BakeResult _score(Order order, BakeOutcome o) => Scoring.evaluate(
      order: order,
      customer: _customer,
      outcome: o,
      modifiers: BakeModifiers.base,
      decorTipBonusPct: 0,
    );

/// Người chơi giả: đưa con trỏ (toạ độ khung 1280×720) thẳng vào `BakeryGame`, thời gian chạy bằng `tester.pump`.
class _Player {
  _Player(this.tester, this.game);

  final WidgetTester tester;
  final BakeryGame game;
  int _id = 1;

  Recipe get recipe => game.recipe;

  static Future<_Player> start(WidgetTester tester, Order order, {BakeModifiers modifiers = BakeModifiers.base}) async {
    final game = BakeryGame(order: order, modifiers: modifiers);
    await tester.pumpWidget(MaterialApp(home: GameWidget<BakeryGame>(game: game)));
    return _Player(tester, game);
  }

  Future<void> run(double sec, {int ms = 16}) async {
    final steps = (sec * 1000 / ms).ceil();
    for (var i = 0; i < steps; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  /// Chờ trạm kiểu [T] vào hẳn (nhận thao tác).
  Future<T> until<T extends Station>({double maxSec = 6}) async {
    for (var t = 0.0; t < maxSec; t += 0.016) {
      final s = game.currentStation;
      if (s is T && s.acceptsInput) return s;
      await tester.pump(const Duration(milliseconds: 16));
    }
    fail('quá $maxSec s chưa tới trạm $T (đang ở ${game.currentStation})');
  }

  int nextPointer() => _id++;

  void drag(Offset from, Offset to, {int steps = 10, int? pointer}) {
    final id = pointer ?? nextPointer();
    game.pointerDown(id, from);
    for (var i = 1; i <= steps; i++) {
      game.pointerMove(id, Offset.lerp(from, to, i / steps)!);
    }
    game.pointerUp(id, to);
  }

  Future<void> mould({int wrong = 0}) async {
    final s = await until<MouldStation>();
    final correct = s.choices.indexOf(recipe.mould);
    expect(correct, isNonNegative, reason: 'khuôn đúng phải có trong 4 ô');
    for (var k = 0; k < wrong; k++) {
      final w = (correct + 1 + k % 3) % 4;
      drag(MouldStation.slotCenter(w), MouldStation.trayRect.center);
      await run(1.6); // lắc 0.5 s rồi trượt về chỗ
    }
    drag(MouldStation.slotCenter(correct), MouldStation.trayRect.center);
  }

  /// Xoay [turns] vòng quanh tâm âu; chưa tự xong thì bấm Xong.
  Future<MixStation> mix(double turns) async {
    final s = await until<MixStation>();
    final id = nextPointer();
    const c = MixStation.center;
    const r = 150.0;
    game.pointerDown(id, c + const Offset(r, 0));
    final steps = (turns * 72).round();
    for (var i = 1; i <= steps; i++) {
      final a = i * 2 * math.pi / 72;
      game.pointerMove(id, c + Offset(math.cos(a), math.sin(a)) * r);
    }
    game.pointerUp(id, c + const Offset(r, 0));
    await tester.pump();
    if (!s.isDone) game.pressDone();
    return s;
  }

  /// Nhấn giữ nút nướng tới khi kim tới [release] rồi thả (release ≥ 1 → giữ tới khi tự thả = cháy).
  Future<BakeStation> bake(double release) async {
    final s = await until<BakeStation>();
    final id = nextPointer();
    game.pointerDown(id, BakeStation.buttonCenter);
    for (var i = 0; i < 2000 && s.meter.holding && (release >= 1 || s.meter.value < release - 0.002); i++) {
      await tester.pump(const Duration(milliseconds: 3));
    }
    game.pointerUp(id, BakeStation.buttonCenter);
    await tester.pump();
    return s;
  }

  /// Tô theo [frac] phần đầu đường gợi ý; chưa tự xong thì bấm Xong.
  Future<FrostStation> frost(double frac) async {
    final s = await until<FrostStation>();
    final g = s.tracker.guide;
    final n = (g.length * frac).round().clamp(1, g.length);
    final id = nextPointer();
    game.pointerDown(id, g.first);
    for (final p in g.take(n).skip(1)) {
      game.pointerMove(id, p);
    }
    game.pointerUp(id, g[n - 1]);
    await tester.pump();
    if (!s.isDone) game.pressDone();
    return s;
  }

  /// Điểm thứ [i] rải trên mặt bánh (không trùng nhau).
  static Offset spot(Rect top, int i) {
    final a = i * 2.39996;
    final k = 0.15 + 0.6 * ((i % 5) / 4);
    return fromEllipseUnit(Offset(math.cos(a) * k, math.sin(a) * k), top);
  }

  Future<ToppingStation> toppings(List<ToppingId> list, {bool done = true}) async {
    final s = await until<ToppingStation>();
    for (var i = 0; i < list.length; i++) {
      final tray = s.trays.indexOf(list[i]);
      expect(tray, isNonNegative, reason: '${list[i].name} không có trên khay ${s.trays}');
      drag(ToppingStation.trayCenter(tray), spot(s.top, i));
    }
    if (done) game.pressDone();
    return s;
  }

  /// Điểm cầm bánh ở trạm hộp (giữa thân bánh đang ngồi trên đĩa chờ).
  Offset get cakeGrab =>
      seatedCakeRect(recipe.mould, BoxStation.cakeHome.dx, BoxStation.cakeHome.dy + 96, BoxStation.cakeSize, recipe: recipe.id).center;

  Future<BakeOutcome> box(BoxType b) async {
    await until<BoxStation>();
    drag(cakeGrab, BoxStation.boxCenter(boxChoices.indexOf(b)));
    for (var t = 0.0; t < 3 && game.hud.outcome == null; t += 0.016) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final o = game.hud.outcome;
    expect(o, isNotNull, reason: 'không ra kết quả sau khi đóng hộp');
    return o!;
  }

  /// Chơi đủ 6 trạm.
  Future<BakeOutcome> play({
    int wrongMoulds = 0,
    double? mixTurns,
    double? bakeAt,
    double frost = 1,
    List<ToppingId>? toppings,
    BoxType? box,
    required Order order,
  }) async {
    await mould(wrong: wrongMoulds);
    await mix(mixTurns ?? recipe.mixTurns.toDouble());
    await bake(bakeAt ?? recipe.bakeTarget);
    await this.frost(frost);
    await this.toppings(toppings ?? [for (final t in order.toppings) for (var i = 0; i < t.count; i++) t.topping]);
    return this.box(box ?? order.box);
  }
}

void main() {
  group('QA 6 trạm × 18 món: chơi chuẩn → 5★, không lời chê', () {
    for (final r in Catalog.recipes) {
      testWidgets(r.id.name, (tester) async {
        final order = _orderFor(r);
        final p = await _Player.start(tester, order);
        final o = await p.play(order: order);
        expect(o.wrongMouldDrops, 0);
        expect(o.mixTurns, closeTo(r.mixTurns, 0.05));
        expect(o.bakeRelease, closeTo(r.bakeTarget, 0.01));
        expect(o.frostCoverage, greaterThanOrEqualTo(0.9));
        expect(o.toppingsPlaced, {r.toppings.first: 2});
        expect(o.boxChosen, r.box);
        final res = _score(order, o);
        for (final s in res.stations.values) {
          expect(s.score, greaterThanOrEqualTo(Scoring.goodThreshold), reason: '$s');
        }
        expect(res.stars, 5);
        expect(res.complaint, isNull);
      });
    }
  });

  group('QA một trạm hỏng → khách chê đúng trạm đó', () {
    // Mỗi tình huống chạy trên một món khác nhau (xoay vòng) để phủ nhiều khuôn / mục tiêu nướng.
    final recipes = Catalog.recipes;
    Recipe pick(int i) => recipes[(i * 5) % recipes.length];

    testWidgets('khuôn: thả sai 2 lần rồi đúng → mouldWrong, điểm khuôn 0.3', (tester) async {
      final r = pick(0);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, wrongMoulds: 2);
      expect(o.wrongMouldDrops, 2);
      final res = _score(order, o);
      expect(res.stations[StationId.mould]!.score, closeTo(0.3, 1e-9));
      expect(res.stations[StationId.mould]!.issue, StationIssue.wrongMould);
      expect(res.weakest, StationId.mould);
      expect(res.complaint, FeedbackKey.mouldWrong);
    });

    testWidgets('khuôn: thả ngoài khay / huỷ con trỏ giữa chừng không tính là sai', (tester) async {
      final r = pick(1);
      final p = await _Player.start(tester, _orderFor(r));
      final s = await p.until<MouldStation>();
      final wrong = (s.choices.indexOf(r.mould) + 1) % 4;
      p.drag(MouldStation.slotCenter(wrong), const Offset(1000, 650)); // ngoài khay
      final id = p.nextPointer();
      p.game.pointerDown(id, MouldStation.slotCenter(wrong));
      p.game.pointerMove(id, MouldStation.trayRect.center);
      p.game.pointerCancel(id); // hệ thống huỷ khi khuôn đang trên khay
      await p.run(1.5);
      expect(p.game.record.wrongMouldDrops, 0);
      expect(p.game.currentStation, same(s));
    });

    testWidgets('trộn thiếu → mixUnder', (tester) async {
      final r = pick(2);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, mixTurns: r.mixTurns * 0.5);
      final res = _score(order, o);
      expect(res.stations[StationId.mix]!.issue, StationIssue.underMixed);
      expect(res.complaint, FeedbackKey.mixUnder);
    });

    testWidgets('trộn quá (xoay quá 2× mục tiêu) → tự dừng ở 2×, mixOver', (tester) async {
      final r = pick(3);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, mixTurns: r.mixTurns * 2.5);
      expect(o.mixTurns, closeTo(r.mixTurns * 2.0, 1e-6));
      final res = _score(order, o);
      expect(res.stations[StationId.mix]!.issue, StationIssue.overMixed);
      expect(res.complaint, FeedbackKey.mixOver);
    });

    for (final (name, delta, perfect) in const [
      ('mép trên vùng hoàn hảo (+0.045)', 0.045, true),
      ('mép dưới vùng hoàn hảo (−0.045)', -0.045, true),
    ]) {
      testWidgets('nướng $name → 1.0, không chê', (tester) async {
        final r = pick(4);
        final order = _orderFor(r);
        final p = await _Player.start(tester, order);
        final o = await p.play(order: order, bakeAt: r.bakeTarget + delta);
        final res = _score(order, o);
        expect(res.stations[StationId.bake]!.score, perfect ? 1.0 : lessThan(1));
        expect(res.complaint, isNull);
        expect(res.stars, 5);
      });
    }

    testWidgets('nướng trong vùng "được" (+0.12) → 0.6 ≤ điểm < 0.9, chê cháy', (tester) async {
      final r = pick(5);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, bakeAt: r.bakeTarget + 0.12);
      final bake = _score(order, o).stations[StationId.bake]!;
      expect(bake.score, inInclusiveRange(0.6, 0.9));
      expect(bake.issue, StationIssue.burnt);
      expect(_score(order, o).complaint, FeedbackKey.bakeBurnt);
    });

    testWidgets('nướng chưa chín (−0.3) → bakeUnder', (tester) async {
      final r = pick(6);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, bakeAt: r.bakeTarget - 0.3);
      final res = _score(order, o);
      expect(res.stations[StationId.bake]!.issue, StationIssue.underBaked);
      expect(res.complaint, FeedbackKey.bakeUnder);
      expect(res.weakest, StationId.bake);
    });

    testWidgets('giữ tới hết thanh → tự thả ở 1.0, cháy → bakeBurnt', (tester) async {
      final r = pick(7);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, bakeAt: 1.0);
      expect(o.bakeRelease, 1.0);
      final res = _score(order, o);
      expect(res.complaint, FeedbackKey.bakeBurnt);
      expect(res.stars, lessThanOrEqualTo(4));
    });

    testWidgets('phủ kem 25% → frostPatchy', (tester) async {
      final r = pick(8);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, frost: 0.25);
      expect(o.frostCoverage, lessThan(Scoring.goodThreshold));
      final res = _score(order, o);
      expect(res.stations[StationId.frost]!.issue, StationIssue.patchy);
      expect(res.complaint, FeedbackKey.frostPatchy);
    });

    testWidgets('topping thiếu (1/3) → toppingMissing', (tester) async {
      final r = pick(9);
      final order = _orderFor(r, toppings: [ToppingRequest(r.toppings.first, 3)]);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, toppings: [r.toppings.first]);
      final res = _score(order, o);
      expect(res.complaint, FeedbackKey.toppingMissing);
    });

    testWidgets('topping sai loại (đủ đúng + 2 mồi) → toppingWrong', (tester) async {
      final r = pick(10);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      await p.mould();
      await p.mix(r.mixTurns.toDouble());
      await p.bake(r.bakeTarget);
      await p.frost(1);
      final s = await p.until<ToppingStation>();
      final decoy = s.trays.firstWhere((t) => t != r.toppings.first);
      await p.toppings([r.toppings.first, r.toppings.first, decoy, decoy]);
      final o = await p.box(r.box);
      expect(o.toppingsPlaced[decoy], 2);
      expect(_score(order, o).complaint, FeedbackKey.toppingWrong);
    });

    testWidgets('sai hộp → boxWrong', (tester) async {
      final r = pick(11);
      final order = _orderFor(r);
      final wrong = boxChoices.firstWhere((b) => b != r.box);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, box: wrong);
      expect(o.boxChosen, wrong);
      final res = _score(order, o);
      expect(res.stations[StationId.box]!.issue, StationIssue.wrongBox);
      expect(res.complaint, FeedbackKey.boxWrong);
    });

    testWidgets('hai trạm cùng hỏng: chê trạm điểm thấp nhất (nướng cháy nặng hơn sai hộp)', (tester) async {
      final r = pick(12);
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      final o = await p.play(order: order, bakeAt: 1.0, box: boxChoices.firstWhere((b) => b != r.box));
      final res = _score(order, o);
      expect(res.weakest, StationId.bake);
      expect(res.complaint, FeedbackKey.bakeBurnt);
    });
  });

  group('QA thao tác biên trong 6 trạm', () {
    final r = Catalog.recipe(RecipeId.strawberryCake);

    testWidgets('ngón thứ hai bị bỏ qua khi ngón đầu đang kéo khuôn', (tester) async {
      final p = await _Player.start(tester, _orderFor(r));
      final s = await p.until<MouldStation>();
      final correct = s.choices.indexOf(r.mould);
      final wrong = (correct + 1) % 4;
      p.game.pointerDown(1, MouldStation.slotCenter(correct));
      // Ngón 2 kéo khuôn sai lên khay: không được tính.
      p.drag(MouldStation.slotCenter(wrong), MouldStation.trayRect.center, pointer: 2);
      expect(p.game.record.wrongMouldDrops, 0);
      p.game.pointerMove(1, MouldStation.trayRect.center);
      p.game.pointerUp(1, MouldStation.trayRect.center);
      await p.until<MixStation>();
      expect(p.game.record.wrongMouldDrops, 0);
    });

    testWidgets('bấm liên tục khi đang chuyển trạm: bị nuốt, trạm sau không nhận vòng trộn / khuôn sai', (tester) async {
      final p = await _Player.start(tester, _orderFor(r));
      final s = await p.until<MouldStation>();
      final correct = s.choices.indexOf(r.mould);
      p.drag(MouldStation.slotCenter(correct), MouldStation.trayRect.center);
      // Trong 1 s hoạt cảnh mừng: kéo khuôn sai, xoay âu, nhấn Xong liên tục.
      for (var k = 0; k < 40; k++) {
        p.drag(MouldStation.slotCenter((correct + 1) % 4), MouldStation.trayRect.center);
        p.drag(MixStation.center + const Offset(150, 0), MixStation.center + const Offset(-150, 0), steps: 6);
        p.game.pressDone();
        await tester.pump(const Duration(milliseconds: 30));
      }
      final mix = await p.until<MixStation>();
      expect(p.game.record.wrongMouldDrops, 0);
      expect(mix.meter.turns, 0);
      expect(mix.isDone, isFalse);
    });

    testWidgets('nhấn Xong ở trạm trộn khi chưa đủ 1 vòng: không làm gì', (tester) async {
      final p = await _Player.start(tester, _orderFor(r));
      await p.mould();
      final s = await p.until<MixStation>();
      final id = p.nextPointer();
      p.game.pointerDown(id, MixStation.center + const Offset(150, 0));
      for (var i = 1; i <= 30; i++) {
        final a = i * 2 * math.pi / 72;
        p.game.pointerMove(id, MixStation.center + Offset(math.cos(a), math.sin(a)) * 150);
      }
      p.game.pointerUp(id, MixStation.center);
      for (var k = 0; k < 10; k++) {
        p.game.pressDone();
      }
      await p.run(1.5);
      expect(s.isDone, isFalse);
      expect(p.game.currentStation, same(s));
    });

    testWidgets('trạm nướng: chạm nhanh (< 4% thanh) không ghi, nhấn lại vẫn chạy tiếp', (tester) async {
      final p = await _Player.start(tester, _orderFor(r));
      await p.mould();
      await p.mix(r.mixTurns.toDouble());
      final s = await p.until<BakeStation>();
      p.game.pointerDown(9, BakeStation.buttonCenter);
      await tester.pump(const Duration(milliseconds: 30));
      p.game.pointerUp(9, BakeStation.buttonCenter);
      expect(s.meter.released, isFalse);
      final before = s.meter.value;
      expect(before, greaterThan(0));
      await p.bake(r.bakeTarget);
      expect(p.game.record.bakeRelease, closeTo(r.bakeTarget, 0.01));
    });

    testWidgets('hộp: thả bánh xong, kéo / thả tiếp vào hộp khác trong lúc đóng nắp không đổi lựa chọn, ra đúng 1 kết quả',
        (tester) async {
      final order = _orderFor(r);
      final p = await _Player.start(tester, order);
      await p.mould();
      await p.mix(r.mixTurns.toDouble());
      await p.bake(r.bakeTarget);
      await p.frost(1);
      await p.toppings([r.toppings.first, r.toppings.first]);
      await p.until<BoxStation>();
      final right = boxChoices.indexOf(r.box);
      final other = (right + 1) % 3;
      p.drag(p.cakeGrab, BoxStation.boxCenter(right));
      var notifications = 0;
      p.game.hud.addListener(() {
        if (p.game.hud.outcome != null) notifications++;
      });
      for (var k = 0; k < 20; k++) {
        p.drag(BoxStation.boxCenter(right), BoxStation.boxCenter(other));
        p.drag(p.cakeGrab, BoxStation.boxCenter(other));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await p.run(1);
      expect(p.game.record.boxChosen, r.box);
      expect(p.game.hud.outcome?.boxChosen, r.box);
      expect(notifications, greaterThanOrEqualTo(1));
      final first = p.game.hud.outcome;
      await p.run(1);
      expect(identical(p.game.hud.outcome, first), isTrue);
    });

    test('topping: giữ ngón trên topping đã đặt rồi (ngón khác) bấm Xong — topping không được mất sau khi chốt', () {
      final order = _orderFor(r);
      final game = BakeryGame(order: order, modifiers: BakeModifiers.base);
      final s = ToppingStation(game)..update(1);
      final tray = s.trays.indexOf(r.toppings.first);
      for (var i = 0; i < 2; i++) {
        s.pointerDown(ToppingStation.trayCenter(tray));
        s.pointerMove(_Player.spot(s.top, i));
        s.pointerUp(_Player.spot(s.top, i));
      }
      expect(s.placed, hasLength(2));
      // Ngón 1 nhấn lên topping thứ hai đang nằm trên bánh (vùng chạm = tâm topping, nhích lên 0.3 cỡ).
      final at = fromEllipseUnit(s.placed[1].unit, s.top).translate(0, -toppingSize(s.top) * 0.3);
      s.pointerDown(at);
      // Ngón 2 bấm nút Xong (nút Flutter nằm trên lớp Listener của game → BakeryGame.pressDone → done()).
      expect(s.acceptsInput && s.canDone, isTrue);
      s.done();
      expect(s.isDone, isTrue);
      // Ngón 1 nhấc lên trong 0.9 s hoạt cảnh mừng (BakeryGame vẫn chuyển pointerUp vì ngón này không bị nuốt).
      s.pointerUp(at);
      expect(s.placed, hasLength(2), reason: 'đã bấm Xong nhưng nhấc ngón vẫn gỡ topping khỏi bánh');
      expect(game.record.toOutcome().toppingsPlaced, {r.toppings.first: 2});
    });

    test('topping: đang nhấc một topping đã đặt để dời chỗ thì (ngón khác) bấm Xong — topping không được biến mất', () {
      final game = BakeryGame(order: _orderFor(r), modifiers: BakeModifiers.base);
      final s = ToppingStation(game)..update(1);
      final tray = s.trays.indexOf(r.toppings.first);
      for (var i = 0; i < 2; i++) {
        s.pointerDown(ToppingStation.trayCenter(tray));
        s.pointerUp(_Player.spot(s.top, i));
      }
      final at = fromEllipseUnit(s.placed[0].unit, s.top).translate(0, -toppingSize(s.top) * 0.3);
      s.pointerDown(at);
      s.pointerMove(at.translate(30, 0)); // > 12 px: nhấc topping lên để dời
      s.done();
      s.pointerUp(s.top.center);
      expect(game.record.toOutcome().toppingsPlaced, {r.toppings.first: 2},
          reason: 'topping đang cầm lúc bấm Xong bị xoá khỏi bánh');
    });

    test('topping: đang dời một topping đã đặt thì bị huỷ con trỏ (cuộc gọi đến) — topping trở về chỗ cũ', () {
      final game = BakeryGame(order: _orderFor(r), modifiers: BakeModifiers.base);
      final s = ToppingStation(game)..update(1);
      final tray = s.trays.indexOf(r.toppings.first);
      for (var i = 0; i < 2; i++) {
        s.pointerDown(ToppingStation.trayCenter(tray));
        s.pointerUp(_Player.spot(s.top, i));
      }
      final before = s.placed[0].unit;
      final at = fromEllipseUnit(before, s.top).translate(0, -toppingSize(s.top) * 0.3);
      s.pointerDown(at);
      s.pointerMove(at.translate(30, 0)); // > 12 px: nhấc topping lên để dời
      expect(s.placed, hasLength(1));
      s.pointerCancel();
      expect(s.placed, hasLength(2), reason: 'huỷ con trỏ làm topping đang dời rơi mất');
      expect(s.placed[0].unit, before, reason: 'topping phải về đúng chỗ và thứ tự cũ');
      // Huỷ khi đang kéo topping mới từ khay thì vẫn rơi, không thêm vào bánh.
      s.pointerDown(ToppingStation.trayCenter(tray));
      s.pointerMove(s.top.center);
      s.pointerCancel();
      expect(game.record.toOutcome().toppingsPlaced, {r.toppings.first: 2});
    });
  });
}
