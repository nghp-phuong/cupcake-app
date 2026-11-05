import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/city/city_settings.dart';
import 'package:sugarleaf_bakery/ui/city_routes.dart';

/// Phố giả cho test route (không dính thermion).
const kTownStubKey = ValueKey('town-stub');

/// Dịch vụ cho test giao diện: `CitySaveStore.load` trên kho bộ nhớ (không autosave, không timer), ngôn ngữ [language].
Future<AppServices> cityServices({
  LanguagePref language = LanguagePref.en,
  AudioService? audio,
}) async {
  final store = await CitySaveStore.load(MemoryCitySaveRepository());
  addTearDown(store.dispose);
  store.game.settings.setLanguage(language);
  return AppServices(
    game: store.game,
    store: store,
    ads: FakeAdService(store.game),
    audio: audio ?? FakeAudioService(store.game.settings),
  );
}

/// Dựng app thật (`SugarleafApp` + `cityRouteFactory` với phố giả) trong khung [size] (dpr 1), không tải font mạng.
/// Cảnh mở đầu chạy liên tục nên không `pumpAndSettle`: người gọi tự `pump`.
Future<void> pumpCityApp(
  WidgetTester tester,
  AppServices services, {
  String initialRoute = AppRoutes.town,
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SugarleafApp(
      services: services,
      onGenerateRoute: cityRouteFactory(
        town: (_) => const SizedBox.expand(key: kTownStubKey),
      ),
      initialRoute: initialRoute,
      useGoogleFonts: false,
    ),
  );
  await tester.pump();
}

NavigatorState navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);
