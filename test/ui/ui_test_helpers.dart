import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/ui/common/navigation.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

/// Thời lượng quảng cáo giả lập trong test.
const kTestAdDuration = Duration(seconds: 1);

/// levels.json thật (đọc thẳng file, không qua asset bundle).
LevelConfig testLevelConfig() => LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

/// levels.json thật + chương thử 3 gồm L21..[upTo] (chép L20, không truyện, không phải màn đặc biệt) — để thử các
/// mốc nhân viên L25–L32 khi levels.json mới có 20 màn. levels.json đã có tới [upTo] (GĐ8: chương 3–5) → dùng bản
/// thật.
LevelConfig testExtendedLevelConfig({int upTo = 40}) {
  final json = jsonDecode(File(LevelConfigLoader.assetPath).readAsStringSync()) as Map<String, dynamic>;
  final levels = (json['levels'] as List).cast<Map<String, dynamic>>();
  final last = levels.last;
  if ((last['id'] as int) >= upTo) return testLevelConfig();
  (json['chapters'] as List).add({
    'id': 3,
    'title': {'en': 'Test Chapter', 'vi': 'Chương thử'},
    'starsToUnlock': 0,
    'mapArt': 'chapter_3',
  });
  final n = upTo - (last['id'] as int);
  for (var k = 0; k < n; k++) {
    levels.add({
      ...last,
      'id': (last['id'] as int) + 1 + k,
      'chapter': 3,
      'title': {'en': 'Test ${k + 1}', 'vi': 'Thử ${k + 1}'},
      'special': false,
      'introScene': null,
      'outroScene': null,
      'mapPos': [0.08 + 0.84 * k / (n > 1 ? n - 1 : 1), k.isEven ? 0.74 : 0.48],
    });
  }
  return LevelConfigLoader.parse(jsonEncode(json), strict: true);
}

/// unlocks.json thật (đọc thẳng file), đọc một lần cho cả bộ test.
final UnlockConfig _unlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync());
UnlockConfig testUnlockConfig() => _unlocks;

/// monetization.json thật (đọc thẳng file), đọc một lần cho cả bộ test.
final MonetizationConfig _monetization =
    MonetizationConfigLoader.parse(File(MonetizationConfigLoader.assetPath).readAsStringSync());
MonetizationConfig testMonetizationConfig() => _monetization;

/// Dịch vụ test. [levels] null → levels.json thật. Gắn cấu hình level + unlocks.json + monetization.json thật vào
/// [state] (như main.dart) nếu chưa gắn; [unlocks] = cấu hình mở khoá khác (vd. `UnlockConfig.empty()`);
/// [monetization] = cấu hình vật phẩm / thẻ mùa / IAP khác.
AppServices testServices(
  GameState state, {
  LevelConfig? levels,
  UnlockConfig? unlocks,
  MonetizationConfig? monetization,
}) {
  final config = levels ?? testLevelConfig();
  state.attachLevelConfig(config);
  return AppServices(
    state: state,
    saves: MemorySaveRepository(),
    ads: FakeAdService(state, duration: kTestAdDuration),
    iap: FakeIapService(state, delay: Duration.zero),
    audio: FakeAudioService(state),
    levels: config,
    unlocks: unlocks ?? testUnlockConfig(),
    monetization: monetization ?? testMonetizationConfig(),
  );
}

/// Ghi kết quả thắng [stars]★ (mỗi lượt +[coins] xu) cho các level [ids] (theo thứ tự) như khi chơi thật — trả về
/// delta của lượt cuối. Mở khoá / thiết bị / trang trí khoá theo level cao nhất đã qua (`highestCompletedLevel`).
LevelProgressDelta? winLevels(GameState state, Iterable<int> ids, {int stars = 3, int coins = 320}) {
  LevelProgressDelta? last;
  for (final id in ids) {
    last = state.applyLevelResult(fakeLevelResult(id, won: true, stars: stars, coins: coins));
  }
  return last;
}

/// Kết quả level giả (đủ trường), [won] + [stars] + [coins] tuỳ chọn.
LevelResult fakeLevelResult(int levelId, {required bool won, int stars = 0, int coins = 320}) => LevelResult(
      levelId: levelId,
      won: won,
      stars: won ? stars : 0,
      coins: coins,
      served: 7,
      lost: 2,
      specialsDone: 1,
      bestCombo: 4,
      perfectBakes: 1,
      recipeStars: const {},
      goalValue: won ? 9 : 3,
      fiveStarTreats: 1,
    );

/// Dựng app thật (route của ui) trong khung 1280×720, không tải font mạng. [services] null → [testServices].
/// [initialRoute] mặc định = bản đồ (bỏ màn khởi động); `AppRoutes.initialFor(...)` → như app thật — khi đó không
/// chờ ổn định (cảnh mở đầu / intro ngắn chạy liên tục), người gọi tự `pump`.
Future<void> pumpSugarApp(
  WidgetTester tester,
  GameState state, {
  AppServices? services,
  String initialRoute = AppRoutes.menu,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  LevelMapScreen.giftShownThisSession = false;
  clearMapReveals(); // hàng chờ hoạt cảnh là biến toàn cục: không để sót từ test trước
  await tester.pumpWidget(
    SugarleafApp(
      services: services ?? testServices(state),
      onGenerateRoute: onGenerateUiRoute,
      initialRoute: initialRoute,
      useGoogleFonts: false,
    ),
  );
  if (AppRoutes.isIntro(initialRoute)) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
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
