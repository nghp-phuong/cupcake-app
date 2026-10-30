import 'dart:math' as math;

import '../models/bake.dart';
import '../models/ids.dart';
import '../models/order.dart';
import '../monetization/booster.dart';
import '../scoring.dart';
import '../unlock/shop_setup.dart';
import 'level_data.dart';
import 'level_result.dart';
import 'level_session.dart';

/// Tham số kỹ năng của bot (đều theo một thang 0..1 qua [BotSkill.of]).
class BotSkill {
  const BotSkill({required this.accuracy, required this.reactionSec, required this.sellBias});

  /// Kỹ năng tổng 0..1 → độ chính xác = s, phản ứng 1.1 → 0.3 s, ưu tiên bán 0.3 → 0.8.
  factory BotSkill.of(double skill) {
    final s = skill.clamp(0.0, 1.0);
    return BotSkill(accuracy: s, reactionSec: 1.1 - 0.8 * s, sellBias: 0.3 + 0.5 * s);
  }

  /// Người mới chơi: chính xác vừa phải, phản ứng chậm (1.2 s), ít ưu tiên bán.
  static const newcomer = BotSkill(accuracy: 0.5, reactionSec: 1.2, sellBias: 0.5);

  /// 0..1: độ chính xác các trạm (khuôn, trộn, giờ lấy lò, kem, topping, hộp) và chọn món hợp lý.
  final double accuracy;

  /// Giây "nghĩ" cộng vào mỗi thao tác; chậm phản ứng với khách đặc biệt gấp 3.
  final double reactionSec;

  /// 0..1: xác suất ưu tiên bán khi vừa có khách bán được vừa có việc bếp.
  final double sellBias;
}

/// Bot chơi headless một [LevelSession] (cân bằng level, GĐ7 dùng lại). Một "bàn tay": mỗi thao tác tốn thời gian
/// màn chơi; đơn đặc biệt giả lập kết quả 6 trạm theo kỹ năng (ngoài đời ~35 s nhưng giờ màn dừng nên tức thì).
class LevelBot {
  LevelBot(this.skill, {math.Random? random}) : _random = random ?? math.Random();

  final BotSkill skill;
  final math.Random _random;

  // Thời gian thao tác cơ bản (giây, chưa cộng phần nghĩ).
  static const _sellSec = 0.45, _startSec = 0.4, _mouldSec = 0.6, _mixSec = 1.2, _takeOutSec = 0.3;
  static const _frostSec = 1.2, _toppingSec = 1.2, _boxSec = 0.5;

  double _busyUntil = 0;
  final Map<int, double> _plannedRelease = {}; // lò → vị trí kim định lấy ra
  int? _specialSeenId;
  double _specialSeenAt = 0;

  double get _think => skill.reactionSec * 0.5;

  /// Chơi tới hết giờ; [useExtraTime] → chưa đạt 1★ thì dùng +30 giây (như người chơi xem quảng cáo).
  /// Bot cân bằng chạy KHÔNG hướng dẫn (session tạo với `tutorialActive: false`): bước hướng dẫn dừng giờ mà bot đang
  /// chờ theo giờ màn thì không bao giờ xong.
  LevelResult play(LevelSession s, {bool useExtraTime = false}) {
    assert(s.tutorial == null, 'LevelBot.play: session có hướng dẫn — bot cân bằng phải chạy không hướng dẫn');
    reset();
    while (true) {
      while (!s.isOver) {
        s.drainEvents();
        step(s);
      }
      if (useExtraTime && s.canAddTime && s.starsNow == 0) {
        s.addTime(30);
        continue;
      }
      break;
    }
    s.drainEvents();
    return s.finish();
  }

  /// Quên trạng thái của lượt trước (gọi trước khi dùng [step] cho session mới).
  void reset() {
    _busyUntil = 0;
    _plannedRelease.clear();
    _specialSeenId = null;
  }

  /// Một bước logic: quyết định (nếu rảnh tay) rồi `advance(LevelSession.step)`. Không đọc sự kiện của session
  /// (bên gọi tự `drainEvents`) — dùng khi cần theo dõi từng khung (mô phỏng GĐ7, test).
  void step(LevelSession s) {
    _special(s);
    if (s.elapsed + 1e-9 >= _busyUntil) _act(s);
    s.advance(LevelSession.step);
  }

  // ------------------------------------------------------------------ Quyết định

  void _act(LevelSession s) {
    final k = s.kitchen;
    final t = s.elapsed;

    // 1. Lò tới vạch định lấy → lấy ra.
    for (var i = 0; i < k.ovens.length; i++) {
      final b = k.ovens[i];
      if (b == null || b.stage != BatchStage.baking) continue;
      final plan = _plannedRelease[i] ??= _planRelease(b);
      if (b.ovenProgress >= plan) {
        s.takeOut(i);
        _plannedRelease.remove(i);
        _spend(t, _takeOutSec);
        return;
      }
    }

    // 2. Bán hoặc làm bếp.
    final buyer = _bestBuyer(s);
    final urgent = buyer != null && buyer.patienceFrac < 0.35;
    final kitchenCost = _nextKitchenCost(s);
    final wantSell = buyer != null && (urgent || kitchenCost == null || _random.nextDouble() < skill.sellBias);
    final base = wantSell ? _sellSec : kitchenCost;
    if (base == null) {
      _busyUntil = t + 0.1; // rảnh
      return;
    }
    final cost = base * _handMult;

    // Người chơi giỏi không bắt đầu việc dài khi lò sắp tới vạch.
    final due = _secondsToOvenDue(s);
    if (due != null && due < cost + _think && _random.nextDouble() < skill.accuracy) {
      _busyUntil = t + math.max(LevelSession.step, due);
      return;
    }

    if (wantSell) {
      s.sell(buyer.id);
      _spend(t, _sellSec);
    } else {
      _kitchenStep(s);
    }
  }

  LevelCustomer? _bestBuyer(LevelSession s) {
    LevelCustomer? best;
    for (final c in s.customers) {
      if (!c.canBuy) continue;
      var ok = false;
      for (final w in c.wants) {
        if (s.displayCase.countOf(w) > 0) ok = true;
      }
      if (ok && (best == null || c.patience < best.patience)) best = c;
    }
    return best;
  }

  /// Thời gian của việc bếp kế tiếp (null nếu không có việc).
  double? _nextKitchenCost(LevelSession s) {
    final k = s.kitchen;
    final f = k.finish;
    if (f != null) {
      switch (f.stage) {
        case BatchStage.frost:
          return _frostSec;
        case BatchStage.topping:
          return _toppingSec;
        case BatchStage.box:
          return _boxSec;
        default:
          break;
      }
    }
    final p = k.prep;
    if (p != null) {
      return switch (p.stage) {
        BatchStage.mould => _mouldSec,
        BatchStage.mix => _mixSec,
        _ => null,
      };
    }
    return _chooseRecipe(s) != null ? _startSec : null;
  }

  void _kitchenStep(LevelSession s) {
    final t = s.elapsed;
    final k = s.kitchen;
    final f = k.finish;
    if (f != null) {
      switch (f.stage) {
        case BatchStage.frost:
          s.finishFrost(_frostCoverage());
          _spend(t, _frostSec);
          return;
        case BatchStage.topping:
          for (var i = 0; i < Batch.toppingTaps; i++) {
            s.addTopping(_hit(_toppingP) ? f.correctTopping : _other(f.toppingChoices, f.correctTopping));
          }
          _spend(t, _toppingSec);
          return;
        case BatchStage.box:
          s.pickBox(_hit(_boxP) ? f.correctBox : _other(f.boxChoices, f.correctBox));
          _spend(t, _boxSec);
          return;
        default:
          break;
      }
    }
    final p = k.prep;
    if (p != null) {
      if (p.stage == BatchStage.mould) {
        final ok = _hit(_mouldP);
        s.pickMould(ok ? p.correctMould : _other(p.mouldChoices, p.correctMould));
        _spend(t, _mouldSec);
      } else if (p.stage == BatchStage.mix) {
        s.finishMix(math.max(0.0, 1 + _gauss() * (1 - skill.accuracy) * 0.3));
        _spend(t, _mixSec);
      }
      return;
    }
    final r = _chooseRecipe(s);
    if (r != null && s.startBatch(r)) _spend(t, _startSec);
  }

  /// Món nên làm: thiếu nhiều nhất so với khách đang chờ; không thiếu → món ít hàng nhất nếu tủ còn chỗ.
  RecipeId? _chooseRecipe(LevelSession s) {
    final menu = s.level.menu;
    final batch = s.tuning.batchSize;
    if (_random.nextDouble() < (1 - skill.accuracy) * 0.3) {
      final r = menu[_random.nextInt(menu.length)];
      return s.displayCase.roomFor(r) >= batch * (1 + s.kitchen.batchesOf(r)) ? r : null;
    }
    RecipeId? best;
    var bestScore = -1 << 30;
    for (final r in menu) {
      if (s.displayCase.roomFor(r) < batch * (1 + s.kitchen.batchesOf(r))) continue;
      var demand = 0;
      for (final c in s.customers) {
        if (!c.isSpecial && !c.isLeaving && c.want == r) demand++;
      }
      final supply = s.displayCase.countOf(r) + s.kitchen.batchesOf(r) * batch;
      final score = (demand - supply) * 10 - supply;
      if (demand - supply <= 0 && supply >= batch) continue;
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    return best;
  }

  // ------------------------------------------------------------------ Khách đặc biệt

  void _special(LevelSession s) {
    final c = s.specialCustomer;
    if (c == null || c.isLeaving || c.phase != CustomerPhase.atCounter) return;
    if (_specialSeenId != c.id) {
      _specialSeenId = c.id;
      _specialSeenAt = s.elapsed;
    }
    if (s.elapsed - _specialSeenAt < skill.reactionSec * 3) return;
    final order = s.beginSpecial(c.id);
    if (order == null) return;
    final result = Scoring.evaluate(
      order: order,
      customer: c.look,
      outcome: _specialOutcome(order),
      modifiers: s.modifiers,
      decorTipBonusPct: s.decorTipBonusPct,
    );
    s.finishSpecial(c.id, result);
  }

  BakeOutcome _specialOutcome(Order order) {
    final recipe = order.recipeData;
    var wrong = 0;
    while (wrong < 3 && !_hit(_mouldP)) {
      wrong++;
    }
    final placed = <ToppingId, int>{};
    for (final req in order.toppings) {
      for (var i = 0; i < req.count; i++) {
        final t = _hit(_toppingP) ? req.topping : _wrongTopping(req.topping);
        placed[t] = (placed[t] ?? 0) + 1;
      }
    }
    return BakeOutcome(
      wrongMouldDrops: wrong,
      mixTurns: math.max(0.0, recipe.mixTurns * (1 + _gauss() * (1 - skill.accuracy) * 0.3)),
      bakeRelease: (recipe.bakeTarget + _gauss() * (1 - skill.accuracy) * 0.10).clamp(0.0, 1.0),
      frostCoverage: _frostCoverage(),
      toppingsPlaced: placed,
      boxChosen: _hit(_boxP) ? order.box : (order.box == BoxType.small ? BoxType.cake : BoxType.small),
    );
  }

  // ------------------------------------------------------------------ Kỹ năng

  double get _mouldP => 0.6 + 0.4 * skill.accuracy;
  double get _toppingP => 0.5 + 0.5 * skill.accuracy;
  double get _boxP => 0.7 + 0.3 * skill.accuracy;

  double _planRelease(Batch b) => (b.bakeTarget + _gauss() * (1 - skill.accuracy) * 0.10).clamp(0.05, 1.0);

  double _frostCoverage() => (0.55 + 0.45 * skill.accuracy + _gauss() * 0.08).clamp(0.0, 1.0);

  /// Giây tới khi một lò đang nướng chạm vạch định lấy (null nếu không có lò nướng).
  double? _secondsToOvenDue(LevelSession s) {
    double? best;
    final ovens = s.kitchen.ovens;
    for (var i = 0; i < ovens.length; i++) {
      final b = ovens[i];
      if (b == null || b.stage != BatchStage.baking) continue;
      final plan = _plannedRelease[i] ??= _planRelease(b);
      final sec = s.ovenSecondsUntil(b, plan);
      if (best == null || sec < best) best = sec;
    }
    return best;
  }

  /// Thao tác tay chậm hơn khi kỹ năng thấp: ×1.0 (s = 1) → ×2.0 (s = 0).
  double get _handMult => 2 - skill.accuracy;

  void _spend(double now, double base) => _busyUntil = now + base * _handMult + _think;

  bool _hit(double p) => _random.nextDouble() < p;

  T _other<T>(List<T> choices, T correct) {
    for (final c in choices) {
      if (c != correct) return c;
    }
    return correct;
  }

  ToppingId _wrongTopping(ToppingId correct) =>
      correct == ToppingId.sprinkles ? ToppingId.cherry : ToppingId.sprinkles;

  double _gauss() {
    final u1 = math.max(1e-12, _random.nextDouble());
    final u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

/// Thống kê nhiều lượt bot trên một level (bảng cân bằng).
class LevelBotStats {
  LevelBotStats(this.level);

  final LevelData level;
  int runs = 0, wins = 0, starSum = 0, coinSum = 0, lostSum = 0, servedSum = 0, specialSum = 0;

  void add(LevelResult r) {
    runs++;
    if (r.won) wins++;
    starSum += r.stars;
    coinSum += r.coins;
    lostSum += r.lost;
    servedSum += r.served;
    specialSum += r.specialsDone;
  }

  double get winRate => runs == 0 ? 0 : wins / runs;
  double get avgStars => runs == 0 ? 0 : starSum / runs;
  double get avgCoins => runs == 0 ? 0 : coinSum / runs;
  double get avgLost => runs == 0 ? 0 : lostSum / runs;
  double get avgServed => runs == 0 ? 0 : servedSum / runs;
  double get avgSpecials => runs == 0 ? 0 : specialSum / runs;

  /// Chạy [seeds] lượt (seed 1..N cho session và bot) với kỹ năng [skill] (hoặc bộ tham số [botSkill] nếu có), với
  /// tiệm [setup] + lò/dụng cụ [modifiers] + % tip trang trí [decorTipBonusPct]. Mặc định không dùng vật phẩm hỗ trợ
  /// ([boosters] rỗng — bảng cân bằng chính); truyền [boosters] để xem mức dễ hơn.
  static LevelBotStats simulate(
    LevelData level,
    LevelDefaults defaults, {
    required double skill,
    int seeds = 50,
    BakeModifiers modifiers = BakeModifiers.base,
    ShopSetup setup = ShopSetup.base,
    int decorTipBonusPct = 0,
    BotSkill? botSkill,
    Set<BoosterId> boosters = const {},
  }) {
    final stats = LevelBotStats(level);
    for (var seed = 1; seed <= seeds; seed++) {
      final session = LevelSession(
        level: level,
        defaults: defaults,
        modifiers: modifiers,
        decorTipBonusPct: decorTipBonusPct,
        setup: setup,
        boosters: boosters,
        random: math.Random(seed),
      );
      stats.add(LevelBot(botSkill ?? BotSkill.of(skill), random: math.Random(seed * 7919)).play(session));
      session.dispose();
    }
    return stats;
  }
}
