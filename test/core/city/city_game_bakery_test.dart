import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/shift/shift_stats.dart';

int _notifies(Listenable l, void Function() act) {
  var n = 0;
  void count() => n++;
  l.addListener(count);
  act();
  l.removeListener(count);
  return n;
}

void main() {
  test('§7-12 CityWallet.earn: cộng xu + XP, kẹp, trả cấp mới', () {
    final w = CityWallet(coins: 100, xp: 90);
    expect(_notifies(w, () => expect(w.earn(coins: 50, xp: 5), isNull)), 1);
    expect(w.coins, 150);
    expect(w.xp, 95);
    expect(w.earn(xp: 10), 2); // 100 XP → cấp 2
    expect(w.earn(coins: -1000), isNull); // âm → trừ, kẹp 0
    expect(w.coins, 0);
    expect(_notifies(w, () => w.earn()), 0);
    w.earn(coins: CityWallet.coinCap);
    w.earn(coins: 10);
    expect(w.coins, CityWallet.coinCap);
    w.earn(xp: CityWallet.xpCap);
    expect(w.xp, CityWallet.xpCap);
  });

  test('§7-12 CityWallet.consumeFullBuff', () {
    final w = CityWallet();
    expect(w.fullBuff, isFalse);
    expect(_notifies(w, () => expect(w.consumeFullBuff(), isFalse)), 0);
    w.eat(RestaurantMenu.dishes.first);
    expect(w.fullBuff, isTrue);
    expect(_notifies(w, () => expect(w.consumeFullBuff(), isTrue)), 1);
    expect(w.fullBuff, isFalse);
    expect(w.consumeFullBuff(), isFalse);
  });

  test('thống kê tiệm: recordOrder / recordShift / addBakeryCoins, kẹp', () {
    final g = CityGame();
    expect(g.bakery, ShiftStats());
    expect(_notifies(g, () => g.recordOrder(stars: 5, coins: 400)), 1);
    g.recordOrder(stars: 3, coins: -5); // xu âm không trừ thống kê
    g.recordOrder(stars: 9, coins: 10); // sao kẹp 5
    expect(g.bakery.orders, 3);
    expect(g.bakery.stars, 13);
    expect(g.bakery.five, 2);
    expect(g.bakery.coins, 410);

    g.recordShift(coins: 300, completed: true);
    g.recordShift(coins: 900, completed: false); // đóng sớm: không lập kỷ lục
    g.recordShift(coins: 200, completed: true);
    expect(g.bakery.shifts, 3);
    expect(g.bakery.best, 300);

    expect(_notifies(g, () => g.addBakeryCoins(0)), 0);
    g.addBakeryCoins(90);
    expect(g.bakery.coins, 500);
    expect(g.bakery.best, 300);

    g.restore(
      g.toSave().copyWith(
        bakery: ShiftStats(orders: 2147483647, coins: CityWallet.coinCap - 1),
      ),
    );
    g.recordOrder(stars: 5, coins: 100);
    expect(g.bakery.orders, 2147483647);
    expect(g.bakery.coins, CityWallet.coinCap);
  });

  test(
    '§7-13 tutorialSeen / recipeSeen: giữ tên lạ, kẹp, không đổi thì không notify',
    () {
      final g = CityGame();
      g.restore(CitySave(bakery: ShiftStats(tutorial: {'mix', 'laTram'})));
      expect(g.tutorialSeen, {StationId.mix});
      expect(_notifies(g, () => g.markTutorialSeen(StationId.mix)), 0);
      expect(_notifies(g, () => g.markTutorialSeen(StationId.bake)), 1);
      expect(g.tutorialSeen, {StationId.mix, StationId.bake});
      expect(g.bakery.tutorial, {'mix', 'laTram', 'bake'});
      expect(
        g.toSave().toJson(DateTime(2026))['bakery'],
        containsPair('tutorial', ['bake', 'laTram', 'mix']),
      );

      expect(g.recipeSeen, 0);
      expect(_notifies(g, () => g.markRecipeSeen(4)), 1);
      expect(_notifies(g, () => g.markRecipeSeen(4)), 0);
      g.markRecipeSeen(99);
      expect(g.recipeSeen, 30);
      g.markRecipeSeen(0);
      expect(g.recipeSeen, 1);
    },
  );

  test(
    '§7-11 interstitial: ngày 1–3 không, 4 có, 5 không, 6 có; removeAds thì không bao giờ',
    () {
      for (final removeAds in [false, true]) {
        final g = CityGame()..restore(CitySave(removeAds: removeAds));
        final shown = <int>[];
        for (var day = 1; day <= 12; day++) {
          g.wallet.restore(dayNumber: day);
          if (g.interstitialDue) {
            shown.add(day);
            expect(_notifies(g, g.registerInterstitialShown), 1);
            expect(g.bakery.adDay, day);
            expect(g.interstitialDue, isFalse);
          }
        }
        expect(
          shown,
          removeAds ? isEmpty : [4, 6, 8, 10, 12],
          reason: '$removeAds',
        );
      }
      // Bỏ một ngày không chơi: ngày 4 hiện, ngày 7 hiện (cách ≥ 2).
      final g = CityGame();
      g.wallet.restore(dayNumber: 4);
      g.registerInterstitialShown();
      g.wallet.restore(dayNumber: 5);
      expect(g.interstitialDue, isFalse);
      g.wallet.restore(dayNumber: 7);
      expect(g.interstitialDue, isTrue);
    },
  );
}
