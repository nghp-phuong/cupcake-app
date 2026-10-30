import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_art.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';
import 'package:sugarleaf_bakery/ui/intro/short_intro_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/settings/settings_screen.dart';

import 'ui_test_helpers.dart';

/// Ghi lại số lần phát âm thanh (chuông cửa = `success`).
class _Audio implements AudioService {
  int successes = 0;

  @override
  void tap() {}

  @override
  void success() => successes++;

  @override
  void fail() {}
}

GameState _fresh() => GameState.newGame()..setLanguage(LanguagePref.en);

GameState _returning() => _fresh()
  ..markIntroSeen()
  ..claimLogin();

AppServices _services(GameState state, AudioService audio) {
  final base = testServices(state);
  return AppServices(
    state: state,
    saves: MemorySaveRepository(),
    ads: FakeAdService(state, duration: kTestAdDuration),
    iap: FakeIapService(state, delay: Duration.zero),
    audio: audio,
    levels: base.levels,
    unlocks: base.unlocks,
  );
}

/// Cảnh mở đầu / màn chơi chạy liên tục: bước khung thủ công thay cho pumpAndSettle.
Future<void> _frames(WidgetTester tester, Duration total, {Duration step = const Duration(milliseconds: 100)}) async {
  var t = Duration.zero;
  while (t < total) {
    await tester.pump(step);
    t += step;
  }
}

Finder get _skip => find.byKey(const ValueKey('intro-skip'));

/// Độ lệch ngang hiện tại của Mai ở cảnh 3 (0 = đứng trước cửa); null khi chưa tới cảnh 3.
double? _maiDx(WidgetTester tester) {
  final f = find.byKey(const ValueKey('intro-mai'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Transform>(f).transform.getTranslation().x;
}

/// Ảnh của Mai đang có trong cây (tên file, vd. `mai_walk_a`).
Set<String> _maiPoses(WidgetTester tester) => {
      for (final img in tester.widgetList<Image>(
        find.descendant(of: find.byKey(const ValueKey('intro-mai')), matching: find.byType(Image)),
      ))
        if (img.image case ResizeImage(imageProvider: AssetImage(:final assetName)))
          assetName.split('/').last.replaceAll('.webp', ''),
    };

Iterable<CustomPainter> _painters(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<CustomPainter>();

void main() {
  testWidgets('lần đầu: cảnh mở đầu → Bỏ qua → vào thẳng L1, đã đánh dấu introSeen', (tester) async {
    final state = _fresh();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: state.introSeen));
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(LevelMapScreen), findsNothing, reason: 'bản đồ không dựng sẵn bên dưới');
    expect(_skip, findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Chạy vài giây (ảnh nạp / hết chờ, cảnh 1 → 2): nút Bỏ qua vẫn hiện.
    await _frames(tester, const Duration(seconds: 8));
    expect(_skip, findsOneWidget);
    expect(find.text('Grandma\'s cake case still shines like it always did.'), findsOneWidget);
    expect(state.introSeen, isFalse);

    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
    expect(state.introSeen, isTrue);
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(tester.widget<LevelScreen>(find.byType(LevelScreen)).levelId, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cảnh mở đầu chạy hết (~22 giây): bảng "Open" lật, chuông kêu một lần, rồi vào L1', (tester) async {
    final state = _fresh();
    final audio = _Audio();
    await pumpSugarApp(
      tester,
      state,
      services: _services(state, audio),
      initialRoute: AppRoutes.initialFor(introSeen: false),
    );
    // Cảnh 1 có hơi nước + bụi nắng (vẽ code).
    await _frames(tester, const Duration(seconds: 3));
    expect(_painters(tester).whereType<IntroSteamPainter>(), isNotEmpty);
    expect(_painters(tester).whereType<IntroDustPainter>(), isNotEmpty);

    // Tới cảnh cửa tiệm, sau khi Mai đi tới cửa, lật bảng + chuông rung.
    await _frames(tester, const Duration(milliseconds: 14500));
    expect(find.byKey(const ValueKey('intro-sign-text')), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(audio.successes, 1);
    expect(state.introSeen, isFalse);

    await _frames(tester, const Duration(milliseconds: 7500));
    expect(state.introSeen, isTrue);
    expect(audio.successes, 1);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cảnh 3: Mai đi bộ từ mép phải tới cửa (khung bước chân), với tay lúc lật bảng, rồi cười', (tester) async {
    final state = _fresh();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: false));
    // Chờ tới cảnh 3 (Mai xuất hiện, đang ở ngoài bên trái).
    var guard = 0;
    while (_maiDx(tester) == null && guard++ < 300) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _frames(tester, const Duration(milliseconds: 600));
    final dx1 = _maiDx(tester)!;
    expect(dx1, greaterThan(0));
    expect(_maiPoses(tester).intersection({'mai_walk_a', 'mai_walk_b'}), isNotEmpty);
    await _frames(tester, const Duration(milliseconds: 600));
    final dx2 = _maiDx(tester)!;
    expect(dx2, lessThan(dx1), reason: 'Mai đi dần sang trái (từ mép phải tới cửa)');
    // Tới cửa: đứng yên, ảnh với tay (thiếu file → ảnh thường làm dự phòng trong cùng ô).
    guard = 0;
    while ((_maiDx(tester) ?? -1).abs() > 0.01 && guard++ < 60) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _frames(tester, const Duration(milliseconds: 400));
    expect(_maiDx(tester)!.abs(), lessThan(0.01));
    expect(_maiPoses(tester), contains('mai_reach'));
    // Chuông rung → cười.
    await _frames(tester, const Duration(milliseconds: 1500));
    expect(_maiPoses(tester), contains('mai_joy'));
    expect(_maiPoses(tester).intersection({'mai_walk_a', 'mai_walk_b'}), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
  });

  testWidgets('nút Back của máy ở cảnh mở đầu = Bỏ qua', (tester) async {
    final state = _fresh();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: false));
    await _frames(tester, const Duration(seconds: 2));
    await tester.binding.handlePopRoute();
    await _frames(tester, const Duration(seconds: 1));
    expect(state.introSeen, isTrue);
    expect(find.byType(LevelScreen), findsOneWidget);
  });

  testWidgets('lần sau: intro ngắn tự sang bản đồ sau 4 giây', (tester) async {
    final state = _returning();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: state.introSeen));
    expect(find.byType(ShortIntroScreen), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.text('Tap to enter the bakery'), findsOneWidget);
    expect(find.text('Sugarleaf Bakery'), findsWidgets);

    await _frames(tester, const Duration(seconds: 3));
    expect(find.byType(LevelMapScreen), findsNothing);
    await _frames(tester, const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(ShortIntroScreen), findsNothing);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    // Bản đồ là route gốc (Back không quay lại intro).
    expect(navigator(tester).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lần sau: chạm bất kỳ ở intro ngắn → bản đồ ngay', (tester) async {
    final state = _returning();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: true));
    await _frames(tester, const Duration(milliseconds: 600));
    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(find.byType(ShortIntroScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lần đầu: chưa nhận quà thì hộp quà chỉ hiện ở bản đồ, không hiện đè cảnh mở đầu', (tester) async {
    final state = _fresh();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: false));
    await _frames(tester, const Duration(seconds: 3));
    expect(find.text('Claim'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
  });

  testWidgets('Cài đặt: Xem lại cảnh mở đầu → bỏ qua → quay về Cài đặt', (tester) async {
    final state = _returning();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-replay-intro')));
    await _frames(tester, const Duration(seconds: 2));
    expect(find.byType(IntroScreen), findsOneWidget);

    await tester.tap(_skip);
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(LevelScreen), findsNothing);
    expect(state.introSeen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cài đặt: Xem lại cảnh mở đầu chạy hết cũng quay về Cài đặt', (tester) async {
    final state = _returning();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-replay-intro')));
    await _frames(tester, const Duration(seconds: 25));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('Cài đặt: Hướng dẫn lại → hướng dẫn L1–L3 hiện lại + toast xác nhận', (tester) async {
    final state = _returning()
      ..markTutorialDone(TutorialIds.basics)
      ..markTutorialDone(TutorialIds.combo)
      ..markTutorialDone(TutorialIds.patience);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.text('Replay opening'), findsOneWidget);
    expect(find.text('Replay tutorials'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-replay-tutorials')));
    await tester.pump();
    expect(state.isTutorialDone(TutorialIds.basics), isFalse);
    expect(state.isTutorialDone(TutorialIds.combo), isFalse);
    expect(state.isTutorialDone(TutorialIds.patience), isFalse);
    expect(find.text('Tutorials will show again in Levels 1–3'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('giảm chuyển động: cảnh mở đầu ngắn hơn, không hạt / không lia, chuông vẫn kêu', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = _fresh();
    final audio = _Audio();
    await pumpSugarApp(
      tester,
      state,
      services: _services(state, audio),
      initialRoute: AppRoutes.initialFor(introSeen: false),
    );
    await _frames(tester, const Duration(seconds: 2));
    expect(_painters(tester).whereType<IntroSteamPainter>(), isEmpty);
    expect(_painters(tester).whereType<IntroDustPainter>(), isEmpty);
    expect(_painters(tester).whereType<IntroSparklePainter>(), isEmpty);

    final total = IntroScreen.reducedSceneSeconds.reduce((a, b) => a + b);
    expect(total, lessThan(IntroScreen.sceneSeconds.reduce((a, b) => a + b)));
    // Cảnh 3: Mai đứng sẵn trước cửa (không đi bộ), chỉ đổi ảnh; không có khung bước chân.
    var seenMai = false;
    var waited = 2000;
    final end = (total * 1000).round() + IntroScreen.preloadWait.inMilliseconds;
    while (waited < end) {
      await tester.pump(const Duration(milliseconds: 100));
      waited += 100;
      final dx = _maiDx(tester);
      if (dx == null) continue;
      seenMai = true;
      expect(dx, 0);
      expect(_maiPoses(tester), isNot(contains('mai_walk_a')));
    }
    expect(seenMai, isTrue);
    // Hết thời lượng rút gọn (+ chờ nạp ảnh tối đa) → đã vào L1.
    await _frames(tester, const Duration(milliseconds: 300));
    expect(audio.successes, 1);
    expect(state.introSeen, isTrue);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('giảm chuyển động: intro ngắn đứng yên, vẫn tự sang bản đồ', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = _returning();
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: true));
    expect(_painters(tester).whereType<IntroSparklePainter>(), isEmpty);
    await _frames(tester, const Duration(milliseconds: 4200));
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen), findsOneWidget);
  });

  testWidgets('tiếng Việt: phụ đề + chữ "Mở cửa" + Bỏ qua', (tester) async {
    final state = GameState.newGame()..setLanguage(LanguagePref.vi);
    await pumpSugarApp(tester, state, initialRoute: AppRoutes.initialFor(introSeen: false));
    await _frames(tester, const Duration(seconds: 2));
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Một buổi sáng ở thị trấn ven biển…'), findsOneWidget);
    await _frames(tester, const Duration(seconds: 14));
    expect(find.text('Mở cửa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
  });
}
