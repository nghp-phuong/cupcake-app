import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_stage.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Sân khấu ca bán (G1): khách vào tiệm, tới quầy, phản ứng, đi ra; khách nền ngồi yên. Thế giới giả (không thermion).

const _dt = 1 / 60;
const _owned = {Shop3dRequires.cafeTables};

class _World implements Shop3dPilotWorld {
  _World(List<ChibiActor> actors, {this.modelsReady = true}) : director = ChibiDirector(actors);

  @override
  final ChibiDirector director;

  /// false: `readyModel` trả null (model chưa dựng xong).
  bool modelsReady;
  final prepared = <String>[];
  final added = <String>[];
  final removed = <String>[];

  @override
  Set<String> get owned => _owned;

  final _models = <String, ChibiModel>{};

  @override
  ChibiModel? readyModel(String id) => modelsReady ? _models[id] : null;

  @override
  void prepareModels(List<String> ids) {
    prepared.addAll(ids);
    for (final id in ids) {
      if (isShiftGuestId(id)) _models.putIfAbsent(id, () => ChibiSizes.fit(buildShiftGuest(id)));
    }
  }

  @override
  void addActor(ChibiActor a) {
    added.add(a.id);
    director.actors.add(a);
  }

  @override
  void removeActor(ChibiActor a) {
    removed.add(a.id);
    director.actors.remove(a);
  }
}

void _run(ShiftStage s, _World w, double seconds, {bool Function()? until}) {
  for (var t = 0.0; t < seconds; t += _dt) {
    s.update(_dt);
    w.director.update(_dt, _owned);
    if (until != null && until()) return;
  }
}

double _distTo(ChibiActor a, Shop3dSpot p) => math.sqrt(math.pow(a.pose.x - p.x, 2) + math.pow(a.pose.z - p.z, 2));

void main() {
  final models = {for (final id in ChibiCharacters.allIds) id: ChibiCharacters.build(id)};

  (ShiftStage, _World, List<int>) make({Duration? timeout, bool withCast = true, bool modelsReady = true}) {
    final w = _World(withCast ? ChibiCast.build(models: models) : [], modelsReady: modelsReady);
    final arrived = <int>[];
    final s = ShiftStage(w, arriveTimeout: timeout ?? ShiftStage.defaultArriveTimeout, onArrived: arrived.add);
    return (s, w, arrived);
  }

  ChibiActor? find(_World w, String id) {
    for (final a in w.director.actors) {
      if (a.id == id) return a;
    }
    return null;
  }

  final cast = castFor(4, random: math.Random(1));

  group('begin', () {
    test('khách 1 đi từ cửa tới counterSpots[2] (kịp trong hạn 12 s); khách 2 đứng chờ ở queue[0]', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      expect(s.active, isTrue);
      expect(s.total, 4);
      expect(s.index, 0);
      expect(s.currentId, cast[0]);
      expect(s.arrived, isFalse);
      final a0 = s.currentActor!;
      // Xuất hiện ngoài cửa.
      expect(a0.pose.x, Shop3dLayout.doorOutside.x);
      expect(a0.pose.z, Shop3dLayout.doorOutside.z);
      expect(w.director.actors, contains(a0));
      var t = 0.0;
      _run(s, w, 20, until: () {
        t += _dt;
        return arrived.isNotEmpty;
      });
      expect(arrived, [0]);
      expect(t, lessThan(11.5), reason: 'tới quầy bằng chân, không phải do quá hạn');
      expect(s.arrived, isTrue);
      expect(_distTo(a0, ShiftStage.counter), lessThan(0.07));
      // Khách 2 đứng ở queue[0] (sau khi đi hết đường vào).
      _run(s, w, 12);
      final a1 = s.waitingActor!;
      expect(a1.id, cast[1]);
      expect(_distTo(a1, Shop3dLayout.queue[0]), lessThan(0.07));
      expect(a1.isBusyMoving, isFalse);
      // Chỉ báo một lần, ca chưa kéo khách thứ ba ra.
      expect(arrived, [0]);
      expect(w.added, [cast[0], cast[1]]);
      // Model dựng sẵn cho khách hiện tại và hai khách kế.
      expect(w.prepared.toSet(), containsAll([cast[0], cast[1], cast[2]]));
    });

    test('model chưa dựng xong: chưa ai xuất hiện, xong thì khách xuất hiện và đi tiếp', () {
      final (s, w, arrived) = make(modelsReady: false);
      s.begin(cast);
      _run(s, w, 2);
      expect(s.waitingForModels, isTrue);
      expect(s.currentActor, isNull);
      expect(w.added, isEmpty);
      w.modelsReady = true;
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      expect(s.waitingForModels, isFalse);
      expect(arrived, [0]);
    });

    test('begin lần nữa khi đang chạy: ca cũ bị gỡ ngay', () {
      final (s, w, _) = make();
      s.begin(cast);
      final old = s.currentActor!;
      s.begin(castFor(3, random: math.Random(5)));
      expect(w.director.actors, isNot(contains(old)));
      expect(s.total, 3);
    });
  });

  group('react / dismiss', () {
    test('react: ≥4 vui, 3 nói chuyện, ≤2 phụng phịu', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      final a = s.currentActor!;
      s.react(5);
      expect(a.performing, ChibiAction.happy);
      s.react(4);
      expect(a.performing, ChibiAction.happy);
      s.react(3);
      expect(a.performing, ChibiAction.talk);
      s.react(2);
      expect(a.performing, ChibiAction.pout);
      s.react(1);
      expect(a.performing, ChibiAction.pout);
      _run(s, w, ShiftStage.poutSeconds + 0.5);
      expect(a.performing, isNull);
      // Vẫn đứng ở quầy.
      expect(_distTo(a, ShiftStage.counter), lessThan(0.07));
    });

    test('dismiss: khách ra cửa và được gỡ; khách sau tiến lên quầy; khách kế nữa vào hàng', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      _run(s, w, 6); // khách 2 vào hàng
      final first = s.currentActor!;
      final second = s.waitingActor!;
      s.react(4);
      s.dismiss();
      expect(s.index, 1);
      expect(s.currentActor, same(second));
      expect(s.arrived, isFalse);
      // Khách cũ đi ra: còn trong cảnh một lúc, rồi bị gỡ khi xong vòng.
      expect(w.director.actors, contains(first));
      expect(first.performing, isNull);
      _run(s, w, 25, until: () => arrived.length == 2 && !w.director.actors.contains(first));
      expect(w.director.actors, isNot(contains(first)));
      expect(w.removed, contains(first.id));
      expect(arrived, [0, 1]);
      expect(_distTo(second, ShiftStage.counter), lessThan(0.07));
      // Khách 3 xuất hiện và vào hàng.
      final third = s.waitingActor!;
      expect(third.id, cast[2]);
      _run(s, w, 20);
      expect(_distTo(third, Shop3dLayout.queue[0]), lessThan(0.07));
      expect(w.added, [cast[0], cast[1], cast[2]]);
    });

    test('tiễn đủ 4 khách thì hết khách; end() dọn sạch khách ra khỏi cảnh', () {
      final (s, w, arrived) = make();
      final startActors = w.director.actors.length;
      s.begin(cast);
      for (var i = 0; i < 4; i++) {
        _run(s, w, 30, until: () => arrived.length == i + 1);
        expect(arrived.length, i + 1, reason: 'khách $i tới quầy');
        expect(s.index, i);
        s.react(3 + i % 2);
        _run(s, w, 1);
        s.dismiss();
      }
      expect(s.index, 4);
      expect(s.currentActor, isNull);
      s.dismiss(); // không còn ai: bỏ qua
      expect(s.index, 4);
      s.end();
      expect(s.active, isFalse);
      expect(s.isIdle, isFalse);
      _run(s, w, 30, until: () => s.isIdle);
      expect(s.isIdle, isTrue);
      expect(w.director.actors.length, startActors);
      expect(w.director.actors.any((a) => cast.contains(a.id)), isFalse);
    });

    test('khách đi ra không giẫm lên khách đứng chờ ở queue[0] (cách ≥ 0,3 m)', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      _run(s, w, 6);
      final leaving = s.currentActor!;
      final waiting = s.waitingActor!;
      s.dismiss();
      var minD = double.infinity;
      _run(s, w, 6, until: () {
        final d = math.sqrt(math.pow(leaving.pose.x - waiting.pose.x, 2) + math.pow(leaving.pose.z - waiting.pose.z, 2));
        if (d < minD) minD = d;
        return false;
      });
      expect(minD, greaterThan(0.3));
    });

    test('end() giữa ca: khách ở quầy và ở hàng đều đi ra rồi được gỡ', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      _run(s, w, 6);
      s.end();
      expect(s.index, -1);
      _run(s, w, 30, until: () => s.isIdle);
      expect(s.isIdle, isTrue);
      expect(w.director.actors.any((a) => cast.contains(a.id)), isFalse);
    });

    test('clear(): gỡ ngay, không diễn đi ra', () {
      final (s, w, arrived) = make();
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      s.dismiss();
      s.clear();
      expect(s.isIdle, isTrue);
      expect(w.director.actors.any((a) => cast.contains(a.id)), isFalse);
    });
  });

  group('quá hạn', () {
    test('khách chưa tới quầy sau arriveTimeout: đặt thẳng vào quầy và báo tới', () {
      final (s, w, arrived) = make(timeout: const Duration(seconds: 2));
      s.begin(cast);
      final a = s.currentActor!;
      _run(s, w, 1.9);
      expect(arrived, isEmpty);
      expect(_distTo(a, ShiftStage.counter), greaterThan(1));
      _run(s, w, 0.2);
      expect(arrived, [0]);
      expect(s.arrived, isTrue);
      expect(_distTo(a, ShiftStage.counter), lessThan(0.07));
      // Hạn mặc định đúng 12 s (ShiftEconomy.arriveTimeout).
      expect(ShiftStage.defaultArriveTimeout, const Duration(seconds: 12));
      // Báo đúng một lần.
      _run(s, w, 5);
      expect(arrived, [0]);
    });

    test('khách kế bị kẹt: tính hạn từ lúc được gọi lên quầy, quá hạn thì đặt thẳng vào quầy', () {
      final (s, w, arrived) = make(timeout: const Duration(seconds: 3));
      s.begin(cast);
      _run(s, w, 20, until: () => arrived.isNotEmpty);
      _run(s, w, 6);
      final second = s.waitingActor!;
      s.dismiss();
      // Ép khách kẹt: đặt xa quầy, ngay trong cửa.
      second.pose
        ..x = Shop3dLayout.entrance.x
        ..z = Shop3dLayout.entrance.z;
      _run(s, w, 2.5);
      expect(arrived, [0]);
      _run(s, w, 1);
      expect(arrived, [0, 1]);
      expect(_distTo(second, ShiftStage.counter), lessThan(0.07));
    });
  });

  group('khách nền', () {
    test('ngồi yên suốt ca; hết ca quay lại vòng cũ', () {
      final (s, w, _) = make();
      final ambient = [for (final id in ChibiCast.ambientGuestIds) find(w, id)!];
      // Chạy vòng thường một lúc cho lệch pha như thật (Linh / bà Rosa đang đi).
      _run(s, w, 7);
      s.begin(cast);
      _run(s, w, 90);
      for (final a in ambient) {
        expect(a.isSeated, isTrue, reason: '${a.id} ngồi sau 90 s');
        expect(a.pose.x, closeTo(ChibiCast.seatOf(a.id).x, 0.01), reason: a.id);
      }
      // Suốt ca (5 phút): không ai đứng dậy.
      for (var t = 0; t < 300; t++) {
        _run(s, w, 1);
        for (final a in ambient) {
          expect(a.isSeated, isTrue, reason: '${a.id} @${t}s');
        }
      }
      s.end();
      for (final a in ambient) {
        expect(a.paused, isFalse, reason: a.id);
        expect(a.script.length, ChibiCast.loopFor(a.id).length, reason: a.id);
        expect(a.script.any((x) => x.action == ChibiAction.walk), isTrue);
      }
      // Quay lại vòng cũ: lần lượt đứng dậy, đi ra, rồi vào lại — trong 60 s phải có người rời ghế.
      _run(s, w, 60);
      expect(ambient.any((a) => !a.isSeated), isTrue);
      for (final a in ambient) {
        expect(a.pose.y, lessThan(0.6), reason: a.id);
      }
    });

    test('khách nền đang đi / đang nhảy ghế lúc mở ca cũng vào ghế và ngồi yên', () {
      for (final warm in [0.0, 3.0, 8.0, 14.0, 21.0, 33.0]) {
        final (s, w, _) = make();
        _run(s, w, warm);
        s.begin(cast);
        _run(s, w, 120);
        for (final id in ChibiCast.ambientGuestIds) {
          final a = find(w, id)!;
          expect(a.isSeated, isTrue, reason: '$id warm=$warm');
        }
        s.clear();
      }
    });

    test('id khách có đơn không trùng id nào trong cảnh', () {
      final (s, w, _) = make();
      s.begin(cast);
      final ids = w.director.actors.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
