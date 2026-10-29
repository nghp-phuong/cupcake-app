/// Thanh nướng: nhấn giữ thì chạy 0 → 1 trong [fullSeconds] giây; tới 1.0 thì tự thả (cháy).
class BakeMeter {
  BakeMeter({this.fullSeconds = 3.0});

  final double fullSeconds;

  double _value = 0;
  bool _holding = false;
  double? _release;

  /// Vị trí hiện tại 0..1.
  double get value => _value;
  bool get holding => _holding;

  /// Vị trí thả tay (null khi chưa thả).
  double? get release => _release;
  bool get released => _release != null;

  void press() {
    if (released) return;
    _holding = true;
  }

  /// Gọi mỗi khung hình. Trả true nếu vừa tự thả do giữ tới 1.0.
  bool tick(double dt) {
    if (!_holding || released) return false;
    _value = (_value + dt / fullSeconds).clamp(0.0, 1.0);
    if (_value >= 1.0) {
      _holding = false;
      _release = 1.0;
      return true;
    }
    return false;
  }

  /// Nhấc tay. Chạm quá ngắn (< [minRelease]) coi như chạm nhầm: không ghi, lần nhấn sau chạy tiếp.
  void lift({double minRelease = 0.04}) {
    if (!_holding || released) return;
    _holding = false;
    if (_value >= minRelease) _release = _value;
  }
}

/// Độ chín để vẽ bánh (0 sống, 1 vàng, 2 cháy) từ vị trí thanh [p] và mục tiêu [target].
double bakedVisual(double p, double target) {
  if (target <= 0) return 1 + p;
  if (p <= target) return p / target;
  final rest = 1 - target;
  return rest <= 0 ? 2 : 1 + ((p - target) / rest).clamp(0.0, 1.0);
}
