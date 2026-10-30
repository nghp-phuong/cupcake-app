import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/characters/character_sprites.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

/// Bundle giả: [files] có trong manifest và đọc được; [broken] có trong manifest nhưng đọc lỗi.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.files, {this.broken = const {}});

  final Map<String, Uint8List> files;
  final Set<String> broken;

  @override
  Future<ByteData> load(String key) async {
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

/// PNG đặc màu 6×8 (tỉ lệ 3:4).
Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 6, 8), ui.Paint()..color = const ui.Color(0xFFE86A5C));
  final image = await recorder.endRecording().toImage(6, 8);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<int> _alphaAt(ui.Picture picture, int x, int y) async {
  final image = await picture.toImage(300, 400);
  final data = (await image.toByteData())!;
  image.dispose();
  return data.getUint8((y * 300 + x) * 4 + 3);
}

void main() {
  tearDown(CharacterSprites.debugReset);

  test('ánh xạ khách / người nói → id ảnh', () {
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.friend, friend: FriendId.hoa, appearanceSeed: 9)), 'hoa');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.friend, friend: FriendId.linh, appearanceSeed: 9)), 'linh');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.friend, friend: FriendId.kenji, appearanceSeed: 9)), 'kenji');
    // Bạn quen thiếu friend → vẽ như khách thường.
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.friend, appearanceSeed: 3)), 'regular_03');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.regular, appearanceSeed: 3)), 'regular_03');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.regular, appearanceSeed: 29)), 'regular_14');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.regular, appearanceSeed: -16)), 'regular_01');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.vip, appearanceSeed: 4)), 'vip_01');
    expect(CustomerArt.spriteId(const Customer(kind: CustomerKind.vip, appearanceSeed: -5)), 'vip_02');
    expect(CustomerArt.speakerSpriteId(Speaker.narrator), isNull);
    expect([for (final s in Speaker.values.skip(1)) CustomerArt.speakerSpriteId(s)], ['mai', 'hoa', 'linh', 'kenji', 'vip_00']);

    // id theo seed: chia đều cho số kiểu ảnh.
    for (var seed = -40; seed < 200; seed++) {
      final regular = CustomerArt.spriteId(Customer(kind: CustomerKind.regular, appearanceSeed: seed));
      expect(regular, 'regular_${(seed.abs() % CustomerArt.regularSprites).toString().padLeft(2, '0')}');
      final vip = CustomerArt.spriteId(Customer(kind: CustomerKind.vip, appearanceSeed: seed));
      expect(vip, 'vip_${(seed.abs() % CustomerArt.vipSprites).toString().padLeft(2, '0')}');
    }

    // Mọi id game sinh ra đều nằm trong bộ 22 nhân vật có ảnh.
    final expected = {
      'mai', 'hoa', 'linh', 'kenji',
      for (var i = 0; i < 15; i++) 'regular_${i.toString().padLeft(2, '0')}',
      for (var i = 0; i < 3; i++) 'vip_0$i',
    };
    final produced = {
      for (final kind in CustomerKind.values)
        for (var seed = 0; seed < 300; seed++)
          CustomerArt.spriteId(Customer(kind: kind, friend: kind == CustomerKind.friend ? FriendId.values[seed % 3] : null, appearanceSeed: seed)),
      for (final s in Speaker.values) ?CustomerArt.speakerSpriteId(s),
    };
    expect(produced, expected);
  });

  test('ánh xạ tâm trạng / Expression → nét mặt trong tên file', () {
    expect([for (final m in CustomerMood.values) CustomerArt.spriteExpr(CustomerArt.expressionFor(m))], ['neutral', 'joy', 'sad']);
    expect([for (final e in Expression.values) CustomerArt.spriteExpr(e)], CharacterSprites.expressions);
    expect(CustomerArt.speakerExpression(Speaker.mai), Expression.smile);
    expect(CustomerArt.speakerExpression(Speaker.hoa), Expression.smile);
    expect(CustomerArt.speakerExpression(Speaker.linh), Expression.smile);
    expect(CustomerArt.speakerExpression(Speaker.kenji), Expression.neutral);
    expect(CharacterSprites.assetPath('regular_07', 'joy'), 'assets/characters/regular_07_joy.webp');
  });

  testWidgets('thiếu file hoặc đọc lỗi: không ném lỗi, đánh dấu thiếu, không vẽ gì', (tester) async {
    CharacterSprites.debugReset(bundle: _FakeBundle(const {}, broken: {'assets/characters/regular_03_neutral.webp'}));
    final logs = <String?>[];
    final saved = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    try {
      await tester.runAsync(() async {
        expect(CharacterSprites.image('ghost', 'neutral'), isNull);
        await CharacterSprites.preload([('ghost', 'neutral'), ('regular_03', 'neutral')]);
      });
    } finally {
      debugPrint = saved;
    }
    expect(CharacterSprites.isMissing('ghost', 'neutral'), isTrue);
    expect(CharacterSprites.isMissing('regular_03', 'neutral'), isTrue);
    // Thiếu file: im lặng; đọc lỗi: tối đa một dòng.
    expect(logs.length, lessThanOrEqualTo(1));
    expect(CharacterSprites.image('ghost', 'neutral'), isNull);
    expect(CharacterSprites.debugCachedCount, 0);

    // Không có hình nhân vật vẽ bằng code: thiếu ảnh → khung trong suốt.
    final recorder = ui.PictureRecorder();
    CustomerArt.paint(ui.Canvas(recorder), const ui.Rect.fromLTWH(0, 0, 300, 400), const Customer(kind: CustomerKind.regular, appearanceSeed: 3));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      for (final (x, y) in const [(150, 10), (150, 300), (150, 398), (5, 300)]) {
        expect(await _alphaAt(picture, x, y), 0);
      }
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('nạp ảnh: báo vẽ lại, vẽ ảnh vừa khung, cache LRU giới hạn', (tester) async {
    final png = (await tester.runAsync(_png))!;
    final ids = [for (var i = 0; i < 15; i++) 'regular_${i.toString().padLeft(2, '0')}'];
    final files = {
      for (final id in ids)
        for (final e in const ['neutral', 'joy']) CharacterSprites.assetPath(id, e): png,
      CharacterSprites.assetPath('mai', 'smile'): png,
    };
    CharacterSprites.debugReset(bundle: _FakeBundle(files));
    var pings = 0;
    void listener() => pings++;
    CustomerArt.repaint.addListener(listener);
    addTearDown(() => CustomerArt.repaint.removeListener(listener));

    await tester.runAsync(() => CharacterSprites.preload([('regular_03', 'neutral')]));
    expect(pings, 1);
    final img = CharacterSprites.image('regular_03', 'neutral')!;
    expect((img.width, img.height), (6, 8));
    // Nét mặt chưa nạp → tạm dùng nét mặt khác của cùng nhân vật (và xếp hàng nạp).
    await tester.runAsync(() async {
      expect(CharacterSprites.image('regular_03', 'joy'), same(img));
      await CharacterSprites.preload([('regular_03', 'joy')]);
    });
    expect(CharacterSprites.image('regular_03', 'joy'), isNot(same(img)));

    // Ảnh đã nạp được vẽ phủ đúng khung 3:4 (đỉnh khung có màu).
    final recorder = ui.PictureRecorder();
    CustomerArt.paint(ui.Canvas(recorder), const ui.Rect.fromLTWH(0, 0, 300, 400), const Customer(kind: CustomerKind.regular, appearanceSeed: 3));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      expect(await _alphaAt(picture, 150, 2), 255);
      expect(await _alphaAt(picture, 2, 398), 255);
    });

    // Chân dung người nói (nửa trên ảnh) cũng vẽ được từ ảnh.
    await tester.runAsync(() => CustomerArt.preloadCast());
    expect(CharacterSprites.isMissing('mai', 'neutral'), isTrue);
    final r2 = ui.PictureRecorder();
    CustomerArt.paintSpeaker(ui.Canvas(r2), const ui.Rect.fromLTWH(0, 0, 300, 400), Speaker.mai);
    final p2 = r2.endRecording();
    await tester.runAsync(() async => expect(await _alphaAt(p2, 150, 2), 255));

    // Nạp nhiều hơn giới hạn → cache không vượt cacheLimit.
    await tester.runAsync(() => CustomerArt.preload([for (var s = 0; s < 15; s++) Customer(kind: CustomerKind.regular, appearanceSeed: s)]));
    expect(CharacterSprites.debugCachedCount, CharacterSprites.cacheLimit);
    expect(pings, greaterThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ảnh thật trong assets/characters giải mã được (480×640)', (tester) async {
    CharacterSprites.debugReset();
    await tester.runAsync(() => CharacterSprites.preload([('mai', 'smile')]));
    final img = CharacterSprites.image('mai', 'smile');
    expect(img, isNotNull);
    expect((img!.width, img.height), (480, 640));
  });
}
