/// Một cấp lò nướng (`Economy.ovenTiers`, index 0 = cấp 1). `cost` / `requiredShopLevel` là bản sao giá và level phải
/// qua của thiết bị `goldenOven` trong unlocks.json (bảng dự phòng khi unlocks.json không có lò; tên trường giữ từ V1).
class OvenTier {
  const OvenTier({
    required this.level,
    required this.cost,
    required this.requiredShopLevel,
    required this.perfectHalfWidth,
    required this.okHalfWidth,
  });

  final int level;
  final int cost;
  /// Level phải qua (0 = có sẵn) — không còn là "cấp tiệm".
  final int requiredShopLevel;
  final double perfectHalfWidth;
  final double okHalfWidth;
}

/// Một cấp dụng cụ (`Economy.toolTiers`, index 0 = cấp 1). `value` là thông số dụng cụ ảnh hưởng; `cost` /
/// `requiredShopLevel` như [OvenTier].
class ToolTier {
  const ToolTier({required this.level, required this.cost, required this.requiredShopLevel, required this.value});

  final int level;
  final int cost;
  final int requiredShopLevel;
  final double value;
}
