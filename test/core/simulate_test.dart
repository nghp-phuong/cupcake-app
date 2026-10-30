import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/sim/balance_report.dart';
import 'package:sugarleaf_bakery/core/sim/sim_runner.dart';

import '../../tool/simulate.dart' as tool;

/// GĐ7 (docs/v2/phase7-spec.md §4): script `tool/simulate.dart` chạy rút gọn không lỗi, tất định theo seed, và đạt các
/// mục tiêu §2 với người chơi `average` ở mức dung sai ±8 điểm % (bảng đầy đủ: `flutter test tool/simulate.dart`,
/// kết quả ghi ở docs/v2/phase7-balance.md). Thêm các mục tiêu sửa lệch sau GĐ7 (`SimTargets`): chương 2 ≈ 68–74%, không
/// màn chương 2 nào dưới 45%, % đủ sao mở chương, nâng nhân viên cấp 2 / dụng cụ không trễ.
const _runs = 48;

/// Dung sai thêm cho mục tiêu dạng khoảng (tỉ lệ) và trễ mốc (màn) khi chỉ chạy [_runs] người chơi giả.
const _rateSlack = 0.06, _lagSlack = 1.0;

void main() {
  final sim = tool.loadSim();

  group('dữ liệu', () {
    test('levels.json: 50 màn, chương 1–5 mỗi chương 10 màn, id liên tục', () {
      expect([for (final l in sim.levels.levels) l.id], [for (var i = 1; i <= 50; i++) i]);
      expect([for (final c in sim.levels.chapters) c.id], [1, 2, 3, 4, 5]);
      for (var c = 1; c <= 5; c++) {
        final ids = [for (final l in sim.levels.levelsInChapter(c)) l.id];
        expect(ids, [for (var i = 1; i <= 10; i++) (c - 1) * 10 + i], reason: 'chương $c');
        expect(sim.levels.level(c * 10).isSpecial, isTrue, reason: 'L${c * 10} là màn đặc biệt cuối chương');
      }
      for (var c = 3; c <= 5; c++) {
        expect(sim.levels.chapter(c)!.starsToUnlock, greaterThan(sim.levels.chapter(c - 1)!.starsToUnlock));
      }
    });

    test('sim đọc thẳng levels.json của game (GĐ8: không còn bản nháp)', () {
      final game = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync(), strict: true);
      expect([for (final l in sim.levels.levels) l.id], [for (final l in game.levels) l.id]);
      expect([for (final l in sim.levels.levels) l.menu], [for (final l in game.levels) l.menu]);
      expect(File('assets/config/levels_draft.json').existsSync(), isFalse);
    });

    test('độ khó tăng dần: kiên nhẫn giảm, khách tới dày hơn qua chương 3–5', () {
      double avgOf(int c, double Function(LevelData l) f) {
        final ls = sim.levels.levelsInChapter(c);
        return ls.map(f).reduce((a, b) => a + b) / ls.length;
      }

      for (var c = 3; c <= 5; c++) {
        expect(avgOf(c, (l) => l.patienceSec), lessThan(avgOf(c - 1, (l) => l.patienceSec)), reason: 'chương $c');
        expect(
          avgOf(c, (l) => l.spawn.startEverySec),
          lessThanOrEqualTo(avgOf(c - 1, (l) => l.spawn.startEverySec)),
          reason: 'chương $c',
        );
      }
    });
  });

  test('SimOptions.fromEnv: mặc định theo đặc tả, đọc biến, báo lỗi giá trị sai', () {
    final d = SimOptions.fromEnv(const {});
    expect(d.runs, 200);
    expect(d.personas, SimPersona.values);
    expect(d.boosters, isFalse);
    expect(d.offlineHours, 0);
    expect(d.maxTries, 10);
    final o = SimOptions.fromEnv(const {
      'SIM_RUNS': '5',
      'SIM_SEED': '7',
      'SIM_SKILL': 'good, newbie',
      'SIM_BOOSTERS': '1',
      'SIM_OFFLINE_HOURS': '8',
    });
    expect(
      [o.runs, o.seed, o.personas, o.boosters, o.offlineHours],
      [
        5,
        7,
        [SimPersona.good, SimPersona.newbie],
        true,
        8,
      ],
    );
    expect(o.runSeed(1), 700001);
    expect(() => SimOptions.fromEnv(const {'SIM_SKILL': 'pro'}), throwsFormatException);
    expect(() => SimOptions.fromEnv(const {'SIM_RUNS': '0'}), throwsFormatException);
  });

  test(
    'chạy rút gọn đủ mọi bảng (vật phẩm, vắng nhà, CSV, gợi ý mốc sao) và tất định theo seed',
    () async {
      const small = SimOptions(runs: 3, boosters: true, offlineHours: 8);
      final a = await tool.runSimulation(small, sim: sim, workers: 1);
      final b = await tool.runSimulation(small, sim: sim, workers: 3);
      final text = a.text();
      expect(text, b.text(), reason: 'cùng seed → cùng kết quả, không phụ thuộc số isolate');
      expect(a.levelsCsv(), b.levelsCsv());
      for (final s in ['1. Mỗi màn', '2. Mốc mở khoá', '3. Tổng kết chương', '4. Lệch mục tiêu', 'Với vật phẩm']) {
        expect(text, contains(s));
      }
      expect(a.levelsCsv().trim().split('\n'), hasLength(1 + 3 * 50));
      expect(a.milestonesCsv().trim().split('\n'), hasLength(1 + 3 * a.milestones.length));
      expect(a.chaptersCsv().trim().split('\n'), hasLength(1 + 2 * 3 * 5));
      // Quản lý được thuê (L32+) → có thu nhập vắng nhà; vật phẩm được dùng khi bật.
      final runs = a.runs[SimPersona.average]!;
      expect(runs.every((r) => r.levels[50]!.offlineCoins > 0), isTrue);
      expect(a.boosterRuns[SimPersona.average]!.any((r) => r.levels.values.any((s) => s.boostersUsed > 0)), isTrue);
      final stars = a.calibrateStars(20);
      expect(stars.keys, [for (var i = 21; i <= 50; i++) i]);
      for (final e in stars.entries) {
        expect(e.value[0] < e.value[1] && e.value[1] < e.value[2], isTrue, reason: 'L${e.key}: ${jsonEncode(e.value)}');
      }

      Future<String> averageCsv(int seed) async => (await tool.runSimulation(
        SimOptions(runs: 3, seed: seed, personas: const [SimPersona.average]),
        sim: sim,
        workers: 1,
      )).levelsCsv();
      expect(await averageCsv(0), await averageCsv(0));
      expect(await averageCsv(1), isNot(await averageCsv(0)), reason: 'seed khác → kết quả khác');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group('mục tiêu §2 (average, $_runs người chơi giả, dung sai ±8 điểm %)', () {
    late BalanceReport report;
    late Map<int, ChapterRow> ch;

    setUpAll(() async {
      report = await tool.runSimulation(
        const SimOptions(runs: _runs, personas: [SimPersona.average]),
        sim: sim,
      );
      ch = {for (final c in report.chapterRows(report.runs[SimPersona.average]!)) c.chapter: c};
      // ignore: avoid_print
      print(
        [
          for (final c in ch.values)
            'chương ${c.chapter}: ${(c.firstWin * 100).toStringAsFixed(0)}% (đủ sao ${(c.starGate * 100).toStringAsFixed(0)}%)',
        ].join(' · '),
      );
    });

    const tol = SimTargets.tolerance;

    test('chương 1 thắng lần đầu ≈ 80%', () {
      expect(ch[1]!.firstWin, closeTo(SimTargets.chapter1FirstWin, tol));
    });

    test('chương 4 ≈ 60%; chương 2–3 nằm giữa chương 1 và chương 4; chương 5 ≤ chương 4 (GĐ8: chương 3 ≈ 62%, 5 ≈ 57%)', () {
      expect(ch[4]!.firstWin, closeTo(SimTargets.chapter4FirstWin, tol));
      expect(ch[3]!.firstWin, closeTo(SimTargets.chapter3FirstWin, tol));
      expect(ch[5]!.firstWin, closeTo(SimTargets.chapter5FirstWin, tol));
      for (final c in [2, 3]) {
        expect(ch[c]!.firstWin, inInclusiveRange(ch[4]!.firstWin - tol, ch[1]!.firstWin + tol), reason: 'chương $c');
      }
      expect(ch[5]!.firstWin, lessThanOrEqualTo(ch[4]!.firstWin + tol));
    });

    test('mỗi mốc (mở rộng, nhân viên, thiết bị) mua được trong ≤ 3 màn sau khi mở, không quá rẻ', () {
      final rows = report.milestoneRows(report.runs[SimPersona.average]!);
      final main = [
        for (final m in rows)
          if (m.milestone.group.checkCheap) m,
      ];
      expect(main.map((m) => m.milestone.key), containsAll(['staff_waiter', 'garden', 'floor_2', 'staff_manager']));
      for (final m in main) {
        expect(m.lag, isNotNull, reason: m.milestone.key);
        expect(m.lag, lessThanOrEqualTo(SimTargets.maxLag + _lagSlack), reason: m.milestone.key);
        expect(m.flag, isNot('quá rẻ'), reason: '${m.milestone.key}: xu dư ${m.surplus} (giá ${m.milestone.price})');
      }
    });

    test('nâng nhân viên lên cấp 2 ≤ 3 màn sau khi thuê được; dụng cụ ≤ 4 màn sau khi mở', () {
      final rows = report.milestoneRows(report.runs[SimPersona.average]!);
      final upgrades = [
        for (final m in rows)
          if (m.milestone.group == MilestoneGroup.staffUpgrade) m,
      ];
      final tools = [
        for (final m in rows)
          if (m.milestone.group == MilestoneGroup.tool) m,
      ];
      expect(upgrades, hasLength(10), reason: '5 nhân viên × tốc độ / tay nghề');
      expect(tools, isNotEmpty);
      for (final (list, max) in [(upgrades, SimTargets.maxStaffUpgradeLag), (tools, SimTargets.maxToolLag)]) {
        for (final m in list) {
          expect(m.lag, isNotNull, reason: m.milestone.key);
          expect(m.lag, lessThanOrEqualTo(max + _lagSlack), reason: m.milestone.key);
        }
      }
    });

    test('chương 2 thắng lần đầu ≈ 68–74%, không màn nào của chương 2 dưới 45%', () {
      const r = SimTargets.chapter2FirstWin;
      expect(ch[2]!.firstWin, inInclusiveRange(r.min - _rateSlack, r.max + _rateSlack));
      for (final l in report.levelRows(report.runs[SimPersona.average]!).where((l) => l.chapter == 2)) {
        expect(l.firstWin, greaterThanOrEqualTo(SimTargets.minLevelFirstWin - _rateSlack), reason: 'L${l.id}');
      }
    });

    test('GĐ8: không màn nào của chương 3–5 dưới 45%', () {
      for (final l in report.levelRows(report.runs[SimPersona.average]!).where((l) => l.chapter >= 3)) {
        expect(l.firstWin, greaterThanOrEqualTo(SimTargets.minLevelFirstWin - _rateSlack), reason: 'L${l.id}');
      }
    });

    test('GĐ8: vắng nhà 8 giờ mỗi màn → xu dư sau L50 (sau mua Bí quyết của bà) ≤ 60 nghìn', () async {
      final offline = await tool.runSimulation(
        const SimOptions(runs: 24, personas: [SimPersona.average], offlineHours: 8),
        sim: sim,
      );
      final surplus = offline.endSurplus(offline.runs[SimPersona.average]!);
      expect(surplus, isNotNull);
      expect(surplus!, lessThanOrEqualTo(SimTargets.maxEndSurplus));
      // Có mua bí quyết.
      expect(offline.runs[SimPersona.average]!.every((r) => r.boughtAt.keys.any((k) => k.startsWith('secret:'))), isTrue);
      // GĐ8 (chủ dự án chọn (a)): mục tiêu theo chương chỉ đo ở chế độ mặc định — khi vắng nhà chỉ tham khảo.
      expect(
        offline.deviations(rateSlack: _rateSlack, lagSlack: _lagSlack).where((d) => d.contains('chương ')),
        isEmpty,
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    void starGates(Iterable<int> chapters) {
      const g = SimTargets.starGate;
      for (final c in chapters) {
        expect(ch[c]!.starGate, inInclusiveRange(g.min - _rateSlack, g.max + _rateSlack), reason: 'chương $c');
      }
    }

    void notStuck(bool Function(int chapter) which) {
      for (final r in report.levelRows(report.runs[SimPersona.average]!).where((r) => which(r.chapter))) {
        expect(r.stuck, lessThanOrEqualTo(0.05), reason: 'L${r.id}');
      }
    }

    test('đủ sao mở chương 2 ngay khi qua hết chương 1 lần đầu: ≈ 70–85%', () => starGates([2]));

    test('đủ sao mở chương 3–5 ≈ 70–88%', () => starGates([3, 4, 5]));

    test('không kẹt (thua 10 lần liền) ở màn nào của chương 1–2 quá 5%', () => notStuck((c) => c <= 2));

    test('không kẹt ở màn nào của chương 3–5 quá 5%', () => notStuck((c) => c >= 3));

    test(
      'danh sách lệch mục tiêu rỗng',
      () => expect(report.deviations(rateSlack: _rateSlack, lagSlack: _lagSlack), isEmpty),
    );
  });
}
