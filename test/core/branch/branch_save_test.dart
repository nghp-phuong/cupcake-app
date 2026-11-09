// §7-10 save, §7-11 store (docs/v3/city-gd4-spec.md §2 "Save").
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/branch_state.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';

import 'branch_test_helpers.dart';

/// Quá `CitySaveStore.autosaveDelay`.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 450));

Map<String, dynamic> _wire(CitySave s, FakeTime t) =>
    jsonDecode(jsonEncode(s.toJson(t.wall))) as Map<String, dynamic>;

CitySave _stored(MemoryCitySaveRepository repo) => CitySave.decode(jsonDecode(repo.v3!)).save;

BranchBook _book(int clock) => BranchBook(
  clock: clock,
  lots: {
    's1': const BranchState(
      lotId: 's1',
      level: 2,
      tillMilli: 845123,
      boughtAt: 1762200000000,
      earned: 12345,
      adDate: '2026-11-05',
    ),
    's3': const BranchState(lotId: 's3', boughtAt: 1762250000000),
  },
  staff: [
    const StaffMember(id: 'ami', lotId: 's1', since: 1762250000000),
    const StaffMember(id: 'hanh', lotId: 's3', since: 1762260000000),
  ],
);

void main() {
  group('§7-10 decode / toJson', () {
    test('lưu rồi nạp lại giữ nguyên; JSON thô vẫn là Map / List, đúng dạng đặc tả', () {
      final t = FakeTime();
      final s = CitySave(coins: 50, branches: _book(1762300000000));
      final j = _wire(s, t);
      expect(j['branches'], isA<Map>());
      expect(j['staff'], isA<List>());
      expect(j['branches'], {
        'clock': 1762300000000,
        'lots': {
          's1': {'lv': 2, 'till': 845123, 'bought': 1762200000000, 'earned': 12345, 'ad': '2026-11-05'},
          's3': {'lv': 1, 'till': 0, 'bought': 1762250000000, 'earned': 0, 'ad': ''},
        },
      });
      expect(j['staff'], [
        {'id': 'ami', 'lot': 's1', 'since': 1762250000000},
        {'id': 'hanh', 'lot': 's3', 'since': 1762260000000},
      ]);
      final r = CitySave.decode(j);
      expect(r.bad, isEmpty);
      expect(r.save, s.copyWith(savedAt: t.ms));
      expect(r.save.hashCode, s.copyWith(savedAt: t.ms).hashCode);
      // Qua CityGame (đồng hồ đơn điệu đứng yên, chưa resume) cũng y nguyên.
      final g = branchGame(t)..restore(s);
      expect(g.toSave(), s);
      expect(g.branches.owned, ['s1', 's3']);
      expect(g.branches.staffAt('s3').single.id, 'hanh');
    });

    test('save GĐ3 ({} / []) và thiếu khoá → sổ rỗng, không hỏng', () {
      for (final (b, st) in <(Object?, Object?)>[(null, null), (<String, Object?>{}, <Object?>[])]) {
        final r = BranchBook.decode(b, st);
        expect(r.bad, isEmpty);
        expect(r.book, BranchBook());
      }
      final gd3 = CitySave.decode({
        'v': 3,
        'wallet': {'coins': 9},
        'branches': <String, Object?>{},
        'staff': <Object?>[],
      });
      expect(gd3.bad, isEmpty);
      expect(gd3.save.branches, BranchBook());
      expect(gd3.save.coins, 9);
      // Lô thiếu trường → mặc định từng trường.
      final r = BranchBook.decode({
        'clock': 7,
        'lots': {'s1': <String, Object?>{}},
      }, null);
      expect(r.bad, isEmpty);
      expect(r.book, BranchBook(clock: 7, lots: {'s1': const BranchState(lotId: 's1')}));
    });

    test('sai kiểu → mặc định, ghi đúng đường dẫn; mục khác giữ', () {
      final cases = <(Object?, Object?, List<String>)>[
        ('x', null, ['branches']),
        (null, {'a': 1}, ['staff']),
        ({'clock': 'x'}, null, ['branches.clock']),
        ({'lots': [1]}, null, ['branches.lots']),
        ({'lots': {'s1': 5}}, null, ['branches.s1']),
        ({'lots': {'s1': {'lv': 'x'}}}, null, ['branches.s1.lv']),
        ({'lots': {'s1': {'till': true}}}, null, ['branches.s1.till']),
        ({'lots': {'s1': {'till': double.nan}}}, null, ['branches.s1.till']),
        ({'lots': {'s1': {'bought': []}}}, null, ['branches.s1.bought']),
        ({'lots': {'s1': {'earned': '1'}}}, null, ['branches.s1.earned']),
        ({'lots': {'s1': {'ad': 5}}}, null, ['branches.s1.ad']),
        (null, [5], ['staff.0']),
        (null, [{'id': 1, 'lot': 's1'}], ['staff.0']),
        (null, [{'id': 'ami'}], ['staff.0']),
        ({'lots': {'s1': {}}}, [{'id': 'ami', 'lot': 's1', 'since': 'x'}], ['staff.ami.since']),
      ];
      for (final (b, st, want) in cases) {
        expect(BranchBook.decode(b, st).bad, want, reason: '$b / $st');
      }
      final r = BranchBook.decode({
        'clock': 9,
        'lots': {
          's1': {'lv': 'x', 'till': 5000},
          's3': {'lv': 3},
        },
      }, null);
      expect(r.book.clock, 9);
      expect(r.book.lots['s1'], const BranchState(lotId: 's1', tillMilli: 5000));
      expect(r.book.lots['s3']!.level, 3);
      // Trong CitySave: bad gộp vào danh sách chung.
      final save = CitySave.decode({
        'wallet': {'coins': 'x'},
        'branches': {
          'lots': {
            's1': {'lv': 'x'},
          },
        },
      });
      expect(save.bad, ['wallet.coins', 'branches.s1.lv']);
    });

    test('kẹp số; ad sai dạng → rỗng (không tính hỏng)', () {
      final r = BranchBook.decode(
        jsonDecode('''{"clock": -5, "lots": {
          "s1": {"lv": 0, "till": -9, "bought": 1e400, "earned": 12.7, "ad": "hôm qua"},
          "s3": {"lv": 99, "till": 1e400, "ad": "2026-13-01"}}}'''),
        null,
      );
      expect(r.bad, isEmpty);
      const top = 9007199254740991;
      expect(r.book.clock, 0);
      expect(r.book.lots['s1'], const BranchState(lotId: 's1', boughtAt: top, earned: 12));
      expect(r.book.lots['s3'], const BranchState(lotId: 's3', level: 5, tillMilli: top));
    });

    test('giữ lô và nhân viên lạ; bỏ nhân viên ở lô chưa mua, trùng id, vượt chỗ', () {
      final r = BranchBook.decode(
        {
          'clock': 1,
          'lots': {
            's1': {'lv': 1},
            's4': {'lv': 3},
            'n3': {'moi': true}, // không phải lô chi nhánh
            'q7': [1, 2],
          },
        },
        [
          {'id': 'ami', 'lot': 's1', 'since': 1},
          {'id': 'biscuit', 'lot': 's1', 'since': 2}, // s1 cấp 1 chỉ 1 chỗ
          {'id': 'hanh', 'lot': 's3', 'since': 3}, // s3 chưa mua
          {'id': 'ami', 'lot': 's4', 'since': 4}, // trùng
          {'id': 'cocoa', 'lot': 's4', 'since': 5},
          {'id': 'maple', 'lot': 'q7', 'since': 6}, // ở lô lạ → giữ
          {'id': 'pierre', 'lot': 's4', 'x': [1]}, // id lạ → giữ
        ],
      );
      expect(r.bad, ['staff.biscuit', 'staff.hanh', 'staff.ami']);
      expect(r.book.lots.keys, unorderedEquals(['s1', 's4']));
      expect(r.book.staff, const [
        StaffMember(id: 'ami', lotId: 's1', since: 1),
        StaffMember(id: 'cocoa', lotId: 's4', since: 5),
      ]);
      expect(r.book.extraLots, {
        'n3': {'moi': true},
        'q7': [1, 2],
      });
      expect(r.book.extraStaff, [
        {'id': 'maple', 'lot': 'q7', 'since': 6},
        {
          'id': 'pierre',
          'lot': 's4',
          'x': [1],
        },
      ]);
      // Ghi lại: lô lạ và nhân viên lạ còn nguyên; lô sắp theo id.
      final out = r.book.branchesJson();
      expect((out['lots'] as Map).keys.toList(), ['n3', 'q7', 's1', 's4']);
      expect(r.book.staffJson().length, 4);
      final again = BranchBook.decode(jsonDecode(jsonEncode(out)), jsonDecode(jsonEncode(r.book.staffJson())));
      expect(again.bad, isEmpty);
      expect(again.book, r.book);
      expect(() => (r.book.extraLots['n3'] as Map)['moi'] = false, throwsUnsupportedError);
    });

    test('restore kẹp két ≤ trần (cấp + thưởng nhân viên)', () {
      final t = FakeTime();
      final g = branchGame(t)
        ..restore(
          CitySave(
            branches: BranchBook(
              clock: t.ms,
              lots: {'s1': const BranchState(lotId: 's1', tillMilli: 99000000)},
              staff: [const StaffMember(id: 'ami', lotId: 's1', since: 0)],
            ),
          ),
        );
      expect(g.branches.view('s1')!.till, 1440);
      expect(g.toSave().branches.lots['s1']!.tillMilli, 1440000);
    });

    test('toSave chụp chi nhánh trước khi đọc ví (tiền quản lý gửi về có trong xu đã lưu)', () {
      final t = FakeTime();
      final g = branchGame(t, level: 10, coins: 1000)
        ..restore(
          CitySave(
            coins: 1000,
            xp: PlayerLevel.xpToReach(10),
            branches: BranchBook(
              clock: t.ms,
              lots: {'s1': const BranchState(lotId: 's1')},
              staff: [const StaffMember(id: 'hanh', lotId: 's1', since: 0)],
            ),
          ),
        );
      t.play(const Duration(hours: 2)); // 300 xu: két 225, ví 75
      expect(g.wallet.coins, 1000); // chưa trả (chưa có lần ghi nào)
      final s = g.toSave();
      expect(s.coins, 1075);
      expect(s.branches.lots['s1']!.tillMilli, 225000);
      expect(s.branches.clock, t.ms);
      expect(g.wallet.coins, 1075);
    });
  });

  group('§7-11 store', () {
    test('nạp: gọi resume (bù két theo giờ máy), chép dự phòng 1 lần khi chi nhánh hỏng', () async {
      final t = FakeTime();
      final saved = CitySave(
        coins: 10,
        dayKey: '2026-11-05',
        adsDate: '2026-11-05',
        branches: BranchBook(
          clock: t.wall.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          lots: {'s1': const BranchState(lotId: 's1')},
        ),
      );
      final raw = jsonEncode(saved.toJson(t.wall));
      final repo = MemoryCitySaveRepository(v3: raw);
      final store = await CitySaveStore.load(repo, clock: t.now, mono: t.monoNow);
      final b = store.game.branches;
      expect(store.badFields, isEmpty);
      expect(b.view('s1')!.till, 450);
      expect(b.takeAway(), const BranchAway(away: Duration(hours: 3), sold: 450));
      // Két đã đổi khi nạp → flush ghi ngay dù chưa có thao tác.
      store.attachAutosave();
      await store.flush();
      expect(repo.writeCount, 1);
      expect(_stored(repo).branches.clock, t.ms);
      expect(_stored(repo).branches.lots['s1']!.tillMilli, 450000);
      store.dispose();

      // Mục con hỏng → mặc định, chép dự phòng đúng 1 lần.
      final badRaw = jsonEncode({
        'v': 3,
        'branches': {
          'clock': t.ms,
          'lots': {
            's1': {'lv': 'x'},
          },
        },
        'staff': [7],
      });
      final r2 = MemoryCitySaveRepository(v3: badRaw);
      final s2 = await CitySaveStore.load(r2, clock: t.now, mono: t.monoNow);
      expect(s2.badFields, ['branches.s1.lv', 'staff.0']);
      expect(r2.backups, [badRaw]);
      expect(s2.game.branches.view('s1')!.level, 1);
      await s2.flush();
      final again = await CitySaveStore.load(r2, clock: t.now, mono: t.monoNow);
      expect(again.badFields, isEmpty);
      expect(r2.backups, [badRaw]);
    });

    test('tự lưu nghe chi nhánh; resetAll xoá chi nhánh và nhân viên', () async {
      final t = FakeTime();
      final repo = MemoryCitySaveRepository(
        v3: jsonEncode(
          CitySave(
            coins: 20000,
            xp: PlayerLevel.xpToReach(10),
            dayKey: '2026-11-05',
            adsDate: '2026-11-05',
          ).toJson(t.wall),
        ),
      );
      final store = await CitySaveStore.load(repo, clock: t.now, mono: t.monoNow);
      final g = store.game;
      store.attachAutosave();
      expect(g.branches.buy('s1'), BranchBuy.ok);
      expect(g.branches.hire('ami', 's1'), StaffHire.ok);
      await _settle();
      expect(repo.writeCount, 1);
      var s = _stored(repo);
      expect(s.coins, 20000 - 8000 - 3500);
      expect(s.branches.lots.keys, ['s1']);
      expect(s.branches.staff.single.id, 'ami');

      t.play(hour);
      expect(g.branches.collect('s1').coins, 180);
      await _settle();
      expect(repo.writeCount, 2);
      s = _stored(repo);
      expect(s.branches.lots['s1']!.earned, 180);
      expect(s.coins, 20000 - 8000 - 3500 + 180);

      // Chỉ chi nhánh đổi (không có quản lý nên ví không đổi) → vẫn tự lưu.
      var walletNotified = 0;
      g.wallet.addListener(() => walletNotified++);
      t.off(hour);
      g.branches.resume();
      expect(walletNotified, 0);
      await _settle();
      expect(repo.writeCount, 3);
      expect(_stored(repo).branches.lots['s1']!.tillMilli, 180000);

      await store.resetAll();
      expect(g.branches.owned, isEmpty);
      expect(g.branches.staff, isEmpty);
      s = _stored(repo);
      expect(s.branches, BranchBook());
      expect(jsonDecode(repo.v3!)['branches'], {'clock': 0, 'lots': {}});
      expect(jsonDecode(repo.v3!)['staff'], []);
      store.dispose();
    });

    test('quay lại app (CityGame.resume): sang ngày mới và bù két', () async {
      final t = FakeTime(DateTime.utc(2026, 11, 5, 20));
      final repo = MemoryCitySaveRepository(
        v3: jsonEncode(
          CitySave(
            dayKey: '2026-11-05',
            adsDate: '2026-11-05',
            branches: BranchBook(clock: t.ms, lots: {'s1': const BranchState(lotId: 's1')}),
          ).toJson(t.wall),
        ),
      );
      final store = await CitySaveStore.load(repo, clock: t.now, mono: t.monoNow);
      final g = store.game;
      store.attachAutosave();
      expect(g.branches.takeAway()!.sold, 0);
      t.off(const Duration(hours: 5)); // qua nửa đêm
      final a = g.resume();
      expect(a.sold, 750);
      expect(a.worthToast, isTrue);
      expect(g.wallet.dayNumber, 2);
      expect(g.branches.takeAway(), a);
      await store.flush();
      expect(_stored(repo).branches.lots['s1']!.tillMilli, 750000);
      store.dispose();
    });
  });
}
