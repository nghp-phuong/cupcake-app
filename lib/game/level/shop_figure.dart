import 'dart:ui' as ui;

/// Một nhân vật vẽ bằng ảnh trong sân tiệm (khách hoặc nhân viên). Mọi hình xếp độ sâu chung (cùng bàn ghế / cây):
/// [depth] nhỏ (xa) vẽ trước; bằng nhau thì [depthKey] nhỏ vẽ trước (nhân viên mang khoá âm → khách đứng cạnh che
/// lên nhân viên).
abstract class ShopFigure {
  /// Tỉ lệ vẽ (khung cao `customerHeight × scale`).
  double scale = 1;

  /// Độ sâu để xếp thứ tự vẽ; khách = [scale], nhân viên có thể khác (thu ngân đứng sau cây trên quầy).
  double depth = 1;
  int depthKey = 0;

  // Hình học khung này (tính ở update, dùng cho vẽ + chạm).
  double drawX = 0, top = 0, height = 0;
  double alpha = 1;

  /// Ảnh của nét mặt hiện tại (null → chưa nạp / thiếu: không vẽ hình, không bao giờ vẽ nhân vật bằng code).
  ui.Image? get image;

  static int byDepth(ShopFigure a, ShopFigure b) {
    final d = a.depth.compareTo(b.depth);
    return d != 0 ? d : a.depthKey.compareTo(b.depthKey);
  }
}
