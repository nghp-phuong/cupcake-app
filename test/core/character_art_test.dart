import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/characters/character_sprites.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/art/shop_art.dart';
import 'package:sugarleaf_bakery/core/constants.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

/// Bundle rỗng: không có ảnh nào.
class _EmptyBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    throw StateError('Unable to load asset: "$key".');
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async => parser(await loadString(key));
}

/// Có pixel nào không trong suốt.
Future<bool> _anyInk(ui.Picture picture, int w, int h) async {
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData())!;
  image.dispose();
  for (var i = 3; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) != 0) return true;
  }
  return false;
}

/// Vẽ mọi khách / người nói / Mochi vào một Picture 300×400.
ui.Picture _paintAll() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const r = Rect.fromLTWH(0, 0, 300, 400);
  for (final kind in CustomerKind.values) {
    final friend = kind == CustomerKind.friend ? FriendId.linh : null;
    for (final mood in CustomerMood.values) {
      CustomerArt.paint(canvas, r, Customer(kind: kind, friend: friend, appearanceSeed: 123456789), mood: mood);
      CustomerArt.paintMochi(canvas, r, mood: mood);
    }
  }
  for (final s in Speaker.values) {
    CustomerArt.paintSpeaker(canvas, r, s);
  }
  return recorder.endRecording();
}

void main() {
  tearDown(() {
    CharacterSprites.debugReset();
    ArtSprites.debugReset();
  });

  test('vẽ mọi khung (kể cả rỗng / lệch tỉ lệ) không lỗi', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final size in const [Size(72, 96), Size(200, 266), Size(300, 400), Size(0, 0), Size(400, 100)]) {
      final r = Offset.zero & size;
      for (final kind in CustomerKind.values) {
        final friend = kind == CustomerKind.friend ? FriendId.linh : null;
        for (final mood in CustomerMood.values) {
          CustomerArt.paint(canvas, r, Customer(kind: kind, friend: friend, appearanceSeed: 123456789), mood: mood);
        }
      }
      for (final s in Speaker.values) {
        CustomerArt.paintSpeaker(canvas, r, s);
      }
    }
    ShopArt.paint(canvas, kRefSize, {for (final s in DecorSlot.values) s: null});
    ShopArt.paint(canvas, const Size(320, 180), {for (final s in DecorSlot.values) s: null});
    recorder.endRecording().dispose();
  });

  testWidgets('ảnh chưa nạp / thiếu: không vẽ hình nhân vật bằng code — khung trong suốt hoàn toàn', (tester) async {
    CharacterSprites.debugReset(bundle: _EmptyBundle());
    ArtSprites.debugReset(bundle: _EmptyBundle());
    await tester.runAsync(() async {
      // Lần đầu: chưa nạp (vừa xếp hàng) → rỗng.
      expect(await _anyInk(_paintAll(), 300, 400), isFalse);
      // Sau khi xác định thiếu hẳn → vẫn rỗng.
      await CustomerArt.preloadCast();
      await CustomerArt.preloadMochi();
      await CustomerArt.preloadSpeakers(Speaker.values);
      await CustomerArt.preload([for (final k in CustomerKind.values) Customer(kind: k, friend: FriendId.hoa, appearanceSeed: 3)]);
      expect(CustomerArt.narratorBook.isMissing && ArtSprites.book.isMissing, isTrue);
      expect(await _anyInk(_paintAll(), 300, 400), isFalse);
    }).timeout(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('người kể: chưa có ảnh narrator_book → dùng ảnh sổ book; chờ nạp thì không nháy', (tester) async {
    ArtSprites.debugReset();
    await tester.runAsync(() async {
      expect(CustomerArt.narratorImage(), isNull); // đang nạp
      await ArtSprites.preload(CustomerArt.narratorArts);
      final image = CustomerArt.narratorImage();
      expect(image, isNotNull);
      if (CustomerArt.narratorBook.isMissing) {
        expect(image, same(ArtSprites.book.image));
      } else {
        expect(image, same(CustomerArt.narratorBook.image));
      }
      final recorder = ui.PictureRecorder();
      CustomerArt.paintSpeaker(Canvas(recorder), const Rect.fromLTWH(0, 0, 300, 400), Speaker.narrator);
      expect(await _anyInk(recorder.endRecording(), 300, 400), isTrue);
    }).timeout(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  test('khách → id ảnh xác định theo seed, đủ mọi kiểu', () {
    final regular = {for (var s = 0; s < 200; s++) CustomerArt.spriteId(Customer(kind: CustomerKind.regular, appearanceSeed: s))};
    final vip = {for (var s = 0; s < 50; s++) CustomerArt.spriteId(Customer(kind: CustomerKind.vip, appearanceSeed: -s))};
    expect(regular.length, CustomerArt.regularSprites);
    expect(vip.length, CustomerArt.vipSprites);
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.regular, appearanceSeed: 7)), 'regular_07');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.vip, appearanceSeed: -4)), 'vip_01');
  });
}
