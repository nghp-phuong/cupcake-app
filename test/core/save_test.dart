import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

void main() {
  _prefsTests();
  test('ván mới đúng mặc định và JSON đúng khuôn', () {
    final s = GameState.newGame(clock: _clock);
    expect(s.coins, Economy.startCoins);
    expect(s.gems, Economy.startGems);
    expect(s.level, 1);
    expect(s.dayNumber, 1);
    expect(s.quests.length, 3);
    expect(s.quests.map((q) => q.type).toSet().length, 3);
    final json = s.toJson();
    expect(json['v'], 1);
    expect(json['questDate'], '2026-10-27');
    expect(json['adDate'], '2026-10-27');
    expect(json['lang'], 'system');
    expect(json['loginDate'], isNull);
    expect(json['lastInterstitialDay'], isNull);
    expect((json['decorEquipped'] as Map).length, 5);
    expect(jsonDecode(jsonEncode(json)), json);
  });

  test('round-trip JSON giữ nguyên dữ liệu', () {
    final s = GameState.newGame(clock: _clock);
    s.addXp(250);
    s.addCoins(1000);
    s.addGems(40);
    s.buyOvenUpgrade();
    s.buyToolUpgrade(ToolId.tongs);
    s.buyDecor(DecorId.wallpaperStripes);
    s.buyDecor(DecorId.windowSeaView);
    s.equipDecor(DecorSlot.window, DecorId.windowSeaView);
    s.markSceneSeen(StorySceneId.prologue);
    s.markTutorialSeen(StationId.bake);
    s.setLanguage(LanguagePref.vi);
    s.setSound(false);
    s.claimLogin();
    s.registerRewardedShown();
    s.registerInterstitialShown(4);
    s.grantIap(IapProductId.removeAds);
    s.completeDay();

    final text = jsonEncode(s.toJson());
    final back = GameState.fromJson(jsonDecode(text) as Map<String, dynamic>, clock: _clock);
    expect(back.toJson(), s.toJson());
    expect(back.level, 3);
    expect(back.ovenLevel, 2);
    expect(back.toolLevel(ToolId.tongs), 2);
    expect(back.equippedDecor[DecorSlot.window], DecorId.windowSeaView);
    expect(back.decorTipBonusPct, 6);
    expect(back.language, LanguagePref.vi);
    expect(back.soundOn, isFalse);
    expect(back.removeAds, isTrue);
    expect(back.rewardedToday, 1);
    expect(back.lastInterstitialDay, 4);
    expect(back.pendingLoginReward, isNull);
    expect(back.dayNumber, 2);
  });

  test('thiếu trường → mặc định', () {
    final s = GameState.fromJson({'v': 1, 'coins': 777}, clock: _clock);
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
    final raw = jsonEncode({'v': 1, 'coins': 4321, 'gems': 'x', 'day': 7});
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
