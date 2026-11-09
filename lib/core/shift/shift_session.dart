/// Một ca bán trong tiệm của bà (docs/v3/city-gd3-spec.md §3): sinh khách + đơn khi mở ca, đi qua từng pha của mỗi
/// khách, chấm điểm (xu nhân [ShiftEconomy.coinMult]), cộng ví / thống kê khi bấm "Khách tiếp", tổng kết khi hết khách.
///
/// Pha của một khách: `arriving → customerArrived → ordering → startBaking → baking → completeBake → result`, rồi
/// [ShiftSession.next] sang khách sau (hoặc `finished`); [ShiftSession.remake] đưa đơn ≤2★ về `baking` một lần. Gọi
/// hàm sai pha thì không làm gì. Không lưu ca dở: đơn đã tính nằm trong ví, phần còn lại mất khi thoát app.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../city/city_game.dart';
import '../city/recipe_unlocks.dart';
import '../economy.dart';
import '../models/bake.dart';
import '../models/customer.dart';
import '../models/ids.dart';
import '../models/order.dart';
import '../order_generator.dart';
import '../scoring.dart';
import 'shift_economy.dart';

enum ShiftPhase { arriving, ordering, baking, result, finished, aborted }

/// Khách thứ [index] (0-based) của ca và đơn của họ.
class ShiftOrder {
  const ShiftOrder({
    required this.index,
    required this.customer,
    required this.order,
  });

  final int index;
  final Customer customer;
  final Order order;
}

/// Kết quả một đơn đã chấm.
class ShiftServed {
  const ShiftServed({
    required this.order,
    required this.outcome,
    required this.result,
    required this.buffTip,
  });

  final ShiftOrder order;
  final BakeOutcome outcome;

  /// `payment`, `tip`, `cost` đã nhân [ShiftEconomy.coinMult] (thẻ kết quả hiện đúng số này).
  final BakeResult result;

  /// Phần tip nhờ buff "No bụng" (đã nhân xu); 0 nếu ca không có buff.
  final int buffTip;
}

/// Tổng kết ca (hết khách hoặc đóng sớm).
class ShiftSummary {
  const ShiftSummary({
    required this.completed,
    required this.served,
    required this.total,
    required this.revenue,
    required this.tips,
    required this.costs,
    required this.net,
    required this.buffTips,
    required this.doubledCoins,
    required this.xp,
    required this.bonusXp,
    required this.levelBefore,
    required this.levelAfter,
    required this.averageStars,
    required this.newRecipes,
    required this.newToppings,
    required this.moreCustomers,
    required this.vipGuests,
    required this.records,
  });

  /// true = phục vụ hết khách; false = đóng sớm.
  final bool completed;

  /// Số đơn đã tính / số khách của ca.
  final int served, total;

  /// Tổng tiền khách trả, tip, chi phí (đã nhân xu); [net] = revenue + tips − costs.
  final int revenue, tips, costs, net;

  /// Tổng tip nhờ buff (nằm trong [tips]).
  final int buffTips;

  /// Xu cộng thêm nhờ x2 quảng cáo (0 = chưa / không x2).
  final int doubledCoins;

  /// XP cả ca (gồm [bonusXp]); thưởng hết ca (0 khi đóng sớm).
  final int xp, bonusXp;

  /// Cấp Mai lúc mở ca / lúc đóng ca.
  final int levelBefore, levelAfter;

  /// Sao trung bình các đơn đã tính (0 nếu chưa có đơn).
  final double averageStars;

  /// Mở mới trong ca: món, topping, thêm khách (cấp 4, 10), khách VIP (cấp 7).
  final List<RecipeId> newRecipes;
  final List<ToppingId> newToppings;
  final bool moreCustomers, vipGuests;

  final List<ShiftServed> records;

  bool get leveledUp => levelAfter > levelBefore;

  /// Xu cả ca, gồm x2.
  int get totalCoins => net + doubledCoins;

  ShiftSummary _doubled(int coins) => ShiftSummary(
    completed: completed,
    served: served,
    total: total,
    revenue: revenue,
    tips: tips,
    costs: costs,
    net: net,
    buffTips: buffTips,
    doubledCoins: coins,
    xp: xp,
    bonusXp: bonusXp,
    levelBefore: levelBefore,
    levelAfter: levelAfter,
    averageStars: averageStars,
    newRecipes: newRecipes,
    newToppings: newToppings,
    moreCustomers: moreCustomers,
    vipGuests: vipGuests,
    records: records,
  );
}

class ShiftSession extends ChangeNotifier {
  /// Mở ca: sinh khách + đơn theo cấp Mai (món / topping theo [RecipeUnlocks], không khách quen), ghi lại buff "No
  /// bụng" lúc mở. `recipeSeen` chưa có mốc (0) → đặt bằng cấp hiện tại (không báo bù).
  ShiftSession({required CityGame game, math.Random? random})
    : _game = game,
      levelAtStart = game.wallet.level,
      buffActive = game.wallet.fullBuff {
    final plan = OrderGenerator(random ?? math.Random()).generateDay(
      level: levelAtStart,
      unlockedRecipes: RecipeUnlocks.recipesAt(levelAtStart),
      unlockedToppings: RecipeUnlocks.toppingsAt(levelAtStart),
      seenScenes: const {},
    );
    orders = List.unmodifiable([
      for (var i = 0; i < plan.orders.length; i++)
        ShiftOrder(
          index: i,
          customer: plan.customers[i],
          order: plan.orders[i],
        ),
    ]);
    if (game.recipeSeen == 0) game.markRecipeSeen(levelAtStart);
    _recipeNews = RecipeUnlocks.newRecipes(game.recipeSeen, levelAtStart);
  }

  final CityGame _game;

  /// Cấp Mai lúc mở ca.
  final int levelAtStart;

  /// Ví có buff "No bụng" lúc mở ca → mọi đơn của ca được +[ShiftEconomy.buffTipPct]% tip.
  final bool buffActive;

  late final List<ShiftOrder> orders;

  ShiftPhase _phase = ShiftPhase.arriving;
  int _index = 0;
  ShiftServed? _served;
  final List<ShiftServed> _records = [];
  final Set<int> _remade = {};
  ShiftSummary? _summary;
  late List<RecipeId> _recipeNews;

  ShiftPhase get phase => _phase;

  /// Khách đang phục vụ (0-based); = [total] sau khi hết khách.
  int get index => _index;
  int get total => orders.length;

  /// Khách đang phục vụ (hết khách → khách cuối).
  ShiftOrder get current => orders[math.min(_index, total - 1)];

  /// Kết quả đơn đang ở pha `result`; null ở pha khác.
  ShiftServed? get served => _served;

  /// Các đơn đã tính, theo thứ tự.
  List<ShiftServed> get records => List.unmodifiable(_records);

  /// Bản thành phố chưa có nâng cấp dụng cụ.
  BakeModifiers get modifiers => BakeModifiers.base;

  /// Trạm chưa xem hướng dẫn (đọc lúc dựng `BakeSessionView`).
  Set<StationId> get tutorialFor {
    final seen = _game.tutorialSeen;
    return {
      for (final s in StationId.values)
        if (!seen.contains(s)) s,
    };
  }

  /// Ghi đã xem hướng dẫn trạm [s] (vào save; không notify phiên).
  void tutorialShown(StationId s) => _game.markTutorialSeen(s);

  /// Lần đầu làm món của khách hiện tại (đọc lúc dựng `BakeSessionView`).
  bool get recipeTutorial => !_game.recipeTutorialSeen(current.order.recipe);

  /// Ghi đã xem hướng dẫn món của khách hiện tại (vào save; không notify phiên).
  void recipeTutorialShown() => _game.markRecipeTutorialSeen(current.order.recipe);

  /// Món mở từ lần báo "Mở mới!" trước tới cấp lúc mở ca (thẻ "Mở mới!" trước khách đầu); rỗng = không có.
  List<RecipeId> get recipeNews => _recipeNews;

  /// Đã hiện thẻ "Mở mới!": ghi mốc = cấp lúc mở ca.
  void acknowledgeRecipeNews() {
    _game.markRecipeSeen(levelAtStart);
    if (_recipeNews.isEmpty) return;
    _recipeNews = const [];
    notifyListeners();
  }

  /// Khách đã tới quầy: `arriving → ordering`.
  void customerArrived() => _move(ShiftPhase.arriving, ShiftPhase.ordering);

  /// Bấm "Làm bánh": `ordering → baking`.
  void startBaking() => _move(ShiftPhase.ordering, ShiftPhase.baking);

  void _move(ShiftPhase from, ShiftPhase to) {
    if (_phase != from) return;
    _phase = to;
    notifyListeners();
  }

  /// Chấm bánh vừa làm: `baking → result`. Sai pha → null.
  ShiftServed? completeBake(BakeOutcome o) {
    if (_phase != ShiftPhase.baking) return null;
    final cur = current;
    BakeResult score(int tipPct) => Scoring.evaluate(
      order: cur.order,
      customer: cur.customer,
      outcome: o,
      modifiers: modifiers,
      decorTipBonusPct: tipPct,
    );
    final raw = score(buffActive ? ShiftEconomy.buffTipPct : 0);
    final plainTip = buffActive ? score(0).tip : raw.tip;
    const m = ShiftEconomy.coinMult;
    final served = ShiftServed(
      order: cur,
      outcome: o,
      result: BakeResult(
        stations: raw.stations,
        quality: raw.quality,
        stars: raw.stars,
        payment: raw.payment * m,
        tip: raw.tip * m,
        cost: raw.cost * m,
        xp: raw.xp,
        praise: raw.praise,
        complaint: raw.complaint,
        weakest: raw.weakest,
      ),
      buffTip: (raw.tip - plainTip) * m,
    );
    _served = served;
    _phase = ShiftPhase.result;
    notifyListeners();
    return served;
  }

  /// Đơn đang ở `result`, ≤2★, chưa làm lại. Không kiểm lượt quảng cáo (quảng cáo xem xong mới gọi [remake]).
  bool get _remakeAllowed =>
      _phase == ShiftPhase.result &&
      _served!.result.stars <= 2 &&
      !_remade.contains(_index);

  /// Hiện nút "Làm lại": đơn ≤2★, mỗi đơn một lần, còn lượt quảng cáo thưởng hôm nay.
  bool get canRemake => _remakeAllowed && _game.canShowRewarded;

  /// Làm lại đơn hiện tại (sau khi xem quảng cáo): `result → baking`, đơn chưa được tính.
  void remake() {
    if (!_remakeAllowed) return;
    _remade.add(_index);
    _served = null;
    _phase = ShiftPhase.baking;
    notifyListeners();
  }

  /// "Khách tiếp": tính đơn vào ví + thống kê, sang khách sau hoặc hết ca (thưởng [ShiftEconomy.completeBonusXp]).
  /// Trả cấp mới nếu lên cấp (kể cả nhờ thưởng hết ca); sai pha → null.
  int? next() {
    if (_phase != ShiftPhase.result) return null;
    final before = _game.wallet.level;
    _commit();
    _index++;
    if (_index >= total) {
      _close(completed: true);
    } else {
      _phase = ShiftPhase.arriving;
    }
    notifyListeners();
    final after = _game.wallet.level;
    return after > before ? after : null;
  }

  void _commit() {
    final s = _served!;
    if (buffActive && _records.isEmpty) _game.wallet.consumeFullBuff();
    _game.wallet.earn(coins: s.result.net, xp: s.result.xp);
    _game.recordOrder(stars: s.result.stars, coins: s.result.net);
    _records.add(s);
    _served = null;
  }

  void _close({required bool completed}) {
    final bonusXp = completed ? ShiftEconomy.completeBonusXp : 0;
    if (bonusXp > 0) _game.wallet.earn(xp: bonusXp);
    var revenue = 0, tips = 0, costs = 0, buffTips = 0, xp = 0, stars = 0;
    for (final s in _records) {
      revenue += s.result.payment;
      tips += s.result.tip;
      costs += s.result.cost;
      buffTips += s.buffTip;
      xp += s.result.xp;
      stars += s.result.stars;
    }
    final net = revenue + tips - costs;
    final levelAfter = _game.wallet.level;
    _summary = ShiftSummary(
      completed: completed,
      served: _records.length,
      total: total,
      revenue: revenue,
      tips: tips,
      costs: costs,
      net: net,
      buffTips: buffTips,
      doubledCoins: 0,
      xp: xp + bonusXp,
      bonusXp: bonusXp,
      levelBefore: levelAtStart,
      levelAfter: levelAfter,
      averageStars: _records.isEmpty ? 0 : stars / _records.length,
      newRecipes: RecipeUnlocks.newRecipes(levelAtStart, levelAfter),
      newToppings: RecipeUnlocks.newToppings(levelAtStart, levelAfter),
      moreCustomers:
          ShiftEconomy.customersFor(levelAfter) >
          ShiftEconomy.customersFor(levelAtStart),
      vipGuests:
          Economy.vipChance(levelAtStart) == 0 &&
          Economy.vipChance(levelAfter) > 0,
      records: List.unmodifiable(_records),
    );
    _game.recordShift(coins: net, completed: completed);
    // Tổng kết hết ca đã hiện "Mở mới" tới [levelAfter]; đóng sớm thì ca sau báo bù.
    if (completed) _game.markRecipeSeen(levelAfter);
    _phase = completed ? ShiftPhase.finished : ShiftPhase.aborted;
  }

  /// Tổng kết: có sau `finished` hoặc `aborted` (đóng sớm: `completed == false`, chỉ dùng cho toast).
  ShiftSummary? get summary => _summary;

  /// x2 xu cuối ca: hết khách, chưa x2, `net > 0`. Không kiểm lượt quảng cáo.
  bool get _doubleAllowed =>
      _phase == ShiftPhase.finished &&
      _summary!.doubledCoins == 0 &&
      _summary!.net > 0;

  /// Hiện nút x2: như trên và còn lượt quảng cáo thưởng hôm nay.
  bool get canDouble => _doubleAllowed && _game.canShowRewarded;

  /// Sau khi xem quảng cáo: cộng thêm `net` một lần.
  void applyDouble() {
    if (!_doubleAllowed) return;
    final net = _summary!.net;
    _game.wallet.earn(coins: net);
    _game.addBakeryCoins(net);
    _summary = _summary!._doubled(net);
    notifyListeners();
  }

  /// Đóng ca sớm: đơn đang ở `result` vẫn được tính, đơn đang làm bỏ; không thưởng, không x2 → `aborted`.
  void abort() {
    if (_phase == ShiftPhase.finished || _phase == ShiftPhase.aborted) return;
    if (_phase == ShiftPhase.result) _commit();
    _close(completed: false);
    notifyListeners();
  }
}
