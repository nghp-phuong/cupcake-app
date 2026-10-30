import 'package:flutter/foundation.dart';

import 'booster.dart';

/// Một phần thưởng (bậc thẻ mùa, nội dung gói IAP): xu, kim cương, vật phẩm vào kho, khung chân dung trang trí.
@immutable
class Reward {
  const Reward({this.coins = 0, this.gems = 0, this.boosters = const {}, this.frame});

  static const none = Reward();

  final int coins;
  final int gems;

  /// Vật phẩm → số lượng cộng vào kho.
  final Map<BoosterId, int> boosters;

  /// Id khung chân dung trang trí (chỉ đổi hình) — `GameState.ownedFrames`; null = không có.
  final String? frame;

  bool get isEmpty => coins <= 0 && gems <= 0 && frame == null && !boosters.values.any((n) => n > 0);

  /// Tổng số vật phẩm.
  int get boosterTotal => boosters.values.fold(0, (a, b) => a + b);

  @override
  bool operator ==(Object other) =>
      other is Reward &&
      other.coins == coins &&
      other.gems == gems &&
      other.frame == frame &&
      mapEquals(other.boosters, boosters);

  @override
  int get hashCode => Object.hash(coins, gems, frame, Object.hashAllUnordered(boosters.entries.map((e) => (e.key, e.value))));

  @override
  String toString() => 'Reward(coins=$coins gems=$gems boosters=${{for (final e in boosters.entries) e.key.name: e.value}}'
      '${frame != null ? ' frame=$frame' : ''})';
}

/// Một bậc thẻ mùa. Bậc thứ k (1-based) đạt khi điểm mùa ≥ [points] (cộng dồn, tăng dần theo bậc).
@immutable
class SeasonTier {
  const SeasonTier({required this.points, this.free = Reward.none, this.premium = Reward.none});

  /// Điểm mùa cộng dồn cần để đạt bậc.
  final int points;

  /// Hàng thưởng miễn phí / cao cấp (cao cấp cần `GameState.seasonPremium`).
  final Reward free;
  final Reward premium;
}

/// Thẻ mùa (`monetization.json` mục `season`). Đang diễn ra khi `start ≤ bây giờ < end` (giờ máy).
@immutable
class SeasonData {
  const SeasonData({
    required this.id,
    required this.start,
    required this.end,
    required this.tiers,
    this.pointsPerNewStar = 10,
    this.pointsPerWin = 5,
    this.names = const {},
  });

  /// Id mùa — đổi id → `GameState` tự nhận thưởng còn chờ của mùa cũ rồi đặt lại phần mùa.
  final String id;
  final DateTime start;

  /// Hết mùa lúc này (không gồm thời điểm này).
  final DateTime end;

  /// Theo thứ tự bậc 1..N (điểm tăng dần).
  final List<SeasonTier> tiers;

  /// Mỗi sao **mới** của một level (kỷ lục tăng) được chừng này điểm.
  final int pointsPerNewStar;

  /// Mỗi lượt thắng được chừng này điểm.
  final int pointsPerWin;

  /// Tên mùa {"en", "vi"}.
  final Map<String, String> names;

  String name(String lang) => names[lang] ?? names['en'] ?? '';

  bool isActive(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  /// Thời gian còn lại (0 nếu đã hết).
  Duration timeLeft(DateTime now) => now.isBefore(end) ? end.difference(now) : Duration.zero;

  /// Số bậc đã đạt với [points] điểm (0..[tiers].length).
  int tierFor(int points) {
    var n = 0;
    for (final t in tiers) {
      if (points >= t.points) n++;
    }
    return n;
  }

  /// Bậc [tier] (1-based); null nếu ngoài khoảng.
  SeasonTier? tier(int tier) => tier >= 1 && tier <= tiers.length ? tiers[tier - 1] : null;
}

/// Thưởng thẻ mùa đã tự nhận khi mùa kết thúc (`GameState.seasonAutoClaim`) — UI thông báo rồi gọi
/// `GameState.ackSeasonAutoClaim`.
@immutable
class SeasonAutoClaim {
  const SeasonAutoClaim({
    required this.seasonId,
    this.coins = 0,
    this.gems = 0,
    this.boosters = const {},
    this.frames = const [],
  });

  final String seasonId;
  final int coins;
  final int gems;
  final Map<BoosterId, int> boosters;
  final List<String> frames;

  bool get isEmpty => coins <= 0 && gems <= 0 && frames.isEmpty && !boosters.values.any((n) => n > 0);

  @override
  String toString() => 'SeasonAutoClaim($seasonId coins=$coins gems=$gems '
      'boosters=${{for (final e in boosters.entries) e.key.name: e.value}} frames=$frames)';
}
