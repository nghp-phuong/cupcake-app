/// Ví của Mai trong thành phố: xu, XP, diện mạo, buff, lô đã ghé, bộ đếm ăn trong ngày. Lưu qua save v3
/// (`CityGame.toSave` / `CityGame.restore`); cấp không lưu mà luôn tính từ XP.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'mai_look.dart';
import 'player_level.dart';
import 'restaurant_menu.dart';

class EatResult {
  final bool ok;
  final int xpGained;
  final bool reducedXp;

  /// != null khi lên cấp.
  final int? newLevel;

  const EatResult({
    required this.ok,
    this.xpGained = 0,
    this.reducedXp = false,
    this.newLevel,
  });
}

class CityWallet extends ChangeNotifier {
  /// Giá trị ngoài khoảng bị kẹp như [restore].
  CityWallet({
    int coins = startCoins,
    int xp = 0,
    MaiLook look = MaiLook.defaults,
    Set<String> visited = const {},
    Map<String, int> eatenToday = const {},
    bool fullBuff = false,
    String dayKey = '',
    int dayNumber = 1,
  }) {
    _assign(
      coins: coins,
      xp: xp,
      look: look,
      visited: visited,
      eatenToday: eatenToday,
      fullBuff: fullBuff,
      dayKey: dayKey,
      dayNumber: dayNumber,
    );
  }

  static const int startCoins = 1500;
  static const int firstVisitXp = 50;

  /// Trần xu: 2^53 − 1 (số nguyên lớn nhất biểu diễn chính xác trên web).
  static const int coinCap = 9007199254740991;

  /// Trần XP: 2^31 − 1.
  static const int xpCap = 2147483647;

  /// Trần bộ đếm ăn một món trong ngày (save chỉ nhận 0..999; từ lần 2 XP đã là 25% nên không đổi lối chơi).
  static const int maxEatenPerDay = 999;

  int _coins = startCoins;
  int _xp = 0;
  MaiLook _look = MaiLook.defaults;
  bool _fullBuff = false;
  final Map<String, int> _eatenToday = {};
  final Set<String> _visited = {};
  String _dayKey = '';
  int _dayNumber = 1;

  int get coins => _coins;
  int get xp => _xp;
  int get level => PlayerLevel.levelForXp(_xp);
  MaiLook get look => _look;

  /// Buff "No bụng" (+10% tip cả ca bán kế tiếp; tắt ở lần tính đơn đầu của ca, [consumeFullBuff]). Sang ngày mới
  /// vẫn giữ.
  bool get fullBuff => _fullBuff;

  /// Số lần đã ăn món [dishId] trong ngày.
  int timesEatenToday(String dishId) => _eatenToday[dishId] ?? 0;

  /// Lô đã ghé (gồm cả id lạ đọc từ save); chỉ đọc.
  Set<String> get visited => UnmodifiableSetView(_visited);

  /// Món → số lần ăn trong ngày [dayKey]; chỉ đọc.
  Map<String, int> get eatenToday => UnmodifiableMapView(_eatenToday);

  /// Ngày lịch `yyyy-mm-dd` của bộ đếm ăn; rỗng = chưa đặt.
  String get dayKey => _dayKey;

  /// Số ngày đã chơi (ngày đầu = 1).
  int get dayNumber => _dayNumber;

  bool canAfford(int price) => _coins >= price;

  /// Thiếu xu → ok=false, không đổi gì. Số lần ăn trong ngày đếm riêng từng món.
  EatResult eat(Dish dish) {
    if (!canAfford(dish.price)) return const EatResult(ok: false);
    final times = timesEatenToday(dish.id);
    final reduced = times > 0;
    final gained = RestaurantMenu.xpFor(dish, times);
    _coins -= dish.price;
    _eatenToday[dish.id] = times < maxEatenPerDay ? times + 1 : maxEatenPerDay;
    _fullBuff = true;
    final newLevel = _applyXp(gained);
    notifyListeners();
    return EatResult(
      ok: true,
      xpGained: gained,
      reducedXp: reduced,
      newLevel: newLevel,
    );
  }

  /// Giá = [SalonPrices.priceFor]; thiếu xu → false.
  bool buyLook(MaiLook to) {
    final price = SalonPrices.priceFor(_look, to);
    if (!canAfford(price)) return false;
    _coins -= price;
    _look = to;
    notifyListeners();
    return true;
  }

  /// Trả cấp mới nếu lên cấp.
  int? addXp(int xp) {
    final newLevel = _applyXp(xp);
    notifyListeners();
    return newLevel;
  }

  /// Cộng xu và XP (ca bán); xu âm thì trừ. Xu kẹp [0, [coinCap]], XP [0, [xpCap]]. Cả hai bằng 0 → không đổi, không
  /// notify. Trả cấp mới nếu lên cấp.
  int? earn({int coins = 0, int xp = 0}) {
    if (coins == 0 && xp == 0) return null;
    _coins = (_coins + coins).clamp(0, coinCap);
    final newLevel = _applyXp(xp);
    notifyListeners();
    return newLevel;
  }

  /// Dùng buff "No bụng" (lần tính đơn đầu của ca có buff): đang có → tắt, notify, trả true; không có → false.
  bool consumeFullBuff() {
    if (!_fullBuff) return false;
    _fullBuff = false;
    notifyListeners();
    return true;
  }

  /// Lần đầu ghé → true và +[firstVisitXp].
  bool markFirstVisit(String lotId) {
    if (!_visited.add(lotId)) return false;
    _applyXp(firstVisitXp);
    notifyListeners();
    return true;
  }

  /// Xoá bộ đếm ăn trong ngày.
  void newDay() {
    _eatenToday.clear();
    notifyListeners();
  }

  /// Đổi sang ngày lịch [todayKey] (`yyyy-mm-dd`): [dayKey] rỗng → chỉ đặt khoá; khác → xoá bộ đếm ăn (như [newDay])
  /// và tăng [dayNumber]; [fullBuff] giữ nguyên. Trả true nếu có đổi (đã notify một lần).
  bool rollDay(String todayKey) {
    if (todayKey == _dayKey) return false;
    if (_dayKey.isNotEmpty) {
      _eatenToday.clear();
      _dayNumber++;
    }
    _dayKey = todayKey;
    notifyListeners();
    return true;
  }

  /// Đặt lại toàn bộ ví tại chỗ (không thay object: màn đang nghe ví vẫn dùng tiếp), notify một lần. Xu kẹp
  /// [0, [coinCap]], XP [0, [xpCap]], [dayNumber] ≥ 1, bộ đếm ăn [0, [maxEatenPerDay]].
  void restore({
    int coins = startCoins,
    int xp = 0,
    MaiLook look = MaiLook.defaults,
    Set<String> visited = const {},
    Map<String, int> eatenToday = const {},
    bool fullBuff = false,
    String dayKey = '',
    int dayNumber = 1,
  }) {
    _assign(
      coins: coins,
      xp: xp,
      look: look,
      visited: visited,
      eatenToday: eatenToday,
      fullBuff: fullBuff,
      dayKey: dayKey,
      dayNumber: dayNumber,
    );
    notifyListeners();
  }

  void _assign({
    required int coins,
    required int xp,
    required MaiLook look,
    required Set<String> visited,
    required Map<String, int> eatenToday,
    required bool fullBuff,
    required String dayKey,
    required int dayNumber,
  }) {
    _coins = coins.clamp(0, coinCap);
    _xp = xp.clamp(0, xpCap);
    _look = look;
    _visited
      ..clear()
      ..addAll(visited);
    _eatenToday
      ..clear()
      ..addAll({
        for (final e in eatenToday.entries)
          e.key: e.value.clamp(0, maxEatenPerDay),
      });
    _fullBuff = fullBuff;
    _dayKey = dayKey;
    _dayNumber = dayNumber < 1 ? 1 : dayNumber;
  }

  int? _applyXp(int gained) {
    final before = level;
    _xp = (_xp + gained).clamp(0, xpCap);
    final after = level;
    return after > before ? after : null;
  }
}
