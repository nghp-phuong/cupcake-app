import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';

import 'progression_sim.dart';

/// Bảng cân bằng chương 1–2 (50 seed mỗi level) với 3 bot, mỗi level chơi với **bộ đồ kỳ vọng** lúc tới level đó
/// (`expectedGear`: mở rộng + nhân viên (cấp 1) + thiết bị mở từ ≥ 2 level trước đã mua — khớp tiến trình bot ở
/// `progression_sim_test`; GĐ4: mốc 1★ L12–L20 nâng lên vì thu ngân / thợ bánh tự làm):
/// - 0.75: người chơi khá; - người mới (chính xác 0.5, phản ứng 1.2 s); - 0.3: người chơi yếu.
/// Mục tiêu GĐ3 (giữ độ khó ~GĐ2 dù đã mua đồ): 0.75 thắng 85–100%; người mới 25–55% từ L5 (chơi lại thì qua, không có
/// tường 0%); chương 2 không dễ hơn chương 1. Mốc 1★ đặt theo người mới, mốc 2–3★ theo người chơi khá.
/// GĐ7 (docs/v2/phase7-balance.md): mốc 1★ L11–L20 cân lại theo người chơi `average` của `tool/simulate.dart` (thắng lần
/// đầu ≈ 71%, trước 57%) → khung người mới ở chương 2 nới thành 25–65%.
/// Chỉnh `assets/config/levels.json` (mốc sao, nhịp khách, ô tủ gốc) khi bảng lệch mục tiêu.
void main() {
  final config = simLevels;
  final ids = [for (final l in config.levels) l.id];
  final gear = {for (final id in ids) id: expectedGear(id)};

  Map<int, LevelBotStats> run(String name, BotSkill skill) {
    final out = <int, LevelBotStats>{};
    final buf = StringBuffer(
      '\n$name (50 seed, bộ đồ kỳ vọng)\n'
      'level | mục tiêu                 | thắng | sao TB | xu TB | khách phục vụ | bỏ đi | đơn đặc biệt | tiệm\n',
    );
    for (final level in config.levels) {
      final g = gear[level.id]!;
      final s = LevelBotStats.simulate(
        level,
        config.defaults,
        skill: skill.accuracy,
        botSkill: skill,
        setup: g.setup,
        modifiers: g.modifiers,
      );
      out[level.id] = s;
      final setup = g.setup;
      buf.writeln(
        'L${level.id.toString().padRight(4)} | '
        '${'${level.goal.type.name} ${level.goal.stars}'.padRight(24)} | '
        '${(s.winRate * 100).toStringAsFixed(0).padLeft(4)}% | '
        '${s.avgStars.toStringAsFixed(2).padLeft(6)} | '
        '${s.avgCoins.toStringAsFixed(0).padLeft(5)} | '
        '${s.avgServed.toStringAsFixed(1).padLeft(13)} | '
        '${s.avgLost.toStringAsFixed(1).padLeft(5)} | '
        '${s.avgSpecials.toStringAsFixed(2).padLeft(11)} | '
        'tủ ${setup.caseSlotsFor(level)}×${setup.slotCapacity}, ${setup.ovens} lò ${setup.ovenSec}s, '
        'mẻ ${setup.batchSize}${setup.owned.isEmpty ? '' : ', ${(setup.owned.toList()..sort()).join('+')}'}',
      );
    }
    // ignore: avoid_print
    print(buf);
    return out;
  }

  final good = run('Bot kỹ năng 0.75', BotSkill.of(0.75));
  final newcomer = run('Bot người mới (chính xác 0.5, phản ứng 1.2 s)', BotSkill.newcomer);
  final weak = run('Bot kỹ năng 0.3', BotSkill.of(0.3));

  test('mọi level đều được mô phỏng', () => expect(ids, [for (var i = 1; i <= 20; i++) i]));

  double avgWin(Map<int, LevelBotStats> m, Iterable<int> ids) =>
      ids.map((id) => m[id]!.winRate).reduce((a, b) => a + b) / ids.length;
  final ch1Hard = [for (var id = 5; id <= 10; id++) id];
  final ch2 = [for (var id = 11; id <= 20; id++) id];

  test('bộ đồ kỳ vọng tăng dần theo level (ô tủ, lò, mẻ)', () {
    expect(gear[1]!.setup.caseSlotsBonus, 0);
    expect(gear[7]!.setup.owns('case_stand'), isTrue);
    expect(gear[14]!.setup.ovens, 2);
    expect(gear[20]!.setup.owns('cafe_tables'), isTrue);
    for (var id = 2; id <= 20; id++) {
      final a = gear[id - 1]!.setup, b = gear[id]!.setup;
      expect(
        b.batchSize >= a.batchSize && b.slotCapacity >= a.slotCapacity && b.ovenSec <= a.ovenSec,
        isTrue,
        reason: 'L$id',
      );
    }
  });

  test('bot 0.75: L1–L2 ≥ 95%, L3–L10 thắng 85–100%, sao TB L3–L10 1.8–2.5', () {
    for (var id = 1; id <= 2; id++) {
      expect(good[id]!.winRate, greaterThanOrEqualTo(0.95), reason: 'L$id');
    }
    for (var id = 3; id <= 10; id++) {
      expect(good[id]!.winRate, inInclusiveRange(0.85, 1.0), reason: 'L$id');
      expect(good[id]!.avgStars, inInclusiveRange(1.8, 2.5), reason: 'L$id');
    }
  });

  test('bot người mới: L1–L2 ≥ 80%, L3–L4 ≥ 58%, L5–L10 25–55% (không có tường 0%)', () {
    for (var id = 1; id <= 2; id++) {
      expect(newcomer[id]!.winRate, greaterThanOrEqualTo(0.8), reason: 'L$id');
    }
    for (var id = 3; id <= 4; id++) {
      expect(newcomer[id]!.winRate, greaterThanOrEqualTo(0.58), reason: 'L$id (dung sai 1 seed)');
    }
    for (var id = 5; id <= 10; id++) {
      expect(newcomer[id]!.winRate, inInclusiveRange(0.25, 0.55), reason: 'L$id');
    }
  });

  test('bot 0.3: L1–L2 ≥ 80%; từ L5 trung bình ≤ 30%, không level nào dễ hơn người mới quá 10 điểm %', () {
    for (var id = 1; id <= 2; id++) {
      expect(weak[id]!.winRate, greaterThanOrEqualTo(0.8), reason: 'L$id');
    }
    final hard = [for (var id = 5; id <= 20; id++) id];
    expect(avgWin(weak, hard), lessThanOrEqualTo(0.3));
    for (final id in hard) {
      expect(weak[id]!.winRate, lessThanOrEqualTo(newcomer[id]!.winRate + 0.1), reason: 'L$id');
    }
  });

  group('chương 2', () {
    test('bot 0.75: thắng 85–100%, sao TB 1.8–2.5; tổng sao chương 1 đủ mở chương 2', () {
      for (final id in ch2) {
        expect(good[id]!.winRate, inInclusiveRange(0.85, 1.0), reason: 'L$id');
        expect(good[id]!.avgStars, inInclusiveRange(1.8, 2.5), reason: 'L$id');
      }
      final ch1Stars = [for (var id = 1; id <= 10; id++) good[id]!.avgStars].reduce((a, b) => a + b);
      expect(ch1Stars, greaterThanOrEqualTo(config.chapter(2)!.starsToUnlock.toDouble()));
      expect(config.chapter(2)!.starsToUnlock, lessThanOrEqualTo(30 * 0.75));
    });

    // GĐ7: chương 2 cân cho người chơi `average` thắng lần đầu ≈ 71% (giữa chương 1 ~80% và chương 4 ~60%; trước đây 57%,
    // thấp hơn cả chương 4), nên người mới (bộ đồ kỳ vọng) thắng 34–58% thay vì ≤ 55%; L12 cao nhất vì phụ thuộc thu ngân +
    // khay lớn, mà "bộ đồ kỳ vọng" có đủ cả hai sớm hơn người chơi thật. Trung bình chương 2 được dễ hơn chương 1 (L5–L10)
    // tối đa 6 điểm % (trước 2) — với người chơi `average` (đồ mua thật) chương 2 vẫn khó hơn chương 1 (71% so với 82%).
    test(
      'bot người mới: 25–65% mọi level, trung bình dễ hơn chương 1 không quá 6 điểm %, không thấp hơn quá 8 điểm %',
      () {
        for (final id in ch2) {
          expect(newcomer[id]!.winRate, inInclusiveRange(0.25, 0.65), reason: 'L$id');
        }
        final c1 = avgWin(newcomer, ch1Hard), c2 = avgWin(newcomer, ch2);
        expect(c2, lessThanOrEqualTo(c1 + 0.06), reason: 'chương 2 không dễ hơn chương 1 quá nhiều');
        expect(c2, greaterThanOrEqualTo(c1 - 0.08), reason: 'chương 2 không khó vọt');
      },
    );

    test('bot 0.3: thắng ≤ 35% mọi level, trung bình thấp hơn chương 1', () {
      for (final id in ch2) {
        expect(weak[id]!.winRate, lessThanOrEqualTo(0.35), reason: 'L$id');
      }
      expect(avgWin(weak, ch2), lessThan(avgWin(weak, ch1Hard)));
    });
  });
}
