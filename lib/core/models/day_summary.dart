import 'bake.dart';
import 'customer.dart';
import 'ids.dart';
import 'order.dart';

class OrderRecord {
  const OrderRecord({required this.order, required this.customer, required this.result});

  final Order order;
  final Customer customer;
  final BakeResult result;
}

class Unlock {
  const Unlock(this.kind, {this.recipe, this.topping});

  final UnlockKind kind;

  /// != null khi kind == recipe.
  final RecipeId? recipe;

  /// != null khi kind == topping.
  final ToppingId? topping;

  @override
  bool operator ==(Object other) =>
      other is Unlock && other.kind == kind && other.recipe == recipe && other.topping == topping;

  @override
  int get hashCode => Object.hash(kind, recipe, topping);

  @override
  String toString() => 'Unlock(${kind.name} ${recipe?.name ?? topping?.name ?? ''})';
}

class DaySummary {
  const DaySummary({
    required this.dayNumber,
    required this.records,
    required this.revenue,
    required this.tips,
    required this.costs,
    required this.net,
    required this.xpGained,
    required this.dayBonusXp,
    required this.levelBefore,
    required this.levelAfter,
    required this.unlocks,
    this.isRainy = false,
  });

  final int dayNumber;
  final List<OrderRecord> records;

  /// Σ payment.
  final int revenue;
  final int tips;
  final int costs;
  final int net;

  /// Gồm cả dayBonusXp.
  final int xpGained;
  final int dayBonusXp;
  final int levelBefore;
  final int levelAfter;

  /// Gộp `Economy.unlocksAtLevel(levelBefore+1..levelAfter)`.
  final List<Unlock> unlocks;

  /// Ngày mưa → tổng kết hiện thêm dòng "Ngày mưa".
  final bool isRainy;

  bool get leveledUp => levelAfter > levelBefore;

  double get averageStars {
    if (records.isEmpty) return 0;
    final total = records.fold<int>(0, (sum, r) => sum + r.result.stars);
    return total / records.length;
  }
}
