/// Kinh tế chi nhánh (GĐ4 V3): tốc độ, trần két, giá nâng cấp và sản xuất tiền bằng mili-xu nguyên.
library;

import '../city/city_config.dart';

class ProduceResult {
  /// Két sau bước tính; phần gửi về ví; số ms đã dùng (nhỏ hơn `ms` khi két đầy); phần dư (đơn vị mili-xu·ms/3 600 000).
  final int tillMilli, depositMilli, usedMs, carry;

  const ProduceResult({
    required this.tillMilli,
    required this.depositMilli,
    required this.usedMs,
    required this.carry,
  });

  ProduceResult copyWith({int? tillMilli, int? depositMilli, int? usedMs, int? carry}) => ProduceResult(
    tillMilli: tillMilli ?? this.tillMilli,
    depositMilli: depositMilli ?? this.depositMilli,
    usedMs: usedMs ?? this.usedMs,
    carry: carry ?? this.carry,
  );

  Map<String, Object?> toJson() => {
    'tillMilli': tillMilli,
    'depositMilli': depositMilli,
    'usedMs': usedMs,
    'carry': carry,
  };

  @override
  bool operator ==(Object other) =>
      other is ProduceResult &&
      other.tillMilli == tillMilli &&
      other.depositMilli == depositMilli &&
      other.usedMs == usedMs &&
      other.carry == carry;

  @override
  int get hashCode => Object.hash(tillMilli, depositMilli, usedMs, carry);
}

abstract final class BranchEconomy {
  static const maxLevel = 5;
  static const tillTime = Duration(hours: 8);
  static const levelPct = [100, 125, 150, 175, 200];

  /// Lên cấp 2..5 = phân số × giá lô, làm tròn tới 500.
  static const upgradeCostFrac = [0.25, 0.40, 0.60, 0.85];

  /// Cấp Mai cần = `lot.requiresLevel` + giá trị này.
  static const upgradeLevelPlus = [0, 2, 5, 8];
  static const dismissRefundPct = 50, doubleMinPct = 50;

  static const _upgradeCostPct = [25, 40, 60, 85];
  static const _msPerHour = 3600000;

  static int slotsFor(int level) => level >= 3 ? 2 : 1;

  /// Giá lên cấp [toLevel] (2..5); 0 nếu ngoài khoảng.
  static int upgradeCost(LotDef lot, int toLevel) {
    if (toLevel < 2 || toLevel > maxLevel) return 0;
    // Tính bằng số nguyên để tránh sai số double; làm tròn nửa lên tới 500.
    return ((lot.price * _upgradeCostPct[toLevel - 2] + 25000) ~/ 50000) * 500;
  }

  /// Cấp Mai cần để lên cấp [toLevel] (2..5); 0 nếu ngoài khoảng.
  static int upgradeLevelReq(LotDef lot, int toLevel) {
    if (toLevel < 2 || toLevel > maxLevel) return 0;
    return lot.requiresLevel + upgradeLevelPlus[toLevel - 2];
  }

  /// base × levelPct × (100 + bonus) / 10 (mili-xu mỗi giờ).
  static int rateMilliPerHour(LotDef lot, int level, {int bonusPct = 0}) {
    final lv = level.clamp(1, maxLevel);
    return lot.baseIncome * levelPct[lv - 1] * (100 + bonusPct) ~/ 10;
  }

  static int ratePerHour(LotDef lot, int level, {int bonusPct = 0}) =>
      (rateMilliPerHour(lot, level, bonusPct: bonusPct) + 500) ~/ 1000;

  static int capMilli(LotDef lot, int level, {int bonusPct = 0}) =>
      rateMilliPerHour(lot, level, bonusPct: bonusPct) * 8;

  /// Sản xuất tiền trong [ms] mili-giây. Két nhận (100 − depositPct)%, ví nhận depositPct%; cả hai dừng khi két
  /// ≥ [capMilli]. [carry] giữ phần dư nên chia bước nào cũng ra cùng kết quả (lệch ≤ 1 xu).
  static ProduceResult produce({
    required int tillMilli,
    required int rateMilliPerHour,
    required int capMilli,
    int depositPct = 0,
    required int ms,
    int carry = 0,
  }) {
    final room = capMilli - tillMilli;
    if (room <= 0) {
      return ProduceResult(tillMilli: tillMilli, depositMilli: 0, usedMs: 0, carry: 0);
    }
    if (ms <= 0 || rateMilliPerHour <= 0) {
      return ProduceResult(tillMilli: tillMilli, depositMilli: 0, usedMs: ms < 0 ? 0 : ms, carry: carry);
    }
    final num = rateMilliPerHour * ms + carry;
    final total = num ~/ _msPerHour;
    final rest = num % _msPerHour;
    final deposit = total * depositPct ~/ 100;
    final toTill = total - deposit;
    if (toTill <= room) {
      return ProduceResult(tillMilli: tillMilli + toTill, depositMilli: deposit, usedMs: ms, carry: rest);
    }
    // Két đầy giữa bước: chỉ dùng phần thời gian đủ lấp chỗ trống.
    final used = (ms * room + toTill - 1) ~/ toTill;
    final dep = depositPct >= 100 ? 0 : room * depositPct ~/ (100 - depositPct);
    return ProduceResult(
      tillMilli: capMilli,
      depositMilli: dep,
      usedMs: used > ms ? ms : used,
      carry: 0,
    );
  }
}
