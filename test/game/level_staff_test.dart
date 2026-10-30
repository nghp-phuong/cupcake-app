import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/staff/staff.dart';
import 'package:sugarleaf_bakery/game/level/level_art.dart';
import 'package:sugarleaf_bakery/game/level/level_characters.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/shop_view.dart';
import 'package:sugarleaf_bakery/game/level/staff_view.dart';

// GĐ4: nhân viên trong cảnh tiệm (thu ngân, thợ bánh, phục vụ), hiệu ứng khi nhân viên bán / xong mẻ, perf.
//
// Ảnh kiểm tra (PNG 1280×720): `P4_RENDER_DIR=<thư mục> flutter test test/game/level_staff_test.dart`.

const _menu = [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate, RecipeId.muffinBlueberry, RecipeId.eggTart];

LevelData _level({
  int caseSlots = 3,
  double every = 100,
  int startStock = 3,
  int maxQueue = 5,
  List<SpecialVisit> specials = const [],
  List<RecipeId> menu = _menu,
}) =>
    LevelData(
      id: 20,
      chapter: 2,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 600,
      goal: const LevelGoal(type: GoalType.coins, stars: [100, 200, 300]),
      menu: menu,
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: 900,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      newRecipe: menu.last,
      specials: specials,
      overrides: {'maxQueue': maxQueue},
    );

StaffMember _member(String id, StaffRole role, String character, {int lane = 0}) =>
    StaffMember(id: id, role: role, character: character, speedValue: 3, skillValue: 1, lane: lane);

final _cashier = _member(StaffIds.cashier, StaffRole.cashier, 'staff_nora');
final _baker = _member(StaffIds.baker, StaffRole.baker, 'staff_bao');
final _waiter = _member(StaffIds.waiter, StaffRole.waiter, 'staff_theo');
final _baker2 = _member(StaffIds.baker2, StaffRole.baker, 'staff_ami', lane: 1);
final _manager = _member(StaffIds.manager, StaffRole.manager, 'staff_hanh');

const _shop = ShopSetup(
  caseSlotsBonus: 1,
  ovens: 2,
  maxQueueBonus: 2,
  owned: {'case_stand', 'oven_2', 'cafe_tables'},
  equipmentTiers: {'fastOven': 3},
);

const _decor = {DecorSlot.counter: DecorId.counterFlowers, DecorSlot.plant: DecorId.plantLemonTree};

LevelGame _game(LevelData level, {ShopSetup setup = ShopSetup.base, List<StaffMember> staff = const [], int seed = 3}) =>
    LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        setup: setup.withStaff(staff),
        random: math.Random(seed),
      ),
      decor: _decor,
    );

const _dt = 1 / 60;

void _paintOnce(LevelGame g) {
  final recorder = ui.PictureRecorder();
  g.paint(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

void _run(LevelGame g, double sec) {
  for (var t = 0.0; t < sec; t += _dt) {
    g.step(_dt);
  }
}

/// Thân nhân vật trong khung ảnh 3:4 (bỏ lề trong suốt hai bên; đo trên ảnh 480×640: thân rộng ~±0.11 cao khung).
Rect _body(Rect frame) => Rect.fromLTRB(frame.center.dx - frame.height * 0.11, frame.top + frame.height * 0.03,
    frame.center.dx + frame.height * 0.11, frame.bottom);

/// Đầu nhân vật (vùng mặt dễ bị bong bóng che).
Rect _headRect(Rect frame) =>
    Rect.fromCenter(center: Offset(frame.center.dx, frame.top + frame.height * 0.16), width: frame.height * 0.16, height: frame.height * 0.2);

/// Bong bóng gọi món quanh tâm [c] (bề ngang ảnh cố định, không theo tỉ lệ khách).
Rect _bubble(Offset c) => Rect.fromCenter(center: c, width: LevelLayout.bubbleWidth, height: LevelLayout.bubbleWidth * 0.8);

const double _counterH = LevelLayout.customerHeight * LevelLayout.counterScale;

/// Tâm bong bóng của khách tỉ lệ quầy đứng ở (x, đáy khung [floor]).
Offset _bubbleAt(double x, double floor, {bool left = false}) {
  final o = left ? LevelLayout.bubbleOffsetLeft : LevelLayout.bubbleOffset;
  return Offset(x + o.dx * LevelLayout.counterScale, floor - _counterH + o.dy * LevelLayout.counterScale);
}

/// Mọi chỗ bong bóng của khách ở quầy (đủ 1..5 chỗ quầy) + khách đặc biệt (lật trái khi có thu ngân).
List<Rect> _counterBubbles({bool cashier = true}) => [
      for (var n = 1; n <= 5; n++)
        for (var i = 0; i < n; i++) _bubble(_bubbleAt(LevelLayout.counterX(i, n), LevelLayout.counterFloor)),
      _bubble(_bubbleAt(LevelLayout.specialX, LevelLayout.specialFloor, left: cashier)),
    ];

/// Thân khách đặc biệt ở mép trái quầy.
final Rect _specialBody = _body(Rect.fromCenter(
    center: const Offset(LevelLayout.specialX, LevelLayout.specialFloor - _counterH / 2), width: _counterH * 0.75, height: _counterH));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bố cục nhân viên', () {
    setUp(() => LevelArt.debugReset());

    test('0 nhân viên: không hình, vẽ không lỗi', () {
      final g = _game(_level(every: 1));
      _run(g, 3);
      _paintOnce(g);
      expect(g.shop.staff.count, 0);
      expect(g.shop.staff.hasCashier, isFalse);
    });

    test('quản lý không xuất hiện trong màn', () {
      final g = _game(_level())..debugStaffPoses = [StaffPose(_manager), StaffPose(_cashier)];
      g.step(_dt);
      _paintOnce(g);
      expect(g.shop.staff.count, 1);
      expect(g.shop.staff.frameOf(0), isNull);
      expect(g.shop.staff.frameOf(1), isNotNull);
    });

    test('thu ngân: sau quầy cạnh máy tính tiền, lộ từ thắt lưng; không che tủ / cây / bong bóng / khách đặc biệt', () {
      final g = _game(_level(every: 1), setup: _shop, staff: [_cashier]);
      _run(g, 4);
      _paintOnce(g);
      final f = g.shop.staff.frameOf(0)!;
      expect(f.center.dx, inInclusiveRange(330, 420));
      expect(f.height, _counterH, reason: 'cùng tỉ lệ khách ở quầy');
      expect(f.bottom, LevelLayout.counterFloor);
      // Thắt lưng (~56% khung) ngang mép trên máy tính tiền / nóc tủ: phần dưới bị quầy che.
      expect(f.top + f.height * 0.56, closeTo(LevelLayout.registerDisplay.top, 6));
      final body = _body(f);
      // Mặt tủ luôn vẽ đè lên mọi nhân vật; thân thu ngân vẫn ở ngoài lòng kính.
      expect(body.right, lessThan(LevelLayout.caseGlass.left));
      // Cây trên quầy + khách đặc biệt / khách quầy vẽ đè lên thu ngân (thu ngân xếp sau cây).
      expect(g.shop.staff.depthOf(0), lessThan(LevelLayout.plantDepth));
      expect(g.shop.staff.depthOf(0), lessThan(LevelLayout.counterScale));
      expect(body.overlaps(_specialBody), isFalse);
      for (final b in _counterBubbles()) {
        expect(_headRect(f).overlaps(b), isFalse, reason: 'bong bóng $b che mặt thu ngân');
      }
      // Thân không chồng khách ở chỗ quầy đầu tiên (mọi số chỗ quầy).
      for (var n = 1; n <= 5; n++) {
        expect(body.right, lessThan(LevelLayout.counterX(0, n) - 20));
      }
      expect(g.shop.staff.hasCashier, isTrue);
    });

    test('khách đặc biệt + thu ngân: bong bóng lật sang trái, khách đặc biệt vẽ đè lên thu ngân', () {
      final level = _level(specials: const [SpecialVisit(atSec: 0.5, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)]);
      final g = _game(level, staff: [_cashier]);
      final s = g.session;
      for (var t = 0.0; !s.customers.any((c) => c.isSpecial && c.phase == CustomerPhase.atCounter && c.phaseT >= 1); t += _dt) {
        if (t > 20) fail('khách đặc biệt không tới');
        g.step(_dt);
      }
      g.step(_dt);
      _paintOnce(g);
      final special = s.customers.firstWhere((c) => c.isSpecial);
      final head = g.shop.headOf(special.id)!;
      expect(head.dx, closeTo(LevelLayout.specialX, 4));
      // Chạm bong bóng (đã lật trái) vẫn mở đơn đặc biệt.
      int? tapped;
      g.onSpecialTap = (id) => tapped = id;
      final bubble = _bubbleAt(head.dx, head.dy - _counterH * 0.16 + _counterH, left: true);
      expect(bubble.dx, lessThan(head.dx), reason: 'bong bóng bên trái đầu');
      g.pointerDown(1, bubble);
      g.pointerUp(1, bubble);
      expect(tapped, special.id);
      expect(_bubble(bubble).overlaps(_headRect(g.shop.staff.frameOf(0)!)), isFalse);
    });

    test('thu ngân + 2 thợ + phục vụ: không chồng tủ / kệ / cây / bàn / bong bóng / khách đặc biệt', () {
      final g = _game(_level(every: 0.8, maxQueue: 7), setup: _shop, staff: [_cashier, _baker, _waiter, _baker2]);
      g.debugStaffPoses = [
        StaffPose(_cashier),
        StaffPose(_baker, working: RecipeId.cupcakeChocolate, progress: 0.4),
        StaffPose(_waiter),
        StaffPose(_baker2, working: RecipeId.eggTart, progress: 0.8),
      ];
      _run(g, 6);
      _paintOnce(g);
      final staff = g.shop.staff;
      expect(staff.count, 4);
      final frames = [for (var i = 0; i < 4; i++) staff.frameOf(i)!];
      for (final i in [1, 3]) {
        final body = _body(frames[i]);
        final ring = staff.ringRectOf(i)!;
        expect(body.overlaps(LevelLayout.caseRect), isFalse);
        expect(body.overlaps(LevelLayout.plantRect.deflate(16)), isFalse);
        expect(body.overlaps(_specialBody), isFalse);
        expect(body.right, lessThan(LevelLayout.register.left));
        expect(staff.depthOf(i), lessThan(LevelLayout.tableDepth), reason: 'thợ sau bàn trái');
        expect(ring.top, greaterThan(LevelLayout.hudBottom));
        for (final b in _counterBubbles()) {
          expect(ring.overlaps(b), isFalse, reason: 'vòng thợ $i chồng bong bóng $b');
          expect(_headRect(frames[i]).overlaps(b), isFalse);
        }
      }
      expect(_body(frames[1]).overlaps(_body(frames[3])), isFalse, reason: 'hai làn thợ tách nhau');
      expect(staff.ringRectOf(1)!.overlaps(staff.ringRectOf(3)!), isFalse);
      expect(staff.ringRectOf(0), isNull, reason: 'thu ngân không có vòng tiến độ');
      // Phục vụ ở chỗ chờ: bên phải kệ tầng, không chồng tủ / kệ.
      final w = _body(frames[2]);
      expect(w.left, greaterThan(LevelLayout.standRect.right));
      expect(w.overlaps(LevelLayout.caseRect), isFalse);
      expect(frames[2].right, lessThan(1280 + 60));
    });

    test('phục vụ tới cạnh khách được nhắm rồi quay về chỗ chờ', () {
      final g = _game(_level(every: 0.7, maxQueue: 7), setup: _shop, staff: [_waiter]);
      final s = g.session;
      for (var t = 0.0; s.customers.where((c) => c.phase == CustomerPhase.queued && c.phaseT >= 1).length < 2; t += _dt) {
        if (t > 30) fail('không có khách chờ');
        g.step(_dt);
      }
      final home = g.shop.staff.frameOf(0)!.center.dx;
      final target = s.customers.lastWhere((c) => c.phase == CustomerPhase.queued && c.phaseT >= 1);
      g.debugStaffPoses = [StaffPose(_waiter, targetCustomer: target.id)];
      _run(g, 2.5);
      _paintOnce(g);
      final head = g.shop.headOf(target.id);
      if (head != null) {
        final at = g.shop.staff.frameOf(0)!.center.dx;
        expect((at - head.dx).abs(), lessThan(LevelLayout.waiterBeside * 1.25 + 8), reason: 'phục vụ đứng cạnh khách');
      }
      g.debugStaffPoses = [StaffPose(_waiter)];
      _run(g, 4);
      expect(g.shop.staff.frameOf(0)!.center.dx, closeTo(home, 1));
    });
  });

  group('hiệu ứng', () {
    test('nhân viên bán: +xu ở khách, đồng xu bay từ nhân viên, nhân viên cười rồi thôi', () {
      final g = _game(_level(every: 1), staff: [_cashier]);
      final s = g.session;
      for (var t = 0.0; !s.customers.any((c) => c.canBuy && c.phaseT >= 1); t += _dt) {
        if (t > 20) fail('không có khách ở quầy');
        g.step(_dt);
      }
      final c = s.customers.firstWhere((c) => c.canBuy && c.phaseT >= 1);
      expect(g.shop.staff.expressionOf(0), LevelCharacters.neutral);
      final before = g.floats.liveCount;
      g.showStaffSold(0, c.id, 42, combo: 3);
      expect(g.floats.liveCount, before + 3, reason: '+xu, combo, đồng xu bay');
      expect(g.shop.staff.expressionOf(0), LevelCharacters.smile);
      _run(g, 0.3);
      _paintOnce(g);
      _run(g, 1.5);
      expect(g.shop.staff.expressionOf(0), LevelCharacters.neutral);
      // Chỉ số sai / quản lý: không lỗi.
      g.showStaffSold(9, -1, 5);
      _paintOnce(g);
    });

    test('thợ xong mẻ: bánh bay từ vòng tiến độ vào ô tủ đúng món + sao', () {
      final g = _game(_level(), staff: [_cashier, _baker]);
      g.step(_dt);
      final before = g.floats.liveCount;
      g.showStaffBatch(1, RecipeId.cupcakeVanilla, 4);
      expect(g.floats.liveCount, before + 2);
      expect(g.shop.staff.expressionOf(1), LevelCharacters.smile);
      _run(g, 0.4);
      _paintOnce(g);
      _run(g, 2);
      expect(g.floats.liveCount, 0);
    });
  });

  group('session thật (LevelSession.staff)', () {
    StaffMember fast(StaffMember m, double sec, {double skill = 4}) => StaffMember(
        id: m.id, role: m.role, character: m.character, speedValue: sec, skillValue: skill, lane: m.lane);

    test('thu ngân + thợ + phục vụ tự làm: staffSold / staffBatchReady → hiệu ứng, vòng tiến độ theo session', () {
      final g = _game(_level(every: 0.8, startStock: 3, maxQueue: 7),
          setup: _shop, staff: [fast(_cashier, 1.2), fast(_baker, 2), fast(_waiter, 1.5)]);
      final s = g.session;
      expect(s.staff.length, 3);
      final events = <SessionEvent>[];
      g.onEvent = events.add;
      var maxFloats = 0;
      var sawRing = false, sawSmile = false;
      for (var t = 0.0; t < 20; t += _dt) {
        g.step(_dt);
        maxFloats = math.max(maxFloats, g.floats.liveCount);
        final baker = s.staff[1];
        if (baker.working != null && baker.progress > 0.2) {
          expect(g.staffPoses[1].progress, baker.progress);
          sawRing = g.shop.staff.ringRectOf(1) != null;
        }
        if (g.shop.staff.expressionOf(0) == LevelCharacters.smile) sawSmile = true;
        if ((t * 60).round() % 30 == 0) _paintOnce(g);
      }
      final sold = events.where((e) => e.type == SessionEventType.staffSold).toList();
      final baked = events.where((e) => e.type == SessionEventType.staffBatchReady).toList();
      expect(sold.map((e) => e.staffIndex).toSet(), containsAll([0]), reason: 'thu ngân có bán');
      expect(baked, isNotEmpty, reason: 'thợ có mẻ');
      expect(baked.every((e) => e.staffIndex == 1), isTrue);
      expect(maxFloats, greaterThan(0));
      expect(sawRing, isTrue);
      expect(sawSmile, isTrue);
      // Phục vụ chỉ bán cho khách đang chờ (không ở quầy).
      expect(s.staff[2].role, StaffRole.waiter);
      _paintOnce(g);
    });

    test('phục vụ theo khách session nhắm (targetCustomer)', () {
      // Một món (có sẵn trong tủ) → khách chờ nào cũng mua được, phục vụ luôn có người để nhắm.
      final g = _game(_level(every: 0.5, startStock: 6, maxQueue: 7, menu: const [RecipeId.cupcakeVanilla]),
          setup: _shop, staff: [fast(_waiter, 30)]);
      final s = g.session;
      for (var t = 0.0; s.staff[0].targetCustomer == null || t < 4; t += _dt) {
        if (t > 30) fail('phục vụ không nhắm khách');
        g.step(_dt);
      }
      _run(g, 3);
      final id = s.staff[0].targetCustomer;
      final head = id == null ? null : g.shop.headOf(id);
      if (head != null) {
        expect((g.shop.staff.frameOf(0)!.center.dx - head.dx).abs(), lessThan(LevelLayout.waiterBeside * 1.25 + 12));
      }
      _paintOnce(g);
    });
  });

  test('thiếu ảnh nhân viên: không vẽ hình (vòng tiến độ vẫn vẽ), không lỗi', () async {
    LevelCharacters.debugReset(bundle: _MissingBundle());
    final g = _game(_level(every: 0.8), setup: _shop, staff: [_cashier, _baker, _waiter, _baker2]);
    g.debugStaffPoses = [StaffPose(_cashier), StaffPose(_baker, working: RecipeId.muffinBlueberry), StaffPose(_waiter), StaffPose(_baker2)];
    await LevelCharacters.preload(StaffView.spritesFor(g.session.setup.staff));
    expect(LevelCharacters.isMissing('staff_nora', LevelCharacters.neutral), isTrue);
    _run(g, 3);
    _paintOnce(g);
    expect(g.shop.staff.count, 4);
    LevelCharacters.debugReset();
  });

  test('perf: 25 khách + 10 nhân viên giả lập + đồ đầy đủ — step+paint TB < 1 ms/khung', () async {
    final level = _level(caseSlots: 4, every: 0.35, startStock: 6, maxQueue: 26);
    final g = _game(level, setup: _shop, seed: 11);
    final s = g.session;
    final roles = [StaffRole.cashier, StaffRole.baker, StaffRole.baker, StaffRole.waiter, StaffRole.cashier];
    const chars = ['staff_nora', 'staff_bao', 'staff_ami', 'staff_theo', 'staff_hanh'];
    final poses = [
      for (var i = 0; i < 10; i++)
        StaffPose(_member('fake_$i', roles[i % 5], chars[i % 5], lane: i ~/ 5), working: _menu[i % 4], progress: i / 10),
    ];
    g.debugStaffPoses = poses;
    await LevelGame.preloadFor(level, ovenLevel: 3, decor: _decor, staff: [for (final p in poses) p.member])
        .timeout(const Duration(seconds: 20), onTimeout: () => const []);
    for (var i = 0; i < 60 * 30 && s.customers.length < 25; i++) {
      g.step(_dt);
    }
    expect(s.customers.length, greaterThanOrEqualTo(25));
    expect(g.shop.staff.count, 10);

    var frameNo = 0;
    void frame() {
      frameNo++;
      for (var i = 0; i < poses.length; i++) {
        final p = poses[i];
        p.progress = (p.progress + _dt / 6) % 1;
        // Phục vụ đổi khách nhắm mỗi giây; nhân viên "bán" / "xong mẻ" luân phiên.
        if (p.member.role == StaffRole.waiter && frameNo % 60 == 0) {
          final q = s.customers.where((c) => c.phase == CustomerPhase.queued).toList();
          p.targetCustomer = q.isEmpty ? null : q[frameNo ~/ 60 % q.length].id;
        }
      }
      if (frameNo % 20 == 0) {
        final i = frameNo ~/ 20 % poses.length;
        if (poses[i].member.role == StaffRole.baker) {
          g.showStaffBatch(i, _menu[i % 4], 4);
        } else if (s.customers.isNotEmpty) {
          g.showStaffSold(i, s.customers.first.id, 30);
        }
      }
      g.step(_dt);
      _paintOnce(g);
    }

    for (var i = 0; i < 60; i++) {
      frame();
    }
    const frames = 600;
    final sw = Stopwatch()..start();
    var maxUs = 0;
    for (var i = 0; i < frames; i++) {
      final t0 = sw.elapsedMicroseconds;
      frame();
      maxUs = math.max(maxUs, sw.elapsedMicroseconds - t0);
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('LevelPlay GĐ4 perf: ${s.customers.length} khách + ${g.shop.staff.count} nhân viên, ảnh nhân vật '
        '${LevelCharacters.debugCachedCount}, step+paint TB ${avgMs.toStringAsFixed(3)} ms/khung '
        '(max ${(maxUs / 1000).toStringAsFixed(2)} ms)');
    expect(avgMs, lessThan(1));
  });

  final renderDir = Platform.environment['P4_RENDER_DIR'];
  group('ảnh kiểm tra', () {
    setUpAll(_loadFonts);

    Future<void> render(String name, LevelGame g, void Function() setupScene) async {
      LevelArt.debugReset();
      LevelCharacters.debugReset();
      await LevelGame.preloadFor(g.session.level, ovenLevel: g.ovenLevel, decor: _decor, staff: g.session.setup.staff)
          .timeout(const Duration(seconds: 30), onTimeout: () => const []);
      g.setLabels(g.labels, fontFamily: 'Nunito', titleFontFamily: 'Fredoka');
      setupScene();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1280, 720), ui.Paint()..color = const Color(0xFFFFF4E6));
      g.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1280, 720);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(renderDir!).createSync(recursive: true);
      File('$renderDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    test('p4_shop_staff / cashier_special / sold / batch / waiter', () async {
      final all = _game(_level(every: 0.9, startStock: 6, maxQueue: 6), setup: _shop, staff: [_cashier, _baker, _waiter, _baker2], seed: 5);
      await render('p4_shop_staff', all, () {
        all.debugStaffPoses = [
          StaffPose(_cashier),
          StaffPose(_baker, working: RecipeId.cupcakeChocolate, progress: 0.35),
          StaffPose(_waiter),
          StaffPose(_baker2, working: RecipeId.eggTart, progress: 0.75),
        ];
        _run(all, 8);
      });

      final special = _game(
          _level(every: 1.4, startStock: 6, specials: const [SpecialVisit(atSec: 0.5, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)]),
          setup: _shop,
          staff: [_cashier, _baker],
          seed: 7);
      await render('p4_cashier_special', special, () {
        special.debugStaffPoses = [StaffPose(_cashier), StaffPose(_baker, working: RecipeId.muffinBlueberry, progress: 0.6)];
        _run(special, 6);
      });

      final sold = _game(_level(every: 0.9, startStock: 6), setup: _shop, staff: [_cashier, _baker, _waiter], seed: 5);
      await render('p4_staff_sold', sold, () {
        _run(sold, 6);
        final c = sold.session.customers.firstWhere((c) => c.canBuy, orElse: () => sold.session.customers.first);
        sold.showStaffSold(0, c.id, 36, combo: 2);
        sold.debugStaffPoses = [StaffPose(_cashier), StaffPose(_baker, working: RecipeId.cupcakeVanilla, progress: 0.05), StaffPose(_waiter)];
        sold.step(_dt);
        sold.showStaffBatch(1, RecipeId.cupcakeVanilla, 4);
        _run(sold, 0.32);
      });

      final waiter = _game(_level(every: 0.7, startStock: 6, maxQueue: 7), setup: _shop, staff: [_cashier, _waiter], seed: 9);
      await render('p4_waiter_serving', waiter, () {
        _run(waiter, 7);
        final q = waiter.session.customers.where((c) => c.phase == CustomerPhase.queued).toList();
        waiter.debugStaffPoses = [StaffPose(_cashier), StaffPose(_waiter, targetCustomer: q.isEmpty ? null : q.last.id)];
        _run(waiter, 2.2);
      });
      LevelCharacters.debugReset();
      LevelArt.debugReset();
    }, timeout: const Timeout(Duration(minutes: 3)));

    /// Chạy tới khi có ≥ [counter] khách đứng yên ở quầy và ≥ [queued] khách đứng yên trong hàng chờ.
    void settle(LevelGame g, {int counter = 3, int queued = 0}) {
      final s = g.session;
      bool ok() =>
          s.customers.where((c) => c.phase == CustomerPhase.atCounter && c.phaseT >= 1 && !c.isSpecial).length >= counter &&
          s.customers.where((c) => c.phase == CustomerPhase.queued && c.phaseT >= 1).length >= queued;
      for (var t = 0.0; !ok(); t += _dt) {
        if (t > 60) fail('không đủ $counter khách quầy + $queued khách chờ');
        g.step(_dt);
      }
      _run(g, 0.6);
    }

    test('p4_scale_counter / p4_scale_queue_plain / stand / tables (phương án A: nhân vật ×1.45)', () async {
      final counter = _game(_level(every: 1.0, startStock: 6, maxQueue: 3), seed: 5);
      await render('p4_scale_counter', counter, () => settle(counter));
      // Kiểm: bong bóng cao nhất dưới HUD ≥ 16 px.
      for (final c in counter.session.customers.where((c) => c.phase == CustomerPhase.atCounter)) {
        final head = counter.shop.headOf(c.id)!;
        expect(head.dy - _counterH * 0.16, greaterThan(0), reason: 'đầu khách không bị cắt');
      }

      for (final (name, setup) in const [
        ('p4_scale_queue_plain', ShopSetup.base),
        ('p4_scale_queue_stand', ShopSetup(caseSlotsBonus: 1, owned: {'case_stand'})),
        ('p4_scale_queue_tables', ShopSetup(owned: {'cafe_tables'})),
      ]) {
        final g = _game(_level(every: 0.6, startStock: 6, maxQueue: 8), setup: setup, seed: 5);
        await render(name, g, () => settle(g, queued: 5));
      }
      LevelCharacters.debugReset();
      LevelArt.debugReset();
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, skip: renderDir == null ? 'đặt P4_RENDER_DIR để xuất ảnh kiểm tra' : null);

  test('ShopView.tableRect vẫn ổn định (bàn trái che chân thợ)', () {
    final t = ShopView.tableRect(0);
    for (var lane = 0; lane < 2; lane++) {
      expect(LevelLayout.bakerX[lane], inInclusiveRange(t.left, t.right + 12));
    }
  });
}

/// Bundle không có ảnh nào (thiếu file → không vẽ hình nhân vật).
class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(StateError('thiếu $key'));
}

Future<void> _loadFonts() async {
  for (final (family, files) in const [
    ('Nunito', ['Nunito-Regular', 'Nunito-SemiBold', 'Nunito-Bold', 'Nunito-ExtraBold']),
    ('Fredoka', ['Fredoka-Medium', 'Fredoka-SemiBold', 'Fredoka-Bold']),
  ]) {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('assets/fonts/$name.ttf');
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      any = true;
    }
    if (any) await loader.load();
  }
}
