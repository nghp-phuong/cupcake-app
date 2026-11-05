import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:thermion_dart/thermion_dart.dart';

import '../../core/city/mai_look.dart';
import 'chibi/chibi_actor.dart';
import 'chibi/chibi_cast.dart';
import 'chibi/chibi_characters.dart';
import 'chibi/chibi_mesh.dart';
import 'chibi/chibi_rig.dart';
import 'chibi/chibi_roster.dart';
import 'chibi/chibi_sizes.dart';
import 'interact/item_meshes.dart';
import 'interact/pilot.dart';
import 'interact/shop3d_items.dart';
import 'shift/shift_cast.dart';
import 'shop3d_actors.dart';
import 'shop3d_batches.dart';
import 'shop3d_layout.dart';
import 'shop3d_math.dart';
import 'shop3d_mesh.dart';
import 'shop3d_pick.dart';
import 'shop3d_quality.dart';

/// Kiểu nhân vật trong cảnh.
enum Shop3dActorMode {
  /// Không nhân vật.
  none,

  /// Nhân vật 3D chibi dựng bằng code, đi lại theo kịch bản ([ChibiCast]). Mặc định.
  chibi,

  /// Ảnh 2D billboard đứng yên ([Shop3dActors]) — để so sánh.
  billboard,
}

/// Tuỳ chọn hình ảnh (để so sánh / khoanh lỗi trên từng nền tảng; GĐ d dùng cho máy yếu).
class Shop3dSceneOptions {
  const Shop3dSceneOptions({
    this.actorMode = Shop3dActorMode.chibi,
    this.chibiHz = 60,
    this.verbose = false,
    this.lineup,
    this.mochi = false,
    this.sunArgb,
    this.ambientArgb,
    this.fillArgb,
    this.skyArgb,
    this.ambientIntensity,
    this.maiLook = MaiLook.defaults,
  });

  /// Kiểu nhân vật.
  final Shop3dActorMode actorMode;

  /// Kiểu tóc của Mai lúc dựng dàn chibi (thành phố V3; đổi sau bằng [Shop3dScene.setMaiLook]). Mặc định = Mai như cũ.
  final MaiLook maiLook;

  /// Tần số cập nhật nhân vật chibi (Hz): 60 = mỗi khung; 30 = cách khung (máy yếu).
  final int chibiHz;

  /// In tiến độ dựng cảnh ra log.
  final bool verbose;

  /// Màn xếp hàng: bộ lọc nhân vật của `ChibiRoster.select` (`all`, `staff`, `vip|friends`, `mochi`…); null = cảnh tiệm
  /// mặc định ([ChibiCast]).
  final String? lineup;

  /// Cảnh mặc định: thêm mèo Mochi (ngày mưa).
  final bool mochi;

  /// Ghi đè màu (sRGB 0xRRGGBB) nắng chính / ánh sáng môi trường / đèn phụ / nền trời — để chỉnh ánh sáng không cần
  /// build lại (`?sun=FFF1DC&amb=FFE9D2&fill=E8FFF6&sky=FFE8D6`); null = mặc định của [Shop3dScene].
  final int? sunArgb, ambientArgb, fillArgb, skyArgb;

  /// Ghi đè cường độ ánh sáng môi trường (`?ambi=19000`); null = [Shop3dScene.ambientIntensity].
  final double? ambientIntensity;
}

/// Cảnh tiệm bánh 3D dựng bằng Thermion (Filament) từ [Shop3dLayout]: sàn, vật thể, tường + đồ gắn tường, nền ngoài
/// tiệm, ánh sáng ấm, nhân vật 3D chibi ([ChibiCast]; hoặc billboard [Shop3dActors] để so sánh).
///
/// - Lưới tĩnh theo nhóm [Shop3dBatches]: mỗi vật chạm được / mặt tường một nhóm, vật không chạm được (sàn, thảm, bục…)
///   gộp chung theo cờ mở rộng; trong nhóm mỗi [Shop3dSurfaceKey] một lưới. Mặt đục dùng màu đỉnh + MỘT material chung
///   theo độ nhám (3 material cho cả tiệm), mặt trong suốt giữ material một màu. Bật / tắt vật mở rộng: [setOwned] (cờ
///   `Shop3dRequires`, khớp `ShopSetup.owned`).
/// - Tường chắn camera: [setWallMask] (mặt nạ từ `OrbitCameraController.hiddenWallMask`) — gỡ / thêm nhóm tường khỏi
///   scene, chỉ gửi lệnh cho mặt đổi trạng thái.
/// - Billboard: [setBillboardYaw] mỗi khi camera xoay (chỉ trục y); chỉ gửi lệnh khi góc đổi.
/// - Chạm chọn: [pickBoxes] (raycast phía Dart, xem shop3d_pick.dart) + [hop] nhún vật vừa chọn, chạy bằng [tick].
/// - Chibi: mỗi bộ phận một entity, chung MỘT material màu đỉnh. [tick] chạy [ChibiDirector] (kịch bản + chuyển
///   động, Dart thuần) rồi gửi ma trận thế giới từng bộ phận bằng `TransformManager.setTransform` đồng bộ (không qua
///   hàng đợi luồng render, không tạo Future) — chỉ bộ phận có ma trận khác lần gửi trước (bộ phận đứng yên, chân lúc
///   đứng, nhân vật ngồi không gửi lại). Hộp chạm của chibi tính theo vị trí hiện tại khi đọc [pickBoxes].
/// - Màn xếp hàng ([Shop3dSceneOptions.lineup]): thay dàn [ChibiCast] bằng [ChibiLineup] (nhân vật chọn từ
///   [ChibiRoster]); [chibiFeet] cho view đặt nhãn id dưới chân.
///
/// - Tương tác (V3): cảnh là [Shop3dPilotWorld] của [Shop3dPilot] ([attachPilot]) — mỗi lần cập nhật chibi chạy
///   `pilot.update` → `ChibiDirector.update` → `pilot.lateUpdate`, rồi gửi transform của nhân vật và 4 vật tương tác
///   (len, 2 hộp bánh, bao bột: mỗi vật một entity, lưới màu đỉnh dùng chung material chibi). Cặp khách của sự kiện cãi
///   nhau dựng sẵn ([prepareModels], song song, để ngoài scene) rồi chỉ thêm / gỡ khỏi scene ([addActor] /
///   [removeActor]); entity giữ lại cho lần sau.
///
/// - Ghép vào thành phố (V3, docs/v3/city-gd1-spec.md): nhiều lớp cảnh dùng chung MỘT viewer. Cảnh này giữ đèn / IBL /
///   đồ họa ([applyGraphics]) và material ([Shop3dSharedMaterials]) cho cả lớp phố; `build(deferContent: true)` chỉ dựng
///   đèn, phần tiệm + nhân vật dựng sau bằng [buildContent]; [setActive] gỡ / thêm mọi entity của lớp tiệm khỏi scene
///   (không huỷ); [setMaiLook] đổi kiểu tóc Mai.
///
/// Web (thermion 0.5.0, docs/v3/thermion-api-notes.md mục 9): mọi mảng gửi xuống native là typed list thường (không
/// `makeFloat32List`), material gán sau `createGeometry`, ảnh texture nạp qua `malloc` (xem [_upload]), material có texture
/// phải truyền `baseColorUV: 0` (xem [_addActor]). Lưới tự tạo mặc định không nhận bóng (xem [_addMesh]).
class Shop3dScene implements Shop3dPilotWorld, Shop3dSharedMaterials {
  Shop3dScene._(this.viewer, this._bundle, Set<String> owned, this.options, {required bool active})
      : _owned = {...owned},
        _active = active,
        _maiLook = options.maiLook;

  final ThermionViewer viewer;
  final Shop3dSceneOptions options;
  final AssetBundle _bundle;
  Set<String> _owned;

  // ---- Thông số cảnh ----------------------------------------------------------------------------------------

  /// Nền ngoài tiệm: đào nhạt (#FFE8D6, decor-proposal.md — Thermion 0.5.0 không có skybox chuyển màu nếu không nạp
  /// KTX; tranh cảnh biển sau cửa sổ vẽ phần trời xanh). Đất quanh tiệm / vỉa hè: [Shop3dBatches.groundArgb] /
  /// [Shop3dBatches.sidewalkArgb].
  static const int skyArgb = 0xFFFFE8D6;

  /// Nắng chính kem vàng (#FFF1DC), ánh sáng môi trường ấm (#FFE9D2), đèn phụ bạc hà rất nhạt từ phía cửa sổ — giữ hồng /
  /// bạc hà tươi (không xám) dưới tone mapper PBR Neutral.
  static const int sunArgb = 0xFFFFF1DC;
  static const int ambientArgb = 0xFFFFE9D2;
  static const int fillArgb = 0xFFE8FFF6;

  /// Cường độ IBL (ánh sáng môi trường đều mọi hướng): thứ duy nhất chiếu sáng mặt quay lưng nắng (mặt trong tường trước,
  /// mặt dưới đồ vật). P3: 19000 → 23000 (+21 %: tường trước ~ +9 %, sàn ~ +7 %, chưa cháy) để mặt trong tường trước bớt tối khi
  /// nhìn về phía cửa sổ.
  static const double ambientIntensity = 23000;

  /// Bóng mềm dưới chân nhân vật.
  static const double actorShadowAlpha = 0.28;

  /// Bóng tròn dưới chân chibi (mức thấp, không bóng động): đường kính = bán kính nhân vật × hệ số này; nâng khỏi sàn
  /// [blobLift] m (trên thảm, tránh z-fighting).
  static const double blobDiameterScale = 2.4;
  static const double blobLift = 0.026;

  /// Nhún khi chạm chọn: cao [hopHeight] m trong [hopDuration] s.
  static const double hopHeight = 0.14;
  static const double hopDuration = 0.45;

  // ---- Trạng thái -------------------------------------------------------------------------------------------

  final _materials = <Shop3dSurfaceKey, UbershaderMaterialInstance>{};
  final _batches = <_BatchNode>[];
  final _actors = <_ActorNode>[];
  final _chibis = <_ChibiNode>[];
  ChibiDirector? _director;
  double _chibiAcc = 0;
  final Stopwatch _chibiWatch = Stopwatch();
  double _chibiMicros = 0;
  int _sent = 0;
  double _sentAvg = 0;
  final _textures = <Texture>[];
  final _extraMaterials = <UbershaderMaterialInstance>[];
  TextureSampler? _sampler;
  UbershaderMaterialInstance? _shadowMaterial;

  // Đồ họa đang áp ([applyGraphics]); null = chưa áp lần nào.
  Shop3dGraphics? _graphics;
  Future<void> _graphicsQueue = Future.value();
  ThermionEntity? _sun;
  IndirectLight? _ibl;
  bool _toneMapperNeutral = false;

  /// Bóng tròn dưới chân chibi ([_ChibiNode.blob]); tạo khi bật [Shop3dGraphics.blobShadows] lần đầu.
  bool _blobsInScene = false;
  Future<void>? _blobsReady;

  // Tương tác (V3).
  UbershaderMaterialInstance? _chibiMat;
  Shop3dPilot? _pilot;
  final _itemNodes = <_ItemNode>[];
  final _eventModels = <String, _EventModel>{};
  final _eventJobs = <String, Future<void>>{};

  int _wallMask = 0;
  double _yaw = double.nan;
  var _pickBoxes = <Shop3dPickBox>[];

  String? _hopId;
  double _hopT = 0;
  final Matrix4 _m = Matrix4.identity();

  /// Lệnh bật / tắt (add/removeFromScene) chạy nối tiếp để không xen nhau.
  Future<void> _queue = Future.value();

  bool _disposed = false;
  int _entities = 0;
  int _triangles = 0;
  int _staticEntities = 0;

  // Ghép thành phố (V3): lớp đang hiện, phần tiệm dựng sau, nhân vật xong, kiểu tóc Mai.
  bool _active;
  Future<void>? _content;
  final _actorsDone = Completer<void>();
  MaiLook _maiLook;
  final _maiLookParts = <MaiLook, Future<Map<ChibiPart, ThermionAsset>?>>{};
  Future<void> _lookQueue = Future.value();

  /// Số entity hiển thị đã tạo, kể cả đang gỡ khỏi scene (mỗi entity = một draw call khi nằm trong scene và trong
  /// khung nhìn).
  int get entityCount => _entities;

  /// Số entity của lưới tĩnh (tiệm: nền, vật thể, tường) đã tạo.
  int get staticEntityCount => _staticEntities;

  /// Số entity đang nằm trong scene (≈ draw call trước khi Filament loại vật ngoài khung nhìn).
  int get drawnEntityCount {
    var n = 0;
    for (final b in _batches) {
      if (b.inScene) n += b.assets.length;
    }
    for (final c in _chibis) {
      if (!_active) break;
      n += c.assets.length;
      if (_blobsInScene && c.blob != null) n++;
    }
    for (final i in _itemNodes) {
      if (i.inScene) n++;
    }
    for (final a in _actors) {
      if (a.inScene) n += 2;
    }
    return n;
  }

  /// Số material instance (dùng chung theo màu + mỗi nhân vật một cái vì khác texture).
  int get materialCount => _materials.length + _extraMaterials.length;
  int get triangleCount => _triangles;
  int get actorCount => _actors.length + _chibis.length;

  /// Có dàn chibi (đã dựng xong) — mới gắn [Shop3dPilot] được.
  bool get hasChibis => _director != null;

  @override
  ChibiDirector get director => _director!;

  /// Thời gian trung bình (µs, trượt mũ) mỗi lần cập nhật chibi: kịch bản + chuyển động + gửi setTransform.
  double get chibiUpdateMicros => _chibiMicros;

  /// Số bộ phận chibi (tối đa số lệnh setTransform mỗi lần cập nhật).
  int get chibiTransformsPerUpdate => _chibis.fold(0, (s, n) => s + n.assets.length);

  /// Số lệnh setTransform thật sự gửi mỗi lần cập nhật (trung bình trượt; bộ phận có ma trận không đổi thì bỏ qua) —
  /// gồm bộ phận chibi, bóng tròn, vật tương tác.
  double get transformsSentPerUpdate => _sentAvg;

  /// Hộp chạm của vật thể / nhân vật đang hiện. Chibi: hộp theo vị trí hiện tại (danh sách mới mỗi lần đọc).
  List<Shop3dPickBox> get pickBoxes {
    if (_chibis.isEmpty) return _pickBoxes;
    return [..._pickBoxes, for (final n in _chibis) _chibiBox(n.actor)];
  }

  static Shop3dPickBox _chibiBox(ChibiActor a) {
    final b = chibiBounds(a.model, a.pose);
    return Shop3dPickBox(a.id, Shop3dPickKind.actor, b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ);
  }

  /// Hướng mặt hiện tại (yaw) của nhân vật chibi [id]; null nếu không phải chibi.
  double? actorYaw(String id) {
    for (final n in _chibis) {
      if (n.actor.id == id) return n.actor.pose.yaw;
    }
    return null;
  }

  /// Chân (vị trí trên sàn + bán kính) của mọi nhân vật chibi — nhãn id ở màn xếp hàng.
  List<({String id, double x, double y, double z, double radius})> get chibiFeet => [
        for (final n in _chibis)
          (id: n.actor.id, x: n.actor.pose.x, y: n.actor.pose.y, z: n.actor.pose.z, radius: n.actor.model.radius),
      ];

  /// Đỉnh đầu hiện tại của nhân vật chibi [id] (để nhãn chọn đi theo); null nếu không phải chibi.
  ({double x, double y, double z})? actorTop(String id) {
    for (final n in _chibis) {
      if (n.actor.id != id) continue;
      final b = chibiBounds(n.actor.model, n.actor.pose);
      return (x: n.actor.pose.x, y: b.maxY, z: n.actor.pose.z);
    }
    return null;
  }

  /// Dựng cảnh với đồ họa [graphics] (đổi sau bằng [applyGraphics]). Nhân vật nạp ảnh bất đồng bộ sau phần tiệm;
  /// [onActorsReady] gọi khi xong (để vẽ lại / đếm lại).
  ///
  /// Ghép thành phố (V3): [deferContent] = chỉ dựng đèn + đồ họa, phần tiệm + nhân vật dựng sau bằng [buildContent];
  /// [active] = false: lớp tiệm dựng xong thì nằm ngoài scene (bật bằng [setActive]).
  static Future<Shop3dScene> build(
    ThermionViewer viewer, {
    required Set<String> owned,
    AssetBundle? bundle,
    Shop3dSceneOptions options = const Shop3dSceneOptions(),
    Shop3dGraphics graphics = Shop3dGraphics.high,
    void Function()? onActorsReady,
    bool deferContent = false,
    bool active = true,
  }) async {
    final scene = Shop3dScene._(viewer, bundle ?? rootBundle, owned, options, active: active);
    scene._log('lighting');
    await scene._setupLighting();
    await scene.applyGraphics(graphics);
    if (!deferContent) await scene.buildContent(onActorsReady: onActorsReady);
    return scene;
  }

  /// Dựng phần tiệm (lưới tĩnh) rồi nhân vật (bất đồng bộ, [onActorsReady] / [actorsReady] khi xong). Gọi một lần —
  /// các lần sau trả lại cùng Future. Future hoàn tất khi lưới tĩnh xong.
  Future<void> buildContent({void Function()? onActorsReady}) => _content ??= () async {
        _log('shop');
        await _buildShop();
        _log('shop done: $_entities entities');
        switch (options.actorMode) {
          case Shop3dActorMode.billboard:
            unawaited(_buildActors().then((_) => _actorsBuilt(onActorsReady)));
          case Shop3dActorMode.chibi:
            unawaited(_buildChibis().then((_) => _actorsBuilt(onActorsReady)));
          case Shop3dActorMode.none:
            _actorsBuilt(null);
        }
      }();

  void _actorsBuilt(void Function()? onActorsReady) {
    if (!_actorsDone.isCompleted) _actorsDone.complete();
    onActorsReady?.call();
  }

  /// Hoàn tất khi phần nhân vật dựng xong (kể cả lỗi / không có nhân vật) — màn ghép chờ trước khi gắn [Shop3dPilot].
  Future<void> get actorsReady => _actorsDone.future;

  void _log(String msg) {
    if (options.verbose) debugPrint('Shop3dScene: $msg');
  }

  // ---- Ánh sáng ---------------------------------------------------------------------------------------------

  /// Nền, hai đèn, IBL. Bóng / hậu kỳ / tone mapper / bật tắt IBL theo đồ họa: [applyGraphics].
  Future<void> _setupLighting() async {
    final sky = Shop3dMaterialKey(options.skyArgb ?? skyArgb, 1);
    await viewer.setBackgroundColor(sky.linearR, sky.linearG, sky.linearB, 1);

    // Nắng chiều kem vàng chiếu xiên qua cửa sổ trước (đổ bóng khi bật bóng động) + đèn phụ bạc hà rất nhạt ngược hướng
    // (không bóng). Lưu ý (P3, đo trên web): đèn phụ này KHÔNG có tác dụng trong bản web — đổi màu đèn phụ thành đỏ vẫn cho
    // ảnh giống hệt từng điểm ảnh — nên mặt trong tường trước (quay lưng nắng) chỉ sáng nhờ ánh sáng môi trường: xem
    // [ambientIntensity].
    final sun = Shop3dMaterialKey(options.sunArgb ?? sunArgb, 1);
    final fill = Shop3dMaterialKey(options.fillArgb ?? fillArgb, 1);
    _sun = await viewer.addDirectLight(
      DirectLight.sun(
        intensity: 100000,
        castShadows: true,
        direction: Vector3(-0.4, -1.0, -0.5).normalized(),
        color: LinearColor(sun.linearR, sun.linearG, sun.linearB),
      ),
    );
    await viewer.addDirectLight(
      DirectLight(
        type: LightType.DIRECTIONAL,
        intensity: 16000,
        castShadows: false,
        direction: Vector3(0.6, -0.5, 0.7).normalized(),
        position: Vector3.zero(),
        color: LinearColor(fill.linearR, fill.linearG, fill.linearB),
      ),
    );
  }

  /// IBL không cần file KTX: chỉ hệ số SH bậc 0 (màu đều mọi hướng), ấm. Tạo một lần, giữ lại để bật / tắt.
  Future<IndirectLight?> _ambient() async {
    if (_ibl != null) return _ibl;
    try {
      // Float32List thường — không makeFloat32List (mục 9.1 ghi chú API).
      final amb = Shop3dMaterialKey(options.ambientArgb ?? ambientArgb, 1);
      final sh = Float32List(27);
      sh[0] = amb.linearR;
      sh[1] = amb.linearG;
      sh[2] = amb.linearB;
      return _ibl = await FFIIndirectLight.fromIrradianceHarmonics(
        viewer.app as FFIFilamentApp,
        sh,
        intensity: options.ambientIntensity ?? ambientIntensity,
      );
    } catch (e) {
      debugPrint('Shop3dScene: ambient IBL failed: $e');
      return null;
    }
  }

  /// Áp thiết lập đồ họa [g] (lúc dựng và khi đổi mức). Chỉ gửi lệnh cho mục đổi; các lần gọi chạy nối tiếp.
  /// [Shop3dGraphics.renderScale] / [Shop3dGraphics.targetFps] do view áp (cỡ texture / vòng render).
  Future<void> applyGraphics(Shop3dGraphics g) => _graphicsQueue = _graphicsQueue.then((_) async {
        if (_disposed) return;
        final old = _graphics;
        _graphics = g;
        try {
          await _applyGraphics(old, g);
        } catch (e) {
          debugPrint('Shop3dScene: applyGraphics failed: $e');
        }
      });

  Future<void> _applyGraphics(Shop3dGraphics? old, Shop3dGraphics g) async {
    final app = viewer.app as FFIFilamentApp;
    if (old?.postProcessing != g.postProcessing) await viewer.setPostProcessing(g.postProcessing);
    // FXAA chỉ chạy trong hậu kỳ; rẻ trên máy tầm trung, bỏ ở mức thấp.
    if (old?.fxaa != g.fxaa || old?.postProcessing != g.postProcessing) {
      await viewer.setAntiAliasing(false, g.fxaa && g.postProcessing, false);
    }
    final wantNeutral = g.neutralToneMapper && g.postProcessing;
    if (wantNeutral != _toneMapperNeutral || old == null) {
      try {
        // PBR Neutral giữ đúng màu pastel của bảng màu (ACES làm nhạt / ám vàng) và không đổi màu nhân vật unlit.
        if (wantNeutral) {
          await viewer.setToneMapper(await ToneMapper.pbrNeutral(app));
        } else if (old != null) {
          await viewer.setToneMapper(await ToneMapper.aces(app));
        }
        _toneMapperNeutral = wantNeutral;
      } catch (e) {
        debugPrint('Shop3dScene: tone mapper failed: $e');
      }
    }
    if (old?.shadows != g.shadows) await viewer.setShadowsEnabled(g.shadows);
    // DPCF: PCF có vùng nửa tối mềm dần theo khoảng cách vật che — mềm hơn PCF, rẻ hơn PCSS / VSM; vẫn quá đắt trên
    // PowerVR GE8320 (mục 9.24).
    if (old?.softShadows != g.softShadows) await viewer.setShadowType(g.softShadows ? ShadowType.DPCF : ShadowType.PCF);
    final sun = _sun;
    if (sun != null) {
      if (old?.shadows != g.shadows) app.lightManager.setShadowCaster(sun, g.shadows);
      if (old?.shadowMapSize != g.shadowMapSize) {
        app.lightManager.setShadowOptions(sun, ShadowOptions(mapSize: g.shadowMapSize, shadowFar: _shadowFar));
      }
    }
    if (old?.ambientLight != g.ambientLight) {
      final scene = await viewer.view.getScene();
      await scene.setIndirectLight(g.ambientLight ? await _ambient() : null);
    }
    _syncBlobs();
  }

  /// Khoảng cách (m) từ camera mà sau đó không còn bóng động (0 = tới far plane của camera — mặc định, như cũ).
  double _shadowFar = 0;

  /// Giới hạn bóng động trong [meters] m tính từ camera (thành phố V3, khi mức đồ họa bật bóng động): mặt đất của quận có
  /// hộp bao rất lớn nên shadow map trải trên cả vùng nhìn tới far plane → texel to khi camera nhìn gần như ngang (cận
  /// cảnh). 0 = như cũ (tới far plane).
  Future<void> setShadowFar(double meters) => _graphicsQueue = _graphicsQueue.then((_) {
        if (_disposed || meters == _shadowFar) return;
        _shadowFar = meters;
        final sun = _sun, g = _graphics;
        if (sun == null || g == null) return;
        try {
          (viewer.app as FFIFilamentApp)
              .lightManager
              .setShadowOptions(sun, ShadowOptions(mapSize: g.shadowMapSize, shadowFar: meters));
        } catch (e) {
          debugPrint('Shop3dScene: shadowFar failed: $e');
        }
      });

  // ---- Tiệm -------------------------------------------------------------------------------------------------

  /// Mọi lưới tĩnh tạo **song song**: trên web luồng render (worker) xử lý hết hàng đợi lệnh rồi mới vẽ một khung, nên
  /// ~10 lệnh nối tiếp mỗi lưới × nhiều lưới mà `await` từng cái = hàng trăm khung (vài chục giây trên GPU thật, vài phút
  /// trên Chrome headless). Song song: còn ~độ dài một chuỗi lệnh (~10–15 khung).
  Future<void> _buildShop() async {
    final batches = Shop3dBatches.build();
    // Material trước (dùng chung, mỗi khoá một lần).
    await Future.wait([
      for (final k in {for (final b in batches) ...b.meshes.keys}) _material(k),
    ]);
    final assets = await Future.wait([
      for (final b in batches)
        Future.wait([
          // Nền / tường / kính không đổ bóng (kiểu nhà búp bê: tiệm sáng đều, bóng không nhảy khi tường ẩn / hiện);
          // vật thể đục đổ bóng xuống sàn khi bật bóng động.
          for (final e in b.meshes.entries) _addMesh(e.value, e.key, castShadows: b.castsShadow(e.key)),
        ]),
    ]);
    for (var i = 0; i < batches.length; i++) {
      _batches.add(_BatchNode(batches[i], assets[i]));
      _staticEntities += assets[i].length;
    }
    // createGeometry tự thêm vào scene: gỡ những gì chưa sở hữu.
    _applyVisibility();
    _rebuildPickBoxes();
  }

  final _materialJobs = <Shop3dSurfaceKey, Future<UbershaderMaterialInstance>>{};

  @override
  Future<UbershaderMaterialInstance> surfaceMaterial(Shop3dSurfaceKey key) => _material(key);

  @override
  Future<UbershaderMaterialInstance> shadowMaterial() => _ensureShadowMaterial();

  Future<UbershaderMaterialInstance>? _chibiMatJob;

  /// Một material cho mọi chibi (và vật tương tác): ubershader nhân baseColor (trắng) với màu đỉnh của lưới.
  /// doubleSided: tấm một mặt (tạp dề, gile, khăn, túi, cổ tay áo) nhìn từ mép / từ dưới vẫn thấy mặt trong, đúng màu
  /// (không thủng). Tạo một lần (nhớ Future), dùng chung với lớp phố.
  @override
  Future<UbershaderMaterialInstance> chibiMaterial() => _chibiMatJob ??= () async {
        final mat = await viewer.app.createUbershaderMaterial(hasVertexColors: true, doubleSided: true);
        await Future.wait([mat.setBaseColorFactor(1, 1, 1, 1), mat.setMetallicFactor(0), mat.setRoughnessFactor(0.72)]);
        _extraMaterials.add(mat);
        return mat;
      }();

  /// Mặt đục: material màu đỉnh (baseColorFactor trắng × màu đỉnh tuyến tính — mục 9.15 ghi chú API), một cái cho mỗi
  /// độ nhám; tranh cảnh ngoài cửa sổ ([Shop3dSurface.backdrop]) dùng material màu đỉnh unlit. Mặt trong suốt: material
  /// một màu (màu + alpha ở baseColorFactor) như trước.
  Future<UbershaderMaterialInstance> _material(Shop3dSurfaceKey key) => _materialJobs.putIfAbsent(key, () async {
        final tint = key.tint;
        final mat = await viewer.app.createUbershaderMaterial(
          unlit: key.surface.unlit,
          hasVertexColors: tint == null,
          alphaMode: tint == null ? AlphaMode.OPAQUE : AlphaMode.BLEND,
        );
        await Future.wait([
          if (tint == null)
            mat.setBaseColorFactor(1, 1, 1, 1)
          else
            mat.setBaseColorFactor(tint.linearR, tint.linearG, tint.linearB, tint.alpha),
          mat.setMetallicFactor(0),
          mat.setRoughnessFactor(key.surface.roughness),
        ]);
        return _materials[key] = mat;
      });

  Future<ThermionAsset> _addMesh(Shop3dMesh mesh, Shop3dSurfaceKey key, {required bool castShadows}) async {
    final mat = await _material(key);
    // Màu đỉnh thật (typed list thường — mục 9.1) cho material màu đỉnh. Material trong suốt một màu: ubershader VẪN
    // nhân màu đỉnh của lưới (kể cả tạo với hasVertexColors: false — đã thấy trên web: cửa lò đậm gấp đôi, kính trong
    // gấp đôi) → đỉnh trắng như trước. UV RỖNG như lưới chibi: không dùng texture, tangent tính từ pháp tuyến (UV toàn 0
    // làm hỏng pháp tuyến ở tấm to phẳng — mục 9.19).
    final colors =
        key.tint == null ? mesh.colors : (Float32List(mesh.colors.length)..fillRange(0, mesh.colors.length, 1.0));
    final asset = await viewer.createGeometry(
      Geometry(
        mesh.positions,
        mesh.indices,
        normals: mesh.normals,
        uvs: Float32List(0),
        uvs1: Float32List(0),
        colors: colors,
      ),
    );
    // Lưới tự tạo của thermion (GeometrySceneAsset) mặc định không đổ và KHÔNG nhận bóng → bật nhận bóng cho mọi lưới.
    await Future.wait([
      asset.setMaterialInstanceAt(mat.materialInstance),
      asset.setReceiveShadows(true),
      if (castShadows) asset.setCastShadows(true),
    ]);
    _entities++;
    _triangles += mesh.triangleCount;
    return asset;
  }

  /// `Geometry` với mọi mảng là typed list thường (UV / màu đỉnh tự tạo bằng `makeFloat32List` bị ghi đè trên web).
  Future<ThermionAsset> _createGeometry(
    Float32List positions,
    Float32List normals,
    Float32List? uvs,
    List<int> indices,
  ) {
    final n = positions.length ~/ 3;
    final uv = uvs ?? Float32List(n * 2);
    return viewer.createGeometry(
      Geometry(
        positions,
        indices,
        normals: normals,
        uvs: uv,
        uvs1: Float32List.fromList(uv),
        colors: Float32List(n * 4)..fillRange(0, n * 4, 1.0),
      ),
    );
  }

  // ---- Nhân vật ---------------------------------------------------------------------------------------------

  Future<void> _buildActors() async {
    try {
      _sampler = await viewer.app.createTextureSampler(
        minFilter: TextureMinFilter.LINEAR_MIPMAP_LINEAR,
        magFilter: TextureMagFilter.LINEAR,
      );
      await _ensureShadowMaterial();
    } catch (e) {
      debugPrint('Shop3dScene: actor setup failed: $e');
      return;
    }
    // Giải mã ảnh song song (Flutter, ngoài luồng render), rồi tạo tài nguyên Filament song song (xem [_buildShop]).
    final images = await Future.wait([for (final a in Shop3dActors.all) _decodeSprite(a.assetPath)]);
    if (_disposed) return;
    final nodes = await Future.wait([
      for (var i = 0; i < Shop3dActors.all.length; i++)
        if (images[i] != null)
          _addActor(Shop3dActors.all[i], images[i]!).catchError((Object e) {
            debugPrint('Shop3dScene: actor ${Shop3dActors.all[i].id} failed: $e');
            return null;
          }),
    ]);
    for (final n in nodes) {
      if (n != null) _actors.add(n);
    }
    _log('actors: ${_actors.length}');
    if (_disposed) return;
    final yaw = _yaw;
    _yaw = double.nan;
    if (!yaw.isNaN) setBillboardYaw(yaw);
    _applyVisibility();
    _rebuildPickBoxes();
  }

  /// Material bóng mềm dưới chân (unlit, trong suốt, nâu chocolate) — dùng chung cho billboard và chibi. Nhớ Future:
  /// các bóng tròn tạo song song cùng chờ MỘT lần tạo (trước đây mỗi bóng tạo song song một material → ~10 bản thừa).
  Future<UbershaderMaterialInstance> _ensureShadowMaterial() => _shadowJob ??= () async {
        final shadow =
            _shadowMaterial = await viewer.app.createUbershaderMaterial(unlit: true, alphaMode: AlphaMode.BLEND);
        final c = Shop3dMaterialKey(Shop3dColor.chocolate.argb, actorShadowAlpha);
        await shadow.setBaseColorFactor(c.linearR, c.linearG, c.linearB, actorShadowAlpha);
        _extraMaterials.add(shadow);
        return shadow;
      }();

  Future<UbershaderMaterialInstance>? _shadowJob;

  /// Ảnh WebP → RGBA alpha thẳng bằng bộ giải mã của Flutter (decoder của Filament có thể không đọc WebP), rồi cắt
  /// viền + loang màu mép. null nếu thiếu file / lỗi.
  Future<Shop3dRgbaImage?> _decodeSprite(String path) async {
    try {
      final data = await _bundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      final image = frame.image;
      var premultiplied = false;
      ByteData? bytes;
      try {
        bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      } catch (_) {
        bytes = null;
      }
      if (bytes == null) {
        bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        premultiplied = true;
      }
      final w = image.width, h = image.height;
      image.dispose();
      codec.dispose();
      if (bytes == null) return null;
      final pixels = Uint8List.fromList(bytes.buffer.asUint8List(bytes.offsetInBytes, w * h * 4));
      if (premultiplied) Shop3dSprite.unpremultiply(pixels);
      return Shop3dSprite.prepare(Shop3dRgbaImage(w, h, pixels));
    } catch (e) {
      debugPrint('Shop3dScene: sprite $path failed: $e');
      return null;
    }
  }

  Future<_ActorNode?> _addActor(Shop3dActor actor, Shop3dRgbaImage img) async {
    final app = viewer.app;
    final mips = Shop3dSprite.mipChain(img);
    final tex = await app.createTexture(
      img.width,
      img.height,
      levels: mips.length,
      textureFormat: TextureFormat.SRGB8_A8,
    );
    _textures.add(tex);
    await Future.wait([for (var l = 0; l < mips.length; l++) _upload(tex, l, mips[l])]);
    final mat = await app.createUbershaderMaterial(
      unlit: true,
      hasBaseColorTexture: true,
      // BẮT BUỘC: mặc định của createUbershaderMaterial là -1 → sang C++ thành uint8 255, gltfio tra UvMap (8 phần
      // tử) ngoài biên → WASM abort (native: ghi đè bộ nhớ). Thermion 0.5.0.
      baseColorUV: 0,
      alphaMode: AlphaMode.MASK,
      doubleSided: true,
    );
    _extraMaterials.add(mat);
    await mat.setBaseColorTexture(tex, _sampler!);

    final w = img.widthMeters(), h = img.heightMeters();
    final (pos, nrm, uv, idx) = buildBillboardQuad(w, h);
    final disc = buildDisc(0, 0.03, 0, Shop3dActors.shadowDiameter);
    final (quad, blob) = await (
      _createGeometry(pos, nrm, uv, idx),
      _createGeometry(disc.positions, disc.normals, null, disc.indices),
    ).wait;
    // Billboard và bóng mềm: unlit, không đổ / nhận bóng (mặc định của lưới tự tạo).
    await Future.wait([
      quad.setMaterialInstanceAt(mat.materialInstance),
      blob.setMaterialInstanceAt(_shadowMaterial!.materialInstance),
    ]);
    _entities += 2;
    _triangles += 2 + disc.triangleCount;

    final node = _ActorNode(actor, quad, blob, w, h, inScene: true);
    _m.setIdentity();
    _m.setTranslationRaw(actor.x, 0, actor.z);
    await viewer.app.setTransform(blob.entity, _m);
    _writeActorTransform(node, _yaw.isNaN ? 0 : _yaw, 0);
    return node;
  }

  /// Nạp một mức mipmap. `Texture_setImageRenderThread` của thermion chép dữ liệu **trên luồng render, sau khi** lệnh
  /// FFI đã trả về, nên không được đưa thẳng `Uint8List` của Dart: native — GC có thể dời mảng (mảng < ~256 KB nằm ở
  /// new space) trước khi kịp chép → mipmap rác; web — mảng < 32 KB bị chép vào stack WASM (`stackAlloc`) và có thể bị
  /// ghi đè. Dùng bộ đệm `malloc` (bộ nhớ native / heap WASM, không bị dời), giải phóng khi lệnh xong (callback chỉ
  /// về sau khi luồng render đã chép).
  Future<void> _upload(Texture tex, int level, Shop3dRgbaImage m) async {
    final n = m.pixels.length;
    final ptr = malloc<Uint8>(n);
    try {
      final buf = ptr.asTypedList(n)..setRange(0, n, m.pixels);
      await tex.setImage(level, buf, m.width, m.height, PixelDataFormat.RGBA, PixelDataType.UBYTE);
    } finally {
      free(ptr);
    }
  }

  // ---- Nhân vật chibi ---------------------------------------------------------------------------------------

  Future<void> _buildChibis() async {
    try {
      final mat = await chibiMaterial();
      final lineup = options.lineup;
      // Kiểu tóc Mai khác mặc định (thành phố V3) → dựng Mai theo kiểu đó; mặc định = như cũ.
      final look = _maiLook;
      final models = look == MaiLook.defaults ? null : {ChibiCharacters.mai: buildMai(look)};
      final actors = lineup == null
          ? ChibiCast.build(models: models, mochi: options.mochi)
          : ChibiLineup.build(ChibiRoster.select(lineup));
      // Mọi bộ phận tạo song song (xem [_buildShop]).
      final nodes = await Future.wait([for (final a in actors) _addChibi(a, mat)]);
      if (_disposed) return;
      _chibis.addAll(nodes);
      _chibiMat = mat;
      for (final n in nodes) {
        if (n.actor.id != ChibiCharacters.mai) continue;
        n.look = look;
        _maiLookParts[look] = Future.value({
          for (var i = 0; i < n.parts.length; i++)
            if (_lookParts.contains(n.parts[i])) n.parts[i]: n.assets[i],
        });
      }
      // Lớp đang tắt (thành phố: dựng nền khi Mai ở ngoài phố) — createGeometry tự thêm vào scene → gỡ ra.
      if (!_active) {
        _enqueue([
          for (final n in nodes)
            for (final a in n.assets) (a, false),
        ]);
      }
      if (_maiLook != look) unawaited(setMaiLook(_maiLook));
      _director = ChibiDirector(actors);
      _updateChibis(0);
      _syncBlobs();
      _log('chibis: ${_chibis.length}, $chibiTransformsPerUpdate parts');
    } catch (e, st) {
      debugPrint('Shop3dScene: chibi setup failed: $e\n$st');
    }
  }

  Future<_ChibiNode> _addChibi(ChibiActor actor, UbershaderMaterialInstance mat) async {
    final parts = <ChibiPart>[
      for (final p in ChibiPart.values)
        if (actor.model.meshes.containsKey(p)) p,
    ];
    final assets = await Future.wait([for (final p in parts) _addChibiMesh(actor.model.meshes[p]!, mat)]);
    return _ChibiNode(actor, parts, assets);
  }

  Future<ThermionAsset> _addChibiMesh(ChibiMesh mesh, UbershaderMaterialInstance mat, {bool cast = true}) async {
    // Mọi mảng là typed list thường (không makeFloat32List — mục 9.1 ghi chú API); màu đỉnh thật, tuyến tính.
    // UV RỖNG (không phải mảng 0): createGeometry chỉ đưa UV vào SurfaceOrientation khi có UV; UV toàn 0 làm phép tính
    // tangent theo UV suy biến ở tam giác to phẳng (túi áo) → quaternion TBN hỏng → mảng đen. Không UV → tangent
    // tính từ pháp tuyến. Material chibi không dùng texture nên thiếu dữ liệu UV không ảnh hưởng.
    final asset = await viewer.createGeometry(
      Geometry(
        mesh.positions,
        mesh.indices,
        normals: mesh.normals,
        uvs: Float32List(0),
        uvs1: Float32List(0),
        colors: mesh.colors,
      ),
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

  /// Bóng tròn dưới chân chibi (thay bóng động ở mức thấp): tạo lần đầu cần, thêm / gỡ khỏi scene theo
  /// [Shop3dGraphics.blobShadows].
  void _syncBlobs() {
    final want = (_graphics?.blobShadows ?? false) && _chibis.isNotEmpty;
    if (want == _blobsInScene) return;
    _blobsInScene = want;
    final ready = _blobsReady ??= _createBlobs();
    unawaited(
      ready.then((_) {
        if (_blobsInScene == want) {
          _enqueue([
            for (final n in _chibis)
              if (n.blob != null) (n.blob!, want && _active),
          ]);
        }
      }),
    );
  }

  /// Đĩa đường kính 1 m ở y = 0; mỗi khung co theo bán kính nhân vật và nâng nhẹ khỏi sàn ([_writeBlobs]).
  Future<ThermionAsset> _createBlob() async {
    final mat = await _ensureShadowMaterial();
    final disc = buildDisc(0, 0, 0, 1, segments: 20);
    final a = await _createGeometry(disc.positions, disc.normals, null, disc.indices);
    // Unlit, không đổ / nhận bóng (mặc định của lưới tự tạo).
    await a.setMaterialInstanceAt(mat.materialInstance);
    _entities++;
    _triangles += disc.triangleCount;
    return a;
  }

  Future<void> _createBlobs() async {
    try {
      final nodes = [
        for (final n in _chibis)
          if (n.blob == null) n,
      ];
      final assets = await Future.wait([for (final _ in nodes) _createBlob()]);
      if (_disposed) return;
      for (var i = 0; i < nodes.length; i++) {
        nodes[i].blob = assets[i];
      }
      _writeBlobs();
    } catch (e) {
      debugPrint('Shop3dScene: blob shadows failed: $e');
    }
  }

  /// Đặt bóng tròn dưới chân từng chibi (đồng bộ, như [_updateChibis]); bỏ qua bóng không đổi chỗ.
  void _writeBlobs() {
    final tm = (viewer.app as FFIFilamentApp).transformManager;
    for (final n in _chibis) {
      final blob = n.blob;
      if (blob == null) continue;
      final a = n.actor;
      final d = a.model.radius * blobDiameterScale;
      if (a.pose.x == n.blobX && a.pose.z == n.blobZ && d == n.blobD) continue;
      n
        ..blobX = a.pose.x
        ..blobZ = a.pose.z
        ..blobD = d;
      _sent++;
      _m
        ..setIdentity()
        ..setEntry(0, 0, d)
        ..setEntry(2, 2, d)
        ..setTranslationRaw(a.pose.x, blobLift, a.pose.z);
      tm.setTransform(blob.entity, _m);
    }
  }

  /// Tiến kịch bản chibi [dt] giây (theo [Shop3dSceneOptions.chibiHz]) và gửi transform. Trả true nếu có chibi.
  bool _tickChibis(double dt) {
    if (_director == null) return false;
    final hz = options.chibiHz;
    if (hz > 0 && hz < 60) {
      _chibiAcc += dt;
      final step = 1 / hz;
      if (_chibiAcc < step * 0.98) return true;
      dt = _chibiAcc;
      _chibiAcc = 0;
    }
    _updateChibis(dt);
    return true;
  }

  void _updateChibis(double dt) {
    final director = _director;
    if (director == null || _disposed) return;
    _chibiWatch
      ..reset()
      ..start();
    final pilot = _pilot;
    if (dt > 0) {
      pilot?.update(dt);
      director.update(dt, _owned);
      pilot?.lateUpdate();
    } else {
      for (final n in _chibis) {
        n.actor.update(1e-4, _owned);
      }
    }
    // Ma trận Dart (cột chính) → Matrix4 dùng chung → TransformManager.setTransform đồng bộ (đọc ngay, tái dùng _m).
    final tm = (viewer.app as FFIFilamentApp).transformManager;
    _sent = 0;
    for (final n in _chibis) {
      _writeChibi(tm, n);
    }
    if (_blobsInScene) _writeBlobs();
    if (pilot != null) _writeItems(tm, pilot, dt);
    _chibiWatch.stop();
    final us = _chibiWatch.elapsedMicroseconds.toDouble();
    _chibiMicros = _chibiMicros == 0 ? us : _chibiMicros * 0.95 + us * 0.05;
    _sentAvg = _sentAvg == 0 ? _sent.toDouble() : _sentAvg * 0.95 + _sent * 0.05;
  }

  /// Gửi ma trận thế giới các bộ phận của [n] có thay đổi so với lần gửi trước. Mỗi lệnh `setTransform` trên web là
  /// ~25 lời gọi JS ↔ WASM (cấp struct trên stack WASM, ghi 16 số từng số một) — so 16 số ở Dart rẻ hơn nhiều.
  void _writeChibi(FFITransformManager tm, _ChibiNode n) {
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
      tm.setTransform(n.assets[i].entity, _m);
      _sent++;
    }
  }

  // ---- Tương tác (V3) ---------------------------------------------------------------------------------------

  /// Gắn bộ điều phối tương tác (sau khi dàn chibi dựng xong, [hasChibis]): dựng entity 4 vật tương tác; từ đó mỗi
  /// lần cập nhật chibi chạy `pilot.update` / `pilot.lateUpdate` và gửi transform của vật.
  void attachPilot(Shop3dPilot pilot) {
    _pilot = pilot;
    unawaited(_buildItems(pilot.items));
  }

  Future<void> _buildItems(ItemBoard board) async {
    final mat = _chibiMat;
    if (mat == null || _itemNodes.isNotEmpty) return;
    try {
      final meshes = {for (final k in ItemKind.values) k: Shop3dItemMeshes.of(k)};
      // Vật không đổ bóng động (rẻ trên máy yếu); nhận bóng như mọi lưới.
      final assets = await Future.wait([
        for (final it in board.items) _addChibiMesh(meshes[it.kind]!, mat, cast: false),
      ]);
      if (_disposed) return;
      for (var i = 0; i < board.items.length; i++) {
        _itemNodes.add(_ItemNode(board.items[i], assets[i]));
      }
      if (!_active) {
        for (final n in _itemNodes) {
          n.inScene = false;
        }
        _enqueue([for (final n in _itemNodes) (n.asset, false)]);
      }
      _log('items: ${_itemNodes.length}');
    } catch (e, st) {
      debugPrint('Shop3dScene: items failed: $e\n$st');
    }
  }

  /// Transform của vật tương tác: đang cầm → quay theo người cầm; đang bay → xoay tròn; ẩn / hiện khi tặng hộp bánh.
  void _writeItems(FFITransformManager tm, Shop3dPilot pilot, double dt) {
    if (_itemNodes.isEmpty) return;
    List<(ThermionAsset, bool)>? batch;
    for (final n in _itemNodes) {
      final it = n.item;
      final want = it.visible && _active;
      if (want != n.inScene) {
        n.inScene = want;
        (batch ??= []).add((n.asset, want));
      }
      if (!want) continue;
      switch (it.phase) {
        case ItemPhase.held:
          final h = pilot.actorById(it.holderId ?? '');
          if (h != null) n.yaw = h.pose.yaw;
        case ItemPhase.flying:
          n.yaw += dt * 9;
        case ItemPhase.rest:
        case ItemPhase.hidden:
          break;
      }
      if (it.x == n.x && it.y == n.y && it.z == n.z && n.yaw == n.sentYaw) continue;
      n
        ..x = it.x
        ..y = it.y
        ..z = it.z
        ..sentYaw = n.yaw;
      _m.setRotationY(n.yaw);
      _m.setTranslationRaw(it.x, it.y, it.z);
      tm.setTransform(n.asset.entity, _m);
      _sent++;
    }
    if (batch != null) _enqueue(batch);
  }

  @override
  Set<String> get owned => Set.unmodifiable(_owned);

  @override
  ChibiModel? readyModel(String id) => _eventModels[id]?.model;

  /// Dựng sẵn khách thường [ids] (model + entity song song, gỡ khỏi scene ngay) — lúc rảnh, trước khi sự kiện / khách
  /// của ca bán tới. Nhận `regular_*` và `vip_01` / `vip_02` (xem `isShiftGuestId`).
  @override
  void prepareModels(List<String> ids) {
    for (final id in ids) {
      if (!isShiftGuestId(id)) continue;
      _eventJobs.putIfAbsent(id, () => _buildEventModel(id));
    }
  }

  Future<void> _buildEventModel(String id) async {
    final mat = _chibiMat;
    if (mat == null) return;
    try {
      // Nhường một nhịp để không dựng chung khung với việc khác (lưới khách ~4k tam giác, tính ở Dart).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_disposed) return;
      final model = ChibiSizes.fit(buildShiftGuest(id));
      final parts = <ChibiPart>[
        for (final p in ChibiPart.values)
          if (model.meshes.containsKey(p)) p,
      ];
      final (assets, blob) = await (
        Future.wait([for (final p in parts) _addChibiMesh(model.meshes[p]!, mat)]),
        _createBlob(),
      ).wait;
      if (_disposed) return;
      // Dời xa khỏi tầm nhìn rồi gỡ khỏi scene (createGeometry tự thêm vào).
      final tm = (viewer.app as FFIFilamentApp).transformManager;
      _m
        ..setIdentity()
        ..setTranslationRaw(0, -50, 0);
      for (final a in [...assets, blob]) {
        tm.setTransform(a.entity, _m);
      }
      _enqueue([
        for (final a in [...assets, blob]) (a, false),
      ]);
      _eventModels[id] = _EventModel(model, parts, assets, blob);
      _log('event model $id ready');
    } catch (e, st) {
      debugPrint('Shop3dScene: event model $id failed: $e\n$st');
      _eventJobs.remove(id);
    }
  }

  /// Thêm khách sự kiện [a] (model đã dựng sẵn bằng [prepareModels]) vào cảnh.
  @override
  void addActor(ChibiActor a) {
    final e = _eventModels[a.id];
    final d = _director;
    if (e == null || d == null || _chibis.any((n) => n.actor.id == a.id)) return;
    final node = _ChibiNode(a, e.parts, e.assets)..blob = e.blob;
    a.update(1e-4, _owned);
    _writeChibi((viewer.app as FFIFilamentApp).transformManager, node);
    _chibis.add(node);
    d.actors.add(a);
    if (_active) _enqueue([for (final x in e.assets) (x, true), if (_blobsInScene) (e.blob, true)]);
    if (_blobsInScene) _writeBlobs();
  }

  /// Gỡ khách sự kiện [a] khỏi cảnh (entity giữ lại cho lần sau).
  @override
  void removeActor(ChibiActor a) {
    final i = _chibis.indexWhere((n) => identical(n.actor, a));
    _director?.actors.remove(a);
    if (i < 0) return;
    final n = _chibis.removeAt(i);
    if (_active) {
      _enqueue([for (final x in n.assets) (x, false), if (n.blob != null && _blobsInScene) (n.blob!, false)]);
    }
  }

  // ---- Kiểu tóc Mai (thành phố V3) ----------------------------------------------------------------------------

  /// Bộ phận đổi theo kiểu tóc (`buildMai`: rig, thân, mắt giống hệt giữa các kiểu).
  static const _lookParts = {ChibiPart.head, ChibiPart.extra};

  /// Kiểu tóc hiện tại của Mai trong tiệm.
  MaiLook get maiLook => _maiLook;

  /// Đổi kiểu tóc Mai trong tiệm: chỉ thay entity của [ChibiPart.head] + [ChibiPart.extra]; entity mỗi kiểu dựng một lần
  /// rồi giữ lại (ngoài scene khi không dùng). Dàn chibi chưa dựng thì áp lúc dựng. Các lần gọi chạy nối tiếp; Future
  /// hoàn tất khi đã đổi (lệnh thêm / gỡ đã xếp hàng).
  Future<void> setMaiLook(MaiLook look) {
    _maiLook = look;
    return _lookQueue = _lookQueue.then((_) => _applyMaiLook()).catchError((Object e) {
      debugPrint('Shop3dScene: mai look failed: $e');
    });
  }

  Future<void> _applyMaiLook() async {
    if (_disposed) return;
    final look = _maiLook;
    _ChibiNode? node;
    for (final n in _chibis) {
      if (n.actor.id == ChibiCharacters.mai) node = n;
    }
    if (node == null || node.look == look) return;
    final parts = await (_maiLookParts[look] ??= _buildLookParts(look));
    if (parts == null || _disposed || _maiLook != look) return;
    final batch = <(ThermionAsset, bool)>[];
    for (final e in parts.entries) {
      final i = node.parts.indexOf(e.key);
      if (i < 0 || identical(node.assets[i], e.value)) continue;
      batch.add((node.assets[i], false));
      node.assets[i] = e.value;
      node.sent.fillRange(i * 16, i * 16 + 16, double.nan);
      if (_active) batch.add((e.value, true));
    }
    // Ma trận hiện tại cho entity mới trước khi thêm vào scene (không loé ở chỗ để dành).
    _writeChibi((viewer.app as FFIFilamentApp).transformManager, node);
    node.look = look;
    _enqueue(batch);
    await _queue;
  }

  /// Entity đầu + phụ của kiểu [look] (cùng kích thước trong cảnh như dàn chibi), dời ra xa rồi gỡ khỏi scene.
  Future<Map<ChibiPart, ThermionAsset>?> _buildLookParts(MaiLook look) async {
    final mat = _chibiMat;
    if (mat == null) return null;
    try {
      final model = ChibiSizes.fit(buildMai(look));
      final keys = [
        for (final p in _lookParts)
          if (model.meshes.containsKey(p)) p,
      ];
      final assets = await Future.wait([for (final p in keys) _addChibiMesh(model.meshes[p]!, mat)]);
      if (_disposed) return null;
      final tm = (viewer.app as FFIFilamentApp).transformManager;
      _m
        ..setIdentity()
        ..setTranslationRaw(0, -50, 0);
      for (final a in assets) {
        tm.setTransform(a.entity, _m);
      }
      _enqueue([for (final a in assets) (a, false)]);
      return {for (var i = 0; i < keys.length; i++) keys[i]: assets[i]};
    } catch (e, st) {
      debugPrint('Shop3dScene: mai look $look failed: $e\n$st');
      _maiLookParts.remove(look);
      return null;
    }
  }

  // ---- Bật / tắt -------------------------------------------------------------------------------------------

  /// Đổi tập mục đã sở hữu (`Shop3dRequires`): bật / tắt vật mở rộng, chỗ ngồi, nhân vật phụ thuộc.
  Future<void> setOwned(Set<String> owned) {
    _owned = {...owned};
    _pilot?.setOwned(_owned);
    _applyVisibility();
    _rebuildPickBoxes();
    return _queue;
  }

  /// Ẩn các mặt tường có bit trong [mask] (`RoomWall.bit`). Chỉ gửi lệnh cho mặt đổi trạng thái.
  void setWallMask(int mask) {
    if (mask == _wallMask) return;
    _wallMask = mask;
    _applyVisibility();
  }

  /// Bật / tắt cả lớp tiệm (thành phố V3: Mai ra phố → tắt). Tắt: gỡ mọi entity của lớp (lưới tĩnh, nhân vật, bóng
  /// tròn, vật tương tác) khỏi scene, KHÔNG huỷ; bật: thêm lại đúng những gì đang phải hiện (cờ mở rộng, mặt nạ tường,
  /// vật đang hiện). Đèn / IBL / material giữ nguyên (dùng chung với lớp khác). Lớp tắt thì không gọi [tick].
  /// Future hoàn tất khi mọi lệnh đã gửi xong.
  Future<void> setActive(bool active) {
    if (active == _active) return _queue;
    _active = active;
    final batch = <(ThermionAsset, bool)>[];
    final tm = (viewer.app as FFIFilamentApp).transformManager;
    for (final n in _chibis) {
      // Bật lại: gửi ngay ma trận hiện tại (bộ phận vừa đổi kiểu tóc chưa có ma trận) trước khi thêm vào scene.
      if (active) _writeChibi(tm, n);
      for (final a in n.assets) {
        batch.add((a, active));
      }
      if (_blobsInScene && n.blob != null) batch.add((n.blob!, active));
    }
    for (final n in _itemNodes) {
      final want = active && n.item.visible;
      if (want == n.inScene) continue;
      n.inScene = want;
      batch.add((n.asset, want));
    }
    _enqueue(batch);
    _applyVisibility();
    return _queue;
  }

  /// Lớp tiệm đang hiện ([setActive]).
  bool get active => _active;

  /// Thêm / gỡ nhóm lưới tĩnh theo cờ mở rộng + mặt nạ tường, billboard theo cờ. Chỉ gửi lệnh cho mục đổi trạng thái.
  void _applyVisibility() {
    final batch = <(ThermionAsset, bool)>[];
    for (final n in _batches) {
      final wall = n.batch.wall;
      final want = _active && n.batch.enabledFor(_owned) && (wall == null || _wallMask & wall.bit == 0);
      if (want == n.inScene) continue;
      n.inScene = want;
      for (final a in n.assets) {
        batch.add((a, want));
      }
    }
    for (final a in _actors) {
      final want = _active && a.actor.enabledFor(_owned);
      if (want == a.inScene) continue;
      a.inScene = want;
      batch
        ..add((a.quad, want))
        ..add((a.shadow, want));
    }
    _enqueue(batch);
  }

  /// Gửi một lô lệnh add/removeFromScene (song song trong lô; các lô nối tiếp nhau để không xen thứ tự).
  void _enqueue(List<(ThermionAsset, bool)> batch) {
    if (batch.isEmpty) return;
    _queue = _queue.then((_) async {
      if (_disposed) return;
      await Future.wait([
        for (final (asset, show) in batch)
          (show ? viewer.addToScene(asset) : viewer.removeFromScene(asset)).catchError((Object e) {
            debugPrint('Shop3dScene: ${show ? 'add' : 'remove'} failed: $e');
          }),
      ]);
    });
  }

  void _rebuildPickBoxes() {
    _pickBoxes = [
      for (final n in _batches)
        if (n.inScene && n.batch.prop != null) ...pickBoxesForProp(n.batch.prop!),
      for (final a in _actors)
        if (a.inScene)
          Shop3dPickBox(
            a.actor.id,
            Shop3dPickKind.actor,
            a.actor.x - a.width * 0.35,
            0,
            a.actor.z - 0.25,
            a.actor.x + a.width * 0.35,
            a.height,
            a.actor.z + 0.25,
          ),
    ];
  }

  // ---- Billboard + nhún -------------------------------------------------------------------------------------

  /// Quay mọi billboard theo góc [yaw] của camera (chỉ trục y). Bỏ qua khi góc gần như không đổi.
  void setBillboardYaw(double yaw) {
    if (!_yaw.isNaN && (yaw - _yaw).abs() < 1e-4) return;
    _yaw = yaw;
    for (final a in _actors) {
      _writeActorTransform(a, yaw, a.actor.id == _hopId ? _hopOffset : 0);
    }
  }

  void _writeActorTransform(_ActorNode a, double yaw, double dy) {
    _m.setRotationY(yaw);
    _m.setTranslationRaw(a.actor.x, dy, a.actor.z);
    // TransformManager.setTransform của thermion chạy đồng bộ (đọc ma trận ngay) → tái dùng [_m] được.
    unawaited(viewer.app.setTransform(a.quad.entity, _m));
  }

  /// Nhún vật thể / nhân vật [id] (vừa được chạm chọn). Gọi [tick] mỗi khung tới khi nó trả false. Chibi: nhảy vui
  /// quay về phía camera (đang ngồi thì vẫy tay).
  void hop(String id) {
    for (final n in _chibis) {
      if (n.actor.id == id) {
        n.actor.react(_yaw.isNaN ? 0 : _yaw);
        return;
      }
    }
    if (_hopId != null && _hopId != id) _writeHop(_hopId!, 0);
    _hopId = id;
    _hopT = 0;
  }

  double get _hopOffset => hopHeight * math.sin(math.pi * (_hopT / hopDuration).clamp(0.0, 1.0));

  /// Tiến animation [dt] giây (nhún vật chọn + nhân vật chibi). Trả true nếu còn đang chạy (có chibi = luôn chạy).
  bool tick(double dt) {
    final chibi = _tickChibis(dt);
    final id = _hopId;
    if (id == null) return chibi;
    _hopT += dt;
    if (_hopT >= hopDuration) {
      _writeHop(id, 0);
      _hopId = null;
      return chibi;
    }
    _writeHop(id, _hopOffset);
    return true;
  }

  void _writeHop(String id, double dy) {
    for (final a in _actors) {
      if (a.actor.id == id) _writeActorTransform(a, _yaw.isNaN ? 0 : _yaw, dy);
    }
    for (final n in _batches) {
      if (n.batch.prop?.id != id) continue;
      _m.setIdentity();
      _m.setTranslationRaw(0, dy, 0);
      for (final a in n.assets) {
        unawaited(viewer.app.setTransform(a.entity, _m));
      }
    }
  }

  /// Gỡ tài nguyên tự tạo (texture, sampler, material). Gọi TRƯỚC `viewer.dispose()`.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _queue;
      await viewer.destroyAssets();
      for (final m in [..._materials.values, ..._extraMaterials]) {
        await m.materialInstance.destroy();
      }
      for (final t in _textures) {
        await t.destroy();
      }
      await _sampler?.dispose();
    } catch (e) {
      debugPrint('Shop3dScene: dispose failed: $e');
    }
    _materials.clear();
    _extraMaterials.clear();
    _textures.clear();
    _chibis.clear();
    _director = null;
  }
}

class _ChibiNode {
  _ChibiNode(this.actor, this.parts, this.assets)
      : sent = Float64List(parts.length * 16)..fillRange(0, parts.length * 16, double.nan);

  final ChibiActor actor;

  /// Bộ phận có lưới, cùng thứ tự với [assets].
  final List<ChibiPart> parts;
  final List<ThermionAsset> assets;

  /// Ma trận đã gửi lần trước, 16 số mỗi bộ phận (NaN = chưa gửi → lần đầu luôn gửi).
  final Float64List sent;

  /// Bóng tròn dưới chân (mức thấp); null = chưa tạo.
  ThermionAsset? blob;

  /// Vị trí / đường kính bóng tròn đã gửi.
  double blobX = double.nan, blobZ = double.nan, blobD = double.nan;

  /// Kiểu tóc đang gắn (chỉ Mai; null = nhân vật khác).
  MaiLook? look;
}

/// Material dùng chung giữa các lớp cảnh trên cùng một viewer (thành phố V3: lớp phố dùng lại material của lớp tiệm —
/// mặt đục màu đỉnh / tranh unlit theo [Shop3dSurfaceKey], chibi, bóng tròn — không tạo bản trùng).
abstract interface class Shop3dSharedMaterials {
  /// Material của bề mặt [key] (mặt đục: màu đỉnh theo độ nhám; `backdrop`: màu đỉnh unlit).
  Future<UbershaderMaterialInstance> surfaceMaterial(Shop3dSurfaceKey key);

  /// Material màu đỉnh của chibi / vật tương tác.
  Future<UbershaderMaterialInstance> chibiMaterial();

  /// Material bóng tròn dưới chân (unlit, trong suốt).
  Future<UbershaderMaterialInstance> shadowMaterial();
}

/// Entity của một vật tương tác.
class _ItemNode {
  _ItemNode(this.item, this.asset);

  final ShopItem item;
  final ThermionAsset asset;
  bool inScene = true;
  double yaw = 0;

  /// Transform đã gửi (NaN = chưa gửi).
  double x = double.nan, y = double.nan, z = double.nan, sentYaw = double.nan;
}

/// Khách sự kiện dựng sẵn: model + entity từng bộ phận + bóng tròn (để ngoài scene khi không dùng).
class _EventModel {
  _EventModel(this.model, this.parts, this.assets, this.blob);

  final ChibiModel model;
  final List<ChibiPart> parts;
  final List<ThermionAsset> assets;
  final ThermionAsset blob;
}

/// Entity của một nhóm lưới tĩnh (mỗi khoá bề mặt một entity). createGeometry tự thêm vào scene → [inScene] ban đầu true.
class _BatchNode {
  _BatchNode(this.batch, this.assets);

  final Shop3dBatch batch;
  final List<ThermionAsset> assets;
  bool inScene = true;
}

class _ActorNode {
  _ActorNode(this.actor, this.quad, this.shadow, this.width, this.height, {required this.inScene});

  final Shop3dActor actor;
  final ThermionAsset quad;
  final ThermionAsset shadow;
  final double width, height;
  bool inScene;
}

/// Tiện ích cho view: [Vec3] của controller → [Vector3] của thermion, ghi vào [out] (không cấp phát).
Vector3 copyVec3(Vec3 v, Vector3 out) => out..setValues(v.x, v.y, v.z);
