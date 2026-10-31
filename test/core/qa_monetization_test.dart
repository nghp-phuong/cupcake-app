import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';

import 'qa_helpers.dart';

/// QA việc 6: quảng cáo / IAP chế độ giả lập.

Future<BuildContext> _context(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  return tester.element(find.byType(SizedBox));
}

void main() {
  group('rewarded', () {
    testWidgets('quảng cáo lỗi / bị đóng giữa chừng (presenter ném) → không trả true, không tính lượt', (tester) async {
      final ctx = await _context(tester);
      final s = qaState();
      final ads = FakeAdService(s, presenter: (_, __) async => throw StateError('đóng giữa chừng'));
      Object? error;
      bool? watched;
      try {
        watched = await ads.showRewarded(ctx, AdPlacement.doubleCoins);
      } catch (e) {
        error = e;
      }
      expect(watched, isNot(true));
      expect(error, isNotNull, reason: 'hiện trạng: ném ra cho UI, không có giá trị "huỷ"');
      expect(s.rewardedToday, 0);
    });

    testWidgets('giới hạn lượt theo ngày lịch: hết lượt → false, không mở quảng cáo; qua nửa đêm → lượt mới', (tester) async {
      final ctx = await _context(tester);
      final clock = QaClock(DateTime(2026, 10, 30, 23, 50));
      final s = qaState(clock: clock);
      var opened = 0;
      final ads = FakeAdService(s, presenter: (_, __) async => opened++);
      for (var i = 0; i < Economy.maxRewardedPerDay; i++) {
        expect(await ads.showRewarded(ctx, AdPlacement.freeGem), isTrue);
      }
      expect(ads.canShowRewarded(), isFalse);
      expect(await ads.showRewarded(ctx, AdPlacement.extraTime), isFalse);
      expect(opened, Economy.maxRewardedPerDay);
      expect(s.rewardedLeftToday, 0);
      clock.now = DateTime(2026, 10, 31, 0, 1);
      expect(s.rewardedLeftToday, Economy.maxRewardedPerDay);
      expect(await ads.showRewarded(ctx, AdPlacement.freeGem), isTrue);
      expect(s.rewardedToday, 1);
    });

    testWidgets('CẦN PO: lùi ngày hệ thống → lượt rewarded được đặt lại (hiện trạng)', (tester) async {
      final ctx = await _context(tester);
      final clock = QaClock(DateTime(2026, 10, 30, 12));
      final s = qaState(clock: clock);
      final ads = FakeAdService(s, presenter: (_, __) async {});
      for (var i = 0; i < Economy.maxRewardedPerDay; i++) {
        await ads.showRewarded(ctx, AdPlacement.freeGem);
      }
      expect(ads.canShowRewarded(), isFalse);
      clock.now = DateTime(2026, 10, 29, 12); // lùi một ngày
      var extra = 0;
      while (await ads.showRewarded(ctx, AdPlacement.freeGem)) {
        extra++;
      }
      expect(extra, Economy.maxRewardedPerDay);
      clock.now = DateTime(2026, 10, 30, 12, 5); // chỉnh lại giờ thật
      expect(ads.canShowRewarded(), isTrue, reason: 'lại thêm 12 lượt trong cùng một ngày thật (tổng 36)');
    });

    test('thưởng của rewarded chỉ một lần: x2 xu một lần mỗi kết quả, +30 giây một lần mỗi lượt', () {
      final s = qaState();
      final r = qaResult(1, coins: 250);
      s.applyLevelResult(r);
      final c = s.coins;
      expect(s.doubleResultCoins(r), 250);
      expect(s.doubleResultCoins(r), 0);
      expect(s.coins, c + 250);
      final ls = qaSession(qaLevel(durationSec: 10));
      qaRunToEnd(ls);
      ls.addTime(30);
      ls.addTime(30);
      expect(ls.duration, 40);
      ls.dispose();
    });

    test('CẦN PO: vật phẩm miễn phí nhờ quảng cáo, thoát trước lần bán đầu → hoàn +1 vào kho (đổi quảng cáo thành vật phẩm)', () {
      final s = qaState();
      qaPassTo(s, 4);
      final before = s.boosterCount(BoosterId.fullCase);
      expect(s.consumeBoosters({BoosterId.fullCase}, adFree: BoosterId.fullCase), isTrue);
      s.refundBoosters({BoosterId.fullCase});
      expect(s.boosterCount(BoosterId.fullCase), before + 1);
    });
  });

  group('interstitial', () {
    testWidgets('sau L5: 10 lượt chơi liền, rời kết quả mỗi lượt → hiện đúng ở lượt 3, 6, 9', (tester) async {
      final ctx = await _context(tester);
      final s = qaState();
      qaPassTo(s, 5);
      final ads = FakeAdService(s, presenter: (_, __) async {});
      final shownAt = <int>[];
      for (var play = 1; play <= 10; play++) {
        s.applyLevelResult(qaResult(6, won: play.isEven));
        s.registerLevelPlayEnded();
        if (await ads.showInterstitial(ctx, watchedRewardedHere: false, unlockedChapter: false)) shownAt.add(play);
      }
      expect(shownAt, [3, 6, 9]);
    });

    testWidgets('trước khi qua L5 không bao giờ hiện, dù chơi bao nhiêu lượt', (tester) async {
      final ctx = await _context(tester);
      final s = qaState();
      qaPassTo(s, 4);
      final ads = FakeAdService(s, presenter: (_, __) async => fail('không được mở interstitial'));
      for (var i = 0; i < 20; i++) {
        s.applyLevelResult(qaResult(5, won: false));
        s.registerLevelPlayEnded();
        expect(await ads.showInterstitial(ctx, watchedRewardedHere: false, unlockedChapter: false), isFalse);
      }
      expect(s.playsSinceInterstitial, 0);
    });

    test('thoát giữa màn (không có kết quả) không được tính lượt cho interstitial', () {
      final s = qaState();
      qaPassTo(s, 6);
      final n = s.playsSinceInterstitial;
      final ls = qaSession(qaLevels.level(7));
      qaRun(ls, 30);
      ls.dispose(); // thoát: UI không gọi applyLevelResult / registerLevelPlayEnded
      expect(s.playsSinceInterstitial, n);
      expect(s.shouldShowInterstitialAfterResult(watchedRewardedHere: false, unlockedChapter: false), isFalse);
    });
  });

  group('IAP giả lập', () {
    test('mua thành công trao đúng một lần với gói một lần; gói tiêu hao mua lại được; không có mùa → thẻ mùa từ chối', () async {
      final s = qaState(clock: QaClock(DateTime(2030, 1, 1)));
      final iap = FakeIapService(s, delay: Duration.zero);
      final g0 = s.gems;
      expect(await iap.buy(IapProductId.gemsS), isTrue);
      final per = s.gems - g0;
      expect(per, greaterThan(0));
      expect(await iap.buy(IapProductId.gemsS), isTrue);
      expect(s.gems, g0 + 2 * per);

      final c0 = s.coins;
      expect(await iap.buy(IapProductId.starterPack), isTrue);
      final c1 = s.coins;
      expect(c1, greaterThan(c0));
      expect(iap.isOwned(IapProductId.starterPack), isTrue);
      expect(await iap.buy(IapProductId.starterPack), isFalse);
      expect(s.coins, c1, reason: 'không trao lại');

      expect(s.activeSeason, isNull, reason: '2030: ngoài mùa');
      expect(iap.canBuy(IapProductId.seasonPass), isFalse);
      expect(await iap.buy(IapProductId.seasonPass), isFalse);
      expect(s.seasonPremium, isFalse);
    });

    test('xoá quảng cáo: có hiệu lực ngay, giữ qua lưu/đọc; rewarded vẫn xem được (theo chủ ý của người chơi)', () async {
      final s = qaState();
      qaPassTo(s, 6);
      for (var i = 0; i < 5; i++) {
        s.registerLevelPlayEnded();
      }
      bool show(GameState g) => g.shouldShowInterstitialAfterResult(watchedRewardedHere: false, unlockedChapter: false);
      expect(show(s), isTrue);
      expect(await FakeIapService(s, delay: Duration.zero).buy(IapProductId.removeAds), isTrue);
      expect(show(s), isFalse);
      expect(s.removeAds, isTrue);
      final again = GameState.fromJson(s.toJson())..attachLevelConfig(qaLevels);
      expect(show(again), isFalse);
      expect(again.rewardedLeftToday, greaterThan(0));
    });

    test('khôi phục: áp lại quyền xoá quảng cáo khi cờ bị mất, không trao lại xu; không có gì → 0', () async {
      final s = qaState(json: {
        'iap': ['removeAds', 'starterPack', 'gemsS'],
        'removeAds': false,
      });
      final c0 = s.coins, g0 = s.gems;
      final iap = FakeIapService(s, delay: Duration.zero);
      expect(await iap.restore(), 2, reason: 'chỉ gói một lần');
      expect(s.removeAds, isTrue);
      expect((s.coins, s.gems), (c0, g0));
      expect(await FakeIapService(qaState(), delay: Duration.zero).restore(), 0);
    });

    test('CẦN PO: xoá dữ liệu (resetAll) → mất quyền đã mua, khôi phục giả lập trả 0 (không có máy chủ cửa hàng)', () async {
      final s = qaState();
      s.grantIap(IapProductId.removeAds);
      await s.resetAll();
      expect(s.removeAds, isFalse);
      expect(await FakeIapService(s, delay: Duration.zero).restore(), 0);
    });
  });
}
