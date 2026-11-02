import 'package:flutter/painting.dart';

/// Chiều cao khung tham chiếu (cố định); chiều rộng co giãn [kRefMinWidth]–[kRefMaxWidth] theo tỉ lệ máy (xem `RefFrame`).
const double kRefHeight = 720;

/// Rộng tối thiểu của khung = rộng vùng nội dung ở giữa (máy 16:9 và hẹp hơn).
const double kRefMinWidth = 1280;

/// Rộng tối đa của khung (20:9); máy dài hơn letterbox hai bên.
const double kRefMaxWidth = 1600;

/// Vùng nội dung 1280×720: mọi màn bố cục theo toạ độ này (xem `RefFrame`, `RefCenter`).
const Size kRefSize = Size(kRefMinWidth, kRefHeight);

abstract final class AppColors {
  static const cream = Color(0xFFFFF4E6);
  static const strawberry = Color(0xFFF49AB0);
  static const mint = Color(0xFFA8DCC8);
  static const butter = Color(0xFFFFD27A);
  static const caramel = Color(0xFFB9805A);
  static const chocolate = Color(0xFF5A3E36); // màu chữ
  static const good = Color(0xFF7BC47F);
  static const bad = Color(0xFFE86A5C);
}
