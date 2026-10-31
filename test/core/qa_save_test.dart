import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';

import 'qa_helpers.dart';

/// QA việc 5: dữ liệu hỏng (JSON lỗi, thiếu trường, kiểu sai, enum lạ), quy đổi V1, thoát giữa màn rồi khởi động lại,
/// xu / kim cương = 0 và rất lớn.

const _maxInt = 9223372036854775807;

/// Ván giữa game: qua L12, có mở rộng, thiết bị, nhân viên, vật phẩm, IAP, trang trí, nhiệm vụ…
GameState _rich() {
  final s = qaState(json: {'coins': 200000, 'gems': 77});
  for (var id = 1; id <= 12; id++) {
    s.applyLevelResult(qaResult(id, stars: 1 + id % 3, coins: 300));
  }
  expect(s.buyUnlock('case_stand'), PurchaseResult.ok);
  expect(s.buyUnlock('staff_cashier'), PurchaseResult.ok);
  expect(s.buyEquipment(EquipmentIds.fastOven), PurchaseResult.ok);
  expect(s.upgradeStaff('staff_cashier', StaffStat.skill), PurchaseResult.ok);
  s.addBoosters(BoosterId.fullCase, 3);
  s.grantIap(IapProductId.removeAds);
  s.markIntroSeen();
  s.setLanguage(LanguagePref.vi);
  return s;
}

void main() {
  group('trường hỏng / sai kiểu / enum lạ', () {
    // Các nhóm khoá phụ thuộc nhau (hỏng một khoá thì khoá kia có thể đổi theo — không so).
    const linked = {
      'oven': {'shop'},
      'tools': {'shop'},
      'shop': {'oven', 'tools'},
      'questDate': {'quests'},
      'quests': {'questDate'},
      'decorOwned': {'decorEquipped'},
      'progress': {'introSeen', 'tutorialsDone', 'scenes'},
      'adDate': {'rewardedToday'},
    };
    const junk = <Object?>['rác', -7, 3.5, true, <dynamic>[1, 'x'], <String, dynamic>{'a': 1}];

    test('mỗi trường nhận lần lượt 6 kiểu rác: không ném, các trường khác giữ nguyên', () {
      final base = _rich().toJson();
      final keys = base.keys.where((k) => k != 'v').toList();
      for (final key in keys) {
        for (final value in junk) {
          final json = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
          json[key] = value;
          final GameState s;
          try {
            s = GameState.fromJson(json, clock: QaClock().call)
              ..attachLevelConfig(qaLevels)
              ..attachUnlockConfig(qaUnlocks);
          } catch (e) {
            fail('$key = $value → ném $e');
          }
          final out = s.toJson();
          for (final other in keys) {
            if (other == key || (linked[key]?.contains(other) ?? false)) continue;
            expect(jsonEncode(out[other]), jsonEncode(base[other]), reason: '$key = $value làm đổi $other');
          }
          final wantCoins = key != 'coins'
              ? base['coins']
              : (value is num ? (value < 0 ? 0 : value.toInt()) : GameState.newGame().coins);
          expect(s.coins, wantCoins, reason: '$key = $value');
        }
      }
    });

    test('thiếu mọi trường ({"v":2}) → ván mới; enum lạ bị bỏ, phần còn lại giữ', () {
      final empty = GameState.fromJson({'v': 2});
      expect(empty.coins, GameState.newGame().coins);
      final s = GameState.fromJson({
        'v': 2,
        'lang': 'klingon',
        'iap': ['bogus', 'removeAds', 42],
        'decorOwned': ['nope', 'wallpaperStripes'],
        'scenes': ['prologue', 'notAScene'],
        'boosters': {'fullCase': 2, 'megaBoost': 9},
        'progress': {
          'levels': {
            '1': {'stars': 3, 'best': 9, 'plays': 2, 'firstWin': true},
            'abc': {'stars': 3},
            '-4': {'stars': 3},
            '2': {'stars': 'ba'},
          },
        },
      });
      expect(s.language, LanguagePref.system);
      expect(s.ownedIap, {IapProductId.removeAds});
      expect(s.ownedDecor, {DecorId.wallpaperStripes});
      expect(s.seenScenes, {StorySceneId.prologue});
      expect(s.boosterCount(BoosterId.fullCase), 2);
      expect(s.levelRecord(1)!.stars, 3);
      expect(s.levelRecord(2)!.stars, 0);
      expect(s.levelRecord(-4), isNull);
    });

    test('load: JSON cụt / mảng / "null" / chuỗi rỗng / BOM → ván mới, chuỗi gốc chép dự phòng (trừ rỗng)', () async {
      final good = jsonEncode(_rich().toJson());
      for (final raw in [good.substring(0, good.length ~/ 2), '[1,2,3]', 'null', '', '﻿$good', '{"coins":}']) {
        final repo = MemorySaveRepository(raw);
        final s = await GameState.load(repo, clock: QaClock().call);
        expect(s.coins, GameState.newGame().coins, reason: raw.length > 20 ? raw.substring(0, 20) : raw);
        expect(repo.backups, raw.isEmpty ? isEmpty : [raw]);
      }
    });
  });

  group('quy đổi V1', () {
    Map<String, dynamic> v1(Map<String, dynamic> extra) => {
          'v': 1,
          'coins': 900,
          'gems': 3,
          'day': 4,
          ...extra,
        };

    test('ngày 4 → qua L1..L3 2★, +500 xu +20 kim cương đúng một lần qua 2 lần mở app', () async {
      final repo = MemorySaveRepository(jsonEncode(v1({})));
      final s = await GameState.load(repo, clock: QaClock().call);
      s.attachLevelConfig(qaLevels);
      expect((s.coins, s.gems), (900 + GameState.welcomeGiftCoins, 3 + GameState.welcomeGiftGems));
      expect([for (var id = 1; id <= 4; id++) s.levelRecord(id)?.stars], [2, 2, 2, null]);
      expect(s.welcomeGiftPending, isTrue);
      expect(repo.preV2Backup, isNotNull);
      final again = await GameState.load(repo, clock: QaClock().call);
      expect((again.coins, again.gems), (s.coins, s.gems), reason: 'không tặng quà lần hai');
    });

    test('ngày rất lớn → tối đa L9; ngày 0 / âm / sai kiểu → không level nào nhưng vẫn có quà', () {
      final big = GameState.fromJson(v1({'day': 100000}))..attachLevelConfig(qaLevels);
      expect(big.highestCompletedLevel, GameState.migrationMaxLevel);
      for (final d in <Object>[0, -3, 'abc']) {
        final s = GameState.fromJson(v1({'day': d}))..attachLevelConfig(qaLevels);
        expect(s.highestCompletedLevel, 0, reason: '$d');
        expect(s.coins, 900 + GameState.welcomeGiftCoins, reason: '$d');
      }
    });
  });

  group('thoát giữa màn rồi khởi động lại', () {
    test('vật phẩm đã trừ lúc Bắt đầu vẫn trừ; xu kiếm dở trong màn không vào ví; kỷ lục / lượt chơi không đổi', () async {
      final repo = MemorySaveRepository();
      final clock = QaClock();
      final s = qaState(clock: clock, json: {'coins': 1000});
      qaPassTo(s, 4);
      s.attachAutosave(repo);
      s.addBoosters(BoosterId.fullCase, 1);
      final coins = s.coins, plays = s.levelRecord(4)!.plays;
      expect(s.consumeBoosters({BoosterId.fullCase}), isTrue);
      final ls = qaSession(qaLevels.level(5), boosters: {BoosterId.fullCase});
      qaUntil(ls, () => qaAtCounter(ls) != null);
      final c = qaAtCounter(ls)!;
      if (ls.sell(c.id) == SellResult.sold) expect(ls.coins, greaterThan(0));
      // Thoát (app bị tắt): không applyLevelResult, UI flush khi app paused.
      await s.flush();
      ls.dispose();
      final again = await GameState.load(repo, clock: clock.call)
        ..attachLevelConfig(qaLevels);
      expect(again.boosterCount(BoosterId.fullCase), 0);
      expect(again.coins, coins);
      expect(again.levelRecord(4)!.plays, plays);
      expect(again.levelRecord(5), isNull);
    });
  });

  group('xu / kim cương ở biên', () {
    test('0 xu, 0 kim cương: mọi mua đều bị từ chối, không âm', () {
      final s = qaState(json: {'coins': 0, 'gems': 0});
      qaPassTo(s, 50);
      qaSetCoins(s, 0);
      expect(s.trySpendGems(s.gems), isTrue);
      for (final u in qaUnlocks.unlocks) {
        expect(s.buyUnlock(u.id), isNot(PurchaseResult.ok), reason: u.id);
      }
      for (final e in qaUnlocks.equipment) {
        expect(s.buyEquipment(e.id), anyOf(PurchaseResult.notEnoughCoins, PurchaseResult.maxed), reason: e.id);
      }
      expect(s.trySpendCoins(1), isFalse);
      expect(s.trySpendCoins(-5), isFalse);
      expect(s.boosterPlan({BoosterId.fullCase}), isNull, reason: 'kho 0, kim cương 0');
      s.addCoins(-100);
      expect(s.coins, 0);
      expect(s.gems, greaterThanOrEqualTo(0));
    });

    test('xu / kim cương = 2^53 − 1 (trần ví): lưu → đọc lại khớp từng đơn vị, mua được', () {
      const big = GameState.walletCap; // 2^53 − 1
      final s = qaState(json: {'coins': big, 'gems': big});
      final again = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect((again.coins, again.gems), (big, big));
      expect(again.trySpendCoins(1), isTrue);
      expect(again.coins, big - 1);
    });

    test('bản lưu xu / kim cương vượt trần (2^53, 2^63 − 1) → kẹp về 2^53 − 1', () {
      final s = qaState(json: {'coins': 9007199254740992, 'gems': _maxInt});
      expect((s.coins, s.gems), (GameState.walletCap, GameState.walletCap));
    });

    test('xu âm / số thực / chuỗi trong bản lưu → kẹp 0 / cắt phần lẻ / mặc định', () {
      expect(GameState.fromJson({'v': 2, 'coins': -50}).coins, 0);
      expect(GameState.fromJson({'v': 2, 'coins': 12.9}).coins, 12);
      expect(GameState.fromJson({'v': 2, 'coins': '500'}).coins, GameState.newGame().coins);
    });

    test('xu rất lớn (gần trần int 64-bit) + kiếm thêm → giữ ở trần ví, không tràn về 0', () {
      final s = qaState(json: {'coins': _maxInt - 10, 'gems': _maxInt - 10});
      s.applyLevelResult(qaResult(1, coins: 100));
      expect(s.coins, GameState.walletCap, reason: 'tràn int → âm → kẹp 0: mất toàn bộ xu');
      s.addGems(100);
      expect(s.gems, GameState.walletCap);
      expect(s.doubleResultCoins(qaResult(1, coins: 100)), 100);
      expect(s.coins, GameState.walletCap);
    });

    test('ví sát trần + mọi nguồn cộng (addCoins/addGems, nhân đôi, chi tiêu) → kẹp trần, chi được', () {
      final s = qaState(json: {'coins': GameState.walletCap - 5, 'gems': GameState.walletCap - 5});
      s.addCoins(1 << 62);
      s.addGems(1 << 62);
      expect((s.coins, s.gems), (GameState.walletCap, GameState.walletCap));
      expect(s.trySpendCoins(10), isTrue);
      expect(s.coins, GameState.walletCap - 10);
      s.addCoins(-(1 << 62));
      expect(s.coins, 0);
    });

    test('bản lưu xu = 1e300 (số thực khổng lồ) → nên kẹp về trần hợp lý thay vì nhận nguyên', () {
      final s = qaState(json: {'coins': 1e300, 'gems': double.infinity});
      expect((s.coins, s.gems), (GameState.walletCap, GameState.walletCap));
      s.addCoins(1);
      expect(s.coins, GameState.walletCap);
    });

    test('GameState.walletAdd: kẹp [0, 2^53 − 1], không tràn với số cộng cực lớn/âm', () {
      const cap = GameState.walletCap;
      expect(GameState.walletAdd(0, 5), 5);
      expect(GameState.walletAdd(10, -3), 7);
      expect(GameState.walletAdd(10, -30), 0);
      expect(GameState.walletAdd(cap, 1), cap);
      expect(GameState.walletAdd(cap - 1, 1), cap);
      expect(GameState.walletAdd(cap - 2, 1), cap - 1);
      expect(GameState.walletAdd(1, _maxInt), cap);
      expect(GameState.walletAdd(cap, -_maxInt - 1), 0);
    });
  });
}
