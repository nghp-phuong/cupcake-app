import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/characters/character_sprites.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_icon_art.dart' show kSLIconIds;

/// Bundle giả: [files] có trong manifest và đọc được; [broken] có trong manifest nhưng đọc lỗi.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.files, {this.broken = const {}, this.onLoad});

  final Map<String, Uint8List> files;
  final Set<String> broken;
  final void Function(String key)? onLoad;

  @override
  Future<ByteData> load(String key) async {
    onLoad?.call(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in [...files.keys, ...broken]) k: [
          {'asset': k},
        ],
      })!;
    }
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(bytes);
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async => parser(await loadString(key));
}

/// Mọi ảnh mà các hàm tra theo enum có thể trả về.
List<ArtRef> _allTypedRefs() => [
      for (final r in RecipeId.values) ArtSprites.cake(r),
      for (final m in MouldType.values) ArtSprites.mould(m),
      for (final b in BatterType.values) ArtSprites.batter(b),
      // Khuôn có ảnh đế gốc × mọi bột; khuôn GĐ8 chỉ có ảnh đế theo món.
      for (final m in MouldType.values)
        if (ArtSprites.ids[ArtGroup.baked]!.contains(m.name))
          for (final b in BatterType.values) ArtSprites.baked(m, b),
      for (final r in Catalog.recipes) ArtSprites.baked(r.mould, r.batter, recipe: r.id),
      for (final f in FrostingId.values) ArtSprites.frosting(f),
      for (final t in ToppingId.values) ArtSprites.topping(t),
      for (final b in BoxType.values) ...[ArtSprites.box(b), ArtSprites.box(b, open: true)],
      for (final d in DecorId.values) ArtSprites.decor(d),
      for (var l = 0; l <= ArtSprites.ovenLevels + 1; l++) ArtSprites.oven(l),
      for (final t in ToolId.values) ArtSprites.tool(t),
      ArtSprites.coin, ArtSprites.gem, ArtSprites.starOn, ArtSprites.starOff, //
      ArtSprites.ticket, ArtSprites.book, ArtSprites.giftDaily, ArtSprites.bowl, //
      ArtSprites.bakingTray, ArtSprites.servingPlate, ArtSprites.pantrySack, ArtSprites.noAdsBadge,
      for (final s in ArtScene.values) ArtSprites.scene(s),
      ArtSprites.shopBase,
      ArtSprites.shopBaseEmpty,
      for (final s in StationId.values) ArtSprites.station(s),
    ];

Future<int> _alphaAt(ui.Picture picture, int w, int h, int x, int y) async {
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData())!;
  image.dispose();
  return data.getUint8((y * w + x) * 4 + 3);
}

void main() {
  tearDown(ArtSprites.debugReset);

  test('ánh xạ enum → id ảnh', () {
    for (final r in RecipeId.values) {
      expect(ArtSprites.cake(r), ArtRef(ArtGroup.cakes, r.name));
      expect(ArtSprites.ids[ArtGroup.cakes], contains(r.name));
    }
    // Mọi món trong Catalog có ảnh bánh.
    for (final recipe in Catalog.recipes) {
      expect(ArtSprites.ids[ArtGroup.cakes], contains(ArtSprites.cake(recipe.id).id));
    }
    for (final d in DecorId.values) {
      final ref = ArtSprites.decor(d);
      final tile = d.name.startsWith('wallpaper') || d.name.startsWith('floor');
      expect(ref.group, tile ? ArtGroup.tiles : ArtGroup.decor, reason: d.name);
      expect(ref.id, d.name);
      expect(ArtSprites.ids[ref.group], contains(d.name));
    }

    // Đế nướng: biến thể theo bột nếu có, không thì ảnh gốc của khuôn.
    expect(ArtSprites.baked(MouldType.cupcakeLiner, BatterType.chocolate).id, 'cupcakeLiner_chocolate');
    expect(ArtSprites.baked(MouldType.cupcakeLiner, BatterType.redVelvet).id, 'cupcakeLiner_redVelvet');
    expect(ArtSprites.baked(MouldType.cupcakeLiner, BatterType.vanilla).id, 'cupcakeLiner');
    expect(ArtSprites.baked(MouldType.roundPan, BatterType.matcha).id, 'roundPan_matcha');
    expect(ArtSprites.baked(MouldType.roundPan, BatterType.vanilla).id, 'roundPan');
    expect(ArtSprites.baked(MouldType.muffinCup, BatterType.chocolate).id, 'muffinCup');
    expect(ArtSprites.baked(MouldType.tallPan, BatterType.matcha).id, 'tallPan');
    for (final recipe in Catalog.recipes) {
      expect(ArtSprites.baked(recipe.mould, recipe.batter).id, startsWith(recipe.mould.name));
    }

    // Lò 1..5, ngoài khoảng kẹp lại.
    expect([for (var l = 1; l <= 5; l++) ArtSprites.oven(l).id], ['oven_1', 'oven_2', 'oven_3', 'oven_4', 'oven_5']);
    expect(ArtSprites.oven(0).id, 'oven_1');
    expect(ArtSprites.oven(9).id, 'oven_5');

    expect(ArtSprites.box(BoxType.gift).id, 'gift_closed');
    expect(ArtSprites.box(BoxType.small, open: true).id, 'small_open');
    expect(ArtSprites.tool(ToolId.pipingBag).id, 'tool_pipingBag');
    expect(ArtSprites.station(StationId.topping), const ArtRef(ArtGroup.kitchen, 'station_topping'));
    expect(ArtSprites.scene(ArtScene.daySummary).id, 'day_summary_bg');
    expect(ArtSprites.star(), ArtSprites.starOn);
    expect(ArtSprites.star(filled: false), ArtSprites.starOff);
    expect(ArtSprites.bakingTray.assetPath, 'assets/art/items/baking_tray.webp');
    expect(ArtSprites.servingPlate.assetPath, 'assets/art/items/plate_serving.webp');
    expect(ArtSprites.pantrySack.assetPath, 'assets/art/items/pantry_sack.webp');
    expect(ArtSprites.noAdsBadge.assetPath, 'assets/art/items/no_ads_badge.webp');
    expect(ArtSprites.cake(RecipeId.macaron).assetPath, 'assets/art/cakes/macaron.webp');
    expect(ArtSprites.decor(DecorId.floorCheckered).assetPath, 'assets/art/tiles/floorCheckered.webp');

    // Mọi id tra theo enum đều nằm trong danh mục ảnh.
    for (final ref in _allTypedRefs()) {
      expect(ArtSprites.ids[ref.group], contains(ref.id), reason: '$ref');
    }
  });

  test('mọi ảnh trong danh mục có trên đĩa, khai báo trong pubspec, không thừa file', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final g in ArtGroup.values) {
      final listed = ArtSprites.ids[g]!.toSet();
      expect(listed.length, ArtSprites.ids[g]!.length, reason: 'id trùng trong ${g.name}');
      if (g.isPending) {
        // Nhóm chưa có ảnh: chưa khai báo trong pubspec; có ảnh rồi thì phải bỏ isPending.
        expect(pubspec, isNot(contains('- ${g.dir}\n')), reason: '${g.name} đã khai báo → bỏ isPending');
        final dir = Directory(g.dir);
        expect(dir.existsSync() && dir.listSync().any((f) => f.path.endsWith('.webp')), isFalse,
            reason: '${g.dir} đã có ảnh → khai báo trong pubspec và bỏ isPending');
        continue;
      }
      expect(pubspec, contains('- ${g.dir}\n'), reason: 'pubspec thiếu ${g.dir}');
      // Ảnh đang chờ vẽ (pendingIds): có thể chưa có file.
      final pending = ArtSprites.pendingIds[g] ?? const <String>{};
      expect(listed.containsAll(pending), isTrue, reason: 'pendingIds phải nằm trong ids (${g.name})');
      for (final ref in ArtSprites.group(g)) {
        if (pending.contains(ref.id)) continue;
        expect(File(ref.assetPath).existsSync(), isTrue, reason: ref.assetPath);
      }
      final onDisk = {
        for (final f in Directory(g.dir).listSync().whereType<File>())
          if (f.path.endsWith('.webp')) f.uri.pathSegments.last.replaceAll('.webp', ''),
      };
      expect(onDisk.difference(pending), listed.difference(pending), reason: g.name);
    }
    for (final ref in _allTypedRefs()) {
      if (ArtSprites.pendingIds[ref.group]?.contains(ref.id) ?? false) continue;
      expect(File(ref.assetPath).existsSync(), isTrue, reason: ref.assetPath);
    }
    for (final e in CharacterSprites.expressions) {
      expect(File(CharacterSprites.assetPath(CustomerArt.mochiSpriteId, e)).existsSync(), isTrue);
    }
  });

  testWidgets('thiếu file hoặc đọc lỗi: không ném lỗi, đánh dấu thiếu, không log ồn', (tester) async {
    ArtSprites.debugReset(bundle: _FakeBundle(const {}, broken: {'assets/art/cakes/macaron.webp'}));
    final logs = <String?>[];
    final saved = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    try {
      await tester.runAsync(() async {
        expect(ArtSprites.image(ArtGroup.cakes, 'ghost'), isNull);
        await ArtSprites.preload([const ArtRef(ArtGroup.cakes, 'ghost'), ArtSprites.cake(RecipeId.macaron)]);
      });
    } finally {
      debugPrint = saved;
    }
    expect(ArtSprites.isMissing(ArtGroup.cakes, 'ghost'), isTrue);
    expect(ArtSprites.cake(RecipeId.macaron).isMissing, isTrue);
    expect(logs.length, lessThanOrEqualTo(1));
    expect(ArtSprites.cake(RecipeId.macaron).image, isNull);
    expect(ArtSprites.debugCachedCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon giao diện: chưa có ảnh → null/thiếu, không ném lỗi, không log, không đọc bundle', (tester) async {
    const expected = [
      'settings', 'close', 'back', 'forward', 'arrow_up', 'arrow_down', 'skip', 'exit', 'check', 'lock', //
      'info', 'warning', 'error', 'medal_max', 'sound_on', 'sound_off', 'language', 'phone', 'trash', 'reset', //
      'play_video', 'no_ads', 'shop_bag', 'basket', 'quest_board', 'decor_chair', 'slot_wallpaper', 'slot_floor', //
      'slot_counter', 'slot_window', 'slot_plant', 'heart', 'vip', 'customer', 'sun', 'umbrella', 'raindrop', 'paw', //
      'moon', 'flame', 'sparkle', 'trophy', 'confetti', 'clock', 'tip_jar', 'bulb', 'leaf_logo', 'pin', 'plus', //
      'cake_slice', 'book', 'star', 'oven', 'gift', 'tap', 'storefront', 'coin', 'ticket',
    ];
    expect(expected.length, 58);
    expect(ArtSprites.ids[ArtGroup.icons], expected);
    // Cùng tập id với bộ icon vẽ bằng code của giao diện (tên file ảnh vẽ tay tương lai).
    expect(ArtSprites.ids[ArtGroup.icons]!.toSet(), kSLIconIds.toSet());
    expect(ArtSprites.icon('settings'), const ArtRef(ArtGroup.icons, 'settings'));
    expect(ArtSprites.icon('tip_jar').assetPath, 'assets/art/icons/tip_jar.webp');
    expect(ArtGroup.icons.maxDecodeSide, 192);
    expect(ArtGroup.icons.isLarge, isFalse);

    final reads = <String>[];
    ArtSprites.debugReset(bundle: _FakeBundle(const {}, onLoad: reads.add));
    final logs = <String?>[];
    final saved = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    try {
      await tester.runAsync(() async {
        for (final id in expected) {
          expect(ArtSprites.icon(id).image, isNull);
          expect(ArtSprites.icon(id).isMissing, isTrue);
        }
        await ArtSprites.preloadIcons();
        await ArtSprites.preload(ArtSprites.group(ArtGroup.icons));
      });
    } finally {
      debugPrint = saved;
    }
    expect(logs, isEmpty);
    expect(reads, isEmpty);
    expect(ArtSprites.icon('ghost').image, isNull);
    expect(ArtSprites.debugCachedCount, 0);
    // preloadStartup không kéo nhóm icon vào.
    await tester.runAsync(ArtSprites.preloadStartup);
    expect(reads.where((k) => k.startsWith('assets/art/icons/')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ảnh thật giải mã được, báo vẽ lại; topping giải mã 256 px', (tester) async {
    ArtSprites.debugReset();
    var pings = 0;
    void listener() => pings++;
    ArtSprites.changes.addListener(listener);
    addTearDown(() => ArtSprites.changes.removeListener(listener));

    final refs = [ArtSprites.cake(RecipeId.cupcakeVanilla), ArtSprites.topping(ToppingId.cherry), ArtSprites.decor(DecorId.wallpaperFloral), ArtSprites.station(StationId.bake)];
    await tester.runAsync(() => ArtSprites.preload(refs));
    expect(pings, refs.length);
    final cake = refs[0].image!;
    expect((cake.width, cake.height), (512, 512));
    final topping = refs[1].image!;
    expect((topping.width, topping.height), (256, 256));
    final station = refs[3].image!;
    expect((station.width, station.height), (1280, 720));
    expect(ArtSprites.debugCachedBytes(large: true), 1280 * 720 * 4);
    expect(ArtSprites.debugCachedBytes(large: false), 512 * 512 * 4 * 2 + 256 * 256 * 4);

    // paintArt (cover): ảnh nền phủ kín khung.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    paintArt(canvas, const Rect.fromLTWH(0, 0, 200, 100), station, fit: BoxFit.cover);
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      expect(await _alphaAt(picture, 200, 100, 2, 2), 255);
      expect(await _alphaAt(picture, 200, 100, 198, 98), 255);
    });
    // paintArtTiled: hoạ tiết (không trong suốt) phủ kín vùng.
    final r2 = ui.PictureRecorder();
    paintArtTiled(ui.Canvas(r2), const Rect.fromLTWH(0, 0, 120, 80), refs[2].image!, tileSize: 32);
    final p2 = r2.endRecording();
    await tester.runAsync(() async {
      expect(await _alphaAt(p2, 120, 80, 1, 1), 255);
      expect(await _alphaAt(p2, 120, 80, 118, 78), 255);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache ảnh nền giới hạn theo byte (LRU)', (tester) async {
    ArtSprites.debugReset();
    final large = [...ArtSprites.group(ArtGroup.kitchen), ...ArtSprites.group(ArtGroup.scenes), ArtSprites.shopBase];
    await tester.runAsync(() => ArtSprites.preload(large));
    expect(ArtSprites.debugCachedBytes(large: true), lessThanOrEqualTo(ArtSprites.largeCacheBytes));
    expect(ArtSprites.debugCachedBytes(large: true), greaterThan(ArtSprites.largeCacheBytes - 1280 * 720 * 4));
    // Ảnh nạp gần nhất còn trong cache; ảnh đầu tiên đã bị đẩy ra, nạp lại được.
    expect(ArtSprites.debugIsCached(ArtSprites.shopBase), isTrue);
    expect(ArtSprites.debugIsCached(ArtSprites.station(StationId.mould)), isFalse);
    await tester.runAsync(() => ArtSprites.preload([ArtSprites.station(StationId.mould)]));
    expect(ArtSprites.station(StationId.mould).image, isNotNull);
    expect(ArtSprites.debugCachedBytes(large: false), 0);
  });

  testWidgets('Mochi: ảnh vẽ tay qua CharacterSprites, thiếu ảnh thì không vẽ gì (không có hình code)', (tester) async {
    CharacterSprites.debugReset(bundle: _FakeBundle(const {}));
    addTearDown(CharacterSprites.debugReset);
    for (final mood in CustomerMood.values) {
      final recorder = ui.PictureRecorder();
      // Gọi trong runAsync: lần vẽ đầu xếp hàng nạp ảnh (I/O thật, không chạy được trong fake async).
      await tester.runAsync(() async {
        CustomerArt.paintMochi(ui.Canvas(recorder), const Rect.fromLTWH(0, 0, 300, 400), mood: mood);
      });
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        expect(await _alphaAt(picture, 300, 400, 150, 330), 0);
        expect(await _alphaAt(picture, 300, 400, 150, 5), 0);
      });
    }
    CharacterSprites.debugReset();
    await tester.runAsync(CustomerArt.preloadMochi);
    final img = CharacterSprites.image(CustomerArt.mochiSpriteId, 'neutral');
    expect(img, isNotNull);
    expect((img!.width, img.height), (480, 640));
    final recorder = ui.PictureRecorder();
    CustomerArt.paintMochi(ui.Canvas(recorder), const Rect.fromLTWH(0, 0, 300, 400));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(300, 400);
      final data = (await image.toByteData())!;
      image.dispose();
      var ink = 0;
      for (var i = 3; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 0) ink++;
      }
      expect(ink, greaterThan(300 * 400 * 0.1)); // ảnh Mochi đã vẽ
    });
    expect(tester.takeException(), isNull);
  });

  test('danh sách nạp trước: theo trạm, cả bếp (trạm 1 đứng đầu)', () {
    // Trạm 1: nền + mọi khuôn + khay nướng, nền đứng đầu.
    final mould = ArtSprites.stationRefs(StationId.mould);
    expect(mould.first, ArtSprites.station(StationId.mould));
    expect(mould.skip(1).toSet(), {...ArtSprites.group(ArtGroup.moulds), ArtSprites.bakingTray});
    // Trạm 3–6 có đế đã nướng của món khi biết khuôn.
    for (final s in [StationId.bake, StationId.frost, StationId.topping, StationId.box]) {
      final refs = ArtSprites.stationRefs(s, ovenLevel: 3, mould: MouldType.roundPan, batter: BatterType.matcha);
      expect(refs.first, ArtSprites.station(s));
      expect(refs, contains(ArtSprites.baked(MouldType.roundPan, BatterType.matcha)), reason: '$s');
      expect(ArtSprites.stationRefs(s).any((r) => r.group == ArtGroup.baked), isFalse, reason: '$s');
    }
    expect(ArtSprites.stationRefs(StationId.bake, ovenLevel: 3), contains(ArtSprites.oven(3)));
    expect(ArtSprites.stationRefs(StationId.mix), containsAll([ArtSprites.bowl, ArtSprites.tool(ToolId.whisk), ...ArtSprites.group(ArtGroup.batter)]));
    expect(ArtSprites.stationRefs(StationId.frost), containsAll([ArtSprites.tool(ToolId.pipingBag), ...ArtSprites.group(ArtGroup.frosting)]));
    expect(ArtSprites.stationRefs(StationId.topping), containsAll([ArtSprites.tool(ToolId.tongs), ArtSprites.servingPlate, ...ArtSprites.group(ArtGroup.toppings)]));
    expect(ArtSprites.stationRefs(StationId.box), containsAll([ArtSprites.servingPlate, ...ArtSprites.group(ArtGroup.boxes)]));
    // Mọi ảnh của mọi trạm đều có trong danh mục.
    for (final s in StationId.values) {
      for (final ref in ArtSprites.stationRefs(s, mould: MouldType.cupcakeLiner)) {
        expect(ArtSprites.ids[ref.group], contains(ref.id), reason: '$ref');
      }
    }
  });

  testWidgets('preloadKitchen: trạm 1 nạp trước; preloadStation chờ được đủ ảnh trạm', (tester) async {
    final order = <String>[];
    ArtSprites.debugReset(bundle: _FakeBundle(const {}, onLoad: order.add));
    await tester.runAsync(() async {
      final all = ArtSprites.preloadKitchen(mould: MouldType.cupcakeLiner);
      await ArtSprites.preloadStation(StationId.mould);
      for (final ref in ArtSprites.stationRefs(StationId.mould)) {
        expect(ref.isMissing, isTrue, reason: '$ref'); // bundle rỗng: đã xác định xong (thiếu).
      }
      await all;
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('preloadStartup nạp nền sân tiệm của màn level (ảnh thật)', (tester) async {
    ArtSprites.debugReset();
    await tester.runAsync(ArtSprites.preloadStartup);
    expect(ArtSprites.debugIsCached(ArtSprites.shopBaseEmpty), isTrue);
    expect(ArtSprites.debugIsCached(ArtSprites.shopBase), isFalse);
    expect(ArtSprites.debugIsCached(ArtSprites.book), isTrue);
    // narrator_book đang chờ vẽ: thiếu thì được đánh dấu thiếu êm.
    expect(ArtSprites.debugIsCached(CustomerArt.narratorBook) || CustomerArt.narratorBook.isMissing, isTrue);
  });
}
