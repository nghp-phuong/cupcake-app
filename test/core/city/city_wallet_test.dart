import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';

void main() {
  final soup = RestaurantMenu.dishes[0]; // 120 xu, 40 xp
  final noodles = RestaurantMenu.dishes[3]; // 260 xu, 90 xp

  int notifies(CityWallet w, void Function() act) {
    var n = 0;
    void l() => n++;
    w.addListener(l);
    act();
    w.removeListener(l);
    return n;
  }

  test('giá trị mặc định', () {
    final w = CityWallet();
    expect(w.coins, 1500);
    expect(w.xp, 0);
    expect(w.level, 1);
    expect(w.look, MaiLook.defaults);
    expect(w.fullBuff, isFalse);
  });

  test('canAfford', () {
    final w = CityWallet(coins: 100);
    expect(w.canAfford(100), isTrue);
    expect(w.canAfford(101), isFalse);
    expect(w.canAfford(0), isTrue);
  });

  test('eat đủ xu: trừ xu, cộng XP, bật buff', () {
    final w = CityWallet();
    final r = w.eat(soup);
    expect(r.ok, isTrue);
    expect(r.xpGained, 40);
    expect(r.reducedXp, isFalse);
    expect(r.newLevel, isNull);
    expect(w.coins, 1380);
    expect(w.xp, 40);
    expect(w.fullBuff, isTrue);
  });

  test('eat thiếu xu: không đổi gì, không notify', () {
    final w = CityWallet(coins: 119);
    late EatResult r;
    final n = notifies(w, () => r = w.eat(soup));
    expect(r.ok, isFalse);
    expect(r.xpGained, 0);
    expect(r.newLevel, isNull);
    expect(w.coins, 119);
    expect(w.xp, 0);
    expect(w.fullBuff, isFalse);
    expect(n, 0);
    // Lần thất bại không tính vào bộ đếm ngày.
    final w2 = CityWallet(coins: 119);
    w2.eat(soup);
    expect(w2.eat(soup).reducedXp, isFalse);
  });

  test('eat đếm riêng từng món: món khác đủ XP, ăn lại món cũ 25%', () {
    final w = CityWallet();
    expect(w.timesEatenToday(soup.id), 0);
    w.eat(soup);
    final b = w.eat(noodles);
    expect(b.reducedXp, isFalse);
    expect(b.xpGained, 90);
    final again = w.eat(soup);
    expect(again.reducedXp, isTrue);
    expect(again.xpGained, 10);
    expect(w.xp, 40 + 90 + 10);
    expect(w.coins, 1500 - 120 - 260 - 120);
    expect(w.timesEatenToday(soup.id), 2);
    expect(w.timesEatenToday(noodles.id), 1);
    expect(w.timesEatenToday('khac'), 0);
  });

  test('newDay xoá bộ đếm ăn', () {
    final w = CityWallet();
    w.eat(soup);
    w.newDay();
    final r = w.eat(soup);
    expect(r.reducedXp, isFalse);
    expect(r.xpGained, 40);
    expect(w.timesEatenToday(soup.id), 1);
  });

  test('eat làm lên cấp trả newLevel', () {
    final w = CityWallet(xp: 70); // cấp 1, cần 100 cho cấp 2
    final r = w.eat(soup); // +40 → 110
    expect(r.newLevel, 2);
    expect(w.level, 2);
    expect(w.eat(soup).newLevel, isNull);
  });

  test('buyLook: đủ xu, thiếu xu, không đổi', () {
    final w = CityWallet(coins: 500);
    const bob = MaiLook(hair: MaiHair.bob);
    expect(w.buyLook(bob), isTrue);
    expect(w.coins, 200);
    expect(w.look, bob);
    // Đổi kiểu + màu = 500 > 200.
    const other = MaiLook(hair: MaiHair.bun, hairColor: MaiHairColor.black);
    expect(w.buyLook(other), isFalse);
    expect(w.coins, 200);
    expect(w.look, bob);
    // Giữ nguyên = 0 xu, vẫn thành công.
    expect(w.buyLook(bob), isTrue);
    expect(w.coins, 200);
    // Chỉ đổi màu = 200, đúng số xu còn lại.
    expect(w.buyLook(bob.copyWith(hairColor: MaiHairColor.caramel)), isTrue);
    expect(w.coins, 0);
  });

  test('addXp trả cấp mới khi lên cấp', () {
    final w = CityWallet();
    expect(w.addXp(50), isNull);
    expect(w.addXp(50), 2);
    expect(w.addXp(1), isNull);
    expect(w.level, 2);
    expect(w.addXp(100000), 30);
    expect(w.level, 30);
  });

  test('markFirstVisit chỉ lần đầu', () {
    final w = CityWallet();
    expect(w.markFirstVisit('n3'), isTrue);
    expect(w.xp, CityWallet.firstVisitXp);
    expect(w.markFirstVisit('n3'), isFalse);
    expect(w.xp, CityWallet.firstVisitXp);
    expect(w.markFirstVisit('n4'), isTrue);
    expect(w.xp, CityWallet.firstVisitXp * 2);
    expect(w.level, 2);
  });

  test('notifyListeners khi đổi', () {
    final w = CityWallet();
    expect(notifies(w, () => w.eat(soup)), 1);
    expect(notifies(w, () => w.buyLook(const MaiLook(hair: MaiHair.bob))), 1);
    expect(notifies(w, () => w.addXp(5)), 1);
    expect(notifies(w, () => w.markFirstVisit('n3')), 1);
    expect(notifies(w, () => w.markFirstVisit('n3')), 0);
    expect(notifies(w, () => w.newDay()), 1);
    // Thiếu xu thì không notify.
    final poor = CityWallet(coins: 0);
    expect(
      notifies(poor, () => poor.buyLook(const MaiLook(hair: MaiHair.bun))),
      0,
    );
  });
}
