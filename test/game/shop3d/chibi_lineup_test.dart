import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_mesh.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_roster.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Nhân vật chibi mới (nhân viên, khách VIP / quen, mèo Mochi bốn chân), đồ cầm tay, danh sách đăng ký và màn xếp
/// hàng. Dart thuần — không import thermion (docs/v3/thermion-api-notes.md mục 9.4).

const _dt = 1 / 60;

const _newIds = [
  'staff_bao',
  'staff_theo',
  'staff_ami',
  'staff_hanh',
  'staff_bao_fest',
  'staff_nora_fest',
  'kenji',
  'vip_00',
  'vip_01',
  'vip_02',
  'mochi',
];

void _run(ChibiActor a, double seconds) {
  for (var t = 0.0; t < seconds; t += _dt) {
    a.update(_dt, const {});
  }
}

/// Điểm thấp nhất (y thế giới) của lưới [part] ở tư thế hiện tại.
double _minY(ChibiActor a, ChibiPart part) {
  final mesh = a.model.meshes[part]!;
  final m = a.rig[part];
  var minY = double.infinity;
  for (var v = 0; v < mesh.vertexCount; v++) {
    final (_, y, _) =
        ChibiM4.transformPoint(m, mesh.positions[3 * v], mesh.positions[3 * v + 1], mesh.positions[3 * v + 2]);
    minY = math.min(minY, y);
  }
  return minY;
}

void main() {
  final models = {for (final id in ChibiCharacters.allIds) id: ChibiCharacters.build(id)};

  group('Nhân vật mới', () {
    test('đủ 11 id mới, không trùng; nhóm staff / vip / friends khớp bảng chuyển đổi', () {
      expect(ChibiCharacters.allIds.toSet().length, ChibiCharacters.allIds.length);
      expect(ChibiCharacters.allIds, containsAll(_newIds));
      expect(ChibiCharacters.ids, ['mai', 'linh', 'hoa', 'staff_nora'], reason: 'API cũ giữ nguyên');
      expect(ChibiCharacters.staffIds, [
        'mai',
        'staff_nora',
        'staff_bao',
        'staff_theo',
        'staff_ami',
        'staff_hanh',
        'staff_bao_fest',
        'staff_nora_fest',
      ]);
      expect(ChibiCharacters.vipIds, ['vip_00', 'vip_01', 'vip_02']);
      expect(ChibiCharacters.friendIds, ['linh', 'hoa', 'kenji', 'mochi']);
      for (final id in _newIds) {
        expect(models[id]!.id, id);
      }
    });

    test('ngân sách: ≤ 9 entity, ≤ ~4k tam giác (mèo ≤ 3,3k); đủ bộ phận chính', () {
      for (final id in _newIds) {
        final m = models[id]!;
        expect(m.entityCount, lessThanOrEqualTo(9), reason: id);
        expect(m.triangleCount, lessThanOrEqualTo(id == 'mochi' ? 3300 : 4200), reason: id);
        for (final p in const [
          ChibiPart.body,
          ChibiPart.head,
          ChibiPart.eyes,
          ChibiPart.armL,
          ChibiPart.armR,
          ChibiPart.legL,
          ChibiPart.legR,
        ]) {
          expect(m.meshes.containsKey(p), isTrue, reason: '$id ${p.name}');
        }
        // Có lưới đồ cầm tay ⇔ có ChibiHold.
        expect(m.meshes.containsKey(ChibiPart.prop), m.rig.hold != null, reason: id);
      }
    });

    test('lưới hợp lệ: chỉ số trong biên, số hữu hạn, màu 0..1, pháp tuyến đơn vị', () {
      for (final id in _newIds) {
        for (final e in models[id]!.meshes.entries) {
          final mesh = e.value;
          expect(mesh.colors.length, mesh.vertexCount * 4);
          for (final i in mesh.indices) {
            expect(i, lessThan(mesh.vertexCount));
          }
          for (var k = 0; k < mesh.positions.length; k += 3) {
            expect(mesh.positions[k].isFinite && mesh.positions[k + 1].isFinite, isTrue);
            final n = math.sqrt(
                math.pow(mesh.normals[k], 2) + math.pow(mesh.normals[k + 1], 2) + math.pow(mesh.normals[k + 2], 2));
            expect(n, closeTo(1, 0.02), reason: '$id ${e.key.name}');
          }
          for (final c in mesh.colors) {
            expect(c, inInclusiveRange(0, 1));
          }
          for (final v in [mesh.minX, mesh.minY, mesh.minZ, mesh.maxX, mesh.maxY, mesh.maxZ]) {
            expect(v.abs(), lessThan(0.9), reason: '$id ${e.key.name}');
          }
        }
      }
    });

    test(
        'tỉ lệ trong cảnh (ChibiSizes): thú nhỏ hơn Mai theo bảng B; mặt cao hơn quầy 0,72 m khi đứng bục; Mochi '
        '~0,25 Mai khi ngồi', () {
      const mai = ChibiSizes.maiHeight;
      for (final id in _newIds) {
        final m = models[id]!;
        final f = ChibiSizes.fit(m);
        if (id == 'mochi') {
          expect(m.rig.quadruped, isTrue);
          expect(ChibiSizes.sittingHeight(f) / mai, closeTo(0.25, 0.01));
          continue;
        }
        expect(m.rig.quadruped, isFalse, reason: id);
        expect(m.rig.crownY, isNotNull, reason: id);
        final crown = ChibiSizes.crownOf(f) / mai;
        expect(crown, closeTo(ChibiSizes.of(id).height, 1e-6), reason: id);
        // Cả tai / gạc / búi (không tính mũ): ≤ 0,92 Mai — thú luôn thấp hơn Mai.
        expect(f.height / mai, inInclusiveRange(0.6, 0.92), reason: '$id ${f.height / mai}');
        // Đầu thú giữ ~0,37–0,42 chiều cao Mai (mặt đọc được).
        expect((ChibiSizes.crownOf(f) - f.rig.neckY) / mai, inInclusiveRange(0.37, 0.425), reason: id);
        // Đứng trên bục khách 0,16 m ở chỗ gọi món: nhìn từ phía bếp, camera chúc 25°, tia tới mắt đi qua trên mép
        // trước mặt quầy 0,72 m (mặt không bị quầy che).
        final spot = Shop3dLayout.counterSpots[1];
        final gap = spot.z - (-0.05) - f.radius * 0.5;
        expect(f.rig.eyeY + Shop3dLayout.customerStepHeight + gap * math.tan(25 * math.pi / 180),
            greaterThan(Shop3dLayout.serviceCounterTop + 0.05),
            reason: '$id: mặt bị quầy che');
      }
      // Bao (thú lớn) cao hơn Nora (thú vừa).
      final bao = ChibiSizes.fit(models['staff_bao']!), nora = ChibiSizes.fit(models['staff_nora']!);
      expect(ChibiSizes.crownOf(bao), greaterThan(ChibiSizes.crownOf(nora)));
    });

    test('mắt phía trước mặt, đối xứng, mắt đen có chấm sáng trắng', () {
      for (final id in _newIds) {
        final m = models[id]!;
        final eyes = m.meshes[ChibiPart.eyes]!;
        final (_, _, neckZ) = m.rig.pivotOf(ChibiPart.head);
        expect(m.rig.eyeZ - neckZ, greaterThan(id == 'mochi' ? 0.1 : 0.18), reason: id);
        expect(eyes.minX, closeTo(-eyes.maxX, 0.01), reason: id);
        var white = 0, dark = 0;
        for (var v = 0; v < eyes.vertexCount; v++) {
          final r = eyes.colors[4 * v];
          if (r > 0.9) white++;
          if (r < 0.05) dark++;
        }
        expect(white, greaterThan(0), reason: id);
        expect(dark, greaterThan(0), reason: id);
      }
    });

    test('bộ đồ lễ hội dùng chung thân với bản thường (mắt, đuôi giống hệt; áo khác)', () {
      for (final (a, b) in const [('staff_bao', 'staff_bao_fest'), ('staff_nora', 'staff_nora_fest')]) {
        final ma = models[a]!, mb = models[b]!;
        expect(mb.meshes[ChibiPart.eyes]!.positions, ma.meshes[ChibiPart.eyes]!.positions, reason: b);
        expect(mb.rig.eyeY, ma.rig.eyeY);
        expect(mb.extraKind, ma.extraKind);
        if (ma.meshes.containsKey(ChibiPart.extra)) {
          expect(mb.meshes[ChibiPart.extra]!.positions, ma.meshes[ChibiPart.extra]!.positions, reason: b);
        }
        expect(mb.meshes[ChibiPart.body]!.colors, isNot(ma.meshes[ChibiPart.body]!.colors), reason: b);
      }
    });
  });

  group('Đồ cầm tay', () {
    test('Bao, Theo, Ami, Hạnh, Kenji, Nora lễ hội cầm đồ; khay của Theo trên tay phải, bìa của Hạnh tay trái', () {
      for (final id in const [
        'staff_bao',
        'staff_bao_fest',
        'staff_theo',
        'staff_ami',
        'staff_hanh',
        'kenji',
        'staff_nora_fest',
      ]) {
        expect(models[id]!.rig.hold, isNotNull, reason: id);
      }
      expect(models['staff_theo']!.rig.hold!.side, -1);
      expect(models['staff_theo']!.rig.hold!.twoHands, isFalse);
      expect(models['staff_hanh']!.rig.hold!.side, 1);
      expect(models['staff_bao']!.rig.hold!.twoHands, isTrue);
      expect(models['vip_00']!.rig.hold, isNull);
    });

    test('điểm xoay đồ đi theo bàn tay; đồ "level" chỉ quay theo hướng người (khay luôn nằm ngang)', () {
      final m = models['staff_theo']!;
      final h = m.rig.hold!;
      final rig = ChibiRig(m.rig);
      final pose = ChibiPose()
        ..x = 1
        ..z = -2
        ..yaw = 0.8
        ..lean = 0.2
        ..roll = 0.1
        ..armSwingR = 1.1
        ..armRaiseR = 0.5;
      rig.compute(pose);
      final (sx, sy, sz) = m.rig.pivotOf(ChibiPart.armR);
      final (hx, hy, hz) = ChibiM4.transformPoint(rig[ChibiPart.armR], h.x - sx, h.y - sy, h.z - sz);
      final p = rig[ChibiPart.prop];
      expect(p[12], closeTo(hx, 1e-9));
      expect(p[13], closeTo(hy, 1e-9));
      expect(p[14], closeTo(hz, 1e-9));
      // Trục y của khay = +y thế giới; trục z = hướng mặt (sin yaw, 0, cos yaw).
      expect(p[4], closeTo(0, 1e-9));
      expect(p[5], closeTo(1, 1e-9));
      expect(p[6], closeTo(0, 1e-9));
      expect(p[8], closeTo(math.sin(0.8), 1e-9));
      expect(p[10], closeTo(math.cos(0.8), 1e-9));
    });

    test('tay cầm khay giữ nguyên khi đi / vui / vẫy; tay kia vẫn đánh và vẫy', () {
      final m = models['staff_theo']!;
      final h = m.rig.hold!;
      for (final step in const [
        ChibiStep.walk([(0.0, 30.0)]),
        ChibiStep.act(ChibiAction.happy, 50),
        ChibiStep.act(ChibiAction.wave, 50),
      ]) {
        final a = ChibiActor(m, [step], x: 0, z: 0, seed: 4);
        _run(a, 1.5);
        var minL = 9.0, maxL = -9.0, maxRaiseL = 0.0;
        for (var i = 0; i < 60; i++) {
          a.update(_dt, const {});
          expect(a.pose.armSwingR, closeTo(h.forward, 0.12), reason: '${step.action}');
          expect(a.pose.armRaiseR, closeTo(h.raise, 1e-9));
          minL = math.min(minL, a.pose.armSwingL);
          maxL = math.max(maxL, a.pose.armSwingL);
          maxRaiseL = math.max(maxRaiseL, a.pose.armRaiseL);
        }
        if (step.action == ChibiAction.walk) expect(maxL - minL, greaterThan(0.4), reason: 'tay trái đánh khi đi');
        if (step.action == ChibiAction.wave) expect(maxRaiseL, greaterThan(2.0), reason: 'vẫy bằng tay trái');
      }
    });

    test('đồ hai tay: hai tay cùng tư thế; làm việc = đẩy tới lui (cán bột); vui = giơ đồ lên cao', () {
      final m = models['staff_bao']!;
      final work = ChibiActor(m, const [ChibiStep.act(ChibiAction.work, 50)], x: 0, z: 0);
      _run(work, 1.5);
      var minS = 9.0, maxS = -9.0;
      for (var i = 0; i < 60; i++) {
        work.update(_dt, const {});
        expect(work.pose.armSwingL, closeTo(work.pose.armSwingR, 1e-9));
        expect(work.pose.armRaiseL, closeTo(work.pose.armRaiseR, 1e-9));
        minS = math.min(minS, work.pose.armSwingL);
        maxS = math.max(maxS, work.pose.armSwingL);
      }
      expect(maxS - minS, greaterThan(0.2));
      final happy = ChibiActor(m, const [ChibiStep.act(ChibiAction.happy, 50)], x: 0, z: 0);
      _run(happy, 1.5);
      expect(happy.pose.armSwingL, greaterThan(1.8));
      happy.rig.compute(happy.pose);
      expect(happy.rig[ChibiPart.prop][13], greaterThan(0.85), reason: 'cây cán bột giơ cao');
    });
  });

  group('Mèo Mochi bốn chân', () {
    final m = models['mochi']!;

    test('đứng: bốn bàn chân chạm sàn, đuôi dựng cao hơn lưng', () {
      final a = ChibiActor(m, const [ChibiStep.act(ChibiAction.stand, 50, faceYaw: 0)], x: 0, z: 0);
      _run(a, 1);
      for (final p in const [ChibiPart.armL, ChibiPart.armR, ChibiPart.legL, ChibiPart.legR]) {
        expect(_minY(a, p), closeTo(0, 0.025), reason: p.name);
      }
      final tail = m.meshes[ChibiPart.extra]!;
      final (_, tailTopY, _) = ChibiM4.transformPoint(a.rig[ChibiPart.extra], 0, tail.maxY, 0);
      expect(tailTopY, greaterThan(0.45));
    });

    test('đi nước kiệu: chân trước trái cùng nhịp chân sau phải; bước đều ~tốc độ dáng đi', () {
      final a = ChibiActor(
          m,
          const [
            ChibiStep.walk([(0.0, 20.0)]),
          ],
          x: 0,
          z: 0,
          yaw: 0);
      _run(a, 1);
      final z0 = a.pose.z;
      var seen = false;
      for (var i = 0; i < 60; i++) {
        a.update(_dt, const {});
        final p = a.pose;
        if (p.legSwingR.abs() > 0.2) {
          expect(p.armSwingL * p.legSwingR, greaterThan(0), reason: 'chéo cùng nhịp');
          seen = true;
        }
      }
      expect(seen, isTrue);
      expect(a.pose.z - z0, closeTo(m.gait.speed, 0.05));
    });

    test('ngồi nghỉ: thân ngả lên, chân trước vẫn chạm sàn và dựng đứng, hông hạ, đầu vẫn nhìn thẳng', () {
      final a = ChibiActor(m, const [ChibiStep.act(ChibiAction.rest, 50, faceYaw: 0)], x: 0, z: 0, seed: 2);
      _run(a, 3);
      expect(a.pose.lean, closeTo(-ChibiActor.quadSitAngle, 0.02));
      expect(a.pose.bob, lessThan(-0.12), reason: 'hông hạ xuống');
      for (final p in const [ChibiPart.armL, ChibiPart.armR]) {
        // Bỏ qua lúc đang liếm chân (một chân giơ lên).
        if (p == ChibiPart.armL && a.pose.armSwingL > 0.3) continue;
        expect(_minY(a, p), closeTo(0, 0.03), reason: p.name);
        final arm = a.rig[p];
        expect(arm[5], closeTo(1, 0.02), reason: '${p.name}: chân trước dựng đứng');
      }
      // Bụng / mông không lún quá sâu dưới sàn; chân sau gập nằm trên sàn.
      expect(_minY(a, ChibiPart.body), greaterThan(-0.06));
      expect(_minY(a, ChibiPart.legL), greaterThan(-0.06));
      // Đầu: tổng góc ngả thân + gật gần 0 (mặt vẫn hướng trước).
      final head = a.rig[ChibiPart.head];
      expect(head[10], greaterThan(0.85));
    });

    test('liếm chân: một chân trước giơ lên gần miệng, mắt lim dim; vẫy: chân phải giơ cao', () {
      final g = ChibiActor(m, const [ChibiStep.act(ChibiAction.groom, 50, faceYaw: 0)], x: 0, z: 0);
      _run(g, 2);
      expect(g.pose.armSwingL, greaterThan(1.6));
      expect(g.pose.eyeOpen, lessThan(0.6));
      final paw = m.meshes[ChibiPart.armL]!;
      final (_, pawY, pawZ) = ChibiM4.transformPoint(g.rig[ChibiPart.armL], 0, paw.minY + 0.03, 0.02);
      expect(pawY, greaterThan(0.2), reason: 'bàn chân giơ lên cao');
      expect(pawZ, greaterThan(0.1));
      final w = ChibiActor(m, const [ChibiStep.act(ChibiAction.wave, 50, faceYaw: 0)], x: 0, z: 0);
      _run(w, 2);
      expect(w.pose.armSwingR, greaterThan(1.5));
    });

    test('nhảy lên ổ nằm (ghế cao 0,18 m): ngồi trên đệm, tự liếm chân lúc nghỉ, xong về chỗ cũ', () {
      const bed = Shop3dSpot('bed', 0, 0.6, 0, y: 0.18);
      final a =
          ChibiActor(m, const [ChibiStep.sit(bed, 12), ChibiStep.act(ChibiAction.stand, 50)], x: 0, z: 0, seed: 7);
      _run(a, 1);
      expect(a.isSeated, isTrue);
      expect(a.pose.y, closeTo(0.2, 1e-6));
      var groomed = false;
      for (var i = 0; i < 10 * 60; i++) {
        a.update(_dt, const {});
        if (a.isSeated && a.pose.armSwingL > 1.5) groomed = true;
      }
      expect(groomed, isTrue);
      _run(a, 3);
      expect(a.action, ChibiAction.stand);
      expect(a.pose.y, 0);
      expect(a.pose.z, closeTo(0, 1e-6));
    });
  });

  group('ChibiRoster', () {
    tearDown(ChibiRoster.extra.clear);

    test('dựng sẵn 15 nhân vật; lọc theo nhóm / id / nhiều nhóm; all = tất cả', () {
      expect(ChibiRoster.builtIn.length, 15);
      expect(ChibiRoster.select('all').length, 15);
      expect(ChibiRoster.select('1').length, 15);
      expect(ChibiRoster.select(null).length, 15);
      expect([for (final e in ChibiRoster.select('staff')) e.id], ChibiCharacters.staffIds);
      expect([for (final e in ChibiRoster.select('vip|friends')) e.id],
          [...ChibiCharacters.vipIds, ...ChibiCharacters.friendIds]);
      expect([for (final e in ChibiRoster.select('mochi')) e.id], ['mochi']);
      expect([for (final e in ChibiRoster.select('kenji,vip_00')) e.id], ['vip_00', 'kenji']);
      expect(ChibiRoster.select('không_có'), isEmpty);
      expect(ChibiRoster.byId('vip_02')!.group, ChibiRoster.vip);
    });

    test('chỗ nối register: thêm nhóm mới (khách thường), trùng id thì thay; all gồm cả mục đăng ký', () {
      final fake = ChibiCharacters.build('linh');
      ChibiRoster.register([
        ChibiRosterEntry('regular_00', ChibiRoster.regulars, () => fake),
        ChibiRosterEntry('regular_01', ChibiRoster.regulars, () => fake),
      ]);
      expect(ChibiRoster.select('regulars').length, 2);
      expect(ChibiRoster.select('all').length, 17);
      ChibiRoster.register([ChibiRosterEntry('regular_00', ChibiRoster.regulars, () => fake)]);
      expect(ChibiRoster.select('regulars').length, 2);
      // Đăng ký đè id dựng sẵn: dùng mục mới, không lặp.
      ChibiRoster.register([ChibiRosterEntry('kenji', ChibiRoster.regulars, () => fake)]);
      expect(ChibiRoster.select('all').where((e) => e.id == 'kenji').length, 1);
      expect(ChibiRoster.byId('kenji')!.group, ChibiRoster.regulars);
    });
  });

  group('ChibiLineup', () {
    test('lưới: ≤ 10 người một hàng, chia đều; 30 người (15 dựng sẵn + 15 khách thường) = 3 hàng × 10', () {
      expect(ChibiLineup.grid(1), (1, 1));
      expect(ChibiLineup.grid(8), (1, 8));
      expect(ChibiLineup.grid(11), (2, 6));
      expect(ChibiLineup.grid(27), (3, 9));
      expect(ChibiLineup.grid(30), (3, 10));
      expect(ChibiLineup.grid(45), (5, 9));
    });

    test('mọi chỗ đứng trong phòng, trước quầy, không chồng nhau', () {
      final obstacles = [
        for (final p in Shop3dLayout.propsFor(const {}))
          if (!p.flat)
            for (final part in p.parts)
              if (part.alpha > 0 && part.minY < 1.2) part,
      ];
      for (final n in const [1, 4, 8, 15, 27, 30, 45]) {
        final pts = [for (var i = 0; i < n; i++) ChibiLineup.slot(i, n)];
        for (var i = 0; i < n; i++) {
          final (x, z) = pts[i];
          expect(Shop3dLayout.room.contains(x, 1, z, margin: -0.35), isTrue, reason: '$n #$i ($x, $z)');
          expect(z, greaterThan(0.2), reason: 'trước tủ kính / quầy');
          for (final o in obstacles) {
            final inside = x > o.minX - 0.3 && x < o.maxX + 0.3 && z > o.minZ - 0.3 && z < o.maxZ + 0.3;
            expect(inside, isFalse, reason: '$n #$i ($x, $z)');
          }
          for (var j = i + 1; j < n; j++) {
            final (x2, z2) = pts[j];
            expect(math.sqrt(math.pow(x - x2, 2) + math.pow(z - z2, 2)), greaterThan(0.6), reason: '$n $i-$j');
          }
        }
      }
    });

    test('dựng: đứng tại chỗ quay mặt camera (+z), thở / chớp mắt, không đi lạc', () {
      final entries = ChibiRoster.select('all');
      final actors = ChibiLineup.build(entries, models: models);
      expect([for (final a in actors) a.id], [for (final e in entries) e.id]);
      final start = [for (final a in actors) (a.pose.x, a.pose.z)];
      final d = ChibiDirector(actors);
      final blinked = <String>{};
      for (var t = 0.0; t < 20; t += _dt) {
        d.update(_dt, const {});
        for (final a in actors) {
          if (a.pose.eyeOpen < 0.4) blinked.add(a.id);
        }
      }
      for (var i = 0; i < actors.length; i++) {
        expect(actors[i].pose.x, closeTo(start[i].$1, 1e-9));
        expect(actors[i].pose.z, closeTo(start[i].$2, 1e-9));
        expect(actors[i].pose.yaw.abs(), lessThan(0.05), reason: actors[i].id);
      }
      expect(blinked.length, actors.length);
    });

    test('camera: nhìn trọn hàng trong giới hạn của controller; một con mèo thì nhìn cận, thấp', () {
      for (final n in const [2, 8, 15, 27]) {
        final c = ChibiLineup.camera(n);
        expect(c.distance, inInclusiveRange(1.5, 16), reason: '$n');
        // Hàng ngang vừa khung 16:9, góc dọc 40°.
        final (_, perRow) = ChibiLineup.grid(n);
        final halfW = math.tan(20 * math.pi / 180) * 16 / 9 * c.distance;
        expect(halfW, greaterThan((perRow - 1) * ChibiLineup.spacing / 2 + 0.3), reason: '$n');
      }
      final cat = ChibiLineup.camera(1, small: true);
      expect(cat.distance, lessThan(2));
      expect(cat.y, lessThan(0.5));
    });
  });

  group('ChibiMeshBuilder (bổ sung)', () {
    test('build bỏ qua bộ phận rỗng; model không cầm đồ không có lưới prop', () {
      expect(models['vip_00']!.meshes.containsKey(ChibiPart.prop), isFalse);
      expect(ChibiMeshBuilder().isEmpty, isTrue);
    });
  });
}
