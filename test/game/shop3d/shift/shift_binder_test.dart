import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/shift/shift_economy.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_binder.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_stage.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations_en.dart';

/// Bộ nối ca bán (G2): pha của `ShiftSession` ↔ `ShiftStage` ↔ bong bóng. Thế giới giả như shift_stage_test (không
/// thermion), phiên thật trên `CityGame`.

const _dt = 1 / 60;
const _owned = {Shop3dRequires.cafeTables};
final _now = DateTime(2026, 11, 4, 10);
final _en = AppLocalizationsEn();

class _World implements Shop3dPilotWorld {
  _World(List<ChibiActor> actors) : director = ChibiDirector(actors);

  @override
  final ChibiDirector director;

  @override
  Set<String> get owned => _owned;

  final _models = <String, ChibiModel>{};

  @override
  ChibiModel? readyModel(String id) => _models[id];

  @override
  void prepareModels(List<String> ids) {
    for (final id in ids) {
      if (isShiftGuestId(id)) _models.putIfAbsent(id, () => ChibiSizes.fit(buildShiftGuest(id)));
    }
  }

  @override
  void addActor(ChibiActor a) => director.actors.add(a);

  @override
  void removeActor(ChibiActor a) => director.actors.remove(a);
}

/// Bong bóng đã gọi: (id chibi, chữ, số giây).
typedef _Said = (String, String, double);

/// Số đo thô cho [order] mà `Scoring.evaluate` chấm đúng [stars] sao (chép từ test/core/shift/shift_test_helpers.dart —
/// gói test tạm của game không có test core).
BakeOutcome _outcomeFor(Order order, int stars) {
  final r = order.recipeData;
  final placed = <ToppingId, int>{};
  for (final t in order.toppings) {
    placed[t.topping] = (placed[t.topping] ?? 0) + t.count;
  }
  final wrongBox = BoxType.values.firstWhere((b) => b != order.box);
  return BakeOutcome(
    wrongMouldDrops: 0,
    mixTurns: r.mixTurns.toDouble(),
    bakeRelease: stars <= 1 ? 1.0 : r.bakeTarget,
    frostCoverage: switch (stars) {
      5 => 1.0,
      4 => 0.6,
      _ => 0.3,
    },
    toppingsPlaced: stars <= 2 ? const {} : placed,
    boxChosen: stars <= 3 ? wrongBox : order.box,
  );
}

void main() {
  final models = {for (final id in ChibiCharacters.allIds) id: ChibiCharacters.build(id)};

  CityGame game({int level = 1}) =>
      CityGame(wallet: CityWallet(xp: PlayerLevel.xpToReach(level)), clock: () => _now)..refreshDay();

  ({ShiftSession session, ShiftStage stage, _World world, ShiftBinder binder, List<_Said> said}) make({
    int level = 1,
    int seed = 1,
    AppLocalizations? l10n,
    bool noL10n = false,
  }) {
    final w = _World(ChibiCast.build(models: models));
    final session = ShiftSession(game: game(level: level), random: math.Random(seed));
    final stage = ShiftStage(w, arriveTimeout: const Duration(seconds: 99));
    final said = <_Said>[];
    final binder = ShiftBinder(
      session: session,
      stage: stage,
      say: (id, text, s) => said.add((id, text, s)),
      l10n: () => noL10n ? null : (l10n ?? _en),
      random: math.Random(seed),
    );
    return (session: session, stage: stage, world: w, binder: binder, said: said);
  }

  void run(ShiftStage s, _World w, double seconds, {bool Function()? until}) {
    for (var t = 0.0; t < seconds; t += _dt) {
      s.update(_dt);
      w.director.update(_dt, _owned);
      if (until != null && until()) return;
    }
  }

  /// Chạy tới khi khách hiện tại tới quầy (phiên sang `ordering`).
  void arrive(ShiftSession session, ShiftStage stage, _World w) {
    run(stage, w, 40, until: () => session.phase == ShiftPhase.ordering);
    expect(session.phase, ShiftPhase.ordering, reason: 'khách ${session.index} tới quầy');
  }

  String orderLine(ShiftSession s, AppLocalizations l) =>
      l.orderLineText(s.current.order.line, l.recipeName(s.current.order.recipe));

  group('start / khách tới', () {
    test('sân khấu bắt đầu với đủ khách của phiên, hạn tới quầy theo core', () {
      final m = make();
      expect(m.binder.running, isFalse);
      m.binder.start();
      expect(m.binder.running, isTrue);
      expect(m.stage.active, isTrue);
      expect(m.stage.total, m.session.total);
      expect(m.stage.index, 0);
      expect(m.stage.arriveTimeout, ShiftEconomy.arriveTimeout);
      expect(m.stage.onArrived, isNotNull);
      expect(isShiftGuestId(m.stage.currentId!), isTrue);
      // start lần nữa: không bắt đầu lại.
      final first = m.stage.currentActor;
      m.binder.start();
      expect(m.stage.currentActor, same(first));
    });

    test('khách tới quầy → customerArrived (ordering) + bong bóng câu gọi món của đơn', () {
      final m = make();
      m.binder.start();
      expect(m.session.phase, ShiftPhase.arriving);
      run(m.stage, m.world, 1);
      expect(m.session.phase, ShiftPhase.arriving, reason: 'khách còn đang đi');
      expect(m.said, isEmpty);
      arrive(m.session, m.stage, m.world);
      expect(m.stage.arrived, isTrue);
      expect(m.said, [(m.stage.currentId!, orderLine(m.session, _en), ShiftBinder.orderSeconds)]);
      // Chuỗi thật (không rỗng, có tên món).
      expect(m.said.single.$2, contains(_en.recipeName(m.session.current.order.recipe)));
    });

    test('quá hạn: khách được đặt thẳng vào quầy và phiên vẫn sang ordering', () {
      final m = make();
      m.binder.start();
      m.stage.arriveTimeout = const Duration(seconds: 1);
      run(m.stage, m.world, 1.2);
      expect(m.session.phase, ShiftPhase.ordering);
    });

    test('báo khách tới sai lúc (sai chỉ số / sai pha) bị bỏ qua', () {
      final m = make();
      m.binder.start();
      m.stage.onArrived!(2);
      expect(m.session.phase, ShiftPhase.arriving);
      expect(m.said, isEmpty);
      arrive(m.session, m.stage, m.world);
      m.session.startBaking();
      m.stage.onArrived!(0);
      expect(m.session.phase, ShiftPhase.baking);
      expect(m.said.length, 1);
    });

    test('chưa có chuỗi giao diện: không bong bóng, ca vẫn chạy', () {
      final m = make(noL10n: true);
      m.binder.start();
      arrive(m.session, m.stage, m.world);
      m.session.startBaking();
      m.session.completeBake(_outcomeFor(m.session.current.order, 1));
      expect(m.stage.currentActor!.performing, ChibiAction.pout);
      expect(m.said, isEmpty);
    });
  });

  group('pha của phiên → sân khấu', () {
    test('trọn một ca: phản ứng theo sao + lời khen / chê, "Khách tiếp" tiễn khách, hết khách thì kết thúc', () {
      final m = make(level: 4, seed: 3);
      final total = m.session.total;
      expect(total, greaterThanOrEqualTo(4));
      final startActors = m.world.director.actors.length;
      m.binder.start();
      final seen = <String>{};
      for (var i = 0; i < total; i++) {
        arrive(m.session, m.stage, m.world);
        expect(m.stage.index, i);
        expect(m.session.index, i);
        final id = m.stage.currentId!;
        expect(seen.add(id), isTrue, reason: 'id không trùng trong ca');
        expect(m.said.last, (id, orderLine(m.session, _en), ShiftBinder.orderSeconds));
        m.session.startBaking();
        expect(m.stage.currentActor!.performing, isNull, reason: 'bắt đầu làm bánh: sân khấu không đổi');
        final stars = [5, 1, 3, 4, 2, 5][i];
        final served = m.session.completeBake(_outcomeFor(m.session.current.order, stars))!;
        expect(served.result.stars, stars);
        final actor = m.stage.currentActor!;
        expect(actor.performing, switch (stars) {
          >= 4 => ChibiAction.happy,
          3 => ChibiAction.talk,
          _ => ChibiAction.pout,
        });
        final fb = served.result.complaint ?? served.result.praise;
        expect(m.said.last, (id, _en.feedbackText(fb), ShiftBinder.feedbackSeconds));
        if (stars <= 2) expect(served.result.complaint, isNotNull, reason: 'đơn ≤2★ có lời chê theo trạm');
        run(m.stage, m.world, 1);
        m.session.next();
        if (i < total - 1) {
          expect(m.session.phase, ShiftPhase.arriving);
          expect(m.stage.index, i + 1, reason: '"Khách tiếp" → dismiss');
          expect(m.stage.active, isTrue);
          expect(actor.performing, isNull, reason: 'khách cũ thôi diễn, đi ra');
        }
      }
      expect(m.session.phase, ShiftPhase.finished);
      expect(m.stage.active, isFalse, reason: 'finished → end');
      // Khách đi ra hết rồi được gỡ; khách nền về vòng cũ.
      run(m.stage, m.world, 40, until: () => m.stage.isIdle);
      expect(m.stage.isIdle, isTrue);
      expect(m.world.director.actors.length, startActors);
      for (final id in ChibiCast.ambientGuestIds) {
        final a = m.world.director.actors.firstWhere((x) => x.id == id);
        expect(a.script.length, ChibiCast.loopFor(id).length, reason: id);
      }
      // stop sau khi hết ca: không lỗi, không làm gì thêm.
      m.binder.stop();
      expect(m.binder.running, isFalse);
    });

    test('khách VIP của đơn dùng vip_01 / vip_02, khách thường dùng regular_*', () {
      // Tìm seed có khách VIP ở cấp 10 (VIP 30 %).
      var seed = 1;
      while (!ShiftSession(game: game(level: 10), random: math.Random(seed))
          .orders
          .any((o) => o.customer.kind == CustomerKind.vip)) {
        seed++;
      }
      final m = make(level: 10, seed: seed);
      m.binder.start();
      var vips = 0;
      for (var i = 0; i < m.session.total; i++) {
        arrive(m.session, m.stage, m.world);
        final id = m.stage.currentId!;
        if (m.session.current.customer.kind == CustomerKind.vip && vips < shiftVipIds.length) {
          expect(shiftVipIds, contains(id), reason: 'khách $i VIP');
          vips++;
        } else {
          expect(id, startsWith('regular_'), reason: 'khách $i');
        }
        expect(ChibiCast.ambientGuestIds, isNot(contains(id)));
        m.session.startBaking();
        m.session.completeBake(_outcomeFor(m.session.current.order, 4));
        m.session.next();
      }
      expect(vips, greaterThan(0));
      expect(m.session.phase, ShiftPhase.finished);
    });

    test('làm lại: result → baking → result diễn lại phản ứng, không tiễn khách', () {
      final m = make();
      m.binder.start();
      arrive(m.session, m.stage, m.world);
      m.session.startBaking();
      m.session.completeBake(_outcomeFor(m.session.current.order, 1));
      final actor = m.stage.currentActor!;
      expect(actor.performing, ChibiAction.pout);
      final saidBefore = m.said.length;
      m.session.remake();
      expect(m.session.phase, ShiftPhase.baking);
      expect(m.stage.index, 0);
      expect(m.said.length, saidBefore);
      m.session.completeBake(_outcomeFor(m.session.current.order, 5));
      expect(m.stage.currentActor, same(actor));
      expect(actor.performing, ChibiAction.happy);
      expect(m.said.last.$2, _en.feedbackText(m.session.served!.result.praise));
      expect(m.said.length, saidBefore + 1);
    });

    test('đóng ca sớm (abort) → khách đi ra, khách nền về vòng cũ', () {
      final m = make();
      m.binder.start();
      arrive(m.session, m.stage, m.world);
      m.session.startBaking();
      m.session.abort();
      expect(m.session.phase, ShiftPhase.aborted);
      expect(m.stage.active, isFalse);
      run(m.stage, m.world, 40, until: () => m.stage.isIdle);
      expect(m.stage.isIdle, isTrue);
      expect(m.world.director.actors.any((a) => isShiftGuestId(a.id)), isFalse);
    });

    test('đổi trong cùng pha (thẻ "Mở mới!", x2) không đụng sân khấu', () {
      final m = make();
      m.binder.start();
      final actor = m.stage.currentActor;
      m.session.acknowledgeRecipeNews();
      expect(m.stage.index, 0);
      expect(m.stage.currentActor, same(actor));
    });
  });

  group('stop', () {
    test('giữa ca: thôi nghe phiên, khách đi ra; gọi lại không sao', () {
      final m = make();
      m.binder.start();
      arrive(m.session, m.stage, m.world);
      m.binder.stop();
      expect(m.binder.running, isFalse);
      expect(m.stage.active, isFalse);
      expect(m.stage.onArrived, isNull);
      // Phiên đổi pha sau đó: sân khấu không bị gọi.
      final said = m.said.length;
      m.session.startBaking();
      m.session.completeBake(_outcomeFor(m.session.current.order, 5));
      expect(m.said.length, said);
      m.binder.stop();
      // Sau stop không start lại được.
      m.binder.start();
      expect(m.binder.running, isFalse);
      expect(m.stage.active, isFalse);
    });

    test('stop trước start: không làm gì', () {
      final m = make();
      m.binder.stop();
      expect(m.stage.active, isFalse);
      expect(m.stage.index, -1);
    });
  });
}
