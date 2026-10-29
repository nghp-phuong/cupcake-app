import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/components/effects.dart';
import 'package:sugarleaf_bakery/game/components/hand_paint.dart';
import 'package:sugarleaf_bakery/game/stations/bake_station.dart';
import 'package:sugarleaf_bakery/game/stations/box_station.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/game/stations/station.dart';
import 'package:sugarleaf_bakery/game/stations/topping_station.dart';

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2), ToppingRequest(ToppingId.sprinkles, 1)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

/// Vẽ một khung của trạm vào Picture (đúng việc của luồng UI khi vẽ khung).
void _paint(Station s) {
  final recorder = PictureRecorder();
  s.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  final game = BakeryGame(order: _order, modifiers: BakeModifiers.base);
  final stations = <String, Station Function()>{
    'khuôn': () => MouldStation(game),
    'trộn': () => MixStation(game),
    'nướng': () => BakeStation(game),
    'phủ kem': () => FrostStation(game),
    'topping': () => ToppingStation(game),
    'hộp': () => BoxStation(game),
  };

  test('hình vẽ tay của trạm dựng một lần: khung sau (cache nóng) không dựng thêm hình nào', () {
    for (final MapEntry(key: name, value: create) in stations.entries) {
      final s = create()..update(1);
      _paint(s);
      final misses = gameArtCache.misses;
      for (var i = 0; i < 5; i++) {
        s.update(1 / 60);
        _paint(s);
      }
      expect(gameArtCache.misses, misses, reason: name);
    }
  });

  test('nút Giữ: giữ / thả chỉ đổi giữa các mặt nút đã dựng (không dựng lại mỗi khung)', () {
    final s = BakeStation(game)..update(1);
    s.pointerDown(BakeStation.buttonCenter);
    for (var i = 0; i < 20; i++) {
      s.update(1 / 60);
      _paint(s);
    }
    final misses = gameArtCache.misses;
    for (var i = 0; i < 30; i++) {
      s.update(1 / 60);
      _paint(s);
    }
    expect(gameArtCache.misses, misses);
  });

  test('đo thời gian vẽ một khung (cache nóng) của từng trạm', () {
    // Khung đầu tiên của mỗi trạm khi cache trống (dựng hình vẽ tay của trạm).
    final cold = <String, double>{};
    for (final MapEntry(key: name, value: create) in stations.entries) {
      gameArtCache.clear();
      final s = create()..update(1);
      final sw = Stopwatch()..start();
      _paint(s);
      cold[name] = sw.elapsedMicroseconds / 1000;
    }
    // ignore: avoid_print
    print('Khung đầu, cache trống (ms): ${cold.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}').join(' · ')}');
    final results = <String, double>{};
    for (final name in stations.keys) {
      final s = stations[name]!()..update(1);
      for (var i = 0; i < 30; i++) {
        _paint(s); // làm nóng cache + JIT.
      }
      const frames = 200;
      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        s.update(1 / 60);
        _paint(s);
      }
      results[name] = sw.elapsedMicroseconds / frames / 1000;
    }
    // ignore: avoid_print
    print('Ghi lệnh vẽ một khung (ms, cache nóng, máy test): '
        '${results.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(3)}').join(' · ')}');
    for (final e in results.entries) {
      expect(e.value, lessThan(8), reason: '${e.key}: ${e.value} ms');
    }
  });

  test('hiệu ứng vẽ tay: hình dựng sẵn, đo thời gian vẽ một khung đông hạt', () {
    final fx = EffectsLayer();
    void burst() {
      fx
        ..sparkle(const Offset(400, 300), count: 24)
        ..hearts(const Offset(400, 200))
        ..puff(const Offset(300, 200), const Color(0xFF9A918A), count: 6, size: 26, rise: 60)
        ..bits(const Offset(500, 300), const [Color(0xFFF49AB0), Color(0xFFFFD27A)], count: 14);
    }

    burst();
    for (var i = 0; i < 20; i++) {
      final recorder = PictureRecorder();
      fx
        ..update(1 / 60)
        ..render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
    const frames = 200;
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      if (i % 30 == 0) burst();
      final recorder = PictureRecorder();
      fx
        ..update(1 / 120)
        ..render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
    final ms = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('Ghi lệnh vẽ hiệu ứng (~50–90 hạt, ms/khung): ${ms.toStringAsFixed(3)}');
    expect(ms, lessThan(4));
  });
}
