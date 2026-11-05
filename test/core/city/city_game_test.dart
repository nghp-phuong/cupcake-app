import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_day.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_settings.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';

var _now = DateTime(2026, 11, 4, 10);
DateTime _clock() => _now;

int _notifies(Listenable l, void Function() act) {
  var n = 0;
  void count() => n++;
  l.addListener(count);
  act();
  l.removeListener(count);
  return n;
}

void main() {
  setUp(() => _now = DateTime(2026, 11, 4, 10));

  test('cityDateKey / isCityDateKey', () {
    expect(cityDateKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(cityDateKey(DateTime(987, 12, 31)), '0987-12-31');
    expect(isCityDateKey('2026-11-04'), isTrue);
    for (final s in ['', '2026-1-04', '2026-13-01', '2026-11-32', 'x']) {
      expect(isCityDateKey(s), isFalse, reason: s);
    }
  });

  test('CitySettings: mặc định, không đổi thì không notify', () {
    final s = CitySettings();
    expect(s.language, LanguagePref.system);
    expect(s.sound, isTrue);
    expect(_notifies(s, () => s.setLanguage(LanguagePref.vi)), 1);
    expect(_notifies(s, () => s.setLanguage(LanguagePref.vi)), 0);
    expect(_notifies(s, () => s.setSound(false)), 1);
    expect(_notifies(s, () => s.setSound(false)), 0);
    expect(s.language, LanguagePref.vi);
    expect(s.sound, isFalse);
  });

  test('cờ intro / levelSeen: kẹp 1..30, không đổi thì không notify', () {
    final g = CityGame(clock: _clock);
    expect(g.introSeen, isFalse);
    expect(g.levelSeen, 1);
    expect(_notifies(g, g.markIntroSeen), 1);
    expect(_notifies(g, g.markIntroSeen), 0);
    expect(g.introSeen, isTrue);
    expect(_notifies(g, () => g.markLevelSeen(5)), 1);
    expect(_notifies(g, () => g.markLevelSeen(5)), 0);
    g.markLevelSeen(99);
    expect(g.levelSeen, 30);
    g.markLevelSeen(0);
    expect(g.levelSeen, 1);
    g.markLevelSeen(3); // cấp giảm: đặt lại mốc
    g.markLevelSeen(2);
    expect(g.levelSeen, 2);
    // Ví có sẵn XP → mốc mặc định là cấp hiện tại.
    expect(CityGame(wallet: CityWallet(xp: 800)).levelSeen, 5);
  });

  test(
    '§2.5-20 quảng cáo thưởng: tối đa 12 lần/ngày, đặt lại khi sang ngày',
    () {
      final g = CityGame(clock: _clock)..refreshDay();
      final AdLedger ledger = g;
      expect(CityGame.maxRewardedPerDay, 12);
      for (var i = 0; i < 12; i++) {
        expect(ledger.canShowRewarded, isTrue, reason: '$i');
        expect(_notifies(g, ledger.registerRewardedShown), 1);
      }
      expect(ledger.rewardedToday, 12);
      expect(ledger.canShowRewarded, isFalse);
      expect(g.toSave().rewarded, 12);

      _now = DateTime(2026, 11, 5, 0, 1);
      // Chưa refreshDay vẫn đọc theo ngày hôm nay.
      expect(ledger.rewardedToday, 0);
      expect(ledger.canShowRewarded, isTrue);
      expect(g.refreshDay(), isTrue);
      expect(g.toSave().rewarded, 0);
      expect(g.toSave().adsDate, '2026-11-05');
      ledger.registerRewardedShown();
      expect(ledger.rewardedToday, 1);

      // Quên refreshDay qua đêm: lần xem đầu của ngày mới đếm lại từ 1.
      _now = DateTime(2026, 11, 6, 9);
      ledger.registerRewardedShown();
      expect(ledger.rewardedToday, 1);
    },
  );

  test(
    'refreshDay: ví sang ngày + quảng cáo; cùng ngày → false, không notify',
    () {
      final g = CityGame(clock: _clock);
      expect(g.wallet.dayKey, '');
      expect(g.refreshDay(), isTrue);
      expect(g.wallet.dayKey, '2026-11-04');
      expect(g.wallet.dayNumber, 1);
      var n = 0;
      void count() => n++;
      g.addListener(count);
      g.wallet.addListener(count);
      expect(g.refreshDay(), isFalse);
      expect(n, 0);
      expect(g.refreshDay(DateTime(2026, 11, 5)), isTrue);
      expect(g.wallet.dayNumber, 2);
    },
  );

  test('restore tại chỗ, toSave khứ hồi; iapOwned chỉ đọc', () {
    final g = CityGame(clock: _clock);
    final wallet = g.wallet;
    final settings = g.settings;
    final s = CitySave(
      createdAt: 5,
      migratedFrom: 2,
      coins: 77,
      xp: 120,
      look: const MaiLook(hair: MaiHair.bob),
      dayKey: '2026-11-04',
      dayNumber: 3,
      eaten: {'fish_soup': 2},
      fullBuff: true,
      visited: {'n3'},
      language: LanguagePref.en,
      sound: false,
      introSeen: true,
      levelSeen: 2,
      removeAds: true,
      adsDate: '2026-11-04',
      rewarded: 4,
      iap: {'removeAds'},
      district: 'sea_market',
      extra: {'moi': 1},
    );
    final nw = _notifies(wallet, () => g.restore(s));
    expect(nw, 1);
    expect(identical(g.wallet, wallet), isTrue);
    expect(identical(g.settings, settings), isTrue);
    expect(g.toSave(), s);
    expect(wallet.coins, 77);
    expect(wallet.level, 2);
    expect(wallet.look.hair, MaiHair.bob);
    expect(settings.language, LanguagePref.en);
    expect(g.removeAds, isTrue);
    expect(g.iapOwned, {'removeAds'});
    expect(g.rewardedToday, 4);
    expect(g.extra, {'moi': 1});
    expect(() => g.iapOwned.add('x'), throwsUnsupportedError);
    // Mỗi lần restore notify game đúng 1 lần.
    expect(_notifies(g, () => g.restore(CitySave())), 1);
    expect(g.toSave(), CitySave());
  });
}
