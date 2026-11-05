import 'dart:math' as math;

import '../chibi/chibi_actor.dart';
import '../chibi/chibi_cast.dart';
import '../interact/pilot.dart';
import '../shop3d_layout.dart';

/// Sân khấu 3D của ca bán (docs/v3/city-gd3-spec.md §5): đưa từng khách vào tiệm, đứng chờ ở hàng, tiến lên quầy,
/// phản ứng theo số sao, rồi đi ra. Dart thuần — chạy trên [Shop3dPilotWorld] (theo mẫu `_spawnPair` của pilot), không
/// import thermion; test dùng thế giới giả.
///
/// Luồng (ShiftBinder nối với `ShiftSession`):
/// - [begin]: khách thứ nhất đi từ cửa tới `counterSpots[2]`; khách kế đứng chờ ở `queue[0]`; khách nền (ông Hòa,
///   Linh, Kenji, bà Rosa) ngồi yên suốt ca. Tới quầy → [onArrived] (đúng một lần mỗi khách).
/// - [react]: khách ở quầy phản ứng theo số sao (≥ 4 vui, 3 nói chuyện, ≤ 2 phụng phịu).
/// - [dismiss]: khách ở quầy đi ra, bị gỡ khi xong vòng; khách kế tiến lên quầy (khách sau nữa đi vào hàng).
/// - Quá [arriveTimeout] mà khách chưa tới quầy thì đặt thẳng khách vào quầy (và báo [onArrived]).
/// - [end]: khách còn lại đi ra, khách nền trở lại vòng cũ. [clear]: gỡ ngay.
///
/// Lớp cảnh gọi [update] mỗi khung **trước** `ChibiDirector.update` (cùng chỗ với `Shop3dPilot.update`); sau [end] vẫn
/// phải gọi [update] tới khi [isIdle] (khách đang đi ra được gỡ ở đó). Model khách dựng sẵn bằng
/// `Shop3dPilotWorld.prepareModels` (stage tự gọi cho khách hiện tại và hai khách kế); chưa sẵn thì khách chưa xuất
/// hiện ([waitingForModels]), hạn [arriveTimeout] tính từ lúc khách xuất hiện.
class ShiftStage {
  ShiftStage(this.world, {this.arriveTimeout = defaultArriveTimeout, this.onArrived});

  /// Hạn khách đi tới quầy (= `ShiftEconomy.arriveTimeout` của core; khai báo cục bộ vì file này không import core —
  /// lớp nối truyền giá trị của core vào [arriveTimeout]).
  static const Duration defaultArriveTimeout = Duration(seconds: 12);

  /// Chỗ khách đứng gọi món.
  static final Shop3dSpot counter = Shop3dLayout.counterSpots[2];

  /// Số khách xuất hiện trước (khách hiện tại + khách đứng chờ).
  static const int onStage = 2;

  /// Khách đứng chờ ở hàng khởi hành chậm chừng này giây sau khách trước (khỏi chồng lên nhau ngoài cửa).
  static const double queueDelay = 1.4;

  /// Sai số coi là "tới quầy" (m).
  static const double arriveRadius = 0.06;

  /// Thời gian diễn phản ứng (s).
  static const double reactSeconds = 2.4, poutSeconds = 3.0;

  final Shop3dPilotWorld world;

  /// Hạn khách tới quầy; sau hạn thì đặt thẳng khách vào quầy.
  Duration arriveTimeout;

  /// Khách thứ [index] (từ 0) đã tới quầy (kể cả khi bị đặt thẳng vào quầy do quá hạn).
  void Function(int index)? onArrived;

  /// Đường vào: ngoài cửa → trong cửa → cuối hàng → `queue[0]` → quầy.
  static final List<(double, double)> _enterChain = [
    (Shop3dLayout.doorOutside.x, Shop3dLayout.doorOutside.z),
    (Shop3dLayout.entrance.x, Shop3dLayout.entrance.z),
    for (var i = Shop3dLayout.queue.length - 1; i >= 0; i--) (Shop3dLayout.queue[i].x, Shop3dLayout.queue[i].z),
    (counter.x, counter.z),
  ];

  List<_Guest> _guests = [];
  int _index = -1;
  bool _active = false;
  double _clock = 0;

  /// Khách đang đi ra (gỡ khi xong vòng).
  final List<ChibiActor> _leaving = [];

  /// Khách nền: đang chờ (đang nhảy lên / xuống ghế), đã giữ ngồi (tạm dừng), hoặc đã đổi sang kịch bản ngồi yên.
  final Map<ChibiActor, _Ambient> _ambient = {};

  // ---- Trạng thái công khai -------------------------------------------------------------------------------------

  /// Đang trong ca (sau [begin], trước [end] / [clear]).
  bool get active => _active;

  /// Tổng số khách của ca.
  int get total => _guests.length;

  /// Chỉ số khách đang ở quầy / đang tới quầy (−1 khi chưa [begin]; = [total] khi đã tiễn hết khách).
  int get index => _index;

  /// Id chibi của khách hiện tại (null nếu không có).
  String? get currentId => _current?.id;

  /// Nhân vật khách hiện tại (null nếu chưa xuất hiện / hết khách).
  ChibiActor? get currentActor => _current?.actor;

  /// Nhân vật khách đứng chờ kế tiếp (null nếu không có / chưa xuất hiện).
  ChibiActor? get waitingActor => _guestAt(_index + 1)?.actor;

  /// Khách hiện tại đã tới quầy.
  bool get arrived => _current?.arrived ?? false;

  /// Khách hiện tại chưa xuất hiện vì model chưa dựng xong.
  bool get waitingForModels => _current != null && _current!.actor == null;

  /// Không còn gì để cập nhật: hết ca (hoặc chưa bắt đầu) và khách đi ra đã được gỡ.
  bool get isIdle => !_active && _leaving.isEmpty;

  _Guest? get _current => _guestAt(_index);

  _Guest? _guestAt(int i) => _active && i >= 0 && i < _guests.length ? _guests[i] : null;

  // ---- Điều khiển -------------------------------------------------------------------------------------------------

  /// Bắt đầu ca với khách [chibiIds] (id chibi, xem `castFor`): dựng sẵn model, khách nền ngồi yên.
  void begin(List<String> chibiIds) {
    if (_active) clear();
    _guests = [for (final id in chibiIds) _Guest(id)];
    _index = 0;
    _active = true;
    _clock = 0;
    _prepare();
    for (final a in world.director.actors) {
      if (ChibiCast.ambientGuestIds.contains(a.id) && !a.done) _ambient[a] = _Ambient.pending;
    }
    _updateAmbient();
    _spawnReady();
  }

  /// Khách hiện tại phản ứng theo số sao [stars]: ≥ 4 vui (nhảy), 3 nói chuyện, ≤ 2 phụng phịu.
  void react(int stars) {
    final a = _current?.actor;
    if (a == null) return;
    if (stars >= 4) {
      a.perform(ChibiAction.happy, reactSeconds, faceYaw: 0.25);
    } else if (stars == 3) {
      a.perform(ChibiAction.talk, reactSeconds, faceYaw: ChibiCast.orderFaceYaw);
    } else {
      a.perform(ChibiAction.pout, poutSeconds, faceYaw: 0.5);
    }
  }

  /// Tiễn khách hiện tại: khách đi ra cửa (gỡ khi xong vòng); khách kế tiến lên quầy.
  void dismiss() {
    final g = _current;
    if (g == null) return;
    final a = g.actor;
    if (a != null) _sendOut(a);
    g.actor = null;
    _index++;
    final next = _current;
    if (next != null) {
      next.spawnedAt = _clock;
      final n = next.actor;
      if (n != null) n.setScript(_toCounter(ChibiCast.pathFrom(_enterChain, n.pose.x, n.pose.z)));
    }
    _prepare();
    _spawnReady();
  }

  /// Hết ca: khách còn lại đi ra (gỡ ở [update]), khách nền trở lại vòng cũ.
  void end() {
    if (!_active) return;
    for (final g in _guests) {
      final a = g.actor;
      if (a != null) _sendOut(a);
      g.actor = null;
    }
    _finish();
  }

  /// Gỡ ngay mọi khách của ca (không diễn đi ra) và trả khách nền về vòng cũ.
  void clear() {
    for (final g in _guests) {
      final a = g.actor;
      if (a != null) world.removeActor(a);
      g.actor = null;
    }
    for (final a in _leaving) {
      world.removeActor(a);
    }
    _leaving.clear();
    if (_active) _finish();
  }

  void _finish() {
    _restoreAmbient();
    _active = false;
    _guests = [];
    _index = -1;
  }

  /// Tiến [dt] giây (trước `ChibiDirector.update`).
  void update(double dt) {
    if (dt <= 0) return;
    if (dt > 0.1) dt = 0.1;
    _clock += dt;
    if (_leaving.isNotEmpty) {
      _leaving.removeWhere((a) {
        if (!world.director.actors.contains(a)) return true;
        if (!a.done) return false;
        world.removeActor(a);
        return true;
      });
    }
    if (!_active) return;
    _updateAmbient();
    _spawnReady();
    final g = _current;
    final a = g?.actor;
    if (g == null || a == null || g.arrived) return;
    if (_atCounter(a)) {
      _arrive(g);
    } else if (_clock - g.spawnedAt >= arriveTimeout.inMilliseconds / 1000) {
      // Quá hạn: đặt thẳng khách vào quầy.
      a
        ..pose.x = counter.x
        ..pose.z = counter.z
        ..pose.yaw = counter.facingYaw;
      a.setScript(_toCounter(const []));
      _arrive(g);
    }
  }

  // ---- Nội bộ ---------------------------------------------------------------------------------------------------

  void _arrive(_Guest g) {
    g.arrived = true;
    onArrived?.call(_index);
  }

  bool _atCounter(ChibiActor a) {
    final dx = a.pose.x - counter.x, dz = a.pose.z - counter.z;
    return dx * dx + dz * dz <= arriveRadius * arriveRadius && a.step.action != ChibiAction.walk;
  }

  /// Dựng sẵn model của khách hiện tại và các khách kế (lúc rảnh — việc dựng nặng).
  void _prepare() {
    final ids = [
      for (var i = _index; i < _index + onStage + 1 && i < _guests.length; i++)
        if (i >= 0) _guests[i].id,
    ];
    if (ids.isNotEmpty) world.prepareModels(ids);
  }

  /// Cho khách hiện tại và khách đứng chờ xuất hiện ngoài cửa khi model đã sẵn.
  void _spawnReady() {
    for (var i = _index; i < _index + onStage && i < _guests.length; i++) {
      final g = _guests[i];
      if (g.actor != null) continue;
      final model = world.readyModel(g.id);
      if (model == null) {
        world.prepareModels([g.id]);
        continue;
      }
      // Còn khách cùng id lần trước trong cảnh → gỡ trước.
      for (final old in world.director.actors.where((x) => x.id == g.id).toList()) {
        world.removeActor(old);
        _leaving.remove(old);
      }
      final isCurrent = i == _index;
      final door = Shop3dLayout.doorOutside;
      final path = ChibiCast.pathFrom(_enterChain, door.x, door.z);
      final script = isCurrent
          ? _toCounter(path)
          : [
              const ChibiStep.act(ChibiAction.stand, queueDelay, faceYaw: math.pi),
              ChibiStep.walk(path.sublist(0, path.length - 1)),
              const ChibiStep.act(ChibiAction.stand, 3600, faceYaw: math.pi),
            ];
      final a = ChibiActor(model, script,
          x: door.x, z: door.z, yaw: door.facingYaw, seed: 200 + i, floor: Shop3dLayout.floorHeightAt);
      g.actor = a;
      if (isCurrent) g.spawnedAt = _clock;
      world.addActor(a);
    }
  }

  /// Đi theo [path] tới quầy, nhìn quầy rồi quay nửa người ra phòng (như khách trong `customerLoop`), đứng chờ.
  List<ChibiStep> _toCounter(List<(double, double)> path) => [
        if (path.isNotEmpty) ChibiStep.walk(path),
        ChibiStep.act(ChibiAction.stand, 0.9, jitter: 0.3, faceYaw: counter.facingYaw),
        const ChibiStep.act(ChibiAction.stand, 3600, faceYaw: ChibiCast.orderFaceYaw),
      ];

  /// Cho [a] đi ra cửa (một vòng, rồi gỡ ở [update]).
  void _sendOut(ChibiActor a) {
    a.stopPerform();
    a.setScript(_exitScript(a.pose.x, a.pose.z), once: true);
    if (!_leaving.contains(a)) _leaving.add(a);
  }

  static List<ChibiStep> _exitScript(double x, double z) {
    final aisleX = x < Shop3dLayout.exitAisle.x - 0.5 ? x : null;
    return [
      ChibiStep.walk([
        // Đang ở quầy (phía tây hàng chờ): xuống hành lang trước, rồi mới tới khúc quanh lối ra.
        if (z < Shop3dLayout.seatAisleZ - 0.2 && aisleX != null) (aisleX, Shop3dLayout.seatAisleZ),
        if (z < Shop3dLayout.exitAisle.z + 0.3) (Shop3dLayout.exitAisle.x, Shop3dLayout.exitAisle.z),
        (Shop3dLayout.exitInside.x, Shop3dLayout.exitInside.z),
        (Shop3dLayout.exitOutside.x, Shop3dLayout.exitOutside.z),
      ]),
      const ChibiStep.act(ChibiAction.stand, 0.2, faceYaw: math.pi),
    ];
  }

  // ---- Khách nền -------------------------------------------------------------------------------------------------

  /// Đang ngồi ghế → giữ ngồi (tạm dừng); đang nhảy lên / xuống ghế → chờ; còn lại → kịch bản ngồi yên.
  void _updateAmbient() {
    if (_ambient.isEmpty) return;
    for (final e in _ambient.entries) {
      if (e.value != _Ambient.pending) continue;
      final a = e.key;
      if (a.isSeated) {
        a.pauseScript();
        _ambient[a] = _Ambient.held;
      } else if (!a.isHopping) {
        a.setScript(ChibiCast.seatedIdle(a.id, fromX: a.pose.x, fromZ: a.pose.z));
        _ambient[a] = _Ambient.idle;
      }
    }
  }

  void _restoreAmbient() {
    for (final e in _ambient.entries) {
      final a = e.key;
      if (!world.director.actors.contains(a)) continue;
      switch (e.value) {
        case _Ambient.pending:
          break;
        case _Ambient.held:
          a.resumeScript();
        case _Ambient.idle:
          final seat = ChibiCast.seatOf(a.id);
          final loop = ChibiCast.loopFor(a.id);
          if (a.isSeated || a.isHopping) {
            // Đứng dậy: về chỗ cạnh ghế (phía hành lang) rồi đi ra như vòng thường.
            a.pose
              ..x = seat.x
              ..z = Shop3dLayout.seatApproachZ
              ..y = 0;
          }
          a.setScript(loop, start: ChibiCast.sitIndex(loop) + 1);
      }
    }
    _ambient.clear();
  }
}

class _Guest {
  _Guest(this.id);

  final String id;
  ChibiActor? actor;
  bool arrived = false;

  /// Đồng hồ stage lúc khách hiện tại bắt đầu đi tới quầy (tính hạn).
  double spawnedAt = 0;
}

enum _Ambient { pending, held, idle }
