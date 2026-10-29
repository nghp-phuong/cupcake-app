// Công cụ chụp "mô phỏng game": dựng các màn hình THẬT của lib/ui ở khung 1280×720 với dữ liệu giả lập,
// chờ ảnh nhân vật vẽ tay nạp xong rồi xuất PNG vào docs/design/screens/.
//
// Không thuộc `flutter test` mặc định. Chạy lại (vd. khi có thêm ảnh nhân vật):
//   flutter test tool/screens/render_screens_test.dart
//
// Font: nạp font đóng gói của app từ assets/fonts (Fredoka, Baloo 2, Nunito). Thư mục xuất đổi được bằng
// --dart-define=SHOTS_OUT=<thư mục>. Khi nạp ảnh vẽ tay, chạy cả file đôi khi treo ở cảnh thứ 6; chạy riêng từng cảnh
// bằng --plain-name "<số cảnh>" (vd. "06 bạn quen", "11–16") thì ổn.
// Khách được chọn bằng cách dò seed của `DayController` sao cho ai cũng có ảnh vẽ tay (file có trong
// assets/characters/) và mỗi ảnh một khách khác nhau — thêm ảnh mới thì chạy lại là tự đổi khách.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/art/characters/character_sprites.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/day_controller.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/day_summary.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/logic/frost.dart';
import 'package:sugarleaf_bakery/game/stations/bake_station.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/day/day_screen.dart';
import 'package:sugarleaf_bakery/ui/decor/decor_screen.dart';
import 'package:sugarleaf_bakery/ui/menu/main_menu_screen.dart';
import 'package:sugarleaf_bakery/ui/menu/quests_dialog.dart';
import 'package:sugarleaf_bakery/ui/recipes/recipe_book_screen.dart';
import 'package:sugarleaf_bakery/ui/settings/settings_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/summary/day_summary_screen.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

/// Thư mục xuất ảnh; đổi bằng `--dart-define=SHOTS_OUT=<thư mục>` (vd. docs/design/ui-after).
const _outDir = String.fromEnvironment('SHOTS_OUT', defaultValue: 'docs/design/screens');
const _vi = Locale('vi');
const _en = Locale('en');

/// Font đóng gói trong assets/fonts (khai báo ở mục `fonts:` của pubspec) — nạp dưới đúng tên họ font của app.
const _fontFiles = <(String, List<String>)>[
  ('Nunito', ['Nunito-Regular', 'Nunito-SemiBold', 'Nunito-Bold', 'Nunito-ExtraBold']),
  ('Fredoka', ['Fredoka-Medium', 'Fredoka-SemiBold', 'Fredoka-Bold']),
  ('Baloo2', ['Baloo2-SemiBold', 'Baloo2-Bold', 'Baloo2-ExtraBold']),
];

/// Giờ "hôm nay" cố định → nhiệm vụ ngày, quà đăng nhập ra giống nhau mỗi lần chạy.
DateTime _now = DateTime(2026, 10, 28, 10);
DateTime _clock() => _now;

final _notes = <String>[];
final _written = <String>[];

/// id ảnh nhân vật đã xuất hiện ở các ảnh trước (ưu tiên khách mới cho ảnh sau).
final _used = <String>{};

final _shotKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== Đã xuất ${_written.length} ảnh vào $_outDir ===\n${_written.map((n) => '  $n.png').join('\n')}');
    if (_notes.isNotEmpty) {
      // ignore: avoid_print
      print('Ghi chú:\n${_notes.map((n) => '  - $n').join('\n')}');
    }
  });

  testWidgets('01 menu chính (vi + en)', (tester) async {
    await _art(tester, _artMenu);
    for (final locale in [_vi, _en]) {
      final state = _midGame(locale);
      MainMenuScreen.giftShownThisSession = true;
      await _sprites(tester, [('mai', 'smile')]);
      await _pump(tester, state, const MainMenuScreen(), locale);
      await tester.pumpAndSettle();
      await _shot(tester, locale == _vi ? '01_menu' : '01_menu_en');
      await _dispose(tester);
    }
  });

  testWidgets('02 quà đăng nhập (ngày 4 của chuỗi 7 ngày)', (tester) async {
    await _art(tester, _artMenu);
    final state = _midGame(_vi, claimLogin: false);
    // Đã nhận 3 ngày liền trước hôm nay → hôm nay là quà ngày 4.
    final today = _now;
    for (var d = 3; d >= 1; d--) {
      _now = today.subtract(Duration(days: d));
      state.claimLogin();
    }
    _now = today;
    MainMenuScreen.giftShownThisSession = false; // menu tự mở hộp quà sau khung hình đầu.
    await _sprites(tester, [('mai', 'smile')]);
    await _pump(tester, state, const MainMenuScreen(), _vi);
    await tester.pumpAndSettle();
    expect(find.byType(SLDialog), findsOneWidget);
    await _shot(tester, '02_login_reward');
    await _dispose(tester);
  });

  testWidgets('03 hội thoại truyện: mở đầu (Mai nói) + ông Hòa', (tester) async {
    await _art(tester, _artStory);
    // Ngày 1, cấp 1: cảnh mở đầu. Dòng 1 là người kể (cuốn sổ) → chạm một lần sang lời Mai.
    final state = GameState.newGame(clock: _clock)
      ..setLanguage(LanguagePref.vi)
      ..claimLogin();
    await _pumpDay(tester, state, 1, _vi, extraSprites: [('mai', 'smile')]);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tapAt(const Offset(640, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, '03_story_mai');
    await _dispose(tester);

    // Ngày 2: cảnh ông Hòa ghé (ông nói trước, Mai mờ bên phải) → bỏ qua → ông Hòa ở quầy.
    final day2 = GameState.newGame(clock: _clock)
      ..setLanguage(LanguagePref.vi)
      ..claimLogin()
      ..markSceneSeen(StorySceneId.prologue)
      ..completeDay();
    for (final s in StationId.values) {
      day2.markTutorialSeen(s);
    }
    await _pumpDay(tester, day2, 1, _vi, extraSprites: [('mai', 'smile'), ('hoa', 'smile')]);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '03_story_hoa');
    await tester.tap(find.text(lookupAppLocalizations(_vi).storySkip));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 2600)); // giới thiệu ngày tự chuyển sang gọi món.
    await tester.pump(const Duration(milliseconds: 900));
    await _shot(tester, '06_counter_hoa');
    await _dispose(tester);
  });

  testWidgets('04–08 một ngày: hàng khách → gọi món → trạm làm bánh → khách vui', (tester) async {
    await _art(tester, _artDay);
    final state = _midGame(_vi);
    final l = lookupAppLocalizations(_vi);
    // Ngày có bạn quen (không ở chỗ đầu), khách đầu là khách thường, ai cũng có ảnh, không trùng ảnh.
    final seed = _seedFor(state, (d) {
      final ids = d.customers.map(CustomerArt.spriteId).toList();
      return d.customers.every(_hasArt) &&
          ids.toSet().length == ids.length &&
          d.customers.first.kind == CustomerKind.regular &&
          d.customers.skip(1).any((c) => c.kind == CustomerKind.friend);
    });
    final day = await _pumpDay(tester, state, seed, _vi);
    _used.addAll(day.customers.map(CustomerArt.spriteId));
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '04_day_intro');

    await tester.pump(const Duration(milliseconds: 2000)); // hết 2.4 s giới thiệu.
    await tester.pump(const Duration(milliseconds: 900)); // khách bước vào.
    await _shot(tester, '05_counter_order');

    // Trạm làm bánh (Flame).
    await tester.tap(find.text(l.dayStartBaking));
    await _run(tester, 0.8);
    final game = tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;
    final g = _mapper(tester);
    final order = day.orders.first;
    final recipe = order.recipeData;

    // 1. Khuôn: đang kéo khuôn đúng về khay.
    final mould = game.currentStation! as MouldStation;
    final from = MouldStation.slotCenter(mould.choices.indexOf(recipe.mould));
    final to = MouldStation.trayRect.center;
    final drag = await tester.startGesture(g(from));
    for (var i = 1; i <= 8; i++) {
      await drag.moveTo(g(Offset.lerp(from, to, i / 14)!));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _shot(tester, '07_station_mould');
    for (var i = 9; i <= 14; i++) {
      await drag.moveTo(g(Offset.lerp(from, to, i / 14)!));
    }
    await drag.up();
    await _run(tester, 1.6);

    // 2. Trộn: đúng số vòng mục tiêu, chụp khi đang xoay vòng cuối.
    final turns = recipe.mixTurns;
    final mix = await tester.startGesture(g(MixStation.center + const Offset(150, 0)));
    for (var i = 1; i <= turns * 36; i++) {
      final a = i * 2 * math.pi / 36;
      await mix.moveTo(g(MixStation.center + Offset(math.cos(a), math.sin(a)) * 150));
      if (i == turns * 36 - 9) {
        await tester.pump(const Duration(milliseconds: 16));
        await _shot(tester, '07_station_mix');
      }
    }
    await mix.up();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(l.commonDone));
    await _run(tester, 1.5);

    // 3. Nướng: đang giữ nút, kim gần vùng vàng.
    final hold = await tester.startGesture(g(BakeStation.buttonCenter), kind: PointerDeviceKind.mouse);
    await _run(tester, recipe.bakeTarget * 3 - 0.15);
    await _shot(tester, '07_station_bake');
    await _run(tester, 0.15);
    await hold.up();
    await _run(tester, 1.8);

    // 4. Phủ kem: đã vẽ ~60% đường gợi ý.
    final guide = spiralGuide(CakeArt.topSurface(FrostStation.cakeRectFor(recipe.mould), recipe.mould));
    final frost = await tester.startGesture(g(guide.first));
    for (final p in guide.skip(1).take((guide.length * 0.6).round())) {
      await frost.moveTo(g(p));
    }
    await tester.pump(const Duration(milliseconds: 16));
    await _shot(tester, '07_station_frost');
    await frost.up();
    await tester.pump();

    // Bỏ qua các trạm còn lại: báo kết quả hoàn hảo qua đúng callback của BakeSessionView.
    tester.widget<BakeSessionView>(find.byType(BakeSessionView)).onComplete(_perfect(order));
    await _settleResult(tester);
    await _shot(tester, '08_result_happy');
    await _dispose(tester);
  });

  testWidgets('05/08 tiếng Anh: khách khác gọi món + khách vui', (tester) async {
    await _art(tester, _artDay);
    final state = _midGame(_en);
    final seed = _seedFor(state, (d) => _freshRegular(d.customers.first), relaxed: (d) => _regularWithArt(d.customers.first));
    final day = await _pumpDay(tester, state, seed, _en);
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 900));
    await _shot(tester, '05_counter_order_en');
    await tester.tap(find.text(lookupAppLocalizations(_en).dayStartBaking));
    await _run(tester, 0.5);
    tester.widget<BakeSessionView>(find.byType(BakeSessionView)).onComplete(_good(day.orders.first));
    await _settleResult(tester);
    await _shot(tester, '08_result_happy_en');
    await _dispose(tester);
  });

  testWidgets('06 bạn quen ở quầy: Linh, Kenji', (tester) async {
    await _art(tester, _artDay);
    for (final friend in [FriendId.linh, FriendId.kenji]) {
      final state = _midGame(_vi);
      final seed = _seedFor(state, (d) => d.customers.first.friend == friend && d.customers.every(_hasArt));
      await _pumpDay(tester, state, seed, _vi);
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump(const Duration(milliseconds: 900));
      await _shot(tester, '06_counter_${friend.name}');
      await _dispose(tester);
    }
  });

  testWidgets('05b/09 khách thường khác gọi món, bánh cháy → khách buồn', (tester) async {
    await _art(tester, _artDay);
    final state = _midGame(_vi);
    final seed = _seedFor(state, (d) => _freshRegular(d.customers.first), relaxed: (d) => _regularWithArt(d.customers.first));
    final day = await _pumpDay(tester, state, seed, _vi);
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 900));
    await _shot(tester, '05_counter_order2');
    await tester.tap(find.text(lookupAppLocalizations(_vi).dayStartBaking));
    await _run(tester, 0.5);
    tester.widget<BakeSessionView>(find.byType(BakeSessionView)).onComplete(_burnt(day.orders.first));
    await _settleResult(tester);
    await _shot(tester, '09_result_sad');
    await _dispose(tester);
  });

  testWidgets('10 tổng kết ngày (có lên cấp)', (tester) async {
    await _art(tester, _artSummary);
    final state = _midGame(_vi);
    final seed = _seedFor(state, (d) => d.customers.every(_hasArt));
    final day = DayController(state: state, random: math.Random(seed));
    final outcomes = [_perfect, _good, _burnt, _perfect, _okay];
    final records = [
      for (var i = 0; i < day.total; i++)
        OrderRecord(
          order: day.orders[i],
          customer: day.customers[i],
          result: Scoring.evaluate(
            order: day.orders[i],
            customer: day.customers[i],
            outcome: outcomes[i % outcomes.length](day.orders[i]),
            modifiers: state.bakeModifiers,
            decorTipBonusPct: state.decorTipBonusPct,
          ),
        ),
    ];
    day.dispose();
    var revenue = 0, tips = 0, costs = 0, xp = 0;
    for (final r in records) {
      revenue += r.result.payment;
      tips += r.result.tip;
      costs += r.result.cost;
      xp += r.result.xp;
    }
    final summary = DaySummary(
      dayNumber: state.dayNumber,
      records: records,
      revenue: revenue,
      tips: tips,
      costs: costs,
      net: revenue + tips - costs,
      xpGained: xp + Economy.dayBonusXp,
      dayBonusXp: Economy.dayBonusXp,
      levelBefore: state.level - 1,
      levelAfter: state.level,
      unlocks: Economy.unlocksAtLevel(state.level),
    );
    await _customers(tester, day.customers);
    await _pump(tester, state, DaySummaryScreen(summary: summary), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '10_day_summary');
    await _dispose(tester);
  });

  testWidgets('11–16 nâng cấp, trang trí, sổ công thức, nhiệm vụ, cửa hàng, cài đặt', (tester) async {
    await _art(tester, _artMeta);
    final pages = <String, Widget>{
      '11_upgrades': const UpgradesScreen(),
      '12_decor': const DecorScreen(),
      '13_recipe_book': const RecipeBookScreen(),
      '15_shop': const StoreScreen(),
      '16_settings': const SettingsScreen(),
    };
    for (final MapEntry(key: name, value: page) in pages.entries) {
      await _pump(tester, _midGame(_vi), page, _vi);
      await tester.pumpAndSettle();
      await _shot(tester, name);
      await _dispose(tester);
    }

    // Nhiệm vụ ngày: hộp thoại mở trên menu chính.
    MainMenuScreen.giftShownThisSession = true;
    await _sprites(tester, [('mai', 'smile')]);
    await _pump(tester, _midGame(_vi), const MainMenuScreen(), _vi);
    await tester.pumpAndSettle();
    showQuestsDialog(tester.element(find.byType(MainMenuScreen)));
    await tester.pumpAndSettle();
    await _shot(tester, '14_quests');
    await _dispose(tester);
  });
}

// ------------------------------------------------------------------ Dữ liệu giả lập

/// Ván giữa game: cấp 7, ngày 7, đã xem hết truyện (bạn quen có thể ghé), đã qua hướng dẫn, có trang trí,
/// vài món đã thành thạo và nhiệm vụ đang làm dở.
GameState _midGame(Locale locale, {bool claimLogin = true}) {
  final state = GameState.newGame(clock: _clock)
    ..setLanguage(locale == _vi ? LanguagePref.vi : LanguagePref.en)
    ..addXp(Economy.xpToReachLevel(6) + 130)
    ..addCoins(2400)
    ..addGems(30);
  if (claimLogin) state.claimLogin();
  for (final s in StorySceneId.values) {
    state.markSceneSeen(s);
  }
  for (final s in StationId.values) {
    state.markTutorialSeen(s);
  }
  for (final d in [DecorId.wallpaperStripes, DecorId.counterFlowers, DecorId.windowCurtains, DecorId.plantFern]) {
    if (state.buyDecor(d) == PurchaseResult.ok) state.equipDecor(Catalog.decorItem(d).slot, d);
  }
  for (var i = 0; i < 6; i++) {
    state.completeDay();
  }
  // Phục vụ vài đơn: thành thạo món + tiến độ nhiệm vụ (một nhiệm vụ xong, chưa nhận).
  final served = <(RecipeId, BakeOutcome Function(Order))>[
    (RecipeId.cupcakeVanilla, _perfect),
    (RecipeId.cupcakeChocolate, _perfect),
    (RecipeId.muffinBlueberry, _good),
    (RecipeId.eggTart, _perfect),
    (RecipeId.strawberryCake, _okay),
  ];
  for (final (recipe, outcome) in served) {
    final data = Catalog.recipe(recipe);
    final order = Order(
      id: 0,
      recipe: recipe,
      frosting: data.frostings.first,
      toppings: [ToppingRequest(data.toppings.first, 2)],
      box: data.box,
      line: OrderLineKind.generic1,
    );
    const customer = Customer(kind: CustomerKind.regular, appearanceSeed: 1);
    state.applyOrderResult(
      order,
      customer,
      Scoring.evaluate(
        order: order,
        customer: customer,
        outcome: outcome(order),
        modifiers: state.bakeModifiers,
        decorTipBonusPct: 0,
      ),
    );
  }
  return state;
}

BakeOutcome _perfect(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: o.recipeData.bakeTarget,
      frostCoverage: 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// 5★ chưa tròn trịa: hơi lệch vùng nướng, trộn hơi thiếu (mọi trạm vẫn đạt → khách khen, không chê).
BakeOutcome _good(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns * 0.88,
      bakeRelease: o.recipeData.bakeTarget + 0.06,
      frostCoverage: 0.93,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// ~3★: trộn thiếu, kem loang.
BakeOutcome _okay(Order o) => BakeOutcome(
      wrongMouldDrops: 1,
      mixTurns: o.recipeData.mixTurns * 0.7,
      bakeRelease: o.recipeData.bakeTarget + 0.06,
      frostCoverage: 0.7,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// 1–2★: giữ nướng tới cuối (cháy), kem loang, thiếu topping.
BakeOutcome _burnt(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: 1,
      frostCoverage: 0.55,
      toppingsPlaced: {for (final t in o.toppings) t.topping: math.max(0, t.count - 1)}..removeWhere((_, n) => n == 0),
      boxChosen: o.box,
    );

/// Có ảnh vẽ tay cho khách này (ít nhất nét mặt neutral).
bool _hasArt(Customer c) => File('assets/characters/${CustomerArt.spriteId(c)}_neutral.webp').existsSync();

/// Khách thường có ảnh mà chưa xuất hiện ở ảnh nào trước đó.
bool _freshRegular(Customer c) => _regularWithArt(c) && !_used.contains(CustomerArt.spriteId(c));

bool _regularWithArt(Customer c) => c.kind == CustomerKind.regular && _hasArt(c);

/// Seed nhỏ nhất cho `DayController` thoả [ok] (DayController thuần: không đổi state).
/// [relaxed]: điều kiện nới dùng khi không seed nào thoả [ok] (vd. hết khách có ảnh chưa xuất hiện).
int _seedFor(GameState state, bool Function(DayController d) ok, {bool Function(DayController d)? relaxed}) {
  for (final test in [ok, ?relaxed]) {
    for (var seed = 1; seed < 20000; seed++) {
      final d = DayController(state: state, random: math.Random(seed));
      final good = test(d);
      d.dispose();
      if (good) return seed;
    }
  }
  _notes.add('không tìm được ngày thoả điều kiện chọn khách, dùng seed 1');
  return 1;
}

// ------------------------------------------------------------------ Dựng + chụp

AppServices _services(GameState state) => AppServices(
      state: state,
      saves: MemorySaveRepository(),
      ads: FakeAdService(state),
      iap: FakeIapService(state, delay: Duration.zero),
      audio: FakeAudioService(state),
    );

/// Theme y như app thật: font đóng gói đã nạp sẵn ở [_loadFonts].
ThemeData _theme(Locale locale) => AppTheme.build(locale: locale);

/// Dựng [home] như `SugarleafApp` (AppScope → MaterialApp → RefFrame → Theme), bọc RepaintBoundary để chụp.
Future<void> _pump(WidgetTester tester, GameState state, Widget home, Locale locale) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = _theme(locale);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: AppScope(
        services: _services(state),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: SugarleafApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: theme,
          home: home,
          onGenerateRoute: onGenerateUiRoute,
          builder: (ctx, child) => RefFrame(child: Theme(data: theme, child: child ?? const SizedBox.shrink())),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Dựng màn ngày với `Random(seed)`; nạp trước ảnh mọi khách của ngày (đúng bộ DayScreen sẽ xin) để
/// không có lượt nạp nào bắt đầu trong vùng thời gian giả của test.
Future<DayController> _pumpDay(
  WidgetTester tester,
  GameState state,
  int seed,
  Locale locale, {
  List<(String, String)> extraSprites = const [],
}) async {
  final day = DayController(state: state, random: math.Random(seed));
  day.dispose();
  _used.add(CustomerArt.spriteId(day.customers.first));
  await _customers(tester, day.customers, visible: day.customers.take(1).toList());
  if (extraSprites.isNotEmpty) await _sprites(tester, extraSprites);
  await _pump(tester, state, DayScreen(random: math.Random(seed)), locale);
  return day;
}

Future<void> _sprites(WidgetTester tester, List<(String, String)> sprites) async {
  await tester.runAsync(() => CharacterSprites.preload(sprites));
  for (final (id, expr) in sprites) {
    if (CharacterSprites.isMissing(id, expr)) _notes.add('thiếu ảnh ${CharacterSprites.assetPath(id, expr)} (vẽ hình code)');
  }
}

/// [visible]: khách lộ mặt trong ảnh (ghi chú nếu thiếu ảnh); mặc định = cả [customers].
Future<void> _customers(WidgetTester tester, List<Customer> customers, {List<Customer>? visible}) async {
  await tester.runAsync(() => CustomerArt.preload(customers));
  for (final c in visible ?? customers) {
    for (final mood in CustomerMood.values) {
      final id = CustomerArt.spriteId(c), expr = CustomerArt.spriteExpr(CustomerArt.expressionFor(mood));
      final note = 'thiếu ảnh ${CharacterSprites.assetPath(id, expr)} (dùng nét mặt khác/hình code)';
      if (CharacterSprites.isMissing(id, expr) && !_notes.contains(note)) _notes.add(note);
    }
  }
}

/// Chờ thẻ kết quả phóng to xong và các sao hiện lần lượt.
Future<void> _settleResult(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Chạy Flame [seconds] giây (bước 50 ms).
Future<void> _run(WidgetTester tester, double seconds) async {
  final steps = (seconds / 0.05).ceil();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Toạ độ khung 1280×720 của trạm → toạ độ màn hình test.
Offset Function(Offset) _mapper(WidgetTester tester) {
  final rect = tester.getRect(find.byKey(const ValueKey('bake-session-input')));
  final k = rect.width / 1280;
  return (p) => rect.topLeft + p * k;
}

/// Xuất ảnh hiện tại ra `$_outDir/<name>.png` (1280×720).
Future<void> _shot(WidgetTester tester, String name) async {
  // Ảnh nhân vật nạp xong muộn (nếu có) → cho vòng lặp thật chạy một chút rồi vẽ lại.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  final error = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    return null;
  });
  expect(error, isNull);
  expect(tester.takeException(), isNull, reason: name);
  _written.add(name);
}

/// Bỏ cây widget (huỷ timer/game), chờ toast tắt.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

// ------------------------------------------------------------------ Ảnh đồ hoạ vẽ tay

/// Nạp trước ảnh vẽ tay (bánh, đồ vật, nền…) để ảnh chụp giống app thật. Bộ nhớ đệm ảnh nhỏ có hạn (48 MB)
/// nên mỗi cảnh chỉ nạp nhóm cần dùng.
Future<void> _art(WidgetTester tester, List<ArtRef> refs) async {
  await tester.runAsync(() => ArtSprites.preload(refs));
}

final _artMenu = [ArtSprites.scene(ArtScene.menu), ...ArtSprites.group(ArtGroup.items), ...ArtSprites.group(ArtGroup.cakes)];
final _artStory = [
  ArtSprites.scene(ArtScene.storyTown),
  ArtSprites.scene(ArtScene.storyGrandmaKitchen),
  ArtSprites.shopBase,
  ...ArtSprites.group(ArtGroup.items),
  ...ArtSprites.group(ArtGroup.decor),
  ...ArtSprites.group(ArtGroup.tiles),
];
final _artDay = [
  ArtSprites.shopBase,
  ...ArtSprites.group(ArtGroup.kitchen),
  ...ArtSprites.group(ArtGroup.items),
  ...ArtSprites.group(ArtGroup.cakes),
  ...ArtSprites.group(ArtGroup.moulds),
  ...ArtSprites.group(ArtGroup.frosting),
  ...ArtSprites.group(ArtGroup.toppings),
  ...ArtSprites.group(ArtGroup.decor),
  ...ArtSprites.group(ArtGroup.tiles),
];
final _artSummary = [ArtSprites.scene(ArtScene.daySummary), ...ArtSprites.group(ArtGroup.items), ...ArtSprites.group(ArtGroup.cakes)];
final _artMeta = [
  ArtSprites.shopBase,
  ...ArtSprites.group(ArtGroup.items),
  ...ArtSprites.group(ArtGroup.cakes),
  ...ArtSprites.group(ArtGroup.decor),
  ...ArtSprites.group(ArtGroup.tiles),
];

// ------------------------------------------------------------------ Font

/// Nạp font đóng gói (assets/fonts) dưới đúng tên họ font của app.
Future<void> _loadFonts() async {
  for (final (family, files) in _fontFiles) {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('assets/fonts/$name.ttf');
      if (!file.existsSync()) {
        _notes.add('thiếu ${file.path}');
        continue;
      }
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      any = true;
    }
    if (any) await loader.load();
  }
}
