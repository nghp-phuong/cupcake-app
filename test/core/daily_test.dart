import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level_result.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';

/// Đồng hồ chỉnh được để giả lập đổi ngày.
class _Clock {
  DateTime now = DateTime(2026, 10, 27, 9);
  DateTime call() => now;
  void nextDay([int days = 1]) => now = DateTime(now.year, now.month, now.day + days, 9);
}

BakeResult _result({int stars = 5, int tip = 10, bool perfectBake = true}) => BakeResult(
      stations: {
        for (final s in StationId.values)
          s: StationScore(s, s == StationId.bake && !perfectBake ? 0.8 : 1.0, StationIssue.none),
      },
      quality: 1,
      stars: stars,
      payment: 40,
      tip: tip,
      cost: 10,
      xp: 20,
      praise: FeedbackKey.allGood,
      complaint: null,
      weakest: StationId.bake,
    );

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.sprinkles, 1)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);
const _customer = Customer(kind: CustomerKind.regular, appearanceSeed: 0);

void main() {
  test('nhiệm vụ: 3 loại khác nhau, cố định theo ngày', () {
    final a = GameState.questTypesFor('2026-10-27');
    expect(a.length, 3);
    expect(a.toSet().length, 3);
    expect(GameState.questTypesFor('2026-10-27'), a);
  });

  test('đổi ngày → nhiệm vụ mới + rewardedToday = 0', () {
    final clock = _Clock();
    final s = GameState.newGame(clock: clock.call);
    s.applyOrderResult(_order, _customer, _result());
    s.registerRewardedShown();
    s.registerRewardedShown();
    expect(s.rewardedToday, 2);
    expect(s.quests.any((q) => q.progress > 0), isTrue);

    clock.nextDay();
    expect(s.rewardedToday, 0); // getter đã theo ngày mới
    s.refreshDaily();
    expect(s.quests.every((q) => q.progress == 0 && !q.claimed), isTrue);
    expect(s.quests.map((q) => q.type).toList(), GameState.questTypesFor(GameState.dateKey(clock.now)));
    expect(s.toJson()['questDate'], '2026-10-28');
    expect(s.toJson()['rewardedToday'], 0);
  });

  test('tiến trình + nhận thưởng nhiệm vụ', () {
    final s = GameState.newGame(clock: () => DateTime(2026, 10, 27));
    for (var i = 0; i < 10; i++) {
      s.applyOrderResult(_order, _customer, _result(stars: 5, tip: 10));
    }
    for (var i = 0; i < s.quests.length; i++) {
      final q = s.quests[i];
      final def = Catalog.quest(q.type);
      expect(q.progress, lessThanOrEqualTo(def.target));
      final coins = s.coins;
      final gems = s.gems;
      if (q.progress >= def.target) {
        final claimed = s.claimQuest(i);
        expect(claimed?.claimed, isTrue);
        expect(s.coins, coins + def.rewardCoins);
        expect(s.gems, gems + def.rewardGems);
        expect(s.claimQuest(i), isNull); // không nhận 2 lần
      } else {
        expect(s.claimQuest(i), isNull);
      }
    }
    expect(s.claimQuest(5), isNull);
  });

  group('quà đăng nhập 7 ngày', () {
    test('nối chuỗi, quay vòng sau ngày 7', () {
      final clock = _Clock();
      final s = GameState.newGame(clock: clock.call);
      expect(s.loginStreakDay, 0);
      for (var day = 1; day <= 7; day++) {
        expect(s.pendingLoginReward?.day, day);
        final coins = s.coins;
        final gems = s.gems;
        final r = s.claimLogin()!;
        expect(r, Catalog.loginReward(day));
        expect(s.coins, coins + r.coins);
        expect(s.gems, gems + r.gems);
        expect(s.pendingLoginReward, isNull);
        expect(s.claimLogin(), isNull); // 1 lần/ngày
        expect(s.loginStreakDay, day);
        clock.nextDay();
      }
      expect(Catalog.loginReward(7).coins, 300);
      expect(Catalog.loginReward(7).gems, 10);
      expect(s.pendingLoginReward?.day, 1);
      expect(s.loginStreakDay, 0);
    });

    test('bỏ lỡ 1 ngày → về ngày 1', () {
      final clock = _Clock();
      final s = GameState.newGame(clock: clock.call);
      s.claimLogin();
      clock.nextDay();
      s.claimLogin();
      expect(s.loginStreakDay, 2);
      clock.nextDay(2);
      expect(s.loginStreakDay, 0);
      expect(s.pendingLoginReward?.day, 1);
    });
  });

  test('rewarded tối đa 12/ngày lịch', () {
    final clock = _Clock();
    final s = GameState.newGame(clock: clock.call);
    final ads = FakeAdService(s);
    for (var i = 0; i < Economy.maxRewardedPerDay; i++) {
      expect(ads.canShowRewarded(), isTrue);
      s.registerRewardedShown();
    }
    expect(ads.canShowRewarded(), isFalse);
    clock.nextDay();
    expect(ads.canShowRewarded(), isTrue);
  });

  test('luật interstitial (GĐ6: theo lượt chơi, chi tiết ở monetization_test)', () {
    final s = GameState.newGame(clock: _Clock().call);
    final ads = FakeAdService(s);
    bool show() => ads.shouldShowInterstitial(watchedRewardedHere: false, unlockedChapter: false);
    expect(show(), isFalse);
    for (var id = 1; id <= 5; id++) {
      s.applyLevelResult(LevelResult(
        levelId: id,
        won: true,
        stars: 1,
        coins: 0,
        served: 0,
        lost: 0,
        specialsDone: 0,
        bestCombo: 0,
        perfectBakes: 0,
        recipeStars: const {},
      ));
      s.registerLevelPlayEnded();
    }
    expect(s.playsSinceInterstitial, 1); // chỉ đếm từ lượt qua L5
    s.registerLevelPlayEnded();
    expect(show(), isFalse);
    s.registerLevelPlayEnded();
    expect(show(), isTrue);
    s.registerInterstitialShown();
    expect(show(), isFalse);
    for (var i = 0; i < 3; i++) {
      s.registerLevelPlayEnded();
    }
    expect(show(), isTrue);
    s.grantIap(IapProductId.removeAds);
    expect(show(), isFalse);
  });

  test('IAP giả lập trao đúng, gói 1 lần không mua lại', () async {
    final s = GameState.newGame(clock: _Clock().call);
    final iap = FakeIapService(s, delay: Duration.zero);
    expect(iap.products.length, 7); // cửa hàng V2 (gói V1 ẩn nhưng vẫn mua/trao được)
    final coins = s.coins;
    expect(await iap.buy(IapProductId.pantryS), isTrue);
    expect(s.coins, coins + 500);
    expect(await iap.buy(IapProductId.pantryS), isTrue); // tiêu hao, mua lại được
    expect(await iap.buy(IapProductId.starterPack), isTrue);
    expect(iap.isOwned(IapProductId.starterPack), isTrue);
    expect(await iap.buy(IapProductId.starterPack), isFalse);
    expect(await iap.buy(IapProductId.decorSetSeaside), isTrue);
    expect(s.ownedDecor, containsAll(Catalog.decorSetSeaside));
  });
}
