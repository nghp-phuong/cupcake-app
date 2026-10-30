import '../catalog.dart';
import '../models/ids.dart';
import 'booster.dart';
import 'season.dart';

/// Loại gói IAP. Thêm giá trị mới ở CUỐI.
enum IapKind {
  /// Tiêu hao: mua lại được (gói kim cương, gói xu V1).
  consumable,

  /// Một lần: mua rồi giữ mãi (`GameState.ownedIap`), khôi phục được (Restore).
  oneTime,

  /// Theo mùa: mở hàng thưởng cao cấp của thẻ mùa đang diễn ra (`GameState.seasonPremium`), đổi mùa thì mua lại.
  season,
}

/// Một gói IAP (giả lập): giá hiển thị cố định (không dịch), loại, nội dung trao ([reward]; gói có quyền đặc biệt —
/// bỏ quảng cáo, trang phục, thẻ mùa, bộ trang trí V1 — do `GameState.grantIap` xử lý thêm).
class IapProduct {
  const IapProduct(
    this.id,
    this.displayPrice, {
    required this.kind,
    this.reward = Reward.none,
    this.art = '',
    this.names = const {},
    this.descs = const {},
  });

  final IapProductId id;

  /// Chuỗi cố định, không dịch (vd. `$1.99`).
  final String displayPrice;
  final IapKind kind;

  /// Xu / kim cương / vật phẩm trao khi mua.
  final Reward reward;

  /// Ảnh `nhóm/tên` dưới `assets/art/` (vd. `items/gem_pouch`); rỗng = chưa có ảnh.
  final String art;

  /// {"en": "...", "vi": "..."} từ `monetization.json`; rỗng ở bản dự phòng / gói V1 ẩn (UI dùng `iapName`).
  final Map<String, String> names;
  final Map<String, String> descs;

  bool get consumable => kind == IapKind.consumable;

  String name(String lang) => names[lang] ?? names['en'] ?? '';
  String desc(String lang) => descs[lang] ?? descs['en'] ?? '';
  String? get artPath => art.isEmpty ? null : 'assets/art/$art.webp';

  @override
  String toString() => 'IapProduct(${id.name} $displayPrice ${kind.name} $reward)';
}

/// Danh mục IAP trong code: gói V2 (bản sao giá/loại/nội dung của `monetization.json` — test kiểm khớp, dùng khi không
/// nạp được file) và gói V1 ẩn khỏi cửa hàng V2 (vẫn trao được, giữ quyền sở hữu cũ).
abstract final class IapCatalog {
  /// Gói hiện ở cửa hàng V2, theo thứ tự hiển thị.
  static const List<IapProduct> v2 = [
    IapProduct(IapProductId.gemsS, r'$0.99', kind: IapKind.consumable, reward: Reward(gems: 80)),
    IapProduct(IapProductId.gemsM, r'$4.99', kind: IapKind.consumable, reward: Reward(gems: 450)),
    IapProduct(IapProductId.gemsL, r'$9.99', kind: IapKind.consumable, reward: Reward(gems: 1000)),
    IapProduct(
      IapProductId.starterPack,
      r'$1.99',
      kind: IapKind.oneTime,
      reward: Reward(
        coins: 8000,
        gems: 120,
        boosters: {BoosterId.fullCase: 3, BoosterId.patience: 3, BoosterId.ovenBoost: 3},
      ),
    ),
    IapProduct(IapProductId.removeAds, r'$3.99', kind: IapKind.oneTime),
    IapProduct(IapProductId.staffOutfits, r'$2.99', kind: IapKind.oneTime),
    IapProduct(IapProductId.seasonPass, r'$4.99', kind: IapKind.season),
  ];

  /// Gói V1 (ẩn ở V2).
  static final List<IapProduct> legacy = [
    for (final (id, price) in const [
      (IapProductId.pantryS, r'$0.99'),
      (IapProductId.pantryM, r'$2.99'),
      (IapProductId.pantryL, r'$6.99'),
    ])
      IapProduct(id, price, kind: IapKind.consumable, reward: Reward(coins: Catalog.iapCoins[id] ?? 0)),
    const IapProduct(IapProductId.decorSetSeaside, r'$2.99', kind: IapKind.oneTime),
  ];

  /// Gói V1 ẩn khỏi cửa hàng V2.
  static const hidden = {IapProductId.pantryS, IapProductId.pantryM, IapProductId.pantryL, IapProductId.decorSetSeaside};

  /// Gói [id] trong code (V2 trước, rồi V1).
  static IapProduct product(IapProductId id) =>
      v2.where((p) => p.id == id).firstOrNull ?? legacy.firstWhere((p) => p.id == id);
}

/// Toàn bộ `monetization.json`: vật phẩm hỗ trợ, thẻ mùa, gói IAP của cửa hàng V2.
class MonetizationConfig {
  MonetizationConfig({
    this.version = 1,
    required List<BoosterData> boosters,
    this.season,
    this.previousSeasons = const [],
    this.seasonInvalid = false,
    required List<IapProduct> products,
  })  : boosters = List.unmodifiable(boosters),
        products = List.unmodifiable(products),
        _boosters = {for (final b in boosters) b.id: b},
        _products = {for (final p in products) p.id: p};

  /// Không nạp được file: vật phẩm theo [BoosterData.fallback], không có thẻ mùa, gói IAP theo [IapCatalog.v2].
  factory MonetizationConfig.empty() =>
      MonetizationConfig(version: 0, boosters: BoosterData.fallback, products: IapCatalog.v2);

  final int version;

  /// Theo thứ tự trong file (thứ tự hiện ở thẻ Sẵn sàng).
  final List<BoosterData> boosters;

  /// Mùa hiện tại; null = không có thẻ mùa.
  final SeasonData? season;

  /// Các mùa trước (`previousSeasons`): dữ liệu bậc để tự nhận thưởng còn chờ khi người chơi mở app sau khi đã đổi mùa.
  final List<SeasonData> previousSeasons;

  /// Loader khoan dung đã bỏ `season` hoặc một mục `previousSeasons` vì hỏng: dữ liệu mùa trong file không đáng tin →
  /// `GameState` không đặt lại phần mùa của bản lưu khi không tìm thấy mùa cũ.
  final bool seasonInvalid;

  /// Gói của cửa hàng V2, theo thứ tự trong file.
  final List<IapProduct> products;

  final Map<BoosterId, BoosterData> _boosters;
  final Map<IapProductId, IapProduct> _products;

  bool get isEmpty => version == 0;

  /// Dữ liệu vật phẩm; thiếu trong file → bản dự phòng.
  BoosterData booster(BoosterId id) =>
      _boosters[id] ?? BoosterData.fallback.firstWhere((b) => b.id == id);

  /// Gói [id]: trong file, thiếu → danh mục code ([IapCatalog.product], gồm gói V1 ẩn).
  IapProduct product(IapProductId id) => _products[id] ?? IapCatalog.product(id);

  /// Mùa có id [id] (hiện tại hoặc trước đó); null nếu không biết.
  SeasonData? seasonById(String id) {
    if (season?.id == id) return season;
    for (final s in previousSeasons) {
      if (s.id == id) return s;
    }
    return null;
  }
}
