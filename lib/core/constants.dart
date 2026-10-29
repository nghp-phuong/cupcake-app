import 'package:flutter/painting.dart';

/// Khung tham chiếu: mọi màn bố cục theo 1280×720 (xem `RefFrame`).
const Size kRefSize = Size(1280, 720);

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
