import 'dart:math' as math;

import '../catalog.dart';
import '../game_state.dart';
import '../level/level.dart';
import '../level/level_bot.dart';
import '../models/bake.dart';
import '../models/ids.dart';

/// Mô phỏng tiến trình có mua sắm (Dart thuần, không I/O): dùng chung cho test cân bằng (`test/core/progression_sim.dart`)
/// và script GĐ7 (`tool/simulate.dart`). Bot chơi bằng đúng `LevelSession` + `LevelBot` của màn chơi thật, mua sắm bằng
/// đúng hàm của `GameState`.

/// Một món có thể mua: khoá `UnlockKeys`, level mở, giá.
class SimItem {
  const SimItem(this.key, this.level, this.price, this.buy);

  final String key;
  final int level;
  final int price;
  final PurchaseResult Function() buy;
}

/// Nhóm mua (GĐ4 §3, GĐ7): mở rộng, thuê nhân viên, nâng nhân viên lên cấp 2, thiết bị mới, dụng cụ (lò vùng vàng +
/// dụng cụ V1), nâng nhân viên cấp 3+, trang trí, Bí quyết của bà (GĐ8, mua trước trang trí — xem [simShop]). Số nhỏ =
/// ưu tiên trước khi hai món cùng level mở.
const simExpansion = 0,
    simStaffHire = 1,
    simStaffFirst = 2,
    simEquipment = 3,
    simTools = 4,
    simStaffUpgrade = 5,
    simDecor = 6,
    simRecipeSecrets = 7;

/// Nhóm "để dành" (GĐ7): mọi món khả dụng của các nhóm này xếp chung một hàng theo level mở (cũ trước); món đầu hàng
/// chưa đủ xu → để dành, không mua gì khác.
const simSaveUpGroups = [simExpansion, simStaffHire, simStaffFirst, simEquipment, simTools];

/// Độ lệch khi xếp hàng để dành (level mở + lệch): mở rộng −1 (món lớn nhất, như GĐ4 xếp trước; không thì bàn ghế L18
/// chờ thiết bị L16–L17 và người chơi khá không mua kịp trong chương 2), dụng cụ +1 (món lặt vặt nhường món lớn mở cùng
/// lúc; không thì kệ bánh L5 bị dụng cụ L3–L4 giành xu, người chơi khá thua L7 nhiều hơn).
const simQueueOffset = {simExpansion: -1, simTools: 1};

/// Thiết bị "mới" của GĐ3 (ưu tiên trước lò vùng vàng / dụng cụ V1).
const simNewEquipment = [EquipmentIds.fastOven, EquipmentIds.bigTray, EquipmentIds.wideCase];
final simToolEquipment = [EquipmentIds.goldenOven, for (final t in ToolId.values) t.name];

/// Khoá mua của Bí quyết của bà (GĐ8): `secret:<món>:<bậc>`.
String simSecretKey(RecipeId r, int tier) => 'secret:${r.name}:$tier';

/// Khoá mua của nâng chỉ số nhân viên: `staff:<id>:<speed|skill>:<cấp>`.
String simStaffKey(String id, StaffStat stat, int level) => 'staff:$id:${stat.name}:$level';

/// Mục mua được ngay (đã tới mốc, chưa có) của một nhóm ưu tiên, rẻ trước (cùng nhóm, level thấp trước).
List<SimItem> _available(GameState s, int group) {
  final passed = s.highestCompletedLevel;
  final out = <SimItem>[];
  if (group == simExpansion || group == simStaffHire) {
    final kind = group == simExpansion ? UnlockKind.expansion : UnlockKind.staff;
    for (final u in s.unlockConfig.unlocks) {
      if (u.kind == kind && s.unlockState(u.id) == UnlockState.available) {
        out.add(SimItem(u.id, u.level, u.price, () => s.buyUnlock(u.id)));
      }
    }
  } else if (group == simStaffUpgrade || group == simStaffFirst) {
    for (final d in s.unlockConfig.staff) {
      for (final stat in StaffStat.values) {
        final price = s.staffUpgradePrice(d.id, stat);
        if (price == null) continue;
        final next = s.staffLevel(d.id, stat) + 1;
        if ((next == 2) != (group == simStaffFirst)) continue;
        // Cấp 2: level mở = level thuê được nhân viên đó (xếp hàng để dành cùng mở rộng / thiết bị).
        final level = group == simStaffFirst ? (s.unlockConfig.unlock(d.id)?.level ?? next) : next;
        out.add(SimItem(simStaffKey(d.id, stat, next), level, price, () => s.upgradeStaff(d.id, stat)));
      }
    }
    out.sort((a, b) => a.price.compareTo(b.price));
    return out;
  } else if (group == simEquipment || group == simTools) {
    for (final id in group == simEquipment ? simNewEquipment : simToolEquipment) {
      final eq = s.unlockConfig.equipmentById(id);
      if (eq == null) continue;
      final next = s.equipmentTier(id) + 1;
      if (next > eq.maxTier) continue;
      final t = eq.tier(next);
      if (t.level <= passed) {
        out.add(SimItem(UnlockKeys.equipment(id, next), t.level, t.price, () => s.buyEquipment(id)));
      }
    }
  } else if (group == simRecipeSecrets) {
    // Bí quyết của bà (GĐ8): món trong menu màn kế trước, rồi rẻ trước. Khoá `secret:<món>:<bậc>`.
    final config = s.levelConfig;
    final next = s.currentLevelId;
    final menu = config.hasLevel(next) ? config.level(next).menu.toSet() : const <RecipeId>{};
    for (final r in Catalog.recipes) {
      final price = s.recipeSecretPrice(r.id);
      if (price == null) continue;
      out.add(SimItem(simSecretKey(r.id, s.recipeSecretTier(r.id) + 1), menu.contains(r.id) ? 0 : 1, price, () {
        return s.buyRecipeSecret(r.id) ? PurchaseResult.ok : PurchaseResult.notEnoughCoins;
      }));
    }
    // `level` của mục ở đây = 0 (món trong menu màn kế) / 1 (món khác), xếp như các nhóm khác: level rồi giá.
  } else {
    for (final d in Catalog.decor) {
      if (d.paidWithGems || s.ownedDecor.contains(d.id) || d.unlockLevel > passed) continue;
      out.add(
        SimItem('decor:${d.id.name}', d.unlockLevel, d.coinPrice, () {
          final r = s.buyDecor(d.id);
          final current = s.equippedDecor[d.slot];
          if (r == PurchaseResult.ok && (current == null || Catalog.decorItem(current).tipBonusPct < d.tipBonusPct)) {
            s.equipDecor(d.slot, d.id);
          }
          return r;
        }),
      );
    }
  }
  out.sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.price.compareTo(b.price));
  if (group == simDecor) out.sort((a, b) => a.price.compareTo(b.price));
  return out;
}

/// Mua sắm trước mỗi lượt chơi (GĐ7, thay thứ tự cứng theo nhóm của GĐ4 — trước đây dụng cụ và nâng nhân viên đứng
/// sau ba nhóm để dành nên trễ 4–14 màn):
/// 1. Hàng để dành: mọi món khả dụng của [simSaveUpGroups] xếp theo level mở (nâng nhân viên cấp 2: level thuê được
///    nhân viên đó) + [simQueueOffset], cùng mốc thì rẻ trước rồi theo thứ tự nhóm (GĐ8: trước đây theo nhóm trước
///    nên bàn ghế L18 — mở rộng tính sớm 1 level — giành xu của khay lớn cấp 3 L17, khay trễ 4 màn). Món đầu hàng đủ
///    xu → mua, lặp lại; chưa đủ → để dành, dừng.
/// 2. Hết hàng: nâng nhân viên cấp 3+ (rẻ trước) → Bí quyết của bà (GĐ8; món trong menu màn kế trước, rồi rẻ trước)
///    → trang trí rẻ nhất, món nào đủ xu thì mua.
/// Trả các khoá vừa mua; [onBuy] nhận khoá + xu còn lại ngay sau mua.
List<String> simShop(GameState s, {void Function(String key, int coinsLeft)? onBuy}) {
  final bought = <String>[];
  void buy(SimItem item) {
    final r = item.buy();
    if (r != PurchaseResult.ok) throw StateError('mua ${item.key}: $r');
    bought.add(item.key);
    onBuy?.call(item.key, s.coins);
  }

  while (true) {
    final queue =
        [
          for (final g in simSaveUpGroups)
            for (final item in _available(s, g)) (group: g, item: item, at: item.level + (simQueueOffset[g] ?? 0)),
        ]..sort(
          (a, b) => a.at != b.at
              ? a.at.compareTo(b.at)
              : a.item.price != b.item.price
              ? a.item.price.compareTo(b.item.price)
              : a.group.compareTo(b.group),
        );
    if (queue.isEmpty) break;
    if (s.coins < queue.first.item.price) return bought;
    buy(queue.first.item);
  }
  // GĐ8: bí quyết sau nâng nhân viên, trước trang trí.
  for (final g in const [simStaffUpgrade, simRecipeSecrets, simDecor]) {
    for (
      var item = _available(s, g).where((i) => i.price <= s.coins).firstOrNull;
      item != null;
      item = _available(s, g).where((i) => i.price <= s.coins).firstOrNull
    ) {
      buy(item);
    }
  }
  return bought;
}

class SimLevelStat {
  int plays = 0;
  int coins = 0;
  bool firstWin = false;
  bool stuck = false;

  /// Sao của lượt thắng (kẹt → 1).
  int stars = 0;

  /// Giá trị mục tiêu (xu / khách / đơn đặc biệt) của lượt chơi đầu — cân mốc sao theo phân vị (GĐ7).
  int firstGoalValue = 0;

  /// Cộng mọi lượt chơi của level: khách đã phục vụ / trong đó do nhân viên bán.
  int served = 0;
  int staffSales = 0;

  /// GĐ6: kim cương kiếm (mọi lượt của level, gồm thưởng thẻ mùa nhận ngay sau lượt) / vật phẩm đã dùng.
  int gems = 0;
  int boostersUsed = 0;

  /// GĐ7: xu nhận từ quản lý khi vắng nhà sau level (chỉ khi bật `offlineHours`).
  int offlineCoins = 0;

  /// GĐ7: xu trong ví ngay sau level (sau lượt cuối, trước lần mua sắm kế) / tổng sao mọi level lúc đó.
  int coinsAfter = 0;
  int totalStarsAfter = 0;
}

/// Chọn vật phẩm cho một lượt chơi (GĐ6). Sim gọi `consumeBoosters`; không trả được → chơi không vật phẩm.
typedef SimBoosterPolicy = Set<BoosterId> Function(GameState s, LevelData level, int attempt);

/// Một lượt chơi từ level đầu tới level cuối của config.
class SimRun {
  final Map<int, SimLevelStat> levels = {};

  /// Khoá mua → số level đã qua lúc mua.
  final Map<String, int> boughtAt = {};

  /// GĐ7: khoá mua → xu còn lại ngay sau khi mua.
  final Map<String, int> coinsLeftAfterBuy = {};

  /// Tiệm + lò/dụng cụ + % tip trang trí ở lượt chơi đầu của từng level.
  final Map<int, ({ShopSetup setup, BakeModifiers modifiers, int decorTip})> gearAt = {};
  int coinsLeft = 0;

  /// GĐ6: kim cương còn lại sau L cuối.
  int gemsLeft = 0;
}

DateTime _clock() => DateTime(2026, 10, 27, 10);

/// Bộ mô phỏng trên một cặp config (levels + unlocks).
class ProgressionSim {
  const ProgressionSim(this.levels, this.unlocks);

  final LevelConfig levels;
  final UnlockConfig unlocks;

  GameState freshState() => GameState.newGame(clock: _clock)
    ..attachLevelConfig(levels)
    ..attachUnlockConfig(unlocks);

  /// Bot chơi theo thứ tự, thua thì chơi lại (tối đa [maxTries]; vẫn thua → coi như qua 1★ không xu, `stuck`),
  /// mua sắm trước mỗi lượt chơi. Mặc định không dùng vật phẩm, không gắn monetization.json (số liệu cân bằng chính).
  /// GĐ6: [monetization] gắn vào ván (thẻ mùa: nhận mọi thưởng miễn phí ngay sau mỗi lượt), [boosterPolicy] chọn vật
  /// phẩm trước mỗi lượt từ L4. GĐ7: [offlineHours] > 0 → sau mỗi level vắng nhà chừng ấy giờ rồi nhận thu nhập quản lý
  /// (không x2); [lastLevel] dừng sau level này.
  SimRun run(
    BotSkill skill,
    int runSeed, {
    int maxTries = 5,
    MonetizationConfig? monetization,
    SimBoosterPolicy? boosterPolicy,
    double offlineHours = 0,
    int? lastLevel,
  }) {
    final s = freshState();
    if (monetization != null) s.attachMonetizationConfig(monetization);
    final run = SimRun();
    // Đồng hồ vắng nhà: mỗi màn vắng thêm [offlineHours] giờ, chỉ tiến (mốc hoạt động không lùi — QA-01; trước đây gọi
    // `refreshOffline(_clock() + giờ)` với đồng hồ cố định, chính là chu kỳ lùi giờ đã chặn).
    var awayClock = _clock();
    void shop() {
      simShop(
        s,
        onBuy: (k, left) {
          run.boughtAt[k] = s.highestCompletedLevel;
          run.coinsLeftAfterBuy[k] = left;
        },
      );
    }

    for (final level in levels.levels) {
      if (lastLevel != null && level.id > lastLevel) break;
      final stat = run.levels[level.id] = SimLevelStat();
      var won = false;
      for (var attempt = 1; attempt <= maxTries && !won; attempt++) {
        shop();
        final seed = runSeed * 100003 + level.id * 101 + attempt;
        if (attempt == 1) {
          run.gearAt[level.id] = (setup: s.shopSetup, modifiers: s.bakeModifiers, decorTip: s.decorTipBonusPct);
        }
        var boosters = const <BoosterId>{};
        if (boosterPolicy != null && GameState.boostersAvailableFor(level.id)) {
          final pick = boosterPolicy(s, level, attempt);
          if (pick.isNotEmpty && s.consumeBoosters(pick)) boosters = pick;
        }
        stat.boostersUsed += boosters.length;
        final session = LevelSession(
          level: level,
          defaults: levels.defaults,
          modifiers: s.bakeModifiers,
          decorTipBonusPct: s.decorTipBonusPct,
          setup: s.shopSetup,
          boosters: boosters,
          random: math.Random(seed),
        );
        final r = LevelBot(skill, random: math.Random(seed * 7919)).play(session);
        session.dispose();
        final gemsBefore = s.gems;
        s.applyLevelResult(r);
        s.claimAllSeason();
        stat.gems += s.gems - gemsBefore;
        stat.plays++;
        stat.coins += r.coins;
        stat.served += r.served;
        stat.staffSales += r.staffSales;
        won = r.won;
        if (won) stat.stars = r.stars;
        if (attempt == 1) {
          stat.firstWin = won;
          stat.firstGoalValue = r.goalValue;
        }
      }
      if (!won) {
        stat.stuck = true;
        stat.stars = 1;
        final gemsBefore = s.gems;
        s.applyLevelResult(
          LevelResult(
            levelId: level.id,
            won: true,
            stars: 1,
            coins: 0,
            served: 0,
            lost: 0,
            specialsDone: 0,
            bestCombo: 0,
            perfectBakes: 0,
            recipeStars: const {},
            goalValue: level.goal.target,
          ),
        );
        s.claimAllSeason();
        stat.gems += s.gems - gemsBefore;
      }
      if (offlineHours > 0) {
        awayClock = awayClock.add(Duration(minutes: (offlineHours * 60).round()));
        s.refreshOffline(awayClock);
        stat.offlineCoins = s.claimOffline();
      }
      stat.coinsAfter = s.coins;
      stat.totalStarsAfter = s.totalStars;
    }
    shop();
    run.coinsLeft = s.coins;
    run.gemsLeft = s.gems;
    return run;
  }

  /// Bộ đồ "kỳ vọng" lúc bắt đầu level [levelId]: đã qua L1..levelId−1 và đã mua mọi mở rộng + cấp thiết bị (kể cả lò
  /// vùng vàng / dụng cụ) mở từ level ≤ levelId − 1 − [lag] (mua trong [lag] level sau khi khả dụng). Không trang trí.
  ({ShopSetup setup, BakeModifiers modifiers}) expectedGear(int levelId, {int lag = 1}) {
    final s = freshState();
    for (var id = 1; id < levelId; id++) {
      s.applyLevelResult(
        LevelResult(
          levelId: id,
          won: true,
          stars: 1,
          coins: 0,
          served: 0,
          lost: 0,
          specialsDone: 0,
          bestCombo: 0,
          perfectBakes: 0,
          recipeStars: const {},
          goalValue: 1,
        ),
      );
    }
    final limit = levelId - 1 - lag;
    s.addCoins(1 << 30);
    for (final u in s.unlockConfig.unlocks) {
      if (u.level <= limit && !u.comingSoon) s.buyUnlock(u.id);
    }
    for (final eq in s.unlockConfig.equipment) {
      while (s.equipmentTier(eq.id) < eq.maxTier && eq.tier(s.equipmentTier(eq.id) + 1).level <= limit) {
        s.buyEquipment(eq.id);
      }
    }
    return (setup: s.shopSetup, modifiers: s.bakeModifiers);
  }
}
