import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/quarrel_director.dart';

const _dt = 0.25;

/// Chạy [seconds] giây, gom tín hiệu kèm thời điểm. [dialogue] cho biết có hội thoại thường tại thời điểm t không.
List<(double, QuarrelSignal)> _run(QuarrelDirector d, double seconds, {bool Function(double t)? dialogue, double from = 0}) {
  final out = <(double, QuarrelSignal)>[];
  var t = 0.0;
  while (t < seconds - 1e-9) {
    t += _dt;
    for (final s in d.update(_dt, dialogueOpen: dialogue?.call(from + t) ?? false)) {
      out.add((from + t, s));
    }
  }
  return out;
}

QuarrelDirector _dir({int seed = 1, bool enabled = true}) => QuarrelDirector(rng: math.Random(seed), enabled: enabled);

/// Chạy tới khi sự kiện bắt đầu; trả thời điểm bắt đầu.
double _untilStart(QuarrelDirector d, {double limit = 400}) {
  var t = 0.0;
  while (t < limit) {
    t += _dt;
    final sig = d.update(_dt);
    if (sig.any((s) => s.kind == QuarrelSignalKind.gatherStarted)) return t;
  }
  fail('sự kiện không bắt đầu trong $limit s');
}

void main() {
  group('lịch', () {
    test('sự kiện đầu sau 75 ± 15 s (mọi hạt giống)', () {
      for (var seed = 0; seed < 60; seed++) {
        final d = _dir(seed: seed);
        expect(d.secondsUntilNext, greaterThanOrEqualTo(60));
        expect(d.secondsUntilNext, lessThanOrEqualTo(90));
        final t = _untilStart(d);
        expect(t, greaterThanOrEqualTo(60));
        expect(t, lessThanOrEqualTo(90 + _dt));
      }
    });

    test('các sự kiện sau cách 150–210 s tính từ lúc sự kiện trước kết thúc', () {
      for (var seed = 0; seed < 30; seed++) {
        final d = _dir(seed: seed);
        _untilStart(d);
        _run(d, 6); // tới arguing
        expect(d.phase, QuarrelPhase.arguing);
        expect(d.beginIntervention(), isTrue);
        d.resolve();
        expect(d.phase, QuarrelPhase.aftermath);
        d.endAftermath();
        expect(d.phase, QuarrelPhase.waiting);
        expect(d.secondsUntilNext, greaterThanOrEqualTo(150));
        expect(d.secondsUntilNext, lessThanOrEqualTo(210));
        final t = _untilStart(d, limit: 260);
        expect(t, greaterThanOrEqualTo(150));
        expect(t, lessThanOrEqualTo(210 + _dt));
      }
    });

    test('xoay vòng lastCake → first → tart → lastCake, nextEventId báo trước', () {
      final d = _dir();
      expect(d.nextEventId, 'lastCake');
      final seen = <String>[];
      for (var i = 0; i < 4; i++) {
        expect(d.nextEventId, QuarrelDirector.defaultEventIds[i % 3]);
        _untilStart(d, limit: 300);
        seen.add(d.currentEventId);
        d.abort(); // abort không đổi lịch (đồng hồ chờ đang 0) nên sự kiện kế bắt đầu ở lần update sau
      }
      expect(seen, ['lastCake', 'first', 'tart', 'lastCake']);
    });

    test('tối đa 1 sự kiện cùng lúc', () {
      final d = _dir();
      _untilStart(d);
      expect(d.active, isTrue);
      // Dù chạy rất lâu, chỉ có đúng một gatherStarted chừng nào chưa kết thúc.
      final sigs = _run(d, 20);
      expect(sigs.where((s) => s.$2.kind == QuarrelSignalKind.gatherStarted), isEmpty);
    });
  });

  group('không bắt đầu khi đang có hội thoại', () {
    test('chờ tới khi hội thoại đóng rồi mới bắt đầu ngay', () {
      final d = _dir();
      final sigs = _run(d, 200, dialogue: (t) => t < 120);
      final starts = sigs.where((s) => s.$2.kind == QuarrelSignalKind.gatherStarted).toList();
      expect(starts.length, 1);
      expect(starts.single.$1, greaterThan(120 - 1e-9));
      expect(starts.single.$1, lessThanOrEqualTo(120 + _dt + 1e-9));
    });

    test('hội thoại ngắt quãng: không bắt đầu trong lúc mở', () {
      final d = _dir(seed: 3);
      var t = 0.0;
      while (!d.active && t < 400) {
        t += _dt;
        final open = (t % 10) < 5;
        final sig = d.update(_dt, dialogueOpen: open);
        if (sig.any((s) => s.kind == QuarrelSignalKind.gatherStarted)) {
          expect(open, isFalse, reason: 'bắt đầu lúc t=$t khi đang có hội thoại');
        }
      }
      expect(d.active, isTrue);
    });
  });

  group('máy trạng thái', () {
    test('kéo tới 6 s rồi cãi nhau; banner phát một lần', () {
      final d = _dir();
      _untilStart(d);
      expect(d.phase, QuarrelPhase.gathering);
      expect(d.canIntervene, isFalse);
      expect(_run(d, 5.5), isEmpty);
      final sigs = _run(d, 1);
      expect(sigs.map((s) => s.$2.kind), [QuarrelSignalKind.arguingStarted]);
      expect(sigs.single.$2.eventId, 'lastCake');
      expect(d.phase, QuarrelPhase.arguing);
      expect(d.canIntervene, isTrue);
    });

    test('hết giờ 45 s sau khi bắt đầu cãi mà chưa can: timedOut, sang aftermath', () {
      final d = _dir();
      _untilStart(d);
      _run(d, 6);
      expect(d.timeoutRemaining, closeTo(45, 1e-6));
      expect(_run(d, 44.5), isEmpty);
      expect(d.phase, QuarrelPhase.arguing);
      final sigs = _run(d, 1);
      expect(sigs.map((s) => s.$2.kind), [QuarrelSignalKind.timedOut]);
      expect(d.phase, QuarrelPhase.aftermath);
      expect(d.canIntervene, isFalse);
      d.endAftermath();
      expect(d.active, isFalse);
    });

    test('đang có hội thoại thường (Mai nói chuyện với khách) đồng hồ hết giờ vẫn chạy', () {
      final d = _dir();
      _untilStart(d);
      _run(d, 6);
      final sigs = _run(d, 50, dialogue: (_) => true);
      expect(sigs.any((s) => s.$2.kind == QuarrelSignalKind.timedOut), isTrue);
    });

    test('đang can ngăn: đồng hồ tạm dừng; huỷ thì chạy tiếp', () {
      final d = _dir();
      _untilStart(d);
      _run(d, 6 + 30);
      expect(d.timeoutRemaining, closeTo(15, 1e-6));
      expect(d.beginIntervention(), isTrue);
      expect(d.phase, QuarrelPhase.intervening);
      expect(d.canIntervene, isFalse);
      expect(d.beginIntervention(), isFalse);
      expect(_run(d, 500, dialogue: (_) => true), isEmpty);
      expect(d.phase, QuarrelPhase.intervening);
      d.cancelIntervention();
      expect(d.phase, QuarrelPhase.arguing);
      expect(d.timeoutRemaining, closeTo(15, 1e-6));
      expect(_run(d, 15.5).map((s) => s.$2.kind), [QuarrelSignalKind.timedOut]);
    });

    test('resolve: sang aftermath; chỉ kết thúc khi cảnh báo xong (hoặc quá 90 s)', () {
      final d = _dir();
      _untilStart(d);
      _run(d, 6);
      d.beginIntervention();
      d.resolve();
      expect(d.phase, QuarrelPhase.aftermath);
      expect(_run(d, 89), isEmpty);
      expect(d.active, isTrue);
      final sigs = _run(d, 1);
      expect(sigs.map((s) => s.$2.kind), [QuarrelSignalKind.ended]);
      expect(d.active, isFalse);
      expect(d.secondsUntilNext, greaterThanOrEqualTo(150));
      expect(d.secondsUntilNext, lessThanOrEqualTo(210));
    });

    test('resolve / endAftermath / cancelIntervention sai pha: bỏ qua', () {
      final d = _dir();
      d.resolve();
      d.endAftermath();
      d.cancelIntervention();
      expect(d.phase, QuarrelPhase.waiting);
      expect(d.beginIntervention(), isFalse);
    });

    test('"Mai ra xem": chỉ khi đang cãi; tới ≤ 1,6 m thì báo đúng một lần; đẩy joystick thì huỷ', () {
      final d = _dir();
      expect(d.requestSendMai(), isFalse);
      _untilStart(d);
      expect(d.requestSendMai(), isFalse); // còn đang kéo tới
      _run(d, 6);
      expect(d.requestSendMai(), isTrue);
      expect(d.sendMaiRequested, isTrue);
      expect(d.maiArrived(3.0), isFalse);
      expect(d.maiArrived(1.7), isFalse);
      expect(d.maiArrived(1.6), isTrue);
      expect(d.maiArrived(1.0), isFalse); // chỉ một lần
      d.requestSendMai();
      d.cancelSendMai();
      expect(d.maiArrived(0.5), isFalse);
    });
  });

  group('ép chạy / tắt', () {
    test('forceStart theo id, kể cả khi lịch tắt; xoay vòng tiếp theo sau id vừa ép', () {
      final d = _dir(enabled: false);
      expect(d.forceStart('nope'), isFalse);
      expect(d.forceStart('tart'), isTrue);
      expect(d.phase, QuarrelPhase.gathering);
      expect(d.currentEventId, 'tart');
      expect(d.nextEventId, 'lastCake');
      expect(d.forceStart('first'), isFalse); // đang có sự kiện
      _run(d, 6);
      expect(d.phase, QuarrelPhase.arguing);
    });

    test('tắt: không tự bắt đầu theo lịch', () {
      final d = _dir(enabled: false);
      expect(_run(d, 1000), isEmpty);
      expect(d.active, isFalse);
      d.enabled = true;
      expect(_untilStart(d), lessThanOrEqualTo(90 + _dt));
    });

    test('abort huỷ sự kiện đang chạy', () {
      final d = _dir();
      d.forceStart('first');
      d.abort();
      expect(d.active, isFalse);
      expect(d.currentEventId, '');
    });
  });
}
