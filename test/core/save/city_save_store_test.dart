import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';

var _now = DateTime(2026, 11, 4, 10);
DateTime _clock() => _now;

/// Quá [CitySaveStore.autosaveDelay].
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 450));

CitySave _stored(MemoryCitySaveRepository repo) =>
    CitySave.decode(jsonDecode(repo.v3!)).save;

final _soup = RestaurantMenu.dishes[0]; // 120 xu, 40 xp

final _v2 = jsonEncode({
  'v': 2,
  'coins': 99999,
  'gems': 50,
  'xp': 1234,
  'day': 30,
  'lang': 'vi',
  'sound': false,
  'introSeen': true,
  'removeAds': true,
  'iap': ['removeAds'],
  'progress': {
    'levels': {
      '1': {'stars': 3},
    },
  },
});

/// Đếm số lần ghi chạy cùng lúc.
class _SlowRepo extends MemoryCitySaveRepository {
  int active = 0, maxActive = 0;

  @override
  Future<void> writeV3(String d) async {
    active++;
    maxActive = math.max(maxActive, active);
    try {
      await super.writeV3(d);
    } finally {
      active--;
    }
  }
}

class _FailV2Repo extends MemoryCitySaveRepository {
  _FailV2Repo() : super(v2: _v2);

  @override
  Future<String?> readV2() async => throw StateError('v2');
}

void main() {
  setUp(() => _now = DateTime(2026, 11, 4, 10));

  test('§2.5-1 người mới: đủ trường mặc định, chưa ghi', () async {
    final repo = MemoryCitySaveRepository();
    final store = await CitySaveStore.load(repo, clock: _clock);
    final g = store.game;
    expect(store.source, CitySaveSource.fresh);
    expect(store.locked, isFalse);
    expect(store.badFields, isEmpty);
    expect(g.toSave(), CitySave.fresh(_now));
    expect(g.wallet.coins, 1500);
    expect(g.wallet.xp, 0);
    expect(g.wallet.level, 1);
    expect(g.wallet.dayKey, '2026-11-04');
    expect(g.wallet.dayNumber, 1);
    expect(g.wallet.visited, isEmpty);
    expect(g.settings.language, LanguagePref.system);
    expect(g.settings.sound, isTrue);
    expect(g.introSeen, isFalse);
    expect(g.levelSeen, 1);
    expect(g.removeAds, isFalse);
    expect(g.iapOwned, isEmpty);
    expect(g.rewardedToday, 0);

    store.attachAutosave();
    g.refreshDay(); // cùng ngày: không đổi
    await _settle();
    await store.flush();
    expect(repo.writeCount, 0);
    expect(repo.v3, isNull);

    g.markIntroSeen(); // thay đổi đầu tiên mới ghi
    await store.flush();
    expect(repo.writeCount, 1);
    expect(_stored(repo).introSeen, isTrue);
    store.dispose();
  });

  test(
    '§2.5-4 nhiều trường hỏng → về mặc định từng trường, chép dự phòng đúng 1 lần',
    () async {
      final raw = jsonEncode({
        'v': 3,
        'wallet': {'coins': 'x', 'xp': 300},
        'settings': {'lang': 'fr', 'sound': false},
        'visited': 'n3',
      });
      final repo = MemoryCitySaveRepository(v3: raw, v2: _v2);
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.source, CitySaveSource.v3);
      expect(
        store.badFields,
        unorderedEquals(['wallet.coins', 'settings.lang', 'visited']),
      );
      expect(repo.backups, [raw]);
      final g = store.game;
      expect(g.wallet.coins, 1500);
      expect(g.wallet.xp, 300);
      expect(g.settings.sound, isFalse);
      expect(g.settings.language, LanguagePref.system);
      expect(repo.writeCount, 0); // không nhập v2
      // Bản đã sửa được ghi ở lần flush đầu → lần nạp sau không chép dự phòng nữa.
      await store.flush();
      expect(repo.writeCount, 1);
      final again = await CitySaveStore.load(repo, clock: _clock);
      expect(again.badFields, isEmpty);
      expect(repo.backups, [raw]);
      expect(again.game.wallet.xp, 300);
    },
  );

  test(
    '§2.5-5 v3 hỏng / không phải object / rỗng → dự phòng, rồi nhập v2 hoặc mặc định',
    () async {
      for (final raw in [
        '{"wallet": {"coins": 5',
        '[1,2]',
        '',
        '"chuỗi"',
        'null',
      ]) {
        // Không có v2 → mặc định.
        final a = MemoryCitySaveRepository(v3: raw);
        final sa = await CitySaveStore.load(a, clock: _clock);
        expect(sa.source, CitySaveSource.recovered, reason: raw);
        expect(a.backups, [raw], reason: raw);
        expect(sa.game.toSave(), CitySave.fresh(_now), reason: raw);
        expect(sa.locked, isFalse);
        expect(a.writeCount, 0);
        await sa
            .flush(); // đã có dự phòng → ghi bản mặc định để lần sau không chép lại
        expect(a.writeCount, 1, reason: raw);
        expect(a.backups, [raw]);

        // Có v2 → nhập v2, ghi ngay.
        final b = MemoryCitySaveRepository(v3: raw, v2: _v2);
        final sb = await CitySaveStore.load(b, clock: _clock);
        expect(sb.source, CitySaveSource.recovered, reason: raw);
        expect(b.backups, [raw]);
        expect(sb.game.settings.language, LanguagePref.vi);
        expect(b.writeCount, 1);
        expect(_stored(b).migratedFrom, 2);
        expect(b.v2, _v2);
      }
    },
  );

  test('§2.5-6 v: 4 → khoá ghi cả phiên; resetAll mở khoá', () async {
    final raw = jsonEncode({
      'v': 4,
      'wallet': {'coins': 999},
      'tinhNangMoi': true,
    });
    final repo = MemoryCitySaveRepository(v3: raw, v2: _v2);
    final store = await CitySaveStore.load(repo, clock: _clock);
    expect(store.locked, isTrue);
    expect(store.source, CitySaveSource.v3);
    expect(store.game.wallet.coins, 999);
    store.attachAutosave();
    store.game.wallet.addXp(5);
    store.game.markIntroSeen();
    await _settle();
    await store.flush();
    expect(repo.writeCount, 0);
    expect(repo.v3, raw);

    await store.resetAll();
    expect(store.locked, isFalse);
    expect(repo.writeCount, 1);
    final s = _stored(repo);
    expect(s.coins, 1500);
    expect(jsonDecode(repo.v3!)['v'], 3);
    expect(repo.v2, _v2);
    store.dispose();
  });

  test('§2.5-7 readV3 ném lỗi → mặc định, khoá ghi', () async {
    final repo = MemoryCitySaveRepository(v3: '{}', v2: _v2)..failRead = true;
    final store = await CitySaveStore.load(repo, clock: _clock);
    expect(store.locked, isTrue);
    expect(store.source, CitySaveSource.fresh);
    expect(store.game.toSave(), CitySave.fresh(_now));
    repo.failRead = false;
    store.attachAutosave();
    store.game.wallet.addXp(5);
    await store.flush();
    expect(repo.writeCount, 0);
    expect(repo.v3, '{}');

    // Không đọc được v2 (không có v3) cũng khoá: chưa biết có v2 hay không.
    final r2 = _FailV2Repo();
    final s2 = await CitySaveStore.load(r2, clock: _clock);
    expect(s2.locked, isTrue);
    s2.attachAutosave();
    s2.game.markIntroSeen();
    await s2.flush();
    expect(r2.writeCount, 0);
    store.dispose();
    s2.dispose();
  });

  test(
    '§2.5-10 nhập v2 → v3 đúng, 1500 xu, migratedFrom 2, ghi 1 lần, chuỗi v2 y nguyên',
    () async {
      final repo = MemoryCitySaveRepository(v2: _v2);
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.source, CitySaveSource.importedV2);
      expect(repo.writeCount, 1); // ghi ngay trong load (trước runApp)
      expect(repo.v2, _v2);
      expect(repo.backups, isEmpty);
      final s = _stored(repo);
      expect(s.migratedFrom, 2);
      expect(s.coins, 1500);
      expect(s.xp, 0);
      expect(s.language, LanguagePref.vi);
      expect(s.sound, isFalse);
      expect(s.introSeen, isTrue);
      expect(s.removeAds, isTrue);
      expect(s.iap, {'removeAds'});
      expect(s.dayKey, '2026-11-04');
      final g = store.game;
      expect(g.toSave(), s.copyWith(savedAt: 0));
      // Không ghi thêm khi chưa có thay đổi.
      store.attachAutosave();
      await _settle();
      await store.flush();
      expect(repo.writeCount, 1);
      store.dispose();
    },
  );

  test(
    '§2.5-11 v1 trong khoá v2 → chỉ nhận cài đặt; v2 hỏng → bỏ qua',
    () async {
      final v1 = jsonEncode({
        'v': 1,
        'coins': 5000,
        'xp': 300,
        'day': 9,
        'oven': 3,
        'lang': 'vi',
        'sound': false,
      });
      final repo = MemoryCitySaveRepository(v2: v1);
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.source, CitySaveSource.importedV2);
      final s = _stored(repo);
      expect(s.language, LanguagePref.vi);
      expect(s.sound, isFalse);
      expect(s.introSeen, isFalse);
      expect(s.coins, 1500);
      expect(s.xp, 0);
      expect(s.dayNumber, 1);
      expect(repo.v2, v1);

      for (final bad in ['{hỏng', '[1]', '', '7']) {
        final r = MemoryCitySaveRepository(v2: bad);
        final st = await CitySaveStore.load(r, clock: _clock);
        expect(st.source, CitySaveSource.fresh, reason: bad);
        expect(st.locked, isFalse);
        expect(st.game.toSave(), CitySave.fresh(_now));
        expect(r.writeCount, 0);
        expect(r.backups, isEmpty);
        expect(r.v2, bad);
      }
    },
  );

  test('§2.5-12 có cả v3 lẫn v2 → dùng v3', () async {
    final v3 = jsonEncode(
      CitySave(coins: 42, language: LanguagePref.en).toJson(_now),
    );
    final repo = MemoryCitySaveRepository(v3: v3, v2: _v2);
    final store = await CitySaveStore.load(repo, clock: _clock);
    expect(store.source, CitySaveSource.v3);
    expect(store.game.wallet.coins, 42);
    expect(store.game.settings.language, LanguagePref.en);
    expect(store.game.introSeen, isFalse);
    expect(repo.backups, isEmpty);
  });

  test(
    '§2.5-13 ghi v3 lỗi lúc nhập → vẫn chơi, v2 còn, lần sau nhập lại',
    () async {
      final repo = MemoryCitySaveRepository(v2: _v2)..failWrite = true;
      final store = await CitySaveStore.load(repo, clock: _clock);
      expect(store.source, CitySaveSource.importedV2);
      expect(store.locked, isFalse);
      expect(store.game.settings.language, LanguagePref.vi);
      expect(repo.v3, isNull);
      expect(repo.writeCount, 0);
      expect(repo.v2, _v2);
      store.attachAutosave();
      store.game.wallet.addXp(5); // vẫn chơi được, ghi lỗi chỉ log
      await store.flush();
      expect(repo.v3, isNull);
      store.dispose();

      repo.failWrite = false;
      final again = await CitySaveStore.load(repo, clock: _clock);
      expect(again.source, CitySaveSource.importedV2);
      expect(repo.writeCount, 1);
      expect(_stored(repo).language, LanguagePref.vi);
    },
  );

  test(
    '§2.5-14 debounce 300 ms gộp 1 lần ghi; flush ghi ngay; sau dispose không ghi',
    () async {
      final repo = MemoryCitySaveRepository();
      final store = await CitySaveStore.load(repo, clock: _clock);
      final g = store.game;
      store.attachAutosave();
      store.attachAutosave(); // gọi lại không gắn đôi
      g.wallet.addXp(1);
      g.markIntroSeen();
      g.settings.setSound(false);
      g.wallet.addXp(1);
      expect(repo.writeCount, 0);
      await _settle();
      expect(repo.writeCount, 1);
      expect(_stored(repo).xp, 2);

      g.wallet.addXp(1);
      await store.flush();
      expect(repo.writeCount, 2);
      expect(_stored(repo).xp, 3);
      await _settle(); // flush đã huỷ hẹn giờ
      expect(repo.writeCount, 2);
      await store.flush(); // không còn gì chưa lưu
      expect(repo.writeCount, 2);

      g.wallet.addXp(1);
      store.dispose();
      await _settle();
      await store.flush();
      g.wallet.addXp(1);
      await _settle();
      expect(repo.writeCount, 2);
    },
  );

  test(
    '§2.5-15 ghi tuần tự với bộ nhớ chậm → bản cuối là trạng thái mới nhất',
    () async {
      final repo = _SlowRepo()..writeGate = Completer<void>();
      final store = await CitySaveStore.load(repo, clock: _clock);
      final g = store.game;
      store.attachAutosave();
      g.wallet.addXp(10);
      await _settle(); // lần ghi 1 bắt đầu, bị giữ
      expect(repo.active, 1);
      expect(repo.writeCount, 0);

      g.wallet.addXp(20);
      g.markIntroSeen();
      await _settle(); // hẹn giờ nổ trong lúc đang ghi: không mở lần ghi thứ hai
      expect(repo.active, 1);
      final flushing = store.flush(); // chờ lần đang ghi rồi ghi tiếp

      final gate = repo.writeGate!;
      repo.writeGate = null;
      gate.complete();
      await flushing;
      expect(repo.maxActive, 1);
      expect(repo.writeCount, 2);
      final s = _stored(repo);
      expect(s.xp, 30);
      expect(s.introSeen, isTrue);
      expect(s, store.game.toSave().copyWith(savedAt: s.savedAt));
      store.dispose();
    },
  );

  test(
    '§2.5-16 đổi ngày: lần ăn thứ 2 được 25%, nạp lại cùng ngày vẫn 25%, sang ngày sau 100%',
    () async {
      final repo = MemoryCitySaveRepository();
      final s1 = await CitySaveStore.load(repo, clock: _clock);
      s1.attachAutosave();
      expect(s1.game.wallet.eat(_soup).xpGained, 40);
      final second = s1.game.wallet.eat(_soup);
      expect(second.reducedXp, isTrue);
      expect(second.xpGained, 10);
      await s1.flush();
      s1.dispose();

      _now = DateTime(2026, 11, 4, 23, 59);
      final s2 = await CitySaveStore.load(repo, clock: _clock);
      s2.attachAutosave();
      expect(s2.game.wallet.timesEatenToday(_soup.id), 2);
      final third = s2.game.wallet.eat(_soup);
      expect(third.reducedXp, isTrue);
      expect(third.xpGained, 10);
      expect(s2.game.wallet.dayNumber, 1);
      await s2.flush();
      expect(_stored(repo).eaten, {_soup.id: 3});
      s2.dispose();

      _now = DateTime(2026, 11, 5, 8);
      final s3 = await CitySaveStore.load(repo, clock: _clock);
      final w = s3.game.wallet;
      expect(w.dayKey, '2026-11-05');
      expect(w.dayNumber, 2);
      expect(w.fullBuff, isTrue);
      expect(w.timesEatenToday(_soup.id), 0);
      // Nạp sang ngày mới đã đổi trạng thái → flush ghi dù chưa có thao tác nào.
      s3.attachAutosave();
      await s3.flush();
      expect(_stored(repo).dayNumber, 2);
      final fresh = w.eat(_soup);
      expect(fresh.reducedXp, isFalse);
      expect(fresh.xpGained, 40);

      // App quay lại sau nửa đêm (onShow → refreshDay).
      _now = DateTime(2026, 11, 6, 0, 5);
      expect(s3.game.refreshDay(), isTrue);
      expect(w.dayNumber, 3);
      expect(w.timesEatenToday(_soup.id), 0);
      expect(w.fullBuff, isTrue);
      await s3.flush();
      expect(_stored(repo).dayNumber, 3);
      expect(_stored(repo).eaten, isEmpty);
      s3.dispose();
    },
  );

  test(
    '§2.5-17 xoá dữ liệu giữ cài đặt và đồ đã mua, ghi bản mặc định, lần nạp sau không nhập v2',
    () async {
      final repo = MemoryCitySaveRepository(v2: _v2);
      final store = await CitySaveStore.load(repo, clock: _clock);
      final g = store.game;
      final wallet = g.wallet;
      final settings = g.settings;
      store.attachAutosave();
      g.settings.setLanguage(LanguagePref.en);
      g.wallet.eat(_soup);
      g.wallet.markFirstVisit('n3');
      g.markLevelSeen(5);
      g.registerRewardedShown();
      await store.flush();
      expect(repo.writeCount, 2);

      var walletNotified = 0;
      wallet.addListener(() => walletNotified++);
      await store.resetAll();
      expect(identical(g.wallet, wallet), isTrue);
      expect(identical(g.settings, settings), isTrue);
      expect(walletNotified, greaterThan(0)); // màn đang nghe ví thấy thay đổi
      expect(wallet.coins, 1500);
      expect(wallet.xp, 0);
      expect(wallet.visited, isEmpty);
      expect(wallet.timesEatenToday(_soup.id), 0);
      expect(wallet.fullBuff, isFalse);
      expect(g.introSeen, isFalse);
      expect(g.levelSeen, 1);
      expect(g.rewardedToday, 0);
      // Đồ đã trả tiền không mất (v2 nhập: removeAds + iap ['removeAds']).
      expect(g.removeAds, isTrue);
      expect(g.iapOwned, {'removeAds'});
      expect(settings.language, LanguagePref.en);
      expect(settings.sound, isFalse);
      expect(repo.writeCount, 3);
      final s = _stored(repo);
      expect(
        s,
        CitySave.fresh(_now).copyWith(
          savedAt: s.savedAt,
          language: LanguagePref.en,
          sound: false,
          removeAds: true,
          iap: {'removeAds'},
        ),
      );
      expect(s.migratedFrom, isNull);
      await _settle();
      expect(repo.writeCount, 3); // hẹn giờ do restore đã bị huỷ
      store.dispose();

      final again = await CitySaveStore.load(repo, clock: _clock);
      expect(again.source, CitySaveSource.v3);
      expect(again.game.introSeen, isFalse);
      expect(again.game.settings.language, LanguagePref.en);
      expect(again.game.removeAds, isTrue);
      expect(again.game.iapOwned, {'removeAds'});
      expect(repo.v2, _v2);
    },
  );

  test(
    '§2.5-17 xoá dữ liệu khi chưa mua gì: không tự thêm đồ, iap lạ vẫn giữ',
    () async {
      final v3 = jsonEncode(
        CitySave(
          coins: 50,
          iap: {'starterPack', 'goi_moi'},
          extra: {'tinhNangMoi': 1},
        ).toJson(_now),
      );
      final repo = MemoryCitySaveRepository(v3: v3);
      final store = await CitySaveStore.load(repo, clock: _clock);
      await store.resetAll();
      final s = _stored(repo);
      expect(s.removeAds, isFalse);
      expect(s.iap, {'starterPack', 'goi_moi'});
      expect(s.coins, 1500);
      expect(s.extra, isEmpty);
      store.dispose();
    },
  );

  test('§2.5-20 quảng cáo thưởng lưu theo ngày', () async {
    final repo = MemoryCitySaveRepository();
    final store = await CitySaveStore.load(repo, clock: _clock);
    store.attachAutosave();
    for (var i = 0; i < 3; i++) {
      store.game.registerRewardedShown();
    }
    await store.flush();
    store.dispose();
    final same = await CitySaveStore.load(repo, clock: _clock);
    expect(same.game.rewardedToday, 3);
    _now = DateTime(2026, 11, 5, 9);
    final next = await CitySaveStore.load(repo, clock: _clock);
    expect(next.game.rewardedToday, 0);
    expect(next.game.canShowRewarded, isTrue);
  });
}
