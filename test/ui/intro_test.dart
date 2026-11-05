import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_art.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';

import 'city_test_helpers.dart';

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

/// Cảnh mở đầu / màn chơi chạy liên tục: bước khung thủ công thay cho pumpAndSettle.
Future<void> _frames(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 100),
}) async {
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
    find.descendant(
      of: find.byKey(const ValueKey('intro-mai')),
      matching: find.byType(Image),
    ),
  ))
    if (img.image case ResizeImage(imageProvider: AssetImage(:final assetName)))
      assetName.split('/').last.replaceAll('.webp', ''),
};

Iterable<CustomPainter> _painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<CustomPainter>();

void main() {
  testWidgets(
    'lần đầu: cảnh mở đầu → Bỏ qua → về phố ("/"), đã đánh dấu introSeen',
    (tester) async {
      final services = await cityServices();
      final game = services.game;
      expect(game.introSeen, isFalse);
      await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
      expect(find.byType(IntroScreen), findsOneWidget);
      expect(
        find.byKey(kTownStubKey),
        findsNothing,
        reason: 'phố không dựng sẵn bên dưới',
      );
      expect(_skip, findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Chạy vài giây (ảnh nạp / hết chờ, cảnh 1 → 2): nút Bỏ qua vẫn hiện.
      await _frames(tester, const Duration(seconds: 8));
      expect(_skip, findsOneWidget);
      expect(
        find.text('Grandma\'s cake case still shines like it always did.'),
        findsOneWidget,
      );
      expect(game.introSeen, isFalse);

      await tester.tap(_skip);
      await _frames(tester, const Duration(seconds: 1));
      expect(game.introSeen, isTrue);
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byKey(kTownStubKey), findsOneWidget);
      expect(
        navigator(tester).canPop(),
        isFalse,
        reason: 'phố thay chỗ cảnh mở đầu, Back không quay lại intro',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cảnh mở đầu chạy hết (~22 giây): bảng "Open" lật, chuông kêu một lần, rồi về phố',
    (tester) async {
      final audio = _Audio();
      final services = await cityServices(audio: audio);
      final game = services.game;
      await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
      // Cảnh 1 có hơi nước + bụi nắng (vẽ code).
      await _frames(tester, const Duration(seconds: 3));
      expect(_painters(tester).whereType<IntroSteamPainter>(), isNotEmpty);
      expect(_painters(tester).whereType<IntroDustPainter>(), isNotEmpty);

      // Tới cảnh cửa tiệm, sau khi Mai đi tới cửa, lật bảng + chuông rung.
      await _frames(tester, const Duration(milliseconds: 14500));
      expect(find.byKey(const ValueKey('intro-sign-text')), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(audio.successes, 1);
      expect(game.introSeen, isFalse);

      await _frames(tester, const Duration(milliseconds: 7500));
      expect(game.introSeen, isTrue);
      expect(audio.successes, 1);
      expect(find.byKey(kTownStubKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cảnh 3: Mai đi bộ từ mép phải tới cửa (khung bước chân), với tay lúc lật bảng, rồi cười',
    (tester) async {
      await pumpCityApp(
        tester,
        await cityServices(),
        initialRoute: AppRoutes.intro,
      );
      // Chờ tới cảnh 3 (Mai xuất hiện, đang ở ngoài bên trái).
      var guard = 0;
      while (_maiDx(tester) == null && guard++ < 300) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _frames(tester, const Duration(milliseconds: 600));
      final dx1 = _maiDx(tester)!;
      expect(dx1, greaterThan(0));
      expect(
        _maiPoses(tester).intersection({'mai_walk_a', 'mai_walk_b'}),
        isNotEmpty,
      );
      await _frames(tester, const Duration(milliseconds: 600));
      final dx2 = _maiDx(tester)!;
      expect(
        dx2,
        lessThan(dx1),
        reason: 'Mai đi dần sang trái (từ mép phải tới cửa)',
      );
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
      expect(
        _maiPoses(tester).intersection({'mai_walk_a', 'mai_walk_b'}),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(_skip);
      await _frames(tester, const Duration(seconds: 1));
    },
  );

  testWidgets('nút Back của máy ở cảnh mở đầu = Bỏ qua', (tester) async {
    final services = await cityServices();
    await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
    await _frames(tester, const Duration(seconds: 2));
    await tester.binding.handlePopRoute();
    await _frames(tester, const Duration(seconds: 1));
    expect(services.game.introSeen, isTrue);
    expect(find.byKey(kTownStubKey), findsOneWidget);
  });

  testWidgets(
    'giảm chuyển động: cảnh mở đầu ngắn hơn, không hạt / không lia, chuông vẫn kêu',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final audio = _Audio();
      final services = await cityServices(audio: audio);
      await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
      await _frames(tester, const Duration(seconds: 2));
      expect(_painters(tester).whereType<IntroSteamPainter>(), isEmpty);
      expect(_painters(tester).whereType<IntroDustPainter>(), isEmpty);
      expect(_painters(tester).whereType<IntroSparklePainter>(), isEmpty);

      final total = IntroScreen.reducedSceneSeconds.reduce((a, b) => a + b);
      expect(total, lessThan(IntroScreen.sceneSeconds.reduce((a, b) => a + b)));
      // Cảnh 3: Mai đứng sẵn trước cửa (không đi bộ), chỉ đổi ảnh; không có khung bước chân.
      var seenMai = false;
      var waited = 2000;
      final end =
          (total * 1000).round() + IntroScreen.preloadWait.inMilliseconds;
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
      // Hết thời lượng rút gọn (+ chờ nạp ảnh tối đa) → đã về phố.
      await _frames(tester, const Duration(milliseconds: 300));
      expect(audio.successes, 1);
      expect(services.game.introSeen, isTrue);
      expect(find.byKey(kTownStubKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tiếng Việt: phụ đề + chữ "Mở cửa" + Bỏ qua', (tester) async {
    await pumpCityApp(
      tester,
      await cityServices(language: LanguagePref.vi),
      initialRoute: AppRoutes.intro,
    );
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
