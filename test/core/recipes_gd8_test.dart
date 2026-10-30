import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

DateTime _clock() => DateTime(2026, 10, 30, 10);

/// Bundle rỗng: không có ảnh nào → CakeArt vẽ hình code dự phòng.
class _EmptyBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    throw StateError('Unable to load asset: "$key".');
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async => parser(await loadString(key));
}

/// 8 món GĐ8 theo bảng `docs/v2/phase8-spec.md` §1: (món, màn mở, khuôn, bột, kem, topping, hộp, giá, chi phí).
const _gd8 = [
  (RecipeId.croissant, 21, MouldType.pastryTray, BatterType.laminated, [FrostingId.butterGlaze], [ToppingId.almondFlakes, ToppingId.powderedSugar], BoxType.small, 64, 16),
  (RecipeId.painAuChocolat, 24, MouldType.pastryTray, BatterType.laminated, [FrostingId.chocolateGanache], [ToppingId.chocolateChips, ToppingId.powderedSugar], BoxType.small, 68, 17),
  (RecipeId.madeleine, 27, MouldType.shellMould, BatterType.butter, [FrostingId.butterGlaze], [ToppingId.powderedSugar, ToppingId.sugarPearl], BoxType.small, 58, 15),
  (RecipeId.eclair, 31, MouldType.eclairTray, BatterType.choux, [FrostingId.chocolateGanache, FrostingId.custard], [ToppingId.almondFlakes, ToppingId.sprinkles], BoxType.small, 74, 19),
  (RecipeId.fruitTart, 34, MouldType.tartShell, BatterType.butter, [FrostingId.custard], [ToppingId.strawberry, ToppingId.blueberry, ToppingId.kiwi, ToppingId.mintLeaf], BoxType.cake, 82, 21),
  (RecipeId.applePie, 38, MouldType.piePan, BatterType.butter, [FrostingId.appleFilling], [ToppingId.powderedSugar, ToppingId.mintLeaf], BoxType.cake, 86, 22),
  (RecipeId.mooncake, 43, MouldType.mooncakeMould, BatterType.mooncake, [FrostingId.lotusPaste], [ToppingId.sesame, ToppingId.sugarPearl], BoxType.gift, 92, 23),
  (
    RecipeId.bucheDeNoel, 47, MouldType.logPan, BatterType.chocolate, [FrostingId.chocolateGanache], //
    [ToppingId.meringueMushroom, ToppingId.powderedSugar, ToppingId.cherry, ToppingId.mintLeaf], BoxType.cake, 98, 25,
  ),
];

const _gd8Moulds = [MouldType.pastryTray, MouldType.shellMould, MouldType.eclairTray, MouldType.piePan, MouldType.mooncakeMould, MouldType.logPan];

/// Khung alpha (> 20) của hình vẽ trên ảnh [n]×[n].
Future<Rect> _alphaBox(int n, void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(n, n);
  final data = (await image.toByteData())!;
  image.dispose();
  var l = n, r = -1, t = n, b = -1;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (data.getUint8((y * n + x) * 4 + 3) > 20) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  return r < 0 ? Rect.zero : Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0);
}

/// Độ sáng trung bình các điểm ảnh thân bánh (alpha > 200) trên ảnh [n]×[n].
Future<double> _meanLuma(int n, void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(n, n);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  image.dispose();
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i + 3) <= 200) continue;
    sum += 0.299 * data.getUint8(i) + 0.587 * data.getUint8(i + 1) + 0.114 * data.getUint8(i + 2);
    count++;
  }
  return count == 0 ? 0 : sum / count;
}

void main() {
  tearDown(ArtSprites.debugReset);

  test('enum: giá trị cũ giữ nguyên tên + chỉ số, giá trị GĐ8 thêm ở cuối', () {
    expect(RecipeId.values.map((e) => e.name), [
      'cupcakeVanilla', 'cupcakeChocolate', 'muffinBlueberry', 'eggTart', 'strawberryCake', 'macaron', 'redVelvetCupcake', //
      'matchaCake', 'cheesecake', 'birthdayCake',
      'croissant', 'painAuChocolat', 'madeleine', 'eclair', 'fruitTart', 'applePie', 'mooncake', 'bucheDeNoel',
    ]);
    expect(MouldType.values.map((e) => e.name), [
      'cupcakeLiner', 'muffinCup', 'tartShell', 'roundPan', 'macaronMat', 'springformPan', 'tallPan', //
      'pastryTray', 'shellMould', 'eclairTray', 'piePan', 'mooncakeMould', 'logPan',
    ]);
    expect(BatterType.values.map((e) => e.name),
        ['vanilla', 'chocolate', 'redVelvet', 'matcha', 'butter', 'almond', 'cheese', 'laminated', 'choux', 'mooncake']);
    expect(FrostingId.values.map((e) => e.name), [
      'vanillaCream', 'chocolateGanache', 'strawberryCream', 'matchaCream', 'creamCheese', 'custard', //
      'butterGlaze', 'appleFilling', 'lotusPaste',
    ]);
    expect(ToppingId.values.map((e) => e.name), [
      'sprinkles', 'strawberry', 'cherry', 'chocolateChips', 'blueberry', 'mintLeaf', 'sugarPearl', 'candle', //
      'almondFlakes', 'powderedSugar', 'kiwi', 'sesame', 'meringueMushroom',
    ]);
  });

  test('catalog: 8 món GĐ8 đúng bảng đặc tả', () {
    for (final (id, level, mould, batter, frostings, toppings, box, price, cost) in _gd8) {
      final r = Catalog.recipe(id);
      expect(r.unlockLevel, level, reason: id.name);
      expect(r.mould, mould, reason: id.name);
      expect(r.batter, batter, reason: id.name);
      expect(r.frostings, frostings, reason: id.name);
      expect(r.toppings, toppings, reason: id.name);
      expect(r.box, box, reason: id.name);
      expect((r.price, r.cost), (price, cost), reason: id.name);
      // Nhịp trạm GĐ8: trộn 4–5 vòng, mục tiêu nướng 0.58–0.72.
      expect(r.mixTurns, inInclusiveRange(4, 5), reason: id.name);
      expect(r.bakeTarget, inInclusiveRange(0.58, 0.72), reason: id.name);
    }
    // Bánh cán bơ / choux nướng nhạy: mục tiêu lệch khỏi 0.65.
    for (final id in [RecipeId.croissant, RecipeId.painAuChocolat, RecipeId.eclair]) {
      expect((Catalog.recipe(id).bakeTarget - 0.65).abs(), greaterThan(0.049), reason: id.name);
    }
  });

  test('catalog: mọi món có dữ liệu hợp lệ', () {
    expect(Catalog.recipes, hasLength(18));
    expect(Catalog.recipes.map((r) => r.id).toList(), RecipeId.values);
    var prevLevel = 0;
    for (final r in Catalog.recipes) {
      expect(r.unlockLevel, greaterThanOrEqualTo(prevLevel), reason: '${r.id.name}: mở theo thứ tự');
      prevLevel = r.unlockLevel;
      expect(r.cost, greaterThan(0), reason: r.id.name);
      expect(r.price, greaterThan(r.cost * 3), reason: r.id.name);
      expect(r.frostings, isNotEmpty, reason: r.id.name);
      expect(r.frostings.toSet(), hasLength(r.frostings.length), reason: r.id.name);
      expect(r.toppings, isNotEmpty, reason: r.id.name);
      expect(r.toppings.toSet(), hasLength(r.toppings.length), reason: r.id.name);
      expect(r.mixTurns, inInclusiveRange(3, 5), reason: r.id.name);
      expect(r.bakeTarget, inInclusiveRange(0.5, 0.8), reason: r.id.name);
    }
    // Topping của món GĐ8 đã mở khi món mở (trạm 5 suy "đã mở" từ `recipe.unlockLevel`).
    for (final (id, _, _, _, _, _, _, _, _) in _gd8) {
      final r = Catalog.recipe(id);
      for (final t in r.toppings) {
        expect(Catalog.toppingUnlockLevel[t]!, lessThanOrEqualTo(r.unlockLevel), reason: '${r.id.name}/${t.name}');
      }
    }
    // Mọi topping có cấp mở; mọi khuôn/bột/kem/topping được ít nhất một món dùng.
    expect(Catalog.toppingUnlockLevel.keys.toSet(), ToppingId.values.toSet());
    expect({for (final r in Catalog.recipes) r.mould}, MouldType.values.toSet());
    expect({for (final r in Catalog.recipes) r.batter}, BatterType.values.toSet());
    expect({for (final r in Catalog.recipes) ...r.frostings}, FrostingId.values.toSet());
    expect({for (final r in Catalog.recipes) ...r.toppings}, ToppingId.values.toSet());
  });

  test('mồi ở bếp nhanh: món chương 1–2 giữ bộ mồi cũ; khuôn/topping mới chỉ làm mồi khi đã gặp', () {
    final oldMoulds = MouldType.values.where((m) => !_gd8Moulds.contains(m)).toSet();
    final newToppings = {for (final (_, _, _, _, _, t, _, _, _) in _gd8) ...t}.difference({for (final r in Catalog.recipes.take(10)) ...r.toppings});
    for (final r in Catalog.recipes.take(10)) {
      expect({for (final m in MouldType.values) if (Catalog.isDecoyMould(m, r.unlockLevel)) m}, oldMoulds, reason: r.id.name);
      expect({for (final t in ToppingId.values) if (Catalog.isDecoyTopping(t, r.unlockLevel)) t}, ToppingId.values.toSet().difference(newToppings),
          reason: r.id.name);
    }
    expect(Catalog.isDecoyMould(MouldType.pastryTray, Catalog.recipe(RecipeId.croissant).unlockLevel), isTrue);
    expect(Catalog.isDecoyMould(MouldType.logPan, Catalog.recipe(RecipeId.croissant).unlockLevel), isFalse);
    expect(Catalog.isDecoyMould(MouldType.logPan, Catalog.recipe(RecipeId.bucheDeNoel).unlockLevel), isTrue);
    expect(Catalog.isDecoyTopping(ToppingId.kiwi, Catalog.recipe(RecipeId.eclair).unlockLevel), isFalse);
    expect(Catalog.isDecoyTopping(ToppingId.kiwi, Catalog.recipe(RecipeId.fruitTart).unlockLevel), isTrue);
  });

  test('ảnh: mọi giá trị enum GĐ8 có đường dẫn ảnh (đang chờ vẽ → hình code)', () {
    void registered(ArtRef ref) {
      expect(ArtSprites.ids[ref.group], contains(ref.id), reason: '$ref');
      expect(ref.assetPath, 'assets/art/${ref.group.name}/${ref.id}.webp');
    }

    for (final (id, _, mould, batter, frostings, toppings, _, _, _) in _gd8) {
      registered(ArtSprites.cake(id));
      registered(ArtSprites.mould(mould));
      registered(ArtSprites.batter(batter));
      for (final f in frostings) {
        registered(ArtSprites.frosting(f));
      }
      for (final t in toppings) {
        registered(ArtSprites.topping(t));
      }
      // Đế nướng tra theo món trước.
      final baked = ArtSprites.baked(mould, batter, recipe: id);
      expect(baked, ArtRef(ArtGroup.baked, id.name));
      registered(baked);
    }
    // Món cũ chưa có ảnh riêng theo món → biến thể theo bột → ảnh gốc khuôn, như trước.
    expect(ArtSprites.baked(MouldType.cupcakeLiner, BatterType.chocolate, recipe: RecipeId.cupcakeChocolate).id, 'cupcakeLiner_chocolate');
    expect(ArtSprites.baked(MouldType.roundPan, BatterType.vanilla, recipe: RecipeId.strawberryCake).id, 'roundPan');
    expect(ArtSprites.baked(MouldType.tartShell, BatterType.butter, recipe: RecipeId.fruitTart).id, 'fruitTart');
    // Trạm 3–6 nạp đúng đế của món.
    expect(
      ArtSprites.stationRefs(StationId.bake, mould: MouldType.pastryTray, batter: BatterType.laminated, recipe: RecipeId.painAuChocolat),
      contains(const ArtRef(ArtGroup.baked, 'painAuChocolat')),
    );
  });

  testWidgets('thiếu ảnh GĐ8 (bundle rỗng): thiếu êm, vẽ hình code, không lỗi, không log', (tester) async {
    ArtSprites.debugReset(bundle: _EmptyBundle());
    final logs = <String?>[];
    final saved = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    try {
      await tester.runAsync(() async {
        final refs = [
          for (final (id, _, mould, batter, frostings, toppings, _, _, _) in _gd8) ...[
            ArtSprites.cake(id),
            ArtSprites.mould(mould),
            ArtSprites.batter(batter),
            ArtSprites.baked(mould, batter, recipe: id),
            for (final f in frostings) ArtSprites.frosting(f),
            for (final t in toppings) ArtSprites.topping(t),
          ],
        ];
        await ArtSprites.preload(refs);
        for (final ref in refs) {
          expect(ref.isMissing, isTrue, reason: '$ref');
        }
        for (final (id, _, _, _, _, _, _, _, _) in _gd8) {
          final v = CakeVisual.recipe(id, toppings: {for (final t in Catalog.recipe(id).toppings) t: 1});
          final box = await _alphaBox(400, (c) => CakeArt.paint(c, const Rect.fromLTWH(0, 0, 400, 400), v));
          expect(box.width, greaterThan(400 * 0.5), reason: id.name);
        }
      });
    } finally {
      debugPrint = saved;
    }
    expect(logs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ảnh đế GĐ8 (một chiếc): cùng bề rộng / đáy với hình code, nằm trong khung, mặt bánh trong thân bánh',
      (tester) async {
    const rect = Rect.fromLTWH(0, 0, 400, 400);
    const tol = 400 * 0.02;
    final code = <RecipeId, Rect>{};
    await tester.runAsync(() async {
      ArtSprites.debugReset(bundle: _EmptyBundle());
      await ArtSprites.preload([for (final r in Catalog.recipes.skip(10)) ArtSprites.baked(r.mould, r.batter, recipe: r.id)]);
      for (final r in Catalog.recipes.skip(10)) {
        code[r.id] = await _alphaBox(400, (c) => CakeArt.paint(c, rect, CakeVisual(mould: r.mould, batter: r.batter, recipe: r.id)));
      }
      ArtSprites.debugReset();
      await ArtSprites.preload([for (final r in Catalog.recipes.skip(10)) ArtSprites.baked(r.mould, r.batter, recipe: r.id)]);
      for (final r in Catalog.recipes.skip(10)) {
        final ref = ArtSprites.baked(r.mould, r.batter, recipe: r.id);
        expect(ref.id, r.id.name);
        expect(ref.image, isNotNull, reason: r.id.name);
        final v = CakeVisual(mould: r.mould, batter: r.batter, recipe: r.id);
        final art = await _alphaBox(400, (c) => CakeArt.paint(c, rect, v));
        expect(art.left, closeTo(code[r.id]!.left, tol * 2), reason: '${r.id.name} trái');
        expect(art.right, closeTo(code[r.id]!.right, tol * 2), reason: '${r.id.name} phải');
        expect(art.bottom, closeTo(code[r.id]!.bottom, tol), reason: '${r.id.name} đáy');
        expect(art.top, greaterThanOrEqualTo(0), reason: r.id.name);
        final body = CakeArt.artBodyRect(rect, r.mould, recipe: r.id);
        expect(art.bottom, closeTo(body.bottom, tol), reason: r.id.name);
        final top = CakeArt.topSurface(rect, r.mould, recipe: r.id);
        expect(body.inflate(0.5).contains(top.topLeft) && body.inflate(0.5).contains(top.bottomRight), isTrue, reason: r.id.name);
        expect(top.width, greaterThan(top.height), reason: r.id.name);
        // Kem đủ + topping: không lệch đáy, không tràn khung.
        final full = await _alphaBox(400, (c) => CakeArt.paint(c, rect, CakeVisual.recipe(r.id, toppings: {r.toppings.first: 2})));
        expect(full.bottom, closeTo(art.bottom, tol), reason: '${r.id.name} kem');
        expect(full.top, greaterThanOrEqualTo(0), reason: '${r.id.name} kem');
      }
    }).timeout(const Duration(seconds: 60));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('lớp quét bóng (bơ trứng, nhân táo, nhân sen) giữ màu độ chín: sống sáng hơn, cháy tối hơn bánh chuẩn',
      (tester) async {
    const rect = Rect.fromLTWH(0, 0, 300, 300);
    await tester.runAsync(() async {
      ArtSprites.debugReset();
      for (final id in [RecipeId.croissant, RecipeId.applePie, RecipeId.mooncake]) {
        final r = Catalog.recipe(id);
        await ArtSprites.preload([ArtSprites.baked(r.mould, r.batter, recipe: id)]);
        expect(ArtSprites.baked(r.mould, r.batter, recipe: id).image, isNotNull, reason: id.name);
        Future<double> luma(double baked, double cover) => _meanLuma(
            300,
            (c) => CakeArt.paint(
                c, rect, CakeVisual(mould: r.mould, batter: r.batter, recipe: id, baked: baked, frosting: r.frostings.first, frostCoverage: cover)));
        final raw = await luma(0, 1), ok = await luma(1, 1), burnt = await luma(2, 1);
        expect(raw, greaterThan(ok + 10), reason: '${id.name}: sống $raw, chuẩn $ok');
        expect(burnt, lessThan(ok * 0.8), reason: '${id.name}: cháy $burnt, chuẩn $ok');
        // Lớp bóng có thật: phủ đủ khác chưa phủ.
        expect((await luma(1, 1) - await luma(1, 0)).abs(), greaterThan(1), reason: id.name);
      }
    }).timeout(const Duration(seconds: 60));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('hình code khuôn GĐ8 khớp số đo (bề rộng, đáy) mà game dùng để đặt bánh', (tester) async {
    ArtSprites.debugReset(bundle: _EmptyBundle());
    await tester.runAsync(() async {
      await ArtSprites.preload([for (final r in Catalog.recipes) ArtSprites.baked(r.mould, r.batter, recipe: r.id)]);
      for (final m in _gd8Moulds) {
        final r = Catalog.recipes.firstWhere((r) => r.mould == m);
        const rect = Rect.fromLTWH(0, 0, 400, 400);
        final code = await _alphaBox(400, (c) => CakeArt.paint(c, rect, CakeVisual(mould: m, batter: r.batter, recipe: r.id)));
        final body = CakeArt.artBodyRect(rect, m);
        const tol = 400 * 0.02;
        expect(code.bottom, closeTo(body.bottom, tol), reason: '${m.name} đáy');
        expect(code.bottom, closeTo(200 + CakeArt.bottomFactor(m) * 400, tol), reason: '${m.name} bottomFactor');
        expect(code.top, greaterThanOrEqualTo(body.top - tol), reason: '${m.name} đỉnh');
        expect(code.width / 2, lessThanOrEqualTo(body.width / 2 + tol), reason: '${m.name} bề rộng');
        // Lớp kem kiểu màu nước (dùng khi có ảnh đế) dựng được cho mọi kem của món, không lỗi.
        for (final f in r.frostings) {
          CakeArt.warmFrosting(CakeVisual(mould: m, batter: r.batter, recipe: r.id, frosting: f, frostCoverage: 0.5));
        }
      }
    });
    expect(tester.takeException(), isNull);
  });

  test('l10n: tên món + nguyên liệu GĐ8 không rỗng (en, vi)', () {
    for (final locale in const [ui.Locale('en'), ui.Locale('vi')]) {
      final l = lookupAppLocalizations(locale);
      for (final (id, _, mould, batter, frostings, toppings, _, _, _) in _gd8) {
        expect(l.recipeName(id), isNotEmpty);
        expect(l.recipeDesc(id), isNotEmpty);
        expect(l.mouldName(mould), isNotEmpty);
        expect(l.batterName(batter), isNotEmpty);
        for (final f in frostings) {
          expect(l.frostingName(f), isNotEmpty);
        }
        for (final t in toppings) {
          expect(l.toppingName(t), isNotEmpty);
        }
      }
    }
    // Đã nối khoá .arb thật (không còn chuỗi tạm tiếng Anh).
    final vi = lookupAppLocalizations(const ui.Locale('vi'));
    expect(vi.recipeName(RecipeId.croissant), vi.recipeCroissant);
    expect(vi.recipeName(RecipeId.croissant), isNot('Croissant'));
    expect(vi.toppingName(ToppingId.powderedSugar), vi.toppingPowderedSugar);
    expect(vi.mouldName(MouldType.logPan), vi.mouldLogPan);
  });

  test('bản lưu cũ (10 món) đọc được, không đổi; món mới thuần thục 0; ghi → đọc lại khớp', () {
    final old = {
      'v': GameState.saveVersion,
      'coins': 1234,
      'mastery': {
        'cupcakeVanilla': 3, 'cupcakeChocolate': 2, 'muffinBlueberry': 1, 'eggTart': 0, 'strawberryCake': 1, //
        'macaron': 0, 'redVelvetCupcake': 0, 'matchaCake': 2, 'cheesecake': 0, 'birthdayCake': 1,
      },
    };
    final s = GameState.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>, clock: _clock);
    expect(s.coins, 1234);
    expect(s.recipeMastery(RecipeId.cupcakeVanilla), 3);
    expect(s.recipeMastery(RecipeId.matchaCake), 2);
    expect(s.recipeMastery(RecipeId.birthdayCake), 1);
    for (final (id, _, _, _, _, _, _, _, _) in _gd8) {
      expect(s.recipeMastery(id), 0, reason: id.name);
    }
    final json = s.toJson();
    final mastery = json['mastery'] as Map<String, dynamic>;
    for (final e in (old['mastery']! as Map<String, int>).entries) {
      expect(mastery[e.key], e.value, reason: e.key);
    }
    final back = GameState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>, clock: _clock);
    expect(back.toJson(), json);
  });
}
