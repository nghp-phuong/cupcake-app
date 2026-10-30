import 'dart:math' as math;

import 'economy.dart';
import 'models/bake.dart';
import 'models/customer.dart';
import 'models/ids.dart';
import 'models/order.dart';

/// Toàn bộ chấm điểm (thuần). Game chỉ đo số thô (`BakeOutcome`), core chấm.
abstract final class Scoring {
  static const weights = {
    StationId.bake: 30,
    StationId.frost: 25,
    StationId.topping: 25,
    StationId.mix: 10,
    StationId.box: 10,
    StationId.mould: 0,
  };

  /// Ngưỡng coi trạm là đạt (issue = none, không bị chê).
  static const goodThreshold = 0.9;

  /// Thứ tự ưu tiên khi hoà điểm (cả weakest lẫn best).
  static const tieOrder = [
    StationId.bake,
    StationId.frost,
    StationId.topping,
    StationId.mix,
    StationId.box,
    StationId.mould,
  ];

  // Sai số dấu phẩy động khi so sánh ngưỡng (vd 0.70 − 0.65 = 0.05000000000000004).
  static const _eps = 1e-9;

  static double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0).toDouble();

  static StationScore mould(int wrongDrops) {
    final wrong = math.max(0, wrongDrops);
    final score = _clamp01(math.max(0.3, 1 - 0.35 * wrong));
    return StationScore(StationId.mould, score, wrong > 0 ? StationIssue.wrongMould : StationIssue.none);
  }

  static StationScore mix(double turns, int target, double perfectBand) {
    final t = target <= 0 ? 1 : target;
    final d = (turns / t - 1).abs();
    final score = d <= perfectBand + _eps ? 1.0 : _clamp01(1 - (d - perfectBand) * 2);
    final issue = score >= goodThreshold
        ? StationIssue.none
        : (turns < t ? StationIssue.underMixed : StationIssue.overMixed);
    return StationScore(StationId.mix, score, issue);
  }

  static StationScore bake(double release, double target, double perfectHalf, double okHalf) {
    final d = (release - target).abs();
    final double score;
    if (d <= perfectHalf + _eps) {
      score = 1.0;
    } else if (d <= okHalf + _eps) {
      final span = okHalf - perfectHalf;
      score = span <= 0 ? 0.6 : _clamp01(1 - 0.4 * (d - perfectHalf) / span);
    } else {
      score = _clamp01(0.6 - (d - okHalf) * 3);
    }
    final issue = score >= goodThreshold
        ? StationIssue.none
        : (release < target ? StationIssue.underBaked : StationIssue.burnt);
    return StationScore(StationId.bake, score, issue);
  }

  static StationScore frost(double coverage) {
    final score = coverage >= goodThreshold - _eps ? 1.0 : _clamp01((coverage - 0.3) / 0.6);
    return StationScore(StationId.frost, score, score >= goodThreshold ? StationIssue.none : StationIssue.patchy);
  }

  static StationScore topping(Map<ToppingId, int> placed, List<ToppingRequest> required) {
    final req = <ToppingId, int>{};
    for (final r in required) {
      req[r.topping] = (req[r.topping] ?? 0) + r.count;
    }
    final total = req.values.fold<int>(0, (a, b) => a + b);
    var correct = 0;
    var wrong = 0;
    req.forEach((t, count) {
      final p = placed[t] ?? 0;
      correct += math.min(p, count);
      wrong += math.max(0, p - count);
    });
    placed.forEach((t, p) {
      if (!req.containsKey(t)) wrong += math.max(0, p);
    });
    final base = total == 0 ? 1.0 : correct / total;
    final score = _clamp01(base - 0.15 * wrong);
    final issue = score >= goodThreshold
        ? StationIssue.none
        : (wrong > 0 ? StationIssue.wrongTopping : StationIssue.missingTopping);
    return StationScore(StationId.topping, score, issue);
  }

  static StationScore box(BoxType chosen, BoxType required) {
    final ok = chosen == required;
    return StationScore(StationId.box, ok ? 1.0 : 0.3, ok ? StationIssue.none : StationIssue.wrongBox);
  }

  static int starsFor(double quality) {
    if (quality >= 0.90 - _eps) return 5;
    if (quality >= 0.75 - _eps) return 4;
    if (quality >= 0.60 - _eps) return 3;
    if (quality >= 0.40 - _eps) return 2;
    return 1;
  }

  /// [decorTipBonusPct]: tổng % tip cộng thêm (trang trí + mở rộng tiệm), trần `Economy.tipBonusCapPct`.
  static BakeResult evaluate({
    required Order order,
    required Customer customer,
    required BakeOutcome outcome,
    required BakeModifiers modifiers,
    required int decorTipBonusPct,
  }) {
    final recipe = order.recipeData;
    final list = [
      mould(outcome.wrongMouldDrops),
      mix(outcome.mixTurns, recipe.mixTurns, modifiers.mixPerfectBand),
      bake(outcome.bakeRelease, recipe.bakeTarget, modifiers.bakePerfectHalfWidth, modifiers.bakeOkHalfWidth),
      frost(outcome.frostCoverage),
      topping(outcome.toppingsPlaced, order.toppings),
      box(outcome.boxChosen, order.box),
    ];
    final stations = {for (final s in list) s.station: s};

    var weighted = 0.0;
    for (final s in list) {
      weighted += (weights[s.station] ?? 0) * s.score;
    }
    final quality = _clamp01(weighted / 100 - 0.05 * math.min(math.max(0, outcome.wrongMouldDrops), 2));
    final stars = starsFor(quality);

    final payment = (recipe.price * Economy.payMult[stars]!).round();
    final tip = stars < 3
        ? 0
        : (recipe.price *
                Economy.tipRate[stars]! *
                Economy.tipKindMult[customer.kind]! *
                (1 + math.min(math.max(0, decorTipBonusPct), Economy.tipBonusCapPct) / 100))
            .round();
    final xp = ((15 + 5 * stars) * (customer.kind == CustomerKind.vip ? 1.5 : 1)).round();

    var weakest = tieOrder.first;
    var best = tieOrder.first;
    for (final id in tieOrder) {
      if (stations[id]!.score < stations[weakest]!.score) weakest = id;
      if (stations[id]!.score > stations[best]!.score) best = id;
    }
    final weakScore = stations[weakest]!;
    final complaint = weakScore.score < goodThreshold ? complaintFor(weakScore.issue) : null;
    final praise = complaint == null && stars == 5 ? FeedbackKey.allGood : praiseFor(best);

    return BakeResult(
      stations: stations,
      quality: quality,
      stars: stars,
      payment: payment,
      tip: tip,
      cost: recipe.cost,
      xp: xp,
      praise: praise,
      complaint: complaint,
      weakest: weakest,
    );
  }

  static FeedbackKey praiseFor(StationId s) => switch (s) {
        StationId.mould => FeedbackKey.mouldGood,
        StationId.mix => FeedbackKey.mixGood,
        StationId.bake => FeedbackKey.bakeGood,
        StationId.frost => FeedbackKey.frostGood,
        StationId.topping => FeedbackKey.toppingGood,
        StationId.box => FeedbackKey.boxGood,
      };

  /// Khoá chê theo issue; `none` → null.
  static FeedbackKey? complaintFor(StationIssue issue) => switch (issue) {
        StationIssue.none => null,
        StationIssue.wrongMould => FeedbackKey.mouldWrong,
        StationIssue.underMixed => FeedbackKey.mixUnder,
        StationIssue.overMixed => FeedbackKey.mixOver,
        StationIssue.underBaked => FeedbackKey.bakeUnder,
        StationIssue.burnt => FeedbackKey.bakeBurnt,
        StationIssue.patchy => FeedbackKey.frostPatchy,
        StationIssue.missingTopping => FeedbackKey.toppingMissing,
        StationIssue.wrongTopping => FeedbackKey.toppingWrong,
        StationIssue.wrongBox => FeedbackKey.boxWrong,
      };
}
