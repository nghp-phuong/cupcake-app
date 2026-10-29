import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

/// Thời lượng quảng cáo giả lập trong test.
const kTestAdDuration = Duration(seconds: 1);

AppServices testServices(GameState state) => AppServices(
  state: state,
  saves: MemorySaveRepository(),
  ads: FakeAdService(state, duration: kTestAdDuration),
  iap: FakeIapService(state, delay: Duration.zero),
  audio: FakeAudioService(state),
);

/// Dựng app thật (route của ui) trong khung 1280×720, không tải font mạng.
Future<void> pumpSugarApp(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MainMenuScreen.giftShownThisSession = false;
  await tester.pumpWidget(
    SugarleafApp(services: testServices(state), onGenerateRoute: onGenerateUiRoute, useGoogleFonts: false),
  );
  await tester.pumpAndSettle();
}

NavigatorState navigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

/// Chờ quảng cáo giả lập tự đóng.
Future<void> waitForAd(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kTestAdDuration);
  await tester.pumpAndSettle();
}

/// Đợi snackbar biến mất để không còn timer treo khi kết thúc test.
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}
