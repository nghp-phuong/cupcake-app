import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

GameState _stateAtLevel(int level, {int coins = 0}) {
  final s = GameState.newGame(clock: _clock);
  s.addXp(Economy.xpToReachLevel(level));
  s.trySpendCoins(s.coins);
  s.addCoins(coins);
  return s;
}

void main() {
  test('bảng XP tích luỹ', () {
    const table = [0, 80, 200, 360, 560, 800, 1080, 1400, 1760, 2160, 2600, 3080, 3600, 4160, 4760];
    for (var l = 1; l <= 15; l++) {
      expect(Economy.xpToReachLevel(l), table[l - 1], reason: 'cấp $l');
    }
  });

  test('levelForXp', () {
    expect(Economy.levelForXp(0), 1);
    expect(Economy.levelForXp(79), 1);
    expect(Economy.levelForXp(80), 2);
    expect(Economy.levelForXp(199), 2);
    expect(Economy.levelForXp(200), 3);
    expect(Economy.levelForXp(4759), 14);
    expect(Economy.levelForXp(4760), 15);
    expect(Economy.levelForXp(99999), 15);
  });

  test('khách/ngày và VIP theo cấp', () {
    expect(Economy.customersPerDay(1), 4);
    expect(Economy.customersPerDay(3), 4);
    expect(Economy.customersPerDay(4), 5);
    expect(Economy.customersPerDay(9), 5);
    expect(Economy.customersPerDay(10), 6);
    expect(Economy.vipChance(6), 0);
    expect(Economy.vipChance(7), 0.20);
    expect(Economy.vipChance(9), 0.30);
  });

  test('addXp cộng thưởng lên cấp', () {
    final s = GameState.newGame(clock: _clock);
    final ups = s.addXp(200); // 1 → 3
    expect(ups, [2, 3]);
    expect(s.level, 3);
    expect(s.coins, Economy.startCoins + 100 + 150);
    expect(s.gems, Economy.startGems + 4);
    expect(s.xpIntoLevel, 0);
    expect(s.xpForNextLevel, 160);
    final max = _stateAtLevel(15);
    expect(max.level, 15);
    expect(max.xpForNextLevel, 0);
    expect(max.addXp(1000), isEmpty);
  });

  group('mua nâng cấp lò', () {
    test('ok', () {
      final s = _stateAtLevel(2, coins: 300);
      expect(s.buyOvenUpgrade(), PurchaseResult.ok);
      expect(s.ovenLevel, 2);
      expect(s.coins, 0);
      expect(s.bakeModifiers.bakePerfectHalfWidth, 0.06);
    });
    test('notEnoughCoins', () {
      final s = _stateAtLevel(2, coins: 299);
      expect(s.buyOvenUpgrade(), PurchaseResult.notEnoughCoins);
      expect(s.ovenLevel, 1);
      expect(s.coins, 299);
    });
    test('locked', () {
      final s = _stateAtLevel(1, coins: 5000);
      expect(s.buyOvenUpgrade(), PurchaseResult.locked);
    });
    test('maxed', () {
      final s = _stateAtLevel(10, coins: 100000);
      for (var i = 0; i < 4; i++) {
        expect(s.buyOvenUpgrade(), PurchaseResult.ok);
      }
      expect(s.ovenLevel, 5);
      expect(s.buyOvenUpgrade(), PurchaseResult.maxed);
      expect(s.bakeModifiers.bakeOkHalfWidth, 0.20);
    });
  });

  test('mua dụng cụ', () {
    final s = _stateAtLevel(2, coins: 1000);
    expect(s.buyToolUpgrade(ToolId.whisk), PurchaseResult.locked); // phới 2 cần cấp 3
    expect(s.buyToolUpgrade(ToolId.tongs), PurchaseResult.ok);
    expect(s.toolLevel(ToolId.tongs), 2);
    expect(s.bakeModifiers.toppingSnapRadius, 16);
    expect(s.buyToolUpgrade(ToolId.tongs), PurchaseResult.locked); // kẹp 3 cần cấp 5
    final rich = _stateAtLevel(7, coins: 100);
    expect(rich.buyToolUpgrade(ToolId.pipingBag), PurchaseResult.notEnoughCoins);
    rich.addCoins(5000);
    expect(rich.buyToolUpgrade(ToolId.pipingBag), PurchaseResult.ok);
    expect(rich.buyToolUpgrade(ToolId.pipingBag), PurchaseResult.ok);
    expect(rich.buyToolUpgrade(ToolId.pipingBag), PurchaseResult.maxed);
    expect(rich.bakeModifiers.frostBrushRadius, 32);
  });

  test('trang trí: mua, đặt, % tip, trần 30', () {
    final s = _stateAtLevel(1, coins: 1000);
    expect(s.buyDecor(DecorId.floorCheckered), PurchaseResult.locked);
    expect(s.buyDecor(DecorId.windowSeaView), PurchaseResult.notEnoughGems);
    expect(s.buyDecor(DecorId.wallpaperStripes), PurchaseResult.ok);
    expect(s.buyDecor(DecorId.wallpaperStripes), PurchaseResult.alreadyOwned);
    expect(s.decorTipBonusPct, 0); // mua chưa tự đặt
    s.equipDecor(DecorSlot.wallpaper, DecorId.wallpaperStripes);
    expect(s.decorTipBonusPct, 3);
    s.equipDecor(DecorSlot.floor, DecorId.wallpaperStripes); // sai ô → bỏ qua
    expect(s.equippedDecor[DecorSlot.floor], isNull);
    s.equipDecor(DecorSlot.wallpaper, null);
    expect(s.decorTipBonusPct, 0);

    // Đặt toàn bộ món tốt nhất: 6 + 6 + 5 + 6 + 5 = 28 (≤ 30).
    final full = _stateAtLevel(8, coins: 100000);
    full.addGems(100);
    for (final id in [
      DecorId.wallpaperFloral,
      DecorId.floorHerringbone,
      DecorId.counterCakeStand,
      DecorId.windowSeaView,
      DecorId.plantLemonTree,
    ]) {
      expect(full.buyDecor(id), PurchaseResult.ok);
      full.equipDecor(Catalog.decorItem(id).slot, id);
    }
    expect(full.decorTipBonusPct, 28);
    expect(full.decorTipBonusPct, lessThanOrEqualTo(Economy.decorTipCapPct));
  });

  test('unlocksAtLevel khớp bảng', () {
    expect(Economy.unlocksAtLevel(2), [
      const Unlock(UnlockKind.recipe, recipe: RecipeId.muffinBlueberry),
      const Unlock(UnlockKind.topping, topping: ToppingId.blueberry),
      const Unlock(UnlockKind.upgrade),
      const Unlock(UnlockKind.decor),
    ]);
    expect(Economy.unlocksAtLevel(4), [
      const Unlock(UnlockKind.recipe, recipe: RecipeId.strawberryCake),
      const Unlock(UnlockKind.upgrade),
      const Unlock(UnlockKind.moreCustomers),
    ]);
    expect(Economy.unlocksAtLevel(7).map((u) => u.kind),
        [UnlockKind.vipGuests, UnlockKind.upgrade, UnlockKind.decor]);
    expect(Economy.unlocksAtLevel(11), isEmpty);
    expect(Economy.unlocksAtLevel(12), [
      const Unlock(UnlockKind.recipe, recipe: RecipeId.birthdayCake),
      const Unlock(UnlockKind.topping, topping: ToppingId.candle),
    ]);
  });

  test('catalog: 10 món đúng thứ tự, mở món theo cấp', () {
    expect(Catalog.recipes.map((r) => r.id).toList(), RecipeId.values);
    final s = _stateAtLevel(5);
    expect(s.unlockedRecipes, [
      RecipeId.cupcakeVanilla,
      RecipeId.cupcakeChocolate,
      RecipeId.muffinBlueberry,
      RecipeId.eggTart,
      RecipeId.strawberryCake,
      RecipeId.macaron,
    ]);
    expect(s.isToppingUnlocked(ToppingId.sugarPearl), isTrue);
    expect(s.isToppingUnlocked(ToppingId.candle), isFalse);
    expect(Catalog.storyScenes.map((e) => e.id).toList(), StorySceneId.values);
  });
}
