import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Material, Texture, Transform, View;

import '../../core/app_scope.dart';
import '../../core/city/city_config.dart';
import '../../game/shop3d/chibi/chibi_actor.dart' show ChibiAction;
import '../../game/shop3d/shop3d_frame_driver.dart';
import '../../game/shop3d/shop3d_quality.dart';
import '../../game/shop3d/shop3d_scene.dart';
import '../../game/shop3d/shop3d_surface.dart';
import '../../game/town3d/town_branch_ui.dart';
import '../../game/town3d/town_layout.dart';
import '../../game/town3d/town_pilot.dart';
import '../../game/town3d/town_scene.dart';
import 'intro_stage.dart';

/// Lớp 3D của cảnh mở đầu: phố "Tiệm Bánh" dựng y như màn chơi (`Town3dView`) — viewer riêng, lớp tiệm [Shop3dScene]
/// chỉ giữ đèn / IBL / material (không dựng nội thất), lớp phố [TownScene] + [TownPilot] (Mai theo kiểu tóc trong ví,
/// 3 chủ quán, mặt tiền chi nhánh theo cấp) — rồi đạo diễn theo đồng hồ của `IntroScreen` ([IntroStageHost.time]):
/// - Mai: pilot ở chế độ `transit` (không lái, không vùng / băng tên / XP); đi bộ dọc vỉa hè từ lô bên phải tới trước
///   cửa tiệm của bà (đặt vị trí mỗi khung → nhịp bước theo quãng đã đi), nhìn vào tiệm, quay ra phố, nhảy vui, vẫy.
/// - Máy quay: nội suy giữa các khung hình (toạ độ theo chỗ Mai xuất hiện `TownLayout.spawn`), điểm nhìn bám Mai; giảm
///   chuyển động → mỗi cảnh một góc đứng yên, Mai đứng sẵn trước cửa.
///
/// Vòng cập nhật chạy trong request-frame hook của Filament như phố (native: [Shop3dFrameDriver] tự vẽ). Nằm trong
/// `RefFrame` (khung W×720 co giãn) nên ảnh 3D được cấp đúng số điểm ảnh thật của màn ([_scaled]). Dựng xong →
/// [IntroStageHost.ready]; lỗi → [IntroStageHost.failed]. [IntroStageHost.release] gỡ ThermionWidget rồi huỷ cảnh +
/// viewer theo đúng thứ tự của `Town3dView.dispose` (phố tạo viewer mới sau đó).
class IntroStage3d extends StatefulWidget {
  const IntroStage3d(this.host, {super.key});

  final IntroStageHost host;

  @override
  State<IntroStage3d> createState() => _IntroStage3dState();
}

/// Một khung hình của máy quay: điểm nhìn (lệch [dx] / [dz] so với chỗ Mai xuất hiện, cao [y]; [follow] = mức bám theo
/// Mai trên trục x), hướng [yaw] (0 = từ phía nam nhìn lên bắc, như camera phố), góc cúi [pitch] (độ), khoảng cách
/// [dist] (m).
class _Shot {
  const _Shot({
    required this.dx,
    required this.follow,
    required this.y,
    required this.dz,
    required this.yaw,
    required this.pitch,
    required this.dist,
  });

  final double dx, follow, y, dz, yaw, pitch, dist;
}

class _IntroStage3dState extends State<IntroStage3d> {
  /// Như camera phố.
  static const fovDeg = 40.0;
  static const _near = 0.1;
  static const _far = 80.0;

  /// Mai bắt đầu đi lúc này (giây) từ chỗ cách cửa [_walkFrom] m về bên phải, tới cửa sau [_arriveIn] giây của cảnh 2.
  static const _walkStart = 0.8;
  static const _walkFrom = 7.5;
  static const _arriveIn = 3.0;

  /// Chèn ThermionWidget xong chờ chừng này (texture xin sau 100 ms + khung đầu) rồi mới báo dựng xong.
  static const _settle = Duration(milliseconds: 400);

  /// Khung hình: đầu cảnh 1 (phố từ trên cao, phía biển), đầu cảnh 2, Mai tới cửa, đầu cảnh 3 (mặt tiền tiệm của
  /// bà), Mai quay ra (góc ba phần tư phía trước), đầu cảnh 4, hết (nâng lên biển hiệu).
  static const _shots = [
    _Shot(dx: 3, follow: 0, y: 1.8, dz: -1.6, yaw: 0.30, pitch: 28, dist: 28),
    _Shot(dx: 3, follow: 0.85, y: 1.3, dz: -0.6, yaw: 0.42, pitch: 15, dist: 11),
    _Shot(dx: 0, follow: 1, y: 1.4, dz: -0.8, yaw: 0.18, pitch: 12, dist: 9),
    _Shot(dx: 0, follow: 1, y: 1.7, dz: -1.2, yaw: 0, pitch: 10, dist: 8.5),
    _Shot(dx: 0, follow: 1, y: 1.0, dz: -0.2, yaw: 0.28, pitch: 9, dist: 5.6),
    _Shot(dx: 0, follow: 1, y: 0.95, dz: -0.1, yaw: 0.16, pitch: 7, dist: 4.6),
    _Shot(dx: 0, follow: 1, y: 2.6, dz: -1.2, yaw: 0.06, pitch: 12, dist: 8.5),
  ];

  /// Giảm chuyển động: khung hình đứng yên của từng cảnh.
  static const _reducedShots = [1, 3, 5, 5];

  final _layout = TownLayout.forDistrict(CityConfig.alpha.district('bakery_street'));

  IntroStageHost get _host => widget.host;
  late final List<double> _times = () {
    final s = _host.starts;
    return [s[0], s[1], s[1] + _arriveIn, s[2], s[2] + 1.2, s[3], s[4]];
  }();

  ThermionViewer? _viewer;
  Camera? _camera;
  Shop3dScene? _shop;
  TownScene? _town;
  TownPilot? _pilot;
  Shop3dFrameDriver? _driver;
  late Shop3dGraphics _graphics;
  Future<void>? _initJob;
  Future<void>? _teardown;
  bool _disposed = false;
  bool _unmounted = false;
  bool _shown = false;
  Size _size = Size.zero;

  // Vòng cập nhật.
  final _clock = Stopwatch();
  int _frameErrors = 0;
  bool _lookAtBusy = false;
  final _eye = Vector3.zero();
  final _focus = Vector3.zero();
  final _up = Vector3(0, 1, 0);

  // Nhịp của Mai (mỗi việc một lần).
  bool _arrived = false;
  bool _turned = false;
  bool _joyed = false;
  bool _waved = false;

  @override
  void initState() {
    super.initState();
    _host.release = _release;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initJob != null) return;
    final services = AppScope.read(context);
    final q = services.debug.raw;
    final preset = Shop3dQualityMode.parse(q['quality']) == Shop3dQualityMode.low
        ? Shop3dGraphics.low
        : Shop3dGraphics.high;
    _graphics = Shop3dGraphicsOverrides.fromParams(q).apply(kIsWeb ? preset.forWeb() : preset);
    _initJob = _init(services);
  }

  Future<void> _init(AppServices services) async {
    try {
      final viewer = _viewer = await ThermionFlutterPlugin.createViewer();
      if (_disposed) return;
      ThermionFlutterPlugin.instance.setTargetFramerate(_graphics.targetFps);
      // Hook cập nhật đăng ký TRƯỚC hook vẽ của driver (native) — cập nhật xong rồi mới vẽ cùng khung.
      await viewer.app.registerRequestFrameHook(_frameHook);
      if (Shop3dFrameDriver.supported) {
        final driver = _driver = Shop3dFrameDriver(viewer);
        await driver.start();
      }
      if (_disposed) return;
      final camera = _camera = await viewer.getActiveCamera();
      final aspect = _size.isEmpty ? 16 / 9 : _size.width / _size.height;
      await camera.setLensProjection(
          near: _near, far: _far, focalLength: 12.0 / math.tan(fovDeg * math.pi / 360.0), aspect: aspect);
      if (_disposed) return;
      final wallet = services.game.wallet;
      final look = wallet.look;
      // Lớp tiệm: chỉ đèn + IBL + đồ họa + material dùng chung (nội thất không dựng).
      final shop = _shop = await Shop3dScene.build(
        viewer,
        owned: const {},
        graphics: _graphics,
        deferContent: true,
        active: false,
      );
      if (_disposed) return;
      unawaited(shop.setShadowFar(30));
      final pilot = _pilot = TownPilot(_layout, wallet, look: look)..beginTransit();
      if (!_host.reduceMotion) {
        // Mai xuất phát ở vỉa hè bên phải, quay mặt về phía tiệm (đi sang trái, -x).
        final sp = _layout.spawn;
        pilot.mai
          ..pose.x = sp.x + _walkFrom
          ..pose.z = sp.z
          ..pose.yaw = -math.pi / 2
          ..driveFace(-math.pi / 2);
      }
      final town = _town = await TownScene.build(
        viewer,
        layout: _layout,
        materials: shop,
        pilot: pilot,
        look: look,
        graphics: _graphics,
      );
      if (_disposed) return;
      // Mặt tiền chi nhánh theo cấp (lô trống = 0), như phố.
      await Future.wait([
        for (final e in TownBranchUi.levels(_layout.district, services.game.branches).entries)
          town.setBranchLevel(e.key, e.value),
      ]);
      if (_disposed) return;
      // ThermionWidget chèn vào cây chỉ khi cảnh đã dựng xong (luồng chính rảnh). Web: widget xin texture sau 100 ms
      // và tìm canvas trong DOM; nếu luồng chính còn bận dựng cảnh, platform view của canvas chưa kịp ghép vào DOM →
      // "Failed to size for canvas" + lỗi null, texture không được cấp, cảnh trống. Chờ texture xong rồi mới hiện.
      _shown = true;
      if (mounted) setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(_settle);
      if (_disposed) return;
      _host.ready();
    } catch (e, st) {
      debugPrint('IntroStage3d init failed: $e\n$st');
      if (!_disposed) _host.failed();
    }
  }

  // ---- Vòng cập nhật ------------------------------------------------------------------------------------------

  Future<void> _frameHook() async {
    try {
      _onFrame();
    } catch (e, st) {
      if (_frameErrors++ == 0) debugPrint('IntroStage3d: frame update failed: $e\n$st');
    }
  }

  void _onFrame() {
    final town = _town, pilot = _pilot;
    if (_disposed || !_shown || town == null || pilot == null) return;
    final first = !_clock.isRunning;
    final dt = first ? 1 / 60 : math.min(0.1, _clock.elapsedMicroseconds / 1e6);
    _clock
      ..reset()
      ..start();
    final t = _host.time.value;
    _direct(pilot, t);
    town.tick(dt);
    _aim(t, pilot.mai.pose.x);
  }

  /// Mai theo đồng hồ: đi tới cửa → nhìn vào tiệm → quay ra phố → nhảy vui → vẫy tay.
  void _direct(TownPilot pilot, double t) {
    final mai = pilot.mai;
    final sp = _layout.spawn;
    final reduce = _host.reduceMotion;
    if (!reduce && !_arrived) {
      final arrive = _times[2];
      if (t < arrive) {
        final u = ((t - _walkStart) / (arrive - _walkStart)).clamp(0.0, 1.0);
        mai.driveMove(sp.x + _walkFrom * (1 - u), sp.z, -math.pi / 2);
        return;
      }
      _arrived = true;
      mai.driveMove(sp.x, sp.z, math.pi);
    }
    final local = t - _host.starts[2];
    if (!_turned && local >= IntroBeats.turn) {
      _turned = true;
      mai.driveFace(_faceCamera);
    }
    if (!_joyed && local >= IntroBeats.joy) {
      _joyed = true;
      if (reduce) {
        mai.perform(ChibiAction.wave, 1.6, freeze: 0);
      } else {
        mai.perform(ChibiAction.happy, 1.1, faceYaw: _faceCamera);
      }
    }
    if (!reduce && !_waved && local >= IntroBeats.wave) {
      _waved = true;
      mai.perform(ChibiAction.wave, 1.6, freeze: 0);
    }
  }

  /// Hướng Mai nhìn về máy quay ở góc ba phần tư phía trước.
  static final double _faceCamera = _shots[5].yaw;

  /// Máy quay theo đồng hồ → `camera.lookAt` (dời gốc lớp phố; tối đa một lệnh đang chờ).
  void _aim(double t, double maiX) {
    final camera = _camera;
    if (camera == null || _lookAtBusy) return;
    final _Shot a, b;
    var u = 0.0;
    if (_host.reduceMotion) {
      var scene = 0;
      while (scene < _reducedShots.length - 1 && t >= _host.starts[scene + 1]) {
        scene++;
      }
      a = b = _shots[_reducedShots[scene]];
    } else {
      var i = 0;
      while (i < _times.length - 2 && t >= _times[i + 1]) {
        i++;
      }
      a = _shots[i];
      b = _shots[i + 1];
      u = Curves.easeInOutSine.transform(((t - _times[i]) / (_times[i + 1] - _times[i])).clamp(0.0, 1.0));
    }
    double mix(double p, double q) => p + (q - p) * u;
    final sp = _layout.spawn;
    final follow = mix(a.follow, b.follow);
    final tx = mix(sp.x + a.dx, sp.x + b.dx) * (1 - follow) + maiX * follow;
    final ty = mix(a.y, b.y), tz = sp.z + mix(a.dz, b.dz);
    final yaw = mix(a.yaw, b.yaw), pitch = mix(a.pitch, b.pitch) * math.pi / 180, dist = mix(a.dist, b.dist);
    final cp = math.cos(pitch);
    const ox = TownScene.originX, oz = TownScene.originZ;
    _focus.setValues(tx + ox, ty, tz + oz);
    _eye.setValues(
        tx + dist * math.sin(yaw) * cp + ox, ty + dist * math.sin(pitch), tz + dist * math.cos(yaw) * cp + oz);
    _lookAtBusy = true;
    camera.lookAt(_eye, focus: _focus, up: _up).whenComplete(() => _lookAtBusy = false);
  }

  // ---- Gỡ -----------------------------------------------------------------------------------------------------

  /// Gỡ ThermionWidget (texture huỷ theo nó), chờ việc dựng đang dở, rồi huỷ theo thứ tự của `Town3dView.dispose`.
  Future<void> _release() => _teardown ??= () async {
        _disposed = true;
        if (mounted && !_unmounted) {
          setState(() {});
          await WidgetsBinding.instance.endOfFrame;
        }
        await _initJob;
        final viewer = _viewer, shop = _shop, driver = _driver;
        _viewer = null;
        _shop = null;
        _camera = null;
        _town?.dispose();
        _town = null;
        _pilot?.dispose();
        _pilot = null;
        if (viewer == null) return;
        try {
          await driver?.stop();
          await viewer.app.unregisterRequestFrameHook(_frameHook);
          await shop?.dispose();
          await ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
          await viewer.dispose();
          await ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
        } catch (e) {
          debugPrint('IntroStage3d dispose failed: $e');
        }
      }();

  @override
  void dispose() {
    _unmounted = true;
    unawaited(_release());
    super.dispose();
  }

  // ---- Giao diện ----------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      final viewer = _viewer;
      if (viewer == null || !_shown || _disposed) return const SizedBox.expand();
      return _scaled(context, Shop3dSurface(viewer: viewer));
    });
  }

  /// Khung W×720 của `RefFrame` được thu [fit] lần trên màn: báo devicePixelRatio nhân [fit] (và tỉ lệ vẽ của mức đồ
  /// họa, trần điểm ảnh web) để texture có đúng số điểm ảnh hiện thật. Web: thermion đặt cỡ CSS của canvas = cỡ ảnh /
  /// devicePixelRatio THẬT của cửa sổ → thu lại bằng transform như `Town3dView`; native: Texture tự giãn kín ô.
  Widget _scaled(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final screen = view.physicalSize / view.devicePixelRatio;
    // RefFrame (Center + FittedBox) chỉ thu nhỏ khung, không phóng to.
    final fit = _size.isEmpty || screen.isEmpty
        ? 1.0
        : math.min(1.0, math.min(screen.width / _size.width, screen.height / _size.height));
    final scale = fit * _graphics.renderScaleFor(_size.width * fit, _size.height * fit, view.devicePixelRatio);
    // Luôn cùng một cấu trúc cây (kể cả khi scale = 1): đổi cỡ cửa sổ không làm ThermionWidget / platform view của
    // canvas bị gỡ rồi dựng lại.
    final inner = MediaQuery(data: mq.copyWith(devicePixelRatio: mq.devicePixelRatio * scale), child: child);
    if (!kIsWeb) return inner;
    return Transform.scale(scale: 1 / scale, alignment: Alignment.topLeft, child: inner);
  }
}
