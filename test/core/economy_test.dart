import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

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

  test('catalog: 18 món đúng thứ tự, cảnh truyện đủ', () {
    expect(Catalog.recipes.map((r) => r.id).toList(), RecipeId.values);
    expect(Catalog.storyScenes.map((e) => e.id).toList(), StorySceneId.values);
  });
}
