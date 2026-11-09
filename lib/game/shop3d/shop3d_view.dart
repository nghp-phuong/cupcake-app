import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide KeyEvent, Material, Texture, Transform, View;

import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/shop3d/action_cluster.dart';
import '../../ui/shop3d/dialogue_panel.dart';
import '../../ui/shop3d/joystick.dart';
import '../../ui/shop3d/shop3d_toasts.dart';
import '../../ui/shop3d/staff_menu.dart';
import 'camera_framing.dart';
import 'chibi/chibi_actor.dart' show ChibiCarry;
import 'interact/pilot.dart';
import 'interact/pilot_rules.dart';
import 'orbit_camera.dart';
import 'shop3d_frame_driver.dart';
import 'shop3d_layout.dart';
import 'shop3d_math.dart';
import 'shop3d_pick.dart';
import 'shop3d_quality.dart';
import 'shop3d_scene.dart';
import 'shop3d_surface.dart';
import 'talk/talk_stories.dart';

/// Màn tiệm bánh 3D (bản thử GĐ a): cảnh [Shop3dScene] + camera quỹ đạo 360° [OrbitCameraController]; nhãn chọn nhân
/// vật đi theo đầu nhân vật.
///
/// Vòng cập nhật (camera, nhân vật, tương tác) chạy trong **request-frame hook của Filament** (ngay trước mỗi khung 3D),
/// không dùng Ticker của Flutter: ảnh 3D lên màn không cần khung Flutter (web: canvas DOM do worker vẽ; native: texture
/// báo khung mới, engine chỉ ghép lại), nên Flutter chỉ dựng khung khi lớp phủ thật sự đổi. Trước đây ticker chạy liên
/// tục vì chibi luôn chuyển động → mỗi vsync một khung Flutter đầy đủ (web, CanvasKit + platform view: ~7 ms/khung trên
/// Chrome desktop, gấp ~6 lần phần cảnh 3D — docs/v3/thermion-api-notes.md mục 9.27). Mỗi lớp phủ đổi theo khung nằm
/// trong `RepaintBoundary` riêng ([_layer]) để không vẽ lại cả trang.
///
/// Cử chỉ (lớp nhận chạm nằm TRÊN cảnh — trên web cảnh là canvas DOM, bọc ngoài thì Flutter không nhận được):
/// một ngón kéo = xoay; chụm hai ngón = phóng; chạm đúp = về góc mặc định (mượt); con lăn chuột = phóng (web);
/// chạm một lần = chọn vật (raycast phía Dart) → vật nhún + nhãn nhỏ.
///
/// Màn xếp hàng ([Shop3dSceneOptions.lineup]): [initialTarget] đặt điểm nhìn (góc ban đầu cũng là góc khi chạm đúp),
/// [showActorLabels] hiện nhãn id nhỏ dưới chân từng nhân vật.
///
/// Lớp debug (khi [showDebug]): FPS thật của Filament (native: số khung `beginFrame` nhận — [Shop3dFrameDriver]; web:
/// số lần vòng render chạy) + số khung Flutter đã raster (`ui`), số entity / material / tam giác, nút bật / tắt cờ
/// mở rộng, mức chất lượng đồ họa.
///
/// Chất lượng ([quality], [Shop3dQuality]): `auto` bắt đầu ở mức cao, đo FPS vài giây sau khi nhân vật dựng xong
/// ([Shop3dQualityProbe]) rồi hạ xuống mức thấp nếu không theo kịp (native: khung Filament thật; web: số vòng rAF của
/// thermion — tụt khi luồng chính hoặc GPU quá tải; bỏ qua lúc tab ẩn). Màn 120 / 144 Hz: giới hạn FPS còn nửa tần số
/// quét. Web: thêm trần điểm ảnh ([Shop3dGraphics.forWeb]). [graphicsOverrides] ghi đè từng thiết lập lên bộ của mức.
/// Chữ trên lớp debug là số liệu / id gỡ lỗi tiếng Anh, không qua AppLocalizations (không có trong app chính).
///
/// Tương tác ([interactive], V3 — docs/v3/interaction-spec.md; cần `AppLocalizations` trong cây): [Shop3dPilot] gắn vào
/// cảnh khi dàn chibi dựng xong. Chạm nhân viên → menu "Điều khiển" / "Nói chuyện với khách" neo trên đầu; khi điều
/// khiển: joystick trái (camera bám nhân vật, ra vỉa hè thì kéo yaw về |yaw| ≤ 80°), cụm nút phải (A theo ngữ cảnh,
/// Ném, Vẫy, Xong), mũi tên trên đích của nút A, bong bóng trên đầu, khung thoại có lựa chọn, banner sự kiện cãi nhau
/// ("Xem" lia camera, "Mai ra xem"), toast ♥ / xu. Bàn phím (web): WASD / mũi tên đi, Shift chạy, E / Space = A, giữ Q
/// rồi thả = ném, Esc = Xong. Lớp phủ đặt trên lớp nhận chạm camera (Stack dừng hit-test ở con đầu tiên trúng, nên ngón
/// trên joystick / nút không xoay camera).
///
/// Ghép vào màn khác ([embed], thành phố V3): không tạo viewer / ThermionWidget / hook / đo FPS — màn chủ làm (xem
/// [Shop3dEmbed]); view chỉ dựng lớp phủ + lớp nhận chạm, chạy vòng cập nhật khi màn chủ gọi `embed.frame()`, ẩn
/// (Offstage, giữ trạng thái) khi `embed.active` = false. Mai luôn được điều khiển: cụm nút không có "Xong", Esc không thả;
/// ở khe cửa nút A = "Ra phố" (`townExitShop`); ở quầy nút A = "Mở ca" (`shiftOpen`, ca bán — [Shop3dEmbed.beginShift]).
class Shop3dView extends StatefulWidget {
  const Shop3dView({
    super.key,
    this.initialOwned = const {Shop3dRequires.cafeTables},
    this.initialYaw,
    this.initialPitch,
    this.initialDistance,
    this.minDistance,
    this.followActorId,
    this.followOrbit,
    this.showDebug = true,
    this.sceneOptions = const Shop3dSceneOptions(),
    this.initialTarget,
    this.minEyeHeight,
    this.showActorLabels = false,
    this.quality = Shop3dQualityMode.auto,
    this.graphicsOverrides = const Shop3dGraphicsOverrides(),
    this.interactive = true,
    this.events = true,
    this.forceEvent,
    this.initialPilot,
    this.embed,
  });

  /// Ghép vào màn khác dùng chung viewer (thành phố V3); null = màn độc lập như cũ (tự tạo viewer).
  final Shop3dEmbed? embed;

  /// Cờ mở rộng (`Shop3dRequires`) bật lúc đầu.
  final Set<String> initialOwned;

  /// Góc camera lúc đầu (rad / m); null = mặc định của controller.
  final double? initialYaw;
  final double? initialPitch;
  final double? initialDistance;

  /// Khoảng cách camera tối thiểu (m); null = mặc định của controller (5 m). Nhỏ hơn để chụp cận nhân vật.
  final double? minDistance;

  /// Camera bám theo nhân vật chibi có id này (điểm nhìn = giữa người); null = nhìn giữa tiệm.
  final String? followActorId;

  /// Khi bám nhân vật: giữ camera ở góc này (rad) so với hướng mặt nhân vật (0 = ngay trước mặt, π/2 = bên trái
  /// nhân vật); null = góc tự do (kéo được).
  final double? followOrbit;
  final bool showDebug;
  final Shop3dSceneOptions sceneOptions;

  /// Điểm nhìn ban đầu; null = giữa tiệm. Có giá trị thì góc / khoảng cách ban đầu cũng là mặc định khi chạm đúp.
  final ({double x, double y, double z})? initialTarget;

  /// Độ cao camera tối thiểu (m); null = mặc định của controller (1,5 m). Thấp hơn để nhìn ngang nhân vật nhỏ (mèo).
  final double? minEyeHeight;

  /// Hiện nhãn id dưới chân mọi nhân vật chibi (màn xếp hàng).
  final bool showActorLabels;

  /// Mức chất lượng đồ họa (ép hoặc tự chọn).
  final Shop3dQualityMode quality;

  /// Ghi đè thiết lập đồ họa lên bộ của mức (tham số soft / ibl / tm / scale / fps / shadows / smap / post / aa / blob).
  final Shop3dGraphicsOverrides graphicsOverrides;

  /// Bật tương tác (điều khiển nhân vật, nói chuyện, sự kiện). Chỉ có hiệu lực ở cảnh chibi mặc định (không phải màn
  /// xếp hàng / billboard / không nhân vật). false = chế độ xem kịch bản cũ (chụp ảnh).
  final bool interactive;

  /// Sự kiện khách cãi nhau tự chạy theo lịch (`?events=0` tắt; [forceEvent] vẫn chạy).
  final bool events;

  /// Ép chạy sự kiện này ~3 s sau khi cảnh sẵn sàng (`lastCake`, `first`, `tart`, hoặc `now` = sự kiện kế tiếp).
  final String? forceEvent;

  /// Điều khiển nhân viên này ngay khi cảnh sẵn sàng (`mai`, `staff_nora`…).
  final String? initialPilot;

  @override
  State<Shop3dView> createState() => _Shop3dViewState();
}

/// Cảnh tiệm ghép vào một màn khác dùng chung MỘT viewer (thành phố V3 — docs/v3/city-gd1-spec.md). Màn chủ tạo viewer,
/// đặt `ThermionWidget`, chạy request-frame hook (+ `Shop3dFrameDriver` trên native), đo FPS / chất lượng, dựng [scene]
/// (`Shop3dScene.build(deferContent: true)` rồi `buildContent`) và bật / tắt lớp (`Shop3dScene.setActive`). [Shop3dView]
/// với `embed` gắn `Shop3dPilot` khi dàn chibi xong ([ready]) và chỉ dựng lớp phủ.
///
/// Mai ở khe cửa ([atDoor], toạ độ nội thất) → nút A = "Ra phố"; bước ra vỉa hè ([outside]) cũng ra → [onExit].
///
/// Ca bán (docs/v3/city-gd3-spec.md §5): Mai ở quầy ([atCounter], cửa được ưu tiên) → nút A = "Mở ca" → [onOpenShift];
/// màn chủ mờ màn rồi gọi [beginShift] (khoá Mai ở quầy, camera đóng khung quầy), hết ca gọi [endShift]. [onTick] chạy
/// mỗi khung trước khi cảnh cập nhật chibi (sân khấu ca bán). [shiftHint]: lần vào tiệm hiện toast + mũi tên chỉ quầy.
class Shop3dEmbed {
  Shop3dEmbed({
    required this.viewer,
    required this.scene,
    required this.onExit,
    required this.atDoor,
    required this.outside,
    this.atCounter,
    this.onOpenShift,
  });

  final ThermionViewer viewer;
  final Shop3dScene scene;

  /// Mai ra khỏi tiệm — màn chủ chuyển cảnh ra phố (gọi một lần mỗi lần vào; lần sau sau [enter]).
  final VoidCallback onExit;

  /// Mai (đang điều khiển) đứng ở khe cửa: nút A = "Ra phố".
  final bool Function(double x, double z) atDoor;

  /// Mai đã bước ra ngoài cửa (vỉa hè giả của cảnh tiệm): ra phố luôn.
  final bool Function(double x, double z) outside;

  /// Mai (đang điều khiển, không ở khe cửa) đứng ở quầy: nút A = "Mở ca". null = không có ca bán.
  final bool Function(double x, double z)? atCounter;

  /// Bấm "Mở ca" (nút A / E / Space ở quầy).
  final VoidCallback? onOpenShift;

  /// Gợi ý mở ca: mỗi lần vào tiệm hiện toast `shiftHintCounter`, mũi tên trên máy tính tiền tới khi Mai tới quầy.
  bool shiftHint = false;

  /// Mỗi khung (trong tiệm, 3D đang chạy), trước khi cảnh cập nhật chibi — `ShiftStage.update`.
  void Function(double dt)? onTick;

  /// Vào ca (gọi dưới màn mờ): Mai thả đồ đang cầm, đứng ở ([maiX], [maiZ]) quay về [maiYaw] và bị khoá
  /// (`Shop3dPilot.locked`: ẩn joystick / cụm nút, phím của tiệm trả `ignored`, chạm nhân vật bỏ qua); Nora đứng ở
  /// ([noraX], [noraZ]); camera đóng khung quầy (Mai + khách ở nửa trái màn); nhả focus để lớp ca nhận phím.
  void beginShift({
    required double maiX,
    required double maiZ,
    required double maiYaw,
    required double noraX,
    required double noraZ,
    required double noraYaw,
  }) =>
      _view?._beginShift(maiX, maiZ, maiYaw, noraX, noraZ, noraYaw);

  /// Hết ca: mở khoá Mai (ngay, không chờ khách đi ra hết), camera lia về bám Mai, lấy lại focus. Nora ở lại tủ kính.
  void endShift() => _view?._endShift();

  /// Bong bóng chữ [text] trên đầu nhân vật [actorId] trong [duration] giây.
  void say(String actorId, String text, {double duration = 2.4}) =>
      _view?._pilot?.say(actorId, text, duration: duration);

  /// Gửi lại camera ở khung tới (sau khi 3D dừng vẽ lúc làm bánh).
  void refreshCamera() => _view?._cameraDirty = true;

  _Shop3dViewState? _view;
  final _ready = ValueNotifier<bool>(false);
  bool _active = false;

  /// Đã gắn điều khiển (dàn chibi dựng xong) — mới vào tiệm được.
  ValueListenable<bool> get ready => _ready;

  /// Lớp phủ đang hiện (đang ở trong tiệm).
  bool get active => _active;

  /// Một khung cập nhật (camera, nhân vật, tương tác, lớp phủ) — màn chủ gọi trong request-frame hook khi ở trong tiệm.
  void frame() => _view?._onFrame();

  /// Vào tiệm: Mai (được điều khiển) đứng ngay sau khe cửa quay vào trong ([entryX], [entryZ]), camera bám Mai từ phía
  /// cửa; lớp phủ hiện, nhận phím. Gọi TRƯỚC `scene.setActive(true)` (mặt nạ tường đặt sẵn).
  void enter({double entryX = 3.6, double entryZ = 2.95, double entryYaw = math.pi}) {
    _active = true;
    _view?._enterFromStreet(entryX, entryZ, entryYaw);
  }

  /// Ra phố: ẩn lớp phủ, thả joystick (Mai vẫn được giữ cho lần vào sau).
  void leave() {
    _active = false;
    _view?._leaveToStreet();
  }

  /// ms Dart mỗi khung (µs, trượt mũ) của vòng cập nhật tiệm — chip debug của màn chủ.
  double get dartMicros => _view?._dartMicros ?? 0;

  /// Vị trí Mai trong tiệm (toạ độ nội thất) + đang ở khe cửa — chip debug của màn chủ; null = chưa có Mai.
  ({double x, double z, bool atDoor})? get maiDebug {
    final v = _view;
    final a = v?._pilot?.actorById('mai');
    if (v == null || a == null) return null;
    return (x: a.pose.x, z: a.pose.z, atDoor: v._atDoor.value);
  }

  void dispose() => _ready.dispose();
}

class _Shop3dViewState extends State<Shop3dView> {
  /// Góc nhìn dọc (độ). Đặt bằng tiêu cự: ThermionWidget đặt lại phép chiếu theo tiêu cự hiện tại mỗi lần đổi cỡ.
  static const fovDeg = 40.0;
  static const _near = 0.1;
  static const _far = 80.0;

  /// Nhãn chọn vật tự ẩn sau chừng này.
  static const _labelDuration = Duration(seconds: 3);

  late final _controller = () {
    final t = widget.initialTarget;
    return OrbitCameraController(
      minDistance: widget.minDistance ?? 5,
      minEyeHeight: widget.minEyeHeight ?? 1.5,
      target: t == null ? null : Vec3(t.x, t.y, t.z),
      defaultYaw: t == null ? null : widget.initialYaw,
      defaultPitch: t == null ? null : widget.initialPitch,
      defaultDistance: t == null ? null : widget.initialDistance,
    );
  }();
  // Vòng cập nhật trong request-frame hook ([_frameHook] → [_onFrame]): dt giữa hai lần gọi, thời gian Dart mỗi khung.
  final _frameClock = Stopwatch();
  final _dartWatch = Stopwatch();
  double _dartMicros = 0;

  ThermionViewer? _viewer;
  Shop3dScene? _scene;
  Camera? _camera;
  Object? _error;
  bool _disposed = false;

  bool _cameraDirty = true;
  bool _lookAtBusy = false;
  final _eye = Vector3.zero();
  final _focus = Vector3.zero();
  final _up = Vector3(0, 1, 0);
  final _basis = Shop3dCameraBasis();
  final _ray = Shop3dRay();
  Size _size = Size.zero;

  late Set<String> _owned = {...widget.initialOwned};

  // FPS. Native: [Shop3dFrameDriver] tự vẽ khung và đếm khung Filament thật sự nhận (beginFrame = true) — request-frame
  // hook vẫn chạy mỗi vsync kể cả khi Filament bỏ khung nên không dùng để đo được (mục 9.23 ghi chú API). Web: đếm hook
  // (worker vẽ theo rAF). Kèm số khung Flutter đã raster (FrameTiming): nay chỉ có khung khi lớp phủ đổi.
  Shop3dFrameDriver? _driver;
  int _frames = 0;
  int _lastRendered = 0;
  int _lastSkipped = 0;
  int _uiFrames = 0;
  final _fps = ValueNotifier<_FpsSample>(const _FpsSample(0, 0, 0));
  Timer? _fpsTimer;
  Future<void> _frameHook() async {
    _frames++;
    try {
      _onFrame();
    } catch (e, st) {
      // Lỗi ở đây không được lọt ra: FilamentApp.render bọc CẢ vòng hook trong một try → hook vẽ của driver (native)
      // phía sau bị bỏ, cảnh đứng hình. Ghi lần đầu kèm stack, sau đó chỉ đếm.
      if (_frameErrors++ == 0) debugPrint('Shop3dView: frame update failed: $e\n$st');
    }
  }

  int _frameErrors = 0;

  void _onTimings(List<FrameTiming> timings) => _uiFrames += timings.length;

  // Chất lượng đồ họa: mức hiện tại; đo tự động (auto, native) sau khi cảnh + nhân vật dựng xong.
  late Shop3dQuality _level = widget.quality == Shop3dQualityMode.low ? Shop3dQuality.low : Shop3dQuality.high;
  Shop3dQualityProbe? _probe;
  bool _probeArmed = false;

  /// Giới hạn FPS cho màn tần số quét cao (đo lúc đầu, [Shop3dQualityProbe.highRefreshCap]); null = theo mức.
  int? _refreshCap;

  Shop3dGraphics get _graphics {
    final preset = Shop3dGraphics.preset(_level);
    return widget.graphicsOverrides.apply(kIsWeb ? preset.forWeb() : preset);
  }

  /// Giới hạn FPS đang áp: của mức (hoặc ghi đè); mức không giới hạn thì theo [_refreshCap].
  int get _targetFps {
    final fps = _graphics.targetFps;
    return fps > 0 ? fps : (_refreshCap ?? 0);
  }

  // Nhãn id dưới chân mọi nhân vật (màn xếp hàng); tính lại khi camera / cỡ màn đổi hoặc nhân vật vừa dựng xong.
  final _actorLabels = ValueNotifier<List<_PickLabel>>(const []);

  // Nhãn vật vừa chọn: id + điểm neo thế giới; vị trí màn tính lại khi camera đổi.
  final _label = ValueNotifier<_PickLabel?>(null);
  String? _labelId;
  ({double x, double y, double z})? _labelAnchor;
  Timer? _labelTimer;

  // ---- Tương tác (V3) ----
  Shop3dPilot? _pilot;
  final _joy = Shop3dJoystickController();
  final _toasts = Shop3dToastController();
  final _keys = FocusNode(debugLabel: 'shop3d');

  /// Lớp phủ bám theo đầu nhân vật (bong bóng, chip tên, mũi tên, menu nhân viên) — tính lại mỗi khung khi có gì hiện.
  final _overlay = ValueNotifier<_OverlayFrame>(_OverlayFrame.empty);

  /// Menu chạm nhân viên: id + số thứ tự (key mới = đếm lại 5 s).
  final _menu = ValueNotifier<(String, int)?>(null);
  int _menuSerial = 0;
  bool _hintShown = false;
  Timer? _eventTimer;

  // Camera: lia tới sự kiện ("Xem"); đang xem thì thôi bám nhân vật tới khi người chơi đẩy cần.
  _CamTween? _tween;
  bool _watching = false;
  Offset? _doubleTapAt;

  // Bàn phím: giữ Q để nạp lực ném.
  Duration? _qDown;

  // Ghép thành phố ([Shop3dView.embed]): Mai ở khe cửa (nút A = ra phố), đã gọi onExit lần này chưa.
  final _atDoor = ValueNotifier<bool>(false);
  bool _exitFired = false;

  // Ca bán (ghép thành phố): Mai ở quầy (nút A = mở ca), đang trong ca (camera đóng khung quầy), hẹn toast gợi ý.
  final _atCounter = ValueNotifier<bool>(false);
  bool _shift = false;
  Timer? _hintTimer;

  /// Khung quầy trong ca: điểm nhìn lệch sang phải của Mai (1,0; −1,45) và khách (1,4; 0,45) để hai người ở nửa trái
  /// màn (vé đơn / thẻ kết quả chiếm bên phải; 1280: x ≈ 330–500 px, 1600: ≈ 490–660 px), nhìn từ phía phòng chếch về
  /// cửa (thấy mặt Mai và mặt khách quay `orderFaceYaw`, máy tính tiền lệch trái Mai).
  static const _shiftTarget = (x: 2.6, y: 0.8, z: -1.3);
  static const double _shiftYaw = 0.45, _shiftPitch = 24 * math.pi / 180, _shiftDistance = 7.0;

  /// Mũi tên gợi ý mở ca: trên máy tính tiền của quầy thu ngân.
  static const _hintAnchor = (x: 0.9, y: 1.45, z: -0.66);

  /// Ô đánh dấu chỗ đứng mở ca: trên bục gỗ phía khách trước quầy thu ngân (z ∈ [0,385; 1,215], mặt bục cao 0,16),
  /// nằm trong vùng quầy của `TownRules.atShopCounter`. Hiện khi có ca bán mà Mai chưa đứng ở quầy.
  static const _counterMark = (x: 1.0, y: Shop3dLayout.customerStepHeight + 0.01, z: 0.8, r: 0.42);

  bool get _embedded => widget.embed != null;

  @override
  void initState() {
    super.initState();
    _controller.setView(yaw: widget.initialYaw, pitch: widget.initialPitch, distance: widget.initialDistance);
    final embed = widget.embed;
    if (embed != null) {
      embed._view = this;
      unawaited(_initEmbedded(embed));
    } else {
      unawaited(_init());
    }
  }

  /// Ghép: dùng viewer / camera / cảnh của màn chủ; gắn điều khiển khi dàn chibi dựng xong.
  Future<void> _initEmbedded(Shop3dEmbed embed) async {
    try {
      _camera = await embed.viewer.getActiveCamera();
      _scene = embed.scene;
      _cameraDirty = true;
      if (mounted) setState(() {});
      await embed.scene.actorsReady;
      if (!mounted || _disposed) return;
      _setupPilot();
      setState(() {});
      embed._ready.value = _pilot != null;
    } catch (e, st) {
      debugPrint('Shop3dView (embed) init failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  /// Ghép — vào tiệm từ phố: Mai được điều khiển, đặt ở (x, z) (ô trống gần nhất) quay về [yaw]; camera bám Mai từ phía
  /// cửa; mặt nạ tường đặt ngay (lớp tiệm bật ngay sau đó).
  void _enterFromStreet(double x, double z, double yaw) {
    final pilot = _pilot;
    _exitFired = false;
    _frameClock
      ..stop()
      ..reset();
    _joy.reset();
    _tween = null;
    _watching = false;
    _closeStaffMenu();
    _hideLabel();
    if (pilot != null && pilot.control('mai')) {
      final free = pilot.nav.nearestFree(x, z, Shop3dPilot.maxNavRadius, maxDist: 1.5);
      if (free != null) {
        x = free.x;
        z = free.z;
      }
      final mai = pilot.actorById('mai');
      if (mai != null) {
        mai
          ..driveMove(x, z, yaw)
          ..pose.yaw = yaw;
      }
    }
    _controller.target.setValues(x, pilot?.followPoint()?.y ?? 0.85, z);
    _controller.setView(yaw: 0.35, pitch: _controller.defaultPitch, distance: 7.5);
    _cameraDirty = true;
    _scene?.setWallMask(_controller.hiddenWallMask());
    _atDoor.value = false;
    _atCounter.value = false;
    if (mounted) setState(() {});
    _keys.requestFocus();
    if (widget.embed?.shiftHint ?? false) {
      // Sau toast hướng dẫn điều khiển (lần vào đầu) nếu nó đang hiện; toast mới thay toast cũ.
      _hintTimer?.cancel();
      _hintTimer = Timer(
          _toasts.current.value == null ? const Duration(milliseconds: 500) : Shop3dToastController.defaultDuration,
          () {
        final l = _l10n;
        if (l != null && (widget.embed?.shiftHint ?? false) && !_shift) {
          _toasts.show(l.shiftHintCounter, icon: Icons.storefront_rounded, duration: const Duration(seconds: 5));
        }
      });
    }
  }

  /// Ghép — ra phố: ẩn lớp phủ, thả joystick.
  void _leaveToStreet() {
    _joy.reset();
    _atDoor.value = false;
    _atCounter.value = false;
    _hintTimer?.cancel();
    _closeStaffMenu();
    _hideLabel();
    if (mounted) setState(() {});
  }

  /// Ghép: Mai ở khe cửa → nút A "Ra phố"; ở quầy (không ở cửa) → "Mở ca"; bước ra vỉa hè → ra phố luôn.
  void _checkStreetDoor(Shop3dPilot pilot, Shop3dEmbed embed) {
    final mai = pilot.pilotId == 'mai' ? pilot.actorById('mai') : null;
    final at = mai != null && pilot.hud.value.controlsVisible && embed.atDoor(mai.pose.x, mai.pose.z);
    if (at != _atDoor.value) {
      _atDoor.value = at;
      if (widget.sceneOptions.verbose && mai != null) {
        debugPrint('Shop3dView: street door $at at (${mai.pose.x.toStringAsFixed(2)}, ${mai.pose.z.toStringAsFixed(2)})');
      }
    }
    final atCounter = embed.atCounter;
    final counter = mai != null &&
        !at &&
        pilot.hud.value.controlsVisible &&
        embed.onOpenShift != null &&
        atCounter != null &&
        atCounter(mai.pose.x, mai.pose.z);
    if (counter != _atCounter.value) {
      _atCounter.value = counter;
      if (widget.sceneOptions.verbose && mai != null) {
        debugPrint('Shop3dView: counter $counter at (${mai.pose.x.toStringAsFixed(2)}, ${mai.pose.z.toStringAsFixed(2)})');
      }
    }
    if (mai != null && embed.outside(mai.pose.x, mai.pose.z)) _exitStreet();
  }

  void _exitStreet() {
    final embed = widget.embed;
    if (embed == null || _exitFired || !embed.active || _shift) return;
    _exitFired = true;
    _joy.reset();
    embed.onExit();
  }

  void _openShift() {
    if (_shift || !_atCounter.value) return;
    _joy.reset();
    widget.embed?.onOpenShift?.call();
  }

  /// Ghép — vào ca (xem [Shop3dEmbed.beginShift]).
  void _beginShift(double maiX, double maiZ, double maiYaw, double noraX, double noraZ, double noraYaw) {
    final pilot = _pilot;
    if (pilot == null || _shift) return;
    _shift = true;
    _hintTimer?.cancel();
    _toasts.hide();
    _joy.reset();
    _tween = null;
    _watching = false;
    _closeStaffMenu();
    _hideLabel();
    _atDoor.value = false;
    _atCounter.value = false;
    pilot.control('mai');
    final mai = pilot.actorById('mai');
    if (mai != null) {
      final held = pilot.items.heldBy('mai');
      if (held != null) pilot.items.putDown(held, mai.pose.x, mai.pose.z, mai.pose.yaw);
      mai
        ..carry = ChibiCarry.none
        ..stopPerform()
        ..driveMove(maiX, maiZ, maiYaw)
        ..pose.yaw = maiYaw;
    }
    pilot.locked = true;
    final nora = pilot.actorById(_nora);
    if (nora != null && !nora.driven) {
      nora
        ..cancelRoute()
        ..stopPerform()
        ..pose.x = noraX
        ..pose.z = noraZ
        ..pose.yaw = noraYaw;
    }
    final t = _shiftTarget;
    _controller.target.setValues(t.x, t.y, t.z);
    _controller.setView(yaw: _shiftYaw, pitch: _shiftPitch, distance: _shiftDistance);
    _cameraDirty = true;
    // Lớp ca (autofocus) chỉ nhận focus khi trong scope không ai giữ.
    _keys.unfocus();
  }

  static const _nora = 'staff_nora';

  /// Ghép — hết ca (xem [Shop3dEmbed.endShift]).
  void _endShift() {
    if (!_shift) return;
    _shift = false;
    final pilot = _pilot;
    if (pilot != null) {
      // Nora ở lại tủ kính (kịch bản đứng tại chỗ): đi về cạnh máy tính tiền thì phải chen qua Mai đang đứng đó.
      pilot.locked = false;
      final p = pilot.followPoint();
      if (p != null) _tweenTo(p.x, p.y, p.z, 0.35, _controller.defaultPitch, 7.5, 0.8);
    }
    _keys.requestFocus();
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
      // Hook cập nhật đăng ký TRƯỚC hook vẽ của driver (native): các hook chạy theo thứ tự đăng ký → cảnh cập nhật xong
      // rồi mới vẽ trong cùng khung.
      await viewer.app.registerRequestFrameHook(_frameHook);
      if (Shop3dFrameDriver.supported) {
        final driver = Shop3dFrameDriver(viewer);
        await driver.start();
        _driver = driver;
      }
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sampleFps());
      if (mounted) setState(() {});
      final camera = await viewer.getActiveCamera();
      final aspect = _size.isEmpty ? 16 / 9 : _size.width / _size.height;
      await camera.setLensProjection(
          near: _near, far: _far, focalLength: 12.0 / math.tan(fovDeg * math.pi / 360.0), aspect: aspect);
      _camera = camera;
      _cameraDirty = true;
      final scene = await Shop3dScene.build(
        viewer,
        owned: _owned,
        options: widget.sceneOptions,
        graphics: _graphics,
        onActorsReady: () {
          if (!mounted) return;
          _probeArmed = true;
          _setupPilot();
          setState(() {});
          _placeActorLabels();
        },
      );
      if (_disposed) return;
      _scene = scene;
      if (widget.sceneOptions.actorMode == Shop3dActorMode.none) _probeArmed = true;
      scene.setWallMask(_controller.hiddenWallMask());
      scene.setBillboardYaw(_controller.yaw);
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Shop3dView init failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  /// Mỗi giây: khung Filament (native: đã vẽ / bị bỏ; web: số lần vòng render chạy) và khung Flutter đã raster.
  void _sampleFps() {
    final driver = _driver;
    if (driver != null) {
      _fps.value = _FpsSample(driver.rendered - _lastRendered, driver.skipped - _lastSkipped, _uiFrames);
      _lastRendered = driver.rendered;
      _lastSkipped = driver.skipped;
    } else {
      _fps.value = _FpsSample(_frames, 0, _uiFrames);
      _frames = 0;
    }
    _uiFrames = 0;
    final probe = _probe;
    if (probe != null && _probeArmed) {
      // Tab ẩn / app nền: rAF (web) / vòng render dừng → khung 0, không phải máy yếu → đo lại từ đầu khi hiện lại.
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed && state != AppLifecycleState.inactive) {
        _probe = Shop3dQualityProbe();
        return;
      }
      final pick = probe.addSecond(_fps.value.filament);
      if (pick != null) {
        _probe = null;
        _refreshCap = pick == Shop3dQuality.high ? probe.highRefreshCap() : null;
        if (widget.sceneOptions.verbose) {
          debugPrint('Shop3dView: probe ${probe.averageFps.toStringAsFixed(1)} fps → ${pick.name}'
              '${_refreshCap != null ? ', cap $_refreshCap fps' : ''}');
        }
        if (pick != _level) {
          _setLevel(pick);
        } else if (_refreshCap != null) {
          ThermionFlutterPlugin.instance.setTargetFramerate(_targetFps);
        }
      }
    }
  }

  /// Đổi mức chất lượng lúc đang chạy: cảnh (bóng, hậu kỳ, IBL, bóng tròn), giới hạn FPS, cỡ ảnh 3D (texture cấp lại).
  void _setLevel(Shop3dQuality level) {
    _level = level;
    final g = _graphics;
    ThermionFlutterPlugin.instance.setTargetFramerate(_targetFps);
    unawaited(_scene?.applyGraphics(g));
    if (mounted) setState(() {});
  }

  // ---- Tương tác --------------------------------------------------------------------------------------------

  bool get _interactive =>
      widget.interactive &&
      widget.sceneOptions.lineup == null &&
      widget.sceneOptions.actorMode == Shop3dActorMode.chibi &&
      Localizations.of<AppLocalizations>(context, AppLocalizations) != null;

  /// Gắn [Shop3dPilot] vào cảnh (dàn chibi vừa dựng xong).
  void _setupPilot() {
    final scene = _scene;
    if (scene == null || !scene.hasChibis || !_interactive || _pilot != null) return;
    final pilot = _pilot = Shop3dPilot(scene, events: widget.events);
    scene.attachPilot(pilot);
    pilot.hud.addListener(_onHud);
    final id = widget.initialPilot;
    if (id != null && pilot.control(id)) _onHud();
    final ev = widget.forceEvent;
    if (ev != null) {
      _eventTimer = Timer(const Duration(seconds: 3), () => pilot.forceEvent(ev == 'now' ? null : ev));
    }
  }

  void _onHud() {
    final hud = _pilot?.hud.value;
    if (hud == null) return;
    if (!hud.controlsVisible) _joy.reset();
    if (hud.pilotId != null && !_hintShown) {
      _hintShown = true;
      final l = _l10n;
      if (l != null) _toasts.show(l.controlHint, icon: Icons.sports_esports_rounded);
    }
  }

  AppLocalizations? get _l10n => Localizations.of<AppLocalizations>(context, AppLocalizations);

  /// Mỗi khung (trước khi cảnh cập nhật): joystick → pilot; camera bám nhân vật; lia camera; toast.
  void _tickPilot(double dt) {
    final pilot = _pilot;
    if (pilot == null) return;
    final v = _joy.value.value;
    pilot
      ..cameraYaw = _controller.yaw
      ..setStick(v.dx, v.dy, running: _joy.running.value, active: _joy.active.value);
    if (_joy.active.value) _watching = false;
    if (pilot.eventPair == null) _watching = false;
    final embed = widget.embed;
    if (embed != null) _checkStreetDoor(pilot, embed);
    _tickTween(dt);
    _followPilot(dt);
    final notices = pilot.takeNotices();
    if (notices.isNotEmpty) {
      final l = _l10n;
      if (l != null) {
        for (final n in notices) {
          final text = n.text?.call(l) ?? pilotRewardText(l, n.hearts, n.coins);
          if (text.isEmpty) continue;
          _toasts.show(text, icon: switch (n.icon) {
            PilotNoticeIcon.heart => Icons.favorite_rounded,
            PilotNoticeIcon.event => Icons.campaign_rounded,
            PilotNoticeIcon.info => Icons.info_outline_rounded,
          });
        }
      }
    }
  }

  /// Camera bám nhân vật đang điều khiển (mượt 6/s, cao đỉnh đầu × 0,62); ra vỉa hè thì kéo yaw về |yaw| ≤ 80°.
  void _followPilot(double dt) {
    final pilot = _pilot;
    var p = pilot?.followPoint();
    // Trong ca: camera giữ khung quầy.
    if (pilot == null || p == null || _watching || _tween != null || _shift) return;
    final t = _controller.target;
    final k = 1 - math.exp(-6 * dt);
    final frame = _frameGoal(pilot, p);
    if (frame != null) {
      p = frame.target;
      final d = _controller.distance;
      if ((frame.distance - d).abs() > 1e-3) {
        _controller.setView(distance: d + (frame.distance - d) * (1 - math.exp(-3 * dt)));
        _cameraDirty = true;
      }
    }
    final nx = t.x + (p.x - t.x) * k, ny = t.y + (p.y - t.y) * k, nz = t.z + (p.z - t.z) * k;
    var changed = (nx - t.x).abs() + (ny - t.y).abs() + (nz - t.z).abs() > 1e-5;
    if (changed) t.setValues(nx, ny, nz);
    if (pilot.onSidewalk && !_controller.isDragging) {
      const limit = 80 * math.pi / 180;
      final yaw = _controller.yaw;
      if (yaw.abs() > limit) {
        final goal = yaw.sign * limit;
        _controller.setView(yaw: yaw + (goal - yaw) * (1 - math.exp(-3 * dt)));
        changed = true;
      }
    }
    if (changed) {
      _controller.refresh();
      _cameraDirty = true;
    }
  }

  /// Khung bao Mai + người đang nói (hội thoại / lựa chọn) hoặc cặp khách sự kiện khi Mai tới gần (vào < 3,5 m, ra
  /// > 5 m so với tâm sự kiện). Người chơi kéo camera thì không lấy khung; đẩy cần thì chỉ lấy khung khi đang hội thoại.
  FrameResult? _frameGoal(Shop3dPilot pilot, FramePoint mai) {
    if (_controller.isDragging) return null;
    final talk = pilot.talkFramePoints();
    if (talk.length >= 2) return frameTargets(talk);
    if (_joy.active.value) return null;
    final ev = pilot.eventFramePoints();
    if (ev.length < 2) return null;
    final dx = mai.x - Shop3dPilot.eventX, dz = mai.z - Shop3dPilot.eventZ;
    final d = math.sqrt(dx * dx + dz * dz);
    _wasNearEvent = d < (_wasNearEvent ? 5 : 3.5);
    return _wasNearEvent ? frameTargets(ev) : null;
  }

  bool _wasNearEvent = false;

  /// "Xem": lia camera tới tâm sự kiện (2,2; 0,9; 5,5), yaw 0,4, dist 7, pitch 30° trong 2 s.
  void _lookAtEvent() {
    final t = _controller.target;
    _tween = _CamTween(
      fromX: t.x,
      fromY: t.y,
      fromZ: t.z,
      fromYaw: _controller.yaw,
      fromPitch: _controller.pitch,
      fromDist: _controller.distance,
      toX: Shop3dPilot.eventX,
      toY: 0.9,
      toZ: Shop3dPilot.eventZ,
      toYaw: 0.4,
      toPitch: 30 * math.pi / 180,
      toDist: 7,
      seconds: 2,
    );
    _watching = true;
  }

  /// Lia camera tới điểm nhìn (x, y, z) + góc trong [seconds] giây (ngắt khi người chơi kéo).
  void _tweenTo(double x, double y, double z, double yaw, double pitch, double distance, double seconds) {
    final t = _controller.target;
    _tween = _CamTween(
      fromX: t.x,
      fromY: t.y,
      fromZ: t.z,
      fromYaw: _controller.yaw,
      fromPitch: _controller.pitch,
      fromDist: _controller.distance,
      toX: x,
      toY: y,
      toZ: z,
      toYaw: yaw,
      toPitch: pitch,
      toDist: distance,
      seconds: seconds,
    );
  }

  void _tickTween(double dt) {
    final tw = _tween;
    if (tw == null) return;
    if (_controller.isDragging) {
      _tween = null;
      return;
    }
    tw.t = math.min(1, tw.t + dt / tw.seconds);
    final e = tw.t * tw.t * (3 - 2 * tw.t);
    _controller.target.setValues(
        tw.fromX + (tw.toX - tw.fromX) * e, tw.fromY + (tw.toY - tw.fromY) * e, tw.fromZ + (tw.toZ - tw.fromZ) * e);
    _controller.setView(
      yaw: tw.fromYaw + wrapAngle(tw.toYaw - tw.fromYaw) * e,
      pitch: tw.fromPitch + (tw.toPitch - tw.fromPitch) * e,
      distance: tw.fromDist + (tw.toDist - tw.fromDist) * e,
    );
    _cameraDirty = true;
    if (tw.t >= 1) _tween = null;
  }

  ({double x, double y, double z})? _headOf(String id) {
    final top = _scene?.actorTop(id);
    return top == null ? null : (x: top.x, y: top.y + 0.08, z: top.z);
  }

  /// Toạ độ màn của bong bóng / chip tên / mũi tên đích / menu nhân viên (chỉ khi có gì để hiện).
  void _placeOverlay() {
    final pilot = _pilot;
    if (pilot == null || _size.isEmpty) return;
    final menu = _menu.value;
    final pick = pilot.pick.value;
    final hud = pilot.hud.value;
    final hint = (widget.embed?.shiftHint ?? false) && !_atCounter.value ? _hintAnchor : null;
    final arrowAt = hud.controlsVisible ? pilot.targetPoint() ?? hint : null;
    final embed = widget.embed;
    final markAt = hud.controlsVisible &&
        embed != null &&
        embed.onOpenShift != null &&
        !_shift &&
        !_atCounter.value &&
        !_atDoor.value;
    if (pilot.bubbles.isEmpty && pick == null && arrowAt == null && menu == null && !markAt) {
      if (!identical(_overlay.value, _OverlayFrame.empty)) _overlay.value = _OverlayFrame.empty;
      return;
    }
    _basis.set(_controller.eye, _controller.target, fovDeg, _size.width, _size.height);
    Offset? proj(({double x, double y, double z})? p) {
      if (p == null) return null;
      final s = _basis.project(p.x, p.y, p.z);
      return s == null ? null : Offset(s.x, s.y);
    }

    final bubbles = <(PilotBubble, Offset)>[
      for (final b in pilot.bubbles)
        if (proj(_headOf(b.actorId)) case final o?) (b, o),
    ];
    final chips = <(String, Offset)>[
      if (pick != null)
        for (final id in pick.guestIds)
          if (proj(_headOf(id)) case final o?) (id, o),
    ];
    // Ô sàn: chiếu tâm và 4 điểm trên chu vi (±r theo x, z) → hình elip bao theo phối cảnh.
    Rect? mark;
    if (markAt) {
      const m = _counterMark;
      final c = proj((x: m.x, y: m.y, z: m.z));
      final l = proj((x: m.x - m.r, y: m.y, z: m.z));
      final r = proj((x: m.x + m.r, y: m.y, z: m.z));
      final n = proj((x: m.x, y: m.y, z: m.z - m.r));
      final f = proj((x: m.x, y: m.y, z: m.z + m.r));
      if (c != null && l != null && r != null && n != null && f != null) {
        mark = Rect.fromCenter(
            center: c, width: math.max(24, (r.dx - l.dx).abs()), height: math.max(12, (f.dy - n.dy).abs()));
      }
    }
    final next = _OverlayFrame(
      bubbles: bubbles,
      chips: chips,
      arrow: proj(arrowAt),
      menu: menu == null ? null : proj(_headOf(menu.$1)),
      mark: mark,
    );
    // Không đổi (nhân vật / camera đứng yên): khỏi báo → không dựng lại lớp phủ, không có khung Flutter.
    if (!next.sameAs(_overlay.value)) _overlay.value = next;
  }

  void _openStaffMenu(String id) {
    _menu.value = (id, ++_menuSerial);
    _placeOverlay();
  }

  void _closeStaffMenu() {
    if (_menu.value != null) _menu.value = null;
  }

  Shop3dJoystickGeometry _joyGeometry() => Shop3dJoystickGeometry.of(_size,
      padding: MediaQuery.paddingOf(context), gestureInsets: MediaQuery.systemGestureInsetsOf(context));

  /// Điểm [p] nằm trên joystick đang hiện (chạm ở đó không chọn vật / không chạm đúp camera).
  bool _onJoystick(Offset p) => (_pilot?.hud.value.controlsVisible ?? false) && _joyGeometry().contains(p);

  // ---- Bàn phím (web) ---------------------------------------------------------------------------------------

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
    if (pilot == null) return KeyEventResult.ignored;
    if (_embedded && !widget.embed!.active) return KeyEventResult.ignored;
    // Ca bán: phím (kể cả Esc) thuộc về lớp ca.
    if (pilot.locked) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final down = e is KeyDownEvent;
    final up = e is KeyUpEvent;
    if (down && k == LogicalKeyboardKey.escape) {
      if (_menu.value != null) {
        _closeStaffMenu();
      } else if (!_embedded) {
        pilot.release();
      }
      return KeyEventResult.handled;
    }
    if (!pilot.hud.value.controlsVisible) return KeyEventResult.ignored;
    if (_moveKeys.contains(k)) {
      _driveFromKeys();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.space) && down) {
      if (_atDoor.value) {
        _exitStreet();
      } else if (_atCounter.value) {
        _openShift();
      } else {
        pilot.pressA();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyQ) {
      if (down) _qDown = e.timeStamp;
      if (up && _qDown != null) {
        final held = (e.timeStamp - _qDown!).inMicroseconds / 1e6;
        _qDown = null;
        pilot.throwHeld(held);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Vector joystick từ phím đang giữ: đi 0,7 (không Shift), chạy 1,0 (Shift).
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

  // ---- Vòng cập nhật ----------------------------------------------------------------------------------------

  /// Mỗi khung Filament (request-frame hook, trước khi vẽ): camera, nhân vật, tương tác, lớp phủ. dt đo giữa hai lần
  /// gọi, chặn 0,1 s (tab ẩn rồi hiện lại không làm nhân vật nhảy cóc). Giới hạn FPS ([_targetFps]) thì cập nhật theo
  /// đúng nhịp đó.
  void _onFrame() {
    if (_disposed) return;
    final first = !_frameClock.isRunning;
    final dt = first ? 1 / 60 : math.min(0.1, _frameClock.elapsedMicroseconds / 1e6);
    _frameClock
      ..reset()
      ..start();
    _dartWatch
      ..reset()
      ..start();
    if (_controller.update(dt)) _cameraDirty = true;
    _tickPilot(dt);
    widget.embed?.onTick?.call(dt);
    _scene?.tick(dt);
    if (_cameraDirty) _pushCamera();
    _followLabel();
    _followActor();
    // Lớp phủ bám đầu nhân vật: sau khi nhân vật và camera của khung này đã cập nhật.
    if (_pilot != null) _placeOverlay();
    _dartWatch.stop();
    final us = _dartWatch.elapsedMicroseconds.toDouble();
    _dartMicros = _dartMicros == 0 ? us : _dartMicros * 0.95 + us * 0.05;
  }

  /// Gửi camera xuống Filament (tối đa một lệnh đang chờ; khung sau gửi giá trị mới nhất) + tường + billboard.
  void _pushCamera() {
    final camera = _camera;
    if (camera == null || _lookAtBusy) return;
    _cameraDirty = false;
    _lookAtBusy = true;
    _eye.setValues(_controller.eye.x, _controller.eye.y, _controller.eye.z);
    _focus.setValues(_controller.target.x, _controller.target.y, _controller.target.z);
    camera.lookAt(_eye, focus: _focus, up: _up).whenComplete(() => _lookAtBusy = false);
    final scene = _scene;
    if (scene != null) {
      scene.setWallMask(_controller.hiddenWallMask());
      scene.setBillboardYaw(_controller.yaw);
    }
    if (_labelAnchor != null) _placeLabel();
    _placeActorLabels();
  }

  /// Nhãn id dưới chân mọi nhân vật chibi (chiếu điểm trước mũi chân lên màn hình).
  void _placeActorLabels() {
    final scene = _scene;
    if (!widget.showActorLabels || scene == null || _size.isEmpty) return;
    _basis.set(_controller.eye, _controller.target, fovDeg, _size.width, _size.height);
    _actorLabels.value = [
      for (final f in scene.chibiFeet)
        if (_basis.project(f.x, f.y, f.z + f.radius * 0.9) case final p?) _PickLabel(f.id, Offset(p.x, p.y)),
    ];
  }

  /// Điểm nhìn bám nhân vật [Shop3dView.followActorId] (giữa người, ngang ngực / mặt).
  void _followActor() {
    final id = widget.followActorId, scene = _scene;
    if (id == null || scene == null) return;
    final top = scene.actorTop(id);
    if (top == null) return;
    final orbit = widget.followOrbit;
    final yaw = orbit == null ? null : scene.actorYaw(id);
    if (yaw != null) _controller.setView(yaw: yaw + orbit!);
    final t = _controller.target;
    final y = top.y * 0.62;
    if (yaw == null && (t.x - top.x).abs() + (t.y - y).abs() + (t.z - top.z).abs() < 1e-4) return;
    t.setValues(top.x, y, top.z);
    _controller.refresh();
    _cameraDirty = true;
  }

  /// Nhãn đang gắn vào nhân vật chibi (đi lại được) → đi theo đỉnh đầu.
  void _followLabel() {
    final id = _labelId, scene = _scene;
    if (id == null || scene == null) return;
    final top = scene.actorTop(id);
    if (top == null) return;
    _labelAnchor = (x: top.x, y: top.y + 0.12, z: top.z);
    _placeLabel();
  }

  // ---- Cử chỉ -----------------------------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _controller
      ..onScaleStart()
      ..onDragStart();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      _controller.onScale(d.scale);
    } else {
      _controller.onDrag(d.focalPointDelta.dx, d.focalPointDelta.dy, _size.height);
    }
    _cameraDirty = true;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _controller
      ..onDragEnd()
      ..onScaleEnd();
  }

  void _onDoubleTap() {
    final at = _doubleTapAt;
    _doubleTapAt = null;
    if (at != null && _onJoystick(at)) return;
    _tween = null;
    _watching = false;
    if (_shift) {
      // Trong ca: về khung quầy.
      final t = _shiftTarget;
      _tweenTo(t.x, t.y, t.z, _shiftYaw, _shiftPitch, _shiftDistance, _controller.resetDuration);
      return;
    }
    _controller.onDoubleTap();
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _controller.onMouseWheel(e.scrollDelta.dy);
      _cameraDirty = true;
    }
  }

  void _onTapUp(TapUpDetails d) {
    final scene = _scene;
    // Ca bán (Mai bị khoá): chạm vào nhân vật / vật bị bỏ qua.
    if (scene == null || _size.isEmpty || (_pilot?.locked ?? false)) return;
    if (_onJoystick(d.localPosition)) return;
    _basis.set(_controller.eye, _controller.target, fovDeg, _size.width, _size.height);
    final hit = pickNearest(_basis.rayThrough(d.localPosition.dx, d.localPosition.dy, _ray), scene.pickBoxes);
    if (widget.sceneOptions.verbose) debugPrint('Shop3dView: tap ${d.localPosition} → ${hit?.id}');
    final pilot = _pilot;
    pilot?.cancelPick();
    if (hit == null) {
      _hideLabel();
      return;
    }
    if (pilot != null && hit.kind == Shop3dPickKind.actor && !pilot.dialogueOpen) {
      if (Shop3dPilot.isStaffId(hit.id)) {
        // Nhân viên: nhún như cũ + menu "Điều khiển" / "Nói chuyện với khách" (thay nhãn id).
        scene.hop(hit.id);
        _hideLabel();
        _openStaffMenu(hit.id);
        return;
      }
      // Khách: đang điều khiển nhân viên và khách ở gần → mở luôn nói chuyện.
      if (pilot.tapGuest(hit.id)) {
        _hideLabel();
        return;
      }
    }
    scene.hop(hit.id);
    final top = topCenterOf(hit.id, scene.pickBoxes);
    _labelId = hit.id;
    _labelAnchor = top == null ? null : (x: top.x, y: top.y + 0.12, z: top.z);
    _placeLabel();
    _labelTimer?.cancel();
    _labelTimer = Timer(_labelDuration, _hideLabel);
  }

  void _placeLabel() {
    final a = _labelAnchor, id = _labelId;
    if (a == null || id == null || _size.isEmpty) return;
    _basis.set(_controller.eye, _controller.target, fovDeg, _size.width, _size.height);
    final p = _basis.project(a.x, a.y, a.z);
    _label.value = p == null ? null : _PickLabel(id, Offset(p.x, p.y));
  }

  void _hideLabel() {
    _labelTimer?.cancel();
    _labelAnchor = null;
    _labelId = null;
    _label.value = null;
  }

  void _toggle(String flag) {
    setState(() {
      _owned = {..._owned};
      if (!_owned.remove(flag)) _owned.add(flag);
    });
    final scene = _scene;
    if (scene == null) return;
    unawaited(scene.setOwned(_owned));
    final id = _labelId;
    if (id != null && !scene.pickBoxes.any((b) => b.id == id)) _hideLabel();
  }

  // ---- Huỷ --------------------------------------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _fpsTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _labelTimer?.cancel();
    final viewer = _viewer;
    final scene = _scene;
    final driver = _driver;
    _viewer = null;
    _scene = null;
    _driver = null;
    if (viewer != null) {
      unawaited(() async {
        try {
          await driver?.stop();
          await viewer.app.unregisterRequestFrameHook(_frameHook);
          await scene?.dispose();
          // Giải phóng texture/swapchain trước rồi mới huỷ viewer (giống ViewerWidget).
          await ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
          await viewer.dispose();
          await ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
        } catch (e) {
          debugPrint('Shop3dView dispose failed: $e');
        }
      }());
    }
    _fps.dispose();
    _label.dispose();
    _actorLabels.dispose();
    _eventTimer?.cancel();
    _pilot?.hud.removeListener(_onHud);
    _pilot?.dispose();
    _joy.dispose();
    _toasts.dispose();
    _keys.dispose();
    _overlay.dispose();
    _menu.dispose();
    _atDoor.dispose();
    _hintTimer?.cancel();
    _atCounter.dispose();
    if (widget.embed?._view == this) widget.embed!._view = null;
    super.dispose();
  }

  // ---- Giao diện --------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    final embed = widget.embed;
    if (embed != null) {
      // Ghép: ẩn (giữ trạng thái) khi Mai ở ngoài phố; màn chủ xin focus khi vào tiệm.
      return Offstage(
        offstage: !embed.active,
        child: Focus(focusNode: _keys, onKeyEvent: _onKey, child: _buildBody(context, null)),
      );
    }
    // Focus: phím tắt web khi đang điều khiển (con lăn chuột vẫn zoom qua Listener bên dưới).
    return Focus(focusNode: _keys, autofocus: true, onKeyEvent: _onKey, child: _buildBody(context, viewer));
  }

  Widget _buildBody(BuildContext context, ThermionViewer? viewer) {
    // Ghép: không nền (ThermionWidget của màn chủ nằm dưới).
    if (_embedded) return _buildLayers(context, null);
    return ColoredBox(color: AppColors.cream, child: _buildLayers(context, viewer));
  }

  Widget _buildLayers(BuildContext context, ThermionViewer? viewer) {
    // Ranh giới layout (ràng buộc chặt) + ranh giới vẽ: lớp phủ dựng lại trong build scope của LayoutBuilder làm nó
    // layout lại; thân Scaffold cho ràng buộc lỏng nên không chặn thì cả Scaffold layout + vẽ lại mỗi khung (đo:
    // ~60 ms/s layout + ~60 ms/s vẽ Material / InkWell khi có sự kiện, Chrome desktop).
    return RepaintBoundary(
          child: SizedBox.expand(
              child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size != _size) {
            _size = size;
            if (_labelAnchor != null) _placeLabel();
            if (widget.showActorLabels) WidgetsBinding.instance.addPostFrameCallback((_) => _placeActorLabels());
          }
          // expand: con không-Positioned (nhãn đang ẩn = SizedBox.shrink) không được kéo Stack về 0×0.
          return Stack(
            fit: StackFit.expand,
            children: [
              if (viewer != null) Positioned.fill(child: _scaled(context, Shop3dSurface(viewer: viewer))),
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
                      onTapUp: _onTapUp),
                ),
              ),
              if (widget.showActorLabels)
                _layer(ValueListenableBuilder<List<_PickLabel>>(
                  valueListenable: _actorLabels,
                  builder: (context, labels, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final l in labels)
                        Positioned(
                            left: l.position.dx,
                            top: l.position.dy,
                            child: IgnorePointer(
                                child: FractionalTranslation(
                                    translation: const Offset(-0.5, 0.15),
                                    child: _DebugChip(text: l.id, color: const Color(0xCCFFF4E6), small: true)))),
                    ],
                  ),
                )),
              _layer(ValueListenableBuilder<_PickLabel?>(
                valueListenable: _label,
                builder: (context, label, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (label != null)
                      Positioned(
                          left: label.position.dx,
                          top: label.position.dy,
                          child: IgnorePointer(
                              child: FractionalTranslation(
                                  translation: const Offset(-0.5, -1),
                                  child: _DebugChip(text: label.id, color: AppColors.strawberry)))),
                  ],
                ),
              )),
              if (_pilot != null) ..._interactionOverlay(context),
              if (widget.showDebug && !_embedded) ..._debugOverlay(),
            ],
          );
        },
      )),
    );
  }

  /// Lớp phủ tương tác, theo thứ tự trong Stack: bong bóng / mũi tên (không nhận chạm), chip tên, joystick, cụm nút,
  /// menu nhân viên, khung thoại, banner sự kiện, toast.
  List<Widget> _interactionOverlay(BuildContext context) {
    final pilot = _pilot!;
    final l = _l10n;
    if (l == null) return const [];
    return [
      _layer(ValueListenableBuilder<_OverlayFrame>(
        valueListenable: _overlay,
        builder: (context, o, _) => Stack(
          fit: StackFit.expand,
          children: [
            for (final (b, at) in o.bubbles)
              Shop3dHeadBubble(
                key: ValueKey('bubble-${b.serial}'),
                anchor: at,
                text: b.text(l),
                kind: switch (b.kind) {
                  PilotBubbleKind.speech => Shop3dBubbleKind.speech,
                  PilotBubbleKind.exclaim => Shop3dBubbleKind.exclaim,
                  PilotBubbleKind.puff => Shop3dBubbleKind.puff,
                  PilotBubbleKind.thinking => Shop3dBubbleKind.thinking,
                },
              ),
            if (o.mark case final m?) _FloorMark(key: const ValueKey('shop3d-floor-mark'), rect: m),
            if (o.arrow case final a?) Shop3dTargetArrow(key: const ValueKey('target-arrow'), anchor: a),
            for (final (id, at) in o.chips)
              Shop3dNameChip(
                key: ValueKey('chip-$id'),
                anchor: at,
                label: TalkNames.of(id)?.call(l) ?? '',
                highlighted: identical(id, o.chips.first.$1),
                onTap: () => pilot.choosePick(id),
              ),
          ],
        ),
      )),
      ValueListenableBuilder<PilotHud>(
        valueListenable: pilot.hud,
        builder: (context, hud, _) => Shop3dJoystick(controller: _joy, visible: hud.controlsVisible),
      ),
      if (_embedded)
        // Ghép thành phố: nút "Ra ngoài" luôn hiện góc phải trên (cùng luồng ra phố với khe cửa).
        ValueListenableBuilder<PilotHud>(
          valueListenable: pilot.hud,
          builder: (context, hud, _) => _ExitButton(
            label: l.shopExitButton,
            visible: hud.controlsVisible,
            onPressed: _exitStreet,
          ),
        ),
      if (_embedded)
        // Ghép thành phố: Mai luôn được điều khiển (không "Xong"); ở khe cửa nút A = ra phố.
        // Ở quầy: nút A = mở ca (cửa được ưu tiên — [_checkStreetDoor]).
        ListenableBuilder(
          listenable: Listenable.merge([pilot.hud, _atDoor, _atCounter]),
          builder: (context, _) {
            final hud = pilot.hud.value;
            final door = _atDoor.value, counter = _atCounter.value;
            final (label, icon) = door
                ? (l.townExitShop, Icons.door_front_door_rounded)
                : counter
                    ? (l.shiftOpen, Icons.storefront_rounded)
                    : _primaryOf(l, hud.decision);
            return _EmbedCluster(
              primaryLabel: label,
              primaryIcon: icon,
              onPrimary: door ? _exitStreet : (counter ? _openShift : (hud.decision.enabled ? pilot.pressA : null)),
              primarySemanticsLabel: door || counter || hud.decision.enabled ? null : l.controlHint,
              showThrow: hud.showThrow,
              throwLabel: l.actionThrow,
              onThrowTap: pilot.throwTap,
              onThrowCharged: pilot.throwCharged,
              waveLabel: l.actionWave,
              onWave: pilot.wave,
              waveCooldown: pilot.waveCooldown,
              visible: hud.controlsVisible,
            );
          },
        )
      else
      ValueListenableBuilder<PilotHud>(
        valueListenable: pilot.hud,
        builder: (context, hud, _) {
          final (label, icon) = _primaryOf(l, hud.decision);
          return Shop3dActionCluster(
            primaryLabel: label,
            primaryIcon: icon,
            onPrimary: hud.decision.enabled ? pilot.pressA : null,
            primarySemanticsLabel: hud.decision.enabled ? null : l.controlHint,
            showThrow: hud.showThrow,
            throwLabel: l.actionThrow,
            onThrowTap: pilot.throwTap,
            onThrowCharged: pilot.throwCharged,
            waveLabel: l.actionWave,
            onWave: pilot.wave,
            waveCooldown: pilot.waveCooldown,
            doneLabel: l.commonDone,
            onDone: pilot.release,
            visible: hud.controlsVisible,
          );
        },
      ),
      // Menu tự đặt chỗ bằng Positioned.fill → cần Stack cha trong lớp.
      _layer(Stack(fit: StackFit.expand, children: [
        ValueListenableBuilder<(String, int)?>(
          valueListenable: _menu,
          builder: (context, menu, _) => menu == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<_OverlayFrame>(
                  valueListenable: _overlay,
                  builder: (context, o, _) => o.menu == null
                      ? const SizedBox.shrink()
                      : Shop3dStaffMenu(
                          key: ValueKey('staff-menu-${menu.$2}'),
                          anchor: o.menu!,
                          controlLabel: l.staffMenuControl,
                          talkLabel: l.staffMenuTalk,
                          onControl: () {
                            _closeStaffMenu();
                            pilot.control(menu.$1);
                          },
                          onTalk: () {
                            _closeStaffMenu();
                            pilot.talkFrom(menu.$1);
                          },
                          onDismiss: _closeStaffMenu,
                        ),
                ),
        ),
      ])),
      ValueListenableBuilder<PilotTalkLine?>(
        valueListenable: pilot.talk,
        builder: (context, line, _) => line == null
            ? const SizedBox.shrink()
            : Shop3dDialoguePanel(
                speaker: line.speakerName?.call(l),
                text: line.text(l),
                tapHint: l.storyTapToContinue,
                skipLabel: l.storySkip,
                choices: [for (final c in line.choices) c(l)],
                onNext: pilot.talkNext,
                onSkip: line.choices.isEmpty ? pilot.talkSkip : null,
                onChoice: pilot.talkChoose,
                lineId: line.lineId,
              ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: pilot.banner,
        builder: (context, show, _) => !show
            ? const SizedBox.shrink()
            : Shop3dEventBanner(
                message: l.quarrelBanner,
                primaryLabel: l.quarrelLook,
                onPrimary: _lookAtEvent,
                secondaryLabel: l.quarrelSendMai,
                onSecondary: pilot.sendMai,
              ),
      ),
      Shop3dToastHost(controller: _toasts),
    ];
  }

  /// Nhãn + icon của nút A theo hành động (mờ: bàn tay, không chữ).
  static (String, IconData) _primaryOf(AppLocalizations l, PilotDecision d) => switch (d.action) {
        PilotAction.intervene => (l.quarrelIntervene, Icons.handshake_rounded),
        PilotAction.offerCake => (l.actionGive, Icons.cake_rounded),
        PilotAction.placeOn => (l.actionPlaceOn, Icons.move_down_rounded),
        PilotAction.putDown => (l.actionPutDown, Icons.download_rounded),
        PilotAction.pickUp => (l.actionPickUp, Icons.pan_tool_alt_rounded),
        PilotAction.talk => (l.actionTalk, Icons.chat_bubble_rounded),
        PilotAction.petMochi => (l.mochiPet, Icons.pets_rounded),
        PilotAction.none => ('', Icons.back_hand_rounded),
      };

  /// Ảnh Filament ở [Shop3dGraphics.renderScale] độ phân giải (hạ thêm theo trần điểm ảnh —
  /// [Shop3dGraphics.renderScaleFor]): ThermionWidget tạo texture / canvas = cỡ logic × devicePixelRatio, nên hạ
  /// devicePixelRatio cho riêng nó; ô hiển thị vẫn phủ kín, Flutter / trình duyệt phóng ảnh lên.
  Widget _scaled(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final scale = _graphics.renderScaleFor(_size.width, _size.height, mq.devicePixelRatio);
    _renderScale = scale;
    // Luôn cùng một cấu trúc cây (kể cả khi scale = 1): đo `auto` hạ mức đồ hoạ / đổi cỡ cửa sổ không làm ảnh 3D +
    // platform view của canvas bị gỡ rồi dựng lại (web: lần xin texture mới hỏng, ảnh bị cắt / phóng to).
    final small = MediaQuery(data: mq.copyWith(devicePixelRatio: mq.devicePixelRatio * scale), child: child);
    // Web: thermion đặt cỡ CSS của canvas = cỡ ảnh / devicePixelRatio THẬT của cửa sổ, nên canvas chỉ phủ `scale` phần
    // màn (góc trên trái) — phóng lại bằng transform (platform view nhận transform). Native: Texture tự giãn kín ô.
    if (!kIsWeb) return small;
    return Transform.scale(scale: 1 / scale, alignment: Alignment.topLeft, child: small);
  }

  /// Tỉ lệ độ phân giải đang áp (lớp debug).
  double _renderScale = 1;

  /// Lớp phủ trên cảnh có `RepaintBoundary` riêng, phủ kín ô (con là `Stack(fit: expand)` hoặc widget tự đặt chỗ):
  /// nội dung đổi mỗi khung chỉ vẽ lại lớp này. Không có thì `markNeedsPaint` lan tới boundary của route và cả trang
  /// (nút Material của lớp debug, joystick, cụm nút…) vẽ lại mỗi khung. Chỗ trống không nhận chạm (Stack chỉ trúng khi
  /// trúng con) → chạm đi xuống lớp camera như cũ.
  static Widget _layer(Widget child) => Positioned.fill(child: RepaintBoundary(child: child));

  List<Widget> _debugOverlay() {
    final scene = _scene;
    return [
      // Chip đổi mỗi giây: lớp riêng, khỏi vẽ lại cả trang.
      _layer(Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 12,
            top: 12,
            child: IgnorePointer(
              child: ValueListenableBuilder<_FpsSample>(
                valueListenable: _fps,
                builder: (context, fps, _) => _DebugChip(
                  text: _error != null
                      ? 'ERR $_error'
                      : scene == null
                          ? 'loading…'
                          : _debugText(fps, scene),
                  color: const Color(0xAA000000),
                  textColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      )),
      Positioned(
        right: 12,
        top: 12,
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (flag, icon, tip) in const [
                (Shop3dRequires.oven2, Icons.local_fire_department, 'oven 2'),
                (Shop3dRequires.cafeTables, Icons.table_restaurant, 'cafe tables'),
                (Shop3dRequires.kitchen2, Icons.kitchen, 'kitchen 2'),
                (Shop3dRequires.caseStand, Icons.cake, 'cake stand'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DebugButton(icon: icon, tooltip: tip, on: _owned.contains(flag), onTap: () => _toggle(flag)),
                ),
              _DebugButton(icon: Icons.threesixty, tooltip: 'reset camera', on: false, onTap: _onDoubleTap),
              if (_pilot case final pilot?) ...[
                const SizedBox(height: 8),
                _DebugButton(
                    icon: Icons.campaign_rounded, tooltip: 'event', on: false, onTap: () => pilot.forceEvent()),
                const SizedBox(height: 8),
                _DebugButton(
                    icon: Icons.restart_alt_rounded, tooltip: 'reset items', on: false, onTap: pilot.resetItems),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  /// Chữ chip debug: FPS · mức · entity trong scene / đã tạo (tĩnh) · material · tam giác · độ phân giải 3D (khi < 1) ·
  /// ms Dart mỗi khung (cả vòng cập nhật) · chibi: lệnh setTransform đã gửi / số bộ phận, ms cập nhật chibi.
  String _debugText(_FpsSample fps, Shop3dScene scene) {
    final b = StringBuffer()
      ..write('${fps.label} · ${_level.name}${widget.quality == Shop3dQualityMode.auto ? ' (auto)' : ''}')
      ..write(_refreshCap != null ? ' cap $_refreshCap' : '')
      ..write(' · ${scene.drawnEntityCount}/${scene.entityCount} ent (static ${scene.staticEntityCount})')
      ..write(' · ${scene.materialCount} mat · ${(scene.triangleCount / 1000).toStringAsFixed(1)}k tri')
      ..write(_renderScale < 1 ? ' · px ×${_renderScale.toStringAsFixed(2)}' : '')
      ..write(' · dart ${(_dartMicros / 1000).toStringAsFixed(2)} ms');
    if (scene.chibiTransformsPerUpdate > 0) {
      b.write(' · chibi ${scene.transformsSentPerUpdate.round()}/${scene.chibiTransformsPerUpdate} xf '
          '${(scene.chibiUpdateMicros / 1000).toStringAsFixed(2)} ms');
    }
    return b.toString();
  }
}

/// Cụm nút khi ghép vào thành phố: A (Ø96) + B "Ném" (Ø68, khi cầm đồ ném được) + C "Vẫy chào" (Ø60) — cùng vị trí /
/// kiểu với [Shop3dActionCluster] ([Shop3dActionLayout]) nhưng không có "Xong" (Mai luôn được điều khiển).
/// Nút "Ra ngoài" góc phải trên khi ghép thành phố (trong tiệm lớp minimap của phố ẩn nên góc này trống).
class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.label, required this.visible, required this.onPressed});

  final String label;
  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Positioned(
      right: 12 + pad.right,
      top: 12 + pad.top,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Shop3dStyle.fade,
          child: Shop3dPillButton(
            key: const ValueKey('shop3d-exit'),
            label: label,
            icon: Icons.door_front_door_rounded,
            onPressed: onPressed,
            height: Shop3dStyle.minTap,
          ),
        ),
      ),
    );
  }
}

/// Ô đánh dấu chỗ đứng trên sàn: elip phẳng bơ nhạt, viền mảnh, không nhận chạm.
class _FloorMark extends StatelessWidget {
  const _FloorMark({super.key, required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.elliptical(rect.width / 2, rect.height / 2)),
            color: AppColors.butter.withValues(alpha: 0.28),
            border: Border.all(color: AppColors.butter.withValues(alpha: 0.8), width: 2),
          ),
        ),
      ),
    );
  }
}

class _EmbedCluster extends StatelessWidget {
  const _EmbedCluster({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.primarySemanticsLabel,
    required this.showThrow,
    required this.throwLabel,
    required this.onThrowTap,
    required this.onThrowCharged,
    required this.waveLabel,
    required this.onWave,
    required this.waveCooldown,
    required this.visible,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? primarySemanticsLabel;
  final bool showThrow;
  final String throwLabel;
  final VoidCallback onThrowTap;
  final ValueChanged<double> onThrowCharged;
  final String waveLabel;
  final VoidCallback onWave;
  final ValueListenable<double> waveCooldown;
  final bool visible;

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
                  key: const ValueKey('shop3d-wave'),
                  diameter: Shop3dActionLayout.waveDiameter,
                  label: waveLabel,
                  icon: Icons.waving_hand_rounded,
                  onTap: onWave,
                  cooldown: waveCooldown,
                ),
              ),
              if (showThrow)
                place(
                  l.throwButton,
                  Shop3dActionLayout.throwDiameter,
                  Shop3dThrowButton(
                    key: const ValueKey('shop3d-throw'),
                    label: throwLabel,
                    icon: Icons.sports_handball_rounded,
                    onTap: onThrowTap,
                    onCharged: onThrowCharged,
                  ),
                ),
              place(
                l.primary,
                Shop3dActionLayout.primaryDiameter,
                Shop3dRoundActionButton(
                  key: const ValueKey('shop3d-primary'),
                  diameter: Shop3dActionLayout.primaryDiameter,
                  label: primaryLabel,
                  icon: primaryIcon,
                  onTap: onPrimary,
                  semanticsLabel: primarySemanticsLabel,
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

/// FPS một giây: khung Filament (native: đã vẽ; web: số lần vòng render chạy), khung Filament bỏ (native), khung
/// Flutter đã raster.
class _FpsSample {
  const _FpsSample(this.filament, this.skipped, this.ui);

  final int filament;
  final int skipped;
  final int ui;

  String get label => '$filament fps${skipped > 0 ? ' (skip $skipped)' : ''} · ui $ui';
}

class _PickLabel {
  const _PickLabel(this.id, this.position);

  final String id;
  final Offset position;
}

class _DebugChip extends StatelessWidget {
  const _DebugChip({required this.text, required this.color, this.textColor = AppColors.chocolate, this.small = false});

  final String text;
  final Color color;
  final Color textColor;

  /// Nhãn nhỏ (id dưới chân nhân vật ở màn xếp hàng).
  final bool small;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(small ? 8 : 10)),
        child: Padding(
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(text,
              style: TextStyle(
                  color: textColor,
                  fontSize: small ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      );
}

/// Nút icon 52×52 (≥ 48 dp), nền bơ khi bật, viền nâu 2 px.
class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.icon, required this.tooltip, required this.on, required this.onTap});

  final IconData icon;
  final String tooltip;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: on ? AppColors.butter : AppColors.cream.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.caramel, width: 2)),
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: SizedBox(
                  width: 52, height: 52, child: Icon(icon, color: on ? AppColors.chocolate : AppColors.caramel))),
        ),
      );
}

/// Vị trí màn (đã chiếu) của lớp phủ bám đầu nhân vật trong một khung.
class _OverlayFrame {
  const _OverlayFrame({this.bubbles = const [], this.chips = const [], this.arrow, this.menu, this.mark});

  static const empty = _OverlayFrame();

  /// Lệch dưới ngưỡng này (px logic) coi như đứng yên.
  static const _epsilon = 0.25;

  final List<(PilotBubble, Offset)> bubbles;
  final List<(String, Offset)> chips;
  final Offset? arrow;
  final Offset? menu;

  /// Ô đánh dấu chỗ đứng trên sàn (hình elip bao, toạ độ màn).
  final Rect? mark;

  /// Cùng bong bóng / chip (cùng đối tượng, cùng thứ tự) và mọi vị trí lệch < [_epsilon].
  bool sameAs(_OverlayFrame o) {
    if (identical(this, o)) return true;
    if (bubbles.length != o.bubbles.length || chips.length != o.chips.length) return false;
    for (var i = 0; i < bubbles.length; i++) {
      if (!identical(bubbles[i].$1, o.bubbles[i].$1) || !_near(bubbles[i].$2, o.bubbles[i].$2)) return false;
    }
    for (var i = 0; i < chips.length; i++) {
      if (chips[i].$1 != o.chips[i].$1 || !_near(chips[i].$2, o.chips[i].$2)) return false;
    }
    final a = mark, b = o.mark;
    if ((a == null) != (b == null)) return false;
    if (a != null && (!_near(a.center, b!.center) || (a.width - b.width).abs() >= _epsilon)) return false;
    return _near(arrow, o.arrow) && _near(menu, o.menu);
  }

  static bool _near(Offset? a, Offset? b) {
    if (a == null || b == null) return a == b;
    return (a.dx - b.dx).abs() < _epsilon && (a.dy - b.dy).abs() < _epsilon;
  }
}

/// Lia camera (điểm nhìn + yaw / pitch / khoảng cách) trong [seconds] giây.
class _CamTween {
  _CamTween({
    required this.fromX,
    required this.fromY,
    required this.fromZ,
    required this.fromYaw,
    required this.fromPitch,
    required this.fromDist,
    required this.toX,
    required this.toY,
    required this.toZ,
    required this.toYaw,
    required this.toPitch,
    required this.toDist,
    required this.seconds,
  });

  final double fromX, fromY, fromZ, fromYaw, fromPitch, fromDist;
  final double toX, toY, toZ, toYaw, toPitch, toDist;
  final double seconds;
  double t = 0;
}
