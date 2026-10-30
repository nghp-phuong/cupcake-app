import 'dart:math' as math;

import 'catalog.dart';
import 'economy.dart';
import 'models/customer.dart';
import 'models/ids.dart';
import 'models/order.dart';
import 'models/recipe.dart';
import 'models/story.dart';

/// Khách + đơn của một ngày.
class DayPlan {
  const DayPlan({required this.customers, required this.orders});

  final List<Customer> customers;
  final List<Order> orders;
}

/// Sinh khách và đơn (thuần, `Random` truyền vào → test được bằng seed).
class OrderGenerator {
  OrderGenerator(this.random);

  final math.Random random;

  /// Xác suất một bạn quen (đã giới thiệu) ghé ngẫu nhiên trong ngày.
  static const friendVisitChance = 0.2;

  /// Sinh cả ngày. [scene] = cảnh truyện chiếu hôm nay (nếu có `featuredFriend` → khách đầu là bạn đó).
  DayPlan generateDay({
    required int level,
    required List<RecipeId> unlockedRecipes,
    required List<ToppingId> unlockedToppings,
    required Set<StorySceneId> seenScenes,
    StoryScene? scene,
  }) {
    final count = Economy.customersPerDay(level);
    final customers = <Customer>[];
    final orders = <Order>[];

    // Bạn quen: ưu tiên bạn của cảnh truyện; nếu không, tối đa 1 bạn đã giới thiệu ghé với xác suất 20%.
    FriendId? friend;
    var friendSlot = -1;
    RecipeId? friendRecipe;
    List<ToppingRequest>? forced;
    if (scene?.featuredFriend != null) {
      friend = scene!.featuredFriend;
      friendSlot = 0;
      friendRecipe = scene.featuredRecipe;
      forced = scene.forcedToppings;
    } else {
      final known = [
        for (final f in FriendId.values)
          if (seenScenes.contains(Catalog.friendIntroScene[f])) f,
      ];
      if (known.isNotEmpty && random.nextDouble() < friendVisitChance) {
        friend = known[random.nextInt(known.length)];
        friendSlot = random.nextInt(count);
      }
    }

    for (var i = 0; i < count; i++) {
      final seed = random.nextInt(1 << 30);
      if (i == friendSlot && friend != null) {
        final customer = Customer(kind: CustomerKind.friend, friend: friend, appearanceSeed: seed);
        final recipe = friendRecipe != null && unlockedRecipes.contains(friendRecipe)
            ? friendRecipe
            : _friendRecipe(friend, unlockedRecipes);
        customers.add(customer);
        orders.add(makeOrder(
          id: i,
          customer: customer,
          recipe: recipe,
          level: level,
          unlockedToppings: unlockedToppings,
          forcedToppings: forced,
        ));
        continue;
      }
      final vip = random.nextDouble() < Economy.vipChance(level);
      final customer = Customer(kind: vip ? CustomerKind.vip : CustomerKind.regular, appearanceSeed: seed);
      customers.add(customer);
      orders.add(makeOrder(
        id: i,
        customer: customer,
        recipe: pickRecipe(unlockedRecipes),
        level: level,
        unlockedToppings: unlockedToppings,
      ));
    }
    return DayPlan(customers: List.unmodifiable(customers), orders: List.unmodifiable(orders));
  }

  RecipeId _friendRecipe(FriendId friend, List<RecipeId> unlocked) {
    RecipeId prefer(RecipeId wanted, RecipeId fallback) {
      if (unlocked.contains(wanted)) return wanted;
      if (unlocked.contains(fallback)) return fallback;
      return pickRecipe(unlocked);
    }

    return switch (friend) {
      FriendId.hoa => prefer(RecipeId.eggTart, RecipeId.cupcakeVanilla),
      FriendId.linh => prefer(RecipeId.macaron, RecipeId.muffinBlueberry),
      FriendId.kenji => pickRecipe(unlocked),
    };
  }

  /// Món mở mới nhất (cấp mở cao nhất) trọng số 3, các món khác 1.
  RecipeId pickRecipe(List<RecipeId> unlocked) {
    if (unlocked.isEmpty) return RecipeId.cupcakeVanilla;
    final newest = unlocked.map((id) => Catalog.recipe(id).unlockLevel).reduce(math.max);
    final weights = [for (final id in unlocked) Catalog.recipe(id).unlockLevel == newest ? 3 : 1];
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = random.nextInt(total);
    for (var i = 0; i < unlocked.length; i++) {
      roll -= weights[i];
      if (roll < 0) return unlocked[i];
    }
    return unlocked.last;
  }

  Order makeOrder({
    required int id,
    required Customer customer,
    required RecipeId recipe,
    required int level,
    required List<ToppingId> unlockedToppings,
    List<ToppingRequest>? forcedToppings,
    BoxType? box,
  }) {
    final data = Catalog.recipe(recipe);
    final frosting = data.frostings[random.nextInt(data.frostings.length)];
    final toppings = forcedToppings ?? _pickToppings(data, level, unlockedToppings);
    // [box] (đơn đặc biệt ghi rõ hộp) > VIP luôn đòi hộp quà > hộp chuẩn của món.
    box ??= customer.kind == CustomerKind.vip ? BoxType.gift : data.box;
    final line = switch (customer.kind) {
      CustomerKind.vip => OrderLineKind.vip,
      CustomerKind.friend => switch (customer.friend) {
          FriendId.hoa => OrderLineKind.hoa,
          FriendId.linh => OrderLineKind.linh,
          FriendId.kenji => OrderLineKind.kenji,
          null => OrderLineKind.generic1,
        },
      CustomerKind.regular => OrderLineKind.values[random.nextInt(6)], // generic1..6
    };
    return Order(id: id, recipe: recipe, frosting: frosting, toppings: toppings, box: box, line: line);
  }

  List<ToppingRequest> _pickToppings(Recipe data, int level, List<ToppingId> unlockedToppings) {
    var allowed = [for (final t in data.toppings) if (unlockedToppings.contains(t)) t];
    if (allowed.isEmpty) allowed = [data.toppings.first];
    final kinds = math.min(allowed.length, level < 5 ? 1 : (random.nextBool() ? 2 : 1));
    final pool = List<ToppingId>.of(allowed);
    final result = <ToppingRequest>[];
    for (var k = 0; k < kinds; k++) {
      final t = pool.removeAt(random.nextInt(pool.length));
      final maxCount = t == ToppingId.candle ? 3 : (level < 7 ? 3 : 4);
      result.add(ToppingRequest(t, 1 + random.nextInt(maxCount)));
    }
    return List.unmodifiable(result);
  }
}
