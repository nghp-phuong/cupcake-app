import '../../core/city/city_config.dart';
import '../shop3d/shop3d_mesh.dart';
import 'town_layout.dart';

/// Một nhóm lưới tĩnh của quận: mọi khối nằm trong cùng một ô lưới ([TownBatches.cellSize], mặc định 16 m) — mỗi khoá
/// bề mặt ([Shop3dSurfaceKey]) một lưới = một entity / draw call khi nằm trong scene. Nhờ chia ô, Filament loại được
/// cả ô nằm ngoài khung nhìn khi Mai đứng ở đầu kia phố.
class TownBatch {
  const TownBatch._(this.id, this.cellX, this.cellZ, this.meshes);

  /// `town:<cellX>:<cellZ>`.
  final String id;

  /// Chỉ số ô (0 ở góc tây-bắc của quận, tăng theo +x / +z).
  final int cellX, cellZ;
  final Map<Shop3dSurfaceKey, Shop3dMesh> meshes;

  int get triangleCount => meshes.values.fold(0, (s, m) => s + m.triangleCount);
}

/// Số liệu đo của một tập nhóm (test / lớp debug) — cùng nghĩa với `Shop3dBatchStats`.
class TownBatchStats {
  const TownBatchStats(this.entities, this.materials, this.triangles);

  factory TownBatchStats.of(Iterable<TownBatch> batches) {
    var entities = 0, tris = 0;
    final keys = <Shop3dSurfaceKey>{};
    for (final b in batches) {
      for (final e in b.meshes.entries) {
        entities++;
        tris += e.value.triangleCount;
        keys.add(e.key);
      }
    }
    return TownBatchStats(entities, keys.length, tris);
  }

  /// Entity tĩnh (mỗi lưới của mỗi nhóm một entity).
  final int entities;

  /// Material khác nhau (đục theo độ nhám + không chịu ánh sáng; không có lớp trong suốt).
  final int materials;
  final int triangles;

  @override
  String toString() =>
      '$entities entities, $materials materials, $triangles tris';
}

/// Gộp bố cục quận ([TownLayout]) thành ít lưới tĩnh nhất: ô 16 m × bề mặt (Dart thuần — cảnh Thermion chỉ việc tạo mỗi
/// lưới một entity với material màu đỉnh của `Shop3dSurfaceKey`).
///
/// - Khối của [TownLayout.props] vào ô chứa tâm khối; mặt đất ([TownLayout.ground]) bị cắt theo đường chia ô nằm trong
///   quận (phần ngoài biên dồn vào ô sát mép) nên đất, đường dài 48 m cũng loại được theo ô.
/// - Màu nằm trong màu đỉnh; chỉ có vài bề mặt: mờ (`matte`, hầu hết) và không chịu ánh sáng (`backdrop`: cửa sổ ấm,
///   đèn, biển, bọt sóng, nước đài phun). Không dùng kính trong suốt / lớp chồng (fill-rate máy yếu).
abstract final class TownBatches {
  static const double cellSize = 16;

  /// Số ô theo (x, z) của quận [d].
  static (int, int) cellCount(DistrictDef d, {double cell = cellSize}) =>
      (((d.maxX - d.minX) / cell).ceil(), ((d.maxZ - d.minZ) / cell).ceil());

  /// Ô chứa điểm (x, z), kẹp vào lưới của quận (điểm ngoài biên thuộc ô sát mép).
  static (int, int) cellOf(
    DistrictDef d,
    double x,
    double z, {
    double cell = cellSize,
  }) {
    final (cols, rows) = cellCount(d, cell: cell);
    return (
      ((x - d.minX) / cell).floor().clamp(0, cols - 1),
      ((z - d.minZ) / cell).floor().clamp(0, rows - 1),
    );
  }

  static List<TownBatch> build(TownLayout layout, {double cell = cellSize}) {
    final d = layout.district;
    final (cols, _) = cellCount(d, cell: cell);
    final builders = <int, Map<Shop3dSurfaceKey, Shop3dMeshBuilder>>{};
    Shop3dMeshBuilder builderFor(int cx, int cz, Shop3dSurfaceKey key) =>
        builders
            .putIfAbsent(cz * cols + cx, () => {})
            .putIfAbsent(key, Shop3dMeshBuilder.new);

    for (final prop in layout.props) {
      for (final part in prop.parts) {
        final (cx, cz) = cellOf(d, part.cx, part.cz, cell: cell);
        builderFor(cx, cz, Shop3dSurfaceKey.ofPart(part)).addPart(part);
      }
    }
    for (final tile in layout.ground) {
      final key = Shop3dSurfaceKey.of(tile.argb, 1);
      for (final (x0, x1, z0, z1) in _split(tile, d, cell)) {
        final (cx, cz) = cellOf(d, (x0 + x1) / 2, (z0 + z1) / 2, cell: cell);
        builderFor(cx, cz, key)
          ..setColor(tile.argb)
          ..addBox(
            (x0 + x1) / 2,
            (tile.top + tile.bottom) / 2,
            (z0 + z1) / 2,
            x1 - x0,
            tile.top - tile.bottom,
            z1 - z0,
          );
      }
    }
    final ids = builders.keys.toList()..sort();
    return [
      for (final id in ids)
        TownBatch._('town:${id % cols}:${id ~/ cols}', id % cols, id ~/ cols, {
          for (final e in builders[id]!.entries)
            if (!e.value.isEmpty) e.key: e.value.build(),
        }),
    ];
  }

  /// Lưới mặt tiền lô chi nhánh [lot] ở cấp [level] ([TownLayout.branchFacade], toạ độ lớp phố): một lưới mỗi bề mặt —
  /// tối đa 2 (mờ + không chịu ánh sáng), tức ≤ 2 entity mỗi lô. Cảnh dựng lưới mới xong mới gỡ lưới cũ khi đổi cấp.
  static Map<Shop3dSurfaceKey, Shop3dMesh> buildLot(LotDef lot, int level) =>
      buildMeshesBySurface([
        for (final p in TownLayout.branchFacade(lot, level)) ...p.parts,
      ]);

  /// Cắt [t] theo các đường chia ô nằm trong quận (không cắt phần ngoài biên → ít mảnh).
  static Iterable<(double, double, double, double)> _split(
    TownGroundTile t,
    DistrictDef d,
    double cell,
  ) sync* {
    List<double> cuts(double lo, double hi, double dLo, double dHi) {
      final out = <double>[lo];
      for (var c = dLo + cell; c < dHi - 1e-9; c += cell) {
        if (c > lo + 1e-9 && c < hi - 1e-9) out.add(c);
      }
      out.add(hi);
      return out;
    }

    final xs = cuts(t.minX, t.maxX, d.minX, d.maxX),
        zs = cuts(t.minZ, t.maxZ, d.minZ, d.maxZ);
    for (var i = 0; i < xs.length - 1; i++) {
      for (var j = 0; j < zs.length - 1; j++) {
        yield (xs[i], xs[i + 1], zs[j], zs[j + 1]);
      }
    }
  }
}
