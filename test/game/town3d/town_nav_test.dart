import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_nav.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_nav.dart';

/// Điều hướng ngoài phố (town_nav.dart = Shop3dNav với biên quận): đứng được, tìm đường A* từ chỗ xuất hiện tới mọi cửa,
/// quầy, ghế, trạm buýt; không đi xuyên nhà / ra khỏi quận. Dart thuần.
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final town = TownLayout.forDistrict(district);
  final nav = TownNav.of(town);
  const r = TownNav.radius;

  test('biên và cỡ ô theo quận; Shop3dNav mặc định giữ biên tiệm cũ', () {
    expect(nav.minX, district.minX);
    expect(nav.maxX, district.maxX);
    expect(nav.minZ, district.minZ);
    expect(nav.maxZ, district.maxZ);
    expect(nav.cellSize, TownNav.cellSize);
    final shop = Shop3dNav(const []);
    expect((shop.minX, shop.maxX, shop.minZ, shop.maxZ),
        (Shop3dNav.worldMinX, Shop3dNav.worldMaxX, Shop3dNav.worldMinZ, Shop3dNav.worldMaxZ));
    expect(shop.cellSize, Shop3dNav.cell);
    // Ngoài biên tiệm cũ: không đứng được (hành vi cũ), ngoài phố thì được.
    expect(shop.canStand(-6, -4.4, r), isFalse);
    expect(nav.canStand(-6, -4.4, r), isTrue);
  });

  final targets = <String, TownPoint>{
    'bus': town.bus,
    for (final e in town.spots.entries) ...{
      '${e.key}.door': e.value.door,
      if (e.value.counter != null) '${e.key}.counter': e.value.counter!,
      if (e.value.seat != null) '${e.key}.seat': e.value.seat!,
    },
  };

  test('mọi cửa / quầy / ghế / trạm buýt / chỗ xuất hiện đứng được với bán kính Mai', () {
    expect(nav.canStand(town.spawn.x, town.spawn.z, r), isTrue, reason: 'spawn');
    for (final e in targets.entries) {
      expect(nav.canStand(e.value.x, e.value.z, r), isTrue, reason: '${e.key} ${e.value}');
    }
  });

  test('A* từ chỗ xuất hiện tới mọi đích: có đường, tới đúng đích, đoạn nào cũng đi được', () {
    for (final e in targets.entries) {
      final t = e.value;
      final path = nav.findPath(town.spawn.x, town.spawn.z, t.x, t.z, clearance: TownNav.clearance);
      expect(path, isNotNull, reason: e.key);
      expect(path, isNotEmpty, reason: e.key);
      final end = path!.last;
      expect(math.sqrt(math.pow(end.x - t.x, 2) + math.pow(end.z - t.z, 2)), lessThan(0.05), reason: e.key);
      // Lấy mẫu dọc đường đi (bán kính nhỏ hơn khoảng hở một chút — đầu mút sát vật vẫn hợp lệ).
      var px = town.spawn.x, pz = town.spawn.z;
      for (final p in path) {
        final len = math.sqrt(math.pow(p.x - px, 2) + math.pow(p.z - pz, 2));
        final n = math.max(1, (len / 0.05).ceil());
        for (var i = 0; i <= n; i++) {
          final x = px + (p.x - px) * i / n, z = pz + (p.z - pz) * i / n;
          expect(nav.canStand(x, z, 0.2), isTrue, reason: '${e.key}: (${x.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})');
        }
        px = p.x;
        pz = p.z;
      }
    }
  });

  test('trượt: đi thẳng vào nhà bị chặn, không lọt ra ngoài quận', () {
    final move = NavMove();
    // Từ chỗ xuất hiện đi thẳng lên phía bắc (vào tiệm của bà) 6 m: dừng ở mép hộp chặn mặt tiền.
    nav.slide(town.spawn.x, town.spawn.z, 0, -6, r, out: move);
    expect(move.blocked, isTrue);
    expect(move.z, greaterThan(-7.5));
    expect(nav.canStand(move.x, move.z, r), isTrue);
    // Đi mãi về phía tây trên lòng đường: dừng trước biên quận.
    nav.slide(0, 0, -60, 0, r, out: move);
    expect(move.x, greaterThan(district.minX));
    expect(nav.canStand(move.x, move.z, r), isTrue);
    // Về phía nam: qua vỉa hè nam rồi bị chặn trước biên / hàng rào lô.
    nav.slide(0, 0, 0, 40, r, out: move);
    expect(move.z, lessThan(district.maxZ));
  });

  test('điểm trống gần nhất dùng bước = cỡ ô của lưới', () {
    // Đứng trong khối nhà tiệm của bà → dời ra ô trống (≤ 3 m).
    final p = nav.nearestFree(-6, -8, r, maxDist: 4);
    expect(p, isNotNull);
    expect(nav.canStand(p!.x, p.z, r), isTrue);
  });
}
