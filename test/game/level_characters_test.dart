import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';

// Cache ảnh nhân vật của màn chơi level: rút hàng chờ khi retainOnly, cỡ giải mã theo hệ số màn.

String _id(int i) => 'regular_${i.toString().padLeft(2, '0')}';

/// Bundle thật, nhưng ảnh nhân vật chỉ trả về khi mở [gate]; ghi lại các ảnh đã được xin nạp.
class _GatedBundle extends AssetBundle {
  final requested = <String>[];
  Completer<void> gate = Completer<void>();

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/characters/')) {
      requested.add(key);
      await gate.future;
    }
    return rootBundle.load(key);
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) =>
      rootBundle.loadStructuredData(key, parser);

  @override
  Future<T> loadStructuredBinaryData<T>(String key, FutureOr<T> Function(ByteData data) parser) =>
      rootBundle.loadStructuredBinaryData(key, parser);
}

/// Chờ tới khi [done] (tối đa [sec] giây thật).
Future<void> _until(bool Function() done, {double sec = 20}) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsedMilliseconds > sec * 1000) fail('quá giờ chờ');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(LevelCharacters.debugReset);

  test('retainOnly rút ảnh ngoài dàn nhân vật khỏi hàng chờ (không nạp tiếp), ảnh đang giải mã bị bỏ khi xong', () async {
    final bundle = _GatedBundle();
    LevelCharacters.debugReset(bundle: bundle, pixelScale: 1);
    final done = LevelCharacters.preload([
      for (var i = 0; i < 12; i++) (_id(i), LevelCharacters.neutral),
      (_id(0), LevelCharacters.joy),
    ]);
    // Hai ảnh đầu đang giải mã (chờ cổng), 11 ảnh còn trong hàng.
    await _until(() => bundle.requested.length == 2);
    expect(LevelCharacters.debugQueuedCount, 11);

    LevelCharacters.retainOnly({_id(0)});
    expect(LevelCharacters.debugQueuedCount, 1, reason: 'chỉ còn regular_00_joy');

    bundle.gate.complete();
    await done.timeout(const Duration(seconds: 20));
    expect(bundle.requested, [
      'assets/characters/regular_00_neutral.webp',
      'assets/characters/regular_01_neutral.webp',
      'assets/characters/regular_00_joy.webp',
    ]);
    expect(LevelCharacters.debugQueuedCount, 0);
    // regular_01 đang giải mã lúc bị bỏ → giải phóng, không giữ.
    expect(LevelCharacters.debugCachedCount, 2);
    expect(LevelCharacters.cached(_id(1), LevelCharacters.neutral), isNull);
    expect(LevelCharacters.isMissing(_id(1), LevelCharacters.neutral), isFalse);
    expect(LevelCharacters.cached(_id(0), LevelCharacters.joy), isNotNull);
  });

  test('ảnh bị bỏ lúc đang giải mã nhưng được xin lại → vẫn giữ', () async {
    final bundle = _GatedBundle();
    LevelCharacters.debugReset(bundle: bundle, pixelScale: 1);
    unawaited(LevelCharacters.preload([(_id(3), LevelCharacters.neutral)]));
    await _until(() => bundle.requested.length == 1);
    LevelCharacters.retainOnly({_id(0)});
    final again = LevelCharacters.preload([(_id(3), LevelCharacters.neutral)], urgent: true);
    bundle.gate.complete();
    await again.timeout(const Duration(seconds: 20));
    expect(LevelCharacters.cached(_id(3), LevelCharacters.neutral), isNotNull);
    expect(bundle.requested.length, 1);
  });

  test('hệ số màn: min(rộng/1280, cao/720), lên bậc 0.2, kẹp 1.0..1.6', () {
    double k(double w, double h) => LevelCharacters.scaleFor(ui.Size(w, h));
    expect(k(0, 0), 1.0);
    expect(k(800, 450), 1.0);
    expect(k(1280, 720), 1.0);
    expect(k(1600, 720), 1.0); // máy 720p
    expect(k(1536, 864), 1.2);
    expect(k(1700, 900), 1.4); // 1.25 → bậc trên
    expect(k(2400, 1080), 1.6); // máy 1080p: 1.5 → 1.6
    expect(k(1920, 1080), 1.6);
    expect(k(3840, 2160), 1.6); // 4K: kẹp
  });

  test('cỡ giải mã theo hệ số màn; sang bậc khác mới giải mã lại', () async {
    final bundle = _GatedBundle()..gate.complete();
    LevelCharacters.debugReset(bundle: bundle, pixelScale: 1);
    final sprite = (_id(2), LevelCharacters.neutral);
    await LevelCharacters.preload([sprite]).timeout(const Duration(seconds: 20));
    expect(LevelCharacters.cached(sprite.$1, sprite.$2)!.height, LevelCharacters.refDecodeHeight);

    LevelCharacters.updatePixelScale(const ui.Size(1920, 1080));
    expect(LevelCharacters.pixelScale, 1.6);
    await _until(() => LevelCharacters.cached(sprite.$1, sprite.$2)!.height != LevelCharacters.refDecodeHeight);
    expect(LevelCharacters.cached(sprite.$1, sprite.$2)!.height, (LevelCharacters.refDecodeHeight * 1.6).round());
    expect(bundle.requested.length, 2);

    // Cùng bậc (đổi cỡ cửa sổ nhẹ) → không giải mã lại.
    final gen = LevelCharacters.generation;
    LevelCharacters.updatePixelScale(const ui.Size(2000, 1100));
    expect(LevelCharacters.debugQueuedCount, 0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(LevelCharacters.generation, gen);
    expect(bundle.requested.length, 2);
  });
}
