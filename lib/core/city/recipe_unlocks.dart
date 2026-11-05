/// Mở món và topping theo cấp Mai (docs/v3/city-gd3-spec.md §4).
///
/// `Recipe.unlockLevel` và `Catalog.toppingUnlockLevel` vẫn theo thang màn v2 (các trạm dùng thang đó để chọn khuôn /
/// topping mồi), nên cấp Mai được ánh xạ qua bảng [RecipeUnlocks.maiLevelForStage] thay vì sửa thang v2.
library;

import '../catalog.dart';
import '../models/ids.dart';

abstract final class RecipeUnlocks {
  /// Màn v2 (`unlockLevel` / `toppingUnlockLevel`) → cấp Mai mở món / topping đó. Tăng dần theo cả hai cột.
  static const Map<int, int> maiLevelForStage = {
    1: 1,
    2: 2,
    3: 3,
    4: 4,
    5: 5,
    6: 6,
    8: 7,
    10: 8,
    12: 9,
    21: 11,
    24: 12,
    27: 14,
    31: 16,
    34: 18,
    38: 20,
    43: 23,
    47: 26,
  };

  /// Mọi màn dùng trong Catalog đều có trong bảng (test kiểm).
  static int _mai(int stage) => maiLevelForStage[stage]!;

  /// Cấp Mai mở món [id].
  static int recipeLevel(RecipeId id) => _mai(Catalog.recipe(id).unlockLevel);

  /// Cấp Mai mở topping [id].
  static int toppingLevel(ToppingId id) =>
      _mai(Catalog.toppingUnlockLevel[id] ?? 1);

  /// Món đã mở ở [maiLevel], theo thứ tự `Catalog.recipes`.
  static List<RecipeId> recipesAt(int maiLevel) => List.unmodifiable([
    for (final r in Catalog.recipes)
      if (recipeLevel(r.id) <= maiLevel) r.id,
  ]);

  /// Topping đã mở ở [maiLevel], theo thứ tự `ToppingId`.
  static List<ToppingId> toppingsAt(int maiLevel) => List.unmodifiable([
    for (final t in ToppingId.values)
      if (toppingLevel(t) <= maiLevel) t,
  ]);

  /// Món mở khi lên từ cấp [from] tới [to] (`from < cấp ≤ to`).
  static List<RecipeId> newRecipes(int from, int to) => List.unmodifiable([
    for (final r in Catalog.recipes)
      if (recipeLevel(r.id) > from && recipeLevel(r.id) <= to) r.id,
  ]);

  /// Topping mở khi lên từ cấp [from] tới [to] (`from < cấp ≤ to`).
  static List<ToppingId> newToppings(int from, int to) => List.unmodifiable([
    for (final t in ToppingId.values)
      if (toppingLevel(t) > from && toppingLevel(t) <= to) t,
  ]);
}
