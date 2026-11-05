import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_mesh.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Nhân vật chibi dựng bằng code (V3): dữ liệu lưới, khung xương, máy trạng thái, kịch bản. Dart thuần — không import
/// thermion (xem docs/v3/thermion-api-notes.md mục 9.4).

const _dt = 1 / 60;

/// Khoảng cách từ (x, z) tới hình chữ nhật xz của khối.
double _distToPart(double x, double z, Shop3dPart p) {
  final dx = math.max(math.max(p.minX - x, x - p.maxX), 0.0);
  final dz = math.max(math.max(p.minZ - z, z - p.maxZ), 0.0);
  return math.sqrt(dx * dx + dz * dz);
}

/// Vật cản ở tầm thân nhân vật chibi khi bật mọi mở rộng.
List<Shop3dPart> _obstacles() => [
      for (final p in Shop3dLayout.propsFor(Shop3dRequires.all))
        if (!p.flat)
          for (final part in p.parts)
            if (part.alpha > 0 && part.minY < 1.2) part,
    ];

void _run(ChibiActor a, double seconds, {Set<String> owned = const {Shop3dRequires.cafeTables}}) {
  for (var t = 0.0; t < seconds; t += _dt) {
    a.update(_dt, owned);
  }
}

void main() {
  final models = {for (final id in ChibiCharacters.ids) id: ChibiCharacters.build(id)};

  group('ChibiMeshBuilder', () {
    test('ellipsoid: đỉnh nằm trên mặt elip, pháp tuyến đơn vị hướng ra ngoài, màu tuyến tính', () {
      final b = ChibiMeshBuilder()..ellipsoid(1, 2, 3, 0.3, 0.2, 0.1, 0xFF8000, lat: 6, lon: 10);
      final m = b.build();
      expect(m.triangleCount, greaterThan(0));
      for (var v = 0; v < m.vertexCount; v++) {
        final x = m.positions[3 * v] - 1, y = m.positions[3 * v + 1] - 2, z = m.positions[3 * v + 2] - 3;
        expect(math.pow(x / 0.3, 2) + math.pow(y / 0.2, 2) + math.pow(z / 0.1, 2), closeTo(1, 1e-4));
        final nx = m.normals[3 * v], ny = m.normals[3 * v + 1], nz = m.normals[3 * v + 2];
        expect(nx * nx + ny * ny + nz * nz, closeTo(1, 1e-4));
        expect(nx * x + ny * y + nz * z, greaterThan(0));
      }
      expect(m.colors[0], closeTo(1, 1e-6));
      expect(m.colors[1], closeTo(math.pow(0x80 / 255, 2.2), 1e-4));
      expect(m.colors[2], 0);
      expect(m.colors[3], 1);
    });

    test('mọi tam giác hướng ra ngoài (theo pháp tuyến đỉnh) với mọi loại khối', () {
      final b = ChibiMeshBuilder()
        ..capsule(0, 0, 0, 0.1, 0.5, 0.05, 0.06, 0.04, 0x112233)
        ..frustum(0, 0, 0, 0, -0.2, 0, 0.1, 0.2, 0x445566, pleats: 6)
        ..frustum(1, 0, 0, 1, 0.3, 0, 0.1, 0, 0x445566)
        ..torus(0, 1, 0, 0.1, 0.02, 0x778899, a0: 0, a1: math.pi)
        ..box(2, 0, 0, 0.1, 0.2, 0.3, 0xAABBCC)
        ..star(3, 0, 0, 0.05, 0.02, 0.01, 0xFFD45A)
        ..dome(4, 0, 0, 0.05, 0.03, 0.01, 0xF7A3AC)
        ..shell(5, 0, const [(0.0, 0.2, 0.15, -1.0, 1.0), (0.2, 0.18, 0.14, -0.8, 0.8)], 0xA8DCC8);
      final m = b.build();
      for (var t = 0; t < m.triangleCount; t++) {
        final i = m.indices[3 * t], j = m.indices[3 * t + 1], k = m.indices[3 * t + 2];
        double p(int v, int c) => m.positions[3 * v + c];
        double n(int v, int c) => m.normals[3 * v + c];
        final e1 = [for (var c = 0; c < 3; c++) p(j, c) - p(i, c)];
        final e2 = [for (var c = 0; c < 3; c++) p(k, c) - p(i, c)];
        final g = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
        final avg = [for (var c = 0; c < 3; c++) n(i, c) + n(j, c) + n(k, c)];
        expect(g[0] * avg[0] + g[1] * avg[1] + g[2] * avg[2], greaterThanOrEqualTo(0));
      }
    });

    test('build dời gốc về điểm xoay', () {
      final b = ChibiMeshBuilder()..sphere(0, 1, 0, 0.1, 0xFFFFFF);
      final m = b.build(py: 1);
      expect(m.minY, closeTo(-0.1, 1e-6));
      expect(m.maxY, closeTo(0.1, 1e-6));
    });
  });

  group('ChibiCharacters', () {
    test('4 nhân vật: ≤ 8 entity, ngân sách tam giác, đủ bộ phận chính', () {
      expect(models.keys, ['mai', 'linh', 'hoa', 'staff_nora']);
      for (final m in models.values) {
        expect(m.entityCount, lessThanOrEqualTo(8), reason: m.id);
        // Ngân sách ~4k / nhân vật (phân đoạn thích ứng: đầu / thân mịn, tay chân / phụ kiện giữ thấp).
        expect(m.triangleCount, lessThanOrEqualTo(4100), reason: m.id);
        for (final p in [
          ChibiPart.body,
          ChibiPart.head,
          ChibiPart.eyes,
          ChibiPart.armL,
          ChibiPart.armR,
          ChibiPart.legL,
          ChibiPart.legR,
        ]) {
          expect(m.meshes.containsKey(p), isTrue, reason: '${m.id} ${p.name}');
        }
      }
      // Bộ phận phụ: đuôi ngựa (Mai), tai thỏ (Linh), đuôi cáo (Nora); ông Hòa không có.
      expect(models['mai']!.extraKind, ChibiExtraKind.ponytail);
      expect(models['linh']!.extraKind, ChibiExtraKind.ears);
      expect(models['staff_nora']!.extraKind, ChibiExtraKind.tail);
      expect(models['hoa']!.meshes.containsKey(ChibiPart.extra), isFalse);
      expect(models['hoa']!.gait.cane, isTrue);
      expect(models['hoa']!.gait.speed, lessThan(models['linh']!.gait.speed));
    });

    test('khung tỉ lệ cute (kích thước dựng gốc): đầu 48–50%, gần như không cổ, mắt 0,50–0,56 từ đỉnh sọ', () {
      const s = ChibiCharacters.scale;
      for (final m in models.values) {
        final head = m.meshes[ChibiPart.head]!;
        final (_, neckY, _) = m.rig.pivotOf(ChibiPart.head);
        final crown = ChibiSizes.crownOf(m);
        expect(m.rig.crownY, isNotNull, reason: m.id);
        expect(crown, inInclusiveRange(1.0 * s, 1.1 * s), reason: m.id);
        final headFrac = (crown - neckY) / crown;
        expect(headFrac, inInclusiveRange(0.47, 0.51), reason: '${m.id} head $headFrac');
        // Cằm sát khớp cổ (gần như không cổ).
        expect(head.minY.abs(), lessThan(0.03 * s), reason: m.id);
        final eyeFromTop = (crown - m.rig.eyeY) / (crown - neckY);
        expect(eyeFromTop, inInclusiveRange(0.5, 0.56), reason: '${m.id} eye $eyeFromTop');
        // Chân ngắn: hông ~0,24·scale (cũ 0,34).
        expect(m.rig.hipY, closeTo(0.24 * s, 0.01), reason: m.id);
      }
      expect(models['linh']!.height, greaterThan(models['linh']!.rig.crownY! + 0.3 * s), reason: 'tai thỏ dựng cao');
    });

    test('ChibiSizes.fit: thú nhỏ hơn Mai; Mai ~1,24 m đỉnh sọ, đầu 50%; thú giữ đầu ~0,37–0,42 × Mai', () {
      final mai = ChibiSizes.fit(models['mai']!);
      expect(mai.fitted, isTrue);
      expect(ChibiSizes.crownOf(mai), closeTo(ChibiSizes.maiHeight, 1e-6));
      expect(mai.height, inInclusiveRange(1.25, 1.38), reason: 'Mai ~1,25–1,30 m (+ tóc / khăn)');
      for (final id in ['linh', 'hoa', 'staff_nora']) {
        final f = ChibiSizes.fit(models[id]!);
        final crown = ChibiSizes.crownOf(f);
        final size = ChibiSizes.of(id);
        expect(crown, closeTo(size.height * ChibiSizes.maiHeight, 1e-6), reason: id);
        expect(f.height, lessThan(mai.height), reason: '$id nhỏ hơn Mai');
        final head = (crown - f.rig.neckY) / ChibiSizes.maiHeight;
        expect(head, inInclusiveRange(0.37, 0.42), reason: '$id head');
        // Mắt vẫn trên đầu (giữa khớp cổ và đỉnh sọ), dáng đi bước ngắn hơn.
        expect(f.rig.eyeY, inExclusiveRange(f.rig.neckY, crown), reason: id);
        expect(f.gait.stride, lessThan(models[id]!.gait.stride), reason: id);
        // Fit lần nữa không đổi.
        expect(identical(ChibiSizes.fit(f), f), isTrue);
      }
      // Hòa / Linh (nhân vật nổi bật) ≥ 0,75 Mai tính cả tai / chỏm lông.
      expect(ChibiSizes.fit(models['linh']!).height / ChibiSizes.maiHeight, greaterThanOrEqualTo(0.75));
      expect(ChibiSizes.fit(models['hoa']!).height / ChibiSizes.maiHeight, greaterThanOrEqualTo(0.75));
    });

    test('lưới hợp lệ: chỉ số trong biên, số hữu hạn, màu 0..1, hộp bao gọn quanh khớp', () {
      for (final m in models.values) {
        for (final e in m.meshes.entries) {
          final mesh = e.value;
          expect(mesh.colors.length, mesh.vertexCount * 4);
          expect(mesh.normals.length, mesh.positions.length);
          for (final i in mesh.indices) {
            expect(i, lessThan(mesh.vertexCount));
          }
          for (final v in mesh.positions) {
            expect(v.isFinite, isTrue);
          }
          for (final c in mesh.colors) {
            expect(c, inInclusiveRange(0, 1));
          }
          // Không bộ phận nào xa khớp quá 0,9 m (gậy của ông Hòa dài nhất ~0,65 m).
          for (final v in [mesh.minX, mesh.minY, mesh.minZ, mesh.maxX, mesh.maxY, mesh.maxZ]) {
            expect(v.abs(), lessThan(0.9), reason: '${m.id} ${e.key.name}');
          }
        }
      }
    });

    test('mắt nằm phía trước mặt, hai mắt đối xứng; mắt đen có chấm sáng trắng', () {
      for (final m in models.values) {
        final eyes = m.meshes[ChibiPart.eyes]!;
        expect(m.rig.eyeZ, greaterThan(0.18), reason: m.id);
        expect(eyes.minX, closeTo(-eyes.maxX, 0.01), reason: m.id);
        var white = 0, dark = 0;
        for (var v = 0; v < eyes.vertexCount; v++) {
          final r = eyes.colors[4 * v];
          if (r > 0.95) white++;
          if (r < 0.05) dark++;
        }
        expect(white, greaterThan(0), reason: m.id);
        expect(dark, greaterThan(white), reason: m.id);
      }
    });
  });

  group('ChibiRig', () {
    test('tư thế nghỉ: ma trận thân = dời tới khớp hông; yaw quay mặt (+z) về (sin, 0, cos)', () {
      final m = models['linh']!;
      final rig = ChibiRig(m.rig);
      final pose = ChibiPose()
        ..x = 1
        ..z = 2;
      rig.compute(pose);
      final body = rig[ChibiPart.body];
      expect(body[12], closeTo(1, 1e-9));
      expect(body[13], closeTo(m.rig.hipY, 1e-9));
      expect(body[14], closeTo(2, 1e-9));
      pose.yaw = 0.7;
      rig.compute(pose);
      final (fx, _, fz) = ChibiM4.transformPoint(rig[ChibiPart.body], 0, 0, 1);
      expect(fx - 1, closeTo(math.sin(0.7), 1e-9));
      expect(fz - 2, closeTo(math.cos(0.7), 1e-9));
    });

    test('đánh chân về trước đưa bàn chân ra +z; giơ tay trái đưa bàn tay ra +x và lên', () {
      final m = models['mai']!;
      final rig = ChibiRig(m.rig);
      final pose = ChibiPose();
      rig.compute(pose);
      final (_, footY0, footZ0) = ChibiM4.transformPoint(rig[ChibiPart.legL], 0, -0.3, 0);
      final (handX0, handY0, _) = ChibiM4.transformPoint(rig[ChibiPart.armL], 0, -0.25, 0);
      pose
        ..legSwingL = 0.5
        ..armRaiseL = 2.5;
      rig.compute(pose);
      final (_, footY1, footZ1) = ChibiM4.transformPoint(rig[ChibiPart.legL], 0, -0.3, 0);
      final (handX1, handY1, _) = ChibiM4.transformPoint(rig[ChibiPart.armL], 0, -0.25, 0);
      expect(footZ1, greaterThan(footZ0 + 0.1));
      expect(footY1, greaterThan(footY0));
      expect(handY1, greaterThan(handY0 + 0.3));
      expect(handX1, greaterThanOrEqualTo(handX0 - 0.05));
    });

    test('chớp mắt: co lưới mắt theo y quanh đường tâm mắt, đầu không đổi', () {
      final m = models['hoa']!;
      final rig = ChibiRig(m.rig);
      final pose = ChibiPose()..eyeOpen = 0.1;
      rig.compute(pose);
      final eyes = rig[ChibiPart.eyes];
      expect(eyes[5], closeTo(0.1, 1e-9)); // trục y bị co
      expect(eyes[0], closeTo(1, 1e-9));
      expect(eyes[13], closeTo(m.rig.eyeY, 1e-9));
    });

    test('compute tái dùng bộ đệm (không cấp phát ma trận mới)', () {
      final rig = ChibiRig(models['mai']!.rig);
      final before = List<Float64List>.of(rig.world);
      rig.compute(ChibiPose()..yaw = 1);
      for (var i = 0; i < before.length; i++) {
        expect(identical(before[i], rig.world[i]), isTrue);
      }
    });
  });

  group('ChibiActor', () {
    test('đi theo đường: quay rồi tiến đều ~tốc độ dáng đi, tới đích thì sang bước sau', () {
      final m = models['linh']!;
      final a = ChibiActor(
          m,
          const [
            ChibiStep.walk([(0, 2), (1, 2)]),
            ChibiStep.act(ChibiAction.stand, 5),
          ],
          x: 0,
          z: 0,
          yaw: math.pi);
      expect(a.action, ChibiAction.walk);
      var lastZ = 0.0, maxStep = 0.0;
      var t = 0.0;
      while (a.stepIndex == 0 && t < 10) {
        a.update(_dt, const {});
        maxStep = math.max(maxStep, (a.pose.z - lastZ).abs());
        lastZ = a.pose.z;
        t += _dt;
      }
      // Quãng 3 m ở 0,9 m/s + quay đầu (bắt đầu quay lưng lại) + góc rẽ.
      expect(t, inInclusiveRange(3 / m.gait.speed, 3 / m.gait.speed + 1.8));
      expect(a.action, ChibiAction.stand);
      expect(a.pose.x, closeTo(1, 1e-6));
      expect(a.pose.z, closeTo(2, 1e-6));
      expect(maxStep, lessThanOrEqualTo(m.gait.speed * _dt + 1e-9));
    });

    test('quay người mượt: không nhảy góc quá tốc độ quay tối đa', () {
      final a = ChibiActor(models['mai']!, const [ChibiStep.act(ChibiAction.stand, 10, faceYaw: math.pi)],
          x: 0, z: 0, yaw: 0);
      var prev = a.pose.yaw;
      for (var i = 0; i < 120; i++) {
        a.update(_dt, const {});
        var d = (a.pose.yaw - prev).abs();
        if (d > math.pi) d = 2 * math.pi - d;
        expect(d, lessThanOrEqualTo(ChibiActor.turnSpeed * _dt + 1e-9));
        prev = a.pose.yaw;
      }
      expect((a.pose.yaw.abs() - math.pi).abs(), lessThan(0.05));
    });

    test('đi: chân tay đánh ngược nhau, thân nhún; đứng: thở + chớp mắt trong vòng 6 s', () {
      final m = models['linh']!;
      final a = ChibiActor(
          m,
          const [
            ChibiStep.walk([(0, 20)]),
          ],
          x: 0,
          z: 0,
          yaw: 0,
          seed: 3);
      _run(a, 1);
      var swingSeen = false, bobSeen = false;
      for (var i = 0; i < 60; i++) {
        a.update(_dt, const {});
        final p = a.pose;
        if ((p.legSwingL - p.legSwingR).abs() > 0.4) swingSeen = true;
        // Tay đánh ngược chân cùng bên.
        if (p.legSwingL.abs() > 0.3) expect(p.armSwingL * p.legSwingL, lessThan(0));
        if (p.bob > m.gait.bob * 0.8) bobSeen = true;
        expect(p.legSwingL.abs(), lessThanOrEqualTo(m.gait.legSwing + 0.05));
      }
      expect(swingSeen, isTrue);
      expect(bobSeen, isTrue);

      final s = ChibiActor(m, const [ChibiStep.act(ChibiAction.stand, 100)], x: 0, z: 0, seed: 9);
      var minEye = 1.0, minScale = 2.0, maxScale = 0.0;
      for (var i = 0; i < 6 * 60; i++) {
        s.update(_dt, const {});
        minEye = math.min(minEye, s.pose.eyeOpen);
        minScale = math.min(minScale, s.pose.bodyScaleY);
        maxScale = math.max(maxScale, s.pose.bodyScaleY);
      }
      expect(minEye, lessThan(0.3), reason: 'phải chớp mắt');
      expect(maxScale - minScale, inInclusiveRange(0.02, 0.06), reason: 'thở ~2%');
    });

    test('ngồi: nhảy lên ghế (gốc = mặt ngồi − seatDrop), đung đưa chân, rồi về đúng chỗ đứng cũ', () {
      final m = models['hoa']!;
      const seat = Shop3dSpot('s', 0, 0.5, math.pi / 2, y: 0.5);
      final a = ChibiActor(m, const [ChibiStep.sit(seat, 3), ChibiStep.act(ChibiAction.stand, 50)], x: 0, z: 0, yaw: 0);
      _run(a, 1.2);
      expect(a.isSeated, isTrue);
      expect(a.pose.y, closeTo(0.5 + 0.02 - m.rig.seatDrop, 1e-6));
      expect(a.pose.z, closeTo(0.5, 1e-6));
      expect(a.pose.legSwingL, greaterThan(1.0), reason: 'chân duỗi về trước khi ngồi');
      var swing = 0.0;
      for (var i = 0; i < 90; i++) {
        final l0 = a.pose.legSwingL;
        a.update(_dt, const {});
        swing = math.max(swing, (a.pose.legSwingL - l0).abs());
      }
      expect(swing, greaterThan(0), reason: 'đung đưa chân');
      _run(a, 3);
      expect(a.action, ChibiAction.stand);
      expect(a.pose.y, 0);
      expect(a.pose.x, closeTo(0, 1e-6));
      expect(a.pose.z, closeTo(0, 1e-6));
    });

    test('bước có requires bị bỏ qua khi tiệm chưa sở hữu', () {
      const seat = Shop3dSpot('s', 0, 0.5, 0, y: 0.5);
      final a = ChibiActor(
        models['linh']!,
        const [
          ChibiStep.act(ChibiAction.stand, 0.2),
          ChibiStep.walk([(0, 1)], requires: Shop3dRequires.cafeTables),
          ChibiStep.sit(seat, 5, requires: Shop3dRequires.cafeTables),
          ChibiStep.act(ChibiAction.wave, 5),
        ],
        x: 0,
        z: 0,
      );
      _run(a, 0.5, owned: const {});
      expect(a.action, ChibiAction.wave);
      expect(a.pose.z, 0);
      expect(a.pose.y, 0);
    });

    test('chạm: đứng → nhảy vui quay về camera (tạm dừng kịch bản); ngồi → vẫy tay tại chỗ', () {
      final a = ChibiActor(
          models['linh']!,
          const [
            ChibiStep.walk([(0, 5)]),
          ],
          x: 0,
          z: 0);
      _run(a, 0.5);
      final z0 = a.pose.z;
      a.react(math.pi);
      expect(a.action, ChibiAction.happy);
      var maxY = 0.0;
      _runTracking(a, 1.0, (p) => maxY = math.max(maxY, p.y));
      expect(a.pose.z, closeTo(z0, 0.02));
      expect(maxY, greaterThan(0.05));
      expect((a.pose.yaw.abs() - math.pi).abs(), lessThan(0.2));
      _run(a, 1.0);
      expect(a.pose.z, greaterThan(z0 + 0.2), reason: 'đi tiếp sau khi vui');
    });
  });

  group('ChibiDirector', () {
    test('hai người cùng đi một đường: người sau đứng chờ, không đi xuyên', () {
      final lead = ChibiActor(
          models['hoa']!,
          const [
            ChibiStep.walk([(0, 3)]),
            ChibiStep.act(ChibiAction.stand, 3),
            ChibiStep.walk([(0, 8)]),
          ],
          x: 0,
          z: 0.6);
      final follow = ChibiActor(
          models['linh']!,
          const [
            ChibiStep.walk([(0, 6)]),
          ],
          x: 0,
          z: 0);
      final d = ChibiDirector([lead, follow]);
      var minGap = 10.0;
      for (var t = 0.0; t < 6; t += _dt) {
        d.update(_dt, const {});
        minGap = math.min(minGap, lead.pose.z - follow.pose.z);
      }
      expect(minGap, greaterThan(0.3));
    });
  });

  group('ChibiCast', () {
    test('8 nhân vật (+ Mochi); 200 s kịch bản: không NaN, khách ghé quầy + ngồi ghế, nhân viên đúng khu', () {
      final all = {for (final id in ChibiCharacters.allIds) id: models[id] ?? ChibiCharacters.build(id)};
      final cast = ChibiCast.build(models: all, mochi: true);
      expect([for (final a in cast) a.id],
          ['linh', 'hoa', 'staff_nora', 'mai', 'staff_bao', 'staff_theo', 'kenji', 'vip_00', 'mochi']);
      final byId = {for (final a in cast) a.id: a};
      final d = ChibiDirector(cast);
      final seated = <String>{}, atCounter = <String>{}, happy = <String>{}, waved = <String>{}, worked = <String>{};
      final served = <String>{};
      for (var t = 0.0; t < 200; t += _dt) {
        d.update(_dt, const {Shop3dRequires.cafeTables});
        for (final a in cast) {
          final p = a.pose;
          expect(p.x.isFinite && p.z.isFinite && p.yaw.isFinite, isTrue);
          if (a.isSeated) seated.add(a.id);
          if (a.action == ChibiAction.happy) happy.add(a.id);
          if (a.action == ChibiAction.wave) waved.add(a.id);
          if (a.action == ChibiAction.work) worked.add(a.id);
          for (final c in Shop3dLayout.counterSpots) {
            if ((p.x - c.x).abs() < 0.05 && (p.z - c.z).abs() < 0.05) atCounter.add(a.id);
          }
          // Trong phòng, hoặc ở làn cửa / ngoài cửa (vỉa hè trước tiệm).
          final inRoom = Shop3dLayout.room.contains(p.x, 1, p.z, margin: -0.15);
          final outside = p.z > 3.6 && p.z < 5.6 && (p.x - 3.5).abs() < 0.4; // làn cửa + vỉa hè
          expect(inRoom || outside, isTrue, reason: '${a.id} at (${p.x}, ${p.z})');
        }
        // Nora, Mai, Bao luôn ở phía trong quầy; Mai nửa bếp đông, Bao nửa bếp tây (không chắn đường nhau).
        for (final id in const ['staff_nora', 'mai', 'staff_bao']) {
          expect(byId[id]!.pose.z, lessThan(-1.2), reason: id);
        }
        expect(byId['mai']!.pose.x, greaterThan(-1.45));
        expect(byId['staff_bao']!.pose.x, lessThan(-2.4));
        // Theo chỉ đi giữa lối nhân viên và hai bàn (không vào bếp, không ra hàng chờ).
        final theo = byId['staff_theo']!.pose;
        expect(theo.z, greaterThan(-0.9));
        expect(theo.x, lessThan(1.0));
        for (final s in [ChibiCast.serveTable2, ChibiCast.serveTable3]) {
          if ((theo.x - s.x).abs() < 0.05 && (theo.z - s.z).abs() < 0.05) served.add(s.id);
        }
      }
      expect(seated, containsAll(['linh', 'hoa', 'kenji', 'vip_00', 'mochi']));
      expect(atCounter, containsAll(['linh', 'hoa', 'kenji', 'vip_00']));
      expect(happy, containsAll(['linh', 'hoa', 'kenji', 'vip_00', 'mai', 'staff_bao']));
      expect(waved, containsAll(['staff_nora', 'staff_theo']));
      expect(worked, containsAll(['kenji', 'staff_bao', 'staff_theo', 'mai']), reason: 'Kenji chụp ảnh, Bao cán bột');
      expect(served, {'serveTable2', 'serveTable3'});
    });

    test('chưa có cafe_tables: khách không ngồi, vẫn đi hết vòng ra cửa', () {
      final cast = ChibiCast.build(models: models);
      final d = ChibiDirector(cast);
      var outside = false;
      for (var t = 0.0; t < 120; t += _dt) {
        d.update(_dt, const {});
        expect(cast[0].isSeated || cast[1].isSeated, isFalse);
        if (cast[0].pose.z > 5) outside = true;
      }
      expect(outside, isTrue);
    });

    test('đường đi của kịch bản không xuyên vật cản (cách mép ≥ 0,2 m)', () {
      final obstacles = _obstacles();
      final scripts = {
        'linh': ChibiCast.customerLoop(Shop3dLayout.counterSpots[1], Shop3dLayout.seats[ChibiCast.linhSeat]),
        'hoa': ChibiCast.customerLoop(Shop3dLayout.counterSpots[2], Shop3dLayout.seats[ChibiCast.hoaSeat]),
        'kenji':
            ChibiCast.customerLoop(Shop3dLayout.counterSpots[0], Shop3dLayout.seats[ChibiCast.kenjiSeat], photo: 2),
        'vip_00': ChibiCast.customerLoop(Shop3dLayout.counterSpots[1], Shop3dLayout.seats[ChibiCast.rosaSeat]),
        'mai': ChibiCast.bakerLoop(),
        'staff_bao': ChibiCast.ovenLoop(),
        'staff_theo': ChibiCast.waiterLoop(),
        'mochi': ChibiCast.catLoop(),
      };
      for (final e in scripts.entries) {
        final pts = <(double, double)>[];
        for (final s in e.value) {
          pts.addAll(s.path);
        }
        // Vòng kín: điểm cuối nối điểm đầu.
        for (var i = 0; i < pts.length; i++) {
          final (ax, az) = pts[i];
          final (bx, bz) = pts[(i + 1) % pts.length];
          for (var k = 0; k <= 20; k++) {
            final x = ax + (bx - ax) * k / 20, z = az + (bz - az) * k / 20;
            if (z > Shop3dLayout.room.maxZ - 0.3) continue; // ngoài cửa / khung cửa
            for (final o in obstacles) {
              expect(
                _distToPart(x, z, o),
                greaterThanOrEqualTo(0.2),
                reason: '${e.key}: (${x.toStringAsFixed(2)}, ${z.toStringAsFixed(2)}) chạm khối '
                    '[${o.minX}..${o.maxX}]×[${o.minZ}..${o.maxZ}]',
              );
            }
          }
        }
      }
    });

    test('điểm trung gian mới nằm trong phòng, trên sàn trống', () {
      final obstacles = _obstacles();
      for (final s in [...Shop3dLayout.walkSpots, ...ChibiCast.walkSpots]) {
        expect(Shop3dLayout.room.contains(s.x, 1, s.z, margin: -0.25), isTrue, reason: s.id);
        for (final o in obstacles) {
          expect(_distToPart(s.x, s.z, o), greaterThanOrEqualTo(0.2), reason: s.id);
        }
      }
    });
  });

  group('Quy chuẩn cute (03/11)', () {
    test('ChibiMesh.scaled: phóng không đều giữ pháp tuyến đơn vị, vuông góc mặt (elip)', () {
      final b = ChibiMeshBuilder()..sphere(0, 0, 0, 0.1, 0xFFFFFF);
      final m = b.build().scaled(2, 0.5, 1);
      expect(m.maxX, closeTo(0.2, 0.012));
      expect(m.maxY, closeTo(0.05, 1e-6));
      for (var k = 0; k < m.positions.length; k += 3) {
        final x = m.positions[k], y = m.positions[k + 1], z = m.positions[k + 2];
        final nx = m.normals[k], ny = m.normals[k + 1], nz = m.normals[k + 2];
        expect(nx * nx + ny * ny + nz * nz, closeTo(1, 1e-4));
        // Pháp tuyến elip ∝ (x/a², y/b², z/c²).
        final gx = x / 0.04, gy = y / 0.0025, gz = z / 0.01;
        final gl = math.sqrt(gx * gx + gy * gy + gz * gz);
        if (gl > 1e-6) expect(nx * gx / gl + ny * gy / gl + nz * gz / gl, closeTo(1, 1e-3));
      }
    });

    test('phân đoạn thích ứng: khối to mịn hơn, khối nhỏ giữ nguyên', () {
      expect(ChibiMeshBuilder.seg(10, 0.3), (10 * ChibiMeshBuilder.detail).round());
      expect(ChibiMeshBuilder.seg(10, 0.03), 10);
    });

    test('bục: nhân vật bước lên bục được nâng mượt tới mặt bục, xuống bục về sàn', () {
      final m = ChibiSizes.fit(models['linh']!);
      final a = ChibiActor(
        m,
        [
          const ChibiStep.walk([(0.0, 2.0)]),
          const ChibiStep.act(ChibiAction.stand, 100),
        ],
        x: 0,
        z: 0,
        floor: (x, z) => z > 1 ? 0.16 : 0,
      );
      _run(a, 0.5);
      expect(a.pose.y, closeTo(0, 1e-6));
      _run(a, 8);
      expect(a.pose.z, closeTo(2, 1e-6));
      expect(a.pose.y, closeTo(0.16, 0.01));
    });

    test('đứng yên: đầu nghiêng nhẹ 5–8°, tay hơi dang', () {
      final a = ChibiActor(ChibiSizes.fit(models['staff_nora']!), [const ChibiStep.act(ChibiAction.stand, 100)],
          x: 0, z: 0, seed: 3);
      _run(a, 2.5);
      expect(a.pose.headTilt.abs(), inInclusiveRange(0.06, 0.16));
      expect(a.pose.armRaiseL, greaterThan(0.12));
    });
  });
}

void _runTracking(ChibiActor a, double seconds, void Function(ChibiPose) f) {
  for (var t = 0.0; t < seconds; t += _dt) {
    a.update(_dt, const {});
    f(a.pose);
  }
}
