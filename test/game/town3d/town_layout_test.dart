import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_nav.dart'
    show NavBox;
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';

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
    'quán ăn và tiệm tóc có counter + keeper, quán ăn có seat; lô khác không có',
    () {
      for (final lot in district.lots) {
        final s = town.spots[lot.id]!;
        final service =
            lot.kind == LotKind.restaurant || lot.kind == LotKind.salon;
        expect(s.counter != null, service, reason: lot.id);
        expect(s.keeper != null, service, reason: lot.id);
        expect(s.seat != null, lot.kind == LotKind.restaurant, reason: lot.id);
      }
      final r = town.spots['n3']!, sa = town.spots['n4']!;
      // Mai đứng trên vỉa hè (z ∈ [-5,5; -3]) trước ô cửa, chủ quán ở trong nhà (z < -5,5), cùng cột x.
      for (final s in [r, sa]) {
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
      for (final id in ['n3', 'n4']) {
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
      bool ok(TownPoint p) {
        final i = ((p.x - town.minX) / step).floor(),
            j = ((p.z - town.minZ) / step).floor();
        return reach.contains(j * w + i);
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
        'lot:s1',
        'lot:s2',
        'lot:s3',
        'lot:s4',
        'busStop',
      ]) {
        expect(ids, contains(id));
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
}
