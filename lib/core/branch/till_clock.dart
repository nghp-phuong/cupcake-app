/// Đồng hồ két (GĐ4 V3, docs/v3/city-gd4-spec.md §2 "Thời gian"): chống chỉnh giờ máy. Mốc `mark` là ms epoch (UTC)
/// đã tính tới; trong phiên cộng theo đồng hồ đơn điệu, lúc mở / quay lại app mới so với giờ máy.
library;

enum ClockAnomaly { none, first, behind, rescued }

class ClockStep {
  /// Số ms được cộng vào sản xuất; mốc `mark` mới.
  final int creditMs, markMs;
  final ClockAnomaly anomaly;

  const ClockStep({required this.creditMs, required this.markMs, this.anomaly = ClockAnomaly.none});

  ClockStep copyWith({int? creditMs, int? markMs, ClockAnomaly? anomaly}) => ClockStep(
    creditMs: creditMs ?? this.creditMs,
    markMs: markMs ?? this.markMs,
    anomaly: anomaly ?? this.anomaly,
  );

  Map<String, Object?> toJson() => {'creditMs': creditMs, 'markMs': markMs, 'anomaly': anomaly.name};

  @override
  bool operator ==(Object other) =>
      other is ClockStep && other.creditMs == creditMs && other.markMs == markMs && other.anomaly == anomaly;

  @override
  int get hashCode => Object.hash(creditMs, markMs, anomaly);
}

abstract final class TillClock {
  static const rollbackTolerance = Duration(minutes: 10), rescueAfter = Duration(hours: 72);

  /// Trần của mốc: 2^53 − 1 (số nguyên lớn nhất biểu diễn chính xác trên web).
  static const _maxMs = 9007199254740991;

  /// Mở app / quay lại app: so giờ máy với mốc (d = giờ máy − mốc).
  /// - mốc = 0 → `first`, không cộng, mốc = giờ máy;
  /// - d ≥ 0 → cộng d (trần két tự kẹp), mốc = giờ máy;
  /// - −10 phút ≤ d < 0 → không cộng, giữ mốc;
  /// - −72 giờ ≤ d < −10 phút → `behind`, không cộng, giữ mốc;
  /// - d < −72 giờ → `rescued`, không cộng, mốc = giờ máy.
  ///
  /// Giờ máy kẹp [0, 2^53 − 1] (trước 1970 → 0).
  static ClockStep wall({required int markMs, required int wallMs}) {
    final now = wallMs.clamp(0, _maxMs);
    if (markMs <= 0) return ClockStep(creditMs: 0, markMs: now, anomaly: ClockAnomaly.first);
    final d = now - markMs;
    if (d >= 0) return ClockStep(creditMs: d, markMs: now);
    if (d >= -rollbackTolerance.inMilliseconds) return ClockStep(creditMs: 0, markMs: markMs);
    if (d >= -rescueAfter.inMilliseconds) {
      return ClockStep(creditMs: 0, markMs: markMs, anomaly: ClockAnomaly.behind);
    }
    return ClockStep(creditMs: 0, markMs: now, anomaly: ClockAnomaly.rescued);
  }

  /// Trong phiên: cộng độ chênh của đồng hồ đơn điệu (mốc += Δ). Mốc chưa đặt (0) hoặc Δ ≤ 0 → không cộng.
  static ClockStep mono({required int markMs, required int monoDeltaMs}) {
    if (markMs <= 0 || monoDeltaMs <= 0) return ClockStep(creditMs: 0, markMs: markMs < 0 ? 0 : markMs);
    final next = markMs + monoDeltaMs;
    return ClockStep(creditMs: monoDeltaMs, markMs: next > _maxMs ? _maxMs : next);
  }
}
