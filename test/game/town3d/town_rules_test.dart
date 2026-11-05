import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_rules.dart';

/// Nút A / vùng / băng tên ngoài phố (town_rules.dart). Dart thuần.
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final town = TownLayout.forDistrict(district);
  final zones = TownRules.zonesOf(town);

  test('mỗi lô một vùng cửa; quán ăn + tiệm tóc thêm vùng quầy; vùng không chồng nhau', () {
    expect(zones.where((z) => z.kind == TownZoneKind.door).length, district.lots.length);
    expect({for (final z in zones.where((z) => z.kind == TownZoneKind.counter)) z.lotId}, {'n3', 'n4'});
    for (var i = 0; i < zones.length; i++) {
      for (var j = i + 1; j < zones.length; j++) {
        final a = zones[i], b = zones[j];
        expect(a.distanceTo(b.x, b.z), greaterThan(a.radius + b.radius), reason: '$a / $b');
      }
    }
  });

  test('nhãn nút A theo chỗ đứng', () {
    // Chỗ xuất hiện = trước cửa tiệm của bà → "Vào tiệm".
    expect(TownRules.actionAt(zones, town.spawn.x, town.spawn.z), TownAction.enterShop);
    final n2 = town.spots['n2']!.door;
    expect(TownRules.actionAt(zones, n2.x, n2.z + 0.6), TownAction.enterShop);
    // Quầy quán ăn / tiệm tóc.
    final c3 = town.spots['n3']!.counter!, c4 = town.spots['n4']!.counter!;
    expect(TownRules.actionAt(zones, c3.x, c3.z), TownAction.orderFood);
    expect(TownRules.actionAt(zones, c3.x + 0.5, c3.z + 0.5), TownAction.orderFood);
    expect(TownRules.actionAt(zones, c4.x, c4.z), TownAction.getHaircut);
    // Cửa quán ăn / tiệm tóc (không phải quầy), cửa lô khác: không có thao tác.
    for (final id in ['n1', 'n3', 'n4', 's1', 's2', 's3', 's4']) {
      final d = town.spots[id]!.door;
      expect(TownRules.actionAt(zones, d.x, d.z), TownAction.none, reason: id);
      expect(TownRules.zoneAt(zones, d.x, d.z)?.lotId, id, reason: id);
    }
    // Giữa đường, đầu phố, trạm buýt: ngoài mọi vùng.
    expect(TownRules.zoneAt(zones, 0, 0), isNull);
    expect(TownRules.zoneAt(zones, town.bus.x, town.bus.z), isNull);
    expect(TownRules.actionAt(zones, c3.x, c3.z + 2), TownAction.none);
  });

  test('trễ khi ra khỏi vùng: giữ vùng tới bán kính + trễ', () {
    final c = town.spots['n3']!.counter!;
    final z0 = TownRules.zoneAt(zones, c.x, c.z)!;
    final edge = z0.radius + TownRules.hysteresis * 0.5;
    expect(TownRules.zoneAt(zones, c.x, c.z + edge), isNull);
    expect(identical(TownRules.zoneAt(zones, c.x, c.z + edge, current: z0), z0), isTrue);
    expect(TownRules.zoneAt(zones, c.x, c.z + z0.radius + TownRules.hysteresis + 0.05, current: z0), isNull);
  });

  test('băng tên: tên lô + dòng phụ theo loại / cấp', () {
    TownBanner b(String id, int level) => TownRules.bannerFor(district.lot(id), level);
    expect(b('n2', 1), const TownBanner('townHomeShop', TownBannerNote.none));
    expect(b('n3', 1), const TownBanner('cityRestaurantName', TownBannerNote.none));
    expect(b('n4', 1), const TownBanner('citySalonName', TownBannerNote.none));
    expect(b('n1', 1), const TownBanner('cityRealtyName', TownBannerNote.comingSoon));
    expect(b('s2', 1), const TownBanner('cityParkName', TownBannerNote.comingSoon));
    expect(b('s1', 1), const TownBanner('townLotForSale', TownBannerNote.locked, level: 5));
    expect(b('s4', 3), const TownBanner('townLotForSale', TownBannerNote.locked, level: 15));
    expect(b('s1', 4), const TownBanner('townLotForSale', TownBannerNote.locked, level: 5));
    expect(b('s1', 5), const TownBanner('townLotForSale', TownBannerNote.unlocked));
  });

  test('newlyUnlocked: lô chi nhánh vừa mở khi lên cấp', () {
    List<String> ids(int from, int to) => [for (final l in TownRules.newlyUnlocked(district, from, to)) l.id];
    expect(ids(4, 5), ['s1']);
    expect(ids(1, 15), ['s1', 's3', 's4']);
    expect(ids(5, 5), isEmpty);
    expect(ids(15, 30), isEmpty);
    expect(ids(10, 3), isEmpty);
  });

  test('ghé tiệm lần đầu: chỉ quán ăn, tiệm tóc', () {
    expect([for (final l in district.lots) if (TownRules.countsAsVisit(l)) l.id], ['n3', 'n4']);
    expect(TownRules.countsAsVisit(district.lot('n2')), isFalse);
  });

  test('trong tiệm: khe cửa (nút A ra phố), bước ra vỉa hè, chỗ vào ngoài vùng cửa', () {
    expect(TownRules.atShopDoor(3.6, 3.9), isTrue);
    expect(TownRules.atShopDoor(3.6, 4.3), isTrue);
    expect(TownRules.atShopDoor(3.6, 3.0), isFalse); // trong phòng
    expect(TownRules.atShopDoor(2.0, 3.9), isFalse); // trước tường, không phải khe cửa
    expect(TownRules.atShopDoor(3.6, 4.7), isFalse); // đã ra vỉa hè → outsideShop
    expect(TownRules.outsideShop(3.6, 4.7), isTrue);
    expect(TownRules.outsideShop(3.6, 4.2), isFalse);
    expect(TownRules.atShopDoor(TownRules.shopEntryX, TownRules.shopEntryZ), isFalse);
    expect(TownRules.outsideShop(TownRules.shopEntryX, TownRules.shopEntryZ), isFalse);
  });
  test('quầy trong tiệm (mở ca): phía khách, phía bếp, cửa được ưu tiên', () {
    // Phía khách: x ∈ [−2,2; 2,0], z ∈ [0,1; 1,2].
    expect(TownRules.atShopCounter(0.2, 0.45), isTrue); // chỗ đứng gọi món
    expect(TownRules.atShopCounter(-2.2, 0.1), isTrue);
    expect(TownRules.atShopCounter(2.0, 1.2), isTrue);
    expect(TownRules.atShopCounter(-2.3, 0.45), isFalse);
    expect(TownRules.atShopCounter(2.1, 0.45), isFalse);
    expect(TownRules.atShopCounter(0.2, 0.05), isFalse);
    expect(TownRules.atShopCounter(0.2, 1.3), isFalse);
    // Phía bếp: z ∈ [−1,9; −1,0] (sau quầy thu ngân).
    expect(TownRules.atShopCounter(TownRules.shiftMaiX, TownRules.shiftMaiZ), isTrue);
    expect(TownRules.atShopCounter(0.2, -1.0), isTrue);
    expect(TownRules.atShopCounter(0.2, -1.9), isTrue);
    expect(TownRules.atShopCounter(0.2, -0.9), isFalse);
    expect(TownRules.atShopCounter(0.2, -2.0), isFalse);
    expect(TownRules.atShopCounter(0.2, 0.0), isFalse); // giữa quầy và tủ kính, không phải vùng
    // Chỗ Mai nhào bột / lấy khay ở sâu trong bếp: không phải quầy.
    expect(TownRules.atShopCounter(Shop3dLayout.staffMixerFar.x, Shop3dLayout.staffMixerFar.z), isFalse);
    // Cửa được ưu tiên: mọi điểm ở khe cửa không tính là quầy; chỗ vào tiệm cũng không.
    for (var x = -2.5; x <= 4.5; x += 0.1) {
      for (var z = -2.5; z <= 5.0; z += 0.1) {
        if (TownRules.atShopDoor(x, z)) expect(TownRules.atShopCounter(x, z), isFalse, reason: '($x, $z)');
      }
    }
    expect(TownRules.atShopCounter(TownRules.shopEntryX, TownRules.shopEntryZ), isFalse);
  });

  test('chỗ đứng trong ca bán: Mai ở staffCashier (1,0; −1,45; yaw 0), Nora ở staffCase', () {
    expect(TownRules.shiftMaiX, 1.0);
    expect(TownRules.shiftMaiZ, -1.45);
    expect(TownRules.shiftMaiYaw, 0);
    expect(TownRules.shiftNoraX, Shop3dLayout.staffCase.x);
    expect(TownRules.shiftNoraZ, Shop3dLayout.staffCase.z);
    expect(TownRules.shiftNoraYaw, Shop3dLayout.staffCase.facingYaw);
    // Cả hai đều đứng trong vùng quầy phía bếp.
    expect(TownRules.atShopCounter(TownRules.shiftNoraX, TownRules.shiftNoraZ), isTrue);
  });
}
