import 'ids.dart';

/// Công thức một món (dữ liệu tĩnh, xem `Catalog.recipes`).
class Recipe {
  const Recipe({
    required this.id,
    required this.unlockLevel,
    required this.price,
    required this.cost,
    required this.mould,
    required this.batter,
    required this.frostings,
    required this.toppings,
    required this.mixTurns,
    required this.bakeTarget,
    required this.box,
  });

  final RecipeId id;
  final int unlockLevel;

  /// Xu khi 4★ (hệ số 1.0).
  final int price;

  /// Chi phí nguyên liệu, trừ mỗi lần phục vụ.
  final int cost;
  final MouldType mould;
  final BatterType batter;

  /// Phần tử đầu = mặc định.
  final List<FrostingId> frostings;

  /// Topping được phép gọi.
  final List<ToppingId> toppings;

  /// Số vòng trộn mục tiêu.
  final int mixTurns;

  /// Vị trí mục tiêu trên thanh nướng 0..1.
  final double bakeTarget;

  /// Hộp chuẩn (khách VIP luôn đòi `BoxType.gift`).
  final BoxType box;
}
