import 'dart:math' as math;

/// Mức chất lượng đồ họa của cảnh 3D (docs/v3/thermion-api-notes.md mục 9.24, 9.27).
enum Shop3dQuality {
  /// GPU yếu (PowerVR GE8320 / Mali-G5x / Adreno 5xx…): không bóng động (bóng tròn giả dưới chân nhân vật), ảnh 3D
  /// ít điểm ảnh hơn, khung đều 30 fps.
  low,

  /// Máy mạnh / Chrome desktop: bóng mềm DPCF, đủ điểm ảnh, không giới hạn FPS.
  high,
}

/// Chọn mức: ép [low] / [high], hoặc [auto] = bắt đầu [Shop3dQuality.high], đo FPS thật vài giây đầu (native) rồi hạ
/// xuống [Shop3dQuality.low] nếu không đủ ([Shop3dQualityProbe]).
enum Shop3dQualityMode {
  auto,
  low,
  high;

  /// `quality=low|high|auto` (thiếu / sai = [auto]).
  static Shop3dQualityMode parse(String? s) => switch (s) {
        'low' => low,
        'high' => high,
        _ => auto,
      };
}

/// Thiết lập đồ họa của cảnh, đổi được lúc đang chạy (`Shop3dScene.applyGraphics` + view).
class Shop3dGraphics {
  const Shop3dGraphics({
    required this.shadows,
    required this.softShadows,
    required this.shadowMapSize,
    required this.postProcessing,
    required this.fxaa,
    required this.neutralToneMapper,
    required this.ambientLight,
    required this.blobShadows,
    required this.renderScale,
    required this.targetFps,
    this.maxRenderPixels = 0,
  });

  /// Bộ thiết lập của từng mức (số đo trên Samsung A12: mục 9.24 ghi chú API).
  factory Shop3dGraphics.preset(Shop3dQuality q) => switch (q) {
        Shop3dQuality.high => high,
        Shop3dQuality.low => low,
      };

  // Chủ dự án bỏ đổ bóng động ở mọi mức (03/11/2026), chỉ giữ bóng tròn mờ dưới chân; `?shadows=1` để so sánh.
  static const high = Shop3dGraphics(
    shadows: false,
    softShadows: false,
    shadowMapSize: 1024,
    postProcessing: true,
    fxaa: true,
    neutralToneMapper: true,
    ambientLight: true,
    blobShadows: true,
    renderScale: 1,
    targetFps: 0,
  );

  static const low = Shop3dGraphics(
    shadows: false,
    softShadows: false,
    shadowMapSize: 512,
    postProcessing: true,
    fxaa: false,
    neutralToneMapper: true,
    ambientLight: true,
    blobShadows: true,
    renderScale: 0.6,
    targetFps: 30,
  );

  /// Bóng động (shadow map của nắng).
  final bool shadows;

  /// Bóng DPCF (mềm) thay cho PCF (cứng) — DPCF đắt nhất trên GPU yếu.
  final bool softShadows;

  /// Cạnh shadow map (texel, lũy thừa 2).
  final int shadowMapSize;

  /// Hậu kỳ (tone mapper, FXAA). Tắt = Filament vẽ thẳng vào swapchain, không tone mapping.
  final bool postProcessing;
  final bool fxaa;

  /// Tone mapper PBR Neutral thay cho mặc định của thermion (chỉ có tác dụng khi bật hậu kỳ).
  final bool neutralToneMapper;

  /// Ánh sáng môi trường (IBL từ SH).
  final bool ambientLight;

  /// Bóng tròn mờ dưới chân nhân vật chibi (thay bóng động khi tắt [shadows]).
  final bool blobShadows;

  /// Tỉ lệ độ phân giải ảnh Filament so với màn hình (Flutter phóng lên).
  final double renderScale;

  /// Giới hạn FPS của vòng render (0 = theo vsync).
  final int targetFps;

  /// Trần số điểm ảnh của ảnh 3D (0 = không giới hạn). Màn mật độ cao (devicePixelRatio 1,5–2, màn 1440p / Retina) vẽ
  /// 3–8 MP mỗi khung; trên web ([forWeb]) hạ [renderScale] để không quá [webMaxRenderPixels] (≈ màn 1080p — màn 1080p
  /// trở xuống giữ nguyên độ nét).
  final int maxRenderPixels;

  static const int webMaxRenderPixels = 2100000;

  /// Bộ cho web: thêm trần điểm ảnh [webMaxRenderPixels] nếu chưa có.
  Shop3dGraphics forWeb() => maxRenderPixels > 0 ? this : copyWith(maxRenderPixels: webMaxRenderPixels);

  /// Tỉ lệ độ phân giải thực áp cho khung [logicalWidth]×[logicalHeight] (điểm logic) ở [devicePixelRatio]:
  /// [renderScale], hạ thêm nếu số điểm ảnh vượt [maxRenderPixels]. Không dưới 0,25.
  double renderScaleFor(double logicalWidth, double logicalHeight, double devicePixelRatio) {
    var scale = renderScale;
    final px = logicalWidth * logicalHeight * devicePixelRatio * devicePixelRatio * scale * scale;
    if (maxRenderPixels > 0 && px > maxRenderPixels) scale *= math.sqrt(maxRenderPixels / px);
    return scale.clamp(0.25, 1.0).toDouble();
  }

  Shop3dGraphics copyWith({
    bool? shadows,
    bool? softShadows,
    int? shadowMapSize,
    bool? postProcessing,
    bool? fxaa,
    bool? neutralToneMapper,
    bool? ambientLight,
    bool? blobShadows,
    double? renderScale,
    int? targetFps,
    int? maxRenderPixels,
  }) =>
      Shop3dGraphics(
        shadows: shadows ?? this.shadows,
        softShadows: softShadows ?? this.softShadows,
        shadowMapSize: shadowMapSize ?? this.shadowMapSize,
        postProcessing: postProcessing ?? this.postProcessing,
        fxaa: fxaa ?? this.fxaa,
        neutralToneMapper: neutralToneMapper ?? this.neutralToneMapper,
        ambientLight: ambientLight ?? this.ambientLight,
        blobShadows: blobShadows ?? this.blobShadows,
        renderScale: renderScale ?? this.renderScale,
        targetFps: targetFps ?? this.targetFps,
        maxRenderPixels: maxRenderPixels ?? this.maxRenderPixels,
      );
}

/// Ghi đè từng thiết lập lên bộ của mức (tham số URL / route: soft, ibl, tm, scale, fps, shadows, smap, post, aa, blob,
/// maxpx). null = giữ theo mức.
class Shop3dGraphicsOverrides {
  const Shop3dGraphicsOverrides({
    this.shadows,
    this.softShadows,
    this.shadowMapSize,
    this.postProcessing,
    this.fxaa,
    this.neutralToneMapper,
    this.ambientLight,
    this.blobShadows,
    this.renderScale,
    this.targetFps,
    this.maxRenderPixels,
  });

  /// Đọc từ tham số: cờ bật / tắt = `1` / `0`; `smap` / `fps` / `maxpx` số nguyên (`maxpx=0` bỏ trần điểm ảnh của
  /// web); `scale` 0,25–1.
  factory Shop3dGraphicsOverrides.fromParams(Map<String, String> q) {
    bool? flag(String k) => switch (q[k]) {
          '0' => false,
          '1' => true,
          _ => null,
        };
    final scale = double.tryParse(q['scale'] ?? '');
    return Shop3dGraphicsOverrides(
      shadows: flag('shadows'),
      softShadows: flag('soft'),
      shadowMapSize: int.tryParse(q['smap'] ?? ''),
      postProcessing: flag('post'),
      fxaa: flag('aa'),
      neutralToneMapper: flag('tm'),
      ambientLight: flag('ibl'),
      blobShadows: flag('blob'),
      renderScale: scale?.clamp(0.25, 1).toDouble(),
      targetFps: int.tryParse(q['fps'] ?? ''),
      maxRenderPixels: int.tryParse(q['maxpx'] ?? ''),
    );
  }

  final bool? shadows;
  final bool? softShadows;
  final int? shadowMapSize;
  final bool? postProcessing;
  final bool? fxaa;
  final bool? neutralToneMapper;
  final bool? ambientLight;
  final bool? blobShadows;
  final double? renderScale;
  final int? targetFps;
  final int? maxRenderPixels;

  Shop3dGraphics apply(Shop3dGraphics g) => g.copyWith(
        shadows: shadows,
        softShadows: softShadows,
        shadowMapSize: shadowMapSize,
        postProcessing: postProcessing,
        fxaa: fxaa,
        neutralToneMapper: neutralToneMapper,
        ambientLight: ambientLight,
        blobShadows: blobShadows,
        renderScale: renderScale,
        targetFps: targetFps,
        maxRenderPixels: maxRenderPixels,
      );
}

/// Đo FPS thật lúc đầu cho chế độ [Shop3dQualityMode.auto]: bỏ [warmup] giây đầu (dựng cảnh, biên dịch shader), đếm
/// khung Filament trong [window] giây; dưới [minFps] → [Shop3dQuality.low]. Dart thuần, cho view gọi mỗi giây.
/// Web: khung = số vòng requestAnimationFrame của thermion, tụt khi luồng chính (Dart + Flutter) hoặc GPU quá tải.
class Shop3dQualityProbe {
  Shop3dQualityProbe({this.warmup = 2, this.window = 3, this.minFps = 45});

  final int warmup;
  final int window;
  final int minFps;

  int _seconds = 0;
  int _frames = 0;

  /// Thêm số khung của một giây; trả mức đã chọn khi đo xong, null khi còn đang đo.
  Shop3dQuality? addSecond(int frames) {
    _seconds++;
    if (_seconds <= warmup) return null;
    _frames += frames;
    if (_seconds < warmup + window) return null;
    return _frames < minFps * window ? Shop3dQuality.low : Shop3dQuality.high;
  }

  /// FPS trung bình trong cửa sổ đo (sau khi [addSecond] trả kết quả).
  double get averageFps => _seconds <= warmup ? 0 : _frames / (_seconds - warmup);

  /// Giới hạn FPS nên đặt cho màn tần số quét cao: đo được > 90 khung/s (màn 120 / 144 Hz) → nửa tần số (mỗi hai vsync
  /// một khung, đều nhịp) để không tốn gấp đôi CPU / GPU cho cảnh cozy; null = để theo vsync.
  int? highRefreshCap() {
    final fps = averageFps;
    return fps > 90 ? (fps / 2).round() : null;
  }
}
