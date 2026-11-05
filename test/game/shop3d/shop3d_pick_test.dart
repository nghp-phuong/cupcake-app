import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/orbit_camera.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_math.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_pick.dart';

void main() {
  const w = 1280.0, h = 720.0, fov = 40.0;

  Shop3dCameraBasis basisFor(OrbitCameraController c) => Shop3dCameraBasis()..set(c.eye, c.target, fov, w, h);

  group('Shop3dCameraBasis', () {
    test('tâm màn hình = hướng nhìn; target chiếu vào giữa màn', () {
      final c = OrbitCameraController();
      final b = basisFor(c);
      final r = b.rayThrough(w / 2, h / 2);
      final d = Vec3(c.target.x - c.eye.x, c.target.y - c.eye.y, c.target.z - c.eye.z);
      final l = d.distanceTo(Vec3());
      expect(r.dx, closeTo(d.x / l, 1e-9));
      expect(r.dy, closeTo(d.y / l, 1e-9));
      expect(r.dz, closeTo(d.z / l, 1e-9));
      final p = b.project(c.target.x, c.target.y, c.target.z)!;
      expect(p.x, closeTo(w / 2, 1e-6));
      expect(p.y, closeTo(h / 2, 1e-6));
    });

    test('chiếu rồi bắn tia qua điểm chiếu → tia đi qua đúng điểm thế giới (nhiều góc camera)', () {
      final c = OrbitCameraController();
      final rnd = math.Random(7);
      for (var i = 0; i < 40; i++) {
        c.setView(
            yaw: rnd.nextDouble() * 2 * math.pi, pitch: 0.3 + rnd.nextDouble(), distance: 5 + rnd.nextDouble() * 10);
        final b = basisFor(c);
        final x = rnd.nextDouble() * 8 - 4, y = rnd.nextDouble() * 2, z = rnd.nextDouble() * 6 - 3;
        final p = b.project(x, y, z);
        if (p == null) continue;
        final r = b.rayThrough(p.x, p.y);
        // khoảng cách từ điểm tới tia
        final vx = x - r.ox, vy = y - r.oy, vz = z - r.oz;
        final t = vx * r.dx + vy * r.dy + vz * r.dz;
        final ex = vx - t * r.dx, ey = vy - t * r.dy, ez = vz - t * r.dz;
        expect(math.sqrt(ex * ex + ey * ey + ez * ez), lessThan(1e-6));
      }
    });

    test('trục màn hình: x phải, y xuống; điểm sau lưng camera → null', () {
      final c = OrbitCameraController()..setView(yaw: 0, pitch: 0.5, distance: 10);
      final b = basisFor(c);
      final center = b.project(0, 0.9, 0)!;
      final right = b.project(1, 0.9, 0)!; // yaw 0: camera ở +z nhìn −z → +x ở bên phải
      final up = b.project(0, 1.9, 0)!;
      expect(right.x, greaterThan(center.x));
      expect(up.y, lessThan(center.y));
      expect(b.project(c.eye.x, c.eye.y, c.eye.z + 5), isNull);
    });
  });

  group('Shop3dRay.hitAabb', () {
    test('trúng / trượt / gốc nằm trong hộp', () {
      final r = Shop3dRay()
        ..ox = 0
        ..oy = 0
        ..oz = 5
        ..dx = 0
        ..dy = 0
        ..dz = -1;
      expect(r.hitAabb(-1, -1, -1, 1, 1, 1), closeTo(4, 1e-9));
      expect(r.hitAabb(2, -1, -1, 3, 1, 1), isNull);
      expect(r.hitAabb(-1, -1, 4, 1, 1, 6), 0);
      // hộp sau lưng tia
      expect(r.hitAabb(-1, -1, 7, 1, 1, 8), isNull);
      // tia song song mặt, nằm ngoài slab
      expect((Shop3dRay()..oy = 2).hitAabb(-1, -1, -10, 1, 1, 10), isNull);
    });
  });

  group('pickNearest', () {
    test('chọn hộp gần nhất', () {
      final r = Shop3dRay()..oz = 10;
      const boxes = [
        Shop3dPickBox('far', Shop3dPickKind.prop, -1, -1, -1, 1, 1, 1),
        Shop3dPickBox('near', Shop3dPickKind.actor, -1, -1, 3, 1, 1, 4),
        Shop3dPickBox('miss', Shop3dPickKind.prop, 5, 5, 5, 6, 6, 6),
      ];
      expect(pickNearest(r, boxes)?.id, 'near');
      expect(pickNearest(r, const []), isNull);
    });

    test('chạm giữa tủ kính từ góc mặc định → trúng tủ kính, không phải kính / quầy khác', () {
      final c = OrbitCameraController();
      final b = basisFor(c);
      final boxes = [for (final p in Shop3dLayout.props) ...pickBoxesForProp(p)];
      // Tâm nắp kính của tủ (y = 1,3) chiếu lên màn — nắp trong suốt vẫn chạm được.
      final p = b.project(Shop3dLayout.caseCenterX, 1.3, Shop3dLayout.caseCenterZ)!;
      expect(pickNearest(b.rayThrough(p.x, p.y), boxes)?.id, 'pastryCase');
    });

    test('chạm trúng lò từ góc nhìn phía bếp', () {
      final c = OrbitCameraController()..setView(yaw: math.pi, pitch: 0.6, distance: 9);
      final b = basisFor(c);
      final boxes = [for (final p in Shop3dLayout.props) ...pickBoxesForProp(p)];
      final p = b.project(-4.0, 0.9, -3.3)!;
      expect(pickNearest(b.rayThrough(p.x, p.y), boxes)?.id, 'oven1');
    });
  });

  group('pickBoxesForProp / topCenterOf', () {
    test('vật phủ sàn không chạm được; tấm kính mỏng bị bỏ, khối kính (vách + nắp tủ) vẫn chạm được', () {
      for (final p in Shop3dLayout.floorProps) {
        expect(pickBoxesForProp(p), isEmpty);
      }
      final pastry = Shop3dLayout.props.firstWhere((p) => p.id == 'pastryCase');
      final glass = pastry.parts.where((p) => p.alpha <= 0.35).toList();
      final panes = glass.where((p) => math.min(p.sx, math.min(p.sy, p.sz)) < 0.05).length;
      expect(panes, greaterThan(0));
      expect(glass.length, greaterThan(panes));
      expect(pickBoxesForProp(pastry).length, pastry.parts.length - panes);
    });

    test('đỉnh trên-giữa = giữa hộp bao, y cao nhất', () {
      const boxes = [
        Shop3dPickBox('a', Shop3dPickKind.prop, 0, 0, 0, 1, 1, 1),
        Shop3dPickBox('a', Shop3dPickKind.prop, 1, 0, 0, 3, 2, 1),
        Shop3dPickBox('b', Shop3dPickKind.prop, 9, 9, 9, 10, 10, 10),
      ];
      final t = topCenterOf('a', boxes)!;
      expect([t.x, t.y, t.z], [1.5, 2, 0.5]);
      expect(topCenterOf('zzz', boxes), isNull);
    });
  });
}
