import 'dart:math' as math;

import '../shop3d_layout.dart';
import 'chibi_rig.dart';

/// Máy trạng thái + chuyển động thủ tục của nhân vật chibi — Dart thuần (test được không cần engine).
///
/// Mỗi nhân vật chạy một **kịch bản** lặp ([ChibiStep]: đi theo đường, đứng / làm việc / vui / vẫy tay, ngồi ghế).
/// Mỗi khung [ChibiActor.update] tiến kịch bản rồi tính [ChibiPose] từ các lớp chuyển động (đi lạch bạch, thở, chớp
/// mắt, nghiêng đầu, nhảy vui, đung đưa chân khi ngồi, tai / đuôi đung đưa), chuyển giữa các trạng thái bằng trọng số
/// làm mượt (không giật). [ChibiRig] tính ma trận thế giới từng bộ phận. Không cấp phát trong [update].

/// Hành động của một bước kịch bản.
enum ChibiAction {
  /// Đi theo [ChibiStep.path].
  walk,

  /// Đứng chờ (thở, chớp mắt, thỉnh thoảng nghiêng đầu).
  stand,

  /// Làm việc tay trước ngực (nhào bột / gõ máy tính tiền).
  work,

  /// Bưng khay (hai tay đưa ra trước).
  carry,

  /// Vui: nhảy nhỏ, hai tay giơ lên.
  happy,

  /// Vẫy tay chào.
  wave,

  /// Ngồi ghế [ChibiStep.seat]: nhảy lên ghế, ngồi đung đưa chân, nhảy xuống về chỗ cũ.
  sit,

  /// Ngồi nghỉ tại chỗ (thú bốn chân: ngồi trên hai chân sau, đuôi quấn, thỉnh thoảng liếm chân). Người: như đứng.
  rest,

  /// Liếm chân / chải lông (thú bốn chân, ngồi). Người: như đứng.
  groom,

  /// Cúi nhặt đồ: gập thân, hai tay với xuống trước (V3 tương tác, [ChibiActor.perform]).
  bend,

  /// Ném: lấy đà 0,15 s (tay phải ra sau) rồi vung ra trước 0,2 s.
  throwAnim,

  /// Giật mình: nhảy nhỏ, giơ hai tay, mắt mở to.
  surprised,

  /// Phụng phịu: khoanh tay, quay mặt đi, hếch cằm.
  pout,

  /// Cãi nhau (hài): ngả về trước, tay vung 6 Hz, nhảy nhỏ, gật nhanh.
  argue,

  /// Nói chuyện: gật nhẹ, tay khua nhẹ.
  talk,
}

/// Tư thế tay khi cầm vật tương tác (V3): vật một tay cầm tay trái, bao bột ôm hai tay.
enum ChibiCarry { none, leftHand, twoHands }

/// Một bước kịch bản (bất biến).
class ChibiStep {
  /// Đi qua lần lượt các điểm (x, z).
  const ChibiStep.walk(this.path, {this.requires})
      : action = ChibiAction.walk,
        duration = 0,
        jitter = 0,
        faceYaw = null,
        seat = null;

  /// Đứng tại chỗ làm [action] trong [duration] (+ ngẫu nhiên 0..[jitter]) giây, quay mặt về [faceYaw] nếu có.
  const ChibiStep.act(this.action, this.duration, {this.jitter = 0, this.faceYaw, this.requires})
      : path = const [],
        seat = null;

  /// Ngồi lên [seat] trong [duration] (+0..[jitter]) giây. Bắt đầu từ chỗ đang đứng (cạnh ghế), xong thì về lại đó.
  const ChibiStep.sit(Shop3dSpot this.seat, this.duration, {this.jitter = 0, this.requires})
      : action = ChibiAction.sit,
        path = const [],
        faceYaw = null;

  final ChibiAction action;
  final List<(double, double)> path;
  final double duration, jitter;
  final double? faceYaw;
  final Shop3dSpot? seat;

  /// Cờ `Shop3dRequires`: thiếu thì bỏ qua bước này (ví dụ chưa có bàn ghế thì không ngồi).
  final String? requires;
}

/// Quấn góc về (−π, π].
double _wrap(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}

/// Tiến [cur] về [target] theo hàm mũ, tốc độ [rate] (1/s).
double _approach(double cur, double target, double rate, double dt) =>
    cur + (target - cur) * (1 - math.exp(-rate * dt));

/// Một nhân vật trong cảnh.
///
/// Mở rộng V3 (tương tác, docs/v3/interaction-spec.md 2.1–2.6; mặc định không bật — kịch bản cũ chạy như trước):
/// - Lái tay: [startDriving] / [driveMove] / [stopDriving] — vị trí do lớp điều khiển tính (va chạm ở `Shop3dNav`),
///   actor chỉ quay người, đánh nhịp bước, chạy ([driveRunning]).
/// - [pauseScript] / [resumeScript]: đứng lại (đang ngồi thì giữ ngồi), giữ nguyên bước kịch bản.
/// - [followRoute]: đi theo lộ trình riêng (A* về lại kịch bản, tới cạnh khách…) rồi chạy tiếp kịch bản (hoặc đứng
///   chờ nếu `hold`); quá hạn thì dời thẳng tới đích.
/// - [perform]: hành động tạm thời (cúi, ném, giật mình, phụng phịu, cãi, nói chuyện, vui, vẫy) chồng lên kịch bản.
/// - [setScript] (+ `once`): đổi kịch bản lúc chạy; chạy hết một vòng thì [done].
/// - [carry]: tư thế tay cầm vật; [handWorld]: tâm bàn tay trong toạ độ thế giới.
class ChibiActor {
  ChibiActor(
    this.model,
    List<ChibiStep> script, {
    required double x,
    required double z,
    double yaw = 0,
    int seed = 1,
    int startStep = 0,
    this.floor,
  })  : _script = script,
        rig = ChibiRig(model.rig),
        _rng = math.Random(seed),
        _phase = (seed * 2.399) % (2 * math.pi),
        _restTilt = (seed.isOdd ? 1 : -1) * restTilt {
    _holdFwd = model.rig.hold?.forward ?? 0;
    pose
      ..x = x
      ..z = z
      ..yaw = yaw;
    _step = startStep % script.length;
    _blinkIn = 1 + _rng.nextDouble() * 3;
    _tiltIn = 3 + _rng.nextDouble() * 4;
    _beginStep();
  }

  final ChibiModel model;
  List<ChibiStep> _script;

  /// Kịch bản đang chạy (đổi bằng [setScript]).
  List<ChibiStep> get script => _script;
  final ChibiRig rig;

  /// Độ cao mặt đứng tại (x, z) — bục trước / sau quầy (`Shop3dLayout.floorHeightAt`); null = sàn phẳng y = 0. Bước
  /// lên / xuống bục mượt (~0,1 s), không áp khi đang ngồi ghế.
  final double Function(double x, double z)? floor;
  final ChibiPose pose = ChibiPose();
  final math.Random _rng;

  String get id => model.id;

  // ---- Thông số chuyển động -------------------------------------------------------------------------------

  /// Tốc độ quay người tối đa (rad/s) và độ "bám" hướng (1/s).
  static const double turnSpeed = 6.5;
  static const double turnRate = 9;

  /// Nhảy lên / xuống ghế (s) và độ vồng (m).
  static const double seatHop = 0.45;
  static const double seatHopArc = 0.12;

  /// Chu kỳ một cú nhảy vui (s) và độ cao (m).
  static const double jumpPeriod = 0.42;
  static const double jumpHeight = 0.12;

  /// Phản ứng khi được chạm (s).
  static const double reactDuration = 1.3;

  /// Đứng yên: đầu nghiêng sẵn ~6° (quy chuẩn cute A10, mỗi nhân vật một phía theo seed) và tay hơi dang (rad).
  static const double restTilt = 0.1;
  static const double restArmRaise = 0.2;

  /// Góc giơ tay khi vui / vẫy nếu dáng đi không đặt [ChibiGait.armUp].
  static const double defaultArmUp = 2.55;

  /// Ném: lấy đà rồi vung (s) — [ChibiAction.throwAnim].
  static const double throwWindup = 0.15;
  static const double throwSwing = 0.2;

  /// Chạy (lái tay): thân ngả thêm (rad) và hệ số vung tay.
  static const double runLean = 0.08;
  static const double runArmScale = 1.3;

  // ---- Trạng thái kịch bản ------------------------------------------------------------------------------------

  int _step = 0;
  double _stepT = 0;
  double _stepDur = 0;
  int _pathIdx = 0;
  bool _moved = false;

  /// Bị nhân vật khác chắn đường (do [ChibiDirector] đặt): đứng chờ.
  bool blocked = false;

  /// Số giây liên tục bị chắn đường, và số giây còn được đi xuyên người khác — do [ChibiDirector] đặt.
  double blockedFor = 0;
  double ghostFor = 0;

  /// Hệ số tốc độ đi theo kịch bản / lộ trình (khách sự kiện vội kéo tới: > 1).
  double speedScale = 1;

  // Ngồi: chỗ bắt đầu (cạnh ghế) và pha 0 = nhảy lên, 1 = đang ngồi, 2 = nhảy xuống.
  double _sitFromX = 0, _sitFromZ = 0, _sitFromYaw = 0;
  int _sitPhase = 0;

  // Phản ứng khi chạm.
  double _reactT = 0;
  double _reactYaw = 0;
  bool _reactSeated = false;

  // ---- Mở rộng V3: lái tay, tạm dừng, lộ trình, hành động tạm, một vòng ---------------------------------------

  bool _driven = false;
  double _driveYaw = 0;
  double _driveDist = 0;
  bool _driveMoving = false;

  /// Đang chạy khi lái tay (thân ngả thêm, tay vung mạnh hơn).
  bool driveRunning = false;

  bool _paused = false;
  double? _pauseYaw;

  List<(double, double)>? _route;
  int _routeIdx = 0;
  double _routeT = 0, _routeLimit = 0;
  bool _routeHold = false;

  ChibiAction? _perf;
  double _perfT = 0, _perfDur = 0, _freezeT = 0;
  double? _perfYaw;

  bool _once = false;
  bool _done = false;
  double _stepStartX = 0, _stepStartZ = 0;

  /// Tư thế tay cầm vật tương tác (do lớp điều khiển đặt).
  ChibiCarry carry = ChibiCarry.none;

  // ---- Lớp chuyển động (làm mượt) ---------------------------------------------------------------------------

  double _t = 0;
  double _walkPhase = 0;
  double _walkW = 0, _happyW = 0, _waveW = 0, _workW = 0, _sitW = 0, _sitSwingW = 0;
  double _legStatic = 0, _armFwd = 0.05, _raiseL = 0.1, _raiseR = 0.1, _lean = 0, _nod = -0.06;
  double _tilt = 0, _tiltTarget = 0, _tiltIn = 4, _tiltHold = 0, _look = 0, _lookTarget = 0;
  double _blinkIn = 3, _blinkT = -1;
  double _groomW = 0, _holdFwd = 0;
  double _runW = 0, _bendW = 0, _throwW = 0, _surpW = 0, _poutW = 0, _argueW = 0, _talkW = 0;
  double _carryL = 0, _carryR = 0;

  /// Lệch pha riêng của nhân vật (theo seed, không lấy thêm số ngẫu nhiên).
  final double _phase;

  /// Góc nghiêng đầu khi đứng yên (theo seed).
  final double _restTilt;

  /// Độ cao mặt đứng đã làm mượt (bục).
  double _floorY = 0;
  bool _floorInit = false;
  bool _doubleBlink = false;

  /// Bước kịch bản đang chạy.
  ChibiStep get step => _script[_step];
  int get stepIndex => _step;

  /// Hành động nền (kịch bản / lái tay / lộ trình / phản ứng chạm), chưa tính hành động tạm [perform].
  ChibiAction get _baseAction {
    if (_driven) return _driveMoving ? ChibiAction.walk : ChibiAction.stand;
    if (_route != null) return ChibiAction.walk;
    if (_reactT > 0 && !_reactSeated) return ChibiAction.happy;
    // Tạm dừng: đứng yên (bước đi / cãi nhau dừng lại; ngồi thì vẫn ngồi).
    if (_done || (_paused && (step.action == ChibiAction.walk || step.action == ChibiAction.argue))) {
      return ChibiAction.stand;
    }
    return step.action;
  }

  /// Hành động hiện tại: hành động tạm ([perform]) nếu có, không thì hành động nền (đang phản ứng chạm khi đứng →
  /// [ChibiAction.happy]).
  ChibiAction get action => _perf ?? _baseAction;

  /// Đang đi (kịch bản / lộ trình / lái tay có di chuyển); đứng khựng vì [perform] thì không tính.
  bool get isWalking => _baseAction == ChibiAction.walk && _freezeT <= 0;

  /// Đang ngồi hẳn trên ghế (không tính lúc nhảy lên / xuống).
  bool get isSeated => step.action == ChibiAction.sit && _sitPhase == 1;

  /// Đang di chuyển trên sàn ở khung vừa rồi.
  bool get moved => _moved;

  /// Đang được lái tay.
  bool get driven => _driven;

  /// Kịch bản đang tạm dừng ([pauseScript]).
  bool get paused => _paused;

  /// Đang đi theo lộ trình riêng ([followRoute]).
  bool get routing => _route != null;

  /// Đang đứng khựng vì hành động tạm ([perform]: cúi, ném, giật mình…) — lớp điều khiển không cho đi lúc này.
  bool get frozen => _freezeT > 0;

  /// Hành động tạm đang diễn (null = không có).
  ChibiAction? get performing => _perf;

  /// Kịch bản chạy một vòng ([setScript] với `once`) đã xong: đứng yên, chờ lớp cảnh gỡ.
  bool get done => _done;

  /// Đang nhảy lên / xuống ghế (không phải ứng viên nói chuyện).
  bool get isHopping => step.action == ChibiAction.sit && _sitPhase != 1;

  /// Đang di chuyển theo kịch bản / lộ trình ("khách đang đi": không nói chuyện, không nhận bánh). Đứng lại vì
  /// [pauseScript] / [perform] hay đang ngồi thì không tính.
  bool get isBusyMoving {
    if (_driven) return _driveMoving;
    if (_done) return false;
    if (_route != null) return true;
    if (_paused) return false;
    if (_freezeT > 0 && step.action == ChibiAction.walk) return false;
    return step.action == ChibiAction.walk || isHopping;
  }

  /// Điểm để về lại kịch bản sau khi bị lái / dời đi: bước đi → điểm kế trên đường; ngồi → chỗ cạnh ghế; còn lại →
  /// chỗ đứng lúc bắt đầu bước.
  (double, double) get scriptResumePoint {
    final s = step;
    if (s.action == ChibiAction.walk && s.path.isNotEmpty) return s.path[math.min(_pathIdx, s.path.length - 1)];
    if (s.action == ChibiAction.sit) return (_sitFromX, _sitFromZ);
    return (_stepStartX, _stepStartZ);
  }

  /// Phản ứng khi người chơi chạm: đứng → quay về [faceYaw] (phía camera) nhảy vui; đang ngồi → vẫy tay tại chỗ.
  void react(double faceYaw) {
    _reactT = reactDuration;
    _reactYaw = faceYaw;
    _reactSeated = step.action == ChibiAction.sit;
  }

  // ---- Điều khiển từ ngoài (V3) ---------------------------------------------------------------------------

  /// Bắt đầu lái tay: dừng kịch bản (giữ bước), huỷ lộ trình / tạm dừng.
  void startDriving() {
    _driven = true;
    _paused = false;
    _route = null;
    _driveYaw = pose.yaw;
    _driveDist = 0;
    _driveMoving = false;
    driveRunning = false;
  }

  /// Lớp điều khiển đã dời nhân vật tới (x, z) (đã qua va chạm); [faceYaw] = hướng muốn quay tới (null = giữ).
  void driveMove(double x, double z, double? faceYaw) {
    final dx = x - pose.x, dz = z - pose.z;
    _driveDist += math.sqrt(dx * dx + dz * dz);
    pose
      ..x = x
      ..z = z;
    if (faceYaw != null) _driveYaw = faceYaw;
  }

  /// Quay mặt về [yaw] (đang lái, không đi).
  void driveFace(double yaw) => _driveYaw = yaw;

  /// Thôi lái: đi [route] (A* về [scriptResumePoint]) rồi chạy tiếp kịch bản; rỗng / null = chạy tiếp ngay.
  void stopDriving({List<(double, double)>? route}) {
    _driven = false;
    driveRunning = false;
    _driveMoving = false;
    _driveDist = 0;
    if (route != null && route.isNotEmpty) followRoute(route);
  }

  /// Tạm dừng kịch bản (giữ bước; đang ngồi thì giữ ngồi), quay mặt về [faceYaw] nếu có.
  void pauseScript({double? faceYaw}) {
    _paused = true;
    _pauseYaw = faceYaw;
  }

  /// Đang tạm dừng: quay mặt về [yaw].
  void pauseFace(double yaw) => _pauseYaw = yaw;

  /// Chạy tiếp kịch bản; [route] (nếu có) đi trước để về điểm kịch bản.
  void resumeScript({List<(double, double)>? route}) {
    _paused = false;
    _pauseYaw = null;
    if (route != null && route.isNotEmpty) followRoute(route);
  }

  /// Đi theo [route] (các điểm x, z) bằng dáng đi của kịch bản; xong thì chạy tiếp kịch bản, hoặc [hold] = đứng chờ
  /// ([pauseScript]). Quá [limit] giây (mặc định: thời gian đi + 3 s) thì dời thẳng tới điểm cuối.
  void followRoute(List<(double, double)> route, {bool hold = false, double? limit}) {
    if (route.isEmpty) {
      if (hold) pauseScript();
      return;
    }
    _route = route;
    _routeIdx = 0;
    _routeT = 0;
    _routeHold = hold;
    _paused = false;
    var len = 0.0, px = pose.x, pz = pose.z;
    for (final (x, z) in route) {
      len += math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz));
      px = x;
      pz = z;
    }
    _routeLimit = limit ?? len / math.max(0.1, model.gait.speed * speedScale) + 3;
  }

  /// Huỷ lộ trình đang đi: đứng lại tại chỗ (lộ trình có `hold` thì kịch bản vẫn tạm dừng).
  void cancelRoute() {
    if (_route == null) return;
    _route = null;
    if (_routeHold) pauseScript();
  }

  /// Diễn [a] trong [seconds] giây chồng lên kịch bản; [faceYaw]: quay về hướng này; [freeze]: số giây đứng khựng
  /// (mặc định = [seconds]; đang ngồi thì không khựng, vẫn ngồi). Hành động mới thay hành động cũ.
  void perform(ChibiAction a, double seconds, {double? faceYaw, double? freeze}) {
    _perf = a;
    _perfT = 0;
    _perfDur = seconds;
    _perfYaw = faceYaw;
    final seated = step.action == ChibiAction.sit && _sitPhase > 0 && !_driven && _route == null;
    _freezeT = seated ? 0 : math.min(seconds, freeze ?? seconds);
  }

  /// Dừng hành động tạm đang diễn.
  void stopPerform() {
    _perf = null;
    _freezeT = 0;
  }

  /// Thay kịch bản (bắt đầu từ bước [start]). [once]: chạy hết một vòng thì [done] (không lặp).
  void setScript(List<ChibiStep> s, {int start = 0, bool once = false}) {
    _script = s;
    _step = start % s.length;
    _once = once;
    _done = false;
    _route = null;
    _paused = false;
    _beginStep();
  }

  // Tâm bàn tay trong không gian cục bộ của khớp vai (tính một lần từ lưới tay).
  double _handY = 0, _handZ = 0, _handXL = 0, _handXR = 0;
  bool _handInit = false;

  void _initHand() {
    _handInit = true;
    final l = model.meshes[ChibiPart.armL], r = model.meshes[ChibiPart.armR];
    final m = l ?? r;
    if (m == null) return;
    // Bàn tay tròn ở đầu dưới lưới tay: tâm cao hơn đáy lưới chừng một bán kính bàn tay.
    _handY = m.minY * 0.82;
    _handZ = (m.minZ + m.maxZ) / 2 + (m.maxZ - m.minZ) * 0.12;
    _handXL = l == null ? 0 : (l.minX + l.maxX) / 2;
    _handXR = r == null ? 0 : (r.minX + r.maxX) / 2;
  }

  /// Tâm bàn tay [side] (+1 trái, −1 phải) trong toạ độ thế giới theo khung xương hiện tại (sau [update]); ghi
  /// x, y, z vào [out] (không cấp phát).
  void handWorld(double side, List<double> out) {
    if (!_handInit) _initHand();
    final m = rig[side > 0 ? ChibiPart.armL : ChibiPart.armR];
    final x = side > 0 ? _handXL : _handXR, y = _handY, z = _handZ;
    out[0] = m[0] * x + m[4] * y + m[8] * z + m[12];
    out[1] = m[1] * x + m[5] * y + m[9] * z + m[13];
    out[2] = m[2] * x + m[6] * y + m[10] * z + m[14];
  }

  // ---- Kịch bản -------------------------------------------------------------------------------------------

  void _beginStep() {
    final s = step;
    _stepT = 0;
    _pathIdx = 0;
    _stepStartX = pose.x;
    _stepStartZ = pose.z;
    _stepDur = s.duration + (s.jitter > 0 ? _rng.nextDouble() * s.jitter : 0);
    if (s.action == ChibiAction.sit) {
      _sitFromX = pose.x;
      _sitFromZ = pose.z;
      _sitFromYaw = pose.yaw;
      _sitPhase = 0;
    }
  }

  void _nextStep(Set<String> owned) {
    if (_once && _step == _script.length - 1) {
      _done = true;
      return;
    }
    // Bỏ qua các bước thiếu cờ (tối đa một vòng kịch bản, phòng kịch bản toàn bước bị bỏ).
    for (var guard = 0; guard < _script.length; guard++) {
      _step = (_step + 1) % _script.length;
      final r = _script[_step].requires;
      if (r == null || owned.contains(r)) break;
      if (_once && _step == _script.length - 1) {
        _done = true;
        return;
      }
    }
    _beginStep();
  }

  void _turnToward(double target, double dt) {
    final err = _wrap(target - pose.yaw);
    final maxStep = turnSpeed * dt;
    var d = err * (1 - math.exp(-turnRate * dt));
    if (d > maxStep) d = maxStep;
    if (d < -maxStep) d = -maxStep;
    pose.yaw = _wrap(pose.yaw + d);
  }

  /// Tiến [dt] giây. [owned]: cờ mở rộng của tiệm (bỏ bước thiếu cờ).
  void update(double dt, Set<String> owned) {
    if (dt <= 0) return;
    if (dt > 0.1) dt = 0.1;
    _t += dt;
    _moved = false;
    final r = step.requires;
    if (!_done && r != null && !owned.contains(r) && !(step.action == ChibiAction.sit && _sitPhase > 0)) {
      _nextStep(owned);
    }

    final perf = _perf;
    if (perf != null) {
      _perfT += dt;
      if (_perfT >= _perfDur) _perf = null;
    }
    if (_driven) {
      // Lái tay: luôn quay theo hướng lái và tiêu quãng đã đi (không khựng, không nhảy vui khi bị chạm).
      if (_freezeT > 0) _freezeT -= dt;
      if (_reactT > 0) _reactT -= dt;
      final face = _perfYaw;
      if (_perf != null && face != null) _driveYaw = face;
      _drive(dt);
    } else if (_freezeT > 0) {
      _freezeT -= dt;
      final face = _perfYaw;
      if (face != null) _turnToward(face, dt);
      // Đang ngồi thì vẫn giữ tư thế ngồi (pha 1 không đổi vị trí).
      if (step.action == ChibiAction.sit && _sitPhase == 1 && !_driven) _sit(step, 0, owned);
    } else if (_reactT > 0) {
      _reactT -= dt;
      if (!_reactSeated) {
        _turnToward(_reactYaw, dt);
      } else {
        _advance(dt, owned);
      }
    } else {
      if (_perf != null && _perfYaw != null) _turnToward(_perfYaw!, dt);
      _advance(dt, owned);
    }
    _animate(dt);
    rig.compute(pose);
    if (model.extraKind == ChibiExtraKind.tail) rig.attachExtraToBody(pose);
  }

  void _advance(double dt, Set<String> owned) {
    if (_driven) {
      _drive(dt);
      return;
    }
    final route = _route;
    if (route != null) {
      _walkRoute(route, dt);
      return;
    }
    if (_done) return;
    if (_paused) {
      final face = _pauseYaw;
      if (face != null) _turnToward(face, dt);
      // Đang ngồi: giữ ngồi (không tính giờ bước).
      if (step.action == ChibiAction.sit && _sitPhase == 1) _sit(step, 0, owned);
      return;
    }
    final s = step;
    switch (s.action) {
      case ChibiAction.walk:
        _walk(s, dt, owned);
      case ChibiAction.sit:
        _sit(s, dt, owned);
      case ChibiAction.stand:
      case ChibiAction.work:
      case ChibiAction.carry:
      case ChibiAction.happy:
      case ChibiAction.wave:
      case ChibiAction.rest:
      case ChibiAction.groom:
      case ChibiAction.bend:
      case ChibiAction.throwAnim:
      case ChibiAction.surprised:
      case ChibiAction.pout:
      case ChibiAction.argue:
      case ChibiAction.talk:
        final face = s.faceYaw;
        if (face != null) _turnToward(face, dt);
        _stepT += dt;
        if (_stepT >= _stepDur) _nextStep(owned);
    }
  }

  /// Lái tay: vị trí đã đặt ([driveMove]); quay người về hướng đi, nhịp bước theo quãng đã đi.
  void _drive(double dt) {
    _turnToward(_driveYaw, dt);
    final d = _driveDist;
    _driveDist = 0;
    _driveMoving = d > 1e-5;
    if (_driveMoving) {
      _walkPhase += d / model.gait.stride * 2 * math.pi;
      _moved = true;
    }
  }

  void _walk(ChibiStep s, double dt, Set<String> owned) {
    _pathIdx = _walkPath(s.path, _pathIdx, dt);
    if (_pathIdx >= s.path.length) _nextStep(owned);
  }

  void _walkRoute(List<(double, double)> route, double dt) {
    _routeT += dt;
    if (_routeT > _routeLimit) {
      // Kẹt quá hạn: dời thẳng tới đích.
      final (x, z) = route.last;
      pose
        ..x = x
        ..z = z;
      _routeIdx = route.length;
    } else {
      _routeIdx = _walkPath(route, _routeIdx, dt);
    }
    if (_routeIdx >= route.length) {
      _route = null;
      if (_routeHold) pauseScript(faceYaw: _pauseYaw);
    }
  }

  /// Đi theo [path] từ điểm [idx] trong [dt] giây; trả chỉ số điểm kế (= độ dài đường khi đã tới cuối).
  int _walkPath(List<(double, double)> path, int idx, double dt) {
    var budget = model.gait.speed * speedScale * dt;
    while (idx < path.length) {
      final (tx, tz) = path[idx];
      final dx = tx - pose.x, dz = tz - pose.z;
      final dist = math.sqrt(dx * dx + dz * dz);
      if (dist < 1e-3) {
        idx++;
        continue;
      }
      _turnToward(math.atan2(dx, dz), dt);
      if (blocked) return idx;
      // Chưa quay đủ thì đi chậm lại (quay người mượt, không trượt ngang).
      final align = math.cos(_wrap(math.atan2(dx, dz) - pose.yaw));
      final speedK = align <= 0 ? 0.0 : align * align;
      final move = math.min(dist, budget * speedK);
      if (move <= 0) return idx;
      pose.x += dx / dist * move;
      pose.z += dz / dist * move;
      _walkPhase += move / model.gait.stride * 2 * math.pi;
      _moved = true;
      if (move >= dist - 1e-9) {
        idx++;
        budget -= move;
        if (budget <= 1e-6) return idx;
      } else {
        return idx;
      }
    }
    return idx;
  }

  void _sit(ChibiStep s, double dt, Set<String> owned) {
    final seat = s.seat!;
    final seatRootY = seat.y + 0.02 - model.rig.seatDrop;
    _stepT += dt;
    switch (_sitPhase) {
      case 0:
        final k = (_stepT / seatHop).clamp(0.0, 1.0);
        final e = k * k * (3 - 2 * k);
        pose.x = _sitFromX + (seat.x - _sitFromX) * e;
        pose.z = _sitFromZ + (seat.z - _sitFromZ) * e;
        pose.y = seatRootY * e + seatHopArc * math.sin(math.pi * k);
        _turnToward(seat.facingYaw, dt * 1.5);
        if (k >= 1) {
          _sitPhase = 1;
          _stepT = 0;
        }
      case 1:
        pose.y = seatRootY;
        _turnToward(seat.facingYaw, dt);
        if (_stepT >= _stepDur) {
          _sitPhase = 2;
          _stepT = 0;
        }
      default:
        final k = (_stepT / seatHop).clamp(0.0, 1.0);
        final e = k * k * (3 - 2 * k);
        pose.x = seat.x + (_sitFromX - seat.x) * e;
        pose.z = seat.z + (_sitFromZ - seat.z) * e;
        pose.y = seatRootY * (1 - e) + seatHopArc * math.sin(math.pi * k);
        _turnToward(_sitFromYaw, dt);
        if (k >= 1) {
          pose.y = 0;
          _nextStep(owned);
        }
    }
  }

  // ---- Chuyển động ----------------------------------------------------------------------------------------

  /// Độ cao mặt đứng dưới chân (bục), làm mượt khi bước lên / xuống.
  double _floorAt(double dt) {
    final f = floor;
    if (f == null) return 0;
    final target = f(pose.x, pose.z);
    if (!_floorInit) {
      _floorInit = true;
      _floorY = target;
    }
    _floorY = _approach(_floorY, target, 22, dt);
    return _floorY;
  }

  /// Nghiêng đầu / quay đầu nhìn quanh ngẫu nhiên khi đứng / ngồi yên.
  void _lookAround(double dt, bool walking) {
    if (_tiltHold > 0) {
      _tiltHold -= dt;
      if (_tiltHold <= 0) {
        _tiltTarget = 0;
        _lookTarget = 0;
      }
    } else if (!walking) {
      _tiltIn -= dt;
      if (_tiltIn <= 0) {
        final side = _rng.nextBool() ? 1.0 : -1.0;
        _tiltTarget = side * (0.12 + _rng.nextDouble() * 0.08);
        _lookTarget = _rng.nextDouble() < 0.5 ? -side * (0.3 + _rng.nextDouble() * 0.25) : 0;
        _tiltHold = 1.2 + _rng.nextDouble() * 0.8;
        _tiltIn = 4 + _rng.nextDouble() * 4;
      }
    }
  }

  /// Chớp mắt mỗi 2,5–5 s (đôi khi chớp đôi). Trả về độ mở mắt.
  double _blink(double dt) {
    var eyeOpen = 1.0;
    if (_blinkT >= 0) {
      _blinkT += dt;
      const blinkLen = 0.16;
      if (_blinkT < blinkLen) {
        eyeOpen = 1 - 0.92 * math.sin(math.pi * _blinkT / blinkLen);
      } else if (_doubleBlink && _blinkT > blinkLen + 0.08 && _blinkT < 2 * blinkLen + 0.08) {
        eyeOpen = 1 - 0.92 * math.sin(math.pi * (_blinkT - blinkLen - 0.08) / blinkLen);
      } else if (_blinkT >= (_doubleBlink ? 2 * blinkLen + 0.08 : blinkLen)) {
        _blinkT = -1;
        _blinkIn = 2.5 + _rng.nextDouble() * 2.5;
      }
    } else {
      _blinkIn -= dt;
      if (_blinkIn <= 0) {
        _blinkT = 0;
        _doubleBlink = _rng.nextDouble() < 0.2;
      }
    }
    return eyeOpen;
  }

  void _animate(double dt) {
    if (model.rig.quadruped) {
      _animateQuad(dt);
      return;
    }
    final g = model.gait;
    final h = model.rig.hold;
    final base = _baseAction;
    final perf = _perf;
    final seatedReact = _reactT > 0 && _reactSeated;
    final walking = base == ChibiAction.walk && _moved;
    final sitting = step.action == ChibiAction.sit && !_driven && _route == null;
    final happy = perf == ChibiAction.happy || (perf == null && base == ChibiAction.happy);
    final waving = perf == ChibiAction.wave || (perf == null && (base == ChibiAction.wave || seatedReact));
    final working = perf == null && base == ChibiAction.work;
    final carrying = perf == null && base == ChibiAction.carry;
    final running = _driven && driveRunning && walking;
    // Hành động mới: hành động tạm, hoặc bước kịch bản (khách sự kiện cãi nhau / phụng phịu).
    bool doing(ChibiAction a) => perf == a || (perf == null && base == a);
    final bending = doing(ChibiAction.bend);
    final throwing = doing(ChibiAction.throwAnim);
    final surprised = doing(ChibiAction.surprised);
    final pouting = doing(ChibiAction.pout);
    final arguing = doing(ChibiAction.argue);
    final talking = doing(ChibiAction.talk);

    // Trọng số lớp (mượt ~0,15 s).
    _walkW = _approach(_walkW, walking ? 1 : 0, walking ? 10 : 7, dt);
    _happyW = _approach(_happyW, happy ? 1 : 0, 9, dt);
    _waveW = _approach(_waveW, waving ? 1 : 0, 8, dt);
    _workW = _approach(_workW, working ? 1 : 0, 6, dt);
    _runW = _approach(_runW, running ? 1 : 0, 8, dt);
    _bendW = _approach(_bendW, bending ? 1 : 0, 16, dt);
    _throwW = _approach(_throwW, throwing ? 1 : 0, 18, dt);
    _surpW = _approach(_surpW, surprised ? 1 : 0, 16, dt);
    _poutW = _approach(_poutW, pouting ? 1 : 0, 7, dt);
    _argueW = _approach(_argueW, arguing ? 1 : 0, 8, dt);
    _talkW = _approach(_talkW, talking ? 1 : 0, 6, dt);
    _carryL = _approach(_carryL, carry != ChibiCarry.none ? 1 : 0, 10, dt);
    _carryR = _approach(_carryR, carry == ChibiCarry.twoHands ? 1 : 0, 10, dt);
    // Ngồi: theo tiến độ nhảy lên / xuống ghế.
    var sitTarget = 0.0;
    if (sitting) {
      final hopK = (_stepT / seatHop).clamp(0.0, 1.0);
      sitTarget = switch (_sitPhase) {
        0 => hopK,
        1 => 1.0,
        _ => 1 - hopK,
      };
    }
    _sitW = _approach(_sitW, sitTarget, 14, dt);
    _sitSwingW = _approach(_sitSwingW, sitting && _sitPhase == 1 ? 1 : 0, 3, dt);

    // Tư thế tĩnh theo hành động.
    final armFwdT = working
        ? 0.95
        : carrying
            ? 1.2
            : (sitting ? 0.25 + 0.3 * _sitW : 0.06);
    final raiseBase = g.cane ? 0.06 : restArmRaise;
    final up = g.armUp ?? defaultArmUp;
    // Vẫy tay phải; người chống gậy (tay phải) hoặc cầm đồ một tay bằng tay phải thì vẫy / giơ tay trái, tay gậy chỉ
    // nhấc nhẹ khi vui. Đang cầm vật tay trái (V3) thì vẫy tay phải.
    final waveLeft = g.cane || (h != null && !h.twoHands && h.side < 0);
    final raiseLT = happy ? up : (waving && waveLeft ? up + 0.15 : raiseBase);
    final raiseRT = happy ? (g.cane ? raiseBase + 0.12 : up) : (waving && !waveLeft ? up + 0.15 : raiseBase);
    final leanT = g.lean + (walking ? 0.05 : 0) + (working ? 0.1 : 0) - 0.06 * _sitW;
    final nodT = working ? 0.14 : (happy ? -0.12 : -0.06);
    _armFwd = _approach(_armFwd, armFwdT, 8, dt);
    _raiseL = _approach(_raiseL, raiseLT, happy ? 12 : 8, dt);
    _raiseR = _approach(_raiseR, raiseRT, (happy || waving) ? 12 : 8, dt);
    _lean = _approach(_lean, leanT, 6, dt);
    _nod = _approach(_nod, nodT, 5, dt);
    _legStatic = 1.45 * _sitW;

    _lookAround(dt, walking);
    final calm = !walking && !happy && !working && !arguing;
    _tilt = _approach(_tilt, calm ? (_tiltTarget == 0 ? _restTilt : _tiltTarget) : 0, 4, dt);
    _look = _approach(_look, calm ? _lookTarget : 0, 3, dt);
    final eyeOpen = _blink(dt);

    final p = _walkPhase, t = _t;
    final s = math.sin(p);
    final w = _walkW;
    final hopWave = (math.sin(math.pi * t / jumpPeriod)).abs();
    final hop = _happyW * jumpHeight * hopWave;
    final sitSwing = _sitSwingW * 0.24 * math.sin(t * 4.2);
    final armK = 1 + (runArmScale - 1) * _runW;

    final o = pose;
    if (!sitting) o.y = _floorAt(dt) + hop;
    o.bob = w * g.bob * (math.cos(2 * p) + 1) / 2;
    o.roll = w * g.waddle * s;
    o.lean = _lean + runLean * _runW;
    final breath = (1 - w) * (1 - _happyW) * 0.02 * math.sin(2 * math.pi * t / 3.2);
    o.bodyScaleY = 1 + breath + _happyW * 0.07 * (hopWave - 0.45);
    o.headYaw = _look;
    o.headNod = _nod + w * 0.04 * math.cos(2 * p - 0.8);
    o.headTilt = _tilt - w * g.waddle * 0.9 * math.sin(p - 0.7) + _waveW * (waveLeft ? -0.1 : 0.1);
    o.eyeOpen = eyeOpen * (1 - 0.35 * _happyW);

    o.legSwingL = _legStatic + w * g.legSwing * s + sitSwing;
    o.legSwingR = _legStatic - w * g.legSwing * s - sitSwing;
    final work = _workW * 0.22 * math.sin(t * 7);
    o.armSwingL = _armFwd - w * g.armSwing * armK * s + work;
    o.armSwingR = g.cane ? _armFwd + 0.1 + w * 0.12 * s : _armFwd + w * g.armSwing * armK * s - work;
    final flap = _happyW * 0.22 * math.sin(t * 2 * math.pi / jumpPeriod);
    final waveOsc = _waveW * 0.38 * math.sin(t * 10);
    o.armRaiseL = _raiseL + flap + (waveLeft ? waveOsc : 0);
    o.armRaiseR = _raiseR - (g.cane ? 0 : flap) + (waveLeft ? 0 : waveOsc);

    if (h != null) _holdPose(h, dt, happy: happy, waving: waving, working: working, carrying: carrying);
    _gesturePose(dt);
    if (_carryL > 1e-3) _carryPose();

    switch (model.extraKind) {
      case ChibiExtraKind.ears:
        // Tai: ngả nhẹ ra sau, nảy theo bước, ve vẩy khi đứng, vẫy mạnh khi vui.
        o.extraA = -0.06 - w * 0.1 * math.cos(2 * p - 1.0) - _happyW * 0.18 * hopWave;
        o.extraB = 0.05 * math.sin(t * 1.6) + w * 0.05 * s;
      case ChibiExtraKind.ponytail:
        o.extraA = 0.08 + w * 0.1 * (math.cos(2 * p - 0.6) + 1) / 2 + _happyW * 0.25 * hopWave;
        o.extraB = w * 0.2 * math.sin(p - 0.5) + 0.04 * math.sin(t * 1.3);
      case ChibiExtraKind.tail:
        // Đuôi: vẫy ngang (Ry) chậm khi đứng, theo bước khi đi, nhanh khi vui; hơi dựng lên (Rx).
        o.extraA = (1 - w) * 0.28 * math.sin(t * 2.3) + w * 0.3 * s + _happyW * 0.3 * math.sin(t * 9);
        o.extraB = -0.04 + 0.05 * math.sin(t * 1.7);
      case ChibiExtraKind.none:
        o.extraA = 0;
        o.extraB = 0;
    }
  }

  /// Trộn tư thế của các hành động mới (V3) lên tư thế đã tính, theo trọng số đã làm mượt. Chỉ cộng / nội suy góc —
  /// không cấp phát.
  void _gesturePose(double dt) {
    final o = pose;
    final t = _t;
    double mix(double a, double b, double k) => a + (b - a) * k;
    // Cúi nhặt: gập thân, cúi đầu, hai tay với xuống trước, hạ người.
    final bw = _bendW;
    if (bw > 1e-3) {
      o.lean = mix(o.lean, 0.5, bw);
      o.headNod = mix(o.headNod, 0.22, bw);
      o.armSwingL = mix(o.armSwingL, 0.85, bw);
      o.armSwingR = mix(o.armSwingR, 0.85, bw);
      o.armRaiseL = mix(o.armRaiseL, 0.12, bw);
      o.armRaiseR = mix(o.armRaiseR, 0.12, bw);
      o.bob -= 0.05 * bw;
    }
    // Ném: lấy đà (tay phải ra sau, ngửa người) rồi vung ra trước.
    final tw = _throwW;
    if (tw > 1e-3) {
      final k = _perf == ChibiAction.throwAnim ? _perfT : throwWindup + throwSwing;
      final wind = k < throwWindup;
      final swingK = wind ? 0.0 : ((k - throwWindup) / throwSwing).clamp(0.0, 1.0);
      final arm = wind ? -0.9 * (k / throwWindup) : -0.9 + 2.6 * swingK;
      o.armSwingR = mix(o.armSwingR, arm, tw);
      o.armRaiseR = mix(o.armRaiseR, 0.35, tw);
      o.lean = mix(o.lean, wind ? -0.08 : 0.14 * swingK, tw);
      o.headNod = mix(o.headNod, -0.08, tw);
    }
    // Giật mình: nhảy nhỏ, giơ hai tay, mắt mở to, ngửa đầu.
    final sw = _surpW;
    if (sw > 1e-3) {
      final k = _perf == ChibiAction.surprised ? (_perfT / math.max(0.1, _perfDur)).clamp(0.0, 1.0) : 1.0;
      o.y += 0.08 * sw * math.sin(math.pi * k);
      o.armRaiseL = mix(o.armRaiseL, 2.1, sw);
      o.armRaiseR = mix(o.armRaiseR, 2.1, sw);
      o.armSwingL = mix(o.armSwingL, 0.3, sw);
      o.armSwingR = mix(o.armSwingR, 0.3, sw);
      o.eyeOpen = mix(o.eyeOpen, 1.15, sw);
      o.headNod = mix(o.headNod, -0.16, sw);
      o.lean = mix(o.lean, -0.06, sw);
    }
    // Phụng phịu: khoanh tay trước ngực, quay mặt đi, hếch cằm, nghiêng đầu.
    final pw = _poutW;
    if (pw > 1e-3) {
      final side = _restTilt >= 0 ? 1.0 : -1.0;
      o.armSwingL = mix(o.armSwingL, 1.25, pw);
      o.armSwingR = mix(o.armSwingR, 1.25, pw);
      o.armRaiseL = mix(o.armRaiseL, -0.55, pw);
      o.armRaiseR = mix(o.armRaiseR, -0.55, pw);
      o.headYaw = mix(o.headYaw, 0.55 * side, pw);
      o.headNod = mix(o.headNod, -0.14, pw);
      o.headTilt = mix(o.headTilt, 0.12 * side, pw);
      o.bodyScaleY += 0.015 * pw * math.sin(t * 2.2);
    }
    // Cãi nhau: ngả về trước, tay vung 6 Hz, nhảy nhỏ, gật nhanh.
    final aw = _argueW;
    if (aw > 1e-3) {
      final osc = math.sin(t * 2 * math.pi * 6 + _phase);
      o.lean = mix(o.lean, 0.16, aw);
      o.armSwingL = mix(o.armSwingL, 0.7 + 0.45 * osc, aw);
      o.armSwingR = mix(o.armSwingR, 0.7 - 0.45 * osc, aw);
      o.armRaiseL = mix(o.armRaiseL, 0.6, aw);
      o.armRaiseR = mix(o.armRaiseR, 0.6, aw);
      o.headNod = mix(o.headNod, 0.08 + 0.1 * math.sin(t * 2 * math.pi * 4), aw);
      o.y += 0.035 * aw * math.sin(t * 2 * math.pi * 2.5 + _phase).abs();
    }
    // Nói chuyện: gật nhẹ, tay phải khua nhẹ.
    final kw = _talkW;
    if (kw > 1e-3) {
      o.headNod += kw * 0.06 * math.sin(t * 2 * math.pi * 1.6);
      o.armSwingR = mix(o.armSwingR, 0.45 + 0.18 * math.sin(t * 5.5), kw);
      o.armRaiseR = mix(o.armRaiseR, 0.35, kw);
    }
  }

  /// Cầm vật tương tác (V3): vật một tay ở tay trái đưa ra trước; bao bột ôm hai tay trước ngực. Nhún nhẹ theo bước.
  void _carryPose() {
    final o = pose;
    final bounce = _walkW * 0.05 * math.cos(2 * _walkPhase);
    final fwd = 0.75 + bounce;
    double mix(double a, double b, double k) => a + (b - a) * k;
    final two = _carryR;
    o.armSwingL = mix(o.armSwingL, mix(fwd, 1.05 + bounce, two), _carryL * (1 - _bendW));
    o.armRaiseL = mix(o.armRaiseL, mix(0.12, 0.06, two), _carryL * (1 - _bendW));
    if (two > 1e-3) {
      o.armSwingR = mix(o.armSwingR, 1.05 + bounce, two * (1 - _bendW));
      o.armRaiseR = mix(o.armRaiseR, 0.06, two * (1 - _bendW));
    }
  }

  /// Tay cầm đồ ([ChibiHold]): giữ tư thế cầm (nhún nhẹ theo bước); hai tay cầm thì cùng nhịp — làm việc = đẩy tới
  /// lui (cán bột), vui = giơ đồ lên cao phía trước, vẫy = nhấc đồ lên xuống. Tay còn lại vẫn đánh / vẫy / giơ như
  /// thường.
  void _holdPose(
    ChibiHold h,
    double dt, {
    required bool happy,
    required bool waving,
    required bool working,
    required bool carrying,
  }) {
    var fwdT = working ? (h.workForward ?? h.forward) : h.forward;
    if (h.twoHands && happy) fwdT = 2.25;
    if (h.twoHands && waving) fwdT += 0.35;
    if (carrying) fwdT += 0.12;
    _holdFwd = _approach(_holdFwd, fwdT, 7, dt);
    final o = pose;
    final bounce = _walkW * 0.05 * math.cos(2 * _walkPhase);
    if (h.twoHands) {
      final osc = _workW * 0.16 * math.sin(_t * 7) + _waveW * 0.2 * math.sin(_t * 9);
      o.armSwingL = o.armSwingR = _holdFwd + bounce + osc;
      o.armRaiseL = o.armRaiseR = h.raise;
    } else if (h.side > 0) {
      o.armSwingL = _holdFwd + bounce;
      o.armRaiseL = h.raise;
    } else {
      o.armSwingR = _holdFwd + bounce;
      o.armRaiseR = h.raise;
    }
  }

  /// Góc ngả thân (rad) khi thú bốn chân ngồi trên hai chân sau.
  static const double quadSitAngle = 0.78;

  /// Độ hạ hông khi thân ngả góc [a] sao cho vai (chân trước) giữ nguyên độ cao — bàn chân trước vẫn chạm sàn.
  double _quadSitDrop(double a) {
    final s = model.rig;
    final l = s.shoulderZ - s.hindZ, hh = s.shoulderY - s.hipY;
    return l * math.sin(a) + hh * (math.cos(a) - 1);
  }

  /// Thú bốn chân (mèo Mochi): đi nước kiệu (chân chéo cùng nhịp), ngồi trên hai chân sau (thân ngửa, đùi gập ra
  /// trước, đầu bù lại để vẫn nhìn thẳng), thỉnh thoảng liếm chân khi ngồi nghỉ, vẫy chân kiểu mèo thần tài, nhảy vui;
  /// đuôi dựng vẫy ngang khi đứng / đi, hạ xuống quấn bên hông khi ngồi. Hành động tạm ([perform]): vui = nhảy vồ,
  /// vẫy = rù rù vẫy chân, nghỉ = ngồi.
  void _animateQuad(double dt) {
    final g = model.gait;
    final base = _baseAction;
    final act = _perf ?? base;
    final seatedReact = _reactT > 0 && _reactSeated;
    final walking = base == ChibiAction.walk && _moved;
    final onSeat = step.action == ChibiAction.sit && _route == null;
    final happy = act == ChibiAction.happy || act == ChibiAction.surprised;
    final waving = act == ChibiAction.wave || seatedReact;
    final resting = act == ChibiAction.rest || (onSeat && _sitPhase == 1);
    final grooming = act == ChibiAction.groom || (resting && !seatedReact && math.sin(_t * 0.8 + _phase) > 0.45);
    final sitting = resting || grooming || waving;

    _walkW = _approach(_walkW, walking ? 1 : 0, walking ? 10 : 7, dt);
    _happyW = _approach(_happyW, happy ? 1 : 0, 9, dt);
    _waveW = _approach(_waveW, waving ? 1 : 0, 6, dt);
    _sitW = _approach(_sitW, sitting ? 1 : 0, 5, dt);
    _groomW = _approach(_groomW, grooming ? 1 : 0, 5, dt);

    _lookAround(dt, walking);
    final calm = !walking && !happy && _groomW < 0.5;
    _tilt = _approach(_tilt, calm ? _tiltTarget : 0, 4, dt);
    _look = _approach(_look, calm ? _lookTarget : 0, 3, dt);
    final eyeOpen = _blink(dt);

    final p = _walkPhase, t = _t;
    final s = math.sin(p);
    final w = _walkW;
    final hopWave = (math.sin(math.pi * t / jumpPeriod)).abs();
    final sitA = quadSitAngle * _sitW;

    final o = pose;
    if (!onSeat) o.y = _floorAt(dt) + _happyW * jumpHeight * 0.75 * hopWave;
    o.bob = w * g.bob * (math.cos(2 * p) + 1) / 2 - _quadSitDrop(sitA);
    o.roll = w * g.waddle * s;
    o.lean = -sitA + w * 0.03;
    final breath = (1 - w) * (1 - _happyW) * 0.025 * math.sin(2 * math.pi * t / 2.6);
    o.bodyScaleY = 1 + breath;
    o.headYaw = _look + _groomW * 0.38;
    o.headNod = sitA * 0.92 -
        0.05 +
        w * 0.05 * math.cos(2 * p - 0.8) +
        _groomW * (0.3 + 0.1 * math.sin(t * 11)) -
        _happyW * 0.12;
    o.headTilt = _tilt + _groomW * 0.2 - w * g.waddle * 0.6 * math.sin(p - 0.7) + _waveW * 0.16;
    o.eyeOpen = eyeOpen * (1 - 0.6 * _groomW) * (1 - 0.35 * _happyW);

    // Chân sau: gập ra trước khi ngồi (đùi nằm trên sàn); chân trước chống thẳng (rig bù độ ngả thân).
    o.legSwingL = 1.55 * _sitW + w * g.legSwing * s;
    o.legSwingR = 1.55 * _sitW - w * g.legSwing * s;
    final hopPaw = _happyW * 0.35 * hopWave;
    o.armSwingL = -w * g.armSwing * s + _groomW * 2.0 + hopPaw;
    o.armSwingR = w * g.armSwing * s + _waveW * (1.95 + 0.35 * math.sin(t * 8)) + hopPaw;
    o.armRaiseL = -0.3 * _groomW;
    o.armRaiseR = 0.08 * _waveW;

    // Đuôi (Rz = vẫy ngang, Rx = dựng / hạ): dựng cao vẫy chậm khi đứng, theo bước khi đi, ngoáy nhanh khi vui; ngồi
    // thì hạ xuống sàn và quấn sang bên.
    final up = 1 - _sitW;
    o.extraA = up * ((1 - w) * 0.24 * math.sin(t * 1.9) + w * 0.14 * s + _happyW * 0.3 * math.sin(t * 10)) +
        _sitW * (0.95 + 0.07 * math.sin(t * 1.3));
    o.extraB = _sitW * 0.55;
  }
}

/// Điều phối nhiều nhân vật: tránh đi xuyên nhau (người đi sau đứng chờ), cập nhật tất cả.
///
/// V3: nhân vật đang lái tay ([ChibiActor.driven]) không bị chặn (lớp điều khiển tự trượt vòng qua người khác) nhưng
/// vẫn chắn đường NPC. NPC bị chắn liên tục [excuseAfter] giây bởi người đang lái / người đang đứng nói chuyện →
/// [excuseMe] (bong bóng "Cho mình qua với!"); [ghostAfter] giây → được đi xuyên trong [ghostSeconds] giây.
class ChibiDirector {
  ChibiDirector(this.actors);

  /// Danh sách sống: lớp cảnh thêm / gỡ khách sự kiện ngay trong danh sách này.
  final List<ChibiActor> actors;

  /// Khoảng hở thêm giữa hai nhân vật khi xét chắn đường (m).
  static const double gap = 0.06;

  /// Nhường đường (V3, đặc tả 2.1).
  static const double excuseAfter = 2, ghostAfter = 4, ghostSeconds = 1.5;

  /// NPC vừa bị chắn đủ [excuseAfter] giây ở lần [update] gần nhất (danh sách tái dùng).
  final List<ChibiActor> excuseMe = [];

  void update(double dt, Set<String> owned) {
    excuseMe.clear();
    final n = actors.length;
    for (var i = 0; i < n; i++) {
      final a = actors[i];
      a.blocked = false;
      if (!a.isWalking || a.driven || a.done) {
        a.blockedFor = 0;
        continue;
      }
      if (a.ghostFor > 0) {
        a.ghostFor -= dt;
        continue;
      }
      final fx = math.sin(a.pose.yaw), fz = math.cos(a.pose.yaw);
      ChibiActor? by;
      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final b = actors[j];
        if (b.isSeated || b.done) continue;
        final dx = b.pose.x - a.pose.x, dz = b.pose.z - a.pose.z;
        final d = math.sqrt(dx * dx + dz * dz);
        if (d > a.model.radius + b.model.radius + gap || d < 1e-6) continue;
        // Chỉ chặn khi người kia ở phía trước (trong ~±70°).
        if ((dx * fx + dz * fz) / d < 0.35) continue;
        // Hai người cùng đi chặn nhau: người có chỉ số nhỏ hơn được đi (tránh kẹt cứng).
        if (b.isWalking && !b.driven && i < j) {
          final bfx = math.sin(b.pose.yaw), bfz = math.cos(b.pose.yaw);
          if ((-dx * bfx - dz * bfz) / d >= 0.35) continue;
        }
        a.blocked = true;
        by = b;
        break;
      }
      if (by == null) {
        a.blockedFor = 0;
        continue;
      }
      final before = a.blockedFor;
      a.blockedFor += dt;
      if (before < excuseAfter && a.blockedFor >= excuseAfter && (by.driven || by.paused)) excuseMe.add(a);
      if (a.blockedFor >= ghostAfter) {
        a.blockedFor = 0;
        a.ghostFor = ghostSeconds;
        a.blocked = false;
      }
    }
    for (var i = 0; i < n; i++) {
      actors[i].update(dt, owned);
    }
  }
}
