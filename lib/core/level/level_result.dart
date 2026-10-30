import '../models/ids.dart';
import '../monetization/booster.dart';

/// Kết quả một lượt chơi level (`LevelSession.finish`). `GameState.applyLevelResult` cộng vào ván.
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.won,
    required this.stars,
    required this.coins,
    required this.served,
    required this.lost,
    required this.specialsDone,
    required this.bestCombo,
    required this.perfectBakes,
    required this.recipeStars,
    this.goalValue = 0,
    this.tips = 0,
    this.treatStars = 0,
    this.fiveStarTreats = 0,
    this.specialsMissed = 0,
    this.specialsGood = 0,
    this.timeAdded = false,
    this.staffSales = 0,
    this.staffBakes = 0,
    this.boosters = const {},
  });

  final int levelId;

  /// Đạt mốc 1★.
  final bool won;

  /// 0..3 sao level.
  final int stars;

  /// Xu kiếm trong màn (thua vẫn nhận).
  final int coins;

  /// Khách đã phục vụ (vãng lai + đặc biệt).
  final int served;

  /// Khách bỏ đi (hết kiên nhẫn) + quay đi vì hàng đầy.
  final int lost;
  final int specialsDone;
  final int bestCombo;

  /// Số mẻ (và đơn đặc biệt) nướng hoàn hảo.
  final int perfectBakes;

  /// Sao bánh (1..5) cao nhất đã làm của từng món trong màn (để tính thành thạo).
  final Map<RecipeId, int> recipeStars;

  /// Giá trị mục tiêu lúc kết thúc (cùng đơn vị với mốc sao).
  final int goalValue;

  /// Phần tip trong [coins].
  final int tips;

  /// Tổng sao bánh (1..5) của mọi bánh đã bán/phục vụ (nhiệm vụ earnStars).
  final int treatStars;

  /// Số bánh 5★ đã bán/phục vụ.
  final int fiveStarTreats;
  final int specialsMissed;

  /// Đơn đặc biệt đạt ≥3★ (mục tiêu `specialOrders`); [specialsDone] gồm cả đơn dưới 3★.
  final int specialsGood;

  /// Đã dùng +30 giây.
  final bool timeAdded;

  /// Lượt bán do nhân viên (thu ngân + phục vụ), đã gồm trong [served] / [coins].
  final int staffSales;

  /// Số mẻ thợ bánh cho vào tủ.
  final int staffBakes;

  /// Vật phẩm hỗ trợ đã dùng ở lượt này (thống kê / cân bằng).
  final Set<BoosterId> boosters;

  @override
  String toString() => 'LevelResult(L$levelId won=$won stars=$stars coins=$coins served=$served lost=$lost '
      'specials=$specialsDone combo=$bestCombo perfect=$perfectBakes staff=$staffSales/$staffBakes'
      '${boosters.isEmpty ? '' : ' boosters=${[for (final b in boosters) b.name]}'})';
}
