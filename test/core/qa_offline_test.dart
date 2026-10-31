import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';

import 'qa_helpers.dart';

/// QA việc 4: thu nhập khi vắng nhà (quản lý) — công thức, trần giờ, đổi giờ hệ thống tiến / lùi.

const _hour = Duration(hours: 1);
final _manager = qaUnlocks.staffById(StaffIds.manager)!;

/// Đã thuê quản lý (cấp [speed] / [skill]), thu nhập gần đây [recent], mốc hoạt động = giờ của [clock].
GameState _withManager(QaClock clock, {int speed = 1, int skill = 1, List<int> recent = const [6000]}) => qaState(
      clock: clock,
      json: {
        'shop': {
          'owned': [StaffIds.manager],
        },
        'staff': {
          StaffIds.manager: {'speed': speed, 'skill': skill},
        },
        'lastActive': clock.now.millisecondsSinceEpoch,
        'offline': {'recentCoins': recent},
      },
    );

void main() {
  group('công thức', () {
    test('mọi cặp cấp tốc độ × tay nghề (25 cặp): xu = round(tỉ lệ × TB 5 lượt gần nhất × min(giờ vắng, trần))', () {
      // 6 lượt → chỉ lấy 5 lượt cuối: TB (2000+4000+6000+8000+10000)/5 = 6000.
      const recent = [999999, 2000, 4000, 6000, 8000, 10000];
      for (var sp = 1; sp <= _manager.maxLevel; sp++) {
        for (var sk = 1; sk <= _manager.maxLevel; sk++) {
          final clock = QaClock();
          final s = _withManager(clock, speed: sp, skill: sk, recent: recent);
          final t0 = clock.now;
          clock.now = t0.add(const Duration(hours: 5, minutes: 30));
          s.refreshOffline(clock.now);
          final rate = _manager.value(StaffStat.speed, sp).toDouble();
          final cap = _manager.value(StaffStat.skill, sk).round();
          final countedMs = (const Duration(hours: 5, minutes: 30).inMilliseconds).clamp(0, cap * _hour.inMilliseconds);
          final want = (rate * 6000 * countedMs / _hour.inMilliseconds).round();
          final p = s.pendingOffline!;
          expect(p.coins, want, reason: 'tốc độ $sp, tay nghề $sk');
          expect(p.capHours, cap);
          expect(p.counted.inMilliseconds, countedMs);
        }
      }
    });

    test('biên: đúng 10 phút được tính, thiếu 1 ms không; đúng trần giờ chưa bị cắt, thêm 1 ms bị cắt', () {
      final c1 = QaClock();
      final a = _withManager(c1);
      a.refreshOffline(c1.now.add(const Duration(minutes: 10)).subtract(const Duration(milliseconds: 1)));
      expect(a.pendingOffline, isNull);

      final c2 = QaClock();
      final b = _withManager(c2);
      b.refreshOffline(c2.now.add(const Duration(minutes: 10)));
      expect(b.pendingOffline!.coins, (0.20 * 6000 * 10 / 60).round());

      final c3 = QaClock();
      final c = _withManager(c3);
      c.refreshOffline(c3.now.add(const Duration(hours: 4)));
      expect(c.pendingOffline!.capped, isFalse);
      expect(c.pendingOffline!.coins, 4800);

      final c4 = QaClock();
      final d = _withManager(c4);
      d.refreshOffline(c4.now.add(const Duration(hours: 4, milliseconds: 1)));
      expect(d.pendingOffline!.capped, isTrue);
      expect(d.pendingOffline!.coins, 4800);
    });

    test('nhận một lần (x1 hoặc x2), lần sau 0; xu lưu lại đúng', () {
      final clock = QaClock();
      final s = _withManager(clock);
      final c0 = s.coins;
      s.refreshOffline(clock.now.add(const Duration(hours: 2)));
      expect(s.claimOffline(doubled: true), 4800);
      expect(s.claimOffline(doubled: true), 0);
      expect(s.claimOffline(), 0);
      expect(s.coins, c0 + 4800);
      final again = GameState.fromJson(s.toJson());
      expect(again.coins, c0 + 4800);
      expect(again.toJson()['offline'], containsPair('awayMs', 0));
    });
  });

  group('đổi giờ hệ thống', () {
    test('giờ tiến xa (1000 ngày): chỉ tính tới trần giờ của quản lý; thời gian vắng lưu kẹp 30 ngày', () {
      final clock = QaClock();
      final s = _withManager(clock);
      s.refreshOffline(clock.now.add(const Duration(days: 1000)));
      final p = s.pendingOffline!;
      expect(p.counted, const Duration(hours: 4));
      expect(p.coins, 4800);
      expect(p.away, GameState.maxStoredAway);
    });

    test('giờ lùi (thời gian âm): không cộng xu, không có khoản chờ, xu không đổi', () {
      final clock = QaClock();
      final s = _withManager(clock);
      final c0 = s.coins;
      s.refreshOffline(clock.now.subtract(const Duration(days: 3)));
      expect(s.pendingOffline, isNull);
      expect(s.claimOffline(doubled: true), 0);
      expect(s.coins, c0);
    });

    test('bản lưu có mốc hoạt động ở tương lai (máy từng chỉnh giờ tiến): mở app không cộng, GIỮ mốc (QA-01)', () {
      final clock = QaClock();
      final future = clock.now.add(const Duration(days: 2));
      final s = qaState(clock: clock, json: {
        'shop': {
          'owned': [StaffIds.manager],
        },
        'lastActive': future.millisecondsSinceEpoch,
        'offline': {
          'recentCoins': [6000],
        },
      });
      s.refreshOffline(clock.now);
      expect(s.pendingOffline, isNull);
      expect(s.toJson()['lastActive'], future.millisecondsSinceEpoch, reason: 'mốc không lùi');
      // Giờ thật chưa vượt mốc → vắng = 0.
      s.refreshOffline(future.subtract(const Duration(minutes: 1)));
      expect(s.pendingOffline, isNull);
      // Giờ thật vượt mốc → tính từ mốc.
      s.refreshOffline(future.add(const Duration(hours: 1)));
      expect(s.pendingOffline?.away, _hour);
    });

    test('QA-01: lùi giờ rồi chỉnh lại ngay → chỉ tính thời gian vắng thật (1 phút < 10 phút → không tính)', () {
      final clock = QaClock();
      final real = clock.now;
      final s = _withManager(clock);
      // Lùi giờ 6 tiếng, mở app (mốc giữ nguyên), chỉnh lại giờ thật sau 1 phút, mở app.
      s.refreshOffline(real.subtract(const Duration(hours: 6)));
      expect(s.pendingOffline, isNull);
      expect(s.toJson()['lastActive'], real.millisecondsSinceEpoch);
      s.refreshOffline(real.add(const Duration(minutes: 1)));
      expect(s.pendingOffline, isNull);
      // Vắng thật 2 giờ sau đó vẫn được tính đủ.
      s.refreshOffline(real.add(const Duration(hours: 2, minutes: 1)));
      expect(s.pendingOffline?.away, const Duration(hours: 2));
      expect(s.pendingOffline?.coins, 2400);
    });

    test('QA-01: lặp chu kỳ tiến giờ → nhận → lùi giờ → tiến giờ: chỉ nhận một lần trần', () {
      final clock = QaClock();
      final real = clock.now;
      final s = _withManager(clock);
      final c0 = s.coins;
      for (var i = 0; i < 5; i++) {
        s.refreshOffline(real.add(const Duration(hours: 8)));
        s.claimOffline(doubled: true);
        s.markActive(); // vào nền
        s.refreshOffline(real); // chỉnh giờ về lại
        s.markActive();
      }
      // Một lần tiến giờ duy nhất vẫn ăn được một lần trần (không có giờ máy chủ) — chấp nhận.
      expect(s.coins - c0, 9600, reason: 'chu kỳ 2..5 không nhận thêm');
      expect(s.toJson()['lastActive'], real.add(const Duration(hours: 8)).millisecondsSinceEpoch);

      // Giờ thật tiếp tục trôi: chỉ tính phần vượt mốc.
      s.refreshOffline(real.add(const Duration(hours: 9)));
      expect(s.pendingOffline?.away, _hour);
    });

    test('QA-01: đồng hồ lùi → nhịp foreground / chơi xong / markActive không kéo mốc lùi', () {
      final clock = QaClock();
      final real = clock.now;
      final s = _withManager(clock);
      clock.now = real.subtract(const Duration(hours: 6));
      s.markActive();
      s.applyLevelResult(qaResult(1, coins: 100));
      expect(s.toJson()['lastActive'], real.millisecondsSinceEpoch);
      clock.now = real.add(const Duration(hours: 1));
      s.refreshOffline(clock.now);
      expect(s.pendingOffline?.away, _hour);
    });
  });

  group('bản lưu phần offline', () {
    test('awayMs khổng lồ → kẹp 30 ngày; âm / sai kiểu → 0; recentCoins hỏng từng phần tử bị bỏ', () {
      final huge = qaState(json: {
        'offline': {'awayMs': 1e18, 'recentCoins': [100, 'x', -5, 300]},
      });
      final off = huge.toJson()['offline'] as Map<String, dynamic>;
      expect(off['awayMs'], GameState.maxStoredAway.inMilliseconds);
      expect(off['recentCoins'], [100, 300]);
      for (final bad in [-1, 'abc', true, <int>[]]) {
        final s = qaState(json: {
          'offline': {'awayMs': bad},
        });
        expect((s.toJson()['offline'] as Map)['awayMs'], 0, reason: '$bad');
      }
    });
  });
}
