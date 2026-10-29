import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'economy.dart';
import 'game_state.dart';
import 'models/bake.dart';
import 'models/customer.dart';
import 'models/day_summary.dart';
import 'models/mochi.dart';
import 'models/order.dart';
import 'models/story.dart';
import 'order_generator.dart';
import 'scoring.dart';
import 'weather.dart';

/// Điều khiển một ngày kinh doanh: sinh khách + đơn ngay khi tạo, chấm, ghi kết quả, tổng kết.
class DayController extends ChangeNotifier {
  DayController({required GameState state, math.Random? random})
      : _state = state,
        dayNumber = state.dayNumber,
        levelAtStart = state.level,
        isRainy = Weather.isRainy(state.dayNumber) {
    _pendingScene = _findPendingScene();
    final plan = OrderGenerator(random ?? math.Random()).generateDay(
      level: levelAtStart,
      unlockedRecipes: state.unlockedRecipes,
      unlockedToppings: state.unlockedToppings,
      seenScenes: state.seenScenes,
      scene: _pendingScene,
    );
    customers = plan.customers;
    orders = plan.orders;
  }

  final GameState _state;
  final int dayNumber;
  final int levelAtStart;

  /// Ngày mưa (theo [Weather.isRainy] của [dayNumber]).
  final bool isRainy;

  late final List<Customer> customers;
  late final List<Order> orders;

  StoryScene? _pendingScene;
  int _index = 0;
  final List<OrderRecord> _records = [];
  final Set<int> _remadeOrders = {};
  DaySummary? _summary;

  StoryScene? _findPendingScene() {
    for (final scene in Catalog.storyScenes) {
      if (_state.seenScenes.contains(scene.id)) continue;
      if (scene.minLevel <= levelAtStart && scene.minDay <= dayNumber) return scene;
    }
    return null;
  }

  /// Cảnh truyện chiếu trước khách đầu tiên; null nếu không có (tối đa 1 cảnh/ngày).
  StoryScene? get pendingScene => _pendingScene;

  /// Ghi đã xem cảnh → `state.markSceneSeen`.
  void markSceneShown() {
    final scene = _pendingScene;
    if (scene == null) return;
    _pendingScene = null;
    _state.markSceneSeen(scene.id);
    notifyListeners();
  }

  int get index => _index;
  int get total => orders.length;
  Customer get currentCustomer => customers[math.min(_index, total - 1)];
  Order get currentOrder => orders[math.min(_index, total - 1)];
  bool get isFinished => _index >= total;
  List<OrderRecord> get records => List.unmodifiable(_records);

  BakeModifiers get modifiers => _state.bakeModifiers;

  /// THUẦN, chưa đổi state.
  BakeResult evaluate(BakeOutcome outcome) => Scoring.evaluate(
        order: currentOrder,
        customer: currentCustomer,
        outcome: outcome,
        modifiers: modifiers,
        decorTipBonusPct: _state.decorTipBonusPct,
      );

  /// r.stars <= 2 && chưa làm lại đơn này && quảng cáo còn lượt.
  bool canRemake(BakeResult r) =>
      !isFinished &&
      r.stars <= 2 &&
      !_remadeOrders.contains(_index) &&
      _state.rewardedToday < Economy.maxRewardedPerDay;

  void markRemakeUsed() {
    if (_remadeOrders.add(_index)) notifyListeners();
  }

  /// `state.applyOrderResult` + lưu OrderRecord + sang khách kế.
  void commit(BakeResult r) {
    if (isFinished) return;
    _state.applyOrderResult(currentOrder, currentCustomer, r);
    _records.add(OrderRecord(order: currentOrder, customer: currentCustomer, result: r));
    _index++;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Mèo Mochi (ngày mưa)

  /// Chỉ số (0-based) của khách mà Mochi ghé ngay sau khi phục vụ xong: khách thứ `total ~/ 2` → `total ~/ 2 - 1`.
  /// null nếu trời tạnh hoặc hôm nay Mochi đã ghé (`state.lastMochiDay == dayNumber`, kể cả khi thoát ra vào lại).
  int? get mochiVisitAfterIndex {
    if (!isRainy || _state.lastMochiDay == dayNumber || total < 2) return null;
    return total ~/ 2 - 1;
  }

  /// true đúng lúc vừa `commit` xong khách thứ `total ~/ 2` (trước khi khách sau vào) và hôm nay chưa xử lý Mochi.
  /// UI kiểm tra sau `commit` ở nút "Khách tiếp"; hiện Mochi rồi gọi [petMochi] / [restMochi].
  bool get shouldShowMochi {
    final after = mochiVisitAfterIndex;
    return after != null && !isFinished && _index == after + 1;
  }

  /// Lần đầu gặp Mochi trong đời game (lời dẫn "lần đầu" thay vì "lại ghé").
  bool get isFirstMochiVisit => _state.mochiVisits == 0;

  /// Vuốt ve Mochi → `state.petMochi`; trả quà đã cộng (null nếu không đúng lúc / đã xử lý hôm nay).
  MochiGift? petMochi() => finishMochiVisit(pet: true);

  /// Để Mochi nghỉ → `state.restMochi` (không quà).
  void restMochi() => finishMochiVisit(pet: false);

  /// Kết thúc lượt ghé của Mochi hôm nay. Không đổi khách, đơn, chấm điểm hay tổng kết ngày.
  MochiGift? finishMochiVisit({required bool pet}) {
    if (!shouldShowMochi) return null;
    MochiGift? gift;
    if (pet) {
      gift = _state.petMochi(day: dayNumber);
    } else {
      _state.restMochi(day: dayNumber);
    }
    notifyListeners();
    return gift;
  }

  /// + dayBonusXp, `state.completeDay()`, trả tổng kết. Gọi lần nữa trả lại kết quả cũ.
  DaySummary finishDay() {
    final existing = _summary;
    if (existing != null) return existing;
    _state.addXp(Economy.dayBonusXp);
    _state.completeDay();
    final levelAfter = _state.level;
    var revenue = 0, tips = 0, costs = 0, xp = 0;
    for (final r in _records) {
      revenue += r.result.payment;
      tips += r.result.tip;
      costs += r.result.cost;
      xp += r.result.xp;
    }
    final summary = DaySummary(
      dayNumber: dayNumber,
      isRainy: isRainy,
      records: List.unmodifiable(_records),
      revenue: revenue,
      tips: tips,
      costs: costs,
      net: revenue + tips - costs,
      xpGained: xp + Economy.dayBonusXp,
      dayBonusXp: Economy.dayBonusXp,
      levelBefore: levelAtStart,
      levelAfter: levelAfter,
      unlocks: List.unmodifiable([
        for (var l = levelAtStart + 1; l <= levelAfter; l++) ...Economy.unlocksAtLevel(l),
      ]),
    );
    _summary = summary;
    notifyListeners();
    return summary;
  }
}
