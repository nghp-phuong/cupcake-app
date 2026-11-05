/// Cảnh chứa lớp ca bán (Dart thuần, không import thermion): lớp 2D gọi để dừng / chạy cảnh 3D và đóng lớp.
library;

abstract interface class ShiftLayerHost {
  /// true khi bắt đầu làm bánh (dừng vẽ 3D), false khi xong (chạy lại).
  void setBaking(bool on);

  /// Gỡ lớp ca, trả Mai về điều khiển bình thường.
  void close();
}
