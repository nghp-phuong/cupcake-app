import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';

/// Phần ví thêm ở GĐ2 (save v3): ngày, lô đã ghé, bộ đếm ăn, restore.
void main() {
  final soup = RestaurantMenu.dishes[0]; // 120 xu, 40 xp

  int notifies(CityWallet w, void Function() act) {
    var n = 0;
    void l() => n++;
    w.addListener(l);
    act();
    w.removeListener(l);
    return n;
  }

  test('mặc định mới', () {
    final w = CityWallet();
    expect(CityWallet.startCoins, 1500);
    expect(w.visited, isEmpty);
    expect(w.eatenToday, isEmpty);
    expect(w.dayKey, '');
    expect(w.dayNumber, 1);
  });

  test('constructor nhận đủ trường, kẹp số', () {
    final w = CityWallet(
      coins: 10,
      xp: 5,
      visited: {'n3', 'lạ'},
      eatenToday: {soup.id: 2, 'x': 5000},
      fullBuff: true,
      dayKey: '2026-11-04',
      dayNumber: 0,
    );
    expect(w.visited, {'n3', 'lạ'});
    expect(w.eatenToday, {soup.id: 2, 'x': 999});
    expect(w.timesEatenToday(soup.id), 2);
    expect(w.fullBuff, isTrue);
    expect(w.dayKey, '2026-11-04');
    expect(w.dayNumber, 1);
    expect(w.markFirstVisit('n3'), isFalse);
  });

  test('visited / eatenToday chỉ đọc', () {
    final w = CityWallet()..markFirstVisit('n3');
    expect(() => w.visited.add('n4'), throwsUnsupportedError);
    expect(() => w.eatenToday['a'] = 1, throwsUnsupportedError);
  });

  test(
    'rollDay: rỗng → chỉ đặt; cùng ngày → không đổi; khác → xoá đếm, n++, giữ buff',
    () {
      final w = CityWallet()..eat(soup);
      expect(notifies(w, () => expect(w.rollDay('2026-11-04'), isTrue)), 1);
      expect(w.dayKey, '2026-11-04');
      expect(w.dayNumber, 1);
      expect(w.timesEatenToday(soup.id), 1); // chỉ đặt khoá

      expect(notifies(w, () => expect(w.rollDay('2026-11-04'), isFalse)), 0);

      expect(notifies(w, () => expect(w.rollDay('2026-11-05'), isTrue)), 1);
      expect(w.dayNumber, 2);
      expect(w.timesEatenToday(soup.id), 0);
      expect(w.fullBuff, isTrue);
      expect(w.eat(soup).xpGained, 40);
    },
  );

  test('restore: tại chỗ, kẹp số, notify 1 lần', () {
    final w = CityWallet()
      ..eat(soup)
      ..markFirstVisit('n3');
    final n = notifies(
      w,
      () => w.restore(
        coins: -1,
        xp: 1 << 40,
        look: const MaiLook(hair: MaiHair.bun),
        visited: {'s1'},
        eatenToday: {'a': -4},
        fullBuff: false,
        dayKey: '2026-01-01',
        dayNumber: 7,
      ),
    );
    expect(n, 1);
    expect(w.coins, 0);
    expect(w.xp, CityWallet.xpCap);
    expect(w.level, 30);
    expect(w.look.hair, MaiHair.bun);
    expect(w.visited, {'s1'});
    expect(w.eatenToday, {'a': 0});
    expect(w.timesEatenToday(soup.id), 0);
    expect(w.fullBuff, isFalse);
    expect(w.dayKey, '2026-01-01');
    expect(w.dayNumber, 7);
    // Không đối số → như ví mới.
    w.restore();
    expect(w.coins, 1500);
    expect(w.xp, 0);
    expect(w.look, MaiLook.defaults);
    expect(w.visited, isEmpty);
    expect(w.dayKey, '');
    expect(w.dayNumber, 1);
  });

  test('bộ đếm ăn dừng ở 999, XP không vượt trần', () {
    final w = CityWallet(coins: 100000, eatenToday: {soup.id: 999});
    final r = w.eat(soup);
    expect(r.reducedXp, isTrue);
    expect(w.timesEatenToday(soup.id), 999);
    final big = CityWallet(xp: CityWallet.xpCap - 1);
    big.addXp(100);
    expect(big.xp, CityWallet.xpCap);
  });
}
