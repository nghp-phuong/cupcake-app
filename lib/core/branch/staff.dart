/// Nhân viên chi nhánh (GĐ4 V3): bảng 6 người và bản ghi người đang làm.
library;

enum StaffRole { server, baker, manager }

class StaffDef {
  final String id, nameKey;
  final StaffRole role;

  /// Phí thuê một lần (xu); cho nghỉ hoàn 50%.
  final int hireCost, requiresLevel;

  /// Cộng % doanh thu chi nhánh.
  final int bonusPct;

  /// % tiền bán gửi thẳng về ví (quản lý).
  final int depositPct;

  const StaffDef({
    required this.id,
    required this.nameKey,
    required this.role,
    required this.hireCost,
    required this.requiresLevel,
    this.bonusPct = 0,
    this.depositPct = 0,
  });
}

abstract final class StaffRoster {
  static const List<StaffDef> all = [
    StaffDef(
      id: 'biscuit',
      nameKey: 'charBiscuit',
      role: StaffRole.server,
      hireCost: 1500,
      requiresLevel: 5,
      bonusPct: 10,
    ),
    StaffDef(
      id: 'nutmeg',
      nameKey: 'charNutmeg',
      role: StaffRole.server,
      hireCost: 1500,
      requiresLevel: 5,
      bonusPct: 10,
    ),
    StaffDef(
      id: 'ami',
      nameKey: 'charAmi',
      role: StaffRole.baker,
      hireCost: 3500,
      requiresLevel: 8,
      bonusPct: 20,
    ),
    StaffDef(
      id: 'hanh',
      nameKey: 'charHanh',
      role: StaffRole.manager,
      hireCost: 6000,
      requiresLevel: 10,
      depositPct: 25,
    ),
    StaffDef(
      id: 'cocoa',
      nameKey: 'charCocoa',
      role: StaffRole.baker,
      hireCost: 3500,
      requiresLevel: 12,
      bonusPct: 20,
    ),
    StaffDef(
      id: 'maple',
      nameKey: 'charMaple',
      role: StaffRole.baker,
      hireCost: 3500,
      requiresLevel: 16,
      bonusPct: 20,
    ),
  ];

  static StaffDef? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}

class StaffMember {
  final String id, lotId;

  /// Mốc giờ máy (ms epoch UTC) lúc vào làm.
  final int since;

  const StaffMember({required this.id, required this.lotId, required this.since});

  StaffMember copyWith({String? id, String? lotId, int? since}) =>
      StaffMember(id: id ?? this.id, lotId: lotId ?? this.lotId, since: since ?? this.since);

  Map<String, Object?> toJson() => {'id': id, 'lot': lotId, 'since': since};

  @override
  bool operator ==(Object other) =>
      other is StaffMember && other.id == id && other.lotId == lotId && other.since == since;

  @override
  int get hashCode => Object.hash(id, lotId, since);
}
