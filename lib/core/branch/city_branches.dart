/// Chi nhánh của Mai (GĐ4 V3, docs/v3/city-gd4-spec.md §2): lô đã mua, két, nhân viên, đồng hồ két.
///
/// - **Ghi** (`buy`, `upgrade`, `collect`, `applyDouble`, `hire`, `dismiss`, `resume`, `restore`): bù sản lượng theo
///   đồng hồ đơn điệu → trả phần quản lý gửi về vào ví → đổi trạng thái → `notifyListeners` đúng 1 lần (không đổi thì
///   không).
/// - **Đọc** (`view`, `fullLots`, `totalTill`): cũng bù sản lượng nhưng không notify và không đụng ví (gọi được trong
///   `build`); phần quản lý gửi về được cộng dồn, trả vào ví ở lần ghi kế tiếp hoặc ở [CityBranches.snapshot].
/// - Giờ máy lùi (`ClockAnomaly.behind`) → két tạm nghỉ: không cộng theo đồng hồ đơn điệu, mỗi lần bù chỉ xét lại giờ
///   máy, đuổi kịp mốc thì chạy tiếp.
library;

import 'package:flutter/foundation.dart';

import '../city/city_config.dart';
import '../city/city_day.dart';
import '../city/city_wallet.dart';
import 'branch_economy.dart';
import 'branch_state.dart';
import 'staff.dart';
import 'till_clock.dart';

class BranchView {
  final String lotId;
  final int branchNo, level, till, cap, ratePerHour, bonusPct, depositPct, slots;
  final Duration fullIn;
  final bool full;
  final int? nextCost, nextLevelReq, nextRatePerHour, nextCap;

  const BranchView({
    required this.lotId,
    required this.branchNo,
    required this.level,
    required this.till,
    required this.cap,
    required this.ratePerHour,
    this.bonusPct = 0,
    this.depositPct = 0,
    required this.slots,
    required this.fullIn,
    required this.full,
    this.nextCost,
    this.nextLevelReq,
    this.nextRatePerHour,
    this.nextCap,
  });

  BranchView copyWith({
    String? lotId,
    int? branchNo,
    int? level,
    int? till,
    int? cap,
    int? ratePerHour,
    int? bonusPct,
    int? depositPct,
    int? slots,
    Duration? fullIn,
    bool? full,
    int? nextCost,
    int? nextLevelReq,
    int? nextRatePerHour,
    int? nextCap,
  }) => BranchView(
    lotId: lotId ?? this.lotId,
    branchNo: branchNo ?? this.branchNo,
    level: level ?? this.level,
    till: till ?? this.till,
    cap: cap ?? this.cap,
    ratePerHour: ratePerHour ?? this.ratePerHour,
    bonusPct: bonusPct ?? this.bonusPct,
    depositPct: depositPct ?? this.depositPct,
    slots: slots ?? this.slots,
    fullIn: fullIn ?? this.fullIn,
    full: full ?? this.full,
    nextCost: nextCost ?? this.nextCost,
    nextLevelReq: nextLevelReq ?? this.nextLevelReq,
    nextRatePerHour: nextRatePerHour ?? this.nextRatePerHour,
    nextCap: nextCap ?? this.nextCap,
  );

  Map<String, Object?> toJson() => {
    'lotId': lotId,
    'branchNo': branchNo,
    'level': level,
    'till': till,
    'cap': cap,
    'ratePerHour': ratePerHour,
    'bonusPct': bonusPct,
    'depositPct': depositPct,
    'slots': slots,
    'fullInMs': fullIn.inMilliseconds,
    'full': full,
    'nextCost': nextCost,
    'nextLevelReq': nextLevelReq,
    'nextRatePerHour': nextRatePerHour,
    'nextCap': nextCap,
  };

  @override
  bool operator ==(Object other) =>
      other is BranchView &&
      other.lotId == lotId &&
      other.branchNo == branchNo &&
      other.level == level &&
      other.till == till &&
      other.cap == cap &&
      other.ratePerHour == ratePerHour &&
      other.bonusPct == bonusPct &&
      other.depositPct == depositPct &&
      other.slots == slots &&
      other.fullIn == fullIn &&
      other.full == full &&
      other.nextCost == nextCost &&
      other.nextLevelReq == nextLevelReq &&
      other.nextRatePerHour == nextRatePerHour &&
      other.nextCap == nextCap;

  @override
  int get hashCode => Object.hash(
    lotId,
    branchNo,
    level,
    till,
    cap,
    ratePerHour,
    bonusPct,
    depositPct,
    slots,
    fullIn,
    full,
    Object.hash(nextCost, nextLevelReq, nextRatePerHour, nextCap),
  );
}

class BranchAway {
  final Duration away;
  final int sold, deposited;
  final ClockAnomaly anomaly;

  const BranchAway({
    this.away = Duration.zero,
    this.sold = 0,
    this.deposited = 0,
    this.anomaly = ClockAnomaly.none,
  });

  bool get worthToast => away >= const Duration(minutes: 30) && sold + deposited > 0;

  BranchAway copyWith({Duration? away, int? sold, int? deposited, ClockAnomaly? anomaly}) => BranchAway(
    away: away ?? this.away,
    sold: sold ?? this.sold,
    deposited: deposited ?? this.deposited,
    anomaly: anomaly ?? this.anomaly,
  );

  Map<String, Object?> toJson() => {
    'awayMs': away.inMilliseconds,
    'sold': sold,
    'deposited': deposited,
    'anomaly': anomaly.name,
  };

  @override
  bool operator ==(Object other) =>
      other is BranchAway &&
      other.away == away &&
      other.sold == sold &&
      other.deposited == deposited &&
      other.anomaly == anomaly;

  @override
  int get hashCode => Object.hash(away, sold, deposited, anomaly);
}

enum BranchBuy { ok, notBranch, owned, levelTooLow, notEnoughCoins }

enum BranchUpgrade { ok, notOwned, maxLevel, levelTooLow, notEnoughCoins }

class BranchCollect {
  final int coins;
  final bool wasFull;

  const BranchCollect({this.coins = 0, this.wasFull = false});

  bool get ok => coins > 0;

  BranchCollect copyWith({int? coins, bool? wasFull}) =>
      BranchCollect(coins: coins ?? this.coins, wasFull: wasFull ?? this.wasFull);

  Map<String, Object?> toJson() => {'coins': coins, 'wasFull': wasFull};

  @override
  bool operator ==(Object other) => other is BranchCollect && other.coins == coins && other.wasFull == wasFull;

  @override
  int get hashCode => Object.hash(coins, wasFull);
}

enum StaffHire { ok, unknown, taken, notOwned, noSlot, levelTooLow, notEnoughCoins }

class StaffDismiss {
  final bool ok;
  final int collected, refund;

  const StaffDismiss({this.ok = false, this.collected = 0, this.refund = 0});

  StaffDismiss copyWith({bool? ok, int? collected, int? refund}) =>
      StaffDismiss(ok: ok ?? this.ok, collected: collected ?? this.collected, refund: refund ?? this.refund);

  Map<String, Object?> toJson() => {'ok': ok, 'collected': collected, 'refund': refund};

  @override
  bool operator ==(Object other) =>
      other is StaffDismiss && other.ok == ok && other.collected == collected && other.refund == refund;

  @override
  int get hashCode => Object.hash(ok, collected, refund);
}

class CityBranches extends ChangeNotifier {
  /// [clock]: giờ máy (mốc két, ngày lịch của x2). [mono]: đồng hồ đơn điệu trong phiên (mặc định [Stopwatch]; test
  /// truyền đồng hồ giả). [district]: quận có các lô chi nhánh (mặc định `bakery_street`).
  CityBranches({
    required CityWallet wallet,
    required DateTime Function() clock,
    Duration Function()? mono,
    DistrictDef? district,
  }) : _wallet = wallet,
       _clock = clock,
       _mono = mono ?? _stopwatch(),
       _district = district ?? CityConfig.alpha.district('bakery_street') {
    _monoAt = _mono();
  }

  static Duration Function() _stopwatch() {
    final s = Stopwatch()..start();
    return () => s.elapsed;
  }

  static const _maxInt = 9007199254740991;

  /// Một lần bù tối đa 30 ngày: két (kể cả khi quản lý gửi 25%) đầy sau ≤ 10,7 giờ nên kết quả không đổi, còn
  /// `rate × ms` luôn < 2^53 (chính xác trên web, không tràn trên máy).
  static const _maxRunMs = 30 * 24 * 3600000;

  final CityWallet _wallet;
  final DateTime Function() _clock;
  final Duration Function() _mono;
  final DistrictDef _district;

  /// Mốc két (ms epoch UTC) đã tính tới; 0 = chưa đặt.
  int _mark = 0;

  /// Số đọc của đồng hồ đơn điệu đã tính tới.
  late Duration _monoAt;
  final Map<String, BranchState> _lots = {};
  final List<StaffMember> _staff = [];
  Map<String, Object?> _extraLots = const {};
  List<Object?> _extraStaff = const [];

  /// Phần dư của `produce` theo lô (không lưu).
  final Map<String, int> _carry = {};

  /// Mili-xu quản lý gửi về chưa trả vào ví.
  int _depositMilli = 0;

  /// Lô → số xu của lần thu gần nhất nếu lần đó ≥ 50% trần (được x2 một lần).
  final Map<String, int> _doubleOffer = {};
  ClockAnomaly _anomaly = ClockAnomaly.none;
  BranchAway? _away;

  bool owns(String lotId) => _lots.containsKey(lotId);

  /// Lô đã mua, theo thứ tự lô trong quận.
  List<String> get owned => [
    for (final l in _district.lots)
      if (_lots.containsKey(l.id)) l.id,
  ];

  /// Số liệu một chi nhánh đã mua (null nếu chưa mua). Đọc: bù sản lượng, không notify.
  BranchView? view(String lotId) {
    if (!_lots.containsKey(lotId)) return null;
    _settle();
    final s = _lots[lotId]!;
    final def = _district.lot(lotId);
    final bonus = _bonusAt(lotId), deposit = _depositAt(lotId);
    final rate = BranchEconomy.rateMilliPerHour(def, s.level, bonusPct: bonus);
    final cap = BranchEconomy.capMilli(def, s.level, bonusPct: bonus);
    final full = s.tillMilli >= cap;
    final toTillPerHour = rate * (100 - deposit) ~/ 100;
    final fullInMs = full || toTillPerHour <= 0
        ? 0
        : ((cap - s.tillMilli) * 3600000 + toTillPerHour - 1) ~/ toTillPerHour;
    final next = s.level < BranchEconomy.maxLevel ? s.level + 1 : null;
    return BranchView(
      lotId: lotId,
      branchNo: _district.branchNumber(lotId),
      level: s.level,
      till: s.tillMilli ~/ 1000,
      cap: cap ~/ 1000,
      ratePerHour: BranchEconomy.ratePerHour(def, s.level, bonusPct: bonus),
      bonusPct: bonus,
      depositPct: deposit,
      slots: BranchEconomy.slotsFor(s.level),
      fullIn: Duration(milliseconds: fullInMs),
      full: full,
      nextCost: next == null ? null : BranchEconomy.upgradeCost(def, next),
      nextLevelReq: next == null ? null : BranchEconomy.upgradeLevelReq(def, next),
      nextRatePerHour: next == null ? null : BranchEconomy.ratePerHour(def, next, bonusPct: bonus),
      nextCap: next == null ? null : BranchEconomy.capMilli(def, next, bonusPct: bonus) ~/ 1000,
    );
  }

  /// Mọi nhân viên đang làm (thứ tự vào làm); chỉ đọc.
  List<StaffMember> get staff => List.unmodifiable(_staff);

  List<StaffMember> staffAt(String lotId) => List.unmodifiable(_staff.where((m) => m.lotId == lotId));

  /// Lô có két đầy. Đọc: bù sản lượng, không notify.
  Set<String> get fullLots {
    _settle();
    return {
      for (final id in _lots.keys)
        if (_lots[id]!.tillMilli >= _capAt(id)) id,
    };
  }

  /// Tổng xu thu được ngay ở mọi két (phần nguyên từng két). Đọc: bù sản lượng, không notify.
  int get totalTill {
    _settle();
    var sum = 0;
    for (final s in _lots.values) {
      sum += s.tillMilli ~/ 1000;
    }
    return sum;
  }

  /// Bất thường của giờ máy ở lần xét gần nhất; `behind` = két đang tạm nghỉ.
  ClockAnomaly get anomaly => _anomaly;

  BranchBuy buy(String lotId) {
    final def = _branchLot(lotId);
    if (def == null) return BranchBuy.notBranch;
    if (_lots.containsKey(lotId)) return BranchBuy.owned;
    if (_wallet.level < def.requiresLevel) return BranchBuy.levelTooLow;
    _settleAndPay();
    if (!_wallet.canAfford(def.price)) return BranchBuy.notEnoughCoins;
    final now = _wallMs();
    if (_lots.isEmpty || _mark <= 0) {
      // Lô đầu tiên: mốc két = giờ máy (khi chưa có lô, mốc cũ không còn ý nghĩa).
      _mark = now;
      _anomaly = ClockAnomaly.none;
    }
    _wallet.earn(coins: -def.price);
    _lots[lotId] = BranchState(lotId: lotId, boughtAt: now);
    notifyListeners();
    return BranchBuy.ok;
  }

  /// Lên một cấp: chỉ đổi `level` (két giữ nguyên; phần đã bán trước đó tính theo tốc độ cũ).
  BranchUpgrade upgrade(String lotId) {
    final s = _lots[lotId];
    if (s == null) return BranchUpgrade.notOwned;
    if (s.level >= BranchEconomy.maxLevel) return BranchUpgrade.maxLevel;
    final def = _district.lot(lotId);
    final to = s.level + 1;
    if (_wallet.level < BranchEconomy.upgradeLevelReq(def, to)) return BranchUpgrade.levelTooLow;
    _settleAndPay();
    final cost = BranchEconomy.upgradeCost(def, to);
    if (!_wallet.canAfford(cost)) return BranchUpgrade.notEnoughCoins;
    _wallet.earn(coins: -cost);
    _lots[lotId] = _lots[lotId]!.copyWith(level: to);
    notifyListeners();
    return BranchUpgrade.ok;
  }

  /// Thu phần nguyên xu trong két (giữ phần lẻ), cộng vào `earned`. Két < 1 xu → `coins = 0`, không đổi gì.
  BranchCollect collect(String lotId) {
    if (!_lots.containsKey(lotId)) return const BranchCollect();
    _settleAndPay();
    final s = _lots[lotId]!;
    final coins = s.tillMilli ~/ 1000;
    if (coins <= 0) return const BranchCollect();
    final cap = _capAt(lotId);
    _wallet.earn(coins: coins);
    _lots[lotId] = s.copyWith(tillMilli: s.tillMilli - coins * 1000, earned: _add(s.earned, coins));
    if (coins * 1000 * 100 >= cap * BranchEconomy.doubleMinPct) {
      _doubleOffer[lotId] = coins;
    } else {
      _doubleOffer.remove(lotId);
    }
    notifyListeners();
    return BranchCollect(coins: coins, wasFull: s.tillMilli >= cap);
  }

  /// Lần thu gần nhất của lô ≥ 50% trần và chưa x2, và hôm nay (ngày lịch của máy) lô chưa dùng x2.
  bool canDouble(String lotId) {
    final s = _lots[lotId];
    return s != null && (_doubleOffer[lotId] ?? 0) > 0 && s.adDate != cityDateKey(_clock());
  }

  /// Sau quảng cáo thưởng: cộng thêm đúng số xu của lần thu đó, đặt `adDate` = hôm nay. Trả số xu cộng thêm (0 nếu
  /// không được x2).
  int applyDouble(String lotId) {
    if (!canDouble(lotId)) return 0;
    _settleAndPay();
    final coins = _doubleOffer.remove(lotId)!;
    _wallet.earn(coins: coins);
    _lots[lotId] = _lots[lotId]!.copyWith(adDate: cityDateKey(_clock()));
    notifyListeners();
    return coins;
  }

  StaffHire hire(String staffId, String lotId) {
    final def = StaffRoster.byId(staffId);
    if (def == null) return StaffHire.unknown;
    if (_staff.any((m) => m.id == staffId)) return StaffHire.taken;
    final s = _lots[lotId];
    if (s == null) return StaffHire.notOwned;
    if (_staff.where((m) => m.lotId == lotId).length >= BranchEconomy.slotsFor(s.level)) return StaffHire.noSlot;
    if (_wallet.level < def.requiresLevel) return StaffHire.levelTooLow;
    _settleAndPay();
    if (!_wallet.canAfford(def.hireCost)) return StaffHire.notEnoughCoins;
    _wallet.earn(coins: -def.hireCost);
    _staff.add(StaffMember(id: staffId, lotId: lotId, since: _wallMs()));
    notifyListeners();
    return StaffHire.ok;
  }

  /// Cho nghỉ: thu hết phần nguyên xu trong két của lô vào ví (cộng `earned`), gỡ nhân viên, hoàn 50% phí thuê (làm
  /// tròn xuống).
  StaffDismiss dismiss(String staffId) {
    final i = _staff.indexWhere((m) => m.id == staffId);
    if (i < 0) return const StaffDismiss();
    _settleAndPay();
    final m = _staff[i];
    final s = _lots[m.lotId]!;
    final collected = s.tillMilli ~/ 1000;
    final refund = StaffRoster.byId(m.id)!.hireCost * BranchEconomy.dismissRefundPct ~/ 100;
    _wallet.earn(coins: collected + refund);
    _lots[m.lotId] = s.copyWith(tillMilli: s.tillMilli - collected * 1000, earned: _add(s.earned, collected));
    _staff.removeAt(i);
    notifyListeners();
    return StaffDismiss(ok: true, collected: collected, refund: refund);
  }

  /// Mở app / quay lại app: bù theo đồng hồ đơn điệu, rồi xét giờ máy ([TillClock.wall]), rồi đặt lại mốc của đồng
  /// hồ đơn điệu (không cộng hai lần). Kết quả cũng cộng dồn vào phần chờ [takeAway]. Chưa có lô → không đổi gì.
  BranchAway resume() {
    if (_lots.isEmpty) {
      _monoAt = _mono();
      return _keepAway(const BranchAway());
    }
    final inSession = _settle();
    final step = TillClock.wall(markMs: _mark, wallMs: _wallMs());
    _mark = step.markMs;
    _anomaly = step.anomaly;
    final offline = _produce(step.creditMs);
    _monoAt = _mono();
    final paid = _pay();
    notifyListeners();
    return _keepAway(
      BranchAway(
        away: Duration(milliseconds: inSession.ms + offline.ms),
        sold: (inSession.soldMilli + offline.soldMilli) ~/ 1000,
        deposited: paid,
        anomaly: step.anomaly,
      ),
    );
  }

  /// Kết quả các lần [resume] chưa lấy (cộng dồn; `anomaly` của lần gần nhất). Trả một lần rồi về null.
  BranchAway? takeAway() {
    final a = _away;
    _away = null;
    return a;
  }

  /// Bản chụp để ghi: bù sản lượng và trả phần quản lý gửi về vào ví trước (nên gọi trước khi đọc ví). Không notify
  /// (ví vẫn notify nếu có tiền gửi về).
  BranchBook snapshot() {
    _settleAndPay();
    return BranchBook(clock: _mark, lots: _lots, staff: _staff, extraLots: _extraLots, extraStaff: _extraStaff);
  }

  /// Nạp tại chỗ. Lô không thuộc quận này và nhân viên lạ (id lạ / ở lô lạ) chuyển sang phần giữ nguyên; nhân viên ở
  /// lô chưa mua, trùng id, vượt số chỗ bị bỏ; két kẹp [0, trần]. Notify một lần.
  void restore(BranchBook b) {
    _lots.clear();
    _staff.clear();
    _carry.clear();
    _doubleOffer.clear();
    final extraLots = <String, Object?>{...b.extraLots};
    for (final e in b.lots.entries) {
      if (_branchLot(e.key) == null) {
        extraLots[e.key] = e.value.toJson();
        continue;
      }
      _lots[e.key] = e.value.copyWith(
        lotId: e.key,
        level: e.value.level.clamp(1, BranchEconomy.maxLevel),
        tillMilli: e.value.tillMilli < 0 ? 0 : null,
      );
    }
    final extraStaff = <Object?>[...b.extraStaff];
    for (final m in b.staff) {
      if (StaffRoster.byId(m.id) == null || (!_lots.containsKey(m.lotId) && extraLots.containsKey(m.lotId))) {
        extraStaff.add(m.toJson());
        continue;
      }
      final s = _lots[m.lotId];
      if (s == null ||
          _staff.any((o) => o.id == m.id) ||
          _staff.where((o) => o.lotId == m.lotId).length >= BranchEconomy.slotsFor(s.level)) {
        continue;
      }
      _staff.add(m);
    }
    for (final id in _lots.keys.toList()) {
      final cap = _capAt(id);
      if (_lots[id]!.tillMilli > cap) _lots[id] = _lots[id]!.copyWith(tillMilli: cap);
    }
    _extraLots = extraLots;
    _extraStaff = extraStaff;
    _mark = b.clock < 0 ? 0 : b.clock;
    _monoAt = _mono();
    _depositMilli = 0;
    _anomaly = ClockAnomaly.none;
    _away = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- nội bộ

  LotDef? _branchLot(String lotId) {
    for (final l in _district.lots) {
      if (l.id == lotId && l.baseIncome > 0) return l;
    }
    return null;
  }

  int _bonusAt(String lotId) {
    var sum = 0;
    for (final m in _staff) {
      if (m.lotId == lotId) sum += StaffRoster.byId(m.id)!.bonusPct;
    }
    return sum;
  }

  int _depositAt(String lotId) {
    var sum = 0;
    for (final m in _staff) {
      if (m.lotId == lotId) sum += StaffRoster.byId(m.id)!.depositPct;
    }
    return sum;
  }

  int _capAt(String lotId) =>
      BranchEconomy.capMilli(_district.lot(lotId), _lots[lotId]!.level, bonusPct: _bonusAt(lotId));

  int _wallMs() => _clock().millisecondsSinceEpoch;

  static int _add(int a, int b) => (a + b).clamp(0, _maxInt);

  /// Bù sản lượng tới số đọc hiện tại của đồng hồ đơn điệu. Két tạm nghỉ (`behind`) → không cộng theo đồng hồ đơn
  /// điệu, chỉ xét lại giờ máy (đuổi kịp mốc thì cộng phần vượt và chạy tiếp).
  _Produced _settle() {
    final now = _mono();
    final delta = (now - _monoAt).inMilliseconds;
    if (delta <= 0) {
      if (delta < 0) _monoAt = now;
      return const _Produced();
    }
    // Chỉ tiến đúng số ms đã tính: gọi dày (mỗi khung hình) cũng không rơi mất phần lẻ dưới 1 ms.
    _monoAt += Duration(milliseconds: delta);
    if (_lots.isEmpty) return const _Produced();
    if (_anomaly == ClockAnomaly.behind) {
      final step = TillClock.wall(markMs: _mark, wallMs: _wallMs());
      _mark = step.markMs;
      _anomaly = step.anomaly;
      return _produce(step.creditMs);
    }
    final step = TillClock.mono(markMs: _mark, monoDeltaMs: delta);
    _mark = step.markMs;
    return _produce(step.creditMs);
  }

  void _settleAndPay() {
    _settle();
    _pay();
  }

  /// Trả phần nguyên xu quản lý gửi về vào ví (giữ phần lẻ); trả số xu đã trả.
  int _pay() {
    final coins = _depositMilli ~/ 1000;
    if (coins <= 0) return 0;
    _depositMilli -= coins * 1000;
    _wallet.earn(coins: coins);
    return coins;
  }

  /// Mọi lô bán trong [ms] mili-giây; phần gửi về cộng vào [_depositMilli].
  _Produced _produce(int ms) {
    if (ms <= 0) return const _Produced();
    final run = ms > _maxRunMs ? _maxRunMs : ms;
    var sold = 0, deposit = 0;
    for (final id in _lots.keys.toList()) {
      final s = _lots[id]!;
      final def = _district.lot(id);
      final bonus = _bonusAt(id);
      final r = BranchEconomy.produce(
        tillMilli: s.tillMilli,
        rateMilliPerHour: BranchEconomy.rateMilliPerHour(def, s.level, bonusPct: bonus),
        capMilli: BranchEconomy.capMilli(def, s.level, bonusPct: bonus),
        depositPct: _depositAt(id),
        ms: run,
        carry: _carry[id] ?? 0,
      );
      _carry[id] = r.carry;
      if (r.tillMilli != s.tillMilli) _lots[id] = s.copyWith(tillMilli: r.tillMilli);
      sold += r.tillMilli - s.tillMilli;
      deposit += r.depositMilli;
    }
    _depositMilli += deposit;
    return _Produced(ms: ms, soldMilli: sold);
  }

  BranchAway _keepAway(BranchAway a) {
    final old = _away;
    _away = old == null
        ? a
        : BranchAway(
            away: old.away + a.away,
            sold: old.sold + a.sold,
            deposited: old.deposited + a.deposited,
            anomaly: a.anomaly,
          );
    return a;
  }
}

/// Kết quả một lần bù: số ms đã tính và mili-xu vào két.
class _Produced {
  final int ms, soldMilli;

  const _Produced({this.ms = 0, this.soldMilli = 0});
}
