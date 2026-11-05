import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_pilot.dart';
import 'package:sugarleaf_bakery/game/town3d/town_rules.dart';

/// Điều phối Mai ngoài phố (town_pilot.dart): lái, vùng → băng tên / ghé lần đầu, nút A, quán ăn (đi tới ghế, ngồi ăn,
/// đứng dậy), tiệm tóc. Dart thuần (không engine).
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final town = TownLayout.forDistrict(district);

  List<TownEvent> run(TownPilot p, double seconds) {
    final out = <TownEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      p.update(1 / 60);
      out.addAll(p.takeEvents());
    }
    return out;
  }

  test('xuất hiện trước cửa tiệm của bà: nút A "Vào tiệm", không băng tên; 2 chủ quán đứng sau quầy', () {
    final p = TownPilot(town, CityWallet());
    expect(p.mai.pose.x, town.spawn.x);
    expect(p.mai.pose.z, town.spawn.z);
    expect(p.hud.value.action, TownAction.enterShop);
    expect(p.hud.value.controls, isTrue);
    expect(p.keepers.map((k) => k.id), [TownPilot.restaurantKeeperId, TownPilot.salonKeeperId]);
    for (final (id, k) in [('n3', p.keepers[0]), ('n4', p.keepers[1])]) {
      final spot = town.spots[id]!.keeper!;
      expect(k.pose.x, spot.x);
      expect(k.pose.z, spot.z);
    }
    expect(run(p, 0.5), isEmpty);
  });

  test('joystick: đi theo hướng camera, va chạm; vào vùng quầy → băng tên + ghé lần đầu (+XP) + nút "Gọi món"', () {
    final wallet = CityWallet();
    final p = TownPilot(town, wallet);
    final c = town.spots['n3']!.counter!;
    // Đứng trên lòng đường trước quán ăn rồi đẩy cần lên (camera yaw 0 → đi về phía bắc, -z).
    p.placeAt(c.x, -2.2, 0);
    expect(p.hud.value.action, TownAction.none);
    p
      ..cameraYaw = 0
      ..setStick(0, -1);
    final events = run(p, 3);
    expect(p.mai.pose.x, closeTo(c.x, 0.05));
    expect(p.mai.pose.z, lessThan(-4));
    expect(events.where((e) => e.kind == TownEventKind.banner).map((e) => e.lot!.id), ['n3']);
    expect(events.where((e) => e.kind == TownEventKind.firstVisit).map((e) => e.lot!.id), ['n3']);
    expect(wallet.xp, CityWallet.firstVisitXp);
    expect(p.hud.value.action, TownAction.orderFood);
    // Đẩy tiếp: bệ quầy chặn, Mai không vào nhà.
    run(p, 3);
    expect(p.mai.pose.z, greaterThan(-5.6));
    // Rời vùng rồi quay lại ngay: không lặp băng tên, không cộng XP lần nữa.
    p.setStick(0, 1);
    run(p, 2.5);
    p.setStick(0, -1);
    final again = run(p, 2.5);
    expect(again.where((e) => e.kind == TownEventKind.banner), isEmpty);
    expect(wallet.xp, CityWallet.firstVisitXp);
    // Camera xoay 90°: cùng cần "lên" đi về phía tây (-x).
    final x0 = p.mai.pose.x;
    p
      ..cameraYaw = math.pi / 2
      ..setStick(0, -1);
    run(p, 1);
    expect(p.mai.pose.x, lessThan(x0 - 0.5));
  });

  test('quán ăn: gọi món → đi tới ghế hiên → ngồi (món trên bàn) → đứng dậy, trừ xu + XP', () {
    final wallet = CityWallet();
    final p = TownPilot(town, wallet);
    final c = town.spots['n3']!.counter!, seat = town.spots['n3']!.seat!;
    p.placeAt(c.x, c.z, c.yaw);
    run(p, 0.2);
    expect(p.hud.value.action, TownAction.orderFood);
    p.beginMenu();
    expect(p.mode, TownMode.menu);
    expect(p.hud.value.controls, isFalse);
    const dish = RestaurantMenu.dishes;
    final r = p.order(dish[1]);
    expect(r.ok, isTrue);
    expect(wallet.coins, 1500 - dish[1].price);
    expect(p.mode, TownMode.eating);
    var sawDish = false, seated = false;
    final events = <TownEvent>[];
    for (var t = 0.0; t < 20 && p.mode == TownMode.eating; t += 1 / 60) {
      p.update(1 / 60);
      events.addAll(p.takeEvents());
      if (p.dishVisible) {
        sawDish = true;
        // Món trên mặt bàn, trước mặt Mai.
        expect(p.dishPose.y, TownPilot.tableTop);
        final dx = p.dishPose.x - seat.x, dz = p.dishPose.z - seat.z;
        expect(math.sqrt(dx * dx + dz * dz), closeTo(TownPilot.dishReach, 1e-6));
      }
      if (p.mai.isSeated) {
        seated = true;
        expect(p.mai.pose.x, closeTo(seat.x, 0.05));
        expect(p.mai.pose.z, closeTo(seat.z, 0.05));
        expect(p.mai.pose.y, greaterThan(0.1));
      }
    }
    expect(p.mode, TownMode.walk);
    expect(seated, isTrue);
    expect(sawDish, isTrue);
    expect(p.dishVisible, isFalse);
    expect(events.map((e) => e.kind), containsAllInOrder([TownEventKind.eatingStart, TownEventKind.eatingDone]));
    final done = events.firstWhere((e) => e.kind == TownEventKind.eatingDone);
    expect(done.eat!.xpGained, dish[1].xp);
    expect(done.eat!.reducedXp, isFalse);
    expect(p.mai.pose.y, closeTo(0, 1e-9));
    expect(p.mai.driven, isTrue);
    expect(wallet.fullBuff, isTrue);
    // Lần hai cùng món trong ngày: XP giảm.
    p.placeAt(c.x, c.z, c.yaw);
    p.beginMenu();
    final r2 = p.order(dish[1]);
    expect(r2.reducedXp, isTrue);
    run(p, 15);
    expect(p.mode, TownMode.walk);
  });

  test('quán ăn: thiếu xu → không đổi gì, bảng vẫn mở', () {
    final wallet = CityWallet(coins: 50);
    final p = TownPilot(town, wallet);
    final c = town.spots['n3']!.counter!;
    p
      ..placeAt(c.x, c.z, c.yaw)
      ..beginMenu();
    final r = p.order(RestaurantMenu.dishes.first);
    expect(r.ok, isFalse);
    expect(wallet.coins, 50);
    expect(p.mode, TownMode.menu);
    p.endMenu();
    expect(p.mode, TownMode.walk);
  });

  test('tiệm tóc: nút "Làm tóc"; mở bảng → Mai quay ra phố, khoá điều khiển; mua → "ta-da"', () {
    final p = TownPilot(town, CityWallet());
    final c = town.spots['n4']!.counter!;
    p.placeAt(c.x, c.z, c.yaw);
    run(p, 0.2);
    expect(p.hud.value.action, TownAction.getHaircut);
    p.beginSalon();
    expect(p.mode, TownMode.salon);
    expect(p.hud.value.controls, isFalse);
    run(p, 1.5);
    expect(p.mai.pose.yaw, closeTo(TownPilot.salonFaceYaw, 0.05));
    p.endSalon(bought: true);
    expect(p.mode, TownMode.walk);
    expect(p.takeEvents().map((e) => e.kind), [TownEventKind.tada]);
    // Huỷ: không hiệu ứng.
    p
      ..beginSalon()
      ..endSalon();
    expect(p.takeEvents(), isEmpty);
  });

  test('chuyển cảnh: khoá điều khiển; ra tiệm đặt Mai trước cửa n2 quay ra phố, không băng tên', () {
    final p = TownPilot(town, CityWallet());
    p.beginTransit();
    expect(p.hud.value.controls, isFalse);
    p.placeAt(town.spawn.x, town.spawn.z, 0);
    expect(p.mode, TownMode.walk);
    expect(p.mai.pose.yaw, 0);
    expect(p.hud.value.action, TownAction.enterShop);
    expect(run(p, 0.3).where((e) => e.kind == TownEventKind.banner), isEmpty);
  });
}
