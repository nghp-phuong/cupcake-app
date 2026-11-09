/// Trạng thái chi nhánh và sổ chi nhánh trong save (GĐ4 V3).
library;

import 'package:flutter/foundation.dart';

import '../city/city_config.dart';
import '../city/city_day.dart';
import 'branch_economy.dart';
import 'staff.dart';

class BranchState {
  final String lotId;
  final int level;

  /// Tiền trong két (mili-xu).
  final int tillMilli;

  /// Mốc giờ máy (ms epoch UTC) lúc mua.
  final int boughtAt;

  /// Tổng xu đã thu từ chi nhánh.
  final int earned;

  /// Ngày (yyyy-MM-dd) đã dùng x2 quảng cáo; '' = chưa.
  final String adDate;

  const BranchState({
    required this.lotId,
    this.level = 1,
    this.tillMilli = 0,
    this.boughtAt = 0,
    this.earned = 0,
    this.adDate = '',
  });

  BranchState copyWith({
    String? lotId,
    int? level,
    int? tillMilli,
    int? boughtAt,
    int? earned,
    String? adDate,
  }) => BranchState(
    lotId: lotId ?? this.lotId,
    level: level ?? this.level,
    tillMilli: tillMilli ?? this.tillMilli,
    boughtAt: boughtAt ?? this.boughtAt,
    earned: earned ?? this.earned,
    adDate: adDate ?? this.adDate,
  );

  Map<String, Object?> toJson() => {
    'lv': level,
    'till': tillMilli,
    'bought': boughtAt,
    'earned': earned,
    'ad': adDate,
  };

  @override
  bool operator ==(Object other) =>
      other is BranchState &&
      other.lotId == lotId &&
      other.level == level &&
      other.tillMilli == tillMilli &&
      other.boughtAt == boughtAt &&
      other.earned == earned &&
      other.adDate == adDate;

  @override
  int get hashCode => Object.hash(lotId, level, tillMilli, boughtAt, earned, adDate);
}

class BranchBook {
  static const _maxInt = 9007199254740991;

  /// Mốc giờ máy (ms epoch UTC) đã tính tới; 0 = chưa đặt.
  final int clock;
  final Map<String, BranchState> lots;
  final List<StaffMember> staff;

  /// Lô và nhân viên lạ (từ bản mới hơn) giữ nguyên để ghi lại.
  final Map<String, Object?> extraLots;
  final List<Object?> extraStaff;

  BranchBook({
    this.clock = 0,
    Map<String, BranchState> lots = const {},
    List<StaffMember> staff = const [],
    Map<String, Object?> extraLots = const {},
    List<Object?> extraStaff = const [],
  }) : lots = Map.unmodifiable(lots),
       staff = List.unmodifiable(staff),
       extraLots = _freezeMap(extraLots),
       extraStaff = List<Object?>.unmodifiable(extraStaff.map(_freeze));

  /// Khoá `branches` của save: lô (gồm lô lạ) sắp theo id.
  Map<String, Object?> branchesJson() {
    final all = <String, Object?>{
      ...extraLots,
      for (final e in lots.entries) e.key: e.value.toJson(),
    };
    return {
      'clock': clock,
      'lots': {for (final id in all.keys.toList()..sort()) id: all[id]},
    };
  }

  List<Object?> staffJson() => [for (final m in staff) m.toJson(), ...extraStaff];

  /// Lô chi nhánh mà bản này biết (`baseIncome > 0` ở một quận của [CityConfig.alpha]).
  static bool _isBranchLot(String id) =>
      CityConfig.alpha.districts.any((d) => d.lots.any((l) => l.id == id && l.baseIncome > 0));

  /// Đọc khoá `branches` / `staff` của save (docs/v3/city-gd4-spec.md §2 "Save"). Không bao giờ ném.
  /// - Thiếu / null → mặc định. Không phải Map / List → mặc định, ghi `branches` / `staff` vào `bad`.
  /// - Mục con sai kiểu → mặc định của mục đó, ghi `branches.clock`, `branches.lots`, `branches.s1`, `branches.s1.lv`,
  ///   `staff.0` (vị trí), `staff.ami.since`…; số ngoài khoảng chỉ kẹp: `clock`/`bought`/`earned`/`till` [0, 2^53 − 1],
  ///   `lv` 1..5; `ad` không đúng dạng `yyyy-mm-dd` → `''`.
  /// - Lô lạ (không phải lô chi nhánh đã biết) giữ nguyên trong [extraLots]; nhân viên lạ (id lạ, hoặc ở lô lạ) giữ
  ///   nguyên trong [extraStaff].
  /// - Nhân viên ở lô chưa mua, trùng id, hoặc vượt số chỗ của lô → bỏ, ghi `staff.<id>`.
  static ({BranchBook book, List<String> bad}) decode(Object? branches, Object? staff) {
    final bad = <String>[];
    var clock = 0;
    final lots = <String, BranchState>{};
    final extraLots = <String, Object?>{};
    if (branches is Map) {
      clock = _int(bad, 'branches.clock', branches['clock'], 0, _maxInt);
      final raw = branches['lots'];
      if (raw is Map) {
        for (final e in raw.entries) {
          final id = '${e.key}';
          final v = e.value;
          if (!_isBranchLot(id)) {
            extraLots[id] = v;
            continue;
          }
          if (v is! Map) {
            bad.add('branches.$id');
            continue;
          }
          lots[id] = BranchState(
            lotId: id,
            level: _int(bad, 'branches.$id.lv', v['lv'], 1, BranchEconomy.maxLevel, def: 1),
            tillMilli: _int(bad, 'branches.$id.till', v['till'], 0, _maxInt),
            boughtAt: _int(bad, 'branches.$id.bought', v['bought'], 0, _maxInt),
            earned: _int(bad, 'branches.$id.earned', v['earned'], 0, _maxInt),
            adDate: _date(bad, 'branches.$id.ad', v['ad']),
          );
        }
      } else if (raw != null) {
        bad.add('branches.lots');
      }
    } else if (branches != null) {
      bad.add('branches');
    }

    final members = <StaffMember>[];
    final extraStaff = <Object?>[];
    if (staff is List) {
      for (final (i, e) in staff.indexed) {
        if (e is! Map || e['id'] is! String || e['lot'] is! String) {
          bad.add('staff.$i');
          continue;
        }
        final id = e['id'] as String, lot = e['lot'] as String;
        if (StaffRoster.byId(id) == null || extraLots.containsKey(lot)) {
          extraStaff.add(e);
          continue;
        }
        final at = lots[lot];
        if (at == null ||
            members.any((m) => m.id == id) ||
            members.where((m) => m.lotId == lot).length >= BranchEconomy.slotsFor(at.level)) {
          bad.add('staff.$id');
          continue;
        }
        members.add(StaffMember(id: id, lotId: lot, since: _int(bad, 'staff.$id.since', e['since'], 0, _maxInt)));
      }
    } else if (staff != null) {
      bad.add('staff');
    }
    return (
      book: BranchBook(clock: clock, lots: lots, staff: members, extraLots: extraLots, extraStaff: extraStaff),
      bad: bad,
    );
  }

  /// Thiếu / null → [def]; không phải số / NaN → [def] và ghi [path] vào [bad]; số (kể cả ±∞) → kẹp [min, max].
  static int _int(List<String> bad, String path, Object? v, int min, int max, {int def = 0}) {
    if (v == null) return def;
    if (v is! num || v.isNaN) {
      bad.add(path);
      return def;
    }
    if (v >= max) return max;
    if (v <= min) return min;
    return v.toInt();
  }

  static String _date(List<String> bad, String path, Object? v) {
    if (v == null) return '';
    if (v is! String) {
      bad.add(path);
      return '';
    }
    return isCityDateKey(v) ? v : '';
  }

  @override
  bool operator ==(Object other) =>
      other is BranchBook &&
      other.clock == clock &&
      mapEquals(other.lots, lots) &&
      listEquals(other.staff, staff) &&
      _jsonEquals(other.extraLots, extraLots) &&
      _jsonEquals(other.extraStaff, extraStaff);

  @override
  int get hashCode => Object.hash(
    clock,
    Object.hashAllUnordered(lots.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(staff),
    _jsonHash(extraLots),
    _jsonHash(extraStaff),
  );
}

Object? _freeze(Object? v) => switch (v) {
  Map() => _freezeMap(v),
  List() => List<Object?>.unmodifiable(v.map(_freeze)),
  _ => v,
};

Map<String, Object?> _freezeMap(Map v) => Map<String, Object?>.unmodifiable({
  for (final e in v.entries) '${e.key}': _freeze(e.value),
});

bool _jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _jsonHash(Object? v) => switch (v) {
  Map() => Object.hashAllUnordered(v.entries.map((e) => Object.hash(e.key, _jsonHash(e.value)))),
  List() => Object.hashAll(v.map(_jsonHash)),
  _ => v.hashCode,
};
