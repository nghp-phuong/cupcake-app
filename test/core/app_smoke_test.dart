import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/art/item_art.dart';
import 'package:sugarleaf_bakery/core/art/shop_art.dart';
import 'package:sugarleaf_bakery/core/constants.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/level/level_config_loader.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

AppServices _services(GameState state) {
  final saves = MemorySaveRepository();
  return AppServices(
    state: state,
    saves: saves,
    ads: FakeAdService(state, duration: const Duration(milliseconds: 1200)),
    iap: FakeIapService(state, delay: Duration.zero),
    audio: FakeAudioService(state),
    levels: LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync()),
  );
}

Size? _innerSize;
String? _title;

Route<dynamic>? _probeRoute(RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        _innerSize = MediaQuery.of(context).size;
        _title = AppLocalizations.of(context).appTitle;
        final l = AppLocalizations.of(context);
        return Scaffold(
          body: Column(
            children: [
              Text(l.recipeName(RecipeId.cupcakeVanilla)),
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AppScope.read(ctx).ads.showRewarded(ctx, AdPlacement.freeGem),
                  child: const Text('ad'),
                ),
              ),
            ],
          ),
        );
      },
    );

void main() {
  testWidgets('SugarleafApp dựng được, khung 1280×720, đổi ngôn ngữ', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = GameState.newGame();
    await tester.pumpWidget(SugarleafApp(services: _services(state), onGenerateRoute: _probeRoute, useGoogleFonts: false));
    await tester.pumpAndSettle();
    expect(_innerSize, kRefSize);
    expect(_title, 'Sugarleaf Bakery');
    expect(find.text('Vanilla cupcake'), findsOneWidget);

    state.setLanguage(LanguagePref.vi);
    await tester.pumpAndSettle();
    expect(find.text('Cupcake vani'), findsOneWidget);
  });

  testWidgets('MaterialApp chỉ dựng lại khi đổi ngôn ngữ', (tester) async {
    final state = GameState.newGame();
    await tester.pumpWidget(SugarleafApp(services: _services(state), onGenerateRoute: _probeRoute, useGoogleFonts: false));
    await tester.pumpAndSettle();
    final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    state.addCoins(10);
    state.addGems(1);
    await tester.pump();
    expect(identical(tester.widget<MaterialApp>(find.byType(MaterialApp)), before), isTrue);
    state.setLanguage(LanguagePref.vi);
    await tester.pumpAndSettle();
    final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(identical(after, before), isFalse);
    expect(after.locale, const Locale('vi'));
  });

  testWidgets('quảng cáo giả lập tự đóng và ghi đếm', (tester) async {
    final state = GameState.newGame();
    await tester.pumpWidget(SugarleafApp(services: _services(state), onGenerateRoute: _probeRoute, useGoogleFonts: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ad'));
    await tester.pump();
    expect(find.text('Ad (simulated)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ad (simulated)'), findsNothing);
    expect(state.rewardedToday, 1);
  });

  testWidgets('ngăn xếp khởi đầu: intro / intro ngắn / `/` một route; liên kết sâu web → bản đồ + route đó', (tester) async {
    Route<dynamic>? named(RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route ${settings.name}')),
        );
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    Future<NavigatorState> open(String browser, String initial) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = browser;
      // Key mới mỗi lần → MaterialApp dựng lại từ đầu (ngăn xếp khởi đầu chỉ tính một lần).
      await tester.pumpWidget(SugarleafApp(
        key: UniqueKey(),
        services: _services(GameState.newGame()),
        onGenerateRoute: named,
        useGoogleFonts: false,
        initialRoute: initial,
      ));
      await tester.pumpAndSettle();
      return tester.state<NavigatorState>(find.byType(Navigator).first);
    }

    for (final (browser, initial, shown) in [
      ('/', AppRoutes.intro, AppRoutes.intro),
      ('/', AppRoutes.shortIntro, AppRoutes.shortIntro),
      (AppRoutes.intro, AppRoutes.shortIntro, AppRoutes.intro),
      (AppRoutes.shortIntro, AppRoutes.intro, AppRoutes.shortIntro),
      (AppRoutes.menu, AppRoutes.shortIntro, AppRoutes.shortIntro),
    ]) {
      final nav = await open(browser, initial);
      expect(find.text('route $shown'), findsOneWidget, reason: '$browser / $initial');
      expect(nav.canPop(), isFalse, reason: '$browser / $initial: một route duy nhất');
    }

    // Trình duyệt mở thẳng `/settings`: bản đồ bên dưới, Back về bản đồ.
    final nav = await open(AppRoutes.settings, AppRoutes.shortIntro);
    expect(find.text('route ${AppRoutes.settings}'), findsOneWidget);
    expect(nav.canPop(), isTrue);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('route ${AppRoutes.menu}'), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });

  testWidgets('màn dọc hiện lời nhắc xoay máy', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        SugarleafApp(services: _services(GameState.newGame()), onGenerateRoute: _probeRoute, useGoogleFonts: false));
    await tester.pumpAndSettle();
    expect(find.text('Please turn your device sideways'), findsOneWidget);
  });

  test('art vẽ được mọi biến thể không lỗi', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const r = Rect.fromLTWH(0, 0, 200, 200);
    for (final id in RecipeId.values) {
      CakeArt.paint(canvas, r, CakeVisual.recipe(id, toppings: {ToppingId.sprinkles: 2, ToppingId.candle: 1}));
      final base = CakeVisual.recipe(id);
      CakeArt.paint(canvas, r, base.copyWith(batterFill: 0));
      CakeArt.paint(canvas, r, CakeVisual(mould: base.mould, batter: base.batter, baked: 0));
      CakeArt.paint(canvas, r, CakeVisual(mould: base.mould, batter: base.batter, baked: 2, frosting: base.frosting, frostCoverage: 0.3));
    }
    for (final t in ToppingId.values) {
      ItemArt.paintTopping(canvas, r, t);
    }
    for (final m in MouldType.values) {
      ItemArt.paintMould(canvas, r, m);
    }
    for (final b in BoxType.values) {
      ItemArt.paintBox(canvas, r, b);
      ItemArt.paintBox(canvas, r, b, open: true);
    }
    for (final f in FrostingId.values) {
      ItemArt.paintFrostingSwatch(canvas, r, f);
    }
    ItemArt.coin(canvas, r);
    ItemArt.gem(canvas, r);
    ItemArt.star(canvas, r);
    ItemArt.star(canvas, r, filled: false);
    for (final kind in CustomerKind.values) {
      for (var seed = 0; seed < 10; seed++) {
        final friend = kind == CustomerKind.friend ? FriendId.values[seed % 3] : null;
        for (final mood in CustomerMood.values) {
          CustomerArt.paint(canvas, r, Customer(kind: kind, friend: friend, appearanceSeed: seed), mood: mood);
        }
      }
    }
    for (final s in Speaker.values) {
      CustomerArt.paintSpeaker(canvas, r, s);
    }
    ShopArt.paint(canvas, kRefSize, {for (final s in DecorSlot.values) s: null});
    ShopArt.paint(canvas, const Size(640, 360), {
      DecorSlot.wallpaper: DecorId.wallpaperStripes,
      DecorSlot.floor: DecorId.floorCheckered,
      DecorSlot.counter: DecorId.counterFlowers,
      DecorSlot.window: DecorId.windowCurtains,
      DecorSlot.plant: DecorId.plantFern,
    });
    ShopArt.paint(canvas, kRefSize, {
      DecorSlot.wallpaper: DecorId.wallpaperFloral,
      DecorSlot.floor: DecorId.floorHerringbone,
      DecorSlot.counter: DecorId.counterCakeStand,
      DecorSlot.window: DecorId.windowSeaView,
      DecorSlot.plant: DecorId.plantLemonTree,
    });
    recorder.endRecording().dispose();
  });
}
