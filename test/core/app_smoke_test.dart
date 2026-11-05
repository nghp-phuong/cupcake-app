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
import 'package:sugarleaf_bakery/core/debug_params.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

/// Dịch vụ như main.dart (save trong bộ nhớ, quảng cáo giả kiểu vẽ tay).
Future<AppServices> _services(WidgetTester tester) async {
  final store = (await tester.runAsync(
    () => CitySaveStore.load(MemoryCitySaveRepository()),
  ))!;
  final game = store.game;
  return AppServices(
    game: game,
    store: store,
    ads: FakeAdService(
      game,
      duration: const Duration(milliseconds: 1200),
      presenter: showSLSimulatedAd,
    ),
    audio: FakeAudioService(game.settings),
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
              onPressed: () => AppScope.read(
                ctx,
              ).ads.showRewarded(ctx, AdPlacement.doubleCoins),
              child: const Text('ad'),
            ),
          ),
        ],
      ),
    );
  },
);

void main() {
  testWidgets(
    'SugarleafApp dựng được, không bọc RefFrame toàn app, ngôn ngữ theo cài đặt',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final services = await _services(tester);
      await tester.pumpWidget(
        SugarleafApp(
          services: services,
          onGenerateRoute: _probeRoute,
          useGoogleFonts: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _innerSize,
        const Size(1600, 900),
      ); // cả màn, không phải khung 1280×720
      expect(find.byType(RefFrame), findsNothing);
      expect(_title, 'Sugarleaf Bakery');
      expect(find.text('Vanilla cupcake'), findsOneWidget);
      final ctx = tester.element(find.text('Vanilla cupcake'));
      expect(identical(AppScope.of(ctx), services), isTrue);
      expect(identical(AppScope.read(ctx).game, services.game), isTrue);

      services.game.settings.setLanguage(LanguagePref.vi);
      await tester.pumpAndSettle();
      expect(find.text('Cupcake vani'), findsOneWidget);
    },
  );

  testWidgets('MaterialApp chỉ dựng lại khi đổi ngôn ngữ', (tester) async {
    final services = await _services(tester);
    final game = services.game;
    await tester.pumpWidget(
      SugarleafApp(
        services: services,
        onGenerateRoute: _probeRoute,
        useGoogleFonts: false,
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    game.wallet.addXp(10);
    game.settings.setSound(false);
    game.markIntroSeen();
    await tester.pump();
    expect(
      identical(tester.widget<MaterialApp>(find.byType(MaterialApp)), before),
      isTrue,
    );
    game.settings.setLanguage(LanguagePref.vi);
    await tester.pumpAndSettle();
    final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(identical(after, before), isFalse);
    expect(after.locale, const Locale('vi'));
  });

  testWidgets('forcedLocale (lang=) thắng cài đặt, không đổi cài đặt', (
    tester,
  ) async {
    final services = await _services(tester);
    services.game.settings.setLanguage(LanguagePref.en);
    await tester.pumpWidget(
      SugarleafApp(
        services: services,
        onGenerateRoute: _probeRoute,
        useGoogleFonts: false,
        forcedLocale: CityDebugParams.fromQuery(const {'lang': 'vi'}).locale,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cupcake vani'), findsOneWidget);
    services.game.settings.setLanguage(LanguagePref.system);
    await tester.pumpAndSettle();
    expect(find.text('Cupcake vani'), findsOneWidget);
    expect(services.game.settings.language, LanguagePref.system);
  });

  testWidgets('quảng cáo giả lập (vẽ tay) tự đóng và ghi đếm vào CityGame', (
    tester,
  ) async {
    final services = await _services(tester);
    await tester.pumpWidget(
      SugarleafApp(
        services: services,
        onGenerateRoute: _probeRoute,
        useGoogleFonts: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ad'));
    await tester.pump();
    expect(find.text('Ad (simulated)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ad (simulated)'), findsNothing);
    expect(services.game.rewardedToday, 1);
    expect(services.game.canShowRewarded, isTrue);
  });

  testWidgets(
    'ngăn xếp khởi đầu: luôn đúng một route initialRoute, bỏ qua route nền tảng gửi',
    (tester) async {
      Route<dynamic>? named(RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route ${settings.name}')),
      );
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final services = await _services(tester);

      for (final (platform, initial) in [
        ('/', AppRoutes.intro),
        ('/', AppRoutes.town),
        (AppRoutes.intro, AppRoutes.town),
        ('/?save=memory&lang=vi', AppRoutes.town),
        ('/settings', AppRoutes.intro),
        ('/level', AppRoutes.town),
      ]) {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = platform;
        // Key mới mỗi lần → MaterialApp dựng lại từ đầu (ngăn xếp khởi đầu chỉ tính một lần).
        await tester.pumpWidget(
          SugarleafApp(
            key: UniqueKey(),
            services: services,
            onGenerateRoute: named,
            useGoogleFonts: false,
            initialRoute: initial,
          ),
        );
        await tester.pumpAndSettle();
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        expect(
          find.text('route $initial'),
          findsOneWidget,
          reason: '$platform / $initial',
        );
        expect(
          nav.canPop(),
          isFalse,
          reason: '$platform / $initial: một route duy nhất',
        );
      }
    },
  );

  test('AppRoutes.initialFor', () {
    expect(AppRoutes.town, '/');
    expect(AppRoutes.intro, '/intro');
    expect(AppRoutes.initialFor(introSeen: false), AppRoutes.intro);
    expect(AppRoutes.initialFor(introSeen: true), AppRoutes.town);
  });

  test('art vẽ được mọi biến thể không lỗi', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const r = Rect.fromLTWH(0, 0, 200, 200);
    for (final id in RecipeId.values) {
      CakeArt.paint(
        canvas,
        r,
        CakeVisual.recipe(
          id,
          toppings: {ToppingId.sprinkles: 2, ToppingId.candle: 1},
        ),
      );
      final base = CakeVisual.recipe(id);
      CakeArt.paint(canvas, r, base.copyWith(batterFill: 0));
      CakeArt.paint(
        canvas,
        r,
        CakeVisual(mould: base.mould, batter: base.batter, baked: 0),
      );
      CakeArt.paint(
        canvas,
        r,
        CakeVisual(
          mould: base.mould,
          batter: base.batter,
          baked: 2,
          frosting: base.frosting,
          frostCoverage: 0.3,
        ),
      );
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
        final friend = kind == CustomerKind.friend
            ? FriendId.values[seed % 3]
            : null;
        for (final mood in CustomerMood.values) {
          CustomerArt.paint(
            canvas,
            r,
            Customer(kind: kind, friend: friend, appearanceSeed: seed),
            mood: mood,
          );
        }
      }
    }
    for (final s in Speaker.values) {
      CustomerArt.paintSpeaker(canvas, r, s);
    }
    ShopArt.paint(canvas, kRefSize, {
      for (final s in DecorSlot.values) s: null,
    });
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
