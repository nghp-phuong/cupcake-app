import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';

final _now = DateTime(2026, 11, 4, 10);

/// Mọi trường khác mặc định.
CitySave _full() => CitySave(
  createdAt: 1700000000000,
  savedAt: 1700000500000,
  migratedFrom: 2,
  coins: 4321,
  xp: 950, // cấp 5
  look: const MaiLook(hair: MaiHair.bun, hairColor: MaiHairColor.strawberry),
  dayKey: '2026-11-03',
  dayNumber: 4,
  eaten: {'veggie_curry': 2, 'fish_soup': 1, 'mon_la': 3},
  fullBuff: true,
  visited: {'n4', 'n3', 'x9'},
  language: LanguagePref.vi,
  sound: false,
  introSeen: true,
  levelSeen: 4,
  removeAds: true,
  adsDate: '2026-11-03',
  rewarded: 5,
  iap: {'starterPack', 'removeAds'},
  branches: {
    's1': {'owned': true, 'level': 2},
  },
  staff: [
    {'id': 'an', 'lv': 1},
    'x',
  ],
  district: 'sea_market',
  quests: {
    'date': '2026-11-03',
    'list': [1, 2],
  },
  login: {'streak': 3},
  extra: {
    'zz': 1,
    'tinhNangMoi': {
      'a': [1, 2],
    },
  },
);

/// JSON như đọc từ bộ nhớ (qua chuỗi).
Map<String, dynamic> _wire(CitySave s) =>
    jsonDecode(jsonEncode(s.toJson(_now))) as Map<String, dynamic>;

Map<String, dynamic> _copy(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void _setPath(Map<String, dynamic> m, String path, Object? v) {
  final parts = path.split('.');
  var cur = m;
  for (final p in parts.take(parts.length - 1)) {
    cur = cur[p] as Map<String, dynamic>;
  }
  cur[parts.last] = v;
}

void main() {
  test('fresh: mặc định của người mới, ngày = hôm nay', () {
    final s = CitySave.fresh(_now);
    expect(s.createdAt, _now.millisecondsSinceEpoch);
    expect(s.savedAt, 0);
    expect(s.migratedFrom, isNull);
    expect(s.coins, 1500);
    expect(s.xp, 0);
    expect(s.look, MaiLook.defaults);
    expect(s.dayKey, '2026-11-04');
    expect(s.dayNumber, 1);
    expect(s.eaten, isEmpty);
    expect(s.fullBuff, isFalse);
    expect(s.visited, isEmpty);
    expect(s.language, LanguagePref.system);
    expect(s.sound, isTrue);
    expect(s.introSeen, isFalse);
    expect(s.levelSeen, 1);
    expect(s.removeAds, isFalse);
    expect(s.adsDate, '2026-11-04');
    expect(s.rewarded, 0);
    expect(s.iap, isEmpty);
    expect(s.branches, isEmpty);
    expect(s.staff, isEmpty);
    expect(s.district, 'bakery_street');
    expect(s.quests, isEmpty);
    expect(s.login, isEmpty);
    expect(s.extra, isEmpty);
    final j = s.toJson(_now);
    expect(j['v'], 3);
    expect(j.containsKey('migratedFrom'), isFalse);
  });

  test('§2.5-2 khứ hồi mọi trường, CitySave ==', () {
    final s = _full();
    final r = CitySave.decode(_wire(s));
    expect(r.bad, isEmpty);
    expect(r.newer, isFalse);
    expect(r.save, s.copyWith(savedAt: _now.millisecondsSinceEpoch));
    expect(
      r.save.hashCode,
      s.copyWith(savedAt: _now.millisecondsSinceEpoch).hashCode,
    );
    // Qua CityGame cũng y nguyên.
    final g = CityGame(clock: () => _now)..restore(s);
    expect(g.toSave(), s);
    // Khác một trường bất kỳ → khác.
    final changes = <CitySave Function(CitySave)>[
      (x) => x.copyWith(createdAt: 1),
      (x) => x.copyWith(savedAt: 1),
      (x) => x.copyWith(migratedFrom: 3),
      (x) => x.copyWith(coins: 1),
      (x) => x.copyWith(xp: 1),
      (x) => x.copyWith(look: MaiLook.defaults),
      (x) => x.copyWith(dayKey: '2026-01-01'),
      (x) => x.copyWith(dayNumber: 9),
      (x) => x.copyWith(eaten: {'fish_soup': 1}),
      (x) => x.copyWith(fullBuff: false),
      (x) => x.copyWith(visited: {'n3'}),
      (x) => x.copyWith(language: LanguagePref.en),
      (x) => x.copyWith(sound: true),
      (x) => x.copyWith(introSeen: false),
      (x) => x.copyWith(levelSeen: 2),
      (x) => x.copyWith(removeAds: false),
      (x) => x.copyWith(adsDate: ''),
      (x) => x.copyWith(rewarded: 0),
      (x) => x.copyWith(iap: {}),
      (x) => x.copyWith(branches: {}),
      (x) => x.copyWith(staff: []),
      (x) => x.copyWith(district: 'bakery_street'),
      (x) => x.copyWith(quests: {}),
      (x) => x.copyWith(login: {}),
      (x) => x.copyWith(extra: {}),
    ];
    for (final (i, c) in changes.indexed) {
      expect(c(s) == s, isFalse, reason: 'thay đổi #$i');
    }
  });

  test('§2.5-2 ghi theo thứ tự ổn định', () {
    final a = _full();
    final b = a.copyWith(
      visited: {'x9', 'n3', 'n4'},
      eaten: {'mon_la': 3, 'fish_soup': 1, 'veggie_curry': 2},
      iap: {'removeAds', 'starterPack'},
      extra: {
        'tinhNangMoi': {
          'a': [1, 2],
        },
        'zz': 1,
      },
    );
    expect(jsonEncode(a.toJson(_now)), jsonEncode(b.toJson(_now)));
    final j = a.toJson(_now);
    expect(j['visited'], ['n3', 'n4', 'x9']);
    expect((j['day'] as Map)['eaten'].keys.toList(), [
      'fish_soup',
      'mon_la',
      'veggie_curry',
    ]);
    expect(j['iap'], ['removeAds', 'starterPack']);
    expect(j.keys.skip(j.length - 2).toList(), ['tinhNangMoi', 'zz']);
  });

  test('§2.5-3 thiếu trường → mặc định, các trường khác giữ', () {
    final r = CitySave.decode({
      'v': 3,
      'wallet': {'coins': 777},
      'day': {'n': 5},
      'look': null,
      'flags': {'introSeen': true},
    });
    expect(r.bad, isEmpty);
    expect(
      r.save,
      CitySave(coins: 777, dayNumber: 5, introSeen: true, levelSeen: 1),
    );
    expect(CitySave.decode(<String, dynamic>{}).save, CitySave());
    expect(CitySave.decode(<String, dynamic>{}).bad, isEmpty);
  });

  test('§2.5-4 từng trường sai kiểu → chỉ trường đó về mặc định', () {
    final base = _wire(_full());
    // (đường dẫn, giá trị sai, giá trị JSON mong đợi sau khi đọc lại)
    final cases = <(String, Object?, Object?)>[
      ('wallet', 'x', {'coins': 1500, 'xp': 0}),
      ('wallet.coins', 'x', 1500),
      ('wallet.xp', true, 0),
      ('look', 5, {'hair': 'ponytail', 'hairColor': 'chestnut'}),
      ('look.hair', 'mohawk', 'ponytail'),
      ('look.hairColor', 3, 'chestnut'),
      ('day', [1], {'key': '', 'n': 1, 'eaten': {}, 'fullBuff': false}),
      ('day.key', 5, ''),
      ('day.n', 'x', 1),
      ('day.eaten', 'x', {}),
      ('day.fullBuff', 'yes', false),
      ('visited', 'n3', []),
      ('settings', 'vi', {'lang': 'system', 'sound': true}),
      ('settings.lang', 'fr', 'system'),
      ('settings.sound', 0, true),
      (
        'flags',
        1,
        {'introSeen': false, 'levelSeen': 5},
      ), // thiếu → cấp hiện tại
      ('flags.introSeen', 'x', false),
      ('flags.levelSeen', 'x', 5),
      ('ads', 'x', {'removeAds': false, 'date': '', 'rewarded': 0}),
      ('ads.removeAds', 1, false),
      ('ads.date', 7, ''),
      ('ads.rewarded', 'x', 0),
      ('iap', {'a': 1}, []),
      ('branches', [1], {}),
      ('staff', {'a': 1}, []),
      ('district', 5, 'bakery_street'),
      ('quests', 'x', {}),
      ('login', [], {}),
      ('createdAt', 'x', 0),
      ('v', 'ba', 3),
    ];
    for (final (path, wrong, fixed) in cases) {
      final json = _copy(base);
      _setPath(json, path, wrong);
      final r = CitySave.decode(json);
      expect(r.bad, [path], reason: path);
      final want = _copy(base);
      _setPath(want, path, fixed);
      expect(_wire(r.save), want, reason: path);
    }
    // migratedFrom / savedAt: toJson không cho thấy giá trị đọc được.
    final m = _copy(base)..['migratedFrom'] = 'x';
    final rm = CitySave.decode(m);
    expect(rm.bad, ['migratedFrom']);
    expect(rm.save.migratedFrom, isNull);
    expect(rm.save.coins, 4321);
    final sa = _copy(base)..['savedAt'] = [1];
    final rs = CitySave.decode(sa);
    expect(rs.bad, ['savedAt']);
    expect(rs.save.savedAt, 0);
    expect(rs.save.coins, 4321);
  });

  test(
    '§2.5-4 phần tử hỏng trong danh sách / bảng: bỏ phần tử đó, giữ phần còn lại',
    () {
      final r = CitySave.decode({
        'visited': ['n3', 5, '', 'n4'],
        'iap': ['removeAds', null, 'lạ'],
        'day': {
          'eaten': {'a': 1000, 'b': -1, 'c': 2.0, 'd': 'x', 'e': 0},
        },
      });
      expect(r.bad, unorderedEquals(['visited', 'iap', 'day.eaten']));
      expect(r.save.visited, {'n3', 'n4'});
      expect(r.save.iap, {'removeAds', 'lạ'});
      expect(r.save.eaten, {'c': 2, 'e': 0});
    },
  );

  test('decode: không phải object → mặc định, không ném', () {
    for (final j in <Object?>[null, 5, 'x', <Object?>[]]) {
      final r = CitySave.decode(j);
      expect(r.save, CitySave());
      expect(r.bad, isNotEmpty);
      expect(r.newer, isFalse);
    }
  });

  test('§2.5-8 kẹp NaN, ∞, số âm; số gần 2^53 khứ hồi đúng', () {
    const cap = 9007199254740991; // 2^53 − 1
    expect(CityWallet.coinCap, cap);
    expect(CityWallet.xpCap, 2147483647);

    CitySave d(Object? coins, [Object? xp]) => CitySave.decode({
      'wallet': {'coins': coins, if (xp != null) 'xp': xp},
    }).save;
    expect(d(-5).coins, 0);
    expect(d(double.negativeInfinity).coins, 0);
    expect(d(double.infinity).coins, cap);
    expect(d(1e300).coins, cap);
    expect(d(12.9).coins, 12);
    final nan = CitySave.decode({
      'wallet': {'coins': double.nan, 'xp': double.nan},
    });
    expect(nan.save.coins, 1500);
    expect(nan.save.xp, 0);
    expect(nan.bad, ['wallet.coins', 'wallet.xp']);
    expect(d(1, -3).xp, 0);
    expect(d(1, double.infinity).xp, CityWallet.xpCap);
    // 1e400 trong chuỗi JSON đọc ra ∞.
    final inf = CitySave.decode(jsonDecode('{"wallet":{"coins":1e400}}'));
    expect(inf.save.coins, cap);
    expect(inf.bad, isEmpty);

    for (final c in [cap - 1, cap]) {
      final s = CitySave(coins: c);
      expect(CitySave.decode(_wire(s)).save.coins, c);
    }

    // Các số khác.
    final o = CitySave.decode({
      'day': {'n': 0, 'key': '2026-13-01'},
      'flags': {'levelSeen': 99},
      'ads': {'rewarded': -3, 'date': 'hôm qua'},
      'district': 'sao_hoa',
    });
    expect(o.bad, isEmpty);
    expect(o.save.dayNumber, 1);
    expect(o.save.dayKey, '');
    expect(o.save.levelSeen, 30);
    expect(o.save.rewarded, 0);
    expect(o.save.adsDate, '');
    expect(o.save.district, 'bakery_street');
    expect(
      CitySave.decode({
        'flags': {'levelSeen': 0},
      }).save.levelSeen,
      1,
    );

    // Ví cũng kẹp khi nạp.
    final w = CityWallet(coins: -5, xp: -1);
    expect(w.coins, 0);
    expect(w.xp, 0);
    w.restore(coins: cap + 10, xp: 1 << 40);
    expect(w.coins, cap);
    expect(w.xp, CityWallet.xpCap);
  });

  test('§2.5-9 khoá lạ, branches, district còn nguyên', () {
    final json = {
      'v': 3,
      'wallet': {'coins': 10},
      'tinhNangMoi': {
        'x': [1, 'a'],
      },
      'branches': {
        's1': {'owned': true},
      },
      'staff': ['an'],
      'district': 'sea_market',
      'quests': {'q': 1},
      'login': {'d': '2026-11-01'},
      'aaa': null,
    };
    final r = CitySave.decode(json);
    expect(r.bad, isEmpty);
    final g = CityGame(clock: () => _now)..restore(r.save);
    g.wallet.addXp(5);
    final out = _wire(g.toSave());
    expect(out['tinhNangMoi'], {
      'x': [1, 'a'],
    });
    expect(out.containsKey('aaa'), isTrue);
    expect(out['branches'], {
      's1': {'owned': true},
    });
    expect(out['staff'], ['an']);
    expect(out['district'], 'sea_market');
    expect(out['quests'], {'q': 1});
    expect(out['login'], {'d': '2026-11-01'});
    expect(g.extra.keys, unorderedEquals(['tinhNangMoi', 'aaa']));
    // Khoá lạ không được đè khoá đã biết.
    expect(CitySave(extra: {'wallet': 1, 'x': 2}).extra, {'x': 2});
    // Bất biến.
    expect(() => r.save.extra['y'] = 1, throwsUnsupportedError);
    expect(
      () => (r.save.branches['s1'] as Map)['owned'] = false,
      throwsUnsupportedError,
    );
    expect(() => r.save.visited.add('n9'), throwsUnsupportedError);
  });

  test('v > 3 → newer; v thiếu → bản hiện tại', () {
    expect(CitySave.decode({'v': 4}).newer, isTrue);
    expect(CitySave.decode({'v': 3}).newer, isFalse);
    expect(CitySave.decode(<String, dynamic>{}).newer, isFalse);
  });

  test('§2.5-18 xp 800 → cấp 5; levelSeen thiếu → cấp hiện tại', () {
    expect(PlayerLevel.levelForXp(800), 5);
    expect(PlayerLevel.levelForXp(799), 4);
    final r = CitySave.decode({
      'wallet': {'xp': 800},
    });
    expect(r.save.levelSeen, 5);
    final g = CityGame(clock: () => _now)..restore(r.save);
    expect(g.wallet.level, 5);
    expect(g.levelSeen, 5);
    // Cấp không lưu.
    expect(jsonEncode(g.toSave().toJson(_now)), isNot(contains('"level"')));
  });
}
