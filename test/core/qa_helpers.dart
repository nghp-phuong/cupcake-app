import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

/// Trợ giúp chung cho các test QA (test/core/qa_*_test.dart). Không phải file test.

final qaLevels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync(), strict: true);
final qaUnlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync(), strict: true);
final qaMonetization =
    MonetizationConfigLoader.parse(File(MonetizationConfigLoader.assetPath).readAsStringSync(), strict: true);

/// Đồng hồ chỉnh được (giả lập đổi giờ hệ thống).
class QaClock {
  QaClock([DateTime? start]) : now = start ?? DateTime(2026, 10, 30, 9);
  DateTime now;
  DateTime call() => now;
}

GameState qaState({Map<String, dynamic> json = const {}, QaClock? clock}) {
  final c = clock ?? QaClock();
  return GameState.fromJson({'v': 2, ...json}, clock: c.call)
    ..attachLevelConfig(qaLevels)
    ..attachUnlockConfig(qaUnlocks)
    ..attachMonetizationConfig(qaMonetization);
}

LevelResult qaResult(int id, {bool won = true, int stars = 1, int coins = 0, int goalValue = 1}) => LevelResult(
      levelId: id,
      won: won,
      stars: won ? stars : 0,
      coins: coins,
      served: 0,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: goalValue,
    );

/// Qua các level còn thiếu tới [last] (1★ mỗi level, 0 xu).
void qaPassTo(GameState s, int last) {
  for (var id = s.highestCompletedLevel + 1; id <= last; id++) {
    s.applyLevelResult(qaResult(id));
  }
}

/// Đặt xu đúng bằng [coins] (trừ / cộng qua API công khai).
void qaSetCoins(GameState s, int coins) {
  if (s.coins > coins) {
    expect(s.trySpendCoins(s.coins - coins), isTrue);
  } else if (s.coins < coins) {
    s.addCoins(coins - s.coins);
  }
  expect(s.coins, coins);
}

LevelData qaLevel({
  int id = 1,
  int durationSec = 120,
  GoalType goal = GoalType.customers,
  List<int> stars = const [2, 4, 6],
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla],
  int caseSlots = 3,
  int startStock = 0,
  double patienceSec = 40,
  double every = 10,
  double endEvery = 10,
  double rushAtPct = 100,
  double rushEvery = 10,
  List<SpecialVisit> specials = const [],
  Map<String, num> overrides = const {},
}) =>
    LevelData(
      id: id,
      chapter: 1,
      title: const {'en': 'QA', 'vi': 'QA'},
      durationSec: durationSec,
      goal: LevelGoal(type: goal, stars: stars),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: patienceSec,
      spawn: SpawnCurve(startEverySec: every, endEverySec: endEvery, rushAtPct: rushAtPct, rushEverySec: rushEvery),
      specials: specials,
      newRecipe: menu.last,
      overrides: overrides,
    );

LevelSession qaSession(
  LevelData level, {
  int seed = 1,
  LevelDefaults defaults = const LevelDefaults(jitterPct: 0),
  ShopSetup setup = ShopSetup.base,
  Set<BoosterId> boosters = const {},
}) =>
    LevelSession(
      level: level,
      defaults: defaults,
      modifiers: BakeModifiers.base,
      setup: setup,
      boosters: boosters,
      random: math.Random(seed),
    );

/// Chạy từng bước tới khi [cond] đúng; trả sự kiện đã gom.
List<SessionEvent> qaUntil(LevelSession s, bool Function() cond, {double maxSec = 60}) {
  final events = <SessionEvent>[];
  final end = s.elapsed + maxSec;
  while (!cond()) {
    if (s.elapsed >= end || s.isOver) fail('quá $maxSec s mà điều kiện chưa đúng (elapsed ${s.elapsed})');
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  events.addAll(s.drainEvents());
  return events;
}

List<SessionEvent> qaRun(LevelSession s, double sec) {
  final events = <SessionEvent>[];
  final n = (sec / LevelSession.step).round();
  for (var i = 0; i < n && !s.isOver; i++) {
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  events.addAll(s.drainEvents());
  return events;
}

/// Chạy tới hết giờ.
List<SessionEvent> qaRunToEnd(LevelSession s) {
  final events = <SessionEvent>[];
  while (!s.isOver) {
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  events.addAll(s.drainEvents());
  return events;
}

LevelCustomer? qaAtCounter(LevelSession s) {
  for (final c in s.customers) {
    if (c.canBuy) return c;
  }
  return null;
}
