import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

String _asset() => File(UnlockConfigLoader.assetPath).readAsStringSync();
final _config = UnlockConfigLoader.parse(_asset(), strict: true);
final _levels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

/// Sửa bản JSON thật rồi parse chặt; trả thông điệp lỗi.
String _errorAfter(void Function(Map<String, dynamic> json) mutate) {
  final json = jsonDecode(_asset()) as Map<String, dynamic>;
  mutate(json);
  try {
    UnlockConfigLoader.parse(jsonEncode(json), strict: true);
  } on FormatException catch (e) {
    return e.message;
  }
  fail('parse phải ném FormatException');
}

Map<String, dynamic> _unlock(Map<String, dynamic> json, String id) =>
    (json['unlocks'] as List).cast<Map<String, dynamic>>().firstWhere((u) => u['id'] == id);

Map<String, dynamic> _equipment(Map<String, dynamic> json, String id) =>
    (json['equipment'] as List).cast<Map<String, dynamic>>().firstWhere((u) => u['id'] == id);

LevelResult _win(int id, {int coins = 0}) => LevelResult(
      levelId: id,
      won: true,
      stars: 1,
      coins: coins,
      served: 0,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: 1,
    );

GameState _fresh({int coins = 0}) => GameState.fromJson({'v': 2, 'coins': coins}, clock: _clock)
  ..attachLevelConfig(_levels)
  ..attachUnlockConfig(_config);

void _clear(GameState s, int last) {
  for (var id = s.highestCompletedLevel + 1; id <= last; id++) {
    s.applyLevelResult(_win(id));
  }
}

void main() {
  group('unlocks.json thật', () {
    test('đủ 13 mục §2 đúng level / loại / hiệu ứng / ảnh, theo level tăng dần', () {
      expect([for (final u in _config.unlocks) (u.id, u.chapter, u.level, u.kind)], [
        ('case_stand', 1, 5, UnlockKind.expansion),
        ('staff_cashier', 1, 10, UnlockKind.staff),
        ('oven_2', 2, 12, UnlockKind.expansion),
        ('staff_baker', 2, 15, UnlockKind.staff),
        ('cafe_tables', 2, 18, UnlockKind.expansion),
        ('kitchen_2', 3, 22, UnlockKind.expansion),
        ('staff_waiter', 3, 25, UnlockKind.staff),
        ('staff_baker_2', 3, 28, UnlockKind.staff),
        ('garden', 3, 30, UnlockKind.expansion),
        ('staff_manager', 4, 32, UnlockKind.staff),
        ('floor_2', 4, 35, UnlockKind.expansion),
        ('staff_training', 5, 41, UnlockKind.staffUpgrade),
        ('rare_decor', 5, 45, UnlockKind.decorSet),
      ]);
      expect(_config.unlock('case_stand')!.effect, {'caseSlots': 1});
      expect(_config.unlock('oven_2')!.effect, {'ovens': 1});
      expect(_config.unlock('cafe_tables')!.effect, {'patienceMult': 1.15, 'maxQueue': 2});
      expect(_config.unlock('kitchen_2')!.effect, {'prepSlots': 1});
      expect(_config.unlock('garden')!.effect, {'tipPct': 5, 'maxQueue': 2});
      expect(_config.unlock('floor_2')!.effect, {'counterSpots': 1, 'maxQueue': 3, 'spawnRatePct': 10});
      expect(_config.unlock('case_stand')!.artPath, 'assets/art/level/case_stand.webp');
      expect(_config.unlock('oven_2')!.art, 'items/oven_2');
      expect(_config.unlock('cafe_tables')!.art, 'level/cafe_table');
      expect(_config.unlock('garden')!.artPath, isNull);
      expect(_config.unlock('case_stand')!.comingSoon, isFalse);
      expect(_config.unlock('staff_cashier')!.comingSoon, isFalse, reason: 'GĐ4: nhân viên mua được');
      expect(_config.unlock('staff_training')!.comingSoon, isTrue);
      expect(_config.unlock('kitchen_2')!.comingSoon, isTrue, reason: 'chỉ có prepSlots (chưa hỗ trợ)');
      expect([for (final u in _config.unlocks) if (!u.comingSoon) u.id], [
        'case_stand',
        'staff_cashier',
        'oven_2',
        'staff_baker',
        'cafe_tables',
        'staff_waiter',
        'staff_baker_2',
        'garden',
        'staff_manager',
        'floor_2',
      ]);
      expect(_config.unlocksInChapter(2).map((u) => u.id), ['oven_2', 'staff_baker', 'cafe_tables']);
      for (final u in _config.unlocks) {
        expect(u.price, greaterThan(0), reason: u.id);
        for (final lang in ['en', 'vi']) {
          expect(u.name(lang), isNotEmpty, reason: '${u.id} $lang');
          expect(u.desc(lang), isNotEmpty, reason: '${u.id} $lang');
          expect(u.desc(lang), isNot(contains('★')), reason: u.id);
        }
      }
      expect(_config.unlock('case_stand')!.name('vi'), 'Kệ bánh nhiều tầng');
      expect(_config.unlock('case_stand')!.name('fr'), 'Tiered Cake Stand', reason: 'thiếu ngôn ngữ → en');
    });

    test('thiết bị §3: 7 dòng, cấp 1 có sẵn, thông số theo bảng, ảnh có sẵn', () {
      expect(_config.equipment.map((e) => e.id),
          ['fastOven', 'bigTray', 'wideCase', 'goldenOven', 'whisk', 'pipingBag', 'tongs']);
      List<num> values(String id) => [for (final t in _config.equipmentById(id)!.tiers) t.value];
      expect(values('fastOven'), [7, 6.3, 5.6, 5.0]);
      expect(values('bigTray'), [3, 4, 5]);
      expect(values('wideCase'), [6, 8, 10]);
      expect(values('goldenOven'), [0.05, 0.06, 0.07, 0.08, 0.10]);
      expect(values('whisk'), [0.10, 0.15, 0.20]);
      for (final e in _config.equipment) {
        expect((e.tiers.first.level, e.tiers.first.price), (0, 0), reason: e.id);
        expect(e.artPath, isNotNull, reason: e.id);
        expect(File(e.artPath!).existsSync(), isTrue, reason: '${e.id}: ${e.artPath}');
        for (var k = 1; k < e.tiers.length; k++) {
          expect(e.tiers[k].level, inInclusiveRange(2, 19), reason: '${e.id} cấp ${k + 1}');
          expect(e.tiers[k].price, greaterThan(e.tiers[k - 1].price), reason: '${e.id} cấp ${k + 1}');
        }
      }
      for (final u in _config.unlocks) {
        if (u.artPath != null) expect(File(u.artPath!).existsSync(), isTrue, reason: u.artPath);
      }
      expect(_config.equipmentById('fastOven')!.tier(99).value, 5.0);
      expect(_config.equipmentById('nope'), isNull);
    });

    test('mọi mở rộng mua được có ít nhất một hiệu ứng ShopSetup hỗ trợ', () {
      for (final u in _config.unlocks) {
        if (u.kind != UnlockKind.expansion || u.comingSoon) continue;
        expect(u.effect.keys.where(UnlockEffects.supported.contains), isNotEmpty, reason: u.id);
      }
    });

    test('khoan dung đọc bản thật y như chặt', () {
      final lenient = UnlockConfigLoader.parse(_asset(), strict: false, onSkip: (r) => fail(r));
      expect(lenient.unlocks.length, 13);
      expect(lenient.equipment.length, 7);
    });
  });

  group('loader chặt: lỗi ghi rõ id + trường', () {
    test('JSON hỏng / gốc sai', () {
      expect(() => UnlockConfigLoader.parse('{', strict: true), throwsFormatException);
      expect(() => UnlockConfigLoader.parse('[]', strict: false), throwsFormatException);
    });
    test('thiếu trường', () {
      expect(_errorAfter((j) => _unlock(j, 'oven_2').remove('price')), allOf(contains('oven_2'), contains('"price"')));
      expect(_errorAfter((j) => _unlock(j, 'garden').remove('name')), allOf(contains('garden'), contains('"name"')));
      expect(_errorAfter((j) => (_unlock(j, 'garden')['desc'] as Map).remove('vi')), contains('thiếu bản "vi"'));
      expect(_errorAfter((j) => _equipment(j, 'bigTray').remove('tiers')), allOf(contains('bigTray'), contains('"tiers"')));
    });
    test('sai kiểu / sai miền', () {
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['kind'] = 'robot'), contains('"kind"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['level'] = 'mười'), contains('"level"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['price'] = -5), contains('"price"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['effect'] = {'ovens': 1.5}), contains('"ovens"'));
      expect(_errorAfter((j) => _unlock(j, 'cafe_tables')['effect'] = {'patienceMult': 0}), contains('"patienceMult"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['effect'] = {'oven': 1}), contains('hiệu ứng lạ'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['art'] = 'oven 2.webp'), contains('"art"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['id'] = 'eq:oven'), contains('"id"'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['prise'] = 1), contains('trường lạ'));
      expect(_errorAfter((j) => _unlock(j, 'oven_2')['id'] = 'case_stand'), contains('trùng id'));
      expect(_errorAfter((j) => (_equipment(j, 'bigTray')['tiers'] as List)[0]['price'] = 10), contains('cấp 1 có sẵn'));
      expect(_errorAfter((j) => (_equipment(j, 'bigTray')['tiers'] as List)[2]['level'] = 1),
          contains('không giảm'));
      expect(_errorAfter((j) => _equipment(j, 'bigTray')['id'] = 'hugeTray'), contains('thiết bị lạ'));
      expect(_errorAfter((j) => j['unlockz'] = []), contains('trường lạ'));
    });
  });

  test('loader khoan dung: bỏ mục hỏng, bỏ hiệu ứng lạ, giữ thiết bị lạ, giữ phần còn lại', () {
    final json = jsonDecode(_asset()) as Map<String, dynamic>;
    _unlock(json, 'oven_2').remove('price');
    _unlock(json, 'case_stand')['effect'] = {'caseSlots': 1, 'sparkles': 3};
    _equipment(json, 'bigTray')['id'] = 'hugeTray';
    (json['equipment'] as List).add('không phải object');
    final reasons = <String>[];
    final cfg = UnlockConfigLoader.parse(jsonEncode(json), strict: false, onSkip: reasons.add);
    expect(cfg.unlock('oven_2'), isNull);
    expect(cfg.unlocks.length, 12);
    expect(cfg.unlock('case_stand')!.effect, {'caseSlots': 1});
    expect(cfg.equipmentById('hugeTray'), isNotNull);
    expect(cfg.equipment.length, 7);
    expect(reasons, hasLength(4));
    expect(reasons.join('\n'), allOf(contains('oven_2'), contains('sparkles'), contains('hugeTray')));
  });

  test('loadOrEmpty: thiếu asset → cấu hình rỗng, không ném', () async {
    final cfg = await UnlockConfigLoader.loadOrEmpty(_EmptyBundle());
    expect(cfg.isEmpty, isTrue);
    expect(UnlockConfig.empty().unlock('case_stand'), isNull);
  });

  test('UnlockKeys: eq:<id>:<cấp>', () {
    expect(UnlockKeys.equipment('fastOven', 2), 'eq:fastOven:2');
    expect(UnlockKeys.parseEquipment('eq:fastOven:2'), (id: 'fastOven', tier: 2));
    expect(UnlockKeys.isEquipment('case_stand'), isFalse);
    expect(UnlockKeys.parseEquipment('case_stand'), isNull);
    expect(UnlockKeys.parseEquipment('eq:fastOven:x'), isNull);
  });

  group('mua mở khoá (buyUnlock / unlockState)', () {
    test('đủ trạng thái: locked → available → notEnoughCoins → ok → owned / alreadyOwned; comingSoon; id lạ', () {
      final s = _fresh();
      final price = _config.unlock('case_stand')!.price;
      expect(s.unlockState('case_stand'), UnlockState.locked);
      s.addCoins(100000);
      expect(s.buyUnlock('case_stand'), PurchaseResult.locked);
      _clear(s, 4);
      expect(s.unlockState('case_stand'), UnlockState.locked);
      _clear(s, 5);
      expect(s.unlockState('case_stand'), UnlockState.available);
      s.trySpendCoins(s.coins - (price - 1));
      expect(s.buyUnlock('case_stand'), PurchaseResult.notEnoughCoins);
      expect(s.coins, price - 1);
      s.addCoins(1);
      var notified = 0;
      s.addListener(() => notified++);
      expect(s.buyUnlock('case_stand'), PurchaseResult.ok);
      expect(notified, 1);
      expect(s.coins, 0);
      expect(s.unlockState('case_stand'), UnlockState.owned);
      expect(s.buyUnlock('case_stand'), PurchaseResult.alreadyOwned);
      expect(s.shopSetup.owns('case_stand'), isTrue);

      _clear(s, 10);
      s.addCoins(100000);
      expect(s.unlockState('staff_cashier'), UnlockState.available, reason: 'GĐ4: thuê được');
      expect(s.unlockState('staff_baker'), UnlockState.locked);
      expect(s.unlockState('staff_training'), UnlockState.comingSoon);
      expect(s.buyUnlock('staff_training'), PurchaseResult.comingSoon);
      _clear(s, 22);
      expect(s.unlockState('kitchen_2'), UnlockState.comingSoon);
      expect(s.buyUnlock('kitchen_2'), PurchaseResult.comingSoon);
      expect(s.unlockState('nope'), UnlockState.locked);
      expect(s.buyUnlock('nope'), PurchaseResult.locked);
    });

    test('giá kim cương (nếu có): thiếu → notEnoughGems, không trừ xu', () {
      final json = jsonDecode(_asset()) as Map<String, dynamic>;
      _unlock(json, 'case_stand')['gemPrice'] = 50;
      final cfg = UnlockConfigLoader.parse(jsonEncode(json), strict: true);
      final s = GameState.fromJson({'v': 2, 'coins': 99999, 'gems': 10}, clock: _clock)
        ..attachLevelConfig(_levels)
        ..attachUnlockConfig(cfg);
      _clear(s, 5);
      expect(s.buyUnlock('case_stand'), PurchaseResult.notEnoughGems);
      expect(s.coins, 99999);
      s.addGems(40);
      expect(s.buyUnlock('case_stand'), PurchaseResult.ok);
      expect(s.gems, 0);
      expect(s.coins, 99999 - cfg.unlock('case_stand')!.price);
    });
  });

  group('thiết bị (buyEquipment / equipmentTier)', () {
    test('đủ trạng thái: locked → notEnoughCoins → ok → … → maxed; cấp áp vào shopSetup', () {
      final s = _fresh(coins: 100000);
      expect(s.equipmentTier('fastOven'), 1);
      expect(s.buyEquipment('fastOven'), PurchaseResult.locked);
      _clear(s, 3);
      s.trySpendCoins(s.coins);
      expect(s.buyEquipment('fastOven'), PurchaseResult.notEnoughCoins);
      s.addCoins(100000);
      expect(s.buyEquipment('fastOven'), PurchaseResult.ok);
      expect(s.equipmentTier('fastOven'), 2);
      expect(s.shopSetup.ovenSec, 6.3);
      expect(s.buyEquipment('fastOven'), PurchaseResult.locked); // cấp 3: qua L8
      _clear(s, 14);
      expect(s.buyEquipment('fastOven'), PurchaseResult.ok);
      expect(s.buyEquipment('fastOven'), PurchaseResult.ok);
      expect(s.buyEquipment('fastOven'), PurchaseResult.maxed);
      expect(s.shopSetup.ovenSec, 5.0);
      expect(s.shopSetup.equipmentTiers['fastOven'], 4);
      expect(s.buyEquipment('bigTray'), PurchaseResult.ok);
      expect(s.buyEquipment('wideCase'), PurchaseResult.ok);
      expect((s.shopSetup.batchSize, s.shopSetup.slotCapacity), (4, 8));
    });

    test('ovenArtLevel = max(cấp fastOven, cấp goldenOven), kẹp 1..5', () {
      expect(ShopSetup.base.ovenArtLevel, 1);
      expect(const ShopSetup(equipmentTiers: {'fastOven': 3}).ovenArtLevel, 3);
      expect(const ShopSetup(equipmentTiers: {'fastOven': 2, 'goldenOven': 4}).ovenArtLevel, 4);
      expect(const ShopSetup(equipmentTiers: {'fastOven': 4, 'goldenOven': 1}).ovenArtLevel, 4);
      expect(const ShopSetup(equipmentTiers: {'goldenOven': 9}).ovenArtLevel, 5);
      expect(const ShopSetup(equipmentTiers: {'fastOven': 0}).ovenArtLevel, 1);

      final s = _fresh(coins: 100000);
      expect(s.shopSetup.ovenArtLevel, 1);
      _clear(s, 8);
      expect(s.buyEquipment('fastOven'), PurchaseResult.ok);
      expect(s.shopSetup.ovenArtLevel, 2);
      expect(s.buyEquipment('goldenOven'), PurchaseResult.ok);
      expect(s.buyEquipment('goldenOven'), PurchaseResult.ok);
      expect(s.shopSetup.ovenArtLevel, 3);
      final v1 = GameState.fromJson({'v': 2, 'oven': 5}, clock: _clock)..attachUnlockConfig(_config);
      expect(v1.shopSetup.ovenArtLevel, 5, reason: 'lò V1 cấp 5 (goldenOven)');
    });

    test('mở rộng không có hiệu ứng hỗ trợ (rỗng / chỉ khoá reserved) → "Sắp có"; có một khoá hỗ trợ → mua được', () {
      UnlockData exp(Map<String, num> effect) => UnlockData(
          id: 'x', chapter: 1, level: 1, kind: UnlockKind.expansion, price: 1, effect: effect, names: const {}, descs: const {});
      expect(exp(const {}).comingSoon, isTrue);
      expect(exp(const {UnlockEffects.prepSlots: 1}).comingSoon, isTrue);
      expect(exp(const {UnlockEffects.prepSlots: 1, UnlockEffects.tipPct: 2}).comingSoon, isFalse);
      expect(exp(const {UnlockEffects.caseSlots: 1}).comingSoon, isFalse);
    });

    test('shopSetup cộng dồn hiệu ứng mở rộng đã mua, bỏ qua mục "Sắp có" và hiệu ứng chưa hỗ trợ', () {
      final s = _fresh(coins: 1000000);
      expect(s.shopSetup.equipmentTiers.keys, containsAll(['fastOven', 'bigTray', 'wideCase', 'goldenOven']));
      _clear(s, 20);
      for (final id in ['case_stand', 'oven_2', 'cafe_tables']) {
        expect(s.buyUnlock(id), PurchaseResult.ok, reason: id);
      }
      final setup = s.shopSetup;
      expect(setup.caseSlotsBonus, 1);
      expect(setup.ovens, 2);
      expect(setup.patienceMult, closeTo(1.15, 1e-9));
      expect(setup.maxQueueBonus, 2);
      expect(setup.counterSpotsBonus, 0);
      expect(setup.tipPct, 0);
      expect(setup.owned, {'case_stand', 'oven_2', 'cafe_tables'});

      // Mục của chương sau (đọc từ bản lưu): garden + floor_2 áp; kitchen_2 (prepSlots) bỏ qua; nhân viên bỏ qua.
      final late = GameState.fromJson({
        'v': 2,
        'shop': {
          'owned': ['garden', 'floor_2', 'kitchen_2', 'staff_cashier'],
        },
      }, clock: _clock)
        ..attachUnlockConfig(_config);
      final l = late.shopSetup;
      expect((l.tipPct, l.maxQueueBonus, l.counterSpotsBonus, l.spawnRatePct, l.ovens), (5, 5, 1, 10, 1));
    });
  });

  group('newUnlocks / unseenUnlocks / markUnlocksSeen', () {
    test('newUnlocks đúng lúc tới mốc (chỉ mục mua được: mở rộng, cấp thiết bị), theo level', () {
      final s = _fresh();
      expect(s.applyLevelResult(_win(1)).newUnlocks, isEmpty);
      expect(s.applyLevelResult(_win(2)).newUnlocks, ['eq:goldenOven:2']);
      expect(s.applyLevelResult(_win(3)).newUnlocks, ['eq:fastOven:2', 'eq:tongs:2']);
      expect(s.applyLevelResult(_win(4)).newUnlocks, ['eq:whisk:2']);
      expect(s.applyLevelResult(_win(5)).newUnlocks, ['case_stand']);
      _clear(s, 9);
      expect(s.applyLevelResult(_win(10)).newUnlocks, ['staff_cashier', 'eq:tongs:3'], reason: 'GĐ4: nhân viên báo mở');
      // Chơi lại level đã qua: không có gì mới.
      expect(s.applyLevelResult(_win(10)).newUnlocks, isEmpty);
      // Thua (không qua level mới): không có gì mới.
      final lose = s.applyLevelResult(LevelResult(
        levelId: 11,
        won: false,
        stars: 0,
        coins: 0,
        served: 0,
        lost: 0,
        specialsDone: 0,
        bestCombo: 0,
        perfectBakes: 0,
        recipeStars: const {},
      ));
      expect(lose.newUnlocks, isEmpty);
    });

    test('cấp đã sở hữu (vd. lò V1 cấp cao) không báo là mới', () {
      final s = GameState.fromJson({'v': 2, 'oven': 5}, clock: _clock)
        ..attachLevelConfig(_levels)
        ..attachUnlockConfig(_config);
      _clear(s, 5);
      expect(s.unseenUnlocks, isNot(contains(startsWith('eq:goldenOven'))));
      final d = s.applyLevelResult(_win(6));
      expect(d.newUnlocks, ['eq:pipingBag:2']);
    });

    test('unseenUnlocks: chỉ mục mua được ngay chưa xem (cấp kế của thiết bị), theo level; markUnlocksSeen xoá', () {
      final s = _fresh(coins: 100000);
      expect(s.unseenUnlocks, isEmpty);
      _clear(s, 9);
      expect(s.unseenUnlocks, [
        'eq:goldenOven:2',
        'eq:fastOven:2',
        'eq:tongs:2',
        'eq:whisk:2',
        'case_stand',
        'eq:pipingBag:2',
        'eq:wideCase:2',
        'eq:bigTray:2',
      ]);
      var notified = 0;
      s.addListener(() => notified++);
      s.markUnlocksSeen(['case_stand', 'eq:fastOven:2']);
      expect(notified, 1);
      s.markUnlocksSeen(['case_stand']);
      expect(notified, 1, reason: 'đã xem rồi → không notify');
      expect(s.unseenUnlocks, isNot(contains('case_stand')));
      // Mua cấp 2 → cấp 3 (đã tới mốc L8) thành mục mới chưa xem.
      expect(s.buyEquipment('fastOven'), PurchaseResult.ok);
      expect(s.unseenUnlocks, contains('eq:fastOven:3'));
      // Đã mua thì không còn trong danh sách dù chưa xem.
      expect(s.buyEquipment('bigTray'), PurchaseResult.ok);
      expect(s.unseenUnlocks, isNot(contains('eq:bigTray:2')));
      // GĐ4: nhân viên thuê được bật chấm đỏ.
      _clear(s, 10);
      expect(s.unseenUnlocks, contains('staff_cashier'));
    });
  });

  group('ShopSetup áp vào LevelSession', () {
    final level = _levels.level(12);

    LevelSession session(ShopSetup setup, {int decorTip = 0, LevelData? l}) => LevelSession(
          level: l ?? level,
          defaults: _levels.defaults,
          modifiers: BakeModifiers.base,
          decorTipBonusPct: decorTip,
          setup: setup,
          random: math.Random(1),
        );

    test('mặc định = tiệm gốc (ShopSetup.base)', () {
      final s = session(ShopSetup.base);
      expect(s.setup, same(ShopSetup.base));
      expect(s.displayCase.slots, level.caseSlots);
      expect(s.kitchen.ovens.length, 1);
      expect(s.tuning.batchSize, 3);
      expect(ShopSetup.base.applyTo(_levels.defaults), same(_levels.defaults));
    });

    test('thêm ô tủ, lò 2, mẻ, sức chứa, giây lò, hàng chờ, chỗ quầy, kiên nhẫn', () {
      const setup = ShopSetup(
        caseSlotsBonus: 1,
        ovens: 2,
        batchSize: 5,
        slotCapacity: 10,
        ovenSec: 5.0,
        maxQueueBonus: 3,
        counterSpotsBonus: 1,
        patienceMult: 1.15,
        owned: {'case_stand', 'oven_2'},
      );
      final s = session(setup);
      expect(s.setup, same(setup));
      expect(s.displayCase.slots, level.caseSlots + 1);
      expect(s.kitchen.ovens.length, 2);
      expect(s.tuning.batchSize, 5);
      expect(s.tuning.slotCapacity, 10);
      expect(s.tuning.ovenSec, closeTo(5.0, 1e-9));
      expect(s.tuning.maxQueue, _levels.defaults.maxQueue + 3);
      expect(s.tuning.counterSpots, _levels.defaults.counterSpots + 1);
      expect(s.tuning.patienceMult, closeTo(1.15, 1e-9));
      // Khách đầu tiên: kiên nhẫn × 1.15.
      while (s.customers.isEmpty) {
        s.advance(LevelSession.step);
      }
      expect(s.customers.first.patienceMax, closeTo(level.patienceSec * 1.15, 1e-6));
      s.dispose();
    });

    test('thông số áp tương đối khi level có ghi đè', () {
      const tuned = LevelDefaults(ovenSec: 8, batchSize: 4, ovens: 2, patienceMult: 0.5);
      const setup = ShopSetup(ovens: 2, batchSize: 4, ovenSec: 6.3, patienceMult: 1.2);
      final out = setup.applyTo(tuned);
      expect((out.ovens, out.batchSize), (3, 5));
      expect(out.ovenSec, closeTo(8 * 0.9, 1e-9));
      expect(out.patienceMult, closeTo(0.6, 1e-9));
    });

    test('tip mở rộng cộng với trang trí (trang trí trần 30, tổng trần 40)', () {
      expect(session(const ShopSetup(tipPct: 5), decorTip: 12).decorTipBonusPct, 17);
      expect(session(const ShopSetup(tipPct: 5), decorTip: 50).decorTipBonusPct, 35);
      expect(session(const ShopSetup(tipPct: 25), decorTip: 30).decorTipBonusPct, 40);
      expect(session(ShopSetup.base, decorTip: 50).decorTipBonusPct, 30);
    });

    test('spawnRatePct: khách tới thường hơn', () {
      int arrivals(ShopSetup setup) {
        final s = session(setup, l: _levels.level(1));
        var n = 0;
        for (var i = 0; i < 60 * 30; i++) {
          s.advance(LevelSession.step);
          n += s.drainEvents().where((e) => e.type == SessionEventType.customerArrived).length;
        }
        s.dispose();
        return n;
      }

      final base = arrivals(ShopSetup.base), faster = arrivals(const ShopSetup(spawnRatePct: 100, maxQueueBonus: 20));
      expect(faster, greaterThan(base * 1.6));
    });

    test('GameState.shopSetup thật → session (người chơi đã mua case_stand + oven_2 + thiết bị)', () {
      final s = _fresh(coins: 1000000);
      _clear(s, 14);
      s.buyUnlock('case_stand');
      s.buyUnlock('oven_2');
      for (final id in ['fastOven', 'fastOven', 'bigTray', 'wideCase']) {
        s.buyEquipment(id);
      }
      final ls = session(s.shopSetup);
      expect(ls.displayCase.slots, level.caseSlots + 1);
      expect(ls.kitchen.ovens.length, 2);
      expect((ls.tuning.batchSize, ls.tuning.slotCapacity), (4, 8));
      expect(ls.tuning.ovenSec, closeTo(5.6, 1e-9));
      expect(ls.setup.owns('oven_2'), isTrue);
      ls.dispose();
    });
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(FlutterError('không có $key'));
}
