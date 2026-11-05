import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Material, Texture, View;

import '../../core/app_scope.dart';
import '../../core/city/city_game.dart';
import '../../core/debug_params.dart';
import '../../core/save/city_save_store.dart';
import '../../core/shift/shift_session.dart';
import '../../ui/shift/shift_layer.dart';
import '../../ui/town/city_settings_sheet.dart';
import '../shop3d/shop3d_quality.dart';
import '../shop3d/shop3d_scene.dart';
import 'town3d_view.dart';

/// Route `/` của bản thành phố (docs/v3/city-gd2-spec.md §3): phố 3D [Town3dView] nối với trạng thái phiên
/// ([CityGame]) và save v3 ([CitySaveStore]). Không bọc RefFrame / SLScope (ảnh 3D và vùng chạm theo điểm ảnh thật).
///
/// Tham số chạy thử đọc từ [CityDebugParams.raw] (web: query của URL; Android: `--es route '/?…'`):
/// - đồ hoạ như cảnh tiệm: `quality=auto|low|high`, `scale`, `fps`, `shadows`, `smap`, `post`, `aa`, `blob`, `soft`,
///   `ibl`, `tm`, `maxpx` (shop3d_quality.dart);
/// - ánh sáng nội thất: `sun` / `amb` / `fill` / `sky=<RRGGBB>`, `ambi=<n>`;
/// - `tex=producer|texture` (Android): nguồn texture của Thermion, áp một lần trước khi tạo viewer đầu tiên.
/// `spawn`, `debug`, `log`, `mochi` đã được [CityDebugParams] đọc sẵn.
///
/// Bảng cài đặt (nút bánh răng bên trái minimap): ngôn ngữ / âm thanh nối thẳng [CityGame.settings]; xoá dữ liệu →
/// `store.resetAll()` (giữ nguyên object ví, cài đặt) rồi đưa Mai về trước cửa tiệm của bà với kiểu tóc mặc định.
///
/// Ca bán (docs/v3/city-gd3-spec.md, GĐ3): "Mở ca" ở quầy tạo [ShiftSession] trên [CityGame]; lớp 2D là [ShiftLayer]
/// (quảng cáo qua `AppScope`); chưa từng mở ca thì view gợi ý mở ca khi vào tiệm.
class Town3dPage extends StatefulWidget {
  const Town3dPage({super.key, required this.game, required this.store, this.debug = CityDebugParams.none});

  final CityGame game;
  final CitySaveStore store;
  final CityDebugParams debug;

  @override
  State<Town3dPage> createState() => _Town3dPageState();
}

class _Town3dPageState extends State<Town3dPage> {
  /// `tex=` chỉ có tác dụng trước khi tạo viewer — áp một lần cho cả phiên.
  static bool _texApplied = false;

  late final Shop3dQualityMode _quality;
  late final Shop3dGraphicsOverrides _overrides;
  late final Shop3dSceneOptions _shopOptions;

  @override
  void initState() {
    super.initState();
    final q = widget.debug.raw;
    _applyTex(q['tex']);
    double? num(String k) => double.tryParse(q[k] ?? '');
    int? hex(String k) => switch (int.tryParse(q[k] ?? '', radix: 16)) {
          final v? => 0xFF000000 | v,
          _ => null,
        };
    _quality = Shop3dQualityMode.parse(q['quality']);
    _overrides = Shop3dGraphicsOverrides.fromParams(q);
    _shopOptions = Shop3dSceneOptions(
      mochi: widget.debug.mochi,
      sunArgb: hex('sun'),
      ambientArgb: hex('amb'),
      fillArgb: hex('fill'),
      skyArgb: hex('sky'),
      ambientIntensity: num('ambi'),
    );
  }

  static void _applyTex(String? tex) {
    if (tex == null || _texApplied) return;
    _texApplied = true;
    ThermionFlutterPlugin.instance.setOptions(
      ThermionFlutterOptions(
        nativeOptions: NativeOptions(
          androidTextureSource:
              tex == 'producer' ? AndroidTextureSource.surfaceProducer : AndroidTextureSource.surfaceTexture,
        ),
      ),
    );
  }

  Widget _settings(BuildContext context, TownSheetHost host) {
    final settings = widget.game.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => CitySettingsSheet(
        language: settings.language,
        sound: settings.sound,
        onLanguage: settings.setLanguage,
        onSound: settings.setSound,
        onReset: () async {
          try {
            await widget.store.resetAll();
          } finally {
            // Ví đã đặt lại tại chỗ (view đã nghe: cấp, kiểu tóc); chỉ còn đưa Mai về trước cửa tiệm của bà.
            host.respawn();
          }
        },
        onClose: host.close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game, debug = widget.debug;
    return Scaffold(
      body: Town3dView(
        wallet: game.wallet,
        levelSeen: game.levelSeen,
        onLevelSeen: game.markLevelSeen,
        settingsSheet: _settings,
        saveReadOnly: widget.store.locked,
        quality: _quality,
        graphicsOverrides: _overrides,
        showDebug: debug.showDebug,
        verbose: debug.verbose,
        spawn: debug.spawn,
        shopOptions: _shopOptions,
        openShift: () => ShiftSession(game: game),
        shiftLayer: (context, session, host) =>
            ShiftLayer(session: session, host: host, ads: AppScope.read(context).ads, game: game),
        shiftHint: game.bakery.shifts == 0,
      ),
    );
  }
}
