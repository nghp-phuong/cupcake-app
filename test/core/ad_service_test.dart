import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';

void main() {
  testWidgets('presenter tiêm vào: được gọi đúng thời lượng, đếm/giới hạn theo sổ AdLedger', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    var now = DateTime(2026, 11, 4, 9);
    final game = CityGame(clock: () => now)..refreshDay();
    final calls = <Duration>[];
    const duration = Duration(milliseconds: 1500);
    final ads = FakeAdService(game, duration: duration, presenter: (_, d) async => calls.add(d));

    for (var i = 0; i < CityGame.maxRewardedPerDay; i++) {
      expect(ads.canShowRewarded(), isTrue);
      expect(await ads.showRewarded(context, AdPlacement.doubleCoins), isTrue);
    }
    expect(game.rewardedToday, CityGame.maxRewardedPerDay);
    expect(ads.canShowRewarded(), isFalse);
    expect(await ads.showRewarded(context, AdPlacement.doubleCoins), isFalse); // hết lượt: không mở hộp thoại
    expect(calls, List.filled(CityGame.maxRewardedPerDay, duration));

    // Sang ngày mới: lượt xem đặt lại.
    now = DateTime(2026, 11, 5, 9);
    expect(ads.canShowRewarded(), isTrue);
    expect(await ads.showRewarded(context, AdPlacement.doubleCoins), isTrue);
    expect(game.rewardedToday, 1);
  });

  testWidgets('showInterstitial: dùng presenter, không cộng vào sổ quảng cáo thưởng', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final game = CityGame()..refreshDay();
    final calls = <Duration>[];
    const duration = Duration(milliseconds: 900);
    final ads = FakeAdService(game, duration: duration, presenter: (_, d) async => calls.add(d));
    await ads.showInterstitial(context);
    await ads.showInterstitial(context);
    expect(calls, [duration, duration]);
    expect(game.rewardedToday, 0);
    expect(ads.canShowRewarded(), isTrue);
  });

  test('mặc định là hộp thoại của core', () {
    final ads = FakeAdService(CityGame());
    expect(ads.presenter, same(showSimulatedAdDialog));
  });
}
