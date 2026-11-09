import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide KeyEvent, Material, Texture, Transform, View;

import '../../core/art/cake_art.dart';
import '../../core/branch/city_branches.dart';
import '../../core/branch/till_clock.dart' show ClockAnomaly;
import '../../core/catalog.dart';
import '../../core/city/city_config.dart';
import '../../core/city/city_wallet.dart';
import '../../core/city/mai_look.dart';
import '../../core/city/restaurant_menu.dart';
import '../../core/constants.dart';
import '../../core/shift/shift_host.dart';
import '../../core/shift/shift_session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/shop3d/action_cluster.dart';
import '../../ui/shop3d/joystick.dart';
import '../../ui/shop3d/shop3d_toasts.dart';
import '../../ui/town/branch_double_chip.dart';
import '../../ui/town/branch_sheet.dart';
import '../../ui/town/city_hud.dart';
import '../../ui/town/city_menu_button.dart';
import '../../ui/town/location_banner.dart';
import '../../ui/town/minimap.dart';
import '../../ui/town/realty_sheet.dart';
import '../../ui/town/restaurant_sheet.dart';
import '../../ui/town/salon_sheet.dart';
import '../../ui/town/town_fade.dart';
import '../../ui/town/town_l10n.dart';
import '../../ui/town/town_map_sheet.dart';
import '../logic/station_setup.dart';
import '../stations/frost_station.dart';
import '../stations/topping_station.dart';
import '../shop3d/chibi/chibi_actor.dart' show ChibiAction;
import '../shop3d/orbit_camera.dart' show degToRad;
import '../shop3d/shift/shift_binder.dart';
import '../shop3d/shift/shift_stage.dart';
import '../shop3d/shop3d_frame_driver.dart';
import '../shop3d/shop3d_layout.dart' show Shop3dRequires;
import '../shop3d/shop3d_pick.dart';
import '../shop3d/shop3d_quality.dart';
import '../shop3d/shop3d_scene.dart';
import '../shop3d/shop3d_surface.dart';
import '../shop3d/shop3d_view.dart';
import 'town_branch_cast.dart';
import 'town_branch_ui.dart';
import 'town_camera.dart';
import 'town_layout.dart';
import 'town_pilot.dart';
import 'town_rules.dart';
import 'town_scene.dart';
import 'town_unlock_notifier.dart';

/// Nơi bảng cài đặt ([Town3dView.settingsSheet]) gọi ngược về view.
abstract interface class TownSheetHost {
  /// Đóng bảng cài đặt.
  void close();

  /// Đưa Mai về trước cửa tiệm của bà, áp kiểu tóc đang có trong ví (sau khi xoá dữ liệu: mặc định). Không tạo lại
  /// viewer.
  void respawn();
}

/// Màn thành phố V3, giai đoạn 1 (docs/v3/city-gd1-spec.md): quận "Phố Tiệm Bánh" đi dạo được, vào / ra tiệm của bà,
/// quán ăn "Bếp Hải Đăng", tiệm tóc "Vỏ Sò", HUD xu / cấp, minimap + bản đồ lớn.
///
/// **Một ThermionViewer dùng chung** cho lớp phố ([TownScene]) và nội thất tiệm ([Shop3dScene] — giữ đèn / IBL / đồ họa
/// / material cho cả hai): tạo viewer chậm (web 10–20 s) nên không tạo lại khi vào tiệm. Lớp tiệm dựng nền (đang tắt)
/// sau khi phố hiện; lớp phố nằm xa gốc toạ độ ([TownScene.originX]) nên hai lớp không lọt khung nhìn của nhau. Vào
/// tiệm: mờ đen 0,4 s → gỡ lớp phố khỏi scene (không huỷ) → bật lớp tiệm → Mai ở khe cửa trong tiệm, điều khiển như
/// `?pilot=mai` (lớp phủ của [Shop3dView] ghép qua [Shop3dEmbed]) → sáng dần. Ra: nút A ở khe cửa (`townExitShop`)
/// hoặc bước ra vỉa hè → ngược lại, Mai đứng trước cửa `n2`.
///
/// Vòng cập nhật chạy trong request-frame hook của Filament như cảnh tiệm (docs/v3/thermion-api-notes.md mục 9.27):
/// không Ticker, Flutter chỉ dựng khung khi lớp phủ đổi (minimap vẽ lại ≤ 10 lần/s, nút A đổi theo vùng). Native: tự
/// vẽ + đếm khung bằng [Shop3dFrameDriver]. Chất lượng `auto` đo FPS vài giây rồi tự hạ mức (như cảnh tiệm); web có
/// trần điểm ảnh.
///
/// Điều khiển ngoài phố: joystick trái + nút A (theo vùng: vào tiệm / gọi món / làm tóc) + vẫy tay; bàn phím (web)
/// WASD / mũi tên đi, Shift chạy, E / Space = A, Q = vẫy. Kéo một ngón = xoay camera (±60° quanh hướng nhìn bắc), chụm /
/// con lăn = phóng (10–12 m), chạm đúp = về góc mặc định.
///
/// Giai đoạn 2 (docs/v3/city-gd2-spec.md): ví [CityWallet] do nơi gọi giữ và lưu (view không dispose). View nghe ví:
/// kiểu tóc đổi (kể cả do xoá dữ liệu) → áp lưới tóc; cấp đổi → minimap / bản đồ; lên cấp mở lô chi nhánh → toast
/// `townLotsUnlockedToast` sau hiệu ứng "Lên cấp" ([TownUnlockNotifier], trong tiệm thì giữ tới khi ra phố, xong gọi
/// [onLevelSeen]). Nút bánh răng bên trái minimap mở [settingsSheet]. [saveReadOnly] → toast `citySaveReadOnly` một lần.
///
/// Giai đoạn 3 (docs/v3/city-gd3-spec.md §2, §5) — ca bán trong tiệm của bà: Mai ở quầy → nút A "Mở ca" → mờ màn 0,4 s →
/// [openShift] tạo phiên, Mai thả đồ / đứng ở quầy thu ngân và bị khoá, Nora ra tủ kính, khách nền ngồi yên, camera đóng
/// khung quầy; [ShiftBinder] nối phiên với sân khấu 3D ([ShiftStage]); lớp 2D [shiftLayer] phủ cảnh (cùng route, sau
/// `LocationBanner`, trước lớp mờ). Lớp gọi [ShiftLayerHost]: `setBaking` dừng / chạy vẽ 3D (web `setRendering`, native
/// `Shop3dFrameDriver.paused`, bỏ vòng cập nhật tiệm, đo lại chất lượng `auto`), `close` gỡ lớp và mở khoá Mai. Trong ca
/// không ra phố được, phím của phố / tiệm trả `ignored`. [shiftHint]: mỗi lần vào tiệm (tới khi mở ca đầu) hiện toast
/// `shiftHintCounter` + mũi tên trên quầy.
///
/// Giai đoạn 4 (docs/v3/city-gd4-spec.md §4, §5) — văn phòng địa ốc, chi nhánh: [branches] (nơi gọi giữ, view nghe).
/// Quầy văn phòng địa ốc → A "Xem lô đất": Mai đứng ở quầy (`TownPilot.beginCounter`), camera cận, [RealtySheet]; mua →
/// toast, mặt tiền 3D + minimap đổi theo notify. Cửa chi nhánh đã mua → A "Thu tiền" (két ≥ 25% trần hoặc đầy: thu ngay,
/// toast, Mai vui, nhân viên vẫy, chip x2 [BranchDoubleChip] nếu được — quảng cáo qua [watchBranchAd]) hoặc "Chi nhánh"
/// (dưới mức đó: [BranchSheet] với camera cận nhìn mặt tiền, trong bảng vẫn thu được). Mỗi giây (bộ đếm FPS, ngoài build): két đầy → biểu tượng 3D +
/// huy hiệu minimap ([TownBranchMarks]), nhân viên đứng ở sân ([TownBranchCast.plan]), toast vắng nhà
/// ([CityBranches.takeAway], cả lúc phố vừa hiện).
///
/// Chip debug (chữ tiếng Anh, không qua AppLocalizations như cảnh tiệm): FPS · ui · mức · entity trong scene / đã tạo
/// (tĩnh) · material · tam giác · ms Dart mỗi khung · lệnh setTransform / bộ phận · thời gian chuyển cảnh gần nhất.
/// `?log=1`: in thêm pha ca bán và bố trí trạm mỗi lần làm bánh (`Shift bake open …`, cho script CDP).
class Town3dView extends StatefulWidget {
  const Town3dView({
    super.key,
    required this.wallet,
    this.levelSeen = 1,
    this.onLevelSeen,
    this.settingsSheet,
    this.saveReadOnly = false,
    this.quality = Shop3dQualityMode.auto,
    this.graphicsOverrides = const Shop3dGraphicsOverrides(),
    this.showDebug = false,
    this.verbose = false,
    this.spawn,
    this.shopOptions = const Shop3dSceneOptions(),
    this.openShift,
    this.shiftLayer,
    this.shiftHint = false,
    this.branches,
    this.watchBranchAd,
    this.canWatchBranchAd,
  });

  /// Ví của Mai (nơi gọi giữ; view không dispose).
  final CityWallet wallet;

  /// Cấp đã báo "mở lô" gần nhất (`CityGame.levelSeen`); cấp hiện tại cao hơn → phố báo bù.
  final int levelSeen;

  /// Mốc [levelSeen] đổi (đã báo xong, hoặc đặt lại khi cấp giảm).
  final ValueChanged<int>? onLevelSeen;

  /// Bảng cài đặt (phủ cả màn) mở bằng nút bánh răng; null = không có nút.
  final Widget Function(BuildContext context, TownSheetHost host)? settingsSheet;

  /// Save chỉ đọc (phiên này không lưu) → toast `citySaveReadOnly` một lần khi phố hiện.
  final bool saveReadOnly;
  final Shop3dQualityMode quality;
  final Shop3dGraphicsOverrides graphicsOverrides;
  final bool showDebug;
  final bool verbose;

  /// Chỗ Mai xuất hiện (toạ độ lớp phố, chụp màn hình / thử nhanh); null = trước cửa tiệm của bà.
  final ({double x, double z})? spawn;

  /// Tuỳ chọn nội thất (ánh sáng, Mochi…); kiểu tóc Mai lấy từ ví.
  final Shop3dSceneOptions shopOptions;

  /// Mở ca bán (bấm "Mở ca" ở quầy): phiên mới. null (hoặc [shiftLayer] null) = không có nút "Mở ca".
  final ShiftSession Function()? openShift;

  /// Lớp 2D của ca (phủ kín cảnh) cho phiên đang chạy; gọi `host.close()` để gỡ.
  final Widget Function(BuildContext context, ShiftSession session, ShiftLayerHost host)? shiftLayer;

  /// Chưa từng mở ca (`bakery.shifts == 0`): gợi ý mở ca khi vào tiệm.
  final bool shiftHint;

  /// Chi nhánh của Mai (GĐ4; nơi gọi giữ, view nghe, không dispose). null = phố không có chi nhánh / văn phòng địa ốc
  /// không bán lô.
  final CityBranches? branches;

  /// Xem quảng cáo thưởng "x2 lần thu" (`AdPlacement.branchDouble`); true = xem xong. null = không có chip x2.
  final Future<bool> Function(BuildContext context)? watchBranchAd;

  /// Còn lượt quảng cáo thưởng hôm nay (chip x2 chỉ hiện khi còn). null = coi như còn.
  final bool Function()? canWatchBranchAd;

  @override
  State<Town3dView> createState() => _Town3dViewState();
}

enum _Sheet { none, menu, salon, map, settings, realty, branch }

class _Town3dViewState extends State<Town3dView> implements TownSheetHost {
  /// Góc nhìn dọc (độ) — như cảnh tiệm (camera dùng chung, đặt bằng tiêu cự).
  static const fovDeg = 40.0;
  static const _near = 0.1;
  static const _far = 80.0;

  /// Nội thất dựng nền sau khi phố hiện chừng này (để phố kịp mượt trước).
  static const _interiorDelay = Duration(milliseconds: 1500);

  /// Vào tiệm khi nội thất chưa xong: chờ tối đa chừng này.
  static const _interiorTimeout = Duration(seconds: 90);

  /// Mở màn: chờ texture đầu của ảnh 3D tối đa chừng này rồi vẫn sáng màn.
  static const _textureWait = Duration(seconds: 5);

  final _layout = TownLayout.forDistrict(CityConfig.alpha.district('bakery_street'));
  CityWallet get _wallet => widget.wallet;
  final _cam = TownCamera();

  ThermionViewer? _viewer;
  Camera? _camera;
  Shop3dScene? _shop;
  TownScene? _town;
  TownPilot? _pilot;
  Shop3dEmbed? _embed;
  Shop3dFrameDriver? _driver;
  Object? _error;
  bool _disposed = false;

  /// Ảnh 3D ([Shop3dSurface]) đã chèn vào cây (cảnh dựng xong); texture đầu của nó.
  bool _shown = false;
  Completer<void>? _firstTexture;

  // Vòng cập nhật (request-frame hook).
  final _frameClock = Stopwatch();
  final _dartWatch = Stopwatch();
  double _dartMicros = 0;
  int _frameErrors = 0;
  bool _cameraDirty = true;
  bool _lookAtBusy = false;
  final _eye = Vector3.zero();
  final _focus = Vector3.zero();
  final _up = Vector3(0, 1, 0);
  final _basis = Shop3dCameraBasis();
  Size _size = Size.zero;

  // Trong tiệm / đang chuyển cảnh.
  bool _insideNow = false;
  final _inside = ValueNotifier<bool>(false);
  bool _busy = false;
  int? _transferMs;

  // Lớp phủ.
  final _joy = Shop3dJoystickController();
  final _toasts = Shop3dToastController();
  final _banner = LocationBannerController();
  final _fade = TownFadeController();
  final _keys = FocusNode(debugLabel: 'town3d');
  final _sheet = ValueNotifier<_Sheet>(_Sheet.none);
  final _maiPos = ValueNotifier<Offset>(Offset.zero);
  final _maiYaw = ValueNotifier<double>(0);
  final _waveLeft = ValueNotifier<double>(0);
  final _tada = ValueNotifier<(int, Offset)?>(null);
  int _tadaSerial = 0;
  Timer? _tadaTimer;
  Timer? _toastTimer;
  Offset? _doubleTapAt;

  /// Đang chuyển cảnh (cả lúc mở màn tới khi phố hiện): ẩn nút cài đặt, giữ toast mở lô.
  final _transit = ValueNotifier<bool>(true);

  // Nghe ví: cấp (minimap / bản đồ), toast mở lô, kiểu tóc.
  late final _playerLevel = ValueNotifier<int>(_wallet.level);
  late final _unlock = TownUnlockNotifier(_layout.district,
      level: _wallet.level, levelSeen: widget.levelSeen, onSeen: (l) => widget.onLevelSeen?.call(l));
  final _uptime = Stopwatch()..start();
  late MaiLook _look = _wallet.look;

  // FPS / chất lượng (như Shop3dView).
  int _frames = 0;
  int _lastRendered = 0;
  int _lastSkipped = 0;
  int _uiFrames = 0;
  final _fps = ValueNotifier<(int, int, int)>((0, 0, 0));
  Timer? _fpsTimer;
  late Shop3dQuality _level = widget.quality == Shop3dQualityMode.low ? Shop3dQuality.low : Shop3dQuality.high;
  Shop3dQualityProbe? _probe;
  bool _probeArmed = false;
  int? _refreshCap;
  double _renderScale = 1;
  int _logTick = 0;

  // Ca bán (GĐ3): phiên đang chạy (lớp 2D hiện khi khác null), sân khấu 3D (một cho cả view — khách ca trước còn đi
  // ra thì ca sau gỡ ngay), bộ nối, đang làm bánh (3D dừng vẽ).
  final _shift = ValueNotifier<ShiftSession?>(null);
  ShiftStage? _stage;
  ShiftBinder? _binder;
  bool _baking = false;
  late final _shiftHost = _ShiftHost(this);

  // Chi nhánh (GĐ4): dữ liệu minimap, nút A "Thu tiền" / "Chi nhánh" ở cửa chi nhánh, lô của bảng chi nhánh đang mở,
  // nhịp 1 Hz cho bảng (két tăng theo giờ, không notify), chip x2, hàng toast vắng nhà.
  CityBranches? get _branches => widget.branches;
  final _marks = ValueNotifier<TownBranchMarks>(TownBranchMarks.none);
  final _collectable = ValueNotifier<bool>(false);
  String? _branchLot;
  int _sheetCollect = 0;
  final _sheetTick = ValueNotifier<int>(0);
  final _double = ValueNotifier<({int serial, String lot, int coins})?>(null);
  int _doubleSerial = 0;
  final _awayQueue = <String>[];
  Timer? _awayTimer;

  Shop3dGraphics get _graphics {
    final preset = Shop3dGraphics.preset(_level);
    return widget.graphicsOverrides.apply(kIsWeb ? preset.forWeb() : preset);
  }

  /// Đồ họa ngoài phố: như [_graphics] nhưng (nếu mức đang dùng bật bóng động) bóng PCF thay DPCF — phố có camera cận
  /// (tiệm tóc, ngồi ăn) mà DPCF tốn và dễ lộ răng cưa ở cận cảnh; PCF rẻ hơn. Trong tiệm trả lại [_graphics] (như cảnh
  /// tiệm cũ). Ghi đè `?soft=1` vẫn được tôn trọng. (04/11: cả hai mức đều tắt bóng động — chỉ bóng tròn — nên hiện
  /// không khác gì.)
  Shop3dGraphics get _streetGraphics {
    final g = _graphics;
    return widget.graphicsOverrides.softShadows == true ? g : g.copyWith(softShadows: false);
  }

  /// Đồ họa của lớp đang hiện.
  Shop3dGraphics get _activeGraphics => _insideNow ? _graphics : _streetGraphics;

  int get _targetFps {
    final fps = _graphics.targetFps;
    return fps > 0 ? fps : (_refreshCap ?? 0);
  }

  AppLocalizations? get _l10n => Localizations.of<AppLocalizations>(context, AppLocalizations);

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_onWallet);
    _branches?.addListener(_onBranches);
    // Mốc đã chuẩn hoá (cấp giảm / không lô nào mở) → lưu lại sau khung đầu (không notify giữa lúc dựng cây widget).
    if (_unlock.seen != widget.levelSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) widget.onLevelSeen?.call(_unlock.seen);
      });
    }
    // Màn đen tới khi phố dựng xong (sau 1 s chưa xong → "Đang mở cửa…").
    unawaited(_fade.fadeOut());
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
      ThermionFlutterPlugin.instance.setTargetFramerate(_targetFps);
      if (widget.quality == Shop3dQualityMode.auto) _probe = Shop3dQualityProbe();
      // Hook cập nhật đăng ký TRƯỚC hook vẽ của driver (native) — cập nhật xong rồi mới vẽ cùng khung.
      await viewer.app.registerRequestFrameHook(_frameHook);
      if (Shop3dFrameDriver.supported) {
        final driver = Shop3dFrameDriver(viewer);
        await driver.start();
        _driver = driver;
      }
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sampleFps());
      final camera = await viewer.getActiveCamera();
      final aspect = _size.isEmpty ? 16 / 9 : _size.width / _size.height;
      await camera.setLensProjection(
          near: _near, far: _far, focalLength: 12.0 / math.tan(fovDeg * math.pi / 360.0), aspect: aspect);
      _camera = camera;
      // Đèn + IBL + đồ họa + material: lớp tiệm (chưa dựng nội thất, đang tắt) giữ cho cả viewer.
      final look = _wallet.look;
      final o = widget.shopOptions;
      final shop = await Shop3dScene.build(
        viewer,
        owned: const {Shop3dRequires.cafeTables},
        options: Shop3dSceneOptions(
          verbose: widget.verbose,
          mochi: o.mochi,
          sunArgb: o.sunArgb,
          ambientArgb: o.ambientArgb,
          fillArgb: o.fillArgb,
          skyArgb: o.skyArgb,
          ambientIntensity: o.ambientIntensity,
          maiLook: look,
        ),
        graphics: _streetGraphics,
        deferContent: true,
        active: false,
      );
      if (_disposed) return;
      _shop = shop;
      unawaited(shop.setShadowFar(_streetShadowFar));
      final pilot = _pilot = TownPilot(_layout, _wallet, look: look);
      pilot.hud.addListener(_updateCollectable);
      final sp = widget.spawn;
      if (sp != null) pilot.placeAt(sp.x, sp.z, _layout.spawn.yaw);
      final town = await TownScene.build(
        viewer,
        layout: _layout,
        materials: shop,
        pilot: pilot,
        look: look,
        graphics: _graphics,
        verbose: widget.verbose,
      );
      if (_disposed) return;
      _town = town;
      // Mặt tiền chi nhánh theo cấp (lô trống = 0) dựng xong trước khi phố hiện.
      await _syncBranches(town, pilot);
      if (_disposed) return;
      _cam.snapTo(pilot.mai.pose.x, pilot.mai.pose.z);
      _cameraDirty = true;
      final shifts = widget.openShift != null && widget.shiftLayer != null;
      final stage = _stage = ShiftStage(shop);
      _embed = Shop3dEmbed(
        viewer: viewer,
        scene: shop,
        onExit: () => unawaited(_exitShop()),
        atDoor: TownRules.atShopDoor,
        outside: TownRules.outsideShop,
        atCounter: shifts ? TownRules.atShopCounter : null,
        onOpenShift: shifts ? () => unawaited(_openShift()) : null,
      )
        ..shiftHint = shifts && widget.shiftHint
        ..onTick = stage.update;
      // Ảnh 3D chèn vào cây chỉ khi cảnh đã dựng xong (dưới màn đen, luồng chính rảnh): chèn sớm rồi dựng cảnh nặng thì
      // trên web platform view của canvas chưa kịp vào DOM lúc widget xin texture → "Failed to size for canvas", cảnh
      // trống. Chờ texture đầu ([Shop3dSurface] tự xin lại nếu hỏng) rồi mới sáng màn; quá [_textureWait] vẫn sáng.
      final texture = _firstTexture = Completer<void>();
      _shown = true;
      if (mounted) setState(() {});
      await texture.future.timeout(_textureWait, onTimeout: () {});
      if (_disposed) return;
      await _fade.fadeIn();
      if (_disposed) return;
      _transit.value = false;
      final l = _l10n;
      if (l != null) _banner.show(cityText(l, _layout.district.nameKey));
      if (widget.saveReadOnly && l != null) {
        _toasts.show(l.citySaveReadOnly, icon: Icons.info_outline_rounded, duration: const Duration(seconds: 5));
      }
      _pumpAway();
      _probeArmed = true;
      // Nội thất dựng nền (lớp tiệm tắt, ở gốc toạ độ — xa lớp phố). Embed tự gắn điều khiển khi nhân vật xong.
      await Future<void>.delayed(_interiorDelay);
      if (_disposed) return;
      final sw = Stopwatch()..start();
      await shop.buildContent();
      await shop.actorsReady;
      if (widget.verbose) debugPrint('Town3dView: interior ready in ${sw.elapsedMilliseconds} ms');
    } catch (e, st) {
      debugPrint('Town3dView init failed: $e\n$st');
      if (mounted) setState(() => _error = e);
      unawaited(_fade.fadeIn());
    }
  }

  // ---- FPS / chất lượng ---------------------------------------------------------------------------------------

  void _onTimings(List<FrameTiming> timings) => _uiFrames += timings.length;

  void _sampleFps() {
    final driver = _driver;
    final int filament;
    var skipped = 0;
    if (driver != null) {
      filament = driver.rendered - _lastRendered;
      skipped = driver.skipped - _lastSkipped;
      _lastRendered = driver.rendered;
      _lastSkipped = driver.skipped;
    } else {
      filament = _frames;
      _frames = 0;
    }
    _fps.value = (filament, skipped, _uiFrames);
    _uiFrames = 0;
    _branchTick();
    // ?log=1: in chip debug mỗi 5 s (đo tự động qua console, khỏi đọc ảnh).
    if (widget.verbose && ++_logTick % 5 == 0) debugPrint('Town3dView: ${_debugText(_fps.value)}');
    final probe = _probe;
    if (probe == null || !_probeArmed) return;
    // Đang làm bánh (3D dừng vẽ, Flame chiếm luồng chính) → số khung không phản ánh máy; đo lại từ đầu.
    if (_baking) {
      _probe = Shop3dQualityProbe();
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed && state != AppLifecycleState.inactive) {
      _probe = Shop3dQualityProbe();
      return;
    }
    final pick = probe.addSecond(filament);
    if (pick == null) return;
    _probe = null;
    _refreshCap = pick == Shop3dQuality.high ? probe.highRefreshCap() : null;
    if (widget.verbose) debugPrint('Town3dView: probe ${probe.averageFps.toStringAsFixed(1)} fps → ${pick.name}');
    if (pick != _level) {
      _level = pick;
      final g = _activeGraphics;
      ThermionFlutterPlugin.instance.setTargetFramerate(_targetFps);
      unawaited(_shop?.applyGraphics(g));
      _town?.applyGraphics(g);
      if (mounted) setState(() {});
    } else if (_refreshCap != null) {
      ThermionFlutterPlugin.instance.setTargetFramerate(_targetFps);
    }
  }

  // ---- Vòng cập nhật ------------------------------------------------------------------------------------------

  Future<void> _frameHook() async {
    _frames++;
    try {
      _onFrame();
    } catch (e, st) {
      // Không để lỗi lọt ra: FilamentApp.render bọc cả vòng hook trong một try (hook vẽ của driver phía sau bị bỏ).
      if (_frameErrors++ == 0) debugPrint('Town3dView: frame update failed: $e\n$st');
    }
  }

  /// Mỗi khung Filament: trong tiệm → vòng của [Shop3dView] ghép; ngoài phố → camera, Mai, chủ quán, lớp phủ.
  void _onFrame() {
    if (_disposed) return;
    final embed = _embed;
    if (_insideNow && embed != null) {
      // Đang làm bánh: 3D dừng vẽ → bỏ luôn vòng cập nhật của tiệm.
      if (!_baking) embed.frame();
      return;
    }
    final first = !_frameClock.isRunning;
    final dt = first ? 1 / 60 : math.min(0.1, _frameClock.elapsedMicroseconds / 1e6);
    _frameClock
      ..reset()
      ..start();
    _dartWatch
      ..reset()
      ..start();
    final pilot = _pilot, town = _town;
    if (pilot != null && town != null && town.active) {
      final v = _joy.value.value;
      final blocked = _sheet.value != _Sheet.none;
      pilot
        ..cameraYaw = _cam.yaw
        ..setStick(blocked ? 0 : v.dx, blocked ? 0 : v.dy, running: !blocked && _joy.running.value);
      town.tick(dt);
      final events = pilot.takeEvents();
      if (events.isNotEmpty) _onEvents(events);
      // Ngồi ăn (món đã lên bàn): camera lia cận ba phần tư về phía mặt Mai + món; ăn xong trả về camera phố.
      final eating = pilot.mode == TownMode.eating && pilot.dishVisible;
      if (eating != _eatingClose) {
        _eatingClose = eating;
        _setCloseUp(eating ? _eatingCloseUp(pilot) : null);
      }
      final m = pilot.mai.pose;
      if (_cam.update(dt, m.x, m.z)) _cameraDirty = true;
      if (_tada.value != null) _trackTada(pilot);
      final p = _maiPos.value;
      if ((p.dx - m.x).abs() + (p.dy - m.z).abs() > 0.05) _maiPos.value = Offset(m.x, m.z);
      if ((wrapYaw(_maiYaw.value - m.yaw)).abs() > 0.05) _maiYaw.value = m.yaw;
      final w = pilot.waveLeft;
      if ((w - _waveLeft.value).abs() > 0.02 || (w == 0 && _waveLeft.value != 0)) _waveLeft.value = w;
      if (_unlock.pending) _pumpUnlock(pilot);
    }
    if (_cameraDirty) _pushCamera();
    _dartWatch.stop();
    final us = _dartWatch.elapsedMicroseconds.toDouble();
    _dartMicros = _dartMicros == 0 ? us : _dartMicros * 0.95 + us * 0.05;
  }

  static double wrapYaw(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    return r;
  }

  /// Camera phố → Filament (dời gốc lớp phố; tối đa một lệnh đang chờ).
  void _pushCamera() {
    final camera = _camera;
    if (camera == null || _lookAtBusy) return;
    _cameraDirty = false;
    _lookAtBusy = true;
    _eye.setValues(_cam.eye.x + TownScene.originX, _cam.eye.y, _cam.eye.z + TownScene.originZ);
    _focus.setValues(_cam.target.x + TownScene.originX, _cam.target.y, _cam.target.z + TownScene.originZ);
    camera.lookAt(_eye, focus: _focus, up: _up).whenComplete(() => _lookAtBusy = false);
  }

  void _onEvents(List<TownEvent> events) {
    final l = _l10n;
    if (l == null) return;
    for (final e in events) {
      switch (e.kind) {
        case TownEventKind.banner:
          final lot = e.lot!;
          final v = _branches?.view(lot.id);
          final b = TownRules.bannerFor(lot, _wallet.level, owned: v != null);
          _banner.show(
            v != null ? l.townBranchN(v.branchNo) : cityText(l, b.nameKey),
            subtitle: switch (b.note) {
              TownBannerNote.none => null,
              TownBannerNote.comingSoon => l.townComingSoon,
              TownBannerNote.locked => l.townLotLocked(b.level),
              TownBannerNote.unlocked => l.townLotUnlocked,
              TownBannerNote.branch => v == null
                  ? null
                  : v.full
                      ? l.branchBannerFull(v.level)
                      : l.branchBannerTill(v.level, v.till, v.cap),
            },
          );
        case TownEventKind.firstVisit:
          _toasts.show('${l.cityFirstVisit} · ${l.cityXpGain(CityWallet.firstVisitXp)}', icon: Icons.star_rounded);
        case TownEventKind.eatingStart:
          _toasts.show(l.cityEating,
              icon: Icons.restaurant_rounded,
              duration: Duration(milliseconds: (TownPilot.eatSeconds * 1000).round()));
        case TownEventKind.eatingDone:
          final r = e.eat;
          _toasts.show('${l.cityXpGain(r?.xpGained ?? 0)} · ${l.cityBuffFull}', icon: Icons.favorite_rounded);
          _toastTimer?.cancel();
          if (r != null && r.reducedXp) {
            _toastTimer = Timer(const Duration(milliseconds: 2400), () {
              final l2 = _l10n;
              if (l2 != null && mounted) _toasts.show(l2.cityAteToday, icon: Icons.info_outline_rounded);
            });
          }
        case TownEventKind.tada:
          _showTada();
      }
    }
  }

  /// "Ta-da": chùm sao lấp lánh quanh đầu Mai (~1,2 s) khi mua kiểu tóc; camera giữ cận tới khi xong.
  void _showTada() {
    final pilot = _pilot;
    final p = pilot == null || _size.isEmpty ? null : _headOnScreen(pilot);
    if (p == null) {
      _setCloseUp(null);
      return;
    }
    _tada.value = (++_tadaSerial, p);
    _tadaTimer?.cancel();
    _tadaTimer = Timer(_tadaDuration, () {
      if (!mounted) return;
      _tada.value = null;
      if (_sheet.value == _Sheet.none && !_eatingClose) _setCloseUp(null);
    });
  }

  static const _tadaDuration = Duration(milliseconds: 1400);

  Offset? _headOnScreen(TownPilot pilot) {
    final top = TownScene.topOf(pilot.mai);
    _basis.set(_cam.eye, _cam.target, fovDeg, _size.width, _size.height);
    final p = _basis.project(top.x, top.y, top.z);
    return p == null ? null : Offset(p.x, p.y);
  }

  /// Chùm sao bám đầu Mai (Mai nhảy vui, camera còn lia nhẹ) — chỉ báo khi lệch > 1 px.
  void _trackTada(TownPilot pilot) {
    final t = _tada.value;
    if (t == null || _size.isEmpty) return;
    final p = _headOnScreen(pilot);
    if (p != null && (p - t.$2).distance > 1) _tada.value = (t.$1, p);
  }

  // ---- Góc cận + giới hạn bóng --------------------------------------------------------------------------------

  /// Bóng động trong bao xa (m) ngoài phố / khi camera cận (mặt đất của quận có hộp bao rất lớn — xem
  /// `Shop3dScene.setShadowFar`); trong tiệm: 0 = như cảnh tiệm cũ.
  static const double _streetShadowFar = 30;
  static const double _closeShadowFar = 14;

  bool _eatingClose = false;

  void _setCloseUp(TownCloseUp? c) {
    _cam.closeUp = c;
    unawaited(_shop?.setShadowFar(c == null ? _streetShadowFar : _closeShadowFar));
  }

  /// Góc cận khi ngồi ăn: ba phần tư phía trước Mai (lệch về phía đường), thấy món trên bàn trước mặt.
  TownCloseUp _eatingCloseUp(TownPilot pilot) {
    final m = pilot.mai.pose, d = pilot.dishPose;
    return TownCloseUp(
      x: (m.x + d.x) / 2,
      y: 0.72,
      z: (m.z + d.z) / 2,
      yaw: wrapYaw(d.yaw + math.pi - 0.6),
      pitch: degToRad(30),
      distance: 4.4,
    );
  }

  /// Góc khi xem thực đơn: Mai ở phần trái màn (bảng chiếm mép phải), nhìn thấy chủ quán sau ô cửa.
  TownCloseUp _menuCloseUp(TownPilot pilot) {
    final m = pilot.mai.pose;
    return TownCloseUp(x: m.x + 1.7, y: 0.9, z: m.z - 0.4, yaw: 0, pitch: degToRad(36), distance: 8);
  }

  // ---- Thao tác -----------------------------------------------------------------------------------------------

  void _pressA() {
    final pilot = _pilot;
    if (pilot == null || _busy || _sheet.value != _Sheet.none || !pilot.hud.value.controls) return;
    _double.value = null;
    switch (pilot.action) {
      case TownAction.enterShop:
        unawaited(_enterShop());
      case TownAction.orderFood:
        _joy.reset();
        pilot.beginMenu();
        _setCloseUp(_menuCloseUp(pilot));
        _sheet.value = _Sheet.menu;
      case TownAction.getHaircut:
        _openSalon();
      case TownAction.realty:
        _openRealty(pilot);
      case TownAction.branch:
        _pressBranch(pilot);
      case TownAction.none:
        break;
    }
  }

  void _wave() => _pilot?.wave();

  void _closeMenu() {
    if (_sheet.value != _Sheet.menu) return;
    _sheet.value = _Sheet.none;
    _setCloseUp(null);
    _pilot?.endMenu();
  }

  /// Gọi món: ví trừ xu (thiếu xu → bảng tự báo, giữ nguyên); được → đóng bảng, Mai đi tới ghế hiên.
  void _order(Dish dish) {
    final r = _pilot?.order(dish);
    if (r == null || !r.ok) return;
    _sheet.value = _Sheet.none;
    _setCloseUp(null);
  }

  void _openSalon() {
    final pilot = _pilot, town = _town;
    if (pilot == null || town == null) return;
    _joy.reset();
    pilot.beginSalon();
    final cur = _wallet.look;
    // Kiểu tóc cùng màu hiện tại dựng sẵn (bấm xem trước là đổi ngay); màu khác dựng khi bấm.
    town.prepareLooks([for (final h in MaiHair.values) cur.copyWith(hair: h)]);
    final m = pilot.mai.pose;
    const yaw = TownPilot.salonFaceYaw;
    // Camera lia sát Mai, nhìn chính diện ba phần tư; điểm nhìn lệch phải (bảng chiếm mép phải) để Mai ở phần trái.
    const shift = 0.62;
    _setCloseUp(TownCloseUp(
      x: m.x + math.cos(yaw) * shift,
      y: 0.92,
      z: m.z - math.sin(yaw) * shift,
      yaw: yaw,
      pitch: degToRad(12),
      distance: 3.3,
    ));
    _sheet.value = _Sheet.salon;
  }

  /// Đóng bảng làm tóc. Vừa mua kiểu mới: camera giữ cận cho "ta-da" rồi mới lia ra ([_showTada]).
  void _closeSalon({required bool bought}) {
    if (_sheet.value != _Sheet.salon) return;
    _sheet.value = _Sheet.none;
    if (!bought) _setCloseUp(null);
    _pilot?.endSalon(bought: bought);
  }

  void _salonPreview(MaiLook look) => unawaited(_town?.setMaiLook(look));

  void _salonConfirm(MaiLook look) {
    final before = _wallet.look;
    if (!_wallet.buyLook(look)) return; // thiếu xu: giữ bảng
    unawaited(_town?.setMaiLook(look));
    _closeSalon(bought: look != before);
  }

  void _salonCancel() {
    unawaited(_town?.setMaiLook(_wallet.look));
    _closeSalon(bought: false);
  }

  void _openMap() {
    if (_insideNow || _busy) return;
    _joy.reset();
    if (_sheet.value == _Sheet.none) _sheet.value = _Sheet.map;
  }

  void _closeMap() {
    if (_sheet.value == _Sheet.map) _sheet.value = _Sheet.none;
  }

  void _openSettings() {
    final pilot = _pilot;
    if (pilot == null || widget.settingsSheet == null || _insideNow || _busy) return;
    if (_sheet.value != _Sheet.none || !pilot.hud.value.controls) return;
    _joy.reset();
    _sheet.value = _Sheet.settings;
    // Nhả focus của view: bảng tự giữ focus (autofocus) để Esc đi qua bảng — bảng không đóng khi đang xác nhận xoá.
    _keys.unfocus();
  }

  @override
  void close() {
    if (_disposed || _sheet.value != _Sheet.settings) return;
    _sheet.value = _Sheet.none;
    _keys.requestFocus();
  }

  @override
  void respawn() {
    final pilot = _pilot;
    if (_disposed || pilot == null || _insideNow) return;
    final s = _layout.spawn;
    _joy.reset();
    pilot.placeAt(s.x, s.z, s.yaw);
    _setCloseUp(null);
    _cam.snapTo(s.x, s.z);
    _cameraDirty = true;
    _maiPos.value = Offset(s.x, s.z);
    _maiYaw.value = s.yaw;
    _look = _wallet.look;
    unawaited(_town?.setMaiLook(_look));
  }

  // ---- Nghe ví ------------------------------------------------------------------------------------------------

  /// Ví đổi: cấp → minimap / bản đồ + hàng toast mở lô; kiểu tóc (mua ở tiệm tóc, xoá dữ liệu) → lưới tóc ngoài phố
  /// (trong tiệm áp lúc vào, [_enterShop]).
  void _onWallet() {
    final level = _wallet.level;
    _playerLevel.value = level;
    _unlock.levelChanged(level, _uptime.elapsed);
    final look = _wallet.look;
    if (look != _look) {
      _look = look;
      unawaited(_town?.setMaiLook(look));
    }
  }

  /// Toast mở lô (gọi mỗi khung ngoài phố khi còn chờ): chỉ khi phố đã hiện hẳn, Mai đang đi dạo, không bảng nào mở và
  /// không toast nào đang hiện / sắp hiện — để không đè toast ăn uống, ghé lần đầu.
  void _pumpUnlock(TownPilot pilot) {
    if (_transit.value || _busy || _sheet.value != _Sheet.none || !pilot.hud.value.controls) return;
    if (_toasts.current.value != null || (_toastTimer?.isActive ?? false) || (_awayTimer?.isActive ?? false)) return;
    final l = _l10n;
    if (l == null) return;
    final lots = _unlock.take(_uptime.elapsed);
    if (lots.isNotEmpty) _toasts.show(l.townLotsUnlockedToast(lots.length), icon: Icons.lock_open_rounded);
  }

  // ---- Chi nhánh (GĐ4) ----------------------------------------------------------------------------------------

  /// Đồng bộ phố với [CityBranches]: cấp mặt tiền mọi lô chi nhánh (scene bỏ qua lô không đổi cấp; chưa mua = 0), lô
  /// đã mua cho nút A, minimap, biểu tượng két đầy, nhân viên ở sân. Hoàn tất khi mặt tiền đã dựng (lần đầu: trước khi
  /// phố hiện). Không có [Town3dView.branches] → mọi lô là lô trống.
  Future<void> _syncBranches(TownScene town, TownPilot pilot) {
    final b = _branches;
    if (b == null) {
      return Future.wait([
        for (final lot in _layout.district.lots)
          if (lot.kind == LotKind.branch) town.setBranchLevel(lot.id, 0),
      ]);
    }
    pilot.ownedLots = b.owned.toSet();
    _refreshBranches(b, town, pilot);
    return Future.wait([
      for (final e in TownBranchUi.levels(_layout.district, b).entries) town.setBranchLevel(e.key, e.value),
      // Chibi của mọi nhân viên đang làm dựng sẵn (lần đầu: dưới màn đen; sau đó: lúc thuê) — vào sân chỉ còn thêm vào
      // scene, không giật khi Mai đi tới gần lô.
      town.prepareStaff({
        for (final m in b.staff)
          if (TownBranchCast.chibiOf[m.id] case final c?) c,
      }),
    ]);
  }

  /// [CityBranches] notify (mua, nâng cấp, thuê, thu tiền, xoá dữ liệu…).
  void _onBranches() {
    final town = _town, pilot = _pilot;
    if (_disposed || town == null || pilot == null) return;
    unawaited(_syncBranches(town, pilot));
  }

  /// Mỗi giây (bộ đếm FPS — ngoài build): két tăng theo giờ mà không notify → biểu tượng / minimap / nút A; nhân viên
  /// theo vị trí Mai; bảng chi nhánh dựng lại khi số đang hiện đổi (web: mỗi lần dựng lại bảng, CanvasKit vẽ lại cả
  /// bảng — tốn ~1 khung); toast vắng nhà.
  void _branchTick() {
    final b = _branches, town = _town, pilot = _pilot;
    if (b == null || town == null || pilot == null || _disposed) return;
    _refreshBranches(b, town, pilot);
    final lot = _sheetBranchLot;
    final v = lot == null ? null : b.view(lot);
    if (v != null) {
      final key = (v.till, v.full, v.fullIn.inMinutes);
      if (key != _sheetKey) {
        _sheetKey = key;
        _sheetTick.value++;
      }
    }
    _pumpAway();
  }

  (int, bool, int)? _sheetKey;

  void _refreshBranches(CityBranches b, TownScene town, TownPilot pilot) {
    final marks = TownBranchUi.marks(b);
    if (marks != _marks.value) _marks.value = marks;
    town.setFullIcons(marks.full);
    final m = pilot.mai.pose;
    town.setBranchActors(TownBranchCast.plan(_layout, TownBranchUi.staffByLot(b.staff), m.x, m.z,
        focusLot: _sheet.value == _Sheet.branch ? _branchLot : null));
    _updateCollectable();
  }

  /// Nút A ở cửa chi nhánh: "Thu tiền" khi két ≥ 25% trần hoặc đầy (gọi khi vùng đổi, mỗi giây, sau khi thu).
  void _updateCollectable() {
    if (_disposed) return;
    final hud = _pilot?.hud.value;
    final lot = hud?.action == TownAction.branch ? hud?.lotId : null;
    _collectable.value = TownBranchUi.collectable(lot == null ? null : _branches?.view(lot));
  }

  /// Toast vắng nhà / quản lý gửi về / giờ máy lùi ([CityBranches.takeAway]): chỉ ngoài phố khi phố đã hiện (trong tiệm
  /// để dành tới khi ra); nối tiếp nhau, chờ toast khác đang hiện xong.
  void _pumpAway() {
    final b = _branches, l = _l10n;
    if (b == null || l == null || _insideNow || _transit.value) return;
    _awayQueue.addAll(TownBranchUi.awayToasts(l, b.takeAway()));
    _showAwayNext();
  }

  void _showAwayNext() {
    if (_disposed || _awayQueue.isEmpty || (_awayTimer?.isActive ?? false)) return;
    if (_toasts.current.value != null) {
      _awayTimer = Timer(const Duration(milliseconds: 600), _showAwayNext);
      return;
    }
    _toasts.show(_awayQueue.removeAt(0), icon: Icons.savings_rounded, duration: TownBranchUi.awayToastDuration);
    _awayTimer = Timer(TownBranchUi.awayToastDuration + const Duration(milliseconds: 250), _showAwayNext);
  }

  /// Quầy văn phòng địa ốc: Mai đứng ở quầy, chủ văn phòng nói chuyện, camera cận như quầy quán ăn, bảng lô đất.
  void _openRealty(TownPilot pilot) {
    if (_branches == null) return;
    _joy.reset();
    pilot.beginCounter();
    _setCloseUp(_menuCloseUp(pilot));
    _sheet.value = _Sheet.realty;
  }

  void _closeRealty() {
    if (_sheet.value != _Sheet.realty) return;
    _sheet.value = _Sheet.none;
    _setCloseUp(null);
    _pilot?.endCounter();
    _keys.requestFocus();
  }

  /// Mua lô (bảng đã xác nhận): được → đóng bảng, toast "Chi nhánh n khai trương!" (mặt tiền + minimap đổi theo notify).
  void _realtyBuy(String lotId) {
    final b = _branches, l = _l10n;
    if (b == null || l == null) return;
    switch (b.buy(lotId)) {
      case BranchBuy.ok:
        _closeRealty();
        _toasts.show(l.branchOpenedToast(_layout.district.branchNumber(lotId)), icon: Icons.storefront_rounded);
      case BranchBuy.notEnoughCoins:
        _toasts.show(l.cityNotEnoughCoins, icon: Icons.info_outline_rounded);
      case BranchBuy.notBranch:
      case BranchBuy.owned:
      case BranchBuy.levelTooLow:
        break;
    }
  }

  /// A ở cửa chi nhánh đã mua: két ≥ 25% trần hoặc đầy ([TownBranchUi.collectable]) → thu ngay (toast, Mai vui, nhân
  /// viên vẫy, chip x2 nếu được); dưới mức đó → bảng chi nhánh (trong bảng vẫn thu được).
  void _pressBranch(TownPilot pilot) {
    final b = _branches, lot = pilot.hud.value.lotId;
    if (b == null || lot == null) return;
    final c = TownBranchUi.collectable(b.view(lot)) ? b.collect(lot) : null;
    if (c == null || !c.ok) {
      _openBranch(pilot, lot);
      return;
    }
    _celebrateCollect(lot, c.coins);
    _offerDouble(lot, c.coins);
  }

  void _celebrateCollect(String lot, int coins) {
    final l = _l10n;
    if (l != null) _toasts.show(l.branchCollectedToast(coins), icon: Icons.savings_rounded);
    _pilot?.mai.perform(ChibiAction.happy, 1.2, freeze: 0);
    _town?.waveBranch(lot);
    _updateCollectable();
  }

  /// Chip x2 trên nút A (8 s) nếu lần thu này được x2 và còn lượt quảng cáo hôm nay.
  void _offerDouble(String lot, int coins) {
    final b = _branches;
    if (b == null || widget.watchBranchAd == null || !b.canDouble(lot)) return;
    if (!(widget.canWatchBranchAd?.call() ?? true)) return;
    _double.value = (serial: ++_doubleSerial, lot: lot, coins: coins);
  }

  Future<void> _watchDouble(String lot) async {
    final watch = widget.watchBranchAd, b = _branches;
    _double.value = null;
    if (watch == null || b == null) return;
    var watched = false;
    try {
      watched = await watch(context);
    } catch (e) {
      debugPrint('Town3dView: branch ad failed: $e');
    }
    final l = _l10n;
    if (!mounted || _disposed || l == null) return;
    if (!watched) {
      _toasts.show((widget.canWatchBranchAd?.call() ?? true) ? l.adNotCompleted : l.adsLimitReached,
          icon: Icons.info_outline_rounded);
      return;
    }
    final add = b.applyDouble(lot);
    if (add > 0) _toasts.show(l.branchCollectedToast(add), icon: Icons.savings_rounded);
  }

  /// Bảng chi nhánh: Mai quay vào lô, camera cận nhìn mặt tiền từ phía đường ([TownBranchUi.closeUp]); nhân viên của lô
  /// đứng ở sân dù Mai ở xa ([TownBranchCast.plan] `focusLot`).
  void _openBranch(TownPilot pilot, String lot) {
    final b = _branches, town = _town;
    if (b == null || town == null) return;
    final def = _layout.district.lot(lot);
    _joy.reset();
    _branchLot = lot;
    _sheetCollect = 0;
    pilot.mai.driveFace(def.z > 0 ? 0 : math.pi);
    _setCloseUp(TownBranchUi.closeUp(def));
    _sheet.value = _Sheet.branch;
    _refreshBranches(b, town, pilot);
  }

  /// Đóng bảng chi nhánh; vừa thu trong bảng mà được x2 → chip x2 trên nút A.
  void _closeBranch() {
    if (_sheet.value != _Sheet.branch) return;
    final lot = _branchLot, collected = _sheetCollect;
    _sheet.value = _Sheet.none;
    _branchLot = null;
    _sheetCollect = 0;
    _setCloseUp(null);
    _keys.requestFocus();
    if (lot != null && collected > 0) _offerDouble(lot, collected);
  }

  String? get _sheetBranchLot => _sheet.value == _Sheet.branch ? _branchLot : null;

  void _branchCollect() {
    final b = _branches, lot = _sheetBranchLot;
    if (b == null || lot == null) return;
    final c = b.collect(lot);
    if (!c.ok) return;
    _sheetCollect = c.coins;
    _celebrateCollect(lot, c.coins);
  }

  void _branchUpgrade() {
    final b = _branches, lot = _sheetBranchLot, l = _l10n;
    if (b == null || lot == null || l == null) return;
    switch (b.upgrade(lot)) {
      case BranchUpgrade.ok:
        final v = b.view(lot);
        if (v != null) _toasts.show(l.branchUpgradedToast(v.branchNo, v.level), icon: Icons.upgrade_rounded);
      case BranchUpgrade.notEnoughCoins:
        _toasts.show(l.cityNotEnoughCoins, icon: Icons.info_outline_rounded);
      case BranchUpgrade.notOwned:
      case BranchUpgrade.maxLevel:
      case BranchUpgrade.levelTooLow:
        break;
    }
  }

  void _branchHire(String staffId) {
    final b = _branches, lot = _sheetBranchLot, l = _l10n;
    if (b == null || lot == null || l == null) return;
    switch (b.hire(staffId, lot)) {
      case StaffHire.ok:
        _toasts.show(l.branchHiredToast(staffName(l, staffId), _layout.district.branchNumber(lot)),
            icon: Icons.person_add_alt_1_rounded);
      case StaffHire.notEnoughCoins:
        _toasts.show(l.cityNotEnoughCoins, icon: Icons.info_outline_rounded);
      case StaffHire.unknown:
      case StaffHire.taken:
      case StaffHire.notOwned:
      case StaffHire.noSlot:
      case StaffHire.levelTooLow:
        break;
    }
  }

  void _branchDismiss(String staffId) {
    final b = _branches, l = _l10n;
    if (b == null || _sheetBranchLot == null || l == null) return;
    final r = b.dismiss(staffId);
    if (r.ok && r.collected > 0) _toasts.show(l.branchCollectedToast(r.collected), icon: Icons.savings_rounded);
  }

  /// Vào tiệm của bà: mờ đen → (chờ nội thất nếu chưa xong) → kiểu tóc → Mai ở khe cửa → đổi lớp → sáng dần.
  Future<void> _enterShop() async {
    final pilot = _pilot, shop = _shop, town = _town, embed = _embed;
    if (pilot == null || shop == null || town == null || embed == null || _busy) return;
    _busy = true;
    _transit.value = true;
    final sw = Stopwatch()..start();
    pilot.beginTransit();
    _joy.reset();
    try {
      await _fade.fadeOut();
      // Nội thất còn đang dựng nền: chờ dưới màn đen (sau 1 s hiện "Đang mở cửa…"); lỗi / quá lâu → ở lại phố.
      if (!embed.ready.value) await _whenTrue(embed.ready).timeout(_interiorTimeout, onTimeout: () {});
      if (_disposed) return;
      if (!embed.ready.value) {
        final m = pilot.mai.pose;
        pilot.placeAt(m.x, m.z, m.yaw);
        await _fade.fadeIn();
        return;
      }
      if (shop.maiLook != _wallet.look) await shop.setMaiLook(_wallet.look);
      embed.enter(entryX: TownRules.shopEntryX, entryZ: TownRules.shopEntryZ, entryYaw: TownRules.shopEntryYaw);
      // Trong tiệm: đồ họa + bóng như cảnh tiệm cũ (DPCF nếu mức cao, tới far plane).
      unawaited(shop.applyGraphics(_graphics));
      unawaited(shop.setShadowFar(0));
      await Future.wait([town.setActive(false), shop.setActive(true)]);
      _insideNow = true;
      _inside.value = true;
      await _fade.fadeIn();
    } finally {
      _transferMs = sw.elapsedMilliseconds;
      if (widget.verbose) debugPrint('Town3dView: enter shop $_transferMs ms');
      _busy = false;
      if (!_disposed) _transit.value = false;
    }
  }

  /// Ra phố: mờ đen → đổi lớp → Mai đứng trước cửa `n2` quay ra phố, camera về góc mặc định → sáng dần.
  Future<void> _exitShop() async {
    final pilot = _pilot, shop = _shop, town = _town, embed = _embed;
    if (pilot == null || shop == null || town == null || embed == null || _busy || !_insideNow) return;
    // Trong ca Mai bị khoá ở quầy — không ra phố được (lớp ca đóng ca trước).
    if (_shift.value != null) return;
    _busy = true;
    _transit.value = true;
    final sw = Stopwatch()..start();
    try {
      await _fade.fadeOut();
      if (_disposed) return;
      // Khách của ca vừa xong còn đang đi ra: gỡ ngay (ngoài phố vòng cập nhật tiệm không chạy).
      _stage?.clear();
      embed.leave();
      _insideNow = false;
      _inside.value = false;
      _frameClock
        ..stop()
        ..reset();
      await Future.wait([shop.setActive(false), town.setActive(true)]);
      final s = _layout.spawn;
      pilot.placeAt(s.x, s.z, 0);
      unawaited(shop.applyGraphics(_streetGraphics));
      unawaited(shop.setShadowFar(_streetShadowFar));
      _cam.snapTo(s.x, s.z);
      _cameraDirty = true;
      _maiPos.value = Offset(s.x, s.z);
      _keys.requestFocus();
      await _fade.fadeIn();
    } finally {
      _transferMs = sw.elapsedMilliseconds;
      if (widget.verbose) debugPrint('Town3dView: exit shop $_transferMs ms');
      _busy = false;
      if (!_disposed) _transit.value = false;
    }
  }

  static Future<void> _whenTrue(ValueListenable<bool> v) {
    if (v.value) return Future.value();
    final c = Completer<void>();
    void on() {
      if (v.value && !c.isCompleted) {
        v.removeListener(on);
        c.complete();
      }
    }

    v.addListener(on);
    return c.future;
  }

  // ---- Ca bán (GĐ3) -----------------------------------------------------------------------------------------------

  /// "Mở ca" ở quầy: mờ đen → phiên mới, Mai / Nora vào chỗ, camera đóng khung quầy, sân khấu bắt đầu, lớp ca hiện →
  /// sáng dần.
  Future<void> _openShift() async {
    final embed = _embed, stage = _stage, open = widget.openShift;
    if (embed == null || stage == null || open == null || widget.shiftLayer == null) return;
    if (!_insideNow || _busy || _shift.value != null) return;
    _busy = true;
    _transit.value = true;
    try {
      await _fade.fadeOut();
      if (_disposed) return;
      final session = open();
      embed.beginShift(
        maiX: TownRules.shiftMaiX,
        maiZ: TownRules.shiftMaiZ,
        maiYaw: TownRules.shiftMaiYaw,
        noraX: TownRules.shiftNoraX,
        noraZ: TownRules.shiftNoraZ,
        noraYaw: TownRules.shiftNoraYaw,
      );
      embed.shiftHint = false;
      final binder = _binder = ShiftBinder(
        session: session,
        stage: stage,
        say: (id, text, seconds) => embed.say(id, text, duration: seconds),
        l10n: () => _l10n,
      );
      binder.start();
      if (widget.verbose) {
        debugPrint('Town3dView: shift open ${session.total} customers '
            '(${[for (final o in session.orders) o.order.recipe.name]})');
        session.addListener(_logShift);
      }
      _shift.value = session;
      await _fade.fadeIn();
    } finally {
      _busy = false;
      if (!_disposed) _transit.value = false;
    }
  }

  ShiftPhase? _loggedPhase;

  /// `?log=1`: pha ca bán (script CDP chờ theo dòng này).
  void _logShift() {
    final s = _shift.value;
    if (s == null || s.phase == _loggedPhase) return;
    _loggedPhase = s.phase;
    final stars = s.served?.result.stars;
    debugPrint('Town3dView: shift ${s.phase.name} ${math.min(s.index + 1, s.total)}/${s.total}'
        '${stars != null ? ' $stars★' : ''}');
  }

  /// [ShiftLayerHost.setBaking]: dừng / chạy lại vẽ 3D (docs/v3/thermion-api-notes.md mục 30). Native →
  /// [Shop3dFrameDriver.paused]; web → `setRendering` (rAF + hook vẫn chạy, worker không vẽ); vòng cập nhật tiệm bỏ qua
  /// khi dừng ([_onFrame]); bộ đo chất lượng `auto` đo lại từ đầu ([_sampleFps]). Chạy lại → gửi lại camera.
  void _setBaking(bool on) {
    if (_disposed || _baking == on) return;
    _baking = on;
    final viewer = _viewer, driver = _driver;
    if (driver != null) {
      driver.paused = on;
    } else if (viewer != null) {
      unawaited(viewer.setRendering(!on));
    }
    if (_probe != null) _probe = Shop3dQualityProbe();
    if (!on) _embed?.refreshCamera();
    if (on && widget.verbose) _logBakeLayout();
  }

  /// [ShiftLayerHost.close]: gỡ lớp ca, khách còn lại đi ra (khách nền về vòng cũ), mở khoá Mai ngay — không chờ khách
  /// đi hết (Mai sau quầy, khách đi phía phòng; chờ thì người chơi đứng im vài giây sau khi bấm "Xong").
  void _closeShift() {
    final session = _shift.value;
    if (session == null) return;
    _setBaking(false);
    _binder?.stop();
    _binder = null;
    _embed?.endShift();
    session.removeListener(_logShift);
    _loggedPhase = null;
    _shift.value = null;
    if (widget.verbose) debugPrint('Town3dView: shift closed');
    // Lớp ca bỏ nghe phiên khi bị gỡ (khung tới) → huỷ phiên sau đó.
    WidgetsBinding.instance.addPostFrameCallback((_) => session.dispose());
  }

  /// `?log=1`: bố trí trạm của đơn sắp làm (ô khuôn đúng, khay topping, hộp, số vòng trộn, mặt bánh — toạ độ khung
  /// tham chiếu) để script CDP làm bánh đúng.
  void _logBakeLayout() {
    final s = _shift.value;
    if (s == null) return;
    final order = s.current.order;
    final recipe = Catalog.recipe(order.recipe);
    final m = recipe.mould;
    final moulds = mouldChoices(m, seededRandom(order, 1), unlockLevel: recipe.unlockLevel);
    String top(Rect cake) {
      final r = CakeArt.topSurface(cake, m, recipe: recipe.id);
      return [r.left, r.top, r.right, r.bottom].map((v) => v.round()).join(',');
    }
    debugPrint('Shift bake open #${s.index + 1}: ${order.recipe.name} mouldSlot=${moulds.indexOf(m)} '
        'toppings=${[for (final t in order.toppings) '${t.topping.name}x${t.count}']} '
        'trays=${toppingTrays(order, seededRandom(order, 2)).map((t) => t.name).toList()} '
        'box=${boxChoices.indexOf(order.box)} mix=${recipe.mixTurns} '
        'frostTop=${top(FrostStation.cakeRectFor(m, recipe: recipe.id))} '
        'toppingTop=${top(ToppingStation.cakeRectFor(m, recipe: recipe.id))}');
  }

  // ---- Cử chỉ / bàn phím --------------------------------------------------------------------------------------

  bool _onJoystick(Offset p) =>
      Shop3dJoystickGeometry.of(_size,
              padding: MediaQuery.paddingOf(context), gestureInsets: MediaQuery.systemGestureInsetsOf(context))
          .contains(p);

  void _onScaleStart(ScaleStartDetails d) {
    _cam
      ..onScaleStart()
      ..onDragStart();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _cam.onScale(d.scale);
    } else {
      _cam.onDrag(d.focalPointDelta.dx, d.focalPointDelta.dy, _size.height);
    }
    _cameraDirty = true;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _cam
      ..onDragEnd()
      ..onScaleEnd();
  }

  void _onDoubleTap() {
    final at = _doubleTapAt;
    _doubleTapAt = null;
    if (at != null && _onJoystick(at)) return;
    _cam.onDoubleTap();
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _cam.onMouseWheel(e.scrollDelta.dy);
      _cameraDirty = true;
    }
  }

  static final _moveKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final pilot = _pilot;
    // Trong tiệm (kể cả trong ca — phím thuộc về lớp ca): cảnh tiệm tự xử lý.
    if (pilot == null || _insideNow) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final down = e is KeyDownEvent;
    if (down && k == LogicalKeyboardKey.escape) {
      switch (_sheet.value) {
        case _Sheet.menu:
          _closeMenu();
        case _Sheet.salon:
          _salonCancel();
        case _Sheet.map:
          _closeMap();
        case _Sheet.settings:
          close();
        case _Sheet.realty:
          _closeRealty();
        case _Sheet.branch:
          _closeBranch();
        case _Sheet.none:
          break;
      }
      return KeyEventResult.handled;
    }
    if (_moveKeys.contains(k)) {
      _driveFromKeys();
      return KeyEventResult.handled;
    }
    if (_sheet.value != _Sheet.none || !pilot.hud.value.controls) return KeyEventResult.ignored;
    if ((k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.space) && down) {
      _pressA();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyQ && down) {
      _wave();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Vector joystick từ phím đang giữ: đi 0,7 (không Shift), chạy 1,0 (Shift) — như cảnh tiệm.
  void _driveFromKeys() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    bool any(LogicalKeyboardKey a, LogicalKeyboardKey b) => keys.contains(a) || keys.contains(b);
    final x = (any(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) ? 1.0 : 0.0) -
        (any(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft) ? 1.0 : 0.0);
    final y = (any(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ? 1.0 : 0.0) -
        (any(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1.0 : 0.0);
    final len = math.sqrt(x * x + y * y);
    if (len == 0) {
      _joy.drive(Offset.zero);
      return;
    }
    final shift = any(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight);
    final mag = shift ? 1.0 : 0.7;
    _joy.drive(Offset(x / len * mag, y / len * mag));
  }

  // ---- Huỷ ----------------------------------------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _fpsTimer?.cancel();
    _tadaTimer?.cancel();
    _toastTimer?.cancel();
    _awayTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final viewer = _viewer, shop = _shop, town = _town, driver = _driver;
    _viewer = null;
    _shop = null;
    _town = null;
    _driver = null;
    town?.dispose();
    if (viewer != null) {
      unawaited(() async {
        try {
          await driver?.stop();
          await viewer.app.unregisterRequestFrameHook(_frameHook);
          await shop?.dispose();
          await ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
          await viewer.dispose();
          await ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
        } catch (e) {
          debugPrint('Town3dView dispose failed: $e');
        }
      }());
    }
    _wallet.removeListener(_onWallet);
    _branches?.removeListener(_onBranches);
    // Ca dở (rời trang giữa ca): thôi nghe phiên (cảnh huỷ cùng viewer); lớp ca (con) đã bị gỡ trước.
    _binder?.stop();
    _shift.value?.dispose();
    _shift.dispose();
    _pilot?.dispose();
    _embed?.dispose();
    _joy.dispose();
    _toasts.dispose();
    _banner.dispose();
    _fade.dispose();
    _keys.dispose();
    _sheet.dispose();
    _maiPos.dispose();
    _maiYaw.dispose();
    _waveLeft.dispose();
    _tada.dispose();
    _inside.dispose();
    _fps.dispose();
    _transit.dispose();
    _playerLevel.dispose();
    _marks.dispose();
    _collectable.dispose();
    _sheetTick.dispose();
    _double.dispose();
    super.dispose();
  }

  // ---- Giao diện ----------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: AppColors.cream,
        // Ranh giới layout + vẽ (như cảnh tiệm): lớp phủ đổi không làm cả trang layout / vẽ lại.
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: LayoutBuilder(builder: (context, constraints) {
              final size = constraints.biggest;
              if (size != _size) _size = size;
              final embed = _embed;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (viewer != null && _shown)
                    Positioned.fill(child: _scaled(context, Shop3dSurface(viewer: viewer, onTexture: _onTexture))),
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: _onPointerSignal,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                        onDoubleTap: _onDoubleTap,
                      ),
                    ),
                  ),
                  // Nội thất: lớp phủ của cảnh tiệm (ẩn — Offstage — khi ở ngoài phố, giữ trạng thái).
                  if (embed != null)
                    Positioned.fill(
                      child: Shop3dView(
                        key: const ValueKey('town-shop'),
                        embed: embed,
                        events: false,
                        showDebug: false,
                        sceneOptions: embed.scene.options,
                        quality: widget.quality,
                        graphicsOverrides: widget.graphicsOverrides,
                      ),
                    ),
                  if (_pilot != null) ..._townOverlay(context),
                  Positioned(
                    left: 12 + MediaQuery.paddingOf(context).left,
                    top: 12 + MediaQuery.paddingOf(context).top,
                    child: IgnorePointer(child: CityHud(_wallet)),
                  ),
                  if (widget.showDebug) _debugChip(context),
                  LocationBanner(controller: _banner),
                  // Lớp 2D của ca bán (phủ kín; HUD của lớp chừa chỗ cho CityHud bên trái).
                  if (widget.shiftLayer != null) _shiftLayer(),
                  if (_pilot != null) _sheetLayer(),
                  TownFadeLayer(controller: _fade),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Lớp phủ ngoài phố: minimap + nút cài đặt, joystick, nút A + vẫy, toast, "ta-da". Ẩn hết khi ở trong tiệm.
  List<Widget> _townOverlay(BuildContext context) {
    final pilot = _pilot!;
    final l = _l10n;
    if (l == null) return const [];
    final pad = MediaQuery.paddingOf(context);
    final s = Shop3dStyle.scaleOf(_size);
    return [
      ValueListenableBuilder<bool>(
        valueListenable: _inside,
        builder: (context, inside, _) => inside
            ? const SizedBox.shrink()
            : Stack(fit: StackFit.expand, children: [
                ListenableBuilder(
                  listenable: Listenable.merge([pilot.hud, _sheet]),
                  builder: (context, _) => Shop3dJoystick(
                      controller: _joy, visible: pilot.hud.value.controls && _sheet.value == _Sheet.none),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([pilot.hud, _sheet, _collectable]),
                  builder: (context, _) {
                    final hud = pilot.hud.value;
                    final (label, icon) = _actionOf(l, hud.action, collect: _collectable.value);
                    final enabled = hud.action != TownAction.none;
                    return _TownButtons(
                      visible: hud.controls && _sheet.value == _Sheet.none,
                      primaryLabel: label,
                      primaryIcon: icon,
                      onPrimary: enabled ? _pressA : null,
                      primarySemantics: enabled ? null : l.controlHint,
                      waveLabel: l.actionWave,
                      onWave: _wave,
                      waveCooldown: _waveLeft,
                    );
                  },
                ),
                // Chip x2 (thu tiền chi nhánh) ngay trên nút A; tự ẩn sau 8 s.
                ValueListenableBuilder<({int serial, String lot, int coins})?>(
                  valueListenable: _double,
                  builder: (context, d, _) => d == null ? const SizedBox.shrink() : _doubleChip(d),
                ),
                Positioned(
                  right: 12 + pad.right,
                  top: 12 + pad.top,
                  child: RepaintBoundary(
                    child: TownMinimap(
                      district: _layout.district,
                      maiPos: _maiPos,
                      maiYaw: _maiYaw,
                      playerLevel: _playerLevel,
                      branches: _marks,
                      onTap: _openMap,
                      width: 168 * s,
                    ),
                  ),
                ),
                // Nút cài đặt bên trái minimap: ẩn khi chuyển cảnh, khi Mai không đi dạo, khi có bảng mở.
                if (widget.settingsSheet != null)
                  Positioned(
                    right: 12 + pad.right + 168 * s + 10,
                    top: 12 + pad.top,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([pilot.hud, _sheet, _transit]),
                      builder: (context, _) {
                        final visible = pilot.hud.value.controls && _sheet.value == _Sheet.none && !_transit.value;
                        return IgnorePointer(
                          ignoring: !visible,
                          child: AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: Shop3dStyle.fade,
                            child: CityMenuButton(
                              key: const ValueKey('town-settings'),
                              onPressed: _openSettings,
                              size: 48 * s,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<(int, Offset)?>(
                        valueListenable: _tada,
                        builder: (context, t, _) => t == null
                            ? const SizedBox.shrink()
                            : Stack(children: [
                                Positioned(
                                  left: t.$2.dx - 100,
                                  top: t.$2.dy - 100,
                                  width: 200,
                                  height: 200,
                                  child: _TadaBurst(key: ValueKey(t.$1)),
                                ),
                              ]),
                      ),
                    ),
                  ),
                ),
                Shop3dToastHost(controller: _toasts),
              ]),
      ),
    ];
  }

  /// Chip x2 đặt ngay trên nút A (vị trí theo [Shop3dActionLayout] như [_TownButtons]).
  Widget _doubleChip(({int serial, String lot, int coins}) d) => Positioned.fill(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final a = Shop3dActionLayout.of(size, padding: MediaQuery.paddingOf(context));
          const r = Shop3dActionLayout.primaryDiameter / 2;
          return Stack(children: [
            Positioned(
              right: math.max(8, size.width - a.primary.dx - r),
              bottom: size.height - a.primary.dy + r + 6,
              child: BranchDoubleChip(
                key: ValueKey(d.serial),
                coins: d.coins,
                onTap: () => unawaited(_watchDouble(d.lot)),
                onExpired: () {
                  if (_double.value?.serial == d.serial) _double.value = null;
                },
              ),
            ),
          ]);
        }),
      );

  /// Bảng đang mở: thực đơn / làm tóc (tự bọc Positioned) hoặc bản đồ lớn / cài đặt (phủ cả màn).
  Widget _sheetLayer() => ValueListenableBuilder<_Sheet>(
        valueListenable: _sheet,
        builder: (context, sheet, _) {
          switch (sheet) {
            case _Sheet.none:
              return const SizedBox.shrink();
            case _Sheet.menu:
              return Stack(fit: StackFit.expand, children: [
                RestaurantSheet(
                  wallet: _wallet,
                  onOrder: _order,
                  onClose: _closeMenu,
                ),
              ]);
            case _Sheet.salon:
              return Stack(fit: StackFit.expand, children: [
                ListenableBuilder(
                  listenable: _wallet,
                  builder: (context, _) => SalonSheet(
                    current: _wallet.look,
                    coins: _wallet.coins,
                    onPreview: _salonPreview,
                    onConfirm: _salonConfirm,
                    onCancel: _salonCancel,
                  ),
                ),
              ]);
            case _Sheet.map:
              return Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([_playerLevel, _marks]),
                  builder: (context, _) => TownMapSheet(
                    district: _layout.district,
                    maiPos: _maiPos,
                    maiYaw: _maiYaw,
                    playerLevel: _playerLevel.value,
                    branches: _marks.value,
                    onClose: _closeMap,
                  ),
                ),
              );
            case _Sheet.settings:
              final sheet = widget.settingsSheet;
              return sheet == null ? const SizedBox.shrink() : Positioned.fill(child: sheet(context, this));
            case _Sheet.realty:
              final b = _branches;
              if (b == null) return const SizedBox.shrink();
              return Stack(fit: StackFit.expand, children: [
                ListenableBuilder(
                  listenable: Listenable.merge([b, _wallet]),
                  builder: (context, _) => RealtySheet(
                    district: _layout.district,
                    owned: b.owned.toSet(),
                    coins: _wallet.coins,
                    playerLevel: _wallet.level,
                    onBuy: _realtyBuy,
                    onClose: _closeRealty,
                  ),
                ),
              ]);
            case _Sheet.branch:
              final b = _branches, lot = _branchLot;
              if (b == null || lot == null) return const SizedBox.shrink();
              return Stack(fit: StackFit.expand, children: [
                // Két tăng theo giờ mà không notify → dựng lại mỗi giây ([_sheetTick]) khi bảng mở.
                ListenableBuilder(
                  listenable: Listenable.merge([b, _wallet, _sheetTick]),
                  builder: (context, _) {
                    final v = b.view(lot);
                    if (v == null) return const SizedBox.shrink();
                    return BranchSheet(
                      view: v,
                      staff: b.staff,
                      coins: _wallet.coins,
                      playerLevel: _wallet.level,
                      clockBehind: b.anomaly == ClockAnomaly.behind,
                      onCollect: _branchCollect,
                      onUpgrade: _branchUpgrade,
                      onHire: _branchHire,
                      onDismiss: _branchDismiss,
                      onClose: _closeBranch,
                    );
                  },
                ),
              ]);
          }
        },
      );

  /// Nhãn + icon nút A; ở cửa chi nhánh: [collect] (két ≥ 25% trần / đầy) → "Thu tiền", không thì "Chi nhánh".
  static (String, IconData) _actionOf(AppLocalizations l, TownAction a, {bool collect = false}) => switch (a) {
        TownAction.enterShop => (l.townEnterShop, Icons.storefront_rounded),
        TownAction.orderFood => (l.cityOrderFood, Icons.restaurant_menu_rounded),
        TownAction.getHaircut => (l.cityGetHaircut, Icons.content_cut_rounded),
        TownAction.realty => (l.townActionRealty, Icons.real_estate_agent_rounded),
        TownAction.branch =>
          collect ? (l.townActionCollect, Icons.savings_rounded) : (l.townActionBranch, Icons.store_mall_directory_rounded),
        TownAction.none => ('', Icons.back_hand_rounded),
      };

  void _onTexture() {
    final c = _firstTexture;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Ảnh Filament theo [Shop3dGraphics.renderScale] + trần điểm ảnh web (như cảnh tiệm).
  Widget _scaled(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final scale = _graphics.renderScaleFor(_size.width, _size.height, mq.devicePixelRatio);
    _renderScale = scale;
    // Luôn cùng một cấu trúc cây (kể cả khi scale = 1): đo `auto` hạ mức đồ hoạ / đổi cỡ cửa sổ không làm ảnh 3D +
    // platform view của canvas bị gỡ rồi dựng lại — trên web canvas rời DOM, lần xin texture mới hỏng, canvas giữ cỡ cũ
    // dưới transform mới (ảnh bị cắt, phóng to).
    final small = MediaQuery(data: mq.copyWith(devicePixelRatio: mq.devicePixelRatio * scale), child: child);
    // Web: thermion đặt cỡ CSS của canvas = cỡ ảnh / devicePixelRatio THẬT của cửa sổ, nên canvas chỉ phủ `scale` phần
    // màn (góc trên trái) — phóng lại bằng transform (platform view nhận transform). Native: Texture tự giãn kín ô.
    if (!kIsWeb) return small;
    return Transform.scale(scale: 1 / scale, alignment: Alignment.topLeft, child: small);
  }

  Widget _debugChip(BuildContext context) {
    final s = Shop3dStyle.scaleOf(_size.isEmpty ? MediaQuery.sizeOf(context) : _size);
    final pad = MediaQuery.paddingOf(context);
    return Positioned(
      left: 12 + pad.left,
      top: 12 + pad.top + 86 * s,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ValueListenableBuilder<(int, int, int)>(
            valueListenable: _fps,
            builder: (context, fps, _) => DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  _debugText(fps),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lớp ca bán của phiên đang chạy (key theo phiên: ca mới = lớp mới).
  Widget _shiftLayer() => ValueListenableBuilder<ShiftSession?>(
        valueListenable: _shift,
        builder: (context, session, _) => session == null
            ? const SizedBox.shrink()
            : Positioned.fill(key: ValueKey(session), child: widget.shiftLayer!(context, session, _shiftHost)),
      );

  String _debugText((int, int, int) fps) {
    if (_error != null) return 'ERR $_error';
    final shop = _shop, town = _town;
    if (shop == null || town == null) return 'loading…';
    final (f, skip, ui) = fps;
    final b = StringBuffer()
      ..write('$f fps${skip > 0 ? ' (skip $skip)' : ''} · ui $ui · ${_level.name}')
      ..write(widget.quality == Shop3dQualityMode.auto ? ' (auto)' : '')
      ..write(_renderScale < 1 ? ' · px ×${_renderScale.toStringAsFixed(2)}' : '');
    if (_insideNow) {
      b
        ..write(' · shop ${shop.drawnEntityCount}/${shop.entityCount} ent (static ${shop.staticEntityCount})')
        ..write(' · ${shop.materialCount} mat · ${(shop.triangleCount / 1000).toStringAsFixed(1)}k tri')
        ..write(' · dart ${((_embed?.dartMicros ?? 0) / 1000).toStringAsFixed(2)} ms');
      if (_embed?.maiDebug case final m?) {
        b.write(' · mai ${m.x.toStringAsFixed(2)},${m.z.toStringAsFixed(2)}${m.atDoor ? ' door' : ''}');
      }
      if (shop.chibiTransformsPerUpdate > 0) {
        b.write(' · chibi ${shop.transformsSentPerUpdate.round()}/${shop.chibiTransformsPerUpdate} xf '
            '${(shop.chibiUpdateMicros / 1000).toStringAsFixed(2)} ms');
      }
    } else {
      b
        ..write(' · town ${town.drawnEntityCount}/${town.entityCount} ent (static ${town.staticEntityCount})')
        ..write(' · ${shop.materialCount} mat · ${(town.triangleCount / 1000).toStringAsFixed(1)}k tri')
        ..write(' (static ${(town.staticTriangleCount / 1000).toStringAsFixed(1)}k)')
        ..write(' · dart ${(_dartMicros / 1000).toStringAsFixed(2)} ms')
        ..write(' · xf ${town.transformsSentPerUpdate.round()}/${town.chibiParts}');
    }
    if (_transferMs != null) b.write(' · door ${_transferMs}ms');
    if (!(_embed?.ready.value ?? false)) b.write(' · shop…');
    return b.toString();
  }
}

/// Cảnh chứa lớp ca bán (view đã có `close` của [TownSheetHost] nên tách riêng).
class _ShiftHost implements ShiftLayerHost {
  _ShiftHost(this._view);

  final _Town3dViewState _view;

  @override
  void setBaking(bool on) => _view._setBaking(on);

  @override
  void close() => _view._closeShift();
}

/// Nút A (Ø96, theo vùng) + vẫy tay (Ø60) ngoài phố — cùng vị trí / kiểu với cụm nút cảnh tiệm
/// ([Shop3dActionLayout]); không có "Xong" / "Ném" (ngoài phố luôn điều khiển Mai, không cầm đồ).
class _TownButtons extends StatelessWidget {
  const _TownButtons({
    required this.visible,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.primarySemantics,
    required this.waveLabel,
    required this.onWave,
    required this.waveCooldown,
  });

  final bool visible;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? primarySemantics;
  final String waveLabel;
  final VoidCallback onWave;
  final ValueListenable<double> waveCooldown;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Shop3dStyle.fade,
          child: LayoutBuilder(builder: (context, constraints) {
            final l = Shop3dActionLayout.of(constraints.biggest, padding: padding);
            Positioned place(Offset c, double d, Widget child) =>
                Positioned(left: c.dx - d / 2, top: c.dy - d / 2, width: d, height: d, child: child);
            return Stack(children: [
              place(
                l.wave,
                Shop3dActionLayout.waveDiameter,
                Shop3dRoundActionButton(
                  key: const ValueKey('town-wave'),
                  diameter: Shop3dActionLayout.waveDiameter,
                  label: waveLabel,
                  icon: Icons.waving_hand_rounded,
                  onTap: onWave,
                  cooldown: waveCooldown,
                ),
              ),
              place(
                l.primary,
                Shop3dActionLayout.primaryDiameter,
                Shop3dRoundActionButton(
                  key: const ValueKey('town-primary'),
                  diameter: Shop3dActionLayout.primaryDiameter,
                  label: primaryLabel,
                  icon: primaryIcon,
                  onTap: onPrimary,
                  semanticsLabel: primarySemantics,
                  iconSize: 36,
                  fontSize: 14,
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Chùm sao lấp lánh ("ta-da") bung ra rồi mờ dần (~1,2 s). Không chữ.
class _TadaBurst extends StatefulWidget {
  const _TadaBurst({super.key});

  @override
  State<_TadaBurst> createState() => _TadaBurstState();
}

class _TadaBurstState extends State<_TadaBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TadaPainter(_c));
}

class _TadaPainter extends CustomPainter {
  _TadaPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static const _colors = [AppColors.butter, AppColors.strawberry, AppColors.mint, AppColors.butter, Colors.white];
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = AppColors.caramel;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final c = size.center(Offset.zero);
    final out = Curves.easeOutCubic.transform(v);
    final fade = v < 0.6 ? 1.0 : (1 - (v - 0.6) / 0.4).clamp(0.0, 1.0);
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 10 + (i.isOdd ? 0.2 : 0);
      final r = (i.isOdd ? 58.0 : 80.0) * out;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final s = (i.isOdd ? 9.0 : 13.0) * (1 - 0.35 * v);
      final path = _star(p, s);
      canvas.drawPath(path, Paint()..color = _colors[i % _colors.length].withValues(alpha: fade));
      canvas.drawPath(path, _edge..color = AppColors.caramel.withValues(alpha: fade));
    }
  }

  static Path _star(Offset c, double r) {
    final p = Path();
    for (var k = 0; k < 8; k++) {
      final a = -math.pi / 2 + k * math.pi / 4;
      final rr = k.isEven ? r : r * 0.42;
      final q = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (k == 0) {
        p.moveTo(q.dx, q.dy);
      } else {
        p.lineTo(q.dx, q.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_TadaPainter old) => old.t != t;
}
