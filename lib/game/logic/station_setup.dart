import 'dart:math' as math;

import '../../core/catalog.dart';
import '../../core/models/ids.dart';
import '../../core/models/order.dart';

/// Random có seed theo đơn → cùng một đơn luôn có cùng bố trí (dễ test, làm lại không đổi chỗ).
math.Random seededRandom(Order order, [int salt = 0]) =>
    math.Random(order.id * 7919 + order.recipe.index * 131 + order.frosting.index * 17 + salt);

/// 4 khuôn: khuôn đúng + 3 khuôn khác ngẫu nhiên, trộn thứ tự.
///
/// Mồi chỉ lấy khuôn người chơi đã gặp khi làm món mở ở màn [unlockLevel] (`Catalog.isDecoyMould`): món chương 1–2
/// có đúng bộ mồi và chuỗi ngẫu nhiên như trước GĐ8 (khuôn mới nằm cuối enum nên bị lọc mà không đổi thứ tự).
List<MouldType> mouldChoices(MouldType correct, math.Random random, {int count = 4, int unlockLevel = 1}) {
  final others = MouldType.values.where((m) => m != correct && Catalog.isDecoyMould(m, unlockLevel)).toList()..shuffle(random);
  final out = [correct, ...others.take(count - 1)]..shuffle(random);
  return out;
}

/// 4 khay topping: các loại được gọi + loại mồi cho đủ [count].
///
/// Game không đọc `GameState`, nên "topping đã mở" được suy ra từ món: món đã mở nghĩa là cấp
/// tiệm ≥ `recipe.unlockLevel`, nên mọi topping có `toppingUnlockLevel` ≤ mức đó chắc chắn đã mở.
/// Ưu tiên mồi trong danh sách topping của món, rồi topping đã mở khác, thiếu nữa mới lấy bất kỳ.
List<ToppingId> toppingTrays(Order order, math.Random random, {int count = 4}) {
  final recipe = Catalog.recipe(order.recipe);
  final requested = <ToppingId>[];
  for (final t in order.toppings) {
    if (!requested.contains(t.topping)) requested.add(t.topping);
  }
  final out = [...requested];
  bool unlocked(ToppingId t) => (Catalog.toppingUnlockLevel[t] ?? 1) <= recipe.unlockLevel;
  final pools = [
    recipe.toppings.where((t) => unlocked(t)).toList()..shuffle(random),
    ToppingId.values.where((t) => unlocked(t)).toList()..shuffle(random),
    // Dự phòng cuối: mọi topping người chơi có thể đã gặp (không lộ topping chương sau).
    ToppingId.values.where((t) => Catalog.isDecoyTopping(t, recipe.unlockLevel)).toList()..shuffle(random),
  ];
  for (final pool in pools) {
    for (final t in pool) {
      if (out.length >= count) break;
      if (!out.contains(t)) out.add(t);
    }
  }
  return out..shuffle(random);
}

/// Thứ tự 3 hộp trên bàn (cố định cho dễ nhớ).
const List<BoxType> boxChoices = [BoxType.small, BoxType.cake, BoxType.gift];
