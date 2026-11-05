import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';

void main() {
  test('thực đơn 4 món đúng đặc tả', () {
    final d = RestaurantMenu.dishes;
    expect(d.map((e) => e.id), [
      'fish_soup',
      'omelette_rice',
      'veggie_curry',
      'seafood_noodles',
    ]);
    expect(d.map((e) => e.price), [120, 160, 200, 260]);
    expect(d.map((e) => e.xp), [40, 55, 70, 90]);
    expect(d.map((e) => e.nameKey), [
      'dishFishSoup',
      'dishOmeletteRice',
      'dishVeggieCurry',
      'dishSeafoodNoodles',
    ]);
  });

  test('xpFor: lần đầu 100%, sau đó 25% làm tròn', () {
    final soup = RestaurantMenu.dishes[0];
    expect(RestaurantMenu.xpFor(soup, 0), 40);
    expect(RestaurantMenu.xpFor(soup, 1), 10);
    expect(RestaurantMenu.xpFor(soup, 5), 10);
    expect(RestaurantMenu.xpFor(RestaurantMenu.dishes[1], 1), 14); // 13.75
    expect(RestaurantMenu.xpFor(RestaurantMenu.dishes[3], 2), 23); // 22.5
  });

  test('xpFor: tối thiểu 1', () {
    expect(RestaurantMenu.xpFor(const Dish('x', 'k', 1, 1), 1), 1);
    expect(RestaurantMenu.xpFor(const Dish('x', 'k', 1, 0), 1), 1);
  });
}
