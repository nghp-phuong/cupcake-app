import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// QA quảng cáo ở giao diện: rewarded bị huỷ (người chơi đóng sớm / SDK lỗi → `showRewarded` trả false) thì không
/// thưởng; interstitial không bao giờ hiện trong màn chơi / thẻ Sẵn sàng, chỉ khi rời màn kết quả.

/// Dịch vụ quảng cáo ghi lại mọi lần gọi. [cancelRewarded] = người chơi đóng quảng cáo thưởng trước khi xong;
/// [throwRewarded] = SDK ném lỗi khi hiện quảng cáo thưởng.
class _SpyAds implements AdService {
  _SpyAds(this.state, {this.cancelRewarded = false, this.throwRewarded = false})
      : _real = FakeAdService(state, duration: kTestAdDuration);

  final GameState state;
  final bool cancelRewarded;
  final bool throwRewarded;
  final FakeAdService _real;

  final List<AdPlacement> rewarded = [];

  /// Tên route trên cùng lúc interstitial được gọi.
  final List<String?> interstitialAt = [];

  @override
  bool canShowRewarded() => _real.canShowRewarded();

  @override
  Future<bool> showRewarded(BuildContext context, AdPlacement placement) async {
    rewarded.add(placement);
    if (throwRewarded) throw StateError('SDK quảng cáo lỗi (giả)');
    if (cancelRewarded) return false;
    return _real.showRewarded(context, placement);
  }

  @override
  bool shouldShowInterstitial({required bool watchedRewardedHere, required bool unlockedChapter}) =>
      _real.shouldShowInterstitial(watchedRewardedHere: watchedRewardedHere, unlockedChapter: unlockedChapter);

  @override
  Future<bool> showInterstitial(BuildContext context,
      {required bool watchedRewardedHere, required bool unlockedChapter}) async {
    final shown = await _real.showInterstitial(context,
        watchedRewardedHere: watchedRewardedHere, unlockedChapter: unlockedChapter);
    if (shown) interstitialAt.add(ModalRoute.of(context)?.settings.name);
    return shown;
  }
}

AppServices _services(GameState state, _SpyAds ads) {
  final base = testServices(state, levels: qaLevels);
  return AppServices(
    state: state,
    saves: base.saves,
    ads: ads,
    iap: base.iap,
    audio: base.audio,
    levels: base.levels,
    unlocks: base.unlocks,
    monetization: base.monetization,
  );
}

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

SLButton _button(WidgetTester tester, bool Function(String label) test) => tester
    .widget<SLButton>(find.byWidgetPredicate((w) => w is SLButton && w.label != null && test(w.label!)).last);

void main() {
  setUp(() => qaNow = DateTime(2026, 10, 28, 10));

  group('rewarded bị huỷ → không thưởng', () {
    testWidgets('kết quả: ×2 xu bị huỷ → xu giữ nguyên, vẫn bấm lại được', (tester) async {
      final state = qaState(LanguagePref.en, cleared: 3);
      final ads = _SpyAds(state, cancelRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      navigator(tester).pushNamed(AppRoutes.levelResult,
          arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3)));
      await tester.pumpAndSettle();
      final coins = state.coins;
      final l = _l(tester);
      await tester.tap(find.text(l.levelResultDoubleCoins));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.doubleCoins]);
      expect(state.coins, coins);
      expect(_button(tester, (s) => s == l.levelResultDoubleCoins).onPressed, isNotNull);
      await settleToasts(tester);
    });

    testWidgets('cửa hàng: xem quảng cáo lấy kim cương bị huỷ → kim cương giữ nguyên', (tester) async {
      final state = qaState(LanguagePref.en, cleared: 3);
      final ads = _SpyAds(state, cancelRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      navigator(tester).pushNamed(AppRoutes.store);
      await tester.pumpAndSettle();
      final gems = state.gems;
      await tester.tap(find.text(_l(tester).commonWatchAd));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.freeGem]);
      expect(state.gems, gems);
      await settleToasts(tester);
    });

    testWidgets('vắng nhà: x2 bị huỷ → chưa cộng, hộp còn, "Nhận" vẫn cộng đúng 1 lần', (tester) async {
      final state = qaStateWithOffline(LanguagePref.en);
      final ads = _SpyAds(state, cancelRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      final pending = state.pendingOffline!;
      final coins = state.coins;
      await tester.tap(find.byKey(const ValueKey('offline-double')));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.offlineDouble]);
      expect(state.coins, coins);
      expect(find.byKey(const ValueKey('offline-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('offline-claim')));
      await tester.pumpAndSettle();
      expect(state.coins, coins + pending.coins);
      await settleToasts(tester);
    });

    testWidgets('hết giờ: +30 giây bị huỷ → không thêm giờ, sang kết quả, cộng xu một lần', (tester) async {
      final state = qaState(LanguagePref.en);
      final ads = _SpyAds(state, cancelRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2));
      await qaFrames(tester, 12);
      final l = _l(tester);
      await tester.tap(find.text(l.levelStart));
      await qaFrames(tester, 2);
      final session = tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;
      final duration = session.duration;
      final coins = state.coins;
      while (!session.isOver) {
        session.advance(LevelSession.maxFrameDt);
      }
      await qaFrames(tester, 6);
      await tester.tap(find.text(l.levelExtraTimeWatch(LevelScreen.extraTimeSec)));
      await qaFrames(tester, 6);
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.extraTime]);
      expect(session.duration, duration);
      expect(find.byType(LevelResultScreen), findsOneWidget);
      expect(state.coins, coins + session.finish().coins);
      await settleToasts(tester);
    });

    testWidgets('huỷ quảng cáo (vẫn còn lượt) → không báo nhầm "hết lượt quảng cáo hôm nay"', (tester) async {
      final state = qaState(LanguagePref.en, cleared: 3);
      final ads = _SpyAds(state, cancelRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      navigator(tester).pushNamed(AppRoutes.levelResult,
          arguments: LevelResultArgs(fakeLevelResult(3, won: true, stars: 3)));
      await tester.pumpAndSettle();
      final l = _l(tester);
      expect(ads.canShowRewarded(), isTrue);
      await tester.tap(find.text(l.levelResultDoubleCoins));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.adsLimitReached), findsNothing);
      expect(find.text(l.adNotCompleted), findsOneWidget);
      await settleToasts(tester);
    }); // UI-07 đã sửa: còn lượt → adNotCompleted (showRewardedFailedToast).
  });

  // QA-02: SDK ném lỗi giữa lúc gọi quảng cáo thưởng → không kẹt trạng thái "đang xem".
  group('rewarded ném lỗi → không kẹt', () {
    testWidgets('vắng nhà: x2 ném lỗi → hộp còn, "Nhận" bấm được và cộng đúng xu một lần', (tester) async {
      final state = qaStateWithOffline(LanguagePref.en);
      final ads = _SpyAds(state, throwRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      final pending = state.pendingOffline!;
      final coins = state.coins;
      await tester.tap(find.byKey(const ValueKey('offline-double')));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.offlineDouble]);
      expect(state.coins, coins);
      expect(find.byKey(const ValueKey('offline-dialog')), findsOneWidget);
      final claim = tester.widget<SLButton>(find.byKey(const ValueKey('offline-claim')));
      expect(claim.onPressed, isNotNull, reason: 'Nhận không được kẹt sau khi quảng cáo lỗi');
      await tester.tap(find.byKey(const ValueKey('offline-claim')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('offline-dialog')), findsNothing);
      expect(state.coins, coins + pending.coins);
      expect(state.pendingOffline, isNull);
      await settleToasts(tester);
    });

    testWidgets('vắng nhà: x2 ném lỗi → Back vẫn nhận thường và đóng hộp', (tester) async {
      final state = qaStateWithOffline(LanguagePref.en);
      final ads = _SpyAds(state, throwRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      final pending = state.pendingOffline!;
      final coins = state.coins;
      await tester.tap(find.byKey(const ValueKey('offline-double')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('offline-dialog')), findsNothing);
      expect(state.coins, coins + pending.coins);
      await settleToasts(tester);
    });

    testWidgets('cửa hàng: kim cương qua quảng cáo ném lỗi → nút trở lại bình thường, bấm lại được', (tester) async {
      final state = qaState(LanguagePref.en, cleared: 3);
      final ads = _SpyAds(state, throwRewarded: true);
      await pumpSugarApp(tester, state, services: _services(state, ads));
      navigator(tester).pushNamed(AppRoutes.store);
      await tester.pumpAndSettle();
      final gems = state.gems;
      final l = _l(tester);
      await tester.tap(find.text(l.commonWatchAd));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.freeGem]);
      expect(state.gems, gems);
      final watch = _button(tester, (s) => s == l.commonWatchAd);
      expect(watch.loading, isFalse, reason: 'nút không được kẹt ở "đang xem"');
      expect(watch.onPressed, isNotNull);
      await settleToasts(tester);
      await tester.tap(find.text(l.commonWatchAd));
      await tester.pumpAndSettle();
      expect(ads.rewarded, [AdPlacement.freeGem, AdPlacement.freeGem]);
      await settleToasts(tester);
    });
  });

  group('interstitial', () {
    testWidgets('đủ điều kiện xen kẽ: không hiện ở thẻ Sẵn sàng / trong màn / lúc hết giờ; chỉ khi rời màn kết quả',
        (tester) async {
      final state = qaState(LanguagePref.en, cleared: 8);
      // Đủ số lượt chơi xong kể từ lần xen kẽ trước.
      for (var i = 0; i < 5; i++) {
        state.registerLevelPlayEnded();
      }
      expect(state.shouldShowInterstitialAfterResult(watchedRewardedHere: false, unlockedChapter: false), isTrue);
      final ads = _SpyAds(state);
      await pumpSugarApp(tester, state, services: _services(state, ads));

      navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(9));
      await qaFrames(tester, 12);
      final l = _l(tester);
      for (var i = 0; i < 20 && find.text(l.levelStart).evaluate().isEmpty; i++) {
        await tester.tapAt(const Offset(640, 300)); // cảnh mở màn (nếu có)
        await qaFrames(tester, 3);
      }
      expect(ads.interstitialAt, isEmpty, reason: 'thẻ Sẵn sàng');
      await tester.tap(find.text(l.levelStart));
      await qaFrames(tester, 10);
      expect(ads.interstitialAt, isEmpty, reason: 'đang chơi');
      final session = tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;
      while (!session.isOver) {
        session.advance(LevelSession.maxFrameDt);
      }
      await qaFrames(tester, 6);
      if (find.text(l.levelExtraTimeNo).evaluate().isNotEmpty) {
        expect(ads.interstitialAt, isEmpty, reason: 'hộp +30 giây');
        await tester.tap(find.text(l.levelExtraTimeNo));
      }
      await qaFrames(tester, 10);
      await tester.pumpAndSettle();
      expect(find.byType(LevelResultScreen), findsOneWidget);
      expect(ads.interstitialAt, isEmpty, reason: 'màn kết quả vừa mở');

      await tester.tap(find.text(l.mapBackToMap));
      await tester.pump();
      await tester.pump(kTestAdDuration);
      await tester.pumpAndSettle();
      expect(ads.interstitialAt, [AppRoutes.levelResult]);
      expect(find.byType(LevelMapScreen), findsOneWidget);
      expect(find.byType(LevelScreen), findsNothing);
      await settleToasts(tester);
    });
  });
}
