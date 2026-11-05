import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/town3d/town_camera.dart';

/// Camera ngoài phố (town_camera.dart): giới hạn xoay / nghiêng / khoảng cách, bám Mai, chạm đúp, góc cận. Dart thuần.
void main() {
  double deg(double r) => r * 180 / math.pi;

  test('mặc định: nhìn về phía bắc (camera ở +z), pitch 45°, cách 11 m', () {
    final c = TownCamera()..snapTo(-6, -4.4);
    expect(c.yaw, 0);
    expect(c.eye.z, greaterThan(c.target.z));
    expect(c.eye.x, closeTo(-6, 1e-9));
    final dx = c.eye.x - c.target.x, dy = c.eye.y - c.target.y, dz = c.eye.z - c.target.z;
    expect(math.sqrt(dx * dx + dy * dy + dz * dz), closeTo(11, 1e-6));
    expect(deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz))), closeTo(45, 1e-6));
  });

  test('kéo: yaw kẹp ±60° quanh hướng chuẩn, pitch 40–50°, khoảng cách 10–12 m (cả quán tính)', () {
    final c = TownCamera()..snapTo(0, 0);
    // Kéo từng chút như ngón tay thật (mỗi lần ~12,5°).
    c.onDragStart();
    for (var i = 0; i < 12; i++) {
      c.onDrag(-50, 0, 720);
    }
    expect(deg(c.yaw), closeTo(60, 1e-6));
    for (var i = 0; i < 24; i++) {
      c.onDrag(50, 0, 720);
    }
    expect(deg(c.yaw), closeTo(-60, 1e-6));
    c.onDrag(0, 4000, 720);
    expect(deg(c.orbit.pitch), closeTo(50, 1e-6));
    c.onDrag(0, -8000, 720);
    expect(deg(c.orbit.pitch), closeTo(40, 1e-6));
    // Thả tay khi đang vuốt nhanh: quán tính không vượt giới hạn.
    for (var i = 0; i < 5; i++) {
      c.onDrag(-60, 0, 720);
      c.update(1 / 60, 0, 0);
    }
    c.onDragEnd();
    for (var i = 0; i < 120; i++) {
      c.update(1 / 60, 0, 0);
      expect(deg(c.yaw).abs(), lessThanOrEqualTo(60 + 1e-6));
    }
    c
      ..onScaleStart()
      ..onScale(5);
    expect(c.orbit.distance, 10);
    c.onScale(0.2);
    expect(c.orbit.distance, 12);
    c.onMouseWheel(-100000);
    expect(c.orbit.distance, 10);
  });

  test('chạm đúp về góc mặc định; điểm nhìn bám Mai mượt', () {
    final c = TownCamera()..snapTo(0, 0);
    c.onDragStart();
    for (var i = 0; i < 6; i++) {
      c.onDrag(-50, 150, 720);
    }
    c
      ..onDragEnd()
      ..onDoubleTap();
    for (var i = 0; i < 90; i++) {
      c.update(1 / 60, 0, 0);
    }
    expect(c.yaw, closeTo(0, 1e-9));
    expect(deg(c.orbit.pitch), closeTo(45, 1e-6));
    expect(c.orbit.distance, closeTo(11, 1e-9));
    // Mai đi 5 m về phía đông: sau 1 s điểm nhìn gần tới nơi.
    for (var i = 0; i < 60; i++) {
      c.update(1 / 60, 5, 0);
    }
    expect(c.target.x, closeTo(5, 0.05));
    expect(c.target.y, TownCamera.targetHeight);
  });

  test('góc cận (tiệm tóc): lia vào, bỏ qua cử chỉ, lia ra về camera phố', () {
    final c = TownCamera()..snapTo(21, -4.6);
    const close = TownCloseUp(x: 21.6, y: 0.92, z: -4.75, yaw: 0.25, pitch: 0.21, distance: 3.3);
    c.closeUp = close;
    for (var i = 0; i < 180; i++) {
      c.update(1 / 60, 21, -4.6);
    }
    expect(c.target.x, closeTo(close.x, 1e-3));
    expect(c.yaw, closeTo(close.yaw, 1e-3));
    final dx = c.eye.x - c.target.x, dy = c.eye.y - c.target.y, dz = c.eye.z - c.target.z;
    expect(math.sqrt(dx * dx + dy * dy + dz * dz), closeTo(3.3, 0.01));
    final before = c.yaw;
    c
      ..onDragStart()
      ..onDrag(-50, 0, 720);
    expect(c.yaw, before);
    c.closeUp = null;
    for (var i = 0; i < 180; i++) {
      c.update(1 / 60, 21, -4.6);
    }
    expect(c.inCloseUp, isFalse);
    expect(c.yaw, closeTo(0, 1e-6));
    expect(c.target.x, closeTo(21, 1e-3));
  });
}
