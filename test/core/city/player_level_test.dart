import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';

void main() {
  test('xpToReach: cấp 1 = 0, tăng dần, kẹp ngoài biên', () {
    expect(PlayerLevel.xpToReach(1), 0);
    expect(PlayerLevel.xpToReach(2), 100);
    for (var l = 2; l <= PlayerLevel.maxLevel; l++) {
      expect(
        PlayerLevel.xpToReach(l),
        greaterThan(PlayerLevel.xpToReach(l - 1)),
        reason: 'cấp $l',
      );
    }
    expect(PlayerLevel.xpToReach(0), 0);
    expect(PlayerLevel.xpToReach(-5), 0);
    expect(
      PlayerLevel.xpToReach(99),
      PlayerLevel.xpToReach(PlayerLevel.maxLevel),
    );
  });

  test('levelForXp nhất quán với xpToReach', () {
    for (var l = 1; l <= PlayerLevel.maxLevel; l++) {
      final need = PlayerLevel.xpToReach(l);
      expect(PlayerLevel.levelForXp(need), l, reason: 'đúng ngưỡng $l');
      if (l > 1) {
        expect(PlayerLevel.levelForXp(need - 1), l - 1, reason: 'sát dưới $l');
      }
    }
  });

  test('levelForXp kẹp 1..30', () {
    expect(PlayerLevel.levelForXp(-100), 1);
    expect(PlayerLevel.levelForXp(0), 1);
    expect(PlayerLevel.levelForXp(99), 1);
    expect(PlayerLevel.levelForXp(100), 2);
    expect(PlayerLevel.levelForXp(100000000), 30);
  });

  test('levelForXp đơn điệu', () {
    var prev = 1;
    for (var xp = 0; xp < PlayerLevel.xpToReach(30) + 500; xp += 7) {
      final l = PlayerLevel.levelForXp(xp);
      expect(l, greaterThanOrEqualTo(prev));
      prev = l;
    }
  });

  test('progress', () {
    expect(PlayerLevel.progress(0), 0);
    expect(PlayerLevel.progress(50), closeTo(0.5, 1e-9));
    expect(PlayerLevel.progress(99), lessThan(1));
    expect(PlayerLevel.progress(100), 0);
    expect(PlayerLevel.progress(-10), 0);
    final max = PlayerLevel.xpToReach(PlayerLevel.maxLevel);
    expect(PlayerLevel.progress(max), 1);
    expect(PlayerLevel.progress(max + 9999), 1);
    for (var xp = 0; xp < max; xp += 13) {
      expect(PlayerLevel.progress(xp), inInclusiveRange(0.0, 1.0));
    }
  });
}
