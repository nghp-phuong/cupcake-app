import 'dart:math' as math;

import '../level/level_data.dart';

/// Vật phẩm hỗ trợ trước màn (GĐ6 §1). Tên chốt — dùng `.name` làm khoá lưu (`boosters` trong bản lưu) và id trong
/// `monetization.json`. Thêm giá trị mới ở CUỐI.
enum BoosterId {
  /// Bắt đầu với tủ đầy: mỗi ô một món trong menu, đủ sức chứa, bánh [BoosterEffects.fullCaseStars]★ (menu nhiều món
  /// hơn số ô → chừa một ô trống, xem `LevelSession`).
  fullCase,

  /// Kiên nhẫn mọi khách vãng lai × [BoosterEffects.patienceMult] cả màn.
  patience,

  /// `ovenSec` × [BoosterEffects.ovenSecMult] cả màn (bếp nhanh; đơn đặc biệt 6 trạm không đổi): kim chạy nhanh gấp đôi
  /// tới mép vùng "được", từ đó chạy như thường — vùng vàng / hoàn hảo / lúc cháy tính theo giây không đổi
  /// (`LevelSession`).
  ovenBoost,
}

/// Cách trả cho một vật phẩm của lượt chơi (`GameState.boosterPaymentFor` / `boosterPlan`).
/// Thêm giá trị mới ở CUỐI.
enum BoosterPayment {
  /// Lấy từ kho (`GameState.boosterCount` > 0).
  inventory,

  /// Trả `BoosterData.gemPrice` kim cương.
  gems,

  /// Miễn phí nhờ xem quảng cáo (`AdPlacement.booster`, một vật phẩm mỗi lượt) — chỉ có trong `boosterPlan`.
  ad,
}

/// Hiệu ứng trong màn (cố định trong code; `monetization.json` chỉ ghi giá / ảnh / tên).
abstract final class BoosterEffects {
  /// Sao của bánh xếp sẵn khi dùng [BoosterId.fullCase].
  static const fullCaseStars = 4;

  /// Hệ số kiên nhẫn khách vãng lai ([BoosterId.patience]).
  static const patienceMult = 1.3;

  /// Hệ số giây lò của bếp nhanh ([BoosterId.ovenBoost]).
  static const ovenSecMult = 0.5;

  /// Vật phẩm mở từ level này (L1–L3 đang hướng dẫn). Khi tới level này (đã qua level liền trước) nhận
  /// [introGift] ×1 vào kho một lần.
  static const minLevel = 4;
  static const introGift = BoosterId.patience;

  /// Mỗi loại tối đa 1 cho một lượt; tối đa mọi loại.
  static int get maxPerPlay => BoosterId.values.length;

  /// Thông số level [t] (đã áp level + tiệm) khi chơi với [boosters]. Không có vật phẩm → trả nguyên [t].
  static LevelDefaults applyTo(LevelDefaults t, Set<BoosterId> boosters) {
    final patience = boosters.contains(BoosterId.patience);
    final oven = boosters.contains(BoosterId.ovenBoost);
    if (!patience && !oven) return t;
    return LevelDefaults(
      ovenSec: oven ? math.max(0.1, t.ovenSec * ovenSecMult) : t.ovenSec,
      ovens: t.ovens,
      batchSize: t.batchSize,
      slotCapacity: t.slotCapacity,
      comboWindowSec: t.comboWindowSec,
      specialPatienceSec: t.specialPatienceSec,
      specialRewardMult: t.specialRewardMult,
      maxQueue: t.maxQueue,
      counterSpots: t.counterSpots,
      jitterPct: t.jitterPct,
      patienceMult: patience ? t.patienceMult * patienceMult : t.patienceMult,
    );
  }
}

/// Một vật phẩm hỗ trợ (bất biến, đọc từ `monetization.json` mục `boosters`).
class BoosterData {
  const BoosterData({
    required this.id,
    this.art = '',
    required this.gemPrice,
    this.names = const {},
    this.descs = const {},
  });

  final BoosterId id;

  /// Ảnh `nhóm/tên` dưới `assets/art/` (vd. `level/booster_patience`); rỗng = chưa có ảnh.
  final String art;

  /// Giá kim cương khi kho hết (≥ 1).
  final int gemPrice;

  /// {"en": "...", "vi": "..."}; rỗng ở bản dự phòng [fallback] (UI dùng chuỗi riêng nếu cần).
  final Map<String, String> names;
  final Map<String, String> descs;

  String name(String lang) => names[lang] ?? names['en'] ?? '';
  String desc(String lang) => descs[lang] ?? descs['en'] ?? '';

  /// `assets/art/<art>.webp`; null nếu chưa có ảnh.
  String? get artPath => art.isEmpty ? null : 'assets/art/$art.webp';

  /// Bản dự phòng khi không nạp được `monetization.json` (giá/ảnh là bản sao của file — test kiểm khớp).
  static const List<BoosterData> fallback = [
    BoosterData(id: BoosterId.fullCase, art: 'level/booster_fullcase', gemPrice: 8),
    BoosterData(id: BoosterId.patience, art: 'level/booster_patience', gemPrice: 6),
    BoosterData(id: BoosterId.ovenBoost, art: 'level/booster_oven', gemPrice: 8),
  ];
}
