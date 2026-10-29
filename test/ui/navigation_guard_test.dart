import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/ui/day/day_screen.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

/// Interstitial luôn đến lượt nhưng ném lỗi.
class _BrokenInterstitialAds extends FakeAdService {
  _BrokenInterstitialAds(super.state) : super(duration: kTestAdDuration);

  @override
  bool shouldShowInterstitial(int completedDay) => true;

  @override
  Future<void> showInterstitial(BuildContext context, int completedDay) async => throw StateError('ad sdk lỗi');
}

DaySummary _emptySummary(int day) => DaySummary(
  dayNumber: day,
  records: const [],
  revenue: 0,
  tips: 0,
  costs: 0,
  net: 0,
  xpGained: 0,
  dayBonusXp: Economy.dayBonusXp,
  levelBefore: 1,
  levelAfter: 1,
  unlocks: const [],
);

/// Dựng app 1280×720 với bảng route tuỳ chỉnh.
Future<void> _pumpApp(WidgetTester tester, AppServices services, {RouteFactory? routes}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MainMenuScreen.giftShownThisSession = false;
  await tester.pumpWidget(
    SugarleafApp(services: services, onGenerateRoute: routes ?? onGenerateUiRoute, useGoogleFonts: false),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menu: bấm đúp nút chỉ mở một màn', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state);

    // Gọi thẳng 2 lần trong cùng một khung hình (hai lần chạm lọt qua trước khi route mới kịp che nút).
    final store = tester.widget<SLButton>(find.widgetWithText(SLButton, 'Store'));
    store.onPressed!();
    store.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen, skipOffstage: false), findsOneWidget);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tổng kết: interstitial lỗi vẫn về menu, không kẹt', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    final services = AppServices(
      state: state,
      saves: MemorySaveRepository(),
      ads: _BrokenInterstitialAds(state),
      iap: FakeIapService(state, delay: Duration.zero),
      audio: FakeAudioService(state),
    );
    await _pumpApp(tester, services);
    navigator(tester).pushNamed(AppRoutes.summary, arguments: DaySummaryArgs(_emptySummary(6)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ngày → tổng kết (pushReplacement) → menu: làm mới ngày lịch và tự mở quà', (tester) async {
    var now = DateTime(2026, 3, 10, 23, 50);
    final state = GameState.newGame(clock: () => now)
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await _pumpApp(
      tester,
      testServices(state),
      // Màn ngày giả: một nút chốt ngày, thay route bằng tổng kết như DayScreen thật.
      routes: (settings) => settings.name == AppRoutes.day
          ? fadeRoute(
              settings,
              Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed(
                        AppRoutes.summary,
                        arguments: DaySummaryArgs(_emptySummary(1)),
                      ),
                      child: const Text('finish day'),
                    ),
                  ),
                ),
              ),
            )
          : onGenerateUiRoute(settings),
    );
    expect(find.text('Claim'), findsNothing);

    await tester.tap(find.text('Open the bakery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('finish day'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);

    // Qua nửa đêm trong lúc xem tổng kết.
    now = DateTime(2026, 3, 11, 0, 5);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(state.quests.map((q) => q.type), GameState.questTypesFor('2026-03-11'));
    expect(find.text('Claim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đang làm bánh: nút thoát hỏi xác nhận rồi về menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MainMenuScreen.giftShownThisSession = true;
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin()
      ..markSceneSeen(StorySceneId.prologue);
    await tester.pumpWidget(
      SugarleafApp(
        services: testServices(state),
        useGoogleFonts: false,
        onGenerateRoute: (settings) => settings.name == AppRoutes.day
            ? fadeRoute(settings, DayScreen(random: math.Random(7)))
            : onGenerateUiRoute(settings),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open the bakery'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start baking'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Step 1/6'), findsOneWidget);

    await tester.tap(find.byTooltip('Leave for now?'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text("Coins earned so far are kept, but today won't count as completed."), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Open the bakery'), findsOneWidget);
    expect(find.text('Step 1/6'), findsNothing);
    expect(state.dayNumber, 1);
    expect(tester.takeException(), isNull);
  });
}
