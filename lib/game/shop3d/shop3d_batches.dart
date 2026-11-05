import 'shop3d_layout.dart';
import 'shop3d_math.dart' show RoomWall;
import 'shop3d_mesh.dart';
import 'shop3d_pick.dart' show pickBoxesForProp;

/// Loại nhóm lưới tĩnh của cảnh.
enum Shop3dBatchKind {
  /// Nền + mọi vật không chạm được (sàn, gạch, thảm, bục, đồ trang trí `pickable: false`) cùng cờ mở rộng — không nhún,
  /// không chọn, chỉ bật / tắt theo [Shop3dBatch.requires].
  scenery,

  /// Một vật thể chạm chọn được ([Shop3dBatch.prop]) — nhún riêng khi được chọn.
  prop,

  /// Một mặt tường + đồ gắn tường — ẩn / hiện theo góc camera ([Shop3dBatch.wall]).
  wall,
}

/// Một nhóm lưới tĩnh: mỗi khoá [Shop3dSurfaceKey] một lưới = một entity / draw call khi nằm trong scene.
class Shop3dBatch {
  const Shop3dBatch._(this.kind, this.id, this.meshes, {this.prop, this.wall, this.requires});

  final Shop3dBatchKind kind;
  final String id;
  final Map<Shop3dSurfaceKey, Shop3dMesh> meshes;

  /// Vật thể (khi [kind] = [Shop3dBatchKind.prop]).
  final Shop3dProp? prop;

  /// Mặt tường (khi [kind] = [Shop3dBatchKind.wall]).
  final RoomWall? wall;

  /// Cờ mở rộng (`Shop3dRequires`); null = luôn có.
  final String? requires;

  bool enabledFor(Set<String> owned) => requires == null || owned.contains(requires);

  /// Lưới đục của vật thể đổ bóng (khi bật bóng động); nền / tường / kính không đổ bóng.
  bool castsShadow(Shop3dSurfaceKey key) => kind == Shop3dBatchKind.prop && !key.transparent;

  int get triangleCount => meshes.values.fold(0, (s, m) => s + m.triangleCount);
}

/// Chia tiệm thành các nhóm lưới tĩnh ít entity nhất mà vẫn giữ được bật / tắt theo cờ mở rộng, ẩn tường theo camera và
/// nhún từng vật được chạm (Dart thuần — cảnh Thermion chỉ việc tạo mỗi lưới một entity).
///
/// - Mặt đục dùng màu đỉnh + một material chung theo độ nhám ([Shop3dSurfaceKey]) → một vật thể thường 1–2 lưới.
/// - Vật không chạm được gộp chung theo cờ [Shop3dProp.requires] ([Shop3dBatchKind.scenery]) cùng đất + vỉa hè.
///
/// Thêm đồ trang trí rẻ nhất: vật `pickable: false` (hoặc khối gắn vào danh sách tường) → không thêm entity nào, chỉ
/// thêm tam giác vào lưới chung; vật chạm được → +1 entity (+1 nếu có kim loại, +1 cho mỗi màu trong suốt).
abstract final class Shop3dBatches {
  /// Đất quanh tiệm và vỉa hè (ngoài layout, chỉ để cảnh không lơ lửng). Mặt trên đất dưới sàn tiệm (y = 0) 4 cm; vỉa hè nhô lên 1 cm so với đất (P3: trước đó cùng độ cao nên bị đất che
  /// khi nhìn từ ngoài vào) — mặt trên -3 cm, khớp [Shop3dLayout.sidewalkTop].
  static const int groundArgb = 0xFFDDEBCF;
  static const int sidewalkArgb = 0xFFEEDFCB;

  static void _addGround(Shop3dMeshBuilder b) {
    b
      ..setColor(groundArgb)
      ..addBox(0, -0.09, 0, 44, 0.1, 44)
      ..setColor(sidewalkArgb)
      ..addBox(0, -0.05, 5.6, 14, 0.04, 2.6);
  }

  /// Vật thể nhận chạm (có hộp chạm) → nhóm riêng; còn lại gộp vào nền.
  static bool isPickable(Shop3dProp prop) => pickBoxesForProp(prop).isNotEmpty;

  /// Các nhóm của bố cục [props] (mặc định: sàn + vật thể + mặt tiền ngoài cửa của [Shop3dLayout]) và [walls]. Thứ tự: nền (cờ null trước),
  /// vật thể, tường.
  static List<Shop3dBatch> build({List<Shop3dProp>? props, Map<RoomWall, List<Shop3dPart>>? walls}) {
    final all = props ?? [...Shop3dLayout.floorProps, ...Shop3dLayout.props, ...Shop3dLayout.outdoorProps];
    final wallParts = walls ?? Shop3dLayout.walls;

    // Nền: builder theo (cờ, khoá bề mặt). Cờ null có sẵn đất + vỉa hè.
    final ground = Shop3dMeshBuilder();
    _addGround(ground);
    final scenery = <String?, Map<Shop3dSurfaceKey, Shop3dMeshBuilder>>{
      null: {const Shop3dSurfaceKey.opaque(Shop3dSurface.matte): ground},
    };
    final batches = <Shop3dBatch>[];
    for (final prop in all) {
      if (isPickable(prop)) {
        batches.add(
          Shop3dBatch._(
            Shop3dBatchKind.prop,
            prop.id,
            buildMeshesBySurface(prop.parts),
            prop: prop,
            requires: prop.requires,
          ),
        );
        continue;
      }
      final group = scenery.putIfAbsent(prop.requires, () => {});
      for (final part in prop.parts) {
        group.putIfAbsent(Shop3dSurfaceKey.ofPart(part), Shop3dMeshBuilder.new).addPart(part);
      }
    }
    return [
      for (final e in scenery.entries)
        Shop3dBatch._(
            Shop3dBatchKind.scenery,
            'scenery:${e.key ?? 'base'}',
            {
              for (final m in e.value.entries)
                if (!m.value.isEmpty) m.key: m.value.build(),
            },
            requires: e.key),
      ...batches,
      for (final wall in RoomWall.values)
        if (wallParts[wall] case final parts? when parts.isNotEmpty)
          Shop3dBatch._(Shop3dBatchKind.wall, 'wall:${wall.name}', buildMeshesBySurface(parts), wall: wall),
    ];
  }
}

/// Số liệu đo của một tập nhóm (test / lớp debug).
class Shop3dBatchStats {
  const Shop3dBatchStats(this.entities, this.drawn, this.materials, this.triangles, this.drawnTriangles);

  /// Tính cho [batches] khi tiệm sở hữu [owned], ẩn các mặt tường trong [hiddenWalls].
  factory Shop3dBatchStats.of(
    List<Shop3dBatch> batches, {
    Set<String> owned = const {},
    Set<RoomWall> hiddenWalls = const {},
  }) {
    var entities = 0, drawn = 0, tris = 0, drawnTris = 0;
    final keys = <Shop3dSurfaceKey>{};
    for (final b in batches) {
      final on = b.enabledFor(owned) && (b.wall == null || !hiddenWalls.contains(b.wall));
      for (final e in b.meshes.entries) {
        entities++;
        tris += e.value.triangleCount;
        keys.add(e.key);
        if (on) {
          drawn++;
          drawnTris += e.value.triangleCount;
        }
      }
    }
    return Shop3dBatchStats(entities, drawn, keys.length, tris, drawnTris);
  }

  /// Entity đã tạo (cả những cái đang gỡ khỏi scene).
  final int entities;

  /// Entity đang nằm trong scene (≈ draw call, trước khi Filament loại vật ngoài khung nhìn).
  final int drawn;

  /// Material instance khác nhau.
  final int materials;
  final int triangles;
  final int drawnTriangles;

  @override
  String toString() =>
      '$entities entities ($drawn drawn), $materials materials, $triangles tris ($drawnTriangles drawn)';
}
