import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/save/v2_import.dart';

final _now = DateTime(2026, 11, 4, 10);

void main() {
  test('§2.5-10 nhập v2: chỉ mang cài đặt, intro, removeAds, iap; 1500 xu', () {
    final s = importV2({
      'v': 2,
      'coins': 99999,
      'gems': 50,
      'xp': 1234,
      'day': 30,
      'lang': 'vi',
      'sound': false,
      'introSeen': true,
      'removeAds': true,
      'iap': ['removeAds', 'starterPack'],
      'adDate': '2026-11-04',
      'rewardedToday': 7,
      'progress': {
        'levels': {
          '1': {'stars': 3},
        },
      },
    }, now: _now);
    expect(
      s,
      CitySave.fresh(_now).copyWith(
        migratedFrom: 2,
        language: LanguagePref.vi,
        sound: false,
        introSeen: true,
        removeAds: true,
        iap: {'removeAds', 'starterPack'},
      ),
    );
    expect(s.coins, 1500);
    expect(s.xp, 0);
    expect(s.rewarded, 0);
    expect(s.levelSeen, 1);
    expect(s.extra, isEmpty);
  });

  test(
    '§2.5-11 bản v1 trong khoá v2: không có introSeen → false, không mang tiến trình',
    () {
      final s = importV2({
        'v': 1,
        'coins': 5000,
        'gems': 9,
        'xp': 300,
        'day': 9,
        'oven': 3,
        'lang': 'en',
        'sound': false,
        'removeAds': false,
        'iap': <Object?>[],
      }, now: _now);
      expect(
        s,
        CitySave.fresh(
          _now,
        ).copyWith(migratedFrom: 2, language: LanguagePref.en, sound: false),
      );
      expect(s.introSeen, isFalse);
    },
  );

  test('trường sai kiểu / thiếu → mặc định, không ném', () {
    final s = importV2({
      'lang': 5,
      'sound': 'no',
      'introSeen': 1,
      'removeAds': 'yes',
      'iap': ['removeAds', '', 3, null, 'lạ'],
    }, now: _now);
    expect(s.language, LanguagePref.system);
    expect(s.sound, isTrue);
    expect(s.introSeen, isFalse);
    expect(s.removeAds, isFalse);
    expect(s.iap, {'removeAds', 'lạ'});
    expect(s.migratedFrom, 2);

    final empty = importV2(<String, dynamic>{}, now: _now);
    expect(empty, CitySave.fresh(_now).copyWith(migratedFrom: 2));
    expect(importV2({'iap': 'removeAds'}, now: _now).iap, isEmpty);
  });
}
