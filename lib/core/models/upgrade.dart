/// Một cấp lò nướng (`Economy.ovenTiers`, index 0 = cấp 1).
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
  final int requiredShopLevel;
  final double perfectHalfWidth;
  final double okHalfWidth;
}

/// Một cấp dụng cụ (`Economy.toolTiers`, index 0 = cấp 1). `value` là thông số dụng cụ ảnh hưởng.
class ToolTier {
  const ToolTier({required this.level, required this.cost, required this.requiredShopLevel, required this.value});

  final int level;
  final int cost;
  final int requiredShopLevel;
  final double value;
}
