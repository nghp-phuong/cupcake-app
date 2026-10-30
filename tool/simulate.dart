// Mô phỏng cân bằng 50 màn (V2 GĐ7, docs/v2/phase7-spec.md). Không UI: bot chơi bằng đúng `LevelSession` +
// `LevelBot` của màn chơi thật trên `levels.json` (GĐ8: đủ 50 màn), mua sắm bằng đúng `GameState`.
//
// Chạy (cần Flutter vì logic level dùng `package:flutter/foundation.dart`):
//   flutter test tool/simulate.dart
// Biến môi trường:
//   SIM_RUNS           số người chơi giả mỗi kỹ năng (mặc định 200)
//   SIM_SEED           seed gốc (mặc định 0 → lượt i dùng seed i như các test cân bằng)
//   SIM_SKILL          newbie | average | good (có thể nhiều, cách nhau dấu phẩy; mặc định cả 3)
//   SIM_BOOSTERS       1 → in thêm bảng "với vật phẩm" (mặc định 0)
//   SIM_OFFLINE_HOURS  giờ vắng nhà giả định sau mỗi màn (thu nhập quản lý; mặc định 0 = tắt)
//   SIM_OUT            đường dẫn CSV mỗi màn (kèm <tên>_milestones.csv, <tên>_chapters.csv)
//   SIM_CALIBRATE      1 → in mốc sao gợi ý (JSON {id: [1★, 2★, 3★]}, công thức ở BalanceReport.calibrateStars)
//                      và starsToUnlock gợi ý mỗi chương (SimTargets.starGateTarget)
//   SIM_CALIBRATE_FROM gợi ý mốc sao cho các màn có id > số này (mặc định 20 = chương 3–5; 10 → cả chương 2)
//   SIM_WORKERS        số isolate song song (mặc định số nhân CPU − 1)
// Ví dụ: SIM_RUNS=50 SIM_SKILL=average flutter test tool/simulate.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/sim/balance_report.dart';
import 'package:sugarleaf_bakery/core/sim/progression_sim.dart';
import 'package:sugarleaf_bakery/core/sim/sim_runner.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

/// Màn cuối đã cân mốc sao bằng tay / `level_balance_test` (chương 1–2); `SIM_CALIBRATE` gợi ý cho các màn sau.
const calibratedThrough = 20;

/// `levels.json` + `unlocks.json` từ thư mục gốc dự án.
ProgressionSim loadSim() => ProgressionSim(
  LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync(), strict: true),
  UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync(), strict: true),
);

/// monetization.json thật, mùa phủ đồng hồ mô phỏng (như `booster_balance_test`).
MonetizationConfig loadMonetization() {
  final real = MonetizationConfigLoader.parse(
    File(MonetizationConfigLoader.assetPath).readAsStringSync(),
    strict: true,
  );
  final season = real.season;
  return MonetizationConfig(
    boosters: real.boosters,
    season: season == null
        ? null
        : SeasonData(
            id: 'sim',
            start: DateTime(2026),
            end: DateTime(2027),
            tiers: season.tiers,
            pointsPerNewStar: season.pointsPerNewStar,
            pointsPerWin: season.pointsPerWin,
          ),
    products: real.products,
  );
}

/// Chạy mô phỏng theo [options] (không in). [workers] isolate song song.
Future<BalanceReport> runSimulation(SimOptions options, {ProgressionSim? sim, int? workers}) async {
  final s = sim ?? loadSim();
  final w = workers ?? math.max(1, Platform.numberOfProcessors - 1);
  final runs = {for (final p in options.personas) p: await simulatePersona(s, p, options, workers: w)};
  final boosterRuns = <SimPersona, List<SimRun>>{};
  if (options.boosters) {
    final monetization = loadMonetization();
    for (final p in options.personas) {
      boosterRuns[p] = await simulatePersona(s, p, options, boosters: true, monetization: monetization, workers: w);
    }
  }
  return BalanceReport(levels: s.levels, unlocks: s.unlocks, options: options, runs: runs, boosterRuns: boosterRuns);
}

void main() {
  test('mô phỏng cân bằng 50 màn', () async {
    final env = Platform.environment;
    final options = SimOptions.fromEnv(env);
    final workers = int.tryParse(env['SIM_WORKERS'] ?? '');
    final watch = Stopwatch()..start();
    final report = await runSimulation(options, workers: workers);
    print(report.text());
    print('(${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s)');

    final out = env['SIM_OUT']?.trim() ?? '';
    if (out.isNotEmpty) {
      final dot = out.toLowerCase().endsWith('.csv') ? out.length - 4 : out.length;
      final stem = out.substring(0, dot);
      File(out).writeAsStringSync(report.levelsCsv());
      File('${stem}_milestones.csv').writeAsStringSync(report.milestonesCsv());
      File('${stem}_chapters.csv').writeAsStringSync(report.chaptersCsv());
      print('CSV: $out, ${stem}_milestones.csv, ${stem}_chapters.csv');
    }
    if ((env['SIM_CALIBRATE'] ?? '').trim() == '1') {
      final from = int.tryParse(env['SIM_CALIBRATE_FROM'] ?? '') ?? calibratedThrough;
      final stars = report.calibrateStars(from);
      print('Mốc sao gợi ý (levels.json, màn > $from):');
      print(jsonEncode({for (final e in stars.entries) '${e.key}': e.value}));
      print('starsToUnlock gợi ý (≈ ${(SimTargets.starGateTarget * 100).round()}% đủ sao ngay khi qua chương trước):');
      for (final MapEntry(key: c, value: g) in report.suggestStarGates().entries) {
        print(
          'chương $c: ${g.stars}★ (đủ ${(g.share * 100).toStringAsFixed(0)}%, sao TV '
          '${g.median.toStringAsFixed(1)}, hiện ${report.levels.chapter(c)!.starsToUnlock}★)',
        );
      }
    }
  }, timeout: Timeout.none);
}
