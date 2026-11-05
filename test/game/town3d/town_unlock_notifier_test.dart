import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/game/town3d/town_unlock_notifier.dart';

/// Toast "mở lô" khi lên cấp (town_unlock_notifier.dart, docs/v3/city-gd2-spec.md §5). Dart thuần. Phố Tiệm Bánh: lô
/// chi nhánh s1 (cấp 5), s3 (cấp 10), s4 (cấp 15).
void main() {
  final district = CityConfig.alpha.district('bakery_street');
  const delay = TownUnlockNotifier.delay;

  Duration ms(int v) => Duration(milliseconds: v);

  test('lên cấp mở lô: chờ hiệu ứng "Lên cấp" rồi mới báo, báo một lần, gọi onSeen', () {
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: 4, levelSeen: 4, onSeen: seen.add);
    expect(n.pending, isFalse);
    n.levelChanged(5, ms(1000));
    expect(n.pending, isTrue);
    expect(n.take(ms(1000) + delay - ms(1)), isEmpty);
    expect(seen, isEmpty);
    expect([for (final l in n.take(ms(1000) + delay)) l.id], ['s1']);
    expect(seen, [5]);
    expect(n.seen, 5);
    expect(n.pending, isFalse);
    expect(n.take(ms(99999)), isEmpty);
    expect(seen, [5]);
  });

  test('lên nhiều cấp trước khi kịp báo: gộp một toast, đếm từ lần lên cấp cuối', () {
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: 4, levelSeen: 4, onSeen: seen.add);
    n.levelChanged(6, ms(0));
    n.levelChanged(11, ms(1000));
    expect(n.take(ms(0) + delay), isEmpty, reason: 'lần lên cấp sau dời giờ báo');
    expect([for (final l in n.take(ms(1000) + delay)) l.id], ['s1', 's3']);
    expect(seen, [11]);
  });

  test('lên cấp không mở lô nào: dời mốc ngay, không báo', () {
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: 1, levelSeen: 1, onSeen: seen.add);
    n.levelChanged(2, ms(0));
    expect(n.pending, isFalse);
    expect(seen, [2]);
    n.levelChanged(4, ms(10));
    expect(seen, [2, 4]);
    expect(n.take(ms(10) + delay), isEmpty);
    // Mốc 4 → lên 5 vẫn báo s1.
    n.levelChanged(5, ms(20));
    expect(n.take(ms(20) + delay).map((l) => l.id), ['s1']);
  });

  test('báo bù: phố vừa hiện mà cấp > mốc thì báo ngay, không chờ', () {
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: 12, levelSeen: 3, onSeen: seen.add);
    expect(n.pending, isTrue);
    expect(n.seen, 3, reason: 'có lô chưa báo: giữ mốc');
    expect(n.take(Duration.zero).map((l) => l.id), ['s1', 's3']);
    expect(seen, [12]);
  });

  test('cấp giảm (xoá dữ liệu): đặt lại mốc, không báo, huỷ toast đang chờ', () {
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: 4, levelSeen: 4, onSeen: seen.add);
    n.levelChanged(7, ms(0));
    expect(n.pending, isTrue);
    n.levelChanged(1, ms(100));
    expect(n.pending, isFalse);
    expect(n.seen, 1);
    expect(seen, [1]);
    expect(n.take(ms(100) + delay * 10), isEmpty);
    // Lên lại cấp 5 → báo lại s1.
    n.levelChanged(5, ms(200));
    expect(n.take(ms(200) + delay).map((l) => l.id), ['s1']);
    expect(seen, [1, 5]);
  });

  test('cấp giảm nhưng vẫn trên mốc: giữ phần chưa báo', () {
    final n = TownUnlockNotifier(district, level: 3, levelSeen: 3);
    n.levelChanged(12, ms(0));
    n.levelChanged(9, ms(50));
    expect(n.take(ms(0) + delay).map((l) => l.id), ['s1']);
    expect(n.seen, 9);
  });

  test('tạo mới: cấp < mốc (hoặc không lô nào chờ) → chuẩn hoá mốc nhưng không gọi onSeen', () {
    final seen = <int>[];
    final down = TownUnlockNotifier(district, level: 2, levelSeen: 9, onSeen: seen.add);
    expect(down.seen, 2);
    expect(down.pending, isFalse);
    final none = TownUnlockNotifier(district, level: 4, levelSeen: 1, onSeen: seen.add);
    expect(none.seen, 4);
    expect(none.pending, isFalse);
    expect(seen, isEmpty);
  });

  test('nối với ví thật: ăn qua mốc cấp 5 (xp 790 → 800+)', () {
    final w = CityWallet(xp: 790);
    expect(w.level, 4);
    final seen = <int>[];
    final n = TownUnlockNotifier(district, level: w.level, levelSeen: w.level, onSeen: seen.add);
    w.addListener(() => n.levelChanged(w.level, ms(500)));
    w.addXp(PlayerLevel.xpToReach(5) - 790);
    expect(w.level, 5);
    expect(n.take(ms(500) + delay).map((l) => l.id), ['s1']);
    expect(seen, [5]);
    // Xoá dữ liệu: ví đặt lại tại chỗ → cấp 1, mốc 1, không báo.
    w.restore();
    expect(n.seen, 1);
    expect(n.pending, isFalse);
    expect(seen, [5, 1]);
  });
}
