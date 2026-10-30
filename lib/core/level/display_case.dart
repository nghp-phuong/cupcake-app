part of 'level_session.dart';

/// Một ô tủ kính: một món, tối đa `slotCapacity` cái; mỗi cái mang số sao 1..5 và topping đã đặt thật của mẻ (bếp nhanh
/// có hũ nhiễu → bánh có thể mang topping khác topping chuẩn của món). Thứ tự hiển thị = thứ tự vào tủ (cái cũ nhất
/// [toppingAt] 0). Mảng cố định theo sức chứa: thêm/bán không cấp phát.
class CaseSlot {
  CaseSlot._(int capacity)
      : _starsAt = List<int>.filled(capacity, 0),
        _toppingAt = List<ToppingId?>.filled(capacity, null);

  RecipeId? _recipe;

  /// Chỉ số = số sao (1..5); [0] không dùng.
  final List<int> _byStars = List<int>.filled(6, 0);

  /// Từng cái theo thứ tự vào tủ (0.._count−1).
  final List<int> _starsAt;
  final List<ToppingId?> _toppingAt;
  int _count = 0;

  /// null = ô trống.
  RecipeId? get recipe => _recipe;
  int get count => _count;
  bool get isEmpty => _count == 0;

  int countWithStars(int stars) => stars < 1 || stars > 5 ? 0 : _byStars[stars];

  /// Sao cao nhất đang có (0 nếu trống).
  int get bestStars {
    for (var s = 5; s >= 1; s--) {
      if (_byStars[s] > 0) return s;
    }
    return 0;
  }

  /// Topping chuẩn của món trong ô (`Recipe.toppings.first`); null nếu ô trống.
  ToppingId? get defaultTopping => _recipe == null ? null : Catalog.recipe(_recipe!).toppings.first;

  /// Topping thật của cái thứ [i] (0..[count]−1, thứ tự hiển thị). Ngoài khoảng → [RangeError].
  ToppingId toppingAt(int i) {
    RangeError.checkValidIndex(i, this, 'i', _count);
    return _toppingAt[i]!;
  }

  /// Sao của cái thứ [i] (0..[count]−1).
  int starsAt(int i) {
    RangeError.checkValidIndex(i, this, 'i', _count);
    return _starsAt[i];
  }

  /// Cái thứ [i] mang topping chuẩn của món (game vẽ ảnh mặc định của món; khác → vẽ topping [toppingAt]).
  bool isDefaultToppingAt(int i) => toppingAt(i) == defaultTopping;

  /// Mọi cái trong ô đều mang topping chuẩn (ô trống → true).
  bool get allDefaultTopping {
    final d = defaultTopping;
    for (var i = 0; i < _count; i++) {
      if (_toppingAt[i] != d) return false;
    }
    return true;
  }

  void _put(RecipeId r, int n, int stars, ToppingId topping) {
    _recipe = r;
    _byStars[stars] += n;
    for (var k = 0; k < n; k++) {
      _starsAt[_count] = stars;
      _toppingAt[_count] = topping;
      _count++;
    }
  }

  /// Lấy cái sao cao nhất (cùng sao → cái cũ nhất), dồn các cái sau lên. Trả số sao (0 nếu trống).
  int _takeBest() {
    final s = bestStars;
    if (s == 0) return 0;
    var at = 0;
    while (_starsAt[at] != s) {
      at++;
    }
    for (var k = at; k < _count - 1; k++) {
      _starsAt[k] = _starsAt[k + 1];
      _toppingAt[k] = _toppingAt[k + 1];
    }
    _count--;
    _starsAt[_count] = 0;
    _toppingAt[_count] = null;
    _byStars[s]--;
    if (_count == 0) _recipe = null;
    return s;
  }
}

/// Tủ kính: [slots] ô, mỗi ô một món. Mẻ mới vào ô cùng món còn chỗ, phần dư sang ô trống.
class DisplayCase {
  DisplayCase._(int slots, this.slotCapacity)
      : items = List<CaseSlot>.unmodifiable([for (var i = 0; i < slots; i++) CaseSlot._(slotCapacity)]);

  final int slotCapacity;

  /// Đúng [slots] phần tử, thứ tự cố định (ô trống có `recipe == null`).
  final List<CaseSlot> items;

  int _revision = 0;

  int get slots => items.length;

  /// Tăng mỗi khi tủ đổi (vẽ lại khi khác lần trước).
  int get revision => _revision;

  int countOf(RecipeId r) {
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      if (s._recipe == r) n += s._count;
    }
    return n;
  }

  int get totalCount {
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      n += items[i]._count;
    }
    return n;
  }

  /// Còn chỗ cho bao nhiêu cái món [r] (ô cùng món + ô trống).
  int roomFor(RecipeId r) {
    var room = 0;
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      if (s._recipe == r) {
        room += slotCapacity - s._count;
      } else if (s._recipe == null) {
        room += slotCapacity;
      }
    }
    return room;
  }

  bool canFit(RecipeId r, int n) => roomFor(r) >= n;

  /// Thêm [n] cái [stars]★ mang topping [topping] (null = topping chuẩn của món); false (không đổi gì) nếu không đủ
  /// chỗ.
  bool _add(RecipeId r, int n, int stars, [ToppingId? topping]) {
    if (n <= 0 || !canFit(r, n)) return false;
    final s = stars.clamp(1, 5);
    final top = topping ?? Catalog.recipe(r).toppings.first;
    var left = n;
    for (final slot in items) {
      if (left == 0) break;
      if (slot._recipe == r && slot._count < slotCapacity) {
        final k = math.min(left, slotCapacity - slot._count);
        slot._put(r, k, s, top);
        left -= k;
      }
    }
    for (final slot in items) {
      if (left == 0) break;
      if (slot._recipe == null) {
        final k = math.min(left, slotCapacity);
        slot._put(r, k, s, top);
        left -= k;
      }
    }
    _revision++;
    return true;
  }

  /// Lấy cái sao cao nhất của món [r]; trả số sao (0 nếu không có).
  int _takeBest(RecipeId r) {
    CaseSlot? best;
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      if (s._recipe == r && s._count > 0 && (best == null || s.bestStars > best.bestStars)) best = s;
    }
    if (best == null) return 0;
    _revision++;
    return best._takeBest();
  }
}
