import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

/// Bản lưu v1 đúng khuôn của app V1 (mọi khoá v1, không có `progress`), [overrides] ghi đè từng trường.
Map<String, dynamic> _v1(Map<String, dynamic> overrides) {
  // Bản v1 thật không có `progress` / `shop` (GĐ2, GĐ3), `introSeen` / `tutorialsDone` (GĐ5), các trường GĐ6.
  final json = GameState.newGame(clock: _clock).toJson()
    ..remove('progress')
    ..remove('shop')
    ..remove('introSeen')
    ..remove('tutorialsDone')
    // GĐ6.
    ..remove('boosters')
    ..remove('boosterIntro')
    ..remove('playsSinceInterstitial')
    ..remove('season')
    ..remove('frames')
    ..remove('outfits');
  json['v'] = 1;
  json.addAll(overrides);
  return json;
}

/// Bản lưu v1 giữa game (ngày 6): đủ loại dữ liệu.
Map<String, dynamic> _midGame() => _v1({
      'coins': 1234,
      'gems': 7,
      'xp': 900,
      'day': 6,
      'oven': 2,
      'tools': {'whisk': 2, 'pipingBag': 1, 'tongs': 2},
      'decorOwned': ['wallpaperStripes', 'windowSeaView'],
      'decorEquipped': {
        'wallpaper': 'wallpaperStripes',
        'floor': null,
        'counter': null,
        'window': 'windowSeaView',
        'plant': null,
      },
      'mastery': {
        'cupcakeVanilla': 3,
        'cupcakeChocolate': 2,
        'muffinBlueberry': 1,
        'eggTart': 1,
        'strawberryCake': 0,
        'macaron': 0,
        'redVelvetCupcake': 0,
        'matchaCake': 0,
        'cheesecake': 0,
        'birthdayCake': 0,
      },
      'loginStreak': 3,
      'loginDate': '2026-10-26',
      'scenes': ['prologue', 'hoa1', 'linh1', 'hoa2'],
      'tutorial': ['mould', 'mix', 'bake'],
      'lang': 'vi',
      'sound': false,
      'removeAds': true,
      'rewardedToday': 2,
      'lastInterstitialDay': 4,
      'iap': ['removeAds'],
      'served': 23,
      'mochiVisits': 1,
      'mochiPets': 1,
      'lastMochiDay': 5,
    });

/// `backupPreV2` luôn lỗi (bộ nhớ đầy / không ghi được khoá phụ).
class _PreV2FailRepository extends MemorySaveRepository {
  _PreV2FailRepository(super.initial);

  @override
  Future<void> backupPreV2(String data) async => throw StateError('pre_v2 không ghi được');
}

Map<String, dynamic> _levels(GameState s) => (s.toJson()['progress'] as Map<String, dynamic>)['levels'] as Map<String, dynamic>;

const _migrated = {'stars': 2, 'best': 0, 'plays': 1, 'firstWin': true};

void main() {
  group('quy đổi v1 → v2', () {
    test('bản v1 mới (ngày 1): không có level, nhận quà chào mừng, pre_v2 = chuỗi gốc, ghi ngay bản v2', () async {
      final raw = jsonEncode(_v1({}));
      final repo = MemorySaveRepository(raw);
      final s = await GameState.load(repo, clock: _clock);
      expect(s.savesLocked, isFalse);
      expect(s.coins, Economy.startCoins + GameState.welcomeGiftCoins);
      expect(s.gems, Economy.startGems + GameState.welcomeGiftGems);
      expect(_levels(s), isEmpty);
      expect(s.highestCompletedLevel, 0);
      expect(s.toJson()['progress'], {'levels': <String, dynamic>{}, 'migratedFromV1': true, 'welcomeGiftPending': true});
      expect(repo.preV2Backup, raw);
      expect(repo.backups, isEmpty, reason: 'bản v1 hợp lệ không phải bản hỏng');
      expect(repo.writeCount, 1);
      final written = jsonDecode(repo.data!) as Map<String, dynamic>;
      expect(written['v'], 2);
      expect(written, s.toJson());
    });

    test('giữa game ngày 6: qua L1..L5 mỗi level 2★, mọi trường v1 giữ nguyên', () async {
      final v1 = _midGame();
      final repo = MemorySaveRepository(jsonEncode(v1));
      final s = await GameState.load(repo, clock: _clock);
      final out = s.toJson();
      for (final key in v1.keys) {
        if (key == 'v' || key == 'coins' || key == 'gems' || key == 'mastery') continue;
        expect(out[key], v1[key], reason: key);
      }
      // Thuần thục: giữ nguyên 10 món cũ; món thêm sau (GĐ8) ghi 0.
      final mastery = out['mastery'] as Map<String, dynamic>;
      expect(mastery, {...v1['mastery']! as Map<String, dynamic>, for (final k in mastery.keys) if (!(v1['mastery']! as Map).containsKey(k)) k: 0});
      expect(out['v'], 2);
      expect(s.coins, 1234 + 500);
      expect(s.gems, 7 + 20);
      expect(s.xp, 900);
      expect(s.dayNumber, 6);
      expect(_levels(s), {for (var id = 1; id <= 5; id++) '$id': _migrated});
      for (var id = 1; id <= 5; id++) {
        expect(s.levelRecord(id), const LevelRecord(stars: 2, plays: 1, firstWin: true));
      }
      expect(s.levelRecord(6), isNull);
      expect(s.totalStars, 10);
      expect(s.highestCompletedLevel, 5);
      // Lò/dụng cụ V1 → thiết bị GĐ3 (trường cũ vẫn ghi).
      expect(s.equipmentTier(EquipmentIds.goldenOven), 2);
      expect(s.toolLevel(ToolId.whisk), 2);
      expect(out['shop'], {
        'owned': <String>[],
        'equipment': {'goldenOven': 2, 'pipingBag': 1, 'tongs': 2, 'whisk': 2},
        'seen': <String>[],
      });
    });

    test('cuối game (ngày 30): tối đa L1..L9', () async {
      final s = await GameState.load(MemorySaveRepository(jsonEncode(_v1({'day': 30, 'coins': 9000}))), clock: _clock);
      expect(_levels(s).keys, [for (var id = 1; id <= 9; id++) '$id']);
      expect(s.highestCompletedLevel, 9);
      expect(s.coins, 9500);
      expect(s.dayNumber, 30);
    });

    test('v1 hỏng một phần: trường hỏng về mặc định, các trường khác + quy đổi vẫn đúng, giữ cả hai bản dự phòng', () async {
      final raw = jsonEncode(_v1({'coins': 'nhiều', 'gems': 3, 'day': 4, 'scenes': 'hỏng', 'tools': {'whisk': 3}}));
      final repo = MemorySaveRepository(raw);
      final s = await GameState.load(repo, clock: _clock);
      expect(s.coins, Economy.startCoins + 500);
      expect(s.gems, 3 + 20);
      expect(s.seenScenes, isEmpty);
      expect(s.toolLevel(ToolId.whisk), 3);
      expect(_levels(s).keys, ['1', '2', '3']);
      expect(repo.preV2Backup, raw);
      expect(repo.backups, [raw]);
    });

    test('ghi → đọc lại khớp, quà không nhận lần hai', () async {
      final repo = MemorySaveRepository(jsonEncode(_midGame()));
      final first = await GameState.load(repo, clock: _clock);
      final again = await GameState.load(repo, clock: _clock);
      expect(again.toJson(), first.toJson());
      expect(again.coins, first.coins);
      expect(repo.writeCount, 1, reason: 'bản v2 không phải quy đổi nữa');
      // fromJson của bản v2 cũng không quy đổi lại.
      expect(GameState.fromJson(first.toJson(), clock: _clock).coins, first.coins);
    });

    test('bản pre_v2 đã có → không ghi đè lần hai', () async {
      final repo = MemorySaveRepository(jsonEncode(_v1({'day': 3})))..preV2Backup = 'bản cũ';
      await GameState.load(repo, clock: _clock);
      expect(repo.preV2Backup, 'bản cũ');
    });

    test('Prefs: pre_v2 ghi một lần ở khoá riêng, lần sau không đè', () async {
      final raw1 = jsonEncode(_v1({'day': 6}));
      SharedPreferences.setMockInitialValues({PrefsSaveRepository.key: raw1});
      final repo = PrefsSaveRepository();
      final s = await GameState.load(repo, clock: _clock);
      expect(s.highestCompletedLevel, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsSaveRepository.preV2Key), raw1);
      expect((jsonDecode(prefs.getString(PrefsSaveRepository.key)!) as Map)['v'], 2);

      // Một bản v1 khác xuất hiện lại ở khoá chính (vd. khôi phục sao lưu) → quy đổi lại nhưng pre_v2 giữ bản đầu.
      final raw2 = jsonEncode(_v1({'day': 9}));
      await prefs.setString(PrefsSaveRepository.key, raw2);
      await GameState.load(repo, clock: _clock);
      expect(prefs.getString(PrefsSaveRepository.preV2Key), raw1);
    });

    test('bản v2 thiếu `v` / có progress: không quy đổi, không quà', () {
      final s = GameState.fromJson({'coins': 50, 'day': 8}, clock: _clock);
      expect(s.coins, 50);
      expect(_levels(s), isEmpty);
      final v2 = GameState.fromJson({
        'v': 2,
        'coins': 50,
        'day': 8,
        'progress': {'levels': <String, dynamic>{}, 'migratedFromV1': false},
      }, clock: _clock);
      expect(v2.coins, 50);
    });

    test('v1 đã đánh dấu migratedFromV1 (không thể xảy ra, phòng hờ) → không quà lần hai', () {
      final s = GameState.fromJson(_v1({'day': 6, 'coins': 10, 'progress': {'migratedFromV1': true}}), clock: _clock);
      expect(s.coins, 10);
      expect(_levels(s), isEmpty);
    });
  });

  group('chép pre_v2 thất bại', () {
    test('khoá ghi cả phiên: bản v1 gốc còn nguyên sau load + thay đổi + autosave + flush', () async {
      final raw = jsonEncode(_midGame());
      final repo = _PreV2FailRepository(raw);
      final s = await GameState.load(repo, clock: _clock);
      expect(s.savesLocked, isTrue);
      expect(s.highestCompletedLevel, 5, reason: 'vẫn quy đổi trong bộ nhớ để chơi được');
      s.attachAutosave(repo);
      s.addCoins(100);
      s.ackWelcomeGift();
      await Future<void>.delayed(GameState.autosaveDelay * 2);
      await s.flush();
      expect(repo.data, raw);
      expect(repo.writeCount, 0);
      s.dispose();
    });
  });

  group('quà chào mừng', () {
    test('vừa quy đổi → pending; ack → lưu, đọc lại không pending', () async {
      final repo = MemorySaveRepository(jsonEncode(_midGame()));
      final s = await GameState.load(repo, clock: _clock);
      expect(s.welcomeGiftPending, isTrue);
      // Thoát trước khi kịp hiện → mở lại vẫn pending (đã ghi bản v2 ngay sau quy đổi).
      expect((await GameState.load(repo, clock: _clock)).welcomeGiftPending, isTrue);

      s.attachAutosave(repo);
      var notified = 0;
      s.addListener(() => notified++);
      s.ackWelcomeGift();
      expect(s.welcomeGiftPending, isFalse);
      expect(notified, 1);
      s.ackWelcomeGift();
      expect(notified, 1, reason: 'ack lần hai không đổi gì');
      await s.flush();
      final again = await GameState.load(repo, clock: _clock);
      expect(again.welcomeGiftPending, isFalse);
      expect(again.coins, s.coins, reason: 'không nhận quà lần hai');
      s.dispose();
    });

    test('ván mới và bản v2 không có cờ (kể cả đã quy đổi trước đó) → không pending', () async {
      expect(GameState.newGame(clock: _clock).welcomeGiftPending, isFalse);
      final fresh = await GameState.load(MemorySaveRepository(), clock: _clock);
      expect(fresh.welcomeGiftPending, isFalse);
      final oldV2 = GameState.fromJson({
        'v': 2,
        'progress': {'levels': <String, dynamic>{}, 'migratedFromV1': true},
      }, clock: _clock);
      expect(oldV2.welcomeGiftPending, isFalse);
    });

    test('cờ sai kiểu → không pending, đánh dấu hỏng (giữ bản dự phòng)', () async {
      final raw = jsonEncode({
        'v': 2,
        'coins': 42,
        'progress': {'migratedFromV1': true, 'welcomeGiftPending': 'có'},
      });
      final repo = MemorySaveRepository(raw);
      final s = await GameState.load(repo, clock: _clock);
      expect(s.welcomeGiftPending, isFalse);
      expect(s.coins, 42);
      expect(repo.backups, [raw]);
    });

    test('resetAll → không pending', () async {
      final s = await GameState.load(MemorySaveRepository(jsonEncode(_v1({}))), clock: _clock);
      expect(s.welcomeGiftPending, isTrue);
      await s.resetAll();
      expect(s.welcomeGiftPending, isFalse);
    });
  });

  group('progress v2', () {
    test('đọc từng level độc lập; id không còn trong config giữ nguyên khi lưu', () {
      final s = GameState.fromJson({
        'v': 2,
        'progress': {
          'levels': {
            '1': {'stars': 3, 'best': 12, 'plays': 4, 'firstWin': true},
            '2': {'stars': 'x', 'best': 9, 'plays': 2, 'firstWin': false},
            '3': {'stars': 9, 'best': -5, 'firstWin': 'có'},
            'abc': {'stars': 1},
            '99': {'stars': 2, 'best': 1, 'plays': 1, 'firstWin': false},
          },
          'migratedFromV1': false,
        },
      }, clock: _clock);
      expect(s.levelRecord(1), const LevelRecord(stars: 3, best: 12, plays: 4, firstWin: true));
      expect(s.levelRecord(2), const LevelRecord(stars: 0, best: 9, plays: 2));
      expect(s.levelRecord(3), const LevelRecord(stars: 3, best: 0, plays: 1));
      expect(s.levelRecord(99), const LevelRecord(stars: 2, best: 1, plays: 1));
      expect(_levels(s).keys, ['1', '2', '3', '99']);
      final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>, clock: _clock);
      expect(back.toJson(), s.toJson());
    });

    test('progress sai kiểu → bỏ, các trường khác giữ nguyên; trường hỏng → bản dự phòng', () async {
      final raw = jsonEncode({'v': 2, 'coins': 333, 'progress': 'hỏng'});
      final repo = MemorySaveRepository(raw);
      final s = await GameState.load(repo, clock: _clock);
      expect(s.coins, 333);
      expect(_levels(s), isEmpty);
      expect(repo.backups, [raw]);
      expect(repo.preV2Backup, isNull);
    });
  });
}
