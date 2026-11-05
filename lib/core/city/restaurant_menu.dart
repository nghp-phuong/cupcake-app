/// Thực đơn quán "Bếp Hải Đăng".
library;

class Dish {
  final String id, nameKey;
  final int price, xp;

  const Dish(this.id, this.nameKey, this.price, this.xp);
}

class RestaurantMenu {
  static const List<Dish> dishes = [
    Dish('fish_soup', 'dishFishSoup', 120, 40),
    Dish('omelette_rice', 'dishOmeletteRice', 160, 55),
    Dish('veggie_curry', 'dishVeggieCurry', 200, 70),
    Dish('seafood_noodles', 'dishSeafoodNoodles', 260, 90),
  ];

  /// Lần đầu trong ngày 100%, các lần sau 25% (làm tròn, tối thiểu 1).
  static int xpFor(Dish d, int timesEatenToday) {
    if (timesEatenToday <= 0) return d.xp;
    final v = (d.xp * 0.25).round();
    return v < 1 ? 1 : v;
  }
}
