import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/city/city_config.dart';
import '../../core/city/city_wallet.dart';
import '../../core/city/mai_look.dart';
import '../../core/city/restaurant_menu.dart';
import '../shop3d/chibi/chibi_actor.dart';
import '../shop3d/chibi/chibi_characters.dart';
import '../shop3d/chibi/chibi_regulars.dart';
import '../shop3d/chibi/chibi_sizes.dart';
import '../shop3d/interact/pilot.dart' show Shop3dPilot;
import '../shop3d/interact/shop3d_nav.dart';
import '../shop3d/shop3d_layout.dart' show Shop3dSpot;
import 'town_layout.dart';
import 'town_nav.dart';
import 'town_rules.dart';

/// Trạng thái của Mai ngoài phố.
enum TownMode {
  /// Đi dạo (joystick / phím), nút A theo vùng.
  walk,

  /// Bảng thực đơn quán ăn đang mở: Mai đứng ở quầy.
  menu,

  /// Đi tới ghế hiên, ngồi ăn, đứng dậy (tự chạy, không điều khiển).
  eating,

  /// Bảng làm tóc đang mở: Mai quay ra phố (camera lia sát).
  salon,

  /// Đang chuyển cảnh (vào / ra tiệm của bà).
  transit,
}

/// Trạng thái nút / joystick (đổi ít — lớp view dựng lại cụm nút khi đổi).
@immutable
class TownHud {
  const TownHud({this.action = TownAction.none, this.lotId, this.controls = true});

  /// Thao tác của nút A (none = mờ).
  final TownAction action;

  /// Lô của vùng Mai đang đứng (null = ngoài mọi vùng).
  final String? lotId;

  /// Hiện joystick + cụm nút (chỉ khi đi dạo).
  final bool controls;

  @override
  bool operator ==(Object other) =>
      other is TownHud && other.action == action && other.lotId == lotId && other.controls == controls;

  @override
  int get hashCode => Object.hash(action, lotId, controls);
}

enum TownEventKind {
  /// Bước vào vùng của lô [TownEvent.lot] → băng tên.
  banner,

  /// Lần ghé đầu (đã cộng XP qua `CityWallet.markFirstVisit`) → toast `cityFirstVisit`.
  firstVisit,

  /// Mai đã ngồi, món lên bàn → toast `cityEating`.
  eatingStart,

  /// Ăn xong, Mai đứng dậy → toast `cityXpGain` + `cityBuffFull` (+ `cityAteToday` nếu [EatResult.reducedXp]).
  eatingDone,

  /// Vừa mua kiểu tóc mới → hiệu ứng "ta-da".
  tada,
}

/// Sự kiện cho lớp view (toast, băng tên, hiệu ứng) — lấy ra bằng [TownPilot.takeEvents].
class TownEvent {
  const TownEvent(this.kind, {this.lot, this.eat});

  final TownEventKind kind;
  final LotDef? lot;
  final EatResult? eat;
}

/// Điều phối Mai ngoài phố (thành phố V3, giai đoạn 1 — docs/v3/city-gd1-spec.md). Dart thuần, không import thermion:
/// lớp cảnh (`town_scene.dart`) chỉ việc dựng entity cho [actors] và gửi transform sau mỗi [update]; lớp view đọc [hud]
/// / [takeEvents] và gọi các thao tác.
///
/// - Lái Mai bằng joystick theo hướng camera ([setStick], [cameraYaw]) — cùng công thức / tốc độ với `Shop3dPilot`
///   (đi 0,35–1,0 ×, chạy 1,6 ×), va chạm ở [nav] (`TownNav`: `Shop3dNav` với biên quận).
/// - Vùng cửa / quầy ([TownRules]): đổi vùng → băng tên, lần ghé đầu quán ăn / tiệm tóc (+XP), chủ quán chào.
/// - Quán ăn: [beginMenu] / [endMenu] (bảng thực đơn), [order] (ví trừ xu, cộng XP) → Mai tự đi A* tới ghế hiên, ngồi
///   ăn [eatSeconds] s (món hiện trên bàn: [dishVisible]), đứng dậy.
/// - Tiệm tóc: [beginSalon] (Mai quay ra phố cho camera cận) / [endSalon].
/// - Chủ quán NPC đứng sau ô cửa quầy ([keepers]): khách thường có sẵn, đứng trên bậc kê sau quầy, đứng / làm việc /
///   vẫy tay nhẹ, quay ra phố.
class TownPilot {
  TownPilot(this.layout, this.wallet, {MaiLook? look})
      : nav = TownNav.of(layout),
        zones = TownRules.zonesOf(layout) {
    final s = layout.spawn;
    mai = ChibiActor(ChibiSizes.fit(buildMai(look ?? wallet.look)), const [ChibiStep.act(ChibiAction.stand, 1)],
        x: s.x, z: s.z, yaw: s.yaw, seed: 41);
    mai.startDriving();
    keepers = [
      for (final (kind, id, seed) in const [
        (LotKind.restaurant, restaurantKeeperId, 97),
        (LotKind.salon, salonKeeperId, 101),
      ])
        if (_spotsOf(kind)?.keeper case final k?)
          ChibiActor(ChibiSizes.fit(ChibiRegulars.build(id)), keeperLoop(k.yaw),
              x: k.x, z: k.z, yaw: k.yaw, seed: seed, floor: _keeperFloor),
    ];
    zone = TownRules.zoneAt(zones, mai.pose.x, mai.pose.z);
    _lastBannerLot = zone?.lotId;
    _decide();
  }

  final TownLayout layout;
  final CityWallet wallet;
  final Shop3dNav nav;
  final List<TownZone> zones;

  late final ChibiActor mai;

  /// Chủ quán NPC (quán ăn, tiệm tóc).
  late final List<ChibiActor> keepers;

  /// Mọi nhân vật của lớp phố (Mai đầu tiên).
  List<ChibiActor> get actors => [mai, ...keepers];

  // ---- Thông số ---------------------------------------------------------------------------------------------

  /// Chủ quán "Bếp Hải Đăng": bác hải mã (khách thường `regular_13`, hợp quán hải sản ven biển); chủ tiệm tóc "Vỏ Sò":
  /// cô poodle lông xù (`regular_10`).
  static const String restaurantKeeperId = 'regular_13';
  static const String salonKeeperId = 'regular_10';

  /// Bậc kê sau quầy cho chủ quán (thú thấp hơn mặt quầy 0,93 m): ván dưới ô cửa che chân bậc.
  static const double keeperStep = 0.3;

  /// Ghế hiên quán ăn: mặt ngồi 0,45 m (`_chair` trong town_layout.dart). Bàn: mặt khăn 0,77 m (`_table`).
  static const double seatTop = 0.45;
  static const double tableTop = 0.77;

  /// Món đặt trên bàn cách tâm ghế chừng này (m) theo hướng Mai nhìn.
  static const double dishReach = 0.5;

  /// Ngồi ăn bao lâu (s) — toast `cityEating` hiện trong lúc này.
  static const double eatSeconds = 3;

  /// Tự đi tới ghế nhanh hơn dáng đi thường; quá hạn thì dời thẳng tới ghế.
  static const double seatWalkSpeed = 1.4;
  static const double seatWalkLimit = 9;

  /// Băng tên cùng một lô không hiện lại trong chừng này giây (đi qua lại mép vùng).
  static const double bannerRepeat = 6;

  /// Vẫy chào: hồi chiêu (s), chủ quán trong bán kính này (m) vẫy lại.
  static const double waveCooldown = 2.5;
  static const double waveRange = 5;

  static double _keeperFloor(double x, double z) => keeperStep;

  /// Kịch bản chủ quán: đứng, làm việc, ngó nghiêng, vẫy tay — luôn quay ra phố ([yaw]).
  static List<ChibiStep> keeperLoop(double yaw) => [
        ChibiStep.act(ChibiAction.stand, 3.5, jitter: 2.5, faceYaw: yaw),
        ChibiStep.act(ChibiAction.work, 2.4, jitter: 1.5, faceYaw: yaw),
        ChibiStep.act(ChibiAction.stand, 2.5, jitter: 2, faceYaw: yaw + 0.35),
        ChibiStep.act(ChibiAction.wave, 1.6, faceYaw: yaw),
      ];

  // ---- Trạng thái -------------------------------------------------------------------------------------------

  TownMode _mode = TownMode.walk;
  TownMode get mode => _mode;

  /// Vùng Mai đang đứng.
  TownZone? zone;

  /// Đồng hồ (giây).
  double now = 0;

  final _hud = ValueNotifier<TownHud>(const TownHud());
  ValueListenable<TownHud> get hud => _hud;

  final List<TownEvent> _events = [];

  /// Món đang ăn (id `RestaurantMenu`) và có đang hiện trên bàn không.
  String? dishId;
  bool dishVisible = false;

  /// Chỗ đặt món (x, y = mặt bàn, z, yaw) — chỉ có nghĩa khi [dishVisible].
  ({double x, double y, double z, double yaw}) dishPose = (x: 0, y: 0, z: 0, yaw: 0);

  EatResult? _eat;
  int _eatPhase = 0; // 0 không; 1 đang đi tới ghế; 2 ngồi
  String? _lastBannerLot;
  double _lastBannerAt = -1e9;
  double _lastWave = -1e9;

  double _jx = 0, _jy = 0;
  bool _run = false;

  /// Yaw camera (rad) — hướng đi theo camera (`TownCamera.yaw`).
  double cameraYaw = 0;

  final _move = NavMove();

  // ---- Đầu vào ------------------------------------------------------------------------------------------------

  /// Joystick: [jx], [jy] trong [−1; 1] (đẩy lên = âm), [running] (có trễ, từ joystick / Shift).
  void setStick(double jx, double jy, {bool running = false}) {
    _jx = jx;
    _jy = jy;
    _run = running;
  }

  /// Lấy (và xoá) các sự kiện đang chờ.
  List<TownEvent> takeEvents() {
    if (_events.isEmpty) return const [];
    final out = List<TownEvent>.of(_events);
    _events.clear();
    return out;
  }

  void dispose() => _hud.dispose();

  TownLotSpots? _spotsOf(LotKind kind) {
    final lot = layout.district.lotOfKind(kind);
    return lot == null ? null : layout.spots[lot.id];
  }

  ChibiActor? _keeperOf(String lotId) {
    final kind = layout.district.lot(lotId).kind;
    final id = switch (kind) {
      LotKind.restaurant => restaurantKeeperId,
      LotKind.salon => salonKeeperId,
      _ => null,
    };
    for (final k in keepers) {
      if (k.id == id) return k;
    }
    return null;
  }

  double get _radius => math.min(mai.model.radius, TownNav.radius);

  static double _yawTo(ChibiActor from, double x, double z) => math.atan2(x - from.pose.x, z - from.pose.z);

  // ---- Mỗi khung ----------------------------------------------------------------------------------------------

  /// Tiến [dt] giây: lái Mai / tự đi tới ghế, vùng, rồi chuyển động của mọi nhân vật ([actors]).
  void update(double dt) {
    if (dt <= 0) return;
    if (dt > 0.1) dt = 0.1;
    now += dt;
    switch (_mode) {
      case TownMode.walk:
        _drive(dt);
        _track();
      case TownMode.eating:
        _eating();
      case TownMode.menu:
      case TownMode.salon:
      case TownMode.transit:
        mai.driveRunning = false;
    }
    for (final a in actors) {
      a.update(dt, const {});
    }
  }

  void _drive(double dt) {
    final a = mai;
    if (!a.driven || a.frozen) {
      a.driveRunning = false;
      return;
    }
    final mag = math.min(1.0, math.sqrt(_jx * _jx + _jy * _jy));
    final k = Shop3dPilot.speedFactor(mag, running: _run);
    if (k <= 0) {
      a.driveRunning = false;
      return;
    }
    final (dx, dz) = Shop3dPilot.stickToWorld(_jx, _jy, cameraYaw);
    final len = math.sqrt(dx * dx + dz * dz);
    if (len < 1e-6) return;
    final ux = dx / len, uz = dz / len;
    final want = math.atan2(ux, uz);
    final turn = math.max(Shop3dPilot.minTurnFactor, math.cos(_wrap(want - a.pose.yaw)));
    final step = a.model.gait.speed * k * turn * dt;
    nav.slide(a.pose.x, a.pose.z, ux * step, uz * step, _radius, out: _move);
    a.driveMove(_move.x, _move.z, want);
    a.driveRunning = _run;
  }

  /// Đổi vùng: băng tên (không lặp cùng lô trong [bannerRepeat] s), lần ghé đầu, chủ quán chào khi tới quầy.
  void _track() {
    final z = TownRules.zoneAt(zones, mai.pose.x, mai.pose.z, current: zone);
    if (identical(z, zone)) return;
    zone = z;
    if (z != null) {
      if (z.lotId != _lastBannerLot || now - _lastBannerAt > bannerRepeat) {
        _events.add(TownEvent(TownEventKind.banner, lot: z.lot));
      }
      _lastBannerLot = z.lotId;
      _lastBannerAt = now;
      if (TownRules.countsAsVisit(z.lot) && wallet.markFirstVisit(z.lotId)) {
        _events.add(TownEvent(TownEventKind.firstVisit, lot: z.lot));
      }
      if (z.kind == TownZoneKind.counter) {
        final k = _keeperOf(z.lotId);
        k?.react(_yawTo(k, mai.pose.x, mai.pose.z));
      }
    }
    _decide();
  }

  void _decide() {
    final walk = _mode == TownMode.walk;
    _hud.value = TownHud(
      action: walk ? TownRules.actionFor(zone) : TownAction.none,
      lotId: zone?.lotId,
      controls: walk,
    );
  }

  void _setMode(TownMode m) {
    _mode = m;
    if (m != TownMode.walk) {
      _jx = 0;
      _jy = 0;
      _run = false;
      mai.driveRunning = false;
    }
    _decide();
  }

  // ---- Thao tác -----------------------------------------------------------------------------------------------

  /// Thao tác nút A hiện tại (lớp view: enterShop → chuyển cảnh, orderFood → [beginMenu] + bảng thực đơn, getHaircut
  /// → [beginSalon] + bảng làm tóc). Không đi dạo / A mờ → none.
  TownAction get action => _hud.value.action;

  /// Vẫy tay; chủ quán gần đó vẫy lại. Hồi chiêu [waveCooldown] s.
  void wave() {
    if (_mode != TownMode.walk || now - _lastWave < waveCooldown) return;
    _lastWave = now;
    mai.perform(ChibiAction.wave, 1.2, freeze: 0);
    for (final k in keepers) {
      final dx = k.pose.x - mai.pose.x, dz = k.pose.z - mai.pose.z;
      if (dx * dx + dz * dz <= waveRange * waveRange) k.perform(ChibiAction.wave, 1.4);
    }
  }

  /// Hồi chiêu vẫy còn lại (1 → 0).
  double get waveLeft => ((waveCooldown - (now - _lastWave)) / waveCooldown).clamp(0.0, 1.0);

  /// Bắt đầu chuyển cảnh (vào tiệm của bà): thôi lái.
  void beginTransit() => _setMode(TownMode.transit);

  /// Đặt Mai tại (x, z) quay về [yaw] rồi đi dạo tiếp (vừa ra khỏi tiệm). Vùng tính lại, không hiện băng tên.
  void placeAt(double x, double z, double yaw) {
    final p = nav.nearestFree(x, z, _radius, maxDist: 2) ?? NavPoint(x, z);
    if (!mai.driven) mai.startDriving();
    mai
      ..driveMove(p.x, p.z, yaw)
      ..pose.yaw = yaw;
    zone = TownRules.zoneAt(zones, p.x, p.z);
    _lastBannerLot = zone?.lotId;
    _lastBannerAt = now;
    _setMode(TownMode.walk);
  }

  /// Mở bảng thực đơn: Mai đứng ở quầy, quay vào ô cửa; chủ quán nói chuyện.
  void beginMenu() {
    if (_mode != TownMode.walk) return;
    final c = _spotsOf(LotKind.restaurant)?.counter;
    if (c != null) mai.driveFace(c.yaw);
    final lot = layout.district.lotOfKind(LotKind.restaurant);
    final k = lot == null ? null : _keeperOf(lot.id);
    k?.perform(ChibiAction.talk, 2.0, faceYaw: _yawTo(k, mai.pose.x, mai.pose.z));
    _setMode(TownMode.menu);
  }

  /// Đóng bảng thực đơn không gọi món.
  void endMenu() {
    if (_mode == TownMode.menu) _setMode(TownMode.walk);
  }

  /// Gọi món [dish]: `CityWallet.eat` (thiếu xu → ok = false, bảng giữ nguyên); được → Mai đi tới ghế hiên, ngồi ăn.
  EatResult order(Dish dish) {
    final r = wallet.eat(dish);
    if (!r.ok) return r;
    _eat = r;
    dishId = dish.id;
    _startEating();
    return r;
  }

  Shop3dSpot? get _seatSpot {
    final s = _spotsOf(LotKind.restaurant)?.seat;
    return s == null ? null : Shop3dSpot('townSeat', s.x, s.z, s.yaw, y: seatTop);
  }

  void _startEating() {
    final seat = _seatSpot;
    _setMode(TownMode.eating);
    mai.stopDriving();
    if (seat == null) {
      _eatPhase = 2;
      mai.setScript([const ChibiStep.act(ChibiAction.happy, 1.2)], once: true);
      return;
    }
    dishPose = (
      x: seat.x + math.sin(seat.facingYaw) * dishReach,
      y: tableTop,
      z: seat.z + math.cos(seat.facingYaw) * dishReach,
      yaw: seat.facingYaw + math.pi,
    );
    final path = nav.findPath(mai.pose.x, mai.pose.z, seat.x, seat.z, clearance: TownNav.clearance);
    final route = <(double, double)>[
      if (path != null)
        for (final p in path) (p.x, p.z),
    ];
    if (route.isEmpty || route.last != (seat.x, seat.z)) route.add((seat.x, seat.z));
    mai.speedScale = seatWalkSpeed;
    mai.followRoute(route, hold: true, limit: seatWalkLimit);
    _eatPhase = 1;
  }

  void _eating() {
    final seat = _seatSpot;
    switch (_eatPhase) {
      case 1:
        if (mai.routing) return;
        mai.speedScale = 1;
        if (seat != null) {
          mai.setScript(
              [ChibiStep.sit(seat, eatSeconds), const ChibiStep.act(ChibiAction.stand, 0.15)], once: true);
        }
        _eatPhase = 2;
      case 2:
        if (!dishVisible && mai.isSeated && dishId != null) {
          dishVisible = true;
          _events.add(const TownEvent(TownEventKind.eatingStart));
        }
        if (!mai.done) return;
        dishVisible = false;
        _eatPhase = 0;
        mai.startDriving();
        final r = _eat;
        _eat = null;
        _events.add(TownEvent(TownEventKind.eatingDone, eat: r));
        _setMode(TownMode.walk);
    }
  }

  /// Mở bảng làm tóc: Mai quay ra phố (về phía camera chuẩn) để xem trước kiểu tóc.
  void beginSalon() {
    if (_mode != TownMode.walk) return;
    mai.driveFace(salonFaceYaw);
    final lot = layout.district.lotOfKind(LotKind.salon);
    final k = lot == null ? null : _keeperOf(lot.id);
    k?.perform(ChibiAction.happy, 1.2, faceYaw: _yawTo(k, mai.pose.x, mai.pose.z));
    _setMode(TownMode.salon);
  }

  /// Hướng Mai quay khi xem trước kiểu tóc: ra phố (+z), hơi nghiêng để camera thấy ba phần tư mặt.
  static const double salonFaceYaw = 0.25;

  /// Đóng bảng làm tóc; [bought] = vừa mua kiểu mới → Mai nhảy vui ("ta-da"), chủ tiệm vỗ tay.
  void endSalon({bool bought = false}) {
    if (_mode != TownMode.salon) return;
    if (bought) {
      mai.perform(ChibiAction.happy, 1.4, freeze: 1.0);
      final lot = layout.district.lotOfKind(LotKind.salon);
      final k = lot == null ? null : _keeperOf(lot.id);
      k?.perform(ChibiAction.happy, 1.4);
      _events.add(const TownEvent(TownEventKind.tada));
    }
    _setMode(TownMode.walk);
  }
}

/// Quấn góc về (−π, π].
double _wrap(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}
