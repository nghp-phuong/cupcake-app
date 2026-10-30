import 'package:flutter/foundation.dart';

/// Vai trò nhân viên (V2 GĐ4). Mỗi vai trò đọc hai chỉ số [StaffStat] theo nghĩa riêng (xem [StaffData]).
enum StaffRole {
  /// Bán cho khách đứng quầy.
  cashier,

  /// Dây chuyền nướng riêng (mỗi thợ một làn), cho mẻ vào tủ.
  baker,

  /// Bán cho khách đang chờ trong hàng (chưa tới quầy); cần `cafe_tables`.
  waiter,

  /// Không làm trong màn: thu nhập khi vắng nhà.
  manager,
}

/// Hai chỉ số nâng được của nhân viên (cấp 1..`maxLevel`).
enum StaffStat { speed, skill }

/// Id nhân viên (= id mục mở khoá `kind: staff` trong unlocks.json).
abstract final class StaffIds {
  static const cashier = 'staff_cashier';
  static const baker = 'staff_baker';
  static const waiter = 'staff_waiter';
  static const baker2 = 'staff_baker_2';
  static const manager = 'staff_manager';

  /// Mục `staffUpgrade` (chương 5, sau): nâng trần cấp.
  static const training = 'staff_training';
}

/// Khoá tham số riêng của vai trò (`params` trong mục `staff` của unlocks.json). Thiếu → giá trị mặc định ở đây.
abstract final class StaffParams {
  /// Quản lý: vắng ít hơn chừng này phút thì không tính.
  static const minAwayMin = 'minAwayMin';
  static const defaultMinAwayMin = 10;

  /// Quản lý: thu nhập một level dùng khi chưa có lượt chơi nào để lấy trung bình.
  static const fallbackIncome = 'fallbackIncome';
  static const defaultFallbackIncome = 2000;

  static const all = {minAwayMin, fallbackIncome};
}

String _text(Map<String, String> m, String lang) => m[lang] ?? m['en'] ?? '';

/// Một nhân viên trong unlocks.json (mục `staff`). Thuê bằng `GameState.buyUnlock(id)`; giá thuê = `price` của mục
/// mở khoá cùng id. Hai chỉ số cấp 1..[maxLevel]; `speedValues[k-1]` / `skillValues[k-1]` là thông số ở cấp k,
/// `speedPrices[k-2]` / `skillPrices[k-2]` là giá nâng lên cấp k (k = 2..[maxLevel]).
///
/// Nghĩa thông số theo vai trò:
/// | vai trò | tốc độ | tay nghề |
/// |---|---|---|
/// | cashier | giây mỗi lượt bán | % tip cộng thêm trên lượt nó bán |
/// | baker | giây mỗi mẻ | sao trung bình của mẻ (1..5) |
/// | waiter | giây mỗi lượt bán | % kiên nhẫn trong hàng giảm chậm hơn |
/// | manager | tỉ lệ xu/giờ vắng so với xu TB một level | trần giờ vắng được tính |
@immutable
class StaffData {
  const StaffData({
    required this.id,
    required this.character,
    required this.role,
    required this.names,
    required this.bios,
    required this.speedValues,
    required this.skillValues,
    required this.speedPrices,
    required this.skillPrices,
    this.requires,
    this.params = const {},
  });

  /// = id mục mở khoá (`staff_cashier`, …).
  final String id;

  /// id ảnh nhân vật: `assets/characters/<character>_<neutral|smile>.webp`.
  final String character;
  final StaffRole role;

  /// {"en": "...", "vi": "..."}.
  final Map<String, String> names;
  final Map<String, String> bios;
  final List<num> speedValues;
  final List<num> skillValues;
  final List<int> speedPrices;
  final List<int> skillPrices;

  /// Id mục mở khoá phải có trước khi thuê (vd. phục vụ cần `cafe_tables`); null = không cần.
  final String? requires;

  /// Tham số riêng của vai trò ([StaffParams]).
  final Map<String, num> params;

  String name(String lang) => _text(names, lang);
  String bio(String lang) => _text(bios, lang);

  /// Cấp tối đa của mỗi chỉ số (= số giá trị).
  int get maxLevel => speedValues.length;

  List<num> values(StaffStat stat) => stat == StaffStat.speed ? speedValues : skillValues;
  List<int> prices(StaffStat stat) => stat == StaffStat.speed ? speedPrices : skillPrices;

  /// Thông số của [stat] ở [level] (ngoài 1..[maxLevel] thì kẹp lại).
  num value(StaffStat stat, int level) {
    final v = values(stat);
    return v[level.clamp(1, v.length) - 1];
  }

  /// Giá nâng [stat] lên [level] (2..[maxLevel]); ngoài khoảng → null.
  int? priceTo(StaffStat stat, int level) {
    final p = prices(stat);
    final i = level - 2;
    return i < 0 || i >= p.length ? null : p[i];
  }

  num param(String key, num fallback) => params[key] ?? fallback;

  @override
  String toString() => 'StaffData($id ${role.name} $character)';
}

/// Nhân viên đã thuê, chụp lúc dựng `ShopSetup` (bất biến): cấp chỉ số + thông số đã tra ([speedValue],
/// [skillValue]) để `LevelSession` dùng thẳng. [lane]: thứ tự trong cùng vai trò (thợ bánh làn 0, 1).
@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.role,
    required this.character,
    this.speed = 1,
    this.skill = 1,
    required this.speedValue,
    required this.skillValue,
    this.lane = 0,
  });

  factory StaffMember.of(StaffData d, {int speed = 1, int skill = 1, int lane = 0}) => StaffMember(
        id: d.id,
        role: d.role,
        character: d.character,
        speed: speed.clamp(1, d.maxLevel),
        skill: skill.clamp(1, d.maxLevel),
        speedValue: d.value(StaffStat.speed, speed).toDouble(),
        skillValue: d.value(StaffStat.skill, skill).toDouble(),
        lane: lane,
      );

  final String id;
  final StaffRole role;
  final String character;

  /// Cấp tốc độ / tay nghề (≥ 1).
  final int speed;
  final int skill;

  /// Thông số của cấp hiện tại (nghĩa theo vai trò, xem [StaffData]).
  final double speedValue;
  final double skillValue;
  final int lane;

  int level(StaffStat stat) => stat == StaffStat.speed ? speed : skill;

  @override
  bool operator ==(Object other) =>
      other is StaffMember &&
      other.id == id &&
      other.role == role &&
      other.character == character &&
      other.speed == speed &&
      other.skill == skill &&
      other.speedValue == speedValue &&
      other.skillValue == skillValue &&
      other.lane == lane;

  @override
  int get hashCode => Object.hash(id, role, character, speed, skill, speedValue, skillValue, lane);

  @override
  String toString() => 'StaffMember($id ${role.name} speed=$speed skill=$skill)';
}

/// Thu nhập khi vắng nhà đang chờ nhận (`GameState.pendingOffline`).
@immutable
class OfflineEarnings {
  const OfflineEarnings({required this.away, required this.counted, required this.coins, required this.capHours});

  /// Tổng thời gian vắng (chưa nhận).
  final Duration away;

  /// Phần được tính (đã cắt theo trần [capHours]). `counted < away` → UI ghi "đã cắt theo trần".
  final Duration counted;

  /// Xu nhận khi bấm "Nhận" (x2 nếu xem quảng cáo).
  final int coins;
  final int capHours;

  bool get capped => counted < away;

  @override
  bool operator ==(Object other) =>
      other is OfflineEarnings &&
      other.away == away &&
      other.counted == counted &&
      other.coins == coins &&
      other.capHours == capHours;

  @override
  int get hashCode => Object.hash(away, counted, coins, capHours);

  @override
  String toString() => 'OfflineEarnings(away=$away counted=$counted coins=$coins cap=${capHours}h)';
}
