import '../models/ids.dart';
import '../staff/staff.dart';

export '../staff/staff.dart';

/// Loại mục mở khoá trong `unlocks.json`. Mua được: [expansion] (có hiệu ứng hỗ trợ) và [staff] (GĐ4, có dữ liệu ở
/// mục `staff`); các loại khác hiện "Sắp có".
enum UnlockKind {
  /// Mở rộng tiệm (có hiệu ứng `effect`, dev-game vẽ trong cảnh tiệm).
  expansion,

  /// Nhân viên (GĐ4): thông số ở `UnlockConfig.staff` cùng id.
  staff,

  /// Nâng cấp nhân viên (`staff_training`, chương 5 — chưa có).
  staffUpgrade,

  /// Bộ trang trí đặc biệt (chương 5).
  decorSet,
}

/// Khoá hiệu ứng của mục mở khoá (`effect` trong unlocks.json). Mọi hiệu ứng cộng dồn, riêng [patienceMult] nhân dồn.
abstract final class UnlockEffects {
  /// Thêm ô tủ kính.
  static const caseSlots = 'caseSlots';

  /// Thêm lò.
  static const ovens = 'ovens';

  /// Nhân kiên nhẫn khách vãng lai (vd. 1.15).
  static const patienceMult = 'patienceMult';

  /// Thêm chỗ trong hàng (quầy + chờ).
  static const maxQueue = 'maxQueue';

  /// Thêm chỗ đứng ở quầy.
  static const counterSpots = 'counterSpots';

  /// % tip cộng thêm (cộng với % của đồ trang trí).
  static const tipPct = 'tipPct';

  /// Khách tới thường hơn chừng này % (khoảng cách sinh khách chia cho 1 + pct/100).
  static const spawnRatePct = 'spawnRatePct';

  /// Thêm khu chuẩn bị (chương 3) — đọc được nhưng GĐ3 chưa áp.
  static const prepSlots = 'prepSlots';

  /// Hiệu ứng GĐ3 áp vào `ShopSetup`.
  static const supported = {caseSlots, ovens, patienceMult, maxQueue, counterSpots, tipPct, spawnRatePct};

  /// Hiệu ứng đã đặt tên cho chương sau: loader chấp nhận, `ShopSetup` bỏ qua.
  static const reserved = {prepSlots};

  static const all = {...supported, ...reserved};
}

/// Id các mục mở khoá mà code dùng tới (dev-game vẽ theo `ShopSetup.owned`).
abstract final class UnlockIds {
  static const caseStand = 'case_stand';
  static const oven2 = 'oven_2';
  static const cafeTables = 'cafe_tables';
  static const kitchen2 = 'kitchen_2';
  static const garden = 'garden';
  static const floor2 = 'floor_2';
}

/// Id thiết bị có cấp (`equipment` trong unlocks.json). Lò/dụng cụ V1 giữ đúng tên cũ (`ToolId.name`).
abstract final class EquipmentIds {
  /// `ovenSec` (giây nướng một mẻ).
  static const fastOven = 'fastOven';

  /// `batchSize` (bánh mỗi mẻ).
  static const bigTray = 'bigTray';

  /// `slotCapacity` (bánh mỗi ô tủ).
  static const wideCase = 'wideCase';

  /// Lò V1: `value` = nửa bề rộng vùng nướng hoàn hảo (vùng "được" = value + 0.10).
  static const goldenOven = 'goldenOven';

  /// Dụng cụ V1 (`value` như `Economy.toolTiers`).
  static String tool(ToolId t) => t.name;

  /// Thiết bị code biết hiệu ứng.
  static final known = {fastOven, bigTray, wideCase, goldenOven, for (final t in ToolId.values) t.name};
}

/// Khoá chung cho "mở khoá mới" (`LevelProgressDelta.newUnlocks`, `GameState.unseenUnlocks`, `markUnlocksSeen`):
/// mục mở khoá dùng nguyên id (`case_stand`), cấp thiết bị dùng `eq:<id>:<cấp>` (`eq:fastOven:2`).
abstract final class UnlockKeys {
  static const _eq = 'eq:';

  static String equipment(String id, int tier) => '$_eq$id:$tier';

  static bool isEquipment(String key) => key.startsWith(_eq);

  /// `eq:<id>:<cấp>` → (id, cấp); khoá khác → null.
  static ({String id, int tier})? parseEquipment(String key) {
    if (!key.startsWith(_eq)) return null;
    final rest = key.substring(_eq.length);
    final i = rest.lastIndexOf(':');
    if (i <= 0) return null;
    final tier = int.tryParse(rest.substring(i + 1));
    return tier == null ? null : (id: rest.substring(0, i), tier: tier);
  }
}

String _text(Map<String, String> m, String lang) => m[lang] ?? m['en'] ?? '';

String? _artPath(String art) => art.isEmpty ? null : 'assets/art/$art.webp';

/// Một mục mở khoá (bất biến, đọc từ unlocks.json). "Khả dụng" khi đã qua [level], rồi mua bằng [price] xu
/// (+ [gemPrice] kim cương nếu > 0).
class UnlockData {
  const UnlockData({
    required this.id,
    required this.chapter,
    required this.level,
    required this.kind,
    required this.price,
    this.gemPrice = 0,
    this.effect = const {},
    this.art = '',
    required this.names,
    required this.descs,
  });

  final String id;
  final int chapter;

  /// Phải qua level này (`highestCompletedLevel ≥ level`) mới mua được.
  final int level;
  final UnlockKind kind;
  final int price;

  /// 0 = không cần kim cương.
  final int gemPrice;

  /// Khoá thuộc [UnlockEffects.all] → giá trị.
  final Map<String, num> effect;

  /// Ảnh `nhóm/tên` dưới `assets/art/` (vd. `level/case_stand`); rỗng = chưa có ảnh.
  final String art;

  /// {"en": "...", "vi": "..."}.
  final Map<String, String> names;
  final Map<String, String> descs;

  String name(String lang) => _text(names, lang);
  String desc(String lang) => _text(descs, lang);

  /// `assets/art/<art>.webp`; null nếu chưa có ảnh.
  String? get artPath => _artPath(art);

  /// "Sắp có" (chưa bán): [UnlockKind.staffUpgrade], [UnlockKind.decorSet], và mở rộng không có hiệu ứng nào thuộc
  /// [UnlockEffects.supported] (vd. `kitchen_2` chỉ có `prepSlots` của chương sau) để không bán thứ vô tác dụng.
  /// Nhân viên (GĐ4) mua được; nhân viên thiếu dữ liệu `staff` thì `GameState.unlockState` vẫn coi là "Sắp có".
  bool get comingSoon => switch (kind) {
        UnlockKind.expansion => !effect.keys.any(UnlockEffects.supported.contains),
        UnlockKind.staff => false,
        UnlockKind.staffUpgrade || UnlockKind.decorSet => true,
      };
}

/// Một bậc "Bí quyết của bà" (GĐ8): giá bán món +[pricePct]%, giá xu = `round50(giá món × costMult)`.
class RecipeSecretTier {
  const RecipeSecretTier({required this.pricePct, required this.costMult});

  /// % cộng vào giá bán món (tính từ giá gốc, không cộng dồn các bậc).
  final int pricePct;

  /// Giá xu của bậc = giá món × hệ số này (làm tròn 50).
  final int costMult;
}

/// "Bí quyết của bà" (GĐ8, mục `kind: "recipeSecrets"` trong unlocks.json): mở khi đã qua [level]; mỗi món mua lần
/// lượt các bậc [tiers] trong Sổ công thức. Không phải mục mua ở màn Nâng cấp (không nằm trong `UnlockConfig.unlocks`).
class RecipeSecretsData {
  const RecipeSecretsData({
    required this.id,
    required this.chapter,
    required this.level,
    required this.tiers,
    required this.names,
    required this.descs,
  });

  final String id;
  final int chapter;

  /// Phải qua level này (`highestCompletedLevel ≥ level`) mới mua được.
  final int level;

  /// Bậc 1..N theo thứ tự; ít nhất 1 phần tử.
  final List<RecipeSecretTier> tiers;
  final Map<String, String> names;
  final Map<String, String> descs;

  int get maxTier => tiers.length;

  String name(String lang) => _text(names, lang);
  String desc(String lang) => _text(descs, lang);
}

/// Một cấp thiết bị. Cấp 1 (`tiers[0]`) có sẵn: `level` 0, `price` 0.
class EquipmentTier {
  const EquipmentTier({required this.level, required this.price, required this.value});

  /// Phải qua level này mới mua được cấp này.
  final int level;
  final int price;

  /// Thông số của cấp (giây lò, số bánh, sức chứa ô, nửa bề rộng vùng vàng…).
  final num value;
}

/// Thiết bị có cấp (lò nhanh, khay lớn, tủ rộng, lò vùng vàng và dụng cụ V1).
class EquipmentData {
  const EquipmentData({required this.id, this.art = '', required this.names, required this.descs, required this.tiers});

  final String id;

  /// Như [UnlockData.art].
  final String art;
  final Map<String, String> names;
  final Map<String, String> descs;

  /// `tiers[0]` = cấp 1 có sẵn; ít nhất 1 phần tử.
  final List<EquipmentTier> tiers;

  String name(String lang) => _text(names, lang);
  String desc(String lang) => _text(descs, lang);
  String? get artPath => _artPath(art);

  int get maxTier => tiers.length;

  /// Cấp [tier] (1..[maxTier], ngoài khoảng thì kẹp lại).
  EquipmentTier tier(int tier) => tiers[tier.clamp(1, tiers.length) - 1];
}

/// Toàn bộ unlocks.json.
class UnlockConfig {
  UnlockConfig({
    this.version = 1,
    required List<UnlockData> unlocks,
    required this.equipment,
    this.staff = const [],
    this.recipeSecrets,
  })  : unlocks = _byLevel(unlocks),
        _unlocks = {for (final u in unlocks) u.id: u},
        _equipment = {for (final e in equipment) e.id: e},
        _staff = {for (final s in staff) s.id: s};

  /// Không có mục nào (nạp unlocks.json thất bại): không có mở rộng / nhân viên; lò/dụng cụ V1 vẫn nâng được theo
  /// bảng dự phòng trong `Economy`.
  factory UnlockConfig.empty() => UnlockConfig(version: 0, unlocks: const [], equipment: const []);

  final int version;

  /// Theo level tăng dần (cùng level giữ thứ tự trong file).
  final List<UnlockData> unlocks;
  final List<EquipmentData> equipment;

  /// Nhân viên (mục `staff`), theo thứ tự trong file — cũng là thứ tự `ShopSetup.staff`.
  final List<StaffData> staff;

  /// Bí quyết của bà (GĐ8); null = không có (tính năng khoá).
  final RecipeSecretsData? recipeSecrets;
  final Map<String, UnlockData> _unlocks;
  final Map<String, EquipmentData> _equipment;
  final Map<String, StaffData> _staff;

  bool get isEmpty => unlocks.isEmpty && equipment.isEmpty && staff.isEmpty;

  UnlockData? unlock(String id) => _unlocks[id];
  EquipmentData? equipmentById(String id) => _equipment[id];

  /// Dữ liệu nhân viên (id = id mục mở khoá); null nếu không có.
  StaffData? staffById(String id) => _staff[id];

  /// Mục mở khoá của một chương (theo level).
  List<UnlockData> unlocksInChapter(int chapter) => [
        for (final u in unlocks)
          if (u.chapter == chapter) u,
      ];

  static List<UnlockData> _byLevel(List<UnlockData> list) {
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])]
      ..sort((a, b) => a.$2.level != b.$2.level ? a.$2.level.compareTo(b.$2.level) : a.$1.compareTo(b.$1));
    return List.unmodifiable([for (final e in indexed) e.$2]);
  }
}
