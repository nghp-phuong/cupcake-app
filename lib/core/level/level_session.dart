import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../catalog.dart';
import '../economy.dart';
import '../models/bake.dart';
import '../models/customer.dart';
import '../models/ids.dart';
import '../models/order.dart';
import '../models/recipe.dart';
import '../monetization/booster.dart';
import '../order_generator.dart';
import '../scoring.dart';
import '../staff/staff.dart';
import '../unlock/shop_setup.dart';
import 'level_data.dart';
import 'level_result.dart';
import 'tutorial.dart';

part 'display_case.dart';
part 'kitchen.dart';
part 'level_customer.dart';
part 'staff_state.dart';
part 'tutorial_runner.dart';

/// Kết quả bấm bán cho một khách.
enum SellResult {
  /// Đã bán (xu + combo xem sự kiện `sold`).
  sold,

  /// Tủ không có món khách muốn (UI lắc nhẹ).
  notInCase,

  /// Khách không ở quầy / không tồn tại / màn đang dừng hoặc đã hết giờ.
  invalid,
}

enum SessionEventType {
  /// Khách vãng lai bước vào cửa.
  customerArrived,

  /// Hàng đầy, khách quay đi ở cửa (tính `lost`).
  turnedAway,

  /// Hết kiên nhẫn, bỏ đi (tính `lost`, combo về 0).
  walkedOut,

  /// Bán xong: `coins`, `stars` (sao bánh), `recipe`, `combo`.
  sold,

  /// Combo vừa về 0 (hết cửa sổ hoặc khách bỏ đi); `combo` = giá trị trước đó.
  comboLost,

  /// Mẻ vào lò `oven`.
  ovenStarted,

  /// Kim lò vừa tới vạch chuẩn — nên lấy ra.
  ovenReady,

  /// Để quá, mẻ ở lò `oven` tự ra (cháy).
  burnt,

  /// Mẻ đã vào tủ: `recipe`, `stars`, `count`.
  batchReady,

  /// Đã đóng hộp nhưng tủ đầy, mẻ nằm chờ ở trạm Hộp.
  caseFull,

  /// Khách đặc biệt tới chỗ đặc biệt.
  specialArrived,

  /// Khách đặc biệt hết kiên nhẫn, rời đi.
  specialLeft,

  /// Đơn đặc biệt xong: `coins`, `stars`.
  specialDone,

  /// Bắt đầu giờ cao điểm.
  rushStarted,

  /// Hết giờ.
  timeUp,

  /// Nhân viên (thu ngân / phục vụ) vừa bán — thay cho [sold] (cùng trường `customerId`, `recipe`, `coins`, `stars`,
  /// `combo`) + `staffIndex`.
  staffSold,

  /// Mẻ của thợ bánh vừa vào tủ — thay cho [batchReady] (`recipe`, `stars`, `count`) + `staffIndex`.
  staffBatchReady,

  /// Bước hướng dẫn mới hiện (`LevelSession.tutorial.current`).
  tutorialStep,

  /// Xong phần bắt buộc của kịch bản hướng dẫn — UI lưu `GameState.markTutorialDone(session.tutorial!.id)`.
  tutorialDone,
}

/// Sự kiện từ session cho UI (âm thanh, rung, chữ bay). Trường không liên quan = giá trị mặc định.
class SessionEvent {
  const SessionEvent(
    this.type, {
    this.customerId = -1,
    this.recipe,
    this.coins = 0,
    this.stars = 0,
    this.combo = 0,
    this.oven = -1,
    this.count = 0,
    this.staffIndex = -1,
  });

  final SessionEventType type;
  final int customerId;
  final RecipeId? recipe;
  final int coins;
  final int stars;
  final int combo;
  final int oven;
  final int count;

  /// Chỉ số trong `LevelSession.staff` (sự kiện nhân viên); −1 = người chơi.
  final int staffIndex;

  @override
  String toString() => 'SessionEvent(${type.name}${customerId >= 0 ? ' #$customerId' : ''}'
      '${recipe != null ? ' ${recipe!.name}' : ''}${coins != 0 ? ' +$coins' : ''}${stars != 0 ? ' $stars★' : ''}'
      '${staffIndex >= 0 ? ' staff#$staffIndex' : ''})';
}

/// Logic một lượt chơi level (Dart thuần, bước cố định 1/30 s, `Random` có seed). Không import widget/Flame.
///
/// UI gọi [advance] mỗi khung hình; đọc trạng thái qua getter; người chơi thao tác qua các hàm hành động. Nhân viên
/// đã thuê (`setup.staff`) tự làm trong [advance] ([staff]); không ai trong số họ đụng tới khách đặc biệt.
class LevelSession {
  LevelSession({
    required this.level,
    required LevelDefaults defaults,
    required BakeModifiers modifiers,
    int decorTipBonusPct = 0,
    this.setup = ShopSetup.base,
    Set<BoosterId> boosters = const {},
    bool tutorialActive = false,
    math.Random? random,
  })  : boosters = Set.unmodifiable(boosters),
        tuning = BoosterEffects.applyTo(setup.applyTo(level.tuningWith(defaults)), boosters),
        _zoneOvenSec = boosters.contains(BoosterId.ovenBoost)
            ? math.max(0.1, setup.applyTo(level.tuningWith(defaults)).ovenSec)
            : null,
        _modifiers = modifiers,
        _decorTipBonusPct = math.min(
          math.min(math.max(0, decorTipBonusPct), Economy.decorTipCapPct) + math.max(0, setup.tipPct),
          Economy.tipBonusCapPct,
        ),
        _spawnIntervalMult = setup.spawnIntervalMult,
        _random = random ?? math.Random() {
    _orders = OrderGenerator(_random);
    _case = DisplayCase._(setup.caseSlotsFor(level), tuning.slotCapacity);
    _kitchen = Kitchen._(math.max(1, tuning.ovens));
    _counter = List<LevelCustomer?>.filled(math.max(1, tuning.counterSpots), null);
    for (final r in level.menu) {
      _standardOrders[r] = _standardOrder(r);
    }
    // Pool khách dựng sẵn: vòng lặp nóng không cấp phát.
    for (var i = 0; i < poolSize; i++) {
      _pool.add(LevelCustomer._());
    }
    if (this.boosters.contains(BoosterId.fullCase)) {
      _fillCase();
    } else if (level.startStock > 0) {
      final first = level.menu.first;
      _case._add(first, math.min(level.startStock, _case.roomFor(first)), 3);
    }
    _unlockedToppings = [
      for (final t in ToppingId.values)
        if ((Catalog.toppingUnlockLevel[t] ?? 1) <= level.id) t,
    ];
    _nextSpawnAt = firstSpawnSec;
    final working = [
      for (final m in setup.staff)
        if (m.role != StaffRole.manager) m,
    ];
    _staff = List<StaffState>.unmodifiable([for (var i = 0; i < working.length; i++) StaffState._(working[i], i)]);
    var waiterSkill = 0.0;
    for (final st in _staff) {
      if (st.role == StaffRole.waiter) waiterSkill = math.max(waiterSkill, st.member.skillValue);
    }
    _queuePatienceMult = (1 - waiterSkill / 100).clamp(0.1, 1.0);
    // RNG riêng cho nhân viên (sao mẻ của thợ) để nhịp khách không đổi theo việc của thợ. Không có nhân viên → không
    // rút số nào từ _random (giữ nguyên chuỗi ngẫu nhiên như trước GĐ4).
    _staffRandom = _staff.isEmpty ? null : math.Random(_random.nextInt(1 << 30));
    final script = level.tutorial;
    _tutorial = tutorialActive && script != null ? _Tutorial._create(script, this) : null;
  }

  /// Bước logic cố định (giây).
  static const step = 1 / 30;

  /// Một khung dài hơn mức này (app khựng / vừa quay lại) chỉ được tính tối đa chừng này.
  static const maxFrameDt = 0.25;

  /// Ngừng sinh khách khi còn ít hơn chừng này giây.
  static const stopSpawnBeforeEndSec = 6.0;

  /// Khách đầu tiên tới sau chừng này giây.
  static const firstSpawnSec = 1.5;

  /// Kiên nhẫn trong hàng chờ giảm với tốc độ này (ở quầy: 1.0).
  static const queuePatienceRate = 0.5;

  /// Topping chuẩn của bánh vào tủ: món `toppings.first` × 3.
  static const standardToppingCount = 3;

  /// Đơn đặc biệt đạt từ chừng này sao mới tính vào mục tiêu `specialOrders`.
  static const specialGoodStars = 3;

  /// Combo tối đa được tính vào hệ số (x2.0).
  static const comboCap = 10;

  /// Độ rải sao mẻ của thợ quanh tay nghề: sao = round(tay nghề + (r − 0.5) × độ rải), r ∈ [0, 1), kẹp 1..5.
  static const staffStarSpread = 1.2;

  /// Thợ không chọn được món (tủ chưa có chỗ) → thử lại sau chừng này giây.
  static const staffRetrySec = 0.25;

  static const poolSize = 32;
  static const _maxQueuedEvents = 256;

  final LevelData level;

  /// Thông số đã áp ghi đè của level, đồ đã mua ([setup]) và vật phẩm hỗ trợ ([boosters]).
  final LevelDefaults tuning;

  /// Vật phẩm hỗ trợ của lượt (GĐ6, chỉ đọc; bên tạo session đã trừ kho / kim cương — session không đọc `GameState`).
  /// `patience` / `ovenBoost` đã nằm trong [tuning]; `fullCase` xếp tủ lúc tạo. dev-game vẽ hiệu ứng theo đây.
  final Set<BoosterId> boosters;

  /// Tiệm của lượt chơi (mở rộng + thiết bị đã mua) — dev-game vẽ kệ bánh tầng, lò thứ 2, bàn ghế… theo đây.
  /// Số ô tủ = `level.caseSlots` + `setup.caseSlotsBonus` ([displayCase]).
  final ShopSetup setup;

  /// true → [advance] không chạy gì (kể cả kiên nhẫn). `beginSpecial` tự bật, `finishSpecial`/`cancelSpecial` tự tắt.
  bool paused = false;

  late final _Tutorial? _tutorial;

  final BakeModifiers _modifiers;

  /// `ovenBoost`: giây lò KHÔNG có vật phẩm — kim chạy theo [tuning] (nhanh gấp đôi) tới mép vùng "được"
  /// (`bakeTarget − bakeOkHalfWidth`), từ đó chạy theo giây này, nên vùng vàng / hoàn hảo / lúc cháy tính theo giây giữ
  /// nguyên như không dùng vật phẩm (Lò ×2 không làm khó lấy đúng vạch hơn). null = không có `ovenBoost`.
  final double? _zoneOvenSec;
  final int _decorTipBonusPct;
  final double _spawnIntervalMult;
  final math.Random _random;
  late final OrderGenerator _orders;
  late final DisplayCase _case;
  late final Kitchen _kitchen;
  late final List<LevelCustomer?> _counter;
  late final List<ToppingId> _unlockedToppings;
  final Map<RecipeId, Order> _standardOrders = {};

  final List<LevelCustomer> _pool = [];
  final List<LevelCustomer> _active = [];
  late final List<LevelCustomer> _activeView = UnmodifiableListView(_active);
  final List<LevelCustomer> _queue = [];
  LevelCustomer? _special;
  int _nextSpecial = 0;
  int _nextId = 1;

  late final List<StaffState> _staff;
  late final double _queuePatienceMult;
  late final math.Random? _staffRandom;
  int _staffSales = 0;
  int _staffBakes = 0;

  /// Số khách đang muốn từng món (theo `RecipeId.index`) — dựng một lần, thợ bánh dùng lại.
  final List<int> _demand = List<int>.filled(RecipeId.values.length, 0);

  final List<SessionEvent> _events = [];
  final ValueNotifier<int> _hud = ValueNotifier<int>(0);

  double _acc = 0;
  double _elapsed = 0;
  int _extraSec = 0;
  bool _timeAdded = false;
  bool _over = false;
  bool _rush = false;
  double _nextSpawnAt = 0;
  int _lastHudSecond = -1;

  int _coins = 0;
  int _tips = 0;
  int _served = 0;
  int _lost = 0;
  int _specialsDone = 0;
  int _specialsMissed = 0;
  int _specialsGood = 0;
  int _specialsSkipped = 0;
  int _combo = 0;
  int _bestCombo = 0;
  double _lastSaleAt = -1e9;
  int _perfectBakes = 0;
  int _treatStars = 0;
  int _fiveStar = 0;
  final Map<RecipeId, int> _recipeStars = {};
  LevelResult? _result;

  /// Vật phẩm `fullCase` (thay cho `startStock`): mỗi ô một món, đủ sức chứa, bánh [BoosterEffects.fullCaseStars]★
  /// topping chuẩn; món mới của level xếp trước, rồi theo menu (ô nhiều hơn món → lặp vòng). Menu nhiều món hơn số ô →
  /// chừa một ô trống để món còn lại vẫn làm được (tủ đầy hết thì món thiếu không có chỗ cho tới khi bán sạch một ô).
  void _fillCase() {
    final menu = level.menu;
    final fresh = level.newRecipe;
    final order = [
      if (fresh != null && menu.contains(fresh)) fresh,
      for (final r in menu)
        if (r != fresh) r,
    ];
    final fill = menu.length > _case.slots ? _case.slots - 1 : _case.slots;
    for (var i = 0; i < fill; i++) {
      _case._add(order[i % order.length], _case.slotCapacity, BoosterEffects.fullCaseStars);
    }
  }

  // ------------------------------------------------------------------ Đọc

  BakeModifiers get modifiers => _modifiers;

  /// Tổng % tip cộng thêm của lượt: trang trí (trần `Economy.decorTipCapPct`) + mở rộng (`setup.tipPct`), trần
  /// `Economy.tipBonusCapPct` — truyền nguyên giá trị này cho `Scoring.evaluate` của đơn đặc biệt.
  int get decorTipBonusPct => _decorTipBonusPct;

  /// Tổng thời lượng hiện tại (gồm +30 giây nếu đã dùng).
  double get duration => (level.durationSec + _extraSec).toDouble();
  double get elapsed => _elapsed;
  double get timeLeft => math.max(0.0, duration - _elapsed);
  bool get isOver => _over;

  /// Đang giờ cao điểm.
  bool get isRush => _rush;

  int get coins => _coins;
  int get served => _served;

  /// Đã bán / phục vụ ít nhất một khách (người chơi, nhân viên, hay đơn đặc biệt). Chưa → UI cho hoàn vật phẩm khi
  /// Thoát / Chơi lại (`GameState.refundBoosters`).
  bool get hasSold => _served > 0;
  int get lost => _lost;
  /// Mọi đơn đặc biệt đã làm xong (kể cả dưới 3★).
  int get specialsDone => _specialsDone;

  /// Đơn đặc biệt đạt ≥ [specialGoodStars]★ — giá trị mục tiêu của level `specialOrders`.
  int get specialsGood => _specialsGood;

  /// Lượt ghé đặc biệt bị bỏ vì quá `bySec` mà chưa phục vụ đủ `afterServed` khách.
  int get specialsSkipped => _specialsSkipped;

  /// Lượt ghé đặc biệt kế tiếp chưa tới (null nếu hết) — HUD có thể hiện "Hòa ghé khi phục vụ N khách trước X giây".
  SpecialVisit? get nextSpecialVisit => _nextSpecial < level.specials.length ? level.specials[_nextSpecial] : null;
  int get combo => _combo;
  int get bestCombo => _bestCombo;

  /// 1.0 .. 2.0.
  double get comboMult => _combo <= 1 ? 1.0 : 1 + 0.1 * math.min(_combo - 1, comboCap);

  /// Giây còn lại của cửa sổ combo (0 nếu không có combo).
  double get comboTimeLeft => _combo == 0 ? 0 : math.max(0.0, tuning.comboWindowSec - (_elapsed - _lastSaleAt));

  /// Giá trị so với mốc sao (xu / khách đã phục vụ / đơn đặc biệt đạt ≥3★ = [specialsGood]).
  int get goalValue => switch (level.goal.type) {
        GoalType.coins => _coins,
        GoalType.customers => _served,
        GoalType.specialOrders => _specialsGood,
      };

  /// 0..3 theo mốc.
  int get starsNow => level.goal.starsFor(goalValue);

  /// Mọi khách đang trong cảnh (vào, chờ, quầy, rời đi). Danh sách chỉ đọc, phần tử tái dùng.
  List<LevelCustomer> get customers => _activeView;

  /// Khách đặc biệt đang ở chỗ đặc biệt (null nếu trống).
  LevelCustomer? get specialCustomer => _special;

  DisplayCase get displayCase => _case;
  Kitchen get kitchen => _kitchen;

  /// Nhân viên làm trong màn (thứ tự `setup.staff`, bỏ quản lý). Danh sách chỉ đọc, dựng một lần.
  List<StaffState> get staff => _staff;

  /// Lượt bán do nhân viên (thu ngân + phục vụ).
  int get staffSales => _staffSales;

  /// Số mẻ thợ bánh đã cho vào tủ.
  int get staffBakes => _staffBakes;

  /// Hệ số tốc độ giảm kiên nhẫn trong hàng chờ (1 = như gốc; phục vụ có tay nghề → nhỏ hơn).
  double get queuePatienceMult => _queuePatienceMult;

  /// Hướng dẫn lần đầu của lượt này: có khi `level.tutorial != null` và người tạo session truyền
  /// `tutorialActive: true` (UI: `!GameState.isTutorialDone(level.tutorial!)`; bot cân bằng: không). Session không đọc
  /// `GameState`.
  TutorialRunner? get tutorial => _tutorial;

  /// Bước hướng dẫn đang hiện dừng giờ: không sinh khách, kiên nhẫn không giảm, đồng hồ màn + nhân viên + khách đặc
  /// biệt chờ; lò, hoạt cảnh khách và thao tác của người chơi vẫn chạy.
  bool get tutorialBlocking => _tutorial?._blocking ?? false;

  /// Chạm để ẩn bước hướng dẫn thông tin (bước có `autoHide`); false nếu bước hiện tại không ẩn bằng chạm.
  bool dismissTutorialStep() => _tutorial?._dismiss() ?? false;

  /// Tăng khi số liệu HUD đổi (xu, giây còn lại, combo, mục tiêu, khách bỏ đi, hết giờ).
  ValueListenable<int> get hudRevision => _hud;

  /// Sự kiện từ lần gọi trước (rỗng → danh sách const, không cấp phát).
  List<SessionEvent> drainEvents() {
    if (_events.isEmpty) return const [];
    final out = List<SessionEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Khách có id (null nếu đã rời cảnh).
  LevelCustomer? customer(int id) {
    for (final c in _active) {
      if (c._id == id) return c;
    }
    return null;
  }

  /// Đơn chuẩn của bánh vào tủ (kem đầu, topping đầu × 3, hộp chuẩn) — UI vẽ bánh mẫu.
  Order standardOrder(RecipeId r) => _standardOrders[r] ?? _standardOrder(r);

  // ------------------------------------------------------------------ Thời gian

  /// Gọi mỗi khung hình (Flame update). Gom vào bước cố định [step].
  void advance(double dt) {
    if (paused || _over || !(dt > 0)) return;
    _acc += math.min(dt, maxFrameDt);
    while (_acc >= step - 1e-9) {
      _acc -= step;
      _tick(step);
      if (_over || paused) {
        _acc = 0;
        break;
      }
    }
  }

  void _tick(double h) {
    final tutorial = _tutorial;
    if (tutorial != null && tutorial._blocking) {
      // Bước hướng dẫn dừng giờ: chỉ hoạt cảnh khách (không trừ kiên nhẫn) + bếp của người chơi.
      _updateCustomers(h, drainPatience: false);
      _updateKitchen(h);
      tutorial._update(h);
      return;
    }

    _elapsed += h;
    if (_elapsed >= duration - 1e-9) {
      _elapsed = duration;
      _over = true;
      tutorial?._onTimeUp();
      _emit(const SessionEvent(SessionEventType.timeUp));
      _bumpHud();
      return;
    }

    final progress = _elapsed / level.durationSec;
    if (!_rush && level.spawn.isRushAt(progress)) {
      _rush = true;
      _emit(const SessionEvent(SessionEventType.rushStarted));
    }

    // Khách vãng lai.
    if (_elapsed >= _nextSpawnAt) {
      if (timeLeft >= stopSpawnBeforeEndSec) _spawnWalkIn();
      final jitter = 1 + (_random.nextDouble() * 2 - 1) * tuning.jitterPct / 100;
      _nextSpawnAt = _elapsed + math.max(0.3, level.spawn.intervalAt(progress) * _spawnIntervalMult * jitter);
    }

    // Khách đặc biệt (theo thứ tự; lượt sau chờ lượt trước tới). Quá `bySec` mà chưa đủ khách → bỏ lượt đó.
    while (_nextSpecial < level.specials.length) {
      final visit = level.specials[_nextSpecial];
      final by = visit.bySec;
      if (by == null || _elapsed <= by || _served >= visit.afterServed) break;
      _nextSpecial++;
      _specialsSkipped++;
      _bumpHud();
    }
    if (_special == null && _nextSpecial < level.specials.length) {
      final visit = level.specials[_nextSpecial];
      if (_elapsed >= visit.atSec && _served >= visit.afterServed) {
        _spawnSpecial(visit);
        _nextSpecial++;
      }
    }

    _updateCustomers(h);
    _updateKitchen(h);
    if (_staff.isNotEmpty) _updateStaff(h);

    // Combo hết cửa sổ.
    if (_combo > 0 && _elapsed - _lastSaleAt > tuning.comboWindowSec) _resetCombo();

    final second = timeLeft.ceil();
    if (second != _lastHudSecond) {
      _lastHudSecond = second;
      _bumpHud();
    }
    tutorial?._update(h);
  }

  // ------------------------------------------------------------------ Khách

  LevelCustomer _obtain() {
    final c = _pool.isNotEmpty ? _pool.removeLast() : LevelCustomer._();
    c._reset(_nextId++);
    _active.add(c);
    return c;
  }

  int get _walkInsInLine {
    var n = _queue.length;
    for (var i = 0; i < _counter.length; i++) {
      if (_counter[i] != null) n++;
    }
    return n;
  }

  void _spawnWalkIn() {
    final c = _obtain();
    c._look = Customer(kind: CustomerKind.regular, appearanceSeed: _random.nextInt(1 << 30));
    _pickWants(c);
    c._patienceMax = math.max(1.0, level.patienceSec * tuning.patienceMult);
    c._patience = c._patienceMax;
    if (_walkInsInLine >= tuning.maxQueue) {
      // Hàng đầy: quay đi ngay ở cửa.
      c._turnedAway = true;
      c._slot = -1;
      c._setPhase(CustomerPhase.leavingSad);
      _lost++;
      _resetCombo();
      _emit(SessionEvent(SessionEventType.turnedAway, customerId: c._id, recipe: c.want));
      _bumpHud();
      return;
    }
    c._slot = _queue.length;
    _queue.add(c);
    _emit(SessionEvent(SessionEventType.customerArrived, customerId: c._id, recipe: c.want));
  }

  /// Món mới của level trọng số 2, các món khác 1; `flexibleChance` → thêm món thứ 2 khác món đầu.
  void _pickWants(LevelCustomer c) {
    final menu = level.menu;
    final fresh = level.newRecipe;
    final total = menu.length + (fresh != null && menu.contains(fresh) ? 1 : 0);
    var roll = _random.nextInt(total);
    var first = menu.last;
    for (final r in menu) {
      roll -= r == fresh ? 2 : 1;
      if (roll < 0) {
        first = r;
        break;
      }
    }
    c._wants.add(first);
    if (menu.length > 1 && level.flexibleChance > 0 && _random.nextDouble() < level.flexibleChance) {
      var k = _random.nextInt(menu.length - 1);
      for (final r in menu) {
        if (r == first) continue;
        if (k-- == 0) {
          c._wants.add(r);
          break;
        }
      }
    }
  }

  void _spawnSpecial(SpecialVisit visit) {
    final c = _obtain();
    c._isSpecial = true;
    c._visit = visit;
    final seed = _random.nextInt(1 << 30);
    c._look = switch (visit.who) {
      SpecialWho.hoa => Customer(kind: CustomerKind.friend, friend: FriendId.hoa, appearanceSeed: seed),
      SpecialWho.linh => Customer(kind: CustomerKind.friend, friend: FriendId.linh, appearanceSeed: seed),
      SpecialWho.kenji => Customer(kind: CustomerKind.friend, friend: FriendId.kenji, appearanceSeed: seed),
      // Ảnh VIP = appearanceSeed % 3; không ghi `look` → vip_01 hoặc vip_02 (vip_00 = bà Rosa, chỉ khi ghi rõ).
      SpecialWho.vip => Customer(kind: CustomerKind.vip, appearanceSeed: visit.vipLookIndex ?? 1 + seed % 2),
    };
    final scene = visit.scene == null ? null : Catalog.storyScene(visit.scene!);
    c._order = _orders.makeOrder(
      id: c._id,
      customer: c._look,
      recipe: visit.recipe,
      level: level.id,
      unlockedToppings: _unlockedToppings,
      forcedToppings: scene?.featuredRecipe == visit.recipe ? scene?.forcedToppings : null,
      box: visit.box,
    );
    c._wants.add(visit.recipe);
    c._patienceMax = math.max(1.0, tuning.specialPatienceSec);
    c._patience = c._patienceMax;
    c._slot = 0;
    _special = c;
    _emit(SessionEvent(SessionEventType.specialArrived, customerId: c._id, recipe: visit.recipe));
  }

  /// [drainPatience] false (bước hướng dẫn dừng giờ) → chỉ chạy hoạt cảnh, kiên nhẫn đứng yên.
  void _updateCustomers(double h, {bool drainPatience = true}) {
    for (var i = _active.length - 1; i >= 0; i--) {
      final c = _active[i];
      switch (c._phase) {
        case CustomerPhase.entering:
          c._phaseT += h / LevelCustomer.enterSec;
          if (drainPatience) c._patience -= h * (c._isSpecial ? 1 : queuePatienceRate * _queuePatienceMult);
          if (c._phaseT >= 1) {
            c._setPhase(c._isSpecial ? CustomerPhase.atCounter : CustomerPhase.queued);
            c._phaseT = 1;
          }
        case CustomerPhase.queued:
          if (c._phaseT < 1) c._phaseT = math.min(1.0, c._phaseT + h / LevelCustomer.shiftSec);
          if (drainPatience) c._patience -= h * queuePatienceRate * _queuePatienceMult;
        case CustomerPhase.atCounter:
          if (c._phaseT < 1) c._phaseT = math.min(1.0, c._phaseT + h / LevelCustomer.toCounterSec);
          if (drainPatience) c._patience -= h;
        case CustomerPhase.leavingHappy:
        case CustomerPhase.leavingSad:
          c._phaseT += h / LevelCustomer.leaveSec;
          if (c._phaseT >= 1) {
            _active.removeAt(i);
            _pool.add(c);
          }
          continue;
      }
      if (c._patience <= 0) {
        c._patience = 0;
        _walkOut(c);
      }
    }
    _fillCounter();
  }

  /// Đưa khách đầu hàng (đã đứng hàng) lên chỗ quầy trống.
  void _fillCounter() {
    while (_queue.isNotEmpty && _queue.first._phase == CustomerPhase.queued) {
      final spot = _freeCounterSpot();
      if (spot < 0) return;
      final c = _queue.removeAt(0);
      _counter[spot] = c;
      c._slot = spot;
      c._setPhase(CustomerPhase.atCounter);
      _renumberQueue();
    }
  }

  int _freeCounterSpot() {
    for (var i = 0; i < _counter.length; i++) {
      if (_counter[i] == null) return i;
    }
    return -1;
  }

  void _renumberQueue() {
    for (var i = 0; i < _queue.length; i++) {
      final c = _queue[i];
      if (c._slot != i) {
        c._slot = i;
        if (c._phase == CustomerPhase.queued) c._phaseT = 0; // hoạt cảnh dịch lên
      }
    }
  }

  /// Gỡ khách khỏi hàng/quầy/chỗ đặc biệt (không đổi pha).
  void _detach(LevelCustomer c) {
    if (_special == c) {
      _special = null;
      return;
    }
    for (var i = 0; i < _counter.length; i++) {
      if (_counter[i] == c) {
        _counter[i] = null;
        return;
      }
    }
    if (_queue.remove(c)) _renumberQueue();
  }

  void _walkOut(LevelCustomer c) {
    _detach(c);
    c._setPhase(CustomerPhase.leavingSad);
    if (c._isSpecial) {
      _specialsMissed++;
      _emit(SessionEvent(SessionEventType.specialLeft, customerId: c._id, recipe: c.want));
      return;
    }
    _lost++;
    _resetCombo();
    _emit(SessionEvent(SessionEventType.walkedOut, customerId: c._id, recipe: c.want));
    _bumpHud();
    _tutorial?._onWalkout(c);
  }

  void _resetCombo() {
    if (_combo == 0) return;
    final was = _combo;
    _combo = 0;
    _emit(SessionEvent(SessionEventType.comboLost, combo: was));
    _bumpHud();
  }

  // ------------------------------------------------------------------ Bán

  /// Bán cho khách vãng lai đang ở quầy: lấy bánh sao cao nhất của món khách muốn (ưu tiên món đầu).
  SellResult sell(int customerId) {
    if (_over || paused) return SellResult.invalid;
    LevelCustomer? c;
    for (final k in _counter) {
      if (k != null && k._id == customerId) c = k;
    }
    if (c == null || !c.canBuy) return SellResult.invalid;
    final recipe = _wantInCase(c);
    if (recipe == null) return SellResult.notInCase;
    _sellTo(c, recipe, null);
    final tutorial = _tutorial;
    if (tutorial != null) {
      tutorial._onPlayerSold();
      tutorial._sync();
    }
    return SellResult.sold;
  }

  /// Món đầu tiên khách muốn mà tủ đang có (null nếu không có).
  RecipeId? _wantInCase(LevelCustomer c) {
    final wants = c._wants;
    for (var i = 0; i < wants.length; i++) {
      if (_case.countOf(wants[i]) > 0) return wants[i];
    }
    return null;
  }

  /// Bán [recipe] cho khách vãng lai [c] (ở quầy hoặc trong hàng chờ): bánh sao cao nhất, combo, tip. [by] = nhân
  /// viên bán (thu ngân cộng tip theo tay nghề) → sự kiện `staffSold`; null = người chơi → `sold`.
  void _sellTo(LevelCustomer c, RecipeId recipe, StaffState? by) {
    final stars = _case._takeBest(recipe);

    _combo = _combo > 0 && _elapsed - _lastSaleAt <= tuning.comboWindowSec ? _combo + 1 : 1;
    _lastSaleAt = _elapsed;
    _bestCombo = math.max(_bestCombo, _combo);

    // Bí quyết của bà (GĐ8): giá bán món × hệ số của tiệm.
    final price = Catalog.recipe(recipe).price * setup.priceMultOf(recipe);
    final frac = c.patienceFrac;
    final tipShare = frac >= 0.5 - 1e-9 ? 1.0 : (frac >= 0.25 - 1e-9 ? 0.5 : 0.0);
    final staffTipPct = by != null && by.role == StaffRole.cashier ? math.max(0.0, by.member.skillValue) : 0.0;
    // Tổng % tip (trang trí + mở rộng + thu ngân) vẫn chịu trần `Economy.tipBonusCapPct`.
    final tipBonusPct = math.min(_decorTipBonusPct + staffTipPct, Economy.tipBonusCapPct.toDouble());
    final tip = price * (Economy.tipRate[stars] ?? 0) * tipShare * (1 + tipBonusPct / 100);
    final mult = comboMult;
    final gained = ((price * Economy.payMult[stars]! + tip) * mult).round();
    _coins += gained;
    _tips += (tip * mult).round();
    _served++;
    _treatStars += stars;
    if (stars == 5) _fiveStar++;

    _detach(c);
    c._setPhase(CustomerPhase.leavingHappy);
    _fillCounter();
    if (by == null) {
      _emit(SessionEvent(SessionEventType.sold,
          customerId: c._id, recipe: recipe, coins: gained, stars: stars, combo: _combo));
    } else {
      _staffSales++;
      by._actions++;
      by._lastActionAt = _elapsed;
      _emit(SessionEvent(SessionEventType.staffSold,
          customerId: c._id, recipe: recipe, coins: gained, stars: stars, combo: _combo, staffIndex: by.index));
    }
    _bumpHud();
  }

  // ------------------------------------------------------------------ Bếp nhanh

  /// Bắt đầu mẻ mới ở khu chuẩn bị (false nếu khu đang bận, món không thuộc menu, hoặc đã hết giờ).
  bool startBatch(RecipeId r) {
    if (_over || _kitchen._prep != null || !level.menu.contains(r)) return false;
    _kitchen._prep = Batch._(r, _random);
    _tutorial?._sync();
    return true;
  }

  /// Bỏ mẻ đang chuẩn bị (kể cả đang chờ lò).
  void cancelPrep() {
    _kitchen._prep = null;
    _tutorial?._sync();
  }

  /// Chọn khuôn; sai → `wrongMoulds++`, ở lại trạm, trả false.
  bool pickMould(MouldType m) {
    final b = _kitchen._prep;
    if (b == null || b._stage != BatchStage.mould) return false;
    if (m != b.correctMould) {
      b._wrongMoulds++;
      return false;
    }
    b._stage = BatchStage.mix;
    _tutorial?._sync();
    return true;
  }

  /// Nhấc tay sau khi xoay; mục tiêu 1.0 vòng. Mẻ tự vào lò trống (hoặc chờ lò).
  void finishMix(double turns) {
    final b = _kitchen._prep;
    if (b == null || b._stage != BatchStage.mix) return;
    b._mixTurns = turns.isFinite ? math.max(0.0, turns) : 0;
    b._stage = BatchStage.waitingOven;
    _tryLoadOven();
    _tutorial?._sync();
  }

  /// Chạm lò: lấy mẻ ra (release = vị trí kim). Khu hoàn thiện bận → mẻ dừng nướng, nằm trong lò chờ.
  bool takeOut(int oven) {
    if (_over || oven < 0 || oven >= _kitchen._ovens.length) return false;
    final b = _kitchen._ovens[oven];
    if (b == null || b._stage != BatchStage.baking) return false;
    b._bakeRelease = b._ovenProgress;
    b._stage = BatchStage.ovenDone;
    _tryMoveToFinish();
    _tutorial?._sync();
    return true;
  }

  /// Độ phủ kem 0..1.
  void finishFrost(double coverage) {
    final b = _kitchen._finish;
    if (b == null || b._stage != BatchStage.frost) return;
    b._frostCoverage = coverage.isFinite ? coverage.clamp(0.0, 1.0) : 0;
    b._stage = BatchStage.topping;
    _tutorial?._sync();
  }

  /// Một lần chạm hũ topping; đủ 3 lần → sang Hộp.
  void addTopping(ToppingId t) {
    final b = _kitchen._finish;
    if (b == null || b._stage != BatchStage.topping) return;
    b._toppings[t] = (b._toppings[t] ?? 0) + 1;
    b._toppingsPlaced++;
    if (b._toppingsPlaced >= Batch.toppingTaps) {
      b._stage = BatchStage.box;
      _tutorial?._sync();
    }
  }

  /// Chọn hộp → chấm mẻ → vào tủ (tủ đầy: nằm chờ ở Hộp, sự kiện `caseFull`). false nếu không có mẻ ở trạm Hộp.
  bool pickBox(BoxType box) {
    final b = _kitchen._finish;
    if (b == null || b._stage != BatchStage.box) return false;
    b._box = box;
    final result = Scoring.evaluate(
      order: standardOrder(b.recipe),
      customer: _standardCustomer,
      outcome: BakeOutcome(
        wrongMouldDrops: b._wrongMoulds,
        // Scoring.mix so với `recipe.mixTurns`; bếp nhanh nhắm 1 vòng → quy đổi cùng tỉ lệ.
        mixTurns: b._mixTurns * b.recipeData.mixTurns,
        bakeRelease: b._bakeRelease,
        frostCoverage: b._frostCoverage,
        toppingsPlaced: b._toppings,
        boxChosen: box,
      ),
      modifiers: _modifiers,
      decorTipBonusPct: _decorTipBonusPct,
    );
    b._result = result;
    if (result.isPerfectBake) _perfectBakes++;
    _noteRecipeStars(b.recipe, result.stars);
    b._stage = BatchStage.waitingCase;
    if (!_tryPlaceFinished()) {
      _emit(SessionEvent(SessionEventType.caseFull, recipe: b.recipe, stars: result.stars));
    }
    _tutorial?._sync();
    return true;
  }

  void _updateKitchen(double h) {
    final ovens = _kitchen._ovens;
    final ovenSec = math.max(0.1, tuning.ovenSec);
    final zoneSec = _zoneOvenSec;
    for (var i = 0; i < ovens.length; i++) {
      final b = ovens[i];
      if (b == null || b._stage != BatchStage.baking) continue;
      b._ovenElapsed += h;
      b._ovenProgress = math.min(1.0, zoneSec == null ? b._ovenElapsed / ovenSec * b.bakeTarget : _boostedProgress(b, ovenSec, zoneSec));
      if (!b._ovenReadyAnnounced && b._ovenProgress >= b.bakeTarget) {
        b._ovenReadyAnnounced = true;
        _emit(SessionEvent(SessionEventType.ovenReady, oven: i, recipe: b.recipe));
      }
      if (b._ovenProgress >= 1.0) {
        b._bakeRelease = 1.0;
        b._burnt = true;
        b._stage = BatchStage.ovenDone;
        _emit(SessionEvent(SessionEventType.burnt, oven: i, recipe: b.recipe));
      }
    }
    final f = _kitchen._finish;
    if (f != null && f._stage == BatchStage.waitingCase) _tryPlaceFinished();
    _tryMoveToFinish();
    _tryLoadOven();
  }

  /// Kim lò của mẻ [b] khi có `ovenBoost` (xem [_zoneOvenSec]).
  double _boostedProgress(Batch b, double fastSec, double zoneSec) {
    final edge = math.max(0.0, b.bakeTarget - _modifiers.bakeOkHalfWidth);
    final t0 = edge / b.bakeTarget * fastSec;
    final t = b._ovenElapsed;
    return t <= t0 ? t / fastSec * b.bakeTarget : edge + (t - t0) / zoneSec * b.bakeTarget;
  }

  /// Giây lò còn lại tới khi kim của mẻ [b] (đang nướng) chạm [progress] (0 nếu đã qua) — tính cả `ovenBoost` (bot dùng
  /// để không bắt đầu việc dài khi lò sắp tới vạch).
  double ovenSecondsUntil(Batch b, double progress) {
    final fastSec = math.max(0.1, tuning.ovenSec);
    final zoneSec = _zoneOvenSec;
    double timeAt(double p) {
      if (zoneSec == null) return p / b.bakeTarget * fastSec;
      final edge = math.max(0.0, b.bakeTarget - _modifiers.bakeOkHalfWidth);
      return p <= edge ? p / b.bakeTarget * fastSec : edge / b.bakeTarget * fastSec + (p - edge) / b.bakeTarget * zoneSec;
    }

    return math.max(0.0, timeAt(progress) - b._ovenElapsed);
  }

  void _tryLoadOven() {
    final b = _kitchen._prep;
    if (b == null || b._stage != BatchStage.waitingOven) return;
    final oven = _kitchen.freeOven;
    if (oven < 0) return;
    _kitchen._ovens[oven] = b;
    _kitchen._prep = null;
    b._oven = oven;
    b._stage = BatchStage.baking;
    b._ovenElapsed = 0;
    b._ovenProgress = 0;
    _emit(SessionEvent(SessionEventType.ovenStarted, oven: oven, recipe: b.recipe));
  }

  void _tryMoveToFinish() {
    if (_kitchen._finish != null) return;
    final ovens = _kitchen._ovens;
    for (var i = 0; i < ovens.length; i++) {
      final b = ovens[i];
      if (b != null && b._stage == BatchStage.ovenDone) {
        ovens[i] = null;
        b._oven = -1;
        b._stage = BatchStage.frost;
        _kitchen._finish = b;
        return;
      }
    }
  }

  bool _tryPlaceFinished() {
    final b = _kitchen._finish;
    if (b == null || b._stage != BatchStage.waitingCase) return false;
    final n = tuning.batchSize;
    if (!_case._add(b.recipe, n, b.stars, b.placedTopping)) return false;
    _kitchen._finish = null;
    _emit(SessionEvent(SessionEventType.batchReady, recipe: b.recipe, stars: b.stars, count: n));
    _tryMoveToFinish();
    return true;
  }

  void _noteRecipeStars(RecipeId r, int stars) {
    if (stars > (_recipeStars[r] ?? 0)) _recipeStars[r] = stars;
  }

  static const _standardCustomer = Customer(kind: CustomerKind.regular, appearanceSeed: 0);

  static Order _standardOrder(RecipeId r) {
    final data = Catalog.recipe(r);
    return Order(
      id: -1,
      recipe: r,
      frosting: data.frostings.first,
      toppings: [ToppingRequest(data.toppings.first, standardToppingCount)],
      box: data.box,
      line: OrderLineKind.generic1,
    );
  }

  // ------------------------------------------------------------------ Nhân viên

  /// Nhân viên tự làm (sau khách + bếp nhanh của người chơi). Không cấp phát, không đụng khách đặc biệt.
  void _updateStaff(double h) {
    for (var i = 0; i < _staff.length; i++) {
      final st = _staff[i];
      switch (st.member.role) {
        case StaffRole.cashier:
          _staffSell(st, h, _cashierTarget());
        case StaffRole.waiter:
          _staffSell(st, h, _waiterTarget());
        case StaffRole.baker:
          _staffBake(st, h);
        case StaffRole.manager:
          break;
      }
    }
  }

  /// Thu ngân / phục vụ: phục vụ một khách mất `speedValue` giây (tiến độ chỉ chạy khi có khách mua được món trong
  /// tủ); xong → bán, tiến độ về 0. Khách đổi (người chơi đã bán / khách bỏ đi / tủ hết món) → làm lại từ 0.
  void _staffSell(StaffState st, double h, LevelCustomer? target) {
    final id = target?._id;
    if (id != st._target) {
      st._target = id;
      st._progress = 0;
    }
    if (target == null) return;
    st._progress = math.min(1.0, st._progress + h / math.max(0.1, st.member.speedValue));
    if (st._progress < 1) return;
    final recipe = _wantInCase(target);
    if (recipe == null) return;
    st._progress = 0;
    st._target = null;
    _sellTo(target, recipe, st);
  }

  /// Khách ở quầy kiên nhẫn thấp nhất (= đứng lâu nhất) có món trong tủ.
  LevelCustomer? _cashierTarget() {
    LevelCustomer? best;
    for (var i = 0; i < _counter.length; i++) {
      final c = _counter[i];
      if (c == null || !c.canBuy || _wantInCase(c) == null) continue;
      if (best == null || c._patience < best._patience) best = c;
    }
    return best;
  }

  /// Khách đang đứng hàng chờ (chưa tới quầy) kiên nhẫn thấp nhất có món trong tủ.
  LevelCustomer? _waiterTarget() {
    LevelCustomer? best;
    for (var i = 0; i < _queue.length; i++) {
      final c = _queue[i];
      if (c._isSpecial || c._phase != CustomerPhase.queued || _wantInCase(c) == null) continue;
      if (best == null || c._patience < best._patience) best = c;
    }
    return best;
  }

  /// Thợ bánh (làn riêng, không chiếm lò/khu của người chơi): chọn món ([_bakerPick]) → sau `speedValue` giây cho
  /// `batchSize` cái vào tủ; tủ chưa đủ chỗ → giữ mẻ chờ. Không có món để làm → thử lại sau [staffRetrySec].
  void _staffBake(StaffState st, double h) {
    if (st._working == null) {
      if (_elapsed < st._retryAt) return;
      final r = _bakerPick(st);
      if (r == null) {
        st._progress = 0;
        st._retryAt = _elapsed + staffRetrySec;
        return;
      }
      st._working = r;
      st._progress = 0;
      final roll = _staffRandom?.nextDouble() ?? 0.5;
      st._workingStars = (st.member.skillValue + (roll - 0.5) * staffStarSpread).round().clamp(1, 5);
    }
    if (st._progress < 1) {
      st._progress = math.min(1.0, st._progress + h / math.max(0.1, st.member.speedValue));
      if (st._progress < 1) return;
    }
    final r = st._working!;
    final n = tuning.batchSize;
    if (!_case._add(r, n, st._workingStars)) return;
    _staffBakes++;
    st._actions++;
    st._lastActionAt = _elapsed;
    st._working = null;
    st._progress = 0;
    _emit(SessionEvent(SessionEventType.staffBatchReady,
        recipe: r, stars: st._workingStars, count: n, staffIndex: st.index));
  }

  /// Chọn món cho thợ: món khách đang trong tiệm muốn (món đầu, bỏ khách đặc biệt) mà tủ + mọi mẻ đang làm còn thiếu
  /// nhiều nhất; cùng mức thiếu → món ít nhất trong tủ, rồi theo thứ tự menu. Tủ phải còn chỗ cho cả mẻ (chừa chỗ cho
  /// mẻ cùng món của thợ khác và của người chơi). Không ai thiếu → null (thợ chờ): bot cân bằng cho thấy thợ lấp tủ
  /// bằng bánh 3★ khi không có khách cần thì kéo thu nhập của người chơi xuống.
  RecipeId? _bakerPick(StaffState self) {
    final menu = level.menu;
    final n = tuning.batchSize;
    final demand = _demand;
    for (var i = 0; i < demand.length; i++) {
      demand[i] = 0;
    }
    for (var i = 0; i < _active.length; i++) {
      final c = _active[i];
      if (!c._isSpecial && !c.isLeaving && c._wants.isNotEmpty) demand[c._wants.first.index]++;
    }
    RecipeId? best;
    var bestDeficit = 0, bestStock = 1 << 30;
    for (var i = 0; i < menu.length; i++) {
      final r = menu[i];
      if (demand[r.index] == 0) continue;
      var pending = 0;
      for (var j = 0; j < _staff.length; j++) {
        final other = _staff[j];
        if (!identical(other, self) && other._working == r) pending++;
      }
      final cooking = pending + _kitchen.batchesOf(r);
      if (_case.roomFor(r) < n * (1 + cooking)) continue;
      final stock = _case.countOf(r);
      final deficit = demand[r.index] - stock - cooking * n;
      if (deficit > bestDeficit || (deficit == bestDeficit && deficit > 0 && stock < bestStock)) {
        bestDeficit = deficit;
        bestStock = stock;
        best = r;
      }
    }
    return best;
  }

  // ------------------------------------------------------------------ Khách đặc biệt

  /// Chạm khách đặc biệt: tự `paused = true`, trả đơn để chạy `BakeSessionView` (null nếu không hợp lệ).
  Order? beginSpecial(int customerId) {
    final c = _special;
    if (_over || c == null || c._id != customerId || c.isLeaving || c._inSpecial) return null;
    c._inSpecial = true;
    paused = true;
    return c._order;
  }

  /// Xong 6 trạm: xu = (payment + tip) × `specialRewardMult` × hệ số giá của món (Bí quyết của bà, `setup`),
  /// `specialsDone++`, bỏ dừng.
  void finishSpecial(int customerId, BakeResult r) {
    final c = _special;
    if (c == null || c._id != customerId || !c._inSpecial) return;
    c._inSpecial = false;
    final mult = tuning.specialRewardMult * setup.priceMultOf(c.want);
    final gained = ((r.payment + r.tip) * mult).round();
    _coins += gained;
    _tips += (r.tip * mult).round();
    _specialsDone++;
    if (r.stars >= specialGoodStars) _specialsGood++;
    _served++;
    _treatStars += r.stars;
    if (r.stars == 5) _fiveStar++;
    if (r.isPerfectBake) _perfectBakes++;
    _noteRecipeStars(c.want, r.stars);
    _detach(c);
    c._setPhase(CustomerPhase.leavingHappy);
    paused = false;
    _emit(SessionEvent(SessionEventType.specialDone, customerId: c._id, recipe: c.want, coins: gained, stars: r.stars));
    _bumpHud();
  }

  /// Bỏ dở đơn đặc biệt (thoát màn 6 trạm): khách vẫn chờ, bỏ dừng.
  void cancelSpecial(int customerId) {
    final c = _special;
    if (c == null || c._id != customerId || !c._inSpecial) return;
    c._inSpecial = false;
    paused = false;
  }

  // ------------------------------------------------------------------ Kết thúc

  /// +30 giây (rewarded) dùng được một lần mỗi lượt.
  bool get canAddTime => !_timeAdded;

  /// Cộng giờ và chơi tiếp (kể cả khi đã hết giờ). Lần thứ hai bị bỏ qua.
  void addTime(int seconds) {
    if (_timeAdded || seconds <= 0) return;
    _timeAdded = true;
    _extraSec += seconds;
    _over = false;
    _result = null;
    _bumpHud();
  }

  /// Gọi khi [isOver] và UI xong hỏi +30 giây. Gọi lại trả cùng kết quả.
  LevelResult finish() => _result ??= LevelResult(
        levelId: level.id,
        won: goalValue >= level.goal.target,
        stars: starsNow,
        coins: _coins,
        served: _served,
        lost: _lost,
        specialsDone: _specialsDone,
        bestCombo: _bestCombo,
        perfectBakes: _perfectBakes,
        recipeStars: Map.unmodifiable(_recipeStars),
        goalValue: goalValue,
        tips: _tips,
        treatStars: _treatStars,
        fiveStarTreats: _fiveStar,
        specialsMissed: _specialsMissed,
        specialsGood: _specialsGood,
        timeAdded: _timeAdded,
        staffSales: _staffSales,
        staffBakes: _staffBakes,
        boosters: boosters,
      );

  /// Giải phóng [hudRevision].
  void dispose() => _hud.dispose();

  // ------------------------------------------------------------------ Nội bộ

  void _emit(SessionEvent e) {
    if (_events.length >= _maxQueuedEvents) _events.removeAt(0);
    _events.add(e);
  }

  void _bumpHud() => _hud.value++;
}
