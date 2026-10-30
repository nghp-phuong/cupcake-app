import 'models/ids.dart';
import 'models/upgrade.dart';

export 'models/upgrade.dart';

/// Số liệu kinh tế và các hàm thuần (không trạng thái).
abstract final class Economy {
  static const maxLevel = 15;
  static const startCoins = 100, startGems = 5;
  static const dayBonusXp = 30;
  static const maxRewardedPerDay = 12; // theo ngày lịch thật, chung mọi chỗ (GĐ6)

  /// Interstitial (GĐ6 §3): chỉ khi rời màn kết quả, tối đa 1 lần mỗi [interstitialEveryPlays] lượt chơi xong, chỉ từ
  /// khi đã qua level [interstitialAfterLevel].
  static const interstitialEveryPlays = 3;
  static const interstitialAfterLevel = 5;

  /// Kim cương kiếm trong game (GĐ6 §6, cân ở `test/core/booster_balance_test.dart`): lần đầu đạt 3★ một level, lần đầu
  /// qua level cuối một chương.
  static const levelThreeStarGems = 1;
  static const chapterCompleteGems = 12;
  static const decorTipCapPct = 30;

  /// Trần tổng % tip cộng thêm của một lượt chơi: trang trí (≤ [decorTipCapPct]) + mở rộng tiệm (`tipPct`).
  static const tipBonusCapPct = 40;
  static const masteryGemReward = 2;
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

  /// Làm tròn tới bội 50 gần nhất (giá Bí quyết của bà, GĐ8).
  static int round50(num v) => (v / 50).round() * 50;

  /// Tổng XP tích luỹ để đạt [level] (cấp 1 → 0). XP cho cấp kế = 80 + 40·(cấp−1).
  static int xpToReachLevel(int level) {
    final n = level.clamp(1, maxLevel) - 1;
    return 80 * n + 20 * n * (n - 1);
  }

  /// Cấp tiệm 1..15 ứng với tổng XP (V1, không còn dùng trong V2).
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

  /// Lò vùng vàng (thiết bị `goldenOven`), index 0 = cấp 1 (có sẵn). Bảng dự phòng khi unlocks.json không có
  /// `goldenOven`; `cost` / `requiredShopLevel` (= level phải qua) là bản sao của unlocks.json (test kiểm khớp).
  static const List<OvenTier> ovenTiers = [
    OvenTier(level: 1, cost: 0, requiredShopLevel: 0, perfectHalfWidth: 0.05, okHalfWidth: 0.15),
    OvenTier(level: 2, cost: 500, requiredShopLevel: 2, perfectHalfWidth: 0.06, okHalfWidth: 0.16),
    OvenTier(level: 3, cost: 900, requiredShopLevel: 6, perfectHalfWidth: 0.07, okHalfWidth: 0.17),
    OvenTier(level: 4, cost: 1700, requiredShopLevel: 11, perfectHalfWidth: 0.08, okHalfWidth: 0.18),
    OvenTier(level: 5, cost: 2800, requiredShopLevel: 19, perfectHalfWidth: 0.10, okHalfWidth: 0.20),
  ];

  /// Dụng cụ (thiết bị `whisk` / `pipingBag` / `tongs`), index 0 = cấp 1 (có sẵn). whisk → mixPerfectBand,
  /// pipingBag → frostBrushRadius, tongs → toppingSnapRadius. Bảng dự phòng như [ovenTiers].
  static const Map<ToolId, List<ToolTier>> toolTiers = {
    ToolId.whisk: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 0, value: 0.10),
      ToolTier(level: 2, cost: 400, requiredShopLevel: 4, value: 0.15),
      ToolTier(level: 3, cost: 1600, requiredShopLevel: 13, value: 0.20),
    ],
    ToolId.pipingBag: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 0, value: 22),
      ToolTier(level: 2, cost: 800, requiredShopLevel: 6, value: 27),
      ToolTier(level: 3, cost: 1800, requiredShopLevel: 15, value: 32),
    ],
    ToolId.tongs: [
      ToolTier(level: 1, cost: 0, requiredShopLevel: 0, value: 0),
      ToolTier(level: 2, cost: 400, requiredShopLevel: 3, value: 16),
      ToolTier(level: 3, cost: 1400, requiredShopLevel: 10, value: 32),
    ],
  };

  static int get maxOvenLevel => ovenTiers.length;
  static int maxToolLevel(ToolId id) => toolTiers[id]!.length;
}
