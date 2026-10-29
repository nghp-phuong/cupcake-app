import 'package:flutter/foundation.dart';

import '../catalog.dart';
import 'ids.dart';
import 'recipe.dart';

class ToppingRequest {
  const ToppingRequest(this.topping, this.count);

  final ToppingId topping;
  final int count;

  @override
  bool operator ==(Object other) => other is ToppingRequest && other.topping == topping && other.count == count;

  @override
  int get hashCode => Object.hash(topping, count);

  @override
  String toString() => 'ToppingRequest(${topping.name} x$count)';
}

class Order {
  const Order({
    required this.id,
    required this.recipe,
    required this.frosting,
    required this.toppings,
    required this.box,
    required this.line,
  });

  /// Số thứ tự trong ngày, 0-based.
  final int id;
  final RecipeId recipe;
  final FrostingId frosting;

  /// 1–2 loại, mỗi loại count 1–4.
  final List<ToppingRequest> toppings;
  final BoxType box;

  /// Câu gọi món.
  final OrderLineKind line;

  Recipe get recipeData => Catalog.recipe(recipe);

  @override
  bool operator ==(Object other) =>
      other is Order &&
      other.id == id &&
      other.recipe == recipe &&
      other.frosting == frosting &&
      listEquals(other.toppings, toppings) &&
      other.box == box &&
      other.line == line;

  @override
  int get hashCode => Object.hash(id, recipe, frosting, Object.hashAll(toppings), box, line);

  @override
  String toString() => 'Order(#$id ${recipe.name}, ${frosting.name}, $toppings, ${box.name}, ${line.name})';
}
