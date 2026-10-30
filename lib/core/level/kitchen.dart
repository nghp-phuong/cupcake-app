part of 'level_session.dart';

/// Vị trí của một mẻ trong bếp nhanh.
/// Khu chuẩn bị (`Kitchen.prep`): mould → mix → waitingOven (chờ lò trống).
/// Lò (`Kitchen.ovens[i]`): baking → ovenDone (đã lấy ra / cháy nhưng khu hoàn thiện đang bận, lò vẫn bận).
/// Khu hoàn thiện (`Kitchen.finish`): frost → topping → box → waitingCase (tủ đầy, chờ chỗ).
enum BatchStage { mould, mix, waitingOven, baking, ovenDone, frost, topping, box, waitingCase }

/// Một mẻ bánh trong bếp nhanh. Chỉ [LevelSession] sửa.
class Batch {
  Batch._(this.recipe, math.Random random)
      : mouldChoices = _mouldChoices(Catalog.recipe(recipe), random),
        toppingChoices = _toppingChoices(Catalog.recipe(recipe), random),
        boxChoices = List<BoxType>.unmodifiable(List<BoxType>.of(BoxType.values)..shuffle(random));

  final RecipeId recipe;
  BatchStage _stage = BatchStage.mould;

  /// 3 khuôn (1 đúng + 2 nhiễu), thứ tự ngẫu nhiên.
  final List<MouldType> mouldChoices;

  /// 2 hũ topping (1 đúng + 1 nhiễu), thứ tự ngẫu nhiên.
  final List<ToppingId> toppingChoices;

  /// 3 hộp, thứ tự ngẫu nhiên.
  final List<BoxType> boxChoices;

  int _wrongMoulds = 0;
  double _mixTurns = 0;
  int _oven = -1;
  double _ovenElapsed = 0;
  double _ovenProgress = 0;
  bool _ovenReadyAnnounced = false;
  double _bakeRelease = 0;
  bool _burnt = false;
  double _frostCoverage = 0;
  final Map<ToppingId, int> _toppings = {};
  int _toppingsPlaced = 0;
  BoxType? _box;
  BakeResult? _result;

  BatchStage get stage => _stage;
  Recipe get recipeData => Catalog.recipe(recipe);
  MouldType get correctMould => recipeData.mould;
  ToppingId get correctTopping => recipeData.toppings.first;
  BoxType get correctBox => recipeData.box;

  /// Vị trí kim lò đúng lúc nướng chuẩn (= `bakeTarget` của món).
  double get bakeTarget => recipeData.bakeTarget;

  /// Số lần chọn sai khuôn.
  int get wrongMoulds => _wrongMoulds;

  /// Lò đang chứa mẻ (−1 nếu không ở lò).
  int get oven => _oven;

  /// 0..1 kim lò (tới [bakeTarget] đúng lúc `ovenSec`; tới 1.0 → cháy).
  double get ovenProgress => _ovenProgress;
  bool get burnt => _burnt;

  /// Hộp đã chọn (null = chưa tới / chưa chọn).
  BoxType? get boxChosen => _box;

  /// Số lần đã chạm hũ topping (0..3).
  int get toppingsPlaced => _toppingsPlaced;

  /// Topping của mẻ khi vào tủ: topping được chạm nhiều nhất (2 hũ × 3 lần → không hoà; hoà thì ưu tiên topping
  /// đúng, rồi theo thứ tự `ToppingId`); chưa chạm lần nào → topping đúng.
  ToppingId get placedTopping {
    var best = correctTopping;
    var bestN = _toppings[best] ?? 0;
    for (final t in ToppingId.values) {
      final n = _toppings[t] ?? 0;
      if (n > bestN) {
        best = t;
        bestN = n;
      }
    }
    return best;
  }
  static const toppingTaps = 3;

  /// 1..5 sau khi chọn hộp; 0 = chưa chấm.
  int get stars => _result?.stars ?? 0;
  BakeResult? get result => _result;

  /// Mồi chỉ lấy khuôn/topping người chơi đã gặp (`Catalog.isDecoyMould`): món chương 1–2 có đúng bộ mồi và
  /// chuỗi ngẫu nhiên như trước GĐ8.
  static List<MouldType> _mouldChoices(Recipe recipe, math.Random random) {
    final correct = recipe.mould;
    final others = [for (final m in MouldType.values) if (m != correct && Catalog.isDecoyMould(m, recipe.unlockLevel)) m]..shuffle(random);
    return List<MouldType>.unmodifiable([correct, others[0], others[1]]..shuffle(random));
  }

  static List<ToppingId> _toppingChoices(Recipe recipe, math.Random random) {
    final correct = recipe.toppings.first;
    final others = [
      for (final t in ToppingId.values)
        if (t != correct && t != ToppingId.candle && Catalog.isDecoyTopping(t, recipe.unlockLevel)) t,
    ];
    return List<ToppingId>.unmodifiable([correct, others[random.nextInt(others.length)]]..shuffle(random));
  }

  @override
  String toString() => 'Batch(${recipe.name} ${_stage.name} oven=$_oven progress=${_ovenProgress.toStringAsFixed(2)})';
}

/// Bếp nhanh: 1 khu chuẩn bị, `ovens` lò, 1 khu hoàn thiện.
class Kitchen {
  Kitchen._(int ovens) : _ovens = List<Batch?>.filled(ovens, null) {
    _ovensView = UnmodifiableListView(_ovens);
  }

  Batch? _prep;
  final List<Batch?> _ovens;
  late final List<Batch?> _ovensView;
  Batch? _finish;

  /// Khuôn → Trộn → chờ lò.
  Batch? get prep => _prep;

  /// Độ dài cố định = số lò; null = lò trống. Chỉ đọc (dựng một lần).
  List<Batch?> get ovens => _ovensView;

  /// Kem → Topping → Hộp (→ chờ tủ).
  Batch? get finish => _finish;

  int get freeOven {
    for (var i = 0; i < _ovens.length; i++) {
      if (_ovens[i] == null) return i;
    }
    return -1;
  }

  /// Số mẻ đang trong bếp của món [r].
  int batchesOf(RecipeId r) {
    var n = 0;
    if (_prep?.recipe == r) n++;
    if (_finish?.recipe == r) n++;
    for (final b in _ovens) {
      if (b?.recipe == r) n++;
    }
    return n;
  }
}
