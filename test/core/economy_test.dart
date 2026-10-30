import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

final _unlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync());

/// Ván đã qua L1..[passed] (mốc khoá GĐ3 = level phải qua), có unlocks.json thật.
GameState _stateAfter(int passed, {int coins = 0}) {
  final s = GameState.fromJson({
    'v': GameState.saveVersion,
    'coins': coins,
    'progress': {
      'levels': {for (var id = 1; id <= passed; id++) '$id': {'stars': 1, 'plays': 1}},
    },
  }, clock: _clock)
    ..attachUnlockConfig(_unlocks);
  expect(s.highestCompletedLevel, passed);
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

  test('bỏ cấp tiệm (GĐ3): mốc khoá = level phải qua; trường xp vẫn đọc/ghi', () {
    // Mọi nâng cấp lò/dụng cụ và đồ trang trí mở trong chương 1–2 (qua ≤ L20).
    final maxNeeded = [
      for (final e in _unlocks.equipment)
        for (final t in e.tiers) t.level,
      for (final d in Catalog.decor) d.unlockLevel,
    ].reduce((a, b) => a > b ? a : b);
    expect(maxNeeded, lessThanOrEqualTo(20));
    final s = GameState.fromJson({'v': GameState.saveVersion, 'xp': 1234}, clock: _clock);
    expect(s.highestCompletedLevel, 0);
    expect(s.xp, 1234);
    expect(s.toJson()['xp'], 1234);
  });

  test('bảng dự phòng Economy.ovenTiers / toolTiers khớp unlocks.json (giá, level, thông số)', () {
    final oven = _unlocks.equipmentById(EquipmentIds.goldenOven)!;
    expect(oven.maxTier, Economy.maxOvenLevel);
    for (final t in Economy.ovenTiers) {
      final e = oven.tier(t.level);
      expect((e.level, e.price, e.value), (t.requiredShopLevel, t.cost, t.perfectHalfWidth), reason: 'lò cấp ${t.level}');
      expect(t.okHalfWidth, closeTo(t.perfectHalfWidth + 0.10, 1e-9));
    }
    for (final MapEntry(key: id, value: tiers) in Economy.toolTiers.entries) {
      final eq = _unlocks.equipmentById(id.name)!;
      expect(eq.maxTier, tiers.length, reason: id.name);
      for (final t in tiers) {
        final e = eq.tier(t.level);
        expect((e.level, e.price, e.value), (t.requiredShopLevel, t.cost, t.value), reason: '${id.name} cấp ${t.level}');
      }
    }
  });

  group('mua lò vùng vàng (buyEquipment goldenOven)', () {
    final price2 = _unlocks.equipmentById(EquipmentIds.goldenOven)!.tier(2).price;
    test('ok', () {
      final s = _stateAfter(2, coins: price2);
      expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.ok);
      expect(s.ovenLevel, 2);
      expect(s.coins, 0);
      expect(s.bakeModifiers.bakePerfectHalfWidth, 0.06);
      expect(s.bakeModifiers.bakeOkHalfWidth, 0.16);
    });
    test('notEnoughCoins', () {
      final s = _stateAfter(2, coins: price2 - 1);
      expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.notEnoughCoins);
      expect(s.ovenLevel, 1);
      expect(s.coins, price2 - 1);
    });
    test('locked (chưa qua L2)', () {
      final s = _stateAfter(1, coins: 5000);
      expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.locked);
    });
    test('maxed', () {
      final s = _stateAfter(20, coins: 100000);
      for (var i = 0; i < 4; i++) {
        expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.ok);
      }
      expect(s.ovenLevel, 5);
      expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.maxed);
      expect(s.bakeModifiers.bakeOkHalfWidth, 0.20);
    });
  });

  test('mua dụng cụ (buyEquipment whisk / pipingBag / tongs)', () {
    final s = _stateAfter(3, coins: 1000);
    expect(s.buyEquipment('whisk'), PurchaseResult.locked); // phới 2: qua L4
    expect(s.buyEquipment('tongs'), PurchaseResult.ok);
    expect(s.toolLevel(ToolId.tongs), 2);
    expect(s.bakeModifiers.toppingSnapRadius, 16);
    expect(s.buyEquipment('tongs'), PurchaseResult.locked); // kẹp 3: qua L10
    final rich = _stateAfter(15, coins: 100);
    expect(rich.buyEquipment('pipingBag'), PurchaseResult.notEnoughCoins);
    rich.addCoins(50000);
    expect(rich.buyEquipment('pipingBag'), PurchaseResult.ok);
    expect(rich.buyEquipment('pipingBag'), PurchaseResult.ok);
    expect(rich.buyEquipment('pipingBag'), PurchaseResult.maxed);
    expect(rich.bakeModifiers.frostBrushRadius, 32);
    expect(rich.buyEquipment('noSuchThing'), PurchaseResult.locked);
  });

  test('không có unlocks.json: lò/dụng cụ V1 vẫn nâng theo bảng dự phòng Economy', () {
    final s = GameState.fromJson({
      'v': GameState.saveVersion,
      'coins': 10000,
      'progress': {
        'levels': {for (var id = 1; id <= 6; id++) '$id': {'stars': 1}},
      },
    }, clock: _clock);
    expect(s.unlockConfig.isEmpty, isTrue);
    expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.ok);
    expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.ok);
    expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.locked); // cấp 4: qua L11
    expect(s.bakeModifiers.bakePerfectHalfWidth, 0.07);
    expect(s.buyEquipment(EquipmentIds.fastOven), PurchaseResult.locked); // thiết bị mới chỉ có trong unlocks.json
    expect(s.shopSetup.ovenSec, ShopSetup.base.ovenSec);
  });

  test('trang trí: mua, đặt, % tip, trần 30', () {
    final s = _stateAfter(4, coins: 1000);
    expect(s.buyDecor(DecorId.floorCheckered), PurchaseResult.locked); // qua L6
    expect(_stateAfter(0, coins: 1000).buyDecor(DecorId.counterFlowers), PurchaseResult.ok); // có sẵn từ đầu
    expect(_stateAfter(0, coins: 1000).buyDecor(DecorId.plantFern), PurchaseResult.locked); // qua L2
    expect(s.buyDecor(DecorId.windowSeaView), PurchaseResult.locked); // qua L8
    expect(_stateAfter(8).buyDecor(DecorId.windowSeaView), PurchaseResult.notEnoughGems);
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
    final full = _stateAfter(16, coins: 100000);
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

  test('trang trí: mốc mở trải L0–L20 (món rẻ nhất có sẵn), giá xu tăng theo mốc', () {
    final coin = [
      for (final d in Catalog.decor)
        if (!d.paidWithGems) d,
    ]..sort((a, b) => a.unlockLevel - b.unlockLevel);
    expect(coin.first.unlockLevel, 0);
    for (final d in Catalog.decor) {
      expect(d.unlockLevel, inInclusiveRange(0, 20), reason: d.id.name);
    }
    for (var i = 1; i < coin.length; i++) {
      expect(coin[i].coinPrice, greaterThanOrEqualTo(coin[i - 1].coinPrice), reason: coin[i].id.name);
    }
  });

  test('catalog: 18 món đúng thứ tự, mở món theo cấp', () {
    expect(Catalog.recipes.map((r) => r.id).toList(), RecipeId.values);
    // Chưa gắn levels.json → món/topping mở như V1 theo số level đã qua (qua L7 ≈ cấp tiệm 5).
    final s = _stateAfter(7);
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
