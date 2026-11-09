import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';

/// Thời gian giả cho két chi nhánh: giờ máy + đồng hồ đơn điệu.
class FakeTime {
  FakeTime([DateTime? start]) : wall = start ?? DateTime.utc(2026, 11, 5, 9);

  DateTime wall;
  Duration mono = Duration.zero;

  DateTime now() => wall;
  Duration monoNow() => mono;
  int get ms => wall.millisecondsSinceEpoch;

  /// App đang mở (hoặc ở nền mà tiến trình còn sống): cả hai đồng hồ cùng chạy.
  void play(Duration d) {
    wall = wall.add(d);
    mono += d;
  }

  /// App đóng / máy ngủ sâu: chỉ giờ máy chạy.
  void off(Duration d) => wall = wall.add(d);

  /// Người chơi chỉnh giờ máy (đồng hồ đơn điệu không đổi).
  void setWall(DateTime w) => wall = w;
}

/// Game với ví ở cấp [level] và [coins] xu, đồng hồ giả [t].
CityGame branchGame(FakeTime t, {int level = 15, int coins = 100000}) => CityGame(
  wallet: CityWallet(coins: coins, xp: PlayerLevel.xpToReach(level)),
  clock: t.now,
  mono: t.monoNow,
);

const hour = Duration(hours: 1);
const minute = Duration(minutes: 1);
