import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/logic/frost.dart';
import 'package:sugarleaf_bakery/game/stations/frost_station.dart';

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

/// Canvas giả chỉ đếm số lệnh vẽ (draw*) — đo khối lượng việc mỗi khung hình.
class _CountingCanvas implements Canvas {
  int draws = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().startsWith('Symbol("draw')) draws++;
    return null;
  }
}

void main() {
  test('FrostTracker cộng dồn mỗi điểm đúng một lần vào path', () {
    final t = FrostTracker(guide: const [Offset(0, 0), Offset(50, 0), Offset(100, 0)], radius: 10);
    expect(t.hasStroke, isFalse);
    t.begin(const Offset(0, 0));
    t.extend(const Offset(100, 0));
    final afterFirst = t.pointCount;
    expect(t.strokeCount, 1);
    expect(afterFirst, greaterThan(2)); // có điểm nội suy
    t.begin(const Offset(0, 40)); // chạm rồi nhấc: một chấm
    expect(t.strokeCount, 2);
    expect(t.pointCount, afterFirst + 1);
    final b = t.path.getBounds();
    expect(b.left, lessThanOrEqualTo(0));
    expect(b.right, greaterThanOrEqualTo(100));
    expect(b.bottom, greaterThanOrEqualTo(40));
  });

  test('vẽ nét kem: số lệnh vẽ mỗi khung không tăng theo số nét / độ dài nét', () {
    int drawsAfter(int strokes) {
      final game = BakeryGame(order: _order, modifiers: BakeModifiers.base);
      final s = FrostStation(game)..update(1);
      // Nét ở góc dưới ngoài mặt bánh: không phủ điểm gợi ý nào → phần vẽ chấm gợi ý giữ nguyên.
      for (var k = 0; k < strokes; k++) {
        s.pointerDown(Offset(240, 640 - k * 0.5));
        for (var i = 1; i <= 20; i++) {
          s.pointerMove(Offset(240 + i * 3.0, 640 - k * 0.5));
        }
        s.pointerUp(Offset(300, 640 - k * 0.5));
      }
      expect(s.tracker.coverage, 0);
      final c = _CountingCanvas();
      s.paintStation(c);
      return c.draws;
    }

    final few = drawsAfter(1);
    final many = drawsAfter(40);
    expect(few, greaterThan(10));
    expect(many, few);
  });
}
