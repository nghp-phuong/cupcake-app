import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/debug_params.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

void main() {
  test('none / query rỗng: không đụng gì', () {
    for (final p in [
      CityDebugParams.none,
      CityDebugParams.fromQuery(const {}),
    ]) {
      expect(p.memorySave, isFalse);
      expect(p.coins, isNull);
      expect(p.xp, isNull);
      expect(p.level, isNull);
      expect(p.day, isNull);
      expect(p.intro, isNull);
      expect(p.locale, isNull);
      expect(p.spawn, isNull);
      expect(p.showDebug, kDebugMode);
      expect(p.verbose, isFalse);
      expect(p.mochi, isFalse);
      expect(p.raw, isEmpty);
    }
  });

  test('§2.5-21 level=5 → xp 800 và bật memory', () {
    final p = CityDebugParams.fromQuery(const {'level': '5'});
    expect(p.memorySave, isTrue);
    expect(p.level, 5);
    expect(p.xp, 800);
    final g = CityGame();
    p.applyTo(g);
    expect(g.wallet.xp, 800);
    expect(g.wallet.level, 5);
    expect(g.wallet.coins, 1500);
    expect(g.levelSeen, 1); // không đổi mốc: phố báo bù các lô vừa mở
  });

  test('§2.5-21 level=99 kẹp về 30', () {
    final p = CityDebugParams.fromQuery(const {'level': '99'});
    expect(p.level, 30);
    expect(p.xp, PlayerLevel.xpToReach(30));
    final g = CityGame();
    p.applyTo(g);
    expect(g.wallet.level, 30);
  });

  test('§2.5-21 coins=abc → null (vẫn bật memory)', () {
    final p = CityDebugParams.fromQuery(const {'coins': 'abc'});
    expect(p.coins, isNull);
    expect(p.memorySave, isTrue);
    final g = CityGame();
    p.applyTo(g);
    expect(g.wallet.coins, 1500);
  });

  test('§2.5-21 spawn=3,-4.6, lang=vi, intro=0', () {
    final p = CityDebugParams.fromQuery(const {
      'spawn': '3,-4.6',
      'lang': 'vi',
      'intro': '0',
      'quality': 'low',
      'sun': 'ffeedd',
      'log': '1',
      'mochi': '1',
      'debug': '0',
    });
    expect(p.spawn, (x: 3.0, z: -4.6));
    expect(p.locale, const Locale('vi'));
    expect(p.intro, isFalse);
    expect(p.memorySave, isFalse); // lang / spawn không bật memory
    expect(p.verbose, isTrue);
    expect(p.mochi, isTrue);
    expect(p.showDebug, isFalse);
    expect(p.raw['quality'], 'low');
    expect(p.raw['sun'], 'ffeedd');
    expect(() => p.raw['x'] = 'y', throwsUnsupportedError);

    final q = CityDebugParams.fromQuery(const {
      'intro': '1',
      'lang': 'en',
      'debug': '1',
      'save': 'memory',
    });
    expect(q.intro, isTrue);
    expect(q.locale, const Locale('en'));
    expect(q.showDebug, isTrue);
    expect(q.memorySave, isTrue);

    for (final bad in ['3', '3,x', 'a,b', '1,2,3', 'Infinity,1', '']) {
      expect(
        CityDebugParams.fromQuery({'spawn': bad}).spawn,
        isNull,
        reason: bad,
      );
    }
    expect(CityDebugParams.fromQuery(const {'lang': 'fr'}).locale, isNull);
    expect(CityDebugParams.fromQuery(const {'intro': 'x'}).intro, isNull);
  });

  test('coins / xp chỉ áp khi memory; xp thắng level', () {
    final p = CityDebugParams.fromQuery(const {
      'coins': '9000',
      'xp': '50',
      'level': '10',
    });
    expect(p.xp, 50);
    final g = CityGame();
    p.applyTo(g);
    expect(g.wallet.coins, 9000);
    expect(g.wallet.xp, 50);

    // Dựng tay không bật memory → không áp (không bao giờ sửa save thật).
    final g2 = CityGame();
    const CityDebugParams(coins: 1, xp: 999).applyTo(g2);
    expect(g2.wallet.coins, 1500);
    expect(g2.wallet.xp, 0);
  });

  test('§7-15 day=6 đặt dayNumber và bật memory', () {
    final p = CityDebugParams.fromQuery(const {'day': '6'});
    expect(p.memorySave, isTrue);
    expect(p.day, 6);
    final g = CityGame()..markTutorialSeen(StationId.mix);
    p.applyTo(g);
    expect(g.wallet.dayNumber, 6);
    expect(g.wallet.coins, 1500); // phần còn lại giữ nguyên
    expect(g.tutorialSeen, {StationId.mix});
    expect(g.interstitialDue, isTrue);

    expect(CityDebugParams.fromQuery(const {'day': '0'}).day, 1);
    final bad = CityDebugParams.fromQuery(const {'day': 'x'});
    expect(bad.day, isNull);
    expect(bad.memorySave, isTrue);
    expect(CityDebugParams.none.day, isNull);
    // Dựng tay không bật memory → không áp.
    final g2 = CityGame();
    const CityDebugParams(day: 9).applyTo(g2);
    expect(g2.wallet.dayNumber, 1);
  });

  test('fromPlatform không ném', () {
    expect(CityDebugParams.fromPlatform, returnsNormally);
  });
}
