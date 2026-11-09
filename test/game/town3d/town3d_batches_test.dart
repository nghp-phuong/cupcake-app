import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_mesh.dart';
import 'package:sugarleaf_bakery/game/town3d/town_batches.dart';
import 'package:sugarleaf_bakery/game/town3d/town_layout.dart';

/// Gộp lưới quận 1 (town_batches.dart): ô 16 m × bề mặt, ngân sách ≤ 40 entity tĩnh, ≤ 20.000 tam giác, ≤ 8 material
/// (dùng chung với nội thất). Dart thuần — không import thermion.
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  final layout = TownLayout.forDistrict(district);
  final batches = TownBatches.build(layout);
  final stats = TownBatchStats.of(batches);

  test(
    'ngân sách quận 1: ≤ 40 entity tĩnh, ≤ 20.000 tam giác, ≤ 8 material',
    () {
      // ignore: avoid_print
      print('town3d bakery_street static: $stats (${batches.length} ô)');
      expect(stats.entities, lessThanOrEqualTo(40));
      expect(stats.triangles, lessThanOrEqualTo(20000));
      expect(stats.materials, lessThanOrEqualTo(8));
    },
  );

  test(
    'chia ô 16 m: ≤ 6 ô (3 × 2), id duy nhất, mỗi ô chỉ nhận khối có tâm nằm trong ô',
    () {
      final (cols, rows) = TownBatches.cellCount(district);
      expect((cols, rows), (3, 2));
      expect({for (final b in batches) b.id}.length, batches.length);
      for (final b in batches) {
        expect(b.cellX, inInclusiveRange(0, cols - 1));
        expect(b.cellZ, inInclusiveRange(0, rows - 1));
        expect(b.id, 'town:${b.cellX}:${b.cellZ}');
      }
      // Khối nhà đầu tiên nằm trong ô mà TownBatches.cellOf trả về.
      final n3 = layout.props.firstWhere((p) => p.id == 'lot:n3');
      final (cx, cz) = TownBatches.cellOf(
        district,
        n3.parts.first.cx,
        n3.parts.first.cz,
      );
      expect(batches.any((b) => b.cellX == cx && b.cellZ == cz), isTrue);
      // Điểm ngoài biên kẹp về ô sát mép.
      expect(TownBatches.cellOf(district, -99, -99), (0, 0));
      expect(TownBatches.cellOf(district, 99, 99), (cols - 1, rows - 1));
      expect(TownBatches.cellOf(district, -8.01, 0.01), (0, 1));
      expect(TownBatches.cellOf(district, -7.99, -0.01), (1, 0));
    },
  );

  test(
    'không dùng lớp trong suốt; mặt đục là material màu đỉnh (đủ 4 số màu mỗi đỉnh)',
    () {
      for (final b in batches) {
        for (final e in b.meshes.entries) {
          expect(e.key.transparent, isFalse, reason: b.id);
          expect(e.value.colors.length, e.value.vertexCount * 4, reason: b.id);
          expect(e.value.triangleCount, greaterThan(0), reason: b.id);
        }
      }
      final surfaces = {
        for (final b in batches) ...b.meshes.keys.map((k) => k.surface),
      };
      // Chỉ mờ + không chịu ánh sáng (cửa sổ ấm, đèn, nước, biển); không kính, không inox.
      expect(surfaces, {Shop3dSurface.matte, Shop3dSurface.backdrop});
    },
  );

  test(
    'tam giác khớp tổng khối của props + mặt đất (không mất, không nhân đôi)',
    () {
      var expected = 0;
      for (final p in layout.props) {
        for (final part in p.parts) {
          expected += (Shop3dMeshBuilder()..addPart(part))
              .build()
              .triangleCount;
        }
      }
      // Mặt đất: mỗi hộp 12 tam giác; bị cắt theo ô thì nhiều mảnh hơn.
      final groundTris = stats.triangles - expected;
      expect(groundTris, greaterThanOrEqualTo(layout.ground.length * 12));
      expect(groundTris % 12, 0);
    },
  );

  test('đo từng nhóm đồ (in ra để cân đối ngân sách)', () {
    final byProp = <String, int>{};
    for (final p in layout.props) {
      final key = p.id.split(':').take(2).join(':');
      for (final part in p.parts) {
        byProp[key] =
            (byProp[key] ?? 0) +
            (Shop3dMeshBuilder()..addPart(part)).build().triangleCount;
      }
    }
    final top = byProp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print(
      'town3d tris theo nhóm: ${top.map((e) => '${e.key}=${e.value}').join(', ')}; '
      'ground ${layout.ground.length} tiles',
    );
    expect(top, isNotEmpty);
  });

  group('lô chi nhánh: TownBatches.buildLot (docs/v3/city-gd4-spec.md §5)', () {
    final branches = [
      for (final l in district.lots)
        if (l.kind == LotKind.branch) l,
    ];

    /// Tam giác tối đa theo cấp 0..5 (bảng §5).
    const maxTris = [1000, 800, 950, 1100, 1200, 1300];

    int tris(Map<Shop3dSurfaceKey, Shop3dMesh> m) =>
        m.values.fold(0, (s, e) => s + e.triangleCount);

    test(
      'mỗi lô ≤ 2 lưới (mờ + không chịu ánh sáng), không trong suốt; tam giác ≤ bảng §5, tăng theo cấp 1..5',
      () {
        for (final lot in branches) {
          final counts = <int>[];
          for (var lv = 0; lv <= TownLayout.branchMaxLevel; lv++) {
            final m = TownBatches.buildLot(lot, lv);
            expect(m.length, inInclusiveRange(1, 2), reason: '${lot.id} cấp $lv');
            for (final e in m.entries) {
              expect(e.key.transparent, isFalse);
              expect(e.key.surface, isIn([Shop3dSurface.matte, Shop3dSurface.backdrop]));
              expect(e.value.colors.length, e.value.vertexCount * 4);
            }
            final t = tris(m);
            expect(t, lessThanOrEqualTo(maxTris[lv]), reason: '${lot.id} cấp $lv: $t tris');
            counts.add(t);
          }
          // ignore: avoid_print
          print('town3d branch ${lot.id} tris cấp 0..5: ${counts.join(' / ')}');
          for (var lv = 2; lv <= TownLayout.branchMaxLevel; lv++) {
            expect(counts[lv], greaterThan(counts[lv - 1]), reason: '${lot.id} cấp $lv');
          }
        }
      },
    );

    test(
      'ngân sách: tĩnh + 3 lô ở cấp 5 ≤ 20.000 tam giác (mục tiêu 19.500), ≤ 40 entity, ≤ 8 material',
      () {
        var entities = stats.entities, triangles = stats.triangles;
        final keys = <Shop3dSurfaceKey>{
          for (final b in batches) ...b.meshes.keys,
        };
        for (final lot in branches) {
          final m = TownBatches.buildLot(lot, TownLayout.branchMaxLevel);
          entities += m.length;
          triangles += tris(m);
          keys.addAll(m.keys);
        }
        // ignore: avoid_print
        print(
          'town3d tĩnh $stats + 3 lô cấp 5 = $entities entities, ${keys.length} materials, $triangles tris',
        );
        expect(triangles, lessThanOrEqualTo(19500));
        expect(entities, lessThanOrEqualTo(40));
        expect(keys.length, lessThanOrEqualTo(8));
      },
    );

    test('lưới lô khớp tổng khối của mặt tiền (không mất, không nhân đôi)', () {
      for (final lot in branches) {
        for (var lv = 0; lv <= TownLayout.branchMaxLevel; lv++) {
          var expected = 0;
          for (final p in TownLayout.branchFacade(lot, lv)) {
            for (final part in p.parts) {
              expected += (Shop3dMeshBuilder()..addPart(part)).build().triangleCount;
            }
          }
          expect(tris(TownBatches.buildLot(lot, lv)), expected);
        }
      }
    });
  });
}
