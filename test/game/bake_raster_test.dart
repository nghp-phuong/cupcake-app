import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/components/game_paint.dart';
import 'package:sugarleaf_bakery/game/components/hand_paint.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sl_theme.dart';

// Hiệu năng web của màn làm bánh (docs/v3/thermion-api-notes.md §31): hình vẽ tay dựng sẵn raster hoá thành ảnh ở
// độ phân giải thật, mảng tĩnh của lớp phủ chụp thành ảnh. Ảnh phải đủ nét (không cắt mất nét vẽ) và được làm mới
// khi độ phân giải / cỡ màn đổi.

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2), ToppingRequest(ToppingId.sprinkles, 1)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Vẽ [art] vào một khung hình bỏ đi (đúng việc của luồng UI mỗi khung).
void _drawOnce(GameArt art, [Offset at = Offset.zero]) {
  final recorder = ui.PictureRecorder();
  art.draw(Canvas(recorder), at);
  recorder.endRecording().dispose();
}

/// Tổng alpha (0..1) của ảnh [w]×[h] do [paint] vẽ — đo "lượng mực" để so vẽ Picture với vẽ ảnh raster.
Future<double> _ink(int w, int h, void Function(Canvas c) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  final bytes = (await image.toByteData())!;
  image.dispose();
  var sum = 0.0;
  for (var i = 3; i < bytes.lengthInBytes; i += 4) {
    sum += bytes.getUint8(i) / 255;
  }
  return sum;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => gameArtPixelRatio = 0);

  test('GameArt: tỉ lệ 0 → vẽ Picture; có tỉ lệ → ảnh raster đúng cỡ, dùng lại; đổi tỉ lệ → dựng lại', () {
    final art = buildPlateArt(58);
    final rect = art.bounds.inflate(GameArt.rasterPad);

    gameArtPixelRatio = 0;
    _drawOnce(art);
    expect(art.rasterImage, isNull);

    gameArtPixelRatio = 1;
    _drawOnce(art);
    final first = art.rasterImage!;
    expect(first.width, rect.width.ceil());
    expect(first.height, rect.height.ceil());
    _drawOnce(art, const Offset(40, 70));
    expect(identical(art.rasterImage, first), isTrue, reason: 'cùng tỉ lệ → không raster lại');

    gameArtPixelRatio = 2.5;
    _drawOnce(art);
    expect(art.rasterImage!.width, (rect.width * 2.5).ceil());
    expect(art.rasterImage!.height, (rect.height * 2.5).ceil());
    art.dispose();
    expect(art.rasterImage, isNull);
  });

  test('ảnh raster chứa trọn nét vẽ của mọi hình dựng sẵn (so lượng mực với vẽ Picture)', () async {
    final text = TextPainter(
      text: const TextSpan(text: 'Cupcake liner', style: TextStyle(fontSize: 14, color: SLColors.ink)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 190);
    final arts = <String, GameArt>{
      'đĩa': buildPlateArt(58),
      'nhãn giấy': buildPaperTag(text, seed: 3),
      'thanh đo': buildMeterArt(const Size(600, 28), seed: 5),
      'nhãn dán tròn': buildStickerDisc(30, SLColors.dangerSoft, seed: 7),
      'khay nướng': buildBakingTrayArt(const Size(460, 270)),
      'đĩa bầu dục': buildServingPlateArt(const Size(400, 80)),
      'chấm mực': buildInkDotArt(4, const Color(0x595A3E36), 1),
      'vòng mực': buildInkRingArt(12, SLColors.strawberry, 3, seed: 2),
      'giá nướng': buildOvenRackArt(300),
    };
    const at = Offset(300, 300);
    for (final MapEntry(key: name, value: art) in arts.entries) {
      gameArtPixelRatio = 0;
      final direct = await _ink(1400, 1000, (c) => art.draw(c, at));
      gameArtPixelRatio = 1;
      final raster = await _ink(1400, 1000, (c) => art.draw(c, at));
      expect(direct, greaterThan(0), reason: name);
      expect((raster - direct).abs() / direct, lessThan(0.02), reason: '$name: $raster so với $direct');
      art.dispose();
    }
    // Tờ giấy cột phải vẽ ở toạ độ khung (gốc hình = 0,0), kể cả khung rộng.
    for (final inset in [0.0, 160.0]) {
      final sheet = buildColumnSheetArt(inset: inset);
      final w = (1320 + inset).ceil();
      gameArtPixelRatio = 0;
      final direct = await _ink(w, 760, (c) => sheet.draw(c, Offset.zero));
      gameArtPixelRatio = 1;
      final raster = await _ink(w, 760, (c) => sheet.draw(c, Offset.zero));
      expect((raster - direct).abs() / direct, lessThan(0.02), reason: 'tờ giấy cột phải inset $inset');
      sheet.dispose();
    }
    // `text` thuộc nhãn giấy (đã giải phóng cùng hình).
  });

  test('bánh dựng sẵn (topping / hộp): dựng khi cỡ đứng yên, đủ nét như vẽ thẳng, đổi cỡ → dựng lại', () async {
    clearCakeCache();
    gameArtPixelRatio = 1;
    const cake = CakeVisual(mould: MouldType.cupcakeLiner, batter: BatterType.vanilla, frosting: FrostingId.vanillaCream, recipe: RecipeId.cupcakeVanilla);
    const rect = Rect.fromLTWH(190, 200, 460, 460);
    void frame(Rect r) {
      final recorder = ui.PictureRecorder();
      paintCakeWithToppings(Canvas(recorder), r, cake, const []);
      recorder.endRecording().dispose();
    }

    frame(rect);
    expect(cakeCacheArt, isNull, reason: 'khung đầu: chưa biết cỡ có đứng yên không → vẽ thẳng');
    frame(rect);
    final built = cakeCacheArt;
    expect(built, isNotNull);
    frame(rect.translate(30, -12));
    expect(identical(cakeCacheArt, built), isTrue, reason: 'chỉ dời chỗ → dùng lại');

    // Hoạt cảnh co giãn: cỡ đổi mỗi khung → vẽ thẳng, giữ ảnh cũ; đứng yên ở cỡ mới → dựng lại.
    for (final s in [440.0, 420.0, 400.0]) {
      frame(Rect.fromLTWH(190, 200, s, s));
      expect(identical(cakeCacheArt, built), isTrue);
    }
    frame(const Rect.fromLTWH(190, 200, 400, 400));
    expect(cakeCacheArt, isNot(same(built)));

    // Đủ nét: so lượng mực với vẽ thẳng CakeArt.
    final direct = await _ink(1000, 900, (c) => CakeArt.paint(c, rect, cake));
    frame(rect);
    frame(rect);
    final cached = await _ink(1000, 900, (c) => paintCakeWithToppings(c, rect, cake, const []));
    expect((cached - direct).abs() / direct, lessThan(0.02), reason: '$cached so với $direct');
    clearCakeCache();
    expect(cakeCacheArt, isNull);
  });

  testWidgets('BakeSessionView: độ phân giải raster theo màn, đổi cỡ màn → đổi theo', (tester) async {
    tester.view
      ..physicalSize = const Size(2560, 1440)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {})));
    await tester.pump();
    // Khung 1280×720 lấp màn 2560×1440 điểm ảnh → 2 điểm ảnh / đơn vị khung.
    expect(gameArtPixelRatio, closeTo(2, 1e-9));

    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump();
    expect(gameArtPixelRatio, closeTo(1.5, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lớp phủ: 3 mảng tĩnh chụp ảnh sau khi ổn định; đổi trạm → chạy trực tiếp rồi chụp lại', (tester) async {
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {})));
    await tester.pump();
    List<bool> snapping() => [for (final w in tester.widgetList<SnapshotWidget>(find.byType(SnapshotWidget))) w.controller.allowSnapshotting];
    expect(snapping(), [false, false, false], reason: 'mới dựng: chạy trực tiếp');
    await tester.pump(const Duration(milliseconds: 450));
    expect(snapping(), [true, true, true]);

    // Độ phân giải ảnh chụp = độ phân giải thật của khung (màn test 2400×1800 → 1,875), con vẫn thấy DPR gốc.
    final snap = find.byType(SnapshotWidget).first;
    expect(MediaQuery.devicePixelRatioOf(tester.element(snap)), closeTo(gameArtPixelRatio, 1e-9));
    final inner = find.descendant(of: snap, matching: find.byType(IgnorePointer)).first;
    expect(MediaQuery.devicePixelRatioOf(tester.element(inner)), tester.view.devicePixelRatio);

    // Đổi trạm: thanh bước + giấy gợi ý chạy trực tiếp, vé đơn (không đổi) vẫn là ảnh.
    final game = tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;
    for (var i = 0; i < 60 && game.currentStation == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 450));
    game.stationFinished(delay: 0);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.hud.station, StationId.mix);
    expect(snapping(), [false, true, false]);
    await tester.pump(const Duration(milliseconds: 450));
    expect(snapping(), [true, true, true]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('GameWidget không giữ focus: Esc tới được lớp bên ngoài', (tester) async {
    final keys = <LogicalKeyboardKey>[];
    await tester.pumpWidget(_host(Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent) keys.add(e.logicalKey);
        return KeyEventResult.handled;
      },
      child: BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {}),
    )));
    await tester.pump();
    expect(tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).autofocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(keys, [LogicalKeyboardKey.escape]);
    await tester.pumpWidget(const SizedBox());
  });
}
