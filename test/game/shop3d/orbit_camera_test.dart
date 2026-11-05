import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/orbit_camera.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_math.dart';

void main() {
  const vh = 720.0;

  group('wrapAngle', () {
    test('quấn về [-π, π)', () {
      for (final a in [0.0, 1.0, math.pi, -math.pi, 3 * math.pi, -3 * math.pi, 100.0, -100.0, 2 * math.pi]) {
        final w = wrapAngle(a);
        expect(w, greaterThanOrEqualTo(-math.pi), reason: 'a=$a');
        expect(w, lessThan(math.pi), reason: 'a=$a');
        expect(math.cos(w), closeTo(math.cos(a), 1e-9));
        expect(math.sin(w), closeTo(math.sin(a), 1e-9));
      }
    });
  });

  group('OrbitCameraController', () {
    test('mặc định nằm trong giới hạn và eye đúng công thức', () {
      final c = OrbitCameraController();
      expect(c.pitch, inInclusiveRange(c.minPitch, c.maxPitch));
      expect(c.distance, inInclusiveRange(c.minDistance, c.maxDistance));
      expect(c.eye.distanceTo(c.target), closeTo(c.distance, 1e-9));
    });

    test('kẹp pitch khi kéo quá tay', () {
      final c = OrbitCameraController();
      c.onDragStart();
      c.onDrag(0, 100000, vh);
      expect(c.pitch, c.maxPitch);
      c.onDrag(0, -100000, vh);
      expect(c.pitch, c.minPitch);
      c.onDragEnd();
    });

    test('kéo xuống nâng pitch, kéo sang phải giảm yaw', () {
      final c = OrbitCameraController();
      final p0 = c.pitch, y0 = c.yaw;
      c.onDrag(0, 50, vh);
      expect(c.pitch, greaterThan(p0));
      c.onDrag(50, 0, vh);
      expect(c.yaw, lessThan(y0));
    });

    test('kẹp distance khi chụm', () {
      final c = OrbitCameraController();
      c.onScaleStart();
      c.onScale(1000);
      expect(c.distance, c.minDistance);
      c.onScale(0.0001);
      expect(c.distance, c.maxDistance);
      c.onScale(1.5);
      expect(c.distance, closeTo(c.defaultDistance / 1.5, 1e-9));
      c.onScaleEnd();
    });

    test('chụm tương đối so với lúc bắt đầu', () {
      final c = OrbitCameraController();
      final d0 = c.distance;
      c.onScaleStart();
      c.onScale(1.5);
      expect(c.distance, closeTo(d0 / 1.5, 1e-9));
      c.onScale(1.0);
      expect(c.distance, closeTo(d0, 1e-9));
      c.onScale(-1); // bỏ qua giá trị vô nghĩa
      expect(c.distance, closeTo(d0, 1e-9));
    });

    test('con lăn chuột kẹp trong giới hạn', () {
      final c = OrbitCameraController();
      for (var i = 0; i < 100; i++) {
        c.onMouseWheel(-500);
      }
      expect(c.distance, c.minDistance);
      for (var i = 0; i < 100; i++) {
        c.onMouseWheel(500);
      }
      expect(c.distance, c.maxDistance);
    });

    test('yaw quấn khi xoay nhiều vòng', () {
      final c = OrbitCameraController();
      c.onDragStart();
      // kéo ngang tổng 10 vòng: rotateSpeed = π rad mỗi chiều cao viewport → 2 chiều cao = 1 vòng
      for (var i = 0; i < 400; i++) {
        c.onDrag(-vh / 20, 0, vh);
        expect(c.yaw, greaterThanOrEqualTo(-math.pi));
        expect(c.yaw, lessThan(math.pi));
      }
      c.onDrag(vh * 4, 0, vh);
      expect(c.yaw, greaterThanOrEqualTo(-math.pi));
      expect(c.yaw, lessThan(math.pi));
    });

    test('quán tính: trôi tiếp rồi dừng; tắt được', () {
      final c = OrbitCameraController();
      c.onDragStart();
      for (var i = 0; i < 10; i++) {
        c.onDrag(-20, 0, vh);
        c.update(1 / 60);
      }
      c.onDragEnd();
      final y0 = c.yaw;
      expect(c.isMoving, isTrue);
      c.update(1 / 60);
      expect(c.yaw, isNot(closeTo(y0, 1e-9)));
      for (var i = 0; i < 600; i++) {
        c.update(1 / 60);
      }
      expect(c.isMoving, isFalse);
      final y1 = c.yaw;
      c.update(1 / 60);
      expect(c.yaw, y1);

      final n = OrbitCameraController(inertia: false);
      n.onDragStart();
      for (var i = 0; i < 10; i++) {
        n.onDrag(-20, 0, vh);
        n.update(1 / 60);
      }
      n.onDragEnd();
      final yn = n.yaw;
      n.update(1 / 60);
      expect(n.yaw, yn);
      expect(n.isMoving, isFalse);
    });

    test('giữ ngón đứng yên rồi thả thì không trôi', () {
      final c = OrbitCameraController();
      c.onDragStart();
      c.onDrag(-40, 0, vh);
      c.update(1 / 60);
      for (var i = 0; i < 30; i++) {
        c.update(1 / 60);
      }
      c.onDragEnd();
      final y = c.yaw;
      for (var i = 0; i < 10; i++) {
        c.update(1 / 60);
      }
      expect((c.yaw - y).abs(), lessThan(0.02));
    });

    test('chạm đúp về mặc định sau đủ thời gian (đường ngắn nhất)', () {
      final c = OrbitCameraController();
      c.setView(yaw: 3.0, pitch: 1.2, distance: 6);
      c.onDoubleTap();
      expect(c.isResetting, isTrue);
      var prevDelta = double.infinity;
      for (var i = 0; i < 20; i++) {
        c.update(0.01);
        final dy = wrapAngle(c.yaw - c.defaultYaw).abs();
        expect(dy, lessThanOrEqualTo(prevDelta + 1e-9), reason: 'yaw không đi vòng xa hơn');
        prevDelta = dy;
      }
      for (var i = 0; i < 100; i++) {
        c.update(1 / 60);
      }
      expect(c.isResetting, isFalse);
      expect(c.yaw, closeTo(c.defaultYaw, 1e-9));
      expect(c.pitch, closeTo(c.defaultPitch, 1e-9));
      expect(c.distance, closeTo(c.defaultDistance, 1e-9));
    });

    test('chạm đúp: chưa đủ thời gian thì chưa về tới', () {
      final c = OrbitCameraController();
      c.setView(yaw: 2.0, distance: 6);
      c.onDoubleTap();
      c.update(0.1);
      expect(c.isResetting, isTrue);
      expect(c.distance, isNot(closeTo(c.defaultDistance, 1e-6)));
    });

    test('kéo trong lúc animation thì huỷ animation', () {
      final c = OrbitCameraController();
      c.onDoubleTap();
      c.onDragStart();
      expect(c.isResetting, isFalse);
    });

    test('eye luôn trên sàn và ở trên minEyeHeight, mọi tổ hợp yaw/pitch/distance', () {
      final c = OrbitCameraController();
      for (var yi = 0; yi < 24; yi++) {
        for (var pi = 0; pi <= 10; pi++) {
          for (var di = 0; di <= 4; di++) {
            c.setView(
              yaw: -math.pi + yi * math.pi / 12,
              pitch: -1 + pi * 0.3, // cố tình ra ngoài giới hạn
              distance: 1 + di * 5,
            );
            expect(c.eye.y, greaterThanOrEqualTo(c.minEyeHeight - 1e-9));
            expect(c.pitch, inInclusiveRange(c.minPitch, c.maxPitch));
          }
        }
      }
    });

    test('minEyeHeight nâng pitch hiệu dụng khi target thấp, camera gần', () {
      final c =
          OrbitCameraController(target: Vec3(0, 0, 0), minPitch: 0.0, maxPitch: 1.3, minDistance: 2, minEyeHeight: 1.0);
      c.setView(pitch: 0.0, distance: 2);
      expect(c.eye.y, greaterThanOrEqualTo(1.0 - 1e-9));
      expect(c.effectivePitch, greaterThan(0));
      expect(c.eye.distanceTo(c.target), closeTo(2, 1e-9));
    });

    test('update không đổi đối tượng eye (tái dùng vector)', () {
      final c = OrbitCameraController();
      final e = c.eye;
      c.onDragStart();
      c.onDrag(-30, 10, vh);
      c.update(1 / 60);
      c.onDragEnd();
      c.onDoubleTap();
      for (var i = 0; i < 60; i++) {
        c.update(1 / 60);
      }
      expect(identical(c.eye, e), isTrue);
    });

    test('update với dt <= 0 hoặc rất lớn không hỏng', () {
      final c = OrbitCameraController();
      expect(c.update(0), isFalse);
      expect(c.update(-1), isFalse);
      c.onDoubleTap();
      c.update(100);
      expect(c.isResetting, isTrue); // dt kẹp 0,1 s → mới 1/7 animation
    });
  });

  group('tường quay mặt về camera', () {
    // Đặt camera ở các hướng chính, đủ xa để ở ngoài phòng.
    OrbitCameraController at(double yaw, {double pitch = 0.6, double distance = 12}) =>
        OrbitCameraController()..setView(yaw: yaw, pitch: pitch, distance: distance);

    List<RoomWall> sides(OrbitCameraController c) => [
          for (final w in c.wallsFacingCamera())
            if (w != RoomWall.ceiling) w,
        ];

    test('yaw 0: camera ở +z → ẩn tường trước (front), không ẩn tường khác', () {
      final c = at(0);
      expect(sides(c), [RoomWall.front]);
      expect(c.wallsFacingCamera(), contains(RoomWall.ceiling)); // camera ở trên mái
    });

    test('yaw π/2: camera ở +x → ẩn tường phải', () {
      expect(sides(at(math.pi / 2)), [RoomWall.right]);
    });

    test('yaw -π (π): camera ở -z → ẩn tường sau (bếp)', () {
      expect(sides(at(-math.pi)), [RoomWall.back]);
    });

    test('yaw -π/2: camera ở -x → ẩn tường trái', () {
      expect(sides(at(-math.pi / 2)), [RoomWall.left]);
    });

    test('đường chéo ẩn hai mặt kề nhau', () {
      final c = at(math.pi / 4, distance: 14);
      expect(sides(c), unorderedEquals([RoomWall.front, RoomWall.right]));
    });

    test('camera trên cao thẳng đứng hơn: có thể không ẩn tường nào nhưng trần thì ẩn', () {
      final c = OrbitCameraController(minDistance: 3)..setView(yaw: 0, pitch: 1.3, distance: 3);
      // eye.y = 0,9 + 3·sin(75°) ≈ 3,8 > 3,2 (trên trần), ngang ở trong phòng
      expect(c.wallsFacingCamera(), [RoomWall.ceiling]);
    });

    test('camera trong phòng, cách xa tường: không ẩn gì', () {
      final c = OrbitCameraController(minDistance: 3)..setView(yaw: 0.3, pitch: 0.3, distance: 3);
      expect(c.eye.y, lessThan(Shop3dLayout.room.maxY));
      expect(c.wallsFacingCamera(), isEmpty);
    });

    test('mặt nạ khớp danh sách; độ mờ 0 cho mặt bị ẩn, 1 cho mặt đối diện', () {
      final c = at(0);
      final mask = c.hiddenWallMask();
      expect(mask, RoomWall.front.bit | RoomWall.ceiling.bit);
      expect(c.wallOpacity(RoomWall.front), 0);
      expect(c.wallOpacity(RoomWall.back), 1);
      // chuyển mượt: camera vừa lọt vào trong sát tường trước
      final near = Vec3(0, 1.8, Shop3dLayout.room.maxZ - 0.5);
      final o = c.wallOpacity(RoomWall.front, fade: 1, at: near);
      expect(o, greaterThan(0));
      expect(o, lessThan(1));
    });

    test('quét 360°: luôn ẩn ít nhất một mặt khi camera ở xa và thấp', () {
      final c = OrbitCameraController();
      for (var i = 0; i < 72; i++) {
        c.setView(yaw: -math.pi + i * math.pi / 36, pitch: c.minPitch, distance: 14);
        expect(c.hiddenWallMask(), isNot(0), reason: 'yaw=${c.yaw}');
      }
    });
  });
}
