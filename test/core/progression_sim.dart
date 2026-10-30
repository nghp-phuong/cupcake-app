import 'dart:io';

import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/sim/progression_sim.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

export 'package:sugarleaf_bakery/core/sim/progression_sim.dart';

/// Mô phỏng tiến trình L1→L20 có mua sắm (dùng chung cho `progression_sim_test`, `level_balance_test`,
/// `booster_balance_test`) trên `levels.json` + `unlocks.json` thật. Logic ở `lib/core/sim/progression_sim.dart`
/// (dùng chung với `tool/simulate.dart`).

/// Màn cuối các test này cân bằng (chương 1–2). GĐ8: levels.json có đủ L1–L50; chương 3–5 cân bằng bằng
/// `simulate_test` / `tool/simulate.dart` (cả 50 màn).
const simLastLevel = 20;

final _allLevels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

/// `levels.json` cắt tới [simLastLevel] (chương 1–2).
final simLevels = LevelConfig(
  version: _allLevels.version,
  defaults: _allLevels.defaults,
  chapters: [
    for (final c in _allLevels.chapters)
      if (_allLevels.levelsInChapter(c.id).any((l) => l.id <= simLastLevel)) c,
  ],
  levels: [
    for (final l in _allLevels.levels)
      if (l.id <= simLastLevel) l,
  ],
);
final simUnlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync());

final _sim = ProgressionSim(simLevels, simUnlocks);

GameState simFreshState() => _sim.freshState();

/// Xem [ProgressionSim.run].
SimRun simulateProgression(
  BotSkill skill,
  int runSeed, {
  int maxTries = 5,
  MonetizationConfig? monetization,
  SimBoosterPolicy? boosterPolicy,
}) =>
    _sim.run(skill, runSeed, maxTries: maxTries, monetization: monetization, boosterPolicy: boosterPolicy);

/// Xem [ProgressionSim.expectedGear].
({ShopSetup setup, BakeModifiers modifiers}) expectedGear(int levelId, {int lag = 1}) =>
    _sim.expectedGear(levelId, lag: lag);
