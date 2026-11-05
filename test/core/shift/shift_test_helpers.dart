import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';

/// Số đo thô cho [order] mà `Scoring.evaluate` chấm đúng [stars] sao (1..5), không phụ thuộc món:
/// 5★ mọi trạm hoàn hảo; 4★ kem phủ 60% (q ≈ 0,875); 3★ kem 30% + sai hộp (q ≈ 0,68); 2★ thêm không topping
/// (q ≈ 0,43); 1★ thêm nướng cháy (q ≈ 0,13).
BakeOutcome outcomeFor(Order order, int stars) {
  final r = order.recipeData;
  final placed = <ToppingId, int>{};
  for (final t in order.toppings) {
    placed[t.topping] = (placed[t.topping] ?? 0) + t.count;
  }
  final wrongBox = BoxType.values.firstWhere((b) => b != order.box);
  return BakeOutcome(
    wrongMouldDrops: 0,
    mixTurns: r.mixTurns.toDouble(),
    bakeRelease: stars <= 1 ? 1.0 : r.bakeTarget,
    frostCoverage: switch (stars) {
      5 => 1.0,
      4 => 0.6,
      _ => 0.3,
    },
    toppingsPlaced: stars <= 2 ? const {} : placed,
    boxChosen: stars <= 3 ? wrongBox : order.box,
  );
}
