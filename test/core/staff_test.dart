import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

/// Nhân viên (V2 GĐ4): dữ liệu `staff` trong unlocks.json, thuê / nâng trong GameState, tự làm trong LevelSession,
/// thu nhập khi vắng nhà của quản lý.

DateTime _t0 = DateTime(2026, 10, 29, 9);
DateTime _clock() => _t0;

String _asset() => File(UnlockConfigLoader.assetPath).readAsStringSync();
final _config = UnlockConfigLoader.parse(_asset(), strict: true);
final _levels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

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

Map<String, dynamic> _staffJson(Map<String, dynamic> json, String id) =>
    (json['staff'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['id'] == id);

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

/// Cấu hình level rỗng → mọi id level đều được tính (để qua được mốc L25 / L32 khi levels.json mới tới L20).
GameState _state(Map<String, dynamic> json, {bool realLevels = false}) =>
    GameState.fromJson({'v': 2, ...json}, clock: _clock)
      ..attachLevelConfig(realLevels ? _levels : LevelConfig.empty())
      ..attachUnlockConfig(_config);

void _pass(GameState s, int last) {
  for (var id = 1; id <= last; id++) {
    s.applyLevelResult(_win(id));
  }
}

// ------------------------------------------------------------------ LevelSession

const _defaults = LevelDefaults(jitterPct: 0);

LevelData _level({
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla],
  int caseSlots = 3,
  int startStock = 0,
  double patienceSec = 1000,
  double every = 10,
  int durationSec = 200,
  List<SpecialVisit> specials = const [],
  Map<String, num> overrides = const {},
}) =>
    LevelData(
      id: 5,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: durationSec,
      goal: const LevelGoal(type: GoalType.customers, stars: [1, 2, 3]),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: patienceSec,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      specials: specials,
      newRecipe: menu.last,
      overrides: overrides,
    );

StaffMember _member(StaffRole role, {double speed = 2, double skill = 0, int lane = 0, String? id}) => StaffMember(
      id: id ?? 'staff_${role.name}_$lane',
      role: role,
      character: 'staff_nora',
      speedValue: speed,
      skillValue: skill,
      lane: lane,
    );

LevelSession _session(LevelData level, List<StaffMember> staff, {int seed = 1, ShopSetup base = ShopSetup.base}) =>
    LevelSession(
      level: level,
      defaults: _defaults,
      modifiers: BakeModifiers.base,
      setup: base.withStaff(staff),
      random: math.Random(seed),
    );

List<SessionEvent> _run(LevelSession s, double sec) {
  final events = <SessionEvent>[];
  final n = (sec / LevelSession.step).round();
  for (var i = 0; i < n && !s.isOver; i++) {
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  return events;
}

List<SessionEvent> _until(LevelSession s, bool Function() cond, {double maxSec = 120}) {
  final events = <SessionEvent>[];
  final end = s.elapsed + maxSec;
  while (!cond()) {
    if (s.elapsed >= end || s.isOver) fail('quá $maxSec s mà điều kiện chưa đúng (elapsed ${s.elapsed})');
    s.advance(LevelSession.step);
    events.addAll(s.drainEvents());
  }
  return events;
}

LevelCustomer? _atCounter(LevelSession s) {
  for (final c in s.customers) {
    if (c.canBuy) return c;
  }
  return null;
}

void main() {
  group('unlocks.json: mục staff', () {
    test('5 nhân viên §2: id, ảnh, vai trò, tên en/vi, giới thiệu, 5 cấp, giá tăng dần, ảnh neutral + smile có sẵn', () {
      expect([for (final s in _config.staff) (s.id, s.character, s.role)], [
        ('staff_cashier', 'staff_nora', StaffRole.cashier),
        ('staff_baker', 'staff_bao', StaffRole.baker),
        ('staff_waiter', 'staff_theo', StaffRole.waiter),
        ('staff_baker_2', 'staff_ami', StaffRole.baker),
        ('staff_manager', 'staff_hanh', StaffRole.manager),
      ]);
      expect([for (final s in _config.staff) s.character], CustomerArt.staffSpriteIds);
      expect([for (final s in _config.staff) s.name('en')], ['Nora', 'Bao', 'Theo', 'Ami', 'Ms. Hanh']);
      expect([for (final s in _config.staff) s.name('vi')], ['Nora', 'Bảo', 'Theo', 'Ami', 'Cô Hạnh']);
      expect(_config.staffById('staff_waiter')!.requires, 'cafe_tables');
      expect(_config.staffById('staff_cashier')!.requires, isNull);
      expect(_config.staffById('nope'), isNull);
      final cashier = _config.staffById('staff_cashier')!;
      expect(cashier.speedValues, [3.2, 2.8, 2.4, 2.0, 1.6]);
      expect(_config.staffById('staff_baker')!.speedValues, [24, 21, 18, 15, 12]);
      expect(_config.staffById('staff_waiter')!.speedValues, [4, 3.5, 3, 2.5, 2]);
      expect(_config.staffById('staff_manager')!.speedValues, [0.20, 0.25, 0.30, 0.35, 0.40]);
      expect(_config.staffById('staff_manager')!.skillValues, [4, 5, 6, 7, 8]);
      expect(_config.staffById('staff_manager')!.param(StaffParams.minAwayMin, 0), 10);
      expect(cashier.value(StaffStat.speed, 99), 1.6, reason: 'kẹp cấp');
      expect(cashier.priceTo(StaffStat.speed, 1), isNull);
      expect(cashier.priceTo(StaffStat.speed, 2), cashier.speedPrices.first);
      expect(cashier.priceTo(StaffStat.speed, 6), isNull);
      for (final s in _config.staff) {
        expect(s.maxLevel, 5, reason: s.id);
        expect(_config.unlock(s.id)!.kind, UnlockKind.staff, reason: s.id);
        for (final stat in StaffStat.values) {
          final p = s.prices(stat);
          expect(p, hasLength(4), reason: '${s.id} ${stat.name}');
          for (var i = 1; i < p.length; i++) {
            expect(p[i], greaterThan(p[i - 1]), reason: '${s.id} ${stat.name}');
          }
        }
        for (final lang in ['en', 'vi']) {
          expect(s.bio(lang), isNotEmpty, reason: '${s.id} $lang');
          expect('${s.name(lang)}${s.bio(lang)}', isNot(contains('★')), reason: s.id);
        }
        expect(s.bio('vi'), matches(RegExp('[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]')),
            reason: '${s.id}: tiếng Việt đủ dấu');
        for (final e in CustomerArt.staffExpressions) {
          final path = 'assets/characters/${s.character}_${CustomerArt.spriteExpr(e)}.webp';
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
      // Hết "Sắp có" cho nhân viên (trừ đào tạo).
      for (final u in _config.unlocks) {
        if (u.kind == UnlockKind.staff) expect(u.comingSoon, isFalse, reason: u.id);
      }
      expect(_config.unlock('staff_training')!.comingSoon, isTrue);
    });

    test('khoan dung đọc bản thật y như chặt; thiếu mục staff → rỗng', () {
      final lenient = UnlockConfigLoader.parse(_asset(), strict: false, onSkip: (r) => fail('không được bỏ: $r'));
      expect(lenient.staff.map((s) => s.id), _config.staff.map((s) => s.id));
      final json = jsonDecode(_asset()) as Map<String, dynamic>..remove('staff');
      expect(UnlockConfigLoader.parse(jsonEncode(json), strict: true).staff, isEmpty);
    });

    test('chế độ chặt: lỗi ghi rõ id + trường', () {
      expect(_errorAfter((j) => _staffJson(j, 'staff_cashier')['role'] = 'chef'), allOf(contains('staff_cashier'), contains('"role"')));
      expect(_errorAfter((j) => _staffJson(j, 'staff_cashier')['id'] = 'oven_2'), contains('"kind": "staff"'));
      expect(_errorAfter((j) => (j['staff'] as List).add(_staffJson(j, 'staff_baker'))), contains('trùng id'));
      expect(_errorAfter((j) => (_staffJson(j, 'staff_baker')['speed'] as Map)['prices'] = [1, 2, 3]), contains('cần 4 giá'));
      expect(_errorAfter((j) => (_staffJson(j, 'staff_baker')['speed'] as Map)['prices'] = [5, 4, 6, 7]), contains('không giảm'));
      expect(_errorAfter((j) => (_staffJson(j, 'staff_baker')['speed'] as Map)['values'] = [24, 0, 18, 15, 12]), contains('> 0'));
      expect(_errorAfter((j) => (_staffJson(j, 'staff_baker')['skill'] as Map)['values'] = [3, 4, 5, 6, 5]), contains('1..5'));
      expect(
          _errorAfter((j) => _staffJson(j, 'staff_baker')['skill'] = {
                'values': [3, 4],
                'prices': [10],
              }),
          contains('cùng số cấp'));
      expect(_errorAfter((j) => _staffJson(j, 'staff_waiter')['requires'] = 'pool'), contains('"requires"'));
      expect(_errorAfter((j) => _staffJson(j, 'staff_manager')['params'] = {'minAwayMins': 5}), contains('tham số lạ'));
      expect(_errorAfter((j) => _staffJson(j, 'staff_manager')['salary'] = 5), contains('"salary"'));
      expect(_errorAfter((j) => _staffJson(j, 'staff_manager')['character'] = 'Staff Hanh'), contains('"character"'));
      expect(_errorAfter((j) => (_staffJson(j, 'staff_manager')['bio'] as Map).remove('vi')), contains('"bio"'));
    });

    test('khoan dung: bỏ nhân viên hỏng (ghi lý do), bỏ tham số lạ, giữ phần còn lại', () {
      final json = jsonDecode(_asset()) as Map<String, dynamic>;
      _staffJson(json, 'staff_baker')['role'] = 'chef';
      _staffJson(json, 'staff_manager')['params'] = {'minAwayMin': 15, 'oops': 1};
      final reasons = <String>[];
      final cfg = UnlockConfigLoader.parse(jsonEncode(json), strict: false, onSkip: reasons.add);
      expect(cfg.staff.map((s) => s.id), ['staff_cashier', 'staff_waiter', 'staff_baker_2', 'staff_manager']);
      expect(cfg.staffById('staff_manager')!.params, {'minAwayMin': 15});
      expect(reasons, hasLength(2));
      // Nhân viên thiếu dữ liệu → GameState coi là "Sắp có".
      final s = GameState.fromJson({'v': 2, 'coins': 99999}, clock: _clock)
        ..attachLevelConfig(LevelConfig.empty())
        ..attachUnlockConfig(cfg);
      _pass(s, 15);
      expect(s.unlockState('staff_baker'), UnlockState.comingSoon);
      expect(s.buyUnlock('staff_baker'), PurchaseResult.comingSoon);
      expect(s.unlockState('staff_cashier'), UnlockState.available);
    });
  });

  group('GameState: thuê / nâng', () {
    test('đủ trạng thái: locked → available → thuê → nâng tới maxed; notEnoughCoins; chưa thuê thì nâng = locked', () {
      final s = _state({'coins': 0}, realLevels: true);
      expect(s.isStaffHired('staff_cashier'), isFalse);
      expect(s.staffLevel('staff_cashier', StaffStat.speed), 0);
      expect(s.upgradeStaff('staff_cashier', StaffStat.speed), PurchaseResult.locked);
      expect(s.staffUpgradePrice('staff_cashier', StaffStat.speed), isNull);
      expect(s.unlockState('staff_cashier'), UnlockState.locked);
      _pass(s, 9);
      expect(s.unlockState('staff_cashier'), UnlockState.locked);
      final d = s.applyLevelResult(_win(10));
      expect(d.newUnlocks, contains('staff_cashier'));
      expect(s.unseenUnlocks, contains('staff_cashier'));
      expect(s.unlockState('staff_cashier'), UnlockState.available);
      expect(s.buyUnlock('staff_cashier'), PurchaseResult.notEnoughCoins);
      final hire = _config.unlock('staff_cashier')!.price;
      s.addCoins(hire);
      expect(s.buyUnlock('staff_cashier'), PurchaseResult.ok);
      expect(s.coins, 0);
      expect(s.isStaffHired('staff_cashier'), isTrue);
      expect(s.unlockState('staff_cashier'), UnlockState.owned);
      expect(s.staffLevel('staff_cashier', StaffStat.speed), 1);
      expect(s.staffLevel('staff_cashier', StaffStat.skill), 1);
      expect(s.shopSetup.staff, [StaffMember.of(_config.staffById('staff_cashier')!)]);

      final data = _config.staffById('staff_cashier')!;
      expect(s.staffUpgradePrice('staff_cashier', StaffStat.speed), data.speedPrices[0]);
      expect(s.upgradeStaff('staff_cashier', StaffStat.speed), PurchaseResult.notEnoughCoins);
      s.addCoins(100000);
      var notified = 0;
      s.addListener(() => notified++);
      for (var k = 2; k <= 5; k++) {
        final before = s.coins;
        expect(s.upgradeStaff('staff_cashier', StaffStat.speed), PurchaseResult.ok);
        expect(before - s.coins, data.speedPrices[k - 2]);
        expect(s.staffLevel('staff_cashier', StaffStat.speed), k);
      }
      expect(notified, 4);
      expect(s.upgradeStaff('staff_cashier', StaffStat.speed), PurchaseResult.maxed);
      expect(s.staffUpgradePrice('staff_cashier', StaffStat.speed), isNull);
      expect(s.staffLevel('staff_cashier', StaffStat.skill), 1, reason: 'hai chỉ số độc lập');
      expect(s.upgradeStaff('staff_cashier', StaffStat.skill), PurchaseResult.ok);
      final m = s.shopSetup.staff.single;
      expect((m.speed, m.skill, m.speedValue, m.skillValue), (5, 2, 1.6, 8.0));
      expect(s.upgradeStaff('nope', StaffStat.speed), PurchaseResult.locked);
    });

    test('phục vụ cần cafe_tables; quản lý không vào ShopSetup.staff; thứ tự + làn thợ cố định', () {
      final s = _state({'coins': 1 << 30});
      _pass(s, 32);
      expect(s.unlockState('staff_waiter'), UnlockState.locked);
      expect(s.staffRequirementMissing('staff_waiter'), 'cafe_tables');
      expect(s.buyUnlock('staff_waiter'), PurchaseResult.locked);
      expect(s.unseenUnlocks, isNot(contains('staff_waiter')));
      expect(s.buyUnlock('cafe_tables'), PurchaseResult.ok);
      expect(s.staffRequirementMissing('staff_waiter'), isNull);
      expect(s.unlockState('staff_waiter'), UnlockState.available);
      for (final id in ['staff_manager', 'staff_baker_2', 'staff_waiter', 'staff_baker', 'staff_cashier']) {
        expect(s.buyUnlock(id), PurchaseResult.ok, reason: id);
      }
      final staff = s.shopSetup.staff;
      expect([for (final m in staff) (m.id, m.role, m.lane)], [
        ('staff_cashier', StaffRole.cashier, 0),
        ('staff_baker', StaffRole.baker, 0),
        ('staff_waiter', StaffRole.waiter, 0),
        ('staff_baker_2', StaffRole.baker, 1),
      ]);
      expect(s.isStaffHired('staff_manager'), isTrue);
    });

    test('lưu / đọc lại cấp nhân viên; trường hỏng chỉ ảnh hưởng nhân viên đó', () {
      final s = _state({'coins': 1 << 30}, realLevels: true);
      _pass(s, 15);
      s.buyUnlock('staff_cashier');
      s.buyUnlock('staff_baker');
      s.upgradeStaff('staff_cashier', StaffStat.skill);
      s.upgradeStaff('staff_cashier', StaffStat.skill);
      s.upgradeStaff('staff_baker', StaffStat.speed);
      final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(json['staff'], {
        'staff_baker': {'speed': 2, 'skill': 1},
        'staff_cashier': {'speed': 1, 'skill': 3},
      });
      final back = GameState.fromJson(json, clock: _clock)
        ..attachLevelConfig(_levels)
        ..attachUnlockConfig(_config);
      expect(back.staffLevel('staff_cashier', StaffStat.skill), 3);
      expect(back.staffLevel('staff_baker', StaffStat.speed), 2);
      expect(back.shopSetup, s.shopSetup);

      json['staff'] = {
        'staff_cashier': {'speed': 'x', 'skill': 4},
        'staff_baker': 7,
        'staff_ghost': {'speed': 3},
      };
      final broken = GameState.fromJson(json, clock: _clock)
        ..attachLevelConfig(_levels)
        ..attachUnlockConfig(_config);
      expect(broken.staffLevel('staff_cashier', StaffStat.speed), 1);
      expect(broken.staffLevel('staff_cashier', StaffStat.skill), 4);
      expect(broken.staffLevel('staff_baker', StaffStat.speed), 1);
      expect(broken.isStaffHired('staff_baker'), isTrue, reason: 'thuê = có trong shop.owned');
      expect((broken.toJson()['staff'] as Map).containsKey('staff_ghost'), isTrue, reason: 'id lạ giữ nguyên');
      expect(broken.coins, s.coins);
    });
  });

  group('LevelSession: nhân viên tự làm', () {
    test('thu ngân: bán khách đứng quầy có món trong tủ sau speedValue giây (staffSold, combo, tip theo tay nghề)', () {
      final level = _level(startStock: 3);
      final s = _session(level, [_member(StaffRole.cashier, speed: 2)]);
      expect(s.staff, hasLength(1));
      expect(s.staff.single.member.role, StaffRole.cashier);
      _until(s, () => _atCounter(s) != null);
      final c = _atCounter(s)!;
      final arrived = s.elapsed;
      expect(s.staff.single.targetCustomer, c.id);
      final events = _until(s, () => s.staffSales == 1);
      expect(s.elapsed - arrived, closeTo(2.0, 0.1));
      final sold = events.singleWhere((e) => e.type == SessionEventType.staffSold);
      expect((sold.customerId, sold.staffIndex, sold.recipe, sold.combo), (c.id, 0, RecipeId.cupcakeVanilla, 1));
      expect(events.where((e) => e.type == SessionEventType.sold), isEmpty, reason: 'staffSold thay cho sold');
      expect(s.coins, sold.coins);
      expect(s.served, 1);
      expect(s.staff.single.actions, 1);
      expect(s.staff.single.lastActionAt, closeTo(s.elapsed, 0.05));
      expect(s.staff.single.progress, 0);

      // Tay nghề +50% tip → nhiều xu hơn cho cùng lượt bán.
      final rich = _session(level, [_member(StaffRole.cashier, speed: 2, skill: 50)]);
      final richEvents = _until(rich, () => rich.staffSales == 1);
      final richSold = richEvents.singleWhere((e) => e.type == SessionEventType.staffSold);
      expect(richSold.coins, greaterThan(sold.coins));

      while (!s.isOver) {
        s.advance(1);
      }
      expect(s.finish().staffSales, s.staffSales);
    });

    test('thu ngân: tip tay nghề cộng chung với trang trí + mở rộng, tổng vẫn chịu trần Economy.tipBonusCapPct', () {
      final level = _level(startStock: 3, menu: const [RecipeId.birthdayCake]);
      int soldCoins({required int decor, required double skill}) {
        final s = LevelSession(
          level: level,
          defaults: _defaults,
          modifiers: BakeModifiers.base,
          decorTipBonusPct: decor,
          setup: ShopSetup.base.withStaff([_member(StaffRole.cashier, speed: 2, skill: skill)]),
          random: math.Random(1),
        );
        final events = _until(s, () => s.staffSales == 1);
        return events.singleWhere((e) => e.type == SessionEventType.staffSold).coins;
      }

      // Trang trí 30% (trần riêng) + thu ngân 10% = đúng trần 40% → thu ngân tay nghề cao hơn không cộng thêm.
      final atCap = soldCoins(decor: 30, skill: 10);
      expect(soldCoins(decor: 30, skill: 50), atCap, reason: '30 + 50 → kẹp 40');
      expect(soldCoins(decor: 30, skill: 200), atCap);
      expect(atCap, greaterThan(soldCoins(decor: 0, skill: 0)), reason: 'dưới trần thì tip vẫn được cộng');
      expect(soldCoins(decor: 0, skill: 40), atCap, reason: 'chỉ thu ngân 40% = trần');
    });

    test('thu ngân: tủ không có món → không bán, tiến độ 0; người chơi bán trước → đổi khách, làm lại từ 0', () {
      final empty = _session(_level(), [_member(StaffRole.cashier, speed: 1)]);
      _until(empty, () => _atCounter(empty) != null);
      _run(empty, 5);
      expect(empty.staffSales, 0);
      expect(empty.staff.single.progress, 0);
      expect(empty.staff.single.targetCustomer, isNull);

      final s = _session(_level(startStock: 3), [_member(StaffRole.cashier, speed: 3)]);
      _until(s, () => _atCounter(s) != null);
      _run(s, 1.5);
      expect(s.staff.single.progress, closeTo(0.5, 0.05));
      expect(s.sell(_atCounter(s)!.id), SellResult.sold);
      _run(s, LevelSession.step * 2);
      expect(s.staff.single.progress, lessThan(0.05), reason: 'khách mới → làm lại từ 0');
      expect(s.staffSales, 0);
    });

    test('thợ bánh: làm món khách đang cần, cho cả mẻ vào tủ khi còn chỗ; không đụng bếp nhanh của người chơi', () {
      final level = _level(menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate], every: 4);
      final s = _session(level, [_member(StaffRole.baker, speed: 6, skill: 3)]);
      final events = _until(s, () => s.staffBakes == 1);
      final ready = events.singleWhere((e) => e.type == SessionEventType.staffBatchReady);
      expect(ready.count, s.tuning.batchSize);
      expect(ready.staffIndex, 0);
      expect(ready.stars, inInclusiveRange(2, 4));
      expect(s.displayCase.countOf(ready.recipe!), s.tuning.batchSize);
      expect(events.where((e) => e.type == SessionEventType.batchReady), isEmpty);
      expect(s.kitchen.prep, isNull);
      expect(s.kitchen.finish, isNull);
      expect(s.kitchen.ovens.every((b) => b == null), isTrue);
      expect(s.staff.single.actions, 1);
    });

    test('thợ bánh: tủ hết chỗ → không làm; có chỗ lại (bán bớt) → làm tiếp', () {
      // 1 ô × 6 cái, đầy sẵn: không còn chỗ cho mẻ 3.
      final level = _level(caseSlots: 1, startStock: 6, every: 3);
      final s = _session(level, [_member(StaffRole.baker, speed: 4, skill: 5)]);
      _until(s, () => s.customers.where((c) => !c.isLeaving).length >= 4);
      _run(s, 10);
      expect(s.staffBakes, 0);
      expect(s.staff.single.working, isNull);
      // Bán 3 cái → đủ chỗ cho một mẻ.
      for (var i = 0; i < 3; i++) {
        _until(s, () => _atCounter(s) != null);
        expect(s.sell(_atCounter(s)!.id), SellResult.sold);
      }
      // Còn khách cần hơn số đang có trong tủ → thợ bắt đầu mẻ.
      _until(s, () => s.staff.single.working != null, maxSec: 30);
      expect(s.staff.single.working, RecipeId.cupcakeVanilla);
      expect(s.staff.single.workingStars, inInclusiveRange(4, 5));
      _until(s, () => s.staffBakes == 1, maxSec: 6);
      expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), 6);
    });

    test('hai thợ không làm trùng khi tủ chỉ đủ chỗ một mẻ; sao theo tay nghề (cấp 1 chủ yếu 3★, cấp 5 chủ yếu 5★)', () {
      // Ô 6 cái: mẻ 3 + mẻ 3 vừa đủ → cả hai cùng làm (khi đủ khách cần).
      final level = _level(caseSlots: 1, every: 0.5);
      final s = _session(level, [
        _member(StaffRole.baker, speed: 60, skill: 3, lane: 0),
        _member(StaffRole.baker, speed: 60, skill: 3, lane: 1),
      ]);
      _until(s, () => s.staff.every((st) => st.working != null), maxSec: 20);
      // Ô 3 cái: chỉ đủ một mẻ → không bao giờ hai người cùng làm.
      final tight = _session(_level(caseSlots: 1, every: 0.5, overrides: const {'slotCapacity': 3}), [
        _member(StaffRole.baker, speed: 60, skill: 3, lane: 0),
        _member(StaffRole.baker, speed: 60, skill: 3, lane: 1),
      ]);
      var maxWorking = 0;
      for (var i = 0; i < 20 * 30; i++) {
        tight.advance(LevelSession.step);
        maxWorking = math.max(maxWorking, tight.staff.where((st) => st.working != null).length);
      }
      expect(maxWorking, 1);

      int share(double skill, int stars) {
        var hit = 0;
        for (var seed = 1; seed <= 60; seed++) {
          final x = _session(_level(every: 2), [_member(StaffRole.baker, speed: 1, skill: skill)], seed: seed);
          _until(x, () => x.staff.single.working != null);
          if (x.staff.single.workingStars == stars) hit++;
        }
        return hit;
      }

      expect(share(3.0, 3), greaterThanOrEqualTo(45));
      expect(share(4.8, 5), greaterThanOrEqualTo(40));
    });

    test('phục vụ: bán khách đang chờ trong hàng (chưa tới quầy); kiên nhẫn trong hàng giảm chậm hơn theo tay nghề', () {
      final level = _level(startStock: 6, every: 1, overrides: const {'counterSpots': 1, 'maxQueue': 8});
      final s = _session(level, [_member(StaffRole.waiter, speed: 2, skill: 20)]);
      expect(s.queuePatienceMult, closeTo(0.8, 1e-9));
      final queued = <int>{};
      final atCounter = <int>{};
      while (s.staffSales < 3) {
        if (s.elapsed > 60) fail('phục vụ chưa bán đủ 3 lượt');
        queued
          ..clear()
          ..addAll([for (final c in s.customers) if (c.phase == CustomerPhase.queued) c.id]);
        atCounter
          ..clear()
          ..addAll([for (final c in s.customers) if (c.phase == CustomerPhase.atCounter) c.id]);
        s.advance(LevelSession.step);
        for (final e in s.drainEvents()) {
          if (e.type != SessionEventType.staffSold) continue;
          expect(queued, contains(e.customerId), reason: 'chỉ bán khách đang chờ trong hàng');
          expect(atCounter, isNot(contains(e.customerId)));
          expect(e.staffIndex, 0);
          expect(s.customer(e.customerId)!.phase, CustomerPhase.leavingHappy);
        }
      }
      expect(s.customers.where((c) => c.phase == CustomerPhase.atCounter), isNotEmpty,
          reason: 'khách ở quầy vẫn chờ người chơi');

      // Kiên nhẫn trong hàng: không có phục vụ → 0.5/giây; phục vụ tay nghề 20% → 0.4/giây.
      double queueDrop(List<StaffMember> staff) {
        final x = _session(_level(every: 1, overrides: const {'counterSpots': 1, 'maxQueue': 8}), staff);
        _until(x, () => x.customers.where((c) => c.phase == CustomerPhase.queued && c.phaseT >= 1).length >= 2);
        final q = x.customers.lastWhere((c) => c.phase == CustomerPhase.queued);
        final id = q.id, before = q.patience;
        _run(x, 1);
        return before - x.customer(id)!.patience;
      }

      expect(queueDrop(const []), closeTo(0.5, 0.02));
      expect(queueDrop([_member(StaffRole.waiter, speed: 100, skill: 20)]), closeTo(0.4, 0.02));
    });

    test('không nhân viên nào đụng khách / đơn đặc biệt', () {
      final level = _level(
        startStock: 6,
        every: 3,
        specials: const [SpecialVisit(atSec: 2, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)],
      );
      final s = _session(level, [
        _member(StaffRole.cashier, speed: 0.5),
        _member(StaffRole.waiter, speed: 0.5, lane: 0),
        _member(StaffRole.baker, speed: 1, skill: 5),
      ]);
      _until(s, () => s.specialCustomer?.phase == CustomerPhase.atCounter);
      final special = s.specialCustomer!;
      final events = _run(s, 40);
      expect(s.specialCustomer, same(special));
      expect(special.isLeaving, isFalse);
      expect(s.specialsDone, 0);
      for (final e in events) {
        if (e.type == SessionEventType.staffSold) expect(e.customerId, isNot(special.id));
        expect(e.type, isNot(SessionEventType.specialDone));
      }
      for (final st in s.staff) {
        expect(st.targetCustomer, isNot(special.id));
      }
      expect(s.staffSales, greaterThan(0), reason: 'vẫn bán cho khách vãng lai');
    });

    test('quản lý không làm trong màn; chỉ có quản lý → chuỗi ngẫu nhiên y như không có nhân viên', () {
      final level = _level(startStock: 3, every: 3);
      final a = _session(level, const []);
      final b = _session(level, [_member(StaffRole.manager)]);
      expect(b.staff, isEmpty);
      final ea = _run(a, 60).map((e) => e.toString()).toList();
      final eb = _run(b, 60).map((e) => e.toString()).toList();
      expect(eb, ea);
    });

    test('hiệu năng: 25 khách + 10 nhân viên giả lập, 180 s mô phỏng, không cấp phát theo khung', () {
      final level = _level(
        menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry],
        durationSec: 200,
        every: 0.3,
        patienceSec: 10000,
        startStock: 6,
        caseSlots: 4,
        overrides: const {'maxQueue': 25, 'counterSpots': 2},
      );
      final staff = [
        for (var i = 0; i < 3; i++) _member(StaffRole.cashier, speed: 1.6, skill: 20, lane: i),
        for (var i = 0; i < 4; i++) _member(StaffRole.baker, speed: 12, skill: 4.8, lane: i),
        for (var i = 0; i < 3; i++) _member(StaffRole.waiter, speed: 2, skill: 25, lane: i),
      ];
      final s = _session(level, staff);
      expect(s.staff, hasLength(10));
      final sw = Stopwatch();
      var frames = 0, maxUs = 0, maxCustomers = 0;
      const dt = 1 / 60;
      _run(s, 2); // JIT
      for (var i = 0; i < 180 * 60; i++) {
        final before = sw.elapsedMicroseconds;
        sw.start();
        s.advance(dt);
        sw.stop();
        maxUs = math.max(maxUs, sw.elapsedMicroseconds - before);
        frames++;
        s.drainEvents();
        maxCustomers = math.max(maxCustomers, s.customers.length);
      }
      final avgMs = sw.elapsedMicroseconds / frames / 1000;
      // ignore: avoid_print
      print('LevelSession.advance + 10 nhân viên: $frames khung, trung bình ${avgMs.toStringAsFixed(4)} ms, '
          'tối đa ${(maxUs / 1000).toStringAsFixed(3)} ms, khách tối đa $maxCustomers, '
          'nhân viên bán ${s.staffSales}, mẻ ${s.staffBakes}');
      expect(maxCustomers, greaterThanOrEqualTo(25));
      expect(s.staffSales, greaterThan(0));
      expect(s.staffBakes, greaterThan(0));
      expect(avgMs, lessThan(2.0), reason: 'mục tiêu < 0.5 ms trên máy dev; assert lỏng cho máy CI');
    });
  });

  group('thu nhập khi vắng nhà (quản lý)', () {
    final hour = const Duration(hours: 1).inMilliseconds;

    /// Đã thuê quản lý cấp 1/1 (tỉ lệ 0.20, trần 4 giờ), thu nhập TB [income], mốc hoạt động = _t0.
    GameState manager({int income = 6000, Map<String, dynamic> extra = const {}}) => _state({
          'shop': {
            'owned': ['staff_manager'],
          },
          'lastActive': _t0.millisecondsSinceEpoch,
          'offline': {
            'recentCoins': [income],
          },
          ...extra,
        });

    test('tính theo tỉ lệ × xu TB một level × giờ, cắt theo trần giờ; nhận x1 / x2 một lần', () {
      final s = manager();
      expect(s.pendingOffline, isNull, reason: 'chưa gọi refreshOffline');
      var notified = 0;
      s.addListener(() => notified++);
      s.refreshOffline(_t0.add(const Duration(hours: 2)));
      expect(notified, 1);
      expect(s.pendingOffline, const OfflineEarnings(
        away: Duration(hours: 2),
        counted: Duration(hours: 2),
        coins: 2400, // 0.20 × 6000 × 2
        capHours: 4,
      ));
      expect(s.pendingOffline!.capped, isFalse);
      final coins = s.coins;
      expect(s.claimOffline(), 2400);
      expect(s.coins, coins + 2400);
      expect(s.pendingOffline, isNull);
      expect(s.claimOffline(), 0, reason: 'nhận một lần');
      expect(s.coins, coins + 2400);

      // Vắng 10 giờ → chỉ tính 4 giờ; x2.
      s.refreshOffline(_t0.add(const Duration(hours: 12)));
      final p = s.pendingOffline!;
      expect((p.away, p.counted, p.coins, p.capped), (const Duration(hours: 10), const Duration(hours: 4), 4800, true));
      expect(s.claimOffline(doubled: true), 9600);
      expect(s.coins, coins + 2400 + 9600);
      expect(s.claimOffline(doubled: true), 0);
    });

    test('< 10 phút không tính; đồng hồ lùi → không tính, đặt lại mốc; chưa thuê quản lý → không tính', () {
      final s = manager();
      s.refreshOffline(_t0.add(const Duration(minutes: 9)));
      expect(s.pendingOffline, isNull);
      s.refreshOffline(_t0.add(const Duration(minutes: 18)));
      expect(s.pendingOffline, isNull, reason: 'mỗi lần vắng 9 phút, không cộng dồn lần ngắn');

      final back = manager();
      back.refreshOffline(_t0.subtract(const Duration(hours: 5)));
      expect(back.pendingOffline, isNull);
      expect(back.toJson()['lastActive'], _t0.subtract(const Duration(hours: 5)).millisecondsSinceEpoch);
      back.refreshOffline(_t0.subtract(const Duration(hours: 4)));
      expect(back.pendingOffline!.counted, const Duration(hours: 1), reason: 'tính từ mốc mới');

      final none = _state({'lastActive': _t0.millisecondsSinceEpoch});
      none.refreshOffline(_t0.add(const Duration(hours: 6)));
      expect(none.pendingOffline, isNull);
      expect(none.claimOffline(), 0);
      expect(none.toJson()['lastActive'], _t0.add(const Duration(hours: 6)).millisecondsSinceEpoch,
          reason: 'vẫn dời mốc: lần vắng trước khi thuê không tính về sau');

      final fresh = _state({
        'shop': {
          'owned': ['staff_manager'],
        },
      });
      fresh.refreshOffline(_t0);
      expect(fresh.pendingOffline, isNull, reason: 'chưa có mốc → chỉ đặt mốc');
    });

    test('cộng dồn các lần vắng chưa nhận (trần áp lên tổng); nâng tay nghề → trần cao hơn; chưa có lượt chơi → fallbackIncome', () {
      final s = manager();
      s.refreshOffline(_t0.add(const Duration(hours: 3)));
      s.refreshOffline(_t0.add(const Duration(hours: 6)));
      expect(s.pendingOffline!.away, const Duration(hours: 6));
      expect(s.pendingOffline!.counted, const Duration(hours: 4));
      s.addCoins(1 << 20);
      expect(s.upgradeStaff('staff_manager', StaffStat.skill), PurchaseResult.ok);
      expect(s.upgradeStaff('staff_manager', StaffStat.speed), PurchaseResult.ok);
      s.refreshOffline(_t0.add(const Duration(hours: 6, minutes: 1)));
      expect(s.pendingOffline, const OfflineEarnings(
        away: Duration(hours: 6),
        counted: Duration(hours: 5),
        coins: 7500, // 0.25 × 6000 × 5
        capHours: 5,
      ));

      final noPlays = _state({
        'shop': {
          'owned': ['staff_manager'],
        },
        'lastActive': _t0.millisecondsSinceEpoch,
      });
      noPlays.refreshOffline(_t0.add(const Duration(hours: 1)));
      final fallback = _config.staffById('staff_manager')!.param(StaffParams.fallbackIncome, 0);
      expect(noPlays.pendingOffline!.coins, (0.2 * fallback).round());

      // Thu nhập TB = 5 lượt chơi gần nhất.
      final played = manager(income: 0);
      for (final c in [1000, 2000, 3000, 4000, 5000, 6000]) {
        played.applyLevelResult(_win(1, coins: c));
      }
      expect(played.toJson()['offline'], {
        'awayMs': 0,
        'recentCoins': [2000, 3000, 4000, 5000, 6000],
      });
      // applyLevelResult ghi mốc hoạt động = _clock().
      played.refreshOffline(_t0.add(const Duration(hours: 1)));
      expect(played.pendingOffline!.coins, (0.2 * 4000).round());
    });

    test('dữ liệu thật: xu TB 6000, vắng 6 giờ, quản lý cấp 1 → 4 giờ × 0.20 × 6000 = 4800', () {
      final s = manager(income: 6000);
      s.refreshOffline(_t0.add(const Duration(hours: 6)));
      expect(s.pendingOffline, const OfflineEarnings(
        away: Duration(hours: 6),
        counted: Duration(hours: 4),
        coins: 4800,
        capHours: 4,
      ));
    });

    test('nâng quản lý / xong một lượt chơi → khoản đang chờ tính lại ngay (không cần refreshOffline)', () {
      final s = manager();
      s.refreshOffline(_t0.add(const Duration(hours: 6)));
      expect(s.pendingOffline!.coins, 4800);
      s.addCoins(1 << 20);
      var notified = 0;
      s.addListener(() => notified++);
      expect(s.upgradeStaff('staff_manager', StaffStat.speed), PurchaseResult.ok);
      expect(notified, 1);
      expect(s.pendingOffline!.coins, 6000, reason: '0.25 × 6000 × 4');
      expect(s.upgradeStaff('staff_manager', StaffStat.skill), PurchaseResult.ok);
      expect((s.pendingOffline!.counted, s.pendingOffline!.coins), (const Duration(hours: 5), 7500));

      // Lượt chơi mới đổi xu TB: (6000 + 2000) / 2 = 4000 → 0.25 × 4000 × 5.
      s.applyLevelResult(_win(1, coins: 2000));
      expect(s.pendingOffline!.coins, 5000);
      expect(s.pendingOffline!.away, const Duration(hours: 6), reason: 'chơi xong không làm mất thời gian vắng chưa nhận');
    });

    testWidgets('nhịp ghi mốc ở foreground: chơi 40 phút không xong ván rồi app bị tắt → lần mở sau không tính 40 phút đó',
        (tester) async {
      final start = _t0;
      try {
        Future<void> elapse(Duration d) async {
          const step = Duration(seconds: 10);
          for (var t = Duration.zero; t < d; t += step) {
            _t0 = _t0.add(step);
            await tester.pump(step);
          }
        }

        final repo = MemorySaveRepository();
        final s = manager()..attachAutosave(repo);
        s.refreshOffline(_t0); // mở app
        s.startActiveHeartbeat();
        await elapse(const Duration(minutes: 40));
        // App bị tắt đột ngột: không onHide / flush — chỉ còn những gì nhịp đã kịp lưu.
        final died = _t0;
        s.dispose();

        _t0 = died.add(const Duration(hours: 2));
        final loaded = await GameState.load(repo, clock: _clock);
        loaded
          ..attachLevelConfig(LevelConfig.empty())
          ..attachUnlockConfig(_config);
        loaded.refreshOffline(_t0);
        final away = loaded.pendingOffline!.away;
        expect(away, greaterThanOrEqualTo(const Duration(hours: 2)));
        expect(away, lessThanOrEqualTo(const Duration(hours: 2) + GameState.activeHeartbeat + GameState.autosaveDelay),
            reason: '40 phút đang chơi không tính là vắng (sai số ≤ một nhịp)');

        // Không có nhịp (như trước khi sửa) → 40 phút bị tính là vắng.
        _t0 = start;
        final old = manager()..refreshOffline(_t0);
        old.refreshOffline(_t0.add(const Duration(minutes: 40, hours: 2)));
        expect(old.pendingOffline!.away, const Duration(minutes: 40, hours: 2));

        // Tắt nhịp (vào nền) → mốc đứng yên, thời gian ở nền được tính.
        final bg = manager()..refreshOffline(_t0);
        bg.startActiveHeartbeat();
        await elapse(const Duration(minutes: 5));
        bg.stopActiveHeartbeat();
        final hidden = _t0;
        await elapse(const Duration(hours: 1));
        bg.refreshOffline(_t0);
        expect(bg.pendingOffline!.away, _t0.difference(hidden));

        // Chưa thuê quản lý: nhịp chỉ dời mốc trong bộ nhớ, không ghi đĩa.
        final noManagerRepo = MemorySaveRepository();
        final none = _state({'lastActive': _t0.millisecondsSinceEpoch})..attachAutosave(noManagerRepo);
        await tester.pump(const Duration(seconds: 1));
        final writes = noManagerRepo.writeCount;
        none.startActiveHeartbeat();
        await elapse(const Duration(minutes: 5));
        expect(noManagerRepo.writeCount, writes);
        expect(none.toJson()['lastActive'],
            greaterThanOrEqualTo(_t0.subtract(GameState.activeHeartbeat).millisecondsSinceEpoch));
        none.dispose();
        bg.dispose();
      } finally {
        _t0 = start;
      }
    });

    test('lưu / đọc lại: thời gian vắng chưa nhận + mốc giữ nguyên; trường hỏng → mặc định, không ảnh hưởng phần khác', () async {
      final repo = MemorySaveRepository();
      final s = manager()..attachAutosave(repo);
      s.refreshOffline(_t0.add(const Duration(hours: 2)));
      await s.flush();
      final saved = jsonDecode(repo.data!) as Map<String, dynamic>;
      expect(saved['lastActive'], _t0.add(const Duration(hours: 2)).millisecondsSinceEpoch);
      expect((saved['offline'] as Map)['awayMs'], 2 * hour);

      final loaded = await GameState.load(repo, clock: _clock);
      loaded
        ..attachLevelConfig(LevelConfig.empty())
        ..attachUnlockConfig(_config);
      expect(loaded.pendingOffline, s.pendingOffline, reason: 'tính lại ngay khi gắn config');
      // Mở lại app sau 1 giờ nữa → cộng dồn.
      loaded.refreshOffline(_t0.add(const Duration(hours: 3)));
      expect(loaded.pendingOffline!.away, const Duration(hours: 3));
      expect(loaded.claimOffline(), 3600);

      final broken = GameState.fromJson({
        'v': 2,
        'coins': 77,
        'lastActive': 'hôm qua',
        'offline': {'awayMs': -5, 'recentCoins': [100, 'x', 300]},
        'shop': {
          'owned': ['staff_manager'],
        },
      }, clock: _clock)
        ..attachLevelConfig(LevelConfig.empty())
        ..attachUnlockConfig(_config);
      expect(broken.coins, 77);
      expect(broken.toJson()['lastActive'], isNull);
      expect(broken.toJson()['offline'], {
        'awayMs': 0,
        'recentCoins': [100, 300],
      });
      expect(broken.pendingOffline, isNull);
    });

    test('markActive ghi mốc (lưu, không báo listener); resetAll xoá nhân viên + thu nhập vắng nhà', () async {
      final repo = MemorySaveRepository();
      final s = manager()..attachAutosave(repo);
      var notified = 0;
      s.addListener(() => notified++);
      _t0 = _t0.add(const Duration(minutes: 30));
      try {
        s.markActive();
        expect(notified, 0);
        await s.flush();
        expect((jsonDecode(repo.data!) as Map)['lastActive'], _t0.millisecondsSinceEpoch);
        s.refreshOffline(_t0.add(const Duration(minutes: 5)));
        expect(s.pendingOffline, isNull, reason: 'mốc đã dời tới lúc vào nền');
        s.refreshOffline(_t0.add(const Duration(hours: 1, minutes: 5)));
        expect(s.pendingOffline, isNotNull);
        await s.resetAll();
        expect(s.pendingOffline, isNull);
        expect(s.isStaffHired('staff_manager'), isFalse);
        expect(s.toJson()['staff'], isEmpty);
      } finally {
        _t0 = DateTime(2026, 10, 29, 9);
      }
    });

    test('AdPlacement.offlineDouble thêm sau extraTime (GĐ6 thêm booster ở cuối)', () {
      expect(AdPlacement.values.indexOf(AdPlacement.offlineDouble), AdPlacement.extraTime.index + 1);
      expect(AdPlacement.values.last, AdPlacement.booster);
    });
  });
}
