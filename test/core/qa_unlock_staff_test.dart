import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

import 'qa_helpers.dart';

/// QA việc 3: duyệt MỌI mục trong unlocks.json (mở rộng, nhân viên, thiết bị), mở chương theo sao, nhân viên đúng vai
/// trò, nâng cấp đổi chỉ số.

LevelSession _sessionFor(GameState s, int levelId) => LevelSession(
      level: qaLevels.level(levelId),
      defaults: qaLevels.defaults,
      modifiers: s.bakeModifiers,
      decorTipBonusPct: s.decorTipBonusPct,
      setup: s.shopSetup,
    );

void main() {
  group('mục mở khoá (unlocks.json) — từng mục', () {
    test('mốc level theo mô tả PO: thu ngân L10, thợ L15, bàn ghế L18, mở rộng bếp L22, phục vụ L25, quản lý L32', () {
      final want = {
        'staff_cashier': 10,
        'staff_baker': 15,
        'cafe_tables': 18,
        'kitchen_2': 22,
        'staff_waiter': 25,
        'staff_manager': 32,
      };
      for (final MapEntry(:key, :value) in want.entries) {
        expect(qaUnlocks.unlock(key)?.level, value, reason: key);
      }
      // Điểm code khác mô tả: "mở rộng bếp" (kitchen_2, prepSlots) đang là "Sắp có", chưa mua được.
      expect(qaUnlocks.unlock('kitchen_2')!.comingSoon, isTrue);
    });

    for (final u in qaUnlocks.unlocks) {
      test('${u.id} (L${u.level}, ${u.kind.name}, ${u.price} xu): chưa đủ level / thiếu xu / đủ cả hai', () {
        final s = qaState();
        if (u.level > 1) qaPassTo(s, u.level - 1);
        final soon = u.comingSoon || (u.kind == UnlockKind.staff && qaUnlocks.staffById(u.id) == null);
        if (soon) {
          qaSetCoins(s, u.price * 10 + 1);
          qaPassTo(s, 50);
          expect(s.unlockState(u.id), UnlockState.comingSoon);
          final c = s.coins;
          expect(s.buyUnlock(u.id), PurchaseResult.comingSoon);
          expect(s.coins, c);
          return;
        }

        // 1. Chưa đủ level (dư xu): khoá, không trừ xu.
        if (u.level > 0) {
          qaSetCoins(s, u.price * 10 + 1);
          expect(s.unlockState(u.id), UnlockState.locked);
          expect(s.buyUnlock(u.id), PurchaseResult.locked);
          expect(s.coins, u.price * 10 + 1);
        }
        qaPassTo(s, u.level);

        // Mục phải có trước (phục vụ cần bàn ghế): vẫn khoá tới khi mua.
        final req = qaUnlocks.staffById(u.id)?.requires;
        if (req != null) {
          expect(s.staffRequirementMissing(u.id), req);
          expect(s.buyUnlock(u.id), PurchaseResult.locked);
          qaPassTo(s, qaUnlocks.unlock(req)!.level);
          qaSetCoins(s, qaUnlocks.unlock(req)!.price);
          expect(s.buyUnlock(req), PurchaseResult.ok);
        }

        // 2. Đủ level, thiếu 1 xu.
        final before = s.shopSetup;
        qaSetCoins(s, u.price - 1);
        expect(s.unlockState(u.id), UnlockState.available);
        expect(s.buyUnlock(u.id), PurchaseResult.notEnoughCoins);
        expect(s.coins, u.price - 1);
        expect(s.shopSetup, before);

        // 3. Đủ cả hai: trừ đúng giá, sở hữu, mua lại = alreadyOwned.
        qaSetCoins(s, u.price);
        expect(s.buyUnlock(u.id), PurchaseResult.ok);
        expect(s.coins, 0);
        expect(s.unlockState(u.id), UnlockState.owned);
        expect(s.buyUnlock(u.id), PurchaseResult.alreadyOwned);
        expect(s.coins, 0);

        // 4. Có hiệu lực ở màn sau.
        final after = s.shopSetup;
        expect(after.owns(u.id), isTrue);
        final next = qaLevels.next(u.level)?.id ?? 50;
        final ls = _sessionFor(s, next);
        final base = LevelSession(
          level: qaLevels.level(next),
          defaults: qaLevels.defaults,
          modifiers: BakeModifiers.base,
          setup: before,
        );
        num e(String k) => u.effect[k] ?? 0;
        if (u.kind == UnlockKind.expansion) {
          expect(ls.displayCase.slots, base.displayCase.slots + e(UnlockEffects.caseSlots));
          expect(ls.kitchen.ovens.length, base.kitchen.ovens.length + e(UnlockEffects.ovens));
          expect(ls.tuning.maxQueue, base.tuning.maxQueue + e(UnlockEffects.maxQueue));
          expect(ls.tuning.counterSpots, base.tuning.counterSpots + e(UnlockEffects.counterSpots));
          expect(after.tipPct, before.tipPct + e(UnlockEffects.tipPct));
          expect(after.spawnRatePct, before.spawnRatePct + e(UnlockEffects.spawnRatePct));
          expect(ls.tuning.patienceMult,
              closeTo(base.tuning.patienceMult * (u.effect[UnlockEffects.patienceMult] ?? 1), 1e-9));
        }
        if (u.kind == UnlockKind.staff) {
          final d = qaUnlocks.staffById(u.id)!;
          expect(s.isStaffHired(u.id), isTrue);
          expect(s.staffLevel(u.id, StaffStat.speed), 1);
          expect(s.staffLevel(u.id, StaffStat.skill), 1);
          final inSession = ls.staff.where((st) => st.member.id == u.id).toList();
          if (d.role == StaffRole.manager) {
            expect(inSession, isEmpty, reason: 'quản lý không làm trong màn');
          } else {
            expect(inSession, hasLength(1));
            expect(inSession.single.role, d.role);
            expect(inSession.single.member.speedValue, d.speedValues.first.toDouble());
            expect(inSession.single.member.skillValue, d.skillValues.first.toDouble());
          }
        }
        ls.dispose();
        base.dispose();
      });
    }
  });

  group('thiết bị (unlocks.json) — từng cấp', () {
    for (final eq in qaUnlocks.equipment) {
      test('${eq.id}: mỗi cấp khoá trước mốc, thiếu 1 xu, đủ thì trừ đúng giá + đổi thông số; cuối → maxed', () {
        final s = qaState();
        expect(s.equipmentTier(eq.id), 1);
        for (var k = 2; k <= eq.tiers.length; k++) {
          final t = eq.tiers[k - 1];
          if (t.level > s.highestCompletedLevel + 0 && t.level > 0) {
            qaPassTo(s, t.level - 1);
            qaSetCoins(s, t.price * 3);
            expect(s.buyEquipment(eq.id), PurchaseResult.locked, reason: '${eq.id} cấp $k trước L${t.level}');
            expect(s.coins, t.price * 3);
          }
          qaPassTo(s, t.level);
          qaSetCoins(s, t.price - 1);
          expect(s.buyEquipment(eq.id), PurchaseResult.notEnoughCoins);
          expect(s.equipmentTier(eq.id), k - 1);
          qaSetCoins(s, t.price);
          expect(s.buyEquipment(eq.id), PurchaseResult.ok);
          expect(s.coins, 0);
          expect(s.equipmentTier(eq.id), k);

          final setup = s.shopSetup, mods = s.bakeModifiers;
          final v = t.value;
          switch (eq.id) {
            case EquipmentIds.fastOven:
              expect(setup.ovenSec, v.toDouble());
            case EquipmentIds.bigTray:
              expect(setup.batchSize, v.round());
            case EquipmentIds.wideCase:
              expect(setup.slotCapacity, v.round());
            case EquipmentIds.goldenOven:
              expect(mods.bakePerfectHalfWidth, v.toDouble());
              expect(mods.bakeOkHalfWidth, closeTo(v + 0.10, 1e-9));
            case 'whisk':
              expect(mods.mixPerfectBand, v.toDouble());
            case 'pipingBag':
              expect(mods.frostBrushRadius, v.toDouble());
            case 'tongs':
              expect(mods.toppingSnapRadius, v.toDouble());
            default:
              fail('thiết bị lạ ${eq.id}');
          }
        }
        qaSetCoins(s, 1 << 30);
        qaPassTo(s, 50);
        expect(s.buyEquipment(eq.id), PurchaseResult.maxed);
        expect(s.coins, 1 << 30);
      });
    }
  });

  group('mở chương theo tổng sao', () {
    for (final ch in qaLevels.chapters.skip(1)) {
      test('chương ${ch.id}: thiếu 1 sao → khoá (level đầu chương khoá); đủ đúng ${ch.starsToUnlock} sao → mở, delta báo', () {
        final s = qaState();
        final prev = [
          for (final l in qaLevels.levels)
            if (l.chapter < ch.id) l.id,
        ];
        final target = ch.starsToUnlock - 1;
        var extra = target - prev.length;
        expect(extra, greaterThanOrEqualTo(0), reason: 'đủ level để thử biên');
        for (final id in prev) {
          final add = extra.clamp(0, 2);
          extra -= add;
          s.applyLevelResult(qaResult(id, stars: 1 + add));
        }
        expect(extra, 0);
        expect(s.totalStars, target);
        final first = qaLevels.levelsInChapter(ch.id).first.id;
        expect(s.isChapterUnlocked(ch.id), isFalse);
        expect(s.isLevelUnlocked(first), isFalse);
        expect(s.currentLevelId, prev.last, reason: 'chờ đủ sao: level mở cao nhất');

        final bump = prev.firstWhere((id) => s.levelRecord(id)!.stars < 3);
        final old = s.levelRecord(bump)!.stars;
        final delta = s.applyLevelResult(qaResult(bump, stars: old + 1));
        expect(s.totalStars, ch.starsToUnlock);
        expect(s.isChapterUnlocked(ch.id), isTrue);
        expect(s.isLevelUnlocked(first), isTrue);
        expect(delta.unlockedChapter, ch.id);
        expect(delta.unlockedLevel, first);
        expect(s.currentLevelId, first);
      });
    }

    test('thua (0★) không làm giảm sao kỷ lục, không mở level sau', () {
      final s = qaState();
      s.applyLevelResult(qaResult(1, stars: 3));
      final d = s.applyLevelResult(qaResult(1, won: false));
      expect(s.levelRecord(1)!.stars, 3);
      expect(d.gainedStars, 0);
      final lose = s.applyLevelResult(qaResult(2, won: false));
      expect(lose.unlockedLevel, isNull);
      expect(s.isLevelUnlocked(3), isFalse);
    });
  });

  group('nhân viên: đúng vai trò trong màn, nâng cấp đổi chỉ số', () {
    GameState allStaff() {
      final s = qaState(json: {'coins': 1 << 40});
      qaPassTo(s, 40);
      for (final id in ['cafe_tables', 'staff_cashier', 'staff_baker', 'staff_waiter', 'staff_baker_2', 'staff_manager']) {
        expect(s.buyUnlock(id), PurchaseResult.ok, reason: id);
      }
      return s;
    }

    test('thu ngân bán khách ở quầy, phục vụ bán khách trong hàng, thợ cho mẻ vào tủ; quản lý không làm trong màn', () {
      final s = allStaff();
      final ls = _sessionFor(s, 26);
      expect([for (final st in ls.staff) st.role],
          [StaffRole.cashier, StaffRole.baker, StaffRole.waiter, StaffRole.baker]);
      final phaseBefore = <int, CustomerPhase>{};
      final sales = <StaffRole, int>{};
      var bakes = 0;
      while (!ls.isOver) {
        phaseBefore
          ..clear()
          ..addAll({for (final c in ls.customers) c.id: c.phase});
        ls.advance(LevelSession.step);
        for (final e in ls.drainEvents()) {
          if (e.type == SessionEventType.staffSold) {
            final role = ls.staff[e.staffIndex].role;
            sales[role] = (sales[role] ?? 0) + 1;
            final was = phaseBefore[e.customerId];
            if (role == StaffRole.cashier) expect(was, CustomerPhase.atCounter);
            if (role == StaffRole.waiter) expect(was, CustomerPhase.queued);
            expect(role, isNot(StaffRole.baker));
          }
          if (e.type == SessionEventType.staffBatchReady) {
            bakes++;
            expect(ls.staff[e.staffIndex].role, StaffRole.baker);
          }
        }
      }
      expect(sales[StaffRole.cashier] ?? 0, greaterThan(0));
      expect(sales[StaffRole.waiter] ?? 0, greaterThan(0));
      expect(bakes, greaterThan(0));
      final r = ls.finish();
      expect(r.staffSales, (sales[StaffRole.cashier] ?? 0) + (sales[StaffRole.waiter] ?? 0));
      expect(r.staffBakes, bakes);
      ls.dispose();
    });

    for (final d in qaUnlocks.staff) {
      test('${d.id}: nâng tốc độ / tay nghề tới cấp ${d.maxLevel}, trừ đúng giá, chỉ số trong màn đổi theo bảng', () {
        final s = allStaff();
        for (final stat in StaffStat.values) {
          for (var k = 2; k <= d.maxLevel; k++) {
            final price = d.priceTo(stat, k)!;
            expect(s.staffUpgradePrice(d.id, stat), price);
            qaSetCoins(s, price - 1);
            expect(s.upgradeStaff(d.id, stat), PurchaseResult.notEnoughCoins);
            expect(s.staffLevel(d.id, stat), k - 1);
            qaSetCoins(s, price);
            expect(s.upgradeStaff(d.id, stat), PurchaseResult.ok);
            expect(s.coins, 0);
            expect(s.staffLevel(d.id, stat), k);
            if (d.role != StaffRole.manager) {
              final m = s.shopSetup.staff.firstWhere((m) => m.id == d.id);
              final v = stat == StaffStat.speed ? m.speedValue : m.skillValue;
              expect(v, d.value(stat, k).toDouble());
            }
          }
          qaSetCoins(s, 1 << 30);
          expect(s.upgradeStaff(d.id, stat), PurchaseResult.maxed);
          expect(s.staffUpgradePrice(d.id, stat), isNull);
          expect(s.coins, 1 << 30);
        }
      });
    }

    test('chưa thuê → nâng = locked, không trừ xu', () {
      final s = qaState(json: {'coins': 100000});
      qaPassTo(s, 40);
      for (final d in qaUnlocks.staff) {
        expect(s.upgradeStaff(d.id, StaffStat.speed), PurchaseResult.locked);
        expect(s.staffLevel(d.id, StaffStat.speed), 0);
      }
      expect(s.coins, 100000);
    });
  });
}
