import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/game/level/kitchen_view.dart';
import 'package:sugarleaf_bakery/game/level/level_art.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';
import 'package:sugarleaf_bakery/game/level/level_layout.dart';
import 'package:sugarleaf_bakery/game/level/level_paint.dart';

LevelData _level({
  int startStock = 3,
  List<RecipeId> menu = const [RecipeId.cupcakeVanilla],
  double every = 1,
  List<SpecialVisit> specials = const [],
}) =>
    LevelData(
      id: 1,
      chapter: 1,
      title: const {'en': 'Test', 'vi': 'Thử'},
      durationSec: 200,
      goal: const LevelGoal(type: GoalType.customers, stars: [1, 2, 3]),
      menu: menu,
      caseSlots: 3,
      startStock: startStock,
      patienceSec: 200,
      spawn: SpawnCurve(startEverySec: every, endEverySec: every, rushAtPct: 100, rushEverySec: every),
      specials: specials,
      newRecipe: menu.last,
    );

LevelGame _game(LevelData level, {ValueChanged<int>? onSpecialTap}) => LevelGame(
      session: LevelSession(
        level: level,
        defaults: const LevelDefaults(jitterPct: 0),
        modifiers: BakeModifiers.base,
        random: math.Random(3),
      ),
      onSpecialTap: onSpecialTap,
    );

const _dt = 1 / 60;

/// Chạy game từng khung tới khi [cond] đúng (tối đa [maxSec] giây).
void _until(LevelGame g, bool Function() cond, {double maxSec = 30}) {
  for (var t = 0.0; !cond(); t += _dt) {
    if (t > maxSec) fail('quá $maxSec s mà điều kiện chưa đúng');
    g.step(_dt);
  }
}

void _tap(LevelGame g, Offset p, {int pointer = 1}) {
  g.pointerDown(pointer, p);
  g.pointerUp(pointer, p);
}

void _paintOnce(LevelGame g) {
  final recorder = PictureRecorder();
  g.paint(Canvas(recorder));
  recorder.endRecording().dispose();
}

LevelCustomer? _atCounter(LevelSession s) {
  for (final c in s.customers) {
    if (c.canBuy && c.phaseT >= 1) return c;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chạm khách ở quầy → bán (sell), khách rời đi vui, có xu', () {
    final g = _game(_level());
    final s = g.session;
    final events = <SessionEvent>[];
    g.onEvent = events.add;
    _until(g, () => _atCounter(s) != null);
    final c = _atCounter(s)!;
    final id = c.id;
    final p = g.customerHitPoint(id)!;
    expect(LevelLayout.shop.contains(p), isTrue);
    _tap(g, p);
    expect(s.served, 1);
    expect(s.coins, greaterThan(0));
    expect(s.customer(id)?.phase, CustomerPhase.leavingHappy);
    g.step(_dt);
    expect(events.any((e) => e.type == SessionEventType.sold && e.customerId == id), isTrue);
    _paintOnce(g);
  });

  test('chạm khách khi tủ không có món → không bán, khách vẫn đứng quầy', () {
    final g = _game(_level(startStock: 0));
    final s = g.session;
    _until(g, () => _atCounter(s) != null);
    final id = _atCounter(s)!.id;
    _tap(g, g.customerHitPoint(id)!);
    expect(s.served, 0);
    expect(s.customer(id)?.phase, CustomerPhase.atCounter);
    g.step(_dt);
    _paintOnce(g);
  });

  test('chạm vùng HUD (y < 64) không làm gì', () {
    final g = _game(_level());
    final s = g.session;
    _until(g, () => _atCounter(s) != null);
    _tap(g, const Offset(640, 30));
    expect(s.served, 0);
  });

  test('chạm thẻ món → mẻ mới ở trạm khuôn; khuôn sai ở lại, khuôn đúng → sang trộn', () {
    final g = _game(_level());
    final s = g.session;
    g.step(_dt);
    _tap(g, LevelLayout.cardRect(0, 1).center);
    final b = s.kitchen.prep!;
    expect(b.stage, BatchStage.mould);
    final tile = LevelLayout.tile(LevelLayout.mouldTile);
    final wrong = b.mouldChoices.indexWhere((m) => m != b.correctMould);
    _tap(g, LevelLayout.choiceRow(tile, wrong).center);
    expect(b.stage, BatchStage.mould);
    expect(b.wrongMoulds, 1);
    final right = b.mouldChoices.indexOf(b.correctMould);
    _tap(g, LevelLayout.choiceRow(tile, right).center);
    expect(b.stage, BatchStage.mix);
    g.step(_dt);
    _paintOnce(g);
  });

  test('cả mẻ bằng chạm/kéo: trộn 1 vòng → lò → lấy ra → kem → topping ×3 → hộp → vào tủ', () {
    final g = _game(_level(startStock: 0, every: 100));
    final s = g.session;
    g.step(_dt);
    _tap(g, LevelLayout.cardRect(0, 1).center);
    final b = s.kitchen.prep!;
    final mouldTile = LevelLayout.tile(LevelLayout.mouldTile);
    _tap(g, LevelLayout.choiceRow(mouldTile, b.mouldChoices.indexOf(b.correctMould)).center);

    // Trộn: kéo ngón tay một vòng quanh âu.
    final c = LevelLayout.bowlCenter();
    g.pointerDown(2, c + const Offset(50, 0));
    for (var i = 1; i <= 40; i++) {
      final a = i / 40 * math.pi * 2;
      g.pointerMove(2, c + Offset(math.cos(a), math.sin(a)) * 50);
      _paintOnce(g);
    }
    g.pointerUp(2, c + const Offset(50, 0));
    g.step(_dt);
    expect(b.stage, BatchStage.baking);

    // Lò: chờ kim tới vạch chuẩn rồi chạm lò.
    _until(g, () => b.ovenProgress >= b.bakeTarget);
    _tap(g, LevelLayout.ovenSlot(0, 1).center);
    g.step(_dt);
    expect(b.stage, BatchStage.frost);
    _paintOnce(g);

    // Kem: 3 đường quẹt ngang qua bánh → nhấc tay khi đủ.
    final cake = LevelLayout.frostCake();
    for (var k = 0; k < 3; k++) {
      final y = cake.center.dy - 20 + k * 20;
      g.pointerDown(3, Offset(cake.left - 25, y));
      for (var i = 1; i <= 20; i++) {
        g.pointerMove(3, Offset(cake.left - 25 + i * (cake.width + 50) / 20, y));
      }
      g.pointerUp(3, Offset(cake.right + 25, y));
    }
    expect(b.stage, BatchStage.topping);

    // Topping: 3 lần chạm hũ đúng.
    final right = b.toppingChoices.indexOf(b.correctTopping);
    for (var k = 0; k < 3; k++) {
      _tap(g, LevelLayout.toppingJar(right).center);
      _paintOnce(g);
    }
    expect(b.toppingsPlaced, 3);
    expect(b.stage, BatchStage.box);

    // Hộp đúng → mẻ vào tủ.
    final boxTile = LevelLayout.tile(LevelLayout.boxTile);
    _tap(g, LevelLayout.choiceRow(boxTile, b.boxChoices.indexOf(b.correctBox)).center);
    g.step(_dt);
    expect(s.displayCase.countOf(RecipeId.cupcakeVanilla), s.tuning.batchSize);
    expect(b.stars, greaterThanOrEqualTo(4));
    _paintOnce(g);
  });

  test('trộn: chỉ chạm (không kéo) → hiện gợi ý xoay, mẻ ở lại; kéo qua lại quanh âu → tính theo góc quét', () {
    final g = _game(_level(startStock: 0, every: 100));
    final s = g.session;
    g.step(_dt);
    s.startBatch(RecipeId.cupcakeVanilla);
    final b = s.kitchen.prep!;
    s.pickMould(b.correctMould);
    expect(g.kitchen.showMixHint, isFalse);
    final c = LevelLayout.bowlCenter();
    _tap(g, c + const Offset(30, 10));
    expect(b.stage, BatchStage.mix);
    expect(g.kitchen.showMixHint, isTrue);
    g.step(_dt);
    _paintOnce(g);

    // Quét qua lại một cung ±90° phía trên âu: mỗi lượt π rad → đủ 1 vòng sau 2 lượt.
    g.pointerDown(4, c + const Offset(50, 0));
    expect(g.kitchen.showMixHint, isFalse);
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 1; i <= 20; i++) {
        final f = pass.isEven ? i / 20 : 1 - i / 20;
        final a = -f * math.pi;
        g.pointerMove(4, c + Offset(math.cos(a), math.sin(a)) * 50);
      }
    }
    expect(g.kitchen.mixTurns, closeTo(1, 0.05));
    g.pointerUp(4, c + const Offset(50, 0));
    expect(b.stage, isNot(BatchStage.mix));
  });

  test('nút × ở ô Trộn huỷ mẻ đang chuẩn bị (ở trạm khuôn và trạm trộn); vùng chạm ≥ 64 px', () {
    final g = _game(_level(startStock: 0, every: 100));
    final s = g.session;
    g.step(_dt);
    final cancel = LevelLayout.cancelPrep();
    expect(cancel.width, greaterThanOrEqualTo(64));
    expect(cancel.height, greaterThanOrEqualTo(64));
    _tap(g, cancel.center); // chưa có mẻ: không làm gì
    expect(s.kitchen.prep, isNull);

    _tap(g, LevelLayout.cardRect(0, 1).center);
    expect(s.kitchen.prep?.stage, BatchStage.mould);
    _paintOnce(g);
    _tap(g, cancel.topLeft.translate(2, 2));
    expect(s.kitchen.prep, isNull);

    _tap(g, LevelLayout.cardRect(0, 1).center);
    final b = s.kitchen.prep!;
    s.pickMould(b.correctMould);
    expect(b.stage, BatchStage.mix);
    _tap(g, cancel.bottomRight.translate(-2, -2));
    expect(s.kitchen.prep, isNull);
    g.step(_dt);
    _paintOnce(g);
    // Huỷ xong bắt đầu mẻ mới được ngay.
    _tap(g, LevelLayout.cardRect(0, 1).center);
    expect(s.kitchen.prep?.stage, BatchStage.mould);
  });

  test('nút × không nằm trong vòng khuấy (kéo trộn không huỷ nhầm)', () {
    final c = LevelLayout.bowlCenter();
    final cancel = LevelLayout.cancelPrep();
    expect(cancel.top, greaterThan(c.dy + 72));
  });

  test('ảnh khách đặc biệt nạp đúng: VIP có look → đúng ảnh, không look → vip_01 + vip_02', () {
    expect(LevelGame.specialSprites(const SpecialVisit(atSec: 1, who: SpecialWho.linh, recipe: RecipeId.macaron)), ['linh']);
    expect(LevelGame.specialSprites(const SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cheesecake, look: 'vip_01')), ['vip_01']);
    expect(LevelGame.specialSprites(const SpecialVisit(atSec: 1, who: SpecialWho.vip, recipe: RecipeId.cheesecake)), ['vip_01', 'vip_02']);
  });

  test('chạm nút Xong ở trạm kem khi chưa phủ → độ phủ 0, mẻ vẫn sang topping', () {
    final g = _game(_level(startStock: 0, every: 100));
    final s = g.session;
    g.step(_dt);
    _tap(g, LevelLayout.cardRect(0, 1).center);
    final b = s.kitchen.prep!;
    s.pickMould(b.correctMould);
    s.finishMix(1);
    _until(g, () => b.ovenProgress >= b.bakeTarget);
    s.takeOut(0);
    g.step(_dt);
    expect(b.stage, BatchStage.frost);
    _tap(g, LevelLayout.frostDone().center);
    expect(b.stage, BatchStage.topping);
  });

  test('chạm khách đặc biệt → onSpecialTap(id)', () {
    final taps = <int>[];
    final g = _game(
      _level(specials: const [SpecialVisit(atSec: 0.5, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)], every: 100),
      onSpecialTap: taps.add,
    );
    final s = g.session;
    _until(g, () => s.specialCustomer?.phase == CustomerPhase.atCounter);
    final id = s.specialCustomer!.id;
    _tap(g, g.customerHitPoint(id)!);
    expect(taps, [id]);
    _paintOnce(g);
  });

  test('đoạn quẹt chỉ tính phần nằm trên bánh', () {
    const r = Rect.fromLTWH(0, 0, 100, 100);
    expect(segmentLengthInRect(const Offset(-50, 50), const Offset(150, 50), r), closeTo(100, 1e-9));
    expect(segmentLengthInRect(const Offset(10, 10), const Offset(40, 10), r), closeTo(30, 1e-9));
    expect(segmentLengthInRect(const Offset(-10, -10), const Offset(-5, 200), r), 0);
  });

  test('ẩn tạm (session dừng) rồi chạy tiếp: khung dài không làm hỏng cảnh', () {
    final g = _game(_level());
    final s = g.session;
    _until(g, () => s.customers.isNotEmpty);
    s.paused = true;
    g.step(5);
    s.paused = false;
    g.step(3); // TickerMode bật lại: một khung rất dài
    g.step(_dt);
    _paintOnce(g);
    expect(s.isOver, isFalse);
  });

  test('tủ kính trong ảnh nền: cột bánh nằm trong lòng kính, vừa khe giữa hai tầng kệ; huy hiệu trong tủ', () {
    for (var slots = 1; slots <= 8; slots++) {
      for (var i = 0; i < slots; i++) {
        final cell = caseCell(i, slots);
        final s = caseCakeSize(cell);
        expect(LevelLayout.caseGlass.inflate(0.01).contains(cell.topLeft) && LevelLayout.caseGlass.inflate(0.01).contains(cell.bottomRight), isTrue);
        for (final o in caseShelfStack[caseShelfCapacity]) {
          expect(cell.center.dx + (o.dx - 0.5) * s, greaterThanOrEqualTo(cell.left - 0.01), reason: 'slots $slots');
          expect(cell.center.dx + (o.dx + 0.5) * s, lessThanOrEqualTo(cell.right + 0.01), reason: 'slots $slots');
          // Kệ dưới: bánh không chọc qua kệ trên; kệ trên (độ sâu 0.4): không chọc qua nóc tủ quá 4 px.
          expect(LevelLayout.lowerShelfY - s + o.dy * s, greaterThanOrEqualTo(LevelLayout.upperShelfBottom - 1));
          expect(LevelLayout.upperShelfY - s + o.dy * 0.4 * s, greaterThanOrEqualTo(LevelLayout.caseGlass.top - 4));
        }
        for (final n in [1, 3, 4, 6]) {
          expect(LevelLayout.caseRect.contains(caseBadgeAt(cell, n)), isTrue);
        }
      }
    }
    // Khách ở quầy lộ từ đầu tới thắt lưng (~56% khung) — nóc tủ ngang thắt lưng.
    const h = LevelLayout.customerHeight * LevelLayout.counterScale;
    final waist = LevelLayout.counterFloor - h * (1 - 0.56);
    expect((waist - LevelLayout.caseRect.top).abs(), lessThan(12));
    // Mép trên bong bóng (tâm thân − 0.437 × cao ảnh bong bóng) dưới HUD, cách ≥ 16 px.
    final bubbleTop = LevelLayout.counterFloor - h + LevelLayout.bubbleOffset.dy * LevelLayout.counterScale -
        0.437 * LevelLayout.bubbleWidth * 270 / 320;
    expect(bubbleTop, greaterThanOrEqualTo(LevelLayout.hudBottom + 16));
  });

  test('ảnh level (bong bóng, huy hiệu, hũ topping) + nền tủ trống nạp được; vẽ cảnh có khách 2 món + khách đặc biệt + trạm topping', () async {
    LevelArt.debugReset();
    await LevelArt.preload().timeout(const Duration(seconds: 20));
    for (final id in LevelArtId.values) {
      // Biểu tượng vật phẩm (GĐ6) có thể chưa có ảnh: thiếu → biểu tượng vẽ code.
      if (const {LevelArtId.boosterFullCase, LevelArtId.boosterPatience, LevelArtId.boosterOven}.contains(id) &&
          !File(id.assetPath).existsSync()) {
        continue;
      }
      expect(LevelArt.image(id), isNotNull, reason: id.assetPath);
    }
    final g = _game(_level(
      menu: const [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate],
      specials: const [SpecialVisit(atSec: 0.5, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)],
    ));
    final s = g.session;
    _until(g, () => s.specialCustomer?.phase == CustomerPhase.atCounter && s.specialCustomer!.phaseT >= 1);
    s.startBatch(RecipeId.cupcakeVanilla);
    final b = s.kitchen.prep!;
    s.pickMould(b.correctMould);
    s.finishMix(1);
    _until(g, () => b.ovenProgress >= b.bakeTarget);
    s.takeOut(0);
    s.finishFrost(1);
    expect(b.stage, BatchStage.topping);
    _tap(g, LevelLayout.toppingJar(b.toppingChoices.indexOf(b.correctTopping)).center);
    expect(b.toppingsPlaced, 1);
    for (var i = 0; i < 5; i++) {
      g.step(_dt);
      _paintOnce(g);
    }
    LevelArt.debugReset();
    _paintOnce(g); // ảnh bị xoá giữa chừng → hình vẽ code dự phòng, không lỗi
  });
}
