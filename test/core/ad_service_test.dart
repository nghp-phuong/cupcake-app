import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';

void main() {
  testWidgets('presenter tiêm vào: được gọi đúng thời lượng, đếm/giới hạn vẫn ở FakeAdService', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final s = GameState.newGame(clock: () => DateTime(2026, 10, 29, 9));
    final calls = <Duration>[];
    const duration = Duration(milliseconds: 1500);
    final ads = FakeAdService(s, duration: duration, presenter: (_, d) async => calls.add(d));

    for (var i = 0; i < Economy.maxRewardedPerDay; i++) {
      expect(await ads.showRewarded(context, AdPlacement.freeGem), isTrue);
    }
    expect(s.rewardedToday, Economy.maxRewardedPerDay);
    expect(await ads.showRewarded(context, AdPlacement.freeGem), isFalse); // hết lượt: không mở hộp thoại
    expect(calls, List.filled(Economy.maxRewardedPerDay, duration));

    await ads.showInterstitial(context, 3); // chưa tới ngày 4: không hiện
    expect(calls.length, Economy.maxRewardedPerDay);
    await ads.showInterstitial(context, 4);
    expect(calls.length, Economy.maxRewardedPerDay + 1);
    expect(s.lastInterstitialDay, 4);
  });

  test('mặc định là hộp thoại của core', () {
    final ads = FakeAdService(GameState.newGame());
    expect(ads.presenter, same(showSimulatedAdDialog));
  });
}
