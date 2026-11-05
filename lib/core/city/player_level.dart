/// Cấp của Mai (1..30) theo tổng XP.
library;

import 'dart:math' as math;

class PlayerLevel {
  static const int maxLevel = 30;

  /// Tổng XP để đạt cấp [level] (kẹp 1..30); cấp 1 = 0. Công thức 100*(l-1)^1.5.
  static int xpToReach(int level) {
    final l = level.clamp(1, maxLevel);
    return (100 * math.pow(l - 1, 1.5)).round();
  }

  /// Cấp ứng với [xp], kẹp 1..30.
  static int levelForXp(int xp) {
    var level = 1;
    while (level < maxLevel && xp >= xpToReach(level + 1)) {
      level++;
    }
    return level;
  }

  /// Tiến độ 0..1 trong cấp hiện tại; ở cấp tối đa → 1.
  static double progress(int xp) {
    final level = levelForXp(xp);
    if (level >= maxLevel) return 1;
    final from = xpToReach(level);
    final to = xpToReach(level + 1);
    return ((xp - from) / (to - from)).clamp(0.0, 1.0);
  }
}
