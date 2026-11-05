import 'dart:math' as math;

import 'shop3d_items.dart';

/// Luật chọn nút thao tác (A / B) khi điều khiển nhân vật và các hồi chiêu (V3, docs/v3/interaction-spec.md mục
/// 2.2). Hàm thuần: đầu vào là ảnh chụp trạng thái, đầu ra là hành động + id đích. Không đụng engine, không đọc
/// đồng hồ (thời gian truyền vào).

enum PilotRole {
  mai,
  nora,

  /// Bảo, Theo, Ami, Hạnh…: bỏ qua nhặt / đặt / mời bánh, không có nút Ném.
  other;

  /// Từ id chibi: `mai`, `mai_fest` → mai; `staff_nora`, `staff_nora_fest` → nora.
  static PilotRole ofId(String id) {
    if (id == 'mai' || id.startsWith('mai_')) return PilotRole.mai;
    if (id == 'nora' || id.contains('nora')) return PilotRole.nora;
    return PilotRole.other;
  }

  /// Nhặt / ném / mời bánh được (Q4: chỉ Mai và Nora).
  bool get canHandle => this != PilotRole.other;
}

/// Hành động của nút A, theo thứ tự ưu tiên của bảng 8 dòng.
enum PilotAction {
  /// 1. Can ngăn (chỉ Mai, trong tầm sự kiện).
  intervene,

  /// 2. Mời bánh.
  offerCake,

  /// 3. Đặt lên mặt bàn / quầy.
  placeOn,

  /// 4. Đặt xuống sàn.
  putDown,

  /// 5. Nhặt.
  pickUp,

  /// 6. Nói chuyện với khách.
  talk,

  /// 7. Vuốt ve Mochi.
  petMochi,

  /// 8. Không có việc: nút mờ.
  none,
}

class PilotDecision {
  const PilotDecision(this.action, [this.targetId]);

  static const none = PilotDecision(PilotAction.none);

  final PilotAction action;

  /// Id đích: khách (offerCake, talk), vật (pickUp), mặt đặt (placeOn), `mochi` (petMochi), id sự kiện (intervene).
  final String? targetId;

  bool get enabled => action != PilotAction.none;

  @override
  bool operator ==(Object other) =>
      other is PilotDecision && other.action == action && other.targetId == targetId;

  @override
  int get hashCode => Object.hash(action, targetId);

  @override
  String toString() => 'PilotDecision($action, $targetId)';
}

/// Khách (hoặc người) có thể là đích: vị trí và có đang đi không.
class PilotGuest {
  const PilotGuest(this.id, this.x, this.z, {this.walking = false});

  final String id;
  final double x, z;
  final bool walking;
}

/// Sự kiện gây gổ đang diễn ra. [canIntervene] = đang ở trạng thái cãi nhau và chưa ai can.
class PilotEventInfo {
  const PilotEventInfo(this.id, this.x, this.z, {required this.canIntervene});

  final String id;
  final double x, z;
  final bool canIntervene;
}

/// Ảnh chụp trạng thái tại một khung.
class PilotSnapshot {
  const PilotSnapshot({
    required this.role,
    required this.x,
    required this.z,
    this.held,
    this.guests = const [],
    this.items = const [],
    this.mochiX,
    this.mochiZ,
    this.event,
    this.placeSurfaceId,
  });

  final PilotRole role;
  final double x, z;

  /// Vật đang cầm (null = tay trống).
  final ShopItem? held;

  /// Khách thường (không gồm Mochi), kể cả đang đi.
  final List<PilotGuest> guests;

  /// Mọi vật tương tác (chỉ vật nằm yên và lấy được mới tính).
  final List<ShopItem> items;

  /// Vị trí Mochi (null = không có Mochi trong cảnh).
  final double? mochiX, mochiZ;

  final PilotEventInfo? event;

  /// Mặt đặt được mà nhân vật đang hướng vào cách ≤ 0,6 m ([ItemBoard.findPlaceTarget]); null = không có.
  final String? placeSurfaceId;
}

abstract final class PilotRules {
  static const double interveneRange = 1.6;
  static const double offerRange = 2.0;
  static const double pickRange = 0.9;
  static const double talkRange = 2.2;
  static const double petRange = 1.0;
  static const double waveRange = 3.0;

  static double _dist(double ax, double az, double bx, double bz) {
    final dx = ax - bx, dz = az - bz;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Khách không đang đi, gần nhất, trong [range]; null nếu không có.
  static PilotGuest? nearestGuest(PilotSnapshot s, double range) {
    PilotGuest? best;
    var bestD = double.infinity;
    for (final g in s.guests) {
      if (g.walking) continue;
      final d = _dist(s.x, s.z, g.x, g.z);
      if (d <= range && d < bestD) {
        best = g;
        bestD = d;
      }
    }
    return best;
  }

  /// Bảng nút A: dòng đầu tiên thoả điều kiện.
  static PilotDecision decideA(PilotSnapshot s) {
    final held = s.held;
    final handler = s.role.canHandle;

    // 1. Can ngăn: chỉ Mai, có sự kiện cãi nhau, cách tâm ≤ 1,6 m.
    final ev = s.event;
    if (s.role == PilotRole.mai && ev != null && ev.canIntervene && _dist(s.x, s.z, ev.x, ev.z) <= interveneRange) {
      return PilotDecision(PilotAction.intervene, ev.id);
    }
    // 2. Mời bánh: cầm hộp bánh, có khách không đang đi cách ≤ 2,0 m.
    if (handler && held != null && held.kind == ItemKind.cakeBox) {
      final g = nearestGuest(s, offerRange);
      if (g != null) return PilotDecision(PilotAction.offerCake, g.id);
    }
    // 3. Đặt lên: đang cầm đồ, hướng vào mặt đặt được.
    if (handler && held != null && s.placeSurfaceId != null) {
      return PilotDecision(PilotAction.placeOn, s.placeSurfaceId);
    }
    // 4. Đặt xuống.
    if (handler && held != null) return PilotDecision(PilotAction.putDown, held.id);
    // 5. Nhặt: tay trống, là Mai / Nora, có vật cách ≤ 0,9 m.
    if (handler && held == null) {
      ShopItem? best;
      var bestD = double.infinity;
      for (final it in s.items) {
        if (!it.reachableFrom(s.x, s.z, reach: pickRange)) continue;
        final d = _dist(s.x, s.z, it.x, it.z);
        if (d < bestD) {
          best = it;
          bestD = d;
        }
      }
      if (best != null) return PilotDecision(PilotAction.pickUp, best.id);
    }
    // 6. Nói chuyện: khách không đang đi cách ≤ 2,2 m.
    final talkTo = nearestGuest(s, talkRange);
    if (talkTo != null) return PilotDecision(PilotAction.talk, talkTo.id);
    // 7. Vuốt ve Mochi: cách ≤ 1,0 m, tay trống.
    final mx = s.mochiX, mz = s.mochiZ;
    if (held == null && mx != null && mz != null && _dist(s.x, s.z, mx, mz) <= petRange) {
      return const PilotDecision(PilotAction.petMochi, 'mochi');
    }
    // 8. Không có việc.
    return PilotDecision.none;
  }

  /// Nút B "Ném" hiện khi Mai / Nora đang cầm vật ném được (cuộn len).
  static bool throwVisible(PilotRole role, ShopItem? held) => role.canHandle && held != null && held.spec.throwable;

  /// Bấm Q / B khi đang cầm [held]: `ok` ném được; `cakeNotThrowable` → "Bánh phải mời tận tay chứ!"; còn lại không làm
  /// gì.
  static ThrowCheck checkThrow(PilotRole role, ShopItem? held) {
    if (!role.canHandle || held == null) return ThrowCheck.nothing;
    if (held.kind == ItemKind.cakeBox) return ThrowCheck.cakeNotThrowable;
    return held.spec.throwable ? ThrowCheck.ok : ThrowCheck.nothing;
  }

  /// Hệ số tốc độ khi đang cầm [held] (bao bột 0,7×) và có chạy được không.
  static double speedFactor(ShopItem? held) => held?.spec.speedFactor ?? 1.0;

  static bool canRun(ShopItem? held) => held?.spec.canRun ?? true;
}

enum ThrowCheck { ok, cakeNotThrowable, nothing }

enum OfferResult {
  /// Nhận: khách nhảy vui, "Cảm ơn nha!", +1♥ +5 xu, hộp biến mất rồi 8 s sau hiện lại.
  thanks,

  /// Mỗi khách nhận tối đa 1 lần / 60 s: "Mình no rồi, cảm ơn nha!".
  full,
}

class WaveOutcome {
  const WaveOutcome(this.reacting, this.firstTimeGuests);

  /// Khách vẫy lại (`react`): không đang đi, trong 3 m.
  final List<String> reacting;

  /// Trong số đó, khách lần đầu được vẫy trong phiên (+1♥ mỗi người).
  final List<String> firstTimeGuests;

  int get hearts => firstTimeGuests.length;
}

/// Hồi chiêu và thưởng "lần đầu" trong một phiên. Thời gian [now] là giây, đồng hồ chạy liên tục.
class PilotCooldowns {
  PilotCooldowns({this.offerCooldown = 60, this.waveCooldown = 8});

  final double offerCooldown;
  final double waveCooldown;

  /// Thưởng mời bánh.
  static const int offerHearts = 1, offerCoins = 5;

  final Map<String, double> _lastOffer = {};
  final Set<String> _waved = {};
  double _lastWave = -1e9;
  bool _petted = false;

  /// Mời bánh [guestId]: lần đầu / sau 60 s → [OfferResult.thanks] (và ghi nhận); trong 60 s → [OfferResult.full].
  OfferResult offer(String guestId, double now) {
    final last = _lastOffer[guestId];
    if (last != null && now - last < offerCooldown) return OfferResult.full;
    _lastOffer[guestId] = now;
    return OfferResult.thanks;
  }

  /// Vẫy chào từ (x, z). null nếu còn hồi chiêu 8 s; ngược lại danh sách khách vẫy lại (không đang đi, ≤ 3 m) và
  /// khách lần đầu (+1♥).
  WaveOutcome? wave(double now, double x, double z, List<PilotGuest> guests) {
    if (now - _lastWave < waveCooldown) return null;
    _lastWave = now;
    final reacting = <String>[], first = <String>[];
    for (final g in guests) {
      if (g.walking) continue;
      final dx = g.x - x, dz = g.z - z;
      if (math.sqrt(dx * dx + dz * dz) > PilotRules.waveRange) continue;
      reacting.add(g.id);
      if (_waved.add(g.id)) first.add(g.id);
    }
    return WaveOutcome(reacting, first);
  }

  bool waveReady(double now) => now - _lastWave >= waveCooldown;

  /// Vuốt ve Mochi: +1♥ ở lần đầu mỗi phiên (trả true đúng một lần).
  bool pet() {
    if (_petted) return false;
    _petted = true;
    return true;
  }

  void reset() {
    _lastOffer.clear();
    _waved.clear();
    _lastWave = -1e9;
    _petted = false;
  }
}
