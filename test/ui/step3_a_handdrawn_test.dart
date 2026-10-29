import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'ui_test_helpers.dart';

/// Các màn đã vẽ lại hoàn toàn bằng SL* (Bước 3, đợt 2 — nhóm A).
const _files = [
  'lib/ui/menu/main_menu_screen.dart',
  'lib/ui/menu/login_gift_dialog.dart',
  'lib/ui/menu/quests_dialog.dart',
  'lib/ui/settings/settings_screen.dart',
  'lib/ui/store/store_screen.dart',
  'lib/ui/day/story_overlay.dart',
];

void main() {
  test('màn nhóm A không còn widget Material phẳng / Material Icons', () {
    final banned = RegExp(
      r'Icons\.|InkWell|Ink\(|Divider|CircleAvatar|CircularProgressIndicator|panelDecoration|Border\.all|Scaffold'
      r'|softShadow|package:flutter/material\.dart',
    );
    for (final path in _files) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        expect(banned.hasMatch(lines[i]), isFalse, reason: '$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  });

  testWidgets('menu: không Scaffold, nút nhãn dán nhiệm vụ/quà chạm ≥ 48 và bấm được', (tester) async {
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await pumpSugarApp(tester, state);

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(SLTopBar), findsOneWidget);
    for (final label in ['Daily quests', 'Daily gift']) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(SLPressable));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48), reason: label);
    }
    await tester.tap(find.text('Daily gift'));
    await tester.pumpAndSettle();
    expect(find.text('Come back tomorrow for more!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('truyện: tắt hiệu ứng thì mũi tên đứng yên (không có animation lặp)', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    MainMenuScreen.giftShownThisSession = true;
    var finished = 0;
    final state = GameState.newGame()
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    await tester.pumpWidget(
      SugarleafApp(
        services: testServices(state),
        useGoogleFonts: false,
        onGenerateRoute: (settings) => fadeRoute(
          settings,
          StoryOverlay(scene: Catalog.storyScene(StorySceneId.hoa1), onFinished: () => finished++),
        ),
      ),
    );
    // pumpAndSettle chỉ xong khi không còn khung hình nào được lên lịch.
    await tester.pumpAndSettle();
    expect(find.text('Tap to continue'), findsOneWidget);
    expect(find.byType(SLSpeechBubble), findsOneWidget);
    expect(find.byType(SLNameTag), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });
}
