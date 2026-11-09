import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_nav.dart'
    show NavBox;
import 'package:sugarleaf_bakery/game/town3d/town_batches.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';
import 'package:sugarleaf_bakery/game/town3d/town_rules.dart';

/// Bố cục quận 1 "Phố Tiệm Bánh" (town_layout.dart): lô, điểm tương tác, hộp chặn, đi tới được. Dart thuần.
///
/// `Shop3dNav` có biên thế giới cứng (x ∈ [-7,5; 7,5], z ∈ [-5; 8]) nên không dùng được cho quận 48 × 32 m → test tự
/// kiểm "hình tròn – hộp chữ nhật" và tìm đường bằng lưới (BFS) trên đúng danh sách [TownLayout.blockers].

/// Bán kính Mai khi kiểm (lớn hơn `Pilot.maxNavRadius` 0,27 m một chút).
const double _r = 0.3;

bool _hits(List<NavBox> boxes, double x, double z, double r) {
  for (final b in boxes) {
    final dx = x < b.minX ? b.minX - x : (x > b.maxX ? x - b.maxX : 0.0);
    final dz = z < b.minZ ? b.minZ - z : (z > b.maxZ ? z - b.maxZ : 0.0);
    if (dx * dx + dz * dz < r * r - 1e-9) return true;
  }
  return false;
}

/// Tập ô lưới 0,15 m có thể đứng được và nối với (sx, sz) bằng bước 4 hướng.
Set<int> _reachable(TownLayout t, double sx, double sz, {double step = 0.15}) {
  final w = ((t.maxX - t.minX) / step).ceil(),
      h = ((t.maxZ - t.minZ) / step).ceil();
  int idx(int i, int j) => j * w + i;
  double cx(int i) => t.minX + (i + 0.5) * step;
  double cz(int j) => t.minZ + (j + 0.5) * step;
  final free = List<bool>.generate(
    w * h,
    (k) => !_hits(t.blockers, cx(k % w), cz(k ~/ w), _r),
  );
  final si = ((sx - t.minX) / step).floor(),
      sj = ((sz - t.minZ) / step).floor();
  final seen = <int>{};
  if (!free[idx(si, sj)]) return seen;
  final q = Queue<int>()..add(idx(si, sj));
  seen.add(idx(si, sj));
  while (q.isNotEmpty) {
    final k = q.removeFirst();
    final i = k % w, j = k ~/ w;
    for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final ni = i + di, nj = j + dj;
      if (ni < 0 || nj < 0 || ni >= w || nj >= h) continue;
      final n = idx(ni, nj);
      if (free[n] && seen.add(n)) q.add(n);
    }
  }
  return seen;
}

void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final town = TownLayout.forDistrict(district);

  test('forDistrict nhớ kết quả; quận 2 (chưa có lô) vẫn dựng được', () {
    expect(identical(TownLayout.forDistrict(district), town), isTrue);
    final sea = TownLayout.forDistrict(CityConfig.alpha.district('sea_market'));
    expect(sea.spots, isEmpty);
    expect(sea.props, isNotEmpty);
  });

  test('mỗi lô nằm trong biên quận và có mục spots; cửa khớp LotDef', () {
    for (final lot in district.lots) {
      expect(lot.minX, greaterThanOrEqualTo(district.minX), reason: lot.id);
      expect(lot.maxX, lessThanOrEqualTo(district.maxX), reason: lot.id);
      expect(lot.minZ, greaterThanOrEqualTo(district.minZ), reason: lot.id);
      expect(lot.maxZ, lessThanOrEqualTo(district.maxZ), reason: lot.id);
      final s = town.spots[lot.id];
      expect(s, isNotNull, reason: lot.id);
      expect(s!.lotId, lot.id);
      expect(s.door.x, lot.doorX);
      expect(s.door.z, lot.doorZ);
    }
    expect(town.spots.keys.toSet(), {for (final l in district.lots) l.id});
  });

  test(
    'quán ăn, tiệm tóc, văn phòng địa ốc có counter + keeper, quán ăn có seat; lô khác không có',
    () {
      for (final lot in district.lots) {
        final s = town.spots[lot.id]!;
        final service =
            lot.kind == LotKind.restaurant ||
            lot.kind == LotKind.salon ||
            lot.kind == LotKind.realty;
        expect(s.counter != null, service, reason: lot.id);
        expect(s.keeper != null, service, reason: lot.id);
        expect(s.seat != null, lot.kind == LotKind.restaurant, reason: lot.id);
      }
      final r = town.spots['n3']!,
          sa = town.spots['n4']!,
          re = town.spots['n1']!;
      // Mai đứng trên vỉa hè (z ∈ [-5,5; -3]) trước ô cửa, chủ quán ở trong nhà (z < -5,5), cùng cột x.
      for (final s in [r, sa, re]) {
        expect(s.counter!.z, inInclusiveRange(-5.5, -3.0));
        expect(s.keeper!.z, lessThan(-5.5));
        expect(s.keeper!.x, s.counter!.x);
        expect(s.counter!.yaw, closeTo(3.14159, 1e-3)); // nhìn -z, vào ô cửa
        expect(s.keeper!.yaw, closeTo(0, 1e-9)); // nhìn +z, ra phố
      }
      // Ghế hiên nằm trong lô quán ăn, quay vào bàn (bàn ở phía +x của ghế).
      final lot = district.lot('n3');
      expect(r.seat!.x, inInclusiveRange(lot.minX, lot.maxX));
      expect(r.seat!.z, inInclusiveRange(lot.minZ, lot.maxZ));
      expect(r.seat!.yaw, closeTo(3.14159 / 2, 1e-3));
    },
  );

  test(
    'văn phòng địa ốc: quầy ở l = +3 quanh (−15; −5,0), vùng quầy cách vùng cửa 3 m, không chồng nhau',
    () {
      final re = town.spots['n1']!;
      expect(re.counter!.x, closeTo(-15, 1e-9));
      expect(re.counter!.z, closeTo(-5.0, 1e-9));
      expect(re.keeper!.x, closeTo(-15, 1e-9));
      final dx = re.counter!.x - re.door.x, dz = re.counter!.z - re.door.z;
      final gap = math.sqrt(dx * dx + dz * dz);
      expect(gap, closeTo(3.0, 0.1));
      expect(gap, greaterThan(TownRules.doorRadius + TownRules.counterRadius));
      final zones = TownRules.zonesOf(town).where((z) => z.lotId == 'n1');
      expect(zones.map((z) => z.kind).toSet(), {
        TownZoneKind.door,
        TownZoneKind.counter,
      });
    },
  );

  test(
    'điểm xuất hiện, trạm buýt, cửa, quầy, ghế đứng được (không nằm trong hộp chặn)',
    () {
      expect(town.spawn.x, district.spawnX);
      expect(town.spawn.z, district.spawnZ);
      expect(town.bus.x, district.busX);
      expect(town.bus.z, district.busZ);
      final named = <String, TownPoint>{
        'spawn': town.spawn,
        'bus': town.bus,
        for (final e in town.spots.entries) ...{
          '${e.key}.door': e.value.door,
          if (e.value.counter != null) '${e.key}.counter': e.value.counter!,
          if (e.value.seat != null) '${e.key}.seat': e.value.seat!,
        },
      };
      for (final e in named.entries) {
        expect(
          _hits(town.blockers, e.value.x, e.value.z, _r),
          isFalse,
          reason: '${e.key} ${e.value}',
        );
      }
      // Chủ quán đứng trong nhà: nằm trong hộp chặn (Mai không tới được).
      for (final id in ['n1', 'n3', 'n4']) {
        final k = town.spots[id]!.keeper!;
        expect(
          _hits(town.blockers, k.x, k.z, 0.05),
          isTrue,
          reason: '$id keeper',
        );
      }
    },
  );

  test(
    'từ điểm xuất hiện đi tới được mọi cửa, quầy, ghế, trạm buýt (4 hướng, bán kính 0,3 m)',
    () {
      final reach = _reachable(town, town.spawn.x, town.spawn.z);
      expect(reach, isNotEmpty);
      const step = 0.15;
      final w = ((town.maxX - town.minX) / step).ceil();
      // Ô chứa điểm hoặc một ô kề: cửa lô chi nhánh nằm đúng 0,3 m trước hộp chặn cố định (d = 0,3), tâm ô lưới
      // 0,15 m có thể gần hộp hơn điểm thật vài cm.
      bool ok(TownPoint p) {
        final i = ((p.x - town.minX) / step).floor(),
            j = ((p.z - town.minZ) / step).floor();
        for (final (di, dj) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
          if (reach.contains((j + dj) * w + i + di)) return true;
        }
        return false;
      }

      expect(ok(town.bus), isTrue, reason: 'bus');
      for (final e in town.spots.entries) {
        expect(ok(e.value.door), isTrue, reason: '${e.key}.door');
        final c = e.value.counter, st = e.value.seat;
        if (c != null) expect(ok(c), isTrue, reason: '${e.key}.counter');
        if (st != null) expect(ok(st), isTrue, reason: '${e.key}.seat');
      }
      // Không có khoảng đi được nào nằm ngoài biên quận (kín: không lọt ra ngoài).
      for (final k in reach) {
        final x = town.minX + (k % w + 0.5) * step,
            z = town.minZ + (k ~/ w + 0.5) * step;
        expect(x, inInclusiveRange(town.minX, town.maxX));
        expect(z, inInclusiveRange(town.minZ, town.maxZ));
      }
    },
  );

  test(
    'đồ dựng: id duy nhất, không chạm được, không trong suốt, không chìm quá sâu, trong vùng nhìn',
    () {
      final ids = <String>{};
      for (final p in town.props) {
        expect(ids.add(p.id), isTrue, reason: 'trùng id ${p.id}');
        expect(p.pickable, isFalse, reason: p.id);
        expect(p.parts, isNotEmpty, reason: p.id);
        for (final part in p.parts) {
          expect(part.alpha, 1.0, reason: p.id);
          expect(part.minY, greaterThan(-0.3), reason: p.id);
          expect(part.maxY, lessThan(9), reason: p.id);
          expect(part.cx.abs(), lessThan(80), reason: p.id);
          expect(part.cz.abs(), lessThan(80), reason: p.id);
        }
      }
      for (final id in [
        'lot:n1',
        'lot:n2',
        'lot:n3',
        'lot:n4',
        'lot:s2',
        'busStop',
      ]) {
        expect(ids, contains(id));
      }
      // Lô chi nhánh không có đồ trong bố cục chung (dựng riêng theo cấp: TownLayout.branchFacade).
      for (final id in ['lot:s1', 'lot:s3', 'lot:s4']) {
        expect(ids, isNot(contains(id)));
      }
    },
  );

  test('hộp chặn hợp lệ và nhà không tràn ra mặt đường / vỉa hè', () {
    for (final b in town.blockers) {
      expect(b.minX, lessThan(b.maxX));
      expect(b.minZ, lessThan(b.maxZ));
    }
    // Không hộp chặn nào chiếm lòng đường, ngoài hai thanh chắn ở hai đầu phố (x sát biên).
    for (final b in town.blockers) {
      final inRoad =
          b.minZ < district.roadHalfWidth && b.maxZ > -district.roadHalfWidth;
      if (inRoad) {
        final atEnd =
            b.maxX <= district.minX + 0.5 || b.minX >= district.maxX - 0.5;
        // cột đèn, bồn hoa nằm trên vỉa hè (|z| ≥ 3), chỉ thanh chắn / biên mới cắt lòng đường
        expect(
          atEnd ||
              b.minZ >= district.roadHalfWidth ||
              b.maxZ <= -district.roadHalfWidth,
          isTrue,
          reason: '$b',
        );
      }
    }
  });

  group('lô chi nhánh (docs/v3/city-gd4-spec.md §5)', () {
    final branches = [
      for (final l in district.lots)
        if (l.kind == LotKind.branch) l,
    ];
    const levels = [0, 1, 2, 3, 4, 5];

    /// Khung lô: độ sâu d từ mép vỉa hè vào trong lô (lô nam d = z − doorZ, lô bắc d = doorZ − z).
    double depthOf(LotDef lot, double z) =>
        math.cos(lot.yaw) > 0 ? lot.doorZ - z : z - lot.doorZ;

    test('đủ 3 lô chi nhánh s1, s3, s4', () {
      expect([for (final l in branches) l.id], ['s1', 's3', 's4']);
    });

    test(
      'bố cục chung: không còn khối nào trong lô chi nhánh, chỉ một hộp chặn cố định',
      () {
        for (final lot in branches) {
          for (final p in town.props) {
            for (final part in p.parts) {
              final inside =
                  part.cx > lot.minX &&
                  part.cx < lot.maxX &&
                  part.cz > lot.minZ &&
                  part.cz < lot.maxZ;
              expect(inside, isFalse, reason: '${p.id} trong ${lot.id}');
            }
          }
          // Hộp chặn [-5,4; 5,4] × [0,3; 9,95] của khung lô (lô nam: x = doorX − l, z = doorZ + d).
          final sgn = math.cos(lot.yaw) > 0 ? -1.0 : 1.0;
          final z0 = lot.doorZ + sgn * TownLayout.branchBlockD0,
              z1 = lot.doorZ + sgn * TownLayout.branchBlockD1;
          final want = NavBox(
            lot.doorX - TownLayout.branchBlockL,
            lot.doorX + TownLayout.branchBlockL,
            math.min(z0, z1),
            math.max(z0, z1),
          );
          expect(
            town.blockers.where(
              (b) =>
                  (b.minX - want.minX).abs() < 1e-9 &&
                  (b.maxX - want.maxX).abs() < 1e-9 &&
                  (b.minZ - want.minZ).abs() < 1e-9 &&
                  (b.maxZ - want.maxZ).abs() < 1e-9,
            ),
            hasLength(1),
            reason: lot.id,
          );
        }
        expect(TownLayout.branchBlockL, 5.4);
        expect(TownLayout.branchBlockD0, 0.3);
        expect(TownLayout.branchBlockD1, 9.95);
      },
    );

    test(
      'hộp chặn giống nhau ở mọi cấp (dựng mặt tiền không đổi bố cục / điều hướng)',
      () {
        final before = [
          for (final b in town.blockers) (b.minX, b.maxX, b.minZ, b.maxZ),
        ];
        for (final lot in branches) {
          for (final lv in levels) {
            TownLayout.branchFacade(lot, lv);
            TownBatches.buildLot(lot, lv);
          }
        }
        expect(identical(TownLayout.forDistrict(district), town), isTrue);
        expect([
          for (final b in town.blockers) (b.minX, b.maxX, b.minZ, b.maxZ),
        ], before);
      },
    );

    test(
      'mặt tiền cấp 0..5: không rỗng, id riêng, không chạm được, không trong suốt',
      () {
        for (final lot in branches) {
          for (final lv in levels) {
            final props = TownLayout.branchFacade(lot, lv);
            expect(props, isNotEmpty, reason: '${lot.id} cấp $lv');
            for (final p in props) {
              expect(p.id, 'branch:${lot.id}');
              expect(p.pickable, isFalse);
              expect(p.parts, isNotEmpty, reason: '${lot.id} cấp $lv');
              for (final part in p.parts) {
                expect(part.alpha, 1.0);
              }
            }
          }
          // Cấp ngoài khoảng kẹp về 0..5.
          expect(
            TownLayout.branchFacade(lot, 9).first.parts.length,
            TownLayout.branchFacade(lot, 5).first.parts.length,
          );
          expect(
            TownLayout.branchFacade(lot, -1).first.parts.length,
            TownLayout.branchFacade(lot, 0).first.parts.length,
          );
        }
      },
    );

    test(
      'mặt tiền cấp 0..5: mọi đỉnh nằm trong lô, không lấn vỉa hè, dưới đường bao 0,6 + 0,8·d',
      () {
        const eps = 1e-4; // lưới lưu Float32
        for (final lot in branches) {
          for (final lv in levels) {
            final meshes = TownBatches.buildLot(lot, lv).values;
            expect(meshes, isNotEmpty);
            for (final m in meshes) {
              final p = m.positions;
              for (var k = 0; k < p.length; k += 3) {
                final x = p[k], y = p[k + 1], z = p[k + 2];
                final d = depthOf(lot, z);
                final where = '${lot.id} cấp $lv: đỉnh ($x, $y, $z), d = $d';
                expect(
                  x,
                  inInclusiveRange(lot.minX - eps, lot.maxX + eps),
                  reason: where,
                );
                expect(d, greaterThanOrEqualTo(-eps), reason: where);
                expect(d, lessThanOrEqualTo(lot.d - 0.05), reason: where);
                expect(y, greaterThan(-0.05), reason: where);
                expect(
                  y,
                  lessThanOrEqualTo(TownRules.branchEnvelope(d) + eps),
                  reason: where,
                );
              }
            }
          }
        }
      },
    );

    test('đường bao: 0,6 m ở mép vỉa hè, 2,52 m ở tường trước d = 2,4', () {
      expect(TownRules.branchEnvelope(0), closeTo(0.6, 1e-12));
      expect(TownRules.branchEnvelope(2.4), closeTo(2.52, 1e-12));
    });
  });
}
