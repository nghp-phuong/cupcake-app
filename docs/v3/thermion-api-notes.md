# Thermion 0.5.0 — ghi chú API cho người dựng cảnh 3D (V3)

Ngày 02/11/2026. Gói: `thermion_flutter 0.5.0` + `thermion_dart 0.5.0` (Filament v1.69.1), Flutter 3.47.9.
Mã mẫu đã chạy thật: `lib/main_3d_probe.dart` (web: đã chụp màn hình trong Chrome; Android: build APK được, chưa
chạy trên máy thật). Nguồn gói để tra thêm: `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\thermion_dart-0.5.0\lib\src`
(giao diện ở `filament/src/interface/`, test mẫu ở `test/helpers.dart`, `test/*_tests.dart`).

## 1. Nền tảng và build

| Nền tảng | Tình trạng |
|---|---|
| Android | Build: `flutter build apk --debug -t lib/main_3d_probe.dart` (đã chạy được; APK có `libthermion_dart.so` cho armeabi-v7a, arm64-v8a, x86_64 — bản Filament dựng sẵn có đủ 3 ABI dù README của gói chỉ cam kết arm64; mới chạy thử được trên máy thật thì mới chắc). APK debug ~190 MB (3 ABI + lớp kiểm tra Vulkan); bản phát hành nên `--target-platform android-arm64` hoặc `--split-per-abi`. Lần build đầu ~18 phút. minSdk của gói = 22, dự án để `flutter.minSdkVersion` (24). Hook native assets biên dịch C++ của Thermion bằng NDK (`28.2.13676358`, Gradle tự cài nếu thiếu) + tải thư viện Filament dựng sẵn (lần đầu vài phút, cache ở `.dart_tool/thermion_dart/`). |
| Web | Chạy được. Hook tự tải `thermion_dart.js` + `thermion_dart.wasm` và **chép vào `web/`** (đã có `web/.gitignore`). Bắt buộc **cross-origin isolation** (COOP `same-origin` + COEP `require-corp`) vì bản WASM đa luồng cần `SharedArrayBuffer`. |
| Windows host (`flutter test`) | Hook biên dịch Thermion cho Windows bằng **MSVC** → máy không có Visual Studio C++ thì `flutter test` hỏng ngay ở bước "Building native assets" — xem mục 9. |

Native assets: Flutter 3.47 stable **bật sẵn** (`enable-native-assets: (Not set)` = mặc định bật). Không cần
`flutter config --enable-native-assets` như README của gói ghi.

Web khi phát triển: `flutter run -d chrome --cross-origin-isolation -t lib/main_3d_probe.dart`.
Web sau khi build (`build/web`): máy chủ tĩnh phải gửi kèm 2 header trên (Firebase Hosting / Netlify: khai báo
`headers`; `python -m http.server` KHÔNG gửi được). Thiếu header → `crossOriginIsolated == false` → không có hình.

## 2. Tạo viewer và đưa lên cây widget

Dùng API mức thấp (tự kiểm soát toàn bộ), không dùng `ViewerWidget` (nó tự gắn camera orbit, tự tải glTF/KTX).

```dart
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture, View; // tránh trùng widget Texture/View của Flutter

final viewer = await ThermionFlutterPlugin.createViewer();   // ThermionViewer (engine + scene + view + camera)
// ... dựng cảnh ...
ThermionWidget(viewer: viewer)                               // đặt trong Positioned.fill / SizedBox.expand
```

- `viewer.app` là `FilamentApp` của viewer này (web: mỗi viewer một engine — dùng `viewer.app`, đừng dùng
  `FilamentApp.instance`).
- Viewer render mỗi vsync từ khi tạo (`RenderManager.setRenderable` mặc định true). `viewer.setRendering(false)` để
  dừng; `FilamentApp.setTargetFramerate(30)` để giới hạn FPS (chung cho mọi viewer).
- Huỷ (thứ tự như `ViewerWidget`):
  ```dart
  await ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
  await viewer.dispose();
  await ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
  ```
- Web: canvas được nhúng bằng `HtmlElementView` → xem cạm bẫy chạm ở mục 7.

## 3. Hình học

Có sẵn (`Geometry`, mọi kích thước tính bằng đơn vị thế giới, y hướng lên):

| Hàm | Hình |
|---|---|
| `CubeGeometry.cube()` | hộp **cạnh 2** (−1..1) → scale = nửa kích thước mong muốn |
| `GeometryUtils.plane(width:, height:)` | mặt phẳng XZ, pháp tuyến +Y, tâm gốc toạ độ |
| `SphereGeometry.sphere(latitudeBands:, longitudeBands:)` | cầu bán kính 1 |
| `CylinderGeometry.cylinder(radius:, length:)`, `ConeGeometry.conic(...)`, `CapsuleGeometry.capsule(...)`, `PyramidGeometry.halfPyramid(...)`, `QuadGeometry.quad()` | |

Hình tuỳ biến: `Geometry(Float32List vertices, List<int> indices, normals:, uvs:, uvs1:, colors:, indexType:)`
(vertices/normals 3 số/đỉnh, uvs 2, colors RGBA 4; có normals thì Thermion tự sinh tangent).

```dart
final asset = await viewer.createGeometry(webSafeGeometry(geom));   // tự thêm vào scene
await asset.setMaterialInstanceAt(mat.materialInstance);             // gán material SAU khi tạo (mục 9)
await viewer.app.setTransform(asset.entity, Matrix4.compose(pos, Quaternion.identity(), scale));
await asset.setCastShadows(true);
await asset.setReceiveShadows(true);
```

Gỡ: `viewer.destroyAsset(asset)`; ẩn tạm: `viewer.removeFromScene(asset)` / `viewer.addToScene(asset)`.
glTF (sau này có model thật): `viewer.loadGltf('asset://assets/x.glb')`, nhiều bản: `initialInstances:` /
`asset.createInstance()`.

## 4. Material và màu

```dart
final mat = await viewer.app.createUbershaderMaterial(doubleSided: false, unlit: false);  // UbershaderMaterialInstance
await mat.setBaseColorFactor(r, g, b, 1);    // màu TUYẾN TÍNH: sRGB^2.2 (xem linearRgb() trong probe)
await mat.setMetallicFactor(0);
await mat.setRoughnessFactor(0.7);           // gốm/bột: 0.6–0.9, kính tủ: thấp + alphaMode
```

- `unlit: true` → không chịu ánh sáng (hợp cho billboard nhân vật, chữ, UI 3D).
- Trong suốt: `alphaMode: AlphaMode.BLEND` (hoặc `MASK` cho ảnh PNG có viền cứng như billboard).
- Texture (ảnh nhân vật billboard): `createUbershaderMaterial(hasBaseColorTexture: true, unlit: true,
  alphaMode: AlphaMode.MASK)` rồi `mat.setBaseColorTexture(texture, sampler)`; ảnh nạp bằng
  `app.decodeImage(bytes)` + `app.createTexture(...)` + `app.createTextureSampler()` (xem `test/texture_tests.dart`).
  Chưa thử trong probe.
- Mặt phẳng nhìn từ dưới bị cull → sàn/tường mỏng dùng `doubleSided: true`.

## 5. Ánh sáng, bóng

```dart
await viewer.addDirectLight(DirectLight.sun(
  intensity: 90000, castShadows: true,
  direction: Vector3(-0.6, -1.0, -0.4).normalized(), color: const LinearColor(1.0, 0.95, 0.88)));
await viewer.addDirectLight(DirectLight(type: LightType.DIRECTIONAL, intensity: 25000, castShadows: false,
  direction: Vector3(0.7, -0.4, 0.6).normalized(), position: Vector3.zero()));            // đèn phụ
await viewer.setShadowsEnabled(true);
await viewer.setShadowType(ShadowType.PCF);   // PCF rẻ nhất; VSM/DPCF/PCSS mềm hơn, đắt hơn
// viewer.view.setSoftShadowOptions(SoftShadowOptions(penumbraScale: .., penumbraRatioScale: ..))
```

Còn có `DirectLight.point(position:, falloffRadius:)`, `DirectLight.spot(...)`; đổi sau khi tạo:
`viewer.setLightDirection(entity, dir)`, `viewer.setLightPosition(entity, x, y, z)`, `viewer.removeLight(entity)`.
Độ sáng hợp với phơi sáng mặc định của camera (f/16, 1/125 s, ISO 100 ≈ nắng trưa); đổi bằng
`camera.setExposure(aperture, shutter, iso)`.

**Ánh sáng môi trường (IBL) không cần file KTX** — dựng từ hệ số cầu điều hoà (SH) bậc 0 = màu đều mọi hướng:

```dart
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';

final sh = Float32List(27)..[0] = 1.0..[1] = 0.93..[2] = 0.85;   // KHÔNG dùng makeFloat32List (mục 9)
final ibl = await FFIIndirectLight.fromIrradianceHarmonics(viewer.app as FFIFilamentApp, sh, intensity: 22000);
await (await viewer.view.getScene()).setIndirectLight(ibl);
```

Có file KTX (sinh bằng `cmgen` của Filament) thì dùng `viewer.loadIbl('asset://assets/x_ibl.ktx', intensity:)`
và `viewer.loadSkybox(...)`. Nền đơn sắc: `viewer.setBackgroundColor(r, g, b, 1)` (tuyến tính).

## 6. Camera

```dart
final camera = await viewer.getActiveCamera();
await camera.lookAt(Vector3(7, 5.5, 9), focus: Vector3(0, 0.6, 0), up: Vector3(0, 1, 0));
await camera.setLensProjection(near: 0.1, far: 100, focalLength: 12 / tan(fovDeg * pi / 360), aspect: 16 / 9);
```

- **Cạm bẫy:** mỗi lần đổi kích thước, `ThermionWidget` gọi lại `setLensProjection(focalLength: hiện tại, aspect:
  mới)`. Vì vậy đặt góc nhìn bằng **tiêu cự** (cảm biến 24 mm chiều cao: `f = 12 / tan(fovDọc/2)`); nếu dùng
  `setProjectionFromVerticalFieldOfView` thì sau lần resize vẫn giữ được góc nhờ tiêu cự suy ra, nhưng aspect bị đặt
  lại — đừng tự đặt aspect sau khi widget đã có kích thước.
- Orbit 360° của dự án: tự tính `eye` (xem `lib/game/shop3d/orbit_camera.dart`) rồi gọi `camera.lookAt(eye, focus:)`
  mỗi khung có thay đổi. Gói có sẵn `DelegateInputHandler.fixedOrbit(viewer, ...)` + `ThermionListenerWidget` nhưng
  không có giới hạn góc nghiêng/khoảng cách theo phòng như ta cần.
- Đọc lại: `camera.getModelMatrix()`, `getViewMatrix()`, `getProjectionMatrix()`, `getPosition()`.
- Mỗi lệnh camera là một tác vụ xếp hàng sang luồng render (bất đồng bộ): gom thay đổi, gọi tối đa 1 lần/khung.

## 7. Chạm → chọn vật (picking)

- **`View.pick(x, y, cb)` làm TREO luồng chính trên web** (đã thử: sau `pick`, trang không còn phản hồi). Trên
  Android API tồn tại (x, y là pixel vật lý = logical × devicePixelRatio, gốc trên-trái) nhưng chưa thử trên máy.
- Cách dùng trong probe (mọi nền tảng): **raycast phía Dart** — camera ta tự đặt nên biết `eye`, `focus`, FOV; mỗi vật
  lưu `Aabb3` thế giới lúc tạo (`Aabb3()..hullPoint(...)` rồi `..transform(matrix)`); tia qua điểm chạm
  (`cameraRay(...)` trong probe) → `ray.intersectsWithAabb3(box)` → lấy vật gần nhất. Không gọi native, không chờ.
- **Web: lớp nhận chạm phải nằm TRÊN cảnh** (`Stack[ThermionWidget, Positioned.fill(GestureDetector(behavior:
  HitTestBehavior.opaque))]`). Bọc `GestureDetector` ngoài `ThermionWidget` thì trên web sự kiện vào canvas DOM,
  Flutter không nhận được.
- Chiếu ngược 3D → màn hình (đặt bóng thoại trên đầu khách): tự nhân `projection * view * vec4(p, 1)` (lấy ma trận
  một lần khi camera đổi, hoặc tự dựng từ eye/focus/FOV như `cameraRay`), hoặc `viewer.getViewportBoundingBox(entity)`.

## 8. Đo FPS, chụp ảnh

```dart
Future<void> _frameHook() async => _frames++;             // phương thức (tear-off so sánh == được)
await viewer.app.registerRequestFrameHook(_frameHook);    // chạy trước MỖI khung Filament (native + web)
// Timer 1 s: fps = _frames; _frames = 0;   khi huỷ: viewer.app.unregisterRequestFrameHook(_frameHook)
```

Đây là FPS của vòng render Filament (không phải khung Flutter). Chrome headless (SwiftShader, CPU) chỉ ~10 fps —
không có ý nghĩa; phải đo trên máy thật. Chụp ảnh khung: `viewer.app.capture([...])` (xem `test/capture_tests.dart`).

## 9. Cạm bẫy đã gặp (quan trọng)

1. **Web — bộ nhớ tạm trên stack WASM.** `makeFloat32List` / `makeUint16List` / `makeIntPtrList` của thermion
   trên web cấp phát bằng `stackAlloc`; vùng này bị ghi đè qua các `await`. Hậu quả đã thấy:
   - `Geometry(...)` tự tạo màu đỉnh / UV giả bằng `makeFloat32List` → **vệt cầu vồng** trên khối.
   - `createGeometry(geom, materialInstances: [...])` truyền danh sách con trỏ material qua `makeIntPtrList` →
     **material không được gán** (khối hiện màu rác, `baseColorFactor` vô tác dụng).

   Cách lách (đã kiểm chứng): luôn truyền `colors`, `uvs`, `uvs1` là `Float32List` thường (xem
   `webSafeGeometry()` trong probe), gọi `createGeometry(geom)` **không** truyền material rồi
   `asset.setMaterialInstanceAt(mi)`; mọi mảng tự tạo để gửi xuống native dùng `Float32List(n)` thường.
2. **Web — `View.pick` treo** (mục 7).
3. **Web — header COOP/COEP** bắt buộc (mục 1).
4. **`flutter test` cần MSVC** trên Windows: hook của `thermion_dart` biên dịch C++ cho host. `skip_native_build`
   (user-define của gói) không cứu được vì hook của `thermion_flutter` lại đòi metadata từ `thermion_dart` và văng
   lỗi. Cách duy nhất: cài *Visual Studio 2022 Build Tools* + workload "Desktop development with C++" (cần chủ dự
   án đồng ý), hoặc chạy test trên CI Linux/macOS. Cách tạm để chạy test logic khi chưa có MSVC: bỏ tạm 2 dòng
   `thermion_*` trong pubspec, `flutter pub get --offline`, `flutter test`, rồi khôi phục pubspec + pubspec.lock
   (không test nào hiện nay import thermion). Test không được import `thermion_*` / `main_3d_probe.dart`.
5. Tên trùng: `thermion_flutter` xuất lại `Texture`, `View` (trùng widget Flutter) → `hide Texture, View`.
   `vector_math_64` được xuất lại (trừ `Colors`), dùng `Vector3`, `Matrix4`, `Quaternion`, `Aabb3`, `Ray` từ đó.
6. Mọi lệnh tới Filament đều `async` và xếp hàng sang luồng render; đừng gọi hàng trăm lệnh mỗi khung — gom và
   chỉ gửi khi có thay đổi (vị trí khách, camera).
7. Android: Flutter 3.47 cảnh báo AGP < 9.0.1, Gradle < 9.1, Kotlin < 2.3.20 "sắp ngừng hỗ trợ" (chỉ cảnh báo). Lên AGP 9 cần thử lại plugin cũ của thermion (`apply plugin: 'kotlin-android'`); `gradle.properties` đã có `android.builtInKotlin=false`, `android.newDsl=false` (Flutter tự thêm). `kotlin.incremental=false` tránh lỗi cache Kotlin "different roots" (pub cache ổ C, dự án ổ D).
9. Material có texture: **luôn truyền `baseColorUV: 0`** cho `createUbershaderMaterial(hasBaseColorTexture: true)`
   (mặc định -1 → 255 phía C++ → gltfio đọc ngoài biên → WASM abort).
10. Lưới `createGeometry` mặc định không nhận bóng → gọi `setReceiveShadows(true)`.
11. `Texture.setImage` chép dữ liệu muộn trên luồng render → nạp qua bộ đệm `malloc` và `free` sau khi lệnh xong
    (xem `lib/game/shop3d/shop3d_scene.dart`).
12. Web: worker xử lý hết hàng đợi rồi mới vẽ một khung → tạo vật song song bằng `Future.wait`, không `await` nối tiếp
    (Chrome headless: >3 phút → ~40 giây).
13. `CylinderGeometry` tô sai nắp trụ → dùng lưới tự dựng ở `lib/game/shop3d/shop3d_mesh.dart`.
14. Android: `ndkVersion` của gói = `28.2.13676358`; `compileSdkVersion 33`, AGP 7.3 khai trong `build.gradle` của gói
   bị AGP của app ghi đè — chạy được với AGP 8.11.1 / Gradle 8.14.3 / Kotlin 2.2.20.
15. **Màu đỉnh có hiệu lực** với ubershader: `createUbershaderMaterial(hasVertexColors: true)` + `baseColorFactor`
    (1,1,1,1) → màu = màu đỉnh (RGBA **tuyến tính**, sRGB^2,2) truyền qua `Geometry(colors: Float32List)` thường. Nhờ
    vậy một bộ phận nhiều màu (đầu + mắt + má + tóc…) là MỘT entity, mọi nhân vật chibi dùng chung MỘT material
    (`lib/game/shop3d/chibi/`, đã chạy trên web).
16. Cập nhật transform mỗi khung: `(viewer.app as FFIFilamentApp).transformManager.setTransform(entity, m)` chạy
    **đồng bộ** trên luồng gọi (không xếp hàng sang luồng render, không tạo `Future` như `viewer.app.setTransform`) và
    đọc ma trận ngay → tái dùng một `Matrix4`. Đo trên web (Chrome desktop, GPU): 4 chibi × 7–8 bộ phận = 31 lệnh +
    tính khung xương ở Dart ≈ 0,3 ms/khung, vẫn 60 fps. Không dùng `setParent` (lệnh bất đồng bộ sang luồng render; khớp
    nào cũng động nên số lệnh mỗi khung không giảm).
17. Chụp màn hình web có GPU thật: Chrome `--headless=new --use-angle=d3d11 --enable-gpu --ignore-gpu-blocklist` →
    60 fps (SwiftShader mặc định chỉ ~2 fps, không thấy được chuyển động).
18. `dart run <script>` trong dự án cũng chạy hook native (hỏng như `flutter test`, mục 4). Script Dart thuần để thử
    nhanh (đếm tam giác, xuất lưới) đặt NGOÀI dự án và import file theo URI `file:///D:/.../lib/...dart`.
19. **UV toàn số 0 làm hỏng pháp tuyến** của lưới tự dựng: `createGeometry` tính quaternion tangent (chứa cả pháp
    tuyến, Filament dùng nó để tô) bằng `SurfaceOrientation` **theo UV nếu mảng UV khác rỗng**; UV toàn 0 suy biến ở
    một số tam giác (thấy rõ ở tấm to phẳng, ví dụ túi áo chibi) → tô đen. Lưới không dùng texture: truyền
    `uvs: Float32List(0), uvs1: Float32List(0)` (rỗng, KHÔNG để null — null thì Geometry tự tạo bằng
    `makeFloat32List`, mục 1) → tangent tính từ pháp tuyến, hết vệt đen (đã kiểm trên web). Lưới có texture thì cần UV
    thật, không suy biến.
20. **Dàn nhân vật lớn vẫn 60 fps** (Chrome desktop, GPU, 03/11): cảnh mặc định 8 chibi = 181 entity, 26k tam giác,
    65 lệnh `setTransform` đồng bộ mỗi khung + máy trạng thái Dart ≈ 0,5–0,85 ms/khung; màn xếp hàng 15 chibi = 237
    entity, 44,7k tam giác, 121 lệnh ≈ 0,56–0,73 ms — vẫn 60 fps. Máy yếu: `chibiHz=30` chia đôi chi phí này. Số liệu
    hiện ở lớp debug (`chibi <n> xf <ms>`); ảnh `docs/v3/screens/chibi2/`.
21. **Đồ cầm tay đi theo tay mà không dùng cha-con của Filament**: bộ phận `ChibiPart.prop` tính ma trận ở Dart = ma
    trận tay × dời tới tâm bàn tay; đồ cần nằm ngang (khay) thì thay phần xoay 3×3 bằng phần xoay của gốc (chỉ yaw) —
    vẫn một lệnh `setTransform` đồng bộ, không `setParent` (bất đồng bộ, mục 16). Thú bốn chân dùng cùng cách: chân
    trước gắn thân rồi bù góc ngả thân (`Rx(−lean)`) để luôn dựng đứng khi mèo ngồi.
22. **Chạy test tạm (mục 4) khi có người khác cùng làm**: trước khi bỏ tạm 2 dòng `thermion_*`, so md5
    `pubspec.yaml` / `pubspec.lock` với bản gốc (đang bị bỏ tạm thì chờ, đừng ghi đè lẫn nhau); khôi phục bằng bản
    chép giữ riêng rồi so md5 lại. Lưu ý mọi lệnh `flutter` (cả `analyze`) tự chạy `pub get` khi `pubspec.yaml` mới hơn
    `.dart_tool/package_config.json` — đừng chạy lệnh `flutter` nào trong lúc người khác đang ở trạng thái bỏ tạm.
    Bản `build/web` cũng dùng chung: chép sang thư mục riêng rồi mới phục vụ / chụp (cổng riêng, ví dụ 8791).
23. **Android máy yếu (Samsung A12, PowerVR GE8320, 03/11): cảnh "đứng" sau 10–50 s nhưng chip vẫn báo 60 fps.**
    - *Chip đo sai:* request-frame hook (mục 8) chạy trước MỖI lần `RenderManager::render`, còn trong đó
      `Renderer::beginFrame` trả false (Filament bỏ khung vì GPU / bên nhận ảnh chưa xong khung trước) thì không vẽ
      gì — vòng Dart vẫn "xong" 60 lần/s. Cách đo đúng (native): `Shop3dFrameDriver`
      (`lib/game/shop3d/shop3d_frame_driver.dart`) gỡ view khỏi vòng của thermion (`viewer.setRendering(false)`,
      swapchain vẫn gắn) rồi trong request-frame hook tự gọi `Renderer_beginFrameRenderThread` (trả bool) →
      `Renderer_renderRenderThread` → `Renderer_endFrameRenderThread`, đếm khung nhận / bỏ. Chip hiện
      `<khung Filament> fps (skip <bỏ>) · ui <khung Flutter đã raster>` (FrameTiming). Web không dùng được (worker
      đơn luồng, không chờ được từ luồng chính) → vẫn đếm hook.
    - *Nút thắt thật là Flutter, không phải Filament:* `top -H` lúc đứng hình: luồng `1.raster` (Impeller OpenGLES)
      ~100% CPU, các luồng `FEngine::loop` gần như rảnh; `dumpsys SurfaceFlinger --latency` cho SurfaceView của
      Flutter: ~550 ms/khung (≈2 khung/s). Bên nhận SurfaceTexture (Impeller GLES, log `IMGSRV: IsTextureConsistent:
      IMGEGLImage is not consistent` trên luồng raster) lấy ảnh quá chậm → `eglSwapBuffers` của Filament phải chờ bộ
      đệm → mỗi ~0,5 s mới qua một khung (`FrameEvents: updateAcquireFence`, `eglGetFrameTimestampsANDROID
      EGL_BAD_ACCESS` lặp theo nhịp đó — chỉ là triệu chứng: Filament hỏi mốc thời gian khung trên surface không phải
      màn hình), sau đó đứng hẳn. Mở bằng `am start ... --ez enable-impeller false` (Skia): luồng raster hết chiếm
      CPU (chưa kịp đo đủ 3 phút — máy mất kết nối adb).
    - *Thử tiếp (không cần build lại):* tham số qua route ban đầu, ví dụ
      `adb shell am start -n com.sugarleafbakery.sugarleaf_bakery/.MainActivity --es route '/?tex=producer'`
      (`tex=producer` = SurfaceProducer/ImageReader thay SurfaceTexture; `scale=0.75` = ảnh 3D ít điểm ảnh hơn;
      `fps=30`). Nếu chỉ Skia chạy được thì phải tắt Impeller trong `AndroidManifest.xml`
      (`io.flutter.embedding.android.EnableImpeller` = false; Flutter 3.47 báo "opt-out deprecated" nhưng vẫn chạy).
24. **Mức chất lượng đồ họa (`lib/game/shop3d/shop3d_quality.dart`).** Số đo trên Samsung A12 (PowerVR GE8320, chip
    `Shop3dFrameDriver`, cảnh mặc định, 03/11): mặc định (DPCF, scale 1, đủ hậu kỳ) 2 fps (skip 58); tắt Impeller
    (Skia) vẫn 2 → không phải do Impeller; `tex=producer` 2; scale 0,5: 4; scale 0,5 + ibl=0: 5; **scale 0,5 + soft=0
    (PCF): 20**; scale 0,5 + soft/ibl/tm=0: 19; scale 0,75 lite: 11; scale 1 lite: 7; không nhân vật + lite + 0,5: 24
    (5,9k tam giác). Kết luận: nghẽn GPU (fill-rate + bóng DPCF), không phải CPU / Dart.
    - `quality=auto|low|high` (+ ghi đè `scale`, `fps`, `shadows`, `smap`, `post`, `aa`, `blob`, `soft`, `ibl`, `tm`).
      `auto`: bắt đầu `high`, native bỏ 2 s sau khi nhân vật dựng xong rồi đếm khung Filament 3 s; < 45 fps → `low`
      (đổi lúc chạy: `Shop3dScene.applyGraphics` + `setTargetFramerate` + cấp lại texture theo scale). Web: từ 04/11
      cũng đo (số vòng rAF — mục 27).
    - `low` hiện tại (CHƯA đo trên máy): không bóng động (`setShadowsEnabled(false)` + tắt shadow caster của nắng),
      bóng tròn mờ dưới chân chibi (đĩa unlit trong suốt, theo vị trí mỗi khung), không FXAA, scale 0,6, giới hạn 30
      fps; giữ hậu kỳ + PBR Neutral + IBL. `high` = như cũ (DPCF 1024, FXAA, scale 1, không giới hạn).
25. **Tương tác V3 — tên trùng và kiểu nội bộ (03/11).**
    - `thermion_flutter` xuất lại `KeyEvent` (`thermion_dart/src/input/src/input_types.dart`) → trùng `KeyEvent` của
      Flutter (phím tắt web) → `import 'package:thermion_flutter/thermion_flutter.dart' hide KeyEvent, Material,
      Texture, View;`.
    - Kiểu của `(viewer.app as FFIFilamentApp).transformManager` là `FFITransformManager` (không xuất công khai) — muốn
      truyền làm tham số thì `// ignore: implementation_imports` +
      `import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';`.
    - Entity dựng sẵn để dùng sau (cặp khách sự kiện): `createGeometry` tự thêm vào scene → ngay sau khi tạo, đặt
      transform ra xa (`y = −50`, `setTransform` đồng bộ) rồi `removeFromScene`; khi cần thì đặt transform đúng chỗ
      TRƯỚC rồi mới `addToScene` (không loé ở gốc toạ độ / chỗ cũ). Không huỷ entity khi gỡ — giữ lại cho lần sau.
    - Vật tương tác (len, hộp bánh, bao bột): mỗi vật một entity, lưới màu đỉnh dùng chung material chibi, cập nhật
      bằng `setTransform` đồng bộ cùng lượt với chibi; ẩn / hiện (tặng hộp bánh) bằng add/removeFromScene khi đổi.
26. **Chạy test Dart thuần mà không sửa pubspec của dự án** (thay cho cách tạm ở mục 4 / 22): tạo gói tạm NGOÀI dự án
    (thư mục scratch) tên `sugarleaf_bakery`, chép `lib/` + `test/game/shop3d`, pubspec chỉ có `flutter`,
    `flutter_localizations`, `intl`, `flutter_test` (không thermion), `flutter pub get --offline`, `flutter test
    test/game/shop3d`. Không đụng `pubspec.yaml` / `.dart_tool` của dự án nên không chặn người khác. Test cần file trong
    `assets/` (`shop3d_actors_test`: ảnh nhân vật) thì chép thêm `assets/` hoặc bỏ qua test đó.
27. **Hiệu năng cảnh tiệm (04/11): nút thắt trên web là khung Flutter, không phải Filament.** Chủ dự án thấy lag
    (~30 fps, chip cũ `215 ent · 26 mat · 45.6k tri · chibi 80 xf 2.63 ms`).
    - *Cách đo* (không cần máy thật): bản `build/web` chép sang thư mục riêng, máy chủ COOP/COEP, Chrome headless có GPU
      (`--headless=new --use-angle=d3d11 --enable-gpu --ignore-gpu-blocklist`, 1280×720) điều khiển qua CDP: đếm rAF
      6 s + `Performance.getMetrics` (TaskDuration / ScriptDuration = ms luồng chính mỗi giây); CPU profile bằng
      `Profiler.start/stop` trên bản `flutter build web --profile -t lib/main_shop3d.dart -o <thư mục riêng>` (giữ tên
      hàm; nhớ chép `web/thermion_dart.js|wasm` vào). Bản profile có thêm `performance.mark/measure` (~60 ms/s) — chỉ so
      tương đối. Máy test nhanh hơn máy chủ dự án ~2,7 lần (chibi 0,96 ms so với 2,63 ms) nên rAF vẫn 60 ở mọi kịch bản;
      so bằng ms luồng chính.
    - *Trước* (ms luồng chính / giây): `?pilot=mai&event=lastCake` 690–720 (≈ 11,5 ms/khung → máy chủ dự án ≈ 30 ms →
      ~30 fps); `?play=0` 425–436; `?actors=0` 135. Profile (`pilot+event`): `drawFrame` của Flutter 421 (paint 189,
      composite CanvasKit 135, layout 82, build 48), `_onTick` 86 (chibi 64, trong đó `setTransform` 27), vòng render
      thermion 52. Khung Flutter ("ui") ~60/s kể cả khi không có gì trên lớp phủ đổi.
    - *Nguyên nhân, theo mức ảnh hưởng:* (1) Ticker chạy liên tục vì chibi luôn động → mỗi vsync một khung Flutter đầy
      đủ; trên web mỗi khung CanvasKit vẽ lại cả cây lớp + tách lớp quanh platform view (`createImageBitmap`) dù ảnh 3D
      (canvas DOM do worker vẽ) không cần khung Flutter nào. (2) Lớp phủ đổi mỗi khung (bong bóng / mũi tên / nhãn)
      không có `RepaintBoundary`, và `LayoutBuilder` gốc nhận ràng buộc lỏng từ thân Scaffold → mỗi lần dựng lại, cả
      Scaffold layout + vẽ lại (Material, InkWell của nút debug). (3) Lưới tĩnh 121 entity / 19 material (mỗi vật × mỗi
      màu một lưới) + ~10 material bóng tròn trùng (tạo song song, không nhớ Future). (4) Mỗi `setTransform` trên web
      ≈ 25 lời gọi JS↔WASM (struct `double4x4` cấp trên stack WASM, ghi từng số) — 80 bộ phận ≈ 0,45 ms/khung.
    - *Đã sửa:* vòng cập nhật (camera, chibi, tương tác, lớp phủ) chạy trong **request-frame hook** của Filament
      (`Shop3dView._frameHook`, đăng ký TRƯỚC hook vẽ của `Shop3dFrameDriver` để cập nhật rồi mới vẽ cùng khung; lỗi
      trong hook phải bắt — `FilamentApp.render` bọc cả vòng hook trong một try, lỗi lọt ra làm bỏ hook vẽ phía sau),
      bỏ Ticker → Flutter chỉ dựng khung khi lớp phủ thật sự đổi. Lớp phủ: mỗi lớp đổi theo khung một
      `RepaintBoundary` (`_layer`), gốc view `RepaintBoundary` + `SizedBox.expand` (ranh giới layout), `_OverlayFrame`
      không đổi (< 0,25 px) thì không báo. Lưới tĩnh theo nhóm `Shop3dBatches` (`shop3d_batches.dart`): mặt đục dùng
      **màu đỉnh** + một material chung theo độ nhám (mờ 0,85 / inox 0,45 / kính 0,15), mặt trong suốt giữ material một
      màu với màu đỉnh TRẮNG (ubershader vẫn nhân màu đỉnh của lưới kể cả material tạo với `hasVertexColors: false` —
      gửi màu thật thì cửa lò vàng bơ alpha 0,85 thành cam đậm, kính alpha 0,3 trong gấp đôi; chưa kiểm được alpha màu
      đỉnh nhân trước hay sau bước nhân trước alpha nên không gộp kính bằng màu đỉnh); vật chạm được mỗi vật một
      nhóm (nhún riêng), vật không chạm được (sàn, gạch, thảm, bục + đất / vỉa hè) gộp theo cờ mở rộng; lưới tĩnh dùng UV
      rỗng như chibi (mục 9.19). Chibi / bóng tròn / vật tương tác chỉ gửi `setTransform` khi ma trận đổi (thực tế nhịp
      thở làm gần như mọi bộ phận đổi mỗi khung: tiết kiệm ~2 %, giữ vì vô hại). Web: trần 2,1 MP cho ảnh 3D
      (`Shop3dGraphics.forWeb`, `?maxpx=`; màn 1080p giữ nguyên, màn 1440p / Retina hạ độ phân giải); `auto` đo cả trên
      web (khung = vòng rAF của thermion; bỏ qua lúc tab ẩn), màn > 90 Hz giới hạn nửa tần số quét.
    - *Sau:* `?play=0` 127–137 ms/s (−69 %), khung Flutter 1/s; `?actors=0` 89–94; tương tác khi rảnh (`?events=0`)
      136; `?pilot=mai&event=lastCake` 454–531 (−29 %; sự kiện có bong bóng bám đầu nhân vật + mũi tên nhấp nhô nên vẫn
      ~45 khung Flutter/s). Lưới tĩnh 121 → 36 entity (trong scene mặc định 101 → 29), material tĩnh 19 → 5; chip
      `pilot+event`: 215 → 130 entity (120 trong scene), 30 → 7 material, tam giác không đổi (tĩnh 5,9k, chibi ~40k).
      Dart mỗi khung (cả vòng cập nhật) 0,6–1,0 ms trên máy test. Test Dart thuần: `shop3d_batches_test` (in số trước /
      sau), `chibi_perf_test` (9 nhân vật, 73 bộ phận, ~75 µs/khung trên VM; 71,6 / 73 bộ phận cần gửi mỗi khung).
    - *Còn lại (ngoài khu vực shop3d, `lib/ui/shop3d`):* `_PuffPainter` dựng `Path.combine` nhiều vòng tròn mỗi lần vẽ
      (~30 ms/s trong sự kiện vì `Shop3dPopIn` co giãn BÊN TRONG `RepaintBoundary` của bong bóng → vẽ lại 11 lần mỗi
      lần bật) → nên nhớ đường viền theo cỡ, hoặc đặt `Transform.scale` ngoài `RepaintBoundary`; bong bóng dựng lại cả
      nội dung khi chỉ đổi vị trí (`Shop3dHeadBubble(anchor:)`) → tách vị trí ra (`Positioned` / `CustomSingleChildLayout`
      bên ngoài, nội dung `const` theo khoá); mũi tên đích nhấp nhô giữ khung Flutter 60/s khi hiện.
    - *Ngân sách cho đồ trang trí* (hiện: 29 entity tĩnh trong scene + ~90 chibi / bóng / vật; ~46k tam giác):
      đồ **không chạm được** (`Shop3dProp(pickable: false)` hoặc khối thêm vào danh sách tường `Shop3dLayout.walls`)
      → 0 entity thêm (vào lưới nền / lưới tường có sẵn; chỉ +1 nếu là độ nhám mới), chỉ tốn tam giác; đồ **chạm được**
      → +1 entity (+1 nếu có inox, +1 mỗi màu trong suốt). Đồ cùng cờ mở rộng mới (`requires`) → +1 nhóm nền cho cờ đó.
      Đề xuất (ước lượng, CHƯA đo trên máy yếu): giữ ≤ ~60 entity tĩnh trong scene và ≤ ~25k tam giác tĩnh (≈ +20k so
      với hiện nay; trụ / cầu nhỏ đã tự giảm cạnh). GPU yếu nghẽn fill-rate hơn là số tam giác (A12: không nhân vật,
      lite, scale 0,5 = 24 fps — mục 24), nên đồ trang trí nên nhỏ, đục, không trong suốt chồng lớp. Kiểm bằng
      `Shop3dBatchStats` (test) và chip (`<trong scene>/<đã tạo> ent (static n)`).
28. **Bài trí "tiệm bánh bên biển của bà" (04/11, đợt P1 + P2 của `docs/design/art-preview/v3/decor-proposal.md` ở
    bản v2).** Toàn bộ là khối màu đỉnh trong lưới tĩnh có sẵn (`shop3d_layout.dart`), không texture, không UV.
    - *Hình mới* (`Shop3dShape`, `Shop3dMeshBuilder`): `Shop3dPart.cone` (nón cụt: chao đèn, cốc cupcake — trụ có
      `topScale` / `bottomScale`, pháp tuyến thân nghiêng theo độ dốc, bán kính 0 thì bỏ nắp), `Shop3dPart.prism` (lăng trụ
      hình thang đùn theo z cục bộ: cờ đuôi nheo = đáy 0, mái hiên mini = đỉnh 0 xoay π/2, nửa chìm trong tường),
      `Shop3dPart.scallop` (diềm sóng nửa elip). `sx` luôn là cạnh lớn nhất nên hộp bao (chạm, lối đi, test chồng lấn)
      giữ đúng. Cầu < 6 cm còn 36 tam giác.
    - *Tranh biển sau cửa sổ* nằm trong bề dày tường trước (z 4,235, chỉ thấy qua ô kính) và dùng bề mặt mới
      `Shop3dSurface.backdrop` = material màu đỉnh **unlit** (`createUbershaderMaterial(unlit: true, hasVertexColors:
      true)` chạy đúng trên web): mặt trong tường trước quay lưng về nắng nên tranh lit trông xám tối. Màu tranh riêng
      (`Shop3dColor.backdrop`) để chọn bề mặt theo màu như kính / inox. +1 material, +1 entity (nhóm tường trước).
    - *Lớp dán không nhấp nháy*: sọc dán trên tấm ốp cách 6 mm, ô bạc hà trên nền gạch bếp 4 mm, ván sàn 6 mm, khối cùng
      độ cao (thảm, viền sàn 2 cm) không chồng nhau (thảm, thảm cửa lùi khỏi viền); mặt ô bếp 1,8 cm < bóng tròn 2,6 cm.
      Trong một lưới gộp, khối thêm trước được vẽ trước → ván / sọc / ô thêm trước nền của chúng (độ sâu loại phần nền
      bị che).
    - *Không che nhân vật*: tủ kính bỏ tấm nắp đặc (nắp kính + khung vàng mảnh, kệ trên bằng kính) — chạm vẫn chọn được
      vì `pickBoxesForProp` nay chỉ bỏ **tấm** kính mỏng (< 5 cm), khối kính (vách + nắp tủ) vẫn có hộp chạm. Đèn thả
      chao 0,3 m treo 2,07–2,33 m, không chạm được, gộp vào lưới nền `cafe_tables` (không nhún theo bàn); quầng sáng giả
      = 2 đĩa vàng bơ alpha 0,22 (cùng material với nhau, không chạm, `flat`). Cờ đuôi nheo ≥ 2,57 m.
    - *Mặt tiền ngoài trời không dựng*: tường trước luôn bị ẩn khi camera ở ngoài (`hiddenWallMask`, biên 0,25 m) nên mái
      hiên / biển hiệu ngoài cửa không bao giờ thấy, còn nếu tách khỏi nhóm tường thì che khách ở cửa → mái hiên sọc
      hồng-kem có diềm sóng làm thành **mái hiên mini phía trong trên 3 cửa sổ**, biển hiệu gỗ hình cupcake (không chữ)
      treo **phía trong trên cửa ra vào**; thấy khi nhìn về phía cửa sổ (yaw ≈ π).
    - *Số liệu* (`shop3d_batches_test`, chip web): entity tĩnh 36 → 37 (trong scene mặc định 29 → 30), material tĩnh 5 → 6
      (bỏ hũ tip trong suốt, thêm quầng sáng + tranh unlit), tam giác tĩnh 5,9k → 19,1k (ngân sách ≤ 60 entity, ≤ 25k tam
      giác — test `ngân sách bài trí`). Ánh sáng: nắng #FFF1DC, môi trường #FFE9D2, đèn phụ bạc hà nhạt #E8FFF6, nền
      #FFE8D6 (Thermion 0.5.0 không có skybox chuyển màu nếu không nạp KTX); ghi đè thử bằng `?sun= / amb= / fill= / sky=`.
29. **Bài trí đợt P3 (04/11, `shop3d_layout.dart`).** Vẫn toàn khối màu đỉnh trong lưới tĩnh; đồ gắn tường vào `walls[...]`
    (ẩn cùng tường), đồ ngoài trời vào `Shop3dLayout.outdoorProps` (không chạm được → lưới nền, 0 entity thêm).
    - *Cây:* `_plant` = chậu nón cụt + viền + đất, 1 tán lớn + 3 cụm lá nhỏ (đậm `leafDeep` / nhạt `leafLight` / `mint`);
      `_miniPot` (chậu nhỏ: 2 trên bệ cửa sổ, 1 trên kệ lọ kẹo + dây lá rủ), `_hangingPot` (chậu treo bắt giá vào tường
      giữa cửa 1 và 2, đáy 1,9 m, lá rủ tới 1,82 m). `Shop3dMeshBuilder.sphereBands` thêm bậc 25 / 45 cm (64 / 100 tam giác,
      trước 168) — cầu lá không phải 168 tam giác.
    - *Rèm* `_curtains`: mỗi cửa 2 rèm = 2 lăng trụ hình thang (thân thu xuống chỗ buộc, xòe ra gấu) + nếp sáng + dây buộc.
    - *Bảng phấn* `_chalkMenu`: khung 6 cm + nền lùi + khay phấn; hình vẽ = khối dày 8 mm dán lớp 1 / lớp 2 (cách 8 mm):
      cupcake (cốc thang kẻ sọc, 3 tầng kem thang, dâu), ly cà phê (thang + tai + khói), 3 dòng giả chữ + chấm giá. Không chữ.
    - *Ảnh bà* `_grandmaFrame`: lăng trụ xoay π/2 (mặt cắt trong mặt phẳng yz) dán nổi 1 cm — búi tóc, đầu lục giác, cổ, vai.
      Không cầu (cầu nhô ra khỏi khung), không mặt. Đèn hải đăng: 3 nón cụt kem / hồng dâu + ban công + đèn vàng bơ + mái, cao
      0,53 m trên kệ trên cùng của `ingredientShelf`.
    - *Mặt tiền* (`outdoorProps`): gạch vỉa hè 1,4 × 0,65 m so le (chỉ ô sáng, ô còn lại lộ nền), bậc thềm (ngưỡng cửa trong
      bề dày tường + bậc gỗ z 4,2–4,5, mặt trên ≤ 1 cm), 2 chậu hoa cạnh cửa (x 2,8 / 4,42), ghế băng (x 5,1). Ra vào dùng
      `Shop3dNav.fromLayout` (chậu / ghế là hộp chặn) — khe cửa x ∈ [3,05; 4,15], vỉa hè quanh (2,2; 5,5) và hai đầu vỉa hè
      vẫn thông (test `shop3d_nav_test`). *Lỗi cũ sửa:* vỉa hè trước đây cùng độ cao với đất (-4 cm) nên đất che mất khi nhìn từ
      ngoài vào → nhô lên 1 cm (mặt trên -3 cm, `Shop3dLayout.sidewalkTop`). Tường trước vẫn ẩn khi camera ở ngoài nên rèm /
      chậu treo ẩn theo; đồ ngoài trời luôn hiện và thấp (< 1 m) để không che khách ở cửa.
    - *Đèn thả* chao 0,22 m (trước 0,3), bóng ở 2,25 m (trước 2,07) — từ camera trên cao chao không che đầu nhân vật.
    - *Mặt trong tường trước tối:* **đèn phụ (`fill`) KHÔNG có tác dụng trên web** (đổi sang đỏ → ảnh giống hệt từng điểm ảnh;
      mặt quay lưng nắng chỉ sáng nhờ IBL). Sửa: tường trước dùng màu đỉnh `wallFront` (#FFF4E4, sáng hơn `wall` một tông) +
      `Shop3dScene.ambientIntensity` 19000 → 23000 (tường trước ~ +9 %, sàn ~ +7 %, không cháy). Thử nhanh không build lại:
      `?ambi=<cường độ>` (+ `?tx= &ty= &tz=` đặt điểm nhìn để chụp mặt tiền, `?mind=3` cho phép đứng gần).
    - *Số liệu:* entity tĩnh 37 (trong scene mặc định 30, không đổi), material tĩnh 6 (không đổi), tam giác tĩnh 19,1k → 24,3k
      (≤ 25k), chip `99/110 ent · 8 mat`, ms luồng chính `?play=0` 144 → 152, `?pilot=mai&event=lastCake` 556 → 485–571
      (nhiễu lớn hơn chênh lệch). Ngân sách tam giác chỉ còn ~0,7k — thêm đồ mới phải bớt chỗ khác.
30. **S0 (04/11): lớp làm bánh 2D Flame và hộp thoại QC đè lên cảnh 3D** (`docs/v3/city-gd3-spec.md` §2). Chỉ đo trên web
    (Chrome headless có GPU, máy test), chưa thử trên máy Android.
    - *Cách làm (mã debug, đánh dấu `// S0 spike` trong `town3d_view.dart`, gỡ ở G2):* `?debug=1`, vào tiệm → nút "bake" /
      phím B mở `Positioned.fill(Listener(opaque) → ColoredBox(kem) → SLScope → RefFrame → BakeSessionView)` ngay sau
      `LocationBanner`, trước `TownFadeLayer`; đơn mẫu `OrderGenerator(Random(1))` cấp 1 (cupcake chocolate). Mở thì dừng 3D:
      web `viewer.setRendering(false)` (view ra khỏi danh sách của RenderManager → worker không `beginFrame`, rAF + hook vẫn
      chạy), native `Shop3dFrameDriver.paused = true` (hook vẽ bỏ qua); bỏ `embed.frame()`; bộ đo `auto` đang đo thì đo lại
      từ đầu mỗi giây lớp còn mở. `onComplete` → gỡ lớp, chạy lại 3D, `_cameraDirty = true`, in `outcome`. Nút "x" (góc
      dưới trái) đóng lớp không kết quả (mô phỏng đóng ca giữa chừng). Nút "ad" / phím N: `showSLSimulatedAd(context, 2 s)`.
      Biến thể `bake3d=1` (3D vẫn chạy), `bake3d=hide` (thêm `Offstage` cho `ThermionWidget`), `bake3d=sched`
      (`pauseFrameScheduler` thay `setRendering`).
    - *Đo:* CDP như mục 27 + CPU theo tiến trình (`SystemInfo.getProcessInfo`), kéo / xoay / giữ bằng
      `Input.dispatchMouseEvent`. Mỗi chế độ ≥ 3 lần (xen kẽ, đảo thứ tự), trạm 1 đứng yên, 1280×720:

      | Chế độ | rAF | Luồng chính ms/s | CPU tiến trình GPU |
      |---|---|---|---|
      | Trong tiệm, chưa làm bánh | 60 | 128–198 | 42–70 % |
      | (a) làm bánh, 3D chạy (`bake3d=1`) | 10,0–13,7 | 999 (bão hoà) | 77–79 % |
      | **(b) làm bánh, `setRendering(false)`** | **16,2–16,4** | 999 | **40–53 %** |
      | (b) + `Offstage` ThermionWidget | 14,5–16,4 | 999 | 38–51 % |
      | (b) bằng `pauseFrameScheduler` | 4,7–8,1 | 999 | 26–42 % |
      | Chỉ `BakeSessionView`, app không có 3D (gói tạm ngoài dự án) | 14,2 | 999 | — |
      | (c) sau khi chạy lại 3D | 57–60 | 108–307 | 40–62 % |

      1600×720 (b + Offstage): làm bánh 13,4 rAF; sau khi chạy lại 60 rAF / 158–229 ms/s. Hai lần đo đầu (b) chỉ 4,8–5 rAF là
      lúc máy đang build song song — lặp lại 3 lần sạch không tái hiện.
    - *Nút thắt là chính màn làm bánh trên web, không phải 3D:* app không có 3D cũng chỉ ~14 khung/s, luồng chính 100 %.
      CPU profile (bản `--profile`): ~85 % thời gian ở `CkSurface.rasterizeToCanvas` → `Canvas.drawPicture` / `Surface.flush`
      của CanvasKit (wasm) + `texSubImage2D` — Skia rasterize lại toàn bộ khung (nền bếp, đường vẽ tay `wobblePath`, bóng
      mờ `paintSLShadow`, kem `CakeArt`) mỗi khung; Flutter web không có raster cache. Máy chủ dự án chậm hơn ~2,7 lần
      (mục 27) → ước ~5 khung/s khi làm bánh trên web ở máy đó. Android (Impeller/Skia native) chưa đo.
    - *Kết quả theo tiêu chí:* (1) 3 lần làm bánh trọn 6 trạm liền nhau + mở / đóng thêm (1280: 3 + 2 + 1; 1600: 2 + 2):
      không treo, không exception (cả console của worker thermion), không có log mất context WebGL; sau mỗi lần chibi chuyển
      động lại (2 ảnh PNG cách 0,4 s khác 18–73k điểm ảnh), chip 60 fps. Một lần trang treo ngay sau khi vào tiệm, TRƯỚC khi
      mở lớp làm bánh (luồng chính không trả lời CDP 30 s); 6 lần chạy sau không lặp lại — chưa rõ nguyên nhân. (2) Toạ độ
      đúng ở 1280 và 1600 (khung rộng lệch 160): `wrongMould` khớp số lần thả sai cố ý (1 / 0 / 2), trộn đúng 3,00 vòng,
      topping 3 / 3, hộp nhỏ. (3) (b) nhẹ hơn (a): rAF +43 % (trung bình 16,3 so với 11,4), CPU tiến trình GPU −43 % (45 so với 78 %); luồng chính bão
      hoà ở cả hai (do màn làm bánh). (4) Mức `auto` không bị hạ: chip luôn `high (auto)`; bộ đo xong trước khi vào tiệm
      (48–59 fps → high) nên nhánh "đo lại khi lớp mở" chưa thực sự chạy trên web. (5) Hộp thoại QC (route) hiện trên
      canvas 3D ở 1280 và 1600, tự đóng sau 2 s; sau đó phím WASD, kéo joystick và kéo xoay camera đều chạy (Mai 3,60 → 2,44).
    - *Cạm bẫy:* `GameWidget` của Flame mặc định `autofocus: true` và trả `KeyEventResult.handled` cho MỌI phím khi đang giữ
      focus → trong lúc làm bánh, Esc / phím tắt không tới `Focus` của lớp ca / `Town3dView`. Ngược lại, `_onKey` của
      `Shop3dView` (embed) nuốt Esc (`handled`) trước `Town3dView`.
    - *Kết luận:* đi tiếp kiến trúc §2 (overlay cùng route + `setRendering(false)` / `driver.paused`); không cần phương án dự
      phòng (`setRendering` không hỏng, hộp thoại route chạy được nên không cần presenter trong lớp). Không dùng
      `pauseFrameScheduler` (chậm hơn 2–3 lần; một lần sau khi chạy lại cảnh tiệm còn ì ở 35 rAF). `Offstage` cho
      ThermionWidget không lợi thêm → không dùng.
    - *Khuyến nghị cho G2:* (1) `ShiftLayerHost.setBaking(true)` = đúng các bước ở trên (web `setRendering(false)`, native
      `driver.paused`, bỏ `embed.frame()`, đặt lại `Shop3dQualityProbe` nếu còn đang đo) — ngược lại khi tắt; gọi
      `setRendering` không `await` trong luồng UI (đã chạy được như vậy). (2) Lớp làm bánh bọc `Listener(behavior: opaque)`
      ngoài cùng để vùng letterbox ngoài `RefFrame` không chạm xuống 3D. (3) Esc trong lúc làm bánh: truyền
      `autofocus: false` cho `GameWidget` trong `BakeSessionView` (game không dùng phím) hoặc bắt Esc bằng
      `HardwareKeyboard.instance.addHandler`; `Shop3dView` khi `pilot.locked` phải trả `ignored` cho Esc (spec §2 đã ghi).
      Nút Back Android đi qua `PopScope`, không bị ảnh hưởng. (4) Trên web, màn làm bánh tự nó chỉ ~14–16 khung/s ở máy test
      → cần một đợt tối ưu riêng cho `BakeSessionView` trên web (gom phần tĩnh vẽ tay thành ảnh một lần — `toImage` /
      `RepaintBoundary` không đủ vì web không có raster cache; thử `--wasm` / skwasm), và đo trên Android trước khi kết luận.
31. **P1 (04–05/11): hiệu năng màn làm bánh 2D trên web (`BakeSessionView` + `BakeryGame`).** Chỉ đo trên web (Chrome
    headless có GPU, máy test), chưa đo Android.
    - *Cách đo:* gói tạm ngoài dự án (như mục 26) chỉ có `BakeSessionView` trong `SLScope` + `RefFrame`, đơn mẫu
      `OrderGenerator(Random(1))` cấp 1 (cupcake chocolate); entry in bố trí trạm ra console và đếm khung Flutter
      (`addPersistentFrameCallback` → `globalThis.p1Frames`). Máy chủ COOP/COEP cổng 8800 (bản `--wasm` cần thêm MIME
      `.mjs` = `text/javascript`, `.wasm` = `application/wasm`, nếu không trình duyệt rơi về bản JS mà không báo lỗi rõ). Script
      CDP (như mục 27, 30) chơi trọn 6 trạm, ở mỗi trạm đo 3 s đứng yên + 2–3 s đang thao tác (kéo khuôn, xoay 3 vòng,
      giữ nút nướng, vẽ xoắn ốc kem, kéo 3 topping, kéo bánh vào hộp); mỗi lượt một phiên Chrome mới, xen kẽ bản cũ / mới.
      Máy test lúc đo có tải lạ (Gradle, Chrome khác: 30–55 % CPU) → số khung/s của bản cũ dao động 6–24 giữa các đợt; so
      bằng **ms luồng chính / khung** (TaskDuration ÷ số khung Flutter) và luôn đo xen kẽ trong cùng đợt. Thí nghiệm cắt bỏ
      (`?off=ov,bg,col,st,cake,shadow,batter`) chỉ chèn vào bản sao lib của gói tạm.
    - *Nguyên nhân (trước):* ~85–90 % thời gian là CanvasKit rasterize (`Canvas.drawPicture` / `Surface.flush` /
      `texSubImage2D`), Dart dựng + vẽ chỉ ~4 %. Cắt bỏ ở trạm khuôn (ms/khung, đợt yên nhất): đủ cả ~50; bỏ **lớp phủ Flutter**
      (thanh bước, vé đơn, giấy gợi ý — bộ SL* vẽ tay: path run tay dài, `clipPath` theo viền, vân giấy) còn ~14; bỏ thêm nội
      dung trạm ~8; bỏ cả ảnh nền + tờ giấy cột phải + trạm ~3. Lớp phủ không vẽ lại phía Dart (đã có `RepaintBoundary`
      trong SL*), nhưng web không có raster cache nên mỗi khung game Flame vẽ, CanvasKit rasterize lại MỌI Picture của
      cả cây lớp. Sau bước 1–2: bánh `CakeArt` (kem vẽ nét màu nước mỗi lần gọi) tốn 6–13 ms/khung ở trạm topping / hộp,
      mặt bột trạm trộn (`_paintBatter`: `clipPath` viền run tay + ~50 path mỗi khung, path web dựng lại backend mỗi khung)
      ~8 ms; bóng mờ (`MaskFilter.blur`) không đáng kể.
    - *Đã sửa (`lib/game`):* (1) `bake_session_view.dart` `_Snap`: thanh bước, vé đơn, giấy gợi ý bọc `SnapshotWidget`
      (chụp thành ảnh một lần, mỗi khung chỉ dán ảnh), độ phân giải chụp = điểm ảnh thật / đơn vị khung
      (`View.physicalSize` ÷ cỡ khung W×720, đặt qua `MediaQuery.devicePixelRatio` bọc ngoài, con vẫn thấy DPR gốc); lề 12
      mỗi phía để bóng / vé nghiêng không bị cắt. Ảnh chụp không tự biết con vẽ lại (SL* có `RepaintBoundary` riêng,
      `AnimatedSwitcher` / `AnimatedScale` chỉ cập nhật layer) → khi đổi trạm, mảng đó chạy trực tiếp 400 ms rồi mới chụp;
      `ArtSprites.changes` / `systemFonts` → chụp lại sau 400 ms yên (đầu phiên ảnh bếp nạp dồn dập, chụp lại theo từng ảnh
      tốn như vẽ trực tiếp). Nút Xong, lời nhắc, thẻ hướng dẫn vẫn vẽ trực tiếp (có hoạt cảnh nhấn). (2) `hand_paint.dart`
      `GameArt.draw` / `drawOverlay`: mọi hình vẽ tay dựng sẵn của game (đĩa, nhãn, thanh đo, kim, nút Giữ, khay, đĩa bầu dục,
      chấm / vòng gợi ý, giá nướng, tờ giấy cột phải) raster hoá một lần bằng `toImageSync` ở `gameArtPixelRatio`
      (`BakeryGame.pixelRatio`, `BakeSessionView` đặt mỗi lần dựng + `didChangeMetrics`), đổi tỉ lệ → raster lại ở lần vẽ
      sau; tỉ lệ 0 (test thuần) → vẽ Picture như cũ. Vùng raster = `GameArt.bounds` (mặc định cỡ + lề `origin` hai phía;
      tờ giấy cột phải vẽ ở toạ độ khung nên khai báo riêng) + lề 24. (3) `game_paint.dart` `paintCakeWithToppings`: bánh đã
      phủ kem (không topping) dựng thành `GameArt` một ô, chỉ khi cỡ bánh đứng yên từ khung trước (hoạt cảnh co giãn ở trạm
      hộp vẽ thẳng); ảnh vẽ tay nạp xong → dựng lại; `BakeryGame.onRemove` → `clearCakeCache`. (4) `GameWidget(autofocus:
      false)` (mục 30, cạm bẫy Esc). Không đổi logic / chấm điểm: 6 lượt × 2 cỡ cho cùng kết quả (sai khuôn 1, trộn 3,00 vòng,
      kem 0,98, topping 3, hộp nhỏ; `release` của trạm nướng lệch theo độ trễ CDP khi luồng chính bão hoà — bản cũ 0,75–0,92,
      bản mới 0,67–0,68 với cùng 1,95 s giữ).
    - *Số liệu (bản JS, CanvasKit), trung vị 3 lượt xen kẽ, khung/s (ms luồng chính / khung):*

      | Trạm | 1280 trước | 1280 sau | 1600 trước | 1600 sau |
      |---|---|---|---|---|
      | 1 khuôn — yên / kéo | 5,7 (175) / 8,3 (120) | 53 (8,6) / 60 (9,3) | 6,2 (161) / 9,9 (101) | 53 (15) / 58 (14) |
      | 2 trộn — yên / xoay | 10 (99) / 12 (83) | 47 (21) / 43 (23) | 10 (98) / 12 (87) | 37 (27) / 37 (27) |
      | 3 nướng — yên / giữ | 11 (88) / 10 (97) | 60 (8,0) / 60 (11) | 16 (64) / 13 (77) | 60 (8,4) / 60 (11) |
      | 4 kem — yên / vẽ | 12 (81) / 19 (53) | 60 (12) / 59 (15) | 18 (57) / 11 (88) | 60 (13) / 60 (15) |
      | 5 topping — yên / kéo | 14 (73) / 11 (89) | 60 (11) / 60 (12) | 8,3 (120) / 9,7 (103) | 60 (15) / 60 (15) |
      | 6 hộp — yên / kéo | 14 (71) / 11 (92) | 60 (6,4) / 56 (11) | 14 (74) / 12 (81) | 60 (12) / 55 (15) |

      Đợt đo yên nhất trước khi sửa (04/11 tối) bản cũ là 17–24 khung/s (42–55 ms/khung) ở 1280 — đợt cuối máy tải nặng hơn nên
      bản cũ thấp hơn; bản mới đo xen kẽ cùng đợt. "1 khuôn yên" gồm cả 3 s đầu phiên (nạp ảnh bếp, raster hoá lần đầu) nên
      thấp hơn trạm khác. Hai lần bản CŨ treo ở chỗ bấm Xong trạm kem → topping khi luồng chính bão hoà (CDP không gửi được
      chuột 30 s); bản mới chưa lần nào.
    - *`--wasm` (dart2wasm + skwasm đa luồng, rasterize ở worker riêng), 1280, 2 lượt:* bản cũ **60 khung/s ở mọi trạm**,
      luồng chính 1,0–3,3 ms/khung, CPU tiến trình renderer ~114 %; bản mới 60 khung/s, 2,2–3,8 ms/khung, renderer ~78 %
      (bản mới JS cùng đợt: renderer ~85 %). Cả app có phố 3D (`?intro=0&save=memory&debug=1`, bản sao dự án ngoài
      `.dart_tool`) build `--wasm` được, thermion chạy (tải `thermion_dart.wasm`, `skwasm.wasm` từ máy chủ), hình giống bản
      JS, không exception: rAF 60, chip 60–61 fps; luồng chính đứng yên 109–111 ms/s (JS 108–116), đi bộ 121–148 (JS
      190–213); chip `dart` 0,50 ms (JS 0,72). CHƯA thử: lớp làm bánh đè lên 3D trong bản wasm, Safari / Firefox (skwasm cần
      WasmGC; trình duyệt không có thì `flutter.js` tự rơi về bản JS), máy Android thật. Cách build mặc định chưa đổi.
    - *Còn lại:* trạm trộn là trạm nặng nhất bản JS (21–27 ms/khung; mặt bột ~8 ms — muốn nhẹ hơn phải raster hoá từng nhóm
      nguyên liệu / vệt xoáy thành ảnh xoay theo tay, đổi cách vẽ đáng kể); khung rộng 1600 thêm ~4–6 ms/khung (nền soi
      gương `paintWideBackdrop` + `clipPath` mỗi khung, tờ giấy rộng hơn) — có thể gom nền + cột thành một ảnh theo trạm.
      Máy người chơi chậm hơn 2–3 lần: bản JS ước 20–40 khung/s ở trạm thường, trạm trộn ~15. Test:
      `test/game/bake_raster_test.dart` (ảnh raster đủ nét — so tổng alpha với vẽ Picture < 2 %, đổi tỉ lệ / cỡ màn → raster
      lại, bánh chỉ dựng khi cỡ đứng yên, `_Snap` chạy trực tiếp khi đổi trạm, Esc tới lớp ngoài).
32. **G0 (05/11): lô chi nhánh tách khỏi lưới phố, mặt tiền theo cấp, ô quầy văn phòng địa ốc** (`docs/v3/city-gd4-spec.md`
    §0, §5; `town_layout.dart`, `town_batches.dart`). Dart thuần, đo bằng `town3d_batches_test` trong gói tạm (mục 26).
    - *Số đo trước* (lưới tĩnh của phố, `TownBatches.build`): **19 052 tam giác**, 12 entity, 2 material (mờ + không chịu
      ánh sáng), 6 ô. Con số "19,1k" trong spec trùng hợp với lưới tĩnh **nội thất tiệm** (mục 28: 5,9k → 19,1k), không
      phải của phố. Theo nhóm: s2 2 552, n3 2 164, n4 2 076, bồn hoa 1 512, **s1 / s3 / s4 mỗi lô 1 368** (lô trống: rào
      có cổng mở, biển, cây, 2 bụi cầu 168 tam giác), n2 1 204, n1 916, đèn 888, bãi biển 488, trạm buýt 376, vạch 300,
      hai đầu phố 2 × 228, bụi khe lô 3 × 224 + 3 × 24, mặt đất 1 272 (72 ô đất, cắt theo ô 16 m).
    - *Sau:* lưới tĩnh **15 528** (bỏ 3 × 1 368 của lô chi nhánh, n1 916 → 1 496 vì thêm ô quầy), vẫn 12 entity / 2
      material. Mặt tiền mỗi lô (`TownBatches.buildLot`, cả ba lô như nhau, chỉ khác màu nhấn) cấp 0..5: **940 / 464 / 728 /
      960 / 1 140 / 1 252** (trần §5: 1 000 / 800 / 950 / 1 100 / 1 200 / 1 300), 2 lưới (mờ + không chịu ánh sáng: cửa sổ,
      đèn). Tĩnh + 3 lô cấp 5 = **19 284 tam giác, 18 entity, 2 material** (trần 20k / 40 / 8, mục tiêu 19,5k) — chưa cần
      bước cắt nào của §5 (cầu (6, 10), đơn giản nửa sau nhà, bỏ rào sau), nên `Shop3dMeshBuilder` không thêm tham số.
    - *Bố cục chung* (`TownLayout.forDistrict`): lô chi nhánh không còn khối nào, chỉ một hộp chặn cố định
      `TownLayout.branchBlockL/D0/D1` = l ∈ [−5,4; 5,4] × d ∈ [0,3; 9,95] (khung lô) cho mọi cấp → `TownPilot` dựng `nav` một
      lần vẫn đúng. Cửa lô (d = 0) cách hộp đúng 0,3 m: Mai (bán kính 0,27) đứng được; test BFS lưới 0,15 m của
      `town_layout_test` chấp nhận ô kề vì tâm ô có thể gần hộp hơn điểm thật vài cm. Bụi khe giữa hai lô (`gap:s*`) vẫn ở
      lưới chung (nằm ngoài lô).
    - *Mặt tiền* (`TownLayout.branchFacade(lot, level)`, toạ độ lớp phố, một `Shop3dProp('branch:<id>')`, cấp kẹp 0..5;
      lớp riêng `_BranchFacade`, dùng lại `_window` / `_door` / `_awning` / `_fence` — nay là hàm static của
      `_TownBuilder`). Đường bao `TownRules.branchEnvelope(d) = 0,6 + 0,8·d` được kiểm theo **từng đỉnh** của lưới (khối lồi,
      đường bao tuyến tính → kiểm đỉnh là đủ). Cách dựng cho vừa đường bao:
      - tường trước d = 2,4 cao 2,45; **mái lệch** = lăng trụ tam giác (chỉ có lăng trụ cân, xoay quanh y) đáy y 2,3 từ d =
        2,15 tới đỉnh 3,9 ở mặt trước **khối sau** (d 4,4–7,4, cao 3,85 + nắp màu nhấn) — nửa sau lăng trụ nằm trong khối sau;
        dốc 0,71 < 0,8;
      - mái hiên đáy 2,05, nhô 0,55, cao 0,38 (mép trước d = 1,85 → trần 2,08); cửa sổ khung tới 2,05; ô dù sân thấp (vành
        1,15 m ở d ≈ 0,75); biển sân ở d = 1,4 (trần 1,7), sao cấp 5 cao tới 1,56; rào lô trống ở d = 0,45 (cột 0,85, cột cổng
        0,8 + nắp); bụi viền chi nhánh 0,6 m ở d ≥ 0,2.
      - Cấp 0: rào trắng kín (cổng hai cánh đóng + chốt), biển hai mặt (sọc màu nhấn xuyên qua bảng nên thấy cả hai mặt),
        cây non hình nón, hoa dại, một bụi. Cấp 1: bụi viền + cột cổng, lối lát, tiệm nhỏ l ∈ [−2; 4,6], 1 cửa sổ, cửa màu
        nhấn, biển cupcake hai mặt. Cấp 2: + mái hiên sọc trên cửa sổ, 2 chậu. Cấp 3: nhà l ∈ [−5; 5], 2 cửa sổ, bàn ô dù
        ở (l 3,6; d 1,3). Cấp 4: mái hiên dài suốt mặt tiền (sọc 1,6 m), dây đèn 4 bóng dưới mép, bồn hoa bệ cửa sổ. Cấp 5:
        ống khói trên khối sau, sao 6 cánh trên biển, 2 đèn lồng cạnh cửa.
      - Chừa chỗ: nhân viên ở (l −1,6; d 1,0) và biểu tượng két đầy ở (l 2,5; d 1,4; y 2,3) đều trống.
      - Màu nhấn (mái, nắp, cửa, mái hiên, ô dù, nắp cột cổng): s1 hồng dâu, s3 bạc hà, s4 vàng bơ; tông nhạt cho chân tường
        và kem biển.
    - *Văn phòng địa ốc (n1):* thân nhà như tiệm tóc (khối sau + hai cánh, hốc ô cửa) với `_hatch` ở l = +3, mái hiên bạc hà
      trên ô cửa, bỏ cửa sổ phải (chỗ ô cửa), chậu phải lùi về l = 1,15. `spots['n1']` có `counter` (−15; −5,0) và `keeper`
      (−15; −7,2) như tiệm tóc → `TownRules.zonesOf` tự thêm vùng quầy n1 (cách vùng cửa 3,04 m > 1,5 + 1,15). Hiện
      `actionFor` vẫn trả `none` và băng tên "Sắp mở" cho n1 cho tới G1.
    - *Ảnh xem trước* (bộ chụp phần mềm: test tạm xuất lưới JSON + `render.py` rasterize numpy, fov 40°): góc cận
      (yaw π − 0,5) cấp 0..5, ba màu nhấn, camera phố yaw 0 / ±60° và Mai đứng ở cửa lô (pitch 40°, cách 10 m — góc gắt
      nhất): Mai không bị che, chỉ chân sát mép bụi khi đứng ngay cửa lô; Mai giữa đường thì lô nam ngoài khung. Ảnh:
      `docs/design/art-preview/v3/city/gd4-facade-*.png` (thư mục dự án chính).
    - *Chưa làm (G2):* chưa ghép vào cảnh — trong game hiện tại lô chi nhánh tạm trống (chỉ còn hộp chặn) cho tới khi
      `TownScene.setBranchLevel` dựng `buildLot`.
33. **G2 (05/11): ghép chi nhánh vào phố** (`docs/v3/city-gd4-spec.md` §4, §5; `town3d_view.dart`, `town_scene.dart`,
    `town3d_page.dart`, phần Dart thuần `town_branch_ui.dart`, biểu tượng `TownMeshes.tillFull`). Đo trên web (Chrome
    headless có GPU, máy test, 1280×720, CDP như mục 27/30; bản trước GĐ4 = bản build GĐ3 G2 chạy song song cổng khác,
    đo xen kẽ). Chưa đo Android.
    - *Cảnh (`TownScene`):* `setBranchLevel(lot, level)` dựng `TownBatches.buildLot` (≤ 2 lưới, material màu đỉnh dùng
      chung theo `Shop3dSurfaceKey`, toạ độ phố, transform = dời gốc lớp phố), tạo **ngoài scene**
      (`ThermionViewerFFI.createGeometry(addToScene: false)` — có cả trên web; viewer khác thì gỡ ngay), gán material rồi
      mới thêm vào scene, sau đó gỡ + `destroyAsset` lưới cũ (huỷ không đụng material dùng chung: `GeometrySceneAsset`
      chỉ huỷ vertex / index buffer + entity). Gọi lại cùng cấp → bỏ qua; gọi chồng → nối tiếp, chỉ cấp cuối được dựng.
      Không truyền `materialInstances` lúc tạo (web, mục 9.1). Biểu tượng két đầy: một entity / lô (material chibi,
      164 tam giác), dựng lần đầu cần, mỗi khung quay mặt về camera (`pilot.cameraYaw`) + lắc / nhấp nhô, ẩn ở lô Mai
      đang đứng ở vùng cửa. Nhân viên ở sân: `setBranchActors(TownBranchCast.plan(...))` mỗi giây; mỗi chibi (7–9
      entity, ~3k tam giác) dựng một lần, giữ lại, chỉ add / remove scene; actor mới (kịch bản chủ quán quay ra đường)
      khi đổi lô; bóng tròn dựng khi mức đồ hoạ cần.
    - *View:* nút A `realty` → `pilot.beginCounter()` + góc cận như quầy quán ăn + `RealtySheet`; `branch` → `collect`
      (được: toast, Mai `happy`, nhân viên vẫy, chip x2 nếu `canDouble` và còn lượt quảng cáo) hoặc `BranchSheet` với
      góc cận `TownBranchUi.closeUp` (yaw π − 0,5, pitch 30°, cách 12 m, điểm nhìn dời 2,6 m sang phải màn để mặt tiền
      nằm phần trái). Nhãn A "Thu tiền" / "Chi nhánh" theo két ≥ 25% trần hoặc đầy (`TownBranchUi.collectable`, `_collectable`, đổi khi vùng đổi / mỗi giây /
      sau khi thu). Bộ đếm 1 Hz (`_sampleFps`, ngoài build): `TownBranchMarks` (chỉ notify khi khác), `setFullIcons`,
      plan nhân viên, `takeAway()` → hàng toast nối tiếp (vắng nhà / quản lý gửi về / giờ lùi; trong tiệm để dành).
      Bảng chi nhánh dựng lại chỉ khi (két, đầy, phút còn lại) đổi — dựng lại mỗi giây làm web mất ~1 khung mỗi lần.
      Đóng bảng → `requestFocus` cho view (khung bảng giữ focus riêng, không trả thì WASD chết).
    - *Số đo* (chip `town … ent (static) · mat · tri`): trước GĐ4 `38 ent (static 12) · 8 mat · 29,3k tri (static 19,1k)`;
      sau, không chi nhánh `49 (static 15) · 31,5k (static 18,3k)` (+3 lô trống, +chủ văn phòng địa ốc `regular_12`);
      s1 cấp 3 + s3 cấp 1, 2 nhân viên, 2 két đầy (Mai giữa s1 và s3) `70 (static 17) · 8 mat · 38,1k (static 17,9k)`.
      Material không đổi (8, kể cả của tiệm). Tĩnh tối đa (3 lô cấp 5) 18 entity / 19,3k tam giác (mục 32).
      rAF 60 ở mọi kịch bản. Luồng chính (ms / s, 3 lượt xen kẽ): đứng yên trước 106–161 → sau 108–149 (không chi
      nhánh), 133–163 (2 nhân viên); chạy dọc phố trước 217–351 → sau 239–302 / 226–269. Chip `dart` (cập nhật mỗi
      khung) với 2 nhân viên 0,52–1,04 ms (trung vị ~0,8; trước 0,36–0,77), có mẫu đỉnh 1,1–1,46 ms — ngưỡng spec
      ≤ 1,0 ms đạt ở trung vị, vượt ở đỉnh (thêm chủ văn phòng địa ốc + 1–2 nhân viên = +16–25 bộ phận chibi cập nhật mỗi khung).
    - *Giật (khoảng cách rAF > 40 ms):* dựng mặt tiền (`buildLot` Dart 1–5 ms, sẵn sàng sau 94–480 ms bất đồng bộ) khi mua
      lô: tệ nhất 33 ms, không khung nào > 40 ms. Nâng cấp **trong bảng chi nhánh** 50–133 ms (3–5 khung) nhưng mở panel
      xác nhận "Cho nghỉ" (chỉ đổi UI, không đụng 3D) cũng 50–100 ms → phần lớn do CanvasKit vẽ lại bảng (mục 31), không
      phải lưới. Nhân viên vào sân khi Mai đi tới (dựng chibi tại chỗ): 3–5 khung ~50 ms (model Dart 10–30 ms + 9
      `createGeometry`) → sửa: `prepareStaff` dựng sẵn chibi mọi nhân viên đang làm dưới màn đen lúc mở phố (và lúc
      thuê), vào sân chỉ còn add scene: tệ nhất 17–33 ms, không khung nào > 40 ms (3 lượt; trước khi sửa 3 lượt đều có 1–5
      khung 45–67 ms). Đổi lại: mở phố chậm thêm ~200–340 ms (dưới màn đen, song song mặt tiền) và chip "đã tạo" thêm 7–9
      entity / nhân viên đang làm (ngoài scene, không vẽ).
    - *Cạm bẫy:* `RealtySheet` / `BranchSheet` trả `Positioned.fill` → đặt làm con trực tiếp của `Stack` (qua
      `ListenableBuilder` vẫn được, ParentData đi xuyên widget không có RenderObject). Toast hiện dưới lớp bảng (thứ tự
      `Stack`), không đè bảng. Két tăng theo giờ không notify → mọi thứ hiển thị két phải đọc lại theo nhịp (1 Hz), không
      chờ notify. File `town3d_view.dart` dùng CRLF — sửa bằng script Python phải giữ `\r\n`.
    - *Ghi nhận cho thiết kế:* từ camera phố (pitch 45°, cách 11 m), Mai đứng ở cửa lô nam cấp ≥ 3 thì mái lệch màu nhấn
      phủ ~1/3 dưới màn (đúng §0: chỉ thấy mái), trông nặng; nhân viên đứng (l −1,6; d 1,0) sau bụi viền 0,6 m nên ở góc
      cận chỉ thấy nửa trên (chibi thấp như hamster `regular_01` gần như chỉ thấy đầu). Lô cấp cao bán ~1 xu / 3–4 s nên
      ngưỡng ban đầu "két ≥ 1 xu" làm nút A gần như luôn là "Thu tiền" → đã chốt (05/11) ngưỡng 25% trần (hoặc đầy).
      Ảnh: `docs/design/art-preview/v3/city/gd4-g2-*.jpg` (thư mục dự án chính).
