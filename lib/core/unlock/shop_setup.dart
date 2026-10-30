import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../level/level_data.dart';
import '../models/ids.dart';
import 'unlock_config.dart';

/// Cấu hình tiệm áp cho một lượt chơi — `GameState.shopSetup` tính từ mở rộng + thiết bị đã mua, `LevelSession`
/// nhận qua tham số `setup` (dev-game vẽ tiệm theo [owned] / [equipmentTiers]).
///
/// [ovens], [batchSize], [slotCapacity], [ovenSec], [patienceMult] là giá trị của tiệm; [applyTo] áp chúng **tương đối
/// so với [base]** (= `LevelDefaults` mặc định) để level có ghi đè thông số vẫn giữ đúng chênh lệch của nó.
@immutable
class ShopSetup {
  const ShopSetup({
    this.caseSlotsBonus = 0,
    this.ovens = 1,
    this.batchSize = 3,
    this.slotCapacity = 6,
    this.maxQueueBonus = 0,
    this.counterSpotsBonus = 0,
    this.tipPct = 0,
    this.spawnRatePct = 0,
    this.ovenSec = 7,
    this.patienceMult = 1.0,
    this.owned = const {},
    this.equipmentTiers = const {},
    this.staff = const [],
    this.recipePricePct = const {},
  });

  /// Tiệm gốc (chưa mua gì) — khớp `LevelDefaults()`.
  static const ShopSetup base = ShopSetup();

  /// Ô tủ thêm (cộng vào `LevelData.caseSlots` của tiệm gốc).
  final int caseSlotsBonus;
  final int ovens;
  final int batchSize;
  final int slotCapacity;
  final int maxQueueBonus;
  final int counterSpotsBonus;

  /// % tip cộng thêm (cộng với % trang trí, trần `Economy.tipBonusCapPct`).
  final int tipPct;

  /// Khách tới thường hơn chừng này %: khoảng cách sinh khách × [spawnIntervalMult].
  final int spawnRatePct;
  final double ovenSec;
  final double patienceMult;

  /// Id mục mở khoá đã mua (vd. `case_stand`, `oven_2`, `cafe_tables`).
  final Set<String> owned;

  /// Id thiết bị → cấp hiện tại (≥ 1).
  final Map<String, int> equipmentTiers;

  /// Nhân viên đã thuê **làm việc trong màn** (thu ngân, thợ bánh, phục vụ — không gồm quản lý; phục vụ chỉ có khi đã
  /// có `cafe_tables`), thứ tự cố định theo unlocks.json. `LevelSession` dựng `staff` theo đây; dev-game vẽ theo đây.
  final List<StaffMember> staff;

  /// Bí quyết của bà (GĐ8): món → % cộng vào giá bán (thiếu = 0). `LevelSession` nhân giá bán (cả đơn đặc biệt).
  final Map<RecipeId, int> recipePricePct;

  /// Hệ số giá bán của món [r] (1 = giá gốc).
  double priceMultOf(RecipeId r) => 1 + (recipePricePct[r] ?? 0) / 100;

  bool owns(String id) => owned.contains(id);

  /// Cấp thiết bị [id] (không có → 1).
  int tierOf(String id) => equipmentTiers[id] ?? 1;

  /// Cấp ảnh lò (1..5) để vẽ lò trong tiệm / trạm nướng: cấp cao hơn giữa lò nhanh và lò vùng vàng.
  int get ovenArtLevel =>
      math.max(tierOf(EquipmentIds.fastOven), tierOf(EquipmentIds.goldenOven)).clamp(1, 5);

  /// Số ô tủ của một level khi chơi với tiệm này.
  int caseSlotsFor(LevelData level) => math.max(1, level.caseSlots + caseSlotsBonus);

  /// Hệ số nhân khoảng cách sinh khách (1 = như gốc).
  double get spawnIntervalMult => 1 / (1 + math.max(-90, spawnRatePct) / 100);

  /// Thông số level [b] (đã áp ghi đè của level) khi chơi với tiệm này.
  LevelDefaults applyTo(LevelDefaults b) {
    if (this == base) return b;
    return LevelDefaults(
      ovenSec: math.max(0.1, b.ovenSec * ovenSec / base.ovenSec),
      ovens: math.max(1, b.ovens + ovens - base.ovens),
      batchSize: math.max(1, b.batchSize + batchSize - base.batchSize),
      slotCapacity: math.max(1, b.slotCapacity + slotCapacity - base.slotCapacity),
      comboWindowSec: b.comboWindowSec,
      specialPatienceSec: b.specialPatienceSec,
      specialRewardMult: b.specialRewardMult,
      maxQueue: math.max(1, b.maxQueue + maxQueueBonus),
      counterSpots: math.max(1, b.counterSpots + counterSpotsBonus),
      jitterPct: b.jitterPct,
      patienceMult: b.patienceMult * patienceMult,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShopSetup &&
      other.caseSlotsBonus == caseSlotsBonus &&
      other.ovens == ovens &&
      other.batchSize == batchSize &&
      other.slotCapacity == slotCapacity &&
      other.maxQueueBonus == maxQueueBonus &&
      other.counterSpotsBonus == counterSpotsBonus &&
      other.tipPct == tipPct &&
      other.spawnRatePct == spawnRatePct &&
      other.ovenSec == ovenSec &&
      other.patienceMult == patienceMult &&
      setEquals(other.owned, owned) &&
      mapEquals(other.equipmentTiers, equipmentTiers) &&
      listEquals(other.staff, staff) &&
      mapEquals(other.recipePricePct, recipePricePct);

  @override
  int get hashCode => Object.hash(caseSlotsBonus, ovens, batchSize, slotCapacity, maxQueueBonus, counterSpotsBonus,
      tipPct, spawnRatePct, ovenSec, patienceMult, owned.length, equipmentTiers.length, staff.length, recipePricePct.length);

  /// Bản sao với nhân viên [staff] (test / mô phỏng).
  ShopSetup withStaff(List<StaffMember> staff) => ShopSetup(
        caseSlotsBonus: caseSlotsBonus,
        ovens: ovens,
        batchSize: batchSize,
        slotCapacity: slotCapacity,
        maxQueueBonus: maxQueueBonus,
        counterSpotsBonus: counterSpotsBonus,
        tipPct: tipPct,
        spawnRatePct: spawnRatePct,
        ovenSec: ovenSec,
        patienceMult: patienceMult,
        owned: owned,
        equipmentTiers: equipmentTiers,
        staff: List.unmodifiable(staff),
        recipePricePct: recipePricePct,
      );

  @override
  String toString() => 'ShopSetup(case+$caseSlotsBonus ovens=$ovens batch=$batchSize slot=$slotCapacity '
      'ovenSec=$ovenSec patience×$patienceMult queue+$maxQueueBonus counter+$counterSpotsBonus tip+$tipPct% '
      'spawn+$spawnRatePct% owned=${owned.toList()..sort()} eq=$equipmentTiers staff=${[for (final m in staff) m.id]}'
      '${recipePricePct.isEmpty ? '' : ' secrets=${{for (final e in recipePricePct.entries) e.key.name: e.value}}'})';
}
