// Bản thử kỹ thuật V3 (giai đoạn a): chứng minh Thermion/Filament chạy được trên Android và web.
// Không phải màn chơi: chỉ dựng sàn + vài khối màu theo bảng màu, nắng có bóng đổ + ánh sáng môi trường,
// camera đặt tay (lookAt + tiêu cự), đếm FPS khung Filament và chạm để chọn vật (picking).
// Chữ trên lớp phủ là số liệu gỡ lỗi (fps, id), không qua AppLocalizations vì không xuất hiện trong app chính.
//
// Chạy: flutter run -d chrome --cross-origin-isolation -t lib/main_3d_probe.dart
//       flutter build apk --debug -t lib/main_3d_probe.dart
//       --dart-define=PROBE_IBL=false: tắt ánh sáng môi trường (so sánh khi chỉnh đèn).
// Ghi chú API: docs/v3/thermion-api-notes.md.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture, View;

import 'core/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: ProbeScreen()));
}

/// Màu sRGB (bảng màu dự án) → tuyến tính cho `baseColorFactor` của Filament.
List<double> linearRgb(Color c) {
  double f(double v) => math.pow(v, 2.2).toDouble();
  return [f(c.r), f(c.g), f(c.b)];
}

/// Tiêu cự (mm, cảm biến 24 mm chiều cao như Filament) cho góc nhìn dọc [fovDeg].
double focalLengthForVerticalFov(double fovDeg) => 12.0 / math.tan(fovDeg * math.pi / 360.0);

/// Dựng lại [g] với màu đỉnh / UV là `Float32List` thường. Trên web, `makeFloat32List` của thermion cấp phát trên
/// stack WASM (`stackAlloc`) — `Geometry` dùng nó cho màu đỉnh/UV giả, và vùng nhớ đó bị ghi đè trước khi
/// `createGeometry` kịp tải lên → vệt cầu vồng. `Float32List` thường được chép vào heap đúng lúc gọi native.
Geometry webSafeGeometry(Geometry g) {
  final n = g.vertices.length ~/ 3;
  final uvs = g.hasUVs ? Float32List.fromList(g.uvs) : Float32List(n * 2);
  return Geometry(
    Float32List.fromList(g.vertices),
    List<int>.of(g.indices),
    normals: g.hasNormals ? Float32List.fromList(g.normals) : null,
    uvs: uvs,
    uvs1: Float32List.fromList(uvs),
    colors: Float32List(n * 4)..fillRange(0, n * 4, 1.0),
    primitiveType: g.primitiveType,
    indexType: g.indexType,
  );
}

/// Tia thế giới từ camera nhìn [eye] → [focus] (up = +Y), góc nhìn dọc [fovDeg], qua điểm [point] (logical px,
/// gốc trên-trái) của khung [viewport].
Ray cameraRay({
  required Vector3 eye,
  required Vector3 focus,
  required double fovDeg,
  required Size viewport,
  required Offset point,
}) {
  final forward = (focus - eye)..normalize();
  final right = forward.cross(Vector3(0, 1, 0))..normalize();
  final up = right.cross(forward)..normalize();
  final tanHalf = math.tan(fovDeg * math.pi / 360.0);
  final aspect = viewport.width / viewport.height;
  final nx = 2 * point.dx / viewport.width - 1;
  final ny = 1 - 2 * point.dy / viewport.height;
  final dir = forward + right * (nx * tanHalf * aspect) + up * (ny * tanHalf);
  return Ray.originDirection(eye.clone(), dir..normalize());
}

class ProbeScreen extends StatefulWidget {
  const ProbeScreen({super.key});

  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen> {
  static const _fovDeg = 40.0;
  static const _near = 0.1;
  static const _far = 100.0;
  static final _cameraPos = Vector3(7, 5.5, 9);
  static final _cameraFocus = Vector3(0, 0.6, 0);

  ThermionViewer? _viewer;
  Object? _error;
  bool _disposed = false;

  // Đo FPS: hook chạy mỗi lần Filament render một khung (native và web).
  int _frames = 0;
  int _fps = 0;
  Timer? _fpsTimer;
  // Tear-off của cùng một phương thức so sánh == bằng nhau → unregister được.
  Future<void> _frameHook() async => _frames++;

  // Hộp bao (toạ độ thế giới) của từng vật, cho raycast phía Dart.
  final List<(String, Aabb3)> _pickables = [];
  String _picked = '-';

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final viewer = await ThermionFlutterPlugin.createViewer();
      if (_disposed) {
        await viewer.dispose();
        return;
      }
      _viewer = viewer;
      await _buildScene(viewer);
      await viewer.app.registerRequestFrameHook(_frameHook);
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _fps = _frames;
          _frames = 0;
        });
      });
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Thermion probe init failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _buildScene(ThermionViewer viewer) async {
    final app = viewer.app;
    final c = linearRgb(AppColors.cream);
    await viewer.setBackgroundColor(c[0], c[1], c[2], 1);
    await viewer.setPostProcessing(true);
    await viewer.setAntiAliasing(false, true, false); // FXAA, rẻ trên máy tầm trung
    await viewer.setShadowsEnabled(true);
    await viewer.setShadowType(ShadowType.PCF);

    // Nắng chiếu xiên (đổ bóng) + đèn phụ ngược hướng (không bóng) cho mặt tối đỡ đen.
    await viewer.addDirectLight(DirectLight.sun(
      intensity: 90000,
      castShadows: true,
      direction: Vector3(-0.6, -1.0, -0.4).normalized(),
      color: const LinearColor(1.0, 0.95, 0.88),
    ));
    await viewer.addDirectLight(DirectLight(
      type: LightType.DIRECTIONAL,
      intensity: 25000,
      castShadows: false,
      direction: Vector3(0.7, -0.4, 0.6).normalized(),
      position: Vector3.zero(),
      color: const LinearColor(0.9, 0.95, 1.0),
    ));
    // Ánh sáng môi trường không cần file KTX: IBL chỉ có hệ số SH bậc 0 (màu đều mọi hướng).
    if (const bool.fromEnvironment("PROBE_IBL", defaultValue: true)) await _addAmbient(viewer, app, const LinearColor(1.0, 0.93, 0.85), 22000);

    // Sàn (plane nằm trong mặt XZ, pháp tuyến +Y).
    await _addBox(
      viewer,
      app,
      label: 'floor',
      geometry: GeometryUtils.plane(width: 14, height: 14),
      color: AppColors.caramel,
      transform: Matrix4.identity(),
      castShadows: false,
      roughness: 0.9,
      doubleSided: true,
    );
    // CubeGeometry.cube() có cạnh 2 (−1..1) → scale = nửa kích thước.
    final boxes = <(String, Color, Vector3, Vector3)>[
      ('counter', AppColors.strawberry, Vector3(-2.2, 0.5, 0), Vector3(1.6, 0.5, 0.6)),
      ('case', AppColors.mint, Vector3(1.6, 0.6, -0.8), Vector3(0.9, 0.6, 0.5)),
      ('oven', AppColors.butter, Vector3(0.6, 0.45, 2.0), Vector3(0.5, 0.45, 0.5)),
      ('crate', AppColors.chocolate, Vector3(3.2, 0.3, 1.6), Vector3(0.3, 0.3, 0.3)),
    ];
    for (final (label, color, pos, half) in boxes) {
      await _addBox(
        viewer,
        app,
        label: label,
        geometry: CubeGeometry.cube(),
        color: color,
        transform: Matrix4.compose(pos, Quaternion.identity(), half),
      );
    }
    await _addBox(
      viewer,
      app,
      label: 'cake',
      geometry: SphereGeometry.sphere(latitudeBands: 16, longitudeBands: 16),
      color: AppColors.good,
      transform: Matrix4.compose(Vector3(-2.2, 1.35, 0), Quaternion.identity(), Vector3.all(0.35)),
    );

    final camera = await viewer.getActiveCamera();
    await camera.lookAt(_cameraPos, focus: _cameraFocus);
    // ThermionWidget đặt lại phép chiếu theo tiêu cự hiện tại mỗi khi đổi kích thước → đặt góc nhìn bằng tiêu cự.
    await camera.setLensProjection(near: _near, far: _far, focalLength: focalLengthForVerticalFov(_fovDeg), aspect: 16 / 9);
  }

  Future<void> _addAmbient(ThermionViewer viewer, FilamentApp app, LinearColor color, double intensity) async {
    try {
      // 9 hệ số × RGB; chỉ bậc 0. Float32List thường (không makeFloat32List) — xem webSafeGeometry.
      final sh = Float32List(27);
      sh[0] = color.r;
      sh[1] = color.g;
      sh[2] = color.b;
      final ibl = await FFIIndirectLight.fromIrradianceHarmonics(app as FFIFilamentApp, sh, intensity: intensity);
      final scene = await viewer.view.getScene();
      await scene.setIndirectLight(ibl);
    } catch (e) {
      // Không có IBL thì vẫn còn đèn phụ; chỉ ghi log.
      debugPrint('Thermion probe: ambient IBL failed: $e');
    }
  }

  Future<void> _addBox(
    ThermionViewer viewer,
    FilamentApp app, {
    required String label,
    required Geometry geometry,
    required Color color,
    required Matrix4 transform,
    bool castShadows = true,
    double roughness = 0.7,
    bool doubleSided = false,
  }) async {
    final mat = await app.createUbershaderMaterial(doubleSided: doubleSided);
    final rgb = linearRgb(color);
    await mat.setBaseColorFactor(rgb[0], rgb[1], rgb[2], 1);
    await mat.setMetallicFactor(0);
    await mat.setRoughnessFactor(roughness);
    // Web: KHÔNG truyền materialInstances vào createGeometry (danh sách con trỏ cấp phát trên stack WASM bị ghi đè
    // qua các await → material không được gán); gán sau khi tạo.
    final asset = await viewer.createGeometry(webSafeGeometry(geometry));
    await asset.setMaterialInstanceAt(mat.materialInstance);
    await app.setTransform(asset.entity, transform);
    await asset.setCastShadows(castShadows);
    await asset.setReceiveShadows(true);
    final v = geometry.vertices;
    final box = Aabb3();
    for (var i = 0; i < v.length; i += 3) {
      box.hullPoint(Vector3(v[i], v[i + 1], v[i + 2]));
    }
    _pickables.add((label, box..transform(transform)));
  }

  // Chọn vật bằng raycast phía Dart: tia từ camera (vị trí, hướng, FOV đã biết) qua điểm chạm, cắt các AABB.
  // KHÔNG dùng View.pick: trên web (thermion 0.5.0) nó làm treo luồng chính — xem docs/v3/thermion-api-notes.md.
  void _onTap(TapUpDetails d) {
    final size = context.size;
    if (_viewer == null || size == null || size.isEmpty) return;
    final ray = cameraRay(
      eye: _cameraPos,
      focus: _cameraFocus,
      fovDeg: _fovDeg,
      viewport: size,
      point: d.localPosition,
    );
    String hit = '-';
    var best = double.infinity;
    for (final (label, box) in _pickables) {
      final t = ray.intersectsWithAabb3(box);
      if (t != null && t >= 0 && t < best) {
        best = t;
        hit = label;
      }
    }
    setState(() => _picked = hit);
  }

  @override
  void dispose() {
    _disposed = true;
    _fpsTimer?.cancel();
    final viewer = _viewer;
    _viewer = null;
    if (viewer != null) {
      unawaited(() async {
        await viewer.app.unregisterRequestFrameHook(_frameHook);
        // Giải phóng texture/swapchain trước rồi mới huỷ viewer (giống ViewerWidget).
        await ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
        await viewer.dispose();
        await ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          if (viewer != null) Positioned.fill(child: ThermionWidget(viewer: viewer)),
          // Lớp nhận chạm nằm TRÊN cảnh: trên web cảnh là HtmlElementView (canvas DOM), bọc GestureDetector bên ngoài
          // thì sự kiện vào canvas chứ không vào Flutter.
          if (viewer != null)
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTapUp: _onTap),
            ),
          Positioned(
            left: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  _error != null ? 'ERR $_error' : (viewer == null ? '...' : '$_fps fps  |  $_picked'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
