import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';

/// GĐ6 phần GameState: kho vật phẩm + thanh toán, interstitial theo lượt, IAP giả lập, thẻ mùa, lưu / đọc.
final _levels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync(), strict: true);
final _real = MonetizationConfigLoader.parse(File(MonetizationConfigLoader.assetPath).readAsStringSync(), strict: true);

class _Clock {
  DateTime now = DateTime(2026, 11, 1, 10);
  DateTime call() => now;
}

SeasonData _season(String id, DateTime start, DateTime end) => SeasonData(
      id: id,
      start: start,
      end: end,
      tiers: [
        const SeasonTier(points: 10, free: Reward(coins: 100), premium: Reward(gems: 10)),
        const SeasonTier(points: 30, free: Reward(boosters: {BoosterId.patience: 1}), premium: Reward(frame: 'frame_a')),
        const SeasonTier(points: 60, free: Reward(gems: 3), premium: Reward(coins: 500)),
      ],
    );

final _s1 = _season('s1', DateTime(2026, 10, 1), DateTime(2026, 12, 1));
final _s2 = _season('s2', DateTime(2026, 12, 1), DateTime(2027, 2, 1));

MonetizationConfig _cfg({SeasonData? season, List<SeasonData> previous = const []}) => MonetizationConfig(
      boosters: BoosterData.fallback,
      season: season,
      previousSeasons: previous,
      products: IapCatalog.v2,
    );

GameState _state(_Clock clock, {MonetizationConfig? cfg}) => GameState.newGame(clock: clock.call)
  ..attachLevelConfig(_levels)
  ..attachMonetizationConfig(cfg ?? _cfg(season: _s1));

LevelResult _result(int id, {bool won = true, int stars = 1, int coins = 0}) => LevelResult(
      levelId: id,
      won: won,
      stars: stars,
      coins: coins,
      served: 0,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
    );

/// Qua L1..[last] mỗi level 1★.
void _passTo(GameState s, int last) {
  for (var id = 1; id <= last; id++) {
    s.applyLevelResult(_result(id));
  }
}

void main() {
  group('vật phẩm: kho, quà L4, thanh toán', () {
    test('quà giới thiệu: patience ×1 vào kho đúng một lần khi qua L3 (tới L4)', () {
      final s = _state(_Clock());
      expect(GameState.boostersAvailableFor(3), isFalse);
      expect(GameState.boostersAvailableFor(4), isTrue);
      _passTo(s, 2);
      expect(s.boosterCount(BoosterId.patience), 0);
      final d = s.applyLevelResult(_result(3));
      expect(d.boosterGift, isTrue);
      expect(s.boosterGiftReceived, isTrue);
      expect(s.boosterInventory, {BoosterId.fullCase: 0, BoosterId.patience: 1, BoosterId.ovenBoost: 0});
      expect(s.applyLevelResult(_result(3, stars: 2)).boosterGift, isFalse);
      s.refreshDaily();
      expect(s.boosterCount(BoosterId.patience), 1);
      expect(s.boosterIntroSeen, isFalse);
      s.markBoosterIntroSeen();
      expect(s.boosterIntroSeen, isTrue);
    });

    test('bản lưu cũ đã qua L3 (không có trường quà) → nhận quà khi load', () {
      final old = _state(_Clock());
      _passTo(old, 6);
      final json = old.toJson()
        ..remove('boosters')
        ..remove('boosterIntro');
      final back = GameState.fromJson(json, clock: _Clock().call)..refreshDaily();
      expect(back.boosterCount(BoosterId.patience), 1);
      back.refreshDaily();
      expect(back.boosterCount(BoosterId.patience), 1);
    });

    test('một vật phẩm: kho trước, hết kho → kim cương, không đủ → null', () {
      final s = _state(_Clock());
      s.addGems(-s.gems + 7);
      expect(s.boosterPaymentFor(BoosterId.patience), BoosterPayment.gems); // 6 ≤ 7
      expect(s.boosterPaymentFor(BoosterId.fullCase), isNull); // 8 > 7
      s.addBoosters(BoosterId.fullCase, 1);
      expect(s.boosterPaymentFor(BoosterId.fullCase), BoosterPayment.inventory);
    });

    test('cả lượt: tổng kim cương phải đủ; kho trước; quảng cáo cho đúng một vật phẩm miễn phí', () {
      final s = _state(_Clock());
      s.addGems(-s.gems + 14);
      final all = {BoosterId.fullCase, BoosterId.patience};
      expect(s.boosterGemCost(all), 14);
      expect(s.boosterPlan(all), {BoosterId.fullCase: BoosterPayment.gems, BoosterId.patience: BoosterPayment.gems});
      final three = {...BoosterId.values};
      expect(s.boosterGemCost(three), 22);
      expect(s.boosterPlan(three), isNull);
      expect(s.consumeBoosters(three), isFalse);
      expect(s.gems, 14, reason: 'không đủ → không trừ gì');
      // Quảng cáo trả lò ×2 → còn 14 kim cương cho hai cái kia.
      expect(s.boosterPlan(three, adFree: BoosterId.ovenBoost)?[BoosterId.ovenBoost], BoosterPayment.ad);
      expect(s.consumeBoosters(three, adFree: BoosterId.ovenBoost), isTrue);
      expect(s.gems, 0);
      expect(s.boosterInventory.values, everyElement(0));
    });

    test('trừ đúng lúc Bắt đầu: kho trừ 1 mỗi loại, kim cương chỉ phần thiếu; không trừ hai lần cùng vật phẩm', () {
      final s = _state(_Clock());
      s
        ..addGems(-s.gems + 20)
        ..addBoosters(BoosterId.patience, 2);
      var notified = 0;
      s.addListener(() => notified++);
      // adFree trùng với vật phẩm đã chọn → chỉ tính miễn phí, không trừ kho/kim cương lần nữa.
      expect(s.consumeBoosters({BoosterId.patience, BoosterId.fullCase}, adFree: BoosterId.fullCase), isTrue);
      expect(notified, 1);
      expect(s.boosterCount(BoosterId.patience), 1);
      expect(s.boosterCount(BoosterId.fullCase), 0);
      expect(s.gems, 20);
      expect(s.consumeBoosters({BoosterId.ovenBoost}), isTrue);
      expect(s.gems, 12);
      // Không chọn gì: không trừ, không notify.
      expect(s.consumeBoosters(const {}), isTrue);
      expect(notified, 2);
    });
  });

  group('hoàn vật phẩm', () {
    test('refundBoosters: mỗi vật phẩm của lượt +1 vào kho (kể cả trả bằng kim cương / quảng cáo), không trả kim cương, '
        'lưu ngay', () async {
      final repo = MemorySaveRepository();
      final s = _state(_Clock())..attachAutosave(repo);
      s
        ..addGems(-s.gems + 8)
        ..addBoosters(BoosterId.patience, 1);
      final all = {...BoosterId.values};
      expect(s.consumeBoosters(all, adFree: BoosterId.ovenBoost), isTrue); // kho + 8 kim cương + quảng cáo
      expect(s.gems, 0);
      expect(s.boosterInventory.values, everyElement(0));
      final writes = repo.writeCount;
      s.refundBoosters(all);
      await Future<void>.delayed(Duration.zero);
      expect(s.boosterInventory, {BoosterId.fullCase: 1, BoosterId.patience: 1, BoosterId.ovenBoost: 1});
      expect(s.gems, 0);
      expect(repo.writeCount, greaterThan(writes), reason: 'lưu ngay, không chờ debounce');
      final saved = jsonDecode(repo.data!) as Map<String, dynamic>;
      expect(saved['boosters'], {'fullCase': 1, 'patience': 1, 'ovenBoost': 1});
      s.refundBoosters(const {});
      expect(s.boosterCount(BoosterId.fullCase), 1);
      s.dispose();
    });
  });

  group('kim cương kiếm trong game', () {
    test('lần đầu 3★ một level, hết chương (một lần); delta.gems', () {
      final s = _state(_Clock());
      _passTo(s, 9);
      final g0 = s.gems;
      final d10 = s.applyLevelResult(_result(10)); // level cuối chương 1
      expect(d10.gems, Economy.chapterCompleteGems);
      expect(s.gems, g0 + Economy.chapterCompleteGems);
      expect(s.applyLevelResult(_result(10, stars: 2)).gems, 0);
      expect(s.applyLevelResult(_result(10, stars: 3)).gems, Economy.levelThreeStarGems);
      expect(s.applyLevelResult(_result(10, stars: 3)).gems, 0);
      expect(s.applyLevelResult(_result(4, stars: 3)).gems, Economy.levelThreeStarGems);
      expect(s.applyLevelResult(_result(5, won: false)).gems, 0);
    });

    test('×2 xu màn kết quả: một lần mỗi kết quả, chỉ khi xu > 0', () {
      final s = _state(_Clock());
      final r = _result(1, coins: 300);
      s.applyLevelResult(r);
      final c = s.coins;
      expect(s.doubleResultCoins(r), 300);
      expect(s.isResultDoubled(r), isTrue);
      expect(s.doubleResultCoins(r), 0);
      expect(s.coins, c + 300);
      expect(s.doubleResultCoins(_result(2, won: false)), 0);
    });
  });

  group('interstitial (GĐ6 §3)', () {
    bool show(GameState s, {bool watched = false, bool chapter = false}) =>
        s.shouldShowInterstitialAfterResult(watchedRewardedHere: watched, unlockedChapter: chapter);

    test('mỗi 3 lượt chơi xong, chỉ từ khi đã qua L5; lượt trước đó không đếm', () {
      final s = _state(_Clock());
      for (var id = 1; id <= 4; id++) {
        s.applyLevelResult(_result(id));
        s.registerLevelPlayEnded();
        s.applyLevelResult(_result(id + 1, won: false)); // thua cũng là một lượt
        s.registerLevelPlayEnded();
      }
      expect(s.playsSinceInterstitial, 0);
      expect(show(s), isFalse);
      s.applyLevelResult(_result(5));
      s.registerLevelPlayEnded(); // lượt qua L5: bắt đầu đếm
      s.registerLevelPlayEnded();
      expect(show(s), isFalse);
      s.applyLevelResult(_result(6, won: false));
      s.registerLevelPlayEnded();
      expect(s.playsSinceInterstitial, 3);
      expect(show(s), isTrue);
      s.registerInterstitialShown();
      expect(s.playsSinceInterstitial, 0);
      expect(show(s), isFalse);
    });

    test('không hiện: vừa xem rewarded ở màn kết quả đó / vừa mở chương / đã mua Bỏ quảng cáo; lượt được giữ', () {
      final s = _state(_Clock());
      _passTo(s, 5);
      for (var i = 0; i < 4; i++) {
        s.registerLevelPlayEnded();
      }
      expect(show(s, watched: true), isFalse);
      expect(show(s, chapter: true), isFalse);
      expect(show(s), isTrue, reason: 'lần rời kết quả sau vẫn hiện');
      s.grantIap(IapProductId.removeAds);
      expect(show(s), isFalse);
      expect(s.rewardedLeftToday, Economy.maxRewardedPerDay);
      expect(Economy.maxRewardedPerDay, 12);
    });
  });

  group('IAP giả lập', () {
    test('danh mục V2 (7 gói), gói V1 ẩn nhưng vẫn mua/trao được; AdPlacement/IapProductId mới ở cuối', () {
      final s = _state(_Clock(), cfg: _real);
      final iap = FakeIapService(s, delay: Duration.zero);
      expect(iap.products.map((p) => p.id), [
        IapProductId.gemsS,
        IapProductId.gemsM,
        IapProductId.gemsL,
        IapProductId.starterPack,
        IapProductId.removeAds,
        IapProductId.staffOutfits,
        IapProductId.seasonPass,
      ]);
      expect(iap.products.map((p) => p.id), isNot(contains(IapProductId.pantryS)));
      expect(IapProductId.values.sublist(0, 6), [
        IapProductId.starterPack,
        IapProductId.pantryS,
        IapProductId.pantryM,
        IapProductId.pantryL,
        IapProductId.decorSetSeaside,
        IapProductId.removeAds,
      ]);
      expect(AdPlacement.values.last, AdPlacement.booster);
      // Không gắn config (rỗng) → danh mục code.
      expect(FakeIapService(GameState.newGame(), delay: Duration.zero).products.length, 7);
    });

    test('trao đúng nội dung, gói một lần đúng một lần, gói kim cương mua lại được', () async {
      final s = _state(_Clock(), cfg: _real);
      final iap = FakeIapService(s, delay: Duration.zero);
      final c = s.coins, g = s.gems;
      expect(await iap.buy(IapProductId.gemsS), isTrue);
      expect(await iap.buy(IapProductId.gemsS), isTrue);
      expect(s.gems, g + 160);
      expect(iap.isOwned(IapProductId.gemsS), isFalse);
      expect(await iap.buy(IapProductId.starterPack), isTrue);
      expect(s.coins, c + 8000);
      expect(s.gems, g + 160 + 120);
      expect(s.boosterInventory, {BoosterId.fullCase: 3, BoosterId.patience: 3, BoosterId.ovenBoost: 3});
      expect(iap.isOwned(IapProductId.starterPack), isTrue);
      expect(await iap.buy(IapProductId.starterPack), isFalse);
      expect(s.grantIap(IapProductId.starterPack), isFalse, reason: 'gọi thẳng cũng không trao lại');
      expect(s.coins, c + 8000);
      expect(s.boosterCount(BoosterId.fullCase), 3);
    });

    test('gói khởi đầu nổi bật từ L4 tới khi mua', () {
      final s = _state(_Clock(), cfg: _real);
      _passTo(s, 2);
      expect(s.starterPackFeatured, isFalse);
      s.applyLevelResult(_result(3));
      expect(s.starterPackFeatured, isTrue);
      s.grantIap(IapProductId.starterPack);
      expect(s.starterPackFeatured, isFalse);
    });

    test('trang phục: mua → bật; tắt/bật được; chưa mua thì không bật được', () {
      final s = _state(_Clock(), cfg: _real);
      s.setOutfitsEnabled(true);
      expect(s.outfitsEnabled, isFalse);
      expect(s.grantIap(IapProductId.staffOutfits), isTrue);
      expect(s.outfitsOwned, isTrue);
      expect(s.outfitsEnabled, isTrue);
      s.setOutfitsEnabled(false);
      expect(s.outfitsEnabled, isFalse);
      expect(s.outfitsOwned, isTrue);
    });

    test('thẻ mùa cao cấp: cần mùa đang diễn ra, mua một lần mỗi mùa', () async {
      final clock = _Clock()..now = DateTime(2026, 9, 1);
      final s = _state(clock);
      final iap = FakeIapService(s, delay: Duration.zero);
      expect(iap.canBuy(IapProductId.seasonPass), isFalse);
      expect(await iap.buy(IapProductId.seasonPass), isFalse);
      clock.now = DateTime(2026, 11, 1);
      s.refreshSeason();
      expect(iap.canBuy(IapProductId.seasonPass), isTrue);
      expect(await iap.buy(IapProductId.seasonPass), isTrue);
      expect(s.seasonPremium, isTrue);
      expect(iap.isOwned(IapProductId.seasonPass), isTrue);
      expect(await iap.buy(IapProductId.seasonPass), isFalse);
      expect(s.ownedIap, isNot(contains(IapProductId.seasonPass)));
    });

    test('restore: áp lại quyền gói một lần (không trao lại xu); không có gì → 0', () async {
      final s = _state(_Clock(), cfg: _real);
      final iap = FakeIapService(s, delay: Duration.zero);
      expect(await iap.restore(), 0);
      // Bản lưu có `iap` nhưng cờ removeAds / đồ trang trí bị mất.
      final json = s.toJson()
        ..['iap'] = ['removeAds', 'decorSetSeaside', 'starterPack', 'pantryS']
        ..['removeAds'] = false;
      final back = GameState.fromJson(json, clock: _Clock().call)..attachMonetizationConfig(_real);
      expect(back.removeAds, isFalse);
      final coins = back.coins;
      expect(await FakeIapService(back, delay: Duration.zero).restore(), 3);
      expect(back.removeAds, isTrue);
      expect(back.ownedDecor, containsAll(Catalog.decorSetSeaside));
      expect(back.coins, coins);
      expect(back.boosterInventory.values, everyElement(0));
    });
  });

  group('thẻ mùa', () {
    test('điểm: mỗi sao mới 10, mỗi lượt thắng 5; thua / chơi lại không sao mới chỉ được phần thắng', () {
      final s = _state(_Clock());
      expect(s.activeSeason?.id, 's1');
      expect(s.applyLevelResult(_result(1, stars: 2)).seasonPoints, 25);
      expect(s.applyLevelResult(_result(1, stars: 2)).seasonPoints, 5);
      expect(s.applyLevelResult(_result(1, stars: 3)).seasonPoints, 15);
      expect(s.applyLevelResult(_result(2, won: false)).seasonPoints, 0);
      expect(s.seasonPoints, 45);
      expect(s.seasonTier, 2);
      expect(s.seasonClaimable, [1, 2]);
      expect(s.seasonTimeLeft, DateTime(2026, 12, 1).difference(DateTime(2026, 11, 1, 10)));
    });

    test('ngoài mùa: không cộng điểm', () {
      final clock = _Clock()..now = DateTime(2027, 3, 1);
      final s = _state(clock);
      expect(s.activeSeason, isNull);
      expect(s.applyLevelResult(_result(1, stars: 3)).seasonPoints, 0);
      expect(s.seasonPoints, 0);
      expect(s.seasonClaimable, isEmpty);
    });

    test('claim từng bậc / nhận tất cả; cao cấp chỉ khi đã mua; không nhận hai lần', () {
      final s = _state(_Clock());
      s.applyLevelResult(_result(1, stars: 3)); // 35 điểm → bậc 2
      final c = s.coins;
      expect(s.claimSeason(1, premium: true), isFalse);
      expect(s.claimSeason(3, premium: false), isFalse, reason: 'chưa đạt');
      expect(s.claimSeason(0, premium: false), isFalse);
      expect(s.claimSeason(1, premium: false), isTrue);
      expect(s.claimSeason(1, premium: false), isFalse);
      expect(s.coins, c + 100);
      expect(s.seasonClaimed(1, premium: false), isTrue);
      expect(s.seasonClaimable, [2]);
      expect(s.claimAllSeason(), 1);
      expect(s.boosterCount(BoosterId.patience), 1 + 0); // bậc 2 free (+ quà L4 chưa tới)
      expect(s.seasonClaimable, isEmpty);
      s.grantIap(IapProductId.seasonPass);
      expect(s.seasonClaimable, [1, 2]);
      final g = s.gems;
      expect(s.claimAllSeason(), 2);
      expect(s.gems, g + 10);
      expect(s.ownedFrames, {'frame_a'});
      expect(s.claimAllSeason(), 0);
    });

    test('hết mùa: thưởng chưa nhận của bậc đã đạt tự nhận (thông báo), điểm/bậc/cao cấp về 0', () {
      final clock = _Clock();
      final s = _state(clock);
      s.applyLevelResult(_result(1, stars: 3));
      s.applyLevelResult(_result(2, stars: 3)); // 70 điểm → bậc 3
      s.grantIap(IapProductId.seasonPass);
      s.claimSeason(1, premium: false);
      final c = s.coins, g = s.gems;
      clock.now = DateTime(2026, 12, 1); // hết s1 (mùa trong config chưa đổi)
      s.refreshDaily();
      final auto = s.seasonAutoClaim!;
      expect(auto.seasonId, 's1');
      expect(auto.coins, 500);
      expect(auto.gems, 10 + 3);
      expect(auto.boosters, {BoosterId.patience: 1});
      expect(auto.frames, ['frame_a']);
      expect(s.coins, c + 500);
      expect(s.gems, g + 13);
      expect(s.seasonPoints, 0);
      expect(s.seasonTier, 0);
      expect(s.seasonPremium, isFalse);
      s.ackSeasonAutoClaim();
      expect(s.seasonAutoClaim, isNull);
      s.refreshDaily();
      expect(s.seasonAutoClaim, isNull, reason: 'không nhận lại');
    });

    test('đổi id mùa: tự nhận thưởng chờ của mùa cũ (previousSeasons) rồi tham gia mùa mới từ 0', () {
      final clock = _Clock();
      final s = _state(clock);
      s.applyLevelResult(_result(1, stars: 1)); // 15 điểm → bậc 1
      clock.now = DateTime(2026, 12, 5);
      final g = s.gems, c = s.coins;
      s.attachMonetizationConfig(_cfg(season: _s2, previous: [_s1]));
      expect(s.seasonAutoClaim?.coins, 100);
      expect(s.coins, c + 100);
      expect(s.gems, g);
      expect(s.activeSeason?.id, 's2');
      expect(s.seasonPoints, 0);
      expect(s.applyLevelResult(_result(1, stars: 2)).seasonPoints, 15);
      expect(s.toJson()['season'], containsPair('id', 's2'));
    });

    test('mùa cũ không còn dữ liệu → chỉ đặt lại; config rỗng → không đụng phần mùa', () {
      final clock = _Clock();
      final s = _state(clock);
      s.applyLevelResult(_result(1, stars: 3));
      s.attachMonetizationConfig(MonetizationConfig.empty());
      expect(s.toJson()['season'], containsPair('points', 35), reason: 'không nạp được file: giữ nguyên');
      clock.now = DateTime(2026, 12, 5);
      s.attachMonetizationConfig(_cfg(season: _s2));
      expect(s.seasonAutoClaim, isNull);
      expect(s.activeSeason?.id, 's2');
      expect(s.seasonPoints, 0);
    });

    test('mùa trong file hỏng / thiếu → không mất điểm, bậc đã nhận, cao cấp; mùa mới hợp lệ → tự nhận rồi đặt lại', () {
      final clock = _Clock();
      final s = _state(clock);
      s.applyLevelResult(_result(1, stars: 3)); // 35 điểm → bậc 2
      s.grantIap(IapProductId.seasonPass);
      s.claimSeason(1, premium: false);
      final saved = jsonEncode(s.toJson()['season']);
      final coins = s.coins;

      // (a) Loader khoan dung bỏ `season` hỏng → cờ seasonInvalid, season null.
      final raw = jsonDecode(File(MonetizationConfigLoader.assetPath).readAsStringSync()) as Map<String, dynamic>;
      (raw['season'] as Map<String, dynamic>)['end'] = 'hỏng';
      final broken = MonetizationConfigLoader.parse(jsonEncode(raw), strict: false, onSkip: (_) {});
      expect(broken.season, isNull);
      expect(broken.seasonInvalid, isTrue);
      expect(_real.seasonInvalid, isFalse);
      s.attachMonetizationConfig(broken);
      s.refreshDaily();
      expect(jsonEncode(s.toJson()['season']), saved);
      expect(s.seasonAutoClaim, isNull);

      // (b) Mùa mới hợp lệ khác id nhưng mục previousSeasons hỏng → vẫn giữ (không biết thưởng mùa cũ).
      clock.now = DateTime(2026, 12, 5);
      s.attachMonetizationConfig(MonetizationConfig(
        boosters: BoosterData.fallback,
        season: _s2,
        products: IapCatalog.v2,
        seasonInvalid: true,
      ));
      expect(jsonEncode(s.toJson()['season']), saved);

      // (c) File không có mùa nào (không hỏng) và không có dữ liệu mùa cũ → giữ.
      s.attachMonetizationConfig(_cfg());
      expect(jsonEncode(s.toJson()['season']), saved);
      expect(s.coins, coins);

      // (d) Mùa mới hợp lệ + mùa cũ ở previousSeasons → tự nhận phần còn chờ rồi đặt lại, tham gia s2.
      s.attachMonetizationConfig(_cfg(season: _s2, previous: [_s1]));
      final auto = s.seasonAutoClaim!;
      expect(auto.seasonId, 's1');
      expect(auto.gems, 10); // bậc 1 cao cấp
      expect(auto.boosters, {BoosterId.patience: 1}); // bậc 2 miễn phí
      expect(auto.frames, ['frame_a']); // bậc 2 cao cấp
      expect(s.activeSeason?.id, 's2');
      expect(s.seasonPoints, 0);
      expect(s.seasonPremium, isFalse);
    });
  });

  group('lưu / đọc', () {
    test('round-trip giữ mọi trường GĐ6', () {
      final clock = _Clock();
      final s = _state(clock);
      _passTo(s, 6);
      s
        ..addBoosters(BoosterId.ovenBoost, 4)
        ..markBoosterIntroSeen()
        ..registerLevelPlayEnded()
        ..grantIap(IapProductId.seasonPass)
        ..grantIap(IapProductId.staffOutfits)
        ..setOutfitsEnabled(false)
        ..claimSeason(1, premium: true);
      final text = jsonEncode(s.toJson());
      final back = GameState.fromJson(jsonDecode(text) as Map<String, dynamic>, clock: clock.call)
        ..attachLevelConfig(_levels)
        ..attachMonetizationConfig(_cfg(season: _s1));
      expect(back.toJson(), s.toJson());
      expect(back.boosterInventory, s.boosterInventory);
      expect(back.boosterIntroSeen, isTrue);
      expect(back.boosterGiftReceived, isTrue);
      expect(back.playsSinceInterstitial, 1);
      expect(back.seasonPoints, s.seasonPoints);
      expect(back.seasonPremium, isTrue);
      expect(back.seasonClaimed(1, premium: true), isTrue);
      expect(back.outfitsOwned, isTrue);
      expect(back.outfitsEnabled, isFalse);
    });

    test('bản lưu cũ thiếu trường GĐ6 → mặc định; trường hỏng → chỉ trường đó về mặc định', () {
      final s = _state(_Clock());
      final json = s.toJson();
      for (final k in ['boosters', 'boosterIntro', 'playsSinceInterstitial', 'season', 'frames', 'outfits']) {
        json.remove(k);
      }
      final old = GameState.fromJson(json, clock: _Clock().call);
      expect(old.boosterInventory.values, everyElement(0));
      expect(old.playsSinceInterstitial, 0);
      expect(old.ownedFrames, isEmpty);

      final broken = s.toJson()
        ..['boosters'] = {'fullCase': 2, 'patience': 'nhiều', 'magic': 3}
        ..['playsSinceInterstitial'] = -4
        ..['season'] = {'id': 's1', 'points': 'x', 'claimedFree': [1, 'a'], 'premium': true}
        ..['outfits'] = 'on'
        ..['frames'] = ['frame_a', 7];
      final b = GameState.fromJson(broken, clock: _Clock().call)..attachMonetizationConfig(_cfg(season: _s1));
      expect(b.boosterInventory, {BoosterId.fullCase: 2, BoosterId.patience: 0, BoosterId.ovenBoost: 0});
      expect(b.playsSinceInterstitial, 0);
      expect(b.seasonPoints, 0);
      expect(b.seasonPremium, isTrue);
      expect(b.ownedFrames, {'frame_a'});
      expect(b.outfitsEnabled, isFalse);
      expect(b.coins, s.coins);
    });

    test('trường cũ lastInterstitialDay vẫn đọc và ghi lại nguyên giá trị', () {
      final json = GameState.newGame().toJson()..['lastInterstitialDay'] = 4;
      final s = GameState.fromJson(json);
      expect(s.lastInterstitialDay, 4);
      expect(s.toJson()['lastInterstitialDay'], 4);
    });
  });
}
