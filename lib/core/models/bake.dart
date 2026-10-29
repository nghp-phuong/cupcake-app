import 'ids.dart';

/// Thông số do nâng cấp ảnh hưởng — game dùng để vẽ vùng/brush, Scoring dùng để chấm.
class BakeModifiers {
  const BakeModifiers({
    required this.bakePerfectHalfWidth,
    required this.bakeOkHalfWidth,
    required this.mixPerfectBand,
    required this.frostBrushRadius,
    required this.toppingSnapRadius,
  });

  /// 0.05..0.10 (theo lò).
  final double bakePerfectHalfWidth;

  /// 0.15..0.20.
  final double bakeOkHalfWidth;

  /// 0.10..0.20 (theo phới).
  final double mixPerfectBand;

  /// px tham chiếu 22..32 (theo túi kem).
  final double frostBrushRadius;

  /// px tham chiếu 0..32 (theo kẹp).
  final double toppingSnapRadius;

  static const base = BakeModifiers(
    bakePerfectHalfWidth: .05,
    bakeOkHalfWidth: .15,
    mixPerfectBand: .10,
    frostBrushRadius: 22,
    toppingSnapRadius: 0,
  );

  @override
  bool operator ==(Object other) =>
      other is BakeModifiers &&
      other.bakePerfectHalfWidth == bakePerfectHalfWidth &&
      other.bakeOkHalfWidth == bakeOkHalfWidth &&
      other.mixPerfectBand == mixPerfectBand &&
      other.frostBrushRadius == frostBrushRadius &&
      other.toppingSnapRadius == toppingSnapRadius;

  @override
  int get hashCode =>
      Object.hash(bakePerfectHalfWidth, bakeOkHalfWidth, mixPerfectBand, frostBrushRadius, toppingSnapRadius);
}

/// Số đo THÔ do game trả về sau 6 trạm. Game không tự chấm điểm.
class BakeOutcome {
  const BakeOutcome({
    required this.wrongMouldDrops,
    required this.mixTurns,
    required this.bakeRelease,
    required this.frostCoverage,
    required this.toppingsPlaced,
    required this.boxChosen,
  });

  /// Số lần thả sai khuôn.
  final int wrongMouldDrops;

  /// Số vòng đã trộn (thực).
  final double mixTurns;

  /// Vị trí thả tay 0..1 (giữ tới 1.0 = tự thả, cháy).
  final double bakeRelease;

  /// 0..1 tỉ lệ điểm đường gợi ý được phủ.
  final double frostCoverage;

  /// CHỈ topping nằm trên bánh (đã tính snap).
  final Map<ToppingId, int> toppingsPlaced;
  final BoxType boxChosen;
}

class StationScore {
  const StationScore(this.station, this.score, this.issue);

  final StationId station;

  /// 0..1.
  final double score;
  final StationIssue issue;

  @override
  String toString() => 'StationScore(${station.name}: ${score.toStringAsFixed(3)}, ${issue.name})';
}

class BakeResult {
  const BakeResult({
    required this.stations,
    required this.quality,
    required this.stars,
    required this.payment,
    required this.tip,
    required this.cost,
    required this.xp,
    required this.praise,
    required this.complaint,
    required this.weakest,
  });

  /// Đủ 6 trạm.
  final Map<StationId, StationScore> stations;

  /// 0..1.
  final double quality;

  /// 1..5.
  final int stars;

  /// Xu khách trả (chưa trừ cost).
  final int payment;
  final int tip;

  /// = recipe.cost.
  final int cost;
  final int xp;

  /// Khen trạm tốt nhất (allGood nếu 5★ và không có complaint).
  final FeedbackKey praise;

  /// Chê trạm yếu nhất, null nếu trạm yếu nhất >= 0.9.
  final FeedbackKey? complaint;
  final StationId weakest;

  int get net => payment + tip - cost;

  /// "Nướng hoàn hảo" (nhiệm vụ) = điểm trạm bake == 1.0.
  bool get isPerfectBake => (stations[StationId.bake]?.score ?? 0) >= 1.0;
}
