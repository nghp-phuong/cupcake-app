import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';

import 'progression_sim.dart';

/// Cân bằng GĐ6: kim cương kiếm trong game (lần đầu 3★ một level, hết chương, thành thạo món, thưởng miễn phí của thẻ
/// mùa) và mức dùng vật phẩm của người chơi không trả tiền (mục tiêu ~1 vật phẩm mỗi 2–3 màn từ L4). Không tính nhiệm
/// vụ ngày / quà đăng nhập / quảng cáo +1 kim cương (theo lịch, không theo màn — người chơi thật có thêm).
/// Bảng "với vật phẩm": tỉ lệ thắng từng level với bộ đồ kỳ vọng khi bot dùng từng vật phẩm (bảng chính không dùng).
/// Chỉnh `Economy.levelThreeStarGems` / `chapterCompleteGems` / giá trong monetization.json khi lệch.
const _runs = 12;

final _real = MonetizationConfigLoader.parse(File(MonetizationConfigLoader.assetPath).readAsStringSync(), strict: true);

/// Mùa thật nhưng ngày phủ đồng hồ mô phỏng (đổi ngày mùa trong file không làm lệch bảng).
final _monetization = MonetizationConfig(
  boosters: _real.boosters,
  season: SeasonData(
    id: 'sim',
    start: DateTime(2026),
    end: DateTime(2027),
    tiers: _real.season!.tiers,
    pointsPerNewStar: _real.season!.pointsPerNewStar,
    pointsPerWin: _real.season!.pointsPerWin,
  ),
  products: _real.products,
);

/// Người chơi không trả tiền: mỗi lượt dùng tối đa một vật phẩm — có trong kho thì dùng (khách kiên nhẫn → lò ×2 →
/// tủ đầy), hết kho thì mua vật phẩm rẻ nhất bằng kim cương nếu đủ.
Set<BoosterId> _freePlayer(GameState s, LevelData level, int attempt) {
  for (final id in const [BoosterId.patience, BoosterId.ovenBoost, BoosterId.fullCase]) {
    if (s.boosterCount(id) > 0) return {id};
  }
  final cheapest = s.boosterCatalog.reduce((a, b) => a.gemPrice <= b.gemPrice ? a : b);
  return s.gems >= cheapest.gemPrice ? {cheapest.id} : const {};
}

void main() {
  final ids = [for (final l in simLevels.levels) l.id];
  final last = ids.last;
  final fromL4 = [for (final id in ids) if (GameState.boostersAvailableFor(id)) id];
  final minPrice = _real.boosters.map((b) => b.gemPrice).reduce((a, b) => a < b ? a : b);
  final avgPrice = _real.boosters.map((b) => b.gemPrice).reduce((a, b) => a + b) / _real.boosters.length;

  ({List<SimRun> earn, List<SimRun> spend}) run(String name, BotSkill skill) {
    // Kiếm (không tiêu) — kim cương thuần theo màn; Tiêu — người chơi không trả tiền dùng vật phẩm khi có.
    final earn = [for (var i = 1; i <= _runs; i++) simulateProgression(skill, i, monetization: _monetization)];
    final spend = [
      for (var i = 1; i <= _runs; i++)
        simulateProgression(skill, i, monetization: _monetization, boosterPolicy: _freePlayer),
    ];
    double avg(List<SimRun> runs, int id, num Function(SimLevelStat s) f) =>
        runs.map((r) => f(r.levels[id]!)).reduce((a, b) => a + b) / runs.length;
    final buf = StringBuffer('\n$name — kim cương / vật phẩm theo màn ($_runs lượt L1→L$last, thẻ mùa: nhận thưởng '
        'miễn phí ngay)\nlevel | kim cương kiếm TB | cộng dồn | vật phẩm dùng TB (người không trả tiền) | '
        'lượt chơi TB (không / có vật phẩm) | thắng lần đầu (không / có)\n');
    var cum = 0.0;
    for (final id in ids) {
      final g = avg(earn, id, (s) => s.gems);
      cum += g;
      buf.writeln('L${id.toString().padRight(4)} | ${g.toStringAsFixed(1).padLeft(17)} | '
          '${cum.toStringAsFixed(0).padLeft(8)} | ${avg(spend, id, (s) => s.boostersUsed).toStringAsFixed(2).padLeft(38)} | '
          '${avg(earn, id, (s) => s.plays).toStringAsFixed(2).padLeft(16)} / ${avg(spend, id, (s) => s.plays).toStringAsFixed(2)} | '
          '${(avg(earn, id, (s) => s.firstWin ? 1 : 0) * 100).toStringAsFixed(0).padLeft(4)}% / '
          '${(avg(spend, id, (s) => s.firstWin ? 1 : 0) * 100).toStringAsFixed(0)}%');
    }
    final used = fromL4.map((id) => avg(spend, id, (s) => s.boostersUsed)).reduce((a, b) => a + b);
    final earned = fromL4.map((id) => avg(earn, id, (s) => s.gems)).reduce((a, b) => a + b);
    buf.writeln('L${fromL4.first}–L$last: kiếm ${earned.toStringAsFixed(0)} kim cương '
        '(${(earned / fromL4.length).toStringAsFixed(1)}/màn ≈ 1 vật phẩm giá TB ${avgPrice.toStringAsFixed(1)} mỗi '
        '${(avgPrice * fromL4.length / earned).toStringAsFixed(1)} màn); người không trả tiền dùng '
        '${used.toStringAsFixed(1)} vật phẩm / ${fromL4.length} màn = 1 mỗi ${(fromL4.length / used).toStringAsFixed(1)} màn; '
        'kim cương còn lại TB ${(spend.map((r) => r.gemsLeft).reduce((a, b) => a + b) / _runs).toStringAsFixed(0)}');
    // ignore: avoid_print
    print(buf);
    return (earn: earn, spend: spend);
  }

  final newcomer = run('Bot người mới', BotSkill.newcomer);
  final good = run('Bot 0.75', BotSkill.of(0.75));

  double perLevel(List<SimRun> runs) =>
      fromL4.map((id) => runs.map((r) => r.levels[id]!.boostersUsed).reduce((a, b) => a + b) / runs.length).reduce(
            (a, b) => a + b,
          ) /
      fromL4.length;

  test('người chơi không trả tiền dùng ~1 vật phẩm mỗi 2–3 màn từ L4 (người mới và người giỏi)', () {
    for (final (name, r) in [('người mới', newcomer), ('0.75', good)]) {
      final rate = perLevel(r.spend);
      expect(1 / rate, inInclusiveRange(1.8, 3.2), reason: '$name: 1 vật phẩm mỗi ${(1 / rate).toStringAsFixed(2)} màn');
    }
  });

  test('kim cương theo màn: mốc chương lớn nhất ở level cuối chương; tổng đủ mua vài vật phẩm, không dư thừa', () {
    for (final r in [newcomer.earn, good.earn]) {
      final total = ids.map((id) => r.map((x) => x.levels[id]!.gems).reduce((a, b) => a + b) / r.length).reduce(
            (a, b) => a + b,
          );
      expect(total, inInclusiveRange(minPrice * 8.0, avgPrice * 14));
      for (final id in const [10, 20]) {
        expect(r.every((x) => x.levels[id]!.gems >= Economy.chapterCompleteGems), isTrue, reason: 'L$id');
      }
    }
  });

  /// Tỉ lệ thắng TB L4–L20 (bộ đồ kỳ vọng) theo vật phẩm; in bảng.
  Map<String, double> withBoosters(String name, BotSkill skill, int seeds) {
    final configs = <String, Set<BoosterId>>{
      'không': const {},
      'kiên nhẫn': {BoosterId.patience},
      'lò ×2': {BoosterId.ovenBoost},
      'tủ đầy': {BoosterId.fullCase},
      'cả ba': {...BoosterId.values},
    };
    final buf = StringBuffer('\nVới vật phẩm — $name, bộ đồ kỳ vọng, $seeds seed: tỉ lệ thắng % (sao TB)\n'
        'level | ${configs.keys.map((k) => k.padLeft(13)).join(' | ')}\n');
    final sums = {for (final k in configs.keys) k: 0.0};
    for (final id in fromL4) {
      final gear = expectedGear(id);
      final level = simLevels.level(id);
      final cells = <String>[];
      configs.forEach((name, boosters) {
        final st = LevelBotStats.simulate(level, simLevels.defaults,
            skill: 0, botSkill: skill, seeds: seeds, setup: gear.setup, modifiers: gear.modifiers, boosters: boosters);
        sums[name] = sums[name]! + st.winRate;
        cells.add('${(st.winRate * 100).toStringAsFixed(0).padLeft(4)}% (${st.avgStars.toStringAsFixed(2)})'.padLeft(13));
      });
      buf.writeln('L${id.toString().padRight(4)} | ${cells.join(' | ')}');
    }
    final n = fromL4.length;
    final avg = {for (final k in configs.keys) k: sums[k]! / n};
    buf.writeln('TB    | ${configs.keys.map((k) => '${(avg[k]! * 100).toStringAsFixed(0)}%'.padLeft(13)).join(' | ')}');
    // ignore: avoid_print
    print(buf);
    return avg;
  }

  test('bảng với vật phẩm: từng vật phẩm không làm khó hơn, cả ba giúp rõ rệt (bot người mới)', () {
    final newcomerAvg = withBoosters('bot người mới', BotSkill.newcomer, 16);
    final goodAvg = withBoosters('bot 0.75', BotSkill.of(0.75), 8);
    final none = newcomerAvg['không']!;
    for (final k in ['kiên nhẫn', 'tủ đầy']) {
      expect(newcomerAvg[k], greaterThanOrEqualTo(none - 0.02), reason: k);
    }
    // Lò ×2 giữ vùng vàng / lúc cháy theo giây → không được khó hơn.
    expect(newcomerAvg['lò ×2'], greaterThanOrEqualTo(none), reason: 'lò ×2');
    expect(newcomerAvg['cả ba'], greaterThanOrEqualTo(none + 0.1));
    // Người giỏi vốn thắng gần hết; tủ đầy bánh 4★ còn kéo sao TB xuống ở màn sau (bánh của họ 5★) — báo cáo, chỉ chặn
    // khi tụt mạnh.
    for (final k in goodAvg.keys) {
      expect(goodAvg[k], greaterThanOrEqualTo(goodAvg['không']! - 0.08), reason: 'bot 0.75: $k');
    }
  });
}
