import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';
import 'package:sugarleaf_bakery/core/shift/shift_stats.dart';

final _now = DateTime(2026, 11, 4, 10);
DateTime _clock() => _now;

ShiftStats _stats() => ShiftStats(
  shifts: 7,
  orders: 33,
  stars: 120,
  five: 9,
  coins: 9007199254740000,
  best: 1460,
  tutorial: {'mould', 'mix', 'tramMoi'},
  recipeSeen: 6,
  adDay: 4,
);

Map<String, dynamic> _wire(CitySave s) =>
    jsonDecode(jsonEncode(s.toJson(_now))) as Map<String, dynamic>;

/// Khoá cấp trên cùng mà bản GĐ2 hiểu (trước khi thêm `bakery`).
const _gd2Keys = {
  'v',
  'createdAt',
  'savedAt',
  'migratedFrom',
  'wallet',
  'look',
  'day',
  'visited',
  'settings',
  'flags',
  'ads',
  'iap',
  'branches',
  'staff',
  'district',
  'quests',
  'login',
};

void main() {
  test('§7-10 bakery: khứ hồi đủ trường, ghi đúng dạng, == / hashCode', () {
    final s = CitySave(coins: 2000, bakery: _stats());
    final j = s.toJson(_now);
    expect(j['bakery'], {
      'shifts': 7,
      'orders': 33,
      'stars': 120,
      'five': 9,
      'coins': 9007199254740000,
      'best': 1460,
      'tutorial': ['mix', 'mould', 'tramMoi'],
      'recipeSeen': 6,
      'adDay': 4,
    });
    final r = CitySave.decode(_wire(s));
    expect(r.bad, isEmpty);
    expect(r.save.bakery, _stats());
    expect(r.save, s.copyWith(savedAt: _now.millisecondsSinceEpoch));
    expect(r.save.extra, isEmpty); // bakery là khoá đã biết, không vào extra
    expect(CitySave.knownKeys, contains('bakery'));
    expect(s == s.copyWith(bakery: ShiftStats()), isFalse);
    expect(s.hashCode, CitySave(coins: 2000, bakery: _stats()).hashCode);
    // Qua CityGame cũng y nguyên.
    final g = CityGame(clock: _clock)..restore(s);
    expect(g.toSave(), s);
    expect(g.bakery, _stats());
  });

  test(
    '§7-10 thiếu trường → mặc định, các trường khác giữ; mặc định của người mới',
    () {
      expect(CitySave.fresh(_now).bakery, ShiftStats());
      expect(CitySave.fresh(_now).toJson(_now)['bakery'], {
        'shifts': 0,
        'orders': 0,
        'stars': 0,
        'five': 0,
        'coins': 0,
        'best': 0,
        'tutorial': <String>[],
        'recipeSeen': 0,
        'adDay': 0,
      });
      final r = CitySave.decode({
        'v': 3,
        'bakery': {
          'shifts': 2,
          'tutorial': ['box'],
        },
      });
      expect(r.bad, isEmpty);
      expect(r.save.bakery, ShiftStats(shifts: 2, tutorial: {'box'}));
      final n = CitySave.decode({'v': 3, 'bakery': null});
      expect(n.bad, isEmpty);
      expect(n.save.bakery, ShiftStats());
    },
  );

  test('§7-10 trường sai kiểu → chỉ trường đó về mặc định, bad = bakery.x', () {
    final base = _wire(CitySave(bakery: _stats()));
    final cases = <(String, Object?, Object?)>[
      ('shifts', 'x', 0),
      ('orders', true, 0),
      ('stars', [1], 0),
      ('five', double.nan.toString(), 0),
      ('coins', {'a': 1}, 0),
      ('best', 'nhiều', 0),
      ('tutorial', 'mould', <String>[]),
      ('recipeSeen', 'x', 0),
      ('adDay', false, 0),
    ];
    for (final (field, bad, expected) in cases) {
      final j = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      (j['bakery'] as Map)[field] = bad;
      final r = CitySave.decode(j);
      expect(r.bad, ['bakery.$field'], reason: field);
      final out = r.save.bakery.toJson();
      expect(out[field], expected, reason: field);
      // Các trường khác giữ.
      for (final k in out.keys.where((k) => k != field)) {
        expect(out[k], _stats().toJson()[k], reason: '$field → $k');
      }
    }
    // Cả mục sai kiểu.
    final j = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    j['bakery'] = [1, 2];
    final r = CitySave.decode(j);
    expect(r.bad, ['bakery']);
    expect(r.save.bakery, ShiftStats());
    // tutorial có phần tử hỏng: giữ phần tử tốt (cả tên lạ), đánh dấu hỏng.
    final t = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    (t['bakery'] as Map)['tutorial'] = ['mix', 3, '', 'tramMoi'];
    final rt = CitySave.decode(t);
    expect(rt.bad, ['bakery.tutorial']);
    expect(rt.save.bakery.tutorial, {'mix', 'tramMoi'});
  });

  test(
    '§7-10 kẹp giá trị: đếm [0, 2^31−1], xu [0, 2^53−1], recipeSeen 0..30',
    () {
      final r = CitySave.decode({
        'bakery': {
          'shifts': -5,
          'orders': 1e12,
          'stars': double.infinity,
          'five': 2.7,
          'coins': 1e300,
          'best': -1,
          'recipeSeen': 99,
          'adDay': -3,
        },
      });
      expect(r.bad, isEmpty);
      final b = r.save.bakery;
      expect(b.shifts, 0);
      expect(b.orders, 2147483647);
      expect(b.stars, 2147483647);
      expect(b.five, 2);
      expect(b.coins, CityWallet.coinCap);
      expect(b.best, 0);
      expect(b.recipeSeen, 30);
      expect(b.adDay, 0);
      expect(
        CitySave.decode({
          'bakery': {'recipeSeen': -1},
        }).save.bakery.recipeSeen,
        0,
      );
    },
  );

  test(
    '§7-10 trường bakery hỏng → store chép dự phòng đúng 1 lần, ghi lại bản đã sửa',
    () async {
      final raw = jsonEncode({
        ..._wire(CitySave(coins: 4321, bakery: _stats())),
        'bakery': {..._stats().toJson(), 'shifts': 'x', 'adDay': 'y'},
      });
      final repo = MemoryCitySaveRepository(v3: raw);
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.source, CitySaveSource.v3);
      expect(
        store.badFields,
        unorderedEquals(['bakery.shifts', 'bakery.adDay']),
      );
      expect(repo.backups, [raw]);
      expect(store.game.bakery, _stats().copyWith(shifts: 0, adDay: 0));
      expect(store.game.wallet.coins, 4321);
      await store.flush();
      final again = await CitySaveStore.load(repo, clock: _clock);
      expect(again.badFields, isEmpty);
      expect(repo.backups, [raw]);
      expect(again.game.bakery, _stats().copyWith(shifts: 0, adDay: 0));
    },
  );

  test(
    '§7-10 save GĐ2 (không có bakery) nạp được, không hỏng, không chép dự phòng',
    () async {
      final gd2 = _wire(CitySave(coins: 777, xp: 300, dayNumber: 5))
        ..remove('bakery');
      expect(_gd2Keys.containsAll(gd2.keys), isTrue);
      final repo = MemoryCitySaveRepository(v3: jsonEncode(gd2));
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.badFields, isEmpty);
      expect(repo.backups, isEmpty);
      expect(store.locked, isFalse);
      expect(store.game.wallet.coins, 777);
      expect(store.game.bakery, ShiftStats());
      expect(store.game.recipeSeen, 0);
    },
  );

  test(
    '§7-10 bản GĐ2 nạp save GĐ3: bakery là khoá lạ → vào extra, ghi lại nguyên vẹn',
    () {
      // Bản GĐ2 không biết `bakery`; cơ chế khoá lạ của nó giống hệt bản này với một khoá chưa biết. Kiểm bằng khoá
      // lạ mang đúng giá trị `bakery` của GĐ3: decode → extra → toJson → decode trả lại y nguyên.
      expect(_gd2Keys.contains('bakery'), isFalse);
      expect(CitySave.knownKeys.difference(_gd2Keys), {'bakery'});
      final gd3 = _wire(CitySave(bakery: _stats()));
      final asUnknown = {...gd3}
        ..['bakeryFromNewerBuild'] = gd3.remove('bakery');
      final r = CitySave.decode(jsonDecode(jsonEncode(asUnknown)));
      expect(r.bad, isEmpty);
      expect(r.save.extra['bakeryFromNewerBuild'], _stats().toJson());
      final rewritten = _wire(r.save);
      expect(rewritten['bakeryFromNewerBuild'], _stats().toJson());
      // Đổi tên khoá về `bakery` → bản này đọc lại đủ thống kê.
      final back = {...rewritten}
        ..['bakery'] = rewritten.remove('bakeryFromNewerBuild');
      expect(CitySave.decode(back).save.bakery, _stats());
    },
  );

  test(
    '§7-13 tutorialSeen và recipeSeen lưu rồi nạp lại đúng (qua store)',
    () async {
      final repo = MemoryCitySaveRepository();
      final store = await CitySaveStore.load(repo, clock: _clock);
      store.attachAutosave();
      store.game
        ..markTutorialSeen(StationId.frost)
        ..markTutorialSeen(StationId.topping)
        ..markRecipeSeen(7)
        ..recordShift(coins: 999, completed: true);
      await store.flush();
      expect(repo.writeCount, 1);
      store.dispose();
      final again = await CitySaveStore.load(repo, clock: _clock);
      expect(again.game.tutorialSeen, {StationId.frost, StationId.topping});
      expect(again.game.recipeSeen, 7);
      expect(again.game.bakery.shifts, 1);
      expect(again.game.bakery.best, 999);
    },
  );

  test('xoá dữ liệu: thống kê tiệm về mặc định', () async {
    final repo = MemoryCitySaveRepository(
      v3: jsonEncode(_wire(CitySave(bakery: _stats()))),
    );
    final store = await CitySaveStore.load(repo, clock: _clock);
    expect(store.game.bakery, _stats());
    await store.resetAll();
    expect(store.game.bakery, ShiftStats());
    expect(CitySave.decode(jsonDecode(repo.v3!)).save.bakery, ShiftStats());
  });
}
