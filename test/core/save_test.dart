import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

LevelResult _result(int id, {int stars = 0, int goal = 0, int coins = 0}) => LevelResult(
      levelId: id,
      won: stars > 0,
      stars: stars,
      coins: coins,
      served: 0,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: goal,
    );

final _unlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync());

void main() {
  _prefsTests();
  _shopSaveTests();
  test('ván mới đúng mặc định và JSON đúng khuôn', () {
    final s = GameState.newGame(clock: _clock);
    expect(s.coins, Economy.startCoins);
    expect(s.gems, Economy.startGems);
    expect(s.highestCompletedLevel, 0);
    expect(s.dayNumber, 1);
    expect(s.quests.length, 3);
    expect(s.quests.map((q) => q.type).toSet().length, 3);
    final json = s.toJson();
    expect(json['v'], 2);
    expect(json['progress'], {'levels': <String, dynamic>{}, 'migratedFromV1': false, 'welcomeGiftPending': false});
    expect(json['shop'], {
      'owned': <String>[],
      'equipment': {'goldenOven': 1, 'pipingBag': 1, 'tongs': 1, 'whisk': 1},
      'seen': <String>[],
    });
    expect(json['oven'], 1);
    expect(json['questDate'], '2026-10-27');
    expect(json['adDate'], '2026-10-27');
    expect(json['lang'], 'system');
    expect(json['loginDate'], isNull);
    expect(json['lastInterstitialDay'], isNull);
    expect((json['decorEquipped'] as Map).length, 5);
    expect(jsonDecode(jsonEncode(json)), json);
  });

  test('round-trip JSON giữ nguyên dữ liệu', () {
    final s = GameState.newGame(clock: _clock)..attachUnlockConfig(_unlocks);
    s.applyLevelResult(_result(1, stars: 3, goal: 12));
    s.applyLevelResult(_result(2, stars: 2, goal: 9));
    s.applyLevelResult(_result(3, stars: 1, goal: 700));
    s.applyLevelResult(_result(3, goal: 500)); // thua: chỉ tăng lượt chơi
    for (var id = 4; id <= 8; id++) {
      s.applyLevelResult(_result(id, stars: 1, goal: 1));
    }
    s.addCoins(20000);
    s.addGems(40);
    expect(s.buyEquipment(EquipmentIds.goldenOven), PurchaseResult.ok);
    expect(s.buyEquipment('tongs'), PurchaseResult.ok);
    expect(s.buyEquipment(EquipmentIds.fastOven), PurchaseResult.ok);
    expect(s.buyEquipment(EquipmentIds.fastOven), PurchaseResult.ok);
    expect(s.buyUnlock(UnlockIds.caseStand), PurchaseResult.ok);
    s.markUnlocksSeen(['eq:wideCase:2', UnlockIds.caseStand]);
    expect(s.buyDecor(DecorId.wallpaperStripes), PurchaseResult.ok);
    expect(s.buyDecor(DecorId.windowSeaView), PurchaseResult.ok);
    s.equipDecor(DecorSlot.window, DecorId.windowSeaView);
    s.markSceneSeen(StorySceneId.prologue);
    s.markTutorialSeen(StationId.bake);
    s.setLanguage(LanguagePref.vi);
    s.setSound(false);
    s.claimLogin();
    s.registerRewardedShown();
    s.registerLevelPlayEnded();
    s.registerLevelPlayEnded();
    s.grantIap(IapProductId.removeAds);
    s.completeDay();

    final text = jsonEncode(s.toJson());
    final back = GameState.fromJson(jsonDecode(text) as Map<String, dynamic>, clock: _clock);
    expect(back.toJson(), s.toJson());
    expect(back.highestCompletedLevel, 8);
    expect(back.levelRecord(3), const LevelRecord(stars: 1, best: 700, plays: 2, firstWin: true));
    expect(back.totalStars, 11);
    expect(back.ovenLevel, 2);
    expect(back.toolLevel(ToolId.tongs), 2);
    back.attachUnlockConfig(_unlocks);
    expect(back.equipmentTier(EquipmentIds.fastOven), 3);
    expect(back.unlockState(UnlockIds.caseStand), UnlockState.owned);
    expect(back.shopSetup, s.shopSetup);
    expect(back.shopSetup.caseSlotsBonus, 1);
    expect(back.unseenUnlocks, s.unseenUnlocks);
    expect(back.unseenUnlocks, isNot(contains('eq:wideCase:2')));
    expect((back.toJson()['shop'] as Map)['seen'], ['case_stand', 'eq:wideCase:2']);
    expect(back.equippedDecor[DecorSlot.window], DecorId.windowSeaView);
    expect(back.decorTipBonusPct, 6);
    expect(back.language, LanguagePref.vi);
    expect(back.soundOn, isFalse);
    expect(back.removeAds, isTrue);
    expect(back.rewardedToday, 1);
    expect(back.playsSinceInterstitial, s.playsSinceInterstitial);
    expect(back.pendingLoginReward, isNull);
    expect(back.dayNumber, 2);
  });

  test('thiếu trường → mặc định', () {
    final s = GameState.fromJson({'v': GameState.saveVersion, 'coins': 777}, clock: _clock);
    expect(s.coins, 777);
    expect(s.gems, Economy.startGems);
    expect(s.dayNumber, 1);
    expect(s.ovenLevel, 1);
    expect(s.toolLevel(ToolId.whisk), 1);
    expect(s.language, LanguagePref.system);
    expect(s.soundOn, isTrue);
    expect(s.quests.length, 3);
  });

  test('một trường sai kiểu → chỉ trường đó về mặc định, các trường khác giữ nguyên', () {
    final s = GameState.fromJson({
      'coins': 'nhiều lắm',
      'gems': 99,
      'day': 5,
      'tools': {'whisk': 3, 'tongs': 'x'},
      'sound': 'tắt',
      'lang': 'vi',
      'scenes': 'không phải danh sách',
      'decorOwned': ['wallpaperStripes'],
    }, clock: _clock);
    expect(s.coins, Economy.startCoins);
    expect(s.gems, 99);
    expect(s.dayNumber, 5);
    expect(s.toolLevel(ToolId.whisk), 3);
    expect(s.toolLevel(ToolId.tongs), 1);
    expect(s.soundOn, isTrue);
    expect(s.language, LanguagePref.vi);
    expect(s.seenScenes, isEmpty);
    expect(s.ownedDecor, {DecorId.wallpaperStripes});
  });

  test('tên enum lạ bị bỏ qua', () {
    final s = GameState.fromJson({
      'decorOwned': ['wallpaperStripes', 'khongCo'],
      'scenes': ['prologue', 'chuong9'],
    }, clock: _clock);
    expect(s.ownedDecor, {DecorId.wallpaperStripes});
    expect(s.seenScenes, {StorySceneId.prologue});
  });

  test('load: JSON hỏng / không phải object / trống → ván mới', () async {
    for (final raw in ['{hỏng', '[1,2,3]', '', null]) {
      final s = await GameState.load(MemorySaveRepository(raw), clock: _clock);
      expect(s.coins, Economy.startCoins, reason: 'raw=$raw');
      expect(s.dayNumber, 1);
    }
  });

  test('MemorySaveRepository đọc/ghi/xoá', () async {
    final repo = MemorySaveRepository('abc');
    expect(await repo.read(), 'abc');
    await repo.write('xyz');
    expect(await repo.read(), 'xyz');
    expect(repo.writeCount, 1);
    await repo.clear();
    expect(await repo.read(), isNull);
  });

  test('autosave debounce 300ms + flush + load lại', () async {
    final repo = MemorySaveRepository();
    final s = await GameState.load(repo, clock: _clock);
    s.attachAutosave(repo);
    s.addCoins(5);
    s.addCoins(5);
    s.addCoins(5);
    expect(repo.writeCount, 0); // chưa lưu ngay
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.writeCount, 1); // gộp thành 1 lần
    s.addGems(1);
    await s.flush();
    expect(repo.writeCount, 2);
    final again = await GameState.load(repo, clock: _clock);
    expect(again.coins, Economy.startCoins + 15);
    expect(again.gems, Economy.startGems + 1);
    s.dispose();
  });

  test('resetAll xoá lưu và về ván mới', () async {
    final repo = MemorySaveRepository();
    final s = GameState.newGame(clock: _clock)..attachAutosave(repo);
    s.addCoins(500);
    await s.flush();
    expect(repo.data, isNotNull);
    await s.resetAll();
    expect(s.coins, Economy.startCoins);
    await s.flush();
    final again = await GameState.load(repo, clock: _clock);
    expect(again.coins, Economy.startCoins);
    s.dispose();
  });

  test('load: JSON hỏng → ván mới, chuỗi gốc được chép dự phòng và không bị mất khi autosave', () async {
    const raw = '{"coins": 5000, "day": 9, hỏng';
    final repo = MemorySaveRepository(raw);
    final s = await GameState.load(repo, clock: _clock);
    expect(s.coins, Economy.startCoins);
    expect(repo.backups, [raw]);
    s.attachAutosave(repo);
    s.addCoins(1);
    await s.flush();
    expect(repo.data, isNot(raw));
    expect(repo.backups, [raw]);
    s.dispose();
  });

  test('load: trường hỏng → giữ các trường khác + chép dự phòng; lưu hợp lệ → không chép', () async {
    final raw = jsonEncode({'v': GameState.saveVersion, 'coins': 4321, 'gems': 'x', 'day': 7});
    final repo = MemorySaveRepository(raw);
    final s = await GameState.load(repo, clock: _clock);
    expect(s.coins, 4321);
    expect(s.gems, Economy.startGems);
    expect(s.dayNumber, 7);
    expect(repo.backups, [raw]);

    final good = MemorySaveRepository(jsonEncode(s.toJson()));
    await GameState.load(good, clock: _clock);
    expect(good.backups, isEmpty);
  });

  test('load: v lớn hơn saveVersion → không ghi đè cả phiên; resetAll mở khoá', () async {
    final raw = jsonEncode({'v': GameState.saveVersion + 1, 'coins': 999999, 'tinhNangMoi': true});
    final repo = MemorySaveRepository(raw);
    final s = await GameState.load(repo, clock: _clock);
    expect(s.savesLocked, isTrue);
    s.attachAutosave(repo);
    s.addCoins(5);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await s.flush();
    expect(repo.writeCount, 0);
    expect(repo.data, raw);
    await s.resetAll();
    expect(s.savesLocked, isFalse);
    await s.flush();
    expect(repo.writeCount, 1);
    s.dispose();
  });

  test('load: không đọc được bộ nhớ → không ghi đè', () async {
    final repo = _FailingReadRepository();
    final s = await GameState.load(repo, clock: _clock);
    expect(s.savesLocked, isTrue);
    s.attachAutosave(repo);
    s.addCoins(5);
    await s.flush();
    expect(repo.writeCount, 0);
    s.dispose();
  });

  test('nhiệm vụ lưu không đủ 3 mục hợp lệ → 3 nhiệm vụ mới của hôm nay', () {
    final fresh = GameState.questTypesFor('2026-10-27');
    final cases = <Object?>[
      [
        {'type': 'serveCustomers', 'progress': 1},
        {'type': 'earnStars'},
      ],
      [
        {'type': 'serveCustomers'},
        {'type': 'serveCustomers'},
        {'type': 'earnStars'},
      ],
      [
        {'type': 'serveCustomers'},
        {'type': 'khongCo'},
        {'type': 'earnStars'},
      ],
      [
        {'type': 'serveCustomers'},
        'hỏng',
        {'type': 'earnStars'},
      ],
      'không phải danh sách',
    ];
    for (final quests in cases) {
      final s = GameState.fromJson({'questDate': '2026-10-20', 'quests': quests, 'coins': 321}, clock: _clock);
      expect(s.quests.map((q) => q.type).toList(), fresh, reason: '$quests');
      expect(s.quests.every((q) => q.progress == 0 && !q.claimed), isTrue);
      expect(s.toJson()['questDate'], '2026-10-27');
      expect(s.coins, 321);
    }
    // 3 mục hợp lệ thì giữ nguyên.
    final ok = GameState.fromJson({
      'questDate': '2026-10-27',
      'quests': [
        {'type': 'earnCoins', 'progress': 40, 'claimed': false},
        {'type': 'earnTips', 'progress': 2, 'claimed': true},
        {'type': 'perfectBakes', 'progress': 1},
      ],
    }, clock: _clock);
    expect(ok.quests.map((q) => q.type).toList(), [QuestType.earnCoins, QuestType.earnTips, QuestType.perfectBakes]);
    expect(ok.quests[1].claimed, isTrue);
  });
}

void _prefsTests() {
  test('PrefsSaveRepository: bản dự phòng đầu không bị đè, lần sau thêm hậu tố thời điểm', () async {
    SharedPreferences.setMockInitialValues({PrefsSaveRepository.key: '{hỏng 1'});
    final repo = PrefsSaveRepository();
    final s = await GameState.load(repo, clock: _clock);
    expect(s.coins, Economy.startCoins);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsSaveRepository.corruptKey), '{hỏng 1');
    expect(prefs.getString(PrefsSaveRepository.key), '{hỏng 1'); // chưa ghi đè cho tới khi autosave

    await prefs.setString(PrefsSaveRepository.key, '{hỏng 2');
    await GameState.load(repo, clock: _clock);
    expect(prefs.getString(PrefsSaveRepository.corruptKey), '{hỏng 1');
    final extra = prefs.getKeys().where((k) => k.startsWith('${PrefsSaveRepository.corruptKey}_')).toList();
    expect(extra, hasLength(1));
    expect(prefs.getString(extra.single), '{hỏng 2');
  });
}

class _FailingReadRepository extends MemorySaveRepository {
  @override
  Future<String?> read() async => throw StateError('bộ nhớ lỗi');
}

/// `shop` (GĐ3): đọc độc lập, bản v2 cũ không có `shop`, quy đổi lò/dụng cụ V1.
void _shopSaveTests() {
  group('shop (GĐ3)', () {
    test('bản v2 cũ (GĐ2, không có shop): lò/dụng cụ V1 thành thiết bị, chưa mua mở rộng; ghi thêm shop, giữ trường cũ',
        () {
      final s = GameState.fromJson({
        'v': 2,
        'coins': 50,
        'oven': 3,
        'tools': {'whisk': 2, 'pipingBag': 3, 'tongs': 1},
        'progress': {
          'levels': {for (var id = 1; id <= 12; id++) '$id': {'stars': 2, 'plays': 1}},
        },
      }, clock: _clock)
        ..attachUnlockConfig(_unlocks);
      expect(s.equipmentTier(EquipmentIds.goldenOven), 3);
      expect(s.ovenLevel, 3);
      expect(s.equipmentTier('whisk'), 2);
      expect(s.equipmentTier('pipingBag'), 3);
      expect(s.equipmentTier(EquipmentIds.fastOven), 1);
      expect(s.bakeModifiers.bakePerfectHalfWidth, 0.07);
      expect(s.unlockState(UnlockIds.caseStand), UnlockState.available);
      expect(s.unlockState(UnlockIds.oven2), UnlockState.available);
      expect(s.shopSetup.owned, isEmpty);
      final json = s.toJson();
      expect(json['oven'], 3);
      expect(json['tools'], {'whisk': 2, 'pipingBag': 3, 'tongs': 1});
      expect(json['shop'], {
        'owned': <String>[],
        'equipment': {'goldenOven': 3, 'pipingBag': 3, 'tongs': 1, 'whisk': 2},
        'seen': <String>[],
      });
    });

    test('cấp thiết bị = max(trường V1, shop.equipment); id lạ giữ nguyên khi ghi', () {
      final s = GameState.fromJson({
        'v': 2,
        'oven': 2,
        'tools': {'whisk': 3},
        'shop': {
          'owned': ['case_stand', 'future_room'],
          'equipment': {'goldenOven': 4, 'whisk': 1, 'fastOven': 3, 'robotMixer': 2},
          'seen': ['eq:fastOven:4'],
        },
      }, clock: _clock)
        ..attachUnlockConfig(_unlocks);
      expect(s.ovenLevel, 4);
      expect(s.toolLevel(ToolId.whisk), 3);
      expect(s.equipmentTier(EquipmentIds.fastOven), 3);
      expect(s.unlockState(UnlockIds.caseStand), UnlockState.owned);
      expect(s.unlockState('future_room'), UnlockState.locked); // không có trong config
      expect(s.shopSetup.owned, {'case_stand', 'future_room'});
      expect(s.shopSetup.caseSlotsBonus, 1);
      expect(s.shopSetup.ovenSec, closeTo(5.6, 1e-9));
      final shop = s.toJson()['shop'] as Map<String, dynamic>;
      expect(shop['owned'], ['case_stand', 'future_room']);
      expect(shop['equipment'], {'fastOven': 3, 'goldenOven': 4, 'pipingBag': 1, 'robotMixer': 2, 'tongs': 1, 'whisk': 3});
      expect(shop['seen'], ['eq:fastOven:4']);
      expect(s.toJson()['oven'], 4);
    });

    test('shop hỏng từng phần: phần tử hỏng bị bỏ, phần khác giữ; shop sai kiểu → mặc định', () async {
      final repo = MemorySaveRepository(jsonEncode({
        'v': 2,
        'coins': 321,
        'shop': {
          'owned': ['case_stand', 5, ''],
          'equipment': {'fastOven': 2, 'bigTray': 'x', 'wideCase': 99},
          'seen': 'không phải mảng',
        },
      }));
      final s = await GameState.load(repo, clock: _clock);
      s.attachUnlockConfig(_unlocks);
      expect(s.coins, 321);
      expect(s.unlockState(UnlockIds.caseStand), UnlockState.owned);
      expect(s.equipmentTier(EquipmentIds.fastOven), 2);
      expect(s.equipmentTier(EquipmentIds.bigTray), 1);
      expect(s.equipmentTier(EquipmentIds.wideCase), 3, reason: 'kẹp theo số cấp trong config');
      expect(repo.backups, hasLength(1), reason: 'trường hỏng → chuỗi gốc vào bản dự phòng');

      final wrong = GameState.fromJson({'v': 2, 'coins': 9, 'shop': ['x']}, clock: _clock);
      expect(wrong.coins, 9);
      expect(wrong.shopSetup.owned, isEmpty);
    });
  });
}
