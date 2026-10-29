import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/game/logic/bake_meter.dart';
import 'package:sugarleaf_bakery/game/logic/cake_geometry.dart';
import 'package:sugarleaf_bakery/game/logic/frost.dart';
import 'package:sugarleaf_bakery/game/logic/mix_meter.dart';
import 'package:sugarleaf_bakery/game/logic/station_setup.dart';

Offset _onCircle(Offset c, double r, double a) => c + Offset(math.cos(a), math.sin(a)) * r;

void main() {
  group('MixMeter', () {
    const c = Offset(470, 400);

    test('1 vòng quanh tô = 1.0', () {
      final m = MixMeter(center: c);
      m.start(_onCircle(c, 140, 0));
      for (var i = 1; i <= 72; i++) {
        m.move(_onCircle(c, 140, i * 2 * math.pi / 72));
      }
      expect(m.turns, closeTo(1.0, 1e-9));
    });

    test('xoay ngược chiều vẫn cộng, qua mốc ±π không nhảy', () {
      final m = MixMeter(center: c);
      m.start(_onCircle(c, 100, math.pi - 0.1));
      m.move(_onCircle(c, 100, -math.pi + 0.1)); // qua mốc π: chỉ 0.2 rad
      expect(m.turns, closeTo(0.2 / (2 * math.pi), 1e-9));
      m.move(_onCircle(c, 100, math.pi - 0.1)); // quay lại
      expect(m.turns, closeTo(0.4 / (2 * math.pi), 1e-9));
    });

    test('bỏ qua điểm ngoài vành (60–220 px)', () {
      final m = MixMeter(center: c);
      m.start(_onCircle(c, 30, 0)); // trong lõi
      for (var i = 1; i <= 36; i++) {
        m.move(_onCircle(c, 30, i * 2 * math.pi / 36));
      }
      for (var i = 0; i <= 36; i++) {
        m.move(_onCircle(c, 300, i * 2 * math.pi / 36)); // ngoài tô
      }
      expect(m.turns, 0);
      // Đi vào vành: điểm đầu chỉ làm mốc, không cộng.
      m.move(_onCircle(c, 150, 0));
      expect(m.turns, 0);
      m.move(_onCircle(c, 150, math.pi / 2));
      expect(m.turns, closeTo(0.25, 1e-9));
    });

    test('vành elip (yScale): xoay theo elip dẹt hay theo vòng tròn đều đúng 1 vòng', () {
      final m = MixMeter(center: c, innerRadius: 60, outerRadius: 320, yScale: 0.5);
      // Elip dẹt như mặt bột nhìn nghiêng (150 × 45): gần trục dọc chỉ cách tâm 45 px nhưng vẫn trong vành.
      m.start(c + const Offset(150, 0));
      for (var i = 1; i <= 72; i++) {
        final a = i * 2 * math.pi / 72;
        m.move(c + Offset(math.cos(a) * 150, math.sin(a) * 45));
      }
      expect(m.turns, closeTo(1.0, 1e-9));
      m.end();
      m.start(_onCircle(c, 150, 0));
      for (var i = 1; i <= 72; i++) {
        m.move(_onCircle(c, 150, i * 2 * math.pi / 72));
      }
      expect(m.turns, closeTo(2.0, 1e-9));
      // Ngoài vành elip (dọc 200 px → 400 sau khi chia 0.5) bị bỏ qua.
      expect(m.inRing(c + const Offset(0, 200)), isFalse);
      expect(m.inRing(c + const Offset(0, 20)), isFalse);
    });

    test('nhấc tay ngắt nét: nét mới không cộng góc nhảy', () {
      final m = MixMeter(center: c);
      m.start(_onCircle(c, 150, 0));
      m.move(_onCircle(c, 150, 0.5));
      m.end();
      m.start(_onCircle(c, 150, 2.5));
      expect(m.turns, closeTo(0.5 / (2 * math.pi), 1e-9));
    });
  });

  group('frostCoverage', () {
    final guide = spiralGuide(const Rect.fromLTWH(0, 0, 300, 120));

    test('phủ hết = 1, rỗng = 0', () {
      expect(frostCoverage(guide, guide, 1), 1.0);
      expect(frostCoverage(guide, const [], 22), 0.0);
      expect(frostCoverage(const [], guide, 22), 0.0);
    });

    test('một nửa điểm', () {
      const g = [Offset(0, 0), Offset(100, 0), Offset(200, 0), Offset(300, 0)];
      expect(frostCoverage(g, const [Offset(5, 0), Offset(195, 0)], 10), 0.5);
      expect(frostCoverage(g, const [Offset(50, 0)], 10), 0.0);
    });

    test('FrostTracker nội suy khi kéo nhanh', () {
      final t = FrostTracker(guide: const [Offset(0, 0), Offset(50, 0), Offset(100, 0)], radius: 10);
      t.begin(const Offset(0, 0));
      t.extend(const Offset(100, 0)); // một bước dài: điểm giữa vẫn được phủ
      expect(t.coverage, 1.0);
      expect(t.nextIndex, -1);
    });
  });

  group('isOnCake', () {
    const top = Rect.fromLTWH(100, 100, 200, 80); // tâm (200, 140), bán trục 100 × 40

    test('trong / ngoài elip', () {
      expect(isOnCake(const Offset(200, 140), top, 0), isTrue);
      expect(isOnCake(const Offset(295, 140), top, 0), isTrue);
      expect(isOnCake(const Offset(310, 140), top, 0), isFalse);
      expect(isOnCake(const Offset(200, 185), top, 0), isFalse);
      // Góc hộp bao nằm ngoài elip.
      expect(isOnCake(const Offset(105, 105), top, 0), isFalse);
    });

    test('snap nới elip', () {
      expect(isOnCake(const Offset(310, 140), top, 16), isTrue);
      expect(isOnCake(const Offset(200, 195), top, 16), isTrue);
      expect(isOnCake(const Offset(340, 140), top, 32), isFalse);
      expect(isOnCake(const Offset(330, 140), top, 32), isTrue);
    });

    test('clampIntoEllipse đưa điểm vào trong', () {
      final p = clampIntoEllipse(const Offset(320, 140), top, inset: 0.9);
      expect(isOnCake(p, top, 0), isTrue);
      expect(clampIntoEllipse(const Offset(200, 140), top), const Offset(200, 140));
    });
  });

  group('spiralGuide', () {
    test('đúng 120 điểm, nằm trong elip', () {
      const r = Rect.fromLTWH(220, 300, 276, 120);
      final g = spiralGuide(r);
      expect(g.length, 120);
      for (final p in g) {
        expect(isOnCake(p, r, 0), isTrue);
      }
      expect(spiralGuide(r, samples: 50).length, 50);
    });

    test('điểm cách đều theo chiều dài cung', () {
      final g = spiralGuide(const Rect.fromLTWH(0, 0, 400, 400));
      final d = [for (var i = 1; i < g.length; i++) (g[i] - g[i - 1]).distance];
      final mean = d.reduce((a, b) => a + b) / d.length;
      for (final x in d) {
        expect(x, closeTo(mean, mean * 0.15));
      }
    });
  });

  group('BakeMeter', () {
    test('3 giây chạy hết; giữ tới 1.0 thì tự thả', () {
      final m = BakeMeter();
      m.press();
      for (var i = 0; i < 15; i++) {
        m.tick(0.1);
      }
      expect(m.value, closeTo(0.5, 1e-9));
      var auto = false;
      for (var i = 0; i < 20; i++) {
        auto = m.tick(0.1) || auto;
      }
      expect(auto, isTrue);
      expect(m.release, 1.0);
    });

    test('thả tay ghi vị trí; chạm quá ngắn bỏ qua', () {
      final m = BakeMeter();
      m.press();
      m.tick(0.06);
      m.lift();
      expect(m.released, isFalse);
      m.press();
      m.tick(1.8);
      m.lift();
      expect(m.release, closeTo(0.62, 1e-9));
    });

    test('bakedVisual: 0 → mục tiêu → 1.0 ứng với sống → vàng → cháy', () {
      expect(bakedVisual(0, 0.65), 0);
      expect(bakedVisual(0.65, 0.65), 1);
      expect(bakedVisual(1, 0.65), 2);
    });
  });

  group('Bố trí trạm', () {
    const order = Order(
      id: 3,
      recipe: RecipeId.cupcakeVanilla,
      frosting: FrostingId.vanillaCream,
      toppings: [ToppingRequest(ToppingId.cherry, 2)],
      box: BoxType.small,
      line: OrderLineKind.generic1,
    );

    test('4 khuôn khác nhau, có khuôn đúng', () {
      final m = mouldChoices(MouldType.tartShell, seededRandom(order));
      expect(m.length, 4);
      expect(m.toSet().length, 4);
      expect(m, contains(MouldType.tartShell));
    });

    test('4 khay topping, có loại được gọi, mồi là topping đã mở', () {
      final t = toppingTrays(order, seededRandom(order));
      expect(t.length, 4);
      expect(t.toSet().length, 4);
      expect(t, contains(ToppingId.cherry));
      // cupcakeVanilla mở ở cấp 1 → chỉ dùng topping mở cấp 1.
      expect(t, everyElement(isIn([ToppingId.sprinkles, ToppingId.strawberry, ToppingId.cherry, ToppingId.chocolateChips])));
      // Cùng đơn → cùng bố trí.
      expect(toppingTrays(order, seededRandom(order)), t);
    });
  });
}
