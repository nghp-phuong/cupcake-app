import 'dart:isolate';
import 'dart:math' as math;

import '../game_state.dart';
import '../level/level.dart';
import '../level/level_bot.dart';
import 'progression_sim.dart';

/// Người chơi giả của script cân bằng GĐ7.
enum SimPersona {
  /// Người mới: chính xác 0.5, phản ứng 1.2 s (`BotSkill.newcomer`, như các test cân bằng GĐ1–6).
  newbie,

  /// Người chơi trung bình — mục tiêu cân bằng GĐ7 đặt theo bot này.
  average,

  /// Người chơi khá: `BotSkill.of(0.75)` (như các test cân bằng GĐ1–6).
  good;

  /// Kỹ năng tổng của [average] (`BotSkill.of`): chọn sao cho chương 1 (đã cân ở GĐ1–5, không đổi) thắng lần đầu
  /// ≈ 80% — nằm giữa người mới (~65%) và người khá (~99%).
  static const averageSkill = 0.5;

  BotSkill get skill => switch (this) {
    SimPersona.newbie => BotSkill.newcomer,
    SimPersona.average => BotSkill.of(averageSkill),
    SimPersona.good => BotSkill.of(0.75),
  };
}

/// Tham số một lần chạy mô phỏng (biến môi trường `SIM_*` của `tool/simulate.dart`).
class SimOptions {
  const SimOptions({
    this.runs = 200,
    this.seed = 0,
    this.personas = SimPersona.values,
    this.boosters = false,
    this.offlineHours = 0,
    this.maxTries = 10,
  });

  /// `SIM_RUNS`, `SIM_SEED`, `SIM_SKILL` (newbie | average | good, có thể nhiều, cách nhau bởi dấu phẩy),
  /// `SIM_BOOSTERS` (0/1), `SIM_OFFLINE_HOURS`. Giá trị sai → [FormatException].
  factory SimOptions.fromEnv(Map<String, String> env) {
    int intOf(String k, int fallback, {int min = 0}) {
      final raw = env[k];
      if (raw == null || raw.trim().isEmpty) return fallback;
      final v = int.tryParse(raw.trim());
      if (v == null || v < min) throw FormatException('$k phải là số nguyên ≥ $min, có "$raw"');
      return v;
    }

    final rawSkill = env['SIM_SKILL']?.trim() ?? '';
    final personas = rawSkill.isEmpty
        ? SimPersona.values
        : [
            for (final name in rawSkill.split(','))
              SimPersona.values.firstWhere(
                (p) => p.name == name.trim(),
                orElse: () => throw FormatException('SIM_SKILL: "$name" không phải newbie | average | good'),
              ),
          ];
    final rawOffline = env['SIM_OFFLINE_HOURS']?.trim() ?? '';
    final offline = rawOffline.isEmpty ? 0.0 : double.tryParse(rawOffline);
    if (offline == null || offline < 0) throw FormatException('SIM_OFFLINE_HOURS phải là số ≥ 0, có "$rawOffline"');
    return SimOptions(
      runs: intOf('SIM_RUNS', 200, min: 1),
      seed: intOf('SIM_SEED', 0),
      personas: personas,
      boosters: intOf('SIM_BOOSTERS', 0) != 0,
      offlineHours: offline,
    );
  }

  final int runs;
  final int seed;
  final List<SimPersona> personas;

  /// Thêm bảng "với vật phẩm" (người chơi không trả tiền dùng vật phẩm khi có — [simFreePlayerBoosters]).
  final bool boosters;

  /// Giờ vắng nhà giả định sau mỗi level (thu nhập quản lý); 0 = tắt.
  final double offlineHours;

  /// Thua liền chừng này lượt → "kẹt" (coi như qua 1★, không xu).
  final int maxTries;

  /// Seed của lượt chơi thứ [i] (1..[runs]); `SIM_SEED` = 0 → 1..N như các test cân bằng cũ.
  int runSeed(int i) => seed * 100000 + i;
}

/// Người chơi không trả tiền (như `booster_balance_test`): mỗi lượt dùng tối đa một vật phẩm — có trong kho thì dùng
/// (khách kiên nhẫn → lò ×2 → tủ đầy), hết kho thì mua vật phẩm rẻ nhất bằng kim cương nếu đủ.
Set<BoosterId> simFreePlayerBoosters(GameState s, LevelData level, int attempt) {
  for (final id in const [BoosterId.patience, BoosterId.ovenBoost, BoosterId.fullCase]) {
    if (s.boosterCount(id) > 0) return {id};
  }
  final cheapest = s.boosterCatalog.reduce((a, b) => a.gemPrice <= b.gemPrice ? a : b);
  return s.gems >= cheapest.gemPrice ? {cheapest.id} : const {};
}

/// Chạy [SimOptions.runs] lượt cho [persona], chia đều cho [workers] isolate (kết quả tất định theo seed, không phụ
/// thuộc số isolate). [monetization] + [boosters] → bảng "với vật phẩm".
Future<List<SimRun>> simulatePersona(
  ProgressionSim sim,
  SimPersona persona,
  SimOptions options, {
  bool boosters = false,
  MonetizationConfig? monetization,
  int workers = 1,
}) async {
  final seeds = [for (var i = 1; i <= options.runs; i++) options.runSeed(i)];
  final skill = persona.skill;
  final maxTries = options.maxTries, offline = options.offlineHours;
  List<SimRun> runChunk(List<int> chunk) => [
    for (final seed in chunk)
      sim.run(
        skill,
        seed,
        maxTries: maxTries,
        offlineHours: offline,
        monetization: boosters ? monetization : null,
        boosterPolicy: boosters ? simFreePlayerBoosters : null,
      ),
  ];
  final n = math.max(1, math.min(workers, seeds.length));
  if (n == 1) return runChunk(seeds);
  final size = (seeds.length / n).ceil();
  final chunks = [for (var i = 0; i < seeds.length; i += size) seeds.sublist(i, math.min(seeds.length, i + size))];
  final parts = await Future.wait([for (final c in chunks) Isolate.run(() => runChunk(c))]);
  return [for (final p in parts) ...p];
}
