import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, setEquals;
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:thermion_dart/thermion_dart.dart';

import '../../core/city/mai_look.dart';
import '../shop3d/chibi/chibi_actor.dart';
import '../shop3d/chibi/chibi_characters.dart';
import '../shop3d/chibi/chibi_mesh.dart';
import '../shop3d/chibi/chibi_regulars.dart';
import '../shop3d/chibi/chibi_rig.dart';
import '../shop3d/chibi/chibi_sizes.dart';
import '../shop3d/shop3d_mesh.dart';
import '../shop3d/shop3d_quality.dart';
import '../shop3d/shop3d_scene.dart' show Shop3dScene, Shop3dSharedMaterials;
import 'town_batches.dart';
import 'town_branch_cast.dart';
import 'town_branch_ui.dart';
import 'town_layout.dart';
import 'town_meshes.dart';
import 'town_pilot.dart';

/// Lớp phố của thành phố V3 (giai đoạn 1) dựng bằng Thermion trên viewer DÙNG CHUNG với lớp tiệm ([Shop3dScene] giữ
/// đèn / IBL / đồ họa và material — [Shop3dSharedMaterials]):
/// - lưới tĩnh của quận theo ô 16 m × bề mặt ([TownBatches]; quận 1: 12 entity, 2 material dùng chung với nội thất),
///   nhận bóng, không đổ bóng (đất + nhà gộp chung lưới; đổ bóng từ mặt đất dễ "acne" — chỉ nhân vật đổ bóng);
/// - nhân vật chibi của [TownPilot] (Mai + 2 chủ quán): mỗi bộ phận một entity, material chibi dùng chung, ma trận gửi
///   bằng `TransformManager.setTransform` đồng bộ, chỉ khi đổi (như lớp tiệm, docs/v3/thermion-api-notes.md mục 9.27);
/// - món ăn trên bàn hiên (một entity động mỗi món, dựng lần đầu cần, ẩn khi ăn xong); bóng tròn dưới chân ở mức thấp;
/// - kiểu tóc Mai ([setMaiLook]): chỉ thay entity đầu + phụ, mỗi kiểu dựng một lần rồi giữ lại;
/// - chi nhánh (GĐ4, docs/v3/city-gd4-spec.md §5): mặt tiền mỗi lô ([setBranchLevel], ≤ 2 lưới tĩnh `buildLot` / lô —
///   dựng lưới mới rồi mới gỡ + huỷ lưới cũ), biểu tượng két đầy ([setFullIcons], một entity / lô, dựng lần đầu cần,
///   lắc nhẹ; ẩn ở lô Mai đang đứng ở cửa), nhân viên đứng ở sân ([setBranchActors], tối đa 2 chibi theo
///   [TownBranchCast.plan]; mỗi chibi dựng một lần rồi giữ lại, chỉ gỡ / thêm vào scene).
///
/// Toạ độ lớp phố (`town_layout.dart`) được dời [originX] / [originZ] trong thế giới Filament (khi gửi transform và
/// camera), nên lớp tiệm (quanh gốc toạ độ) và lớp phố không bao giờ cùng nằm trong khung nhìn — kể cả lúc lớp tiệm
/// đang dựng nền (createGeometry tự thêm vào scene trước khi kịp gỡ). Chuyển cảnh: [setActive] gỡ / thêm mọi entity của
/// lớp (removeFromScene, không huỷ).
class TownScene {
  TownScene._(this.viewer, this.materials, this.pilot, this.layout, {required this.verbose});

  /// Gốc lớp phố trong thế giới Filament (m). Lớp tiệm: |x|, |z| < 10, camera tiệm ≤ 16 m, far 80 m.
  static const double originX = 400, originZ = 0;

  final ThermionViewer viewer;
  final Shop3dSharedMaterials materials;
  final TownPilot pilot;
  final TownLayout layout;
  final bool verbose;

  final _static = <ThermionAsset>[];
  final _chibis = <_TownChibi>[];
  final _dishes = <String, _DishNode>{};

  // Chi nhánh: mặt tiền theo lô, biểu tượng két đầy theo lô, nhân viên đứng ở sân (chibi theo id, giữ lại).
  final _lots = <String, _BranchLot>{};
  final _icons = <String, _IconNode>{};
  Set<String> _full = const {};
  final _staff = <String, _StaffNode>{};
  List<TownBranchActor> _cast = const [];
  double _clock = 0;
  final Matrix4 _m = Matrix4.identity();
  Future<void> _queue = Future.value();
  bool _active = true;
  bool _disposed = false;
  bool _blobs = false;
  Future<void>? _blobsReady;
  Shop3dGraphics? _graphics;

  // Kiểu tóc Mai: lưới đầu + phụ đã dựng theo kiểu (entity giữ lại, ngoài scene khi không dùng).
  final _lookParts = <MaiLook, Future<Map<ChibiPart, ThermionAsset>?>>{};
  Future<void> _lookQueue = Future.value();
  MaiLook _look = MaiLook.defaults;

  int _entities = 0;
  int _triangles = 0;
  int _staticTriangles = 0;
  int _sent = 0;
  double _sentAvg = 0;
  final Stopwatch _watch = Stopwatch();
  double _micros = 0;

  /// Bộ phận đổi theo kiểu tóc.
  static const _maiLookParts = {ChibiPart.head, ChibiPart.extra};

  /// Dựng lớp phố trên [viewer] (đèn đã có — của lớp tiệm). Lưới tĩnh + nhân vật tạo song song (mục 9.12 ghi chú API).
  /// [look]: kiểu tóc của lưới Mai trong [pilot] (`TownPilot(look:)`).
  static Future<TownScene> build(
    ThermionViewer viewer, {
    required TownLayout layout,
    required Shop3dSharedMaterials materials,
    required TownPilot pilot,
    required MaiLook look,
    Shop3dGraphics graphics = Shop3dGraphics.high,
    bool verbose = false,
  }) async {
    final s = TownScene._(viewer, materials, pilot, layout, verbose: verbose).._look = look;
    s._log('static');
    await Future.wait([s._buildStatic(layout), s._buildChibis()]);
    s._log('done: ${s._entities} entities, ${s._triangles} tris');
    s.applyGraphics(graphics);
    s._write(0);
    return s;
  }

  void _log(String msg) {
    if (verbose) debugPrint('TownScene: $msg');
  }

  FFITransformManager get _tm => (viewer.app as FFIFilamentApp).transformManager;

  // ---- Số liệu (chip debug) ---------------------------------------------------------------------------------

  /// Entity đã tạo (kể cả đang ngoài scene) / đang trong scene / của lưới tĩnh.
  int get entityCount => _entities;

  /// Lưới tĩnh của quận + mặt tiền chi nhánh.
  int get staticEntityCount => _static.length + _lots.values.fold(0, (s, l) => s + l.assets.length);
  int get drawnEntityCount {
    if (!_active) return 0;
    var n = staticEntityCount;
    for (final c in _chibis) {
      n += c.assets.length;
      if (_blobs && c.blob != null) n++;
    }
    for (final d in _dishes.values) {
      if (d.inScene) n++;
    }
    for (final i in _icons.values) {
      if (i.inScene) n++;
    }
    for (final s in _staff.values) {
      if (s.inScene) n += s.node!.assets.length + (s.blobShown ? 1 : 0);
    }
    return n;
  }

  int get triangleCount => _triangles;
  int get staticTriangleCount => _staticTriangles;

  /// Số lệnh setTransform gửi mỗi khung (trung bình trượt) / số bộ phận chibi.
  double get transformsSentPerUpdate => _sentAvg;
  int get chibiParts =>
      _chibis.fold(0, (s, n) => s + n.assets.length) +
      _staff.values.fold(0, (s, n) => s + (n.inScene ? n.node!.assets.length : 0));

  /// Thời gian (µs, trượt mũ) mỗi [tick]: cập nhật [pilot] + nhân vật + gửi transform.
  double get updateMicros => _micros;

  bool get active => _active;

  // ---- Dựng -------------------------------------------------------------------------------------------------

  Future<void> _buildStatic(TownLayout layout) async {
    final batches = TownBatches.build(layout);
    await Future.wait([
      for (final k in {for (final b in batches) ...b.meshes.keys}) materials.surfaceMaterial(k),
    ]);
    final assets = await Future.wait([
      for (final b in batches)
        for (final e in b.meshes.entries) _addStatic(e.value, e.key),
    ]);
    if (_disposed) return;
    _static.addAll(assets);
    if (!_active) _enqueue([for (final a in assets) (a, false)]);
  }

  /// `createGeometry` của viewer; [show] = false → tạo ngoài scene (`ThermionViewerFFI` — native lẫn web — có
  /// `addToScene`; viewer khác tự thêm vào scene thì gỡ ngay). Không truyền material lúc tạo (web: mục 9.1).
  Future<ThermionAsset> _createGeometry(Geometry g, {required bool show}) async {
    final v = viewer;
    if (v is ThermionViewerFFI) return v.createGeometry(g, addToScene: show);
    final a = await v.createGeometry(g);
    if (!show) _enqueue([(a, false)]);
    return a;
  }

  /// [show] = false: tạo ngoài scene (nơi gọi tự thêm khi đã sẵn sàng — mặt tiền chi nhánh).
  Future<ThermionAsset> _addStatic(Shop3dMesh mesh, Shop3dSurfaceKey key, {bool show = true}) async {
    final mat = await materials.surfaceMaterial(key);
    // Màu đỉnh thật (typed list thường — mục 9.1), UV RỖNG (mục 9.19) như lưới tĩnh của tiệm.
    final asset = await _createGeometry(
      Geometry(
        mesh.positions,
        mesh.indices,
        normals: mesh.normals,
        uvs: Float32List(0),
        uvs1: Float32List(0),
        colors: mesh.colors,
      ),
      show: show,
    );
    _m
      ..setIdentity()
      ..setTranslationRaw(originX, 0, originZ);
    _tm.setTransform(asset.entity, _m);
    await Future.wait([asset.setMaterialInstanceAt(mat.materialInstance), asset.setReceiveShadows(true)]);
    _entities++;
    _triangles += mesh.triangleCount;
    _staticTriangles += mesh.triangleCount;
    return asset;
  }

  Future<ThermionAsset> _addChibiMesh(ChibiMesh mesh, UbershaderMaterialInstance mat,
      {bool cast = true, bool show = true}) async {
    final asset = await _createGeometry(
      Geometry(
        mesh.positions,
        mesh.indices,
        normals: mesh.normals,
        uvs: Float32List(0),
        uvs1: Float32List(0),
        colors: mesh.colors,
      ),
      show: show,
    );
    await Future.wait([
      asset.setMaterialInstanceAt(mat.materialInstance),
      asset.setReceiveShadows(true),
      if (cast) asset.setCastShadows(true),
    ]);
    _entities++;
    _triangles += mesh.triangleCount;
    return asset;
  }

  Future<void> _buildChibis() async {
    try {
      final mat = await materials.chibiMaterial();
      final nodes = await Future.wait([
        for (final a in pilot.actors)
          () async {
            final parts = [
              for (final p in ChibiPart.values)
                if (a.model.meshes.containsKey(p)) p,
            ];
            final assets = await Future.wait([for (final p in parts) _addChibiMesh(a.model.meshes[p]!, mat)]);
            return _TownChibi(a, parts, assets);
          }(),
      ]);
      if (_disposed) return;
      _chibis.addAll(nodes);
      final mai = nodes.first;
      mai.look = _look;
      _lookParts[_look] = Future.value({
        for (var i = 0; i < mai.parts.length; i++)
          if (_maiLookParts.contains(mai.parts[i])) mai.parts[i]: mai.assets[i],
      });
      if (!_active) {
        _enqueue([
          for (final n in nodes)
            for (final a in n.assets) (a, false),
        ]);
      }
    } catch (e, st) {
      debugPrint('TownScene: chibi setup failed: $e\n$st');
    }
  }

  // ---- Đồ họa -----------------------------------------------------------------------------------------------

  /// Áp mức đồ họa cho phần riêng của lớp phố (bóng tròn dưới chân ở mức thấp); đèn / bóng động / hậu kỳ do lớp tiệm
  /// áp cho cả viewer (`Shop3dScene.applyGraphics`).
  void applyGraphics(Shop3dGraphics g) {
    _graphics = g;
    final want = g.blobShadows && _chibis.isNotEmpty;
    if (want == _blobs) return;
    _blobs = want;
    final ready = _blobsReady ??= _createBlobs();
    unawaited(ready.then((_) {
      if (_blobs != want || _disposed) return;
      _enqueue([
        for (final n in _chibis)
          if (n.blob != null) (n.blob!, want && _active),
      ]);
    }));
  }

  Future<void> _createBlobs() async {
    try {
      final assets = await Future.wait([for (final _ in _chibis) _addBlob()]);
      if (_disposed) return;
      for (var i = 0; i < assets.length; i++) {
        _chibis[i].blob = assets[i];
      }
    } catch (e) {
      debugPrint('TownScene: blob shadows failed: $e');
    }
  }

  static final _disc = buildDisc(0, 0, 0, 1, segments: 20);

  Future<ThermionAsset> _addBlob() async {
    final mat = await materials.shadowMaterial();
    final disc = _disc;
    final n = disc.positions.length ~/ 3;
    final a = await _createGeometry(
        Geometry(disc.positions, disc.indices,
            normals: disc.normals,
            uvs: Float32List(n * 2),
            uvs1: Float32List(n * 2),
            colors: Float32List(n * 4)..fillRange(0, n * 4, 1.0)),
        show: false);
    await a.setMaterialInstanceAt(mat.materialInstance);
    _entities++;
    _triangles += disc.triangleCount;
    return a;
  }

  // ---- Mỗi khung --------------------------------------------------------------------------------------------

  /// Tiến [dt] giây: [TownPilot.update] (lái Mai, vùng, ăn, chuyển động nhân vật) rồi gửi transform. Lớp tắt
  /// ([active] = false) thì bỏ qua.
  void tick(double dt) {
    if (_disposed || !_active) return;
    _watch
      ..reset()
      ..start();
    pilot.update(dt);
    _clock += dt;
    for (final s in _staff.values) {
      if (s.inScene) s.node!.actor.update(dt, const {});
    }
    _write(dt);
    _watch.stop();
    final us = _watch.elapsedMicroseconds.toDouble();
    _micros = _micros == 0 ? us : _micros * 0.95 + us * 0.05;
  }

  void _write(double dt) {
    final tm = _tm;
    _sent = 0;
    for (final n in _chibis) {
      _writeChibi(tm, n);
    }
    if (_blobs) _writeBlobs(tm);
    _writeDish(tm);
    if (_staff.isNotEmpty) _writeStaff(tm);
    if (_icons.isNotEmpty) _writeIcons(tm);
    if (dt > 0) _sentAvg = _sentAvg == 0 ? _sent.toDouble() : _sentAvg * 0.95 + _sent * 0.05;
  }

  /// Ma trận thế giới (lớp phố) các bộ phận có đổi → dời gốc [originX] / [originZ] → setTransform đồng bộ.
  void _writeChibi(FFITransformManager tm, _TownChibi n) {
    final storage = _m.storage;
    final world = n.actor.rig.world;
    final sent = n.sent;
    for (var i = 0; i < n.parts.length; i++) {
      final w = world[n.parts[i].index];
      final o = i * 16;
      var k = 0;
      while (k < 16 && sent[o + k] == w[k]) {
        k++;
      }
      if (k == 16) continue;
      sent.setRange(o, o + 16, w);
      storage.setRange(0, 16, w);
      storage[12] += originX;
      storage[14] += originZ;
      tm.setTransform(n.assets[i].entity, _m);
      _sent++;
    }
  }

  void _writeBlobs(FFITransformManager tm) {
    for (final n in _chibis) {
      _writeBlob(tm, n);
    }
  }

  void _writeBlob(FFITransformManager tm, _TownChibi n) {
    final blob = n.blob;
    if (blob == null) return;
    final a = n.actor;
    final d = a.model.radius * Shop3dScene.blobDiameterScale;
    final y = a.floor?.call(a.pose.x, a.pose.z) ?? 0;
    if (a.pose.x == n.blobX && a.pose.z == n.blobZ && y == n.blobY) return;
    n
      ..blobX = a.pose.x
      ..blobZ = a.pose.z
      ..blobY = y;
    _m
      ..setIdentity()
      ..setEntry(0, 0, d)
      ..setEntry(2, 2, d)
      ..setTranslationRaw(a.pose.x + originX, y + Shop3dScene.blobLift, a.pose.z + originZ);
    tm.setTransform(blob.entity, _m);
    _sent++;
  }

  /// Món trên bàn: hiện khi [TownPilot.dishVisible] (dựng entity lần đầu cần), ẩn khi xong.
  void _writeDish(FFITransformManager tm) {
    final id = pilot.dishVisible ? pilot.dishId : null;
    for (final d in _dishes.values) {
      if (d.inScene && d.id != id) {
        d.inScene = false;
        _enqueue([(d.asset!, false)]);
      }
    }
    if (id == null) return;
    final d = _dishes.putIfAbsent(id, () => _DishNode(id)..job = _buildDish(id));
    final asset = d.asset;
    if (asset == null || d.inScene || !_active) return;
    final p = pilot.dishPose;
    _m
      ..setRotationY(p.yaw)
      ..setTranslationRaw(p.x + originX, p.y, p.z + originZ);
    tm.setTransform(asset.entity, _m);
    _sent++;
    d.inScene = true;
    _enqueue([(asset, true)]);
  }

  Future<void> _buildDish(String id) async {
    try {
      final mat = await materials.chibiMaterial();
      final asset = await _addChibiMesh(TownMeshes.dish(id), mat, cast: false);
      _m
        ..setIdentity()
        ..setTranslationRaw(originX, -50, originZ);
      _tm.setTransform(asset.entity, _m);
      _enqueue([(asset, false)]);
      _dishes[id]?.asset = asset;
    } catch (e) {
      debugPrint('TownScene: dish $id failed: $e');
    }
  }

  // ---- Kiểu tóc Mai -------------------------------------------------------------------------------------------

  /// Kiểu tóc Mai đang hiện.
  MaiLook get maiLook => _look;

  /// Đổi kiểu tóc Mai ngay (xem trước ở tiệm tóc / sau khi mua): thay entity [ChibiPart.head] + [ChibiPart.extra] bằng
  /// bản của [look] (dựng lần đầu, giữ lại). Gọi chồng: chạy nối tiếp, chỉ kiểu cuối cùng được áp.
  Future<void> setMaiLook(MaiLook look) {
    _look = look;
    return _lookQueue = _lookQueue.then((_) => _applyLook()).catchError((Object e) {
      debugPrint('TownScene: mai look failed: $e');
    });
  }

  Future<void> _applyLook() async {
    if (_disposed || _chibis.isEmpty) return;
    final look = _look;
    final node = _chibis.first;
    if (node.look == look) return;
    final parts = await (_lookParts[look] ??= _buildLook(look));
    if (parts == null || _disposed || _look != look) return;
    final batch = <(ThermionAsset, bool)>[];
    for (final e in parts.entries) {
      final i = node.parts.indexOf(e.key);
      if (i < 0 || identical(node.assets[i], e.value)) continue;
      batch.add((node.assets[i], false));
      node.assets[i] = e.value;
      node.sent.fillRange(i * 16, i * 16 + 16, double.nan);
      if (_active) batch.add((e.value, true));
    }
    _writeChibi(_tm, node);
    node.look = look;
    _enqueue(batch);
    await _queue;
  }

  Future<Map<ChibiPart, ThermionAsset>?> _buildLook(MaiLook look) async {
    try {
      final mat = await materials.chibiMaterial();
      final model = ChibiSizes.fit(buildMai(look));
      final keys = [
        for (final p in _maiLookParts)
          if (model.meshes.containsKey(p)) p,
      ];
      final assets = await Future.wait([for (final p in keys) _addChibiMesh(model.meshes[p]!, mat)]);
      if (_disposed) return null;
      _m
        ..setIdentity()
        ..setTranslationRaw(originX, -50, originZ);
      for (final a in assets) {
        _tm.setTransform(a.entity, _m);
      }
      _enqueue([for (final a in assets) (a, false)]);
      return {for (var i = 0; i < keys.length; i++) keys[i]: assets[i]};
    } catch (e, st) {
      debugPrint('TownScene: look $look failed: $e\n$st');
      _lookParts.remove(look);
      return null;
    }
  }

  /// Dựng sẵn lưới tóc của các kiểu [looks] (lúc rảnh, để xem trước ở tiệm tóc đổi ngay).
  void prepareLooks(Iterable<MaiLook> looks) {
    for (final l in looks) {
      _lookParts.putIfAbsent(l, () => _buildLook(l));
    }
  }

  // ---- Chi nhánh (GĐ4) ----------------------------------------------------------------------------------------

  /// Mặt tiền lô chi nhánh [lotId] ở cấp [level] (0 = lô trống, docs/v3/city-gd4-spec.md §5): dựng lưới mới
  /// ([TownBatches.buildLot], ≤ 2 lưới, toạ độ lớp phố), thêm vào scene rồi mới gỡ + huỷ lưới cũ. Cùng cấp đang có /
  /// đang dựng → không làm gì; gọi chồng → chạy nối tiếp, chỉ cấp cuối cùng được dựng.
  Future<void> setBranchLevel(String lotId, int level) {
    final node = _lots.putIfAbsent(lotId, _BranchLot.new);
    if (node.want == level) return node.job;
    node.want = level;
    return node.job = node.job.then((_) => _applyBranch(lotId, node)).catchError((Object e, StackTrace st) {
      debugPrint('TownScene: branch $lotId failed: $e\n$st');
    });
  }

  /// Cấp mặt tiền đã dựng của [lotId] (−1 = chưa dựng).
  int branchLevelOf(String lotId) => _lots[lotId]?.level ?? -1;

  Future<void> _applyBranch(String lotId, _BranchLot node) async {
    final level = node.want;
    if (_disposed || node.level == level) return;
    final sw = Stopwatch()..start();
    final meshes = TownBatches.buildLot(layout.district.lot(lotId), level);
    final dartUs = sw.elapsedMicroseconds;
    final assets = await Future.wait([for (final e in meshes.entries) _addStatic(e.value, e.key, show: false)]);
    if (_disposed) return;
    final tris = meshes.values.fold(0, (s, m) => s + m.triangleCount);
    final old = node.assets, oldTris = node.triangles;
    node
      ..assets = assets
      ..level = level
      ..triangles = tris;
    if (_active) _enqueue([for (final a in assets) (a, true)]);
    if (old.isNotEmpty) {
      _entities -= old.length;
      _triangles -= oldTris;
      _staticTriangles -= oldTris;
      _enqueue([for (final a in old) (a, false)]);
      _queue = _queue.then((_) => Future.wait([
            for (final a in old)
              viewer.destroyAsset(a).catchError((Object e) => debugPrint('TownScene: destroy failed: $e')),
          ]));
    }
    await _queue;
    _log('branch $lotId L$level: ${assets.length} meshes, $tris tris, build ${(dartUs / 1000).toStringAsFixed(1)} ms, '
        'ready ${sw.elapsedMilliseconds} ms');
  }

  /// Lô có két đầy: biểu tượng (bóng nói + chồng xu) hiện ở sân các lô này, trừ lô Mai đang đứng ở cửa (xét mỗi khung,
  /// [TownBranchUi.visibleIcons]). Entity dựng lần đầu cần, giữ lại.
  void setFullIcons(Set<String> lots) {
    if (setEquals(lots, _full)) return;
    _full = Set.unmodifiable(lots);
    for (final id in lots) {
      _icons.putIfAbsent(id, () {
        final n = _IconNode(id, TownBranchUi.iconAt(layout.district.lot(id)));
        unawaited(_buildIcon(n));
        return n;
      });
    }
  }

  Future<void> _buildIcon(_IconNode n) async {
    try {
      final mat = await materials.chibiMaterial();
      final asset = await _addChibiMesh(TownMeshes.tillFull(), mat, cast: false, show: false);
      if (_disposed) return;
      n.asset = asset;
    } catch (e) {
      debugPrint('TownScene: till icon ${n.lotId} failed: $e');
    }
  }

  /// Biểu tượng két đầy: quay mặt về camera (yaw của camera phố = [TownPilot.cameraYaw]), lắc nhẹ + nhấp nhô; thêm /
  /// gỡ khỏi scene khi đổi.
  void _writeIcons(FFITransformManager tm) {
    final show = TownBranchUi.visibleIcons(_full, pilot.zone);
    for (final n in _icons.values) {
      final asset = n.asset;
      if (asset == null) continue;
      final want = show.contains(n.lotId) && _active;
      if (want) {
        final t = _clock * 2 * math.pi * TownBranchUi.iconHz + n.lotId.hashCode % 7;
        _m
          ..setIdentity()
          ..setTranslationRaw(n.at.x + originX, n.at.y + math.sin(t * 2) * TownBranchUi.iconBob, n.at.z + originZ)
          ..rotateY(pilot.cameraYaw)
          ..rotateZ(math.sin(t) * TownBranchUi.iconRock);
        tm.setTransform(asset.entity, _m);
        _sent++;
      }
      if (want != n.inScene) {
        n.inScene = want;
        _enqueue([(asset, want)]);
      }
    }
  }

  /// Nhân viên đứng ở sân chi nhánh ([TownBranchCast.plan], tối đa [TownBranchCast.maxVisible]): chibi chưa có thì dựng
  /// (một lần, giữ lại; tạo ngoài scene rồi thêm ở khung kế tiếp sau khi đã gửi transform); chibi không còn trong danh
  /// sách thì gỡ khỏi scene. Cùng danh sách → không làm gì.
  void setBranchActors(List<TownBranchActor> actors) {
    if (_sameCast(actors, _cast)) return;
    _cast = List.unmodifiable(actors);
    final want = {for (final a in actors) a.chibiId: a};
    for (final s in _staff.values) {
      s.want = want[s.chibiId];
    }
    for (final a in actors) {
      _staffNode(a.chibiId).want = a;
    }
  }

  /// Dựng sẵn (ngoài scene, giữ lại) chibi của các nhân viên [chibiIds] — gọi lúc phố còn màn đen / khi thuê: đưa vào sân
  /// sau đó chỉ còn thêm vào scene. Web (05/11): dựng một chibi ngay lúc Mai đang đi tốn 3–5 khung ~50 ms.
  Future<void> prepareStaff(Iterable<String> chibiIds) => Future.wait([for (final id in chibiIds) _staffNode(id).job]);

  _StaffNode _staffNode(String chibiId) => _staff.putIfAbsent(chibiId, () {
        final s = _StaffNode(chibiId);
        s.job = _buildStaff(s);
        return s;
      });

  static bool _sameCast(List<TownBranchActor> a, List<TownBranchActor> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].lotId != b[i].lotId || a[i].chibiId != b[i].chibiId) return false;
    }
    return true;
  }

  /// Nhân viên chi nhánh đang đứng ở sân lô [lotId] vẫy tay (vừa thu tiền).
  void waveBranch(String lotId) {
    for (final s in _staff.values) {
      if (s.inScene && s.placedLot == lotId) s.node!.actor.perform(ChibiAction.wave, 1.4);
    }
  }

  static ChibiModel _staffModel(String chibiId) => ChibiSizes.fit(
      chibiId.startsWith('regular_') ? ChibiRegulars.build(chibiId) : ChibiCharacters.build(chibiId));

  Future<void> _buildStaff(_StaffNode s) async {
    try {
      final sw = Stopwatch()..start();
      final mat = await materials.chibiMaterial();
      final model = _staffModel(s.chibiId);
      final dartUs = sw.elapsedMicroseconds;
      final parts = [
        for (final p in ChibiPart.values)
          if (model.meshes.containsKey(p)) p,
      ];
      final assets = await Future.wait([for (final p in parts) _addChibiMesh(model.meshes[p]!, mat, show: false)]);
      if (_disposed) return;
      s
        ..model = model
        ..parts = parts
        ..assets = assets;
      _log('staff ${s.chibiId}: ${assets.length} parts, model ${(dartUs / 1000).toStringAsFixed(1)} ms, '
          'ready ${sw.elapsedMilliseconds} ms');
    } catch (e, st) {
      debugPrint('TownScene: staff ${s.chibiId} failed: $e\n$st');
    }
  }

  /// Nhân viên: đặt vào chỗ đứng của lô mới (kịch bản đứng / làm việc / vẫy như chủ quán, quay ra đường), gửi
  /// transform, rồi thêm / gỡ khỏi scene khi đổi.
  void _writeStaff(FFITransformManager tm) {
    for (final s in _staff.values) {
      final assets = s.assets;
      if (assets == null) continue;
      final w = _active ? s.want : null;
      if (w == null) {
        if (s.inScene) {
          s.inScene = false;
          final n = s.node!;
          _enqueue([
            for (final a in n.assets) (a, false),
            if (n.blob != null && s.blobShown) (n.blob!, false),
          ]);
        }
        continue;
      }
      var n = s.node;
      if (n == null || s.placedLot != w.lotId) {
        final actor = ChibiActor(s.model!, TownPilot.keeperLoop(w.at.yaw),
            x: w.at.x, z: w.at.z, yaw: w.at.yaw, seed: 131 + s.chibiId.hashCode % 97)
          ..update(1 / 60, const {});
        final blob = n?.blob;
        n = s.node = _TownChibi(actor, s.parts!, assets)..blob = blob;
        s.placedLot = w.lotId;
      }
      _writeChibi(tm, n);
      if (_blobs) {
        if (n.blob == null && !s.blobPending) {
          s.blobPending = true;
          unawaited(_addBlob().then((b) => s.node?.blob = b, onError: (Object e) {
            debugPrint('TownScene: staff blob failed: $e');
          }));
        }
        _writeBlob(tm, n);
      }
      final blobOn = _blobs && n.blob != null;
      if (!s.inScene) {
        s.inScene = true;
        s.blobShown = blobOn;
        _enqueue([
          for (final a in n.assets) (a, true),
          if (blobOn) (n.blob!, true),
        ]);
      } else if (blobOn != s.blobShown && n.blob != null) {
        s.blobShown = blobOn;
        _enqueue([(n.blob!, blobOn)]);
      }
    }
  }

  // ---- Bật / tắt ----------------------------------------------------------------------------------------------

  /// Bật / tắt cả lớp phố (vào / ra tiệm của bà): gỡ / thêm mọi entity khỏi scene, không huỷ. Future hoàn tất khi mọi
  /// lệnh đã gửi.
  Future<void> setActive(bool active) {
    if (active == _active) return _queue;
    _active = active;
    final batch = <(ThermionAsset, bool)>[
      for (final a in _static) (a, active),
      for (final l in _lots.values)
        for (final a in l.assets) (a, active),
    ];
    // Biểu tượng két đầy / nhân viên chi nhánh: tắt thì gỡ ngay; bật thì vòng cập nhật tự thêm lại.
    if (!active) {
      for (final i in _icons.values) {
        if (i.inScene) {
          i.inScene = false;
          batch.add((i.asset!, false));
        }
      }
      for (final s in _staff.values) {
        if (!s.inScene) continue;
        s.inScene = false;
        final n = s.node!;
        for (final a in n.assets) {
          batch.add((a, false));
        }
        if (n.blob != null && s.blobShown) batch.add((n.blob!, false));
      }
    }
    final tm = _tm;
    for (final n in _chibis) {
      if (active) _writeChibi(tm, n);
      for (final a in n.assets) {
        batch.add((a, active));
      }
      if (_blobs && n.blob != null) batch.add((n.blob!, active));
    }
    for (final d in _dishes.values) {
      if (d.inScene && !active) {
        d.inScene = false;
        batch.add((d.asset!, false));
      }
    }
    _enqueue(batch);
    return _queue;
  }

  void _enqueue(List<(ThermionAsset, bool)> batch) {
    if (batch.isEmpty) return;
    _queue = _queue.then((_) async {
      if (_disposed) return;
      await Future.wait([
        for (final (asset, show) in batch)
          (show ? viewer.addToScene(asset) : viewer.removeFromScene(asset)).catchError((Object e) {
            debugPrint('TownScene: ${show ? 'add' : 'remove'} failed: $e');
          }),
      ]);
    });
  }

  /// Ngừng gửi lệnh. Entity / material do lớp tiệm huỷ cùng viewer (`Shop3dScene.dispose` → `destroyAssets`).
  void dispose() {
    _disposed = true;
    _chibis.clear();
  }

  /// Mức đồ họa đang áp (null = chưa áp).
  Shop3dGraphics? get graphics => _graphics;

  /// Đỉnh đầu (toạ độ lớp phố) của nhân vật [a] — lớp phủ (hiệu ứng "ta-da").
  static ({double x, double y, double z}) topOf(ChibiActor a) {
    final b = chibiBounds(a.model, a.pose);
    return (x: a.pose.x, y: math.max(b.maxY, a.pose.y + 0.5), z: a.pose.z);
  }
}

class _TownChibi {
  _TownChibi(this.actor, this.parts, this.assets)
      : sent = Float64List(parts.length * 16)..fillRange(0, parts.length * 16, double.nan);

  final ChibiActor actor;
  final List<ChibiPart> parts;
  final List<ThermionAsset> assets;
  final Float64List sent;
  ThermionAsset? blob;
  double blobX = double.nan, blobZ = double.nan, blobY = double.nan;
  MaiLook? look;
}

class _DishNode {
  _DishNode(this.id);

  final String id;
  Future<void>? job;
  ThermionAsset? asset;
  bool inScene = false;
}

/// Mặt tiền một lô chi nhánh: cấp muốn dựng / đã dựng (−1 = chưa), lưới đang dùng.
class _BranchLot {
  int want = -1, level = -1, triangles = 0;
  List<ThermionAsset> assets = const [];
  Future<void> job = Future.value();
}

/// Biểu tượng két đầy của một lô.
class _IconNode {
  _IconNode(this.lotId, this.at);

  final String lotId;
  final ({double x, double y, double z}) at;
  ThermionAsset? asset;
  bool inScene = false;
}

/// Một chibi nhân viên chi nhánh (theo id chibi): lưới dựng một lần; [node] dựng lại (actor mới) khi đổi lô.
class _StaffNode {
  _StaffNode(this.chibiId);

  final String chibiId;
  TownBranchActor? want;
  ChibiModel? model;
  List<ChibiPart>? parts;
  List<ThermionAsset>? assets;
  _TownChibi? node;
  String? placedLot;
  bool inScene = false, blobPending = false, blobShown = false;
  Future<void> job = Future.value();
}
