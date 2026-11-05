import 'package:thermion_flutter/thermion_flutter.dart' hide Material, Texture, View;
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

/// Vẽ khung Filament cho một viewer và đếm khung Filament THẬT SỰ nhận (`Renderer::beginFrame` trả true).
///
/// Vòng mặc định của thermion (`RenderManager::render` trên luồng render) bỏ qua kết quả `beginFrame`: khi GPU / bên
/// nhận SurfaceTexture tụt lại, Filament bỏ khung (beginFrame = false) nhưng phía Dart vẫn thấy mỗi vsync một lần
/// render "xong" — request-frame hook vẫn chạy 60 lần/s dù màn hình đứng yên (docs/v3/thermion-api-notes.md mục 9.23).
/// Ở đây view được gỡ khỏi vòng của thermion (`setRendering(false)`, swapchain vẫn gắn) và mỗi khung, trong
/// request-frame hook (FrameScheduler chờ hook xong rồi mới nhận khung sau → không chạy chồng), ta tự gọi
/// beginFrame → render → endFrame qua luồng render và đếm [rendered] / [skipped].
///
/// Chỉ dùng trên native (FFI nhiều luồng). Web (`FILAMENT_SINGLE_THREADED`): worker tự vẽ theo rAF và không chờ được
/// từ luồng chính → [supported] = false, để thermion vẽ như cũ.
class Shop3dFrameDriver {
  Shop3dFrameDriver(this.viewer);

  final ThermionViewer viewer;

  static bool get supported => !FILAMENT_SINGLE_THREADED;

  /// Khung Filament đã nhận và vẽ / khung bị bỏ (beginFrame = false) — cộng dồn, người dùng tự lấy hiệu.
  int rendered = 0;
  int skipped = 0;

  /// Tạm dừng vẽ (lớp 2D mờ đục che kín cảnh, vd. lúc làm bánh): hook không gọi beginFrame / render / endFrame, không
  /// đếm khung; ảnh cuối vẫn nằm trên texture. Đặt lại false là vẽ tiếp từ khung sau.
  bool paused = false;

  bool _started = false;

  Future<void> start() async {
    if (_started || !supported) return;
    _started = true;
    await viewer.setRendering(false);
    await viewer.app.registerRequestFrameHook(_frame);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await viewer.app.unregisterRequestFrameHook(_frame);
  }

  Future<void> _frame() async {
    if (paused) return;
    final app = viewer.app as FFIFilamentApp;
    final view = viewer.view;
    for (final swapChain in app.renderManager.getAttachedSwapChains(view)) {
      final renderer = app.renderer;
      final ok = await withBoolCallback(
          (cb) => Renderer_beginFrameRenderThread(renderer, swapChain.getNativeHandle(), 0.toBigInt, cb));
      if (!ok) {
        skipped++;
        continue;
      }
      await withVoidCallback(
          (requestId, cb) => Renderer_renderRenderThread(renderer, view.getNativeHandle(), requestId, cb));
      await withVoidCallback((requestId, cb) => Renderer_endFrameRenderThread(renderer, requestId, cb));
      rendered++;
    }
  }
}
