import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_items.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_nav.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

const _r = 0.27;
const _dt = 1 / 60;

/// Chạy mô phỏng tới khi không còn vật bay (tối đa [maxSeconds]); gom sự kiện.
List<ItemEvent> _simulate(ItemBoard board, {List<ItemTarget> targets = const [], double maxSeconds = 12}) {
  final events = <ItemEvent>[];
  var t = 0.0;
  while (t < maxSeconds && board.items.any((i) => i.phase == ItemPhase.flying)) {
    events.addAll(board.update(_dt, targets));
    t += _dt;
  }
  return events;
}

void _holdAndThrow(ItemBoard board, ShopItem it, double x, double z, double yaw, double d, {String holder = 'mai'}) {
  expect(board.pickUp(it, holder), isTrue);
  expect(board.throwItem(it, x, z, yaw, d), isTrue);
}

void main() {
  final nav = Shop3dNav.fromLayout(owned: Shop3dRequires.all);

  group('vật lý ném', () {
    test('tốc độ ném cho đúng quãng chạm sàn (rời tay ở 0,8 m, góc 30°)', () {
      for (final d in [1.5, 2.5, 3.2, 4.0]) {
        final v = ItemPhysics.speedForDistance(d);
        final vy = v * math.sin(ItemPhysics.throwAngle);
        final t = (vy + math.sqrt(vy * vy + 2 * ItemPhysics.gravity * ItemPhysics.releaseHeight)) / ItemPhysics.gravity;
        expect(v * math.cos(ItemPhysics.throwAngle) * t, closeTo(d, 1e-3));
      }
      // Ngoài khoảng thì kẹp.
      expect(ItemPhysics.speedForDistance(0.2), closeTo(ItemPhysics.speedForDistance(1.5), 1e-9));
      expect(ItemPhysics.speedForDistance(9), closeTo(ItemPhysics.speedForDistance(4.0), 1e-9));
    });

    test('nạp lực: chạm nhanh 2,5 m; giữ 0,2–0,8 s ↔ 1,5–4,0 m', () {
      expect(ItemPhysics.distanceForHold(0.05), 2.5);
      expect(ItemPhysics.distanceForHold(0.2), closeTo(1.5, 1e-9));
      expect(ItemPhysics.distanceForHold(0.5), closeTo(2.75, 1e-9));
      expect(ItemPhysics.distanceForHold(0.8), closeTo(4.0, 1e-9));
      expect(ItemPhysics.distanceForHold(3), closeTo(4.0, 1e-9));
    });

    test('chỉ cuộn len ném được; hộp bánh và bao bột thì không', () {
      final board = ItemBoard(nav);
      final cake = board.byId('cakeBox0')!;
      final flour = board.byId('flour')!;
      expect(board.pickUp(cake, 'mai'), isTrue);
      expect(board.throwItem(cake, 3, -1, math.pi, 2.5), isFalse);
      expect(cake.phase, ItemPhase.held);
      expect(board.pickUp(flour, 'nora'), isTrue);
      expect(board.throwItem(flour, 3, -1, math.pi, 2.5), isFalse);
    });

    test('ném từ nhiều vị trí / hướng / lực: luôn dừng trên sàn hoặc vỉa hè, trong biên', () {
      final board = ItemBoard(nav, owned: Shop3dRequires.all);
      final yarn = board.byId('yarn')!;
      var flights = 0;
      for (var x = -6.2; x <= 6.2; x += 0.7) {
        for (var z = -3.7; z <= 6.4; z += 0.7) {
          if (!nav.canStand(x, z, _r)) continue;
          for (var k = 0; k < 16; k++) {
            final yaw = k * math.pi / 8;
            for (final d in [1.5, 2.5, 4.0]) {
              board.reset();
              _holdAndThrow(board, yarn, x, z, yaw, d);
              _simulate(board);
              flights++;
              final reason = 'từ ($x,$z) yaw=$yaw d=$d → (${yarn.x},${yarn.z})';
              expect(yarn.phase, ItemPhase.rest, reason: reason);
              expect(nav.canStand(yarn.x, yarn.z, ItemPhysics.restRadius), isTrue, reason: reason);
              expect(yarn.y, closeTo(nav.floorHeight(yarn.x, yarn.z), 1e-9), reason: reason);
              expect(yarn.vx == 0 && yarn.vy == 0 && yarn.vz == 0, isTrue);
            }
          }
        }
      }
      expect(flights, greaterThan(1000));
    });

    test('ném giữa phòng thoáng: rơi cách ~d rồi nảy / lăn thêm không quá ~1,5 m', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, -3, 1.0, math.pi / 2, 2.5); // hướng +x, hàng thoáng giữa quầy và khu ngồi
      final events = _simulate(board);
      expect(events.where((e) => e.kind == ItemEventKind.landed).length, 1);
      expect(yarn.z, closeTo(1.0, 1e-6));
      final travelled = yarn.x + 3 - ItemPhysics.handReach;
      expect(travelled, greaterThan(2.5 - 0.1));
      expect(travelled, lessThan(2.5 + 1.8));
    });

    test('ném thẳng vào tường: bật ngược, nằm lại trong phòng', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, -4.3, 1.0, -math.pi / 2, 4.0); // hướng −x, sát tường trái
      _simulate(board);
      expect(yarn.x, greaterThanOrEqualTo(-5.0 + ItemPhysics.restRadius - 1e-6));
      expect(nav.canStand(yarn.x, yarn.z, ItemPhysics.restRadius), isTrue);
    });

    test('ném sát quầy vào quầy: không lọt xuyên sang bếp', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, 0.2, 0.3, math.pi, 4.0); // hướng −z vào quầy thu ngân
      _simulate(board);
      expect(yarn.phase, ItemPhase.rest);
      expect(nav.canStand(yarn.x, yarn.z, ItemPhysics.restRadius), isTrue);
    });
  });

  group('ném trúng nhân vật', () {
    ItemTarget guest(String id, double x, double z, {TargetKind kind = TargetKind.guest}) =>
        ItemTarget(id, kind, x, z, 0.27, 1.1);

    test('trúng khách: một sự kiện hitTarget, vật rơi xuống gần đó', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, 0, 1.2, 0, 2.5);
      final events = _simulate(board, targets: [guest('g1', 0, 2.6)]);
      final hits = events.where((e) => e.kind == ItemEventKind.hitTarget).toList();
      expect(hits.length, 1);
      expect(hits.single.targetId, 'g1');
      expect(hits.single.targetKind, TargetKind.guest);
      expect(yarn.phase, ItemPhase.rest);
      expect(yarn.z, lessThan(2.6));
    });

    test('trúng nhân viên cũng báo hitTarget (kind = staff)', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, 0, 1.2, 0, 2.5);
      final events = _simulate(board, targets: [guest('staff_nora', 0, 2.6, kind: TargetKind.staff)]);
      expect(events.firstWhere((e) => e.kind == ItemEventKind.hitTarget).targetKind, TargetKind.staff);
    });

    test('Mochi không bao giờ bị trúng; người ném không tự trúng mình', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, 0, 1.2, 0, 2.5);
      final events = _simulate(board, targets: [
        guest('mochi', 0, 2.6, kind: TargetKind.mochi),
        guest('mai', 0, 1.3, kind: TargetKind.staff),
      ]);
      expect(events.any((e) => e.kind == ItemEventKind.hitTarget), isFalse);
    });

    test('bay lệch ra ngoài hình trụ: không trúng; bay cao hơn đầu: không trúng', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      _holdAndThrow(board, yarn, 0, 1.2, 0, 2.5);
      var events = _simulate(board, targets: [guest('g1', 1.5, 2.6)]);
      expect(events.any((e) => e.kind == ItemEventKind.hitTarget), isFalse);
      board.reset();
      _holdAndThrow(board, yarn, 0, 1.2, 0, 2.5);
      events = _simulate(board, targets: [const ItemTarget('tiny', TargetKind.guest, 0, 2.2, 0.27, 0.3)]);
      expect(events.any((e) => e.kind == ItemEventKind.hitTarget), isFalse);
    });
  });

  group('chống phá (3 lần / 30 s)', () {
    test('lần 1–2 giật mình, lần 3 trong 30 s phụng phịu 20 s', () {
      final t = ThrowHitTracker();
      expect(t.register('g', 0), ThrowHitReaction.surprised);
      expect(t.register('g', 10), ThrowHitReaction.surprised);
      expect(t.register('g', 20), ThrowHitReaction.pout);
      expect(t.isPouting('g', 20), isTrue);
      expect(t.isPouting('g', 39.9), isTrue);
      expect(t.isPouting('g', 40.1), isFalse);
      expect(ThrowHitTracker.poutHearts, -1);
    });

    test('đang phụng phịu: không phản ứng thêm; hết phụng phịu thì đếm lại từ đầu', () {
      final t = ThrowHitTracker();
      for (final s in [0.0, 1.0, 2.0]) {
        t.register('g', s);
      }
      expect(t.register('g', 5), ThrowHitReaction.alreadyPouting);
      expect(t.register('g', 30), ThrowHitReaction.surprised);
      expect(t.register('g', 31), ThrowHitReaction.surprised);
      expect(t.register('g', 32), ThrowHitReaction.pout);
    });

    test('cách quá 30 s thì không cộng dồn; mỗi khách tính riêng', () {
      final t = ThrowHitTracker();
      expect(t.register('a', 0), ThrowHitReaction.surprised);
      expect(t.register('a', 15), ThrowHitReaction.surprised);
      expect(t.register('a', 31), ThrowHitReaction.surprised); // lần 0 đã quá 30 s
      expect(t.register('b', 31), ThrowHitReaction.surprised);
      expect(t.register('b', 32), ThrowHitReaction.surprised);
    });
  });

  group('nhặt / đặt / hẹn giờ', () {
    test('vị trí ban đầu theo đặc tả', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      expect([yarn.x, yarn.z], [4.0, 1.6]);
      expect(board.items.where((i) => i.kind == ItemKind.cakeBox).length, 2);
      final c0 = board.byId('cakeBox0')!, c1 = board.byId('cakeBox1')!;
      expect([c0.x, c1.x], [3.55, 3.95]);
      expect([c0.y, c0.z], [0.72, -0.5]);
      final flour = board.byId('flour')!;
      expect([flour.x, flour.z], [-4.8, -1.9]);
    });

    test('hộp bánh chỉ lấy được từ phía nhân viên (z ≤ −0,5), bao bột từ phía bếp', () {
      final board = ItemBoard(nav);
      final cake = board.byId('cakeBox0')!;
      expect(cake.reachableFrom(3.55, -1.3), isTrue);
      expect(cake.reachableFrom(3.55, 0.3), isFalse);
      expect(cake.reachableFrom(3.55, -2.5), isFalse); // quá 0,9 m
      expect(board.byId('flour')!.reachableFrom(-4.35, -2.1), isTrue);
      expect(board.byId('yarn')!.reachableFrom(3.6, 1.6), isTrue);
      expect(board.nearestPickable(3.7, -1.3)!.kind, ItemKind.cakeBox);
    });

    test('nhặt: một tay một vật; vật đang cầm không nhặt lại được', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      final cake = board.byId('cakeBox0')!;
      expect(board.pickUp(yarn, 'mai'), isTrue);
      expect(board.heldBy('mai'), same(yarn));
      expect(board.pickUp(cake, 'mai'), isFalse);
      expect(board.pickUp(yarn, 'staff_nora'), isFalse);
      expect(board.pickUp(cake, 'staff_nora'), isTrue);
    });

    test('đặt xuống: lên sàn cách 0,4 m trước mặt', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      board.pickUp(yarn, 'mai');
      board.putDown(yarn, 0, 1.2, 0);
      expect(yarn.phase, ItemPhase.rest);
      expect(yarn.x, closeTo(0, 1e-9));
      expect(yarn.z, closeTo(1.6, 1e-9));
      expect(board.heldBy('mai'), isNull);
    });

    test('đặt xuống sát tường: dời tới chỗ trống', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      board.pickUp(yarn, 'mai');
      board.putDown(yarn, -4.7, 1.0, -math.pi / 2);
      expect(nav.canStand(yarn.x, yarn.z, ItemPhysics.restRadius), isTrue);
    });

    test('bao bột đặt lên bàn trộn: về kệ sau 10 s', () {
      final board = ItemBoard(nav);
      final flour = board.byId('flour')!;
      board.pickUp(flour, 'mai');
      final target = board.findPlaceTarget(-2.0, -1.55, math.pi)!;
      expect(target.surface.id, PlaceSurfaces.mixingIsland);
      expect(board.placeOn(flour, target), isTrue);
      expect(flour.surfaceId, PlaceSurfaces.mixingIsland);
      expect(flour.y, closeTo(0.73, 1e-9));
      board.update(9.9, const []);
      expect(flour.x, isNot(-4.8));
      board.update(0.2, const []);
      expect([flour.x, flour.y, flour.z], [-4.8, 0.44, -1.9]);
      expect(flour.surfaceId, isNull);
    });

    test('hộp bánh tặng khách: biến mất, 8 s sau hiện lại trên bàn đóng hộp', () {
      final board = ItemBoard(nav);
      final cake = board.byId('cakeBox1')!;
      board.pickUp(cake, 'mai');
      board.consume(cake);
      expect(cake.visible, isFalse);
      board.update(7.9, const []);
      expect(cake.visible, isFalse);
      board.update(0.2, const []);
      expect(cake.visible, isTrue);
      expect(cake.phase, ItemPhase.rest);
      expect([cake.x, cake.y, cake.z], [3.95, 0.72, -0.5]);
      expect(cake.surfaceId, PlaceSurfaces.packingCounter);
    });

    test('reset đưa mọi vật về chỗ cũ', () {
      final board = ItemBoard(nav);
      final yarn = board.byId('yarn')!;
      board.pickUp(yarn, 'mai');
      board.putDown(yarn, 0, 0, 0);
      board.consume(board.byId('cakeBox0')!);
      board.reset();
      expect([yarn.x, yarn.z], [4.0, 1.6]);
      expect(board.byId('cakeBox0')!.visible, isTrue);
    });

    test('bao bột: tốc độ 0,7×, không chạy', () {
      expect(ItemSpec.flourSack.speedFactor, 0.7);
      expect(ItemSpec.flourSack.canRun, isFalse);
      expect(ItemSpec.flourSack.twoHands, isTrue);
      expect(ItemSpec.yarn.canRun, isTrue);
    });
  });

  group('mặt đặt được', () {
    test('khớp kích thước thật trong Shop3dLayout (mặt trên của khối)', () {
      bool matches(PlaceSurface s) {
        for (final p in Shop3dLayout.props) {
          for (final part in p.parts) {
            if ((part.minX - s.minX).abs() < 1e-6 &&
                (part.maxX - s.maxX).abs() < 1e-6 &&
                (part.minZ - s.minZ).abs() < 1e-6 &&
                (part.maxZ - s.maxZ).abs() < 1e-6 &&
                (part.maxY - s.top).abs() < 1e-6) {
              return true;
            }
          }
        }
        return false;
      }

      for (final s in PlaceSurfaces.all) {
        expect(matches(s), isTrue, reason: s.id);
      }
    });

    test('tìm thấy khi nhìn đúng hướng, trong tầm', () {
      final owned = Shop3dRequires.all;
      // Nhân viên sau bàn đóng hộp (z −1,25) nhìn +z (yaw 0).
      expect(PlaceSurfaces.find(3.55, -1.25, 0, owned)!.surface.id, PlaceSurfaces.packingCounter);
      // Nhìn đi chỗ khác thì không.
      expect(PlaceSurfaces.find(3.55, -1.25, math.pi, owned), isNull);
      // Quá 0,6 m thì không.
      expect(PlaceSurfaces.find(3.55, -1.8, 0, owned), isNull);
      // Phía khách nhìn −z.
      expect(PlaceSurfaces.find(3.55, 0.3, math.pi, owned)!.surface.id, PlaceSurfaces.packingCounter);
      // Bàn trộn từ phía quầy nhìn −z.
      expect(PlaceSurfaces.find(-2.0, -1.55, math.pi, owned)!.surface.id, PlaceSurfaces.mixingIsland);
      // Bàn khách chỉ khi có cafe_tables.
      expect(PlaceSurfaces.find(-3.8, 1.9, 0, owned)!.surface.id, 'cafeTable1');
      expect(PlaceSurfaces.find(-3.8, 1.9, 0, const {}), isNull);
    });

    test('chỗ đặt nằm trong mặt và đúng độ cao', () {
      final t = PlaceSurfaces.find(3.55, -1.25, 0, Shop3dRequires.all)!;
      expect(t.y, Shop3dLayout.serviceCounterTop);
      expect(t.x, greaterThanOrEqualTo(t.surface.minX));
      expect(t.x, lessThanOrEqualTo(t.surface.maxX));
      expect(t.z, greaterThanOrEqualTo(t.surface.minZ));
      expect(t.z, lessThanOrEqualTo(t.surface.maxZ));
    });
  });
}
