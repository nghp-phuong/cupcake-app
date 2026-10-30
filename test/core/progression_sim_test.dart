import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';

import 'progression_sim.dart';

/// Tiến trình L1→L20 có mua sắm (GĐ3 §4, GĐ4 §3, GĐ7): bot người mới và bot 0.75 chơi theo thứ tự, thua thì chơi lại
/// (tối đa 5 lần/level), trước mỗi lượt mua theo `simShop` — GĐ7: mở rộng, thuê nhân viên, nâng nhân viên lên cấp 2, thiết
/// bị mới và dụng cụ xếp chung một hàng để dành theo level mở (mở rộng −1, dụng cụ +1), hết hàng mới nâng nhân viên cấp
/// 3+ rồi trang trí rẻ nhất. Đồ + nhân viên đã có áp vào lượt sau qua `ShopSetup`. In bảng: xu/level, số lượt chơi, tỉ lệ thắng lần đầu (với đồ đã mua lúc đó), phần bán do nhân viên,
/// level mua từng mục (gồm thuê nhân viên), level nâng chỉ số nhân viên, tỉ lệ giá / thu nhập quanh mốc.
/// Chỉnh giá ở `assets/config/unlocks.json` (+ bản sao lò/dụng cụ trong `Economy`) khi lệch mục tiêu.
const _runs = 24;

/// Phần khách do nhân viên bán ở level [id] (mọi lượt chơi của mọi run).
double staffShare(List<SimRun> runs, int id) {
  var served = 0, staff = 0;
  for (final r in runs) {
    served += r.levels[id]!.served;
    staff += r.levels[id]!.staffSales;
  }
  return served == 0 ? 0 : staff / served;
}

void main() {
  final ids = [for (final l in simLevels.levels) l.id];
  final last = ids.last;

  /// (khoá, nhóm, level mở, giá) — mục mua được trước khi hết L20. Nhóm: mở rộng / nhân viên / thiết bị mới / dụng cụ.
  final items = <(String, String, int, int)>[
    for (final u in simUnlocks.unlocks)
      if (!u.comingSoon && u.level < last)
        (u.id, u.kind == UnlockKind.staff ? 'nhân viên' : 'mở rộng', u.level, u.price),
    for (final e in simUnlocks.equipment)
      for (var k = 2; k <= e.maxTier; k++)
        if (e.tier(k).level < last)
          (
            UnlockKeys.equipment(e.id, k),
            simNewEquipment.contains(e.id) ? 'thiết bị' : 'dụng cụ',
            e.tier(k).level,
            e.tier(k).price,
          ),
  ]..sort((a, b) => a.$3.compareTo(b.$3));

  ({List<SimRun> runs, Map<String, double> lag, Map<String, int> missing, Map<int, double> income}) run(
    String name,
    BotSkill skill,
  ) {
    final runs = [for (var i = 1; i <= _runs; i++) simulateProgression(skill, i)];
    double avg(int id, num Function(SimLevelStat s) f) =>
        runs.map((r) => f(r.levels[id]!)).reduce((a, b) => a + b) / _runs;
    final buf = StringBuffer(
      '\n$name — $_runs lượt L1→L$last có mua sắm\n'
      'level | xu TB/level | lượt chơi TB | thắng lần đầu | kẹt (5 lần thua) | bán bởi nhân viên\n',
    );
    final income = <int, double>{};
    for (final id in ids) {
      income[id] = avg(id, (s) => s.coins);
      buf.writeln(
        'L${id.toString().padRight(4)} | '
        '${income[id]!.toStringAsFixed(0).padLeft(11)} | '
        '${avg(id, (s) => s.plays).toStringAsFixed(2).padLeft(12)} | '
        '${(avg(id, (s) => s.firstWin ? 1 : 0) * 100).toStringAsFixed(0).padLeft(12)}% | '
        '${(avg(id, (s) => s.stuck ? 1 : 0) * 100).toStringAsFixed(0).padLeft(3)}%              | '
        '${(staffShare(runs, id) * 100).toStringAsFixed(0).padLeft(3)}%',
      );
    }
    final lag = <String, double>{}, missing = <String, int>{};
    buf.writeln(
      '\nmục                 | nhóm     | mở sau L | giá   | qua L lúc mua (TB / min–max) | trễ TB | chưa mua',
    );
    for (final (key, group, level, price) in items) {
      final at = [for (final r in runs) r.boughtAt[key]].whereType<int>().toList()..sort();
      missing[key] = _runs - at.length;
      // Chưa mua hết L20 → tính như mua sau level cuối (trễ tối thiểu).
      final all = [...at, for (var i = 0; i < missing[key]!; i++) last + 1];
      final avgAt = all.reduce((a, b) => a + b) / all.length;
      lag[key] = avgAt - level;
      buf.writeln(
        '${key.padRight(19)} | ${group.padRight(8)} | ${'$level'.padLeft(8)} | ${'$price'.padLeft(5)} | '
        '${at.isEmpty ? '—'.padLeft(28) : '${avgAt.toStringAsFixed(1)} / ${at.first}–${at.last}'.padLeft(28)} | '
        '${lag[key]!.toStringAsFixed(1).padLeft(6)} | ${missing[key]}',
      );
    }
    buf.writeln('\nnâng nhân viên: qua L lúc mua (TB, số lượt có mua / $_runs)');
    for (final d in simUnlocks.staff) {
      for (final stat in StaffStat.values) {
        final cells = <String>[];
        for (var k = 2; k <= d.maxLevel; k++) {
          final at = [for (final r in runs) r.boughtAt[simStaffKey(d.id, stat, k)]].whereType<int>().toList();
          if (at.isEmpty) continue;
          cells.add(
            'c$k ${d.priceTo(stat, k)}: L${(at.reduce((a, b) => a + b) / at.length).toStringAsFixed(1)} '
            '(${at.length})',
          );
        }
        if (cells.isNotEmpty) buf.writeln('${d.id.padRight(14)} ${stat.name.padRight(5)} | ${cells.join(' · ')}');
      }
    }
    final decor = [for (final r in runs) r.boughtAt.keys.where((k) => k.startsWith('decor:')).length];
    final left = runs.map((r) => r.coinsLeft).reduce((a, b) => a + b) / _runs;
    buf.writeln(
      'trang trí đã mua (TB): ${(decor.reduce((a, b) => a + b) / _runs).toStringAsFixed(1)}'
      '/${Catalog.decor.where((d) => !d.paidWithGems).length} · xu còn lại sau L$last (TB): ${left.toStringAsFixed(0)}',
    );
    // ignore: avoid_print
    print(buf);
    return (runs: runs, lag: lag, missing: missing, income: income);
  }

  final newcomer = run('Bot người mới', BotSkill.newcomer);
  final good = run('Bot 0.75', BotSkill.of(0.75));

  /// Giá / thu nhập TB một level quanh mốc (level mở → +2, trung bình hai bot).
  final ratio = <String, double>{};
  final ratioBuf = StringBuffer('\nGiá / xu TB một level quanh mốc (L mở..L mở+2, TB hai bot)\n');
  for (final (key, group, level, price) in items) {
    final window = [for (var id = level; id <= level + 2 && id <= last; id++) id];
    final income =
        window.map((id) => (newcomer.income[id]! + good.income[id]!) / 2).reduce((a, b) => a + b) / window.length;
    ratio[key] = price / income;
    ratioBuf.writeln('${key.padRight(19)} | ${group.padRight(8)} | ${ratio[key]!.toStringAsFixed(2)}×');
  }
  // ignore: avoid_print
  print(ratioBuf);

  /// GĐ7: mục mở từ L${last - 3} trở đi chỉ còn ≤ 3 level trong cửa sổ L1→L$last; người chơi khá (không chơi lại, ít xu
  /// hơn) có thể mua sau L$last — các mục này kiểm ở `simulate_test` (50 màn, người chơi `average`).
  bool late(String key) => items.firstWhere((e) => e.$1 == key).$3 >= last - 3;

  Iterable<String> keysOf(String group) => [
    for (final (key, g, _, _) in items)
      if (g == group) key,
  ];

  test('có đủ mục để mua: 3 mở rộng + 2 nhân viên + thiết bị mới + dụng cụ trước L$last', () {
    expect(keysOf('mở rộng'), ['case_stand', 'oven_2', 'cafe_tables']);
    expect(keysOf('nhân viên'), ['staff_cashier', 'staff_baker']);
    expect(keysOf('thiết bị'), hasLength(7));
    expect(keysOf('dụng cụ'), hasLength(10));
  });

  test('mở rộng: người mới mua trong ≤ 3 level, người giỏi trong 0.5–2 level (TB), không ai bỏ lỡ', () {
    for (final key in keysOf('mở rộng')) {
      expect(newcomer.lag[key], lessThanOrEqualTo(3), reason: key);
      // GĐ8: mốc mở từ L17 chỉ kiểm trễ TB (simulate_test kiểm trễ mốc trên 50 màn) — chủ dự án duyệt.
      if (!late(key)) expect(newcomer.missing[key], 0, reason: key);
      if (!late(key)) {
        // GĐ8: cùng mốc mua món rẻ trước — chủ dự án duyệt (2.0 → 2.2; oven_2 TB 2.04).
        expect(good.lag[key], inInclusiveRange(0.5, 2.2), reason: key);
        expect(good.missing[key], 0, reason: key);
      }
      expect(ratio[key], inInclusiveRange(1.5, 2.5), reason: '$key: giá ≈ 1.5–2.5 × xu một level');
    }
  });

  test('nhân viên: thuê trong 1–3 level sau khi mở (TB ≤ 3), không ai bỏ lỡ; giá thuê ≈ 0.8–2 × xu một level', () {
    for (final key in keysOf('nhân viên')) {
      expect(newcomer.lag[key], lessThanOrEqualTo(3), reason: key);
      expect(good.lag[key], lessThanOrEqualTo(3), reason: key);
      expect(newcomer.missing[key], 0, reason: key);
      expect(good.missing[key], 0, reason: key);
      expect(ratio[key], inInclusiveRange(0.8, 2.0), reason: key);
    }
  });

  // GĐ7: cấp 2 hạ giá (≈ 0.3× xu một level) và xếp hàng để dành ngay khi thuê → mua trong ≤ 3 level sau khi thuê được.
  test('nâng nhân viên: giá cấp 2 ≈ 0.25–1.2 × xu một level quanh mốc, mua trong ≤ 3 level sau khi thuê được', () {
    for (final id in keysOf('nhân viên')) {
      final d = simUnlocks.staffById(id)!;
      final u = simUnlocks.unlock(id)!;
      final window = [for (var l = u.level; l <= u.level + 2 && l <= last; l++) l];
      final income =
          window.map((l) => (newcomer.income[l]! + good.income[l]!) / 2).reduce((a, b) => a + b) / window.length;
      for (final stat in StaffStat.values) {
        final first = d.priceTo(stat, 2)! / income;
        expect(first, inInclusiveRange(0.25, 1.2), reason: '$id ${stat.name} cấp 2: ${first.toStringAsFixed(2)}×');
        for (final bot in [newcomer, good]) {
          final at = [for (final r in bot.runs) r.boughtAt[simStaffKey(id, stat, 2)] ?? last + 1];
          expect(
            at.reduce((a, b) => a + b) / at.length - u.level,
            lessThanOrEqualTo(3),
            reason: '$id ${stat.name} cấp 2',
          );
        }
      }
    }
  });

  test('thiết bị mới: mua trong ≤ 3 level (TB), giá ≈ 0.8–1.5 × xu một level', () {
    for (final key in keysOf('thiết bị')) {
      expect(newcomer.lag[key], lessThanOrEqualTo(3), reason: key);
      // GĐ8: cùng mốc mua món rẻ trước — chủ dự án duyệt (3 → 3.2; wideCase:3 TB 3.1).
      if (!late(key)) expect(good.lag[key], lessThanOrEqualTo(3.2), reason: key);
      expect(ratio[key], inInclusiveRange(0.8, 1.5), reason: key);
    }
  });

  test('dụng cụ: người mới mua trong ≤ 3 level; giá ≤ 1 × xu một level', () {
    for (final key in keysOf('dụng cụ')) {
      expect(newcomer.lag[key], lessThanOrEqualTo(3), reason: key);
      expect(ratio[key], lessThanOrEqualTo(1.0), reason: key);
    }
  });

  test('độ khó với đồ đã mua: người giỏi thắng lần đầu ≥ 85%, người mới 30–60% từ L5, ít khi kẹt', () {
    double firstWin(List<SimRun> runs, int id) => runs.where((r) => r.levels[id]!.firstWin).length / runs.length;
    final hard = [for (var id = 5; id <= last; id++) id];
    final goodAvg = hard.map((id) => firstWin(good.runs, id)).reduce((a, b) => a + b) / hard.length;
    final newAvg = hard.map((id) => firstWin(newcomer.runs, id)).reduce((a, b) => a + b) / hard.length;
    expect(goodAvg, greaterThanOrEqualTo(0.85));
    expect(newAvg, inInclusiveRange(0.3, 0.6));
    for (final id in hard) {
      expect(firstWin(good.runs, id), greaterThanOrEqualTo(0.75), reason: 'L$id');
      final stuck = newcomer.runs.where((r) => r.levels[id]!.stuck).length / _runs;
      expect(stuck, lessThanOrEqualTo(0.3), reason: 'L$id: người mới kẹt (thua 5 lần liền)');
    }
  });
}
