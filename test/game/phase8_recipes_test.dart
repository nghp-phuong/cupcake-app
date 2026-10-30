import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/models/recipe.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/components/game_paint.dart';
import 'package:sugarleaf_bakery/game/logic/station_setup.dart';
import 'package:sugarleaf_bakery/game/stations/bake_station.dart';
import 'package:sugarleaf_bakery/game/stations/box_station.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/game/stations/station.dart';
import 'package:sugarleaf_bakery/game/stations/topping_station.dart';

/// Khung tham chiếu của game.
const _frame = Rect.fromLTWH(0, 0, 1280, 720);

/// Khuôn mới của GĐ8 (chỉ có ở món chương 3–5).
const _newMoulds = {
  MouldType.pastryTray,
  MouldType.shellMould,
  MouldType.eclairTray,
  MouldType.piePan,
  MouldType.mooncakeMould,
  MouldType.logPan,
};

Order _orderFor(Recipe r, {int id = 5}) => Order(
      id: id,
      recipe: r.id,
      frosting: r.frostings.first,
      toppings: [ToppingRequest(r.toppings.first, 2)],
      box: r.box,
      line: OrderLineKind.generic1,
    );

void _paint(Station s) {
  final recorder = PictureRecorder();
  s.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

bool _inside(Rect outer, Rect inner) =>
    inner.left >= outer.left && inner.top >= outer.top && inner.right <= outer.right && inner.bottom <= outer.bottom;

void main() {
  final newRecipes = [for (final r in Catalog.recipes) if (r.unlockLevel > Catalog.decoyBaseLevel) r];

  test('GĐ8 có đủ 8 món mới', () => expect(newRecipes, hasLength(8)));

  for (final r in newRecipes) {
    group('${r.id.name} (màn ${r.unlockLevel})', () {
      final order = _orderFor(r);

      test('khuôn mồi: có khuôn đúng, chỉ khuôn đã gặp', () {
        for (var salt = 0; salt < 20; salt++) {
          final m = mouldChoices(r.mould, seededRandom(order, salt), unlockLevel: r.unlockLevel);
          expect(m, hasLength(4));
          expect(m.toSet(), hasLength(4));
          expect(m, contains(r.mould));
          for (final x in m) {
            if (x == r.mould) continue;
            expect(Catalog.isDecoyMould(x, r.unlockLevel), isTrue, reason: '${x.name} chưa mở ở màn ${r.unlockLevel}');
            // Khuôn chỉ có ở món mở sau món này không được lộ ra.
            final intro = Catalog.recipes.where((o) => o.mould == x).map((o) => o.unlockLevel).reduce((a, b) => a < b ? a : b);
            expect(intro, lessThanOrEqualTo(r.unlockLevel), reason: x.name);
          }
        }
      });

      test('khay topping: có loại được gọi, mồi là topping đã mở', () {
        final t = toppingTrays(order, seededRandom(order, 2));
        expect(t, hasLength(4));
        expect(t.toSet(), hasLength(4));
        expect(t, contains(r.toppings.first));
        for (final x in t) {
          expect(Catalog.isDecoyTopping(x, r.unlockLevel), isTrue, reason: x.name);
        }
      });

      test('6 trạm dựng + vẽ không lỗi', () {
        final game = BakeryGame(order: order, modifiers: BakeModifiers.base);
        game.record
          ..mixTurns = r.mixTurns.toDouble()
          ..bakeRelease = r.bakeTarget
          ..frostCoverage = 1;
        final stations = <Station Function()>[
          () => MouldStation(game),
          () => MixStation(game),
          () => BakeStation(game),
          () => FrostStation(game),
          () => ToppingStation(game),
          () => BoxStation(game),
        ];
        for (final create in stations) {
          final s = create()..update(1);
          _paint(s);
          s.update(1 / 60);
          _paint(s);
        }
      });

      test('trạm kem: mặt bánh nằm trong khung, tô theo đường gợi ý đủ phủ', () {
        final game = BakeryGame(order: order, modifiers: BakeModifiers.base);
        final s = FrostStation(game)..update(1);
        expect(_inside(_frame, s.top), isTrue, reason: '${s.top}');
        expect(_inside(s.cakeBox, s.top), isTrue);
        expect(s.top.width, greaterThan(60));
        expect(s.top.height, greaterThan(20));
        final g = s.tracker.guide;
        s.pointerDown(g.first);
        for (final p in g.skip(1)) {
          s.pointerMove(p);
        }
        s.pointerUp(g.last);
        expect(s.tracker.coverage, greaterThan(0.95));
      });

      test('trạm topping: mặt bánh trong khung, thả vào giữa mặt bánh thì nhận', () {
        final game = BakeryGame(order: order, modifiers: BakeModifiers.base);
        final s = ToppingStation(game)..update(1);
        expect(_inside(_frame, s.top), isTrue, reason: '${s.top}');
        // Mặt bánh không lấn sang cột khay topping.
        expect(s.top.right, lessThan(ToppingStation.trayCenter(0).dx - ToppingStation.trayRadius));
        final tray = s.trays.indexOf(r.toppings.first);
        s.pointerDown(ToppingStation.trayCenter(tray));
        s.pointerMove(s.top.center);
        s.pointerUp(s.top.center);
        expect(game.record.toppings, hasLength(1));
        expect(game.record.toppings.single.topping, r.toppings.first);
        _paint(s);
      });

      test('bánh ngồi trên mặt đỡ, thân bánh nằm trong màn', () {
        // Khung vuông có phần trống dưới đáy bánh (bánh dẹt), nên đo theo đáy thân bánh và mặt bánh.
        for (final rect in [FrostStation.cakeRectFor(r.mould, recipe: r.id), ToppingStation.cakeRectFor(r.mould, recipe: r.id)]) {
          final bottom = rect.center.dy + cakeBottomFactor(r.mould, recipe: r.id) * rect.height;
          expect(bottom, lessThanOrEqualTo(_frame.bottom), reason: 'đáy $bottom');
          expect(_inside(_frame, CakeArt.topSurface(rect, r.mould, recipe: r.id)), isTrue);
        }
        expect(cakeBottomFactor(r.mould, recipe: r.id), CakeArt.bottomFactor(r.mould, recipe: r.id));
      });
    });
  }

  test('món có số đo ảnh riêng: trạm kem / topping dùng mặt bánh + đáy theo món', () {
    for (final id in [RecipeId.fruitTart, RecipeId.painAuChocolat]) {
      final r = Catalog.recipe(id);
      final game = BakeryGame(order: _orderFor(r), modifiers: BakeModifiers.base);
      final frost = FrostStation(game);
      expect(frost.cakeBox, FrostStation.cakeRectFor(r.mould, recipe: id));
      expect(frost.top, CakeArt.topSurface(frost.cakeBox, r.mould, recipe: id));
      final topping = ToppingStation(game);
      expect(topping.cakeBox, ToppingStation.cakeRectFor(r.mould, recipe: id));
      expect(topping.top, CakeArt.topSurface(topping.cakeBox, r.mould, recipe: id));
      expect(_inside(_frame, topping.top), isTrue, reason: id.name);
    }
  });

  test('món chương 1–2: mồi không có khuôn / topping GĐ8, giữ nguyên bố trí cũ', () {
    for (final r in Catalog.recipes.where((r) => r.unlockLevel <= Catalog.decoyBaseLevel)) {
      final order = _orderFor(r, id: 3);
      final m = mouldChoices(r.mould, seededRandom(order, 1), unlockLevel: r.unlockLevel);
      expect(m.where(_newMoulds.contains), isEmpty, reason: r.id.name);
      // Không truyền màn (mặc định 1) cũng không lộ khuôn mới.
      expect(mouldChoices(r.mould, seededRandom(order, 1)), m);
      final t = toppingTrays(order, seededRandom(order, 2));
      expect(t.where((x) => (Catalog.toppingUnlockLevel[x] ?? 1) > Catalog.decoyBaseLevel), isEmpty, reason: r.id.name);
    }
  });
}
