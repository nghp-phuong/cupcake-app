import 'dart:math' as math;
import 'dart:ui';

/// Đếm số vòng trộn: mỗi lần con trỏ di chuyển TRONG vành tô (bán kính [innerRadius]..[outerRadius]
/// quanh [center]) thì cộng |Δgóc| / 2π. Điểm ngoài vành bị bỏ qua (và ngắt nét).
///
/// Tô nhìn nghiêng (mặt bột là elip dẹt): [yScale] < 1 → khoảng cách dọc được chia cho [yScale] trước khi
/// đo góc/bán kính, nên vành là elip và xoay theo hình elip vẫn tính đúng 1 vòng mỗi vòng.
class MixMeter {
  MixMeter({required this.center, this.innerRadius = 60, this.outerRadius = 220, this.yScale = 1});

  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final double yScale;

  double _turns = 0;
  double? _lastAngle;

  /// Tổng góc tích luỹ (rad, luôn dương — dù tay xoay chiều nào).
  double _angle = 0;

  /// Số vòng đã trộn (thực).
  double get turns => _turns;

  /// Góc tích luỹ có dấu (rad) — chỉ để vẽ xoáy bột quay theo tay.
  double get signedAngle => _angle;

  bool inRing(Offset p) {
    final d = Offset(p.dx - center.dx, (p.dy - center.dy) / yScale).distance;
    return d >= innerRadius && d <= outerRadius;
  }

  /// Bắt đầu nét (nhấn xuống).
  void start(Offset p) {
    _lastAngle = inRing(p) ? _angleOf(p) : null;
  }

  /// Con trỏ di chuyển tới [p]. Trả về số vòng vừa cộng thêm.
  double move(Offset p) {
    if (!inRing(p)) {
      _lastAngle = null;
      return 0;
    }
    final a = _angleOf(p);
    final last = _lastAngle;
    _lastAngle = a;
    if (last == null) return 0;
    var d = a - last;
    // Chuẩn hoá về (-π, π] để không bị nhảy khi qua mốc ±π.
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d <= -math.pi) {
      d += 2 * math.pi;
    }
    _angle += d;
    final add = d.abs() / (2 * math.pi);
    _turns += add;
    return add;
  }

  /// Nhấc tay.
  void end() => _lastAngle = null;

  double _angleOf(Offset p) => math.atan2((p.dy - center.dy) / yScale, p.dx - center.dx);
}
