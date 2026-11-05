import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../chibi/chibi_actor.dart';
import '../chibi/chibi_cast.dart';
import '../chibi/chibi_rig.dart';
import '../shop3d_layout.dart';
import '../talk/quarrel_director.dart';
import '../talk/quarrel_events.dart';
import '../talk/talk_model.dart';
import '../talk/talk_picker.dart';
import '../talk/talk_runner.dart';
import '../talk/talk_stories.dart';
import 'pilot_rules.dart';
import 'shop3d_items.dart';
import 'shop3d_nav.dart';

/// Điều phối tương tác của cảnh tiệm 3D (V3, docs/v3/interaction-spec.md): nhân vật đang được điều khiển, joystick →
/// di chuyển có va chạm, nút A / Ném / Vẫy / Xong, vật cầm tay, nói chuyện với khách, sự kiện khách cãi nhau trước
/// quán. Dart thuần — không import thermion: lớp cảnh cài [Shop3dPilotWorld] (thêm / gỡ nhân vật, dựng sẵn model),
/// lớp view đọc các `ValueListenable` để vẽ lớp phủ và gọi các hàm thao tác.
///
/// Thứ tự mỗi khung (do lớp cảnh gọi, cùng nhịp cập nhật chibi): [update] (đọc joystick, dời nhân vật, vật bay, sự
/// kiện) → `ChibiDirector.update` → [lateUpdate] (vật cầm tay bám bàn tay, "Cho mình qua với!").
///
/// Không cấp phát lớn mỗi khung: danh sách hình tròn NPC / mục tiêu ném tái dùng; bảng nút A tính lại 10 lần/s; A*
/// chỉ chạy khi cần (thôi điều khiển, tự đi tới khách / sự kiện).
///
/// Phần thưởng (♥ thiện cảm, xu thử) chỉ tính trong phiên (quyết định tạm Q1).

/// Thế giới mà [Shop3dPilot] điều phối. Lớp cảnh cài đặt; test dùng bản giả.
abstract interface class Shop3dPilotWorld {
  /// Điều phối nhân vật (danh sách sống `actors`, `excuseMe`).
  ChibiDirector get director;

  /// Cờ mở rộng đang bật (`Shop3dRequires`).
  Set<String> get owned;

  /// Model khách sự kiện đã dựng xong (đã đưa về kích thước); null = chưa sẵn — gọi [prepareModels] trước.
  ChibiModel? readyModel(String id);

  /// Dựng sẵn model (và entity) của các khách [ids] lúc rảnh, để ngoài scene.
  void prepareModels(List<String> ids);

  /// Thêm nhân vật vào cảnh (hiện entity, thêm vào `director.actors`).
  void addActor(ChibiActor a);

  /// Gỡ nhân vật khỏi cảnh (ẩn entity, bỏ khỏi `director.actors`).
  void removeActor(ChibiActor a);
}

/// Kiểu bong bóng trên đầu (lớp view ánh xạ sang `Shop3dBubbleKind`).
enum PilotBubbleKind { speech, exclaim, puff, thinking }

/// Bong bóng trên đầu nhân vật [actorId] tới thời điểm [until] (giây, đồng hồ của pilot).
class PilotBubble {
  PilotBubble(this.actorId, this.text, this.kind, this.until, this.serial);

  final String actorId;
  final TalkText text;
  final PilotBubbleKind kind;
  final double until;

  /// Tăng dần — lớp view dùng làm `key` để bong bóng mới bật lên lại.
  final int serial;
}

enum PilotNoticeIcon { info, heart, event }

/// Toast cho lớp view: chữ ([text]) hoặc phần thưởng ([hearts] ♥ / [coins] xu, lớp view ghép chuỗi l10n).
class PilotNotice {
  const PilotNotice.text(TalkText this.text, {this.icon = PilotNoticeIcon.info})
      : hearts = 0,
        coins = 0;

  const PilotNotice.reward(this.hearts, this.coins)
      : text = null,
        icon = PilotNoticeIcon.heart;

  final TalkText? text;
  final int hearts, coins;
  final PilotNoticeIcon icon;
}

/// Trạng thái cụm nút (đổi ít — lớp view dựng lại cụm nút khi đổi).
@immutable
class PilotHud {
  const PilotHud({
    this.pilotId,
    this.decision = PilotDecision.none,
    this.showThrow = false,
    this.dialogue = false,
    this.locked = false,
  });

  /// Nhân vật đang được điều khiển (null = không điều khiển ai: ẩn joystick / cụm nút).
  final String? pilotId;
  final PilotDecision decision;
  final bool showThrow;

  /// Đang mở khung thoại: ẩn joystick và cụm nút.
  final bool dialogue;

  /// Đang khoá điều khiển (ca bán, [Shop3dPilot.locked]): ẩn joystick và cụm nút.
  final bool locked;

  bool get controlsVisible => pilotId != null && !dialogue && !locked;

  @override
  bool operator ==(Object other) =>
      other is PilotHud &&
      other.pilotId == pilotId &&
      other.decision == decision &&
      other.showThrow == showThrow &&
      other.dialogue == dialogue &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(pilotId, decision, showThrow, dialogue, locked);
}

/// Một câu đang hiện trong khung thoại (lớp view lấy chuỗi bằng `AppLocalizations`).
@immutable
class PilotTalkLine {
  const PilotTalkLine({
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.choices,
    required this.lineId,
  });

  /// Id nhân vật đang nói (null = lời dẫn / người không có trong cảnh).
  final String? speakerId;

  /// Tên người nói; null = lời dẫn (không có chip tên).
  final TalkText? speakerName;
  final TalkText text;

  /// Nhãn lựa chọn (rỗng = câu thường).
  final List<TalkText> choices;

  /// Khác nhau giữa hai câu liền nhau.
  final Object lineId;
}

/// Chọn khách để trò chuyện: chip tên trên đầu tối đa 3 khách gần [staffId] nhất.
@immutable
class PilotPickPrompt {
  const PilotPickPrompt(this.staffId, this.guestIds);

  final String staffId;
  final List<String> guestIds;
}

enum _TalkKind { story, smallTalk, quarrel }

class _TalkSession {
  _TalkSession(this.kind, this.runner, this.speakerId, this.guestId, {this.storyId, this.granted = 0, this.b});

  final _TalkKind kind;
  final TalkRunner runner;
  final String speakerId;
  final String guestId;

  /// Khách thứ hai (sự kiện).
  final String? b;
  final String? storyId;

  /// Chuyện phiếm: ♥ đã cộng lúc chọn.
  final int granted;

  /// Đang tự đi tới cạnh khách (chưa mở khung thoại).
  bool approaching = false;
  double approachT = 0;

  /// Lái tay bị tạm dừng để tự đi tới khách → bật lại khi xong.
  bool resumeDrive = false;

  /// Bốc thăm người thắng (Q1 B): true = a thắng.
  bool? aWins;
  int serial = 0;
}

/// Cặp khách của sự kiện đang chạy.
class _Pair {
  _Pair(this.eventId, this.a, this.b);

  final String eventId;
  final ChibiActor a, b;
  bool resolved = false;
  bool timedOut = false;
}

class Shop3dPilot {
  Shop3dPilot(
    this.world, {
    math.Random? rng,
    bool events = true,
    QuarrelDirector? quarrel,
    List<TalkStory>? stories,
  })  : _rng = rng ?? math.Random(),
        stories = stories ?? TalkStories.all {
    this.quarrel = quarrel ?? QuarrelDirector(rng: _rng, enabled: events);
    _owned = {...world.owned};
    nav = Shop3dNav.fromLayout(owned: _owned);
    items = ItemBoard(nav, owned: _owned);
    ledger = TalkLedger(rng: _rng);
    _prepareNext();
  }

  final Shop3dPilotWorld world;
  final math.Random _rng;
  final List<TalkStory> stories;

  late Shop3dNav nav;
  late final ItemBoard items;
  late final QuarrelDirector quarrel;
  late final TalkLedger ledger;
  final cooldowns = PilotCooldowns();
  final hits = ThrowHitTracker();
  Set<String> _owned = const {};

  /// Đồng hồ phiên (giây).
  double now = 0;

  // ---- Thông số ---------------------------------------------------------------------------------------------

  /// Bán kính va chạm tối đa của nhân vật điều khiển (bếp hẹp: lưới nav kiểm theo 0,27 m).
  static const double maxNavRadius = 0.27;

  /// Joystick: vùng chết; đi 0,15–0,8 ↔ 0,35–1,0 × tốc độ dáng đi; chạy 1,6 ×.
  static const double deadZone = 0.15, walkTop = 0.8, walkMin = 0.35, runFactor = 1.6;

  /// Quay người khi đổi hướng: tốc độ nhân max(0,35, cos lệch).
  static const double minTurnFactor = 0.35;

  /// Chạm khách khi đang điều khiển nhân viên: ≤ 2,5 m thì mở luôn nói chuyện.
  static const double tapTalkRange = 2.5;

  /// Nói chuyện: nhân viên xa hơn 3,5 m thì tự đi tới cạnh khách (tối đa 5 s), đứng cách khách 0,9 m.
  static const double approachRange = 3.5, approachLimit = 5, talkGap = 0.9;

  /// Sự kiện: tâm, chỗ đứng của A / B / Mai, chỗ xuất hiện.
  static const double eventX = 2.2, eventZ = 5.5;
  static const (double, double) eventA = (1.75, 5.5), eventB = (2.65, 5.5), eventMai = (2.2, 4.8);
  static const (double, double) eventEnterA = (-6.5, 6.2), eventEnterB = (6.5, 6.2);

  /// Ra vỉa hè (z lớn hơn): camera kéo yaw về |yaw| ≤ 80°.
  static const double sidewalkZ = 4.2;

  /// Bảng nút A tính lại mỗi chừng này giây.
  static const double decideInterval = 0.1;

  /// Id nhân viên (chạm vào thì hiện menu; điều khiển được).
  static bool isStaffId(String id) =>
      id == 'mai' || id.startsWith('mai_') || id.startsWith('staff_') || id.endsWith('_fest');

  // ---- Trạng thái công khai cho lớp view ----------------------------------------------------------------------

  final _hud = ValueNotifier<PilotHud>(const PilotHud());
  final _talk = ValueNotifier<PilotTalkLine?>(null);
  final _pick = ValueNotifier<PilotPickPrompt?>(null);
  final _banner = ValueNotifier<bool>(false);
  final _waveCooldown = ValueNotifier<double>(0);
  final _hearts = ValueNotifier<int>(0);
  final _coins = ValueNotifier<int>(0);
  final _bubblesRev = ValueNotifier<int>(0);

  ValueListenable<PilotHud> get hud => _hud;
  ValueListenable<PilotTalkLine?> get talk => _talk;
  ValueListenable<PilotPickPrompt?> get pick => _pick;
  ValueListenable<bool> get banner => _banner;

  /// Hồi chiêu nút Vẫy còn lại (1 → 0).
  ValueListenable<double> get waveCooldown => _waveCooldown;

  /// ♥ thiện cảm / xu thử trong phiên.
  ValueListenable<int> get hearts => _hearts;
  ValueListenable<int> get coins => _coins;

  /// Đổi mỗi khi danh sách [bubbles] đổi (thêm / hết hạn).
  ValueListenable<int> get bubblesRevision => _bubblesRev;
  final List<PilotBubble> bubbles = [];

  /// Toast chờ lớp view lấy ra ([takeNotices]).
  final List<PilotNotice> _notices = [];

  String? get pilotId => _hud.value.pilotId;
  bool get dialogueOpen => _session != null && !_session!.approaching;

  /// Cặp khách sự kiện đang hiện (id A, id B) — lớp view đặt bong bóng / mũi tên.
  (String, String)? get eventPair => _pair == null ? null : (_pair!.a.id, _pair!.b.id);

  // ---- Đầu vào ------------------------------------------------------------------------------------------------

  double _jx = 0, _jy = 0;
  bool _run = false, _stickActive = false;

  /// Góc yaw của camera (rad) — hướng đi theo camera.
  double cameraYaw = 0;

  /// Joystick (đọc mỗi khung): [jx], [jy] trong [−1; 1] (trục y màn, đẩy lên = âm), [running] (có trễ), [active]
  /// (có ngón / phím đang giữ → huỷ việc tự đi).
  void setStick(double jx, double jy, {bool running = false, bool active = false}) {
    if (_locked) {
      _jx = _jy = 0;
      _run = _stickActive = false;
      return;
    }
    _jx = jx;
    _jy = jy;
    _run = running;
    _stickActive = active || jx != 0 || jy != 0;
  }

  bool _locked = false;

  /// Khoá điều khiển (ca bán): ẩn joystick / cụm nút ([PilotHud.controlsVisible] = false); cần điều khiển, nút A / Ném /
  /// Vẫy, chạm vào nhân vật và đổi người điều khiển bị bỏ qua. Nhân vật đang điều khiển vẫn đứng đó. Khi khoá, sự kiện
  /// cãi nhau mới không bắt đầu.
  bool get locked => _locked;

  set locked(bool v) {
    if (_locked == v) return;
    _locked = v;
    if (v) {
      _jx = _jy = 0;
      _run = _stickActive = false;
      _cancelPick();
    }
    _decideNow();
  }

  // ---- Trạng thái nội bộ --------------------------------------------------------------------------------------

  ChibiActor? _pilot;
  _TalkSession? _session;
  _Pair? _pair;

  /// Khách sự kiện đã xong sự kiện nhưng còn đi vòng trong tiệm: gỡ khi đi hết vòng.
  final List<ChibiActor> _strays = [];
  String? _pendingSpawn;
  bool _maiAuto = false; // Mai tự đi tới chỗ can (Mai ra xem)
  bool _maiAutoResumeDrive = false;
  final Set<String> _doneEvents = {};
  double _decideT = 0;
  double _lastWave = -1e9;
  double _pickT = 0;
  int _bubbleSerial = 0;
  double _argueBubbleT = 0;
  bool _argueSideA = true;

  // Ném đang lấy đà.
  ShopItem? _throwItem;
  double _throwIn = 0, _throwDist = 0;

  // Mochi đuổi cuộn len.
  int _mochiChase = 0; // 0 không; 1 đang chạy tới; 2 vồ; 3 ngồi
  double _mochiT = 0;

  // Bộ đệm tái dùng.
  final _move = NavMove();
  final List<NavCircle> _circles = [];
  final List<ItemTarget> _targets = [];
  final List<double> _hand = [0, 0, 0];
  final List<double> _hand2 = [0, 0, 0];

  List<ChibiActor> get _actors => world.director.actors;

  ChibiActor? actorById(String id) {
    for (final a in _actors) {
      if (a.id == id) return a;
    }
    return null;
  }

  ChibiActor? get _mochi => actorById('mochi');

  /// Lấy (và xoá) toast đang chờ.
  List<PilotNotice> takeNotices() {
    if (_notices.isEmpty) return const [];
    final out = List<PilotNotice>.of(_notices);
    _notices.clear();
    return out;
  }

  void dispose() {
    _hud.dispose();
    _talk.dispose();
    _pick.dispose();
    _banner.dispose();
    _waveCooldown.dispose();
    _hearts.dispose();
    _coins.dispose();
    _bubblesRev.dispose();
  }

  /// Cờ mở rộng đổi: dựng lại lưới va chạm, vật theo mặt đặt.
  void setOwned(Set<String> owned) {
    _owned = {...owned};
    nav = Shop3dNav.fromLayout(owned: _owned);
    items.owned = _owned;
  }

  double _radiusOf(ChibiActor a) => math.min(a.model.radius, maxNavRadius);

  // ---- Hàm thuần (test được riêng) ----------------------------------------------------------------------------

  /// Hướng đi trên sàn (x, z) từ joystick ([jx], [jy]) theo camera [yaw]: `jx·right + (−jy)·forward`, với
  /// forward = (−sin yaw, −cos yaw), right = (cos yaw, −sin yaw). Chưa chuẩn hoá (độ dài = độ lớn cần).
  static (double, double) stickToWorld(double jx, double jy, double yaw) {
    final s = math.sin(yaw), c = math.cos(yaw);
    return (jx * c + jy * s, -jx * s + jy * c);
  }

  /// Hệ số tốc độ (× `gait.speed`) theo độ lớn cần [mag]: vùng chết 0; đi 0,15–0,8 ↔ 0,35–1,0; [running] (và chạy
  /// được) 1,6; nhân [carryFactor] (bao bột 0,7).
  static double speedFactor(double mag, {bool running = false, bool canRun = true, double carryFactor = 1}) {
    if (mag < deadZone) return 0;
    double k;
    if (running && canRun) {
      k = runFactor;
    } else {
      k = walkMin + (1 - walkMin) * ((mag - deadZone) / (walkTop - deadZone)).clamp(0.0, 1.0);
    }
    return k * carryFactor;
  }

  // ---- Điều khiển ------------------------------------------------------------------------------------------

  /// Điều khiển nhân viên [id] (người đang điều khiển trước đó được thả về kịch bản). false nếu không được.
  bool control(String id) {
    if (_locked || dialogueOpen || !isStaffId(id)) return false;
    final a = actorById(id);
    if (a == null) return false;
    if (_pilot == a) return true;
    if (_pilot != null) release();
    _cancelPick();
    if (_session != null && _session!.speakerId == id) _cancelTalk();
    if (id == 'mai' && _maiAuto) {
      _maiAuto = false;
      quarrel.cancelSendMai();
    }
    a.cancelRoute();
    a.stopPerform();
    a.startDriving();
    // Đứng sẵn trong ô chặn (vd. vừa ngồi / sát quầy) → dời ra ô trống gần nhất.
    final r = _radiusOf(a);
    if (!nav.canStand(a.pose.x, a.pose.z, r)) {
      final p = nav.nearestFree(a.pose.x, a.pose.z, r, maxDist: 2);
      if (p != null) a.driveMove(p.x, p.z, null);
    }
    _pilot = a;
    _decideNow();
    return true;
  }

  /// Thôi điều khiển ("Xong"): đang cầm đồ thì đặt xuống trước chân; đi A* về điểm kịch bản đang dở rồi chạy tiếp.
  void release() {
    final a = _pilot;
    if (a == null) return;
    if (dialogueOpen) return;
    _dropHeld(a);
    _throwItem = null;
    final s = _session;
    if (s != null && s.speakerId == a.id) _cancelTalk();
    if (a.id == 'mai' && _maiAuto) {
      _maiAuto = false;
      quarrel.cancelSendMai();
    }
    _pilot = null;
    a.carry = ChibiCarry.none;
    a.stopDriving(route: _routeTo(a, a.scriptResumePoint));
    _cancelPick();
    _decideNow();
  }

  void _dropHeld(ChibiActor a) {
    final held = items.heldBy(a.id);
    if (held != null) items.putDown(held, a.pose.x, a.pose.z, a.pose.yaw);
    a.carry = ChibiCarry.none;
  }

  /// Đường A* từ chỗ đứng của [a] tới [to] (x, z): danh sách điểm (không gồm điểm xuất phát). Không có đường → đi
  /// thẳng tới đích (lộ trình tự dời thẳng nếu kẹt quá hạn).
  List<(double, double)> _routeTo(ChibiActor a, (double, double) to) {
    final (tx, tz) = to;
    final dx = tx - a.pose.x, dz = tz - a.pose.z;
    if (dx * dx + dz * dz < 0.01) return const [];
    final path = nav.findPath(a.pose.x, a.pose.z, tx, tz);
    if (path == null || path.isEmpty) return [(tx, tz)];
    return [for (final p in path) (p.x, p.z)];
  }

  // ---- Mỗi khung ----------------------------------------------------------------------------------------------

  /// Tiến [dt] giây (trước `ChibiDirector.update`).
  void update(double dt) {
    if (dt <= 0) return;
    if (dt > 0.1) dt = 0.1;
    now += dt;
    _drivePilot(dt);
    _updateThrow(dt);
    _updateItems(dt);
    _updateTalk(dt);
    _updateQuarrel(dt);
    _updateMochi(dt);
    _updatePick(dt);
    final waveLeft = ((cooldowns.waveCooldown - (now - _lastWave)) / cooldowns.waveCooldown).clamp(0.0, 1.0);
    if ((waveLeft - _waveCooldown.value).abs() > 0.02 || (waveLeft == 0 && _waveCooldown.value != 0)) {
      _waveCooldown.value = waveLeft;
    }
    _decideT -= dt;
    if (_decideT <= 0) _decideNow();
    _expireBubbles();
  }

  /// Sau `ChibiDirector.update`: vật cầm tay bám bàn tay; NPC bị chắn đường lên tiếng.
  void lateUpdate() {
    for (final it in items.items) {
      if (it.phase != ItemPhase.held) continue;
      final h = actorById(it.holderId ?? '');
      if (h == null) continue;
      _syncHeld(it, h);
    }
    for (final a in world.director.excuseMe) {
      _bubble(a.id, (l) => l.reactExcuseMe, PilotBubbleKind.speech, 2.2);
    }
  }

  void _syncHeld(ShopItem it, ChibiActor h) {
    final r = it.spec.radius;
    if (it.spec.twoHands) {
      h.handWorld(1, _hand);
      h.handWorld(-1, _hand2);
      final fx = math.sin(h.pose.yaw), fz = math.cos(h.pose.yaw);
      it
        ..x = (_hand[0] + _hand2[0]) / 2 + fx * r * 0.45
        ..z = (_hand[2] + _hand2[2]) / 2 + fz * r * 0.45
        ..y = math.max(0, (_hand[1] + _hand2[1]) / 2 - r * 1.1);
    } else {
      h.handWorld(1, _hand);
      it
        ..x = _hand[0]
        ..z = _hand[2]
        ..y = math.max(0, _hand[1] - r * 1.15);
    }
  }

  void _drivePilot(double dt) {
    final a = _pilot;
    if (a == null) return;
    if (_maiAuto && a.id == 'mai') {
      if (_stickActive) {
        // Người chơi đẩy cần: huỷ "Mai ra xem".
        _maiAuto = false;
        quarrel.cancelSendMai();
        a.cancelRoute();
        if (!a.driven) a.startDriving();
      } else {
        return;
      }
    }
    if (!a.driven || dialogueOpen || (_session?.approaching ?? false) || a.frozen) {
      a.driveRunning = false;
      return;
    }
    final mag = math.min(1.0, math.sqrt(_jx * _jx + _jy * _jy));
    final held = items.heldBy(a.id);
    final k = speedFactor(mag,
        running: _run, canRun: PilotRules.canRun(held), carryFactor: PilotRules.speedFactor(held));
    if (k <= 0) {
      a.driveRunning = false;
      return;
    }
    final (dx, dz) = stickToWorld(_jx, _jy, cameraYaw);
    final len = math.sqrt(dx * dx + dz * dz);
    if (len < 1e-6) return;
    final ux = dx / len, uz = dz / len;
    final want = math.atan2(ux, uz);
    final turn = math.max(minTurnFactor, math.cos(_wrap(want - a.pose.yaw)));
    final step = a.model.gait.speed * k * turn * dt;
    _fillCircles(a);
    nav.slide(a.pose.x, a.pose.z, ux * step, uz * step, _radiusOf(a), out: _move, others: _circles);
    a.driveMove(_move.x, _move.z, want);
    a.driveRunning = _run && PilotRules.canRun(held);
  }

  /// Hình tròn NPC cho phép trượt (tái dùng đối tượng; chỉ cấp phát khi số nhân vật tăng).
  void _fillCircles(ChibiActor self) {
    var n = 0;
    for (final b in _actors) {
      if (identical(b, self) || b.done) continue;
      if (n == _circles.length) _circles.add(NavCircle(0, 0, 0));
      _circles[n]
        ..x = b.pose.x
        ..z = b.pose.z
        ..r = math.min(b.model.radius, maxNavRadius) * 0.85
        ..id = b.id;
      n++;
    }
    if (_circles.length > n) _circles.removeRange(n, _circles.length);
  }

  // ---- Nút A ----------------------------------------------------------------------------------------------

  /// Khách có thể là đích (không gồm nhân viên, Mochi, người đã xong vòng).
  bool _isGuest(ChibiActor a) => !isStaffId(a.id) && a.id != 'mochi' && !a.done && !_inQuarrel(a);

  /// Thuộc cặp khách đang cãi (chưa giải quyết): chỉ can được, không nói chuyện / mời bánh.
  bool _inQuarrel(ChibiActor a) {
    final p = _pair;
    return p != null && !p.resolved && !p.timedOut && (identical(a, p.a) || identical(a, p.b));
  }

  PilotSnapshot _snapshot(ChibiActor a) {
    final held = items.heldBy(a.id);
    final mochi = _mochi;
    String? surface;
    if (held != null) {
      surface = items.findPlaceTarget(a.pose.x, a.pose.z, a.pose.yaw, itemRadius: held.spec.radius)?.surface.id;
    }
    final pair = _pair;
    return PilotSnapshot(
      role: PilotRole.ofId(a.id),
      x: a.pose.x,
      z: a.pose.z,
      held: held,
      guests: [
        for (final g in _actors)
          if (_isGuest(g)) PilotGuest(g.id, g.pose.x, g.pose.z, walking: g.isBusyMoving || g.isHopping),
      ],
      items: items.items,
      mochiX: mochi?.pose.x,
      mochiZ: mochi?.pose.z,
      event: pair == null || pair.resolved || pair.timedOut
          ? null
          : PilotEventInfo(pair.eventId, eventX, eventZ, canIntervene: quarrel.canIntervene),
      placeSurfaceId: surface,
    );
  }

  /// Bảng nút A hiện tại (theo [PilotRules.decideA]).
  PilotDecision get decision => _hud.value.decision;

  void _decideNow() {
    _decideT = decideInterval;
    final a = _pilot;
    if (a == null) {
      _hud.value = PilotHud(dialogue: dialogueOpen, locked: _locked);
      return;
    }
    final snap = _snapshot(a);
    var d = PilotRules.decideA(snap);
    // Đang ném dở / đang tự đi: chưa cho bấm A.
    if (_throwItem != null || (_session?.approaching ?? false)) d = PilotDecision.none;
    _hud.value = PilotHud(
      pilotId: a.id,
      decision: d,
      showThrow: PilotRules.throwVisible(snap.role, snap.held),
      dialogue: dialogueOpen,
      locked: _locked,
    );
  }

  /// Nút A.
  void pressA() {
    final a = _pilot;
    if (_locked || a == null || dialogueOpen || a.frozen) return;
    _decideNow();
    final d = decision;
    final id = d.targetId;
    switch (d.action) {
      case PilotAction.intervene:
        _startQuarrelTalk();
      case PilotAction.offerCake:
        if (id != null) _offer(a, id);
      case PilotAction.placeOn:
        _placeOn(a);
      case PilotAction.putDown:
        final held = items.heldBy(a.id);
        if (held != null) {
          a.perform(ChibiAction.bend, 0.35);
          items.putDown(held, a.pose.x, a.pose.z, a.pose.yaw);
          a.carry = ChibiCarry.none;
        }
      case PilotAction.pickUp:
        final it = id == null ? null : items.byId(id);
        if (it != null && items.pickUp(it, a.id)) {
          a.perform(ChibiAction.bend, 0.35, faceYaw: math.atan2(it.x - a.pose.x, it.z - a.pose.z));
          a.carry = it.spec.twoHands ? ChibiCarry.twoHands : ChibiCarry.leftHand;
        }
      case PilotAction.talk:
        if (id != null) startTalk(a.id, id);
      case PilotAction.petMochi:
        _petMochi(a);
      case PilotAction.none:
        break;
    }
    _decideNow();
  }

  double _yawTo(ChibiActor from, ChibiActor to) => math.atan2(to.pose.x - from.pose.x, to.pose.z - from.pose.z);

  void _offer(ChibiActor a, String guestId) {
    final g = actorById(guestId);
    final held = items.heldBy(a.id);
    if (g == null || held == null) return;
    a.driveFace(_yawTo(a, g));
    if (cooldowns.offer(guestId, now) == OfferResult.full) {
      _bubble(g.id, (l) => l.reactFull, PilotBubbleKind.speech, 2.4);
      g.perform(ChibiAction.talk, 1.2, faceYaw: _yawTo(g, a), freeze: g.isBusyMoving ? 0 : 1.2);
      return;
    }
    items.consume(held);
    a.carry = ChibiCarry.none;
    g.perform(ChibiAction.happy, 1.5, faceYaw: _yawTo(g, a));
    _bubble(g.id, (l) => l.reactThanks, PilotBubbleKind.speech, 2.4);
    _reward(PilotCooldowns.offerHearts, PilotCooldowns.offerCoins);
  }

  void _placeOn(ChibiActor a) {
    final held = items.heldBy(a.id);
    if (held == null) return;
    final t = items.findPlaceTarget(a.pose.x, a.pose.z, a.pose.yaw, itemRadius: held.spec.radius);
    if (t == null) return;
    a.perform(ChibiAction.bend, 0.3, freeze: 0.3);
    a.carry = ChibiCarry.none;
    if (items.placeOn(held, t)) {
      // Bao bột lên bàn trộn: Bảo (nếu có) hoặc Mai cảm ơn.
      final thanker = actorById('staff_bao') ?? actorById('mai');
      if (thanker != null) _bubble(thanker.id, (l) => l.reactThanks, PilotBubbleKind.speech, 2.4);
    }
  }

  void _petMochi(ChibiActor a) {
    final m = _mochi;
    if (m == null) return;
    a.perform(ChibiAction.bend, 0.5, faceYaw: _yawTo(a, m));
    m.perform(ChibiAction.wave, 1.6, faceYaw: _yawTo(m, a));
    _bubble(m.id, (l) => l.reactPurr, PilotBubbleKind.speech, 2.2);
    if (cooldowns.pet()) _reward(1, 0);
  }

  // ---- Ném --------------------------------------------------------------------------------------------------

  /// Nút B chạm nhanh: ném 2,5 m.
  void throwTap() => _throw(ItemPhysics.quickThrow);

  /// Nút B giữ rồi thả: [power] 0..1 ↔ 1,5..4,0 m.
  void throwCharged(double power) =>
      _throw(ItemPhysics.minThrow + (ItemPhysics.maxThrow - ItemPhysics.minThrow) * power.clamp(0.0, 1.0));

  /// Phím Q giữ [seconds] giây rồi thả.
  void throwHeld(double seconds) => _throw(ItemPhysics.distanceForHold(seconds));

  void _throw(double distance) {
    final a = _pilot;
    if (_locked || a == null || dialogueOpen || _throwItem != null || a.frozen) return;
    final held = items.heldBy(a.id);
    switch (PilotRules.checkThrow(PilotRole.ofId(a.id), held)) {
      case ThrowCheck.cakeNotThrowable:
        _bubble(a.id, (l) => l.reactNoThrowCake, PilotBubbleKind.speech, 2.4);
      case ThrowCheck.ok:
        a.perform(ChibiAction.throwAnim, ChibiActor.throwWindup + ChibiActor.throwSwing + 0.05);
        _throwItem = held;
        _throwIn = ChibiActor.throwWindup;
        _throwDist = distance;
      case ThrowCheck.nothing:
        break;
    }
    _decideNow();
  }

  void _updateThrow(double dt) {
    final it = _throwItem;
    if (it == null) return;
    _throwIn -= dt;
    if (_throwIn > 0) return;
    _throwItem = null;
    final a = it.holderId == null ? null : actorById(it.holderId!);
    if (a == null || it.phase != ItemPhase.held) return;
    items.throwItem(it, a.pose.x, a.pose.z, a.pose.yaw, _throwDist);
    a.carry = ChibiCarry.none;
    _decideNow();
  }

  // ---- Vẫy ------------------------------------------------------------------------------------------------

  /// Nút C: vẫy chào; khách đứng trong 3 m vẫy lại; lần đầu mỗi khách +1♥. Hồi chiêu 8 s.
  void wave() {
    final a = _pilot;
    if (_locked || a == null || dialogueOpen) return;
    final out = cooldowns.wave(now, a.pose.x, a.pose.z, _snapshot(a).guests);
    if (out == null) return;
    _lastWave = now;
    _waveCooldown.value = 1;
    a.perform(ChibiAction.wave, 1.2, freeze: 0);
    for (final id in out.reacting) {
      final g = actorById(id);
      g?.react(_yawTo(g, a));
    }
    if (out.hearts > 0) _reward(out.hearts, 0);
  }

  // ---- Vật ------------------------------------------------------------------------------------------------

  void _updateItems(double dt) {
    var flying = false;
    for (final it in items.items) {
      if (it.phase == ItemPhase.flying) flying = true;
    }
    _targets.clear();
    if (flying) {
      for (final a in _actors) {
        if (a.done) continue;
        final kind = a.id == 'mochi' ? TargetKind.mochi : (isStaffId(a.id) ? TargetKind.staff : TargetKind.guest);
        _targets.add(ItemTarget(a.id, kind, a.pose.x, a.pose.z, a.model.radius * 0.8, a.model.height,
            baseY: a.pose.y));
      }
    }
    final events = items.update(dt, _targets);
    for (final e in events) {
      switch (e.kind) {
        case ItemEventKind.hitTarget:
          _onHit(e);
        case ItemEventKind.landed:
          final it = items.byId(e.itemId);
          if (it != null && it.kind == ItemKind.yarn && it.phase == ItemPhase.rest) _mochiChaseYarn(it);
      }
    }
  }

  void _onHit(ItemEvent e) {
    final g = actorById(e.targetId ?? '');
    if (g == null) return;
    final it = items.byId(e.itemId);
    final thrower = it?.thrownBy == null ? null : actorById(it!.thrownBy!);
    final face = thrower == null ? null : _yawTo(g, thrower);
    if (e.targetKind == TargetKind.staff) {
      _bubble(g.id, (l) => l.reactOops, PilotBubbleKind.exclaim, 1.4);
      if (!g.driven) g.perform(ChibiAction.surprised, 0.5, faceYaw: face);
      return;
    }
    switch (hits.register(g.id, now)) {
      case ThrowHitReaction.surprised:
        _bubble(g.id, (l) => l.reactOops, PilotBubbleKind.exclaim, 1.4);
        // Giật mình 0,5 s (khách đang đi thì dừng 0,6 s) rồi cười.
        g.perform(ChibiAction.surprised, 0.6, faceYaw: face);
      case ThrowHitReaction.pout:
        _bubble(g.id, (l) => l.reactStop, PilotBubbleKind.speech, 2.6);
        // Phụng phịu 20 s: quay mặt đi (ngược hướng người ném), khoanh tay; đứng khựng 0,6 s rồi đi tiếp.
        g.perform(ChibiAction.pout, hits.poutSeconds, faceYaw: face == null ? null : face + math.pi, freeze: 0.6);
        _reward(ThrowHitTracker.poutHearts, 0, toast: false);
      case ThrowHitReaction.alreadyPouting:
        break;
    }
  }

  // ---- Mochi ----------------------------------------------------------------------------------------------

  /// Có Mochi: chạy tới cuộn len, vồ, rồi ngồi (không làm khi Mochi đang ngồi ổ / nhảy lên xuống).
  void _mochiChaseYarn(ShopItem yarn) {
    final m = _mochi;
    if (m == null || _mochiChase != 0 || m.isSeated || m.isHopping) return;
    if (_session != null && (_session!.guestId == 'mochi')) return;
    final dx = m.pose.x - yarn.x, dz = m.pose.z - yarn.z;
    final d = math.sqrt(dx * dx + dz * dz);
    final k = d < 1e-6 ? 0.0 : 0.22 / d;
    m.stopPerform();
    m.followRoute(_routeTo(m, (yarn.x + dx * k, yarn.z + dz * k)), hold: true, limit: 6);
    _mochiChase = 1;
    _mochiT = 0;
  }

  void _updateMochi(double dt) {
    if (_mochiChase == 0) return;
    final m = _mochi;
    if (m == null) {
      _mochiChase = 0;
      return;
    }
    _mochiT += dt;
    switch (_mochiChase) {
      case 1:
        if (!m.routing) {
          final yarn = items.byId('yarn');
          m.perform(ChibiAction.happy, 0.7,
              faceYaw: yarn == null ? null : math.atan2(yarn.x - m.pose.x, yarn.z - m.pose.z));
          _mochiChase = 2;
          _mochiT = 0;
        }
      case 2:
        if (_mochiT > 0.7) {
          m.perform(ChibiAction.rest, 3);
          _mochiChase = 3;
          _mochiT = 0;
        }
      default:
        if (_mochiT > 3) {
          _mochiChase = 0;
          m.resumeScript(route: _routeTo(m, m.scriptResumePoint));
        }
    }
  }

  // ---- Nói chuyện -------------------------------------------------------------------------------------------

  /// Ứng viên nói chuyện của nhân viên [staffId]: khách không đang đi (ở quầy, xếp hàng, đang ngồi) hoặc Mochi đang
  /// ngồi, gần nhất trước; tối đa [max].
  List<String> talkCandidates(String staffId, {int max = 3}) {
    final s = actorById(staffId);
    if (s == null) return const [];
    final list = <(double, String)>[];
    for (final g in _actors) {
      if (g.done || isStaffId(g.id) || g.isBusyMoving || g.isHopping) continue;
      if (g.id == 'mochi' && !(g.isSeated || g.action == ChibiAction.rest)) continue;
      if (_inQuarrel(g)) continue;
      final dx = g.pose.x - s.pose.x, dz = g.pose.z - s.pose.z;
      list.add((dx * dx + dz * dz, g.id));
    }
    list.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in list.take(max)) e.$2];
  }

  /// Menu "Nói chuyện với khách" của nhân viên [staffId]: một ứng viên → vào luôn; nhiều → chip tên + toast; không
  /// có → toast "Chưa có vị khách nào rảnh…".
  void talkFrom(String staffId) {
    if (_locked || dialogueOpen) return;
    final c = talkCandidates(staffId);
    if (c.isEmpty) {
      _notices.add(PilotNotice.text((l) => l.talkNoCustomer));
      return;
    }
    if (c.length == 1) {
      startTalk(staffId, c.first);
      return;
    }
    _pick.value = PilotPickPrompt(staffId, c);
    _pickT = 8;
    _notices.add(PilotNotice.text((l) => l.talkPickCustomer));
  }

  /// Chọn chip tên [guestId].
  void choosePick(String guestId) {
    final p = _pick.value;
    if (p == null || _locked) return;
    _cancelPick();
    startTalk(p.staffId, guestId);
  }

  void cancelPick() => _cancelPick();

  void _cancelPick() {
    if (_pick.value != null) _pick.value = null;
  }

  void _updatePick(double dt) {
    if (_pick.value == null) return;
    _pickT -= dt;
    if (_pickT <= 0) _cancelPick();
  }

  /// Chạm vào khách [guestId]: đang điều khiển nhân viên và khách cách ≤ 2,5 m (không đang đi) → mở nói chuyện. Trả
  /// true nếu đã mở.
  bool tapGuest(String guestId) {
    final a = _pilot;
    final g = actorById(guestId);
    if (_locked || a == null || g == null || dialogueOpen || !_isGuestOrMochi(g)) return false;
    if (g.isBusyMoving || g.isHopping) return false;
    final dx = g.pose.x - a.pose.x, dz = g.pose.z - a.pose.z;
    if (dx * dx + dz * dz > tapTalkRange * tapTalkRange) return false;
    return startTalk(a.id, guestId);
  }

  bool _isGuestOrMochi(ChibiActor g) => !isStaffId(g.id) && !g.done;

  /// Mở nói chuyện giữa nhân viên [staffId] và khách [guestId] (truyện nếu là Mai và khách có truyện chưa xem; không
  /// thì chuyện phiếm). Nhân viên xa hơn 3,5 m thì tự đi tới trước.
  bool startTalk(String staffId, String guestId) {
    if (_locked || _session != null) return false;
    final s = actorById(staffId), g = actorById(guestId);
    if (s == null || g == null || g.done || isStaffId(guestId)) return false;
    // Khách đang đi / đang nhảy lên xuống ghế / đang cãi: không nói chuyện được.
    if (g.isBusyMoving || g.isHopping || _inQuarrel(g)) return false;
    _cancelPick();
    final byMai = PilotRole.ofId(staffId) == PilotRole.mai;
    final present = {for (final a in _actors) a.id};
    if (guestId == 'mochi' &&
        (!byMai || ledger.storyFor(guestId, stories, TalkWorld(present: present, doneEvents: _doneEvents)) == null)) {
      // Mochi không nói chuyện phiếm: rù rù như khi vuốt ve (nhân viên đang điều khiển).
      if (s.driven) _petMochi(s);
      return s.driven;
    }
    final pick = ledger.pick(
        guestId: guestId,
        byMai: byMai,
        stories: stories,
        world: TalkWorld(present: present, doneEvents: _doneEvents),
        now: now);
    _TalkSession session;
    if (pick.kind == TalkPickKind.story) {
      session = _TalkSession(_TalkKind.story, TalkRunner(pick.story!), staffId, guestId, storyId: pick.story!.id);
    } else {
      final story = TalkSmallTalk.build(
          byMai: byMai, staffId: staffId, openIndex: pick.openIndex, replyIndex: pick.replyIndex);
      session = _TalkSession(_TalkKind.smallTalk, TalkRunner(story), staffId, guestId, granted: pick.heartsGranted);
    }
    _session = session;
    g.pauseScript(faceYaw: _yawTo(g, s));
    final dx = g.pose.x - s.pose.x, dz = g.pose.z - s.pose.z;
    final d = math.sqrt(dx * dx + dz * dz);
    if (d > approachRange) {
      // Tự đi A* tới cạnh khách (đứng cách 0,9 m, phía nhân viên), tối đa ~5 s.
      final k = talkGap / d;
      final to = (g.pose.x - dx * k, g.pose.z - dz * k);
      final free = nav.nearestFree(to.$1, to.$2, _radiusOf(s), maxDist: 1.5);
      if (s.driven) {
        session.resumeDrive = true;
        s.stopDriving();
      }
      s.followRoute(_routeTo(s, free == null ? to : (free.x, free.z)), hold: true, limit: approachLimit);
      session.approaching = true;
      session.approachT = 0;
    } else {
      _faceEachOther(s, g);
      _openDialogue();
    }
    _decideNow();
    return true;
  }

  void _faceEachOther(ChibiActor s, ChibiActor g) {
    if (s.driven) {
      s.driveFace(_yawTo(s, g));
    } else {
      s.pauseScript(faceYaw: _yawTo(s, g));
    }
    g.pauseScript(faceYaw: _yawTo(g, s));
  }

  void _updateTalk(double dt) {
    final s = _session;
    if (s == null || !s.approaching) return;
    final sp = actorById(s.speakerId), g = actorById(s.guestId);
    if (sp == null || g == null) {
      _cancelTalk();
      return;
    }
    s.approachT += dt;
    if (!sp.routing || s.approachT > approachLimit + 0.5) {
      sp.cancelRoute();
      s.approaching = false;
      if (s.resumeDrive) {
        sp.startDriving();
        s.resumeDrive = false;
      }
      _faceEachOther(sp, g);
      _openDialogue();
    }
  }

  void _openDialogue() {
    _pushLine();
    _decideNow();
  }

  /// Huỷ cuộc nói chuyện chưa mở / đang đi tới (thôi điều khiển, đổi người).
  void _cancelTalk() {
    final s = _session;
    if (s == null) return;
    _session = null;
    final sp = actorById(s.speakerId), g = actorById(s.guestId);
    if (s.kind == _TalkKind.quarrel) quarrel.cancelIntervention();
    if (g != null && s.kind != _TalkKind.quarrel) g.resumeScript();
    if (sp != null) {
      sp.cancelRoute();
      if (s.resumeDrive) {
        sp.startDriving();
      } else if (!sp.driven) {
        sp.resumeScript(route: _routeTo(sp, sp.scriptResumePoint));
      }
    }
    _talk.value = null;
    _decideNow();
  }

  /// Id nhân vật nói câu vai [who] trong phiên [s].
  String? _actorFor(_TalkSession s, TalkRole who) => switch (who) {
        TalkRole.mai => 'mai',
        TalkRole.staff => s.speakerId,
        TalkRole.a => s.guestId,
        TalkRole.b => s.b,
        TalkRole.hoa => 'hoa',
        TalkRole.narrator => null,
        TalkRole.winner => (s.aWins ?? true) ? s.guestId : s.b,
        TalkRole.loser => (s.aWins ?? true) ? s.b : s.guestId,
      };

  void _pushLine() {
    final s = _session;
    if (s == null) return;
    final r = s.runner;
    s.serial++;
    switch (r.phase) {
      case TalkPhase.done:
        _finishTalk();
        return;
      case TalkPhase.line:
        final line = r.line!;
        _talk.value = _lastLine = _lineView(s, line, s.serial);
        _lastSource = line;
        _animateLine(_actorFor(s, line.who), line.anim);
      case TalkPhase.choice:
        // Lựa chọn: hiện câu cuối của đoạn (kể cả sau "Bỏ qua"); đúng câu đang hiện thì giữ lineId → chữ không chạy
        // lại, cột lựa chọn hiện ngay.
        final lines = r.node!.lines;
        final src = lines.isEmpty ? null : (r.useAlt ? (lines.last.alt ?? lines.last) : lines.last);
        final last = src == null
            ? _lastLine
            : (identical(src, _lastSource) && _lastLine != null ? _lastLine : _lineView(s, src, s.serial));
        _talk.value = PilotTalkLine(
          speakerId: last?.speakerId ?? 'mai',
          speakerName: last == null ? TalkNames.of('mai') : last.speakerName,
          text: last?.text ?? _empty,
          choices: [for (var i = 0; i < r.choices.length; i++) r.labelOf(i)],
          lineId: last?.lineId ?? s.serial,
        );
    }
  }

  PilotTalkLine _lineView(_TalkSession s, TalkLine line, Object lineId) {
    final id = _actorFor(s, line.who);
    return PilotTalkLine(
      speakerId: id,
      speakerName: line.who == TalkRole.narrator || id == null ? null : TalkNames.of(id),
      text: line.text,
      choices: const [],
      lineId: lineId,
    );
  }

  TalkLine? _lastSource;
  PilotTalkLine? _lastLine;
  static String _empty(AppLocalizations l) => '';

  /// Người nói diễn theo câu (vui, giật mình, phụng phịu…; mặc định gật / khua tay); dấu "…" trên đầu.
  void _animateLine(String? id, TalkAnim? anim) {
    if (id == null) return;
    final a = actorById(id);
    if (a == null) return;
    final act = switch (anim) {
      TalkAnim.happy || TalkAnim.laugh => ChibiAction.happy,
      TalkAnim.surprised => ChibiAction.surprised,
      TalkAnim.pout => ChibiAction.pout,
      TalkAnim.argue => ChibiAction.argue,
      TalkAnim.wave => ChibiAction.wave,
      TalkAnim.nod || TalkAnim.shrug || null => ChibiAction.talk,
    };
    a.perform(act, act == ChibiAction.talk ? 2.2 : 1.4, freeze: 0);
    _bubble(id, (l) => '…', PilotBubbleKind.thinking, 2.0);
  }

  /// Chạm khung thoại khi chữ đã hiện hết: sang câu kế.
  void talkNext() {
    final s = _session;
    if (s == null || s.approaching || s.runner.phase != TalkPhase.line) return;
    s.runner.advance();
    _pushLine();
  }

  /// "Bỏ qua": tới lựa chọn kế tiếp hoặc tới cuối (không bao giờ bỏ qua lựa chọn).
  void talkSkip() {
    final s = _session;
    if (s == null || s.approaching || s.runner.phase != TalkPhase.line) return;
    s.runner.skip();
    _pushLine();
  }

  /// Chọn lựa chọn [index].
  void talkChoose(int index) {
    final s = _session;
    if (s == null || s.runner.phase != TalkPhase.choice) return;
    if (index < 0 || index >= s.runner.choices.length) return;
    s.runner.choose(index);
    if (s.runner.totals.effects.contains(TalkSideEffect.randomWinner) && s.aWins == null) {
      s.aWins = _rng.nextBool();
    }
    _pushLine();
  }

  void _finishTalk() {
    final s = _session;
    if (s == null) return;
    _session = null;
    _talk.value = null;
    _lastLine = null;
    _lastSource = null;
    final totals = s.runner.totals;
    final sp = actorById(s.speakerId), g = actorById(s.guestId);
    switch (s.kind) {
      case _TalkKind.story:
        final h = ledger.finishStory(s.storyId!, s.guestId, totals.hearts);
        _reward(h, totals.coins);
        if (totals.effects.contains(TalkSideEffect.mochiChaseYarn)) _rollYarnForMochi();
        g?.resumeScript();
      case _TalkKind.smallTalk:
        _reward(s.granted, 0);
        g?.resumeScript();
      case _TalkKind.quarrel:
        _resolveQuarrel(s);
    }
    if (sp != null) {
      if (s.resumeDrive) {
        sp.startDriving();
      } else if (!sp.driven) {
        sp.resumeScript(route: _routeTo(sp, sp.scriptResumePoint));
      }
    }
    _decideNow();
  }

  /// T5 C2: cuộn len lăn ra 1,5 m, Mochi chạy theo.
  void _rollYarnForMochi() {
    final yarn = items.byId('yarn'), m = _mochi;
    if (yarn == null || m == null || yarn.phase != ItemPhase.rest) return;
    final ang = _rng.nextDouble() * 2 * math.pi;
    final x = m.pose.x + math.sin(ang) * 1.5, z = m.pose.z + math.cos(ang) * 1.5;
    final p = nav.nearestFree(x, z, ItemPhysics.restRadius, maxDist: 2) ?? NavPoint(yarn.x, yarn.z);
    yarn
      ..x = p.x
      ..z = p.z
      ..y = nav.floorHeight(p.x, p.z)
      ..surfaceId = null;
    _mochiChaseYarn(yarn);
  }

  void _reward(int hearts, int coins, {bool toast = true}) {
    if (hearts != 0) _hearts.value = math.max(0, _hearts.value + hearts);
    if (coins != 0) _coins.value += coins;
    if (toast && (hearts > 0 || coins > 0)) _notices.add(PilotNotice.reward(math.max(0, hearts), coins));
  }

  // ---- Sự kiện cãi nhau ---------------------------------------------------------------------------------------

  /// Dựng sẵn cặp khách của sự kiện kế tiếp.
  void _prepareNext() {
    final story = QuarrelEvents.byId[quarrel.nextEventId];
    if (story != null) world.prepareModels(story.cast.toList());
  }

  /// Ép chạy sự kiện [id] (`?event=`, nút debug); null = sự kiện kế tiếp. false nếu đang có sự kiện.
  bool forceEvent([String? id]) {
    final eid = id ?? quarrel.nextEventId;
    if (_pair != null || !quarrel.forceStart(eid)) return false;
    _spawnPair(eid);
    return true;
  }

  void _updateQuarrel(double dt) {
    final signals =
        quarrel.update(dt, dialogueOpen: _locked || (_session != null && _session!.kind != _TalkKind.quarrel));
    for (final sig in signals) {
      switch (sig.kind) {
        case QuarrelSignalKind.gatherStarted:
          _spawnPair(sig.eventId);
        case QuarrelSignalKind.arguingStarted:
          _banner.value = true;
        case QuarrelSignalKind.timedOut:
          _banner.value = false;
          _onQuarrelTimeout();
        case QuarrelSignalKind.ended:
          _despawnPair();
      }
    }
    if (_pendingSpawn != null) _spawnPair(_pendingSpawn!);
    if (_strays.isNotEmpty) {
      _strays.removeWhere((a) {
        if (!_actors.contains(a)) return true;
        if (!a.done) return false;
        world.removeActor(a);
        return true;
      });
    }
    final pair = _pair;
    if (pair == null) return;
    // Banner chỉ hiện khi đang cãi và chưa ai can.
    final wantBanner = quarrel.canIntervene && !quarrel.sendMaiRequested;
    if (_banner.value != wantBanner) _banner.value = wantBanner;
    // Mai ra xem: tới nơi → tự mở hội thoại can ngăn.
    if (_maiAuto) {
      final mai = actorById('mai');
      if (mai == null) {
        _maiAuto = false;
      } else {
        final dx = mai.pose.x - eventX, dz = mai.pose.z - eventZ;
        if (quarrel.maiArrived(math.sqrt(dx * dx + dz * dz))) {
          _maiAuto = false;
          mai.cancelRoute();
          if (_maiAutoResumeDrive) mai.startDriving();
          _startQuarrelTalk();
        } else if (!mai.routing && !quarrel.sendMaiRequested) {
          _maiAuto = false;
        }
      }
    }
    // Cãi nhau: "!" phồng trên đầu, xen kẽ hai người.
    if (quarrel.phase == QuarrelPhase.arguing) {
      _argueBubbleT -= dt;
      if (_argueBubbleT <= 0) {
        _argueBubbleT = 1.1;
        _argueSideA = !_argueSideA;
        _bubble((_argueSideA ? pair.a : pair.b).id, (l) => '!', PilotBubbleKind.puff, 1.0);
      }
    }
    // Sau khi giải quyết / hết giờ: gỡ người đã xong vòng; vỉa hè trống thì kết thúc sự kiện.
    if (pair.resolved || pair.timedOut) {
      for (final a in [pair.a, pair.b]) {
        if (a.done && _actors.contains(a)) world.removeActor(a);
      }
      final aGone = !_actors.contains(pair.a) || pair.a.pose.z < sidewalkZ - 0.3;
      final bGone = !_actors.contains(pair.b) || pair.b.pose.z < sidewalkZ - 0.3;
      if (quarrel.phase == QuarrelPhase.aftermath && aGone && bGone) {
        quarrel.endAftermath();
        if (pair.resolved) _notices.add(PilotNotice.text((l) => l.quarrelPeace, icon: PilotNoticeIcon.event));
        _prepareNext();
        // Sự kiện xong; người đã vào tiệm đi tiếp vòng khách (nói chuyện được — T6–T8) rồi được gỡ.
        for (final a in [pair.a, pair.b]) {
          if (_actors.contains(a)) _strays.add(a);
        }
        _pair = null;
      } else if (!_actors.contains(pair.a) && !_actors.contains(pair.b)) {
        _pair = null;
      }
    }
  }

  void _spawnPair(String eventId) {
    final story = QuarrelEvents.byId[eventId];
    if (story == null) {
      _pendingSpawn = null;
      return;
    }
    final ids = story.cast.toList();
    // Còn người của lần trước trong tiệm (cùng id) → gỡ trước.
    for (final id in ids) {
      final old = actorById(id);
      if (old != null) {
        world.removeActor(old);
        _strays.remove(old);
      }
    }
    final ma = world.readyModel(ids[0]), mb = world.readyModel(ids[1]);
    if (ma == null || mb == null) {
      _pendingSpawn = eventId;
      world.prepareModels(ids);
      return;
    }
    _pendingSpawn = null;
    const floor = Shop3dLayout.floorHeightAt;
    ChibiActor make(ChibiModel m, (double, double) from, (double, double) to, double face, int seed) {
      final dist = math.sqrt(math.pow(to.$1 - from.$1, 2) + math.pow(to.$2 - from.$2, 2)).toDouble();
      final a = ChibiActor(m, [
        ChibiStep.walk([to]),
        ChibiStep.act(ChibiAction.argue, 600, faceYaw: face),
      ], x: from.$1, z: from.$2, yaw: math.atan2(to.$1 - from.$1, to.$2 - from.$2), seed: seed, floor: floor);
      // Kéo tới trong ~6 s.
      a.speedScale = (dist / (quarrel.gatherSeconds * math.max(0.2, m.gait.speed))).clamp(1.0, 2.4);
      return a;
    }

    final a = make(ma, eventEnterA, eventA, math.pi / 2, 101);
    final b = make(mb, eventEnterB, eventB, -math.pi / 2, 103);
    world.addActor(a);
    world.addActor(b);
    _pair = _Pair(eventId, a, b);
    _argueBubbleT = 0;
  }

  void _despawnPair() {
    final p = _pair;
    if (p == null) return;
    for (final a in [p.a, p.b]) {
      if (_actors.contains(a)) world.removeActor(a);
    }
    _pair = null;
    _banner.value = false;
    _prepareNext();
  }

  /// "Mai ra xem": Mai tự đi A* tới chỗ can; tới nơi thì hội thoại tự mở. Người chơi đẩy cần thì huỷ.
  void sendMai() {
    final mai = actorById('mai');
    if (mai == null || !quarrel.requestSendMai()) return;
    _maiAuto = true;
    _maiAutoResumeDrive = mai.driven;
    if (mai.driven) mai.stopDriving();
    mai.stopPerform();
    mai.followRoute(_routeTo(mai, eventMai), hold: true, limit: 30);
    _banner.value = false;
  }

  void _startQuarrelTalk() {
    final pair = _pair;
    final mai = actorById('mai');
    if (pair == null || mai == null || _session != null) return;
    if (!quarrel.beginIntervention()) return;
    final story = QuarrelEvents.byId[pair.eventId]!;
    final useAlt = pair.eventId == 'tart' && actorById('hoa') == null;
    final s = _TalkSession(_TalkKind.quarrel, TalkRunner(story, useAlt: useAlt), 'mai', pair.a.id, b: pair.b.id);
    _session = s;
    _banner.value = false;
    // Mai đứng can giữa hai người, quay về phía họ; hai khách quay vào Mai.
    final face = math.atan2(eventX - mai.pose.x, eventZ - mai.pose.z);
    if (mai.driven) {
      mai.driveFace(face);
    } else {
      mai.pauseScript(faceYaw: face);
    }
    pair.a.pauseScript(faceYaw: _yawTo(pair.a, mai));
    pair.b.pauseScript(faceYaw: _yawTo(pair.b, mai));
    _openDialogue();
  }

  void _resolveQuarrel(_TalkSession s) {
    final pair = _pair;
    final t = s.runner.totals;
    _reward(t.hearts, t.coins);
    quarrel.resolve();
    if (pair == null) return;
    pair.resolved = true;
    _doneEvents.add(pair.eventId);
    final join = <ChibiActor>{}, leave = <ChibiActor>{};
    ChibiActor? of(TalkRole r) => switch (r) {
          TalkRole.a => pair.a,
          TalkRole.b => pair.b,
          TalkRole.winner => (s.aWins ?? true) ? pair.a : pair.b,
          TalkRole.loser => (s.aWins ?? true) ? pair.b : pair.a,
          _ => null,
        };
    for (final r in t.joinQueue) {
      final a = of(r);
      if (a != null) join.add(a);
    }
    for (final r in t.leave) {
      final a = of(r);
      if (a != null) leave.add(a);
    }
    if (t.effects.contains(TalkSideEffect.randomWinner)) {
      join.add(of(TalkRole.winner)!);
      leave.add(of(TalkRole.loser)!);
    }
    join.removeAll(leave);
    final delayed = t.effects.contains(TalkSideEffect.delayedEnter);
    var seat = 0;
    for (final a in [pair.a, pair.b]) {
      a.resumeScript();
      a.stopPerform();
      if (join.contains(a)) {
        _enterShop(a, seat++, delayed: delayed);
        if (t.mood[a == pair.a ? TalkRole.a : TalkRole.b] == TalkMood.pout ||
            t.effects.contains(TalkSideEffect.glareAtEachOther)) {
          a.perform(ChibiAction.pout, 10, freeze: 0);
        }
      } else {
        _leavePouting(a, a == pair.a);
      }
    }
    if (t.effects.contains(TalkSideEffect.crowdLaughs)) {
      for (final g in _actors) {
        if (g == pair.a || g == pair.b || g.done) continue;
        final dx = g.pose.x - eventX, dz = g.pose.z - eventZ;
        if (dx * dx + dz * dz <= 9) g.react(math.atan2(-dx, -dz));
      }
    }
  }

  /// Khách vui vào tiệm: (chờ 30 s trước cửa nếu [delayed]) → một vòng khách (hàng chờ → quầy → bàn → ra cửa) rồi ẩn.
  void _enterShop(ChibiActor a, int index, {bool delayed = false}) {
    final counter = Shop3dLayout.counterSpots[index == 0 ? 0 : 2];
    final seat = Shop3dLayout.seats[index == 0 ? 0 : 1];
    final loop = ChibiCast.customerLoop(counter, seat, sitTime: 7);
    a.speedScale = 1;
    a.setScript([
      if (delayed) const ChibiStep.act(ChibiAction.happy, 30, faceYaw: math.pi),
      ...loop,
    ], once: true);
  }

  /// Khách phụng phịu bỏ về đầu vỉa hè phía mình rồi ẩn.
  void _leavePouting(ChibiActor a, bool isA) {
    final (x, z) = isA ? eventEnterA : eventEnterB;
    a.speedScale = 1;
    a.setScript([
      ChibiStep.walk([(x, z)]),
    ], once: true);
    a.perform(ChibiAction.pout, 30, freeze: 0.8, faceYaw: math.atan2(x - a.pose.x, z - a.pose.z));
  }

  void _onQuarrelTimeout() {
    final p = _pair;
    _notices.add(PilotNotice.text((l) => l.quarrelTimeout, icon: PilotNoticeIcon.event));
    final mai = actorById('mai');
    if (_maiAuto && mai != null) {
      _maiAuto = false;
      mai.cancelRoute();
      if (_maiAutoResumeDrive) {
        mai.startDriving();
      } else {
        mai.resumeScript(route: _routeTo(mai, mai.scriptResumePoint));
      }
    }
    if (p == null) return;
    p.timedOut = true;
    _leavePouting(p.a, true);
    _leavePouting(p.b, false);
  }

  // ---- Bong bóng --------------------------------------------------------------------------------------------

  /// Bong bóng chữ [text] trên đầu nhân vật [actorId] trong [duration] giây (thay bong bóng cũ của người đó).
  void say(String actorId, String text, {double duration = 2.4, PilotBubbleKind kind = PilotBubbleKind.speech}) =>
      _bubble(actorId, (_) => text, kind, duration);

  void _bubble(String actorId, TalkText text, PilotBubbleKind kind, double seconds) {
    bubbles.removeWhere((b) => b.actorId == actorId);
    bubbles.add(PilotBubble(actorId, text, kind, now + seconds, ++_bubbleSerial));
    _bubblesRev.value++;
  }

  void _expireBubbles() {
    if (bubbles.isEmpty) return;
    final before = bubbles.length;
    bubbles.removeWhere((b) => b.until <= now || actorById(b.actorId) == null);
    if (bubbles.length != before) _bubblesRev.value++;
  }

  // ---- Truy vấn cho lớp view ---------------------------------------------------------------------------------

  /// Điểm camera bám khi đang điều khiển (x, y = đỉnh đầu × 0,62, z); null nếu không điều khiển ai.
  ({double x, double y, double z})? followPoint() {
    final a = _pilot;
    if (a == null) return null;
    final b = chibiBounds(a.model, a.pose);
    return (x: a.pose.x, y: b.maxY * 0.62, z: a.pose.z);
  }

  /// Các điểm (x, y = đỉnh đầu × 0,62, z) của người đang nói trong khung thoại (nhân vật điều khiển + khách / khách B);
  /// rỗng nếu chưa mở khung thoại.
  List<({double x, double y, double z})> talkFramePoints() {
    final s = _session;
    if (s == null || s.approaching) return const [];
    return _pointsOf([_pilot?.id, s.speakerId, s.guestId, s.b]);
  }

  /// Các điểm của cặp khách sự kiện + nhân vật điều khiển; rỗng nếu không có sự kiện.
  List<({double x, double y, double z})> eventFramePoints() {
    final p = _pair;
    if (p == null) return const [];
    return _pointsOf([_pilot?.id, p.a.id, p.b.id]);
  }

  List<({double x, double y, double z})> _pointsOf(List<String?> ids) {
    final seen = <String>{};
    final out = <({double x, double y, double z})>[];
    for (final id in ids) {
      if (id == null || !seen.add(id)) continue;
      final a = actorById(id);
      if (a == null) continue;
      out.add((x: a.pose.x, y: chibiBounds(a.model, a.pose).maxY * 0.62, z: a.pose.z));
    }
    return out;
  }

  /// Nhân vật đang điều khiển ra vỉa hè (camera kéo yaw về |yaw| ≤ 80°).
  bool get onSidewalk => (_pilot?.pose.z ?? 0) > sidewalkZ;

  /// Điểm đặt mũi tên đích của nút A (đỉnh đầu người / đỉnh vật / tâm sự kiện); null nếu nút A mờ.
  ({double x, double y, double z})? targetPoint() {
    final d = decision;
    final id = d.targetId;
    if (!d.enabled || id == null) return null;
    switch (d.action) {
      case PilotAction.offerCake:
      case PilotAction.talk:
      case PilotAction.petMochi:
        final a = actorById(id);
        if (a == null) return null;
        final b = chibiBounds(a.model, a.pose);
        return (x: a.pose.x, y: b.maxY + 0.1, z: a.pose.z);
      case PilotAction.pickUp:
        final it = items.byId(id);
        if (it == null) return null;
        return (x: it.x, y: it.y + it.spec.radius * 2 + 0.05, z: it.z);
      case PilotAction.intervene:
        return (x: eventX, y: 1.4, z: eventZ);
      case PilotAction.placeOn:
      case PilotAction.putDown:
      case PilotAction.none:
        return null;
    }
  }

  /// Đặt lại mọi vật về chỗ ban đầu (nút debug "reset items").
  void resetItems() {
    for (final a in _actors) {
      a.carry = ChibiCarry.none;
    }
    _throwItem = null;
    items.reset();
    _decideNow();
  }
}

/// Quấn góc về (−π, π].
double _wrap(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}

/// Chuỗi hiển thị của [PilotNotice.reward]: "+n thiện cảm · +m xu" (bỏ phần bằng 0).
String pilotRewardText(AppLocalizations l, int hearts, int coins) {
  final parts = [
    if (hearts > 0) l.interactGoodwill(hearts),
    if (coins > 0) l.interactCoins(coins),
  ];
  return parts.join(' · ');
}
