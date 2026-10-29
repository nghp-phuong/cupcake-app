import 'catalog.dart';
import 'models/day_summary.dart';
import 'models/ids.dart';
import 'models/upgrade.dart';

export 'models/upgrade.dart';

/// Số liệu kinh tế và các hàm thuần (không trạng thái).
abstract final class Economy {
  static const maxLevel = 15;
  static const startCoins = 100, startGems = 5;
  static const dayBonusXp = 30;
  static const maxRewardedPerDay = 8; // theo ngày lịch thật
  static const interstitialMinDay = 4; // ngày game đã hoàn thành
  static const interstitialGapDays = 2;
  static const decorTipCapPct = 30;
  static const masteryGemReward = 5;
  static const freeGemPerAd = 1;
  static const levelUpGems = 2;

  /// Quà vuốt ve mèo Mochi (ngày mưa); lần vuốt ve đầu tiên trong đời game thêm đá quý.
  static const mochiPetCoins = 30, mochiFirstPetGems = 5;

  /// Hệ số tiền trả theo số sao.
  static const Map<int, double> payMult = {1: 0.5, 2: 0.7, 3: 0.85, 4: 1.0, 5: 1.1};

  /// Tỉ lệ tip theo số sao (dưới 3★ không tip).
  static const Map<int, double> tipRate = {3: 0.10, 4: 0.20, 5: 0.35};

  /// Hệ số tip theo loại khách.
  static const Map<CustomerKind, double> tipKindMult = {
    CustomerKind.regular: 1.0,
    CustomerKind.friend: 1.5,
    CustomerKind.vip: 2.0,
  };

  /// Tổng XP tích luỹ để đạt [level] (cấp 1 → 0). XP cho cấp kế = 80 + 40·(cấp−1).
  static int xpToReachLevel(int level) {
    final n = level.clamp(1, maxLevel) - 1;
    return 80 * n + 20 * n * (n - 1);
  }

  /// Cấp tiệm 1..15 ứng với tổng XP.
  static int levelForXp(int xp) {
    var level = 1;
    while (level < maxLevel && xp >= xpToReachLevel(level + 1)) {
      level++;
    }
    return level;
  }

  static int customersPerDay(int level) {
    if (level >= 10) return 6;
    if (level >= 4) return 5;
    return 4;
  }

  static double vipChance(int level) {
    if (level >= 9) return 0.30;
    if (level >= 7) return 0.20;
    return 0;
  }

  static int levelUpCoins(int newLevel) => 50 * newLevel;

  /// Lò nướng, index 0 = cấp 1 (có sẵn).
  static const List<OvenTier> ovenTiers = [
    OvenTier(level: 1, cost: 0, requiredShopLevel: 1, perfectHalfWidth: 0.05, okHalfWidth: 0.15),
    OvenTier(level: 2, cost: 300, requiredShopLevel: 2, perfectHalfWidth: 0.06, okHalfWidth: 0.16),
    OvenTier(level: 3, cost: 800, requiredShopLevel: 4, perfectHalfWidth: 0.07, okHalfWidth: 0.17),
    OvenTier(level: 4, cost: 1800, requiredShopLevel: 7, perfectHalfWidth: 0.08, okHalfWidth: 0.18),
    OvenTier(level: 5, cost: 3500, requiredShopLevel: 10, perfectHalfWidth: 0.10, okHalfWidth: 0.20),
  ];

  /// Dụng cụ, index 0 = cấp 1 (có sẵn). whisk → mixPerfectBand, pipingBag → frostBrushRadius,
  /// tongs → toppingSnapRadius.
  static const Map<ToolId, List<ToolTier>> toolTiers = {
    ToolId.whisk: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 1, value: 0.10),
      ToolTier(level: 2, cost: 250, requiredShopLevel: 3, value: 0.15),
      ToolTier(level: 3, cost: 900, requiredShopLevel: 6, value: 0.20),
    ],
    ToolId.pipingBag: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 1, value: 22),
      ToolTier(level: 2, cost: 250, requiredShopLevel: 3, value: 27),
      ToolTier(level: 3, cost: 900, requiredShopLevel: 7, value: 32),
    ],
    ToolId.tongs: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 1, value: 0),
      ToolTier(level: 2, cost: 200, requiredShopLevel: 2, value: 16),
      ToolTier(level: 3, cost: 700, requiredShopLevel: 5, value: 32),
    ],
  };

  static int get maxOvenLevel => ovenTiers.length;
  static int maxToolLevel(ToolId id) => toolTiers[id]!.length;

  /// Những gì mở ở đúng [level] (dùng cho màn tổng kết). Tính từ dữ liệu Catalog/Economy nên luôn
  /// khớp bảng: món, topping, khách VIP lần đầu, nâng cấp, trang trí, thêm khách mỗi ngày.
  static List<Unlock> unlocksAtLevel(int level) {
    final result = <Unlock>[
      for (final r in Catalog.recipes)
        if (r.unlockLevel == level) Unlock(UnlockKind.recipe, recipe: r.id),
      for (final t in ToppingId.values)
        if (Catalog.toppingUnlockLevel[t] == level) Unlock(UnlockKind.topping, topping: t),
    ];
    if (level <= 1) return result;
    if (vipChance(level) > 0 && vipChance(level - 1) == 0) {
      result.add(const Unlock(UnlockKind.vipGuests));
    }
    final newUpgrade = ovenTiers.any((t) => t.level > 1 && t.requiredShopLevel == level) ||
        toolTiers.values.any((tiers) => tiers.any((t) => t.level > 1 && t.requiredShopLevel == level));
    if (newUpgrade) result.add(const Unlock(UnlockKind.upgrade));
    if (Catalog.decor.any((d) => d.unlockLevel == level)) result.add(const Unlock(UnlockKind.decor));
    if (customersPerDay(level) > customersPerDay(level - 1)) result.add(const Unlock(UnlockKind.moreCustomers));
    return result;
  }
}
