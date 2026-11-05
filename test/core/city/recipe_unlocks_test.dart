import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/city/recipe_unlocks.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

void main() {
  test('§7-1 bảng §4: đủ 18 món, cấp tăng dần theo thứ tự Catalog', () {
    expect(Catalog.recipes.length, 18);
    final levels = [
      for (final r in Catalog.recipes) RecipeUnlocks.recipeLevel(r.id),
    ];
    expect(levels, [
      1,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      11,
      12,
      14,
      16,
      18,
      20,
      23,
      26,
    ]);
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i], greaterThanOrEqualTo(levels[i - 1]), reason: '$i');
    }
    // Bảng tăng dần ở cả hai cột; mọi màn v2 của Catalog đều có trong bảng.
    final stages = RecipeUnlocks.maiLevelForStage.keys.toList();
    for (var i = 1; i < stages.length; i++) {
      expect(stages[i], greaterThan(stages[i - 1]));
      expect(
        RecipeUnlocks.maiLevelForStage[stages[i]],
        greaterThan(RecipeUnlocks.maiLevelForStage[stages[i - 1]]!),
      );
    }
    for (final r in Catalog.recipes) {
      expect(RecipeUnlocks.maiLevelForStage, contains(r.unlockLevel));
    }
    for (final l in Catalog.toppingUnlockLevel.values) {
      expect(RecipeUnlocks.maiLevelForStage, contains(l));
    }
    // Cấp 10 và 15 không mở món (hai cấp này mở lô).
    expect(RecipeUnlocks.newRecipes(9, 10), isEmpty);
    expect(RecipeUnlocks.newRecipes(14, 15), isEmpty);
  });

  test('§7-1 cấp 1 có vani + choco; cấp 30 mở đủ', () {
    expect(RecipeUnlocks.recipesAt(1), [
      RecipeId.cupcakeVanilla,
      RecipeId.cupcakeChocolate,
    ]);
    expect(RecipeUnlocks.recipesAt(PlayerLevel.maxLevel), [
      for (final r in Catalog.recipes) r.id,
    ]);
    expect(RecipeUnlocks.toppingsAt(PlayerLevel.maxLevel), ToppingId.values);
    expect(RecipeUnlocks.toppingsAt(1), [
      ToppingId.sprinkles,
      ToppingId.strawberry,
      ToppingId.cherry,
      ToppingId.chocolateChips,
    ]);
  });

  test('§4 cấp mở topping', () {
    final expected = {
      ToppingId.blueberry: 2,
      ToppingId.mintLeaf: 3,
      ToppingId.sugarPearl: 5,
      ToppingId.candle: 9,
      ToppingId.almondFlakes: 11,
      ToppingId.powderedSugar: 11,
      ToppingId.kiwi: 18,
      ToppingId.sesame: 23,
      ToppingId.meringueMushroom: 26,
    };
    for (final t in ToppingId.values) {
      expect(RecipeUnlocks.toppingLevel(t), expected[t] ?? 1, reason: t.name);
    }
  });

  test(
    '§7-1 topping mở ở recipeLevel(r) khớp station_setup (thang v2: toppingUnlockLevel ≤ unlockLevel)',
    () {
      for (final r in Catalog.recipes) {
        // Bản sao điều kiện `unlocked` của toppingTrays (lib/game/logic/station_setup.dart).
        final v2 = [
          for (final t in ToppingId.values)
            if ((Catalog.toppingUnlockLevel[t] ?? 1) <= r.unlockLevel) t,
        ];
        expect(
          RecipeUnlocks.toppingsAt(RecipeUnlocks.recipeLevel(r.id)),
          v2,
          reason: r.id.name,
        );
        // Món đã mở luôn có ít nhất một topping của nó đã mở (OrderGenerator không phải lấy topping khoá).
        expect(
          r.toppings.any(
            (t) =>
                RecipeUnlocks.toppingLevel(t) <=
                RecipeUnlocks.recipeLevel(r.id),
          ),
          isTrue,
          reason: r.id.name,
        );
      }
    },
  );

  test('§7-1 newRecipes / newToppings', () {
    expect(RecipeUnlocks.newRecipes(4, 5), [RecipeId.macaron]);
    expect(RecipeUnlocks.newToppings(4, 5), [ToppingId.sugarPearl]);
    expect(RecipeUnlocks.newRecipes(5, 5), isEmpty);
    expect(RecipeUnlocks.newRecipes(1, 3), [
      RecipeId.muffinBlueberry,
      RecipeId.eggTart,
    ]);
    expect(RecipeUnlocks.newToppings(8, 11), [
      ToppingId.candle,
      ToppingId.almondFlakes,
      ToppingId.powderedSugar,
    ]);
    expect(RecipeUnlocks.newRecipes(0, 1), [
      RecipeId.cupcakeVanilla,
      RecipeId.cupcakeChocolate,
    ]);
  });

  test('thang v2 không đổi', () {
    expect(
      [for (final r in Catalog.recipes) r.unlockLevel],
      [
        1, 1, 2, 3, 4, 5, 6, 8, 10, 12, 21, 24, 27, 31, 34, 38, 43, 47, //
      ],
    );
    expect(Catalog.toppingUnlockLevel[ToppingId.candle], 12);
  });
}
