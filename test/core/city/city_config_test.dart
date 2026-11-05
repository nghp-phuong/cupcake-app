import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';

void main() {
  final street = CityConfig.alpha.district('bakery_street');

  test('quận 1: thông số chung', () {
    expect(street.nameKey, 'townStreetName');
    expect(
      [street.minX, street.maxX, street.minZ, street.maxZ],
      [-24, 24, -16, 16],
    );
    expect(street.roadHalfWidth, 3);
    expect(street.sidewalkOuter, 5.5);
    expect([street.busX, street.busZ], [-23, -4]);
    expect([street.spawnX, street.spawnZ], [-6, -4.4]);
    expect(street.lots.length, 8);
  });

  test('bảng 8 lô đúng đặc tả', () {
    const expected = {
      'n1': (LotKind.realty, -18.0, 0, 1, 'cityRealtyName'),
      'n2': (LotKind.home, -6.0, 0, 1, 'townHomeShop'),
      'n3': (LotKind.restaurant, 6.0, 0, 1, 'cityRestaurantName'),
      'n4': (LotKind.salon, 18.0, 0, 1, 'citySalonName'),
      's1': (LotKind.branch, -18.0, 8000, 5, 'townLotForSale'),
      's2': (LotKind.park, -6.0, 0, 1, 'cityParkName'),
      's3': (LotKind.branch, 6.0, 20000, 10, 'townLotForSale'),
      's4': (LotKind.branch, 18.0, 45000, 15, 'townLotForSale'),
    };
    expected.forEach((id, e) {
      final l = street.lot(id);
      expect(l.kind, e.$1, reason: id);
      expect(l.x, e.$2, reason: id);
      expect(l.price, e.$3, reason: id);
      expect(l.requiresLevel, e.$4, reason: id);
      expect(l.nameKey, e.$5, reason: id);
      expect(l.w, 11);
      expect(l.d, 10);
    });
  });

  test('toạ độ cửa và hướng cửa đúng từng lô', () {
    for (final l in street.lots) {
      final north = l.id.startsWith('n');
      expect(l.z, north ? -10.5 : 10.5, reason: l.id);
      expect(l.doorX, l.x, reason: l.id);
      expect(l.doorZ, north ? -5.5 : 5.5, reason: l.id);
      expect(l.yaw, north ? 0 : closeTo(math.pi, 1e-12), reason: l.id);
      // Cửa nằm ở mép lô giáp vỉa hè.
      expect(l.doorZ, north ? l.maxZ : l.minZ, reason: l.id);
    }
  });

  test('lô không chồng nhau và nằm trong biên quận', () {
    final lots = street.lots;
    for (var i = 0; i < lots.length; i++) {
      final a = lots[i];
      expect(a.minX, greaterThanOrEqualTo(street.minX), reason: a.id);
      expect(a.maxX, lessThanOrEqualTo(street.maxX), reason: a.id);
      expect(a.minZ, greaterThanOrEqualTo(street.minZ), reason: a.id);
      expect(a.maxZ, lessThanOrEqualTo(street.maxZ), reason: a.id);
      for (var j = i + 1; j < lots.length; j++) {
        final b = lots[j];
        final overlap =
            a.minX < b.maxX &&
            b.minX < a.maxX &&
            a.minZ < b.maxZ &&
            b.minZ < a.maxZ;
        expect(overlap, isFalse, reason: '${a.id} chồng ${b.id}');
      }
    }
  });

  test('không lô nào lấn lòng đường / vỉa hè', () {
    for (final l in street.lots) {
      if (l.z < 0) {
        expect(l.maxZ, lessThanOrEqualTo(-street.sidewalkOuter), reason: l.id);
      } else {
        expect(
          l.minZ,
          greaterThanOrEqualTo(street.sidewalkOuter),
          reason: l.id,
        );
      }
    }
  });

  test('điểm xuất hiện và trạm buýt nằm trên vỉa hè trong biên', () {
    for (final p in [
      (street.spawnX, street.spawnZ),
      (street.busX, street.busZ),
    ]) {
      expect(p.$1, inInclusiveRange(street.minX, street.maxX));
      expect(p.$2.abs(), inInclusiveRange(3, 5.5));
    }
  });

  test('lot / lotOfKind', () {
    expect(street.lot('n3').kind, LotKind.restaurant);
    expect(() => street.lot('zzz'), throwsStateError);
    expect(street.lotOfKind(LotKind.salon)!.id, 'n4');
    expect(street.lotOfKind(LotKind.home)!.id, 'n2');
    expect(street.lotOfKind(LotKind.branch)!.id, 's1');
  });

  test('quận 2: lots rỗng, biên hợp lệ, tra theo id', () {
    final sea = CityConfig.alpha.district('sea_market');
    expect(sea.nameKey, 'citySeaMarketName');
    expect(sea.lots, isEmpty);
    expect(sea.minX, lessThan(sea.maxX));
    expect(sea.minZ, lessThan(sea.maxZ));
    expect(sea.lotOfKind(LotKind.home), isNull);
    expect(CityConfig.alpha.districts.length, 2);
    expect(() => CityConfig.alpha.district('nope'), throwsStateError);
  });
}
