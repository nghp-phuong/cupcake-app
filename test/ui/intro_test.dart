import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_art.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_stage.dart';

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

/// Lớp 3D giả (test không dựng thermion): giữ [host], đếm số lần gỡ; [gate] (nếu có) giữ việc gỡ chưa xong.
class _FakeStage {
  IntroStageHost? host;
  int builds = 0;
  int releases = 0;
  Completer<void>? gate;

  Widget build(IntroStageHost h) {
    builds++;
    host = h;
    h.release = () {
      releases++;
      return gate?.future ?? Future<void>.value();
    };
    return const SizedBox.expand(key: ValueKey('fake-stage'));
  }
}

_FakeStage _useFakeStage() {
  final fake = _FakeStage();
  IntroScreen.stageBuilder = fake.build;
  addTearDown(() => IntroScreen.stageBuilder = null);
  return fake;
}

/// Cảnh mở đầu chạy liên tục: bước khung thủ công thay cho pumpAndSettle.
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

double _coverOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('intro-cover'))).opacity;

Iterable<CustomPainter> _painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<CustomPainter>();

const _line1 = 'One morning in a little seaside town…';
const _line2 = 'Grandma\'s little bakery is still right where it was.';
const _line3 = 'Mai is home — Sugarleaf opens its doors again!';

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

      // Không có lớp 3D: chạy ngay trên nền giấy, phụ đề theo cảnh.
      await _frames(tester, const Duration(seconds: 2));
      expect(find.text(_line1), findsOneWidget);
      await _frames(tester, const Duration(seconds: 5));
      expect(find.text(_line2), findsOneWidget);
      expect(_skip, findsOneWidget);
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
    'chạy hết (~18 giây): phụ đề cảnh 3, chuông kêu một lần, logo, rồi về phố',
    (tester) async {
      final audio = _Audio();
      final services = await cityServices(audio: audio);
      final game = services.game;
      await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
      await _frames(tester, const Duration(seconds: 12));
      expect(find.text(_line3), findsOneWidget);
      expect(audio.successes, 1);
      expect(find.byType(IntroLogo), findsNothing);

      await _frames(tester, const Duration(seconds: 4));
      expect(find.byType(IntroLogo), findsOneWidget);
      expect(_painters(tester).whereType<IntroSparklePainter>(), isNotEmpty);
      expect(game.introSeen, isFalse);

      await _frames(tester, const Duration(seconds: 3));
      expect(game.introSeen, isTrue);
      expect(audio.successes, 1);
      expect(find.byKey(kTownStubKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lớp 3D: chờ dựng xong mới chạy ("Đang mở cửa…" khi lâu), bỏ nền giấy, đồng hồ + mốc cảnh cho lớp 3D',
    (tester) async {
      final fake = _useFakeStage();
      await pumpCityApp(tester, await cityServices(), initialRoute: AppRoutes.intro);
      expect(find.byKey(const ValueKey('fake-stage')), findsOneWidget);
      final host = fake.host!;
      expect(host.starts, [0, 5, 10, 15, 18]);
      expect(host.reduceMotion, isFalse);
      expect(_coverOpacity(tester), 1);

      await _frames(tester, const Duration(milliseconds: 1500));
      expect(find.text('Opening the door…'), findsOneWidget);
      expect(find.text(_line1), findsNothing);
      expect(host.time.value, 0, reason: 'chưa dựng xong thì đồng hồ chưa chạy');

      host.ready();
      await _frames(tester, const Duration(seconds: 2));
      expect(find.text('Opening the door…'), findsNothing);
      expect(find.text(_line1), findsOneWidget);
      expect(_coverOpacity(tester), 0);
      expect(host.time.value, closeTo(2, 0.15));
      expect(fake.releases, 0);
      expect(tester.takeException(), isNull);

      await tester.tap(_skip);
      await _frames(tester, const Duration(seconds: 1));
      expect(fake.releases, 1);
      expect(find.byKey(kTownStubKey), findsOneWidget);
    },
  );

  testWidgets('lớp 3D: hết cảnh / bỏ qua → chờ gỡ viewer xong rồi mới sang phố', (tester) async {
    final fake = _useFakeStage()..gate = Completer<void>();
    final services = await cityServices();
    await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
    fake.host!.ready();
    await _frames(tester, const Duration(seconds: 1));

    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
    expect(services.game.introSeen, isTrue);
    expect(fake.releases, 1);
    expect(_coverOpacity(tester), 1, reason: 'nền giấy che lớp 3D đang gỡ');
    expect(find.byKey(kTownStubKey), findsNothing);

    fake.gate!.complete();
    await _frames(tester, const Duration(seconds: 1));
    expect(find.byKey(kTownStubKey), findsOneWidget);
    expect(fake.releases, 1);
  });

  testWidgets('lớp 3D gỡ quá lâu → vẫn sang phố sau releaseWait', (tester) async {
    final fake = _useFakeStage()..gate = Completer<void>();
    await pumpCityApp(tester, await cityServices(), initialRoute: AppRoutes.intro);
    fake.host!.ready();
    await tester.pump();
    await tester.tap(_skip);
    await _frames(tester, IntroScreen.releaseWait + const Duration(seconds: 1));
    expect(find.byKey(kTownStubKey), findsOneWidget);
  });

  testWidgets(
    'đổi cỡ cửa sổ qua mốc khung rộng (RefFrame dựng lại cây): intro không chạy lại, không tạo / gỡ lớp 3D',
    (tester) async {
      final fake = _useFakeStage();
      await pumpCityApp(tester, await cityServices(), initialRoute: AppRoutes.intro);
      fake.host!.ready();
      await _frames(tester, const Duration(seconds: 6));
      expect(find.text(_line2), findsOneWidget);
      final before = fake.host!.time.value;

      tester.view.physicalSize = const Size(1600, 720);
      await _frames(tester, const Duration(milliseconds: 500));
      tester.view.physicalSize = const Size(1280, 720);
      await _frames(tester, const Duration(milliseconds: 500));
      expect(fake.builds, 1, reason: 'không dựng lớp 3D (viewer) thứ hai');
      expect(fake.releases, 0);
      expect(fake.host!.time.value, greaterThan(before));
      expect(find.text(_line2), findsOneWidget, reason: 'vẫn ở cảnh 2, không quay về đầu');
      expect(_coverOpacity(tester), 0);
      expect(tester.takeException(), isNull);
      await tester.tap(_skip);
      await _frames(tester, const Duration(seconds: 1));
      expect(fake.releases, 1);
    },
  );

  testWidgets('lớp 3D hỏng → chạy trên nền giấy', (tester) async {
    final fake = _useFakeStage();
    await pumpCityApp(tester, await cityServices(), initialRoute: AppRoutes.intro);
    fake.host!.failed();
    await _frames(tester, const Duration(seconds: 2));
    expect(find.text(_line1), findsOneWidget);
    expect(_coverOpacity(tester), 1);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
    expect(find.byKey(kTownStubKey), findsOneWidget);
  });

  testWidgets('lớp 3D không xong sau stageWait → chạy trên nền giấy; xong muộn thì hiện', (tester) async {
    final fake = _useFakeStage();
    await pumpCityApp(tester, await cityServices(), initialRoute: AppRoutes.intro);
    await _frames(tester, IntroScreen.stageWait + const Duration(seconds: 2), step: const Duration(milliseconds: 500));
    expect(find.text(_line1), findsOneWidget);
    expect(_coverOpacity(tester), 1);
    fake.host!.ready();
    await _frames(tester, const Duration(milliseconds: 500));
    expect(_coverOpacity(tester), 0);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
    expect(find.byKey(kTownStubKey), findsOneWidget);
  });

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
    'giảm chuyển động: cảnh mở đầu ngắn hơn, không lấp lánh, chuông vẫn kêu, lớp 3D biết để cắt cảnh',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final fake = _useFakeStage();
      final audio = _Audio();
      final services = await cityServices(audio: audio);
      await pumpCityApp(tester, services, initialRoute: AppRoutes.intro);
      final host = fake.host!;
      expect(host.reduceMotion, isTrue);
      final total = IntroScreen.reducedSceneSeconds.reduce((a, b) => a + b);
      expect(total, lessThan(IntroScreen.sceneSeconds.reduce((a, b) => a + b)));
      expect(host.starts.last, total);
      host.ready();

      var sawLogo = false;
      var waited = 0;
      while (waited < (total * 1000).round() - 200) {
        await tester.pump(const Duration(milliseconds: 100));
        waited += 100;
        expect(_painters(tester).whereType<IntroSparklePainter>(), isEmpty);
        if (find.byType(IntroLogo).evaluate().isNotEmpty) sawLogo = true;
      }
      expect(sawLogo, isTrue);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(audio.successes, 1);
      expect(services.game.introSeen, isTrue);
      expect(find.byKey(kTownStubKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tiếng Việt: phụ đề + Bỏ qua', (tester) async {
    await pumpCityApp(
      tester,
      await cityServices(language: LanguagePref.vi),
      initialRoute: AppRoutes.intro,
    );
    await _frames(tester, const Duration(seconds: 2));
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Một buổi sáng ở thị trấn ven biển…'), findsOneWidget);
    await _frames(tester, const Duration(seconds: 10));
    expect(find.text('Mai đã về — tiệm Sugarleaf lại mở cửa!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(_skip);
    await _frames(tester, const Duration(seconds: 1));
  });
}
