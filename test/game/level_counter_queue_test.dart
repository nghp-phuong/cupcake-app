import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/staff/staff.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';

// Lỗi chủ dự án báo: khách sau không dồn lên quầy khi khách trước rời đi. Session giữ chỗ quầy logic (`slot`) cố
// định; cảnh tiệm phải vẽ khách đứng quầy theo thứ tự tới quầy (0 = đầu quầy bên trái), dồn lên mượt khi khách trước
// đi, khách mới từ hàng chờ vào chỗ cuối, không đi xuyên qua người khác.

const _menu = [RecipeId.cupcakeVanilla];

LevelData _level({
  int startStock = 6,
  double every = 1,
  double patienceSec = 300,
  List<SpecialVisit> specials = const [],
}) =>
    LevelData(
      id: 1,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 300,
      goal: const LevelGoal(type: GoalType.customers, stars: [1, 2, 3]),
      menu: _menu,
      caseSlots: 3,
      startStock: startStock,
      patienceSec: patienceSec,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      specials: specials,
      newRecipe: _menu.last,
    );

LevelGame _game(LevelData level, {List<StaffMember> staff = const []}) => LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        setup: ShopSetup.base.withStaff(staff),
        random: math.Random(3),
      ),
    );

const _dt = 1 / 60;

/// Khách vãng lai đang đứng quầy (không tính người đang rời đi), theo id (= thứ tự tới quầy).
List<LevelCustomer> _counter(LevelSession s) =>
    [for (final c in s.customers) if (c.phase == CustomerPhase.atCounter && !c.isSpecial) c]..sort((a, b) => a.id.compareTo(b.id));

double _x(LevelGame g, LevelCustomer c) => g.shop.hitPointOf(c.id)!.dx;

/// Chạy [sec] giây; mỗi khung kiểm: khách đứng quầy không chồng hình (cách nhau ≥ 100 px) và không giật (≤ 16 px
/// mỗi khung khi đã đứng quầy yên trước đó).
void _run(LevelGame g, double sec) {
  final last = <int, double>{};
  for (var t = 0.0; t < sec; t += _dt) {
    g.step(_dt);
    final list = _counter(g.session);
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      final x = _x(g, c);
      final prev = last[c.id];
      if (prev != null) expect((x - prev).abs(), lessThan(16), reason: 'khách #${c.id} giật ${(x - prev).abs()} px');
      if (c.phaseT >= 1) last[c.id] = x;
      for (var j = 0; j < i; j++) {
        expect((x - _x(g, list[j])).abs(), greaterThan(100), reason: 'khách #${c.id} chồng lên #${list[j].id}');
      }
    }
  }
}

/// Khách đứng quầy (đã đứng yên) chiếm đúng các chỗ đầu 0..k−1 theo thứ tự tới quầy.
void _expectPacked(LevelGame g) {
  final spots = g.session.tuning.counterSpots;
  final list = _counter(g.session);
  for (var i = 0; i < list.length; i++) {
    expect(_x(g, list[i]), closeTo(LevelLayout.counterX(i, spots), 1), reason: 'khách #${list[i].id} phải ở chỗ quầy $i');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bán cho khách đầu quầy → khách sau dồn lên, khách mới vào chỗ cuối', () {
    final g = _game(_level());
    final s = g.session;
    _run(g, 8);
    final before = _counter(s);
    expect(before.length, s.tuning.counterSpots);
    _expectPacked(g);
    expect(s.sell(before.first.id), SellResult.sold);
    _run(g, 1.5);
    final after = _counter(s);
    expect(after.map((c) => c.id).take(2), [before[1].id, before[2].id]);
    expect(after.length, s.tuning.counterSpots, reason: 'khách đầu hàng chờ lên quầy');
    _expectPacked(g);
  });

  test('bán cho khách giữa quầy → chỉ khách phía sau dồn lên', () {
    final g = _game(_level());
    final s = g.session;
    _run(g, 8);
    final before = _counter(s);
    expect(s.sell(before[1].id), SellResult.sold);
    _run(g, 1.5);
    final after = _counter(s);
    expect(after.first.id, before.first.id);
    expect(after[1].id, before[2].id);
    _expectPacked(g);
  });

  test('khách đầu quầy hết kiên nhẫn bỏ đi → khách sau dồn lên', () {
    final g = _game(_level(every: 3, patienceSec: 14));
    final s = g.session;
    LevelCustomer? first;
    for (var t = 0.0; first == null || !first.isLeaving; t += _dt) {
      if (t > 60) fail('khách đầu không bỏ đi');
      _run(g, _dt);
      final list = _counter(s);
      if (first == null && list.length >= 2) first = list.first;
    }
    expect(s.lost, greaterThan(0));
    _run(g, 1.2);
    _expectPacked(g);
    expect(_counter(s).first.id, greaterThan(first.id));
  });

  test('khách đặc biệt không chiếm chỗ quầy; khách vãng lai vẫn dồn lên', () {
    final g = _game(_level(specials: const [SpecialVisit(atSec: 0.5, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)]));
    final s = g.session;
    _run(g, 8);
    final special = s.customers.firstWhere((c) => c.isSpecial);
    expect(_x(g, special), closeTo(LevelLayout.specialX, 1));
    _expectPacked(g);
    expect(s.sell(_counter(s).first.id), SellResult.sold);
    _run(g, 1.5);
    _expectPacked(g);
    expect(_x(g, special), closeTo(LevelLayout.specialX, 1));
  });

  test('thu ngân bán liên tục → quầy luôn dồn, không chồng hình, không giật', () {
    const cashier =
        StaffMember(id: StaffIds.cashier, role: StaffRole.cashier, character: 'staff_nora', speedValue: 1.5, skillValue: 1);
    final g = _game(_level(startStock: 6, every: 1.5), staff: const [cashier]);
    final s = g.session;
    _run(g, 20);
    expect(s.staffSales, greaterThan(2));
  });

  test('tủ hết món: không ai rời quầy, chỗ quầy giữ nguyên; khách ở hàng chờ không bán được', () {
    final g = _game(_level(startStock: 0));
    final s = g.session;
    _run(g, 8);
    final list = _counter(s);
    expect(list.length, s.tuning.counterSpots);
    expect(s.sell(list.first.id), SellResult.notInCase);
    _run(g, 1);
    _expectPacked(g);
    final queued = s.customers.firstWhere((c) => c.phase == CustomerPhase.queued);
    expect(s.sell(queued.id), SellResult.invalid);
  });
}
