import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_batches.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_math.dart' show RoomWall;
import 'package:sugarleaf_bakery/game/shop3d/shop3d_mesh.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_pick.dart';

/// Nhóm lưới tĩnh của tiệm 3D (shop3d_batches.dart): số entity / draw call / material trước và sau khi gộp (số liệu ghi
/// ở docs/v3/thermion-api-notes.md mục 9.27). Dart thuần — không import thermion.

/// Cách cũ (đến 04/11): mỗi vật thể / mặt tường một lưới cho mỗi (màu, alpha), material một màu; đất + vỉa hè 2 lưới.
({int entities, int drawn, int materials, int triangles}) _oldStats(Set<String> owned) {
  var entities = 2, drawn = 2, tris = 0;
  final keys = <Shop3dMaterialKey>{const Shop3dMaterialKey(0xFFDDEBCF, 1), const Shop3dMaterialKey(0xFFEEDFCB, 1)};
  void add(Iterable<Shop3dPart> parts, bool on) {
    final groups = <Shop3dMaterialKey, Shop3dMeshBuilder>{};
    for (final p in parts) {
      groups.putIfAbsent(Shop3dMaterialKey.of(p), Shop3dMeshBuilder.new).addPart(p);
    }
    for (final e in groups.entries) {
      entities++;
      if (on) drawn++;
      keys.add(e.key);
      tris += e.value.build().triangleCount;
    }
  }

  for (final p in [...Shop3dLayout.floorProps, ...Shop3dLayout.props, ...Shop3dLayout.outdoorProps]) {
    add(p.parts, p.enabledFor(owned));
  }
  for (final w in RoomWall.values) {
    add(Shop3dLayout.walls[w]!, true);
  }
  return (entities: entities, drawn: drawn, materials: keys.length, triangles: tris + 24);
}

void main() {
  final batches = Shop3dBatches.build();
  const owned = {Shop3dRequires.cafeTables}; // mặc định của Shop3dView

  test('trước / sau: entity giảm ≥ 60 %, material ≤ 8, tam giác giữ nguyên', () {
    final before = _oldStats(owned);
    final after = Shop3dBatchStats.of(batches, owned: owned);
    final allOn = Shop3dBatchStats.of(batches, owned: Shop3dRequires.all);
    // ignore: avoid_print
    print(
      'shop3d static: before ${before.entities} entities (${before.drawn} drawn), ${before.materials} materials, '
      '${before.triangles} tris → after $after; all owned: ${allOn.drawn} drawn',
    );
    expect(after.triangles, before.triangles);
    expect(after.entities, lessThanOrEqualTo(before.entities * 2 ~/ 5));
    expect(after.drawn, lessThanOrEqualTo(before.drawn * 2 ~/ 5));
    expect(after.materials, lessThanOrEqualTo(8));
    expect(allOn.drawn, after.entities);
  });

  test('mỗi vật chạm được một nhóm riêng (nhún được), vật không chạm được gộp theo cờ mở rộng', () {
    final props = [...Shop3dLayout.floorProps, ...Shop3dLayout.props];
    final pickable = [
      for (final p in props)
        if (pickBoxesForProp(p).isNotEmpty) p.id,
    ];
    expect([for (final b in batches.where((b) => b.kind == Shop3dBatchKind.prop)) b.prop!.id], pickable);
    for (final b in batches.where((b) => b.kind == Shop3dBatchKind.prop)) {
      expect(b.requires, b.prop!.requires);
      expect(b.meshes.length, lessThanOrEqualTo(3), reason: b.id);
    }
    final scenery = batches.where((b) => b.kind == Shop3dBatchKind.scenery).toList();
    final flags = {
      for (final p in props)
        if (pickBoxesForProp(p).isEmpty) p.requires,
    }..add(null);
    expect({for (final b in scenery) b.requires}, flags);
    // Nền luôn có: một lưới đục duy nhất (đất, vỉa hè, sàn, gạch, thảm cửa, bục).
    final base = scenery.firstWhere((b) => b.requires == null);
    expect(base.meshes.keys, [const Shop3dSurfaceKey.opaque(Shop3dSurface.matte)]);
    expect(base.castsShadow(base.meshes.keys.first), isFalse);
  });

  test('mỗi mặt tường một nhóm; tam giác mỗi nhóm khớp khối của nó', () {
    final walls = batches.where((b) => b.kind == Shop3dBatchKind.wall).toList();
    expect([for (final b in walls) b.wall], RoomWall.values);
    for (final b in walls) {
      final tris = Shop3dLayout.walls[b.wall]!.fold<int>(
        0,
        (s, p) => s + (Shop3dMeshBuilder()..addPart(p)).build().triangleCount,
      );
      expect(b.triangleCount, tris, reason: b.id);
      expect(b.requires, isNull);
    }
    final hidden = Shop3dBatchStats.of(batches, owned: owned, hiddenWalls: {RoomWall.front, RoomWall.ceiling});
    final shown = Shop3dBatchStats.of(batches, owned: owned);
    final frontCeiling = walls
        .where((b) => b.wall == RoomWall.front || b.wall == RoomWall.ceiling)
        .fold<int>(0, (s, b) => s + b.meshes.length);
    expect(shown.drawn - hidden.drawn, frontCeiling);
  });

  test('đồ trang trí pickable: false không thêm entity, chỉ thêm tam giác vào nền', () {
    const deco = Shop3dProp(
        'decoVase',
        Shop3dZone.decor,
        [
          Shop3dPart.cyl(Shop3dColor.mint, 4.6, 0, -1.6, 0.2, 0.3),
          Shop3dPart.ball(Shop3dColor.strawberry, 4.6, 0.3, -1.6, 0.18),
          Shop3dPart.cyl(Shop3dColor.steel, 4.6, 0.3, -1.9, 0.05, 0.2),
        ],
        pickable: false);
    final props = [...Shop3dLayout.floorProps, ...Shop3dLayout.props, ...Shop3dLayout.outdoorProps];
    final withDeco = Shop3dBatches.build(props: [...props, deco]);
    final a = Shop3dBatchStats.of(batches, owned: owned), b = Shop3dBatchStats.of(withDeco, owned: owned);
    // Đục mờ vào lưới nền có sẵn; kim loại tạo thêm đúng 1 lưới nền (độ nhám khác) nếu nền chưa có.
    expect(b.entities - a.entities, lessThanOrEqualTo(1));
    expect(b.triangles, greaterThan(a.triangles));
    expect(pickBoxesForProp(deco), isEmpty);
  });

  test('ngân sách bài trí (decor-proposal.md, P1 + P2 + P3): ≤ 60 entity tĩnh trong scene, ≤ 25k tam giác tĩnh', () {
    final def = Shop3dBatchStats.of(batches, owned: owned);
    final all = Shop3dBatchStats.of(batches, owned: Shop3dRequires.all);
    // ignore: avoid_print
    print('shop3d decor budget: default $def; all owned $all');
    for (final s in [def, all]) {
      expect(s.drawn, lessThanOrEqualTo(60));
      expect(s.drawnTriangles, lessThanOrEqualTo(25000));
    }
    expect(all.entities, lessThanOrEqualTo(60));
    expect(all.triangles, lessThanOrEqualTo(25000));
    expect(all.materials, lessThanOrEqualTo(8));
    // Lớp trong suốt: chỉ kính (một material cho cửa sổ + tủ), cửa lò, quầng sáng giả trên bàn (cùng màu vàng bơ).
    final tints = {
      for (final b in batches)
        for (final k in b.meshes.keys)
          if (k.tint case final t?) t.argb,
    };
    expect(tints, {Shop3dColor.glass.argb, Shop3dColor.butter.argb});
  });

  test('mặt tiền ngoài cửa (vỉa hè, bậc thềm, chậu hoa, ghế băng): không chạm được, 0 entity thêm, vào lưới nền', () {
    expect(Shop3dLayout.outdoorProps, isNotEmpty);
    for (final p in Shop3dLayout.outdoorProps) {
      expect(Shop3dBatches.isPickable(p), isFalse, reason: p.id);
      expect(p.requires, isNull, reason: p.id);
    }
    final without = Shop3dBatches.build(props: [...Shop3dLayout.floorProps, ...Shop3dLayout.props]);
    final a = Shop3dBatchStats.of(without, owned: owned), b = Shop3dBatchStats.of(batches, owned: owned);
    expect(b.entities, a.entities);
    expect(b.triangles, greaterThan(a.triangles));
  });

  test('mặt đục dùng material màu đỉnh, mặt trong suốt giữ material một màu', () {
    for (final b in batches) {
      for (final e in b.meshes.entries) {
        expect(e.key.transparent, e.key.tint != null);
        expect(e.value.colors.length, e.value.vertexCount * 4);
        if (e.key.transparent) expect(b.castsShadow(e.key), isFalse);
      }
    }
  });
}
